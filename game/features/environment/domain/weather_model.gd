class_name WeatherModel
extends RefCounted

## Deterministic cloud, wind and precipitation scheduling for one day
## (`world_environment.md` §7–§9).
##
## Everything visible here is a pure function of `(minute, pattern, seed)`. The
## sole persisted continuity value is the origin of integrated wind displacement:
## it prevents cloud/flag animation from jumping when a save crosses midnight
## (§3, §9). The day is chosen once in `new_day`; every question afterwards is
## answered by evaluating a curve at a minute, which is what lets the player skip
## a night or a cutscene rewind time for free.
##
## What it no longer knows is the settlement. It takes a `WeatherPattern` — a
## description of a sky — where it used to take `TentEraSurvivalRules.Weather`.
##
## What *kind* of precipitation falls is deliberately not here: that follows from
## temperature and the climate's snow chance, and lives with them (§10).

const MINUTES_PER_DAY := 24 * 60
const DEFAULT_TRANSITION_MINUTES := 30.0
const CLOUD_BUILDUP_MINUTES := 150.0
const CLOUD_CLEARING_MINUTES := 105.0
const WIND_DIRECTION_TRANSITION_MINUTES := 240.0
const WIND_INTEGRATION_STEP_MINUTES := 10.0

enum Phase { CLEAR, FADE_IN, FULL, FADE_OUT }
enum CloudPhase { CLEAR, FAIR, PARTLY_CLOUDY, CLOUDY, OVERCAST, STORM }

var pattern: WeatherPattern = WeatherPatternCatalog.pattern(WeatherPattern.DEFAULT_ID)
var precipitation_start_minute: float = -1.0
var precipitation_end_minute: float = -1.0
var transition_minutes: float = DEFAULT_TRANSITION_MINUTES
var cloud_seed := 0.0
# --- Global wind (authoritative source for the whole game) ---------------------
# The sky consumes it to drift the cloud layers, but it is deliberately a general
# world parameter: waves, sails and flags read the same wind out of the snapshot
# so everything wind-driven in the world goes one way (§9).
var wind_previous_direction := 0.0
var wind_direction := 0.0
var _wind_displacement_origin := Vector2.ZERO
var _wind_displacement_samples := PackedVector2Array()
var _rolled := false


## Rolls one day. `announcement_minute` is when the forecast is declared, which is
## also the earliest the precipitation window may open — a day announced at 06:00
## cannot start raining at 05:00.
func new_day(next_pattern: WeatherPattern, rng: RandomNumberGenerator, announcement_minute: int = 6 * 60) -> void:
	if _rolled and not _wind_displacement_samples.is_empty():
		_wind_displacement_origin += _wind_displacement_samples[-1]
	_roll(next_pattern, rng, announcement_minute, true)


## Replaces the forecast inside the current calendar day. This is deliberately
## not `new_day`: a settlement announcing its own pattern at 06:00 must not add a
## second day's wind displacement or choose a second prevailing bearing (§7, §9).
func change_pattern(
	next_pattern: WeatherPattern,
	rng: RandomNumberGenerator,
	announcement_minute: int,
	current_minute: float,
) -> void:
	if not _rolled:
		new_day(next_pattern, rng, announcement_minute)
		return
	var displacement_here := wind_displacement_at(current_minute)
	_roll(next_pattern, rng, announcement_minute, false)
	_wind_displacement_origin += displacement_here - wind_displacement_at(current_minute)


func _roll(
	next_pattern: WeatherPattern,
	rng: RandomNumberGenerator,
	announcement_minute: int,
	advance_bearing: bool,
) -> void:
	pattern = next_pattern if next_pattern != null else WeatherPatternCatalog.pattern(WeatherPattern.DEFAULT_ID)
	precipitation_start_minute = -1.0
	precipitation_end_minute = -1.0
	cloud_seed = rng.randf_range(0.0, TAU)
	# A new prevailing bearing is selected exactly once per day. Limit the turn so
	# consecutive days flow into one another instead of making implausible reversals.
	if not _rolled:
		wind_direction = rng.randf_range(0.0, TAU)
		wind_previous_direction = wind_direction
	elif advance_bearing:
		wind_previous_direction = wind_direction
		var daily_turn := rng.randf_range(-PI * 0.42, PI * 0.42)
		wind_direction = wrapf(wind_previous_direction + daily_turn, 0.0, TAU)
	_rolled = true
	_roll_precipitation_window(rng, announcement_minute)
	_rebuild_wind_displacement_samples()


## Forces a precipitation window regardless of the pattern's chance — the
## scripted "let it rain now" of §14. Cleared by rolling a new day.
func force_precipitation(start_minute: float, end_minute: float) -> void:
	precipitation_start_minute = start_minute
	precipitation_end_minute = maxf(end_minute, start_minute + transition_minutes * 2.0)


func clear_precipitation() -> void:
	precipitation_start_minute = -1.0
	precipitation_end_minute = -1.0


func has_precipitation() -> bool:
	return precipitation_start_minute >= 0.0


func is_precipitating_at(current_minute: float) -> bool:
	if not has_precipitation():
		return false
	return current_minute >= precipitation_start_minute and current_minute < precipitation_end_minute


func intensity_at(current_minute: float) -> float:
	if not has_precipitation():
		return 0.0
	if current_minute < precipitation_start_minute or current_minute >= precipitation_end_minute:
		return 0.0
	if current_minute < precipitation_start_minute + transition_minutes:
		return (current_minute - precipitation_start_minute) / transition_minutes
	if current_minute > precipitation_end_minute - transition_minutes:
		return (precipitation_end_minute - current_minute) / transition_minutes
	return 1.0


func phase_at(current_minute: float) -> int:
	var intensity := intensity_at(current_minute)
	if intensity <= 0.0:
		return Phase.CLEAR
	if intensity >= 1.0:
		return Phase.FULL
	if current_minute < precipitation_start_minute + transition_minutes:
		return Phase.FADE_IN
	return Phase.FADE_OUT


func cloud_cover_at(current_minute: float) -> float:
	# Fair-weather cloudiness only: purely "how many/how big the clouds are". It never
	# seals into a grey storm ceiling and never adds haze — the storm front owns all of
	# that through storm_influence_at, so the two axes stay independent (§8).
	var minutes := fposmod(current_minute, float(MINUTES_PER_DAY))
	return clampf(_living_cloud_cover_at(minutes), 0.0, 1.0)


func storm_influence_at(current_minute: float) -> float:
	if not has_precipitation():
		return 0.0
	var minutes := fposmod(current_minute, float(MINUTES_PER_DAY))
	# The front rolls in well before the first drops and disperses after the last,
	# so the player watches the weather approach instead of being caught by it.
	var arrival := smoothstep(precipitation_start_minute - CLOUD_BUILDUP_MINUTES, precipitation_start_minute, minutes)
	var departure := 1.0 - smoothstep(precipitation_end_minute, precipitation_end_minute + CLOUD_CLEARING_MINUTES, minutes)
	return clampf(arrival * departure, 0.0, 1.0) * pattern.storm_scale


func cloud_phase_at(current_minute: float) -> int:
	# A caption for UI, texts and scenario conditions — never for rendering (§8).
	var cover := cloud_cover_at(current_minute)
	if storm_influence_at(current_minute) > 0.75:
		return CloudPhase.STORM
	if cover < 0.08:
		return CloudPhase.CLEAR
	if cover < 0.22:
		return CloudPhase.FAIR
	if cover < 0.42:
		return CloudPhase.PARTLY_CLOUDY
	if cover < 0.67:
		return CloudPhase.CLOUDY
	return CloudPhase.OVERCAST


func wind_direction_at(current_minute: float) -> float:
	# The bearing changes only after the daily forecast is rolled, then eases toward
	# that day's target during the early hours and remains stable until tomorrow.
	var minutes := fposmod(current_minute, float(MINUTES_PER_DAY))
	var blend := smoothstep(0.0, WIND_DIRECTION_TRANSITION_MINUTES, minutes)
	return lerp_angle(wind_previous_direction, wind_direction, blend)


func wind_strength_at(current_minute: float) -> float:
	# Two broad waves create a few gentle changes per day. The smaller secondary
	# harmonic prevents a mechanical loop without producing rapid gust flicker.
	var day_phase := fposmod(current_minute, float(MINUTES_PER_DAY)) / float(MINUTES_PER_DAY) * TAU
	var gust := sin(day_phase * 2.0 + cloud_seed * 1.3) * 0.72
	gust += sin(day_phase * 4.0 + cloud_seed * 0.47 + 1.1) * 0.28
	var strength := pattern.wind_base_strength + gust * pattern.wind_gust_amount
	strength = lerpf(strength, 1.0, storm_influence_at(current_minute) * 0.85)
	return clampf(strength, 0.0, 1.0)


func wind_vector_at(current_minute: float) -> Vector2:
	# Normalised bearing scaled by strength; the canonical wind other systems read.
	var angle := wind_direction_at(current_minute)
	return Vector2(cos(angle), sin(angle)) * wind_strength_at(current_minute)


func wind_displacement_at(current_minute: float) -> Vector2:
	# Integrated wind is the stable animation coordinate for clouds and any future
	# flags/waves. Multiplying today's vector by total elapsed time would teleport
	# them whenever wind speed or bearing changes (§9).
	if _wind_displacement_samples.is_empty():
		return _wind_displacement_origin
	var minutes := fposmod(current_minute, float(MINUTES_PER_DAY))
	var sample_position := minutes / WIND_INTEGRATION_STEP_MINUTES
	var sample_index := mini(int(floor(sample_position)), _wind_displacement_samples.size() - 2)
	var fraction := sample_position - float(sample_index)
	return _wind_displacement_origin + _wind_displacement_samples[sample_index].lerp(
		_wind_displacement_samples[sample_index + 1],
		fraction
	)


func save_state() -> Dictionary:
	return {
		"pattern": String(pattern.id),
		"precipitation_start_minute": precipitation_start_minute,
		"precipitation_end_minute": precipitation_end_minute,
		"cloud_seed": cloud_seed,
		"wind_direction": wind_direction,
		"wind_previous_direction": wind_previous_direction,
		"wind_displacement_origin": [_wind_displacement_origin.x, _wind_displacement_origin.y],
		"rolled": _rolled,
	}


func restore_state(state: Dictionary) -> void:
	pattern = WeatherPatternCatalog.pattern(StringName(state.get("pattern", pattern.id)))
	precipitation_start_minute = float(state.get("precipitation_start_minute", -1.0))
	precipitation_end_minute = float(state.get("precipitation_end_minute", -1.0))
	cloud_seed = float(state.get("cloud_seed", cloud_seed))
	wind_direction = float(state.get("wind_direction", wind_direction))
	wind_previous_direction = float(state.get("wind_previous_direction", wind_previous_direction))
	var origin: Variant = state.get("wind_displacement_origin", null)
	if origin is Array and (origin as Array).size() == 2:
		_wind_displacement_origin = Vector2(float(origin[0]), float(origin[1]))
	_rolled = bool(state.get("rolled", true))
	_rebuild_wind_displacement_samples()


func _roll_precipitation_window(rng: RandomNumberGenerator, announcement_minute: int) -> void:
	if pattern.precipitation_chance <= 0.0:
		return
	if pattern.precipitation_chance < 1.0 and rng.randf() > pattern.precipitation_chance:
		return
	# Precipitation takes part of a day, not all of it (§7).
	var earliest := maxi(pattern.precipitation_earliest, announcement_minute)
	var latest_end := mini(pattern.precipitation_latest_end, MINUTES_PER_DAY)
	var latest_start := latest_end - pattern.precipitation_min_duration
	if latest_start <= earliest:
		earliest = maxi(0, latest_start - 1)
	if latest_start <= earliest:
		return
	var start_minute := rng.randi_range(earliest, latest_start)
	var end_minute := rng.randi_range(start_minute + pattern.precipitation_min_duration, latest_end)
	precipitation_start_minute = float(start_minute)
	precipitation_end_minute = float(end_minute)


func _living_cloud_cover_at(minutes: float) -> float:
	var day_phase := minutes / float(MINUTES_PER_DAY) * TAU
	# Broad harmonics let cloud cover breathe over hours, not flicker between
	# states. Integer frequencies keep the signal continuous across midnight.
	var broad := sin(day_phase + cloud_seed)
	var medium := sin(day_phase * 2.0 + cloud_seed * 1.71 + 1.9)
	var detail := sin(day_phase * 3.0 + cloud_seed * 0.63 + 4.2)
	var living_signal := broad * 0.58 + medium * 0.29 + detail * 0.13
	return clampf(pattern.cloud_base + living_signal * pattern.cloud_variation, 0.0, 1.0)


func _rebuild_wind_displacement_samples() -> void:
	_wind_displacement_samples = PackedVector2Array()
	_wind_displacement_samples.append(Vector2.ZERO)
	var displacement := Vector2.ZERO
	var previous_wind := wind_vector_at(0.0)
	var minute := WIND_INTEGRATION_STEP_MINUTES
	while minute <= float(MINUTES_PER_DAY):
		var current_wind := wind_vector_at(minute)
		displacement += (previous_wind + current_wind) * 0.5 * WIND_INTEGRATION_STEP_MINUTES
		_wind_displacement_samples.append(displacement)
		previous_wind = current_wind
		minute += WIND_INTEGRATION_STEP_MINUTES
