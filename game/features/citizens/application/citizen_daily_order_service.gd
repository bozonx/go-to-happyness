class_name CitizenDailyOrderService
extends RefCounted

## Manages citizen daily orders, overtime assignment, workday expirations,
## and overtime scope syncing across citizens and workplaces.

var simulation: Node


func configure(p_simulation: Node) -> void:
	simulation = p_simulation


func daily_order_workday_for_new_order() -> int:
	if simulation._is_work_time() or simulation.clock.hour() < 8:
		return simulation.day_cycle.current_day
	return simulation.day_cycle.current_day + 1


func daily_order_expiration_for_workday(workday_id: int) -> float:
	var end_minute := (workday_id - 1) * SimulationClock.MINUTES_PER_DAY + (8 + workday_hours_for(workday_id)) * 60
	var remaining_minutes := maxi(0, end_minute - int(simulation._absolute_game_minutes()))
	return simulation.runtime_seconds + float(remaining_minutes) / simulation.GAME_MINUTES_PER_SECOND


func workday_hours_for(workday_id: int) -> int:
	if simulation.settlement.pending_workday_hours > 0 and (workday_id > simulation.day_cycle.current_day or (workday_id == simulation.day_cycle.current_day and simulation.clock.hour() < 8)):
		return simulation.settlement.pending_workday_hours
	return simulation.settlement.workday_hours


func activate_citizen_overtime(citizen: Citizen, source: String) -> bool:
	if not is_instance_valid(citizen):
		return false
	if not citizen.activate_overtime(simulation.day_cycle.current_day + 1, source, simulation.day_cycle.current_day):
		return false
	if citizen.has_daily_order():
		if citizen.daily_order_workday_id > simulation.day_cycle.current_day:
			citizen.daily_order_workday_id = simulation.day_cycle.current_day
		citizen.daily_order_expires_at = daily_order_expiration_for_workday(simulation.day_cycle.current_day + 1)
	return true


func is_daily_order_active(citizen: Citizen) -> bool:
	return (
		is_instance_valid(citizen)
		and citizen.daily_order_workday_id == simulation.day_cycle.current_day
		and simulation._is_citizen_work_time(citizen)
	)


func assign_daily_order(citizen: Citizen, role: String) -> void:
	if not is_instance_valid(citizen) or citizen.is_player_controlled:
		return
	var workday_id := daily_order_workday_for_new_order()
	citizen.assign_daily_order(role, workday_id, daily_order_expiration_for_workday(workday_id))
	if simulation.citizen_ai != null:
		simulation.citizen_ai.request_decision_refresh()


func clear_daily_orders(workday_id := 0) -> void:
	var changed := false
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen):
			continue
		if citizen.has_daily_order():
			citizen.clear_daily_order(workday_id)
			changed = true
	if changed and simulation.citizen_ai != null:
		simulation.citizen_ai.request_decision_refresh()


func sync_overtime_scope_indicators() -> void:
	simulation.settlement.night_work_order_day = simulation.day_cycle.current_day if has_overtime_source("settlement") else -1
	for record in simulation.building_registry.records():
		var node := record.node as Node3D
		if is_instance_valid(node) and node.has_meta("night_work_order_day") and not has_overtime_source("workplace", node):
			node.set_meta("night_work_order_day", -1)


func has_overtime_source(source: String, workplace: Node3D = null) -> bool:
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen) or not citizen.has_overtime_source(source, simulation.day_cycle.current_day):
			continue
		if workplace == null or citizen.employment_workplace == workplace:
			return true
	return false


func resume_overtime_daily_orders() -> void:
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen):
			continue
		if citizen.has_active_overtime(simulation.day_cycle.current_day) and citizen.daily_order_workday_id == simulation.day_cycle.current_day - 1:
			citizen.daily_order_workday_id = simulation.day_cycle.current_day
			citizen.daily_order_expires_at = maxf(citizen.daily_order_expires_at, daily_order_expiration_for_workday(simulation.day_cycle.current_day))
