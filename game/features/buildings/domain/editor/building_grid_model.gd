class_name BuildingGridModel
extends RefCounted

## Deterministic frame state for the building editor. Several blocks may use the
## same anchor cell; spatial compatibility is decided by their occupied volumes,
## never by the cell address alone. `_occupied` is therefore only a broad-phase
## index, while `_blocks` remains the authoritative set of placed records.

const BlueprintBlockScript = preload("res://game/features/buildings/domain/editor/blueprint_block.gd")
const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")

const INTERSECTION_EPSILON := 0.0001

var _blocks: Dictionary = {}    ## String placement key -> BlueprintBlock
var _occupied: Dictionary = {}  ## Vector3i broad-phase cell -> Array[String] placement keys


func is_empty() -> bool:
	return _blocks.is_empty()


func count() -> int:
	return _blocks.size()


func has_block_at(cell: Vector3i) -> bool:
	return _occupied.has(cell) and not (_occupied[cell] as Array).is_empty()


## The most recently placed block covering `cell`, or null. The editor can use
## this deterministic top-most choice for erase; the model never treats it as
## the only block in the cell.
func get_block_at(cell: Vector3i) -> BlueprintBlock:
	var keys: Array = _occupied.get(cell, [])
	for index in range(keys.size() - 1, -1, -1):
		var block: BlueprintBlock = _blocks.get(keys[index], null)
		if block != null:
			return block
	return null


## All elements whose anchor is exactly `cell`, in stable placement-key order. A frame
## "block" can be assembled from several compatible sub-blocks in one voxel;
## callers that copy the complete assembly must not use the broad-phase index
## (which also includes pieces anchored in neighbouring cells).
func blocks_anchored_at(cell: Vector3i) -> Array[BlueprintBlock]:
	var result: Array[BlueprintBlock] = []
	var keys: Array = _blocks.keys()
	keys.sort()
	for key in keys:
		var block: BlueprintBlock = _blocks[key]
		if block.pos == cell:
			result.append(block)
	return result


func block_key_at(cell: Vector3i) -> String:
	var block := get_block_at(cell)
	return placement_key_for(block) if block != null else ""


func anchor_at(cell: Vector3i) -> Vector3i:
	var block := get_block_at(cell)
	return block.pos if block != null else cell


func all_blocks() -> Array:
	return _blocks.values()


func placement_key_for(block: BlueprintBlock) -> String:
	return placement_key(block.pos, block.block_id, block.variant, block.anchor, block.rot, block.rot_x, block.rot_z)


static func placement_key(
	cell: Vector3i,
	block_id: StringName,
	variant: StringName,
	anchor: int,
	rot: int,
	rot_x: int,
	rot_z: int
) -> String:
	# Material is intentionally absent: differently painted duplicate solids are
	# still one invalid placement, not two compatible construction elements.
	return "%d:%d:%d|%s|%s|%d|%d|%d|%d" % [
		cell.x, cell.y, cell.z, block_id, variant, anchor, rot, rot_x, rot_z]


## Cells used for broad-phase lookup. They do not define the final collision
## decision; `occupied_aabb` below does.
static func occupied_cells(cell: Vector3i, block_id: StringName, variant: StringName, rot: int) -> Array:
	var fp := BuildingBlockCatalogScript.footprint_of(block_id, variant)
	if fp == Vector3i.ONE:
		return [cell]
	var ox := (fp.x - 1) / 2
	var oz := (fp.z - 1) / 2
	var out: Array = []
	for dx in fp.x:
		for dy in fp.y:
			for dz in fp.z:
				var off := _rotate_xz(Vector2i(dx - ox, dz - oz), rot)
				out.append(cell + Vector3i(off.x, dy, off.y))
	return out


func can_place(
	cell: Vector3i,
	block_id: StringName,
	rot: int = 0,
	material_id: StringName = BuildingMaterialCatalogScript.DEFAULT_ID,
	variant: StringName = &"",
	anchor: int = 0,
	rot_x: int = 0,
	rot_z: int = 0
) -> bool:
	if not BuildingBlockCatalogScript.has_block(block_id) or not BuildingMaterialCatalogScript.has_material(material_id):
		return false
	var norm_variant := BuildingBlockCatalogScript.normalize_variant(block_id, variant)
	var norm_rot := _normalize_rot(block_id, rot)
	var norm_anchor := BuildingBlockCatalogScript.normalize_anchor(block_id, norm_variant, anchor)
	var key := placement_key(cell, block_id, norm_variant, norm_anchor, norm_rot, rot_x, rot_z)
	if _blocks.has(key):
		return false
	var candidate := BuildingBlockCatalogScript.occupied_aabb(cell, block_id, norm_variant, norm_rot, norm_anchor, rot_x, rot_z)
	for existing_key in _candidate_keys(cell, block_id, norm_variant, norm_rot):
		var existing: BlueprintBlock = _blocks.get(existing_key, null)
		if existing == null:
			continue
		var occupied := BuildingBlockCatalogScript.occupied_aabb(existing.pos, existing.block_id,
			existing.variant, existing.rot, existing.anchor, existing.rot_x, existing.rot_z)
		if _interiors_intersect(candidate, occupied) and not _allows_joint(block_id, existing.block_id):
			return false
	return true


## Kept for the editor call-site; compatible placements no longer evict blocks.
func overlapping_anchors(_cell: Vector3i, _block_id: StringName, _variant: StringName, _rot: int) -> Array:
	return []


func place(
	cell: Vector3i,
	block_id: StringName,
	rot: int = 0,
	material_id: StringName = BuildingMaterialCatalogScript.DEFAULT_ID,
	variant: StringName = &"",
	anchor: int = 0,
	rot_x: int = 0,
	rot_z: int = 0
) -> bool:
	if not can_place(cell, block_id, rot, material_id, variant, anchor, rot_x, rot_z):
		return false
	var norm_variant := BuildingBlockCatalogScript.normalize_variant(block_id, variant)
	var norm_rot := _normalize_rot(block_id, rot)
	var block := BlueprintBlockScript.new(cell, block_id, norm_rot, material_id, norm_variant,
		BuildingBlockCatalogScript.normalize_anchor(block_id, norm_variant, anchor),
		((rot_x % 4) + 4) % 4, ((rot_z % 4) + 4) % 4)
	var key := placement_key_for(block)
	_blocks[key] = block
	for covered_cell in occupied_cells(cell, block_id, norm_variant, norm_rot):
		var keys: Array = _occupied.get(covered_cell, [])
		keys.append(key)
		_occupied[covered_cell] = keys
	return true


func erase(cell: Vector3i) -> bool:
	var key := block_key_at(cell)
	if key.is_empty():
		return false
	_erase_key(key)
	return true


func erase_block(block: BlueprintBlock) -> bool:
	var key := placement_key_for(block)
	if not _blocks.has(key):
		return false
	_erase_key(key)
	return true


func _erase_key(key: String) -> void:
	var block: BlueprintBlock = _blocks.get(key, null)
	if block == null:
		return
	for covered_cell in occupied_cells(block.pos, block.block_id, block.variant, block.rot):
		var keys: Array = _occupied.get(covered_cell, [])
		keys.erase(key)
		if keys.is_empty():
			_occupied.erase(covered_cell)
		else:
			_occupied[covered_cell] = keys
	_blocks.erase(key)


func rotate_at(cell: Vector3i, steps: int = 1) -> bool:
	var block := get_block_at(cell)
	if block == null:
		return false
	_erase_key(placement_key_for(block))
	if place(block.pos, block.block_id, block.rot + steps, block.material_id,
		block.variant, block.anchor, block.rot_x, block.rot_z):
		return true
	# Rotation cannot silently destroy a valid placed element; restore it.
	place(block.pos, block.block_id, block.rot, block.material_id,
		block.variant, block.anchor, block.rot_x, block.rot_z)
	return false


func clear() -> void:
	_blocks.clear()
	_occupied.clear()


func bounds() -> AABB:
	if _occupied.is_empty():
		return AABB()
	var min_c := Vector3i(2147483647, 2147483647, 2147483647)
	var max_c := Vector3i(-2147483648, -2147483648, -2147483648)
	for cell in _occupied.keys():
		min_c.x = mini(min_c.x, cell.x)
		min_c.y = mini(min_c.y, cell.y)
		min_c.z = mini(min_c.z, cell.z)
		max_c.x = maxi(max_c.x, cell.x)
		max_c.y = maxi(max_c.y, cell.y)
		max_c.z = maxi(max_c.z, cell.z)
	return AABB(Vector3(min_c), Vector3(max_c - min_c) + Vector3.ONE)


func write_to_blueprint(blueprint: BuildingBlueprintScript) -> void:
	blueprint.clear_blocks()
	var keys: Array = _blocks.keys()
	keys.sort()
	for key in keys:
		var block: BlueprintBlock = _blocks[key]
		blueprint.blocks.append(BlueprintBlockScript.new(block.pos, block.block_id, block.rot,
			block.material_id, block.variant, block.anchor, block.rot_x, block.rot_z))
	var b := bounds()
	blueprint.grid_bounds = Vector3i(maxi(1, int(b.size.x)), maxi(1, int(b.size.y)), maxi(1, int(b.size.z)))


func load_from_blueprint(blueprint: BuildingBlueprintScript) -> void:
	clear()
	for block in blueprint.blocks:
		if BuildingBlockCatalogScript.has_block(block.block_id) and BuildingMaterialCatalogScript.has_material(block.material_id):
			place(block.pos, block.block_id, block.rot, block.material_id,
				block.variant, block.anchor, block.rot_x, block.rot_z)


func _candidate_keys(cell: Vector3i, block_id: StringName, variant: StringName, rot: int) -> Array:
	var seen: Dictionary = {}
	for covered_cell in occupied_cells(cell, block_id, variant, rot):
		for key in _occupied.get(covered_cell, []):
			seen[key] = true
	return seen.keys()


static func _interiors_intersect(a: AABB, b: AABB) -> bool:
	return a.position.x < b.end.x - INTERSECTION_EPSILON and b.position.x < a.end.x - INTERSECTION_EPSILON \
		and a.position.y < b.end.y - INTERSECTION_EPSILON and b.position.y < a.end.y - INTERSECTION_EPSILON \
		and a.position.z < b.end.z - INTERSECTION_EPSILON and b.position.z < a.end.z - INTERSECTION_EPSILON


static func _allows_joint(new_block_id: StringName, existing_block_id: StringName) -> bool:
	return BuildingBlockCatalogScript.allows_structural_joint(new_block_id) \
		and BuildingBlockCatalogScript.allows_structural_joint(existing_block_id)


func _normalize_rot(block_id: StringName, rot: int) -> int:
	var def := BuildingBlockCatalogScript.get_block(block_id)
	if def.is_empty() or not def.get("rotatable", true):
		return 0
	return ((rot % 4) + 4) % 4


static func _rotate_xz(off: Vector2i, rot: int) -> Vector2i:
	match ((rot % 4) + 4) % 4:
		1: return Vector2i(-off.y, off.x)
		2: return Vector2i(-off.x, -off.y)
		3: return Vector2i(off.y, -off.x)
		_: return off
