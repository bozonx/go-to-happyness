class_name TestDomainTerrain
extends RefCounted

## Covers the invariant the whole terrain system rests on: only integers are
## stored, everything fractional is derived (design_docs/engine/grid_terrain_system.md §2.1).
##
## The edge cases are the point here. A cascade that is right in the middle of a
## plain and wrong at the board edge, at an anchor, at a hole or on a ramp it
## broke is not right at all — those are exactly the states the player reaches by
## dragging a brush around.


static func run_all() -> void:
	_test_catalog_is_closed()
	_test_catalog_lookups_agree()
	_test_material_repose_matches_design()
	_test_height_limits_are_rejected_not_clamped()
	_test_flat_cell_corners()
	_test_height_at_samples_across_cells()
	_test_ramp_placement_rules()
	_test_ramp_connection_reshapes_ground_atomically()
	_test_ramp_unrolls_into_fractional_corners_only()
	_test_corners_follow_orthogonal_neighbours()
	_test_shallow_ramp_spans_eight_cells()
	_test_ramp_dissolves_on_height_edit()
	_test_ramp_dissolves_when_its_top_column_moves()
	_test_ramp_dissolves_when_ground_is_carved_away()
	_test_dirty_chunks_cover_neighbours()
	_test_geometry_delta_does_not_publish_surface_early()
	print("    [PASS] Terrain Grid Tests")
	_test_cascade_builds_symmetric_pyramid()
	_test_cascade_respects_material_repose()
	_test_terrace_mode_keeps_vertical_face()
	_test_cascade_digs_a_funnel()
	_test_cascade_stops_at_the_board_edge()
	_test_cascade_flows_around_a_hole()
	_test_cascade_is_deterministic()
	_test_anchor_rejects_whole_operation()
	_test_cascade_rejects_beyond_height_range()
	_test_cascade_rejects_nothing_to_do()
	print("    [PASS] Terrain Cascade Tests")
	_test_auto_slope_decorates_a_grass_boundary()
	_test_auto_slope_terraces_sand_over_two_cells()
	_test_auto_slope_falls_back_to_cliff_on_rock()
	_test_auto_skirt_descends_from_a_levelled_plateau()
	_test_auto_slope_refuses_occupied_ground()
	_test_auto_slope_never_moves_an_anchor()
	_test_requested_slope_profile_shapes_full_footprint()
	_test_grass_hillside_closes_every_corner()
	_test_hillsides_grow_no_wedges()
	_test_terrace_mode_assigns_no_slopes()
	print("    [PASS] Terrain Auto-Slope Tests")
	_test_delta_apply_and_revert_restore_grid()
	_test_delta_carries_material_and_flags()
	_test_service_undo_redo()
	_test_service_paint_and_hole_are_undoable()
	print("    [PASS] Terrain Transaction Tests")


static func _make_grid(fill_height: int = 0) -> TerrainGrid:
	var grid := TerrainGrid.new()
	grid.configure(1.0, 32, fill_height)
	return grid


# --- Catalogs ---------------------------------------------------------------

static func _test_catalog_is_closed() -> void:
	assert(SlopeCatalog.SLOPES.size() == 8)
	assert(SlopeCatalog.slope_class_of(SlopeCatalog.SHALLOW) == 1)
	assert(SlopeCatalog.slope_class_of(SlopeCatalog.GENTLE) == 2)
	assert(SlopeCatalog.slope_class_of(SlopeCatalog.CLIFF) == 7)
	assert(SlopeCatalog.run_of(SlopeCatalog.SHALLOW) == 8)
	assert(SlopeCatalog.run_of(SlopeCatalog.GENTLE) == 4)
	assert(SlopeCatalog.rise_of(SlopeCatalog.GENTLE) == 1)
	assert(SlopeCatalog.run_of(SlopeCatalog.CLIFF) == 0)
	assert(not SlopeCatalog.is_ramp(SlopeCatalog.CLIFF))
	assert(not SlopeCatalog.is_ramp(SlopeCatalog.FLAT))
	assert(SlopeCatalog.ramp_ids().size() == 6)
	# Nothing outside the table exists, and asking about it is not an error.
	assert(not SlopeCatalog.has_slope(&"custom_30_degrees"))
	assert(SlopeCatalog.slope_class_of(&"custom_30_degrees") == -1)
	assert(SlopeCatalog.id_of_class(-1) == SlopeCatalog.FLAT)
	assert(SlopeCatalog.id_of_class(99) == SlopeCatalog.FLAT)
	assert(is_inf(SlopeCatalog.steps_per_cell_of(SlopeCatalog.CLIFF)))


static func _test_catalog_lookups_agree() -> void:
	# The fast per-class arrays the mesher and the cascade use must not be able to
	# drift away from the table §3 is written against.
	for slope_class in SlopeCatalog.SLOPES.size():
		var entry: Dictionary = SlopeCatalog.SLOPES[slope_class]
		assert(SlopeCatalog.id_of_class(slope_class) == entry["id"])
		assert(SlopeCatalog.slope_class_of(entry["id"]) == slope_class)
		assert(SlopeCatalog.rise_of_class(slope_class) == int(entry["rise"]))
		assert(SlopeCatalog.run_of_class(slope_class) == int(entry["run"]))
		assert(is_equal_approx(SlopeCatalog.angle_degrees_of(entry["id"]), float(entry["angle"])))
	# Steepness grows monotonically with the class — §3.2 walks the table in this
	# order and relies on it.
	var previous := -1.0
	for slope_class in SlopeCatalog.SLOPES.size():
		var steepness := SlopeCatalog.steps_per_cell_of_class(slope_class)
		assert(steepness > previous)
		previous = steepness
	for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
		assert(SlopeCatalog.is_orthogonal(direction))
		assert(SlopeCatalog.direction_offset(SlopeCatalog.opposite_direction(direction)) == -SlopeCatalog.direction_offset(direction))
	assert(not SlopeCatalog.is_orthogonal(SlopeCatalog.DIR_NE))
	assert(SlopeCatalog.direction_offset(-1) == Vector2i.ZERO)


static func _test_material_repose_matches_design() -> void:
	# §4.2, verbatim: sand 22.5°, earth and grass 45°, rock 76°.
	assert(SlopeCatalog.angle_degrees_of(SlopeCatalog.id_of_class(TerrainMaterialCatalog.repose_class_of(TerrainMaterialCatalog.SAND))) == 22.5)
	assert(SlopeCatalog.angle_degrees_of(SlopeCatalog.id_of_class(TerrainMaterialCatalog.repose_class_of(TerrainMaterialCatalog.DIRT))) == 45.0)
	assert(SlopeCatalog.angle_degrees_of(SlopeCatalog.id_of_class(TerrainMaterialCatalog.repose_class_of(TerrainMaterialCatalog.GRASS))) == 45.0)
	assert(SlopeCatalog.angle_degrees_of(SlopeCatalog.id_of_class(TerrainMaterialCatalog.repose_class_of(TerrainMaterialCatalog.STONE))) == 76.0)
	assert(is_equal_approx(TerrainMaterialCatalog.repose_steps_per_cell_of(TerrainMaterialCatalog.SAND), 0.5))
	assert(is_equal_approx(TerrainMaterialCatalog.repose_steps_per_cell_of(TerrainMaterialCatalog.GRASS), 1.0))
	assert(is_equal_approx(TerrainMaterialCatalog.repose_steps_per_cell_of(TerrainMaterialCatalog.STONE), 4.0))
	# Unknown ids fall back to the default rather than crashing a cascade midway.
	assert(not TerrainMaterialCatalog.has_material(&"lava"))
	assert(TerrainMaterialCatalog.index_of(&"lava") == -1)
	assert(TerrainMaterialCatalog.id_of_index(-1) == TerrainMaterialCatalog.DEFAULT_MATERIAL)
	assert(TerrainMaterialCatalog.id_of_index(99) == TerrainMaterialCatalog.DEFAULT_MATERIAL)
	for material_id: StringName in TerrainMaterialCatalog.ids():
		assert(TerrainMaterialCatalog.id_of_index(TerrainMaterialCatalog.index_of(material_id)) == material_id)


# --- Grid -------------------------------------------------------------------

static func _test_height_limits_are_rejected_not_clamped() -> void:
	var grid := _make_grid()
	assert(grid.set_height(Vector2i(0, 0), TerrainGrid.MAX_HEIGHT))
	assert(not grid.set_height(Vector2i(0, 0), TerrainGrid.MAX_HEIGHT + 1))
	assert(grid.height_of(Vector2i(0, 0)) == TerrainGrid.MAX_HEIGHT)
	assert(not grid.set_height(Vector2i(0, 0), TerrainGrid.MIN_HEIGHT - 1))
	assert(grid.height_of(Vector2i(0, 0)) == TerrainGrid.MAX_HEIGHT)
	assert(grid.set_height(Vector2i(0, 0), TerrainGrid.MIN_HEIGHT))
	# Outside the board every write is refused and every read is well defined.
	assert(not grid.set_height(Vector2i(4096, 0), 1))
	assert(not grid.set_material(Vector2i(4096, 0), TerrainMaterialCatalog.SAND))
	assert(not grid.set_material(Vector2i(0, 0), &"lava"))
	assert(grid.height_of(Vector2i(4096, 0)) == 0)
	assert(grid.material_of(Vector2i(4096, 0)) == TerrainMaterialCatalog.DEFAULT_MATERIAL)
	assert(grid.slope_of(Vector2i(4096, 0)) == SlopeCatalog.FLAT)
	assert(grid.flags_of(Vector2i(4096, 0)) == 0)
	assert(not grid.is_inside(grid.min_cell() - Vector2i.ONE))
	assert(grid.is_inside(grid.min_cell()) and grid.is_inside(grid.max_cell()))


static func _test_flat_cell_corners() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(2, 3), 6)
	for corner: float in grid.corner_heights(Vector2i(2, 3)):
		assert(is_equal_approx(corner, 6.0))
	assert(is_equal_approx(grid.height_at(Vector3(2.5, 0.0, 3.5)), 6.0 * TerrainGrid.HEIGHT_STEP))


static func _test_height_at_samples_across_cells() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(1, 0), 1)
	assert(grid.place_ramp(Vector2i(-1, 0), SlopeCatalog.MODERATE, SlopeCatalog.DIR_E))
	# Along a moderate ramp the standing height climbs linearly, and the samples
	# on the shared edge agree from both sides — that is the seam citizens walk.
	assert(is_equal_approx(grid.height_at(Vector3(-1.0, 0.0, 0.5)), 0.0))
	assert(is_equal_approx(grid.height_at(Vector3(0.0, 0.0, 0.5)), 0.25))
	assert(absf(grid.height_at(Vector3(0.999, 0.0, 0.5)) - grid.height_at(Vector3(1.0, 0.0, 0.5))) < 0.001)
	# Negative coordinates floor towards the lower cell, not towards zero.
	grid.set_height(Vector2i(-3, -3), 4)
	assert(grid.cell_from_position(Vector3(-2.5, 0.0, -2.5)) == Vector2i(-3, -3))
	assert(is_equal_approx(grid.height_at(Vector3(-2.5, 0.0, -2.5)), 2.0))
	assert(is_equal_approx(grid.cell_center(Vector2i(-3, -3)).y, 2.0))


static func _test_ramp_placement_rules() -> void:
	var grid := _make_grid()
	# Needs a column exactly `rise` higher beyond the run.
	assert(not grid.can_place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	assert(grid.ramp_placement_rejection(Vector2i(0, 0), SlopeCatalog.CLASS_GENTLE, SlopeCatalog.DIR_E) == &"top_height")
	grid.set_height(Vector2i(4, 0), 1)
	assert(grid.can_place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	assert(grid.ramp_placement_rejection(Vector2i(0, 0), SlopeCatalog.CLASS_GENTLE, SlopeCatalog.DIR_E).is_empty())
	grid.set_height(Vector2i(4, 0), 2)
	assert(not grid.can_place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	grid.set_height(Vector2i(4, 0), 1)

	# An uneven run is not a ramp site.
	grid.set_height(Vector2i(2, 0), 1)
	assert(not grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	assert(grid.ramp_placement_rejection(Vector2i(0, 0), SlopeCatalog.CLASS_GENTLE, SlopeCatalog.DIR_E) == &"run_height")
	grid.set_height(Vector2i(2, 0), 0)
	# Neither is a run crossing a hole or an anchor.
	grid.set_hole(Vector2i(2, 0), true)
	assert(not grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	grid.set_hole(Vector2i(2, 0), false)
	grid.set_anchor(Vector2i(2, 0), true)
	assert(not grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	grid.set_anchor(Vector2i(2, 0), false)
	# A hole as the top column has nothing to climb to.
	grid.set_hole(Vector2i(4, 0), true)
	assert(not grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	grid.set_hole(Vector2i(4, 0), false)

	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	assert(grid.is_ramp_valid_at(Vector2i(1, 0)))
	# Diagonals and non-ramp classes are refused outright (§3, §3.3).
	assert(not grid.place_ramp(Vector2i(0, 8), SlopeCatalog.GENTLE, SlopeCatalog.DIR_NE))
	assert(not grid.place_ramp(Vector2i(0, 8), SlopeCatalog.CLIFF, SlopeCatalog.DIR_E))
	assert(not grid.place_ramp(Vector2i(0, 8), SlopeCatalog.FLAT, SlopeCatalog.DIR_E))
	assert(not grid.place_ramp(Vector2i(0, 8), &"custom_30_degrees", SlopeCatalog.DIR_E))
	# A run leaving the board cannot fit either.
	assert(not grid.place_ramp(grid.max_cell() - Vector2i(1, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))


static func _test_ramp_connection_reshapes_ground_atomically() -> void:
	var grid := _make_grid()
	var service := TerrainService.new()
	service.configure(grid)
	# The gesture anchors are four cells apart and one step apart: Auto therefore
	# chooses gentle. Uneven ground in the run is authored noise the connection
	# tool is explicitly allowed to reshape.
	grid.set_height(Vector2i(2, 0), 3)
	grid.set_height(Vector2i(4, 0), 1)
	var plan := RampConnectionPlan.between(grid, Vector2i(0, 0), Vector2i(4, 0))
	assert(plan.is_valid())
	assert(plan.slope_class == SlopeCatalog.CLASS_GENTLE)
	assert(plan.direction == SlopeCatalog.DIR_E)
	assert(plan.reshaped_cells == 1)
	assert(service.connect_ramp(Vector2i(0, 0), Vector2i(4, 0)))
	for x in 4:
		assert(grid.height_of(Vector2i(x, 0)) == 0)
		assert(grid.slope_class_at(Vector2i(x, 0)) == SlopeCatalog.CLASS_GENTLE)
	assert(grid.is_ramp_valid_at(Vector2i(2, 0)))
	# One undo restores both the old height and the absence of a slope.
	assert(service.undo())
	assert(grid.height_of(Vector2i(2, 0)) == 3)
	assert(grid.slope_class_at(Vector2i(2, 0)) == SlopeCatalog.CLASS_FLAT)
	# Direction comes from relative heights, not drag order.
	var reverse := RampConnectionPlan.between(grid, Vector2i(4, 0), Vector2i(0, 0))
	assert(reverse.is_valid() and reverse.direction == SlopeCatalog.DIR_E)
	assert(RampConnectionPlan.between(grid, Vector2i.ZERO, Vector2i(1, 1)).reason == RampConnectionPlan.REASON_NOT_STRAIGHT)
	assert(RampConnectionPlan.between(grid, Vector2i.ZERO, Vector2i(3, 0)).reason == RampConnectionPlan.REASON_SAME_HEIGHT)
	assert(RampConnectionPlan.between(
		grid, Vector2i.ZERO, Vector2i(4, 0), SlopeCatalog.CLASS_MODERATE,
	).reason == RampConnectionPlan.REASON_WRONG_RUN)

	# A larger height difference is a chain, and dragging a new footprint to the
	# same top replaces the old ramp atomically instead of reporting it occupied.
	var chained := _make_grid()
	var chain_service := TerrainService.new()
	chain_service.configure(chained)
	chained.set_height(Vector2i(8, 0), 2)
	assert(chain_service.connect_ramp(Vector2i.ZERO, Vector2i(8, 0), SlopeCatalog.CLASS_GENTLE))
	assert(chained.is_ramp_valid_at(Vector2i(1, 0)))
	assert(chained.is_ramp_valid_at(Vector2i(5, 0)))
	# Same top, gentler profile: two shallow segments occupy sixteen cells and
	# add the missing lower ground to the footprint.
	assert(chain_service.connect_ramp(Vector2i(-8, 0), Vector2i(8, 0), SlopeCatalog.CLASS_SHALLOW))
	assert(chained.slope_class_at(Vector2i(-8, 0)) == SlopeCatalog.CLASS_SHALLOW)
	assert(chained.is_ramp_valid_at(Vector2i(4, 0)))
	# Steepen again. Cells no longer used by the short profile are flattened in
	# the same transaction, not left as orphaned pieces of the old ramp.
	assert(chain_service.reshape_ramp(Vector2i(4, 0), SlopeCatalog.CLASS_STEEP))
	assert(chained.slope_class_at(Vector2i(6, 0)) == SlopeCatalog.CLASS_STEEP)
	assert(chained.slope_class_at(Vector2i.ZERO) == SlopeCatalog.CLASS_FLAT)
	assert(chained.is_ramp_valid_at(Vector2i(7, 0)))


static func _test_ramp_unrolls_into_fractional_corners_only() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(4, 0), 1)
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))

	var ramp := grid.ramp_cells_at(Vector2i(2, 0))
	assert(ramp.size() == 4)
	assert(ramp[0] == Vector2i(0, 0) and ramp[3] == Vector2i(3, 0))
	assert(grid.ramp_top_anchor_at(Vector2i(2, 0)) == Vector2i(4, 0))

	for step in 4:
		var cell := Vector2i(step, 0)
		# Stored data stays integer: one height, one class, one index.
		assert(grid.height_of(cell) == 0)
		assert(grid.slope_of(cell) == SlopeCatalog.GENTLE)
		assert(grid.slope_index_of(cell) == step)
		var corners := grid.corner_heights(cell)
		assert(is_equal_approx(corners[TerrainGrid.CORNER_NW], float(step) * 0.25))
		assert(is_equal_approx(corners[TerrainGrid.CORNER_SW], float(step) * 0.25))
		assert(is_equal_approx(corners[TerrainGrid.CORNER_NE], float(step + 1) * 0.25))
		assert(is_equal_approx(corners[TerrainGrid.CORNER_SE], float(step + 1) * 0.25))

	# The ramp meets the column it climbs to without a seam.
	assert(is_equal_approx(grid.corner_heights(Vector2i(3, 0))[TerrainGrid.CORNER_NE], 1.0))
	assert(is_equal_approx(grid.corner_heights(Vector2i(4, 0))[TerrainGrid.CORNER_NW], 1.0))

	var previous := -1.0
	for sample in 9:
		var height := grid.height_at(Vector3(float(sample) * 0.5, 0.0, 0.5))
		assert(height > previous)
		previous = height


static func _test_corners_follow_orthogonal_neighbours() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(0, -1), 1)
	grid.set_height(Vector2i(1, 0), 1)
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.STEEP, SlopeCatalog.DIR_N))

	# §3.4: the slope rises north, and its east neighbour stands exactly one step
	# up as well — so the corner they share rises too, and the inside corner of the
	# hill comes out without a vertical wedge across the diagonal.
	var corners := grid.corner_heights(Vector2i(0, 0))
	assert(is_equal_approx(corners[TerrainGrid.CORNER_NW], 1.0))
	assert(is_equal_approx(corners[TerrainGrid.CORNER_NE], 1.0))
	assert(is_equal_approx(corners[TerrainGrid.CORNER_SE], 1.0))
	assert(is_equal_approx(corners[TerrainGrid.CORNER_SW], 0.0))
	# Stored data did not change: the column is still one integer height.
	assert(grid.height_of(Vector2i(0, 0)) == 0)

	# A neighbour further up than one step is a cliff and stays one.
	grid.set_height(Vector2i(1, 0), 3)
	var cliffed := grid.corner_heights(Vector2i(0, 0))
	assert(is_equal_approx(cliffed[TerrainGrid.CORNER_SE], 0.0))
	assert(is_equal_approx(cliffed[TerrainGrid.CORNER_NW], 1.0))

	# A flat column takes no part in the rule at all — that is what keeps a
	# terrace sheer (§4.1).
	var terrace := _make_grid()
	terrace.set_height(Vector2i(0, 0), 2)
	for corner: float in terrace.corner_heights(Vector2i(1, 0)):
		assert(is_equal_approx(corner, 0.0))


static func _test_shallow_ramp_spans_eight_cells() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(8, 0), 1)
	assert(grid.can_place_ramp(Vector2i(0, 0), SlopeCatalog.SHALLOW, SlopeCatalog.DIR_E))
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.SHALLOW, SlopeCatalog.DIR_E))
	assert(grid.ramp_cells_at(Vector2i(5, 0)).size() == 8)
	# Δh / 8 per cell, and never anything but that in the data.
	for step in 8:
		var corners := grid.corner_heights(Vector2i(step, 0))
		assert(grid.height_of(Vector2i(step, 0)) == 0)
		assert(is_equal_approx(corners[TerrainGrid.CORNER_NE], float(step + 1) / 8.0))
	assert(grid.is_ramp_valid_at(Vector2i(0, 0)))


static func _test_ramp_dissolves_on_height_edit() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(2, 0), 1)
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.MODERATE, SlopeCatalog.DIR_E))
	# Moving one cell of a ramp dissolves the whole object: it is one thing, and a
	# partial ramp cannot exist in the data (§3.1).
	assert(grid.set_height(Vector2i(1, 0), 3))
	assert(grid.slope_of(Vector2i(0, 0)) == SlopeCatalog.FLAT)
	assert(grid.slope_of(Vector2i(1, 0)) == SlopeCatalog.FLAT)
	assert(grid.height_of(Vector2i(0, 0)) == 0)
	assert(grid.height_of(Vector2i(1, 0)) == 3)


static func _test_ramp_dissolves_when_its_top_column_moves() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(4, 0), 1)
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	# The column a ramp climbs to is part of the ramp's identity. Raising it must
	# not leave a slope that climbs into a wall.
	assert(grid.set_height(Vector2i(4, 0), 6))
	assert(grid.slope_of(Vector2i(3, 0)) == SlopeCatalog.FLAT)
	assert(grid.slope_of(Vector2i(0, 0)) == SlopeCatalog.FLAT)
	assert(not grid.is_ramp_valid_at(Vector2i(2, 0)))

	# A column beside the ramp is not part of it and leaves it alone.
	grid.set_height(Vector2i(4, 0), 1)
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	assert(grid.set_height(Vector2i(2, 1), 5))
	assert(grid.slope_of(Vector2i(2, 0)) == SlopeCatalog.GENTLE)
	assert(grid.is_ramp_valid_at(Vector2i(2, 0)))


static func _test_ramp_dissolves_when_ground_is_carved_away() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(4, 0), 1)
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	# Carving the column the ramp climbs to takes the ramp with it (§6).
	grid.set_hole(Vector2i(4, 0), true)
	assert(grid.slope_of(Vector2i(1, 0)) == SlopeCatalog.FLAT)

	grid.set_hole(Vector2i(4, 0), false)
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	# So does carving one of its own cells.
	grid.set_hole(Vector2i(2, 0), true)
	assert(grid.slope_of(Vector2i(0, 0)) == SlopeCatalog.FLAT)


static func _test_dirty_chunks_cover_neighbours() -> void:
	var grid := _make_grid()
	grid.take_dirty_chunks()
	assert(not grid.has_dirty_chunks())

	# A cell in the middle of a chunk only dirties its own chunk.
	grid.set_height(Vector2i(8, 8), 1)
	assert(grid.take_dirty_chunks() == ([Vector2i(0, 0)] as Array[Vector2i]))

	# A cell on a chunk corner shares its geometry with three more.
	grid.set_height(Vector2i(0, 0), 1)
	var chunks := grid.take_dirty_chunks()
	assert(chunks.has(Vector2i(0, 0)))
	assert(chunks.has(Vector2i(-1, -1)))
	assert(chunks.has(Vector2i(-1, 0)))
	assert(chunks.has(Vector2i(0, -1)))
	assert(chunks.size() == 4)

	# And the queue is sorted, so a rebuild budget spends itself in the same order
	# on every machine (§4.4).
	grid.mark_all_chunks_dirty()
	var all_chunks := grid.take_dirty_chunks()
	var sorted := all_chunks.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	assert(all_chunks == sorted)
	assert(all_chunks.size() == 4)


static func _test_geometry_delta_does_not_publish_surface_early() -> void:
	var grid := _make_grid()
	grid.take_dirty_chunks()
	grid.take_dirty_surface_cells()
	var cell := Vector2i(4, 4)
	var old_state := TerrainDelta.state_of(grid, cell)
	var raised_state := old_state.duplicate()
	raised_state[TerrainDelta.STATE_HEIGHT] = 1
	assert(grid.set_cell_state(
		cell,
		raised_state[TerrainDelta.STATE_HEIGHT], raised_state[TerrainDelta.STATE_SLOPE_CLASS],
		raised_state[TerrainDelta.STATE_SLOPE_DIR], raised_state[TerrainDelta.STATE_SLOPE_INDEX],
		raised_state[TerrainDelta.STATE_MATERIAL], raised_state[TerrainDelta.STATE_FLAGS],
		raised_state[TerrainDelta.STATE_DETAIL],
	))
	assert(grid.has_dirty_chunks())
	# The chunk rebuild updates ground and derived grass together. Publishing this
	# as a surface-only edit would move the grass one frame before the ground.
	assert(not grid.has_dirty_surface_cells())


# --- Cascade ----------------------------------------------------------------

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


static func _test_cascade_stops_at_the_board_edge() -> void:
	var grid := _make_grid()
	var corner := grid.min_cell()
	# A wave that runs off the board simply stops there; the operation is not
	# refused, because the missing ground is not an obstacle, it is the end.
	assert(_sculpt(grid, corner, 3) != null)
	assert(grid.height_of(corner) == 3)
	assert(grid.height_of(corner + Vector2i(1, 0)) == 2)
	assert(grid.height_of(corner + Vector2i(3, 0)) == 0)
	# A brush aimed off the board is refused outright.
	var solver := CascadeSolver.new()
	assert(solver.solve(grid, TerrainEditOperation.offset([corner - Vector2i(1, 0)] as Array[Vector2i], 1)) == null)
	assert(solver.rejection_reason == CascadeSolver.REASON_OUT_OF_BOUNDS)


static func _test_cascade_flows_around_a_hole() -> void:
	var grid := _make_grid()
	grid.set_hole(Vector2i(1, 0), true)
	assert(_sculpt(grid, Vector2i(0, 0), 3) != null)
	# The carved column keeps its data untouched and does not conduct the wave...
	assert(grid.height_of(Vector2i(1, 0)) == 0)
	assert(grid.height_of(Vector2i(2, 0)) == 0)
	# ...while the wave still travels the ways that remain open.
	assert(grid.height_of(Vector2i(0, 1)) == 2)
	assert(grid.height_of(Vector2i(1, 1)) == 1)

	# Painting height onto a hole is refused: there is no ground to move.
	var solver := CascadeSolver.new()
	assert(solver.solve(grid, TerrainEditOperation.offset([Vector2i(1, 0)] as Array[Vector2i], 1)) == null)
	assert(solver.rejection_reason == CascadeSolver.REASON_HOLE)


static func _test_cascade_is_deterministic() -> void:
	var first := _make_grid()
	var second := _make_grid()
	for grid: TerrainGrid in [first, second]:
		_fill_material(grid, TerrainMaterialCatalog.SAND)
		grid.set_material(Vector2i(3, 3), TerrainMaterialCatalog.STONE)
		grid.set_material(Vector2i(-2, 4), TerrainMaterialCatalog.GRASS)
	var brush: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-3, 2)]
	var first_delta := CascadeSolver.solve_operation(first, TerrainEditOperation.offset(brush, 4))
	# The same edit described in a different order must still give the same terrain.
	var shuffled: Array[Vector2i] = [Vector2i(-3, 2), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, 0)]
	var second_delta := CascadeSolver.solve_operation(second, TerrainEditOperation.offset(shuffled, 4))
	assert(first_delta != null and second_delta != null)
	first_delta.apply(first)
	second_delta.apply(second)
	_assert_same_grid(first.snapshot(), second.snapshot())
	assert(first_delta.cells == second_delta.cells)


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

	# A wave that stops one cell short of the anchor is fine.
	var short := CascadeSolver.new()
	var short_delta := short.solve(grid, TerrainEditOperation.offset([Vector2i(0, 0)] as Array[Vector2i], 2))
	assert(short_delta != null)


static func _test_cascade_rejects_beyond_height_range() -> void:
	var grid := _make_grid(TerrainGrid.MAX_HEIGHT - 1)
	var before := grid.snapshot()
	var solver := CascadeSolver.new()
	assert(solver.solve(grid, TerrainEditOperation.offset([Vector2i(0, 0)] as Array[Vector2i], 5)) == null)
	assert(solver.rejection_reason == CascadeSolver.REASON_HEIGHT_LIMIT)
	_assert_same_grid(before, grid.snapshot())
	# Levelling to an impossible height is the same answer.
	var level := CascadeSolver.new()
	assert(level.solve(grid, TerrainEditOperation.level([Vector2i(0, 0)] as Array[Vector2i], TerrainGrid.MIN_HEIGHT - 1)) == null)
	assert(level.rejection_reason == CascadeSolver.REASON_HEIGHT_LIMIT)


static func _test_cascade_rejects_nothing_to_do() -> void:
	var grid := _make_grid()
	var solver := CascadeSolver.new()
	assert(solver.solve(grid, TerrainEditOperation.offset([] as Array[Vector2i], 1)) == null)
	assert(solver.rejection_reason == CascadeSolver.REASON_NOTHING_TO_DO)
	# Levelling flat ground to the height it already has changes nothing, and
	# saying so is better than committing an empty delta onto the undo stack.
	var idle := CascadeSolver.new()
	assert(idle.solve(grid, TerrainEditOperation.level([Vector2i(0, 0)] as Array[Vector2i], 0)) == null)
	assert(idle.rejection_reason == CascadeSolver.REASON_NOTHING_TO_DO)
	assert(CascadeSolver.new().solve(null, TerrainEditOperation.offset([Vector2i(0, 0)] as Array[Vector2i], 1)) == null)
	assert(CascadeSolver.new().solve(grid, null) == null)


# --- Auto-slope (§3.2, §4.5) ------------------------------------------------

static func _test_auto_slope_decorates_a_grass_boundary() -> void:
	var grid := _make_grid()
	assert(_sculpt(grid, Vector2i(0, 0), 2) != null)
	# Grass holds a full step per cell, so the gentlest slope that fits the
	# cascade's own footprint is `steep`: one cell, one step, no ground moved.
	assert(grid.slope_of(Vector2i(1, 0)) == SlopeCatalog.STEEP)
	assert(grid.slope_direction_of(Vector2i(1, 0)) == SlopeCatalog.DIR_W)
	assert(grid.slope_index_of(Vector2i(1, 0)) == 0)
	assert(grid.height_of(Vector2i(1, 0)) == 1)
	assert(grid.is_ramp_valid_at(Vector2i(1, 0)))
	# The slope reaches exactly the top of the column beside it — no seam, and no
	# fractional data anywhere.
	assert(is_equal_approx(grid.corner_heights(Vector2i(1, 0))[TerrainGrid.CORNER_NW], 2.0))
	assert(is_equal_approx(grid.corner_heights(Vector2i(0, 0))[TerrainGrid.CORNER_NE], 2.0))


static func _test_auto_slope_terraces_sand_over_two_cells() -> void:
	var grid := _make_grid()
	_fill_material(grid, TerrainMaterialCatalog.SAND)
	assert(_sculpt(grid, Vector2i(0, 0), 2) != null)
	# Sand terraces every second cell, so the first boundary is between (1,0) and
	# (2,0) — and the gentlest class that fits its two-cell footprint is
	# `moderate`, laid across the very cells the cascade terraced.
	assert(grid.height_of(Vector2i(1, 0)) == 2 and grid.height_of(Vector2i(2, 0)) == 1)
	assert(grid.slope_of(Vector2i(2, 0)) == SlopeCatalog.MODERATE)
	assert(grid.slope_of(Vector2i(3, 0)) == SlopeCatalog.MODERATE)
	assert(grid.slope_direction_of(Vector2i(2, 0)) == SlopeCatalog.DIR_W)
	assert(grid.slope_index_of(Vector2i(2, 0)) == 1)
	assert(grid.slope_index_of(Vector2i(3, 0)) == 0)
	# The descent decorates the ground the cascade already shaped; it moves none.
	assert(grid.height_of(Vector2i(3, 0)) == 1)
	assert(grid.is_ramp_valid_at(Vector2i(3, 0)))
	assert(is_equal_approx(grid.corner_heights(Vector2i(2, 0))[TerrainGrid.CORNER_NW], 2.0))


static func _test_auto_slope_falls_back_to_cliff_on_rock() -> void:
	var grid := _make_grid()
	_fill_material(grid, TerrainMaterialCatalog.STONE)
	assert(_sculpt(grid, Vector2i(0, 0), 3) != null)
	# Rock spends no ground on a three-step drop, and no catalog class rises 3 in
	# one cell — so the boundary stays a bare face. That is a normal outcome (§3.2
	# step 4), not a refusal: the column still moved.
	assert(grid.height_of(Vector2i(0, 0)) == 3)
	assert(grid.slope_of(Vector2i(1, 0)) == SlopeCatalog.FLAT)
	assert(grid.slope_of(Vector2i(0, 0)) == SlopeCatalog.FLAT)

	# A four-step drop on rock does have a class: `pre_cliff`, one cell.
	var four := _make_grid()
	_fill_material(four, TerrainMaterialCatalog.STONE)
	assert(_sculpt(four, Vector2i(0, 0), 4) != null)
	assert(four.slope_of(Vector2i(1, 0)) == SlopeCatalog.PRE_CLIFF)
	assert(four.height_of(Vector2i(1, 0)) == 0)


static func _test_auto_skirt_descends_from_a_levelled_plateau() -> void:
	var grid := _make_grid()
	var plateau: Array[Vector2i] = []
	for z in range(-1, 2):
		for x in range(-1, 2):
			plateau.append(Vector2i(x, z))
	var solver := CascadeSolver.new()
	var delta := solver.solve(grid, TerrainEditOperation.level(plateau, 3))
	assert(delta != null)
	delta.apply(grid)

	# The plateau itself is flat at the requested height.
	for cell: Vector2i in plateau:
		assert(grid.height_of(cell) == 3)
		assert(grid.slope_of(cell) == SlopeCatalog.FLAT)
	# Outside it the cascade terraced the ground, and the skirt turned those
	# terraces into a walkable 45° descent instead of three bare faces (§4.5).
	assert(grid.height_of(Vector2i(2, 0)) == 2)
	assert(grid.height_of(Vector2i(3, 0)) == 1)
	assert(grid.height_of(Vector2i(4, 0)) == 0)
	for x in range(2, 5):
		assert(grid.slope_of(Vector2i(x, 0)) == SlopeCatalog.STEEP)
		assert(grid.slope_direction_of(Vector2i(x, 0)) == SlopeCatalog.DIR_W)
		assert(grid.is_ramp_valid_at(Vector2i(x, 0)))
	# Every column is still an integer number of steps; only the mesh is fractional.
	assert(is_equal_approx(grid.corner_heights(Vector2i(2, 0))[TerrainGrid.CORNER_NW], 3.0))


static func _test_auto_slope_refuses_occupied_ground() -> void:
	var grid := _make_grid()
	# An authored ramp already owns the ground west of the column, so the skirt
	# has nowhere to go and leaves that boundary a cliff rather than dissolving
	# somebody else's geometry.
	grid.set_height(Vector2i(0, 0), 1)
	assert(grid.place_ramp(Vector2i(-4, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	var before_slope := grid.slope_of(Vector2i(-1, 0))
	assert(before_slope == SlopeCatalog.GENTLE)

	assert(_sculpt(grid, Vector2i(0, 4), 1) != null)
	assert(grid.slope_of(Vector2i(-1, 0)) == SlopeCatalog.GENTLE)
	assert(grid.is_ramp_valid_at(Vector2i(-1, 0)))


static func _test_auto_slope_never_moves_an_anchor() -> void:
	var grid := _make_grid()
	grid.set_anchor(Vector2i(2, 0), true)
	# Two steps up beside an anchored column: the cascade stays clear of it, and
	# the skirt may not raise it to build a descent either.
	var solver := CascadeSolver.new()
	var delta := solver.solve(grid, TerrainEditOperation.level([Vector2i(0, 0)] as Array[Vector2i], 2))
	assert(delta != null)
	delta.apply(grid)
	assert(grid.height_of(Vector2i(2, 0)) == 0)
	assert(grid.slope_of(Vector2i(2, 0)) == SlopeCatalog.FLAT)
	assert(not grid.is_anchor(Vector2i(1, 0)))


static func _test_requested_slope_profile_shapes_full_footprint() -> void:
	var grid := _make_grid()
	var solver := CascadeSolver.new()
	var operation := TerrainEditOperation.offset(
		[Vector2i.ZERO] as Array[Vector2i], 3,
		TerrainEditOperation.Mode.SCULPT, SlopeCatalog.CLASS_GENTLE,
	)
	var delta := solver.solve(grid, operation)
	assert(delta != null)
	delta.apply(grid)
	# A forced 1:4 profile spends four cells on each of the three half-metre
	# steps. The cascade creates the missing terraces and SlopeAssigner writes
	# three matching ramp objects over them.
	for x in range(4, 16, 4):
		assert(grid.slope_class_at(Vector2i(x, 0)) == SlopeCatalog.CLASS_GENTLE)
		assert(grid.is_ramp_valid_at(Vector2i(x, 0)))
	assert(grid.height_of(Vector2i(3, 0)) == 3)
	assert(grid.height_of(Vector2i(7, 0)) == 2)
	assert(grid.height_of(Vector2i(11, 0)) == 1)
	assert(grid.height_of(Vector2i(15, 0)) == 0)

	# Lowering uses the same profile mirrored: missing blocks are cut away from
	# the pit and the authored class is preserved on both steps.
	var lowered := _make_grid()
	for z in range(-16, 16):
		for x in range(-16, 16):
			lowered.set_height(Vector2i(x, z), 3)
	var lower_delta := CascadeSolver.new().solve(lowered, TerrainEditOperation.offset(
		[Vector2i.ZERO] as Array[Vector2i], -2,
		TerrainEditOperation.Mode.SCULPT, SlopeCatalog.CLASS_GENTLE,
	))
	assert(lower_delta != null)
	lower_delta.apply(lowered)
	assert(lowered.height_of(Vector2i(3, 0)) == 1)
	assert(lowered.height_of(Vector2i(7, 0)) == 2)
	assert(lowered.is_ramp_valid_at(Vector2i(1, 0)))
	assert(lowered.is_ramp_valid_at(Vector2i(5, 0)))

	# Level shares the same slope policy instead of silently falling back to
	# the material's natural repose angle.
	var levelled := _make_grid()
	var level_delta := CascadeSolver.new().solve(levelled, TerrainEditOperation.level(
		[Vector2i.ZERO] as Array[Vector2i], 2, SlopeCatalog.CLASS_GENTLE,
	))
	assert(level_delta != null)
	level_delta.apply(levelled)
	assert(levelled.height_of(Vector2i(3, 0)) == 2)
	assert(levelled.height_of(Vector2i(7, 0)) == 1)
	assert(levelled.slope_class_at(Vector2i(4, 0)) == SlopeCatalog.CLASS_GENTLE)
	assert(levelled.slope_class_at(Vector2i(8, 0)) == SlopeCatalog.CLASS_GENTLE)
	assert(levelled.is_ramp_valid_at(Vector2i(4, 0)))
	assert(levelled.is_ramp_valid_at(Vector2i(8, 0)))


## Every corner of a sculpted grass hill, seen from both cells that share it.
## Returns how many disagree — a disagreement is a vertical wedge in the mesh.
static func _count_open_corners(grid: TerrainGrid, radius: int) -> int:
	var open := 0
	for z in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var cell := Vector2i(x, z)
			var mine := grid.corner_heights(cell)
			var east := grid.corner_heights(cell + Vector2i(1, 0))
			var south := grid.corner_heights(cell + Vector2i(0, 1))
			var seams: Array = [
				[mine[TerrainGrid.CORNER_NE], east[TerrainGrid.CORNER_NW]],
				[mine[TerrainGrid.CORNER_SE], east[TerrainGrid.CORNER_SW]],
				[mine[TerrainGrid.CORNER_SW], south[TerrainGrid.CORNER_NW]],
				[mine[TerrainGrid.CORNER_SE], south[TerrainGrid.CORNER_NE]],
			]
			for seam: Array in seams:
				if absf(float(seam[0]) - float(seam[1])) > 0.001:
					open += 1
	return open


## Wedges: seams that match at one end and not at the other. A seam that differs
## at both ends is an honest wall between two terraces; a seam that differs at one
## end is the triangular fin §3.4 exists to remove.
static func _count_wedges(grid: TerrainGrid, radius: int) -> int:
	var wedges := 0
	for z in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var cell := Vector2i(x, z)
			var mine := grid.corner_heights(cell)
			var east := grid.corner_heights(cell + Vector2i(1, 0))
			var south := grid.corner_heights(cell + Vector2i(0, 1))
			var east_open := [
				absf(mine[TerrainGrid.CORNER_NE] - east[TerrainGrid.CORNER_NW]) > 0.001,
				absf(mine[TerrainGrid.CORNER_SE] - east[TerrainGrid.CORNER_SW]) > 0.001,
			]
			var south_open := [
				absf(mine[TerrainGrid.CORNER_SW] - south[TerrainGrid.CORNER_NW]) > 0.001,
				absf(mine[TerrainGrid.CORNER_SE] - south[TerrainGrid.CORNER_NE]) > 0.001,
			]
			if bool(east_open[0]) != bool(east_open[1]):
				wedges += 1
			if bool(south_open[0]) != bool(south_open[1]):
				wedges += 1
	return wedges


static func _test_hillsides_grow_no_wedges() -> void:
	# The shapes a player actually makes with a brush, each of which used to end up
	# speckled with triangular fins where two slopes met at a right angle.
	var sand := _make_grid()
	_fill_material(sand, TerrainMaterialCatalog.SAND)
	assert(_sculpt(sand, Vector2i(0, 0), 4) != null)
	assert(_count_wedges(sand, 12) == 0)

	# A patch of one material inside another: the two halves of the hill terrace at
	# different rates and still have to meet.
	var mixed := _make_grid()
	for z in range(-3, 4):
		for x in range(-3, 4):
			mixed.set_material(Vector2i(x, z), TerrainMaterialCatalog.SAND)
	assert(_sculpt(mixed, Vector2i(0, 0), 4) != null)
	assert(_count_wedges(mixed, 10) == 0)

	# Two strokes that run into each other.
	var twice := _make_grid()
	assert(_sculpt(twice, Vector2i(0, 0), 4) != null)
	assert(_sculpt(twice, Vector2i(2, 2), 4) != null)
	assert(_count_wedges(twice, 10) == 0)

	# A wide brush, and a plateau levelled out of one.
	var wide := _make_grid()
	var brush: Array[Vector2i] = []
	for z in range(-2, 3):
		for x in range(-2, 3):
			brush.append(Vector2i(x, z))
	var solver := CascadeSolver.new()
	var delta := solver.solve(wide, TerrainEditOperation.level(brush, 3))
	assert(delta != null)
	delta.apply(wide)
	assert(_count_wedges(wide, 10) == 0)


static func _test_grass_hillside_closes_every_corner() -> void:
	# §3.4 in one number. A hill of 45° cells is four ramps meeting at every
	# diagonal; each raises different corners of the same point, so without the
	# neighbour rule the mesh grows a vertical wedge on every diagonal — the whole
	# hillside is speckled with them. With it, every shared corner agrees exactly.
	for delta in [2, 3, 5]:
		var grid := _make_grid()
		assert(_sculpt(grid, Vector2i(0, 0), delta) != null)
		assert(_count_open_corners(grid, delta + 3) == 0)
	# Digging is the same surface mirrored; the inside of a pit is a harder shape
	# (a column can be lower than three of its neighbours at once) and keeps a
	# seam or two, but nothing like the speckle a hillside had.
	var pit := _make_grid()
	assert(_sculpt(pit, Vector2i(0, 0), -3) != null)
	assert(_count_open_corners(pit, 6) <= 4)

	# A terrace is the opposite promise: it must keep its face. Flat ground never
	# follows flat ground, however close the step.
	var terrace := _make_grid()
	assert(_sculpt(terrace, Vector2i(0, 0), 2, TerrainEditOperation.Mode.TERRACE) != null)
	assert(_count_open_corners(terrace, 3) > 0)
	for corner: float in terrace.corner_heights(Vector2i(1, 0)):
		assert(is_equal_approx(corner, 0.0))


static func _test_terrace_mode_assigns_no_slopes() -> void:
	var grid := _make_grid()
	assert(_sculpt(grid, Vector2i(0, 0), 2, TerrainEditOperation.Mode.TERRACE) != null)
	# Terrace asked for a sheer edge and gets one — no cascade, no decoration.
	for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
		var neighbour := Vector2i(0, 0) + SlopeCatalog.direction_offset(direction)
		assert(grid.height_of(neighbour) == 0)
		assert(grid.slope_of(neighbour) == SlopeCatalog.FLAT)


# --- Transactions -----------------------------------------------------------

static func _test_delta_apply_and_revert_restore_grid() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(4, 0), 1)
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	var before := grid.snapshot()

	var solver := CascadeSolver.new()
	var delta := solver.solve(grid, TerrainEditOperation.offset([Vector2i(2, 0)] as Array[Vector2i], 2))
	assert(delta != null)
	delta.apply(grid)
	# Moving one cell of a ramp dissolves the whole object; what the auto-slope
	# pass then writes over the result is a new decision, not the old ramp.
	assert(not grid.is_ramp_valid_at(Vector2i(0, 0)) or grid.slope_of(Vector2i(0, 0)) != SlopeCatalog.GENTLE)
	assert(grid.slope_index_of(Vector2i(3, 0)) != 3 or grid.slope_of(Vector2i(3, 0)) != SlopeCatalog.GENTLE)

	delta.revert(grid)
	_assert_same_grid(before, grid.snapshot())
	assert(grid.slope_of(Vector2i(1, 0)) == SlopeCatalog.GENTLE)
	assert(grid.slope_index_of(Vector2i(1, 0)) == 1)
	assert(grid.is_ramp_valid_at(Vector2i(1, 0)))


static func _test_delta_carries_material_and_flags() -> void:
	var grid := _make_grid()
	var state := TerrainDelta.state_of(grid, Vector2i(0, 0))
	assert(state.size() == TerrainDelta.STATE_SIZE)
	# A delta describes the whole column. Anything it cannot express is something
	# undo would silently lose.
	var delta := TerrainDelta.new()
	delta.record(Vector2i(0, 0), state, TerrainDelta.make_state(
		4, SlopeCatalog.CLASS_STEEP, SlopeCatalog.DIR_E, 0,
		TerrainMaterialCatalog.index_of(TerrainMaterialCatalog.SAND), TerrainCell.FLAG_ANCHOR,
	))
	var before := grid.snapshot()
	delta.apply(grid)
	assert(grid.height_of(Vector2i(0, 0)) == 4)
	assert(grid.material_of(Vector2i(0, 0)) == TerrainMaterialCatalog.SAND)
	assert(grid.is_anchor(Vector2i(0, 0)))
	assert(grid.slope_of(Vector2i(0, 0)) == SlopeCatalog.STEEP)
	delta.revert(grid)
	_assert_same_grid(before, grid.snapshot())


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

	# A refused operation leaves the history alone and says why.
	var depth := service.undo_depth()
	grid.set_anchor(Vector2i(-8, -8), true)
	assert(not service.apply_operation(TerrainEditOperation.offset([Vector2i(-8, -8)] as Array[Vector2i], 1)))
	assert(service.last_rejection() == CascadeSolver.REASON_ANCHOR)
	assert(service.undo_depth() == depth)

	# Ramps are transactions too.
	assert(grid.set_height(Vector2i(-4, 8), 1))
	assert(service.place_ramp(Vector2i(-8, 8), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	assert(grid.slope_of(Vector2i(-6, 8)) == SlopeCatalog.GENTLE)
	assert(service.undo())
	assert(grid.slope_of(Vector2i(-6, 8)) == SlopeCatalog.FLAT)
	# As is dissolving one.
	assert(service.redo())
	assert(service.dissolve_ramp(Vector2i(-6, 8)))
	assert(grid.slope_of(Vector2i(-6, 8)) == SlopeCatalog.FLAT)
	assert(service.undo())
	assert(grid.slope_of(Vector2i(-6, 8)) == SlopeCatalog.GENTLE)
	assert(not service.place_ramp(Vector2i(-8, 8), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))


static func _test_service_paint_and_hole_are_undoable() -> void:
	var grid := _make_grid()
	var service := TerrainService.new()
	service.configure(grid)
	var before := grid.snapshot()

	# Material is not decoration — it sets the angle of repose — so painting is a
	# transaction like any other edit.
	var brush: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 0)]
	assert(service.paint_material(brush, TerrainMaterialCatalog.SAND))
	assert(grid.material_of(Vector2i(0, 0)) == TerrainMaterialCatalog.SAND)
	assert(service.last_delta_size() == 2)
	# Repainting the same material is not an edit.
	assert(not service.paint_material(brush, TerrainMaterialCatalog.SAND))
	assert(not service.paint_material(brush, &"lava"))
	assert(service.undo())
	_assert_same_grid(before, grid.snapshot())

	# Cutting a hole takes the ramps leaning on it along, in the same transaction.
	grid.set_height(Vector2i(4, 0), 1)
	assert(grid.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	var with_ramp := grid.snapshot()
	assert(service.set_hole([Vector2i(4, 0)] as Array[Vector2i], true))
	assert(grid.is_hole(Vector2i(4, 0)))
	assert(grid.slope_of(Vector2i(1, 0)) == SlopeCatalog.FLAT)
	assert(not service.set_hole([Vector2i(4, 0)] as Array[Vector2i], true))
	assert(service.undo())
	_assert_same_grid(with_ramp, grid.snapshot())
	assert(grid.slope_of(Vector2i(1, 0)) == SlopeCatalog.GENTLE)
