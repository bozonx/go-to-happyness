class_name WaterDelta
extends RefCounted

## The result of one water operation: what every touched cell looked like before
## and after (design_docs/engine/grid_terrain_system.md §9, §4.4).
##
## The same shape as `TerrainDelta` and for the same reason: an operation is
## computed first and committed as one piece, so a refused stroke leaves nothing
## behind and the delta IS the undo record.
##
## State is the whole water cell — body, level and the flag byte — because a
## single stroke can change all three: painting a level into a frozen lake both
## moves the surface and, where it deepens past what the ice covered, has to carry
## the old flags back on undo.

const STATE_BODY := 0
const STATE_HEIGHT := 1
const STATE_FLAGS := 2
const STATE_SIZE := 3

var cells: Array[Vector2i] = []

var _old_states := PackedInt32Array()
var _new_states := PackedInt32Array()


static func state_of(grid: WaterGrid, cell: Vector2i) -> PackedInt32Array:
	return PackedInt32Array([
		grid.body_id_at(cell),
		grid.height_of(cell),
		grid.flags_of(cell),
	])


static func make_state(body_id: int, height: int, flags: int) -> PackedInt32Array:
	return PackedInt32Array([body_id, height, flags])


static func dry_state() -> PackedInt32Array:
	return PackedInt32Array([WaterBody.NO_BODY, 0, 0])


func is_empty() -> bool:
	return cells.is_empty()


func size() -> int:
	return cells.size()


## Registry-aware edits override this so publishers can invalidate body material
## caches without subscribing to a second navigation-producing signal.
func changes_registry() -> bool:
	return false


func record(cell: Vector2i, old_state: PackedInt32Array, new_state: PackedInt32Array) -> void:
	cells.append(cell)
	_old_states.append_array(old_state)
	_new_states.append_array(new_state)


func old_state_at(index: int) -> PackedInt32Array:
	return _old_states.slice(index * STATE_SIZE, (index + 1) * STATE_SIZE)


func new_state_at(index: int) -> PackedInt32Array:
	return _new_states.slice(index * STATE_SIZE, (index + 1) * STATE_SIZE)


func apply(grid: WaterGrid) -> void:
	for index in cells.size():
		_write(grid, cells[index], _new_states, index * STATE_SIZE)


func revert(grid: WaterGrid) -> void:
	for index in cells.size():
		_write(grid, cells[index], _old_states, index * STATE_SIZE)


static func _write(grid: WaterGrid, cell: Vector2i, states: PackedInt32Array, offset: int) -> void:
	grid.set_cell(
		cell,
		states[offset + STATE_BODY],
		states[offset + STATE_HEIGHT],
		states[offset + STATE_FLAGS],
	)
