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
## Registry edits (adding, removing, retyping a body) are deliberately NOT on the
## undo stack. A body is an authored object with a name, a colour and a fish
## stock, edited in a side panel like a building blueprint; the stack is for
## strokes over the board. Removing a body does dry its cells, and that is why
## `remove_body` clears the history rather than leaving entries that would restore
## cells pointing at a body which no longer exists.

const MAX_UNDO_STEPS := 128

const REASON_NONE: StringName = &"none"
const REASON_NO_GRID: StringName = &"no_grid"
const REASON_NO_BODY: StringName = &"no_body"
const REASON_NOTHING_TO_DO: StringName = &"nothing_to_do"
const REASON_NOT_FREEZABLE: StringName = &"not_freezable"

signal edit_committed(delta: WaterDelta)
signal edit_rejected(reason: StringName)
## The registry changed shape: a body was added, removed or retyped. Presentation
## caches its per-body materials, so it has to hear about this separately from a
## cell edit.
signal registry_changed()

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


func undo_depth() -> int:
	return _undo_stack.size()


func redo_depth() -> int:
	return _redo_stack.size()


# --- Registry -----------------------------------------------------------------

func create_body(body_type: WaterBody.Type, surface_height := 0) -> WaterBody:
	if grid == null:
		_reject(REASON_NO_GRID)
		return null
	var body := grid.create_body(body_type, surface_height)
	if body != null:
		registry_changed.emit()
	return body


## Drops a body and every cell of it. The undo stack goes with it: entries below
## may reference the body, and restoring a cell into a body that is gone is the
## one state the layer must never reach.
func remove_body(body_id: int) -> bool:
	if grid == null:
		return _reject(REASON_NO_GRID)
	if not grid.remove_body(body_id):
		return _reject(REASON_NO_BODY)
	clear_history()
	registry_changed.emit()
	return true


func notify_body_edited() -> void:
	registry_changed.emit()


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
	return paint(cells, body_id, level)


func erase(cells: Array[Vector2i]) -> bool:
	if grid == null:
		return _reject(REASON_NO_GRID)
	var delta := WaterDelta.new()
	for cell: Vector2i in CellUtils.sorted_unique(cells):
		if not grid.is_inside(cell) or not grid.has_water(cell):
			continue
		delta.record(cell, WaterDelta.state_of(grid, cell), WaterDelta.dry_state())
	return _commit_or_reject(delta)


## Raises or lowers the surface of the cells already painted, without changing
## which body they belong to. Absolute, so it is idempotent under a drag that
## crosses its own path — the rule every brush in this project follows.
func set_level(cells: Array[Vector2i], level: int) -> bool:
	if grid == null:
		return _reject(REASON_NO_GRID)
	if level < WaterGrid.MIN_HEIGHT or level > WaterGrid.MAX_HEIGHT:
		return _reject(REASON_NOTHING_TO_DO)
	var delta := WaterDelta.new()
	for cell: Vector2i in CellUtils.sorted_unique(cells):
		if not grid.is_inside(cell) or not grid.has_water(cell):
			continue
		var old_state := WaterDelta.state_of(grid, cell)
		var body_id: int = old_state[WaterDelta.STATE_BODY]
		var new_state := WaterDelta.make_state(body_id, level, _kept_flags(old_state, body_id, level))
		if old_state == new_state:
			continue
		delta.record(cell, old_state, new_state)
	return _commit_or_reject(delta)


## Freezes or thaws cells (§9.6). Geometry does not change at all — this only
## flips the state the water shader and the navigation field read — but it IS a
## passability change, which is why it is a transaction and republishes.
##
## Cells whose body cannot freeze (lava, a fast river reach, a body flagged as
## never freezing) are skipped, so one call over a whole lake produces exactly the
## natural result: the still water sets and the current stays open.
func set_frozen(cells: Array[Vector2i], frozen: bool, thickness: int = WaterGrid.MAX_ICE_THICKNESS) -> bool:
	if grid == null:
		return _reject(REASON_NO_GRID)
	var delta := WaterDelta.new()
	var refused_any := false
	for cell: Vector2i in CellUtils.sorted_unique(cells):
		if not grid.is_inside(cell) or not grid.has_water(cell):
			continue
		var body := grid.body_at(cell)
		if frozen and (body == null or not body.can_freeze_at(cell)):
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
	if grid == null or _undo_stack.is_empty():
		return false
	var delta: WaterDelta = _undo_stack.pop_back()
	delta.revert(grid)
	_redo_stack.push_back(delta)
	_last_delta = delta
	edit_committed.emit(delta)
	return true


func redo() -> bool:
	if grid == null or _redo_stack.is_empty():
		return false
	var delta: WaterDelta = _redo_stack.pop_back()
	delta.apply(grid)
	_undo_stack.push_back(delta)
	_last_delta = delta
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
