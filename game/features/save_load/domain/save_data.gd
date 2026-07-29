class_name SaveData
extends RefCounted

## Generic save envelope and JSON helper. The root carries only compatibility
## metadata and sections: `game`, `map`, `engine` headers owned by the host and a
## `modules` dictionary where each participating module owns its section
## (multi_purpose_engine.md §3.5).
##
## SaveData deliberately knows nothing about settlement fields. A v1–v3 save —
## which was a flat settlement blob — is normalized exactly once in `from_dict`:
## the legacy fields are packed into `modules["gth.settlement"]`, the embedded
## `map_ref` is lifted into `map_header`, and the version is bumped to 4. That
## adapter is the single import path for old saves and is not developed further.

## Bump this only alongside an explicit migration in `from_dict`.
##   v2 -> v3: added per-tree `forest` state (older saves load with a pristine forest).
##   v3 -> v4: root became game/map/engine/module sections. The legacy flat fields
##             are migrated into `modules["gth.settlement"]` once, then dropped.
const VERSION := 4

## Read once from the project so a single edit in project.godot propagates here.
static func _project_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

var version: int = VERSION
var timestamp: int = 0
var game_version: String = _project_version()

## Host-owned headers. `game`/`map` identify which pack, definition and world the
## save belongs to; `engine` holds host-scale state (seed, clock model). A module
## never writes here — the coordinator composes these around the module sections.
var game_header: Dictionary = {}
var map_header: Dictionary = {}
var engine_state: Dictionary = {}
## One entry per participating module id; the module owns its section's schema,
## migration and validation. SaveData treats the contents as opaque.
var module_states: Dictionary = {}


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
	var game := game_header.duplicate(true)
	if game.is_empty():
		# A save written without a host header is by construction a legacy
		# settlement save (the only pre-sectioned game). Keep the default so a
		# bare SaveData round-trips, but production writes always set the header.
		game = {"pack": "core", "id": "settlement", "revision": ""}
	return {
		"format_version": VERSION,
		"timestamp": timestamp,
		"game_version": game_version,
		"game": game,
		"map": map_header.duplicate(true),
		"engine": engine_state.duplicate(true),
		"modules": module_states.duplicate(true),
	}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty() or (not data.has("version") and not data.has("format_version")):
		return false
	version = int(data.get("format_version", data.get("version", 1)))
	if version < 1 or version > VERSION:
		return false
	timestamp = int(data.get("timestamp", 0))
	game_version = str(data.get("game_version", _project_version()))
	if version == VERSION:
		return _read_sectioned_v4(data)
	return _migrate_legacy_to_v4(data, version)


func _read_sectioned_v4(data: Dictionary) -> bool:
	if not (data.get("game", {}) is Dictionary) or not (data.get("map", {}) is Dictionary):
		push_error("SaveData: Invalid v4 game/map headers")
		return false
	if not (data.get("engine", {}) is Dictionary) or not (data.get("modules", {}) is Dictionary):
		push_error("SaveData: Invalid v4 engine/modules sections")
		return false
	game_header = (data["game"] as Dictionary).duplicate(true)
	map_header = (data["map"] as Dictionary).duplicate(true)
	engine_state = (data["engine"] as Dictionary).duplicate(true)
	module_states = (data["modules"] as Dictionary).duplicate(true)
	version = VERSION
	return true


## One-time normalization of a flat v1–v3 settlement save into the sectioned v4
## envelope. Every legacy save is a settlement save, so the flat blob becomes the
## `gth.settlement` module section and its embedded `map_ref` is lifted into the
## host `map_header`. This is the only code path that still understands the old
## field names; once no v1–v3 save exists in the wild it is not extended.
func _migrate_legacy_to_v4(data: Dictionary, legacy_version: int) -> bool:
	if not _is_dictionary_field(data, "settlement") or not _is_dictionary_field(data, "clock") or not _is_dictionary_field(data, "world"):
		push_error("SaveData: Invalid legacy save root schema")
		return false
	if not _is_array_field(data, "buildings") or not _is_array_field(data, "construction_sites") or not _is_array_field(data, "citizens") or not _is_array_field(data, "resource_piles"):
		push_error("SaveData: Invalid legacy save collection schema")
		return false
	var settlement_state := (data["settlement"] as Dictionary).duplicate(true)
	var clock_state := (data["clock"] as Dictionary).duplicate(true)
	var world_state := (data["world"] as Dictionary).duplicate(true)
	var buildings_state := (data["buildings"] as Array).duplicate(true)
	var construction_sites_state := (data["construction_sites"] as Array).duplicate(true)
	var citizens_state := (data["citizens"] as Array).duplicate(true)
	var resource_piles_state := (data["resource_piles"] as Array).duplicate(true)
	# Forest and camera are optional: saves predating v3 (or headless) omit them,
	# and a missing forest simply means the regenerated one is left untouched.
	var forest_state := (data.get("forest", []) as Array).duplicate(true) if data.get("forest", []) is Array else []
	var camera_state := (data.get("camera", {}) as Dictionary).duplicate(true) if data.get("camera", {}) is Dictionary else {}
	if legacy_version == 1:
		_migrate_v1_piles(resource_piles_state)

	game_header = {"pack": "core", "id": "settlement", "revision": ""}
	engine_state = {}
	# Lift the embedded map reference into the host header so launch/save routing
	# never needs to reach inside a module section to find the world.
	var map_reference: Variant = world_state.get("map_ref", {})
	if map_reference is Dictionary and not (map_reference as Dictionary).is_empty():
		map_header = (map_reference as Dictionary).duplicate(true)
	module_states = {
		"gth.settlement": {
			"settlement": settlement_state,
			"world": world_state,
			"buildings": buildings_state,
			"construction_sites": construction_sites_state,
			"citizens": citizens_state,
			"resource_piles": resource_piles_state,
			"forest": forest_state,
			"clock": clock_state,
			"camera": camera_state,
		},
	}
	version = VERSION
	return true


func _is_dictionary_field(data: Dictionary, key: String) -> bool:
	return data.has(key) and data.get(key) is Dictionary


func _is_array_field(data: Dictionary, key: String) -> bool:
	return data.has(key) and data.get(key) is Array


## v1 piles stored one resource per entry. Keep old saves loadable.
func _migrate_v1_piles(resource_piles_state: Array) -> void:
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
