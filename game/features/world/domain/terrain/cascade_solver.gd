class_name CascadeSolver
extends RefCounted

## Angle-of-repose cascade (design_docs/engine/grid_terrain_system.md §4).
##
## Pure algorithm: reads a `TerrainGrid`, writes nothing, returns a `TerrainDelta`
## to commit or `null` to refuse. Everything happens on a `TerrainWorkingRegion`,
## so a refusal leaves the grid untouched and a success is a single atomic commit
## with a free undo record.
##
## The wave is a rational cone, not a per-cell step limit. Each material states
## how much height it holds per cell (§4.2): rock 4 steps, earth and grass 1,
## sand half a step. Since columns are integers, half a step per cell cannot be a
## per-neighbour rule — it means a step every two cells. So the wave carries a
## fractional limit outward and stores the rounded height, which turns sand into
## wide terraces and grass into a clean pyramid, with the data staying integer.
##
## Once the columns have settled, `SlopeAssigner` (§3.2, §4.5) decorates the
## boundaries the operation disturbed. That step is part of the same transaction:
## the slope descriptors it writes are in the same delta as the heights.
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
var _region: TerrainWorkingRegion = null
## Fractional height limit the wave carries, per cell.
var _limits: Dictionary = {}
var _pending: Dictionary = {}
## Every column whose height this operation moved — the seeds of the slope pass.
var _moved: Dictionary = {}
var _processed := 0
var _requested_slope_class := RampConnectionPlan.AUTO_CLASS


## Convenience for callers that only care about the outcome (§14: `(grid, op) -> delta | null`).
static func solve_operation(grid: TerrainGrid, operation: TerrainEditOperation) -> TerrainDelta:
	return CascadeSolver.new().solve(grid, operation)


## Returns the delta to commit, or null when the operation is refused;
## `rejection_reason` then says why.
func solve(grid: TerrainGrid, operation: TerrainEditOperation) -> TerrainDelta:
	rejection_reason = REASON_NONE
	_grid = grid
	_limits = {}
	_pending = {}
	_moved = {}
	_processed = 0
	_requested_slope_class = RampConnectionPlan.AUTO_CLASS
	if grid == null or operation == null or operation.cells.is_empty():
		rejection_reason = REASON_NOTHING_TO_DO
		return null
	_requested_slope_class = operation.slope_class if SlopeCatalog.is_ramp_class(operation.slope_class) else RampConnectionPlan.AUTO_CLASS
	_region = TerrainWorkingRegion.new(grid)

	var raised: Array[Vector2i] = []
	var lowered: Array[Vector2i] = []
	if not _apply_brush(operation, raised, lowered):
		return null

	if operation.mode != TerrainEditOperation.Mode.TERRACE:
		if not _cascade(raised, 1):
			return null
		if not _cascade(lowered, -1):
			return null
		# Terrace mode wants the bare vertical face and says so (§4.1); every
		# other mode gets the gentlest slope that fits (§3.2), which for Level is
		# exactly the auto-skirt of §4.5.
		SlopeAssigner.assign_slopes(_region, _moved_cells(), _requested_slope_class)

	return _build_delta()


# --- Brush ------------------------------------------------------------------

func _apply_brush(operation: TerrainEditOperation, raised: Array[Vector2i], lowered: Array[Vector2i]) -> bool:
	for cell: Vector2i in operation.cells:
		if not _region.is_inside(cell):
			rejection_reason = REASON_OUT_OF_BOUNDS
			return false
		if _region.is_anchor(cell):
			rejection_reason = REASON_ANCHOR
			return false
		if _region.is_hole(cell):
			rejection_reason = REASON_HOLE
			return false
		var current := _region.height_of(cell)
		var target := current + operation.height_delta
		if operation.mode == TerrainEditOperation.Mode.LEVEL:
			target = operation.target_height
		if target == current:
			# A ramp cell levelled to the height it already has still loses its
			# slope: the brush asked for flat ground.
			if _region.is_ramp_cell(cell):
				_move_column(cell, target)
			continue
		if target < TerrainGrid.MIN_HEIGHT or target > TerrainGrid.MAX_HEIGHT:
			rejection_reason = REASON_HEIGHT_LIMIT
			return false
		_move_column(cell, target)
		if target > current:
			raised.append(cell)
		else:
			lowered.append(cell)
	if raised.is_empty() and lowered.is_empty() and _moved.is_empty():
		rejection_reason = REASON_NOTHING_TO_DO
		return false
	return true


## Moves one column in the working copy, dissolving every ramp that move
## invalidates (§3.1): the one the column belongs to and the ones climbing to it.
func _move_column(cell: Vector2i, height: int) -> void:
	_region.dissolve_ramps_touching(cell)
	_region.clear_slope(cell)
	_region.set_height(cell, height)
	_moved[cell] = true


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
		_limits[cell] = float(_region.height_of(cell))
		_pending[cell] = true

	while not _pending.is_empty():
		# Sorted rounds, not dictionary insertion order: the same edit must give
		# the same terrain on every machine (§4.4).
		var wave := _sorted_cells(_pending)
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
		if not _region.is_inside(neighbour) or _region.is_hole(neighbour):
			continue
		var repose := (
			SlopeCatalog.steps_per_cell_of_class(_requested_slope_class)
			if SlopeCatalog.is_ramp_class(_requested_slope_class)
			else TerrainMaterialCatalog.repose_steps_per_cell_of_index(_region.material_index_at(neighbour))
		)
		if is_inf(repose):
			continue
		var allowed := limit - repose * float(direction)
		var current := _region.height_of(neighbour)
		var required := 0
		if direction > 0:
			required = ceili(allowed - EPSILON)
			if current >= required:
				continue
		else:
			required = floori(allowed + EPSILON)
			if current <= required:
				continue
		if _region.is_anchor(neighbour):
			# The ground under a building may not sag silently: the whole
			# operation is refused instead (§4.4).
			rejection_reason = REASON_ANCHOR
			return false
		if required < TerrainGrid.MIN_HEIGHT or required > TerrainGrid.MAX_HEIGHT:
			rejection_reason = REASON_HEIGHT_LIMIT
			return false
		_move_column(neighbour, required)
		# The limit keeps the fraction the height had to drop; that is what makes
		# a half-step-per-cell material terrace instead of stair-stepping.
		_limits[neighbour] = allowed
		_pending[neighbour] = true
	return true


func _sorted_cells(source: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in source:
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return cells


func _moved_cells() -> Array[Vector2i]:
	return _sorted_cells(_moved)


# --- Result -----------------------------------------------------------------

## Snapshots the whole state of every column the working copy touched, and drops
## the ones that ended up identical to what the grid already holds.
func _build_delta() -> TerrainDelta:
	var delta := TerrainDelta.new()
	for cell: Vector2i in _region.touched_cells():
		var old_state := TerrainDelta.state_of(_grid, cell)
		var new_state := _region.state_of(cell)
		if old_state == new_state:
			continue
		delta.record(cell, old_state, new_state)
	if delta.is_empty():
		rejection_reason = REASON_NOTHING_TO_DO
		return null
	return delta
