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
		# Cargo already in transit must never disappear. It may temporarily exceed
		# the allocation; scheduling prevents new production until room is freed.
		simulation.settlement.add(resource_type, amount)
		_finish_storage_delivery(worker, resource_type, storage_status)
		simulation._update_interface(_pause_message(storage_status, amount, resource_type))
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


func _pause_message(storage_status: int, amount: int, resource_type: String) -> String:
	if storage_status == SettlementState.StorageAvailability.NO_WAREHOUSE:
		return "Workers delivered %d %s without warehouse storage. New collection is paused." % [amount, resource_type]
	return "Workers delivered %d %s over the storage limit. New collection is paused." % [amount, resource_type]
