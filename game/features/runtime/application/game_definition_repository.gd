class_name GameDefinitionRepository
extends RefCounted

const SUFFIX := ".gdgame.json"

var pack_root := ""
var last_error := ""


func _init(p_pack_root: String) -> void:
	pack_root = p_pack_root


func list_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var games_root := pack_root.path_join("games")
	if not DirAccess.dir_exists_absolute(games_root):
		return result
	for file_name: String in DirAccess.get_files_at(games_root):
		if not file_name.ends_with(SUFFIX):
			continue
		var path := games_root.path_join(file_name)
		var definition := GameDefinition.load_from_file(path)
		if definition != null:
			result.append({"path": path, "id": definition.id, "name": definition.name})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.name) < String(b.name))
	return result


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
	var games_root := pack_root.path_join("games")
	if DirAccess.make_dir_recursive_absolute(games_root) != OK:
		last_error = "Не удалось создать games/"
		return ""
	var target := path if not path.is_empty() else games_root.path_join(String(definition.id) + SUFFIX)
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		last_error = "Не удалось записать %s" % target
		return ""
	file.store_string(JSON.stringify(definition.to_dict(), "  "))
	file.close()
	return target
