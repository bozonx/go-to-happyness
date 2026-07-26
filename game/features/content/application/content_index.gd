class_name ContentIndex
extends RefCounted

const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")
const ContentEntryScript = preload("res://game/features/content/domain/content_entry.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")

const BUILTIN_BLUEPRINTS := "res://game/features/buildings/data/blueprints"
const PLAYER_BLUEPRINTS := "user://custom_buildings"
const BUILTIN_MAPS := "res://game/features/world/data/maps"
const PLAYER_MAPS := "user://custom_maps"
const BLUEPRINT_SUFFIX := ".gdbuilding.json"
const MAP_SUFFIX := ".gdmap"

var entries: Dictionary = {}
var errors: Array[String] = []

func rebuild() -> void:
	entries.clear()
	errors.clear()
	_index_blueprints(BUILTIN_BLUEPRINTS, ContentIdScript.SOURCE_BUILTIN)
	_index_blueprints(PLAYER_BLUEPRINTS, ContentIdScript.SOURCE_PLAYER)
	_index_maps(BUILTIN_MAPS, ContentIdScript.SOURCE_BUILTIN)
	_index_maps(PLAYER_MAPS, ContentIdScript.SOURCE_PLAYER)

func get_entry(key: StringName) -> ContentEntryScript:
	return entries.get(key) as ContentEntryScript

func blueprint_entries() -> Array[ContentEntryScript]:
	return _entries_of(&"blueprint")

func map_entries() -> Array[ContentEntryScript]:
	return _entries_of(&"map")

func _entries_of(content_type: StringName) -> Array[ContentEntryScript]:
	var result: Array[ContentEntryScript] = []
	for key in entries:
		var entry := entries[key] as ContentEntryScript
		if entry.content_type == content_type:
			result.append(entry)
	result.sort_custom(func(a: ContentEntryScript, b: ContentEntryScript): return String(a.runtime_key) < String(b.runtime_key))
	return result

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
		var entry := ContentEntryScript.new(source, id, &"map", package_path)
		entry.runtime_key = ContentIdScript.runtime_key(source, id)
		entry.kind = StringName(parsed.get("kind", "map"))
		entry.name = String(parsed.get("name", id))
		entry.metadata = parsed.duplicate(true)
		_register(entry)

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
