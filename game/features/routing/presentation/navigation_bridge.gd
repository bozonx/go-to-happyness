class_name NavigationBridge
extends Node

## Bridge between bootstrap state and the navigation subsystem.
## Owns the route reachability cache and recovery-path logic so bootstrap
## does not need to know about NavGrid internals.

var simulation: Node

var _route_reachability_cache: Dictionary = {}
var _route_reachability_cache_revision := -1
const ROUTE_REACHABILITY_CACHE_LIMIT := 1024


func setup(p_simulation: Node) -> void:
	simulation = p_simulation


## A repeated physical blockage needs a different first leg; replanning the
## identical A* request would otherwise select the same waypoint forever.
func find_recovery_path(from: Vector3, destination: Vector3, may_enter_destination_house: bool) -> RouteResult:
	var fallback := find_path_around_houses(from, destination, may_enter_destination_house)
	var nav_grid = simulation.nav_grid
	if nav_grid == null or simulation.route_service == null or not fallback.reachable:
		return fallback
	var from_cell := nav_grid.cell_from_position(from)
	var desired := Vector2(destination.x - from.x, destination.z - from.z)
	if desired.length_squared() <= 0.0001:
		return fallback
	desired = desired.normalized()
	var best: RouteResult = null
	var best_cost := INF
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]:
		var candidate_cell: Vector2i = from_cell + offset
		if not nav_grid.is_walkable(candidate_cell):
			continue
		var candidate: Vector3 = nav_grid.cell_center(candidate_cell)
		var direction := Vector2(candidate.x - from.x, candidate.z - from.z).normalized()
		# Keep the first leg lateral or backward. A forward cell repeats the blocked
		# physical approach that just failed.
		if direction.dot(desired) > 0.25 or not nav_grid.is_segment_clear(from, candidate):
			continue
		var prefix := find_path_around_houses(from, candidate, false)
		var suffix := find_path_around_houses(candidate, destination, may_enter_destination_house)
		if not prefix.reachable or not suffix.reachable:
			continue
		var waypoints := prefix.waypoints.duplicate()
		waypoints.append_array(suffix.waypoints)
		var candidate_route := RouteResult.success(waypoints, destination, nav_grid.revision(), nav_grid.topology_revision())
		var cost := simulation._route_cost(from, candidate_route)
		if cost < best_cost:
			best = candidate_route
			best_cost = cost
	return best if best != null else fallback


## Candidate discovery asks only whether a destination can be reached. Cache the
## result per topology revision and use connected components, reserving A* for
## blocked interaction destinations that need an approach cell.
func is_route_reachable(from: Vector3, destination: Vector3, may_enter_destination_house := false) -> bool:
	var nav_grid = simulation.nav_grid
	if nav_grid == null:
		return false
	var topology_revision := nav_grid.topology_revision()
	if _route_reachability_cache_revision != topology_revision:
		_route_reachability_cache.clear()
		_route_reachability_cache_revision = topology_revision
	var key := "%d:%d>%d:%d:%d" % [
		nav_grid.cell_from_position(from).x,
		nav_grid.cell_from_position(from).y,
		nav_grid.cell_from_position(destination).x,
		nav_grid.cell_from_position(destination).y,
		1 if may_enter_destination_house else 0,
	]
	if _route_reachability_cache.has(key):
		return bool(_route_reachability_cache[key])
	var reachable := false
	if not may_enter_destination_house:
		reachable = nav_grid.are_cells_connected(nav_grid.cell_from_position(from), nav_grid.cell_from_position(destination))
	else:
		reachable = find_path_around_houses(from, destination, true).reachable
	if _route_reachability_cache.size() < ROUTE_REACHABILITY_CACHE_LIMIT:
		_route_reachability_cache[key] = reachable
	return reachable


func find_path_around_houses(from: Vector3, destination: Vector3, may_enter_destination_house: bool) -> RouteResult:
	if simulation.navigation_facade == null:
		return RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)
	return simulation.navigation_facade.find_route(from, destination, may_enter_destination_house)


## Recomputes walkable cells (terrain + building footprints with clearance) and
## publishes them to the shared NavGrid. Citizens route entirely through the grid,
## so this is the only navigation structure the settlement maintains.
func refresh_navigation_grid() -> void:
	if simulation.navigation_obstacle_publisher == null:
		return
	simulation.navigation_blocked_cells = simulation.navigation_obstacle_publisher.publish(
		simulation.terrain_blocked_cells,
		simulation.building_registry.records(),
		simulation.service_pockets,
		simulation.NAVIGATION_CLEARANCE_MARGIN
	)
