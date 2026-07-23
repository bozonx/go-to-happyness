class_name NavGrid
extends RefCounted

## Single source of truth for the settlement's walkable space.
##
## Owns cell geometry (world <-> cell), passability, and line-of-sight queries.
## Every routing consumer reads the grid through this object, so there is exactly
## one definition of "can a citizen stand/pass here" instead of duplicated cell
## math scattered behind Callables.

var cell_size := 1.0
var board_half_cells := 0
var _blocked: Dictionary = {}
var _cell_weights: Dictionary = {}
## Constructed coverage wins over terrain and organic trails.  Keeping this
## layer separate means demolishing a road reveals the still-existing trail
## rather than destroying unrelated coverage data.
var _road_cell_weights: Dictionary = {}
var _road_cells: Dictionary = {}
var _profile_cell_weights: Dictionary = {}
var _minimum_cell_weight := DEFAULT_CELL_WEIGHT
# Set when an incremental erase may have removed the cell that held the current
# minimum. The recompute is deferred to the next minimum_cell_weight() query so a
# batch of per-cell trail updates costs at most one full scan, not one per cell.
var _minimum_dirty := false
var _revision := 0
var _topology_revision := 0
var _component_topology_revision := -1
var _walkable_components: Dictionary = {}

const DEFAULT_CELL_WEIGHT := 2.0
const MIN_CELL_WEIGHT := 0.05
const MAX_CELL_WEIGHT := 32.0
const PEDESTRIAN_PROFILE := &"pedestrian"
const CONNECTED_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1),
]


func configure(next_cell_size: float, next_board_cells: int) -> void:
	var next_half_cells := next_board_cells / 2
	if is_equal_approx(cell_size, next_cell_size) and board_half_cells == next_half_cells:
		return
	cell_size = next_cell_size
	board_half_cells = next_half_cells
	_revision += 1
	_topology_revision += 1


## Replaces the blocked set wholesale. Callers rebuild the dictionary (terrain +
## building footprints) and hand it over; the grid never mutates it in place.
func set_blocked_cells(next_blocked: Dictionary) -> void:
	if _blocked == next_blocked:
		return
	_blocked = next_blocked.duplicate()
	_revision += 1
	_topology_revision += 1


## Replaces terrain traversal weights wholesale. Cells not listed here use the
## default grass cost. Blocked cells remain impassable regardless of a weight.
func set_cell_weights(next_weights: Dictionary) -> void:
	var sanitized := _sanitize_weights(next_weights)
	if _cell_weights == sanitized:
		return
	_cell_weights = sanitized
	_recompute_minimum_cell_weight()
	_revision += 1


## Replaces constructed-road coverage. Roads are deliberately a separate layer:
## terrain is the base, trails are pedestrian-only hints, and a completed road
## is the authoritative surface for every traveller it supports.
func set_road_cell_weights(next_weights: Dictionary) -> void:
	var cells: Dictionary = {}
	for cell: Variant in next_weights:
		if cell is Vector2i:
			cells[cell] = true
	set_road_profile_weights({PEDESTRIAN_PROFILE: next_weights}, cells)


## Roads are profile-aware surfaces. A profile may not enter a road cell unless
## its road type explicitly supports it; this prevents a vehicle from silently
## using pedestrian-only coverage as a fast corridor.
func set_road_profile_weights(next_weights: Dictionary, next_cells: Dictionary) -> void:
	var sanitized_profiles: Dictionary = {}
	for profile: Variant in next_weights:
		if not profile is StringName:
			continue
		var weights: Variant = next_weights[profile]
		if weights is Dictionary:
			var sanitized := _sanitize_weights(weights)
			if not sanitized.is_empty():
				sanitized_profiles[profile] = sanitized
	var sanitized_cells: Dictionary = {}
	for cell: Variant in next_cells:
		if cell is Vector2i:
			sanitized_cells[cell] = true
	if _road_cell_weights == sanitized_profiles and _road_cells == sanitized_cells:
		return
	_road_cell_weights = sanitized_profiles
	_road_cells = sanitized_cells
	_recompute_minimum_cell_weight()
	_revision += 1
	_topology_revision += 1


func set_profile_cell_weights(profile: StringName, next_weights: Dictionary) -> void:
	var sanitized := _sanitize_weights(next_weights)
	var current: Dictionary = _profile_cell_weights.get(profile, {})
	if current == sanitized:
		return
	if sanitized.is_empty():
		_profile_cell_weights.erase(profile)
	else:
		_profile_cell_weights[profile] = sanitized
	_recompute_minimum_cell_weight()
	_revision += 1


## Incremental single-cell update of a profile weight. The trail field pushes one
## cell at a time as walkers reinforce or decay it; this avoids re-sanitizing and
## comparing the entire (ever-growing) overrides dictionary on every change.
func set_profile_cell_weight(profile: StringName, cell: Vector2i, weight: float) -> void:
	if not is_finite(weight) or weight <= 0.0:
		erase_profile_cell_weight(profile, cell)
		return
	var clamped := clampf(weight, MIN_CELL_WEIGHT, MAX_CELL_WEIGHT)
	var profile_weights: Dictionary = _profile_cell_weights.get(profile, {})
	if profile_weights.has(cell) and is_equal_approx(float(profile_weights[cell]), clamped):
		return
	profile_weights[cell] = clamped
	_profile_cell_weights[profile] = profile_weights
	# A lower weight only lowers the minimum, which is O(1) to fold in.
	if clamped < _minimum_cell_weight:
		_minimum_cell_weight = clamped
	_revision += 1


func erase_profile_cell_weight(profile: StringName, cell: Vector2i) -> void:
	var profile_weights: Dictionary = _profile_cell_weights.get(profile, {})
	if not profile_weights.has(cell):
		return
	var removed := float(profile_weights[cell])
	profile_weights.erase(cell)
	if profile_weights.is_empty():
		_profile_cell_weights.erase(profile)
	else:
		_profile_cell_weights[profile] = profile_weights
	# Removing the cell that held the minimum may raise it; defer the scan.
	if removed <= _minimum_cell_weight + 0.0001:
		_minimum_dirty = true
	_revision += 1


func get_cell_weight(cell: Vector2i, profile: StringName = PEDESTRIAN_PROFILE) -> float:
	var road_weights: Dictionary = _road_cell_weights.get(profile, {})
	if road_weights.has(cell):
		return clampf(float(road_weights[cell]), MIN_CELL_WEIGHT, MAX_CELL_WEIGHT)
	var profile_weights: Dictionary = _profile_cell_weights.get(profile, {})
	if profile_weights.has(cell):
		return clampf(float(profile_weights[cell]), MIN_CELL_WEIGHT, MAX_CELL_WEIGHT)
	return clampf(float(_cell_weights.get(cell, DEFAULT_CELL_WEIGHT)), MIN_CELL_WEIGHT, MAX_CELL_WEIGHT)


func movement_speed_modifier_at(position_on_board: Vector3, profile: StringName = PEDESTRIAN_PROFILE) -> float:
	return 1.0 / get_cell_weight(cell_from_position(position_on_board), profile)


func minimum_cell_weight() -> float:
	if _minimum_dirty:
		_recompute_minimum_cell_weight()
	return _minimum_cell_weight


func revision() -> int:
	return _revision


## Topology revision changes only when passability changes. Consumers that need
## collision safety can ignore terrain-cost-only updates through this value.
func topology_revision() -> int:
	return _topology_revision


func cell_from_position(position_on_board: Vector3) -> Vector2i:
	return Vector2i(floori(position_on_board.x / cell_size), floori(position_on_board.z / cell_size))


func cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * cell_size, 0.0, (cell.y + 0.5) * cell_size)


func is_board_cell(cell: Vector2i) -> bool:
	return cell.x >= -board_half_cells and cell.x < board_half_cells and cell.y >= -board_half_cells and cell.y < board_half_cells


func is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


func is_walkable(cell: Vector2i, profile: StringName = PEDESTRIAN_PROFILE) -> bool:
	if not is_board_cell(cell) or _blocked.has(cell):
		return false
	return not _road_cells.has(cell) or (_road_cell_weights.get(profile, {}) as Dictionary).has(cell)


## Reachability queries used during AI candidate discovery do not need a route.
## Connected components reduce those queries to O(1) after one topology-sized
## flood fill, leaving weighted A* for the actor that actually accepts the task.
func are_positions_connected(from: Vector3, to: Vector3) -> bool:
	return are_cells_connected(cell_from_position(from), cell_from_position(to))


func are_cells_connected(from: Vector2i, to: Vector2i) -> bool:
	if not is_walkable(from) or not is_walkable(to):
		return false
	_ensure_walkable_components()
	return _walkable_components.get(from, -1) == _walkable_components.get(to, -2)


## Builds the component cache at a controlled caller-owned time instead of on
## the first AI candidate query after a topology update.
func refresh_connectivity() -> void:
	_ensure_walkable_components()


## True when a straight line between two world points crosses only walkable cells.
## Uses Amanatides & Woo grid traversal so every cell the segment touches is
## tested — no corner is cut past an obstacle. This is what lets routes collapse
## to straight lines while still hugging around blocked footprints.
func is_segment_clear(from: Vector3, to: Vector3, profile: StringName = PEDESTRIAN_PROFILE) -> bool:
	return is_finite(segment_cost(from, to, profile))


## Revalidates only the remaining route after a topology change. A route that ends
## inside an explicitly allowed blocked destination is safe when every segment up
## to that destination cell remains clear.
func is_waypoint_path_clear(from: Vector3, waypoints: Array[Vector3], allow_blocked_destination := false, profile: StringName = PEDESTRIAN_PROFILE) -> bool:
	if waypoints.is_empty():
		return true
	var destination_cell := cell_from_position(waypoints.back())
	var previous := from
	for index in range(waypoints.size()):
		var waypoint: Vector3 = waypoints[index]
		var is_final_allowed_destination := allow_blocked_destination and index == waypoints.size() - 1 and is_blocked(destination_cell)
		if not is_final_allowed_destination and not is_segment_clear(previous, waypoint, profile):
			return false
		if is_final_allowed_destination and not _is_segment_clear_to_allowed_destination(previous, waypoint, profile):
			return false
		previous = waypoint
	return true


## Calculates the total weighted traversal cost of a route's waypoint chain.
## Returns INF if the route is null, unreachable, or any segment crosses a blocked cell.
func route_cost(from: Vector3, route: RefCounted, profile: StringName = PEDESTRIAN_PROFILE) -> float:
	if route == null or not route.reachable:
		return INF
	var cost := 0.0
	var previous := from
	for waypoint: Vector3 in route.waypoints:
		var segment := segment_cost(previous, waypoint, profile)
		if not is_finite(segment):
			return INF
		cost += segment
		previous = waypoint
	return cost


## Traverses every cell crossed by a world-space segment and returns its
## weighted length. INF means the segment crosses a blocked cell or cuts an
## obstacle corner. This is deliberately shared by visibility and smoothing so
## both use the same conservative geometry rules.
func segment_cost(from: Vector3, to: Vector3, profile: StringName = PEDESTRIAN_PROFILE) -> float:
	var start_cell := cell_from_position(from)
	var end_cell := cell_from_position(to)
	if not is_walkable(start_cell, profile) or not is_walkable(end_cell, profile):
		return INF
	var ax := from.x / cell_size
	var az := from.z / cell_size
	var dx := (to.x / cell_size) - ax
	var dz := (to.z / cell_size) - az
	var segment_length := Vector2(to.x - from.x, to.z - from.z).length()
	if segment_length <= 0.0001:
		return 0.0

	var cell := start_cell
	var step_x := 0
	var step_z := 0
	var t_max_x := INF
	var t_max_z := INF
	var t_delta_x := INF
	var t_delta_z := INF

	if dx > 0.0:
		step_x = 1
		t_delta_x = 1.0 / dx
		t_max_x = (float(cell.x + 1) - ax) / dx
	elif dx < 0.0:
		step_x = -1
		t_delta_x = 1.0 / -dx
		t_max_x = (float(cell.x) - ax) / dx

	if dz > 0.0:
		step_z = 1
		t_delta_z = 1.0 / dz
		t_max_z = (float(cell.y + 1) - az) / dz
	elif dz < 0.0:
		step_z = -1
		t_delta_z = 1.0 / -dz
		t_max_z = (float(cell.y) - az) / dz

	var traversed_cost := 0.0
	var previous_t := 0.0
	# A board is at most board_half_cells * 2 wide in each axis; the diagonal span
	# bounds the number of cells any segment can enter, so the loop always ends.
	var guard := board_half_cells * 4 + 4
	while guard > 0:
		guard -= 1
		if cell == end_cell:
			return traversed_cost + (1.0 - previous_t) * segment_length * get_cell_weight(cell, profile)
		var next_t := minf(t_max_x, t_max_z)
		traversed_cost += (next_t - previous_t) * segment_length * get_cell_weight(cell, profile)
		previous_t = next_t
		if is_equal_approx(t_max_x, t_max_z):
			# Crossing exactly through a grid corner touches both side cells. Requiring
			# both prevents a line from slipping through a building corner.
			var horizontal_side := cell + Vector2i(step_x, 0)
			var vertical_side := cell + Vector2i(0, step_z)
			if not is_walkable(horizontal_side, profile) or not is_walkable(vertical_side, profile):
				return INF
			cell += Vector2i(step_x, step_z)
			t_max_x += t_delta_x
			t_max_z += t_delta_z
		elif t_max_x < t_max_z:
			cell.x += step_x
			t_max_x += t_delta_x
		else:
			cell.y += step_z
			t_max_z += t_delta_z
		if not is_walkable(cell, profile):
			return INF
	return INF


## Same Amanatides traversal as segment_cost, except the final blocked cell is
## permitted for an explicit interaction target. Every preceding cell and both
## sides of a crossed corner still must be traversable.
func _is_segment_clear_to_allowed_destination(from: Vector3, to: Vector3, profile: StringName) -> bool:
	var destination_cell := cell_from_position(to)
	if not is_blocked(destination_cell):
		return is_segment_clear(from, to, profile)
	if cell_from_position(from) == destination_cell:
		return true
	var low := 0.0
	var high := 1.0
	for _step in range(24):
		var middle := (low + high) * 0.5
		if cell_from_position(from.lerp(to, middle)) == destination_cell:
			high = middle
		else:
			low = middle
	return is_segment_clear(from, from.lerp(to, low), profile)


func _recompute_minimum_cell_weight() -> void:
	_minimum_cell_weight = DEFAULT_CELL_WEIGHT
	for weight in _cell_weights.values():
		_minimum_cell_weight = minf(_minimum_cell_weight, float(weight))
	for road_weights in _road_cell_weights.values():
		for weight in (road_weights as Dictionary).values():
			_minimum_cell_weight = minf(_minimum_cell_weight, float(weight))
	for profile_weights in _profile_cell_weights.values():
		for weight in (profile_weights as Dictionary).values():
			_minimum_cell_weight = minf(_minimum_cell_weight, float(weight))
	_minimum_cell_weight = clampf(_minimum_cell_weight, MIN_CELL_WEIGHT, MAX_CELL_WEIGHT)
	_minimum_dirty = false


func _sanitize_weights(next_weights: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for cell: Variant in next_weights:
		if not cell is Vector2i:
			continue
		var value: Variant = next_weights[cell]
		if not (value is float or value is int):
			continue
		var weight := float(value)
		if not is_finite(weight) or weight <= 0.0:
			continue
		sanitized[cell] = clampf(weight, MIN_CELL_WEIGHT, MAX_CELL_WEIGHT)
	return sanitized


func _ensure_walkable_components() -> void:
	if _component_topology_revision == _topology_revision:
		return
	_walkable_components.clear()
	var next_component := 0
	for y in range(-board_half_cells, board_half_cells):
		for x in range(-board_half_cells, board_half_cells):
			var start := Vector2i(x, y)
			if not is_walkable(start) or _walkable_components.has(start):
				continue
			var frontier: Array[Vector2i] = [start]
			var cursor := 0
			_walkable_components[start] = next_component
			while cursor < frontier.size():
				var current := frontier[cursor]
				cursor += 1
				for direction in CONNECTED_DIRECTIONS:
					var neighbor := current + direction
					if not is_walkable(neighbor) or _walkable_components.has(neighbor):
						continue
					if direction.x != 0 and direction.y != 0:
						if not is_walkable(current + Vector2i(direction.x, 0)) or not is_walkable(current + Vector2i(0, direction.y)):
							continue
					_walkable_components[neighbor] = next_component
					frontier.append(neighbor)
			next_component += 1
	_component_topology_revision = _topology_revision
