class_name TerrainService
extends RefCounted

## Transaction boundary for terrain editing (design_docs/core/grid_terrain_system.md §14).
##
## Tools describe what they want as a `TerrainEditOperation`; this service runs it
## through the solver, commits it in one piece, and keeps the undo history. Tools
## never write to the grid directly, which is what keeps "computed on a copy,
## applied as one commit" (§4.4) true for every path.
##
## Ramp placement goes through here as well, so a ramp is undoable like any other
## edit rather than a side door into the grid.

const MAX_UNDO_STEPS := 128

signal edit_committed(delta: TerrainDelta)
signal edit_rejected(reason: StringName)

var grid: TerrainGrid = null

var _undo_stack: Array[TerrainDelta] = []
var _redo_stack: Array[TerrainDelta] = []
var _last_rejection: StringName = CascadeSolver.REASON_NONE
var _last_delta: TerrainDelta = null


func configure(next_grid: TerrainGrid) -> void:
	grid = next_grid
	clear_history()


func clear_history() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_last_delta = null
	_last_rejection = CascadeSolver.REASON_NONE


func last_rejection() -> StringName:
	return _last_rejection


## How many columns the last committed edit actually moved — the honest measure of
## how far a cascade spread, which tools show instead of the brush size.
func last_delta_size() -> int:
	return 0 if _last_delta == null else _last_delta.size()


func undo_depth() -> int:
	return _undo_stack.size()


func redo_depth() -> int:
	return _redo_stack.size()


## Runs one height operation. Returns false when the solver refused it; the grid
## is then guaranteed untouched and `last_rejection()` explains why.
func apply_operation(operation: TerrainEditOperation) -> bool:
	if grid == null:
		_last_rejection = CascadeSolver.REASON_NOTHING_TO_DO
		return false
	var solver := CascadeSolver.new()
	var delta := solver.solve(grid, operation)
	if delta == null:
		_last_rejection = solver.rejection_reason
		edit_rejected.emit(_last_rejection)
		return false
	_commit(delta)
	return true


## Places one ramp object as a transaction. The grid validates the run itself
## (§3.1); this only records the before/after state so the placement can be undone.
func place_ramp(start_cell: Vector2i, slope_id: StringName, direction: int) -> bool:
	if grid == null or not grid.can_place_ramp(start_cell, slope_id, direction):
		_last_rejection = CascadeSolver.REASON_NOTHING_TO_DO
		edit_rejected.emit(_last_rejection)
		return false
	var offset := SlopeCatalog.direction_offset(direction)
	var run := SlopeCatalog.run_of(slope_id)
	var slope_class := SlopeCatalog.slope_class_of(slope_id)
	var base_height := grid.height_of(start_cell)
	var delta := TerrainDelta.new()
	for step in run:
		var cell := start_cell + offset * step
		delta.record(cell, TerrainDelta.state_of(grid, cell), Vector4i(base_height, slope_class, direction, step))
	_commit(delta)
	return true


## Dissolves the ramp under `cell` back into flat columns, as one undoable step.
func dissolve_ramp(cell: Vector2i) -> bool:
	if grid == null:
		return false
	var ramp_cells := grid.ramp_cells_at(cell)
	if ramp_cells.is_empty():
		_last_rejection = CascadeSolver.REASON_NOTHING_TO_DO
		return false
	var delta := TerrainDelta.new()
	for ramp_cell: Vector2i in ramp_cells:
		delta.record(ramp_cell, TerrainDelta.state_of(grid, ramp_cell), Vector4i(grid.height_of(ramp_cell), 0, 0, 0))
	_commit(delta)
	return true


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo() -> bool:
	if grid == null or _undo_stack.is_empty():
		return false
	var delta: TerrainDelta = _undo_stack.pop_back()
	delta.revert(grid)
	_redo_stack.push_back(delta)
	edit_committed.emit(delta)
	return true


func redo() -> bool:
	if grid == null or _redo_stack.is_empty():
		return false
	var delta: TerrainDelta = _redo_stack.pop_back()
	delta.apply(grid)
	_undo_stack.push_back(delta)
	edit_committed.emit(delta)
	return true


func _commit(delta: TerrainDelta) -> void:
	delta.apply(grid)
	_last_delta = delta
	_undo_stack.push_back(delta)
	if _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.pop_front()
	# A new edit invalidates the redo branch; keeping it would let the player
	# reapply a delta whose "before" state no longer exists.
	_redo_stack.clear()
	_last_rejection = CascadeSolver.REASON_NONE
	edit_committed.emit(delta)
