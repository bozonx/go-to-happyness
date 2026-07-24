class_name WeatherState
extends RefCounted

## Deterministic rain and cloud scheduling for a single in-game day.
##
## Cloud cover is deliberately separate from precipitation: a cool day can be
## cloudy without raining, while rain builds a storm ceiling before the first
## drops fall. Presentation consumes only the continuous cover value and never
## needs to know how the forecast was chosen.

const MINUTES_PER_DAY := 24 * 60
const DEFAULT_TRANSITION_MINUTES := 30.0
const MIN_DURATION_MINUTES := 180
const CLOUD_BUILDUP_MINUTES := 150.0
const CLOUD_CLEARING_MINUTES := 105.0

enum Phase { CLEAR, FADE_IN, FULL_RAIN, FADE_OUT }
enum CloudPhase { CLEAR, FAIR, PARTLY_CLOUDY, CLOUDY, OVERCAST, STORM }
# Kind of precipitation currently falling. RAIN today; SNOW is wired through the
# whole pipeline (see precipitation_type_at) so the snow effect can be dropped in
# later without touching the callers.
enum Precipitation { NONE, RAIN, SNOW }

var forecast_weather: int = -1
var is_raining: bool = false
var is_cold: bool = false
var rain_start_minute: float = -1.0
var rain_end_minute: float = -1.0
var transition_minutes: float = DEFAULT_TRANSITION_MINUTES
var cloud_base_cover := 0.0
var cloud_variation := 0.0
var cloud_seed := 0.0
# --- Global wind (authoritative source for the whole game) ---------------------
# The sky consumes it to drift the cloud layers, but it is deliberately a general
# weather parameter: waves, sailboats and waving flags should read wind_vector_at /
# wind_direction_at / wind_strength_at so every wind-driven system stays in sync.
# Direction is chosen fresh each day (wind shifts once per day) and drifts a little
# across the day; strength gusts, and a storm front drives it toward a gale.
var wind_direction := 0.0
var wind_base_strength := 0.35
var wind_gust_amount := 0.28
var _previous_minute: float = -1.0


func new_day(weather: int, rng: RandomNumberGenerator, announcement_minute: int = 6 * 60) -> void:
	forecast_weather = weather
	is_raining = false
	is_cold = weather == TentEraSurvivalRules.Weather.COOLING
	rain_start_minute = -1.0
	rain_end_minute = -1.0
	_previous_minute = -1.0
	_match_cloud_profile(weather, rng)
	# Wind shifts to a new prevailing bearing each day.
	wind_direction = rng.randf_range(0.0, TAU)

	if weather != TentEraSurvivalRules.Weather.RAIN:
		return

	var latest_start := MINUTES_PER_DAY - MIN_DURATION_MINUTES
	if announcement_minute >= latest_start:
		announcement_minute = maxi(0, latest_start - 1)
	var start_minute := rng.randi_range(announcement_minute, latest_start)
	var end_minute := rng.randi_range(start_minute + MIN_DURATION_MINUTES, MINUTES_PER_DAY)
	rain_start_minute = float(start_minute)
	rain_end_minute = float(end_minute)


func update(current_minute: float) -> bool:
	var previous := is_raining
	_previous_minute = current_minute
	if forecast_weather != TentEraSurvivalRules.Weather.RAIN or rain_start_minute < 0.0:
		is_raining = false
	else:
		is_raining = current_minute >= rain_start_minute and current_minute < rain_end_minute
	return previous != is_raining


func intensity_at(current_minute: float) -> float:
	if forecast_weather != TentEraSurvivalRules.Weather.RAIN or rain_start_minute < 0.0:
		return 0.0
	if current_minute < rain_start_minute:
		return 0.0
	if current_minute >= rain_end_minute:
		return 0.0
	if current_minute < rain_start_minute + transition_minutes:
		return (current_minute - rain_start_minute) / transition_minutes
	if current_minute > rain_end_minute - transition_minutes:
		return (rain_end_minute - current_minute) / transition_minutes
	return 1.0


func phase_at(current_minute: float) -> int:
	var intensity := intensity_at(current_minute)
	if intensity <= 0.0:
		return Phase.CLEAR
	if intensity >= 1.0:
		return Phase.FULL_RAIN
	if current_minute < rain_start_minute + transition_minutes:
		return Phase.FADE_IN
	return Phase.FADE_OUT


func cloud_cover_at(current_minute: float) -> float:
	# Fair-weather cloudiness only: purely "how many/how big the clouds are". It never
	# seals into a grey storm ceiling and never adds haze — the storm front owns all of
	# that through storm_influence_at, so the two axes stay independent.
	var minutes := fposmod(current_minute, float(MINUTES_PER_DAY))
	return clampf(_living_cloud_cover_at(minutes), 0.0, 1.0)


func wind_direction_at(current_minute: float) -> float:
	# The day's prevailing bearing with a slow intra-day swing.
	var day_phase := fposmod(current_minute, float(MINUTES_PER_DAY)) / float(MINUTES_PER_DAY) * TAU
	return wind_direction + sin(day_phase + cloud_seed) * 0.4


func wind_strength_at(current_minute: float) -> float:
	# Gusts up and down through the day, then rises toward a gale under a storm front.
	var day_phase := fposmod(current_minute, float(MINUTES_PER_DAY)) / float(MINUTES_PER_DAY) * TAU
	var gust := sin(day_phase * 7.0 + cloud_seed * 1.3) * 0.5 + sin(day_phase * 3.0 + 1.1) * 0.5
	var strength := wind_base_strength + gust * wind_gust_amount
	strength = lerpf(strength, 1.0, storm_influence_at(current_minute) * 0.85)
	return clampf(strength, 0.0, 1.0)


func wind_vector_at(current_minute: float) -> Vector2:
	# Normalised bearing scaled by strength; the canonical wind other systems read.
	var angle := wind_direction_at(current_minute)
	return Vector2(cos(angle), sin(angle)) * wind_strength_at(current_minute)


func precipitation_type_at(current_minute: float) -> int:
	# What is falling right now. Cold days will fall as SNOW once the snow effect
	# exists; until then a cold rain forecast still reports SNOW so the plumbing and
	# balancing can be exercised, and the presentation decides what to actually spawn.
	if intensity_at(current_minute) <= 0.0:
		return Precipitation.NONE
	return Precipitation.SNOW if is_cold else Precipitation.RAIN


func storm_influence_at(current_minute: float) -> float:
	if forecast_weather != TentEraSurvivalRules.Weather.RAIN or rain_start_minute < 0.0:
		return 0.0
	var minutes := fposmod(current_minute, float(MINUTES_PER_DAY))
	var storm_arrival := smoothstep(rain_start_minute - CLOUD_BUILDUP_MINUTES, rain_start_minute, minutes)
	var storm_departure := 1.0 - smoothstep(rain_end_minute, rain_end_minute + CLOUD_CLEARING_MINUTES, minutes)
	return clampf(storm_arrival * storm_departure, 0.0, 1.0)


func cloud_phase_at(current_minute: float) -> int:
	var cover := cloud_cover_at(current_minute)
	if cover < 0.08:
		return CloudPhase.CLEAR
	if cover < 0.22:
		return CloudPhase.FAIR
	if cover < 0.42:
		return CloudPhase.PARTLY_CLOUDY
	if cover < 0.67:
		return CloudPhase.CLOUDY
	if cover < 0.88:
		return CloudPhase.OVERCAST
	return CloudPhase.STORM


func _match_cloud_profile(weather: int, rng: RandomNumberGenerator) -> void:
	cloud_seed = rng.randf_range(0.0, TAU)
	match weather:
		TentEraSurvivalRules.Weather.WARMING:
			cloud_base_cover = 0.13
			cloud_variation = 0.11
			wind_base_strength = 0.28
		TentEraSurvivalRules.Weather.COOLING:
			cloud_base_cover = 0.50
			cloud_variation = 0.18
			wind_base_strength = 0.45
		TentEraSurvivalRules.Weather.RAIN:
			cloud_base_cover = 0.28
			cloud_variation = 0.18
			wind_base_strength = 0.5
		_:
			cloud_base_cover = 0.24
			cloud_variation = 0.20
			wind_base_strength = 0.35


func _living_cloud_cover_at(minutes: float) -> float:
	var day_phase := minutes / float(MINUTES_PER_DAY) * TAU
	# Several slow harmonics create changing clear, fair, and partly-cloudy
	# intervals without per-frame randomness. Integer frequencies keep the
	# signal continuous across midnight; cloud_seed makes every day distinct.
	var broad := sin(day_phase * 3.0 + cloud_seed)
	var medium := sin(day_phase * 5.0 + cloud_seed * 1.71 + 1.9)
	var detail := sin(day_phase * 9.0 + cloud_seed * 0.63 + 4.2)
	var living_signal := broad * 0.52 + medium * 0.31 + detail * 0.17
	return clampf(cloud_base_cover + living_signal * cloud_variation, 0.0, 1.0)
