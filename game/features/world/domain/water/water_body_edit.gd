class_name WaterBodyEdit
extends WaterDelta

## An undoable registry change. Removing a body also changes every cell that
## references it, so both must travel through one transaction. Retyping a body
## swaps its metadata (type, colour, wave, salinity, freezes) without touching
## cells — the body id stays the same.

enum Kind { CREATE, REMOVE, RETYPE, RESURFACE }

var kind: Kind = Kind.CREATE
var _body_snapshot: WaterBody = null
var _new_body: WaterBody = null


static func creation(body: WaterBody) -> WaterBodyEdit:
	var edit := WaterBodyEdit.new()
	edit.kind = Kind.CREATE
	edit._body_snapshot = body.duplicate_body() if body != null else null
	return edit


## Creates the registry entry and its first wet footprint as one transaction.
## This is the editor's "click dry ground" gesture: one action and one Ctrl+Z.
static func creation_with_cells(grid: WaterGrid, terrain: TerrainGrid, body: WaterBody, cells: Array[Vector2i]) -> WaterBodyEdit:
	var edit := creation(body)
	if grid == null or body == null:
		return edit
	for cell: Vector2i in CellUtils.sorted_unique(cells):
		if not grid.is_inside(cell) or (terrain != null and terrain.height_of(cell) >= body.surface_height):
			continue
		var old_state := WaterDelta.state_of(grid, cell)
		var new_state := WaterDelta.make_state(body.id, body.surface_height, 0)
		if old_state != new_state:
			edit.record(cell, old_state, new_state)
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
## snapshot is what revert restores; the new body is what apply writes. The cells
## are recorded so the presentation knows which chunks to rebuild.
static func retype(grid: WaterGrid, body: WaterBody, new_type: WaterBody.Type) -> WaterBodyEdit:
	var edit := WaterBodyEdit.new()
	edit.kind = Kind.RETYPE
	edit._body_snapshot = body.duplicate_body() if body != null else null
	var replacement := WaterBody.of_type(body.id, new_type)
	replacement.surface_height = body.surface_height
	replacement.name = body.name
	# Changing liquid type changes material and gameplay flags, not the authored
	# current. Lava may flow too, and switching a river to lava and back must not
	# silently erase its per-cell direction/strength map.
	replacement.flow = body.flow.duplicate(true)
	edit._new_body = replacement
	if grid != null:
		for cell: Vector2i in grid.cells_of_body(body.id):
			edit.cells.append(cell)
	return edit


## Replaces a body's complete wet footprint with one surface.  A WaterBody has
## one authored level: cells are its extent, never independent little puddles.
## Recording the metadata and cells together makes level changes properly
## undoable and prevents the registry's displayed level drifting from the mesh.
static func resurface(grid: WaterGrid, terrain: TerrainGrid, body: WaterBody, cells_at_level: Array[Vector2i], level: int) -> WaterBodyEdit:
	var edit := WaterBodyEdit.new()
	edit.kind = Kind.RESURFACE
	edit._body_snapshot = body.duplicate_body() if body != null else null
	if body == null:
		return edit
	edit._new_body = body.duplicate_body()
	edit._new_body.surface_height = level
	var next_cells: Dictionary = {}
	for cell: Vector2i in cells_at_level:
		next_cells[cell] = true
	# Current belongs to a water footprint just as much as ice does. Once a bank
	# retracts or a body splits, flow entries outside its remaining cells must not
	# linger in the registry and unexpectedly return on a later re-flood.
	var next_flow: Dictionary = {}
	for cell: Vector2i in next_cells:
		if edit._new_body.flow.has(cell):
			next_flow[cell] = edit._new_body.flow[cell]
	edit._new_body.flow = next_flow
	var affected: Dictionary = {}
	for cell: Vector2i in grid.cells_of_body(body.id):
		affected[cell] = true
	for cell: Vector2i in next_cells:
		affected[cell] = true
	var ordered: Array[Vector2i] = []
	for cell: Vector2i in affected:
		ordered.append(cell)
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	for cell: Vector2i in ordered:
		var old_state := WaterDelta.state_of(grid, cell)
		var becomes_wet := next_cells.has(cell) and (terrain == null or terrain.height_of(cell) < level)
		# Re-evaluating an unchanged shoreline must not thaw it.  A border ocean
		# runs this after every terrain stroke, while a changed body or water level
		# still deliberately clears ice because that sheet described the old surface.
		var kept_flags := old_state[WaterDelta.STATE_FLAGS] if (
			old_state[WaterDelta.STATE_BODY] == body.id
			and old_state[WaterDelta.STATE_HEIGHT] == level
		) else 0
		var next_state := WaterDelta.make_state(body.id, level, kept_flags) if becomes_wet else WaterDelta.dry_state()
		if old_state != next_state:
			edit.record(cell, old_state, next_state)
	return edit


func apply(grid: WaterGrid) -> void:
	if grid == null or _body_snapshot == null:
		return
	match kind:
		Kind.CREATE:
			grid.add_body(_body_snapshot.duplicate_body())
			super.apply(grid)
		Kind.REMOVE:
			grid.remove_body(_body_snapshot.id)
		Kind.RETYPE:
			if _new_body != null:
				grid.replace_body(_body_snapshot.id, _new_body.duplicate_body())
		Kind.RESURFACE:
			if _new_body != null:
				grid.replace_body(_body_snapshot.id, _new_body.duplicate_body())
			super.apply(grid)


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
		Kind.RESURFACE:
			super.revert(grid)
			grid.replace_body(_body_snapshot.id, _body_snapshot.duplicate_body())
