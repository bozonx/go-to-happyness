class_name StorageDeliveryService
extends RefCounted

const CitizenStatusEffectScript = preload("res://game/features/citizens/domain/citizen_status_effect.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func on_resource_delivered(worker: Citizen, resource_type: String, amount: int) -> void:
	if simulation == null:
		return
	var task: RefCounted = simulation.courier_dispatcher.task_for(worker)
	var reserved_index := -1
	var reserved_amount := 0
	if task != null and task.has_reservation():
		if task.reserved_resource_type == resource_type:
			reserved_index = task.reserved_warehouse_index
			reserved_amount = task.reserved_amount
		else:
			simulation._release_task_warehouse_reservation(task)
	simulation.courier_dispatcher.complete_for(worker)
	var worker_position: Vector3 = worker.global_position if worker.is_inside_tree() else worker.position
	var warehouse_index: int = reserved_index if reserved_index >= 0 else _warehouse_index(worker_position, resource_type, amount)
	if warehouse_index < 0:
		if simulation.has_method("_drop_resource_pile"):
			simulation._drop_resource_pile(_drop_position(worker), resource_type, amount)
		if simulation.warehouse_positions.is_empty():
			simulation._update_interface("No warehouse for %d %s; the worker left it in a ground pile." % [amount, resource_type])
		else:
			simulation._update_interface("No warehouse room for %d %s; the worker left it in a ground pile." % [amount, resource_type])
		worker.storage_delivery_result(true)
		if simulation.has_method("_release_task_warehouse_reservation") and task != null:
			simulation._release_task_warehouse_reservation(task)
		simulation._request_courier_dispatch()
		return
	# If the task had a reservation, release any unused portion before adding.
	if reserved_index >= 0 and reserved_amount > amount:
		simulation.settlement.release_warehouse_reservation(reserved_index, resource_type, reserved_amount - amount)
	var overflow: int = simulation.settlement.add_to_warehouse(resource_type, amount, warehouse_index)
	if overflow > 0 and simulation.has_method("_drop_resource_pile"):
		simulation._drop_resource_pile(_drop_position(worker), resource_type, overflow)
	_finish_storage_delivery(worker, resource_type)
	simulation._update_interface("Workers delivered %d %s to the warehouse." % [amount - overflow, resource_type])
	simulation._request_courier_dispatch()


func _finish_storage_delivery(worker: Citizen, resource_type: String, _storage_status := SettlementState.StorageAvailability.OK) -> void:
	if simulation.warehouse_positions.is_empty():
		worker.storage_delivery_result(false, CitizenStatusEffectScript.STORAGE_NO_WAREHOUSE)
		return
	var worker_position: Vector3 = worker.global_position if worker.is_inside_tree() else worker.position
	var next_index: int = _warehouse_index(worker_position, resource_type, 1)
	if next_index >= 0:
		worker.storage_delivery_result(true)
		return
	worker.idle()
	simulation._send_citizen_to_leisure(worker)


func _drop_message(storage_status: int, amount: int, resource_type: String) -> String:
	if storage_status == SettlementState.StorageAvailability.NO_WAREHOUSE:
		return "No warehouse for %d %s; the worker left it in a ground pile." % [amount, resource_type]
	return "No warehouse room for %d %s; the worker left it in a ground pile." % [amount, resource_type]


func _drop_position(worker: Citizen) -> Vector3:
	return worker.global_position if worker.is_inside_tree() else worker.position


func _warehouse_index(from: Vector3, resource_type: String, amount: int) -> int:
	if simulation.has_method(&"_find_reachable_warehouse_index"):
		return simulation._find_reachable_warehouse_index(from, resource_type, amount)
	return simulation.settlement.find_warehouse_index(from, resource_type, amount, simulation.warehouse_positions)
