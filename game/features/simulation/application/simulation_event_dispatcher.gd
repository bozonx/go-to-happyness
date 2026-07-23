class_name SimulationEventDispatcher
extends RefCounted

const SimulationDayEvent = preload("res://game/features/simulation/domain/simulation_day_event.gd")
const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")

var start_meal_fn: Callable
var start_park_rest_fn: Callable
var end_ai_work_shift_fn: Callable
var clear_finished_daily_orders_fn: Callable
var refresh_living_statuses_fn: Callable
var update_workers_fn: Callable
var apply_pending_workday_hours_fn: Callable
var clear_expired_overtime_orders_fn: Callable
var reset_building_night_work_toggles_fn: Callable
var resume_overtime_daily_orders_fn: Callable
var update_interface_fn: Callable
var citizen_ai_refresh_fn: Callable
var school_day_ended_fn: Callable
var daily_settlement_update_fn: Callable

func configure(callbacks: Dictionary) -> void:
	start_meal_fn = callbacks.get("start_meal", Callable())
	start_park_rest_fn = callbacks.get("start_park_rest", Callable())
	end_ai_work_shift_fn = callbacks.get("end_ai_work_shift", Callable())
	clear_finished_daily_orders_fn = callbacks.get("clear_finished_daily_orders", Callable())
	refresh_living_statuses_fn = callbacks.get("refresh_living_statuses", Callable())
	update_workers_fn = callbacks.get("update_workers", Callable())
	apply_pending_workday_hours_fn = callbacks.get("apply_pending_workday_hours", Callable())
	clear_expired_overtime_orders_fn = callbacks.get("clear_expired_overtime_orders", Callable())
	reset_building_night_work_toggles_fn = callbacks.get("reset_building_night_work_toggles", Callable())
	resume_overtime_daily_orders_fn = callbacks.get("resume_overtime_daily_orders", Callable())
	update_interface_fn = callbacks.get("update_interface", Callable())
	citizen_ai_refresh_fn = callbacks.get("citizen_ai_refresh", Callable())
	school_day_ended_fn = callbacks.get("school_day_ended", Callable())
	daily_settlement_update_fn = callbacks.get("daily_settlement_update", Callable())

func dispatch_event(event: SimulationDayEvent, current_day: int) -> void:
	match event.kind:
		SimulationDayEvent.Kind.MEAL:
			if start_meal_fn.is_valid():
				start_meal_fn.call(event.hour)
		SimulationDayEvent.Kind.PARK_REST:
			if start_park_rest_fn.is_valid():
				start_park_rest_fn.call(event.cooks_only)
		SimulationDayEvent.Kind.WORKDAY_ENDED:
			if end_ai_work_shift_fn.is_valid():
				end_ai_work_shift_fn.call()
			if clear_finished_daily_orders_fn.is_valid():
				clear_finished_daily_orders_fn.call(current_day)
			if update_interface_fn.is_valid():
				update_interface_fn.call("Workday ended: residents without a night-work order are returning home.")
		SimulationDayEvent.Kind.NIGHTFALL:
			if refresh_living_statuses_fn.is_valid():
				refresh_living_statuses_fn.call()
			if update_workers_fn.is_valid():
				update_workers_fn.call()
			if update_interface_fn.is_valid():
				update_interface_fn.call("Nightfall: workers are returning to their assigned homes.")
		SimulationDayEvent.Kind.WORKDAY_STARTED:
			if apply_pending_workday_hours_fn.is_valid():
				apply_pending_workday_hours_fn.call()
			if clear_expired_overtime_orders_fn.is_valid():
				clear_expired_overtime_orders_fn.call()
			if reset_building_night_work_toggles_fn.is_valid():
				reset_building_night_work_toggles_fn.call()
			if resume_overtime_daily_orders_fn.is_valid():
				resume_overtime_daily_orders_fn.call()
			if refresh_living_statuses_fn.is_valid():
				refresh_living_statuses_fn.call()
			if update_workers_fn.is_valid():
				update_workers_fn.call()
			if citizen_ai_refresh_fn.is_valid():
				citizen_ai_refresh_fn.call()
			if update_interface_fn.is_valid():
				update_interface_fn.call("Morning: workers left their homes for their assignments.")
		SimulationDayEvent.Kind.SCHOOL_DAY_ENDED:
			if school_day_ended_fn.is_valid():
				school_day_ended_fn.call()
			if update_workers_fn.is_valid():
				update_workers_fn.call()
		SimulationDayEvent.Kind.DAILY_SETTLEMENT_UPDATE:
			if daily_settlement_update_fn.is_valid():
				daily_settlement_update_fn.call(event)
