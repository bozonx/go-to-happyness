class_name MapStart
extends RefCounted

## The conditions a session begins in (design_docs/engine/map_start.md).
##
## World fields are game-neutral. Gameplay-specific constraints and defaults are
## keyed by their owning module in `module_settings`, and each section says which
## of the three things it is doing — setting a value, narrowing a range, or
## taking the choice away from the player (§2.5).
##
## `starts` and `default_start` live here rather than at the top level of
## `map.json` because an entrance *is* start data: it names a spawn group, a
## camera and a set of overrides, and every one of those is resolved by the same
## code that resolves the fields beside it. `day_of_year`, `latitude`,
## `time_of_day` and `weather_preset` were declared before anything read them,
## for the reason §7 gave: adding them later would raise `format_version` on
## every map already authored. `WorldSession` reads them now — they are the input
## the environment starts from (`world_environment.md` §15).

## Minute of day the settlement clock starts at; 480 = 08:00, the current default.
const DEFAULT_TIME_OF_DAY := 480

## Visual world style; `generic` is the stable fallback for old maps.
var style: StringName = &"generic"
var day_of_year := 120
var latitude := 54.0
var time_of_day := DEFAULT_TIME_OF_DAY
var weather_preset: StringName = &"clear"
## Climate the world runs on (`world_environment.md` §5). It joins the four
## fields above rather than sitting in a module's settings for the same reason
## they do: season, temperature and day length are world facts, and a shooter map
## has them exactly as a settlement map does.
var climate: StringName = &"temperate"
## `false` freezes the environment: a session begun in `SCRIPTED` and never
## released (§7.1 here, `world_environment.md` §14). Arenas and staged scenes
## want it; ordinary play does not.
var dynamic := true
## `module_id -> ModuleSettingsSection`.
var module_settings: Dictionary = {}
## The authored game that interprets this map. It replaces map-owned mode and
## system switches as the session-composition boundary; old maps without it
## retain the generic showcase so they remain testable without settlement data.
var game_definition: StringName = &"core:world_showcase"
## How this map uses the eras its game declares. Progression is host
## functionality, so the policy sits beside the other world fields rather than
## inside a module's settings: a map narrows or disables it without naming the
## module that happens to advance it.
var progression: ProgressionPolicy = ProgressionPolicy.new()

## The entrances this map offers (§3). A v7 map gains exactly one, `default`.
var starts: Array[MapStartOption] = []
## Which entrance is the one, by id. Deliberately not "the first element" and not
## a `default: true` flag on an element: array order is an editor's business, and
## a flag can be set twice while a reference cannot (§3.3).
var default_start: StringName = &""

## The implicit entrance a map without authored ones is read as (§16). Its id is
## part of the format: a save records which entrance a session began at.
const LEGACY_START_ID := &"default"


static func from_dict(source: Dictionary) -> MapStart:
	var start := MapStart.new()
	start.style = StringName(source.get("style", start.style))
	# The upper bound belongs to the selected climate, whose year is not required
	# to have 365 days. WorldCalendar wraps it after the climate is resolved.
	start.day_of_year = maxi(int(source.get("day_of_year", start.day_of_year)), 1)
	start.latitude = clampf(float(source.get("latitude", start.latitude)), -90.0, 90.0)
	start.time_of_day = clampi(int(source.get("time_of_day", start.time_of_day)), 0, 1439)
	start.weather_preset = StringName(source.get("weather_preset", start.weather_preset))
	start.climate = StringName(source.get("climate", start.climate))
	start.dynamic = bool(source.get("dynamic", start.dynamic))
	start.game_definition = StringName(source.get("game_definition", start.game_definition))
	start.progression = ProgressionPolicy.from_dict(source.get("progression", {}))
	start.module_settings = ModuleSettingsSection.map_from_dict(source.get("module_settings", {}))
	for raw_option: Variant in source.get("starts", []):
		if raw_option is Dictionary:
			var option := MapStartOption.from_dict(raw_option as Dictionary)
			if option.id != &"":
				start.starts.append(option)
	start.default_start = StringName(source.get("default_start", ""))
	return start


func to_dict() -> Dictionary:
	var result := {
		"style": String(style),
		"day_of_year": day_of_year,
		"latitude": latitude,
		"time_of_day": time_of_day,
		"weather_preset": String(weather_preset),
		"climate": String(climate),
		"dynamic": dynamic,
		"game_definition": String(game_definition),
		"progression": progression.to_dict(),
		"module_settings": ModuleSettingsSection.map_to_dict(module_settings),
		"starts": starts.map(func(option: MapStartOption) -> Dictionary: return option.to_dict()),
	}
	if default_start != &"":
		result["default_start"] = String(default_start)
	return result


## The section a module owns, always a section — a module asking for its settings
## on a map that never mentioned it gets an empty one rather than a null check.
func section_for(module_id: StringName) -> ModuleSettingsSection:
	var section: Variant = module_settings.get(module_id, null)
	return section if section is ModuleSettingsSection else ModuleSettingsSection.new()


func set_section(module_id: StringName, section: ModuleSettingsSection) -> void:
	module_settings[module_id] = section


## Plain values a module declared, for readers that do not care who set them.
func module_settings_for(module_id: StringName) -> Dictionary:
	return section_for(module_id).values.duplicate(true)


func start_by_id(option_id: StringName) -> MapStartOption:
	for option: MapStartOption in starts:
		if option.id == option_id:
			return option
	return null


## The entrance a session begins at when nobody chose one (§3.3): the declared
## default, or the only one there is. Several entrances and no `default_start` is
## a warning, not an error — the map launches and the menu is obliged to ask — so
## this still answers with the first, and `MapValidator` reports the omission.
func default_option(definition: StringName = &"") -> MapStartOption:
	var declared := start_by_id(default_start)
	if declared != null and declared.suits_definition(definition):
		return declared
	for option: MapStartOption in starts:
		if option.suits_definition(definition):
			return option
	return null


## Entrances a player may pick for this game (§3.4). Selectability and game
## compatibility are separate questions and both are the menu's to explain.
func selectable_options(definition: StringName = &"") -> Array[MapStartOption]:
	var result: Array[MapStartOption] = []
	for option: MapStartOption in starts:
		if option.selectable and option.suits_definition(definition):
			result.append(option)
	return result
