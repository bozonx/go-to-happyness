class_name CitizenNeedsService
extends RefCounted

## Owns personal-need schedules and completion state. It never drives a Citizen
## directly; the native AI consumes the exported requests through the facade.

const GrassSourceRecord = preload("res://game/features/production/domain/grass_source_record.gd")

const TOILET_START_MINUTE := 8.0 * 60.0
const TOILET_END_MINUTE := 20.0 * 60.0
const RELIEF_SEARCH_RADIUS := 100.0
const TREE_ACCESS_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var _nav_grid: Variant = null
var _toilets_getter: Callable = Callable()
var _is_route_reachable: Callable = Callable()
var _building_type_for_node: Callable = Callable()
var _tree_positions: Array[Vector3] = []
var _grass_sources: Dictionary = {}
var _toilet_due_minutes: Dictionary = {}
var _toilet_requests: Dictionary = {}
var _rest_requests: Dictionary = {}
var _relief_candidates_by_citizen: Dictionary = {}
var _random: RandomNumberGenerator


func set_random(rng: RandomNumberGenerator) -> void:
	_random = rng


func configure(
	nav_grid: Variant,
	toilets_getter: Callable,
	is_route_reachable: Callable,
	building_type_for_node: Callable,
	tree_positions: Array[Vector3],
	grass_sources: Dictionary,
) -> void:
	_nav_grid = nav_grid
	_toilets_getter = toilets_getter
	_is_route_reachable = is_route_reachable
	_building_type_for_node = building_type_for_node
	_tree_positions = tree_positions
	_grass_sources = grass_sources


func schedule_toilet(citizen_id: int) -> void:
	if citizen_id <= 0:
		return
	_toilet_due_minutes[citizen_id] = _random.randf_range(TOILET_START_MINUTE, TOILET_END_MINUTE) if _random != null else randf_range(TOILET_START_MINUTE, TOILET_END_MINUTE)
	_toilet_requests.erase(citizen_id)
	_relief_candidates_by_citizen.erase(citizen_id)


func schedule_daily_toilets(citizens: Array) -> void:
	for citizen in citizens:
		if is_instance_valid(citizen) and citizen.ai_id > 0:
			schedule_toilet(citizen.ai_id)


func tick(game_minutes: float) -> void:
	for citizen_id in _toilet_due_minutes.keys():
		if game_minutes >= float(_toilet_due_minutes[citizen_id]):
			_toilet_due_minutes.erase(citizen_id)
			_toilet_requests[citizen_id] = true


func request_scheduled_rest(cooks_only: bool, citizens: Array, rest_positions: Array[Vector3]) -> int:
	if rest_positions.is_empty():
		return 0
	var requested := 0
	for citizen in citizens:
		if not is_instance_valid(citizen) or citizen.ai_id <= 0 or citizen.is_player_controlled:
			continue
		if citizen.state not in [Citizen.State.IDLE, Citizen.State.WAITING]:
			continue
		if (citizen.specialization == "cook") != cooks_only:
			continue
		_rest_requests[citizen.ai_id] = {
			&"position": rest_positions[requested % rest_positions.size()],
			&"duration": 4.0,
		}
		requested += 1
	return requested


func request_leisure(citizen_id: int, rest_positions: Array[Vector3], minimum_hours := 0) -> bool:
	if citizen_id <= 0 or rest_positions.is_empty():
		return false
	_rest_requests[citizen_id] = {
		&"position": rest_positions[(_random.randi() if _random != null else randi()) % rest_positions.size()],
		&"duration": maxf(4.0, float(minimum_hours) * 12.5) if minimum_hours > 0 else 4.0,
	}
	return true


func has_toilet_request(citizen_id: int) -> bool:
	return _toilet_requests.has(citizen_id)


func has_rest_request(citizen_id: int) -> bool:
	return _rest_requests.has(citizen_id)


func rest_request(citizen_id: int) -> Dictionary:
	return (_rest_requests.get(citizen_id, {}) as Dictionary).duplicate(true)


func relief_candidates_for(citizen: Citizen) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if not is_instance_valid(citizen):
		return candidates
	var topology_revision: int = _nav_grid.topology_revision()
	var cached: Dictionary = _relief_candidates_by_citizen.get(citizen.ai_id, {})
	if int(cached.get(&"topology_revision", -1)) == topology_revision:
		return (cached.get(&"candidates", []) as Array[Dictionary]).duplicate(true)
	for toilet in _toilets_getter.call():
		var position: Vector3 = toilet.get_meta("service_position") if toilet.has_meta("service_position") else toilet.global_position
		if citizen.global_position.distance_to(position) > RELIEF_SEARCH_RADIUS:
			continue
		if not _is_route_reachable.call(citizen.global_position, position):
			continue
		var building_type: String = ""
		if _building_type_for_node.is_valid():
			building_type = _building_type_for_node.call(toilet)
		elif toilet.has_meta("building_type"):
			building_type = str(toilet.get_meta("building_type"))
		var capacity := _toilet_capacity(building_type)
		for slot in range(capacity):
			candidates.append({
				&"id": StringName("toilet:%s:%d" % [_position_key(position), slot]),
				&"position": position,
				&"kind": &"toilet",
			})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return citizen.global_position.distance_squared_to(left.position) < citizen.global_position.distance_squared_to(right.position)
	)
	if not candidates.is_empty():
		_cache_relief_candidates(citizen.ai_id, topology_revision, candidates)
		return candidates
	var relief_types: Array[StringName] = []
	if citizen.gender == "male":
		relief_types.assign([&"tree", &"grass"])
	else:
		relief_types.assign([&"grass", &"tree"])
	for relief_type in relief_types:
		var position := _nearest_relief_position(citizen, relief_type)
		if position != Vector3.INF:
			candidates.append({
				&"id": StringName("%s:%s" % [relief_type, _position_key(position)]),
				&"position": position,
				&"kind": relief_type,
			})
	if not candidates.is_empty():
		_cache_relief_candidates(citizen.ai_id, topology_revision, candidates)
	return candidates


func fulfill_toilet(citizen_id: int) -> void:
	_toilet_requests.erase(citizen_id)
	_relief_candidates_by_citizen.erase(citizen_id)


func fulfill_rest(citizen_id: int) -> void:
	_rest_requests.erase(citizen_id)


func remove_citizen(citizen_id: int) -> void:
	_toilet_due_minutes.erase(citizen_id)
	_toilet_requests.erase(citizen_id)
	_rest_requests.erase(citizen_id)
	_relief_candidates_by_citizen.erase(citizen_id)


func _cache_relief_candidates(citizen_id: int, topology_revision: int, candidates: Array[Dictionary]) -> void:
	_relief_candidates_by_citizen[citizen_id] = {
		&"topology_revision": topology_revision,
		&"candidates": candidates.duplicate(true),
	}


func _nearest_relief_position(citizen: Citizen, relief_type: StringName) -> Vector3:
	var closest := Vector3.INF
	var closest_distance := INF
	if relief_type == &"tree":
		for tree_position in _tree_positions:
			if citizen.global_position.distance_to(tree_position) > RELIEF_SEARCH_RADIUS:
				continue
			var tree_cell: Vector2i = _nav_grid.cell_from_position(tree_position)
			for offset in TREE_ACCESS_OFFSETS:
				var access_cell := tree_cell + offset
				if not _nav_grid.are_cells_connected(
					_nav_grid.cell_from_position(citizen.global_position), access_cell
				):
					continue
				var position: Vector3 = _nav_grid.cell_center(access_cell)
				var distance := citizen.global_position.distance_squared_to(position)
				if distance < closest_distance:
					closest = position
					closest_distance = distance
	elif relief_type == &"grass":
		var positions_by_distance: Array[Dictionary] = []
		for source in _grass_sources.values():
			var grass_source: GrassSourceRecord = source
			if not is_instance_valid(grass_source.node) or citizen.global_position.distance_to(grass_source.node.global_position) > RELIEF_SEARCH_RADIUS:
				continue
			positions_by_distance.append({
				&"position": grass_source.node.global_position,
				&"distance": citizen.global_position.distance_squared_to(grass_source.node.global_position),
			})
		positions_by_distance.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return float(left[&"distance"]) < float(right[&"distance"])
		)
		for candidate in positions_by_distance:
			var position: Vector3 = candidate[&"position"]
			if _nav_grid.are_positions_connected(citizen.global_position, position):
				return position
	return closest


func _toilet_capacity(building_type: String) -> int:
	var base_capacity := 1
	if "earth" in building_type:
		base_capacity = 2
	elif "clay" in building_type:
		base_capacity = 3
	elif "wood" in building_type:
		base_capacity = 4
	elif "stone" in building_type:
		base_capacity = 5
	elif "brick" in building_type:
		base_capacity = 6
	var level := 3 if "lvl3" in building_type else 2 if "lvl2" in building_type else 1
	return base_capacity + level - 1


func _position_key(position: Vector3) -> String:
	return "%d:%d:%d" % [roundi(position.x * 100.0), roundi(position.y * 100.0), roundi(position.z * 100.0)]
