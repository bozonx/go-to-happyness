class_name CompositeRouteSolver
extends RouteSolver

## Composite router that dispatches requests to appropriate layer solvers
## and links multi-layer routes across portal transition nodes.

var solvers: Array[RouteSolver] = []


func _init() -> void:
	solver_id = &"composite_solver"


func register_solver(solver: RouteSolver) -> void:
	if solver != null and not solvers.has(solver):
		solvers.append(solver)


func unregister_solver(solver: RouteSolver) -> void:
	solvers.erase(solver)


func can_solve(request: RouteRequest) -> bool:
	for solver in solvers:
		if solver.can_solve(request):
			return true
	return false


func find_route(request: RouteRequest) -> RouteResult:
	if request == null:
		return RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)

	for solver in solvers:
		if solver.can_solve(request):
			var result := solver.find_route(request)
			if result.reachable:
				return result

	# Fallback if no specific solver matched or produced a path
	if not solvers.is_empty():
		return solvers[0].find_route(request)
	return RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)
