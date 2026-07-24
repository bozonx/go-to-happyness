class_name RouteSolver
extends RefCounted

## Abstract base class for navigation solvers in the routing system.
## Specific solvers (Grid, RoadGraph, Indoor, Composite) implement find_route.

var solver_id: StringName = &"base_solver"


func can_solve(request: RouteRequest) -> bool:
	return request != null


func find_route(request: RouteRequest) -> RouteResult:
	return RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)
