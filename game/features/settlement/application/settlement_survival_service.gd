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
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var _settlement: SettlementState
var _day_cycle: SimulationDayCycle
var _clock: SimulationClock
var _citizens: Array = []
var _random: RandomNumberGenerator
## The environment as of this frame (`world_environment.md` §2). The survival
## rules read it; they never hold a weather object of their own.
var _environment_getter: Callable
var _building_registry: Variant
var _fire_management_service: Variant
var _tent_weather_getter: Callable
var _entrance_stone_getter: Callable
var _event_service_getter: Callable
var _has_lit_communal_fire: Callable
var _add_message: Callable
var _is_citizen_work_time: Callable
var _is_work_time: Callable

var last_survival_hour := -1
var last_zero_wellbeing_departure_day := -1
var is_skipping_night := false
var skip_zero_wellbeing_departure_applied := false


func configure(port: SettlementSurvivalRuntimePort) -> void:
	_settlement = port.settlement
	_day_cycle = port.day_cycle
	_clock = port.clock
	_citizens = port.citizens
	_random = port.random
	_environment_getter = port.environment_getter
	_building_registry = port.building_registry
	_fire_management_service = port.fire_management_service
	_tent_weather_getter = port.tent_weather_getter
	_entrance_stone_getter = port.entrance_stone_getter
	_event_service_getter = port.event_service_getter
	_has_lit_communal_fire = port.has_lit_communal_fire
	_add_message = port.add_message
	_is_citizen_work_time = port.is_citizen_work_time
	_is_work_time = port.is_work_time


func apply_hourly_tent_survival(hour: int, survival_day := 0) -> void:
	var day := _day_cycle.current_day if survival_day <= 0 else survival_day
	var survival_hour := day * 24 + hour
	if _settlement.era != SettlementStateScript.Era.TENT or last_survival_hour == survival_hour:
		return
	last_survival_hour = survival_hour
	var night := hour >= 22 or hour < 6
	var has_fire: bool = _has_lit_communal_fire.call()
	var total_loss := 0
	for citizen in _citizens:
		if not is_instance_valid(citizen):
			continue
		var has_home := is_instance_valid(citizen.home)
		total_loss += TentEraSurvivalRulesScript.hourly_wellbeing_loss(has_home, has_fire, _tent_weather_getter.call(), night)
	if total_loss > 0:
		_settlement.wellbeing = maxi(0, _settlement.wellbeing - ceili(float(total_loss) / maxi(1, _citizens.size())))
	if _settlement.wellbeing == 0 and last_zero_wellbeing_departure_day != day and (not is_skipping_night or not skip_zero_wellbeing_departure_applied):
		last_zero_wellbeing_departure_day = day
		skip_zero_wellbeing_departure_applied = true
		_trigger_zero_wellbeing_departure()
	if hour > 0 and _is_precipitating():
		apply_rain_damage()


func _trigger_zero_wellbeing_departure() -> void:
	var candidate: Citizen = null
	for citizen in _citizens:
		if not is_instance_valid(citizen) or citizen.is_hero or citizen.state == Citizen.State.LEAVING:
			continue
		if candidate == null or citizen.satisfaction < candidate.satisfaction:
			candidate = citizen
	var entrance_stone: Node3D = _entrance_stone_getter.call()
	if candidate == null or not is_instance_valid(entrance_stone):
		return
	var non_hero_count := 0
	for citizen in _citizens:
		if is_instance_valid(citizen) and not citizen.is_hero:
			non_hero_count += 1
	if non_hero_count <= SETTLEMENT_RULES.MIN_SETTLEMENT_POPULATION - 1:
		return
	candidate.set_meta("leave_at_morning", true)
	_add_message.call("%s will leave at dawn after the settlement's wellbeing collapsed." % candidate.role_label())


func apply_rain_damage() -> void:
	var sheltered_capacity := int(_settlement.buildings.get("straw_warehouse", 0)) * 48 + int(_settlement.buildings.get("tarp_warehouse", 0)) * 72
	if _settlement.warehouse_tarp_covered:
		sheltered_capacity += 24
	var stored_units := _settlement.storage_used_units()
	if stored_units <= sheltered_capacity:
		return
	var exposed_ratio := (stored_units - sheltered_capacity) / stored_units
	var event_service: Variant = _event_service_getter.call()
	var _firewood_protected: bool = event_service != null and event_service.log.has_flag(&"firewood_protected_today")
	var rain_amounts := {
		ResourceIds.FOOD: _settlement.amount(ResourceIds.FOOD),
		ResourceIds.GRASS: _settlement.amount(ResourceIds.GRASS),
		ResourceIds.BRANCHES: 0 if _firewood_protected else _settlement.amount(ResourceIds.BRANCHES),
		ResourceIds.WOOD: _settlement.amount(ResourceIds.WOOD),
		ResourceIds.LOGS: _settlement.amount(ResourceIds.LOGS),
	}
	var losses := TentEraSurvivalRulesScript.rain_hourly_decay_losses(rain_amounts, exposed_ratio)
	for resource_type in losses:
		_settlement.add(resource_type, -int(losses[resource_type]))
	for record in _building_registry.records():
		var building: Node3D = record.node
		if is_instance_valid(building) and _fire_management_service.is_managed_fire_source(building):
			var fire_state: RefCounted = _fire_management_service.fire_state_for(building)
			fire_state.lit = false
			_fire_management_service.apply_fire_state(building, fire_state)


func check_daily_departures() -> void:
	for citizen in _citizens:
		if not is_instance_valid(citizen) or citizen.is_hero:
			continue
		if SETTLEMENT_RULES.is_satisfaction_warning(citizen.satisfaction):
			_add_message.call("Warning: %s is unhappy (satisfaction %d). They may leave if conditions don't improve." % [citizen.role_label(), int(citizen.satisfaction)])
	var candidate: Citizen = null
	for citizen in _citizens:
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
	for citizen in _citizens:
		if is_instance_valid(citizen) and not citizen.is_hero:
			non_hero_count += 1
	if non_hero_count <= 1:
		_add_message.call("Despite the hardship, your loyal companion stays and believes you will fix things.")
		return
	var entrance_stone: Node3D = _entrance_stone_getter.call()
	if is_instance_valid(entrance_stone):
		candidate.remove_meta("leave_at_morning")
		candidate.begin_leaving(entrance_stone.global_position)
		_add_message.call("%s has decided to leave the settlement (satisfaction %d)." % [candidate.role_label(), int(candidate.satisfaction)])


func apply_hourly_work_fatigue() -> void:
	var double_time_active := _settlement.double_time_order_day == _day_cycle.current_day
	for citizen in _citizens:
		if not is_instance_valid(citizen) or citizen.is_player_controlled:
			continue
		if citizen.is_recovering(_day_cycle.current_day):
			citizen.fatigue = maxf(0.0, citizen.fatigue - 18.0)
			continue
		if _is_citizen_work_time.call(citizen) and not citizen.active_role.is_empty():
			var overtime: bool = citizen.has_active_overtime(_day_cycle.current_day)
			citizen.continuous_work_hours += 1.0
			var fatigue_gain := (6.0 if overtime else 2.0) + maxf(0.0, _settlement.workday_hours - 8) * 0.75
			if double_time_active:
				fatigue_gain *= 1.5
			citizen.fatigue = minf(100.0, citizen.fatigue + fatigue_gain)
			if overtime:
				citizen.satisfaction = maxf(0.0, citizen.satisfaction - 2.0)
			elif _settlement.workday_hours < 8:
				citizen.satisfaction = minf(citizen.get_satisfaction_cap(), citizen.satisfaction + 0.6)
			elif _settlement.workday_hours > 8:
				var long_day_penalty := pow(float(_settlement.workday_hours - 8), 1.25) * 0.22
				citizen.satisfaction = maxf(0.0, citizen.satisfaction - long_day_penalty)
			if double_time_active and not overtime:
				citizen.satisfaction = maxf(0.0, citizen.satisfaction - 1.0)
		elif _is_work_time.call():
			citizen.continuous_work_hours = maxf(0.0, citizen.continuous_work_hours - 3.0)
			citizen.fatigue = maxf(0.0, citizen.fatigue - 4.0)
	if _clock.hour() == 6:
		resolve_exhausted_homecomings()


func resolve_exhausted_homecomings() -> void:
	for citizen in _citizens:
		if not is_instance_valid(citizen) or not citizen.is_dangerously_tired():
			continue
		var food_factor := 0.15 if citizen.hunger >= 60.0 else -0.10
		var distance_factor := 0.0 if not is_instance_valid(citizen.home) else clampf(citizen.global_position.distance_to(citizen.home.global_position) / 120.0, 0.0, 0.25)
		var risk := clampf(0.15 + citizen.fatigue / 160.0 + distance_factor + food_factor, 0.0, 0.90)
		if _random.randf() < risk:
			citizen.recovery_until_workday_id = _day_cycle.current_day
			citizen.continuous_work_hours = 0.0
			citizen.fatigue = maxf(35.0, citizen.fatigue - 25.0)
			citizen.end_work_shift()
			_add_message.call("%s collapsed from exhaustion and will recover at home today." % citizen.role_label())


## Precipitation soaks stores whatever form it takes: a wet snowfall ruins a hide
## the same way rain does.
func _is_precipitating() -> bool:
	if not _environment_getter.is_valid():
		return false
	var snapshot: EnvironmentSnapshot = _environment_getter.call()
	return snapshot != null and snapshot.is_precipitating()
