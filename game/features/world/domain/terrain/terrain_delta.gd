class_name TerrainDelta
extends RefCounted

## The result of one terrain operation: what every touched column looked like
## before and after (design_docs/core/grid_terrain_system.md §4.4).
##
## Operations are computed on a copy and committed as one delta, so a rejected
## operation leaves nothing behind and undo costs nothing extra — the delta IS the
## undo record. State is the WHOLE column, not just its height: a cascade that
## moves a column also dissolves the ramp it belonged to, a levelling brush may
## repaint it, and an editor may cut a hole in it. Anything a delta cannot express
## is something undo would silently lose.

## Column state layout, `STATE_SIZE` ints per cell.
const STATE_HEIGHT := 0
const STATE_SLOPE_CLASS := 1
const STATE_SLOPE_DIR := 2
const STATE_SLOPE_INDEX := 3
const STATE_MATERIAL := 4
const STATE_FLAGS := 5
const STATE_SIZE := 6

var cells: Array[Vector2i] = []

var _old_states := PackedInt32Array()
var _new_states := PackedInt32Array()


static func state_of(grid: TerrainGrid, cell: Vector2i) -> PackedInt32Array:
	return PackedInt32Array([
		grid.height_of(cell),
		grid.slope_class_at(cell),
		grid.slope_direction_of(cell),
		grid.slope_index_of(cell),
		grid.material_index_at(cell),
		grid.flags_of(cell),
	])


static func make_state(height: int, slope_class: int, slope_dir: int, slope_index: int, material_index: int, flags: int) -> PackedInt32Array:
	return PackedInt32Array([height, slope_class, slope_dir, slope_index, material_index, flags])


## The same column, flattened: height kept, slope descriptor dropped. What a
## dissolved ramp cell becomes.
static func flattened(state: PackedInt32Array, height: int) -> PackedInt32Array:
	return PackedInt32Array([
		height,
		SlopeCatalog.CLASS_FLAT,
		0,
		0,
		state[STATE_MATERIAL],
		state[STATE_FLAGS],
	])


func is_empty() -> bool:
	return cells.is_empty()


func size() -> int:
	return cells.size()


func record(cell: Vector2i, old_state: PackedInt32Array, new_state: PackedInt32Array) -> void:
	cells.append(cell)
	_old_states.append_array(old_state)
	_new_states.append_array(new_state)


func old_state_at(index: int) -> PackedInt32Array:
	return _old_states.slice(index * STATE_SIZE, (index + 1) * STATE_SIZE)


func new_state_at(index: int) -> PackedInt32Array:
	return _new_states.slice(index * STATE_SIZE, (index + 1) * STATE_SIZE)


func apply(grid: TerrainGrid) -> void:
	for index in cells.size():
		_write(grid, cells[index], _new_states, index * STATE_SIZE)


func revert(grid: TerrainGrid) -> void:
	for index in cells.size():
		_write(grid, cells[index], _old_states, index * STATE_SIZE)


func _write(grid: TerrainGrid, cell: Vector2i, states: PackedInt32Array, offset: int) -> void:
	grid.set_cell_state(
		cell,
		states[offset + STATE_HEIGHT],
		states[offset + STATE_SLOPE_CLASS],
		states[offset + STATE_SLOPE_DIR],
		states[offset + STATE_SLOPE_INDEX],
		states[offset + STATE_MATERIAL],
		states[offset + STATE_FLAGS],
	)
