class_name ContentIndex
extends RefCounted

const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")
const ContentEntryScript = preload("res://game/features/content/domain/content_entry.gd")
const ContentPackScript = preload("res://game/features/content/domain/content_pack.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")

const BUILTIN_ROOT := "res://game/content"
const PROJECTS_ROOT := "user://content/projects"
const INSTALLED_ROOT := "user://content/installed"
const BLUEPRINT_SUFFIX := ".gdbuilding.json"
const MAP_SUFFIX := ".gdmap"
const GAME_SUFFIX := ".gdgame.json"

var entries: Dictionary = {}
var errors: Array[String] = []
var packs: Array = []

## The host keeps exactly one index. Every consumer used to build its own, which
## meant a full parse of every pack per query — three of them for one click in
## the menu — and two indexes could disagree about what exists. Writers call
## `invalidate()`; nobody else needs to think about freshness.
static var _shared: ContentIndex = null


static func shared() -> ContentIndex:
	if _shared == null:
		_shared = ContentIndex.new()
		_shared.rebuild()
	return _shared


## Drops the cached index after content is written or removed. Cheap on purpose:
## the next reader rebuilds, so a writer never has to know who is holding one.
static func invalidate() -> void:
	_shared = null


func rebuild() -> void:
	entries.clear()
	errors.clear()
	packs.clear()
	_index_pack_roots(BUILTIN_ROOT, ContentIdScript.SOURCE_CORE)
	_index_pack_roots(PROJECTS_ROOT, &"project")
	_index_pack_roots(INSTALLED_ROOT, ContentIdScript.SOURCE_INSTALLED)


func content_packs() -> Array:
	return packs.duplicate()


func pack_by_source(source: StringName) -> ContentPackScript:
	for pack in packs:
		if pack.source == source:
			return pack
	return null


func pack_by_id(pack_id: StringName) -> ContentPackScript:
	for pack in packs:
		if pack.id == pack_id:
			return pack
	return null


## Packs the given pack declares in `requires` but which are not installed. A
## missing dependency is why another author's game opens to an empty world, so
## the launch path refuses instead of starting one.
func missing_requirements(source: StringName) -> Array[String]:
	var problems: Array[String] = []
	var pack := pack_by_source(source)
	if pack == null:
		return ["пак %s не найден" % source]
	for requirement: Dictionary in pack.requires:
		if StringName(requirement.get("kind", "pack")) != &"pack":
			continue
		var required_id := StringName(requirement.get("id", ""))
		if required_id.is_empty() or required_id == pack.id:
			continue
		var installed := pack_by_id(required_id)
		if installed == null:
			problems.append("не установлен пак %s" % required_id)
			continue
		var minimum := String(requirement.get("min_version", ""))
		if not minimum.is_empty() and _version_is_older(installed.version, minimum):
			problems.append("паку %s нужна версия %s, установлена %s" % [required_id, minimum, installed.version])
	return problems


## Dotted numeric comparison. Anything non-numeric compares as 0, which keeps a
## hand-written `"1.0"` working without inventing a semver parser.
static func _version_is_older(version: String, minimum: String) -> bool:
	var left := version.split(".")
	var right := minimum.split(".")
	for index in maxi(left.size(), right.size()):
		var left_part := int(left[index]) if index < left.size() else 0
		var right_part := int(right[index]) if index < right.size() else 0
		if left_part != right_part:
			return left_part < right_part
	return false

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


func _index_pack(root: String, source: StringName) -> void:
	var metadata_path := root.path_join("pack.json")
	# A directory without a manifest is not a broken pack, it is not a pack: the
	# content roots also hold ordinary folders. Parsing the empty string here is
	# what used to log an engine-level JSON error per scan.
	if not FileAccess.file_exists(metadata_path):
		return
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
		entry.style = blueprint.style
		entry.variant = blueprint.variant
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
			"description": definition.description,
			"is_builtin": source_kind_is_core(source),
		}
		_register(entry)


func _pack_id_for(source: StringName) -> StringName:
	var pack := pack_by_source(source)
	return pack.id if pack != null else &""

func _register(entry: ContentEntryScript) -> void:
	if entries.has(entry.runtime_key):
		errors.append("Дубликат content id %s: %s" % [entry.runtime_key, entry.path])
		return
	entries[entry.runtime_key] = entry


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
