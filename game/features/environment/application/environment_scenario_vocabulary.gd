class_name EnvironmentScenarioVocabulary
extends RefCounted

## The environment's half of the map scenario (`world_environment.md` §14).
##
## The map author and a cutscene use **one** vocabulary, because both go through
## `EnvironmentDirector`; a second path for controlling the weather is exactly
## what this whole system exists to prevent. Nothing here is hard-coded into the
## scenario runtime: actions arrive through `register_action` and moments through
## `publish`, the same seam a gameplay module uses.
##
## Conditions take the one shape the rule format has — a test over a declared
## flag (`map_editor.md` §10.3). That is not a compromise: the moment a condition
## could read `temperature <= -5` directly, the map format would know what a
## temperature is. So the environment **declares** its flags into the running
## scenario and keeps them current, and an author writes
## `{"flag": "env.is_snowing"}` with the machinery that already exists.

const ACTION_SET_TIME := &"gth.environment:set_time"
const ACTION_SET_DAY := &"gth.environment:set_day"
const ACTION_SKIP := &"gth.environment:skip_minutes"
const ACTION_SET_WEATHER := &"gth.environment:set_weather"
const ACTION_FORCE_PRECIPITATION := &"gth.environment:force_precipitation"
const ACTION_STOP_PRECIPITATION := &"gth.environment:stop_precipitation"
const ACTION_SET_TIME_SCALE := &"gth.environment:set_time_scale"
const ACTION_RELEASE := &"gth.environment:release"

const TRIGGER_DAY_STARTED := &"gth.environment:day_started"
const TRIGGER_SEASON_CHANGED := &"gth.environment:season_changed"
const TRIGGER_WEATHER_CHANGED := &"gth.environment:weather_changed"

## Flags the environment owns and keeps current. The prefix is reserved: a
## scenario declaring its own `env.` flag is overwritten, and the validator has
## one place to say so.
const FLAG_PREFIX := "env."
const FLAG_DAY_OF_YEAR := &"env.day_of_year"
const FLAG_MINUTE_OF_DAY := &"env.minute_of_day"
const FLAG_TEMPERATURE := &"env.temperature"
const FLAG_IS_RAINING := &"env.is_raining"
const FLAG_IS_SNOWING := &"env.is_snowing"
const FLAG_IS_NIGHT := &"env.is_night"
const FLAG_SEASON_PREFIX := "env.season."

var director: EnvironmentDirector = null
var runtime: MapScenarioRuntime = null

var _season_flags: Array[StringName] = []


## Binds the environment to a running scenario. Called once per session, before
## the scenario starts, so the prologue's first rule already reads a real season
## rather than the flag table's neutral default.
func install(p_director: EnvironmentDirector, p_runtime: MapScenarioRuntime) -> void:
	director = p_director
	runtime = p_runtime
	if director == null or runtime == null:
		return
	_declare_flags()
	runtime.register_action(ACTION_SET_TIME, _on_set_time)
	runtime.register_action(ACTION_SET_DAY, _on_set_day)
	runtime.register_action(ACTION_SKIP, _on_skip)
	runtime.register_action(ACTION_SET_WEATHER, _on_set_weather)
	runtime.register_action(ACTION_FORCE_PRECIPITATION, _on_force_precipitation)
	runtime.register_action(ACTION_STOP_PRECIPITATION, _on_stop_precipitation)
	runtime.register_action(ACTION_SET_TIME_SCALE, _on_set_time_scale)
	runtime.register_action(ACTION_RELEASE, _on_release)
	director.day_rolled.connect(_on_day_rolled)
	director.season_changed.connect(_on_season_changed)
	director.weather_changed.connect(_on_weather_changed)
	publish_state(director.snapshot())


## Refreshes the environment's flags. The host calls it on the frames that matter
## rather than every frame: a flag write publishes `flag_changed`, and doing that
## sixty times a second for a minute counter would make the rule table hot.
func publish_state(snapshot: EnvironmentSnapshot) -> void:
	if runtime == null or snapshot == null:
		return
	runtime.set_flag(FLAG_DAY_OF_YEAR, snapshot.day_of_year)
	runtime.set_flag(FLAG_MINUTE_OF_DAY, int(snapshot.minute_of_day))
	runtime.set_flag(FLAG_TEMPERATURE, roundi(snapshot.temperature))
	runtime.set_flag(FLAG_IS_RAINING, snapshot.precipitation == EnvironmentSnapshot.Precipitation.RAIN)
	runtime.set_flag(FLAG_IS_SNOWING, snapshot.is_snowing())
	runtime.set_flag(FLAG_IS_NIGHT, snapshot.is_night())
	for flag: StringName in _season_flags:
		runtime.set_flag(flag, flag == season_flag(snapshot.season))


static func season_flag(season: StringName) -> StringName:
	return StringName(FLAG_SEASON_PREFIX + String(season))


## One boolean per season the climate declares, plus the scalar readings. Seasons
## are flags rather than one string flag because the rule format has booleans and
## counters and deliberately nothing else (`map_editor.md` §10.2).
##
## They are registered on the **runtime**, never appended to the map's scenario:
## the scenario belongs to the document, and writing `env.` flags into it would
## persist the environment's vocabulary into `map.json` the first time an author
## saved after a test run.
func _declare_flags() -> void:
	_season_flags.clear()
	for season_id: StringName in director.season_ids():
		var flag := season_flag(season_id)
		_season_flags.append(flag)
		runtime.register_flag(MapFlagDef.create(flag, MapFlagDef.TYPE_BOOL))
	for flag: StringName in [FLAG_IS_RAINING, FLAG_IS_SNOWING, FLAG_IS_NIGHT]:
		runtime.register_flag(MapFlagDef.create(flag, MapFlagDef.TYPE_BOOL))
	for flag: StringName in [FLAG_DAY_OF_YEAR, FLAG_MINUTE_OF_DAY, FLAG_TEMPERATURE]:
		runtime.register_flag(MapFlagDef.create(flag, MapFlagDef.TYPE_INT))


# --- Actions -------------------------------------------------------------------

func _on_set_time(action: Dictionary, _scenario: MapScenarioRuntime, _payload: Dictionary) -> void:
	director.set_time_of_day(int(action.get("minute", _minute_from_clock(action))))


func _on_set_day(action: Dictionary, _scenario: MapScenarioRuntime, _payload: Dictionary) -> void:
	director.set_day_of_year(int(action.get("day", director.day_of_year())))


func _on_skip(action: Dictionary, _scenario: MapScenarioRuntime, _payload: Dictionary) -> void:
	director.skip_minutes(float(action.get("minutes", 0.0)))


func _on_set_weather(action: Dictionary, _scenario: MapScenarioRuntime, _payload: Dictionary) -> void:
	var pattern := StringName(action.get("pattern", ""))
	if pattern.is_empty():
		return
	var transition := float(action.get("transition", EnvironmentDirector.DEFAULT_TRANSITION_SECONDS))
	if bool(action.get("hold", true)):
		director.pin_pattern(pattern, transition)
	else:
		director.set_pattern(pattern)


func _on_force_precipitation(action: Dictionary, _scenario: MapScenarioRuntime, _payload: Dictionary) -> void:
	director.force_precipitation(
		float(action.get("minutes", 240.0)),
		float(action.get("transition", EnvironmentDirector.DEFAULT_TRANSITION_SECONDS)))


func _on_stop_precipitation(action: Dictionary, _scenario: MapScenarioRuntime, _payload: Dictionary) -> void:
	director.stop_precipitation(
		float(action.get("transition", EnvironmentDirector.DEFAULT_TRANSITION_SECONDS)))


func _on_set_time_scale(action: Dictionary, _scenario: MapScenarioRuntime, _payload: Dictionary) -> void:
	director.set_time_scale(float(action.get("scale", 1.0)))


func _on_release(action: Dictionary, _scenario: MapScenarioRuntime, _payload: Dictionary) -> void:
	director.release(float(action.get("transition", EnvironmentDirector.DEFAULT_TRANSITION_SECONDS)))


## `{"hour": 19, "minute": 40}` is what an author writes; `minute` alone is what a
## tool generates. Both mean the same instant.
func _minute_from_clock(action: Dictionary) -> int:
	return int(action.get("hour", 0)) * 60 + int(action.get("minute_of_hour", 0))


# --- Moments -------------------------------------------------------------------

func _on_day_rolled(_day_of_session: int, pattern: StringName) -> void:
	publish_state(director.snapshot())
	runtime.publish(TRIGGER_DAY_STARTED, {"pattern": pattern})


func _on_season_changed(season: StringName) -> void:
	publish_state(director.snapshot())
	runtime.publish(TRIGGER_SEASON_CHANGED, {"season": season})


func _on_weather_changed(pattern: StringName) -> void:
	runtime.publish(TRIGGER_WEATHER_CHANGED, {"pattern": pattern})
