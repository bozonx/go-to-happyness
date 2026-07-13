class_name CourierDispatcher
extends RefCounted

const CourierTaskScript = preload("res://game/features/logistics/domain/courier_task.gd")

## Single entry point for courier scheduling. Task producers may still keep
## their domain-specific reservation rules while migration to CourierTask is
## in progress, but only this dispatcher starts the scheduling pass.

var simulation: Node
var tasks: Dictionary = {}


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func dispatch() -> void:
	if simulation == null or not simulation._is_work_time():
		return
	simulation._publish_courier_tasks(self)
	_cleanup_invalid_tasks()
	var available := _available_couriers()
	var ordered := tasks.values()
	ordered.sort_custom(func(a: CourierTask, b: CourierTask):
		if a.priority != b.priority:
			return a.priority > b.priority
		return a.created_at < b.created_at
	)
	for task: CourierTask in ordered:
		if task.is_assigned() or available.is_empty():
			continue
		var courier := _nearest_courier(available, task.pickup)
		if courier == null:
			continue
		if simulation._start_courier_task(courier, task):
			task.assigned_courier_id = courier.get_instance_id()
			available.erase(courier)


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
	for task: CourierTask in tasks.values():
		if task.assigned_courier_id == courier.get_instance_id():
			tasks.erase(task.id)
			return


func _available_couriers() -> Array[Citizen]:
	var pinned: Array[Citizen] = []
	var flexible: Array[Citizen] = []
	for citizen in simulation.citizens:
		if not citizen.is_reserve() or citizen.state != Citizen.State.IDLE:
			continue
		if citizen.freelance_assignment == "courier":
			pinned.append(citizen)
		elif citizen.freelance_assignment.is_empty() and citizen.can_recheck_automatic_role():
			flexible.append(citizen)
	return pinned if not pinned.is_empty() else flexible


func _nearest_courier(couriers: Array[Citizen], pickup: Vector3) -> Citizen:
	var best: Citizen = null
	var distance := INF
	for courier in couriers:
		var candidate_distance := courier.global_position.distance_squared_to(pickup)
		if candidate_distance < distance:
			best = courier
			distance = candidate_distance
	return best


func _cleanup_invalid_tasks() -> void:
	for id: StringName in tasks.keys():
		var task: CourierTask = tasks[id]
		if task.is_assigned():
			var courier := instance_from_id(task.assigned_courier_id) as Citizen
			if is_instance_valid(courier) and courier.has_active_delivery():
				continue
			task.assigned_courier_id = -1
		if not simulation._is_courier_task_valid(task):
			tasks.erase(id)
