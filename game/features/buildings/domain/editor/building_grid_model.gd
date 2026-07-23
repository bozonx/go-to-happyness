class_name BuildingGridModel
extends RefCounted

## Deterministic voxel-grid state for the building editor frame mode.
## Keyed by `Vector3i` cell -> `BlueprintBlock`. Owns place / erase / query and
## conversion to and from a `BuildingBlueprint`. No engine node types.

const BlueprintBlockScript = preload("res://game/features/buildings/domain/editor/blueprint_block.gd")
const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")

var _cells: Dictionary = {}  ## Vector3i -> BlueprintBlock


func is_empty() -> bool:
	return _cells.is_empty()


func count() -> int:
	return _cells.size()


func has_block_at(cell: Vector3i) -> bool:
	return _cells.has(cell)


func get_block_at(cell: Vector3i) -> BlueprintBlockScript:
	return _cells.get(cell, null)


func all_blocks() -> Array:
	return _cells.values()


## Places (or replaces) a block. Returns false when the id is unknown or the
## cell is below ground (negative Y is reserved for underground bunkers, which
## the frame level does not yet support).
func place(cell: Vector3i, block_id: StringName, rot: int = 0) -> bool:
	if not BuildingBlockCatalogScript.has_block(block_id):
		return false
	var block := BlueprintBlockScript.new(cell, block_id, _normalize_rot(block_id, rot))
	_cells[cell] = block
	return true


func erase(cell: Vector3i) -> bool:
	if not _cells.has(cell):
		return false
	_cells.erase(cell)
	return true


func rotate_at(cell: Vector3i, steps: int = 1) -> bool:
	var block: BlueprintBlockScript = _cells.get(cell, null)
	if block == null:
		return false
	block.rot = _normalize_rot(block.block_id, block.rot + steps)
	return true


func clear() -> void:
	_cells.clear()


## Axis-aligned bounds covering all placed cells, or a zero-size box when empty.
func bounds() -> AABB:
	if _cells.is_empty():
		return AABB()
	var min_c := Vector3i(2147483647, 2147483647, 2147483647)
	var max_c := Vector3i(-2147483648, -2147483648, -2147483648)
	for cell in _cells.keys():
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
		var block: BlueprintBlockScript = _cells[cell]
		blueprint.blocks.append(BlueprintBlockScript.new(block.pos, block.block_id, block.rot))
	var b := bounds()
	blueprint.grid_bounds = Vector3i(int(b.size.x), int(b.size.y), int(b.size.z))


func load_from_blueprint(blueprint: BuildingBlueprintScript) -> void:
	_cells.clear()
	for block in blueprint.blocks:
		if BuildingBlockCatalogScript.has_block(block.block_id):
			_cells[block.pos] = BlueprintBlockScript.new(block.pos, block.block_id, block.rot)


func _normalize_rot(block_id: StringName, rot: int) -> int:
	var def := BuildingBlockCatalogScript.get_block(block_id)
	if def.is_empty() or not def.get("rotatable", true):
		return 0
	return ((rot % 4) + 4) % 4


func _compare_cells(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.x != b.x:
		return a.x < b.x
	return a.z < b.z
