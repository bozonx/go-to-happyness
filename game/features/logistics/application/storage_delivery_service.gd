class_name StorageDeliveryService
extends RefCounted

const CitizenStatusEffectScript = preload("res://game/features/citizens/domain/citizen_status_effect.gd")

var _settlement: SettlementState
var _warehouse_positions: Array[Vector3] = []
var _courier_dispatcher: Variant
var _storage_routing: Variant
var _release_reservation: Callable
var _drop_resource_pile: Callable
var _update_interface: Callable
var _request_courier_dispatch: Callable
var _send_citizen_to_leisure: Callable


func configure(
	p_settlement: SettlementState,
	p_warehouse_positions: Array[Vector3],
	p_courier_dispatcher: Variant,
	p_storage_routing: Variant,
	p_release_reservation: Callable,
	p_drop_resource_pile: Callable,
	p_update_interface: Callable,
	p_request_courier_dispatch: Callable,
	p_send_citizen_to_leisure: Callable
) -> void:
	_settlement = p_settlement
	_warehouse_positions = p_warehouse_positions
	_courier_dispatcher = p_courier_dispatcher
	_storage_routing = p_storage_routing
	_release_reservation = p_release_reservation
	_drop_resource_pile = p_drop_resource_pile
	_update_interface = p_update_interface
	_request_courier_dispatch = p_request_courier_dispatch
	_send_citizen_to_leisure = p_send_citizen_to_leisure


func on_resource_delivered(worker: Citizen, resource_type: String, amount: int) -> void:
	var task: RefCounted = _courier_dispatcher.task_for(worker)
	var reserved_index := -1
	var reserved_amount := 0
	if task != null and task.has_reservation():
		if task.reserved_resource_type == resource_type:
			reserved_index = task.reserved_warehouse_index
			reserved_amount = task.reserved_amount
		else:
			_release_reservation.call(task)
	_courier_dispatcher.complete_for(worker)
	var warehouse_index: int = reserved_index if reserved_index >= 0 else _storage_routing.find_reachable_warehouse_index(_drop_position(worker), resource_type, amount)
	if warehouse_index < 0:
		_drop_resource_pile.call(_drop_position(worker), resource_type, amount)
		if _warehouse_positions.is_empty():
			_update_interface.call("No warehouse for %d %s; the worker left it in a ground pile." % [amount, resource_type])
		else:
			_update_interface.call("No warehouse room for %d %s; the worker left it in a ground pile." % [amount, resource_type])
		worker.storage_delivery_result(true)
		if task != null:
			_release_reservation.call(task)
		_request_courier_dispatch.call()
		return
	# If the task had a reservation, release any unused portion before adding.
	if reserved_index >= 0 and reserved_amount > amount:
		_settlement.release_warehouse_reservation(reserved_index, resource_type, reserved_amount - amount)
	var overflow: int = _settlement.add_to_warehouse(resource_type, amount, warehouse_index)
	if overflow > 0:
		_drop_resource_pile.call(_drop_position(worker), resource_type, overflow)
	_finish_storage_delivery(worker, resource_type)
	_update_interface.call("Workers delivered %d %s to the warehouse." % [amount - overflow, resource_type])
	_request_courier_dispatch.call()


func _finish_storage_delivery(worker: Citizen, resource_type: String, _storage_status := SettlementState.StorageAvailability.OK) -> void:
	if _warehouse_positions.is_empty():
		worker.storage_delivery_result(false, CitizenStatusEffectScript.STORAGE_NO_WAREHOUSE)
		return
	var next_index: int = _storage_routing.find_reachable_warehouse_index(_drop_position(worker), resource_type, 1)
	if next_index >= 0:
		worker.storage_delivery_result(true)
		return
	worker.idle()
	_send_citizen_to_leisure.call(worker)


func _drop_position(worker: Citizen) -> Vector3:
	return worker.global_position if worker.is_inside_tree() else worker.position
