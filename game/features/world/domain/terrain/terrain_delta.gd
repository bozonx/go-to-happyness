class_name TerrainDelta
extends RefCounted

## The result of one terrain operation: what every touched column looked like
## before and after (design_docs/core/grid_terrain_system.md §4.4).
##
## Operations are computed on a copy and committed as one delta, so a rejected
## operation leaves nothing behind and undo costs nothing extra — the delta IS the
## undo record. State is stored whole (height + slope descriptor) rather than
## height only, because a cascade that moves a column also dissolves the ramp that
## column belonged to.

## Column state as (height, slope_class, slope_dir, slope_index).
var cells: Array[Vector2i] = []
var old_states: Array[Vector4i] = []
var new_states: Array[Vector4i] = []


static func state_of(grid: TerrainGrid, cell: Vector2i) -> Vector4i:
	return Vector4i(
		grid.height_of(cell),
		SlopeCatalog.slope_class_of(grid.slope_of(cell)),
		grid.slope_direction_of(cell),
		grid.slope_index_of(cell),
	)


func is_empty() -> bool:
	return cells.is_empty()


func size() -> int:
	return cells.size()


func record(cell: Vector2i, old_state: Vector4i, new_state: Vector4i) -> void:
	cells.append(cell)
	old_states.append(old_state)
	new_states.append(new_state)


func apply(grid: TerrainGrid) -> void:
	for index in cells.size():
		_write(grid, cells[index], new_states[index])


func revert(grid: TerrainGrid) -> void:
	for index in cells.size():
		_write(grid, cells[index], old_states[index])


func _write(grid: TerrainGrid, cell: Vector2i, state: Vector4i) -> void:
	grid.set_cell_state(cell, state.x, SlopeCatalog.id_of_class(state.y), state.z, state.w)
