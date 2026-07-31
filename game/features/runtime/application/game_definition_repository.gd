class_name GameDefinitionRepository
extends RefCounted

## Reads game definitions from every installed pack and writes them into one —
## the project the author is editing (content_packaging.md §6.4). Opening a
## shipped game as a starting point is the normal first step; saving it always
## lands in the author's own pack.

const SUFFIX := ".gdgame.json"

var pack_root := ""
var last_error := ""


func _init(p_pack_root: String) -> void:
	pack_root = p_pack_root


## Every definition the author may open, writable ones first:
## `{ path, id, name, source, key, writable }`.
func list_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in ContentIndex.shared().game_entries():
		result.append({
			"path": entry.path,
			"id": entry.id,
			"name": entry.name,
			"source": entry.source,
			"key": entry.runtime_key,
			"writable": can_write(entry.path),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["writable"] != b["writable"]:
			return a["writable"]
		return String(a["key"]) < String(b["key"]))
	return result


## Whether this editor session owns `path`. A definition opened from anywhere
## else is detached: "Сохранить" writes a copy into the active project instead of
## failing, or silently editing content the player does not own.
func can_write(path: String) -> bool:
	return not pack_root.is_empty() and path.begins_with(pack_root + "/")


func load(path: String) -> GameDefinition:
	return GameDefinition.load_from_file(path)


func save(definition: GameDefinition, path := "") -> String:
	last_error = ""
	if definition == null or not ContentId.is_valid_id(String(definition.id)):
		last_error = "У игры нет корректного id"
		return ""
	var errors := GameModuleRegistry.validate_definition(definition)
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return ""
	var target := path if not path.is_empty() else _default_path(definition.id)
	if not can_write(target):
		last_error = "Этот файл доступен только для чтения: %s" % target
		return ""
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
		last_error = "Не удалось создать games/"
		return ""
	# Stamped on write, like maps and blueprints: the revision answers "is this
	# the same file I loaded", and a save records it beside the game reference.
	definition.revision = ContentRevision.new_stamp()
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		last_error = "Не удалось записать %s" % target
		return ""
	file.store_string(JSON.stringify(definition.to_dict(), "  "))
	file.close()
	ContentIndex.invalidate()
	return target


func _default_path(definition_id: StringName) -> String:
	return pack_root.path_join("games").path_join(String(definition_id) + SUFFIX)
