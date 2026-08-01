class_name CoverageDelta
extends RefCounted

## One coverage operation: what every touched cell was and what it became
## (map_editor.md §5.2.1, §3.3).
##
## The same shape as `TerrainDelta` and `WaterDelta`, for the same reason: the
## operation is computed whole and committed as one piece, so a refused stroke
## leaves nothing behind and the delta IS the undo record.
##
## Two numbers per cell — index and detail — because they are one state. A stroke
## that lays stone over a worn dirt path changes both, and undo has to bring back
## the wear as well as the surface.

const STATE_INDEX := 0
const STATE_DETAIL := 1
const STATE_SIZE := 2

var cells: Array[Vector2i] = []

var _old_states := PackedInt32Array()
var _new_states := PackedInt32Array()


static func state_of(layer: CoverageLayer, cell: Vector2i) -> PackedInt32Array:
	return PackedInt32Array([layer.index_at(cell), layer.detail_at(cell)])


static func make_state(index: int, detail: int) -> PackedInt32Array:
	return PackedInt32Array([index, detail])


static func bare_state() -> PackedInt32Array:
	return PackedInt32Array([CoverageLayer.NO_COVERAGE, TerrainDetailCodec.DEFAULT_DETAIL])


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


func apply(layer: CoverageLayer) -> void:
	for index in cells.size():
		_write(layer, cells[index], _new_states, index * STATE_SIZE)


func revert(layer: CoverageLayer) -> void:
	for index in cells.size():
		_write(layer, cells[index], _old_states, index * STATE_SIZE)


static func _write(layer: CoverageLayer, cell: Vector2i, states: PackedInt32Array, offset: int) -> void:
	layer.set_cell(cell, states[offset + STATE_INDEX], states[offset + STATE_DETAIL])
