class_name MapStart
extends RefCounted

## The conditions a session begins in (design_docs/engine/map_editor.md §7).
##
## World fields are game-neutral. Gameplay-specific constraints and defaults are
## keyed by their owning module in `module_settings`. `day_of_year` and `latitude` have no
## consumer yet — season and daylight belong to terrain phase 4c — but they are
## declared now on purpose: adding them later would mean raising `format_version`
## on every map already authored (§7).
##
## Minute of day the settlement clock starts at; 480 = 08:00, the current default.
const DEFAULT_TIME_OF_DAY := 480

## Visual world style; `generic` is the stable fallback for old maps.
var style: StringName = &"generic"
var day_of_year := 120
var latitude := 54.0
var time_of_day := DEFAULT_TIME_OF_DAY
var weather_preset: StringName = &"clear"
var module_settings: Dictionary = {}
## The authored game that interprets this map. It replaces map-owned mode and
## system switches as the session-composition boundary; old maps without it
## retain the generic showcase so they remain testable without settlement data.
var game_definition: StringName = &"core:world_showcase"


static func from_dict(source: Dictionary) -> MapStart:
	var start := MapStart.new()
	start.style = StringName(source.get("style", start.style))
	start.day_of_year = clampi(int(source.get("day_of_year", start.day_of_year)), 1, 365)
	start.latitude = clampf(float(source.get("latitude", start.latitude)), -90.0, 90.0)
	start.time_of_day = clampi(int(source.get("time_of_day", start.time_of_day)), 0, 1439)
	start.weather_preset = StringName(source.get("weather_preset", start.weather_preset))
	start.game_definition = StringName(source.get("game_definition", start.game_definition))
	var authored_settings: Variant = source.get("module_settings", {})
	if authored_settings is Dictionary:
		start.module_settings = (authored_settings as Dictionary).duplicate(true)
	return start


func to_dict() -> Dictionary:
	return {
		"style": String(style),
		"day_of_year": day_of_year,
		"latitude": latitude,
		"time_of_day": time_of_day,
		"weather_preset": String(weather_preset),
		"game_definition": String(game_definition),
		"module_settings": module_settings.duplicate(true),
	}


func module_settings_for(module_id: StringName) -> Dictionary:
	var value: Variant = module_settings.get(module_id, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
