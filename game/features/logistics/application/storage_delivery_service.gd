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
	var storage_status: int = simulation.settlement.storage_availability_for(resource_type, amount, simulation.warehouse_positions.size())
	if storage_status != SettlementState.StorageAvailability.OK:
		# Cargo already in transit must never disappear or silently overflow the
		# warehouse allocation. Leave it on the ground at the delivery point so a
		# courier can recover it after the player makes room.
		if simulation.has_method("_drop_resource_pile"):
			simulation._drop_resource_pile(_drop_position(worker), resource_type, amount)
		worker.storage_delivery_result(true)
		simulation._update_interface(_drop_message(storage_status, amount, resource_type))
		simulation._request_courier_dispatch()
		return
	simulation.settlement.reserve_storage_room_for(resource_type, amount, simulation.warehouse_positions.size())
	simulation.settlement.add(resource_type, amount)
	_finish_storage_delivery(worker, resource_type, storage_status)
	simulation._update_interface("Workers delivered %d %s to the warehouse." % [amount, resource_type])
	simulation._request_courier_dispatch()


func _finish_storage_delivery(worker: Citizen, resource_type: String, storage_status := SettlementState.StorageAvailability.OK) -> void:
	if storage_status == SettlementState.StorageAvailability.NO_WAREHOUSE:
		worker.storage_delivery_result(false, CitizenStatusEffectScript.STORAGE_NO_WAREHOUSE)
		return
	if simulation.settlement.can_make_room_for(resource_type, 1, simulation.warehouse_positions.size()):
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
