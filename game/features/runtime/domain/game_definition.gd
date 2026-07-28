class_name GameDefinition
extends RefCounted

## Authored description of one playable game. It contains composition choices,
## never session state or implementation objects.

const FORMAT_VERSION := 1

var id: StringName = &""
var name := ""
var pack_id: StringName = &""
var default_map: StringName = &""
var module_ids: Array[StringName] = []
var clock_id: StringName = &"realtime_pauseable"
var input_profile: StringName = &"rts"
var ui_layout: StringName = &""
var start_parameters: Dictionary = {}


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
	definition.pack_id = StringName(source.get("pack", ""))
	definition.default_map = StringName(source.get("default_map", ""))
	definition.clock_id = StringName(source.get("clock", definition.clock_id))
	definition.input_profile = StringName(source.get("input_profile", definition.input_profile))
	definition.ui_layout = StringName(source.get("ui_layout", ""))
	for raw_id: Variant in source.get("modules", []):
		definition.module_ids.append(StringName(raw_id))
	var start: Variant = source.get("start", {})
	definition.start_parameters = (start as Dictionary).duplicate(true) if start is Dictionary else {}
	if definition.id.is_empty() or definition.pack_id.is_empty() or definition.module_ids.is_empty():
		return null
	return definition
