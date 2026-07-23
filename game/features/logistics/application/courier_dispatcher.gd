class_name CourierDispatcher
extends RefCounted

const CourierTaskScript = preload("res://game/features/logistics/domain/courier_task.gd")

## Single entry point for courier scheduling. Task producers may still keep
## their domain-specific reservation rules while migration to CourierTask is
## in progress, but only this dispatcher starts the scheduling pass.

var _citizens: Array = []
var _warehouse_positions: Array[Vector3] = []
var _storage_routing: StorageRoutingService
var _runtime_seconds_getter: Callable
var _publish_tasks: Callable
var _is_task_valid: Callable
var _start_task: Callable
var _cancel_task: Callable
var _release_reservation: Callable

var tasks: Dictionary = {}
var _tasks_by_courier_id: Dictionary = {}


func configure(
	citizens: Array,
	warehouse_positions: Array[Vector3],
	storage_routing: StorageRoutingService,
	runtime_seconds_getter: Callable,
	publish_tasks: Callable,
	is_task_valid: Callable,
	start_task: Callable,
	cancel_task: Callable,
	release_reservation: Callable
) -> void:
	_citizens = citizens
	_warehouse_positions = warehouse_positions
	_storage_routing = storage_routing
	_runtime_seconds_getter = runtime_seconds_getter
	_publish_tasks = publish_tasks
	_is_task_valid = is_task_valid
	_start_task = start_task
	_cancel_task = cancel_task
	_release_reservation = release_reservation


func dispatch() -> void:
	_cleanup_invalid_tasks()
	_publish_tasks.call(self)
	_publish_manual_worker_tasks()
	_cleanup_invalid_tasks()


func available_tasks() -> Array[CourierTask]:
	var result: Array[CourierTask] = []
	for task: CourierTask in tasks.values():
		if not task.is_assigned() and _is_task_valid.call(task):
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
	if task.is_assigned() or (requested_courier_ai_id > 0 and requested_courier_ai_id != courier.ai_id) or not _is_task_valid.call(task) or not _start_task.call(courier, task):
		return false
	task.assigned_courier_ai_id = courier.ai_id
	_tasks_by_courier_id[task.assigned_courier_ai_id] = task
	return true


func is_manually_targeted(worker: Citizen) -> bool:
	if not is_instance_valid(worker):
		return false
	for courier in _citizens:
		if is_instance_valid(courier) and courier.can_handle_entry_logistics() and courier.courier_worker == worker:
			return true
	return false


func _publish_manual_worker_tasks() -> void:
	if _warehouse_positions.is_empty():
		return
	for courier in _citizens:
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
		var warehouse_index: int = _storage_routing.find_reachable_warehouse_index(worker_position, resource_type, amount)
		if warehouse_index < 0:
			continue
		publish(
			StringName("manual_worker_%d" % courier.ai_id),
			CourierTask.Kind.WORKER_PICKUP,
			110,
			worker_position,
			_warehouse_positions[warehouse_index],
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
	task.created_at = _runtime_seconds_getter.call()
	tasks[id] = task


func complete_for(courier: Citizen) -> void:
	if not is_instance_valid(courier):
		return
	var courier_id := courier.ai_id
	var task := _tasks_by_courier_id.get(courier_id) as CourierTask
	_tasks_by_courier_id.erase(courier_id)
	if task != null and tasks.get(task.id) == task:
		tasks.erase(task.id)


## Ends an interrupted assignment without completing its underlying request. The
## producer-specific cancellation callback restores cargo or reservations, then a
## still-valid task becomes available for the next courier immediately.
func cancel_for(courier: Citizen) -> void:
	if not is_instance_valid(courier):
		return
	var task := task_for(courier)
	if task == null:
		return
	_cancel_task.call(courier, task)
	_tasks_by_courier_id.erase(courier.ai_id)
	task.assigned_courier_ai_id = 0
	if task.has_reservation():
		_release_reservation.call(task)
	if not _is_task_valid.call(task):
		tasks.erase(task.id)


func _cleanup_invalid_tasks() -> void:
	for id: StringName in tasks.keys():
		var task: CourierTask = tasks[id]
		if task.is_assigned():
			var courier := _courier_for_ai_id(task.assigned_courier_ai_id)
			if is_instance_valid(courier) and courier.has_active_delivery():
				continue
			if is_instance_valid(courier):
				cancel_for(courier)
			else:
				_tasks_by_courier_id.erase(task.assigned_courier_ai_id)
				task.assigned_courier_ai_id = 0
				if task.has_reservation():
					_release_reservation.call(task)
		if not _is_task_valid.call(task):
			_tasks_by_courier_id.erase(task.assigned_courier_ai_id)
			tasks.erase(id)


func _courier_for_ai_id(citizen_id: int) -> Citizen:
	if citizen_id <= 0:
		return null
	for candidate in _citizens:
		if is_instance_valid(candidate) and candidate.ai_id == citizen_id:
			return candidate
	return null
