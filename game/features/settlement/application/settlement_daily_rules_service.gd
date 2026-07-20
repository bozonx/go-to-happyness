class_name SettlementDailyRulesService
extends RefCounted

## Orchestrates the daily settlement update: trail decay, smoky eyes status,
## citizen daily decay, building wear, open-air storage decay, resource pile
## decay, daily food/water consumption, wellbeing change, campfire story
## effects, departures, and resource warnings.

const SETTLEMENT_RULES = preload("res://game/features/settlement/domain/settlement_rules.gd")
const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")
const CitizenStatusEffectScript = preload("res://game/features/citizens/domain/citizen_status_effect.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func apply_daily_settlement_rules() -> void:
	if simulation.trail_field != null:
		simulation.trail_field.apply_daily_decay()
	var _is_smoky: bool = simulation.event_service != null and simulation.event_service.log.has_flag(&"smoky_firewood")
	if _is_smoky:
		for citizen in simulation.citizens:
			if is_instance_valid(citizen):
				citizen.set_status_effect(CitizenStatusEffectScript.SMOKY_EYES, "Smoky eyes", 1.0, -1.0)
	else:
		for citizen in simulation.citizens:
			if is_instance_valid(citizen):
				citizen.clear_status_effect(CitizenStatusEffectScript.SMOKY_EYES)
	var population: int = simulation.citizens.size()
	if population == 0:
		return
	for citizen in simulation.citizens:
		citizen.apply_daily_decay()
	if simulation.citizen_needs_service != null:
		simulation.citizen_needs_service.schedule_daily_toilets(simulation.citizens)
	simulation._apply_building_wear_and_repairs()

	# Heap (Open-Air) Storage decay:
	var settlement: SettlementState = simulation.settlement
	var straw_warehouse_count := int(settlement.buildings.get("straw_warehouse", 0))
	var tarp_warehouse_count := int(settlement.buildings.get("tarp_warehouse", 0))
	var safe_capacity := straw_warehouse_count * 48.0 + tarp_warehouse_count * 72.0
	var total_stored := settlement.storage_used_units()
	var decay_losses := SETTLEMENT_RULES.open_air_storage_decay_losses({
		"food": simulation.food,
		"grass": simulation.grass,
		"branches": simulation.branches,
		"wood": simulation.wood,
		"logs": settlement.logs,
	}, total_stored, safe_capacity)
	if not decay_losses.is_empty():
		var decay_msg := ""
		for res in decay_losses:
			var lost := int(decay_losses[res])
			settlement.add(res, -lost)
			if decay_msg.is_empty():
				decay_msg = "Daily decay: lost "
			else:
				decay_msg += ", "
			decay_msg += "%d %s" % [lost, res]
		if not decay_msg.is_empty():
			decay_msg += " due to open-air Heap storage."
			simulation._add_message(decay_msg)
			simulation._update_interface(decay_msg)

	simulation._decay_resource_piles()
	# Everyone drinks each day. When there is no kitchen running meals, they also
	# eat straight from the stores; a working cooking campfire/canteen already
	# draws food through the meal pipeline, so we don't double-count there.
	settlement.add("water", -population)
	if not is_instance_valid(simulation.canteen):
		settlement.add("food", -TentEraSurvivalRulesScript.daily_food_consumption(population, simulation.tent_weather))
	var housing: int = simulation._total_housing_slots()
	var change := SETTLEMENT_RULES.daily_wellbeing_change(housing >= population, float(simulation.food) / population, float(simulation.water) / population, settlement.workday_hours)
	simulation.wellbeing = clampi(simulation.wellbeing + change, 0, 100)
	# Campfire story effects are resolved at dawn.
	match settlement.campfire_story_effect:
		"optimistic":
			simulation.wellbeing = mini(100, simulation.wellbeing + 10)
			simulation._add_message("The optimistic stories lifted spirits. Wellbeing recovered an extra 10.")
		"teaching":
			if not simulation.citizens.is_empty():
				var pupil: Citizen = simulation.citizens.pick_random()
				var physical_skills := ["construction", "forestry", "farming", "excavation", "factory_worker", "craftsman"]
				var skill: String = physical_skills.pick_random()
				pupil.skills[skill] = minf(1.0, float(pupil.skills.get(skill, 0.0)) + 0.1)
				simulation._add_message("Teaching tales helped %s learn a little %s." % [pupil.role_label(), skill.capitalize()])
		"plan":
			simulation._add_message("The plan for tomorrow focuses on %s." % settlement.campfire_story_target_role.capitalize())
	if settlement.campfire_story_effect != "plan" or simulation.day_cycle.current_day > settlement.campfire_story_target_day:
		settlement.campfire_story_effect = ""
		settlement.campfire_story_target_role = ""
		settlement.campfire_story_target_day = -1
	simulation._check_daily_departures()
	# --- Daily settlement warnings ---
	if simulation.food == 0:
		simulation._add_message("CRITICAL: Food supplies exhausted! Workers are starving.")
	elif float(simulation.food) / population < 1.0:
		simulation._add_message("Warning: Food is running low (%d for %d people)." % [simulation.food, population])
	if simulation.water == 0:
		simulation._add_message("CRITICAL: Water supplies exhausted! Settlement is dehydrated.")
	elif float(simulation.water) / population < 1.0:
		simulation._add_message("Warning: Water is running low (%d for %d people)." % [simulation.water, population])
	var storage_ratio := float(simulation._stored_resources()) / float(maxi(1, simulation._warehouse_capacity()))
	if storage_ratio >= 0.95:
		simulation._add_message("CRITICAL: Storage nearly full (%d%%). Build another warehouse or rebalance." % [int(storage_ratio * 100)])
	elif storage_ratio >= 0.80:
		simulation._add_message("Warning: Storage filling up (%d%% used)." % [int(storage_ratio * 100)])
	if simulation.wellbeing < 30:
		simulation._add_message("Warning: Low wellbeing (%d). Unhappiness is accumulating — residents may leave!" % simulation.wellbeing)
	elif change < 0:
		simulation._add_message("Wellbeing is declining (change: %d). Consider improving living conditions." % change)
