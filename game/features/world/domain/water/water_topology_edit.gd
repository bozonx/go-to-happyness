class_name WaterTopologyEdit
extends WaterDelta

## One atomic replacement of a water body's topology after terrain changed.
##
## A raised ridge may turn one body into several bodies, while a buried basin may
## remove it completely.  Cell-only deltas cannot express either operation: undo
## would try to restore references to registry entries that no longer exist.  This
## edit carries both registry snapshots and the complete affected cell set, so the
## service publishes and replays the transition exactly once.

var _old_bodies: Array[WaterBody] = []
var _new_bodies: Array[WaterBody] = []


static func replacement(
	grid: WaterGrid,
	old_bodies: Array[WaterBody],
	new_bodies: Array[WaterBody],
	new_states: Dictionary,
) -> WaterTopologyEdit:
	var edit := WaterTopologyEdit.new()
	if grid == null:
		return edit
	for body: WaterBody in old_bodies:
		if body != null:
			edit._old_bodies.append(body.duplicate_body())
	for body: WaterBody in new_bodies:
		if body != null:
			edit._new_bodies.append(body.duplicate_body())

	var affected: Dictionary = {}
	for body: WaterBody in old_bodies:
		if body != null:
			for cell: Vector2i in grid.cells_of_body(body.id):
				affected[cell] = true
	for cell: Vector2i in new_states:
		affected[cell] = true
	var affected_cells: Array[Vector2i] = []
	for cell: Vector2i in affected:
		affected_cells.append(cell)
	for cell: Vector2i in CellUtils.sorted_unique(affected_cells):
		var old_state := WaterDelta.state_of(grid, cell)
		var new_state: PackedInt32Array = new_states.get(cell, WaterDelta.dry_state())
		# Registry replacement removes the old body before writing cells. Even a
		# cell which keeps the original id is cleared by that removal and therefore
		# must be replayed explicitly.
		edit.record(cell, old_state, new_state)
	return edit


func changes_registry() -> bool:
	return true


func apply(grid: WaterGrid) -> void:
	if grid == null:
		return
	_remove_bodies(grid, _old_bodies)
	_add_bodies(grid, _new_bodies)
	super.apply(grid)


func revert(grid: WaterGrid) -> void:
	if grid == null:
		return
	_remove_bodies(grid, _new_bodies)
	_add_bodies(grid, _old_bodies)
	super.revert(grid)


static func _remove_bodies(grid: WaterGrid, bodies: Array[WaterBody]) -> void:
	for body: WaterBody in bodies:
		if body != null and grid.has_body(body.id):
			grid.remove_body(body.id)


static func _add_bodies(grid: WaterGrid, bodies: Array[WaterBody]) -> void:
	for body: WaterBody in bodies:
		if body != null:
			grid.add_body(body.duplicate_body())
