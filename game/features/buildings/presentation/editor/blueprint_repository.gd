class_name BlueprintRepository
extends RefCounted

## Persists `BuildingBlueprint` records as `.gdbuilding.json` files.
##
## Dev mode writes canonical blueprints under `res://game/features/buildings/data/blueprints/`;
## player mode writes user creations under `user://custom_buildings/`. Save/load is the
## only place the editor touches the filesystem.

const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const ContentRevisionScript = preload("res://game/features/content/domain/content_revision.gd")

## Canonical, feature-local blueprint folder. The game's BuildingBlueprintLibrary
## also reads from here, so dev edits are exactly what ships in-game.
const DEV_DIR := "res://game/features/buildings/data/blueprints"
const PLAYER_DIR := "user://custom_buildings"

var dev_mode: bool = false
## Read by the editor after listing, so duplicate ids are actionable instead of
## silently selecting whichever recursive traversal happened to win.
var last_errors: Array[String] = []


func _init(p_dev_mode: bool = false) -> void:
	dev_mode = p_dev_mode and OS.has_feature("editor")


func base_dir() -> String:
	return DEV_DIR if dev_mode else PLAYER_DIR


func ensure_dir() -> void:
	var dir := base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)


func file_path_for(blueprint_id: StringName) -> String:
	return "%s/%s.%s" % [base_dir(), _sanitize_id(blueprint_id), BuildingBlueprintScript.FILE_EXTENSION]


## Returns { ok: bool, path: String, error: String }.
func save(blueprint: BuildingBlueprintScript) -> Dictionary:
	if blueprint.role == &"new_building":
		blueprint.role = blueprint.id
	blueprint.era = blueprint.category
	blueprint.recalculate_construction_cost()
	var validation_errors := blueprint.validation_errors()
	if not validation_errors.is_empty():
		return {"ok": false, "path": "", "error": "\n".join(validation_errors)}
	# Stamped here rather than in `to_dict()`: the revision must change when the
	# file on disk changes, not when the editor happens to serialize a preview.
	blueprint.revision = ContentRevisionScript.new_stamp()
	ensure_dir()
	var path := file_path_for(blueprint.id)
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": path, "error": "Не удалось открыть временный файл: %s" % error_string(FileAccess.get_open_error())}
	file.store_string(blueprint.to_json())
	file.flush()
	file.close()
	var rename_error := DirAccess.rename_absolute(temporary_path, path)
	if rename_error != OK:
		return {"ok": false, "path": path, "error": "Не удалось завершить сохранение: %s" % error_string(rename_error)}
	return {"ok": true, "path": path, "error": ""}


func load_blueprint(path: String) -> BuildingBlueprintScript:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return BuildingBlueprintScript.from_json(text)


## Lists available blueprint files as { id, name, path } dictionaries.
func list_blueprints() -> Array:
	var out: Array = []
	last_errors.clear()
	var seen_ids: Dictionary = {}
	var dir := base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var suffix := "." + BuildingBlueprintScript.FILE_EXTENSION
	for path in _files_recursively(dir, suffix):
		var bp := load_blueprint(path)
		if bp != null:
			if seen_ids.has(bp.id):
				last_errors.append("Дубликат id '%s': %s и %s" % [bp.id, seen_ids[bp.id], path])
				continue
			seen_ids[bp.id] = path
			out.append({"id": bp.id, "name": bp.name, "path": path})
	return out


static func _files_recursively(root: String, suffix: String) -> Array[String]:
	var result: Array[String] = []
	if not DirAccess.dir_exists_absolute(root):
		return result
	for file_name in DirAccess.get_files_at(root):
		if file_name.ends_with(suffix):
			result.append(root.path_join(file_name))
	for directory in DirAccess.get_directories_at(root):
		result.append_array(_files_recursively(root.path_join(directory), suffix))
	result.sort()
	return result


func _sanitize_id(blueprint_id: StringName) -> String:
	var text := String(blueprint_id).strip_edges().to_lower()
	var safe := ""
	for i in text.length():
		var c := text[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			safe += c
		elif c == " ":
			safe += "_"
	if safe.is_empty():
		safe = "untitled_building"
	return safe
