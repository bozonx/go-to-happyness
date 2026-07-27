class_name ZoneFunctionCatalog
extends RefCounted

## What an active zone *means* in a game — supplied by content packs, never by
## the engine (design_docs/engine/active_zones.md §2, §8.3).
##
## The engine knows a closed list of zone roles and nothing else. A bakery, an
## inn and a respawn room are all `role: room`; they differ by the `function`
## picked from this catalog and by the properties that function declares. That is
## the whole reason the editors can be handed to players who are not building a
## settlement game: a new mechanic is a new pack entry, not a new enum value in
## the domain and a new control in the editor.
##
## Previously this lived in code as a hardcoded profession list plus a match
## statement mapping zone kinds to required capabilities. Both are gone.
##
## Pack file layout — `<pack>/zone_functions.json`:
## ```json
## {
##   "functions": [
##     {
##       "id": "bakery",
##       "label": "Пекарня",
##       "scope": "area",
##       "roles": ["room"],
##       "requires": ["fire_source"],
##       "properties": [
##         {"key": "profession", "label": "Профессия", "type": "string", "default": "cook"},
##         {"key": "max_workers", "label": "Работников", "type": "int", "default": 2, "min": 0, "max": 16}
##       ]
##     }
##   ]
## }
## ```
## Ids are namespaced with the pack id on load (`core:bakery`), so two packs may
## ship a function of the same name without colliding.

const FILE_NAME := "zone_functions.json"
const PACK_ROOTS: Array[String] = [
	"res://game/content", "user://content/local", "user://content/installed",
]

## What a function can be attached to.
const SCOPE_AREA := &"area"
const SCOPE_ACTIVITY := &"activity"

const SCOPES: Array[StringName] = [SCOPE_AREA, SCOPE_ACTIVITY]

## Cached across calls; `reload()` drops it when packs change.
static var _functions: Dictionary = {}
static var _loaded: bool = false
## Populated on load so a broken pack surfaces in the editor instead of silently
## dropping half its functions.
static var load_errors: Array[String] = []


static func reload() -> void:
	_functions.clear()
	load_errors.clear()
	_loaded = false
	_ensure_loaded()


static func all() -> Array[Dictionary]:
	_ensure_loaded()
	var result: Array[Dictionary] = []
	for key in _functions:
		result.append(_functions[key])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("label", "")) < String(b.get("label", "")))
	return result


## Functions attachable to an area of this role, in display order.
static func for_area_role(area_role: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in all():
		if entry.get("scope", SCOPE_AREA) != SCOPE_AREA:
			continue
		var roles: Array = entry.get("roles", [])
		if roles.is_empty() or area_role in roles:
			result.append(entry)
	return result


## Activities a `slot` may perform.
static func activities() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in all():
		if entry.get("scope", SCOPE_AREA) == SCOPE_ACTIVITY:
			result.append(entry)
	return result


static func get_function(function_id: StringName) -> Dictionary:
	_ensure_loaded()
	return _functions.get(function_id, {})


static func has_function(function_id: StringName) -> bool:
	_ensure_loaded()
	return _functions.has(function_id)


static func label_for(function_id: StringName) -> String:
	var entry := get_function(function_id)
	return String(entry.get("label", String(function_id)))


## Pack that declared the function — shown in the editor so an author can see
## that "Bakery" comes from content, not from the engine.
static func pack_of(function_id: StringName) -> StringName:
	return StringName(get_function(function_id).get("pack", ""))


## Capabilities a fixture in the zone must provide for this function to work.
static func required_capabilities(function_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for cap in get_function(function_id).get("requires", []):
		result.append(StringName(cap))
	return result


## Property descriptors of the function, for the editor inspector.
static func property_schema(function_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw in get_function(function_id).get("properties", []):
		if raw is Dictionary:
			result.append(raw)
	return result


## Properties filled with the function's declared defaults. Used when the author
## picks a function so the inspector never starts from an empty dictionary.
static func default_properties(function_id: StringName) -> Dictionary:
	var result: Dictionary = {}
	for descriptor in property_schema(function_id):
		if descriptor.has("default"):
			result[String(descriptor.get("key", ""))] = descriptor["default"]
	return result


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for root in PACK_ROOTS:
		if DirAccess.dir_exists_absolute(root):
			for pack_dir in DirAccess.get_directories_at(root):
				_load_pack("%s/%s" % [root, pack_dir], StringName(pack_dir))


static func _load_pack(pack_root: String, pack_id: StringName) -> void:
	var path := "%s/%s" % [pack_root, FILE_NAME]
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_errors.append("Cannot read %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		load_errors.append("%s is not a JSON object" % path)
		return
	var raw_functions: Variant = (parsed as Dictionary).get("functions", [])
	if not (raw_functions is Array):
		load_errors.append("%s has no `functions` array" % path)
		return
	for raw in raw_functions:
		if raw is Dictionary:
			_register(raw as Dictionary, pack_id, path)


static func _register(raw: Dictionary, pack_id: StringName, path: String) -> void:
	var local_id := String(raw.get("id", ""))
	if local_id.is_empty():
		load_errors.append("%s: function without an id" % path)
		return
	var scope := StringName(raw.get("scope", SCOPE_AREA))
	if scope not in SCOPES:
		load_errors.append("%s: function %s has unknown scope %s" % [path, local_id, scope])
		return
	var entry := raw.duplicate(true)
	var qualified := StringName("%s:%s" % [pack_id, local_id])
	entry["id"] = qualified
	entry["pack"] = String(pack_id)
	entry["scope"] = scope
	entry["label"] = String(raw.get("label", local_id))
	var roles: Array[StringName] = []
	for role in raw.get("roles", []):
		roles.append(StringName(role))
	entry["roles"] = roles
	if _functions.has(qualified):
		load_errors.append("%s: duplicate function id %s" % [path, qualified])
		return
	_functions[qualified] = entry
