class_name CitizenLifecycleService
extends RefCounted

## Manages citizen lifecycle: spawning house citizens, arrival greeter
## selection, arrival update loop, greeter-ready callback, interrupted
## arrival requeueing, arrival cancellation, unhoused settlement,
## citizen departure cleanup, and unemployment registration.

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func on_citizen_leaving_departed(citizen: Citizen) -> void:
	if not is_instance_valid(citizen):
		return
	simulation.citizens.erase(citizen)
	if simulation.citizen_ai != null:
		simulation.citizen_ai.unregister_citizen(citizen.ai_id)
	if simulation.canteen_service != null:
		simulation.canteen_service.remove_citizen(citizen.ai_id)
	if simulation.citizen_needs_service != null:
		simulation.citizen_needs_service.remove_citizen(citizen.ai_id)
	citizen.queue_free()


func spawn_house_citizen() -> void:
	if simulation.selected_house == null or bool(simulation.selected_house.get_meta("pending_demolition", false)):
		return
	var slots: int = simulation.selected_house.get_meta("spawn_slots", 0)
	if slots <= 0:
		return
	var is_tent: bool = simulation.selected_house.has_meta("is_tent")
	if is_tent:
		if int(simulation.selected_house.get_meta("tent_order_day", -1)) == simulation.day_cycle.current_day:
			return
		simulation.selected_house.set_meta("tent_order_day", simulation.day_cycle.current_day)
	elif unhoused_citizen_count() > 0:
		return
	simulation.selected_house.set_meta("spawn_slots", slots - 1)
	simulation._show_house_menu()
	simulation.pending_arrivals.append({"house": simulation.selected_house})
	update_arrivals()
	simulation._update_interface("A resident is expected at the entrance sign. Assign a Courier to meet them.")


func find_arrival_greeter(allow_busy := false) -> Citizen:
	var best: Citizen = null
	var best_score := INF
	for citizen in simulation.citizens:
		if citizen.is_player_controlled or not citizen.can_handle_entry_logistics():
			continue
		if citizen.has_active_arrival_task() or citizen.pending_arrival_entrance != Vector3.INF:
			continue
		var is_free: bool = citizen.state in [Citizen.State.IDLE, Citizen.State.RESTING]
		if not is_free and not allow_busy:
			continue
		if not is_free and citizen.has_active_delivery():
			continue
		var score: float = citizen.global_position.distance_to(simulation.entrance_stone.global_position)
		if not is_free:
			score += citizen.task_timer.remaining * Citizen.WALK_SPEED
		if score < best_score:
			best = citizen
			best_score = score
	return best


func update_arrivals() -> void:
	if not is_instance_valid(simulation.entrance_stone):
		return
	requeue_interrupted_arrivals()
	if simulation._is_work_time():
		for citizen in simulation.citizens:
			if citizen.state != Citizen.State.ARRIVAL_WAITING:
				continue
			if simulation.arrival_escort_ids.has(citizen.ai_id):
				citizen.escort_arrivals_to(simulation._employment_center_position())
				simulation.arrival_escort_ids.erase(citizen.ai_id)
			else:
				if simulation._employment_center_position() != Vector3.INF:
					citizen.begin_employment_processing(simulation._employment_center_position())
				else:
					citizen.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
					citizen.idle()
	for greeter_id in simulation.arrival_waiting_greeters.keys():
		var waiting_greeter := simulation._citizen_for_ai_id(int(greeter_id))
		var waiting_order: Dictionary = simulation.arrival_waiting_greeters[greeter_id]
		if not is_instance_valid(waiting_greeter) or not waiting_greeter.can_handle_entry_logistics():
			simulation.arrival_waiting_greeters.erase(greeter_id)
			requeue_arrival_order(waiting_order)
			continue
		if waiting_greeter.has_active_arrival_task():
			simulation.arrival_waiting_greeters.erase(greeter_id)
			simulation.arrival_greeters[greeter_id] = waiting_order
			continue
		if waiting_greeter.state in [Citizen.State.IDLE, Citizen.State.RESTING]:
			waiting_greeter.go_to_arrival_entrance(simulation.entrance_stone.global_position)
			simulation.arrival_waiting_greeters.erase(greeter_id)
			simulation.arrival_greeters[greeter_id] = waiting_order
	simulation._request_courier_dispatch()


func on_arrival_greeter_ready(greeter: Citizen) -> void:
	var order: Dictionary = simulation.arrival_greeters.get(greeter.ai_id, {})
	simulation.arrival_greeters.erase(greeter.ai_id)
	simulation.courier_dispatcher.complete_for(greeter)
	if order.is_empty():
		greeter.idle()
		return
	simulation.pending_arrivals.erase(order)
	var house: Node3D = order.get("house") as Node3D
	if not is_instance_valid(house) or bool(house.get_meta("pending_demolition", false)):
		greeter.idle()
		simulation._update_interface("Arrival cancelled because its assigned home is being demolished.")
		return
	var spawn_position: Vector3 = simulation.entrance_stone.global_position + Vector3(0.55, 0.08, 0.55)
	var terrain_height: float = simulation._terrain_height_at(spawn_position.x, spawn_position.z, spawn_position.y)
	if not is_nan(terrain_height):
		spawn_position.y = terrain_height + 0.08
	simulation._add_citizen(spawn_position, "unassigned")
	var newcomer: Citizen = simulation.citizens.back()
	newcomer.assign_home(house)
	simulation._refresh_living_status(newcomer)
	if simulation._is_work_time():
		var centre: Vector3 = simulation._employment_center_position()
		if centre != Vector3.INF:
			greeter.escort_arrivals_to(centre)
			newcomer.begin_employment_processing(centre)
			simulation._update_interface("The newcomer was met at the entrance and is heading to employment registration.")
		else:
			greeter.idle()
			newcomer.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
			newcomer.idle()
			simulation._update_interface("The newcomer joined the settlement without a permanent job.")
	else:
		simulation.arrival_escort_ids[greeter.ai_id] = true
		greeter.wait_for_arrival_morning()
		newcomer.wait_for_arrival_morning()
		simulation._update_interface("The newcomer and greeter are waiting at the entrance for the workday.")
	simulation._show_house_menu()


func requeue_interrupted_arrivals() -> void:
	for greeter_id in simulation.arrival_waiting_greeters.keys():
		var waiting_greeter := simulation._citizen_for_ai_id(int(greeter_id))
		if is_instance_valid(waiting_greeter) and waiting_greeter.has_active_arrival_task():
			simulation.arrival_greeters[greeter_id] = simulation.arrival_waiting_greeters[greeter_id]
			simulation.arrival_waiting_greeters.erase(greeter_id)
			continue
		if is_instance_valid(waiting_greeter) and waiting_greeter.pending_arrival_entrance != Vector3.INF:
			continue
		var waiting_order: Dictionary = simulation.arrival_waiting_greeters[greeter_id]
		simulation.arrival_waiting_greeters.erase(greeter_id)
		requeue_arrival_order(waiting_order)
	for greeter_id in simulation.arrival_greeters.keys():
		var greeter: Citizen = simulation._citizen_for_ai_id(int(greeter_id))
		if is_instance_valid(greeter) and greeter.has_active_arrival_task():
			continue
		var order: Dictionary = simulation.arrival_greeters[greeter_id]
		simulation.arrival_greeters.erase(greeter_id)
		requeue_arrival_order(order)


func requeue_arrival_order(order: Dictionary) -> void:
	for index in simulation.pending_arrivals.size():
		if simulation.pending_arrivals[index] == order:
			order.dispatched = false
			order.erase("greeter_id")
			simulation.pending_arrivals[index] = order
			return


func cancel_arrivals_for_house(house: Node3D) -> void:
	var cancelled := false
	for index in range(simulation.pending_arrivals.size() - 1, -1, -1):
		var order: Dictionary = simulation.pending_arrivals[index]
		if order.get("house") != house:
			continue
		var greeter_id: int = int(order.get("greeter_id", -1))
		if greeter_id >= 0:
			simulation.arrival_greeters.erase(greeter_id)
			simulation.arrival_waiting_greeters.erase(greeter_id)
			var greeter: Citizen = simulation._citizen_for_ai_id(greeter_id)
			if is_instance_valid(greeter):
				greeter.pending_arrival_entrance = Vector3.INF
				if greeter.has_active_arrival_task():
					greeter.idle()
		simulation.pending_arrivals.remove_at(index)
		cancelled = true
	if cancelled:
		simulation._update_interface("Pending arrival cancelled because its assigned home is being demolished.")


func settle_unhoused_resident() -> void:
	if simulation.selected_house == null or bool(simulation.selected_house.get_meta("pending_demolition", false)):
		return
	var slots: int = simulation.selected_house.get_meta("spawn_slots", 0)
	if slots <= 0:
		return
	for citizen in simulation.citizens:
		if is_instance_valid(citizen.home):
			continue
		citizen.assign_home(simulation.selected_house)
		simulation._refresh_living_status(citizen)
		simulation.selected_house.set_meta("spawn_slots", slots - 1)
		simulation._update_interface("%s has been settled in this home." % citizen.role_label())
		simulation._show_house_menu()
		return


func unhoused_citizen_count() -> int:
	var count := 0
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen.home):
			count += 1
	return count


func house_initial_residents(house: Node3D) -> void:
	if not house.has_meta("is_tent"):
		return
	var slots: int = int(house.get_meta("spawn_slots", 0))
	for citizen in simulation.citizens:
		if slots <= 0:
			break
		if not is_instance_valid(citizen.home):
			citizen.assign_home(house)
			simulation._refresh_living_status(citizen)
			slots -= 1
	house.set_meta("spawn_slots", slots)


func send_to_unemployment_registration(citizen: Citizen) -> void:
	if citizen.is_player_controlled:
		return
	if simulation.citizen_ai != null:
		simulation.citizen_ai.cancel_citizen_work(citizen.ai_id)
	citizen.idle()
	citizen.permanent_role = ""
	citizen.pending_employment_role = ""
	citizen.employment_workplace = null
	citizen.pending_employment_workplace = null
	citizen.release_to_no_permanent_work()
