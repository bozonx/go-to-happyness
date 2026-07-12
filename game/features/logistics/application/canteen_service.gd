class_name CanteenService
extends RefCounted

var simulation: Node


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
		if citizen.is_available_for_schedule():
			citizen.request_goap_meal()
	simulation._update_interface("%02d:00 meal service started. Residents are heading to the canteen." % hour)


func update_canteen_delivery() -> void:
	if simulation.pending_canteen_delivery:
		if not is_instance_valid(simulation.pending_canteen_carrier) or simulation.pending_canteen_carrier.state not in [Citizen.State.TO_FOOD_PICKUP, Citizen.State.TO_CANTEEN_DELIVERY]:
			cancel_canteen_delivery()
		else:
			return
	if not is_instance_valid(simulation.canteen) or simulation.warehouse_positions.is_empty() or simulation.food <= 0:
		return
	var capacity := BuildingCatalog.kitchen_food_capacity(str(simulation.canteen.get_meta("building_type", "")))
	if capacity <= 0 or simulation.canteen_food >= capacity:
		return
	var carrier: Citizen = null
	for citizen in simulation.citizens:
		if citizen.employment_state == Citizen.EmploymentState.FREELANCE and citizen.freelance_assignment == "courier" and citizen.state == Citizen.State.IDLE:
			carrier = citizen
			break
	if carrier == null:
		for citizen in simulation.citizens:
			if citizen.specialization == "cook" and citizen.state == Citizen.State.IDLE:
				carrier = citizen
				break
	if carrier == null:
		return
	var amount: int = mini(4, mini(simulation.food, capacity - simulation.canteen_food))
	simulation.food -= amount
	simulation.pending_canteen_delivery = true
	simulation.pending_canteen_carrier = carrier
	simulation.pending_canteen_delivery_amount = amount
	carrier.deliver_food_to_canteen(simulation.warehouse_positions[0], simulation.canteen_position, amount)


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
	citizen.finish_goap_meal()
	if not served:
		simulation._update_interface("Canteen ran out of food. A worker missed their meal.")
	if simulation._is_work_time():
		simulation._update_workers()
