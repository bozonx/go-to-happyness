class_name BuildingQueueService
extends RefCounted

## Keeps one FIFO line per building and lays that line over walkable grid cells.

var building_registry: BuildingRegistry
var grid: NavGrid
var _queues: Dictionary = {}
var _last_admitted_frame: Dictionary = {}
var _building_lookup_cache: Dictionary = {}
const BUILDING_LOOKUP_CACHE_LIMIT := 512


func configure(registry: BuildingRegistry, next_grid: NavGrid) -> void:
	building_registry = registry
	grid = next_grid


func resolve(citizen: Node, destination: Vector3) -> Dictionary:
	if building_registry == null:
		return {"position": destination, "is_head": true}
	var building := _building_for_destination(destination)
	if not is_instance_valid(building):
		return {"position": destination, "is_head": true}
	var service_position: Vector3 = building.get_meta("service_position", building.position)

	var frame := Engine.get_physics_frames()
	var building_id := building.get_instance_id()
	var citizen_id := citizen.get_instance_id()
	var queue: Array = _queues.get(building_id, [])
	_prune_queue(queue)
	if not queue.has(citizen_id):
		queue.append(citizen_id)
	_queues[building_id] = queue

	var index := queue.find(citizen_id)
	if index <= 0 and int(_last_admitted_frame.get(building_id, -1)) != frame:
		return {"position": service_position, "is_head": true}
	var slots := _build_slots(building, service_position, queue.size())
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
	var queue: Array = _queues.get(building_id, [])
	var index := queue.find(citizen.get_instance_id())
	if index != 0:
		return
	queue.pop_front()
	_last_admitted_frame[building_id] = Engine.get_physics_frames()
	if queue.is_empty():
		_queues.erase(building_id)
	else:
		_queues[building_id] = queue


func release(citizen: Node) -> void:
	if not is_instance_valid(citizen):
		return
	var citizen_id := citizen.get_instance_id()
	for building_id in _queues.keys().duplicate():
		var queue: Array = _queues[building_id]
		queue.erase(citizen_id)
		_prune_queue(queue)
		if queue.is_empty():
			_queues.erase(building_id)
		else:
			_queues[building_id] = queue


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
	var service_position: Vector3 = building.get_meta("service_position", building.position)
	var entrance: Vector3 = building.get_meta("entrance_position", Vector3.INF)
	return (
		building.position.distance_squared_to(destination) < 0.01
		or service_position.distance_squared_to(destination) < 0.01
		or entrance.distance_squared_to(destination) < 0.01
	)


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
