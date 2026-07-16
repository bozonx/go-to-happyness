class_name TentEraEvents
extends RefCounted

## Data-driven definitions of all tent-era random events.
## Returns an array of GameEventDef via the static build() method.

const SettlementStateScript = preload("res://game/features/settlement/domain/settlement_state.gd")
const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")
const EventDef = preload("res://game/features/events/domain/game_event_def.gd")
const EventChoice = preload("res://game/features/events/domain/event_choice_def.gd")
const EventOutcome = preload("res://game/features/events/domain/event_outcome.gd")
const EventCondition = preload("res://game/features/events/domain/event_condition.gd")


static func build() -> Array[GameEventDef]:
	var defs: Array[GameEventDef] = []
	defs.append(_protect_firewood())
	defs.append(_forest_gifts())
	defs.append(_traveler())
	defs.append(_lost_child())
	defs.append(_strange_illness())
	defs.append(_wild_boars())
	defs.append(_forest_ranger())
	defs.append(_refugees())
	defs.append(_strange_light())
	defs.append(_broken_tools())
	defs.append(_tainted_water())
	defs.append(_forest_cache())
	return defs


# --- Existing events (ported from hardcoded logic) -----------------------------

static func _protect_firewood() -> GameEventDef:
	var conditions: Array[EventCondition] = [
		EventCondition.era_is(SettlementStateScript.Era.TENT),
		EventCondition.weather_is(TentEraSurvivalRulesScript.Weather.RAIN),
		EventCondition.resource_at_least("branches", 1),
	]
	var choices: Array[EventChoiceDef] = [
		EventChoice.create(
			"Assign a resident to protect the firewood",
			[
				EventOutcome.worker_busy(3.0, "Protecting firewood"),
				EventOutcome.set_flag(&"firewood_protected_today"),
				EventOutcome.message("A resident is protecting the firewood from rain."),
			],
		),
		EventChoice.create(
			"Ignore the risk",
			[
				EventOutcome.delayed(1, EventOutcome.set_flag(&"smoky_firewood")),
				EventOutcome.message("The firewood was left exposed and will smoke tomorrow."),
			],
		),
	]
	return EventDef.create(
		&"protect_firewood", "Threat of wet firewood",
		"The open storage will be soaked by rain. Protect the branch supply for three hours, or keep everyone working and risk smoky fires tomorrow.",
		SettlementStateScript.Era.TENT, choices, conditions,
		1.0, 1,
	)


static func _forest_gifts() -> GameEventDef:
	var conditions: Array[EventCondition] = [
		EventCondition.era_is(SettlementStateScript.Era.TENT),
		EventCondition.day_at_least(2),
	]
	var try_outcomes: Array[EventOutcome] = [
		EventOutcome.wellbeing(20),
		EventOutcome.message("The berries were safe. Wellbeing rose by 20."),
	]
	var fail_outcomes: Array[EventOutcome] = [
		EventOutcome.worker_busy(24.0, "Poisoned"),
		EventOutcome.message("The berries were poisonous. One resident cannot work for 24 hours."),
	]
	var random_outcome := EventOutcome.new()
	random_outcome.kind = EventOutcome.Kind.MESSAGE
	random_outcome.random_chance = 0.5
	random_outcome.random_outcomes = try_outcomes + fail_outcomes
	var choices: Array[EventChoiceDef] = [
		EventChoice.create("Try the berries", [random_outcome]),
		EventChoice.create("Discard them", [EventOutcome.message("The unknown berries were discarded.")]),
	]
	return EventDef.create(
		&"forest_gifts", "Unknown forest gifts",
		"Foragers found unfamiliar berries. They may lift the camp's spirits or poison one resident for a day.",
		SettlementStateScript.Era.TENT, choices, conditions,
		1.0, 3,
	)


static func _traveler() -> GameEventDef:
	var conditions: Array[EventCondition] = [
		EventCondition.era_is(SettlementStateScript.Era.TENT),
		EventCondition.resource_at_least("food", 3),
		EventCondition.resource_at_least("water", 2),
		EventCondition.day_at_least(3),
	]
	var choices: Array[EventChoiceDef] = [
		EventChoice.create(
			"Trade",
			[
				EventOutcome.resource_change("food", -3),
				EventOutcome.resource_change("water", -2),
				EventOutcome.resource_change("tarp", 1),
				EventOutcome.message("Traded 3 food and 2 water for a tarp roll."),
			],
		),
		EventChoice.create("Send away", [EventOutcome.message("The traveler left without trading.")]),
	]
	return EventDef.create(
		&"traveler", "Wandering traveler",
		"A lost tourist will trade a tarp roll for 3 food and 2 water.",
		SettlementStateScript.Era.TENT, choices, conditions,
		0.8, 4,
	)


# --- New events ----------------------------------------------------------------

static func _lost_child() -> GameEventDef:
	var conditions: Array[EventCondition] = [
		EventCondition.era_is(SettlementStateScript.Era.TENT),
		EventCondition.day_at_least(3),
		EventCondition.population_at_least(3),
	]
	var choices: Array[EventChoiceDef] = [
		EventChoice.create(
			"Take them in",
			[
				EventOutcome.wellbeing(10),
				EventOutcome.resource_change("food", -2),
				EventOutcome.message("The child joined the settlement. Wellbeing rose by 10."),
			],
		),
		EventChoice.create(
			"Send them away",
			[
				EventOutcome.wellbeing(-15),
				EventOutcome.message("The child was sent away. The camp feels colder."),
			],
		),
	]
	return EventDef.create(
		&"lost_child", "Lost child",
		"A child was found wandering near the road. They say their parents went foraging days ago and never came back.",
		SettlementStateScript.Era.TENT, choices, conditions,
		0.7, 5,
	)


static func _strange_illness() -> GameEventDef:
	var conditions: Array[EventCondition] = [
		EventCondition.era_is(SettlementStateScript.Era.TENT),
		EventCondition.day_at_least(4),
		EventCondition.population_at_least(3),
	]
	var ignore_random := EventOutcome.new()
	ignore_random.kind = EventOutcome.Kind.MESSAGE
	ignore_random.random_chance = 0.5
	ignore_random.random_outcomes = [
		EventOutcome.worker_busy(48.0, "Sick"),
		EventOutcome.worker_busy(48.0, "Sick"),
		EventOutcome.message("It was just a mild cold. Everyone recovered."),
		EventOutcome.message("It was just a mild cold. Everyone recovered."),
	]
	var choices: Array[EventChoiceDef] = [
		EventChoice.create(
			"Quarantine them",
			[
				EventOutcome.worker_busy(48.0, "Quarantined"),
				EventOutcome.wellbeing(-5),
				EventOutcome.message("The sick resident is quarantined for two days."),
			],
		),
		EventChoice.create("Ignore it", [ignore_random]),
		EventChoice.create(
			"Use the last medicine",
			[
				EventOutcome.resource_change("goods", -1),
				EventOutcome.wellbeing(5),
				EventOutcome.message("The medicine worked. The resident recovered quickly."),
			],
		),
	]
	return EventDef.create(
		&"strange_illness", "Strange illness",
		"One of the residents woke up with a fever and red spots. It could be contagious.",
		SettlementStateScript.Era.TENT, choices, conditions,
		0.6, 6,
	)


static func _wild_boars() -> GameEventDef:
	var conditions: Array[EventCondition] = [
		EventCondition.era_is(SettlementStateScript.Era.TENT),
		EventCondition.flag_set(&"boar_warning"),
	]
	var chase_random := EventOutcome.new()
	chase_random.kind = EventOutcome.Kind.MESSAGE
	chase_random.random_chance = 0.7
	chase_random.random_outcomes = [
		EventOutcome.message("Residents chased the boars away."),
		EventOutcome.message("Residents chased the boars away."),
		EventOutcome.resource_change("food", -2),
		EventOutcome.message("The boars got some food before being chased off."),
	]
	var choices: Array[EventChoiceDef] = [
		EventChoice.create(
			"Chase them off",
			[
				EventOutcome.worker_busy(6.0, "Chasing boars"),
				chase_random,
			],
		),
		EventChoice.create(
			"Let them take what they want",
			[
				EventOutcome.resource_change("food", -4),
				EventOutcome.message("The boars raided the storage and left."),
			],
		),
	]
	return EventDef.create(
		&"wild_boars", "Wild boars",
		"A pack of wild boars is raiding the food storage!",
		SettlementStateScript.Era.TENT, choices, conditions,
		1.5, 5,
		&"boar_warning",
	)


static func _forest_ranger() -> GameEventDef:
	var conditions: Array[EventCondition] = [
		EventCondition.era_is(SettlementStateScript.Era.TENT),
		EventCondition.day_at_least(5),
	]
	var choices: Array[EventChoiceDef] = [
		EventChoice.create(
			"Trade and heed the warning",
			[
				EventOutcome.resource_change("food", -1),
				EventOutcome.set_flag(&"boar_warning"),
				EventOutcome.message("The ranger traded and warned about boars nearby."),
			],
		),
		EventChoice.create(
			"Just listen",
			[
				EventOutcome.set_flag(&"boar_warning"),
				EventOutcome.message("The ranger warned about boars. No trade was made."),
			],
		),
		EventChoice.create(
			"Ignore him",
			[EventOutcome.message("The ranger left. You dismissed his warning.")],
		),
	]
	return EventDef.create(
		&"forest_ranger", "Forest ranger",
		"A forest ranger passes by. He warns that boar tracks were seen near the camp. He also offers to trade.",
		SettlementStateScript.Era.TENT, choices, conditions,
		0.8, 7,
	)


static func _refugees() -> GameEventDef:
	var conditions: Array[EventCondition] = [
		EventCondition.era_is(SettlementStateScript.Era.TENT),
		EventCondition.day_at_least(6),
		EventCondition.resource_at_most("food", 999),
	]
	var choices: Array[EventChoiceDef] = [
		EventChoice.create(
			"Welcome them",
			[
				EventOutcome.resource_change("food", -4),
				EventOutcome.wellbeing(8),
				EventOutcome.message("The refugees joined the settlement. Population increased."),
			],
		),
		EventChoice.create(
			"Turn them away",
			[
				EventOutcome.wellbeing(-10),
				EventOutcome.message("The refugees were turned away. Some residents feel guilty."),
			],
		),
	]
	return EventDef.create(
		&"refugees", "Refugees",
		"A small family of refugees asks to join the settlement. They look hungry but willing to work.",
		SettlementStateScript.Era.TENT, choices, conditions,
		0.6, 8,
	)


static func _strange_light() -> GameEventDef:
	var conditions: Array[EventCondition] = [
		EventCondition.era_is(SettlementStateScript.Era.TENT),
		EventCondition.day_at_least(4),
	]
	var investigate_random := EventOutcome.new()
	investigate_random.kind = EventOutcome.Kind.MESSAGE
	investigate_random.random_chance = 0.6
	investigate_random.random_outcomes = [
		EventOutcome.resource_change("goods", 2),
		EventOutcome.message("The search party found abandoned supplies."),
		EventOutcome.worker_busy(24.0, "Lost"),
		EventOutcome.message("The investigator got lost and took a day to return."),
	]
	var choices: Array[EventChoiceDef] = [
		EventChoice.create("Investigate", [EventOutcome.worker_busy(12.0, "Investigating"), investigate_random]),
		EventChoice.create("Ignore it", [EventOutcome.message("The light faded by morning. Nothing happened.")]),
	]
	return EventDef.create(
		&"strange_light", "Strange light",
		"During the night, a strange pulsing light was seen in the forest. It might be worth investigating.",
		SettlementStateScript.Era.TENT, choices, conditions,
		0.7, 5,
	)


static func _broken_tools() -> GameEventDef:
	var conditions: Array[EventCondition] = [
		EventCondition.era_is(SettlementStateScript.Era.TENT),
		EventCondition.day_at_least(5),
		EventCondition.resource_at_least("branches", 2),
	]
	var choices: Array[EventChoiceDef] = [
		EventChoice.create(
			"Repair it",
			[
				EventOutcome.worker_busy(4.0, "Repairing tools"),
				EventOutcome.resource_change("branches", -2),
				EventOutcome.message("The tool was repaired with branches and effort."),
			],
		),
		EventChoice.create(
			"Work without it",
			[
				EventOutcome.wellbeing(-5),
				EventOutcome.message("Work continues without the tool. Morale dropped slightly."),
			],
		),
	]
	return EventDef.create(
		&"broken_tools", "Broken tools",
		"A tool broke during work. It can be repaired, but it will take time and materials.",
		SettlementStateScript.Era.TENT, choices, conditions,
		0.6, 6,
	)


static func _tainted_water() -> GameEventDef:
	var conditions: Array[EventCondition] = [
		EventCondition.era_is(SettlementStateScript.Era.TENT),
		EventCondition.day_at_least(4),
		EventCondition.resource_at_least("water", 3),
	]
	var risk_random := EventOutcome.new()
	risk_random.kind = EventOutcome.Kind.MESSAGE
	risk_random.random_chance = 0.6
	risk_random.random_outcomes = [
		EventOutcome.message("The water was fine. No one got sick."),
		EventOutcome.message("The water was fine. No one got sick."),
		EventOutcome.worker_busy(12.0, "Sick"),
		EventOutcome.message("The water was contaminated. One resident got sick."),
	]
	var choices: Array[EventChoiceDef] = [
		EventChoice.create(
			"Boil it all",
			[
				EventOutcome.worker_busy(3.0, "Boiling water"),
				EventOutcome.resource_change("branches", -1),
				EventOutcome.message("The water was boiled and is now safe."),
			],
		),
		EventChoice.create("Risk it", [risk_random]),
	]
	return EventDef.create(
		&"tainted_water", "Tainted water",
		"The water supply looks cloudy and smells odd. It might be contaminated.",
		SettlementStateScript.Era.TENT, choices, conditions,
		0.7, 6,
	)


static func _forest_cache() -> GameEventDef:
	var conditions: Array[EventCondition] = [
		EventCondition.era_is(SettlementStateScript.Era.TENT),
		EventCondition.day_at_least(7),
	]
	var open_random := EventOutcome.new()
	open_random.kind = EventOutcome.Kind.MESSAGE
	open_random.random_chance = 0.5
	open_random.random_outcomes = [
		EventOutcome.resource_change("goods", 3),
		EventOutcome.message("The cache contained preserved goods."),
		EventOutcome.resource_change("food", 4),
		EventOutcome.message("The cache had canned food."),
		EventOutcome.worker_busy(24.0, "Trapped"),
		EventOutcome.message("It was a trap! A forager got caught and took a day to free themselves."),
	]
	var choices: Array[EventChoiceDef] = [
		EventChoice.create("Open it", [open_random]),
		EventChoice.create("Leave it", [EventOutcome.message("The cache was left untouched. Better safe than sorry.")]),
	]
	return EventDef.create(
		&"forest_cache", "Forest cache",
		"A forager stumbled upon a hidden cache in the forest. It could contain valuable supplies — or something dangerous.",
		SettlementStateScript.Era.TENT, choices, conditions,
		0.5, 10,
	)
