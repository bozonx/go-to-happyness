class_name TestDomainTerrain
extends RefCounted

## Covers the invariant the whole terrain system rests on: only integers are
## stored, everything fractional is derived (design_docs/core/grid_terrain_system.md §2.1).


static func run_all() -> void:
	_test_catalog_is_closed()
	_test_height_limits_are_rejected_not_clamped()
	_test_flat_cell_corners()
	_test_ramp_placement_rules()
	_test_ramp_unrolls_into_fractional_corners_only()
	_test_ramp_dissolves_on_height_edit()
	_test_dirty_chunks_cover_neighbours()
	print("    [PASS] Terrain Grid Tests")
	_test_cascade_builds_symmetric_pyramid()
	_test_cascade_respects_material_repose()
	_test_terrace_mode_keeps_vertical_face()
	_test_cascade_digs_a_funnel()
	_test_anchor_rejects_whole_operation()
	_test_delta_apply_and_revert_restore_grid()
	_test_service_undo_redo()
	print("    [PASS] Terrain Cascade Tests")


static func _make_grid(fill_height: int = 0) -> TerrainGrid:
	var grid := TerrainGrid.new()
	grid.configure(1.0, 32, fill_height)
	return grid


static func _test_catalog_is_closed() -> void:
	assert(SlopeCatalog.slope_class_of(SlopeCatalog.GENTLE) == 1)
	assert(SlopeCatalog.run_of(SlopeCatalog.GENTLE) == 4)
	assert(SlopeCatalog.rise_of(SlopeCatalog.GENTLE) == 1)
	assert(SlopeCatalog.run_of(SlopeCatalog.CLIFF) == 0)
	assert(not SlopeCatalog.is_ramp(SlopeCatalog.CLIFF))
	assert(not SlopeCatalog.is_ramp(SlopeCatalog.FLAT))
	assert(SlopeCatalog.ramp_ids().size() == 5)
	# Nothing outside the table exists.
	assert(not SlopeCatalog.has_slope(&"custom_30_degrees"))
	assert(SlopeCatalog.slope_class_of(&"custom_30_degrees") == -1)


static func _test_height_limits_are_rejected_not_clamped() -> void:
	var grid := _make_grid()
	assert(grid.set_height(Vector2i(0, 0), TerrainGrid.MAX_HEIGHT))
	assert(not grid.set_height(Vector2i(0, 0), TerrainGrid.MAX_HEIGHT + 1))
	assert(grid.height_of(Vector2i(0, 0)) == TerrainGrid.MAX_HEIGHT)
	assert(not grid.set_height(Vector2i(0, 0), TerrainGrid.MIN_HEIGHT - 1))
	assert(grid.height_of(Vector2i(0, 0)) == TerrainGrid.MAX_HEIGHT)
	# Outside the board is a refusal, not a crash.
	assert(not grid.set_height(Vector2i(4096, 0), 1))


static func _test_flat_cell_corners() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(2, 3), 6)
	var corners := grid.corner_heights(Vector2i(2, 3))
	for corner: float in corners:
		assert(is_equal_approx(corner, 6.0))
	assert(is_equal_approx(grid.height_at(Vector3(2.5, 0.0, 3.5)), 6.0 * TerrainGrid.HEIGHT_STEP))


static func _test_ramp_placement_rules() -> void:
	var grid := _make_grid()
	# A gentle ramp needs 4 free flat cells and a column exactly +1 step at the top.
	assert(not grid.can_place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	grid.set_height(Vector2i(4, 0), 1)
	assert(grid.can_place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	# Wrong drop at the top end: two steps is not a gentle ramp.
	grid.set_height(Vector2i(4, 0), 2)
	assert(not grid.can_place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	grid.set_height(Vector2i(4, 0), 1)
	# An uneven run cannot carry one ramp object.
	grid.set_height(Vector2i(2, 0), 1)
	assert(not grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	grid.set_height(Vector2i(2, 0), 0)
	# A hole in the run blocks it too.
	grid.set_hole(Vector2i(1, 0), true)
	assert(not grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	grid.set_hole(Vector2i(1, 0), false)
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	# Diagonal ramps do not exist.
	assert(not grid.place_ramp(Vector2i(0, 8), SlopeCatalog.GENTLE, SlopeCatalog.DIR_NE))


static func _test_ramp_unrolls_into_fractional_corners_only() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(4, 0), 1)
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))

	var ramp := grid.ramp_cells_at(Vector2i(2, 0))
	assert(ramp.size() == 4)
	assert(ramp[0] == Vector2i(0, 0) and ramp[3] == Vector2i(3, 0))

	for step in 4:
		var cell := Vector2i(step, 0)
		# Stored data stays integer: same base height, same slope, only the index moves.
		assert(grid.height_of(cell) == 0)
		assert(grid.slope_of(cell) == SlopeCatalog.GENTLE)
		assert(grid.slope_index_of(cell) == step)
		var corners := grid.corner_heights(cell)
		assert(is_equal_approx(corners[TerrainGrid.CORNER_NW], float(step) * 0.25))
		assert(is_equal_approx(corners[TerrainGrid.CORNER_SW], float(step) * 0.25))
		assert(is_equal_approx(corners[TerrainGrid.CORNER_NE], float(step + 1) * 0.25))
		assert(is_equal_approx(corners[TerrainGrid.CORNER_SE], float(step + 1) * 0.25))

	# The ramp meets the top column exactly — no crack, no fractional column.
	assert(is_equal_approx(grid.corner_heights(Vector2i(3, 0))[TerrainGrid.CORNER_NE], 1.0))
	assert(is_equal_approx(grid.corner_heights(Vector2i(4, 0))[TerrainGrid.CORNER_NW], 1.0))
	# Standing height rises monotonically along the run.
	var previous := -1.0
	for step in 4:
		var height := grid.height_steps_in_cell(Vector2i(step, 0), 0.5, 0.5)
		assert(height > previous)
		previous = height


static func _test_ramp_dissolves_on_height_edit() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(2, 0), 1)
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.MODERATE, SlopeCatalog.DIR_E))
	# Editing one cell of a ramp removes the whole object; half a ramp cannot exist.
	assert(grid.set_height(Vector2i(1, 0), 3))
	assert(grid.slope_of(Vector2i(0, 0)) == SlopeCatalog.FLAT)
	assert(grid.slope_of(Vector2i(1, 0)) == SlopeCatalog.FLAT)
	assert(grid.height_of(Vector2i(0, 0)) == 0)
	assert(grid.height_of(Vector2i(1, 0)) == 3)


static func _test_dirty_chunks_cover_neighbours() -> void:
	var grid := _make_grid()
	grid.take_dirty_chunks()
	assert(not grid.has_dirty_chunks())
	# A cell on a chunk seam changes the neighbouring chunk's wall too.
	grid.set_height(Vector2i(0, 0), 3)
	var chunks := grid.take_dirty_chunks()
	assert(chunks.has(Vector2i(0, 0)))
	assert(chunks.has(Vector2i(-1, -1)))
	assert(chunks.size() == 4)
	# Deterministic order, independent of insertion.
	var sorted := chunks.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	assert(chunks == sorted)


static func _assert_same_grid(before: Dictionary, after: Dictionary) -> void:
	for key: String in before:
		assert(before[key] == after[key])


static func _fill_material(grid: TerrainGrid, material_id: StringName) -> void:
	for z in range(-16, 16):
		for x in range(-16, 16):
			grid.set_material(Vector2i(x, z), material_id)


static func _sculpt(grid: TerrainGrid, cell: Vector2i, delta: int, mode: int = TerrainEditOperation.Mode.SCULPT) -> TerrainDelta:
	var solver := CascadeSolver.new()
	var operation := TerrainEditOperation.offset([cell] as Array[Vector2i], delta, mode)
	var change := solver.solve(grid, operation)
	if change != null:
		change.apply(grid)
	return change


static func _test_cascade_builds_symmetric_pyramid() -> void:
	var grid := _make_grid()
	assert(_sculpt(grid, Vector2i(0, 0), 3) != null)
	# Grass holds one step per cell, so the flanks fall off with Manhattan distance.
	for z in range(-4, 5):
		for x in range(-4, 5):
			var expected := maxi(0, 3 - absi(x) - absi(z))
			assert(grid.height_of(Vector2i(x, z)) == expected)


static func _test_cascade_respects_material_repose() -> void:
	# Sand slumps at half a step per cell: terraces two cells wide, not stairs.
	var sand := _make_grid()
	_fill_material(sand, TerrainMaterialCatalog.SAND)
	assert(_sculpt(sand, Vector2i(0, 0), 3) != null)
	assert(sand.height_of(Vector2i(0, 0)) == 3)
	assert(sand.height_of(Vector2i(1, 0)) == 3)
	assert(sand.height_of(Vector2i(2, 0)) == 2)
	assert(sand.height_of(Vector2i(3, 0)) == 2)
	assert(sand.height_of(Vector2i(4, 0)) == 1)
	assert(sand.height_of(Vector2i(6, 0)) == 0)

	# Rock holds four steps per cell: a three-step column stands on its own.
	var stone := _make_grid()
	_fill_material(stone, TerrainMaterialCatalog.STONE)
	assert(_sculpt(stone, Vector2i(0, 0), 3) != null)
	assert(stone.height_of(Vector2i(0, 0)) == 3)
	assert(stone.height_of(Vector2i(1, 0)) == 0)


static func _test_terrace_mode_keeps_vertical_face() -> void:
	var grid := _make_grid()
	assert(_sculpt(grid, Vector2i(0, 0), 3, TerrainEditOperation.Mode.TERRACE) != null)
	assert(grid.height_of(Vector2i(0, 0)) == 3)
	# No cascade at all: the face stays sheer and asks for a wall or auto-rock.
	assert(grid.height_of(Vector2i(1, 0)) == 0)
	assert(grid.height_of(Vector2i(0, 1)) == 0)


static func _test_cascade_digs_a_funnel() -> void:
	var grid := _make_grid()
	assert(_sculpt(grid, Vector2i(0, 0), -3) != null)
	for z in range(-4, 5):
		for x in range(-4, 5):
			var expected := mini(0, -3 + absi(x) + absi(z))
			assert(grid.height_of(Vector2i(x, z)) == expected)


static func _test_anchor_rejects_whole_operation() -> void:
	var grid := _make_grid()
	grid.set_anchor(Vector2i(2, 0), true)
	var before := grid.snapshot()

	var solver := CascadeSolver.new()
	var operation := TerrainEditOperation.offset([Vector2i(0, 0)] as Array[Vector2i], 3)
	assert(solver.solve(grid, operation) == null)
	assert(solver.rejection_reason == CascadeSolver.REASON_ANCHOR)
	# Refused as a whole: nothing partially applied, not even the cells the wave
	# passed before reaching the anchor.
	_assert_same_grid(before, grid.snapshot())

	# Editing the anchored column itself is refused too.
	var direct := CascadeSolver.new()
	assert(direct.solve(grid, TerrainEditOperation.offset([Vector2i(2, 0)] as Array[Vector2i], 1)) == null)
	assert(direct.rejection_reason == CascadeSolver.REASON_ANCHOR)
	_assert_same_grid(before, grid.snapshot())


static func _test_delta_apply_and_revert_restore_grid() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(4, 0), 1)
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	var before := grid.snapshot()

	var solver := CascadeSolver.new()
	var delta := solver.solve(grid, TerrainEditOperation.offset([Vector2i(2, 0)] as Array[Vector2i], 2))
	assert(delta != null)
	delta.apply(grid)
	# Moving one cell of a ramp dissolves the whole object.
	assert(grid.slope_of(Vector2i(0, 0)) == SlopeCatalog.FLAT)
	assert(grid.slope_of(Vector2i(3, 0)) == SlopeCatalog.FLAT)

	delta.revert(grid)
	_assert_same_grid(before, grid.snapshot())
	assert(grid.slope_of(Vector2i(1, 0)) == SlopeCatalog.GENTLE)
	assert(grid.slope_index_of(Vector2i(1, 0)) == 1)


static func _test_service_undo_redo() -> void:
	var grid := _make_grid()
	var service := TerrainService.new()
	service.configure(grid)
	var before := grid.snapshot()

	assert(service.apply_operation(TerrainEditOperation.offset([Vector2i(0, 0)] as Array[Vector2i], 2)))
	assert(service.apply_operation(TerrainEditOperation.level([Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i], 4)))
	assert(service.undo_depth() == 2)
	assert(grid.height_of(Vector2i(0, 0)) == 4 and grid.height_of(Vector2i(1, 0)) == 4)

	assert(service.undo() and service.undo())
	assert(not service.can_undo())
	_assert_same_grid(before, grid.snapshot())

	assert(service.redo())
	assert(grid.height_of(Vector2i(0, 0)) == 2)
	assert(service.redo_depth() == 1)
	# A fresh edit drops the redo branch.
	assert(service.apply_operation(TerrainEditOperation.offset([Vector2i(8, 8)] as Array[Vector2i], 1)))
	assert(not service.can_redo())

	# Ramps are transactions too.
	assert(grid.set_height(Vector2i(-4, 8), 1))
	assert(service.place_ramp(Vector2i(-8, 8), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	assert(grid.slope_of(Vector2i(-6, 8)) == SlopeCatalog.GENTLE)
	assert(service.undo())
	assert(grid.slope_of(Vector2i(-6, 8)) == SlopeCatalog.FLAT)
