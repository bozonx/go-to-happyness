class_name SettlementDailyRulesService
extends RefCounted

## Orchestrates the daily settlement update: trail decay, smoky eyes status,
## citizen daily decay, building wear, open-air storage decay, resource pile
## decay, daily food/water consumption, wellbeing change, campfire story
## effects, departures, and resource warnings.

const SETTLEMENT_RULES = preload("res://game/features/settlement/domain/settlement_rules.gd")
const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")
const CitizenStatusEffectScript = preload("res://game/features/citizens/domain/citizen_status_effect.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var _settlement: SettlementState
var _day_cycle: SimulationDayCycle
var _citizens: Array = []
var _trail_field: Variant
var _event_service_getter: Callable
var _citizen_needs_service: Variant
var _canteen_getter: Callable
var _tent_weather_getter: Callable
var _add_message: Callable
var _update_interface: Callable
var _apply_building_wear_and_repairs: Callable
var _decay_resource_piles: Callable
var _total_housing_slots: Callable
var _check_daily_departures: Callable
var _stored_resources: Callable
var _warehouse_capacity: Callable


func configure(
	p_settlement: SettlementState,
	p_day_cycle: SimulationDayCycle,
	p_citizens: Array,
	p_trail_field: Variant,
	p_event_service_getter: Callable,
	p_citizen_needs_service: Variant,
	p_canteen_getter: Callable,
	p_tent_weather_getter: Callable,
	p_add_message: Callable,
	p_update_interface: Callable,
	p_apply_building_wear_and_repairs: Callable,
	p_decay_resource_piles: Callable,
	p_total_housing_slots: Callable,
	p_check_daily_departures: Callable,
	p_stored_resources: Callable,
	p_warehouse_capacity: Callable
) -> void:
	_settlement = p_settlement
	_day_cycle = p_day_cycle
	_citizens = p_citizens
	_trail_field = p_trail_field
	_event_service_getter = p_event_service_getter
	_citizen_needs_service = p_citizen_needs_service
	_canteen_getter = p_canteen_getter
	_tent_weather_getter = p_tent_weather_getter
	_add_message = p_add_message
	_update_interface = p_update_interface
	_apply_building_wear_and_repairs = p_apply_building_wear_and_repairs
	_decay_resource_piles = p_decay_resource_piles
	_total_housing_slots = p_total_housing_slots
	_check_daily_departures = p_check_daily_departures
	_stored_resources = p_stored_resources
	_warehouse_capacity = p_warehouse_capacity


func apply_daily_settlement_rules() -> void:
	if _trail_field != null:
		_trail_field.apply_daily_decay()
	var event_service: Variant = _event_service_getter.call()
	var _is_smoky: bool = event_service != null and event_service.log.has_flag(&"smoky_firewood")
	if _is_smoky:
		for citizen in _citizens:
			if is_instance_valid(citizen):
				citizen.set_status_effect(CitizenStatusEffectScript.SMOKY_EYES, "Smoky eyes", 1.0, -1.0)
	else:
		for citizen in _citizens:
			if is_instance_valid(citizen):
				citizen.clear_status_effect(CitizenStatusEffectScript.SMOKY_EYES)
	var population: int = _citizens.size()
	if population == 0:
		return
	for citizen in _citizens:
		citizen.apply_daily_decay()
	if _citizen_needs_service != null:
		_citizen_needs_service.schedule_daily_toilets(_citizens)
	_apply_building_wear_and_repairs.call()

	# Heap (Open-Air) Storage decay:
	var straw_warehouse_count := int(_settlement.buildings.get("straw_warehouse", 0))
	var tarp_warehouse_count := int(_settlement.buildings.get("tarp_warehouse", 0))
	var safe_capacity := straw_warehouse_count * 48.0 + tarp_warehouse_count * 72.0
	var total_stored := _settlement.storage_used_units()
	var decay_losses := SETTLEMENT_RULES.open_air_storage_decay_losses({
	"food": _settlement.amount(ResourceIds.FOOD),
		"grass": _settlement.amount(ResourceIds.GRASS),
		"branches": _settlement.amount(ResourceIds.BRANCHES),
		"wood": _settlement.amount(ResourceIds.WOOD),
		"logs": _settlement.amount(ResourceIds.LOGS),
	}, total_stored, safe_capacity)
	if not decay_losses.is_empty():
		var decay_msg := ""
		for res in decay_losses:
			var lost := int(decay_losses[res])
			_settlement.add(res, -lost)
			if decay_msg.is_empty():
				decay_msg = "Daily decay: lost "
			else:
				decay_msg += ", "
			decay_msg += "%d %s" % [lost, res]
		if not decay_msg.is_empty():
			decay_msg += " due to open-air Heap storage."
			_add_message.call(decay_msg)
			_update_interface.call(decay_msg)

	_decay_resource_piles.call()
	# Everyone drinks each day. When there is no kitchen running meals, they also
	# eat straight from the stores; a working cooking campfire/canteen already
	# draws food through the meal pipeline, so we don't double-count there.
	_settlement.add(ResourceIds.WATER, -population)
	var canteen: Node3D = _canteen_getter.call()
	if not is_instance_valid(canteen):
		_settlement.add(ResourceIds.FOOD, -TentEraSurvivalRulesScript.daily_food_consumption(population, _tent_weather_getter.call()))
	var housing: int = _total_housing_slots.call()
	var change := SETTLEMENT_RULES.daily_wellbeing_change(housing >= population, float(_settlement.amount(ResourceIds.FOOD)) / population, float(_settlement.amount(ResourceIds.WATER)) / population, _settlement.workday_hours)
	_settlement.wellbeing = clampi(_settlement.wellbeing + change, 0, 100)
	# Campfire story effects are resolved at dawn.
	match _settlement.campfire_story_effect:
		"optimistic":
			_settlement.wellbeing = mini(100, _settlement.wellbeing + 10)
			_add_message.call("The optimistic stories lifted spirits. Wellbeing recovered an extra 10.")
		"teaching":
			if not _citizens.is_empty():
				var pupil: Citizen = _citizens.pick_random()
				var physical_skills := ["construction", "forestry", "farming", "excavation", "factory_worker", "craftsman"]
				var skill: String = physical_skills.pick_random()
				pupil.skills[skill] = minf(1.0, float(pupil.skills.get(skill, 0.0)) + 0.1)
				_add_message.call("Teaching tales helped %s learn a little %s." % [pupil.role_label(), skill.capitalize()])
		"plan":
			_add_message.call("The plan for tomorrow focuses on %s." % _settlement.campfire_story_target_role.capitalize())
	if _settlement.campfire_story_effect != "plan" or _day_cycle.current_day > _settlement.campfire_story_target_day:
		_settlement.campfire_story_effect = ""
		_settlement.campfire_story_target_role = ""
		_settlement.campfire_story_target_day = -1
	_check_daily_departures.call()
	# --- Daily settlement warnings ---
	if _settlement.amount(ResourceIds.FOOD) == 0:
		_add_message.call("CRITICAL: Food supplies exhausted! Workers are starving.")
	elif float(_settlement.amount(ResourceIds.FOOD)) / population < 1.0:
		_add_message.call("Warning: Food is running low (%d for %d people)." % [_settlement.amount(ResourceIds.FOOD), population])
	if _settlement.amount(ResourceIds.WATER) == 0:
		_add_message.call("CRITICAL: Water supplies exhausted! Settlement is dehydrated.")
	elif float(_settlement.amount(ResourceIds.WATER)) / population < 1.0:
		_add_message.call("Warning: Water is running low (%d for %d people)." % [_settlement.amount(ResourceIds.WATER), population])
	var storage_ratio := float(_stored_resources.call()) / float(maxi(1, _warehouse_capacity.call()))
	if storage_ratio >= 0.95:
		_add_message.call("CRITICAL: Storage nearly full (%d%%). Build another warehouse or rebalance." % [int(storage_ratio * 100)])
	elif storage_ratio >= 0.80:
		_add_message.call("Warning: Storage filling up (%d%% used)." % [int(storage_ratio * 100)])
	if _settlement.wellbeing < 30:
		_add_message.call("Warning: Low wellbeing (%d). Unhappiness is accumulating — residents may leave!" % _settlement.wellbeing)
	elif change < 0:
		_add_message.call("Wellbeing is declining (change: %d). Consider improving living conditions." % change)


func set_campfire_story(story_id: String, next_day: int) -> void:
	if _settlement == null:
		return
	_settlement.campfire_story_effect = story_id
	if story_id == "plan":
		var roles: Array[String] = ["gather_branches", "gather_grass", "gather_food", "gather_water"]
		_settlement.campfire_story_target_role = roles.pick_random()
		_settlement.campfire_story_target_day = next_day
