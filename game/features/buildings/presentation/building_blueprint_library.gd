class_name BuildingBlueprintLibrary
extends RefCounted

## Resolves an in-game gameplay role to the active visual block blueprint
## (`.gdbuilding.json`) and exposes the data the construction pipeline needs.
##
## This is the bridge that lets the game render buildings from the modular
## editor format. A role resolves through the world's style/variant; a namespaced
## runtime key still addresses one immutable file for saves and map placements.

const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingCatalogScript = preload("res://game/features/buildings/domain/building_catalog.gd")
const ContentIndexScript = preload("res://game/features/content/application/content_index.gd")
const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")
const StyleResolverScript = preload("res://game/features/content/application/style_resolver.gd")

const SOURCE_BUILTIN := &"core"

static var _index: Dictionary = {}          ## runtime key -> {path, source, id}
static var _cache: Dictionary = {}          ## building_type(String) -> BuildingBlueprint
static var _index_built: bool = false
static var _content_index: ContentIndex
static var _world_style: StringName = &"generic"


static func refresh() -> void:
	_index.clear()
	_cache.clear()
	_index_built = true
	BuildingCatalogScript.clear_runtime_definitions()
	_content_index = ContentIndexScript.new()
	_content_index.rebuild()
	for indexed_entry in _content_index.blueprint_entries():
		var path: String = indexed_entry.path
		var blueprint := BuildingBlueprintScript.from_json(FileAccess.get_file_as_string(path))
		if blueprint == null:
			continue
		var key := String(indexed_entry.runtime_key)
		if _index.has(key):
			continue
		_index[key] = {"path": path, "source": indexed_entry.source, "id": blueprint.id}
		_cache[key] = blueprint
		if blueprint.kind == &"building":
			_register_definition(blueprint.role, blueprint)


static func set_world_style(style: StringName) -> void:
	_world_style = style if not String(style).is_empty() else &"generic"


static func world_style() -> StringName:
	return _world_style


static func _ensure_index() -> void:
	if not _index_built:
		refresh()


static func has(building_type: String) -> bool:
	_ensure_index()
	return not _resolved_key(building_type).is_empty()


static func get_blueprint(building_type: String) -> BuildingBlueprintScript:
	_ensure_index()
	building_type = _resolved_key(building_type)
	if building_type.is_empty():
		return null
	if _cache.has(building_type):
		return _cache[building_type]
	if not _index.has(building_type):
		return null
	var entry: Dictionary = _index[building_type]
	var text := FileAccess.get_file_as_string(entry["path"])
	if text.is_empty():
		return null
	var bp := BuildingBlueprintScript.from_json(text)
	_cache[building_type] = bp
	return bp


static func runtime_key(source: StringName, blueprint_id: StringName) -> String:
	return String(ContentIdScript.runtime_key(source, blueprint_id))


static func blueprint_ref(building_type: String) -> Dictionary:
	_ensure_index()
	building_type = _resolved_key(building_type)
	var entry: Dictionary = _index.get(building_type, {})
	var blueprint := get_blueprint(building_type)
	if entry.is_empty() or blueprint == null:
		return {}
	return {
		"source": String(entry["source"]),
		"id": String(entry["id"]),
		"role": String(blueprint.role),
		"revision": blueprint.revision_id(),
	}


static func resolve_reference(reference: Dictionary) -> String:
	_ensure_index()
	var source := StringName(reference.get("source", "core"))
	var blueprint_id := StringName(reference.get("id", ""))
	var key := runtime_key(source, blueprint_id)
	return key if _index.has(key) else ""


static func resolve_role(role: StringName) -> String:
	_ensure_index()
	return _resolved_key(String(role))


static func player_entries() -> Array[Dictionary]:
	_ensure_index()
	var result: Array[Dictionary] = []
	var seen_roles: Dictionary = {}
	for key in _index:
		var entry: Dictionary = _index[key]
		if not String(entry["path"]).begins_with(ContentIndexScript.PROJECTS_ROOT + "/"):
			continue
		var blueprint := get_blueprint(key)
		if blueprint != null and blueprint.kind == &"building" and not seen_roles.has(blueprint.role):
			# Only show the active variant for a role. A local file may exist but be
			# shadowed by another explicit local variant of the same role.
			if _resolved_key(String(blueprint.role)) != key:
				continue
			seen_roles[blueprint.role] = true
			result.append({
				"building_type": String(blueprint.role),
				"id": blueprint.id,
				"name": blueprint.name,
				"category": "custom",
				"variant": String(blueprint.variant),
			})
	result.sort_custom(func(a: Dictionary, b: Dictionary): return str(a["name"]) < str(b["name"]))
	return result


## Read-only catalogue view for migration audits and content tooling.
static func authored_entries() -> Array[Dictionary]:
	_ensure_index()
	var result: Array[Dictionary] = []
	for key in _index:
		var entry: Dictionary = _index[key]
		result.append({
			"runtime_key": key,
			"source": entry["source"],
			"id": entry["id"],
			"path": entry["path"],
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary): return str(a["runtime_key"]) < str(b["runtime_key"]))
	return result


static func _register_definition(role: StringName, blueprint: BuildingBlueprintScript) -> void:
	# A builtin blueprint that matches an existing catalog building_type only
	# supplies visuals + zones: the static definition stays authoritative so its
	# costs, housing/civic flags and upgrade chains are never silently lost
	# (functionality is keyed by building_type, not by the blueprint — see the
	# design doc §1). Only genuinely new types (player customs) get a runtime def.
	if BuildingCatalogScript.has_definition(String(role)):
		return
	BuildingCatalogScript.register_runtime_definition(String(role), {
		"name": blueprint.name,
		"category": "custom",
		"costs": blueprint.construction_cost.duplicate(true),
		"requires_village_area": true,
		"expands_village_area": false,
		"demolishable": true,
		"custom_blueprint": true,
	})


static func _resolved_key(building_type: String) -> String:
	# Runtime keys are immutable file references (not style requests), so use
	# them verbatim for save restore and map placement.
	if _index.has(building_type):
		return building_type
	if ":" in building_type:
		return ""
	var resolver := StyleResolverScript.new(_content_index)
	var requested_variant := &"default"
	if BuildingCatalogScript.has_definition(building_type):
		requested_variant = StringName(BuildingCatalogScript.definition_for(building_type).get("variant", requested_variant))
	var entry := resolver.resolve(StringName(building_type), requested_variant, _world_style)
	if entry != null:
		return String(entry.runtime_key)
	return ""


static func footprint(building_type: String) -> Vector2i:
	var bp := get_blueprint(building_type)
	if bp == null:
		return Vector2i.ZERO
	if bp.footprint != Vector2i.ZERO:
		return bp.footprint
	return Vector2i(bp.grid_bounds.x, bp.grid_bounds.z)


## Ordered block "modules" for the progressive construction reveal. Each entry is
## a `{position, block_id, rot, kind:"block"}` dict compatible with
## `BuildingBlueprints.create_module`. Positions are centred on the footprint so
## the building sits correctly around the placed cell, and sorted bottom-up so
## the frame grows from the ground as construction advances.
static func ordered_modules(building_type: String) -> Array:
	var bp := get_blueprint(building_type)
	if bp == null:
		return []
	var center := bp.pivot_offset()
	var entries: Array = []
	for block in bp.blocks:
		var local := Vector3(block.pos) + _block_offset(block.block_id, block.variant, block.rot, block.anchor) - center
		entries.append({
			"position": local,
			"block_id": block.block_id,
			"material_id": block.material_id,
			"variant": block.variant,
			"rot": block.rot,
			"kind": "block",
		})
	for decor in bp.objects:
		entries.append({
			"position": decor.pos - center,
			"rotation": decor.rot,
			"scale": decor.scale,
			"asset_id": decor.asset_id,
			"appearance": decor.appearance,
			"kind": "decor",
		})
	entries.sort_custom(_compare_module_height)
	return entries


## Offset from a cell's minimum corner to the block mesh origin (floor-aligned,
## horizontally centred). Mirrors BlockMeshLibrary.local_offset but stays in the
## application/domain layer (catalog math only, no presentation dependency).
static func _block_offset(block_id: StringName, variant: StringName = &"", rot: int = 0, anchor: int = 0) -> Vector3:
	var size := BuildingBlockCatalogScript.size_of(block_id, variant)
	var xz := BuildingBlockCatalogScript.cell_offset(block_id, variant, anchor, rot)
	return Vector3(xz.x, size.y * 0.5, xz.y)


static func _compare_module_height(a: Dictionary, b: Dictionary) -> bool:
	var pa: Vector3 = a["position"]
	var pb: Vector3 = b["position"]
	if not is_equal_approx(pa.y, pb.y):
		return pa.y < pb.y
	if not is_equal_approx(pa.x, pb.x):
		return pa.x < pb.x
	return pa.z < pb.z
