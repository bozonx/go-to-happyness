class_name CoverageService
extends RefCounted

## Transaction boundary for the coverage layer (map_editor.md §5.2.1).
##
## The same contract `TerrainService` has over the ground and `WaterService` over
## water: tools describe what they want, this commits it in one piece and keeps
## the undo history, and nobody writes into `CoverageLayer` behind it. Coverage
## changes traversal cost, so an edit undo cannot see would leave the navigation
## grid describing a road nobody can see.
##
## **Everything here stamps an absolute value.** There is deliberately no
## "upgrade" or "wear one more step" operation: a drag overlaps its own path, and
## a brush defined as "one better than what is here" would lay a staircase from
## dirt to asphalt along a single stroke (map_editor.md §5.2.1, the same rule the
## wear and water-level brushes already follow).

const MAX_UNDO_STEPS := 128

const REASON_NONE: StringName = &"none"
const REASON_NO_LAYER: StringName = &"no_layer"
const REASON_UNKNOWN_COVERAGE: StringName = &"unknown_coverage"
const REASON_ERA_LOCKED: StringName = &"era_locked"
const REASON_NOT_BUILDABLE: StringName = &"not_buildable"
const REASON_SLOPE_TOO_STEEP: StringName = &"slope_too_steep"
const REASON_NOTHING_TO_DO: StringName = &"nothing_to_do"

signal edit_committed(delta: CoverageDelta)
signal edit_rejected(reason: StringName)

var layer: CoverageLayer = null
## Read-only here. Coverage needs the ground to refuse cells that cannot carry a
## surface at all: a hole has nothing to pave, and open water is not ground.
var terrain: TerrainGrid = null
var water: WaterGrid = null

var _undo_stack: Array[CoverageDelta] = []
var _redo_stack: Array[CoverageDelta] = []
var _last_rejection: StringName = REASON_NONE
var _last_delta: CoverageDelta = null
var _corners_scratch := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


func configure(next_layer: CoverageLayer, next_terrain: TerrainGrid, next_water: WaterGrid = null) -> void:
	layer = next_layer
	terrain = next_terrain
	water = next_water
	clear_history()


func clear_history() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_last_delta = null
	_last_rejection = REASON_NONE


func last_rejection() -> StringName:
	return _last_rejection


func last_delta() -> CoverageDelta:
	return _last_delta


func last_delta_size() -> int:
	return 0 if _last_delta == null else _last_delta.size()


func undo_depth() -> int:
	return _undo_stack.size()


func redo_depth() -> int:
	return _redo_stack.size()


# --- Operations ---------------------------------------------------------------

## Lays coverage over the given cells, absolutely. `detail` carries variant, wear
## and snow in the terrain codec; leaving it at the default paves a clean surface.
##
## `current_era` gates what a settlement may build. The editor passes -1: an
## author works outside the progression, and a map may legitimately start with a
## stone square in the tent era.
func paint(cells: Array[Vector2i], index: int, detail := TerrainDetailCodec.DEFAULT_DETAIL, current_era := -1) -> bool:
	if layer == null:
		return _reject(REASON_NO_LAYER)
	if index == CoverageLayer.NO_COVERAGE:
		return erase(cells)
	if not CoverageCatalog.is_known_index(index):
		return _reject(REASON_UNKNOWN_COVERAGE)
	if current_era >= 0 and current_era < CoverageCatalog.minimum_era_of_index(index):
		return _reject(REASON_ERA_LOCKED)

	var delta := CoverageDelta.new()
	var new_state := CoverageDelta.make_state(index, detail)
	var rejected_reason := REASON_NONE
	for cell: Vector2i in cells:
		var reason := coverage_placement_rejection(cell, index)
		if reason != REASON_NONE:
			rejected_reason = reason
			continue
		var old_state := CoverageDelta.state_of(layer, cell)
		if old_state == new_state:
			continue
		delta.record(cell, old_state, new_state)
	if delta.is_empty() and rejected_reason != REASON_NONE:
		return _reject(rejected_reason)
	return _commit_or_reject(delta)


## Removes coverage, revealing the ground that was under it all along. It does not
## touch the terrain material, and it does not touch the trail layer: an unfaded
## desire line survives the road that was laid over it (`nav_grid._surface_weight`).
func erase(cells: Array[Vector2i]) -> bool:
	if layer == null:
		return _reject(REASON_NO_LAYER)
	var delta := CoverageDelta.new()
	var bare := CoverageDelta.bare_state()
	for cell: Vector2i in cells:
		if not layer.is_inside(cell) or not layer.has_coverage(cell):
			continue
		delta.record(cell, CoverageDelta.state_of(layer, cell), bare)
	return _commit_or_reject(delta)


## Whether a cell can carry a built surface at all. A hole has no ground to pave;
## open water is refused, but a ford or ice is not — a plank walk over a shallow
## crossing is exactly the thing coverage is for, and the water layer keeps
## deciding passability on its own.
func can_carry_coverage(cell: Vector2i, coverage_index := CoverageCatalog.NONE_INDEX) -> bool:
	return coverage_placement_rejection(cell, coverage_index) == REASON_NONE


## Stable preview/query contract used by both the editor brush and the future
## settlement construction tool. The slope is derived from the actual four
## terrain corners, not the stored descriptor: a nominally-flat cell beside a
## ramp may still be tilted by that ramp.
func coverage_placement_rejection(cell: Vector2i, coverage_index: int) -> StringName:
	if layer == null or not layer.is_inside(cell):
		return REASON_NOT_BUILDABLE
	if terrain != null and (not terrain.is_inside(cell) or terrain.is_hole(cell)):
		return REASON_NOT_BUILDABLE
	if water != null and terrain != null and water.is_wet(terrain, cell):
		if not water.is_ford(terrain, cell) and not water.is_frozen(cell):
			return REASON_NOT_BUILDABLE
	if terrain != null and coverage_index != CoverageCatalog.NONE_INDEX:
		var corners := _corners_scratch
		terrain.corner_heights_into(cell, corners)
		var actual_slope := TerrainNavigationPublisher.surface_class_of(corners)
		if actual_slope > CoverageCatalog.max_build_slope_class_of_index(coverage_index):
			return REASON_SLOPE_TOO_STEEP
	return REASON_NONE


# --- History ------------------------------------------------------------------

func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo() -> bool:
	return undo_delta()


## Reverts the top of the stack. `expected` lets the editor's command assert that
## the two stacks are still in step; a mismatch reverts nothing rather than
## quietly undoing somebody else's edit.
func undo_delta(expected: CoverageDelta = null) -> bool:
	if _undo_stack.is_empty() or layer == null:
		return false
	if expected != null and _undo_stack.back() != expected:
		return false
	var delta: CoverageDelta = _undo_stack.pop_back()
	delta.revert(layer)
	_redo_stack.push_back(delta)
	_last_delta = delta
	edit_committed.emit(delta)
	return true


func redo() -> bool:
	return redo_delta()


func redo_delta(expected: CoverageDelta = null) -> bool:
	if _redo_stack.is_empty() or layer == null:
		return false
	if expected != null and _redo_stack.back() != expected:
		return false
	var delta: CoverageDelta = _redo_stack.pop_back()
	delta.apply(layer)
	_undo_stack.push_back(delta)
	_last_delta = delta
	edit_committed.emit(delta)
	return true


func _commit_or_reject(delta: CoverageDelta) -> bool:
	if delta.is_empty():
		return _reject(REASON_NOTHING_TO_DO)
	delta.apply(layer)
	_undo_stack.push_back(delta)
	if _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_last_delta = delta
	_last_rejection = REASON_NONE
	edit_committed.emit(delta)
	return true


func _reject(reason: StringName) -> bool:
	_last_rejection = reason
	edit_rejected.emit(reason)
	return false
