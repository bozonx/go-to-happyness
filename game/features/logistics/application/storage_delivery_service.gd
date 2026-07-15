class_name StorageDeliveryService
extends RefCounted

const CitizenStatusEffectScript = preload("res://game/features/citizens/domain/citizen_status_effect.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func on_resource_delivered(worker: Citizen, resource_type: String, amount: int) -> void:
	if simulation == null:
		return
	simulation.courier_dispatcher.complete_for(worker)
	var worker_position: Vector3 = worker.global_position if worker.is_inside_tree() else worker.position
	var warehouse_index: int = simulation.settlement.find_warehouse_index(worker_position, resource_type, amount, simulation.warehouse_positions)
	if warehouse_index < 0:
		if simulation.has_method("_drop_resource_pile"):
			simulation._drop_resource_pile(_drop_position(worker), resource_type, amount)
		if simulation.warehouse_positions.is_empty():
			simulation._update_interface("No warehouse for %d %s; the worker left it in a ground pile." % [amount, resource_type])
		else:
			simulation._update_interface("No warehouse room for %d %s; the worker left it in a ground pile." % [amount, resource_type])
		worker.storage_delivery_result(true)
		simulation._request_courier_dispatch()
		return
	if not simulation.settlement.reserve_warehouse_room(warehouse_index, resource_type, amount):
		if simulation.has_method("_drop_resource_pile"):
			simulation._drop_resource_pile(_drop_position(worker), resource_type, amount)
		worker.storage_delivery_result(true)
		simulation._update_interface("No warehouse room for %d %s; the worker left it in a ground pile." % [amount, resource_type])
		simulation._request_courier_dispatch()
		return
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
	var next_index: int = simulation.settlement.find_warehouse_index(worker_position, resource_type, 1, simulation.warehouse_positions)
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
