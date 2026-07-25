class_name TestDomainTerrainNavigation
extends RefCounted

## Phase 3 of the terrain system: routing over real ground
## (design_docs/core/grid_terrain_system.md §10).
##
## The thing worth testing here is the one rule that a cell-based grid cannot
## express — passability lives on the EDGE. Two free columns on either side of a
## terrace are both perfectly standable and still not connected, and every test
## below is a variation of that: a cliff that must block, a ramp that must be the
## only way up, and a ramp too steep for a cart but not for a walker.

const GridRouteServiceScript = preload("res://game/features/routing/application/grid_route_service.gd")

const BOARD_CELLS := 32
const CART := &"cart"


static func run_all() -> void:
	_test_nav_cell_keys()
	_test_slope_class_from_gradient()
	_test_flat_terrain_leaves_routing_unchanged()
	_test_terrace_edge_blocks_and_ramp_opens_it()
	_test_ramp_too_steep_for_a_cart()
	_test_slope_costs_speed()
	_test_holes_are_not_walkable()
	_test_height_at_agrees_with_terrain()
	print("    [PASS] Terrain Navigation Tests")


# --- Building blocks ---------------------------------------------------------

static func _terrain() -> TerrainGrid:
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, BOARD_CELLS)
	return terrain


static func _nav_over(terrain: TerrainGrid) -> NavGrid:
	var grid := NavGrid.new()
	grid.configure(terrain.cell_size, BOARD_CELLS)
	TerrainNavigationPublisher.publish(terrain, grid)
	return grid


static func _centre(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)


## A plateau two steps above the plain, starting at x = 4. Nothing shapes the
## boundary, so it is a sheer face — §4.1's terrace beside a terrace.
static func _raise_plateau(terrain: TerrainGrid) -> void:
	for z in range(-8, 9):
		for x in range(4, 9):
			assert(terrain.set_height(Vector2i(x, z), 2))


static func _route(grid: NavGrid, from: Vector2i, to: Vector2i, profile: StringName = NavGrid.PEDESTRIAN_PROFILE) -> RouteResult:
	var router: RefCounted = GridRouteServiceScript.new()
	router.configure(grid)
	return router.find_route_for_profile(_centre(from), _centre(to), profile)


# --- Tests -------------------------------------------------------------------

static func _test_nav_cell_keys() -> void:
	var key := NavCell.ground(Vector2i(3, -7))
	assert(NavCell.cell_of(key) == Vector2i(3, -7))
	assert(NavCell.level_of(key) == NavCell.GROUND)
	# The key is a value, so two of them made independently are the same key —
	# this is what lets it index a dictionary at all.
	assert(NavCell.of(Vector2i(3, -7)) == key)
	assert(NavCell.of(Vector2i(3, -7), 1) != key)
	assert(NavCell.offset(key, Vector2i(1, 0)) == NavCell.ground(Vector2i(4, -7)))
	assert(NavCell.ground_keys({Vector2i(1, 1): true, "not a cell": true}) == {NavCell.ground(Vector2i(1, 1)): true})


static func _test_slope_class_from_gradient() -> void:
	# The classification is the catalog read backwards: the flattest slope that
	# still gains this much height per cell.
	assert(NavTerrainField.class_from_steps_per_cell(0.0) == 0)
	assert(NavTerrainField.class_from_steps_per_cell(0.25) == 2)
	assert(NavTerrainField.class_from_steps_per_cell(0.3) == 3)
	assert(NavTerrainField.class_from_steps_per_cell(1.0) == 4)
	assert(NavTerrainField.class_from_steps_per_cell(2.0) == 5)
	assert(NavTerrainField.class_from_steps_per_cell(9.0) == NavTerrainField.CLASS_CLIFF)
	assert(is_equal_approx(NavTerrainField.speed_multiplier(4, true), 0.5))
	assert(NavTerrainField.speed_multiplier(4, false) <= 0.0)


static func _test_flat_terrain_leaves_routing_unchanged() -> void:
	# Publishing flat ground must not change a single routing answer: the whole
	# settlement runs on it today, and a regression here is invisible until a
	# citizen walks into a wall that is not there.
	var grid := _nav_over(_terrain())
	assert(grid.has_terrain_field())
	assert(grid.is_walkable(Vector2i(0, 0)))
	assert(grid.is_edge_passable(Vector2i(0, 0), Vector2i(1, 1)))
	assert(is_equal_approx(grid.get_cell_weight(Vector2i(0, 0)), NavGrid.DEFAULT_CELL_WEIGHT))
	assert(is_equal_approx(grid.height_at(_centre(Vector2i(2, 2))), 0.0))
	var route := _route(grid, Vector2i(-3, 0), Vector2i(3, 0))
	assert(route.reachable and route.waypoints.size() == 1)


static func _test_terrace_edge_blocks_and_ramp_opens_it() -> void:
	var terrain := _terrain()
	_raise_plateau(terrain)
	var grid := _nav_over(terrain)

	# Both columns are standable, and the step between them still does not exist.
	assert(grid.is_walkable(Vector2i(3, 0)) and grid.is_walkable(Vector2i(4, 0)))
	assert(not grid.is_edge_passable(Vector2i(3, 0), Vector2i(4, 0)))
	assert(not grid.is_edge_passable(Vector2i(3, 0), Vector2i(4, 1)))
	assert(not grid.are_cells_connected(Vector2i(0, 0), Vector2i(6, 0)))
	assert(not _route(grid, Vector2i(0, 0), Vector2i(6, 0)).reachable)
	# A straight line may not climb it either, or smoothing would put the route
	# back through the face the search just avoided.
	assert(not grid.is_segment_clear(_centre(Vector2i(3, 0)), _centre(Vector2i(5, 0))))

	# One `very_steep` ramp rises the full two steps in one cell, and it is the
	# only way onto the plateau.
	assert(terrain.place_ramp(Vector2i(3, 0), SlopeCatalog.VERY_STEEP, SlopeCatalog.DIR_E))
	TerrainNavigationPublisher.publish(terrain, grid)
	assert(grid.is_edge_passable(Vector2i(3, 0), Vector2i(4, 0)))
	assert(grid.are_cells_connected(Vector2i(0, 0), Vector2i(6, 0)))
	assert(_route(grid, Vector2i(0, 0), Vector2i(6, 0)).reachable)

	# Elsewhere along the terrace the face is untouched, so a walker starting well
	# along it reaches the plateau only by detouring to the ramp: the straight line
	# is not clear, and the route is.
	assert(not grid.is_edge_passable(Vector2i(3, 4), Vector2i(4, 4)))
	assert(not grid.is_segment_clear(_centre(Vector2i(0, 6)), _centre(Vector2i(6, 6))))
	assert(_route(grid, Vector2i(0, 6), Vector2i(6, 6)).reachable)

	# And the ramp is what carries all of it: dissolving it seals the plateau again.
	assert(terrain.dissolve_ramp_at(Vector2i(3, 0)))
	TerrainNavigationPublisher.publish(terrain, grid)
	assert(not _route(grid, Vector2i(0, 6), Vector2i(6, 6)).reachable)


static func _test_ramp_too_steep_for_a_cart() -> void:
	var terrain := _terrain()
	_raise_plateau(terrain)
	assert(terrain.place_ramp(Vector2i(3, 0), SlopeCatalog.VERY_STEEP, SlopeCatalog.DIR_E))
	var grid := _nav_over(terrain)

	# §10.1: a pedestrian tolerates class 5, a cart only class 3. The ramp surface
	# itself is already out of reach for the cart, so it never gets to the edge.
	assert(grid.is_walkable(Vector2i(3, 0)))
	assert(not grid.is_walkable(Vector2i(3, 0), CART))
	assert(not _route(grid, Vector2i(0, 0), Vector2i(6, 0), CART).reachable)
	assert(_route(grid, Vector2i(0, 0), Vector2i(6, 0)).reachable)

	# A `gentle` ramp climbs one step over four cells — well inside what a cart
	# accepts — so the same plateau becomes reachable when the road is built for it.
	var cart_terrain := _terrain()
	for z in range(-8, 9):
		for x in range(4, 9):
			assert(cart_terrain.set_height(Vector2i(x, z), 1))
	assert(cart_terrain.place_ramp(Vector2i(0, 0), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	var cart_grid := _nav_over(cart_terrain)
	assert(cart_grid.is_walkable(Vector2i(2, 0), CART))
	assert(cart_grid.is_edge_passable(Vector2i(3, 0), Vector2i(4, 0), CART))
	assert(_route(cart_grid, Vector2i(-2, 0), Vector2i(6, 0), CART).reachable)


static func _test_slope_costs_speed() -> void:
	var terrain := _terrain()
	_raise_plateau(terrain)
	assert(terrain.place_ramp(Vector2i(3, 0), SlopeCatalog.VERY_STEEP, SlopeCatalog.DIR_E))
	var grid := _nav_over(terrain)
	# §10.2: a walker keeps a quarter of their speed on a 63° slope, so the cell
	# costs four times what the flat ground beside it costs.
	assert(is_equal_approx(grid.get_cell_weight(Vector2i(3, 0)), NavGrid.DEFAULT_CELL_WEIGHT * 4.0))
	assert(is_equal_approx(grid.get_cell_weight(Vector2i(2, 0)), NavGrid.DEFAULT_CELL_WEIGHT))
	# The slope is a multiplier on whatever surface is there: a road up a hillside
	# is still a hillside.
	grid.set_road_cell_weights({Vector2i(3, 0): 0.5})
	assert(is_equal_approx(grid.get_cell_weight(Vector2i(3, 0)), 2.0))
	# A cost multiplier must never drop a cell below the A* heuristic's floor.
	assert(grid.minimum_cell_weight() <= grid.get_cell_weight(Vector2i(3, 0)))


static func _test_holes_are_not_walkable() -> void:
	var terrain := _terrain()
	assert(terrain.set_hole(Vector2i(2, 0), true))
	var grid := _nav_over(terrain)
	assert(not grid.is_walkable(Vector2i(2, 0)))
	assert(not grid.is_edge_passable(Vector2i(1, 0), Vector2i(2, 0)))
	# Ground around the hole is untouched; a route simply goes past it.
	assert(grid.is_walkable(Vector2i(1, 0)) and grid.is_walkable(Vector2i(3, 0)))
	var route := _route(grid, Vector2i(0, 0), Vector2i(4, 0))
	assert(route.reachable and not _crosses_cell(route, Vector2i(2, 0)))


static func _test_height_at_agrees_with_terrain() -> void:
	var terrain := _terrain()
	_raise_plateau(terrain)
	assert(terrain.place_ramp(Vector2i(3, 0), SlopeCatalog.VERY_STEEP, SlopeCatalog.DIR_E))
	var grid := _nav_over(terrain)
	# §10.4: mesh, collision and the height a citizen is placed at are one surface.
	# Sampling across the ramp is the case that catches a bilinear reading of a
	# quad the mesher splits into triangles.
	for step in 9:
		var fraction := float(step) / 8.0
		for z_step in 5:
			var sample := Vector3(3.0 + fraction, 0.0, float(z_step) * 0.25)
			assert(is_equal_approx(grid.height_at(sample), terrain.height_at(sample)))
	assert(is_equal_approx(grid.height_at(_centre(Vector2i(6, 0))), 2.0 * TerrainGrid.HEIGHT_STEP))
	# Waypoints are produced on that surface rather than on the y = 0 plane.
	assert(is_equal_approx(grid.cell_center(Vector2i(6, 0)).y, 2.0 * TerrainGrid.HEIGHT_STEP))


static func _crosses_cell(route: RouteResult, cell: Vector2i) -> bool:
	for waypoint: Vector3 in route.waypoints:
		if Vector2i(floori(waypoint.x), floori(waypoint.z)) == cell:
			return true
	return false
