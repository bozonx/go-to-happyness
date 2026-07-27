class_name WaterBodyEdit
extends WaterDelta

## An undoable registry change. Removing a body also changes every cell that
## references it, so both must travel through one transaction. Retyping a body
## swaps its metadata (type, colour, wave, salinity, freezes) without touching
## cells — the body id stays the same.

enum Kind { CREATE, REMOVE, RETYPE }

var kind: Kind = Kind.CREATE
var _body_snapshot: WaterBody = null
var _new_body: WaterBody = null


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


## Retypes a body in place: the id and cells stay, the metadata changes. The old
## snapshot is what revert restores; the new body is what apply writes.
static func retype(grid: WaterGrid, body: WaterBody, new_type: WaterBody.Type) -> WaterBodyEdit:
	var edit := WaterBodyEdit.new()
	edit.kind = Kind.RETYPE
	edit._body_snapshot = body.duplicate_body() if body != null else null
	var replacement := WaterBody.of_type(body.id, new_type)
	replacement.surface_height = body.surface_height
	replacement.name = body.name
	edit._new_body = replacement
	return edit


func apply(grid: WaterGrid) -> void:
	if grid == null or _body_snapshot == null:
		return
	match kind:
		Kind.CREATE:
			grid.add_body(_body_snapshot.duplicate_body())
		Kind.REMOVE:
			grid.remove_body(_body_snapshot.id)
		Kind.RETYPE:
			if _new_body != null:
				grid.replace_body(_body_snapshot.id, _new_body.duplicate_body())


func revert(grid: WaterGrid) -> void:
	if grid == null or _body_snapshot == null:
		return
	match kind:
		Kind.CREATE:
			grid.remove_body(_body_snapshot.id)
		Kind.REMOVE:
			grid.add_body(_body_snapshot.duplicate_body())
			super.revert(grid)
		Kind.RETYPE:
			grid.replace_body(_body_snapshot.id, _body_snapshot.duplicate_body())
