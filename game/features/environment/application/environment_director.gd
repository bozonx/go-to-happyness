class_name EnvironmentDirector
extends RefCounted

## The one way to **write** the environment (`world_environment.md` §2, §14).
##
## It lives in `WorldSession`, not in a game, so every game on the engine and
## everything the map scenario runs can reach it. It is the reason the whole
## system is assembled: a cutscene, an arena, the laboratory and a map rule all
## say "make it the 15th of March, 19:40, thunderstorm" through this object and
## through no other path. A second path is the bug.
##
## Two modes, and this is the point of the class:
##
## * `SIMULATED` — the environment's rules roll the day themselves.
## * `SCRIPTED`  — a value is held by whoever set it.
##
## An override **has a transition and it can be released**. A cutscene that set a
## storm and forgot to clear it must not leave the world in an eternal storm; nor
## may the sky snap back mid-frame. `release()` returns to what the rules say,
## over a transition.

signal day_rolled(day_of_session: int, pattern: StringName)
signal season_changed(season: StringName)
signal weather_changed(pattern: StringName)
## Re-emitted from the calendar so accumulation catches up on skipped time (§13).
signal time_jumped(skipped_minutes: float)

const DEFAULT_TRANSITION_SECONDS := 2.5

var state := EnvironmentState.new()
## Game minutes per real second the host runs time at. The director owns it
## because changing the flow of time is a write to the environment (§14).
var minutes_per_second := 12.0

var _mode := EnvironmentSnapshot.Mode.SIMULATED
var _snapshot: EnvironmentSnapshot = null
## Blend of the scripted values over the rules', `0 … 1`. Both entering and
## leaving an override move through it, which is what makes `release()` gradual.
var _override_blend := 0.0
var _override_target := 0.0
var _override_rate := 1.0 / DEFAULT_TRANSITION_SECONDS
## Scripted values, applied on top of the rules while `_override_blend > 0`.
var _override_cloud_cover := -1.0
var _override_storm := -1.0
var _override_precipitation := -1.0
var _last_season: StringName = &""
var _last_pattern: StringName = &""


func _init() -> void:
	state.calendar.day_started.connect(_on_day_started)
	state.calendar.time_jumped.connect(func(minutes: float) -> void: time_jumped.emit(minutes))


## Starts the environment from resolved session values (§15). The resolution
## order itself belongs to `map_start.md` §7 — the director receives answers, it
## never reads the map.
func configure(
	climate_id: StringName,
	day_of_year: int,
	minute_of_day: int,
	latitude: float,
	pattern_id: StringName,
	seed: int,
	dynamic := true,
) -> void:
	state.configure(climate_id, day_of_year, minute_of_day, latitude, pattern_id, seed)
	_last_season = state.climate.season_at(day_of_year)
	_last_pattern = state.weather.pattern.id
	_snapshot = null
	# `dynamic: false` from map_start.md §7 is not a separate mechanism: it is a
	# session that begins SCRIPTED and is never released.
	if dynamic:
		_mode = EnvironmentSnapshot.Mode.SIMULATED
		state.calendar.time_scale = 1.0
	else:
		_mode = EnvironmentSnapshot.Mode.SCRIPTED
		state.calendar.time_scale = 0.0
		state.pinned_pattern = state.weather.pattern.id


# --- Reading -------------------------------------------------------------------

## The current environment. One value per frame: `tick` invalidates it, and every
## consumer in that frame reads the same object.
func snapshot() -> EnvironmentSnapshot:
	if _snapshot == null:
		_snapshot = _build()
	return _snapshot


func mode() -> int:
	return _mode


func is_scripted() -> bool:
	return _mode == EnvironmentSnapshot.Mode.SCRIPTED


# --- The frame -----------------------------------------------------------------

## Advances time and rebuilds the snapshot. The host calls this once per frame
## and then only reads; no consumer advances anything.
func tick(delta: float) -> void:
	state.calendar.advance(delta, minutes_per_second)
	if _override_blend != _override_target:
		_override_blend = move_toward(_override_blend, _override_target, delta * _override_rate)
		if is_equal_approx(_override_blend, 0.0) and _override_target == 0.0:
			_clear_override_values()
	_snapshot = _build()


# --- Writing (§14) -------------------------------------------------------------

## Sets the time of day. Time only moves forward — accumulation cannot be
## un-accumulated (§13.1) — so an hour already past lands on it tomorrow.
func set_time_of_day(minute: int) -> void:
	# Built before the jump on purpose: accumulation hears `time_jumped` while the
	# calendar is mid-operation, and the weather it should apply over the skipped
	# interval is the weather that prevailed, not tomorrow's.
	snapshot()
	state.calendar.set_time_of_day(minute)
	_snapshot = null


func set_day_of_year(day: int) -> void:
	snapshot()
	state.calendar.set_day_of_year(day)
	_snapshot = null


## Skips forward, the operation behind "skip the night". Accumulation hears about
## it through `time_jumped` and catches up in one step.
func skip_minutes(minutes: float) -> void:
	snapshot()
	state.calendar.jump_minutes(minutes)
	_snapshot = null


## Scrubs the clock in either direction, for the laboratory (§17). It is the one
## write that skips accumulation, and it is allowed to exist only because a lab
## has no world to accumulate in — a game must use `skip_minutes`.
func scrub_minutes(minutes: float) -> void:
	state.calendar.scrub(minutes)
	_snapshot = null


func set_time_scale(scale: float) -> void:
	state.calendar.time_scale = maxf(scale, 0.0)
	_snapshot = null


## The day's weather, chosen by whoever owns the forecast. A game maps its own
## vocabulary onto a pattern name and calls this; the environment never learns
## what "потепление" is (§7).
func set_pattern(pattern_id: StringName, announcement_minute := -1) -> void:
	var minute := announcement_minute if announcement_minute >= 0 else int(state.calendar.minute_of_day)
	state.roll_day(pattern_id, minute)
	_snapshot = null
	_emit_weather_changed()


## Holds a pattern across day boundaries until `release()`. This is the cutscene's
## "and it stays a storm", as opposed to "make today a storm".
func pin_pattern(pattern_id: StringName, transition_seconds := DEFAULT_TRANSITION_SECONDS) -> void:
	state.pinned_pattern = pattern_id
	set_pattern(pattern_id)
	_enter_scripted(transition_seconds)


## Forces precipitation regardless of what the day rolled. `duration_minutes`
## bounds it so a forgotten override still ends.
func force_precipitation(duration_minutes := 240.0, transition_seconds := DEFAULT_TRANSITION_SECONDS) -> void:
	var start := state.calendar.minute_of_day
	state.weather.force_precipitation(start, start + duration_minutes)
	_override_precipitation = 1.0
	_enter_scripted(transition_seconds)


func stop_precipitation(transition_seconds := DEFAULT_TRANSITION_SECONDS) -> void:
	state.weather.clear_precipitation()
	_override_precipitation = 0.0
	_enter_scripted(transition_seconds)


## Pins the two sky axes directly. Kept separate because they are independent
## (§8): pinning cloudiness must not grey the sky, and pinning the front must not
## invent cumulus.
func set_sky(cloud_cover := -1.0, storm_influence := -1.0, transition_seconds := DEFAULT_TRANSITION_SECONDS) -> void:
	_override_cloud_cover = cloud_cover
	_override_storm = storm_influence
	_enter_scripted(transition_seconds)


## Returns the environment to what the rules say, over a transition. Called by
## every scripted consumer when it is done — and safe to call when nothing was
## overridden.
func release(transition_seconds := DEFAULT_TRANSITION_SECONDS) -> void:
	state.pinned_pattern = &""
	_mode = EnvironmentSnapshot.Mode.SIMULATED
	if state.calendar.time_scale == 0.0:
		state.calendar.time_scale = 1.0
	_override_target = 0.0
	_override_rate = 1.0 / maxf(transition_seconds, 0.001)
	_snapshot = null


# --- Persistence (§16) ---------------------------------------------------------

func save_state() -> Dictionary:
	var data := state.save_state()
	data["mode"] = _mode
	data["override"] = {
		"blend": _override_blend,
		"target": _override_target,
		"cloud_cover": _override_cloud_cover,
		"storm": _override_storm,
		"precipitation": _override_precipitation,
	}
	return data


func restore_state(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	state.restore_state(data)
	_mode = int(data.get("mode", EnvironmentSnapshot.Mode.SIMULATED))
	var override: Variant = data.get("override", {})
	if override is Dictionary:
		var values := override as Dictionary
		_override_blend = float(values.get("blend", 0.0))
		_override_target = float(values.get("target", 0.0))
		_override_cloud_cover = float(values.get("cloud_cover", -1.0))
		_override_storm = float(values.get("storm", -1.0))
		_override_precipitation = float(values.get("precipitation", -1.0))
	_last_season = state.climate.season_at(state.calendar.day_of_year)
	_last_pattern = state.weather.pattern.id
	_snapshot = null
	return true


# --- Internals -----------------------------------------------------------------

func _build() -> EnvironmentSnapshot:
	var snapshot := state.build_snapshot(_mode)
	if _override_blend <= 0.0:
		return snapshot
	# The override is a blend over the rules rather than a replacement, which is
	# what makes both taking control and giving it back gradual.
	if _override_cloud_cover >= 0.0:
		snapshot.cloud_cover = lerpf(snapshot.cloud_cover, _override_cloud_cover, _override_blend)
	if _override_storm >= 0.0:
		snapshot.storm_influence = lerpf(snapshot.storm_influence, _override_storm, _override_blend)
	if _override_precipitation >= 0.0:
		snapshot.precipitation_intensity = lerpf(
			snapshot.precipitation_intensity, _override_precipitation, _override_blend)
		if snapshot.precipitation_intensity <= 0.0:
			snapshot.precipitation = EnvironmentSnapshot.Precipitation.NONE
		elif snapshot.precipitation == EnvironmentSnapshot.Precipitation.NONE:
			snapshot.precipitation = state.precipitation_type_at(snapshot.minute_of_day)
			if snapshot.precipitation == EnvironmentSnapshot.Precipitation.NONE:
				snapshot.precipitation = (
					EnvironmentSnapshot.Precipitation.SNOW if snapshot.snow_chance >= 0.5
					else EnvironmentSnapshot.Precipitation.RAIN
				)
	return snapshot


func _enter_scripted(transition_seconds: float) -> void:
	_mode = EnvironmentSnapshot.Mode.SCRIPTED
	_override_target = 1.0
	_override_rate = 1.0 / maxf(transition_seconds, 0.001)
	_snapshot = null


func _clear_override_values() -> void:
	_override_cloud_cover = -1.0
	_override_storm = -1.0
	_override_precipitation = -1.0


func _on_day_started(day_of_session: int) -> void:
	# Rolling here rather than in a game's tick is what makes the daily forecast
	# happen for every game on the engine, not only for the one that remembered.
	state.roll_day(&"", 0)
	_snapshot = null
	day_rolled.emit(day_of_session, state.weather.pattern.id)
	_emit_weather_changed()
	var season := state.climate.season_at(state.calendar.day_of_year)
	if season != _last_season:
		_last_season = season
		season_changed.emit(season)


func _emit_weather_changed() -> void:
	if state.weather.pattern.id == _last_pattern:
		return
	_last_pattern = state.weather.pattern.id
	weather_changed.emit(_last_pattern)
