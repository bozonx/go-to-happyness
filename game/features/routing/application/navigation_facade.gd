class_name NavigationFacade
extends RefCounted

## Small application port for route consumers. It prevents actors and bootstrap
## code from knowing whether routes come from a grid, a future hierarchy, or a
## cached provider.

var _grid: NavGrid
var _routes: GridRouteService
var route_requests := 0
var route_failures := 0
var expanded_nodes := 0


func configure(next_grid: NavGrid, next_routes: GridRouteService) -> void:
	_grid = next_grid
	_routes = next_routes


func find_route(from: Vector3, destination: Vector3, allow_destination_cell := false, traveler_profile: StringName = NavGrid.PEDESTRIAN_PROFILE) -> RouteResult:
	if _routes == null:
		return RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)
	var request := RouteRequest.new()
	request.from = from
	request.destination = destination
	request.allow_destination_cell = allow_destination_cell
	request.traveler_profile = traveler_profile
	route_requests += 1
	var result := _routes.find_route_request(request)
	expanded_nodes += _routes.last_search_expanded_nodes
	if not result.reachable:
		route_failures += 1
	return result


func movement_speed_modifier_at(position: Vector3, profile: StringName = NavGrid.PEDESTRIAN_PROFILE) -> float:
	return _grid.movement_speed_modifier_at(position, profile) if _grid != null else 1.0


func topology_revision() -> int:
	return _grid.topology_revision() if _grid != null else -1


func route_cost(from: Vector3, route: RouteResult, profile: StringName = NavGrid.PEDESTRIAN_PROFILE) -> float:
	return _grid.route_cost(from, route, profile) if _grid != null else INF


func metrics() -> Dictionary:
	return {"requests": route_requests, "failures": route_failures, "expanded_nodes": expanded_nodes}
