class_name WaterService
extends RefCounted

## Transaction boundary for the water layer (grid_terrain_system.md §9).
##
## The same contract `TerrainService` has over the ground: tools describe what
## they want, this commits it in one piece and keeps the undo history, and nobody
## writes into `WaterGrid` behind it. An edit undo cannot see is worse than no
## undo at all — and here it is worse still, because water changes passability and
## a stale navigation field is a citizen walking into a lake.
##
## Registry edits are transactions too. Removing a body drains all of its cells,
## so excluding it from the editor's one undo stack would make Ctrl+Z lie.

const MAX_UNDO_STEPS := 128

const REASON_NONE: StringName = &"none"
const REASON_NO_GRID: StringName = &"no_grid"
const REASON_NO_BODY: StringName = &"no_body"
const REASON_NOTHING_TO_DO: StringName = &"nothing_to_do"
const REASON_NOT_FREEZABLE: StringName = &"not_freezable"
const REASON_FLOW_REQUIRES_RIVER: StringName = &"flow_requires_river"

signal edit_committed(delta: WaterDelta)
signal edit_rejected(reason: StringName)
## The registry changed shape: a body was added, removed or retyped.
##
## It carries the cells the change actually reaches, and that argument is the
## whole point of the signal being separate from `edit_committed`. Adding an empty
## body reaches nothing: republishing the board for it cost 2.5 s on a 256×256
## map, to add one entry to a dictionary. Removing one reaches exactly its own
## cells. Presentation still drops its cached per-body material either way,
## because that cache is keyed by id and not by cell.
signal registry_changed(affected_cells: Array[Vector2i])

var grid: WaterGrid = null
## Read-only here. Water needs the ground for depth, for flood fill and for
## refusing to stand above a column that is already higher than the surface.
var terrain: TerrainGrid = null

var _undo_stack: Array[WaterDelta] = []
var _redo_stack: Array[WaterDelta] = []
var _last_rejection: StringName = REASON_NONE
var _last_delta: WaterDelta = null


func configure(next_grid: WaterGrid, next_terrain: TerrainGrid) -> void:
	grid = next_grid
	terrain = next_terrain
	clear_history()


func clear_history() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_last_delta = null
	_last_rejection = REASON_NONE


func last_rejection() -> StringName:
	return _last_rejection


func last_delta_size() -> int:
	return 0 if _last_delta == null else _last_delta.size()


## The delta most recently committed or replayed.  Composite editor commands
## use it to bind a border-ocean fill to this exact water transaction.
func last_delta() -> WaterDelta:
	return _last_delta


func undo_depth() -> int:
	return _undo_stack.size()


func redo_depth() -> int:
	return _redo_stack.size()


# --- Registry -----------------------------------------------------------------

func create_body(body_type: WaterBody.Type, surface_height := 0) -> WaterBody:
	if grid == null:
		_reject(REASON_NO_GRID)
		return null
	var next_id := grid.next_free_body_id()
	if next_id == WaterBody.NO_BODY:
		_reject(REASON_NOTHING_TO_DO)
		return null
	var body := WaterBody.of_type(next_id, body_type)
	body.surface_height = surface_height
	_commit_registry_edit(WaterBodyEdit.creation(body))
	return grid.body(body.id)


## Drops a body and every cell of it as one undoable operation.
func remove_body(body_id: int) -> bool:
	if grid == null:
		return _reject(REASON_NO_GRID)
	var body := grid.body(body_id)
	if body == null:
		return _reject(REASON_NO_BODY)
	return _commit_registry_edit(WaterBodyEdit.removal(grid, body))


## Changes a body's type in place: the id and cells stay, the metadata changes.
## One undoable operation that emits registry_changed so the presentation drops
## its cached per-body material.
func retype_body(body_id: int, new_type: WaterBody.Type) -> bool:
	if grid == null:
		return _reject(REASON_NO_GRID)
	var body := grid.body(body_id)
	if body == null:
		return _reject(REASON_NO_BODY)
	if body.type == new_type:
		return _reject(REASON_NOTHING_TO_DO)
	return _commit_registry_edit(WaterBodyEdit.retype(grid, body, new_type))


# --- Strokes ------------------------------------------------------------------

## Paints cells into a body at a level.
##
## Columns already at or above the surface are skipped rather than refused: an
## author drags a level across uneven ground constantly, and painting water that
## stands zero deep on a bank would put a wet cell on dry land. A stroke that
## touches only banks changes nothing and says so.
func paint(cells: Array[Vector2i], body_id: int, level: int) -> bool:
	if grid == null:
		return _reject(REASON_NO_GRID)
	if not grid.has_body(body_id):
		return _reject(REASON_NO_BODY)
	if level < WaterGrid.MIN_HEIGHT or level > WaterGrid.MAX_HEIGHT:
		return _reject(REASON_NOTHING_TO_DO)
	var delta := WaterDelta.new()
	for cell: Vector2i in CellUtils.sorted_unique(cells):
		if not grid.is_inside(cell) or _is_dry_ground(cell, level):
			continue
		var old_state := WaterDelta.state_of(grid, cell)
		# Freezing does not survive a level change: the sheet the flags described
		# covered a surface that is no longer there. A seasonal pass refreezes.
		var new_state := WaterDelta.make_state(body_id, level, _kept_flags(old_state, body_id, level))
		if old_state == new_state:
			continue
		delta.record(cell, old_state, new_state)
	return _commit_or_reject(delta)


## Fills the basin under `seed` up to `level` in one operation (§9.1). This is the
## only "spreading" water ever does, and it happens here, at edit time, over a
## copy — never per frame.
func flood(seed: Vector2i, body_id: int, level: int) -> bool:
	if grid == null or terrain == null:
		return _reject(REASON_NO_GRID)
	if not grid.has_body(body_id):
		return _reject(REASON_NO_BODY)
	var cells := grid.flood_cells(terrain, seed, level, body_id)
	if cells.is_empty():
		return _reject(REASON_NOTHING_TO_DO)
	return _resurface_body(body_id, cells, level)


## Floods every low area connected to the board edge.  This is the authored
## ocean boundary: unlike `flood`, it deliberately has no inland seed, so a
## closed depression remains dry until its author chooses to fill it.
func flood_from_edges(body_id: int, level: int) -> bool:
	if grid == null or terrain == null:
		return _reject(REASON_NO_GRID)
	if not grid.has_body(body_id):
		return _reject(REASON_NO_BODY)
	if level < WaterGrid.MIN_HEIGHT or level > WaterGrid.MAX_HEIGHT:
		return _reject(REASON_NOTHING_TO_DO)
	var delta := WaterDelta.new()
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = []
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for x in range(minimum.x, maximum.x + 1):
		_queue_ocean_cell(Vector2i(x, minimum.y), level, body_id, seen, queue)
		_queue_ocean_cell(Vector2i(x, maximum.y), level, body_id, seen, queue)
	for z in range(minimum.y + 1, maximum.y):
		_queue_ocean_cell(Vector2i(minimum.x, z), level, body_id, seen, queue)
		_queue_ocean_cell(Vector2i(maximum.x, z), level, body_id, seen, queue)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		var old_state := WaterDelta.state_of(grid, cell)
		var new_state := WaterDelta.make_state(body_id, level, _kept_flags(old_state, body_id, level))
		if old_state != new_state:
			delta.record(cell, old_state, new_state)
		for offset: Vector2i in WaterGrid.ORTHOGONAL_OFFSETS:
			_queue_ocean_cell(cell + offset, level, body_id, seen, queue)
	return _commit_or_reject(delta)


func _queue_ocean_cell(cell: Vector2i, level: int, body_id: int, seen: Dictionary, queue: Array[Vector2i]) -> void:
	if seen.has(cell) or not grid.is_inside(cell):
		return
	seen[cell] = true
	if terrain.is_hole(cell) or terrain.height_of(cell) >= level:
		return
	var occupant := grid.body_id_at(cell)
	if occupant != WaterBody.NO_BODY and occupant != body_id:
		return
	queue.append(cell)


## Raises or lowers one whole water body.  A body cannot contain multiple water
## levels; lowering also removes columns whose ground is now at or above the
## surface.  Expanding a shoreline is explicitly Flood, from a chosen seed.
func set_body_level(body_id: int, level: int) -> bool:
	if grid == null:
		return _reject(REASON_NO_GRID)
	if level < WaterGrid.MIN_HEIGHT or level > WaterGrid.MAX_HEIGHT:
		return _reject(REASON_NOTHING_TO_DO)
	if not grid.has_body(body_id):
		return _reject(REASON_NO_BODY)
	return _resurface_body(body_id, cells_of_body(body_id), level)


## Freezes or thaws cells (§9.6). Geometry does not change at all — this only
## flips the state the water shader and the navigation field read — but it IS a
## passability change, which is why it is a transaction and republishes.
##
## Cells whose body cannot freeze (lava, a fast river reach, a body flagged as
## never freezing) are skipped unless `force` is set (editor brush tool).
func set_frozen(cells: Array[Vector2i], frozen: bool, thickness: int = WaterGrid.MAX_ICE_THICKNESS, force: bool = false) -> bool:
	if grid == null:
		return _reject(REASON_NO_GRID)
	var delta := WaterDelta.new()
	var refused_any := false
	for cell: Vector2i in CellUtils.sorted_unique(cells):
		if not grid.is_inside(cell) or not grid.has_water(cell):
			continue
		var body := grid.body_at(cell)
		if frozen and not force and (body == null or not body.can_freeze_at(cell)):
			refused_any = true
			continue
		var old_state := WaterDelta.state_of(grid, cell)
		var new_state := WaterDelta.make_state(
			old_state[WaterDelta.STATE_BODY],
			old_state[WaterDelta.STATE_HEIGHT],
			WaterGrid.pack_flags(frozen, thickness),
		)
		if old_state == new_state:
			continue
		delta.record(cell, old_state, new_state)
	if delta.is_empty() and refused_any:
		return _reject(REASON_NOT_FREEZABLE)
	return _commit_or_reject(delta)


## Drains water from specified cells as one undoable transaction.
func drain_cells(cells: Array[Vector2i]) -> bool:
	if grid == null:
		return _reject(REASON_NO_GRID)
	var delta := WaterDelta.new()
	for cell: Vector2i in CellUtils.sorted_unique(cells):
		if not grid.is_inside(cell) or not grid.has_water(cell):
			continue
		var old_state := WaterDelta.state_of(grid, cell)
		var new_state := WaterDelta.make_state(WaterBody.NO_BODY, 0, 0)
		if old_state == new_state:
			continue
		delta.record(cell, old_state, new_state)
	if delta.is_empty():
		return _reject(REASON_NOTHING_TO_DO)
	var ok := _commit_or_reject(delta)
	if ok:
		prune_empty_bodies()
	return ok


## Removes any registered body that has 0 wet cells remaining.
func prune_empty_bodies() -> void:
	if grid == null:
		return
	var empty_ids: Array[int] = []
	for body in grid.bodies():
		if grid.cells_of_body(body.id).is_empty():
			empty_ids.append(body.id)
	for body_id in empty_ids:
		grid.remove_body(body_id)



## Season's worth of freezing or thawing over a whole body, as ONE transaction
## (§9.6): freezing is the single seasonal change that moves passability, so it
## goes through the same commit-and-republish path as an author's stroke instead
## of growing a second write owner.
func set_body_frozen(body_id: int, frozen: bool, thickness: int = WaterGrid.MAX_ICE_THICKNESS) -> bool:
	if grid == null:
		return _reject(REASON_NO_GRID)
	if not grid.has_body(body_id):
		return _reject(REASON_NO_BODY)
	return set_frozen(cells_of_body(body_id), frozen, thickness)


## Sets flow direction and strength on cells of a body, as one undoable
## transaction. Flow lives on the `WaterBody`, not on the grid cells, so this
## produces a `WaterFlowEdit` rather than a `WaterDelta` — but it rides the same
## undo stack and emits the same `edit_committed` signal, which is what keeps
## the editor's shared undo and the navigation publisher in step.
func set_flow(cells: Array[Vector2i], body_id: int, direction: int, strength: int) -> bool:
	if grid == null:
		return _reject(REASON_NO_GRID)
	if not grid.has_body(body_id):
		return _reject(REASON_NO_BODY)
	var body := grid.body(body_id)
	if body == null or body.type != WaterBody.Type.RIVER:
		return _reject(REASON_FLOW_REQUIRES_RIVER)
	var clamped_strength := clampi(strength, 0, WaterBody.MAX_FLOW_STRENGTH)
	var new_flow_value := (direction & WaterBody.FLOW_DIR_MASK) | (clamped_strength << WaterBody.FLOW_STRENGTH_SHIFT)
	var edit_cells: Array[Vector2i] = []
	var old_flows := PackedInt32Array()
	var new_flows := PackedInt32Array()
	for cell: Vector2i in CellUtils.sorted_unique(cells):
		if not grid.is_inside(cell) or grid.body_id_at(cell) != body_id:
			continue
		var old_value := int(body.flow.get(cell, 0))
		if old_value == new_flow_value:
			continue
		edit_cells.append(cell)
		old_flows.append(old_value)
		new_flows.append(new_flow_value)
	if edit_cells.is_empty():
		return _reject(REASON_NOTHING_TO_DO)
	var edit := WaterFlowEdit.create(body_id, edit_cells, old_flows, new_flows)
	edit.apply(grid)
	_undo_stack.push_back(edit)
	if _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_last_rejection = REASON_NONE
	edit_committed.emit(edit)
	return true


func cells_of_body(body_id: int) -> Array[Vector2i]:
	if grid == null:
		return []
	return grid.cells_of_body(body_id)


# --- History ------------------------------------------------------------------

func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo() -> bool:
	return undo_delta()


## Revert the exact delta recorded by an editor command.  This prevents a
## stale command from operating on a different water edit after histories move.
func undo_delta(expected: WaterDelta = null) -> bool:
	if grid == null or _undo_stack.is_empty():
		return false
	var delta: WaterDelta = _undo_stack.pop_back()
	if expected != null and delta != expected:
		_undo_stack.push_back(delta)
		return false
	delta.revert(grid)
	_redo_stack.push_back(delta)
	_last_delta = delta
	if delta is WaterBodyEdit:
		registry_changed.emit(delta.cells)
	edit_committed.emit(delta)
	return true


func redo() -> bool:
	return redo_delta()


## Replay the exact delta recorded by an editor command. See `undo_delta`.
func redo_delta(expected: WaterDelta = null) -> bool:
	if grid == null or _redo_stack.is_empty():
		return false
	var delta: WaterDelta = _redo_stack.pop_back()
	if expected != null and delta != expected:
		_redo_stack.push_back(delta)
		return false
	delta.apply(grid)
	_undo_stack.push_back(delta)
	_last_delta = delta
	if delta is WaterBodyEdit:
		registry_changed.emit(delta.cells)
	edit_committed.emit(delta)
	return true


# --- Internals ----------------------------------------------------------------

func _commit_or_reject(delta: WaterDelta) -> bool:
	if delta.is_empty():
		return _reject(REASON_NOTHING_TO_DO)
	delta.apply(grid)
	_last_delta = delta
	_undo_stack.push_back(delta)
	if _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_last_rejection = REASON_NONE
	edit_committed.emit(delta)
	return true


func _commit_registry_edit(edit: WaterBodyEdit) -> bool:
	if edit == null:
		return _reject(REASON_NOTHING_TO_DO)
	edit.apply(grid)
	_last_delta = edit
	_undo_stack.push_back(edit)
	if _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_last_rejection = REASON_NONE
	registry_changed.emit(edit.cells)
	edit_committed.emit(edit)
	return true


func _resurface_body(body_id: int, cells: Array[Vector2i], level: int) -> bool:
	var body := grid.body(body_id)
	if body == null:
		return _reject(REASON_NO_BODY)
	var edit := WaterBodyEdit.resurface(grid, terrain, body, cells, level)
	# A new empty body may receive no cells when its seed was invalid; existing
	# bodies may still need their metadata level updated.
	if edit.is_empty() and body.surface_height == level:
		return _reject(REASON_NOTHING_TO_DO)
	# The body remains the same registry entry; only its authored surface and
	# cells changed. `edit_committed` republishes those cells, while
	# `registry_changed` stays reserved for add/remove/retype cache invalidation.
	return _commit_or_reject(edit)


func _reject(reason: StringName) -> bool:
	_last_rejection = reason
	edit_rejected.emit(reason)
	return false


## Ground standing at or above the surface the stroke would paint. Not water, so
## not painted.
func _is_dry_ground(cell: Vector2i, level: int) -> bool:
	return terrain != null and terrain.height_of(cell) >= level


## Ice survives a stroke only when it changes neither the body nor the level. Any
## other stroke replaced the surface the sheet was on.
func _kept_flags(old_state: PackedInt32Array, body_id: int, level: int) -> int:
	if old_state[WaterDelta.STATE_BODY] == body_id and old_state[WaterDelta.STATE_HEIGHT] == level:
		return old_state[WaterDelta.STATE_FLAGS]
	return 0
