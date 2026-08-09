extends SceneTree

## Rules of the world environment (`design_docs/engine/world_environment.md` §19.16).
##
## The four things worth proving are the four invariants the design rests on:
## the same `(day, minute, seed)` yields the same snapshot; accumulation catches
## up on time that was skipped rather than pretending it did not pass; a save and
## a load return the same world; and a game's own forecast vocabulary maps onto
## weather patterns from outside without the engine learning it.


func _init() -> void:
	run_tests()
	quit(0)


static func run_tests() -> void:
	_test_calendar_owns_time()
	_test_calendar_only_moves_forward()
	_test_climate_curve_and_seasons()
	_test_solar_arc_follows_the_calendar()
	_test_snapshot_is_a_function_of_day_minute_seed()
	_test_temperature_decides_snow_not_a_cold_flag()
	_test_pattern_is_not_settlement_vocabulary()
	_test_director_override_and_release()
	_test_forced_precipitation_expires()
	_test_airless_climate_has_no_fog()
	_test_cloud_caption_respects_the_storm_axis()
	_test_scenario_flags_follow_the_current_snapshot()
	_test_save_round_trip()
	_test_accumulation_catches_up_on_skipped_time()
	_test_chunk_cursor_accounts_for_each_slices_elapsed_time()
	print("test_domain_environment: OK")


static func _test_calendar_owns_time() -> void:
	var calendar := WorldCalendar.new()
	calendar.configure(23.0 * 60.0, 365, 54.0, 365)
	var days: Array[int] = []
	calendar.day_started.connect(func(day: int) -> void: days.append(day))
	calendar.advance(1.0, 120.0)  # two game hours
	assert(days.size() == 1 and days[0] == 2)
	# Day of year and day of session are different numbers, and the year rolls.
	assert(calendar.day_of_year == 1)
	assert(calendar.year == 2)
	assert(calendar.day_of_session == 2)
	assert(is_equal_approx(calendar.minute_of_day, 60.0))
	assert(is_equal_approx(calendar.elapsed_minutes, 120.0))


static func _test_calendar_only_moves_forward() -> void:
	var calendar := WorldCalendar.new()
	calendar.configure(12.0 * 60.0, 100, 54.0, 365)
	var skipped: Array[float] = []
	calendar.time_jumped.connect(func(minutes: float) -> void: skipped.append(minutes))
	# An hour already past is reached tomorrow: accumulation cannot be undone.
	calendar.set_time_of_day(6 * 60)
	assert(calendar.day_of_year == 101)
	assert(is_equal_approx(calendar.minute_of_day, 360.0))
	assert(skipped.size() == 1 and is_equal_approx(skipped[0], 18.0 * 60.0))
	calendar.set_day_of_year(103)
	assert(calendar.day_of_year == 103)


static func _test_climate_curve_and_seasons() -> void:
	var temperate := ClimateCatalog.profile(&"temperate")
	var summer := temperate.seasonal_temperature(temperate.warmest_day, 54.0)
	var winter := temperate.seasonal_temperature(temperate.warmest_day + 182, 54.0)
	assert(summer > winter + 20.0)
	assert(temperate.season_at(temperate.warmest_day) == &"summer")
	assert(temperate.season_at(15) == &"winter")
	# The southern hemisphere is the same curve half a year out of phase, so no
	# flag anywhere else in the system has to know about hemispheres.
	assert(temperate.seasonal_temperature(temperate.warmest_day, -34.0) < summer)
	# A tropical profile declares two seasons rather than four, which is why
	# boundaries belong to the profile and not to a global enum.
	var tropical := ClimateCatalog.profile(&"tropical")
	assert(tropical.seasons.size() == 2)
	assert(tropical.season_at(200) in [&"wet", &"dry"])
	assert(tropical.snow_chance(15.0) == 0.0)
	# Season phase runs 0 → 1 inside a season and resets at the boundary.
	assert(temperate.season_phase(60) < 0.05)
	assert(temperate.season_phase(150) > 0.9)


static func _test_solar_arc_follows_the_calendar() -> void:
	# The whole reason winter can be read visually: one arc in January and another
	# in July, at the same latitude and the same hour.
	var summer_noon := SolarGeometry.solar_height(172, 54.0, 720.0)
	var winter_noon := SolarGeometry.solar_height(355, 54.0, 720.0)
	assert(summer_noon > winter_noon + 0.4)
	assert(SolarGeometry.daylight_hours(172, 54.0) > SolarGeometry.daylight_hours(355, 54.0) + 6.0)
	# Polar day and polar night fall straight out of the same formula.
	assert(is_equal_approx(SolarGeometry.daylight_hours(172, 80.0), 24.0))
	assert(is_equal_approx(SolarGeometry.daylight_hours(355, 80.0), 0.0))
	# Azimuth is measured from due south and sweeps eastward-to-westward.
	assert(SolarGeometry.solar_azimuth_degrees(172, 54.0, 480.0) < 0.0)
	assert(SolarGeometry.solar_azimuth_degrees(172, 54.0, 960.0) > 0.0)
	assert(absf(SolarGeometry.solar_azimuth_degrees(172, 54.0, 720.0)) < 1.0)


static func _test_snapshot_is_a_function_of_day_minute_seed() -> void:
	var first := _state(&"temperate", 90, 9 * 60, 4242)
	var second := _state(&"temperate", 90, 9 * 60, 4242)
	var a := first.build_snapshot()
	var b := second.build_snapshot()
	for field: String in [
		"cloud_cover", "storm_influence", "temperature", "wind_strength",
		"precipitation_intensity", "solar_height", "visibility_range",
	]:
		assert(is_equal_approx(a.get(field), b.get(field)))
	assert(a.pattern == b.pattern)
	# A different seed is a different world; the same one is the same world.
	var other := _state(&"temperate", 90, 9 * 60, 9999).build_snapshot()
	assert(other.cloud_seed != a.cloud_seed or other.pattern != a.pattern)
	# The snapshot is the whole read interface: season, temperature and fog are
	# fields, not extra calls into the rules.
	assert(a.season != &"")
	assert(a.daylight_hours > 0.0)
	assert(a.visibility_range > 0.0)
	# Height correction is the same function, not a second source of truth.
	assert(a.temperature_at(Vector3(0.0, 100.0, 0.0)) < a.temperature)


static func _test_temperature_decides_snow_not_a_cold_flag() -> void:
	# Deep winter in a polar climate under a pattern that precipitates: snow.
	var polar := _state(&"polar", 15, 12 * 60, 7, &"snowfall", 72.0)
	polar.weather.force_precipitation(0.0, 1440.0)
	assert(polar.temperature_at_minute(720.0) < 0.0)
	assert(polar.precipitation_type_at(720.0) == EnvironmentSnapshot.Precipitation.SNOW)
	# The same pattern in a tropical climate delivers rain — the pattern is a sky,
	# not a decision about what falls.
	# At its own latitude: a tropical curve read at 54° north is not tropical, which
	# is the latitude term of §6 doing its job.
	var tropical := _state(&"tropical", 15, 12 * 60, 7, &"snowfall", 9.0)
	tropical.weather.force_precipitation(0.0, 1440.0)
	assert(tropical.temperature_at_minute(720.0) > 15.0)
	assert(tropical.precipitation_type_at(720.0) == EnvironmentSnapshot.Precipitation.RAIN)


static func _test_pattern_is_not_settlement_vocabulary() -> void:
	# The engine's weather never sees a settlement enum; the settlement maps onto a
	# pattern name from its own side (§7).
	assert(TentEraSurvivalRules.weather_pattern_for(TentEraSurvivalRules.Weather.RAIN) == &"rain")
	assert(TentEraSurvivalRules.weather_pattern_for(TentEraSurvivalRules.Weather.WARMING) == &"clear")
	assert(TentEraSurvivalRules.weather_pattern_for(TentEraSurvivalRules.Weather.COOLING) == &"cloudy")
	for pattern_id: StringName in [&"clear", &"cloudy", &"rain"]:
		assert(WeatherPatternCatalog.has_pattern(pattern_id))
	# A rain pattern always opens a window; a clear one never does.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var model := WeatherModel.new()
	model.new_day(WeatherPatternCatalog.pattern(&"rain"), rng, 6 * 60)
	assert(model.has_precipitation())
	assert(model.precipitation_start_minute >= 6 * 60)
	# The front arrives before the first drop and clears after the last (§8).
	assert(model.storm_influence_at(model.precipitation_start_minute - WeatherModel.CLOUD_BUILDUP_MINUTES - 1.0) == 0.0)
	assert(model.storm_influence_at(model.precipitation_start_minute) > 0.0)
	model.new_day(WeatherPatternCatalog.pattern(&"clear"), rng, 6 * 60)
	assert(not model.has_precipitation())
	assert(model.storm_influence_at(12 * 60) == 0.0)


static func _test_director_override_and_release() -> void:
	var director := EnvironmentDirector.new()
	director.configure(&"temperate", 100, 8 * 60, 54.0, &"clear", 11)
	assert(director.mode() == EnvironmentSnapshot.Mode.SIMULATED)
	director.set_sky(0.9, 0.8, 0.0)
	director.tick(0.016)
	assert(director.is_scripted())
	assert(director.snapshot().cloud_cover > 0.8)
	# Release returns to the rules — over a transition, never as a mid-frame snap.
	director.release(0.0)
	director.tick(0.016)
	assert(director.mode() == EnvironmentSnapshot.Mode.SIMULATED)
	assert(director.snapshot().cloud_cover < 0.5)
	# `dynamic: false` is not a separate mechanism: a session begun SCRIPTED.
	var frozen := EnvironmentDirector.new()
	frozen.configure(&"temperate", 100, 8 * 60, 54.0, &"clear", 11, false)
	assert(frozen.is_scripted())
	frozen.tick(1.0)
	assert(is_equal_approx(frozen.snapshot().minute_of_day, 8.0 * 60.0))


static func _test_forced_precipitation_expires() -> void:
	var director := EnvironmentDirector.new()
	director.configure(&"temperate", 100, 8 * 60, 54.0, &"clear", 11)
	director.minutes_per_second = 60.0
	director.force_precipitation(60.0, 0.0)
	director.tick(0.01)
	assert(director.snapshot().is_precipitating())
	director.tick(1.1)
	director.tick(EnvironmentDirector.DEFAULT_TRANSITION_SECONDS + 0.1)
	assert(not director.snapshot().is_precipitating())
	assert(not director.is_scripted())


static func _test_airless_climate_has_no_fog() -> void:
	var airless := _state(&"airless", 120, 5 * 60, 4, &"vacuum")
	assert(is_equal_approx(airless.visibility_at(5 * 60), EnvironmentState.CLEAR_VISIBILITY))


static func _test_cloud_caption_respects_the_storm_axis() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var model := WeatherModel.new()
	var dense := WeatherPattern.from_dict({"id": "dense", "cloud_base": 1.0, "cloud_variation": 0.0})
	model.new_day(dense, rng)
	assert(model.storm_influence_at(720.0) == 0.0)
	assert(model.cloud_phase_at(720.0) == WeatherModel.CloudPhase.OVERCAST)


static func _test_scenario_flags_follow_the_current_snapshot() -> void:
	var director := EnvironmentDirector.new()
	director.configure(&"temperate", 100, 12 * 60, 54.0, &"clear", 22)
	var runtime := MapScenarioRuntime.new()
	runtime.configure(MapScenario.new())
	var vocabulary := EnvironmentScenarioVocabulary.new()
	vocabulary.install(director, runtime)
	assert(not bool(runtime.flag_value(EnvironmentScenarioVocabulary.FLAG_IS_NIGHT)))
	director.set_time_of_day(23 * 60)
	vocabulary.publish_state(director.snapshot())
	assert(bool(runtime.flag_value(EnvironmentScenarioVocabulary.FLAG_IS_NIGHT)))
	assert(int(runtime.flag_value(EnvironmentScenarioVocabulary.FLAG_MINUTE_OF_DAY)) == 23 * 60)


static func _test_save_round_trip() -> void:
	var director := EnvironmentDirector.new()
	director.configure(&"temperate", 210, 14 * 60, 61.0, &"rain", 5150)
	director.tick(2.0)
	var before := director.snapshot()
	var state := director.save_state()

	var restored := EnvironmentDirector.new()
	restored.configure(&"temperate", 1, 0, 0.0, &"clear", 0)
	assert(restored.restore_state(state))
	var after := restored.snapshot()
	# What is saved is what does not follow from time; cloud and wind come back
	# because they are recomputed from it (§16).
	assert(after.day_of_year == before.day_of_year)
	assert(after.year == before.year)
	assert(after.day_of_session == before.day_of_session)
	assert(is_equal_approx(after.minute_of_day, before.minute_of_day))
	assert(is_equal_approx(after.latitude, before.latitude))
	assert(after.pattern == before.pattern)
	assert(is_equal_approx(after.cloud_cover, before.cloud_cover))
	assert(is_equal_approx(after.wind_strength, before.wind_strength))
	assert(is_equal_approx(after.temperature, before.temperature))
	assert(after.wind_displacement.distance_to(before.wind_displacement) < 0.001)


static func _test_accumulation_catches_up_on_skipped_time() -> void:
	var terrain := TerrainGrid.new()
	terrain.configure(2.0, 16)
	var service := TerrainService.new()
	service.configure(terrain)
	var accumulation := EnvironmentAccumulationService.new()
	accumulation.configure(service, null, terrain, null)

	var snapshot := EnvironmentSnapshot.new()
	snapshot.precipitation = EnvironmentSnapshot.Precipitation.SNOW
	snapshot.precipitation_intensity = 1.0
	snapshot.temperature = -8.0
	# A negative cell on purpose: the board is centred on the origin, and a fixture
	# entirely east of it hides the recurring bug of this codebase.
	var probe := Vector2i(-4, -3)
	assert(terrain.snow_depth_at(probe) == 0)
	# A night that was skipped rather than lived must still have snowed.
	accumulation.catch_up(snapshot, 8.0 * 60.0)
	assert(terrain.snow_depth_at(probe) > 0)

	var deep := terrain.snow_depth_at(probe)
	var thaw := EnvironmentSnapshot.new()
	thaw.temperature = 9.0
	thaw.solar_height = 0.6
	accumulation.catch_up(thaw, 12.0 * 60.0)
	assert(terrain.snow_depth_at(probe) < deep)


static func _test_chunk_cursor_accounts_for_each_slices_elapsed_time() -> void:
	var terrain := TerrainGrid.new()
	terrain.configure(2.0, 32)
	var terrain_service := TerrainService.new()
	terrain_service.configure(terrain)
	var accumulation := EnvironmentAccumulationService.new()
	accumulation.configure(terrain_service, null, terrain, null)
	var snapshot := EnvironmentSnapshot.new()
	snapshot.precipitation = EnvironmentSnapshot.Precipitation.SNOW
	snapshot.precipitation_intensity = 1.0
	snapshot.temperature = -5.0
	# Initialise the per-slice clocks, then run two full cursor rounds. Every slice
	# receives the time since its own previous visit, not merely the latest frame.
	accumulation.tick(snapshot)
	for index in range(9):
		snapshot.elapsed_minutes += 22.5
		accumulation.tick(snapshot)
	assert(terrain.snow_depth_at(Vector2i(-15, -15)) > 0)
	assert(terrain.snow_depth_at(Vector2i(15, 15)) > 0)


static func _state(
	climate: StringName,
	day: int,
	minute: int,
	seed: int,
	pattern: StringName = &"",
	latitude := 54.0,
) -> EnvironmentState:
	var state := EnvironmentState.new()
	state.configure(climate, day, minute, latitude, pattern, seed)
	return state
