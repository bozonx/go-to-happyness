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
	if _grid == null:
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var material_index := TerrainMaterialCatalog.index_of(material_id)
	if material_index < 0:
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	var delta := TerrainDelta.new()
	for cell: Vector2i in CellUtils.sorted_unique(cells):
		if not _grid.is_inside(cell):
			continue
		var old_state := TerrainDelta.state_of(_grid, cell)
		var new_state := old_state.duplicate()
		new_state[TerrainDelta.STATE_MATERIAL] = material_index
		if variant >= 0:
			new_state[TerrainDelta.STATE_DETAIL] = TerrainDetailCodec.with_variant(
				old_state[TerrainDelta.STATE_DETAIL],
				TerrainMaterialVariants.clamp_variant(material_index, variant),
			)
		if new_state == old_state:
			continue
		delta.record(cell, old_state, new_state)
	if delta.is_empty():
		return _reject(CascadeSolver.REASON_NOTHING_TO_DO)
	_commit(delta)
	return true


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


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo() -> bool:
	if _grid == null or _undo_stack.is_empty():
		return false
	var delta: TerrainDelta = _undo_stack.pop_back()
	delta.revert(_grid)
	_redo_stack.push_back(delta)
	_last_delta = delta
	edit_committed.emit(delta)
	return true


func redo() -> bool:
	if _grid == null or _redo_stack.is_empty():
		return false
	var delta: TerrainDelta = _redo_stack.pop_back()
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


## Stages a mutable copy of a column's state, keeping first-touch order so the
## delta stays deterministic.
func _stage(states: Dictionary, order: Array[Vector2i], cell: Vector2i) -> void:
	if states.has(cell):
		return
	states[cell] = TerrainDelta.state_of(_grid, cell)
	order.append(cell)


static func _with_flag(flags: int, flag: int, enabled: bool) -> int:
	return (flags | flag) if enabled else (flags & ~flag)
