class_name CourierDispatcher
extends RefCounted

const CourierTaskScript = preload("res://game/features/logistics/domain/courier_task.gd")

## Single entry point for courier scheduling. Task producers may still keep
## their domain-specific reservation rules while migration to CourierTask is
## in progress, but only this dispatcher starts the scheduling pass.

var simulation: Node
var tasks: Dictionary = {}
var _tasks_by_courier_id: Dictionary = {}


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func dispatch() -> void:
	if simulation == null:
		return
	_cleanup_invalid_tasks()
	simulation._publish_courier_tasks(self)
	_publish_manual_worker_tasks()
	_cleanup_invalid_tasks()


func available_tasks() -> Array[CourierTask]:
	var result: Array[CourierTask] = []
	for task: CourierTask in tasks.values():
		if not task.is_assigned() and simulation._is_courier_task_valid(task):
			result.append(task)
	result.sort_custom(func(a: CourierTask, b: CourierTask): return a.priority > b.priority)
	return result


func task_for(courier: Citizen) -> CourierTask:
	if not is_instance_valid(courier):
		return null
	var courier_id := courier.ai_id
	var task := _tasks_by_courier_id.get(courier_id) as CourierTask
	if task != null and tasks.get(task.id) == task and task.assigned_courier_ai_id == courier_id:
		return task
	_tasks_by_courier_id.erase(courier_id)
	return null


func start_task(courier: Citizen, task_id: StringName) -> bool:
	if not is_instance_valid(courier) or courier.ai_id <= 0 or not tasks.has(task_id):
		return false
	var task: CourierTask = tasks[task_id]
	var requested_courier_ai_id := int(task.payload.get("courier_ai_id", 0))
	if task.is_assigned() or (requested_courier_ai_id > 0 and requested_courier_ai_id != courier.ai_id) or not simulation._is_courier_task_valid(task) or not simulation._start_courier_task(courier, task):
		return false
	task.assigned_courier_ai_id = courier.ai_id
	_tasks_by_courier_id[task.assigned_courier_ai_id] = task
	return true


func is_manually_targeted(worker: Citizen) -> bool:
	if simulation == null or not is_instance_valid(worker):
		return false
	for courier in simulation.citizens:
		if is_instance_valid(courier) and courier.can_handle_entry_logistics() and courier.courier_worker == worker:
			return true
	return false


func _publish_manual_worker_tasks() -> void:
	if simulation.warehouse_positions.is_empty():
		return
	for courier in simulation.citizens:
		if not is_instance_valid(courier) or not courier.can_handle_entry_logistics():
			continue
		var worker: Citizen = courier.courier_worker
		if not is_instance_valid(worker):
			continue
		if not worker.has_pending_resource():
			courier.courier_worker = null
			continue
		var resource_type: String = worker.resource_type
		var amount := worker.carried_amount
		var worker_position: Vector3 = worker.global_position if worker.is_inside_tree() else worker.position
		var warehouse_index: int = _warehouse_index(worker_position, resource_type, amount)
		if warehouse_index < 0:
			continue
		publish(
			StringName("manual_worker_%d" % courier.ai_id),
			CourierTask.Kind.WORKER_PICKUP,
			110,
			worker_position,
			simulation.warehouse_positions[warehouse_index],
			{"worker": worker, "courier_ai_id": courier.ai_id}
		)


func publish(id: StringName, kind: CourierTask.Kind, priority: int, pickup: Vector3, dropoff: Vector3, payload := {}) -> void:
	if tasks.has(id):
		return
	var task := CourierTaskScript.new()
	task.id = id
	task.kind = kind
	task.priority = priority
	task.pickup = pickup
	task.dropoff = dropoff
	task.payload = payload
	task.created_at = simulation.runtime_seconds
	tasks[id] = task


func complete_for(courier: Citizen) -> void:
	if not is_instance_valid(courier):
		return
	var courier_id := courier.ai_id
	var task := _tasks_by_courier_id.get(courier_id) as CourierTask
	_tasks_by_courier_id.erase(courier_id)
	if task != null and tasks.get(task.id) == task:
		tasks.erase(task.id)


func _available_couriers() -> Array[Citizen]:
	var couriers: Array[Citizen] = []
	var daily_couriers: Array[Citizen] = []
	for citizen in simulation.citizens:
		if not citizen.can_handle_entry_logistics() or citizen.state not in [Citizen.State.IDLE, Citizen.State.WAITING]:
			continue
		if citizen.is_courier():
			couriers.append(citizen)
		elif citizen.is_daily_courier():
			daily_couriers.append(citizen)
	return couriers if not couriers.is_empty() else daily_couriers


func _nearest_courier(couriers: Array[Citizen], pickup: Vector3) -> Citizen:
	var best: Citizen = null
	var distance := INF
	for courier in couriers:
		var candidate_distance := courier.global_position.distance_squared_to(pickup)
		if candidate_distance < distance:
			best = courier
			distance = candidate_distance
	return best


func _warehouse_index(from: Vector3, resource_type: String, amount: int) -> int:
	if simulation.has_method(&"_find_reachable_warehouse_index"):
		return simulation._find_reachable_warehouse_index(from, resource_type, amount)
	return simulation.settlement.find_warehouse_index(from, resource_type, amount, simulation.warehouse_positions)


func _cleanup_invalid_tasks() -> void:
	for id: StringName in tasks.keys():
		var task: CourierTask = tasks[id]
		var became_unassigned := false
		if task.is_assigned():
			var courier := _courier_for_ai_id(task.assigned_courier_ai_id)
			if is_instance_valid(courier) and courier.has_active_delivery():
				continue
			if simulation.has_method("_cancel_courier_task"):
				simulation._cancel_courier_task(courier, task)
			_tasks_by_courier_id.erase(task.assigned_courier_ai_id)
			task.assigned_courier_ai_id = 0
			became_unassigned = true
		if not simulation._is_courier_task_valid(task) or became_unassigned:
			if task.has_reservation() and simulation.has_method("_release_task_warehouse_reservation"):
				simulation._release_task_warehouse_reservation(task)
		if not simulation._is_courier_task_valid(task):
			_tasks_by_courier_id.erase(task.assigned_courier_ai_id)
			tasks.erase(id)


func _courier_for_ai_id(citizen_id: int) -> Citizen:
	if simulation == null or citizen_id <= 0:
		return null
	for candidate in simulation.citizens:
		if is_instance_valid(candidate) and candidate.ai_id == citizen_id:
			return candidate
	return null
