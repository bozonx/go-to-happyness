class_name CitizenDailyOrderService
extends RefCounted

## Manages citizen daily orders, overtime assignment, workday expirations,
## and overtime scope syncing across citizens and workplaces.

var _settlement: SettlementState
var _citizens: Array = []
var _day_cycle: SimulationDayCycle
var _clock: SimulationClock
var _building_registry: Variant
var _runtime_seconds_getter: Callable
var _is_work_time: Callable
var _is_citizen_work_time: Callable
var _absolute_game_minutes: Callable
var _game_minutes_per_second: float
var _citizen_ai_request_decision_refresh: Callable


func configure(
	p_settlement: SettlementState,
	p_citizens: Array,
	p_day_cycle: SimulationDayCycle,
	p_clock: SimulationClock,
	p_building_registry: Variant,
	p_runtime_seconds_getter: Callable,
	p_is_work_time: Callable,
	p_is_citizen_work_time: Callable,
	p_absolute_game_minutes: Callable,
	p_game_minutes_per_second: float,
	p_citizen_ai_request_decision_refresh: Callable
) -> void:
	_settlement = p_settlement
	_citizens = p_citizens
	_day_cycle = p_day_cycle
	_clock = p_clock
	_building_registry = p_building_registry
	_runtime_seconds_getter = p_runtime_seconds_getter
	_is_work_time = p_is_work_time
	_is_citizen_work_time = p_is_citizen_work_time
	_absolute_game_minutes = p_absolute_game_minutes
	_game_minutes_per_second = p_game_minutes_per_second
	_citizen_ai_request_decision_refresh = p_citizen_ai_request_decision_refresh


func daily_order_workday_for_new_order() -> int:
	if _is_work_time.call() or _clock.hour() < 8:
		return _day_cycle.current_day
	return _day_cycle.current_day + 1


func daily_order_expiration_for_workday(workday_id: int) -> float:
	var end_minute := (workday_id - 1) * SimulationClock.MINUTES_PER_DAY + (8 + workday_hours_for(workday_id)) * 60
	var remaining_minutes := maxi(0, end_minute - int(_absolute_game_minutes.call()))
	return _runtime_seconds_getter.call() + float(remaining_minutes) / _game_minutes_per_second


func workday_hours_for(workday_id: int) -> int:
	if _settlement.pending_workday_hours > 0 and (workday_id > _day_cycle.current_day or (workday_id == _day_cycle.current_day and _clock.hour() < 8)):
		return _settlement.pending_workday_hours
	return _settlement.workday_hours


func activate_citizen_overtime(citizen: Citizen, source: String) -> bool:
	if not is_instance_valid(citizen):
		return false
	if not citizen.activate_overtime(_day_cycle.current_day + 1, source, _day_cycle.current_day):
		return false
	if citizen.has_daily_order():
		# Overtime keeps today's assignment alive through the following workday.
		# An order may have been assigned either before or during the current shift,
		# so extending only already-future orders leaves the common active-order path
		# expiring at today's end of shift.
		citizen.daily_order_workday_id = _day_cycle.current_day
		citizen.daily_order_expires_at = maxf(
			citizen.daily_order_expires_at,
			daily_order_expiration_for_workday(_day_cycle.current_day + 1)
		)
	return true


func is_daily_order_active(citizen: Citizen) -> bool:
	return (
		is_instance_valid(citizen)
		and citizen.daily_order_workday_id == _day_cycle.current_day
		and _is_citizen_work_time.call(citizen)
	)


func assign_daily_order(citizen: Citizen, role: String) -> void:
	if not is_instance_valid(citizen) or citizen.is_player_controlled:
		return
	var workday_id := daily_order_workday_for_new_order()
	citizen.assign_daily_order(role, workday_id, daily_order_expiration_for_workday(workday_id))
	_citizen_ai_request_decision_refresh.call()


func clear_daily_orders(workday_id := 0) -> void:
	var changed := false
	for citizen in _citizens:
		if not is_instance_valid(citizen):
			continue
		if citizen.has_daily_order():
			citizen.clear_daily_order(workday_id)
			changed = true
	if changed:
		_citizen_ai_request_decision_refresh.call()


func sync_overtime_scope_indicators() -> void:
	_settlement.night_work_order_day = _day_cycle.current_day if has_overtime_source("settlement") else -1
	for record in _building_registry.records():
		var node := record.node as Node3D
		if is_instance_valid(node) and node.has_meta("night_work_order_day") and not has_overtime_source("workplace", node):
			node.set_meta("night_work_order_day", -1)


func has_overtime_source(source: String, workplace: Node3D = null) -> bool:
	for citizen in _citizens:
		if not is_instance_valid(citizen) or not citizen.has_overtime_source(source, _day_cycle.current_day):
			continue
		if workplace == null or citizen.employment_workplace == workplace:
			return true
	return false


func resume_overtime_daily_orders() -> void:
	for citizen in _citizens:
		if not is_instance_valid(citizen):
			continue
		if citizen.has_active_overtime(_day_cycle.current_day) and citizen.daily_order_workday_id == _day_cycle.current_day - 1:
			citizen.daily_order_workday_id = _day_cycle.current_day
			citizen.daily_order_expires_at = maxf(citizen.daily_order_expires_at, daily_order_expiration_for_workday(_day_cycle.current_day))
