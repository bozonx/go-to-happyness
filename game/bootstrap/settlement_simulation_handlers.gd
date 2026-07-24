class_name SettlementSimulationHandlers
extends RefCounted

## Handles simulation event callbacks: school day end, AI work shift end,
## daily order clearing, overtime management, and daily settlement updates.
## Extracted from SettlementGame to reduce monolithic file size.

const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")
const EventContextScript = preload("res://game/features/events/domain/event_context.gd")

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func on_school_day_ended() -> void:
	var teacher_ok := game._is_teacher_present_at_school()
	for citizen in game.citizens:
		citizen.finish_school_day(teacher_ok)


func on_daily_settlement_update(_event: SimulationDayEvent) -> void:
	game.tent_weather = TentEraSurvivalRulesScript.weather_for_day(game.day_cycle.current_day)
	game.weather_state.new_day(game.tent_weather, game.random, int(game.clock.minutes))
	game._update_interface("Forecast: %s." % TentEraSurvivalRulesScript.WEATHER_NAMES[game.tent_weather])
	if game.event_service != null:
		game.event_service.log.clear_flag(&"smoky_firewood")
		game.event_service.log.clear_flag(&"firewood_protected_today")
		var delayed_outcomes: Array[EventOutcome] = game.event_service.advance_day(game.day_cycle.current_day, game.survival_event_controller.build_event_context() if game.survival_event_controller != null else EventContextScript.create(0, 1, 0, {}, 0, 0, {}), game.random)
		for outcome in delayed_outcomes:
			if game.survival_event_controller != null:
				game.survival_event_controller.apply_event_outcome(outcome)
	if game.survival_event_controller != null:
		game.survival_event_controller.maybe_present_survival_decision()
	game._refresh_living_statuses()
	game.settlement.cheer_up_used_today = false
	game.settlement.double_time_order_day = -1
	if game.building_lifecycle_service != null:
		game.building_lifecycle_service.remove_expired_temporary_tents()
	if game.settlement_daily_rules_service != null:
		game.settlement_daily_rules_service.apply_daily_settlement_rules()
	game._return_outside_workers()


func end_ai_work_shift() -> void:
	for citizen: Citizen in game.citizens:
		if not is_instance_valid(citizen) or citizen.is_player_controlled:
			continue
		if citizen.has_active_overtime(game.day_cycle.current_day) and citizen.overtime_until_workday_id > game.day_cycle.current_day:
			continue
		if game.citizen_ai != null:
			game.citizen_ai.cancel_citizen_work(citizen.ai_id)
		citizen.end_work_shift()


func clear_finished_daily_orders(workday_id: int) -> void:
	for citizen in game.citizens:
		if not is_instance_valid(citizen):
			continue
		if citizen.has_active_overtime(workday_id) and citizen.overtime_until_workday_id > workday_id:
			continue
		citizen.clear_daily_order(workday_id)
		if citizen.overtime_until_workday_id == workday_id:
			citizen.clear_expired_overtime(workday_id + 1)
	if game.citizen_ai != null:
		game.citizen_ai.request_decision_refresh()
	if game.citizen_daily_order_service != null:
		game.citizen_daily_order_service.sync_overtime_scope_indicators()


func clear_expired_overtime_orders() -> void:
	for citizen in game.citizens:
		if is_instance_valid(citizen):
			citizen.clear_expired_overtime(game.day_cycle.current_day)


func reset_building_night_work_toggles() -> void:
	# Keep an active overnight scope visible through the following workday. The
	# previous implementation cleared this at 08:00 while its workers still had
	# overtime, turning the next click into an accidental extension.
	if game.citizen_daily_order_service != null:
		game.citizen_daily_order_service.sync_overtime_scope_indicators()


func resume_overtime_daily_orders() -> void:
	if game.citizen_daily_order_service != null:
		game.citizen_daily_order_service.resume_overtime_daily_orders()
