class_name CanteenService
extends RefCounted

const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var _settlement: SettlementState
var _citizens: Array = []
var _canteen_getter: Callable
var _canteen_food_getter: Callable
var _set_canteen_food: Callable
var _canteen_position_getter: Callable
var _pending_canteen_delivery_getter: Callable
var _pending_canteen_carrier_getter: Callable
var _pending_canteen_delivery_amount_getter: Callable
var _set_canteen_delivery_state: Callable
var _is_canteen_delivery_in_progress: Callable
var _is_fire_lit: Callable
var _has_cook: Callable
var _update_interface: Callable
var _request_courier_dispatch: Callable
var _is_work_time: Callable
var _update_workers: Callable
var _meal_requests: Dictionary = {}

# Whether the current meal is cooked. Set when start_meal() runs and used by
# on_meal_finished() to apply the correct nutritional effect.
var _current_meal_cooked: bool = false


func configure(
	p_settlement: SettlementState,
	p_citizens: Array,
	p_canteen_getter: Callable,
	p_canteen_food_getter: Callable,
	p_set_canteen_food: Callable,
	p_canteen_position_getter: Callable,
	p_pending_canteen_delivery_getter: Callable,
	p_pending_canteen_carrier_getter: Callable,
	p_pending_canteen_delivery_amount_getter: Callable,
	p_set_canteen_delivery_state: Callable,
	p_is_canteen_delivery_in_progress: Callable,
	p_is_fire_lit: Callable,
	p_has_cook: Callable,
	p_update_interface: Callable,
	p_request_courier_dispatch: Callable,
	p_is_work_time: Callable,
	p_update_workers: Callable
) -> void:
	_settlement = p_settlement
	_citizens = p_citizens
	_canteen_getter = p_canteen_getter
	_canteen_food_getter = p_canteen_food_getter
	_set_canteen_food = p_set_canteen_food
	_canteen_position_getter = p_canteen_position_getter
	_pending_canteen_delivery_getter = p_pending_canteen_delivery_getter
	_pending_canteen_carrier_getter = p_pending_canteen_carrier_getter
	_pending_canteen_delivery_amount_getter = p_pending_canteen_delivery_amount_getter
	_set_canteen_delivery_state = p_set_canteen_delivery_state
	_is_canteen_delivery_in_progress = p_is_canteen_delivery_in_progress
	_is_fire_lit = p_is_fire_lit
	_has_cook = p_has_cook
	_update_interface = p_update_interface
	_request_courier_dispatch = p_request_courier_dispatch
	_is_work_time = p_is_work_time
	_update_workers = p_update_workers


func start_meal(hour: int) -> void:
	var canteen: Node3D = _canteen_getter.call()
	var has_canteen := is_instance_valid(canteen)
	if not has_canteen:
		# No kitchen/cooking campfire yet: residents eat raw rations straight from
		# the backpack or warehouse. Food is consumed by the daily survival update.
		for citizen in _citizens:
			if not citizen.is_player_controlled:
				citizen.receive_meal(true, false, true)
		_update_interface.call("%02d:00 meal: raw rations from stores." % hour)
		return

	var fire_lit: bool = _is_fire_lit.call(canteen)
	var has_cook: bool = _has_cook.call()
	_current_meal_cooked = fire_lit and has_cook

	for citizen in _citizens:
		# The cook keeps the canteen staffed during the lunch service and receives
		# their park break after the rush.
		var is_cook: bool = citizen.specialization == "cook" or (citizen.daily_order_role == "cook" and citizen.has_active_daily_order())
		if is_cook and hour == 13:
			continue
		if citizen.ai_id > 0 and citizen.is_available_for_schedule():
			_meal_requests[citizen.ai_id] = true
	if _current_meal_cooked:
		_update_interface.call("%02d:00 meal service started. Residents are heading to the canteen." % hour)
	else:
		_update_interface.call("%02d:00 meal started. No cook or fire is out; residents will eat raw rations." % hour)


func update_canteen_delivery() -> void:
	if _pending_canteen_delivery_getter.call():
		if not _is_canteen_delivery_in_progress.call():
			cancel_canteen_delivery()
		else:
			return
	_request_courier_dispatch.call()


func cancel_canteen_delivery() -> void:
	_settlement.add(ResourceIds.FOOD, _pending_canteen_delivery_amount_getter.call())
	_set_canteen_delivery_state.call(false, null, 0)
	_update_interface.call("Canteen delivery was interrupted; food returned to the warehouse.")


func on_canteen_delivery_finished(worker: Citizen, amount: int) -> void:
	if not _pending_canteen_delivery_getter.call() or worker != _pending_canteen_carrier_getter.call() or amount != _pending_canteen_delivery_amount_getter.call():
		return
	var canteen_food: int = _canteen_food_getter.call()
	_set_canteen_food.call(canteen_food + amount)
	_set_canteen_delivery_state.call(false, null, 0)
	var is_cook: bool = worker.specialization == "cook" or (worker.daily_order_role == "cook" and worker.has_active_daily_order())
	if is_cook:
		worker.assign_canteen_work(_canteen_position_getter.call())
	_update_interface.call("Canteen received %d food. Stock: %d." % [amount, _canteen_food_getter.call()])


func on_meal_finished(citizen: Citizen) -> void:
	var served: bool = is_instance_valid(_canteen_getter.call()) and _canteen_food_getter.call() > 0
	if served:
		_set_canteen_food.call(_canteen_food_getter.call() - 1)
	citizen.receive_meal(served, _current_meal_cooked, true)
	_meal_requests.erase(citizen.ai_id)
	if not served:
		_update_interface.call("Canteen ran out of food. A worker missed their meal.")
	if _is_work_time.call():
		_update_workers.call()


func is_meal_requested(citizen_id: int) -> bool:
	return _meal_requests.has(citizen_id)


func remove_citizen(citizen_id: int) -> void:
	_meal_requests.erase(citizen_id)
