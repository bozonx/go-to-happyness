class_name GridRouteService
extends RefCounted

## Deterministic route selection over the settlement's navigation grid.
##
## A weighted A* search finds the coarse cell path, then weighted string pulling
## removes only bends that do not materially increase traversal cost.

var grid: NavGrid

const RouteRequestScript = preload("res://game/features/routing/application/route_request.gd")
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1),
]
const DIAGONAL_DISTANCE := 1.41421356237


func configure(next_grid: NavGrid) -> void:
	grid = next_grid


func find_route(from: Vector3, destination: Vector3) -> RouteResult:
	return find_route_request(_make_request(from, destination))


func find_route_for_profile(from: Vector3, destination: Vector3, traveler_profile: StringName) -> RouteResult:
	var request := _make_request(from, destination)
	request.traveler_profile = traveler_profile
	return find_route_request(request)


func find_route_request(request: RefCounted) -> RouteResult:
	if grid == null:
		return RouteResult.unreachable()
	var grid_revision := grid.revision()
	var start: Vector2i = grid.cell_from_position(request.from)
	var goal: Vector2i = grid.cell_from_position(request.destination)
	if not grid.is_board_cell(start) or not grid.is_board_cell(goal):
		return RouteResult.unreachable(grid_revision)
	# A task must name an actual reachable interaction point. Snapping an
	# inaccessible target to a nearby cell causes false task completion.
	if grid.is_blocked(goal):
		return RouteResult.unreachable(grid_revision)

	var came_from := _search(start, goal, request.traveler_profile)
	if not came_from.has(goal):
		return RouteResult.unreachable(grid_revision)

	# Reconstruct the coarse path as world points: the start, each cell centre,
	# and finally the exact service/work interaction point requested by the task.
	var points: Array[Vector3] = [request.from]
	var chain: Array[Vector2i] = []
	var step := goal
	while step != start:
		chain.push_front(step)
		step = came_from[step]
	for cell in chain:
		points.append(grid.cell_center(cell))
	if points.back().distance_squared_to(request.destination) > 0.0001:
		points.append(request.destination)

	var waypoints := _smooth(points, request.traveler_profile)
	if waypoints.is_empty():
		waypoints = [request.destination]
	return RouteResult.success(waypoints, request.destination, grid_revision)


func _make_request(from: Vector3, destination: Vector3, allow_destination := false) -> RefCounted:
	var request := RouteRequestScript.new()
	request.from = from
	request.destination = destination
	request.allow_destination_cell = allow_destination
	return request


func _search(start: Vector2i, goal: Vector2i, traveler_profile: StringName) -> Dictionary:
	var frontier_cells: Array[Vector2i] = []
	var frontier_priorities := PackedFloat32Array()
	var came_from: Dictionary = {start: start}
	var costs: Dictionary = {start: 0.0}
	var closed: Dictionary = {}
	var minimum_weight := grid.minimum_cell_weight()
	_heap_push(frontier_cells, frontier_priorities, start, _octile_distance(start, goal) * minimum_weight)
	while not frontier_cells.is_empty():
		var current := _heap_pop(frontier_cells, frontier_priorities)
		if closed.has(current):
			continue
		closed[current] = true
		if current == goal:
			break
		for direction in DIRECTIONS:
			var next := current + direction
			if closed.has(next):
				continue
			if not grid.is_walkable(next):
				continue
			if direction.x != 0 and direction.y != 0:
				if not grid.is_walkable(current + Vector2i(direction.x, 0)) or not grid.is_walkable(current + Vector2i(0, direction.y)):
					continue
			var distance := DIAGONAL_DISTANCE if direction.x != 0 and direction.y != 0 else 1.0
			var next_cost := float(costs[current]) + distance * grid.get_cell_weight(next, traveler_profile)
			if next_cost >= float(costs.get(next, INF)):
				continue
			came_from[next] = current
			costs[next] = next_cost
			_heap_push(frontier_cells, frontier_priorities, next, next_cost + _octile_distance(next, goal) * minimum_weight)
	return came_from


func _heap_push(cells: Array[Vector2i], priorities: PackedFloat32Array, cell: Vector2i, priority: float) -> void:
	cells.append(cell)
	priorities.append(priority)
	var index := cells.size() - 1
	while index > 0:
		var parent := (index - 1) / 2
		if priorities[parent] <= priority:
			break
		cells[index] = cells[parent]
		priorities[index] = priorities[parent]
		index = parent
	cells[index] = cell
	priorities[index] = priority


func _heap_pop(cells: Array[Vector2i], priorities: PackedFloat32Array) -> Vector2i:
	var first := cells[0]
	var last_cell: Vector2i = cells.pop_back()
	var last_priority := priorities[priorities.size() - 1]
	priorities.remove_at(priorities.size() - 1)
	if cells.is_empty():
		return first
	var index := 0
	while true:
		var left := index * 2 + 1
		if left >= cells.size():
			break
		var right := left + 1
		var child := left
		if right < cells.size() and priorities[right] < priorities[left]:
			child = right
		if priorities[child] >= last_priority:
			break
		cells[index] = cells[child]
		priorities[index] = priorities[child]
		index = child
	cells[index] = last_cell
	priorities[index] = last_priority
	return first


func _octile_distance(from: Vector2i, to: Vector2i) -> float:
	var dx := absf(float(to.x - from.x))
	var dy := absf(float(to.y - from.y))
	return maxf(dx, dy) + (DIAGONAL_DISTANCE - 1.0) * minf(dx, dy)


## Collapses the cell path only when a direct weighted segment costs at most 8%
## more than the original path portion. The leading point is not emitted as a
## waypoint; it may be inside a transient clearance cell, so its first successor
## is retained if no valid weighted segment starts there.
func _smooth(points: Array[Vector3], traveler_profile: StringName) -> Array[Vector3]:
	if points.size() <= 1:
		return []
	var waypoints: Array[Vector3] = []
	var anchor_index := 0
	while anchor_index < points.size() - 1:
		var best_index := anchor_index + 1
		var original_cost := 0.0
		for candidate_index in range(anchor_index + 1, points.size()):
			var leg_cost := grid.segment_cost(points[candidate_index - 1], points[candidate_index], traveler_profile)
			if not is_finite(leg_cost):
				break
			original_cost += leg_cost
			var direct_cost := grid.segment_cost(points[anchor_index], points[candidate_index], traveler_profile)
			if is_finite(direct_cost) and direct_cost <= original_cost * 1.08:
				best_index = candidate_index
			else:
				break
		waypoints.append(points[best_index])
		anchor_index = best_index
	return waypoints
