class_name BuildingQueueService
extends RefCounted

## Keeps FIFO lines per worker entrance of a building and lays each line over
## walkable grid cells. Citizens distribute evenly across multiple entrances when
## they first arrive, and once assigned to a line they stay there until served.

var building_registry: BuildingRegistry
var grid: NavGrid
var _queues: Dictionary = {}
var _occupants: Dictionary = {}
var _last_admitted_frame: Dictionary = {}
var _building_lookup_cache: Dictionary = {}
const BUILDING_LOOKUP_CACHE_LIMIT := 512


func configure(registry: BuildingRegistry, next_grid: NavGrid) -> void:
	building_registry = registry
	grid = next_grid


func _citizen_id(citizen: Node) -> int:
	var ai_id: Variant = citizen.get("ai_id")
	if ai_id != null:
		return int(ai_id)
	return citizen.get_instance_id()


func resolve(citizen: Node, destination: Vector3) -> Dictionary:
	if building_registry == null:
		return {"position": destination, "is_head": true}
	var building := _building_for_destination(destination)
	if not is_instance_valid(building):
		return {"position": destination, "is_head": true}

	var frame := Engine.get_physics_frames()
	var building_id := building.get_instance_id()
	var citizen_id := _citizen_id(citizen)
	_release_from_other_buildings(citizen_id, building_id)

	var entrance_count := _entrance_count(building)
	_ensure_building_queues(building_id, entrance_count)
	var service_positions := _service_positions(building)

	var entrance_index := _find_citizen_entrance(building_id, citizen_id)
	if entrance_index < 0:
		# New arrival: balance across entrances by choosing the shortest queue.
		entrance_index = 0
		var shortest: int = (_queues[building_id] as Array)[0].size()
		for index in range(1, entrance_count):
			var queue_size: int = (_queues[building_id] as Array)[index].size()
			if queue_size < shortest:
				shortest = queue_size
				entrance_index = index

	var queue: Array = (_queues[building_id] as Array)[entrance_index]
	_prune_queue(queue)
	if not queue.has(citizen_id):
		queue.append(citizen_id)
	(_queues[building_id] as Array)[entrance_index] = queue

	var index := queue.find(citizen_id)
	var capacity := _capacity_for(building)
	var total_occupants := _total_occupants(building_id)
	var per_entrance_capacity := maxi(1, ceili(float(capacity) / entrance_count))
	var entrance_occupants: Array = (_occupants[building_id] as Array)[entrance_index]
	_prune_queue(entrance_occupants)
	(_occupants[building_id] as Array)[entrance_index] = entrance_occupants

	if index <= 0 and total_occupants < capacity and entrance_occupants.size() < per_entrance_capacity and int((_last_admitted_frame[building_id] as Array)[entrance_index]) != frame:
		return {"position": service_positions[entrance_index], "is_head": true}

	var slots := _build_slots(building, service_positions[entrance_index], queue.size() + 1)
	var waiting_index := maxi(1, index)
	if waiting_index < slots.size():
		return {"position": slots[waiting_index], "is_head": false}

	# Do not stack overflow members onto the same final cell. They remain where
	# they are until a unique slot becomes available.
	var current_position := destination
	if citizen is Node3D:
		current_position = (citizen as Node3D).global_position
	return {"position": current_position, "is_head": false}


func complete_arrival(citizen: Node, destination: Vector3) -> void:
	if not is_instance_valid(citizen):
		return
	var building := _building_for_destination(destination)
	if not is_instance_valid(building):
		return
	var building_id := building.get_instance_id()
	var citizen_id := _citizen_id(citizen)
	var entrance_index := _find_citizen_entrance(building_id, citizen_id)
	if entrance_index < 0:
		entrance_index = _entrance_for_destination(building, destination)
	if entrance_index < 0:
		entrance_index = 0
	var entrance_count := _entrance_count(building)
	_ensure_building_queues(building_id, entrance_count)

	var queue: Array = (_queues[building_id] as Array)[entrance_index]
	if queue.is_empty() or queue[0] != citizen_id:
		return
	queue.pop_front()
	if queue.is_empty():
		(_queues[building_id] as Array)[entrance_index] = []
	else:
		(_queues[building_id] as Array)[entrance_index] = queue

	var occupants: Array = (_occupants[building_id] as Array)[entrance_index]
	_prune_queue(occupants)
	if not occupants.has(citizen_id):
		occupants.append(citizen_id)
	(_occupants[building_id] as Array)[entrance_index] = occupants
	(_last_admitted_frame[building_id] as Array)[entrance_index] = Engine.get_physics_frames()


func release(citizen: Node) -> void:
	if not is_instance_valid(citizen):
		return
	var citizen_id := _citizen_id(citizen)
	for building_id in _queues.keys().duplicate():
		var entrances: Array = _queues[building_id]
		var became_empty := true
		for index in range(entrances.size()):
			var queue: Array = entrances[index]
			queue.erase(citizen_id)
			_prune_queue(queue)
			if not queue.is_empty():
				became_empty = false
			entrances[index] = queue
		_queues[building_id] = entrances
		if became_empty:
			_queues.erase(building_id)
	for building_id in _occupants.keys().duplicate():
		var entrances: Array = _occupants[building_id]
		var became_empty := true
		for index in range(entrances.size()):
			var occupants: Array = entrances[index]
			occupants.erase(citizen_id)
			_prune_queue(occupants)
			if not occupants.is_empty():
				became_empty = false
			entrances[index] = occupants
		_occupants[building_id] = entrances
		if became_empty:
			_occupants.erase(building_id)


func _release_from_other_buildings(citizen_id: int, retained_building_id: int) -> void:
	for building_id in _queues.keys().duplicate():
		if int(building_id) == retained_building_id:
			continue
		var entrances: Array = _queues[building_id]
		var became_empty := true
		for index in range(entrances.size()):
			var queue: Array = entrances[index]
			queue.erase(citizen_id)
			_prune_queue(queue)
			if not queue.is_empty():
				became_empty = false
			entrances[index] = queue
		_queues[building_id] = entrances
		if became_empty:
			_queues.erase(building_id)
	for building_id in _occupants.keys().duplicate():
		if int(building_id) == retained_building_id:
			continue
		var entrances: Array = _occupants[building_id]
		var became_empty := true
		for index in range(entrances.size()):
			var occupants: Array = entrances[index]
			occupants.erase(citizen_id)
			_prune_queue(occupants)
			if not occupants.is_empty():
				became_empty = false
			entrances[index] = occupants
		_occupants[building_id] = entrances
		if became_empty:
			_occupants.erase(building_id)


func _capacity_for(building: Node3D) -> int:
	var building_type := str(building.get_meta("building_type", ""))
	if building_type.begins_with("toilet_"):
		var base_capacity := 1
		if "earth" in building_type: base_capacity = 2
		elif "clay" in building_type: base_capacity = 3
		elif "wood" in building_type: base_capacity = 4
		elif "stone" in building_type: base_capacity = 5
		elif "brick" in building_type: base_capacity = 6
		var level := 3 if "lvl3" in building_type else 2 if "lvl2" in building_type else 1
		return base_capacity + level - 1
	if building.has_meta("housing_capacity"):
		return maxi(1, int(building.get_meta("housing_capacity")))
	if building.has_meta("required_factory_workers"):
		return maxi(1, int(building.get_meta("required_factory_workers")))
	return maxi(1, int(building.get_meta("queue_capacity", 1)))


func _entrance_count(building: Node3D) -> int:
	if building.has_meta("service_positions"):
		var positions: Array = building.get_meta("service_positions")
		return maxi(1, positions.size())
	return 1


func _service_positions(building: Node3D) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if building.has_meta("service_positions"):
		for value in building.get_meta("service_positions") as Array:
			if value is Vector3:
				result.append(value)
	if result.is_empty() and building.has_meta("service_position"):
		result.append(building.get_meta("service_position"))
	if result.is_empty():
		result.append(building.position)
	return result


func _entrance_for_destination(building: Node3D, destination: Vector3) -> int:
	var service_positions := _service_positions(building)
	for index in range(service_positions.size()):
		if service_positions[index].distance_squared_to(destination) < 0.01:
			return index
	if building.has_meta("entrance_positions"):
		var positions: Array = building.get_meta("entrance_positions")
		for index in range(positions.size()):
			if positions[index] is Vector3 and (positions[index] as Vector3).distance_squared_to(destination) < 0.01:
				return index
	if building.has_meta("entrance_position") and (building.get_meta("entrance_position") as Vector3).distance_squared_to(destination) < 0.01:
		return 0
	if building.position.distance_squared_to(destination) < 0.01:
		return 0
	return -1


func _find_citizen_entrance(building_id: int, citizen_id: int) -> int:
	if not _queues.has(building_id) and not _occupants.has(building_id):
		return -1
	var entrances: Array = _queues.get(building_id, [])
	for index in range(entrances.size()):
		if citizen_id in (entrances[index] as Array):
			return index
	entrances = _occupants.get(building_id, [])
	for index in range(entrances.size()):
		if citizen_id in (entrances[index] as Array):
			return index
	return -1


func _ensure_building_queues(building_id: int, entrance_count: int) -> void:
	_queues[building_id] = _ensure_entrance_array(_queues.get(building_id, []), entrance_count, [])
	_occupants[building_id] = _ensure_entrance_array(_occupants.get(building_id, []), entrance_count, [])
	_last_admitted_frame[building_id] = _ensure_entrance_array(_last_admitted_frame.get(building_id, []), entrance_count, -1)


func _ensure_entrance_array(existing: Variant, entrance_count: int, default_value: Variant) -> Array:
	var result: Array = existing if existing is Array else []
	while result.size() < entrance_count:
		if default_value is Array:
			result.append([])
		else:
			result.append(default_value)
	return result


func _total_occupants(building_id: int) -> int:
	var total := 0
	if _occupants.has(building_id):
		for occupants in _occupants[building_id] as Array:
			total += (occupants as Array).size()
	return total


func _building_for_destination(destination: Vector3) -> Node3D:
	var key := _destination_key(destination)
	var cached := _building_lookup_cache.get(key) as Node3D
	if is_instance_valid(cached) and _matches_destination(cached, destination):
		return cached
	_building_lookup_cache.erase(key)
	for record in building_registry.records():
		if not is_instance_valid(record.node):
			continue
		var building: Node3D = record.node
		if _matches_destination(building, destination):
			if _building_lookup_cache.size() >= BUILDING_LOOKUP_CACHE_LIMIT:
				_building_lookup_cache.clear()
			_building_lookup_cache[key] = building
			return building
	return null


func _matches_destination(building: Node3D, destination: Vector3) -> bool:
	for position in _service_positions(building):
		if position.distance_squared_to(destination) < 0.01:
			return true
	if building.has_meta("entrance_position"):
		var entrance: Vector3 = building.get_meta("entrance_position")
		if entrance.distance_squared_to(destination) < 0.01:
			return true
	if building.has_meta("entrance_positions"):
		for value in building.get_meta("entrance_positions") as Array:
			if value is Vector3 and (value as Vector3).distance_squared_to(destination) < 0.01:
				return true
	return false


func _destination_key(destination: Vector3) -> String:
	return "%d:%d:%d" % [roundi(destination.x * 100.0), roundi(destination.y * 100.0), roundi(destination.z * 100.0)]


func _prune_queue(queue: Array) -> void:
	for index in range(queue.size() - 1, -1, -1):
		var citizen_id: int = queue[index]
		if not is_instance_id_valid(citizen_id):
			queue.remove_at(index)


func _build_slots(building: Node3D, destination: Vector3, count: int) -> Array[Vector3]:
	var slots: Array[Vector3] = [destination]
	if count <= 1:
		return slots
	var current: Vector2i = grid.cell_from_position(destination)
	var outward := _cardinal_direction(destination - building.position)
	var direction := outward
	var visited := {current: true}
	while slots.size() < count:
		var next_direction := _choose_next_direction(current, direction, visited)
		if next_direction == Vector2i.ZERO:
			break
		direction = next_direction
		current += direction
		visited[current] = true
		slots.append(grid.cell_center(current))
	return slots


func _choose_next_direction(cell: Vector2i, direction: Vector2i, visited: Dictionary) -> Vector2i:
	var right := Vector2i(-direction.y, direction.x)
	var candidates: Array[Vector2i] = [direction, right, -right, -direction]
	for candidate in candidates:
		var next := cell + candidate
		if grid.is_walkable(next) and not visited.has(next):
			return candidate
	return Vector2i.ZERO


func _cardinal_direction(offset: Vector3) -> Vector2i:
	if absf(offset.x) >= absf(offset.z):
		return Vector2i(1 if offset.x >= 0.0 else -1, 0)
	return Vector2i(0, 1 if offset.z >= 0.0 else -1)
