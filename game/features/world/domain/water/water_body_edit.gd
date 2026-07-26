class_name WaterBodyEdit
extends WaterDelta

## An undoable registry change. Removing a body also changes every cell that
## references it, so both must travel through one transaction.

enum Kind { CREATE, REMOVE }

var kind: Kind = Kind.CREATE
var _body_snapshot: WaterBody = null


static func creation(body: WaterBody) -> WaterBodyEdit:
	var edit := WaterBodyEdit.new()
	edit.kind = Kind.CREATE
	edit._body_snapshot = body.duplicate_body() if body != null else null
	return edit


static func removal(grid: WaterGrid, body: WaterBody) -> WaterBodyEdit:
	var edit := WaterBodyEdit.new()
	edit.kind = Kind.REMOVE
	edit._body_snapshot = body.duplicate_body() if body != null else null
	if grid == null or body == null:
		return edit
	for cell: Vector2i in grid.cells_of_body(body.id):
		edit.record(cell, WaterDelta.state_of(grid, cell), WaterDelta.dry_state())
	return edit


func apply(grid: WaterGrid) -> void:
	if grid == null or _body_snapshot == null:
		return
	match kind:
		Kind.CREATE:
			grid.add_body(_body_snapshot.duplicate_body())
		Kind.REMOVE:
			grid.remove_body(_body_snapshot.id)


func revert(grid: WaterGrid) -> void:
	if grid == null or _body_snapshot == null:
		return
	match kind:
		Kind.CREATE:
			grid.remove_body(_body_snapshot.id)
		Kind.REMOVE:
			grid.add_body(_body_snapshot.duplicate_body())
			super.revert(grid)
