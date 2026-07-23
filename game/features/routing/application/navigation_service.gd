class_name NavigationService
extends RefCounted

## Application boundary for route consumers and obstacle publication.
## It owns recovery and reachability policy without depending on a scene node or
## composition root.

var _grid: NavGrid
var _facade: NavigationFacade
var _obstacle_publisher: NavigationObstaclePublisher
var _reachability_cache: Dictionary = {}
var _reachability_cache_revision := -1

const ROUTE_REACHABILITY_CACHE_LIMIT := 1024
const RECOVERY_OFFSETS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1),
]


func configure(grid: NavGrid, facade: NavigationFacade, obstacle_publisher: NavigationObstaclePublisher = null) -> void:
	_grid = grid
	_facade = facade
	_obstacle_publisher = obstacle_publisher


func find_route(from: Vector3, destination: Vector3, allow_destination_cell := false, traveler_profile: StringName = NavGrid.PEDESTRIAN_PROFILE) -> RouteResult:
	if _facade == null:
		return RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)
	return _facade.find_route(from, destination, allow_destination_cell, traveler_profile)


func find_recovery_path(from: Vector3, destination: Vector3, allow_destination_cell: bool) -> RouteResult:
	var fallback := find_route(from, destination, allow_destination_cell)
	if _grid == null or not fallback.reachable:
		return fallback
	var desired := Vector2(destination.x - from.x, destination.z - from.z)
	if desired.length_squared() <= 0.0001:
		return fallback
	desired = desired.normalized()
	var best: RouteResult = null
	var best_cost := INF
	var from_cell := _grid.cell_from_position(from)
	for offset in RECOVERY_OFFSETS:
		var candidate_cell := from_cell + offset
		if not _grid.is_walkable(candidate_cell):
			continue
		var candidate := _grid.cell_center(candidate_cell)
		var direction := Vector2(candidate.x - from.x, candidate.z - from.z).normalized()
		if direction.dot(desired) > 0.25 or not _grid.is_segment_clear(from, candidate):
			continue
		var prefix := find_route(from, candidate)
		var suffix := find_route(candidate, destination, allow_destination_cell)
		if not prefix.reachable or not suffix.reachable:
			continue
		var waypoints := prefix.waypoints.duplicate()
		waypoints.append_array(suffix.waypoints)
		var candidate_route := RouteResult.success(waypoints, destination, _grid.revision(), _grid.topology_revision())
		var cost := _grid.route_cost(from, candidate_route)
		if cost < best_cost:
			best = candidate_route
			best_cost = cost
	return best if best != null else fallback


func is_route_reachable(from: Vector3, destination: Vector3, allow_destination_cell := false) -> bool:
	if _grid == null:
		return false
	var topology_revision := _grid.topology_revision()
	if _reachability_cache_revision != topology_revision:
		_reachability_cache.clear()
		_reachability_cache_revision = topology_revision
	var from_cell := _grid.cell_from_position(from)
	var destination_cell := _grid.cell_from_position(destination)
	var key := "%d:%d>%d:%d:%d" % [from_cell.x, from_cell.y, destination_cell.x, destination_cell.y, 1 if allow_destination_cell else 0]
	if _reachability_cache.has(key):
		return bool(_reachability_cache[key])
	var reachable := find_route(from, destination, true).reachable if allow_destination_cell else _grid.are_cells_connected(from_cell, destination_cell)
	if _reachability_cache.size() < ROUTE_REACHABILITY_CACHE_LIMIT:
		_reachability_cache[key] = reachable
	return reachable


func publish_obstacles(terrain_blocked: Dictionary, building_records: Array, service_pockets: Array, clearance_margin: float) -> Dictionary:
	if _obstacle_publisher == null:
		return terrain_blocked.duplicate()
	return _obstacle_publisher.publish(terrain_blocked, building_records, service_pockets, clearance_margin)
