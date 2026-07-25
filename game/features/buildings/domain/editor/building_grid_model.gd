class_name BuildingGridModel
extends RefCounted

## Deterministic voxel-grid state for the building editor frame mode.
## The primary map keys the anchor `Vector3i` cell of each placed block; an
## occupancy map tracks every cell a (possibly multi-cell) block covers so
## overlap resolution and erase can work from any covered cell. Owns place /
## erase / query and conversion to and from a `BuildingBlueprint`. No engine
## node types.

const BlueprintBlockScript = preload("res://game/features/buildings/domain/editor/blueprint_block.gd")
const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")

var _cells: Dictionary = {}      ## Vector3i anchor -> BlueprintBlock
var _occupied: Dictionary = {}   ## Vector3i covered cell -> Vector3i anchor


func is_empty() -> bool:
	return _cells.is_empty()


func count() -> int:
	return _cells.size()


## True when any block (single- or multi-cell) covers this cell.
func has_block_at(cell: Vector3i) -> bool:
	return _occupied.has(cell)


## The block covering this cell, or null. Works from any covered cell, not just
## the anchor.
func get_block_at(cell: Vector3i) -> BlueprintBlock:
	var anchor: Variant = _occupied.get(cell, null)
	if anchor == null:
		return null
	return _cells.get(anchor, null)


## Anchor cell of the block covering `cell`, or `cell` itself when none.
func anchor_at(cell: Vector3i) -> Vector3i:
	return _occupied.get(cell, cell)


func all_blocks() -> Array:
	return _cells.values()


## Cells a block would cover if anchored at `cell`, honouring its footprint and
## Y rotation. Single-cell blocks return just `[cell]`.
static func occupied_cells(cell: Vector3i, block_id: StringName, variant: StringName, rot: int) -> Array:
	var fp := BuildingBlockCatalogScript.footprint_of(block_id, variant)
	if fp == Vector3i.ONE:
		return [cell]
	var ox := (fp.x - 1) / 2  # centre width/depth around the anchor cell
	var oz := (fp.z - 1) / 2
	var out: Array = []
	for dx in fp.x:
		for dy in fp.y:
			for dz in fp.z:
				var off := _rotate_xz(Vector2i(dx - ox, dz - oz), rot)
				out.append(cell + Vector3i(off.x, dy, off.y))
	return out


## Anchors of blocks that a new placement at `cell` would overlap and replace.
func overlapping_anchors(cell: Vector3i, block_id: StringName, variant: StringName, rot: int) -> Array:
	var norm_variant := BuildingBlockCatalogScript.normalize_variant(block_id, variant)
	var seen: Dictionary = {}
	for c in occupied_cells(cell, block_id, norm_variant, _normalize_rot(block_id, rot)):
		if _occupied.has(c):
			seen[_occupied[c]] = true
	return seen.keys()


## Places (or replaces) a block at any layer (negative Y included, for
## underground structures). Existing blocks whose cells intersect the new block's
## footprint are removed first. Returns false only when the block id or material
## id is unknown.
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
	if not BuildingBlockCatalogScript.has_block(block_id) or not BuildingMaterialCatalogScript.has_material(material_id):
		return false
	var norm_variant := BuildingBlockCatalogScript.normalize_variant(block_id, variant)
	var norm_rot := _normalize_rot(block_id, rot)
	var cells := occupied_cells(cell, block_id, norm_variant, norm_rot)
	# Clear whatever the footprint would overlap (including a block already at the
	# anchor) so occupancy never double-books a cell.
	for c in cells:
		if _occupied.has(c):
			_erase_block(_occupied[c])
	var block := BlueprintBlockScript.new(
		cell,
		block_id,
		norm_rot,
		material_id,
		norm_variant,
		BuildingBlockCatalogScript.normalize_anchor(block_id, norm_variant, anchor),
		((rot_x % 4) + 4) % 4,
		((rot_z % 4) + 4) % 4)
	_cells[cell] = block
	for c in cells:
		_occupied[c] = cell
	return true


## Erases the block covering `cell` (from any covered cell). Returns true when a
## block was removed.
func erase(cell: Vector3i) -> bool:
	if not _occupied.has(cell):
		return false
	_erase_block(_occupied[cell])
	return true


func _erase_block(anchor: Vector3i) -> void:
	var block: BlueprintBlock = _cells.get(anchor, null)
	if block == null:
		return
	for c in occupied_cells(anchor, block.block_id, block.variant, block.rot):
		if _occupied.get(c, null) == anchor:
			_occupied.erase(c)
	_cells.erase(anchor)


func rotate_at(cell: Vector3i, steps: int = 1) -> bool:
	var anchor := anchor_at(cell)
	var block: BlueprintBlock = _cells.get(anchor, null)
	if block == null:
		return false
	# Re-place so multi-cell occupancy follows the new rotation.
	return place(anchor, block.block_id, block.rot + steps, block.material_id,
		block.variant, block.anchor, block.rot_x, block.rot_z)


func clear() -> void:
	_cells.clear()
	_occupied.clear()


## Axis-aligned bounds covering all occupied cells, or a zero-size box when empty.
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
	var size := Vector3(max_c - min_c) + Vector3.ONE
	return AABB(Vector3(min_c), size)


func write_to_blueprint(blueprint: BuildingBlueprintScript) -> void:
	blueprint.clear_blocks()
	# Stable ordering keeps saved JSON diffs deterministic.
	var keys: Array = _cells.keys()
	keys.sort_custom(_compare_cells)
	for cell in keys:
		var block: BlueprintBlock = _cells[cell]
		blueprint.blocks.append(BlueprintBlockScript.new(
			block.pos, block.block_id, block.rot, block.material_id,
			block.variant, block.anchor, block.rot_x, block.rot_z))
	var b := bounds()
	blueprint.grid_bounds = Vector3i(int(b.size.x), int(b.size.y), int(b.size.z))


func load_from_blueprint(blueprint: BuildingBlueprintScript) -> void:
	clear()
	for block in blueprint.blocks:
		if BuildingBlockCatalogScript.has_block(block.block_id) and BuildingMaterialCatalogScript.has_material(block.material_id):
			place(block.pos, block.block_id, block.rot, block.material_id,
				block.variant, block.anchor, block.rot_x, block.rot_z)


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


func _compare_cells(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.x != b.x:
		return a.x < b.x
	return a.z < b.z
