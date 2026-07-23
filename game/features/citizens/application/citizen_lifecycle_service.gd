class_name CitizenLifecycleService
extends RefCounted

## Manages citizen lifecycle: spawning house citizens, arrival greeter
## selection, arrival update loop, greeter-ready callback, interrupted
## arrival requeueing, arrival cancellation, unhoused settlement,
## citizen departure cleanup, and unemployment registration.

var _citizens: Array = []
var _pending_arrivals: Array = []
var _arrival_greeters: Dictionary = {}
var _arrival_waiting_greeters: Dictionary = {}
var _arrival_escort_ids: Dictionary = {}
var _entrance_stone_getter: Callable
var _entrance_anchor_position: Callable
var _employment_center_position: Callable
var _is_work_time: Callable
var _update_interface: Callable
var _show_house_menu: Callable
var _add_citizen: Callable
var _refresh_living_status: Callable
var _request_courier_dispatch: Callable
var _citizen_for_ai_id: Callable
var _terrain_height_at: Callable
var _citizen_ai_unregister: Callable
var _citizen_ai_cancel_work: Callable
var _canteen_service_remove_citizen: Callable
var _citizen_needs_service_remove_citizen: Callable
var _courier_dispatcher_complete_for: Callable
var _selected_house_getter: Callable
var _day_cycle_current_day_getter: Callable


func configure(
	p_citizens: Array,
	p_pending_arrivals: Array,
	p_arrival_greeters: Dictionary,
	p_arrival_waiting_greeters: Dictionary,
	p_arrival_escort_ids: Dictionary,
	p_entrance_stone_getter: Callable,
	p_entrance_anchor_position: Callable,
	p_employment_center_position: Callable,
	p_is_work_time: Callable,
	p_update_interface: Callable,
	p_show_house_menu: Callable,
	p_add_citizen: Callable,
	p_refresh_living_status: Callable,
	p_request_courier_dispatch: Callable,
	p_citizen_for_ai_id: Callable,
	p_terrain_height_at: Callable,
	p_citizen_ai_unregister: Callable,
	p_citizen_ai_cancel_work: Callable,
	p_canteen_service_remove_citizen: Callable,
	p_citizen_needs_service_remove_citizen: Callable,
	p_courier_dispatcher_complete_for: Callable,
	p_selected_house_getter: Callable,
	p_day_cycle_current_day_getter: Callable
) -> void:
	_citizens = p_citizens
	_pending_arrivals = p_pending_arrivals
	_arrival_greeters = p_arrival_greeters
	_arrival_waiting_greeters = p_arrival_waiting_greeters
	_arrival_escort_ids = p_arrival_escort_ids
	_entrance_stone_getter = p_entrance_stone_getter
	_entrance_anchor_position = p_entrance_anchor_position
	_employment_center_position = p_employment_center_position
	_is_work_time = p_is_work_time
	_update_interface = p_update_interface
	_show_house_menu = p_show_house_menu
	_add_citizen = p_add_citizen
	_refresh_living_status = p_refresh_living_status
	_request_courier_dispatch = p_request_courier_dispatch
	_citizen_for_ai_id = p_citizen_for_ai_id
	_terrain_height_at = p_terrain_height_at
	_citizen_ai_unregister = p_citizen_ai_unregister
	_citizen_ai_cancel_work = p_citizen_ai_cancel_work
	_canteen_service_remove_citizen = p_canteen_service_remove_citizen
	_citizen_needs_service_remove_citizen = p_citizen_needs_service_remove_citizen
	_courier_dispatcher_complete_for = p_courier_dispatcher_complete_for
	_selected_house_getter = p_selected_house_getter
	_day_cycle_current_day_getter = p_day_cycle_current_day_getter


func on_citizen_leaving_departed(citizen: Citizen) -> void:
	if not is_instance_valid(citizen):
		return
	_citizens.erase(citizen)
	_citizen_ai_unregister.call(citizen.ai_id)
	_canteen_service_remove_citizen.call(citizen.ai_id)
	_citizen_needs_service_remove_citizen.call(citizen.ai_id)
	citizen.queue_free()


func spawn_house_citizen() -> void:
	var selected_house: Node3D = _selected_house_getter.call()
	if selected_house == null or bool(selected_house.get_meta("pending_demolition", false)):
		return
	var slots: int = selected_house.get_meta("spawn_slots", 0)
	if slots <= 0:
		return
	var is_tent: bool = selected_house.has_meta("is_tent")
	if is_tent:
		if int(selected_house.get_meta("tent_order_day", -1)) == _day_cycle_current_day_getter.call():
			return
		selected_house.set_meta("tent_order_day", _day_cycle_current_day_getter.call())
	elif unhoused_citizen_count() > 0:
		return
	selected_house.set_meta("spawn_slots", slots - 1)
	_show_house_menu.call()
	_pending_arrivals.append({"house": selected_house})
	update_arrivals()
	_update_interface.call("A resident is expected at the entrance sign. Assign a Courier to meet them.")


func find_arrival_greeter(allow_busy := false) -> Citizen:
	var best: Citizen = null
	var best_score := INF
	for citizen in _citizens:
		if citizen.is_player_controlled or not citizen.can_handle_entry_logistics():
			continue
		if citizen.has_active_arrival_task() or citizen.pending_arrival_entrance != Vector3.INF:
			continue
		var is_free: bool = citizen.state in [Citizen.State.IDLE, Citizen.State.RESTING]
		if not is_free and not allow_busy:
			continue
		if not is_free and citizen.has_active_delivery():
			continue
		var score: float = citizen.global_position.distance_to(_entrance_anchor_position.call())
		if not is_free:
			score += citizen.task_timer.remaining * Citizen.WALK_SPEED
		if score < best_score:
			best = citizen
			best_score = score
	return best


func update_arrivals() -> void:
	if not is_instance_valid(_entrance_stone_getter.call()):
		return
	requeue_interrupted_arrivals()
	if _is_work_time.call():
		for citizen in _citizens:
			if citizen.state != Citizen.State.ARRIVAL_WAITING:
				continue
			if _arrival_escort_ids.has(citizen.ai_id):
				citizen.escort_arrivals_to(_employment_center_position.call())
				_arrival_escort_ids.erase(citizen.ai_id)
			else:
				if _employment_center_position.call() != Vector3.INF:
					citizen.begin_employment_processing(_employment_center_position.call())
				else:
					citizen.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
					citizen.idle()
	for greeter_id in _arrival_waiting_greeters.keys():
		var waiting_greeter: Citizen = _citizen_for_ai_id.call(int(greeter_id))
		var waiting_order: Dictionary = _arrival_waiting_greeters[greeter_id]
		if not is_instance_valid(waiting_greeter) or not waiting_greeter.can_handle_entry_logistics():
			_arrival_waiting_greeters.erase(greeter_id)
			requeue_arrival_order(waiting_order)
			continue
		if waiting_greeter.has_active_arrival_task():
			_arrival_waiting_greeters.erase(greeter_id)
			_arrival_greeters[greeter_id] = waiting_order
			continue
		if waiting_greeter.state in [Citizen.State.IDLE, Citizen.State.RESTING]:
			waiting_greeter.go_to_arrival_entrance(_entrance_anchor_position.call())
			_arrival_waiting_greeters.erase(greeter_id)
			_arrival_greeters[greeter_id] = waiting_order
	_request_courier_dispatch.call()


func on_arrival_greeter_ready(greeter: Citizen) -> void:
	var order: Dictionary = _arrival_greeters.get(greeter.ai_id, {})
	_arrival_greeters.erase(greeter.ai_id)
	_courier_dispatcher_complete_for.call(greeter)
	if order.is_empty():
		greeter.idle()
		return
	_pending_arrivals.erase(order)
	var house: Node3D = order.get("house") as Node3D
	if not is_instance_valid(house) or bool(house.get_meta("pending_demolition", false)):
		greeter.idle()
		_update_interface.call("Arrival cancelled because its assigned home is being demolished.")
		return
	var spawn_position: Vector3 = _entrance_anchor_position.call() + Vector3(0.55, 0.08, 0.55)
	var terrain_height: float = _terrain_height_at.call(spawn_position.x, spawn_position.z, spawn_position.y)
	if not is_nan(terrain_height):
		spawn_position.y = terrain_height + 0.08
	_add_citizen.call(spawn_position, "unassigned")
	var newcomer: Citizen = _citizens.back()
	newcomer.assign_home(house)
	_refresh_living_status.call(newcomer)
	if _is_work_time.call():
		var centre: Vector3 = _employment_center_position.call()
		if centre != Vector3.INF:
			greeter.escort_arrivals_to(centre)
			newcomer.begin_employment_processing(centre)
			_update_interface.call("The newcomer was met at the entrance and is heading to employment registration.")
		else:
			greeter.idle()
			newcomer.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
			newcomer.idle()
			_update_interface.call("The newcomer joined the settlement without a permanent job.")
	else:
		_arrival_escort_ids[greeter.ai_id] = true
		greeter.wait_for_arrival_morning()
		newcomer.wait_for_arrival_morning()
		_update_interface.call("The newcomer and greeter are waiting at the entrance for the workday.")
	_show_house_menu.call()


func requeue_interrupted_arrivals() -> void:
	for greeter_id in _arrival_waiting_greeters.keys():
		var waiting_greeter: Citizen = _citizen_for_ai_id.call(int(greeter_id))
		if is_instance_valid(waiting_greeter) and waiting_greeter.has_active_arrival_task():
			_arrival_greeters[greeter_id] = _arrival_waiting_greeters[greeter_id]
			_arrival_waiting_greeters.erase(greeter_id)
			continue
		if is_instance_valid(waiting_greeter) and waiting_greeter.pending_arrival_entrance != Vector3.INF:
			continue
		var waiting_order: Dictionary = _arrival_waiting_greeters[greeter_id]
		_arrival_waiting_greeters.erase(greeter_id)
		requeue_arrival_order(waiting_order)
	for greeter_id in _arrival_greeters.keys():
		var greeter: Citizen = _citizen_for_ai_id.call(int(greeter_id))
		if is_instance_valid(greeter) and greeter.has_active_arrival_task():
			continue
		var order: Dictionary = _arrival_greeters[greeter_id]
		_arrival_greeters.erase(greeter_id)
		requeue_arrival_order(order)


func requeue_arrival_order(order: Dictionary) -> void:
	for index in _pending_arrivals.size():
		if _pending_arrivals[index] == order:
			order.dispatched = false
			order.erase("greeter_id")
			_pending_arrivals[index] = order
			return


func cancel_arrivals_for_house(house: Node3D) -> void:
	var cancelled := false
	for index in range(_pending_arrivals.size() - 1, -1, -1):
		var order: Dictionary = _pending_arrivals[index]
		if order.get("house") != house:
			continue
		var greeter_id: int = int(order.get("greeter_id", -1))
		if greeter_id >= 0:
			_arrival_greeters.erase(greeter_id)
			_arrival_waiting_greeters.erase(greeter_id)
			var greeter: Citizen = _citizen_for_ai_id.call(greeter_id)
			if is_instance_valid(greeter):
				greeter.pending_arrival_entrance = Vector3.INF
				if greeter.has_active_arrival_task():
					greeter.idle()
		_pending_arrivals.remove_at(index)
		cancelled = true
	if cancelled:
		_update_interface.call("Pending arrival cancelled because its assigned home is being demolished.")


func settle_unhoused_resident() -> void:
	var selected_house: Node3D = _selected_house_getter.call()
	if selected_house == null or bool(selected_house.get_meta("pending_demolition", false)):
		return
	var slots: int = selected_house.get_meta("spawn_slots", 0)
	if slots <= 0:
		return
	for citizen in _citizens:
		if is_instance_valid(citizen.home):
			continue
		citizen.assign_home(selected_house)
		_refresh_living_status.call(citizen)
		selected_house.set_meta("spawn_slots", slots - 1)
		_update_interface.call("%s has been settled in this home." % citizen.role_label())
		_show_house_menu.call()
		return


func unhoused_citizen_count() -> int:
	var count := 0
	for citizen in _citizens:
		if not is_instance_valid(citizen.home):
			count += 1
	return count


func house_initial_residents(house: Node3D) -> void:
	if not house.has_meta("is_tent"):
		return
	var slots: int = int(house.get_meta("spawn_slots", 0))
	for citizen in _citizens:
		if slots <= 0:
			break
		if not is_instance_valid(citizen.home):
			citizen.assign_home(house)
			_refresh_living_status.call(citizen)
			slots -= 1
	house.set_meta("spawn_slots", slots)


func send_to_unemployment_registration(citizen: Citizen) -> void:
	if citizen.is_player_controlled:
		return
	_citizen_ai_cancel_work.call(citizen.ai_id)
	citizen.idle()
	citizen.permanent_role = ""
	citizen.pending_employment_role = ""
	citizen.employment_workplace = null
	citizen.pending_employment_workplace = null
	citizen.release_to_no_permanent_work()
