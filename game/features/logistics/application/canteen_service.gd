class_name CanteenService
extends RefCounted

const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var simulation: Node
var _meal_requests: Dictionary = {}

# Whether the current meal is cooked. Set when start_meal() runs and used by
# on_meal_finished() to apply the correct nutritional effect.
var _current_meal_cooked: bool = false


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func start_meal(hour: int) -> void:
	var has_canteen := is_instance_valid(simulation.canteen)
	if not has_canteen:
		# No kitchen/cooking campfire yet: residents eat raw rations straight from
		# the backpack or warehouse. Food is consumed by the daily survival update.
		for citizen in simulation.citizens:
			if not citizen.is_player_controlled:
				citizen.receive_meal(true, false, true)
		simulation._update_interface("%02d:00 meal: raw rations from stores." % hour)
		return

	var fire_lit: bool = simulation._is_fire_lit(simulation.canteen)
	var has_cook: bool = simulation._has_cook()
	_current_meal_cooked = fire_lit and has_cook

	for citizen in simulation.citizens:
		# The cook keeps the canteen staffed during the lunch service and receives
		# their park break after the rush.
		var is_cook: bool = citizen.specialization == "cook" or (citizen.daily_order_role == "cook" and citizen.has_active_daily_order())
		if is_cook and hour == 13:
			continue
		if citizen.ai_id > 0 and citizen.is_available_for_schedule():
			_meal_requests[citizen.ai_id] = true
	if _current_meal_cooked:
		simulation._update_interface("%02d:00 meal service started. Residents are heading to the canteen." % hour)
	else:
		simulation._update_interface("%02d:00 meal started. No cook or fire is out; residents will eat raw rations." % hour)


func update_canteen_delivery() -> void:
	if simulation.pending_canteen_delivery:
		if not is_instance_valid(simulation.pending_canteen_carrier) or simulation.pending_canteen_carrier.state not in [Citizen.State.TO_FOOD_PICKUP, Citizen.State.TO_CANTEEN_DELIVERY]:
			cancel_canteen_delivery()
		else:
			return
	# Publishing and assignment are owned by CourierDispatcher. This service only
	# validates an in-flight delivery and applies its result.
	simulation._request_courier_dispatch()


func cancel_canteen_delivery() -> void:
	simulation.settlement.add(ResourceIds.FOOD, simulation.pending_canteen_delivery_amount)
	simulation.pending_canteen_delivery = false
	simulation.pending_canteen_carrier = null
	simulation.pending_canteen_delivery_amount = 0
	simulation._update_interface("Canteen delivery was interrupted; food returned to the warehouse.")


func on_canteen_delivery_finished(worker: Citizen, amount: int) -> void:
	if not simulation.pending_canteen_delivery or worker != simulation.pending_canteen_carrier or amount != simulation.pending_canteen_delivery_amount:
		return
	simulation.canteen_food += amount
	simulation.pending_canteen_delivery = false
	simulation.pending_canteen_carrier = null
	simulation.pending_canteen_delivery_amount = 0
	var is_cook: bool = worker.specialization == "cook" or (worker.daily_order_role == "cook" and worker.has_active_daily_order())
	if is_cook:
		worker.assign_canteen_work(simulation.canteen_position)
	simulation._update_interface("Canteen received %d food. Stock: %d." % [amount, simulation.canteen_food])


func on_meal_finished(citizen: Citizen) -> void:
	var served: bool = is_instance_valid(simulation.canteen) and simulation.canteen_food > 0
	if served:
		simulation.canteen_food -= 1
	citizen.receive_meal(served, _current_meal_cooked, true)
	_meal_requests.erase(citizen.ai_id)
	if not served:
		simulation._update_interface("Canteen ran out of food. A worker missed their meal.")
	if simulation._is_work_time():
		simulation._update_workers()


func is_meal_requested(citizen_id: int) -> bool:
	return _meal_requests.has(citizen_id)


func remove_citizen(citizen_id: int) -> void:
	_meal_requests.erase(citizen_id)
