class_name WaterFlowEdit
extends WaterDelta

## An undoable change to a body's flow dictionary (grid_terrain_system.md §9).
##
## Flow is stored on the `WaterBody`, not on the grid cells, so it cannot ride in
## the cell-state arrays of a `WaterDelta`. This class extends `WaterDelta` so it
## can share the same undo stack and the same `edit_committed` signal: the
## `cells` array tells the navigation publisher which columns to republish, and
## `apply` / `revert` write to the body's `flow` dictionary instead of the grid's
## cell arrays.

var body_id := WaterBody.NO_BODY
var _old_flows := PackedInt32Array()
var _new_flows := PackedInt32Array()


static func create(
	next_body_id: int,
	edit_cells: Array[Vector2i],
	old_flows: PackedInt32Array,
	new_flows: PackedInt32Array,
) -> WaterFlowEdit:
	var edit := WaterFlowEdit.new()
	edit.body_id = next_body_id
	edit.cells = edit_cells.duplicate()
	edit._old_flows = old_flows.duplicate()
	edit._new_flows = new_flows.duplicate()
	return edit


func apply(grid: WaterGrid) -> void:
	var body := grid.body(body_id)
	if body == null:
		return
	for index in cells.size():
		_write_flow(body, cells[index], _new_flows, index)


func revert(grid: WaterGrid) -> void:
	var body := grid.body(body_id)
	if body == null:
		return
	for index in cells.size():
		_write_flow(body, cells[index], _old_flows, index)


static func _write_flow(body: WaterBody, cell: Vector2i, flows: PackedInt32Array, index: int) -> void:
	var value := flows[index]
	if value == 0:
		body.flow.erase(cell)
	else:
		body.flow[cell] = value
