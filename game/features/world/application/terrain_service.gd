class_name TerrainService
extends RefCounted

## Transaction boundary for terrain editing (design_docs/engine/grid_terrain_system.md §14).
##
## Tools describe what they want as a `TerrainEditOperation`; this service runs it
## through the solver, commits it in one piece, and keeps the undo history. Tools
## never write to the grid directly, which is what keeps "computed on a copy,
## applied as one commit" (§4.4) true for every path.
##
## Every editing verb lives here for the same reason — ramps, material painting
## and hole cutting included. A tool that reaches into the grid behind this class
## produces a change undo cannot see, which is worse than no undo at all.

const MAX_UNDO_STEPS := 128
const REASON_UNSTABLE_MATERIAL := &"unstable_material"

signal edit_committed(delta: TerrainDelta)
signal edit_rejected(reason: StringName)

var _grid: TerrainGrid = null


## Read-only access to the grid for services that need it.  Write access goes
## through `apply_operation` and the other editing verbs — never through this.
func get_grid() -> TerrainGrid:
	return _grid

var _undo_stack: Array[TerrainDelta] = []
var _redo_stack: Array[TerrainDelta] = []
var _last_rejection: StringName = CascadeSolver.REASON_NONE
var _last_delta: TerrainDelta = null
## How many cells the last `paint_material` call skipped because the slope was
## too steep for the requested material. Zero when the whole brush was stable.
var _last_material_skipped := 0


func configure(next_grid: TerrainGrid) -> void:
	_grid = next_grid
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


## The delta most recently committed or replayed.  Editor commands retain this
## identity so they can only undo the transaction they represent.
func last_delta() -> TerrainDelta:
	return _last_delta


func undo_depth() -> int:
	return _undo_stack.size()


func redo_depth() -> int:
	return _redo_stack.size()


## Runs one height operation. Returns false when the solver refused it; the grid
## is then guaranteed untouched and `last_rejection()` explains why.
func apply_operation(operation: TerrainEditOperation) -> bool:
	if _grid == null:
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var solver := CascadeSolver.new()
	var delta := solver.solve(_grid, operation)
	if delta == null:
		return _reject(solver.rejection_reason)
	_commit(delta)
	return true


## Places one ramp object as a transaction. The grid validates the run itself
## (§3.1); this only records the before/after state so the placement can be undone.
func place_ramp(start_cell: Vector2i, slope_id: StringName, direction: int) -> bool:
	if _grid == null:
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var slope_class := SlopeCatalog.slope_class_of(slope_id)
	if not _grid.can_place_ramp_class(start_cell, slope_class, direction):
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var offset := SlopeCatalog.direction_offset(direction)
	var base_height := _grid.height_of(start_cell)
	var delta := TerrainDelta.new()
	for step: int in SlopeCatalog.run_of_class(slope_class):
		var cell := start_cell + offset * step
		var old_state := TerrainDelta.state_of(_grid, cell)
		delta.record(cell, old_state, TerrainDelta.make_state(
			base_height, slope_class, direction, step,
			old_state[TerrainDelta.STATE_MATERIAL], old_state[TerrainDelta.STATE_FLAGS],
			old_state[TerrainDelta.STATE_DETAIL],
		))
	_commit(delta)
	return true


## Connects two authored height anchors with one catalog ramp. Unlike the legacy
## one-click placement verb, this is allowed to reshape uneven intermediate
## columns. The reshape and slope descriptors are one delta, so the author sees
## one action and Ctrl+Z restores both the old heights and the old surfaces.
func connect_ramp(first_cell: Vector2i, second_cell: Vector2i, requested_class: int = RampConnectionPlan.AUTO_CLASS) -> bool:
	if _grid == null:
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var plan := RampConnectionPlan.between(_grid, first_cell, second_cell, requested_class)
	if not plan.is_valid():
		return _reject(plan.reason)
	_commit_ramp_plan(plan)
	return true


## Changes the profile of the complete connected ramp chain under `ramp_cell`,
## keeping its low and high levels. The footprint may grow or shrink; old cells
## outside the new run are flattened inside the same undo record.
func reshape_ramp(ramp_cell: Vector2i, requested_class: int) -> bool:
	if _grid == null:
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var plan := RampConnectionPlan.reshape(_grid, ramp_cell, requested_class)
	if not plan.is_valid():
		return _reject(plan.reason)
	_commit_ramp_plan(plan)
	return true


func _commit_ramp_plan(plan: RampConnectionPlan) -> void:
	var delta := TerrainDelta.new()
	var footprint: Dictionary = {}
	for cell: Vector2i in plan.cells:
		footprint[cell] = true
	for old_ramp_cell: Vector2i in plan.replacement_cells:
		if footprint.has(old_ramp_cell):
			continue
		var old_state := TerrainDelta.state_of(_grid, old_ramp_cell)
		delta.record(old_ramp_cell, old_state, TerrainDelta.flattened(old_state, _grid.height_of(old_ramp_cell)))
	var segment_run := SlopeCatalog.run_of_class(plan.slope_class)
	for step in plan.cells.size():
		var cell: Vector2i = plan.cells[step]
		var old_state := TerrainDelta.state_of(_grid, cell)
		delta.record(cell, old_state, TerrainDelta.make_state(
			plan.expected_height_at_step(step), plan.slope_class, plan.direction, step % segment_run,
			old_state[TerrainDelta.STATE_MATERIAL], old_state[TerrainDelta.STATE_FLAGS],
			old_state[TerrainDelta.STATE_DETAIL],
		))
	_commit(delta)


## Dissolves the ramp under `cell` back into flat columns, as one undoable step.
func dissolve_ramp(cell: Vector2i) -> bool:
	if _grid == null:
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var ramp_cells := _grid.ramp_cells_at(cell)
	if ramp_cells.is_empty():
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var delta := TerrainDelta.new()
	for ramp_cell: Vector2i in ramp_cells:
		var old_state := TerrainDelta.state_of(_grid, ramp_cell)
		delta.record(ramp_cell, old_state, TerrainDelta.flattened(old_state, _grid.height_of(ramp_cell)))
	_commit(delta)
	return true


## Repaints the surface material of a brush. Material is not decoration — it sets
## the angle of repose (§4.2), the traversal weight and the soil digging yields —
## so it is a transaction like any height edit. It is NOT a mesh operation,
## though: the index reaches the GPU through the index map, so the stroke writes
## one texel per cell and rebuilds nothing (`terrain_materials.md` §7.3, §7.5).
##
## `variant` picks the look inside the material; -1 keeps whatever variant the
## column already had.
func paint_material(cells: Array[Vector2i], material_id: StringName, variant: int = -1) -> bool:
	_last_material_skipped = 0
	if _grid == null:
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var material_index := TerrainMaterialCatalog.index_of(material_id)
	if material_index < 0:
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var paint_cells := CellUtils.sorted_unique(cells)
	# Painting is intentionally a texel-only operation. Since it cannot cascade
	# or rebuild geometry, skip cells whose slope cannot hold the material rather
	# than silently authoring a sand or mud cliff. A partial brush paints what it
	# can; only when every cell is unstable does the whole stroke fail.
	var stable_cells: Array[Vector2i] = []
	for cell: Vector2i in paint_cells:
		if not _grid.is_inside(cell):
			continue
		if _material_is_stable_at(cell, material_index):
			stable_cells.append(cell)
		else:
			_last_material_skipped += 1
	if stable_cells.is_empty():
		return _reject(REASON_UNSTABLE_MATERIAL)
	var delta := TerrainDelta.new()
	for cell: Vector2i in stable_cells:
		var old_state := TerrainDelta.state_of(_grid, cell)
		var new_state := old_state.duplicate()
		new_state[TerrainDelta.STATE_MATERIAL] = material_index
		# Detail belongs to the column, but a numeric variant belongs to a
		# particular material. Preserve it only after clamping to the new palette;
		# otherwise a stale mud variant can address an unrelated texture-array layer.
		var requested_variant := variant if variant >= 0 else TerrainDetailCodec.variant_of(old_state[TerrainDelta.STATE_DETAIL])
		new_state[TerrainDelta.STATE_DETAIL] = TerrainDetailCodec.with_variant(
			old_state[TerrainDelta.STATE_DETAIL],
			TerrainMaterialVariants.clamp_variant(material_index, requested_variant),
		)
		if new_state == old_state:
			continue
		delta.record(cell, old_state, new_state)
	if delta.is_empty():
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	_commit(delta)
	return true


func last_material_skipped() -> int:
	return _last_material_skipped


## The detail brush (§4): a different look, identical mechanics. Kept a
## transaction anyway — an edit undo cannot see is worse than no undo (§4.4).
func paint_variant(cells: Array[Vector2i], variant: int) -> bool:
	return _paint_detail(cells, func(detail: int, cell: Vector2i) -> int:
		return TerrainDetailCodec.with_variant(
			detail, TerrainMaterialVariants.clamp_variant(_grid.material_index_at(cell), variant)
		))


## Sets wear directly. `SurfaceWearService` owns the gradual version (§6.1); this
## is the authoring path, for tools that paint a trodden field by hand.
func set_wear(cells: Array[Vector2i], wear: int) -> bool:
	return _paint_detail(cells, func(detail: int, _cell: Vector2i) -> int:
		return TerrainDetailCodec.with_wear(detail, wear))


## Snow depth as an authored value. Accumulation and melt (§6.2) belong to the
## weather-driven service; the data path is the same one, and it is here so the
## lab can pose the state before that service exists.
func set_snow_depth(cells: Array[Vector2i], snow_depth: int) -> bool:
	return _paint_detail(cells, func(detail: int, _cell: Vector2i) -> int:
		return TerrainDetailCodec.with_snow_depth(detail, snow_depth))


func _paint_detail(cells: Array[Vector2i], mutate: Callable) -> bool:
	if _grid == null:
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var delta := TerrainDelta.new()
	for cell: Vector2i in CellUtils.sorted_unique(cells):
		if not _grid.is_inside(cell):
			continue
		var old_state := TerrainDelta.state_of(_grid, cell)
		var next_detail := int(mutate.call(old_state[TerrainDelta.STATE_DETAIL], cell))
		if next_detail == old_state[TerrainDelta.STATE_DETAIL]:
			continue
		var new_state := old_state.duplicate()
		new_state[TerrainDelta.STATE_DETAIL] = next_detail
		delta.record(cell, old_state, new_state)
	if delta.is_empty():
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	_commit(delta)
	return true


## Carves cells out of the terrain or fills them back in (§6). Cutting removes the
## ground a ramp leans on, so the ramps that touch the cut go with it, inside the
## same transaction.
func set_hole(cells: Array[Vector2i], enabled: bool) -> bool:
	if _grid == null:
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var states: Dictionary = {}
	var order: Array[Vector2i] = []
	for cell: Vector2i in CellUtils.sorted_unique(cells):
		if not _grid.is_inside(cell) or _grid.is_hole(cell) == enabled:
			continue
		_stage(states, order, cell)
		var state: PackedInt32Array = states[cell]
		state[TerrainDelta.STATE_FLAGS] = _with_flag(state[TerrainDelta.STATE_FLAGS], TerrainCell.FLAG_HOLE, enabled)
		states[cell] = state
		if not enabled:
			continue
		for ramp_start: Vector2i in _grid.ramps_touching(cell):
			for ramp_cell: Vector2i in _grid.ramp_cells_at(ramp_start):
				_stage(states, order, ramp_cell)
				var ramp_state: PackedInt32Array = states[ramp_cell]
				ramp_state[TerrainDelta.STATE_SLOPE_CLASS] = SlopeCatalog.CLASS_FLAT
				ramp_state[TerrainDelta.STATE_SLOPE_DIR] = 0
				ramp_state[TerrainDelta.STATE_SLOPE_INDEX] = 0
				states[ramp_cell] = ramp_state
	var delta := TerrainDelta.new()
	for cell: Vector2i in order:
		var old_state := TerrainDelta.state_of(_grid, cell)
		if old_state == states[cell]:
			continue
		delta.record(cell, old_state, states[cell])
	if delta.is_empty():
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	_commit(delta)
	return true


## Pins cells against the cascade (§4.4). An anchored column is one the cascade
## may not move: reaching one rejects the whole operation rather than letting the
## ground subside under what is standing on it.
##
## The flag is the domain half of an invariant whose other half is Placement Merge
## (§5.3, phase 5) — nothing in the game writes anchors yet, because nothing in the
## game moves a column yet. This entry point exists so that when something does, it
## writes them through the one owner of terrain writes and not into the grid behind
## its back; an anchor set outside a transaction is an anchor undo silently drops.
func set_anchor(cells: Array[Vector2i], enabled: bool) -> bool:
	if _grid == null:
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var delta := TerrainDelta.new()
	for cell: Vector2i in CellUtils.sorted_unique(cells):
		if not _grid.is_inside(cell) or _grid.is_anchor(cell) == enabled:
			continue
		var old_state := TerrainDelta.state_of(_grid, cell)
		var new_state := old_state.duplicate()
		new_state[TerrainDelta.STATE_FLAGS] = _with_flag(
			new_state[TerrainDelta.STATE_FLAGS], TerrainCell.FLAG_ANCHOR, enabled,
		)
		delta.record(cell, old_state, new_state)
	if delta.is_empty():
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	_commit(delta)
	return true


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo() -> bool:
	return undo_delta()


## Revert the exact delta recorded by an editor command.  The identity check
## turns accidental history desynchronisation into a safe refusal rather than
## undoing whichever terrain edit happens to be on top.
func undo_delta(expected: TerrainDelta = null) -> bool:
	if _grid == null or _undo_stack.is_empty():
		return false
	var delta: TerrainDelta = _undo_stack.pop_back()
	if expected != null and delta != expected:
		_undo_stack.push_back(delta)
		return false
	delta.revert(_grid)
	_redo_stack.push_back(delta)
	_last_delta = delta
	edit_committed.emit(delta)
	return true


func redo() -> bool:
	return redo_delta()


## Replay the exact delta recorded by an editor command. See `undo_delta`.
func redo_delta(expected: TerrainDelta = null) -> bool:
	if _grid == null or _redo_stack.is_empty():
		return false
	var delta: TerrainDelta = _redo_stack.pop_back()
	if expected != null and delta != expected:
		_redo_stack.push_back(delta)
		return false
	delta.apply(_grid)
	_undo_stack.push_back(delta)
	_last_delta = delta
	edit_committed.emit(delta)
	return true


func _commit(delta: TerrainDelta) -> void:
	delta.apply(_grid)
	_last_delta = delta
	_undo_stack.push_back(delta)
	if _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.pop_front()
	# A new edit invalidates the redo branch; keeping it would let the player
	# reapply a delta whose "before" state no longer exists.
	_redo_stack.clear()
	_last_rejection = CascadeSolver.REASON_NONE
	edit_committed.emit(delta)


func _reject(reason: StringName) -> bool:
	_last_rejection = reason
	edit_rejected.emit(reason)
	return false


func _material_is_stable_at(cell: Vector2i, material_index: int) -> bool:
	if _grid.is_hole(cell):
		return false
	var height := _grid.height_of(cell)
	for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
		var neighbour := cell + SlopeCatalog.direction_offset(direction)
		if not _grid.is_inside(neighbour) or _grid.is_hole(neighbour):
			continue
		if not TerrainMaterialCatalog.holds_height_difference(
			material_index, _grid.height_of(neighbour) - height,
		):
			return false
	return true


## Stages a mutable copy of a column's state, keeping first-touch order so the
## delta stays deterministic.
func _stage(states: Dictionary, order: Array[Vector2i], cell: Vector2i) -> void:
	if states.has(cell):
		return
	states[cell] = TerrainDelta.state_of(_grid, cell)
	order.append(cell)


static func _with_flag(flags: int, flag: int, enabled: bool) -> int:
	return (flags | flag) if enabled else (flags & ~flag)
