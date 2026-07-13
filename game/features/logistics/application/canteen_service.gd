class_name CanteenService
extends RefCounted

var simulation: Node
var _meal_requests: Dictionary = {}


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func start_meal(hour: int) -> void:
	if not is_instance_valid(simulation.canteen) or not simulation._is_fire_lit(simulation.canteen):
		for citizen in simulation.citizens:
			if not citizen.is_player_controlled:
				citizen.receive_meal(false)
		simulation._update_interface("%02d:00 meal missed: no canteen." % hour)
		return
	if not simulation._has_cook():
		for citizen in simulation.citizens:
			if not citizen.is_player_controlled:
				citizen.receive_meal(false)
		simulation._update_interface("%02d:00 meal missed: the canteen needs a cook." % hour)
		return
	for citizen in simulation.citizens:
		# The cook keeps the canteen staffed during the lunch service and receives
		# their park break after the rush.
		if citizen.specialization == "cook" and hour == 13:
			continue
		if citizen.ai_id > 0 and citizen.is_available_for_schedule():
			_meal_requests[citizen.ai_id] = true
	simulation._update_interface("%02d:00 meal service started. Residents are heading to the canteen." % hour)


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
	simulation.food += simulation.pending_canteen_delivery_amount
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
	if worker.specialization == "cook":
		worker.assign_canteen_work(simulation.canteen_position)
	simulation._update_interface("Canteen received %d food. Stock: %d." % [amount, simulation.canteen_food])


func on_meal_finished(citizen: Citizen) -> void:
	var served: bool = is_instance_valid(simulation.canteen) and simulation._has_cook() and simulation.canteen_food > 0
	if served:
		simulation.canteen_food -= 1
	citizen.receive_meal(served)
	_meal_requests.erase(citizen.ai_id)
	if not served:
		simulation._update_interface("Canteen ran out of food. A worker missed their meal.")
	if simulation._is_work_time():
		simulation._update_workers()


func is_meal_requested(citizen_id: int) -> bool:
	return _meal_requests.has(citizen_id)


func remove_citizen(citizen_id: int) -> void:
	_meal_requests.erase(citizen_id)
