class_name GridRouteSolver
extends RouteSolver

## Grid-based A* route solver. Implementation of weighted A* with string pulling over NavGrid.

var grid: NavGrid
var last_search_expanded_nodes := 0
var last_search_peak_frontier := 0

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1),
]
const DIAGONAL_DISTANCE := 1.41421356237
const MAX_SMOOTH_LOOKAHEAD := 12


func _init(next_grid: NavGrid = null) -> void:
	solver_id = &"grid_solver"
	grid = next_grid


func configure(next_grid: NavGrid) -> void:
	grid = next_grid


func can_solve(request: RouteRequest) -> bool:
	if request == null or grid == null:
		return false
	var profile := request.get_profile()
	return (profile.layer_mask & (TravelerProfile.LAYER_TERRAIN | TravelerProfile.LAYER_ROAD)) != 0


func find_route(request: RouteRequest) -> RouteResult:
	if grid == null:
		return RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)
	var grid_revision := grid.revision()
	var topology_revision := grid.topology_revision()
	if request == null or not can_solve(request):
		return RouteResult.unreachable(grid_revision, topology_revision, RouteResult.UnreachableReason.PROFILE_UNSUPPORTED)
	var start: Vector2i = grid.cell_from_position(request.from)
	var goal: Vector2i = grid.cell_from_position(request.destination)
	if not grid.is_board_cell(start) or not grid.is_board_cell(goal):
		return RouteResult.unreachable(grid_revision, topology_revision, RouteResult.UnreachableReason.OUTSIDE_BOARD)
	if grid.is_blocked(goal) and not request.allow_destination_cell:
		return RouteResult.unreachable(grid_revision, topology_revision, RouteResult.UnreachableReason.GOAL_BLOCKED)

	var profile := request.get_profile()
	var profile_id := profile.profile_id
	if not grid.is_walkable(start, profile_id, profile) and not profile.allows_offroad:
		return RouteResult.unreachable(grid_revision, topology_revision, RouteResult.UnreachableReason.DISCONNECTED)
	if not request.allow_destination_cell and grid.is_walkable(start, profile_id, profile) and grid.is_walkable(goal, profile_id, profile) and not grid.are_cells_connected(start, goal, profile_id, profile):
		return RouteResult.unreachable(grid_revision, topology_revision, RouteResult.UnreachableReason.DISCONNECTED)

	var came_from := _search(start, goal, profile, request.allow_destination_cell)
	if not came_from.has(goal):
		return RouteResult.unreachable(grid_revision, topology_revision, RouteResult.UnreachableReason.DISCONNECTED)

	var points: Array[Vector3] = [request.from]
	var reverse_chain: Array[Vector2i] = []
	var step := goal
	while step != start:
		reverse_chain.append(step)
		step = came_from[step]
	for index in range(reverse_chain.size() - 1, -1, -1):
		var cell := reverse_chain[index]
		if request.allow_destination_cell and cell == goal and grid.is_blocked(goal):
			continue
		points.append(grid.cell_center(cell))
	if points.back().distance_squared_to(request.destination) > 0.0001:
		points.append(request.destination)

	var waypoints := _smooth(points, profile, request.allow_destination_cell)
	if waypoints.is_empty():
		waypoints = [request.destination]
	return RouteResult.success(waypoints, request.destination, grid_revision, topology_revision)


func _search(start: Vector2i, goal: Vector2i, traveler_profile: TravelerProfile, allow_blocked_goal: bool) -> Dictionary:
	var frontier_cells: Array[Vector2i] = []
	var frontier_priorities := PackedFloat32Array()
	var came_from: Dictionary = {start: start}
	var costs: Dictionary = {start: 0.0}
	var closed: Dictionary = {}
	last_search_expanded_nodes = 0
	last_search_peak_frontier = 0
	var minimum_weight := grid.minimum_cell_weight()
	_heap_push(frontier_cells, frontier_priorities, start, _octile_distance(start, goal) * minimum_weight)
	last_search_peak_frontier = frontier_cells.size()
	while not frontier_cells.is_empty():
		var current := _heap_pop(frontier_cells, frontier_priorities)
		if closed.has(current):
			continue
		closed[current] = true
		last_search_expanded_nodes += 1
		if current == goal:
			break
		for direction in DIRECTIONS:
			var next := current + direction
			if closed.has(next):
				continue
			var is_allowed_blocked_goal := allow_blocked_goal and next == goal
			if not grid.is_walkable(next, traveler_profile.profile_id, traveler_profile) and not is_allowed_blocked_goal:
				continue
			if direction.x != 0 and direction.y != 0:
				if not grid.is_walkable(current + Vector2i(direction.x, 0), traveler_profile.profile_id, traveler_profile) or not grid.is_walkable(current + Vector2i(0, direction.y), traveler_profile.profile_id, traveler_profile):
					continue
			# The step itself has to exist: a terrace beside a terrace is a face,
			# not a neighbour (§10.1). An explicitly allowed goal cell is an
			# interaction target, so only the ground it is entered from matters.
			if not is_allowed_blocked_goal and not grid.is_step_passable(current, next, traveler_profile.profile_id, traveler_profile):
				continue
			var distance := DIAGONAL_DISTANCE if direction.x != 0 and direction.y != 0 else 1.0
			var next_cost := float(costs[current]) + distance * grid.get_step_weight(current, next, traveler_profile.profile_id, traveler_profile)
			if next_cost >= float(costs.get(next, INF)):
				continue
			came_from[next] = current
			costs[next] = next_cost
			_heap_push(frontier_cells, frontier_priorities, next, next_cost + _octile_distance(next, goal) * minimum_weight)
			last_search_peak_frontier = maxi(last_search_peak_frontier, frontier_cells.size())
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


func _smooth(points: Array[Vector3], traveler_profile: TravelerProfile, allow_blocked_destination := false) -> Array[Vector3]:
	if points.size() <= 1:
		return []
	var waypoints: Array[Vector3] = []
	var anchor_index := 0
	while anchor_index < points.size() - 1:
		var best_index := anchor_index + 1
		var original_cost := 0.0
		var last_candidate := mini(points.size() - 1, anchor_index + MAX_SMOOTH_LOOKAHEAD)
		for candidate_index in range(anchor_index + 1, last_candidate + 1):
			if allow_blocked_destination and candidate_index == points.size() - 1:
				break
			var leg_cost := grid.segment_cost(points[candidate_index - 1], points[candidate_index], traveler_profile.profile_id, traveler_profile)
			if not is_finite(leg_cost):
				break
			original_cost += leg_cost
			var direct_cost := grid.segment_cost(points[anchor_index], points[candidate_index], traveler_profile.profile_id, traveler_profile)
			if is_finite(direct_cost) and direct_cost <= original_cost * 1.08:
				best_index = candidate_index
			else:
				break
		waypoints.append(points[best_index])
		anchor_index = best_index
	return waypoints
