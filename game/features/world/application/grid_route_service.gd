class_name GridRouteService
extends RefCounted

## Deterministic route selection over the settlement's navigation grid.
##
## A breadth-first search finds the coarse cell path, then the path is string-
## pulled against the grid's line-of-sight so citizens walk in straight lines and
## only bend around blocked footprints.

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
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if current == goal:
			break
		for direction in directions:
			var next := current + direction
			if came_from.has(next) or not grid.is_board_cell(next):
				continue
			if grid.is_blocked(next) and next != goal:
				continue
			came_from[next] = current
			frontier.append(next)
	return came_from


## Collapses the cell path to the fewest waypoints whose connecting segments each
## stay on walkable cells. The leading point (the citizen's own position) is not
## emitted as a waypoint. The first point is always kept as an anchor because the
## citizen may currently stand on a blocked/clearance cell it must first leave.
func _smooth(points: Array[Vector3]) -> Array[Vector3]:
	if points.size() <= 1:
		return []
	var waypoints: Array[Vector3] = []
	var anchor := points[0]
	var index := 1
	while index < points.size() - 1:
		if not grid.is_segment_clear(anchor, points[index + 1]):
			waypoints.append(points[index])
			anchor = points[index]
		index += 1
	waypoints.append(points[points.size() - 1])
	return waypoints
