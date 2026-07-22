class_name SettlementSurvivalService
extends RefCounted

## Owns hourly tent-era survival rules, rain damage, bare-hands penalty,
## work fatigue, exhaustion homecomings, wellbeing-collapse departures,
## and daily departure checks.
## State that tracks survival idempotency (last_survival_hour, skip-night flags)
## lives here so the bootstrap controller does not manage it directly.

const SETTLEMENT_RULES = preload("res://game/features/settlement/domain/settlement_rules.gd")
const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")
const SettlementStateScript = preload("res://game/features/settlement/domain/settlement_state.gd")

var simulation: Node

var last_survival_hour := -1
var last_zero_wellbeing_departure_day := -1
var is_skipping_night := false
var skip_zero_wellbeing_departure_applied := false


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func apply_hourly_tent_survival(hour: int, survival_day := 0) -> void:
	var day_cycle: SimulationDayCycle = simulation.day_cycle
	var day := day_cycle.current_day if survival_day <= 0 else survival_day
	var survival_hour := day * 24 + hour
	var settlement: SettlementState = simulation.settlement
	if settlement.era != SettlementStateScript.Era.TENT or last_survival_hour == survival_hour:
		return
	last_survival_hour = survival_hour
	var night := hour >= 22 or hour < 6
	var has_fire: bool = simulation._has_lit_communal_fire()
	var total_loss := 0
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen):
			continue
		var has_home := is_instance_valid(citizen.home)
		total_loss += TentEraSurvivalRulesScript.hourly_wellbeing_loss(has_home, has_fire, simulation.tent_weather, night)
	if total_loss > 0:
		settlement.wellbeing = maxi(0, settlement.wellbeing - ceili(float(total_loss) / maxi(1, simulation.citizens.size())))
	if settlement.wellbeing == 0 and last_zero_wellbeing_departure_day != day and (not is_skipping_night or not skip_zero_wellbeing_departure_applied):
		last_zero_wellbeing_departure_day = day
		skip_zero_wellbeing_departure_applied = true
		_trigger_zero_wellbeing_departure()
	if simulation.weather_state.is_raining and hour > 0:
		apply_rain_damage()


func _trigger_zero_wellbeing_departure() -> void:
	var candidate: Citizen = null
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen) or citizen.is_hero or citizen.state == Citizen.State.LEAVING:
			continue
		if candidate == null or citizen.satisfaction < candidate.satisfaction:
			candidate = citizen
	if candidate == null or not is_instance_valid(simulation.entrance_stone):
		return
	var non_hero_count := 0
	for citizen in simulation.citizens:
		if is_instance_valid(citizen) and not citizen.is_hero:
			non_hero_count += 1
	if non_hero_count <= SETTLEMENT_RULES.MIN_SETTLEMENT_POPULATION - 1:
		return
	candidate.set_meta("leave_at_morning", true)
	simulation._add_message("%s will leave at dawn after the settlement's wellbeing collapsed." % candidate.role_label())


func apply_hourly_bare_hands_penalty() -> void:
	var settlement: SettlementState = simulation.settlement
	if settlement.construction_gloves_available():
		return
	var bare_handed_workers := 0
	for citizen in simulation.citizens:
		if is_instance_valid(citizen) and citizen._is_physical_work():
			bare_handed_workers += 1
	if bare_handed_workers > 0:
		settlement.wellbeing = maxi(0, settlement.wellbeing - ceili(float(bare_handed_workers) / maxi(1, simulation.citizens.size())))


func apply_rain_damage() -> void:
	var settlement: SettlementState = simulation.settlement
	var sheltered_capacity := int(settlement.buildings.get("straw_warehouse", 0)) * 48 + int(settlement.buildings.get("tarp_warehouse", 0)) * 72
	if settlement.warehouse_tarp_covered:
		sheltered_capacity += 24
	var stored_units := settlement.storage_used_units()
	if stored_units <= sheltered_capacity:
		return
	var exposed_ratio := (stored_units - sheltered_capacity) / stored_units
	var _firewood_protected: bool = simulation.event_service != null and simulation.event_service.log.has_flag(&"firewood_protected_today")
	var rain_amounts := {
		"food": settlement.amount("food"),
		"grass": settlement.amount("grass"),
		"branches": 0 if _firewood_protected else settlement.amount("branches"),
		"wood": settlement.amount("wood"),
		"logs": settlement.amount("logs"),
	}
	var losses := TentEraSurvivalRulesScript.rain_hourly_decay_losses(rain_amounts, exposed_ratio)
	for resource_type in losses:
		settlement.add(resource_type, -int(losses[resource_type]))
	for record in simulation.building_registry.records():
		var building: Node3D = record.node
		if is_instance_valid(building) and record.building_type in ["campfire", "campfire_lvl2", "campfire_lvl3", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3"]:
			var fire_state: RefCounted = simulation.fire_management_service.fire_state_for(building)
			fire_state.lit = false
			simulation.fire_management_service.apply_fire_state(building, fire_state)


func check_daily_departures() -> void:
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen) or citizen.is_hero:
			continue
		if SETTLEMENT_RULES.is_satisfaction_warning(citizen.satisfaction):
			simulation._add_message("Warning: %s is unhappy (satisfaction %d). They may leave if conditions don't improve." % [citizen.role_label(), int(citizen.satisfaction)])
	var candidate: Citizen = null
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen) or citizen.is_hero:
			continue
		if citizen.state == Citizen.State.LEAVING:
			continue
		if bool(citizen.get_meta("leave_at_morning", false)):
			candidate = citizen
			break
		if SETTLEMENT_RULES.should_citizen_leave(citizen.satisfaction):
			if candidate == null or citizen.satisfaction < candidate.satisfaction:
				candidate = citizen
	if candidate == null:
		return
	var non_hero_count := 0
	for citizen in simulation.citizens:
		if is_instance_valid(citizen) and not citizen.is_hero:
			non_hero_count += 1
	if non_hero_count <= 1:
		simulation._add_message("Despite the hardship, your loyal companion stays and believes you will fix things.")
		return
	if is_instance_valid(simulation.entrance_stone):
		candidate.remove_meta("leave_at_morning")
		candidate.begin_leaving(simulation.entrance_stone.global_position)
		simulation._add_message("%s has decided to leave the settlement (satisfaction %d)." % [candidate.role_label(), int(candidate.satisfaction)])


func apply_hourly_work_fatigue() -> void:
	var settlement: SettlementState = simulation.settlement
	var day_cycle: SimulationDayCycle = simulation.day_cycle
	var clock: SimulationClock = simulation.clock
	var double_time_active := settlement.double_time_order_day == day_cycle.current_day
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen) or citizen.is_player_controlled:
			continue
		if citizen.is_recovering(day_cycle.current_day):
			citizen.fatigue = maxf(0.0, citizen.fatigue - 18.0)
			continue
		if simulation._is_citizen_work_time(citizen) and not citizen.active_role.is_empty():
			var overtime: bool = citizen.has_active_overtime(day_cycle.current_day)
			citizen.continuous_work_hours += 1.0
			var fatigue_gain := (6.0 if overtime else 2.0) + maxf(0.0, settlement.workday_hours - 8) * 0.75
			if double_time_active:
				fatigue_gain *= 1.5
			citizen.fatigue = minf(100.0, citizen.fatigue + fatigue_gain)
			if overtime:
				citizen.satisfaction = maxf(0.0, citizen.satisfaction - 2.0)
			elif settlement.workday_hours < 8:
				citizen.satisfaction = minf(citizen.get_satisfaction_cap(), citizen.satisfaction + 0.6)
			elif settlement.workday_hours > 8:
				var long_day_penalty := pow(float(settlement.workday_hours - 8), 1.25) * 0.22
				citizen.satisfaction = maxf(0.0, citizen.satisfaction - long_day_penalty)
			if double_time_active and not overtime:
				citizen.satisfaction = maxf(0.0, citizen.satisfaction - 1.0)
		elif simulation._is_work_time():
			citizen.continuous_work_hours = maxf(0.0, citizen.continuous_work_hours - 3.0)
			citizen.fatigue = maxf(0.0, citizen.fatigue - 4.0)
	if clock.hour() == 6:
		resolve_exhausted_homecomings()


func resolve_exhausted_homecomings() -> void:
	var day_cycle: SimulationDayCycle = simulation.day_cycle
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen) or not citizen.is_dangerously_tired():
			continue
		var food_factor := 0.15 if citizen.hunger >= 60.0 else -0.10
		var distance_factor := 0.0 if not is_instance_valid(citizen.home) else clampf(citizen.global_position.distance_to(citizen.home.global_position) / 120.0, 0.0, 0.25)
		var risk := clampf(0.15 + citizen.fatigue / 160.0 + distance_factor + food_factor, 0.0, 0.90)
		if simulation.random.randf() < risk:
			citizen.recovery_until_workday_id = day_cycle.current_day
			citizen.continuous_work_hours = 0.0
			citizen.fatigue = maxf(35.0, citizen.fatigue - 25.0)
			citizen.end_work_shift()
			simulation._add_message("%s collapsed from exhaustion and will recover at home today." % citizen.role_label())
