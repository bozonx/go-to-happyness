class_name GameDefinition
extends RefCounted

## Authored description of one playable game. It contains composition choices,
## never session state or implementation objects.

const FORMAT_VERSION := 1

var id: StringName = &""
var name := ""
## Short human-readable description shown in the game library menu.
var description := ""
## Runtime address from ContentIndex (`core:settlement` or `pack:author.pack/game`).
## It is assigned by the registry, not authored in
## `.gdgame.json`, because an installed pack's source is chosen on install.
var runtime_key: StringName = &""
var pack_id: StringName = &""
var default_map: StringName = &""
var module_ids: Array[StringName] = []
var clock_id: StringName = &"realtime_pauseable"
var input_profile: StringName = &"rts"
var ui_layout: StringName = &""
## Defaults keyed by the module that owns and validates them.
var start_module_parameters: Dictionary = {}
## Declares which start parameters the game wants surfaced in the menu UI.
## Each entry is `{ "id": StringName, "label": String, "type": "era" }`.
## An empty array means the menu shows no game-specific selectors.
var menu_parameters: Array[Dictionary] = []
var progression: GameProgressionDefinition = GameProgressionDefinition.new()


static func load_from_file(path: String) -> GameDefinition:
	if not FileAccess.file_exists(path):
		push_error("GameDefinition: file does not exist: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameDefinition: cannot open: %s" % path)
		return null
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK or not json.data is Dictionary:
		push_error("GameDefinition: invalid JSON: %s" % path)
		return null
	return from_dict(json.data as Dictionary)


static func from_dict(source: Dictionary) -> GameDefinition:
	if int(source.get("format_version", 0)) != FORMAT_VERSION:
		return null
	var definition := GameDefinition.new()
	definition.id = StringName(source.get("id", ""))
	definition.name = String(source.get("name", definition.id))
	definition.description = String(source.get("description", ""))
	definition.pack_id = StringName(source.get("pack", ""))
	definition.default_map = StringName(source.get("default_map", ""))
	definition.clock_id = StringName(source.get("clock", definition.clock_id))
	definition.input_profile = StringName(source.get("input_profile", definition.input_profile))
	definition.ui_layout = StringName(source.get("ui_layout", ""))
	for raw_id: Variant in source.get("modules", []):
		definition.module_ids.append(StringName(raw_id))
	var start: Variant = source.get("start", {})
	if start is Dictionary:
		var modules: Variant = (start as Dictionary).get("modules", {})
		if modules is Dictionary:
			definition.start_module_parameters = (modules as Dictionary).duplicate(true)
	var menu_params_source: Variant = source.get("menu_parameters", [])
	if menu_params_source is Array:
		for raw_param: Variant in menu_params_source:
			if raw_param is Dictionary:
				definition.menu_parameters.append((raw_param as Dictionary).duplicate(true))
	var progression_source: Variant = source.get("progression", {})
	if progression_source is Dictionary:
		definition.progression = GameProgressionDefinition.from_dict(progression_source)
	if definition.id.is_empty() or definition.pack_id.is_empty() or definition.module_ids.is_empty():
		return null
	return definition


func to_dict() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"id": String(id),
		"name": name,
		"description": description,
		"pack": String(pack_id),
		"modules": module_ids.map(func(module_id: StringName) -> String: return String(module_id)),
		"default_map": String(default_map),
		"clock": String(clock_id),
		"input_profile": String(input_profile),
		"ui_layout": String(ui_layout),
		"start": {"modules": start_module_parameters.duplicate(true)},
		"menu_parameters": menu_parameters.duplicate(true),
		"progression": progression.to_dict(),
	}
