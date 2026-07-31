class_name SaveData
extends RefCounted

## Generic save envelope and JSON helper. The root carries only compatibility
## metadata and sections: `game`, `map`, `engine` headers owned by the host and a
## `modules` dictionary where each participating module owns its section
## (multi_purpose_engine.md §3.5).
##
## Each module section is versioned by its owner:
## `modules[<id>] = {"version": int, "data": {...}}`. The host never reads inside
## `data`; it only hands the section to the module together with the version that
## wrote it, so a module can change its own shape without a host release.

const VERSION := 5

## Read once from the project so a single edit in project.godot propagates here.
static func _project_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

var version: int = VERSION
var timestamp: int = 0
var game_version: String = _project_version()

## Host-owned headers. `game`/`map` identify which pack, definition and world the
## save belongs to; `engine` holds host-scale state. A module never writes here —
## the coordinator composes these around the module sections.
var game_header: Dictionary = {}
var map_header: Dictionary = {}
var engine_state: Dictionary = {}
## One entry per participating module id, each `{"version": int, "data": {...}}`.
var module_sections: Dictionary = {}


static func vector3_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


static func dict_to_vector3(d: Dictionary) -> Vector3:
	return Vector3(
		float(d.get("x", 0.0)),
		float(d.get("y", 0.0)),
		float(d.get("z", 0.0))
	)


static func vector2i_to_dict(v: Vector2i) -> Dictionary:
	return {"x": v.x, "y": v.y}


static func dict_to_vector2i(d: Dictionary) -> Vector2i:
	return Vector2i(
		int(d.get("x", 0)),
		int(d.get("y", 0))
	)


func set_module_section(module_id: StringName, section_version: int, data: Dictionary) -> void:
	module_sections[module_id] = {"version": section_version, "data": data.duplicate(true)}


func module_section(module_id: StringName) -> Dictionary:
	var section: Variant = module_sections.get(module_id, {})
	if not section is Dictionary:
		return {}
	var data: Variant = (section as Dictionary).get("data", {})
	return (data as Dictionary).duplicate(true) if data is Dictionary else {}


func module_section_version(module_id: StringName) -> int:
	var section: Variant = module_sections.get(module_id, {})
	return int((section as Dictionary).get("version", 0)) if section is Dictionary else 0


func to_dict() -> Dictionary:
	return {
		"format_version": VERSION,
		"timestamp": timestamp,
		"game_version": game_version,
		"game": game_header.duplicate(true),
		"map": map_header.duplicate(true),
		"engine": engine_state.duplicate(true),
		"modules": module_sections.duplicate(true),
	}


## A save from an older host is not migrated. The envelope is host-owned and its
## shape changes only with the host, so an unreadable version is reported once
## and refused; per-module shape changes are the module's own business.
func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	version = int(data.get("format_version", 0))
	if version != VERSION:
		push_warning("SaveData: несовместимая версия сохранения (%d, требуется %d)" % [version, VERSION])
		return false
	if not (data.get("game", {}) is Dictionary) or not (data.get("map", {}) is Dictionary):
		push_error("SaveData: invalid game/map headers")
		return false
	if not (data.get("engine", {}) is Dictionary) or not (data.get("modules", {}) is Dictionary):
		push_error("SaveData: invalid engine/modules sections")
		return false
	timestamp = int(data.get("timestamp", 0))
	game_version = str(data.get("game_version", _project_version()))
	game_header = (data["game"] as Dictionary).duplicate(true)
	map_header = (data["map"] as Dictionary).duplicate(true)
	engine_state = (data["engine"] as Dictionary).duplicate(true)
	module_sections = (data["modules"] as Dictionary).duplicate(true)
	return true


func save_to_file(path: String) -> bool:
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	timestamp = int(Time.get_unix_time_from_system())
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveData: Failed to open temporary save file: " + path + " error: " + str(FileAccess.get_open_error()))
		return false

	file.store_string(JSON.stringify(to_dict(), "  "))
	file.flush()
	file.close()
	var rename_error := DirAccess.rename_absolute(temporary_path, path)
	if rename_error != OK:
		push_error("SaveData: Failed to finalize save: " + error_string(rename_error))
		return false
	return true


func load_from_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("SaveData: File does not exist: " + path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveData: Failed to open file for reading: " + path)
		return false

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("SaveData: JSON parse error: " + json.get_error_message())
		return false

	if not (json.data is Dictionary):
		push_error("SaveData: Invalid root JSON structure")
		return false

	return from_dict(json.data as Dictionary)
