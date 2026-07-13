class_name GridRouteService
extends RefCounted

## Deterministic route selection over the settlement's navigation grid.
##
## A weighted A* search finds the coarse cell path, then weighted string pulling
## removes only bends that do not materially increase traversal cost.

var grid: NavGrid


func configure(next_grid: NavGrid) -> void:
	grid = next_grid


func find_route(from: Vector3, destination: Vector3) -> RouteResult:
	if grid == null:
		return RouteResult.unreachable()
	var start: Vector2i = grid.cell_from_position(from)
	var goal: Vector2i = grid.cell_from_position(destination)
	if not grid.is_board_cell(start) or not grid.is_board_cell(goal):
		return RouteResult.unreachable()
	# A task must name an actual reachable interaction point. Snapping an
	# inaccessible target to a nearby cell causes false task completion.
	if grid.is_blocked(goal):
		return RouteResult.unreachable()

	var came_from := _search(start, goal)
	if not came_from.has(goal):
		return RouteResult.unreachable()

	# Reconstruct the coarse path as world points: the start, each cell centre,
	# and finally the exact service/work interaction point requested by the task.
	var points: Array[Vector3] = [from]
	var chain: Array[Vector2i] = []
	var step := goal
	while step != start:
		chain.push_front(step)
		step = came_from[step]
	for cell in chain:
		points.append(grid.cell_center(cell))
	if points.back().distance_squared_to(destination) > 0.0001:
		points.append(destination)

	var waypoints := _smooth(points)
	if waypoints.is_empty():
		waypoints = [destination]
	return RouteResult.success(waypoints, destination)


func _search(start: Vector2i, goal: Vector2i) -> Dictionary:
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var costs: Dictionary = {start: 0.0}
	var priorities: Dictionary = {start: _octile_distance(start, goal) * grid.minimum_cell_weight()}
	var directions: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1),
	]
	while not frontier.is_empty():
		var best_index := 0
		for index in range(1, frontier.size()):
			if float(priorities[frontier[index]]) < float(priorities[frontier[best_index]]):
				best_index = index
		var current := frontier[best_index]
		frontier.remove_at(best_index)
		if current == goal:
			break
		for direction in directions:
			var next := current + direction
			if not grid.is_walkable(next):
				continue
			if direction.x != 0 and direction.y != 0:
				if not grid.is_walkable(current + Vector2i(direction.x, 0)) or not grid.is_walkable(current + Vector2i(0, direction.y)):
					continue
			var distance := sqrt(2.0) if direction.x != 0 and direction.y != 0 else 1.0
			var next_cost := float(costs[current]) + distance * grid.get_cell_weight(next)
			if next_cost >= float(costs.get(next, INF)):
				continue
			came_from[next] = current
			costs[next] = next_cost
			priorities[next] = next_cost + _octile_distance(next, goal) * grid.minimum_cell_weight()
			if not frontier.has(next):
				frontier.append(next)
	return came_from


func _octile_distance(from: Vector2i, to: Vector2i) -> float:
	var dx := absf(float(to.x - from.x))
	var dy := absf(float(to.y - from.y))
	return maxf(dx, dy) + (sqrt(2.0) - 1.0) * minf(dx, dy)


## Collapses the cell path only when a direct weighted segment costs at most 8%
## more than the original path portion. The leading point is not emitted as a
## waypoint; it may be inside a transient clearance cell, so its first successor
## is retained if no valid weighted segment starts there.
func _smooth(points: Array[Vector3]) -> Array[Vector3]:
	if points.size() <= 1:
		return []
	var waypoints: Array[Vector3] = []
	var anchor_index := 0
	while anchor_index < points.size() - 1:
		var best_index := anchor_index + 1
		var original_cost := 0.0
		for candidate_index in range(anchor_index + 1, points.size()):
			var leg_cost := grid.segment_cost(points[candidate_index - 1], points[candidate_index])
			if not is_finite(leg_cost):
				break
			original_cost += leg_cost
			var direct_cost := grid.segment_cost(points[anchor_index], points[candidate_index])
			if is_finite(direct_cost) and direct_cost <= original_cost * 1.08:
				best_index = candidate_index
			else:
				break
		waypoints.append(points[best_index])
		anchor_index = best_index
	return waypoints
