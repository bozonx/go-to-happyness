class_name SurvivalEventController
extends Node

## Coordinates survival event decisions, skip-night logic, and survival busy workers.
## Holds a simulation reference (like PlayerController) and calls back into it
## for state mutations that span multiple systems.

const EventContextScript = preload("res://game/features/events/domain/event_context.gd")
const EventOutcomeScript = preload("res://game/features/events/domain/event_outcome.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")
const SimulationDayEvent = preload("res://game/features/simulation/domain/simulation_day_event.gd")
const SimulationClock = preload("res://game/features/simulation/domain/simulation_clock.gd")
const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")

var simulation: Node


func setup(p_simulation: Node) -> void:
	simulation = p_simulation


# --- Event decisions ---

func maybe_present_survival_decision() -> void:
	if simulation.ui_manager.decision_menu == null or simulation.ui_manager.decision_menu.visible:
		return
	if simulation.event_service == null or simulation.event_service.has_pending():
		return
	var ctx := _build_event_context()
	var event_def = simulation.event_service.roll_daily_event(ctx, simulation.random)
	if event_def == null:
		return
	_show_event_decision(event_def)


func _show_event_decision(event_def) -> void:
	var choice_labels: Array[String] = []
	for choice in event_def.choices:
		choice_labels.append(choice.label)
	simulation.ui_manager.decision_menu.show_event(event_def.title, event_def.description, choice_labels)


func resolve_event_decision(choice_index: int) -> void:
	if simulation.event_service == null or not simulation.event_service.has_pending():
		simulation.ui_manager.decision_menu.visible = false
		return
	var ctx := _build_event_context()
	var outcomes: Array[EventOutcome] = simulation.event_service.resolve_choice(choice_index, ctx, simulation.random)
	for outcome in outcomes:
		_apply_event_outcome(outcome)
	simulation.ui_manager.decision_menu.visible = false


func _build_event_context() -> EventContext:
	var res := {
		"food": simulation.settlement.amount(ResourceIds.FOOD),
		"water": simulation.settlement.amount(ResourceIds.WATER),
		"branches": simulation.settlement.amount(ResourceIds.BRANCHES),
		"grass": simulation.settlement.amount(ResourceIds.GRASS),
		"wood": simulation.settlement.amount(ResourceIds.WOOD),
		"stone": simulation.settlement.amount(ResourceIds.STONE),
		"hides": simulation.settlement.amount(ResourceIds.HIDES),
		"goods": simulation.settlement.goods,
		"tarp": simulation.settlement.tarp,
		"logs": simulation.settlement.logs,
	}
	var flags: Dictionary = {}
	if simulation.event_service != null and simulation.event_service.log != null:
		flags = simulation.event_service.log.flags.duplicate()
	return EventContextScript.create(
		simulation.settlement.era,
		simulation.day_cycle.current_day,
		simulation.tent_weather,
		res,
		simulation.settlement.wellbeing,
		simulation.citizens.size(),
		flags,
	)


func _apply_event_outcome(outcome: EventOutcome) -> void:
	match outcome.kind:
		EventOutcome.Kind.MESSAGE:
			if not outcome.text.is_empty():
				simulation._add_message(outcome.text)
		EventOutcome.Kind.RESOURCE_CHANGE:
			simulation.settlement.add(outcome.resource, outcome.amount)
		EventOutcome.Kind.WELLBEING_CHANGE:
			simulation.settlement.wellbeing = clampi(simulation.settlement.wellbeing + outcome.wellbeing_delta, 0, 100)
		EventOutcome.Kind.WORKER_BUSY:
			_assign_survival_busy_worker(outcome.worker_busy_hours, outcome.worker_busy_label)
		EventOutcome.Kind.SET_FLAG:
			pass
		EventOutcome.Kind.DELAYED:
			pass


func apply_event_outcome(outcome: EventOutcome) -> void:
	_apply_event_outcome(outcome)


func build_event_context() -> EventContext:
	return _build_event_context()


# --- Survival busy workers ---

func _assign_survival_busy_worker(hours: float, status_label: String) -> void:
	var candidates: Array[Citizen] = []
	for citizen in simulation.citizens:
		if is_instance_valid(citizen) and not citizen.is_hero and not citizen.is_player_controlled:
			candidates.append(citizen)
	if candidates.is_empty():
		return
	var worker: Citizen = candidates[simulation.random.randi_range(0, candidates.size() - 1)]
	if simulation.citizen_ai != null:
		simulation.citizen_ai.cancel_citizen_work(worker.ai_id)
	worker.cancel_current_action()
	worker.set_player_controlled(true)
	worker.set_status_effect(&"survival_assignment", status_label, 1.0, hours)
	simulation.survival_busy_until[worker.ai_id] = simulation._total_game_minutes() + hours * 60.0


func update_survival_busy_workers() -> void:
	for worker_id in simulation.survival_busy_until.keys().duplicate():
		if simulation._total_game_minutes() < float(simulation.survival_busy_until[worker_id]):
			continue
		var worker = simulation._citizen_for_ai_id(int(worker_id))
		if is_instance_valid(worker):
			worker.set_player_controlled(false)
			worker.clear_status_effect(&"survival_assignment")
			worker.idle()
		simulation.survival_busy_until.erase(worker_id)
		simulation._update_workers()


# --- Skip night ---

func can_skip_night() -> bool:
	if simulation._has_active_night_work_order():
		return false
	var hour: int = simulation.clock.hour()
	return hour >= 8 + simulation.settlement.workday_hours or hour < 6


func can_skip_to_workday_start() -> bool:
	if simulation._has_active_night_work_order():
		return false
	var hour: int = simulation.clock.hour()
	return hour >= 6 and hour < 8


func update_skip_night_button() -> void:
	if simulation.ui_manager.time_controls_panel != null:
		simulation.ui_manager.time_controls_panel.update_skip_buttons(can_skip_night(), can_skip_to_workday_start(), simulation.is_first_person)


func _skip_night_survival_hours() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var current_hour: int = simulation.clock.hour()
	var first_hour: int = current_hour if simulation.clock.minute() == 0 else posmod(current_hour + 1, 24)
	if current_hour >= 6 and current_hour < 22:
		first_hour = 22
	var offset := 0
	while offset < 24:
		var hour: int = posmod(first_hour + offset, 24)
		if hour == 6:
			break
		var survival_day: int = simulation.day_cycle.current_day
		if current_hour >= 6 and hour < current_hour:
			survival_day += 1
		result.append({"day": survival_day, "hour": hour})
		offset += 1
	return result


func skip_night() -> void:
	if not can_skip_night():
		update_skip_night_button()
		return
	# Skipping time must not teleport workers to the entrance. Their current
	# locations are valid even when the morning scheduler assigns fresh work.
	var positions: Dictionary = {}
	for citizen in simulation.citizens:
		if is_instance_valid(citizen) and not simulation.outside_workers.has(citizen.get_stable_id()):
			positions[citizen.get_stable_id()] = citizen.global_position
	var target_day: int = simulation.day_cycle.current_day + (1 if simulation.clock.hour() >= 6 else 0)
	simulation.settlement_survival_service.is_skipping_night = true
	simulation.settlement_survival_service.skip_zero_wellbeing_departure_applied = false
	for survival_hour in _skip_night_survival_hours():
		simulation._apply_hourly_tent_survival(int(survival_hour.hour), int(survival_hour.day))
	simulation.settlement_survival_service.is_skipping_night = false
	simulation.day_cycle.current_day = target_day
	simulation.tent_weather = TentEraSurvivalRulesScript.weather_for_day(simulation.day_cycle.current_day)
	simulation.clock.set_time(6 * 60)
	# Living through the night crosses 06:00, when the daily water/food sink runs and
	# frees storage. Skipping must apply the same rules, otherwise stores stay full,
	# no production is assignable, and workers have nothing to wake up for.
	simulation._refresh_living_statuses()
	simulation._apply_daily_settlement_rules()
	# A skipped night has no intervening movement frames for a departing resident.
	# Remove dawn departures immediately so the simulated result matches elapsed time.
	for citizen in simulation.citizens.duplicate():
		if is_instance_valid(citizen) and citizen.state == Citizen.State.LEAVING:
			simulation._on_citizen_leaving_departed(citizen)
	simulation._return_outside_workers()
	_apply_skip_night_incident()
	simulation._update_workers()
	for citizen in simulation.citizens:
		if is_instance_valid(citizen) and positions.has(citizen.get_stable_id()):
			citizen.global_position = positions[citizen.get_stable_id()]
			citizen.velocity = Vector3.ZERO
			simulation.last_citizen_positions[citizen.get_stable_id()] = citizen.global_position
	if simulation.citizen_ai != null:
		simulation.citizen_ai.request_decision_refresh()
	update_skip_night_button()
	simulation._update_daylight()
	simulation._update_house_lights()
	simulation._update_interface("Skipped the night. Morning begins at 06:00.")


func skip_to_workday_start() -> void:
	if not can_skip_to_workday_start():
		update_skip_night_button()
		return
	simulation.day_cycle.set_to_workday_start()
	simulation._handle_day_cycle_event(SimulationDayEvent.new(SimulationDayEvent.Kind.WORKDAY_STARTED, 8))
	if simulation.citizen_ai != null:
		simulation.citizen_ai.request_decision_refresh()
	update_skip_night_button()
	simulation._update_daylight()
	simulation._update_house_lights()
	simulation._update_interface("Workday starts at 08:00.")


func _apply_skip_night_incident() -> void:
	var incidents := [
		{"resource": ResourceIds.FOOD, "min": 3, "max": 5, "message": "Night scavengers took %d food."},
		{"resource": ResourceIds.GRASS, "min": 10, "max": 15, "message": "A stray animal ate %d grass."},
		{"resource": ResourceIds.BRANCHES, "min": 5, "max": 8, "message": "Wind scattered %d branches."},
		{"resource": "gloves", "min": 20, "max": 20, "message": "Night scavengers damaged a glove set by %d%%."},
	]
	var incident: Dictionary = incidents[simulation.random.randi_range(0, incidents.size() - 1)]
	if str(incident.resource) == "gloves":
		var gloves: Dictionary = simulation.settlement.equipment.get(ResourceIds.CONSTRUCTION_GLOVES, {})
		if int(gloves.get("sets", 0)) > 0:
			gloves["active_durability"] = maxf(0.0, float(gloves.get("active_durability", 100.0)) - float(incident.max))
			simulation.settlement.equipment[ResourceIds.CONSTRUCTION_GLOVES] = gloves
			simulation._add_message(str(incident.message) % int(incident.max))
		return
	var amount := mini(simulation.settlement.amount(str(incident.resource)), simulation.random.randi_range(int(incident.min), int(incident.max)))
	if amount > 0:
		simulation.settlement.add(str(incident.resource), -amount)
		simulation._add_message(str(incident.message) % amount)
