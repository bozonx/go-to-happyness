class_name CitizenNeedsService
extends RefCounted

## Owns personal-need schedules and completion state. It never drives a Citizen
## directly; the native AI consumes the exported requests through the facade.

const TOILET_START_MINUTE := 8.0 * 60.0
const TOILET_END_MINUTE := 20.0 * 60.0
const RELIEF_SEARCH_RADIUS := 100.0

var simulation: Node
var _toilet_due_minutes: Dictionary = {}
var _toilet_requests: Dictionary = {}
var _rest_requests: Dictionary = {}


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func schedule_toilet(citizen_id: int) -> void:
	if citizen_id <= 0:
		return
	_toilet_due_minutes[citizen_id] = randf_range(TOILET_START_MINUTE, TOILET_END_MINUTE)
	_toilet_requests.erase(citizen_id)


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
		&"position": rest_positions[randi() % rest_positions.size()],
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
	if not is_instance_valid(simulation) or not is_instance_valid(citizen):
		return candidates
	for toilet in simulation.get_toilets():
		var position: Vector3 = toilet.get_meta("service_position") if toilet.has_meta("service_position") else toilet.global_position
		if citizen.global_position.distance_to(position) > RELIEF_SEARCH_RADIUS:
			continue
		var building_type := str(toilet.get_meta("building_type", ""))
		var capacity := _toilet_capacity(building_type)
		for slot in range(capacity):
			candidates.append({
				&"id": StringName("toilet:%s:%d" % [_position_key(position), slot]),
				&"position": position,
				&"kind": &"toilet",
			})
	if not candidates.is_empty():
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
	return candidates


func fulfill_toilet(citizen_id: int) -> void:
	_toilet_requests.erase(citizen_id)


func fulfill_rest(citizen_id: int) -> void:
	_rest_requests.erase(citizen_id)


func remove_citizen(citizen_id: int) -> void:
	_toilet_due_minutes.erase(citizen_id)
	_toilet_requests.erase(citizen_id)
	_rest_requests.erase(citizen_id)


func _nearest_relief_position(citizen: Citizen, relief_type: StringName) -> Vector3:
	var closest := Vector3.INF
	var closest_distance := INF
	if relief_type == &"tree":
		for tree_position in simulation.tree_positions:
			if citizen.global_position.distance_to(tree_position) > RELIEF_SEARCH_RADIUS:
				continue
			var position: Vector3 = simulation._resource_access_position(citizen.global_position, tree_position)
			if position == Vector3.INF:
				continue
			var distance := citizen.global_position.distance_squared_to(position)
			if distance < closest_distance:
				closest = position
				closest_distance = distance
	elif relief_type == &"grass":
		for source in simulation.grass_sources.values():
			var grass_node := source.get("node") as Node3D
			if not is_instance_valid(grass_node) or citizen.global_position.distance_to(grass_node.global_position) > RELIEF_SEARCH_RADIUS:
				continue
			var route: RouteResult = simulation._find_path_around_houses(citizen.global_position, grass_node.global_position, false)
			if not route.reachable:
				continue
			var distance := citizen.global_position.distance_squared_to(grass_node.global_position)
			if distance < closest_distance:
				closest = grass_node.global_position
				closest_distance = distance
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
