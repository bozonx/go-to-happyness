class_name MapStart
extends RefCounted

## The conditions a session begins in (design_docs/engine/map_editor.md §7).
##
## Every field here overrides a `GameLaunchConfig` default; anything the map does
## not state is left to the era config. `day_of_year` and `latitude` have no
## consumer yet — season and daylight belong to terrain phase 4c — but they are
## declared now on purpose: adding them later would mean raising `format_version`
## on every map already authored (§7).
##
## `mode` is what makes the format worth having (§7.1). No game system ever learns
## about "modes": each one is handed its own on/off flag at session start, so a
## shooter map is a settlement map with `settlement_sim` and `construction` off.

const MODE_SETTLEMENT := &"settlement"
const MODE_HERO := &"hero"
const MODE_SQUAD := &"squad"
const MODE_SANDBOX := &"sandbox"

const HERO_CONTROL_NONE := &"none"
const HERO_CONTROL_THIRD_PERSON := &"third_person"
const HERO_CONTROL_FIRST_PERSON := &"first_person"

## Minute of day the settlement clock starts at; 480 = 08:00, the current default.
const DEFAULT_TIME_OF_DAY := 480

var era: StringName = &"tent"
## Visual world style; `generic` is the stable fallback for old maps.
var style: StringName = &"generic"
var day_of_year := 120
var latitude := 54.0
var time_of_day := DEFAULT_TIME_OF_DAY
var weather_preset: StringName = &"clear"
## The authored game that interprets this map. It replaces map-owned mode and
## system switches as the session-composition boundary; old maps without it
## retain the generic showcase so they remain testable without settlement data.
var game_definition: StringName = &"core:world_showcase"

var mode_id: StringName = MODE_SETTLEMENT
## Per-system switches. Only the keys a map states are stored; a system whose flag
## is absent keeps whatever the mode preset gives it.
var systems: Dictionary = {}

## Overrides `GameLaunchConfig`: money, population, resources, equipment. Absent
## keys fall through to the era defaults rather than to zero.
var economy: Dictionary = {}


static func from_dict(source: Dictionary) -> MapStart:
	var start := MapStart.new()
	start.era = StringName(source.get("era", start.era))
	start.style = StringName(source.get("style", start.style))
	start.day_of_year = clampi(int(source.get("day_of_year", start.day_of_year)), 1, 365)
	start.latitude = clampf(float(source.get("latitude", start.latitude)), -90.0, 90.0)
	start.time_of_day = clampi(int(source.get("time_of_day", start.time_of_day)), 0, 1439)
	start.weather_preset = StringName(source.get("weather_preset", start.weather_preset))
	start.game_definition = StringName(source.get("game_definition", start.game_definition))
	var mode: Dictionary = source.get("mode", {})
	start.mode_id = StringName(mode.get("id", start.mode_id))
	start.systems = (mode.get("systems", {}) as Dictionary).duplicate(true)
	start.economy = (source.get("economy", {}) as Dictionary).duplicate(true)
	return start


func to_dict() -> Dictionary:
	return {
		"era": String(era),
		"style": String(style),
		"day_of_year": day_of_year,
		"latitude": latitude,
		"time_of_day": time_of_day,
		"weather_preset": String(weather_preset),
		"game_definition": String(game_definition),
		"mode": {"id": String(mode_id), "systems": systems.duplicate(true)},
		"economy": economy.duplicate(true),
	}


## Whether a named game system runs in this map. Unknown systems default to on for
## `settlement`, which keeps every map authored before a system existed working
## the way it did when it was authored.
func is_system_enabled(system: StringName, fallback := true) -> bool:
	var key := String(system)
	if systems.has(key):
		return bool(systems[key])
	return fallback


func hero_control() -> StringName:
	var value: Variant = systems.get("hero_control", HERO_CONTROL_THIRD_PERSON)
	return StringName(value) if value is String or value is StringName else HERO_CONTROL_NONE
