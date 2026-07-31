class_name BlueprintRepository
extends RefCounted

## Persists `BuildingBlueprint` records as `.gdbuilding.json` files.
##
## Reading and writing are deliberately asymmetric (content_packaging.md §6.4):
## **every source can be opened, only one can be written.** Dev mode writes the
## core pack, player mode the selected project pack. Taking a shipped building as a
## starting point is the most common first step an author takes, so the open list
## must show it; where the result lands is decided by the mode, not by the file.
##
## Save/load is the only place the editor touches the filesystem.

const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const ContentRevisionScript = preload("res://game/features/content/domain/content_revision.gd")
const ContentIndexScript = preload("res://game/features/content/application/content_index.gd")
const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")

## Canonical, feature-local blueprint folder. The game's BuildingBlueprintLibrary
## also reads from here, so dev edits are exactly what ships in-game.
const DEV_DIR := "res://game/content/core/buildings"

var dev_mode: bool = false
var project_root := ""
var project_source: StringName = &""
## Read by the editor after listing, so duplicate ids are actionable instead of
## silently selecting whichever recursive traversal happened to win.
var last_errors: Array[String] = []


func _init(p_dev_mode: bool = false, p_project_root := "", p_project_source: StringName = &"") -> void:
	# Gated here rather than in the UI: a forgotten @export in the scene must not
	# turn into a write that never happened. `res://` is a read-only `.pck` once
	# exported (content_packaging.md §9).
	dev_mode = p_dev_mode and OS.has_feature("editor")
	project_root = p_project_root
	project_source = p_project_source


func base_dir() -> String:
	if not project_root.is_empty():
		return project_root.path_join("buildings")
	return DEV_DIR if dev_mode else ""


## The source name this mode writes under, in runtime-key terms.
func target_source() -> StringName:
	if not project_source.is_empty():
		return project_source
	return ContentIdScript.SOURCE_CORE if dev_mode else &""


func file_path_for(blueprint_id: StringName) -> String:
	return "%s/%s.%s" % [base_dir(), ContentIdScript.normalize_id(String(blueprint_id)),
		BuildingBlueprintScript.FILE_EXTENSION]


## Whether this mode may write `path`. A player editing a shipped blueprint gets
## `false` here, which is what detaches the document (§6.4) rather than failing
## the save at the last moment.
func can_write(path: String) -> bool:
	if path.is_empty():
		return false
	return not base_dir().is_empty() and path.begins_with(base_dir() + "/")


## Returns { ok: bool, path: String, error: String }.
##
## `path` empty means "the canonical path for this id in the writable source" —
## the case of a first save or a Save As. A non-empty `path` is honoured verbatim
## so a file living in a subfolder is written back into it instead of being
## duplicated at the source root.
func save(blueprint: BuildingBlueprintScript, path: String = "") -> Dictionary:
	if blueprint.role == &"new_building":
		blueprint.role = blueprint.id
	blueprint.recalculate_construction_cost()
	# Checked before the generic validator so the author gets the one message that
	# tells them what to do, instead of an English rule about the alphabet.
	if not ContentIdScript.is_valid_id(String(blueprint.id)):
		return {"ok": false, "path": "", "error":
			"ID здания может содержать только латинские строчные буквы, цифры, «_» и «-». Сейчас: «%s»"
			% blueprint.id}
	var validation_errors := blueprint.validation_errors()
	if not validation_errors.is_empty():
		return {"ok": false, "path": "", "error": "\n".join(validation_errors)}
	var target := path if not path.is_empty() else file_path_for(blueprint.id)
	if not can_write(target):
		return {"ok": false, "path": target, "error": "Этот файл доступен только для чтения: %s" % target}
	# Stamped here rather than in `to_dict()`: the revision must change when the
	# file on disk changes, not when the editor happens to serialize a preview.
	blueprint.revision = ContentRevisionScript.new_stamp()
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
		return {"ok": false, "path": target, "error": "Не удалось создать папку: %s" % target.get_base_dir()}
	var temporary_path := target + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": target, "error": "Не удалось открыть временный файл: %s" % error_string(FileAccess.get_open_error())}
	file.store_string(blueprint.to_json())
	file.flush()
	file.close()
	var rename_error := DirAccess.rename_absolute(temporary_path, target)
	if rename_error != OK:
		return {"ok": false, "path": target, "error": "Не удалось завершить сохранение: %s" % error_string(rename_error)}
	ContentIndexScript.invalidate()
	return {"ok": true, "path": target, "error": ""}


func load_blueprint(path: String) -> BuildingBlueprintScript:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return BuildingBlueprintScript.from_json(text)


## Every blueprint the author may open, from every source, as
## { id, name, path, source, key, writable } dictionaries. Writable ones come
## first: they are what the author is usually looking for, and the rest are
## starting points.
func list_blueprints() -> Array:
	var out: Array = []
	last_errors.clear()
	var index := ContentIndexScript.shared()
	last_errors.append_array(index.errors)
	for entry in index.blueprint_entries():
		out.append({
			"id": entry.id,
			"name": entry.name if not entry.name.is_empty() else String(entry.id),
			"path": entry.path,
			"source": entry.source,
			"key": entry.runtime_key,
			"writable": can_write(entry.path),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["writable"] != b["writable"]:
			return a["writable"]
		return String(a["key"]) < String(b["key"]))
	return out
