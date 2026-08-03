class_name TerrainDelta
extends RefCounted

## The result of one terrain operation: what every touched column looked like
## before and after (design_docs/engine/grid_terrain_system.md §4.4).
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
## variant | wear | snow_depth, packed (`terrain_materials.md` §5). Part of the
## column state for the same reason the material is: a levelling brush may reset
## a variant and a wear pass may raise a trodden path, and undo has to carry both
## back.
const STATE_DETAIL := 6
const STATE_SIZE := 7

## The fields that mean "ground moved" — everything `changes_geometry` compares.
## Material and detail are deliberately absent: they are the surface, and the
## surface reaches the GPU without a vertex (`terrain_materials.md` §7.5).
const GEOMETRY_FIELDS: Array[int] = [
	STATE_HEIGHT, STATE_SLOPE_CLASS, STATE_SLOPE_DIR, STATE_SLOPE_INDEX, STATE_FLAGS,
]

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
		grid.detail_at(cell),
	])


static func make_state(height: int, slope_class: int, slope_dir: int, slope_index: int, material_index: int, flags: int, detail: int = TerrainDetailCodec.DEFAULT_DETAIL) -> PackedInt32Array:
	return PackedInt32Array([height, slope_class, slope_dir, slope_index, material_index, flags, detail])


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
		state[STATE_DETAIL],
	])


func is_empty() -> bool:
	return cells.is_empty()


## True when the operation moved ground: height, slope descriptor or flags. False
## for a pure surface edit — material, variant, wear, snow — which touches neither
## the mesh nor passability (`terrain_materials.md` §7.5) and so must not make
## anyone rebuild a chunk or replan a route.
func changes_geometry() -> bool:
	for index in cells.size():
		var offset := index * STATE_SIZE
		# The field list is a constant, not an array literal built per cell: a
		# cascade delta runs to thousands of columns, and this used to allocate one
		# throwaway `Array` for each of them.
		for field: int in GEOMETRY_FIELDS:
			if _old_states[offset + field] != _new_states[offset + field]:
				return true
	return false


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
		states[offset + STATE_DETAIL],
	)
