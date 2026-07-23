class_name SaveData
extends RefCounted

## Typed record and JSON helper for game state serialization and deserialization.

## Bump this only alongside an explicit migration in `from_dict`.
const VERSION := 2

var version: int = VERSION
var timestamp: int = 0
var game_version: String = "0.4.7"

var settlement_state: Dictionary = {}
var clock_state: Dictionary = {}
var world_state: Dictionary = {}
var buildings_state: Array = []
var construction_sites_state: Array = []
var citizens_state: Array = []
var resource_piles_state: Array = []
var camera_state: Dictionary = {}


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


func to_dict() -> Dictionary:
	return {
		"version": version,
		"timestamp": timestamp,
		"game_version": game_version,
		"settlement": settlement_state.duplicate(true),
		"clock": clock_state.duplicate(true),
		"world": world_state.duplicate(true),
		"buildings": buildings_state.duplicate(true),
		"construction_sites": construction_sites_state.duplicate(true),
		"citizens": citizens_state.duplicate(true),
		"resource_piles": resource_piles_state.duplicate(true),
		"camera": camera_state.duplicate(true)
	}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty() or not data.has("version"):
		return false
	version = int(data.get("version", 1))
	if version < 1 or version > VERSION:
		push_error("SaveData: Unsupported save format version: " + str(version))
		return false
	timestamp = int(data.get("timestamp", 0))
	game_version = str(data.get("game_version", "0.4.7"))
	
	if not _is_dictionary_field(data, "settlement") or not _is_dictionary_field(data, "clock") or not _is_dictionary_field(data, "world"):
		push_error("SaveData: Invalid save root schema")
		return false
	if not _is_array_field(data, "buildings") or not _is_array_field(data, "construction_sites") or not _is_array_field(data, "citizens") or not _is_array_field(data, "resource_piles"):
		push_error("SaveData: Invalid save collection schema")
		return false
	settlement_state = (data.get("settlement") as Dictionary).duplicate(true)
	clock_state = (data.get("clock") as Dictionary).duplicate(true)
	world_state = (data.get("world") as Dictionary).duplicate(true)
	buildings_state = (data.get("buildings") as Array).duplicate(true)
	construction_sites_state = (data.get("construction_sites") as Array).duplicate(true)
	citizens_state = (data.get("citizens") as Array).duplicate(true)
	resource_piles_state = (data.get("resource_piles") as Array).duplicate(true)
	camera_state = (data.get("camera", {}) as Dictionary).duplicate(true) if data.get("camera", {}) is Dictionary else {}
	if version == 1:
		_migrate_v1_to_v2()
	version = VERSION
	return true


func _is_dictionary_field(data: Dictionary, key: String) -> bool:
	return data.has(key) and data.get(key) is Dictionary


func _is_array_field(data: Dictionary, key: String) -> bool:
	return data.has(key) and data.get(key) is Array


func _migrate_v1_to_v2() -> void:
	## v1 piles stored one resource per entry. Keep old saves loadable.
	for index in resource_piles_state.size():
		var pile: Variant = resource_piles_state[index]
		if pile is Dictionary and pile.has("resource_id"):
			resource_piles_state[index] = {
				"resources": {str(pile.get("resource_id", "")): int(pile.get("amount", 0))},
				"position": pile.get("position", {}),
				"is_backpack": false,
			}


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
	
	var json_string := JSON.stringify(to_dict(), "  ")
	file.store_string(json_string)
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
