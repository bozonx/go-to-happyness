class_name CascadeSolver
extends RefCounted

## Angle-of-repose cascade (design_docs/core/grid_terrain_system.md §4).
##
## Pure algorithm: reads a `TerrainGrid`, writes nothing, returns a `TerrainDelta`
## to commit or `null` to refuse. Everything happens on a working copy of the
## touched region, so a refusal leaves the grid untouched and a success is a
## single atomic commit with a free undo record.
##
## The wave is a rational cone, not a per-cell step limit. Each material states
## how much height it holds per cell (§4.2): rock 4 steps, earth and grass 1,
## sand half a step. Since columns are integers, half a step per cell cannot be a
## per-neighbour rule — it means a step every two cells. So the wave carries a
## fractional limit outward and stores the rounded height, which turns sand into
## wide terraces and grass into a clean pyramid, with the data staying integer.
##
## Rejection is a normal answer, not an error: anchors (ground under a building or
## a road) are never moved, and an operation whose wave reaches one is refused as a
## whole rather than applied in part.

const REASON_NONE := &""
const REASON_ANCHOR := &"anchor"
const REASON_HEIGHT_LIMIT := &"height_limit"
const REASON_BUDGET := &"budget"
const REASON_OUT_OF_BOUNDS := &"out_of_bounds"
const REASON_HOLE := &"hole"
const REASON_NOTHING_TO_DO := &"nothing_to_do"

## Hard stop from §4.4: an operation may not touch more cells than this.
const MAX_PROCESSED_CELLS := 10000
const EPSILON := 0.0001

var rejection_reason: StringName = REASON_NONE

var _grid: TerrainGrid = null
## Working copy of the region: cell -> height. Absent means "unchanged, read the grid".
var _working: Dictionary = {}
## Fractional height limit the wave carries, per cell.
var _limits: Dictionary = {}
var _pending: Dictionary = {}
var _processed := 0


## Convenience for callers that only care about the outcome (§14: `(grid, op) -> delta | null`).
static func solve_operation(grid: TerrainGrid, operation: TerrainEditOperation) -> TerrainDelta:
	return CascadeSolver.new().solve(grid, operation)


## Returns the delta to commit, or null when the operation is refused;
## `rejection_reason` then says why.
func solve(grid: TerrainGrid, operation: TerrainEditOperation) -> TerrainDelta:
	rejection_reason = REASON_NONE
	_grid = grid
	_working = {}
	_limits = {}
	_pending = {}
	_processed = 0
	if grid == null or operation == null or operation.cells.is_empty():
		rejection_reason = REASON_NOTHING_TO_DO
		return null

	var raised: Array[Vector2i] = []
	var lowered: Array[Vector2i] = []
	if not _apply_brush(operation, raised, lowered):
		return null

	if operation.mode != TerrainEditOperation.Mode.TERRACE:
		if not _cascade(raised, 1):
			return null
		if not _cascade(lowered, -1):
			return null

	return _build_delta()


# --- Brush ------------------------------------------------------------------

func _apply_brush(operation: TerrainEditOperation, raised: Array[Vector2i], lowered: Array[Vector2i]) -> bool:
	for cell: Vector2i in operation.cells:
		if not _grid.is_inside(cell):
			rejection_reason = REASON_OUT_OF_BOUNDS
			return false
		if _grid.is_anchor(cell):
			rejection_reason = REASON_ANCHOR
			return false
		if _grid.is_hole(cell):
			rejection_reason = REASON_HOLE
			return false
		var current := _height_of(cell)
		var target := current + operation.height_delta
		if operation.mode == TerrainEditOperation.Mode.LEVEL:
			target = operation.target_height
		if target == current:
			continue
		if target < TerrainGrid.MIN_HEIGHT or target > TerrainGrid.MAX_HEIGHT:
			rejection_reason = REASON_HEIGHT_LIMIT
			return false
		_working[cell] = target
		if target > current:
			raised.append(cell)
		else:
			lowered.append(cell)
	if raised.is_empty() and lowered.is_empty():
		rejection_reason = REASON_NOTHING_TO_DO
		return false
	return true


# --- Cascade ----------------------------------------------------------------

## `direction` is +1 for the wave that lifts the flanks of a raised column and -1
## for the wave that pulls the rim of a pit down. Both are the same relaxation,
## mirrored.
func _cascade(seeds: Array[Vector2i], direction: int) -> bool:
	if seeds.is_empty():
		return true
	_limits = {}
	_pending = {}
	for cell: Vector2i in seeds:
		_limits[cell] = float(_height_of(cell))
		_pending[cell] = true

	while not _pending.is_empty():
		# Sorted rounds, not dictionary insertion order: the same edit must give
		# the same terrain on every machine (§4.4).
		var wave := _sorted_pending()
		_pending = {}
		for cell: Vector2i in wave:
			_processed += 1
			if _processed > MAX_PROCESSED_CELLS:
				rejection_reason = REASON_BUDGET
				return false
			if not _relax_neighbours(cell, direction):
				return false
	return true


func _relax_neighbours(cell: Vector2i, direction: int) -> bool:
	var limit: float = _limits[cell]
	for neighbour_direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
		var neighbour := cell + SlopeCatalog.direction_offset(neighbour_direction)
		if not _grid.is_inside(neighbour) or _grid.is_hole(neighbour):
			continue
		var repose := TerrainMaterialCatalog.repose_steps_per_cell_of(_grid.material_of(neighbour))
		if is_inf(repose):
			continue
		var allowed := limit - repose * float(direction)
		var current := _height_of(neighbour)
		var required := 0
		if direction > 0:
			required = ceili(allowed - EPSILON)
			if current >= required:
				continue
		else:
			required = floori(allowed + EPSILON)
			if current <= required:
				continue
		if _grid.is_anchor(neighbour):
			# The ground under a building may not sag silently: the whole
			# operation is refused instead (§4.4).
			rejection_reason = REASON_ANCHOR
			return false
		if required < TerrainGrid.MIN_HEIGHT or required > TerrainGrid.MAX_HEIGHT:
			rejection_reason = REASON_HEIGHT_LIMIT
			return false
		_working[neighbour] = required
		# The limit keeps the fraction the height had to drop; that is what makes
		# a half-step-per-cell material terrace instead of stair-stepping.
		_limits[neighbour] = allowed
		_pending[neighbour] = true
	return true


func _sorted_pending() -> Array[Vector2i]:
	var wave: Array[Vector2i] = []
	for cell: Vector2i in _pending:
		wave.append(cell)
	wave.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return wave


# --- Result -----------------------------------------------------------------

## Expands the changed set with the ramps it broke, then snapshots before/after.
## A ramp is one object spanning several cells (§3.1), so moving any of its cells
## dissolves all of them; recording the whole group is what lets undo restore it.
func _build_delta() -> TerrainDelta:
	var changed: Dictionary = {}
	for cell: Vector2i in _working:
		if _working[cell] == _grid.height_of(cell) and not _grid.is_ramp_cell(cell):
			continue
		changed[cell] = true
	for cell: Vector2i in changed.keys():
		for ramp_cell: Vector2i in _grid.ramp_cells_at(cell):
			changed[ramp_cell] = true

	var delta := TerrainDelta.new()
	var cells: Array[Vector2i] = []
	for cell: Vector2i in changed:
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for cell: Vector2i in cells:
		var old_state := TerrainDelta.state_of(_grid, cell)
		# Cells only pulled in by a dissolved ramp keep their height and lose the
		# slope descriptor; flat is class 0 with no direction and no index.
		var new_state := Vector4i(_height_of(cell), 0, 0, 0)
		if old_state == new_state:
			continue
		delta.record(cell, old_state, new_state)
	if delta.is_empty():
		rejection_reason = REASON_NOTHING_TO_DO
		return null
	return delta


func _height_of(cell: Vector2i) -> int:
	return _working.get(cell, _grid.height_of(cell))
