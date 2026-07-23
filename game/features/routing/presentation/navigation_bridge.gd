class_name NavigationBridge
extends Node

## Bridge between bootstrap state and the navigation subsystem.
## Owns the route reachability cache and recovery-path logic so bootstrap
## does not need to know about NavGrid internals.

var simulation: Node
var nav_grid: NavGrid
var navigation_facade: NavigationFacade
var route_service: GridRouteService
var navigation_obstacle_publisher: NavigationObstaclePublisher

var _route_reachability_cache: Dictionary = {}
var _route_reachability_cache_revision := -1
const ROUTE_REACHABILITY_CACHE_LIMIT := 1024


func setup(p_simulation: Node) -> void:
	simulation = p_simulation
	if p_simulation != null:
		nav_grid = p_simulation.get("nav_grid")
		navigation_facade = p_simulation.get("navigation_facade")
		route_service = p_simulation.get("route_service")
		navigation_obstacle_publisher = p_simulation.get("navigation_obstacle_publisher")


func configure(
	p_nav_grid: NavGrid,
	p_facade: NavigationFacade,
	p_route_service: GridRouteService = null,
	p_obstacle_publisher: NavigationObstaclePublisher = null
) -> void:
	nav_grid = p_nav_grid
	navigation_facade = p_facade
	route_service = p_route_service
	navigation_obstacle_publisher = p_obstacle_publisher


## A repeated physical blockage needs a different first leg; replanning the
## identical A* request would otherwise select the same waypoint forever.
func find_recovery_path(from: Vector3, destination: Vector3, may_enter_destination_house: bool) -> RouteResult:
	var fallback := find_path_around_houses(from, destination, may_enter_destination_house)
	var active_grid := _get_nav_grid()
	var active_route_service := _get_route_service()
	if active_grid == null or active_route_service == null or not fallback.reachable:
		return fallback
	var from_cell: Vector2i = active_grid.cell_from_position(from)
	var desired := Vector2(destination.x - from.x, destination.z - from.z)
	if desired.length_squared() <= 0.0001:
		return fallback
	desired = desired.normalized()
	var best: RouteResult = null
	var best_cost := INF
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]:
		var candidate_cell: Vector2i = from_cell + offset
		if not active_grid.is_walkable(candidate_cell):
			continue
		var candidate: Vector3 = active_grid.cell_center(candidate_cell)
		var direction := Vector2(candidate.x - from.x, candidate.z - from.z).normalized()
		# Keep the first leg lateral or backward. A forward cell repeats the blocked
		# physical approach that just failed.
		if direction.dot(desired) > 0.25 or not active_grid.is_segment_clear(from, candidate):
			continue
		var prefix := find_path_around_houses(from, candidate, false)
		var suffix := find_path_around_houses(candidate, destination, may_enter_destination_house)
		if not prefix.reachable or not suffix.reachable:
			continue
		var waypoints := prefix.waypoints.duplicate()
		waypoints.append_array(suffix.waypoints)
		var candidate_route := RouteResult.success(waypoints, destination, active_grid.revision(), active_grid.topology_revision())
		var cost: float = active_grid.route_cost(from, candidate_route)
		if cost < best_cost:
			best = candidate_route
			best_cost = cost
	return best if best != null else fallback


## Candidate discovery asks only whether a destination can be reached. Cache the
## result per topology revision and use connected components, reserving A* for
## blocked interaction destinations that need an approach cell.
func is_route_reachable(from: Vector3, destination: Vector3, may_enter_destination_house := false) -> bool:
	var active_grid := _get_nav_grid()
	if active_grid == null:
		return false
	var topology_revision: int = active_grid.topology_revision()
	if _route_reachability_cache_revision != topology_revision:
		_route_reachability_cache.clear()
		_route_reachability_cache_revision = topology_revision
	var key := "%d:%d>%d:%d:%d" % [
		active_grid.cell_from_position(from).x,
		active_grid.cell_from_position(from).y,
		active_grid.cell_from_position(destination).x,
		active_grid.cell_from_position(destination).y,
		1 if may_enter_destination_house else 0,
	]
	if _route_reachability_cache.has(key):
		return bool(_route_reachability_cache[key])
	var reachable := false
	if not may_enter_destination_house:
		reachable = active_grid.are_cells_connected(active_grid.cell_from_position(from), active_grid.cell_from_position(destination))
	else:
		reachable = find_path_around_houses(from, destination, true).reachable
	if _route_reachability_cache.size() < ROUTE_REACHABILITY_CACHE_LIMIT:
		_route_reachability_cache[key] = reachable
	return reachable


func find_path_around_houses(from: Vector3, destination: Vector3, may_enter_destination_house: bool) -> RouteResult:
	var facade := _get_navigation_facade()
	if facade == null:
		return RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)
	return facade.find_route(from, destination, may_enter_destination_house)


## Recomputes walkable cells (terrain + building footprints with clearance) and
## publishes them to the shared NavGrid. Citizens route entirely through the grid,
## so this is the only navigation structure the settlement maintains.
func refresh_navigation_grid() -> void:
	var publisher := _get_navigation_obstacle_publisher()
	if publisher == null or simulation == null:
		return
	simulation.set("navigation_blocked_cells", publisher.publish(
		simulation.get("terrain_blocked_cells"),
		simulation.get("building_registry").records(),
		simulation.get("service_pockets"),
		simulation.get("NAVIGATION_CLEARANCE_MARGIN")
	))


func _get_nav_grid() -> NavGrid:
	if nav_grid != null:
		return nav_grid
	if simulation != null:
		return simulation.get("nav_grid")
	return null


func _get_navigation_facade() -> NavigationFacade:
	if navigation_facade != null:
		return navigation_facade
	if simulation != null:
		return simulation.get("navigation_facade")
	return null


func _get_route_service() -> GridRouteService:
	if route_service != null:
		return route_service
	if simulation != null:
		return simulation.get("route_service")
	return null


func _get_navigation_obstacle_publisher() -> NavigationObstaclePublisher:
	if navigation_obstacle_publisher != null:
		return navigation_obstacle_publisher
	if simulation != null:
		return simulation.get("navigation_obstacle_publisher")
	return null

