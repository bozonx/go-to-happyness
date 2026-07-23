class_name BuildingBlueprintLibrary
extends RefCounted

## Resolves an in-game `building_type` to its canonical block blueprint
## (`.gdbuilding.json`) and exposes the data the construction pipeline needs.
##
## This is the bridge that lets the game render buildings from the modular
## editor format. A `building_type` maps to the blueprint file whose `id`
## matches. While a type has no file, `has()` returns false and callers fall
## back to the legacy procedural generator — so the game keeps working during
## the gradual conversion.

const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")

const DATA_DIR := "res://game/features/buildings/data/blueprints"

static var _index: Dictionary = {}          ## building_type(String) -> file path
static var _cache: Dictionary = {}          ## building_type(String) -> BuildingBlueprint
static var _index_built: bool = false


static func refresh() -> void:
	_index.clear()
	_cache.clear()
	_index_built = true
	if not DirAccess.dir_exists_absolute(DATA_DIR):
		return
	var suffix := "." + BuildingBlueprintScript.FILE_EXTENSION
	for file_name in DirAccess.get_files_at(DATA_DIR):
		if not file_name.ends_with(suffix):
			continue
		# The id key is the filename stem by convention; verified against the
		# blueprint's own id when loaded.
		var stem := file_name.substr(0, file_name.length() - suffix.length())
		_index[stem] = "%s/%s" % [DATA_DIR, file_name]


static func _ensure_index() -> void:
	if not _index_built:
		refresh()


static func has(building_type: String) -> bool:
	_ensure_index()
	return _index.has(building_type)


static func get_blueprint(building_type: String) -> BuildingBlueprintScript:
	_ensure_index()
	if _cache.has(building_type):
		return _cache[building_type]
	if not _index.has(building_type):
		return null
	var text := FileAccess.get_file_as_string(_index[building_type])
	if text.is_empty():
		return null
	var bp := BuildingBlueprintScript.from_json(text)
	_cache[building_type] = bp
	return bp


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
	var center := _footprint_center(bp)
	var entries: Array = []
	for block in bp.blocks:
		var local := Vector3(block.pos) + _block_offset(block.block_id) - center
		entries.append({
			"position": local,
			"block_id": block.block_id,
			"rot": block.rot,
			"kind": "block",
		})
	entries.sort_custom(_compare_module_height)
	return entries


## Offset from a cell's minimum corner to the block mesh origin (floor-aligned,
## horizontally centred). Mirrors BlockMeshLibrary.local_offset but stays in the
## application/domain layer (catalog math only, no presentation dependency).
static func _block_offset(block_id: StringName) -> Vector3:
	var def := BuildingBlockCatalogScript.get_block(block_id)
	if def.is_empty():
		return Vector3(0.5, 0.5, 0.5)
	var size: Vector3 = def["size"]
	return Vector3(0.5, size.y * 0.5, 0.5)


static func _footprint_center(bp: BuildingBlueprintScript) -> Vector3:
	# Midpoint of the placed extent in X/Z, floor in Y.
	if bp.blocks.is_empty():
		return Vector3.ZERO
	var min_c := Vector3i(2147483647, 2147483647, 2147483647)
	var max_c := Vector3i(-2147483648, -2147483648, -2147483648)
	for block in bp.blocks:
		min_c.x = mini(min_c.x, block.pos.x)
		min_c.y = mini(min_c.y, block.pos.y)
		min_c.z = mini(min_c.z, block.pos.z)
		max_c.x = maxi(max_c.x, block.pos.x)
		max_c.z = maxi(max_c.z, block.pos.z)
	return Vector3(
		float(min_c.x) + float(max_c.x - min_c.x + 1) * 0.5,
		float(min_c.y),
		float(min_c.z) + float(max_c.z - min_c.z + 1) * 0.5)


static func _compare_module_height(a: Dictionary, b: Dictionary) -> bool:
	var pa: Vector3 = a["position"]
	var pb: Vector3 = b["position"]
	if not is_equal_approx(pa.y, pb.y):
		return pa.y < pb.y
	if not is_equal_approx(pa.x, pb.x):
		return pa.x < pb.x
	return pa.z < pb.z
