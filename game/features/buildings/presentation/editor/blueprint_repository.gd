extends RefCounted

## Persists `BuildingBlueprint` records as `.gdbuilding.json` files.
##
## Dev mode writes canonical blueprints under `res://game/features/buildings/data/blueprints/`;
## player mode writes user creations under `user://custom_buildings/`. Save/load is the
## only place the editor touches the filesystem.

const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")

## Canonical, feature-local blueprint folder. The game's BuildingBlueprintLibrary
## also reads from here, so dev edits are exactly what ships in-game.
const DEV_DIR := "res://game/features/buildings/data/blueprints"
const PLAYER_DIR := "user://custom_buildings"

var dev_mode: bool = false


func _init(p_dev_mode: bool = false) -> void:
	dev_mode = p_dev_mode


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
	blueprint.recalculate_construction_cost()
	var validation_errors := blueprint.validation_errors()
	if not validation_errors.is_empty():
		return {"ok": false, "path": "", "error": "\n".join(validation_errors)}
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
	var dir := base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var suffix := "." + BuildingBlueprintScript.FILE_EXTENSION
	for file_name in DirAccess.get_files_at(dir):
		if not file_name.ends_with(suffix):
			continue
		var path := "%s/%s" % [dir, file_name]
		var bp := load_blueprint(path)
		if bp != null:
			out.append({"id": bp.id, "name": bp.name, "path": path})
	return out


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
