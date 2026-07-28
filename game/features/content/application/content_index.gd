class_name ContentIndex
extends RefCounted

const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")
const ContentEntryScript = preload("res://game/features/content/domain/content_entry.gd")
const ContentPackScript = preload("res://game/features/content/domain/content_pack.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")

const BUILTIN_ROOT := "res://game/content"
const LOCAL_ROOT := "user://content/local"
const INSTALLED_ROOT := "user://content/installed"
const LEGACY_BLUEPRINTS := "user://custom_buildings"
const BLUEPRINT_SUFFIX := ".gdbuilding.json"
const MAP_SUFFIX := ".gdmap"
const GAME_SUFFIX := ".gdgame.json"

var entries: Dictionary = {}
var errors: Array[String] = []
var packs: Array = []

func rebuild() -> void:
	entries.clear()
	errors.clear()
	packs.clear()
	_migrate_legacy_player_content()
	_index_pack_roots(BUILTIN_ROOT, ContentIdScript.SOURCE_CORE)
	_index_local_pack()
	_index_pack_roots(INSTALLED_ROOT, ContentIdScript.SOURCE_INSTALLED)


func content_packs() -> Array:
	return packs.duplicate()

func get_entry(key: StringName) -> ContentEntryScript:
	return entries.get(key) as ContentEntryScript

func blueprint_entries() -> Array[ContentEntryScript]:
	return _entries_of(&"blueprint")

func map_entries() -> Array[ContentEntryScript]:
	return _entries_of(&"map")

func prefab_entries() -> Array[ContentEntryScript]:
	return _entries_of(&"prefab")

func game_entries() -> Array[ContentEntryScript]:
	return _entries_of(&"game")

func _entries_of(content_type: StringName) -> Array[ContentEntryScript]:
	var result: Array[ContentEntryScript] = []
	for key in entries:
		var entry := entries[key] as ContentEntryScript
		if entry.content_type == content_type:
			result.append(entry)
	result.sort_custom(func(a: ContentEntryScript, b: ContentEntryScript): return String(a.runtime_key) < String(b.runtime_key))
	return result

func _index_pack_roots(root: String, source_kind: StringName) -> void:
	if not DirAccess.dir_exists_absolute(root):
		return
	for directory in DirAccess.get_directories_at(root):
		var root_path := root.path_join(directory)
		var source := StringName(directory) if source_kind == ContentIdScript.SOURCE_CORE else StringName("pack:" + directory)
		_index_pack(root_path, source)


func _index_local_pack() -> void:
	if not DirAccess.dir_exists_absolute(LOCAL_ROOT):
		return
	var local := ContentPackScript.new()
	local.id = &"local"
	local.name = "Локальный контент"
	local.root_path = LOCAL_ROOT
	local.source = ContentIdScript.SOURCE_LOCAL
	packs.append(local)
	_index_blueprints(LOCAL_ROOT.path_join("buildings"), ContentIdScript.SOURCE_LOCAL)
	_index_maps(LOCAL_ROOT.path_join("maps"), ContentIdScript.SOURCE_LOCAL)
	_index_maps(LOCAL_ROOT.path_join("prefabs"), ContentIdScript.SOURCE_LOCAL)
	_index_games(LOCAL_ROOT.path_join("games"), ContentIdScript.SOURCE_LOCAL)


func _index_pack(root: String, source: StringName) -> void:
	var metadata_path := root.path_join("pack.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not (parsed is Dictionary):
		errors.append("Некорректный pack.json: %s" % metadata_path)
		return
	var pack := ContentPackScript.new()
	if not pack.read_from_dict(parsed, root, source):
		errors.append("Некорректные метаданные пака: %s" % metadata_path)
		return
	if source_kind_is_core(source) and pack.id != StringName(String(source)):
		errors.append("id встроенного пака не совпадает с папкой: %s" % metadata_path)
		return
	packs.append(pack)
	_index_blueprints(root.path_join("buildings"), source)
	_index_maps(root.path_join("maps"), source)
	_index_maps(root.path_join("prefabs"), source)
	_index_games(root.path_join("games"), source)


static func source_kind_is_core(source: StringName) -> bool:
	return not String(source).begins_with("pack:")


func _index_blueprints(root: String, source: StringName) -> void:
	for path in _files_recursively(root, BLUEPRINT_SUFFIX):
		var blueprint := BuildingBlueprintScript.from_json(FileAccess.get_file_as_string(path))
		if blueprint == null:
			errors.append("Некорректный чертёж: %s" % path)
			continue
		var entry := ContentEntryScript.new(source, blueprint.id, &"blueprint", path)
		entry.runtime_key = ContentIdScript.runtime_key(source, blueprint.id)
		entry.kind = blueprint.kind
		entry.role = blueprint.role
		entry.era = blueprint.era
		entry.style = blueprint.style
		entry.name = blueprint.name
		entry.metadata = {"pack": _pack_id_for(source)}
		_register(entry)

func _index_maps(root: String, source: StringName) -> void:
	if not DirAccess.dir_exists_absolute(root):
		return
	for package_path in _directories_recursively(root, MAP_SUFFIX):
		var json_path := package_path.path_join("map.json")
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if not (parsed is Dictionary):
			errors.append("Некорректная карта: %s" % package_path)
			continue
		var id := StringName(parsed.get("id", package_path.get_file().trim_suffix(MAP_SUFFIX)))
		if String(id).is_empty():
			errors.append("У карты нет id: %s" % package_path)
			continue
		var kind := StringName(parsed.get("kind", "map"))
		if kind not in [&"map", &"prefab"]:
			errors.append("Неизвестный kind карты: %s" % package_path)
			continue
		var entry := ContentEntryScript.new(source, id, kind, package_path)
		entry.runtime_key = ContentIdScript.runtime_key(source, id)
		entry.kind = kind
		entry.name = String(parsed.get("name", id))
		entry.metadata = parsed.duplicate(true)
		_register(entry)


func _index_games(root: String, source: StringName) -> void:
	for path in _files_recursively(root, GAME_SUFFIX):
		var definition := GameDefinition.load_from_file(path)
		if definition == null:
			errors.append("Некорректное описание игры: %s" % path)
			continue
		var entry := ContentEntryScript.new(source, definition.id, &"game", path)
		entry.runtime_key = ContentIdScript.runtime_key(source, definition.id)
		entry.name = definition.name
		entry.metadata = {
			"pack": _pack_id_for(source),
			"modules": definition.module_ids.map(func(module_id: StringName) -> String: return String(module_id)),
			"default_map": String(definition.default_map),
		}
		_register(entry)


func _pack_id_for(source: StringName) -> StringName:
	for pack in packs:
		if pack.source == source:
			return pack.id
	return &""

func _register(entry: ContentEntryScript) -> void:
	if entries.has(entry.runtime_key):
		errors.append("Дубликат content id %s: %s" % [entry.runtime_key, entry.path])
		return
	entries[entry.runtime_key] = entry


## One-time, copy-then-remove migration.  It only touches the two old player
## folders and leaves a failed move intact, so interrupted first launch remains
## recoverable. Built-in files are intentionally never migrated here: the repo
## owns their relocation and exported builds ship the new layout directly.
func _migrate_legacy_player_content() -> void:
	_migrate_legacy_directory(LEGACY_BLUEPRINTS, LOCAL_ROOT.path_join("buildings"))


static func _migrate_legacy_directory(old_root: String, new_root: String) -> void:
	if not DirAccess.dir_exists_absolute(old_root):
		return
	if DirAccess.make_dir_recursive_absolute(new_root) != OK:
		return
	var old_dir := DirAccess.open(old_root)
	if old_dir == null:
		return
	for file_name in old_dir.get_files():
		var old_path := old_root.path_join(file_name)
		var new_path := new_root.path_join(file_name)
		if not FileAccess.file_exists(new_path) and DirAccess.rename_absolute(old_path, new_path) != OK:
			push_warning("[content] не удалось перенести %s" % old_path)
	for directory in old_dir.get_directories():
		var old_path := old_root.path_join(directory)
		var new_path := new_root.path_join(directory)
		if not DirAccess.dir_exists_absolute(new_path) and DirAccess.rename_absolute(old_path, new_path) != OK:
			push_warning("[content] не удалось перенести %s" % old_path)

static func _files_recursively(root: String, suffix: String) -> Array[String]:
	var result: Array[String] = []
	_collect_files(root, suffix, result)
	result.sort()
	return result

static func _collect_files(root: String, suffix: String, result: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(root):
		return
	for file_name in DirAccess.get_files_at(root):
		if file_name.ends_with(suffix): result.append(root.path_join(file_name))
	for directory in DirAccess.get_directories_at(root):
		_collect_files(root.path_join(directory), suffix, result)

static func _directories_recursively(root: String, suffix: String) -> Array[String]:
	var result: Array[String] = []
	_collect_directories(root, suffix, result)
	result.sort()
	return result

static func _collect_directories(root: String, suffix: String, result: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(root): return
	for directory in DirAccess.get_directories_at(root):
		var path := root.path_join(directory)
		if directory.ends_with(suffix): result.append(path)
		else: _collect_directories(path, suffix, result)
