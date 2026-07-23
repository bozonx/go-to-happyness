class_name NavigationBridge
extends Node

## Presentation adapter only. Navigation policy belongs to NavigationService;
## this node remains solely to keep bootstrap's node wiring and compatibility
## delegates narrow.

var _service: NavigationService


func configure(grid: NavGrid, facade: NavigationFacade, _route_service: GridRouteService = null, obstacle_publisher: NavigationObstaclePublisher = null) -> void:
	_service = NavigationService.new()
	_service.configure(grid, facade, obstacle_publisher)


func find_recovery_path(from: Vector3, destination: Vector3, may_enter_destination_house: bool) -> RouteResult:
	return _service.find_recovery_path(from, destination, may_enter_destination_house) if _service != null else RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)


func is_route_reachable(from: Vector3, destination: Vector3, may_enter_destination_house := false) -> bool:
	return _service.is_route_reachable(from, destination, may_enter_destination_house) if _service != null else false


func find_path_around_houses(from: Vector3, destination: Vector3, may_enter_destination_house: bool) -> RouteResult:
	return _service.find_route(from, destination, may_enter_destination_house) if _service != null else RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)


func refresh_navigation_grid(terrain_blocked: Dictionary, building_records: Array, service_pockets: Array, clearance_margin: float) -> Dictionary:
	return _service.publish_obstacles(terrain_blocked, building_records, service_pockets, clearance_margin) if _service != null else terrain_blocked.duplicate()
