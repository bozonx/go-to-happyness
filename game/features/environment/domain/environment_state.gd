class_name EnvironmentState
extends RefCounted

## Calendar, climate and weather rules assembled into one snapshot
## (`world_environment.md` §2, §6, §12).
##
## It is domain: no nodes, no shaders, no wall clock. Everything is computed from
## the game minute, the day of year and the seed, which is exactly what lets the
## laboratory reproduce a game frame without starting a settlement (§17), and
## what lets a skipped night cost nothing (§3).
##
## Writing goes through `EnvironmentDirector`, never through here directly.

## What can be seen on a clear day, in world units. Fog and aerial perspective
## are graded between this and `MINIMUM_VISIBILITY`.
const CLEAR_VISIBILITY := 1400.0
const MINIMUM_VISIBILITY := 45.0
## Reference height the map temperature is quoted at. Height correction is the
## same function plus this offset, not a second source of truth (§6).
const TEMPERATURE_REFERENCE_HEIGHT := 0.0

var calendar := WorldCalendar.new()
var climate: ClimateProfile = ClimateCatalog.profile(ClimateProfile.DEFAULT_ID)
var weather := WeatherModel.new()
## The one seed the whole environment is a function of. Saved; everything derived
## from it is not (§16).
var seed := 0

var _rng := RandomNumberGenerator.new()
## Set when a scripted override pins the pattern, so a new day does not roll it
## away behind the cutscene's back.
var pinned_pattern: StringName = &""


func configure(
	climate_id: StringName,
	day_of_year: int,
	minute_of_day: int,
	p_latitude: float,
	pattern_id: StringName,
	p_seed: int,
) -> void:
	climate = ClimateCatalog.profile(climate_id)
	seed = p_seed
	_rng.seed = p_seed
	calendar.configure(float(minute_of_day), day_of_year, p_latitude, climate.days_per_year)
	roll_day(pattern_id, minute_of_day, true)


## Rolls the weather for the current day. An empty `pattern_id` means "let the
## climate choose", which is what an ordinary morning does; a game that owns its
## own forecast hands the pattern in from outside (§7).
func roll_day(
	pattern_id: StringName = &"",
	announcement_minute := 6 * 60,
	calendar_day_started := false,
) -> void:
	var chosen := pattern_id
	if not pinned_pattern.is_empty():
		chosen = pinned_pattern
	if chosen.is_empty():
		chosen = choose_pattern(calendar.day_of_year)
	var next_pattern := WeatherPatternCatalog.pattern(chosen)
	if calendar_day_started:
		weather.new_day(next_pattern, _day_rng(), announcement_minute)
	else:
		weather.change_pattern(next_pattern, _day_rng(), announcement_minute, calendar.minute_of_day)


## The climate's own choice for a day: deterministic in `(day, seed)` and
## weighted by season, so the same world always produces the same weather and a
## winter profile shifts the odds rather than swapping the table (§7).
func choose_pattern(day_of_year: int) -> StringName:
	var candidates := WeatherPatternCatalog.patterns_for(climate)
	if candidates.is_empty():
		return WeatherPattern.DEFAULT_ID
	var season := climate.season_at(day_of_year)
	var total := 0.0
	for pattern: WeatherPattern in candidates:
		total += maxf(pattern.weight_for_season(season), 0.0)
	if total <= 0.0:
		return candidates[0].id
	var pick := _day_rng().randf() * total
	for pattern: WeatherPattern in candidates:
		pick -= maxf(pattern.weight_for_season(season), 0.0)
		if pick <= 0.0:
			return pattern.id
	return candidates[-1].id


## Map temperature: season, time of day and weather, in that order (§6). The
## fourth term — height — is `EnvironmentSnapshot.temperature_at`, because it is
## a property of the point asked about rather than of the map.
func temperature_at_minute(minute: float) -> float:
	var seasonal := climate.seasonal_temperature(calendar.day_of_year, calendar.latitude)
	var cover := weather.cloud_cover_at(minute)
	var storm := weather.storm_influence_at(minute)
	# Cloud flattens the daily swing from both ends: it shades the day and it traps
	# the night's heat, which is one damping factor rather than two rules.
	var damping := 1.0 - clampf(cover * 0.45 + storm * 0.35, 0.0, 0.85)
	var diurnal := _diurnal_shape(minute) * climate.diurnal_amplitude * damping
	# Daytime cloud cools; night-time cloud holds warmth. One term, opposite signs.
	var daylight := smoothstep(-0.05, 0.25, _solar_height_at(minute))
	var cloud_term := lerpf(cover * 1.6, -cover * 3.2, daylight) - storm * 1.4
	return seasonal + diurnal + cloud_term


## Temperature as it is felt: precipitation and wind take from it without
## changing what a thermometer would read (§6, term three).
func felt_temperature_at_minute(minute: float) -> float:
	var wind := weather.wind_strength_at(minute)
	var intensity := weather.intensity_at(minute)
	return temperature_at_minute(minute) - wind * 3.2 - intensity * 2.0


## Snow or rain, from the temperature and the climate's snow chance — never from
## a "cold day" flag (§10). Around the threshold the chance decides, and it does
## so per minute of the same window, so a shower turns over during the day
## instead of the whole day committing at 06:00.
func precipitation_type_at(minute: float) -> int:
	if weather.intensity_at(minute) <= 0.0:
		return EnvironmentSnapshot.Precipitation.NONE
	var chance := climate.snow_chance(temperature_at_minute(minute))
	return (
		EnvironmentSnapshot.Precipitation.SNOW if chance >= 0.5
		else EnvironmentSnapshot.Precipitation.RAIN
	)


## How far can be seen (§12). Fog thickens before dawn when the daily spread is
## widest, burns off toward noon, and grows in precipitation and under a front.
## Ground fog tied to water and hollows needs locality and is stage 3.
func visibility_at(minute: float) -> float:
	if not climate.has_atmosphere:
		return CLEAR_VISIBILITY
	var cover := weather.cloud_cover_at(minute)
	var storm := weather.storm_influence_at(minute)
	var intensity := weather.intensity_at(minute)
	var sunrise := SolarGeometry.sunrise_minute(calendar.day_of_year, calendar.latitude, climate.days_per_year)
	# A window that opens a couple of hours before sunrise and closes a few hours
	# after it. Clear skies radiate heat away, so a clear night is the foggy one.
	var dawn := 1.0 - smoothstep(0.0, 240.0, absf(fposmod(minute - sunrise + 720.0, 1440.0) - 720.0))
	var radiation_fog := dawn * (1.0 - cover) * clampf(climate.diurnal_amplitude / 8.0, 0.0, 1.0)
	var fog := clampf(radiation_fog * 0.85 + storm * 0.35 + intensity * 0.4, 0.0, 1.0)
	# Geometric, not linear. Visibility spans a factor of thirty, and interpolating
	# it linearly means half a unit of fog still leaves seven hundred metres of
	# sight — a number that reads as "clear" in every scene the game has. Halving
	# the distance per equal step of fog is how the eye actually experiences it.
	return CLEAR_VISIBILITY * pow(MINIMUM_VISIBILITY / CLEAR_VISIBILITY, fog)


## The whole environment as one immutable value (§2). Rebuilt per frame; cheap
## because every field above it is a curve evaluated at a minute.
func build_snapshot(mode := EnvironmentSnapshot.Mode.SIMULATED) -> EnvironmentSnapshot:
	var minute := calendar.minute_of_day
	var snapshot := EnvironmentSnapshot.new()
	snapshot.minute_of_day = minute
	snapshot.day_of_year = calendar.day_of_year
	snapshot.year = calendar.year
	snapshot.day_of_session = calendar.day_of_session
	snapshot.days_per_year = climate.days_per_year
	snapshot.latitude = calendar.latitude
	snapshot.time_scale = calendar.time_scale
	snapshot.elapsed_minutes = calendar.elapsed_minutes

	snapshot.climate = climate.id
	snapshot.season = climate.season_at(calendar.day_of_year)
	snapshot.season_phase = climate.season_phase(calendar.day_of_year)

	var temperature := temperature_at_minute(minute)
	snapshot.temperature = temperature
	snapshot.felt_temperature = felt_temperature_at_minute(minute)
	snapshot.lapse_rate = climate.lapse_rate
	snapshot.snow_chance = climate.snow_chance(temperature)
	snapshot.growth_rate = climate.growth_rate(temperature)

	var days := climate.days_per_year
	snapshot.daylight_hours = SolarGeometry.daylight_hours(calendar.day_of_year, calendar.latitude, days)
	snapshot.sunrise_minute = SolarGeometry.sunrise_minute(calendar.day_of_year, calendar.latitude, days)
	snapshot.sunset_minute = SolarGeometry.sunset_minute(calendar.day_of_year, calendar.latitude, days)
	snapshot.solar_height = SolarGeometry.solar_height(calendar.day_of_year, calendar.latitude, minute, days)
	snapshot.solar_altitude_degrees = rad_to_deg(asin(snapshot.solar_height))
	snapshot.solar_azimuth_degrees = SolarGeometry.solar_azimuth_degrees(calendar.day_of_year, calendar.latitude, minute, days)
	snapshot.lunar_height = SolarGeometry.lunar_height(
		calendar.day_of_year, calendar.latitude, minute, calendar.elapsed_minutes, days)
	snapshot.lunar_altitude_degrees = rad_to_deg(asin(snapshot.lunar_height))
	snapshot.lunar_azimuth_degrees = SolarGeometry.lunar_azimuth_degrees(
		calendar.day_of_year, calendar.latitude, minute, calendar.elapsed_minutes, days)
	snapshot.lunar_phase_axis = SolarGeometry.lunar_phase_axis(calendar.elapsed_minutes)

	snapshot.pattern = weather.pattern.id
	snapshot.pattern_name = weather.pattern.display_name
	snapshot.cloud_cover = weather.cloud_cover_at(minute)
	snapshot.storm_influence = weather.storm_influence_at(minute)
	snapshot.cloud_phase = weather.cloud_phase_at(minute)
	snapshot.cloud_seed = weather.cloud_seed
	snapshot.wind_vector = weather.wind_vector_at(minute)
	snapshot.wind_direction = weather.wind_direction_at(minute)
	snapshot.wind_strength = weather.wind_strength_at(minute)
	snapshot.wind_displacement = weather.wind_displacement_at(minute)
	snapshot.precipitation = precipitation_type_at(minute)
	snapshot.precipitation_intensity = weather.intensity_at(minute)
	snapshot.precipitation_phase = weather.phase_at(minute)

	snapshot.visibility_range = visibility_at(minute)
	snapshot.mode = mode
	return snapshot


## Only what does not follow from time (§16): the calendar, the seed, the rolled
## pattern and its window. Clouds and wind are restored by evaluating them again.
func save_state() -> Dictionary:
	return {
		"calendar": calendar.snapshot_state(),
		"climate": String(climate.id),
		"seed": seed,
		"weather": weather.save_state(),
		"pinned_pattern": String(pinned_pattern),
	}


func restore_state(state: Dictionary) -> void:
	climate = ClimateCatalog.profile(StringName(state.get("climate", climate.id)))
	seed = int(state.get("seed", seed))
	_rng.seed = seed
	var calendar_state: Variant = state.get("calendar", {})
	if calendar_state is Dictionary:
		calendar.restore_state(calendar_state as Dictionary)
	var weather_state: Variant = state.get("weather", {})
	if weather_state is Dictionary:
		weather.restore_state(weather_state as Dictionary)
	pinned_pattern = StringName(state.get("pinned_pattern", ""))


## A generator seeded by `(seed, day)`. Rolling a day twice — a reload, a rewind —
## therefore produces the same day rather than a new one.
func _day_rng() -> RandomNumberGenerator:
	_rng.seed = hash([seed, calendar.year, calendar.day_of_year])
	return _rng


func _solar_height_at(minute: float) -> float:
	return SolarGeometry.solar_height(
		calendar.day_of_year, calendar.latitude, minute, climate.days_per_year)


## `-1 … 1` over the day: coldest at sunrise, warmest well into the afternoon.
## Derived from sunrise rather than from a fixed hour, so a short winter day and
## a long summer one are shaped by the same rule.
func _diurnal_shape(minute: float) -> float:
	var sunrise := SolarGeometry.sunrise_minute(calendar.day_of_year, calendar.latitude, climate.days_per_year)
	return -cos(TAU * fposmod(minute - sunrise, 1440.0) / 1440.0)
