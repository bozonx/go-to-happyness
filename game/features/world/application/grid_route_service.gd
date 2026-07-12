class_name GridRouteService
extends RefCounted

## Deterministic route selection over the settlement's canonical navigation grid.

var cell_from_position: Callable
var cell_center: Callable
var is_board_cell: Callable
var is_cell_blocked: Callable


func configure(next_cell_from_position: Callable, next_cell_center: Callable, next_is_board_cell: Callable, next_is_cell_blocked: Callable) -> void:
	cell_from_position = next_cell_from_position
	cell_center = next_cell_center
	is_board_cell = next_is_board_cell
	is_cell_blocked = next_is_cell_blocked


func find_route(from: Vector3, destination: Vector3) -> RouteResult:
	if not _is_configured():
		return RouteResult.unreachable()
	var start: Vector2i = cell_from_position.call(from)
	var goal: Vector2i = cell_from_position.call(destination)
	if not bool(is_board_cell.call(start)) or not bool(is_board_cell.call(goal)):
		return RouteResult.unreachable()
	# A task must name an actual reachable interaction point. Snapping an
	# inaccessible target to a nearby cell causes false task completion.
	if bool(is_cell_blocked.call(goal)):
		return RouteResult.unreachable()

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
			if not bool(is_board_cell.call(next)) or came_from.has(next):
				continue
			if bool(is_cell_blocked.call(next)) and next != goal:
				continue
			came_from[next] = current
			frontier.append(next)
	if not came_from.has(goal):
		return RouteResult.unreachable()

	var cells: Array[Vector2i] = []
	var step := goal
	while step != start:
		cells.push_front(step)
		step = came_from[step]
	var waypoints: Array[Vector3] = []
	for cell in cells:
		waypoints.append(cell_center.call(cell))
	# Cell centres keep the route clear of the next obstacle; the final point is
	# the exact service/work interaction point requested by the task.
	if waypoints.is_empty() or waypoints.back().distance_squared_to(destination) > 0.0001:
		waypoints.append(destination)
	return RouteResult.success(waypoints, destination)


func _is_configured() -> bool:
	return cell_from_position.is_valid() and cell_center.is_valid() and is_board_cell.is_valid() and is_cell_blocked.is_valid()
