class_name EntityArchetypeCatalog
extends RefCounted

## Archetypes supplied by content packs, never by the engine
## (design_docs/engine/map_fill_mode.md §4, §14.1).
##
## Pack file layout — one file per archetype, mirroring blueprints:
## `<pack>/archetypes/<name>.gdarchetype.json`. Ids are namespaced with the pack id
## on load (`core:campfire`), so two packs may ship an archetype of the same name
## without colliding — the same rule `ZoneFunctionCatalog` already follows.
##
## Nothing here knows a component by name. The catalog loads, namespaces and
## resolves; what a component *does* is the business of the module that executes
## it. That is what will let the future archetype editor (§14.1) add a mechanic
## without a commit in GDScript.

const PACK_ROOTS: Array[String] = [
	"res://game/content", "user://content/projects", "user://content/installed",
]
const ARCHETYPE_DIR := "archetypes"

static var _archetypes: Dictionary = {}
static var _loaded: bool = false
## Populated on load so a broken pack surfaces in the editor instead of silently
## dropping half its archetypes.
static var load_errors: Array[String] = []


static func reload() -> void:
	_archetypes.clear()
	load_errors.clear()
	_loaded = false
	_ensure_loaded()


static func all() -> Array[EntityArchetype]:
	_ensure_loaded()
	var result: Array[EntityArchetype] = []
	for key: StringName in _archetypes:
		result.append(_archetypes[key])
	result.sort_custom(func(a: EntityArchetype, b: EntityArchetype) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return result


static func get_archetype(archetype_id: StringName) -> EntityArchetype:
	_ensure_loaded()
	return _archetypes.get(archetype_id, null)


static func has_archetype(archetype_id: StringName) -> bool:
	_ensure_loaded()
	return _archetypes.has(archetype_id)


## Archetypes of one content class (§4.2) — the palette of the fill mode groups by
## this, because a pebble, a fellable tree and a merchant are placed by different
## tools.
static func of_class(content_class: StringName) -> Array[EntityArchetype]:
	var result: Array[EntityArchetype] = []
	for archetype: EntityArchetype in all():
		if archetype.content_class == content_class:
			result.append(archetype)
	return result


static func of_category(category: StringName) -> Array[EntityArchetype]:
	var result: Array[EntityArchetype] = []
	for archetype: EntityArchetype in all():
		if archetype.category == category:
			result.append(archetype)
	return result


static func of_tag(tag: StringName) -> Array[EntityArchetype]:
	var result: Array[EntityArchetype] = []
	for archetype: EntityArchetype in all():
		if tag in archetype.tags:
			result.append(archetype)
	return result


## The asset an archetype is drawn with, or null when the pack that owns it is not
## installed. A missing asset is **not** an error (§11): a map shared without its
## pack must still open, with a placeholder in place of the model.
static func asset_of(archetype_id: StringName) -> WorldAssetDef:
	var archetype := get_archetype(archetype_id)
	if archetype == null:
		return null
	return WorldAssetCatalog.get_asset(archetype.asset_id)


## Pack that declared the archetype — shown in the editor so an author can see
## that "spruce" comes from content, not from the engine.
static func pack_of(archetype_id: StringName) -> StringName:
	var qualified := String(archetype_id)
	var separator := qualified.find(":")
	return StringName(qualified.substr(0, separator)) if separator > 0 else &""


static func qualified_id(pack_id: StringName, local_id: StringName) -> StringName:
	return StringName("%s:%s" % [pack_id, local_id])


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for root: String in PACK_ROOTS:
		if not DirAccess.dir_exists_absolute(root):
			continue
		for pack_dir: String in DirAccess.get_directories_at(root):
			_load_pack(root.path_join(pack_dir), StringName(pack_dir))


static func _load_pack(pack_root: String, pack_id: StringName) -> void:
	var root := pack_root.path_join(ARCHETYPE_DIR)
	if not DirAccess.dir_exists_absolute(root):
		return
	var file_names := DirAccess.get_files_at(root)
	# Sorted so a pack loads in the same order on every machine: two archetypes
	# colliding must produce the same error, not a different one per filesystem.
	file_names.sort()
	for file_name: String in file_names:
		if not file_name.ends_with(EntityArchetype.FILE_SUFFIX):
			continue
		var path := root.path_join(file_name)
		var archetype := EntityArchetype.from_json(FileAccess.get_file_as_string(path))
		if archetype == null:
			load_errors.append("Некорректный архетип: %s" % path)
			continue
		_register(archetype, pack_id, path)


static func _register(
	archetype: EntityArchetype,
	pack_id: StringName,
	path: String
) -> void:
	archetype.id = qualified_id(pack_id, archetype.id)
	if _archetypes.has(archetype.id):
		load_errors.append("Дубликат архетипа %s: %s" % [archetype.id, path])
		return
	_archetypes[archetype.id] = archetype
