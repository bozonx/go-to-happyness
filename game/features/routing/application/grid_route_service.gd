class_name GridRouteService
extends RefCounted

## Deterministic route selection over the settlement's navigation grid.
##
## A weighted A* search finds the coarse cell path, then weighted string pulling
## removes only bends that do not materially increase traversal cost.

var grid: NavGrid
var solver: GridRouteSolver
var last_search_expanded_nodes: int:
	get: return solver.last_search_expanded_nodes if solver != null else 0
var last_search_peak_frontier: int:
	get: return solver.last_search_peak_frontier if solver != null else 0

const RouteRequestScript = preload("res://game/features/routing/domain/route_request.gd")
const GridRouteSolverScript = preload("res://game/features/routing/application/solvers/grid_route_solver.gd")


func configure(next_grid: NavGrid) -> void:
	grid = next_grid
	if solver == null:
		solver = GridRouteSolverScript.new(next_grid)
	else:
		solver.configure(next_grid)


func find_route(from: Vector3, destination: Vector3) -> RouteResult:
	return find_route_request(_make_request(from, destination))


func find_route_for_profile(from: Vector3, destination: Vector3, traveler_profile: StringName) -> RouteResult:
	var request := _make_request(from, destination)
	request.traveler_profile = traveler_profile
	return find_route_request(request)


func find_route_request(request: RefCounted) -> RouteResult:
	if solver == null and grid != null:
		solver = GridRouteSolverScript.new(grid)
	if solver == null:
		return RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)
	return solver.find_route(request)



func _make_request(from: Vector3, destination: Vector3, allow_destination := false) -> RefCounted:
	var request := RouteRequestScript.new()
	request.from = from
	request.destination = destination
	request.allow_destination_cell = allow_destination
	return request
