class_name TerrainWorkingRegion
extends RefCounted

## A scratch copy of the part of a `TerrainGrid` an operation touches
## (design_docs/engine/grid_terrain_system.md §4.4 "атомарность").
##
## Reads fall through to the grid; writes land in override dictionaries. Nothing
## here mutates the grid, so an operation that is refused halfway leaves no trace,
## and one that succeeds is turned into a single `TerrainDelta` at the end.
##
## It carries the whole column state, not just height, because the cascade
## dissolves ramps and the auto-slope pass (§3.2) writes slope descriptors — both
## have to be undoable, and both have to be visible to the steps that run after
## them.

var grid: TerrainGrid = null

var _heights: Dictionary = {}
## cell -> Vector3i(slope_class, slope_dir, slope_index)
var _slopes: Dictionary = {}
## cell -> flags. Only a placement merge writes these: cutting the mouth of an
## underground entrance out of the ground (§6) has to be part of the same
## transaction as the heights around it, or undo would fill the opening back in
## and leave the doorway sealed.
var _flags: Dictionary = {}


func _init(target_grid: TerrainGrid) -> void:
	grid = target_grid


# --- Reads ------------------------------------------------------------------

func is_inside(cell: Vector2i) -> bool:
	return grid.is_inside(cell)


func flags_of(cell: Vector2i) -> int:
	return _flags.get(cell, grid.flags_of(cell))


func is_hole(cell: Vector2i) -> bool:
	return (flags_of(cell) & TerrainCell.FLAG_HOLE) != 0


func is_anchor(cell: Vector2i) -> bool:
	return grid.is_anchor(cell)


func material_index_at(cell: Vector2i) -> int:
	return grid.material_index_at(cell)


func height_of(cell: Vector2i) -> int:
	return _heights.get(cell, grid.height_of(cell))


func slope_class_at(cell: Vector2i) -> int:
	if _slopes.has(cell):
		return (_slopes[cell] as Vector3i).x
	return grid.slope_class_at(cell)


func slope_direction_of(cell: Vector2i) -> int:
	if _slopes.has(cell):
		return (_slopes[cell] as Vector3i).y
	return grid.slope_direction_of(cell)


func slope_index_of(cell: Vector2i) -> int:
	if _slopes.has(cell):
		return (_slopes[cell] as Vector3i).z
	return grid.slope_index_of(cell)


func is_ramp_cell(cell: Vector2i) -> bool:
	return SlopeCatalog.is_ramp_class(slope_class_at(cell))


func state_of(cell: Vector2i) -> PackedInt32Array:
	return TerrainDelta.make_state(
		height_of(cell),
		slope_class_at(cell),
		slope_direction_of(cell),
		slope_index_of(cell),
		grid.material_index_at(cell),
		flags_of(cell),
		grid.detail_at(cell),
	)


# --- Writes -----------------------------------------------------------------

func set_height(cell: Vector2i, height: int) -> void:
	_heights[cell] = height


func set_slope(cell: Vector2i, slope_class: int, slope_dir: int, slope_index: int) -> void:
	_slopes[cell] = Vector3i(slope_class, slope_dir, slope_index)


func set_hole(cell: Vector2i, enabled: bool) -> void:
	var flags := flags_of(cell)
	_flags[cell] = (flags | TerrainCell.FLAG_HOLE) if enabled else (flags & ~TerrainCell.FLAG_HOLE)


func clear_slope(cell: Vector2i) -> void:
	_slopes[cell] = Vector3i(SlopeCatalog.CLASS_FLAT, 0, 0)


# --- Ramps ------------------------------------------------------------------

## Same geometry as `TerrainGrid.ramp_cells_at`, read through the overrides.
func ramp_cells_at(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var slope_class := slope_class_at(cell)
	if not SlopeCatalog.is_ramp_class(slope_class):
		return result
	var offset := SlopeCatalog.direction_offset(slope_direction_of(cell))
	var start := cell - offset * slope_index_of(cell)
	for step in SlopeCatalog.run_of_class(slope_class):
		result.append(start + offset * step)
	return result


func ramp_top_anchor_at(cell: Vector2i) -> Vector2i:
	var slope_class := slope_class_at(cell)
	if not SlopeCatalog.is_ramp_class(slope_class):
		return cell
	var offset := SlopeCatalog.direction_offset(slope_direction_of(cell))
	var start := cell - offset * slope_index_of(cell)
	return start + offset * SlopeCatalog.run_of_class(slope_class)


## True when some ramp uses this column as the top it climbs to. Moving such a
## column breaks that ramp (§3.1) — the cascade dissolves it, the decorative
## slope pass steps around it instead.
func has_ramp_climbing_to(cell: Vector2i) -> bool:
	for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
		var neighbour := cell + SlopeCatalog.direction_offset(direction)
		if is_ramp_cell(neighbour) and ramp_top_anchor_at(neighbour) == cell:
			return true
	return false


## Dissolves every ramp moving this column would invalidate: the one the column
## belongs to, and the ones that climb to it (§3.1). Returns the cells that lost
## their slope descriptor.
func dissolve_ramps_touching(cell: Vector2i) -> Array[Vector2i]:
	var dissolved: Array[Vector2i] = []
	var starts: Array[Vector2i] = []
	if is_ramp_cell(cell):
		starts.append(cell)
	for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
		var neighbour := cell + SlopeCatalog.direction_offset(direction)
		if is_ramp_cell(neighbour) and ramp_top_anchor_at(neighbour) == cell:
			starts.append(neighbour)
	for start: Vector2i in starts:
		for ramp_cell: Vector2i in ramp_cells_at(start):
			clear_slope(ramp_cell)
			dissolved.append(ramp_cell)
	return dissolved


# --- Result -----------------------------------------------------------------

## Every cell the operation wrote to, in the deterministic order §4.4 requires.
func touched_cells() -> Array[Vector2i]:
	var seen: Dictionary = {}
	for cell: Vector2i in _heights:
		seen[cell] = true
	for cell: Vector2i in _slopes:
		seen[cell] = true
	for cell: Vector2i in _flags:
		seen[cell] = true
	var cells: Array[Vector2i] = []
	for cell: Vector2i in seen:
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return cells
