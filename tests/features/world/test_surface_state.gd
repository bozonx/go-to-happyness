class_name TestSurfaceState
extends RefCounted

## Surface state end to end: painting, wear, snow and what they cost
## (design_docs/engine/terrain_materials.md §10).
##
## The interesting claims are all negative ones — what a surface edit must NOT do.
## It must not rebuild a chunk, must not move `topology_revision`, must not
## survive an undo. Each of those, if it broke, would break quietly: the picture
## would still be right and only the frame time or the citizens' routes would go
## wrong.
##
## Seasonal accumulation and melt (§6.2), regrowth of `scorched` (§6.4) and map
## regions (§8) are deliberately not covered: the services that produce them do
## not exist yet, and the state they write is checked here through the authoring
## path instead.

const BOARD_CELLS := 32


static func run_all() -> void:
	_test_paint_writes_texels_and_no_geometry()
	_test_paint_rejects_an_unstable_material()
	_test_material_paint_clamps_the_carried_variant()
	_test_undo_restores_material_and_detail()
	_test_detail_survives_a_height_edit()
	print("    [PASS] Surface Paint Tests")
	_test_wear_rises_once_per_tick_per_cell()
	_test_wear_needs_traffic_not_a_single_walker()
	_test_wear_recovers_after_quiet_days_but_rock_never_does()
	_test_tall_grass_weight_falls_from_two_to_one()
	print("    [PASS] Surface Wear Tests")
	_test_snow_changes_weight_and_not_passability()
	_test_material_weight_reaches_navigation()
	print("    [PASS] Surface Weight Tests")


static func _make() -> Dictionary:
	var grid := TerrainGrid.new()
	grid.configure(1.0, BOARD_CELLS)
	var service := TerrainService.new()
	service.configure(grid)
	var nav_grid := NavGrid.new()
	var publisher := TerrainNavigationPublisher.new()
	publisher.configure(grid, nav_grid, service)
	var wear := SurfaceWearService.new()
	wear.configure(service)
	# The demo board is written straight to the grid; drain what that dirtied so a
	# test can assert on what IT dirtied.
	grid.take_dirty_chunks()
	grid.take_dirty_surface_cells()
	return {"grid": grid, "service": service, "nav": nav_grid, "publisher": publisher, "wear": wear}


static func _brush(cells: Array) -> Array[Vector2i]:
	var typed: Array[Vector2i] = []
	for cell: Vector2i in cells:
		typed.append(cell)
	return typed


# --- Painting -----------------------------------------------------------------

## §7.5, the row that pays for the whole scheme: a material brush updates a texel
## and republishes a weight. No remesh, no topology bump.
static func _test_paint_writes_texels_and_no_geometry() -> void:
	var world := _make()
	var grid: TerrainGrid = world["grid"]
	var service: TerrainService = world["service"]
	var nav_grid: NavGrid = world["nav"]
	var topology_before := nav_grid.topology_revision()
	var weights_before := nav_grid.weights_revision()

	var cells := _brush([Vector2i(0, 0), Vector2i(1, 0)])
	assert(service.paint_material(cells, TerrainMaterialCatalog.MUD))
	assert(grid.material_of(Vector2i(0, 0)) == TerrainMaterialCatalog.MUD)
	assert(not grid.has_dirty_chunks())
	assert(grid.has_dirty_surface_cells())
	assert(grid.take_dirty_surface_cells().size() == 2)
	assert(nav_grid.topology_revision() == topology_before)
	assert(nav_grid.weights_revision() > weights_before)

	# The same holds for the detail brushes.
	assert(service.paint_variant(cells, 1))
	assert(service.set_snow_depth(cells, 2))
	assert(grid.variant_at(Vector2i(0, 0)) == 1)
	assert(grid.snow_depth_at(Vector2i(0, 0)) == 2)
	assert(not grid.has_dirty_chunks())
	assert(nav_grid.topology_revision() == topology_before)

	# Painting what is already there is not an edit at all.
	assert(not service.paint_material(cells, TerrainMaterialCatalog.MUD))


## A texel-only material paint must not create a sand or mud wall. Height edits
## are the operation that cascades; material edits reject instead.
static func _test_paint_rejects_an_unstable_material() -> void:
	var world := _make()
	var grid: TerrainGrid = world["grid"]
	var service: TerrainService = world["service"]
	var cell := Vector2i(0, 0)
	assert(grid.set_height(cell, 1))
	assert(not service.paint_material(_brush([cell]), TerrainMaterialCatalog.SAND))
	assert(service.last_rejection() == TerrainService.REASON_UNSTABLE_MATERIAL)
	assert(grid.material_of(cell) == TerrainMaterialCatalog.DEFAULT_MATERIAL)
	assert(service.paint_material(_brush([cell]), TerrainMaterialCatalog.STONE))


## Variant numbers are meaningful only within their material palette. A carried
## grass variant 3 therefore becomes mud's last valid variant (1), not a raw
## texture-array layer.
static func _test_material_paint_clamps_the_carried_variant() -> void:
	var world := _make()
	var grid: TerrainGrid = world["grid"]
	var service: TerrainService = world["service"]
	var cell := Vector2i(0, 0)
	assert(service.paint_material(_brush([cell]), TerrainMaterialCatalog.GRASS, 3))
	assert(grid.variant_at(cell) == 3)
	assert(service.paint_material(_brush([cell]), TerrainMaterialCatalog.MUD))
	assert(grid.variant_at(cell) == 1)


## §4.4: the delta carries the WHOLE column, detail byte included. Anything it
## cannot express, undo loses silently.
static func _test_undo_restores_material_and_detail() -> void:
	var world := _make()
	var grid: TerrainGrid = world["grid"]
	var service: TerrainService = world["service"]
	var cell := Vector2i(2, 3)
	var cells := _brush([cell])
	assert(service.paint_material(cells, TerrainMaterialCatalog.GRASS_TALL, 2))
	assert(service.set_wear(cells, 2))
	var before := grid.snapshot()

	assert(service.set_snow_depth(cells, 3))
	assert(grid.snow_depth_at(cell) == 3)
	assert(service.undo())
	assert(grid.snapshot() == before)
	assert(grid.wear_at(cell) == 2)
	assert(grid.variant_at(cell) == 2)
	assert(grid.material_of(cell) == TerrainMaterialCatalog.GRASS_TALL)

	assert(service.undo())            # the wear edit
	assert(grid.wear_at(cell) == 0)
	assert(service.undo())            # the paint
	assert(grid.material_of(cell) == TerrainMaterialCatalog.DEFAULT_MATERIAL)
	assert(grid.variant_at(cell) == 0)


## Moving ground must not wipe the surface painted on it: a cascade that reset
## variants would repaint half a map every time a hill was raised.
static func _test_detail_survives_a_height_edit() -> void:
	var world := _make()
	var grid: TerrainGrid = world["grid"]
	var service: TerrainService = world["service"]
	var cell := Vector2i(0, 0)
	assert(service.paint_material(_brush([cell]), TerrainMaterialCatalog.SAND, 1))
	assert(service.set_wear(_brush([cell]), 1))
	assert(service.apply_operation(TerrainEditOperation.offset(_brush([cell]), 2)))
	assert(grid.height_of(cell) == 2)
	assert(grid.material_of(cell) == TerrainMaterialCatalog.SAND)
	assert(grid.variant_at(cell) == 1)
	assert(grid.wear_at(cell) == 1)
	# ...and that edit DID move geometry, so it dirtied chunks.
	assert(grid.has_dirty_chunks())


# --- Wear ---------------------------------------------------------------------

## §6.1: at most one crossing counted per cell per simulation tick. Without the
## throttle a crowd standing on a meadow flattens it inside one frame, because
## every body reports on every step.
static func _test_wear_rises_once_per_tick_per_cell() -> void:
	var world := _make()
	var wear: SurfaceWearService = world["wear"]
	var grid: TerrainGrid = world["grid"]
	var service: TerrainService = world["service"]
	var cell := Vector2i(4, 4)
	assert(service.paint_material(_brush([cell]), TerrainMaterialCatalog.GRASS_TALL))

	# A hundred bodies on one tick count as one crossing.
	wear.begin_tick()
	for _body in 100:
		wear.record_crossing(cell)
	assert(wear.progress_at(cell) == 1)
	assert(wear.flush(0).is_empty())
	assert(grid.wear_at(cell) == 0)

	# Ticks are what accumulate.
	for _tick in SurfaceWearService.CROSSINGS_PER_WEAR_LEVEL - 1:
		wear.begin_tick()
		wear.record_crossing(cell)
	var raised := wear.flush(0)
	assert(raised.size() == 1 and raised[0] == cell)
	assert(grid.wear_at(cell) == 1)
	# And it went through the service, so it is undoable like any other edit.
	assert(service.undo())
	assert(grid.wear_at(cell) == 0)


static func _test_wear_needs_traffic_not_a_single_walker() -> void:
	var world := _make()
	var wear: SurfaceWearService = world["wear"]
	var grid: TerrainGrid = world["grid"]
	var cell := Vector2i(5, 5)
	wear.begin_tick()
	wear.record_crossing(cell)
	assert(wear.flush(0).is_empty())
	assert(grid.wear_at(cell) == 0)
	# Cells nobody walked on are never touched, however busy the neighbours are.
	assert(grid.wear_at(Vector2i(6, 5)) == 0)


## §6.1: recovery is a per-material period, and 0 means never. Rock keeps the path
## worn into it for good.
static func _test_wear_recovers_after_quiet_days_but_rock_never_does() -> void:
	var world := _make()
	var wear: SurfaceWearService = world["wear"]
	var grid: TerrainGrid = world["grid"]
	var service: TerrainService = world["service"]
	var meadow := Vector2i(-3, -3)
	var rock := Vector2i(-4, -3)
	assert(service.paint_material(_brush([meadow]), TerrainMaterialCatalog.GRASS_TALL))
	assert(service.paint_material(_brush([rock]), TerrainMaterialCatalog.STONE))

	for cell: Vector2i in [meadow, rock]:
		for _tick in SurfaceWearService.CROSSINGS_PER_WEAR_LEVEL:
			wear.begin_tick()
			wear.record_crossing(cell)
	wear.flush(0)
	assert(grid.wear_at(meadow) == 1)
	assert(grid.wear_at(rock) == 1)

	var recovery := TerrainMaterialCatalog.wear_recovery_days(TerrainMaterialCatalog.index_of(TerrainMaterialCatalog.GRASS_TALL))
	assert(wear.recover(recovery - 1).is_empty())
	assert(grid.wear_at(meadow) == 1)
	var healed := wear.recover(recovery)
	assert(healed.has(meadow))
	assert(grid.wear_at(meadow) == 0)
	# Rock was in the same pass and stayed exactly as trodden as it was.
	assert(not healed.has(rock))
	assert(grid.wear_at(rock) == 1)
	assert(wear.recover(recovery * 100).is_empty())
	assert(grid.wear_at(rock) == 1)


## The §6.1 table, read through the grid: 2.0 untouched, 1.0 once it is a path.
static func _test_tall_grass_weight_falls_from_two_to_one() -> void:
	var world := _make()
	var grid: TerrainGrid = world["grid"]
	var service: TerrainService = world["service"]
	var cell := Vector2i(1, 1)
	assert(service.paint_material(_brush([cell]), TerrainMaterialCatalog.GRASS_TALL))
	assert(is_equal_approx(grid.surface_weight_at(cell), 2.0))
	assert(service.set_wear(_brush([cell]), 1))
	assert(is_equal_approx(grid.surface_weight_at(cell), 1.5))
	assert(service.set_wear(_brush([cell]), 2))
	assert(is_equal_approx(grid.surface_weight_at(cell), 1.0))


# --- Weights in navigation ------------------------------------------------------

## §6.2 and §7.5 together: snow costs speed and nothing else. The ground under a
## drift is still ground, and every route planned across it is still valid.
static func _test_snow_changes_weight_and_not_passability() -> void:
	var world := _make()
	var service: TerrainService = world["service"]
	var nav_grid: NavGrid = world["nav"]
	var cell := Vector2i(0, 2)
	var before := nav_grid.get_cell_weight(cell)
	var topology_before := nav_grid.topology_revision()
	var weights_before := nav_grid.weights_revision()

	assert(service.set_snow_depth(_brush([cell]), 3))
	assert(nav_grid.is_walkable(cell))
	assert(nav_grid.is_edge_passable(cell, cell + Vector2i(1, 0)))
	assert(nav_grid.get_cell_weight(cell) > before)
	assert(is_equal_approx(nav_grid.get_cell_weight(cell), before * 2.2))
	assert(nav_grid.topology_revision() == topology_before)
	assert(nav_grid.weights_revision() > weights_before)


static func _test_material_weight_reaches_navigation() -> void:
	var world := _make()
	var service: TerrainService = world["service"]
	var nav_grid: NavGrid = world["nav"]
	var cell := Vector2i(-1, -1)
	var grass_weight := nav_grid.get_cell_weight(cell)
	assert(service.paint_material(_brush([cell]), TerrainMaterialCatalog.MUD))
	assert(is_equal_approx(nav_grid.get_cell_weight(cell), grass_weight * 2.0))
	assert(service.paint_material(_brush([cell]), TerrainMaterialCatalog.SAND))
	assert(is_equal_approx(nav_grid.get_cell_weight(cell), grass_weight * 1.3))
	# A road over it is a surface of its own and is priced as one — the material
	# under a paved road must not be charged twice (§1).
	nav_grid.set_road_cell_weights({cell: 1.0})
	assert(is_equal_approx(nav_grid.get_cell_weight(cell), 1.0))
