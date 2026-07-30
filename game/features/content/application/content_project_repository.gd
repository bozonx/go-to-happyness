class_name ContentProjectRepository
extends RefCounted

## Writable authored packs. Player projects live in user://; dev mode exposes
## the shipped packs in res:// through the same contract.

const PLAYER_ROOT := "user://content/projects"
const DEV_ROOT := "res://game/content"

var dev_mode := false
var last_error := ""


func _init(p_dev_mode := false) -> void:
	dev_mode = p_dev_mode and OS.has_feature("editor")


func list_projects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var root := DEV_ROOT if dev_mode else PLAYER_ROOT
	if not DirAccess.dir_exists_absolute(root):
		return result
	for directory: String in DirAccess.get_directories_at(root):
		var project_root := root.path_join(directory)
		var pack := load_pack(project_root)
		if pack == null:
			continue
		result.append({
			"root": project_root,
			"folder": directory,
			"id": pack.id,
			"name": pack.name,
			"author_id": pack.author_id,
			"author_name": pack.author_name,
			"source": StringName(pack.id) if dev_mode else source_for(pack),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.name) < String(b.name))
	return result


func create_project(author_id: StringName, pack_id: StringName, display_name: String, author_name: String) -> Dictionary:
	last_error = ""
	if dev_mode:
		last_error = "В dev mode новый встроенный pack создаётся в репозитории явно."
		return {}
	if not ContentId.is_valid_id(String(author_id)) or not ContentId.is_valid_id(String(pack_id)):
		last_error = "author_id и pack id должны быть стабильными латинскими идентификаторами"
		return {}
	var folder := "%s.%s" % [author_id, pack_id]
	var root := PLAYER_ROOT.path_join(folder)
	if DirAccess.dir_exists_absolute(root):
		last_error = "Проект уже существует: %s" % folder
		return {}
	for subdir: String in ["games", "maps", "buildings", "entities", "prefabs", "assets"]:
		if DirAccess.make_dir_recursive_absolute(root.path_join(subdir)) != OK:
			last_error = "Не удалось создать %s" % root.path_join(subdir)
			return {}
	var pack := ContentPack.new()
	pack.id = pack_id
	pack.name = display_name if not display_name.strip_edges().is_empty() else String(pack_id)
	pack.author_id = author_id
	pack.author_name = author_name if not author_name.strip_edges().is_empty() else String(author_id)
	pack.version = "0.1.0"
	pack.revision = ContentRevision.new_stamp()
	if not save_pack(pack, root):
		return {}
	return {"root": root, "folder": folder, "id": pack.id, "name": pack.name,
		"author_id": pack.author_id, "author_name": pack.author_name, "source": source_for(pack)}


func load_pack(root: String) -> ContentPack:
	var path := root.path_join("pack.json")
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var pack := ContentPack.new()
	if not parsed is Dictionary or not pack.read_from_dict(parsed, root):
		return null
	return pack


func save_pack(pack: ContentPack, root: String) -> bool:
	last_error = ""
	pack.revision = ContentRevision.new_stamp()
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		last_error = "Не удалось создать папку проекта"
		return false
	var file := FileAccess.open(root.path_join("pack.json"), FileAccess.WRITE)
	if file == null:
		last_error = "Не удалось записать pack.json"
		return false
	file.store_string(JSON.stringify(pack.to_dict(), "  "))
	file.close()
	return true


static func source_for(pack: ContentPack) -> StringName:
	return StringName("pack:%s.%s" % [pack.author_id, pack.id])
