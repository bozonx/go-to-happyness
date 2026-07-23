extends SceneTree

## Tests for the data-driven event system.
## Covers domain model, registry, log, service, and tent-era event definitions.

const SettlementStateScript = preload("res://game/features/settlement/domain/settlement_state.gd")
const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")
const EventRegistryScript = preload("res://game/features/events/domain/event_registry.gd")
const EventLogScript = preload("res://game/features/events/domain/event_log.gd")
const EventContextScript = preload("res://game/features/events/domain/event_context.gd")
const EventOutcomeScript = preload("res://game/features/events/domain/event_outcome.gd")
const EventConditionScript = preload("res://game/features/events/domain/event_condition.gd")
const EventChoiceScript = preload("res://game/features/events/domain/event_choice_def.gd")
const EventDefScript = preload("res://game/features/events/domain/game_event_def.gd")
const EventServiceScript = preload("res://game/features/events/application/event_service.gd")
const TentEraEventsScript = preload("res://game/features/events/application/tent_era_events.gd")


func _init() -> void:
	_test_event_outcome_factory()
	_test_event_condition_evaluation()
	_test_registry_register_and_filter()
	_test_event_log_cooldown()
	_test_event_log_flags()
	_test_event_def_eligibility()
	_test_service_roll_no_eligible()
	_test_service_roll_picks_eligible()
	_test_service_resolve_choice()
	_test_service_cooldown_prevents_reroll()
	_test_service_delayed_effect()
	_test_service_chain_flag()
	_test_tent_era_events_count()
	_test_tent_era_events_have_choices()
	_test_tent_era_protect_firewood()
	_test_tent_era_wild_boars_chain()
	_test_random_outcome_resolution()
	print("test_events: all tests passed")
	quit(0)


# --- Domain model tests ---------------------------------------------------------

func _test_event_outcome_factory() -> void:
	var msg := EventOutcomeScript.message("hello")
	assert(msg.kind == EventOutcomeScript.Kind.MESSAGE)
	assert(msg.text == "hello")

	var res := EventOutcomeScript.resource_change("food", -3)
	assert(res.kind == EventOutcomeScript.Kind.RESOURCE_CHANGE)
	assert(res.resource == "food")
	assert(res.amount == -3)

	var wb := EventOutcomeScript.wellbeing(10)
	assert(wb.kind == EventOutcomeScript.Kind.WELLBEING_CHANGE)
	assert(wb.wellbeing_delta == 10)

	var busy := EventOutcomeScript.worker_busy(6.0, "Chasing")
	assert(busy.kind == EventOutcomeScript.Kind.WORKER_BUSY)
	assert(busy.worker_busy_hours == 6.0)
	assert(busy.worker_busy_label == "Chasing")

	var flag := EventOutcomeScript.set_flag(&"test_flag")
	assert(flag.kind == EventOutcomeScript.Kind.SET_FLAG)
	assert(flag.flag == &"test_flag")

	var inner := EventOutcomeScript.message("delayed")
	var delayed := EventOutcomeScript.delayed(2, inner)
	assert(delayed.kind == EventOutcomeScript.Kind.DELAYED)
	assert(delayed.delay_days == 2)
	assert(delayed.delayed_outcome != null)
	assert(delayed.delayed_outcome.text == "delayed")


func _test_event_condition_evaluation() -> void:
	var ctx := EventContextScript.create(
		SettlementStateScript.Era.TENT, 5,
		TentEraSurvivalRulesScript.Weather.RAIN,
		{"food": 10, "water": 3}, 75, 4, {}
	)

	assert(EventConditionScript.era_is(SettlementStateScript.Era.TENT).is_satisfied(ctx))
	assert(not EventConditionScript.era_is(SettlementStateScript.Era.EARTH).is_satisfied(ctx))

	assert(EventConditionScript.weather_is(TentEraSurvivalRulesScript.Weather.RAIN).is_satisfied(ctx))
	assert(not EventConditionScript.weather_is(TentEraSurvivalRulesScript.Weather.WARMING).is_satisfied(ctx))

	assert(EventConditionScript.resource_at_least("food", 5).is_satisfied(ctx))
	assert(not EventConditionScript.resource_at_least("food", 11).is_satisfied(ctx))
	assert(EventConditionScript.resource_at_most("food", 10).is_satisfied(ctx))
	assert(not EventConditionScript.resource_at_most("food", 9).is_satisfied(ctx))

	assert(EventConditionScript.day_at_least(3).is_satisfied(ctx))
	assert(not EventConditionScript.day_at_least(6).is_satisfied(ctx))

	assert(EventConditionScript.population_at_least(4).is_satisfied(ctx))
	assert(not EventConditionScript.population_at_least(5).is_satisfied(ctx))

	var ctx_with_flag := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1, 0, {}, 75, 1, {&"boar_warning": true}
	)
	assert(EventConditionScript.flag_set(&"boar_warning").is_satisfied(ctx_with_flag))
	assert(not EventConditionScript.flag_not_set(&"boar_warning").is_satisfied(ctx_with_flag))
	assert(EventConditionScript.flag_not_set(&"boar_warning").is_satisfied(ctx))


# --- Registry tests -------------------------------------------------------------

func _test_registry_register_and_filter() -> void:
	var reg := EventRegistryScript.new()
	var def1 := EventDefScript.create(&"event_a", "A", "Desc A", SettlementStateScript.Era.TENT, [])
	var def2 := EventDefScript.create(&"event_b", "B", "Desc B", SettlementStateScript.Era.EARTH, [])
	reg.register(def1)
	reg.register(def2)
	assert(reg.all().size() == 2)
	assert(reg.by_era(SettlementStateScript.Era.TENT).size() == 1)
	assert(reg.by_era(SettlementStateScript.Era.EARTH).size() == 1)
	assert(reg.by_era(SettlementStateScript.Era.CLAY).is_empty())
	assert(reg.find_by_id(&"event_a") == def1)
	assert(reg.find_by_id(&"nonexistent") == null)


# --- EventLog tests -------------------------------------------------------------

func _test_event_log_cooldown() -> void:
	var log := EventLogScript.new()
	assert(not log.is_on_cooldown(&"event_x", 1, 2))
	log.record(&"event_x", 1, 0)
	assert(log.is_on_cooldown(&"event_x", 2, 2))
	assert(not log.is_on_cooldown(&"event_x", 3, 2))
	assert(not log.is_on_cooldown(&"event_y", 1, 2))


func _test_event_log_flags() -> void:
	var log := EventLogScript.new()
	assert(not log.has_flag(&"flag_a"))
	log.set_flag(&"flag_a")
	assert(log.has_flag(&"flag_a"))
	log.clear_flag(&"flag_a")
	assert(not log.has_flag(&"flag_a"))


# --- GameEventDef eligibility tests ---------------------------------------------

func _test_event_def_eligibility() -> void:
	var log := EventLogScript.new()
	var conditions: Array = [
		EventConditionScript.era_is(SettlementStateScript.Era.TENT),
		EventConditionScript.weather_is(TentEraSurvivalRulesScript.Weather.RAIN),
		EventConditionScript.resource_at_least("branches", 1),
	]
	var def := EventDefScript.create(
		&"test_event", "Test", "Desc",
		SettlementStateScript.Era.TENT, [], conditions,
		1.0, 2,
	)
	var ctx_rain := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1,
		TentEraSurvivalRulesScript.Weather.RAIN,
		{"branches": 5}, 75, 4, {}
	)
	assert(def.is_eligible(ctx_rain, log))

	var ctx_no_rain := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1,
		TentEraSurvivalRulesScript.Weather.WARMING,
		{"branches": 5}, 75, 4, {}
	)
	assert(not def.is_eligible(ctx_no_rain, log))

	var ctx_wrong_era := EventContextScript.create(
		SettlementStateScript.Era.EARTH, 1,
		TentEraSurvivalRulesScript.Weather.RAIN,
		{"branches": 5}, 75, 4, {}
	)
	assert(not def.is_eligible(ctx_wrong_era, log))

	log.record(&"test_event", 1, 0)
	assert(not def.is_eligible(ctx_rain, log))
	var ctx_next_day := EventContextScript.create(
		SettlementStateScript.Era.TENT, 3,
		TentEraSurvivalRulesScript.Weather.RAIN,
		{"branches": 5}, 75, 4, {}
	)
	assert(def.is_eligible(ctx_next_day, log))


# --- EventService tests ---------------------------------------------------------

func _test_service_roll_no_eligible() -> void:
	var reg := EventRegistryScript.new()
	var service := EventServiceScript.new(reg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ctx := EventContextScript.create(
		SettlementStateScript.Era.BRICK, 1, 0, {}, 75, 4, {}
	)
	assert(service.roll_daily_event(ctx, rng) == null)
	assert(not service.has_pending())


func _test_service_roll_picks_eligible() -> void:
	var reg := EventRegistryScript.new()
	var def := EventDefScript.create(
		&"simple_event", "Simple", "Desc",
		SettlementStateScript.Era.TENT,
		[EventChoiceScript.create("Choice A", [EventOutcomeScript.message("A")])],
		[EventConditionScript.era_is(SettlementStateScript.Era.TENT)],
	)
	reg.register(def)
	var service := EventServiceScript.new(reg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ctx := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1, 0, {}, 75, 4, {}
	)
	var picked := service.roll_daily_event(ctx, rng)
	assert(picked != null)
	assert(picked.id == &"simple_event")
	assert(service.has_pending())


func _test_service_resolve_choice() -> void:
	var reg := EventRegistryScript.new()
	var def := EventDefScript.create(
		&"choice_event", "Choice", "Desc",
		SettlementStateScript.Era.TENT,
		[
			EventChoiceScript.create("Accept", [
				EventOutcomeScript.resource_change("food", -2),
				EventOutcomeScript.wellbeing(10),
				EventOutcomeScript.message("Accepted."),
			]),
			EventChoiceScript.create("Reject", [
				EventOutcomeScript.message("Rejected."),
			]),
		],
		[EventConditionScript.era_is(SettlementStateScript.Era.TENT)],
	)
	reg.register(def)
	var service := EventServiceScript.new(reg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ctx := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1, 0, {"food": 10}, 75, 4, {}
	)
	service.roll_daily_event(ctx, rng)
	assert(service.has_pending())
	var outcomes: Array = service.resolve_choice(0, ctx, rng)
	assert(outcomes.size() == 3)
	assert(outcomes[0].kind == EventOutcomeScript.Kind.RESOURCE_CHANGE)
	assert(outcomes[0].resource == "food")
	assert(outcomes[0].amount == -2)
	assert(outcomes[1].kind == EventOutcomeScript.Kind.WELLBEING_CHANGE)
	assert(outcomes[1].wellbeing_delta == 10)
	assert(outcomes[2].kind == EventOutcomeScript.Kind.MESSAGE)
	assert(outcomes[2].text == "Accepted.")
	assert(not service.has_pending())
	assert(service.log.entries.size() == 1)
	assert(service.log.entries[0].choice_index == 0)


func _test_service_cooldown_prevents_reroll() -> void:
	var reg := EventRegistryScript.new()
	var def := EventDefScript.create(
		&"cooldown_event", "Cooldown", "Desc",
		SettlementStateScript.Era.TENT,
		[EventChoiceScript.create("OK", [EventOutcomeScript.message("Done.")])],
		[EventConditionScript.era_is(SettlementStateScript.Era.TENT)],
		1.0, 3,
	)
	reg.register(def)
	var service := EventServiceScript.new(reg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ctx_day1 := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1, 0, {}, 75, 4, {}
	)
	service.roll_daily_event(ctx_day1, rng)
	service.resolve_choice(0, ctx_day1, rng)
	var ctx_day2 := EventContextScript.create(
		SettlementStateScript.Era.TENT, 2, 0, {}, 75, 4, {}
	)
	assert(service.roll_daily_event(ctx_day2, rng) == null)
	var ctx_day4 := EventContextScript.create(
		SettlementStateScript.Era.TENT, 4, 0, {}, 75, 4, {}
	)
	var picked := service.roll_daily_event(ctx_day4, rng)
	assert(picked != null)
	assert(picked.id == &"cooldown_event")


func _test_service_delayed_effect() -> void:
	var reg := EventRegistryScript.new()
	var def := EventDefScript.create(
		&"delayed_event", "Delayed", "Desc",
		SettlementStateScript.Era.TENT,
		[
			EventChoiceScript.create("Ignore", [
				EventOutcomeScript.delayed(1, EventOutcomeScript.set_flag(&"smoky_firewood")),
				EventOutcomeScript.message("Will be smoky tomorrow."),
			]),
		],
		[EventConditionScript.era_is(SettlementStateScript.Era.TENT)],
	)
	reg.register(def)
	var service := EventServiceScript.new(reg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ctx_day1 := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1, 0, {}, 75, 4, {}
	)
	service.roll_daily_event(ctx_day1, rng)
	var outcomes := service.resolve_choice(0, ctx_day1, rng)
	assert(outcomes.size() == 1)
	assert(outcomes[0].kind == EventOutcomeScript.Kind.MESSAGE)
	assert(not service.log.has_flag(&"smoky_firewood"))
	var ctx_day2 := EventContextScript.create(
		SettlementStateScript.Era.TENT, 2, 0, {}, 75, 4, {}
	)
	var delayed_outcomes := service.advance_day(2, ctx_day2, rng)
	assert(service.log.has_flag(&"smoky_firewood"))


func _test_service_chain_flag() -> void:
	var reg := EventRegistryScript.new()
	var ranger_def := EventDefScript.create(
		&"forest_ranger", "Ranger", "Desc",
		SettlementStateScript.Era.TENT,
		[
			EventChoiceScript.create("Listen", [
				EventOutcomeScript.set_flag(&"boar_warning"),
				EventOutcomeScript.message("Ranger warned about boars."),
			]),
		],
		[EventConditionScript.era_is(SettlementStateScript.Era.TENT)],
		1.0, 7, &"",
	)
	var boar_def := EventDefScript.create(
		&"wild_boars", "Boars", "Desc",
		SettlementStateScript.Era.TENT,
		[EventChoiceScript.create("Fight", [EventOutcomeScript.message("Fought boars.")])],
		[EventConditionScript.era_is(SettlementStateScript.Era.TENT)],
		10.0, 5, &"boar_warning",
	)
	reg.register(ranger_def)
	reg.register(boar_def)
	var service := EventServiceScript.new(reg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ctx := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1, 0, {}, 75, 4, {}
	)
	var picked := service.roll_daily_event(ctx, rng)
	assert(picked != null)
	assert(picked.id == &"forest_ranger")
	service.resolve_choice(0, ctx, rng)
	assert(service.log.has_flag(&"boar_warning"))
	service.clear_pending()
	var ctx2 := EventContextScript.create(
		SettlementStateScript.Era.TENT, 8, 0, {}, 75, 4, {&"boar_warning": true}
	)
	assert(boar_def.is_eligible(ctx2, service.log))


# --- TentEraEvents tests --------------------------------------------------------

func _test_tent_era_events_count() -> void:
	var defs := TentEraEventsScript.build()
	assert(defs.size() == 12)


func _test_tent_era_events_have_choices() -> void:
	var defs := TentEraEventsScript.build()
	for def in defs:
		assert(def.choices.size() >= 2, "Event %s has fewer than 2 choices" % def.id)
		assert(not def.title.is_empty(), "Event %s has empty title" % def.id)
		assert(not def.description.is_empty(), "Event %s has empty description" % def.id)
		assert(def.era == SettlementStateScript.Era.TENT, "Event %s is not TENT era" % def.id)
		assert(def.cooldown_days >= 1, "Event %s has cooldown < 1" % def.id)


func _test_tent_era_protect_firewood() -> void:
	var defs := TentEraEventsScript.build()
	var firewood_def: GameEventDef = null
	for def in defs:
		if def.id == &"protect_firewood":
			firewood_def = def
			break
	assert(firewood_def != null)
	assert(firewood_def.choices.size() == 2)
	var log := EventLogScript.new()
	var ctx_rain := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1,
		TentEraSurvivalRulesScript.Weather.RAIN,
		{"branches": 5}, 75, 4, {}
	)
	assert(firewood_def.is_eligible(ctx_rain, log))
	var ctx_no_rain := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1,
		TentEraSurvivalRulesScript.Weather.WARMING,
		{"branches": 5}, 75, 4, {}
	)
	assert(not firewood_def.is_eligible(ctx_no_rain, log))
	var ctx_no_branches := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1,
		TentEraSurvivalRulesScript.Weather.RAIN,
		{"branches": 0}, 75, 4, {}
	)
	assert(not firewood_def.is_eligible(ctx_no_branches, log))


func _test_tent_era_wild_boars_chain() -> void:
	var defs := TentEraEventsScript.build()
	var boar_def: GameEventDef = null
	for def in defs:
		if def.id == &"wild_boars":
			boar_def = def
			break
	assert(boar_def != null)
	assert(boar_def.chain_flag == &"boar_warning")
	var log := EventLogScript.new()
	var ctx_no_flag := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1, 0, {}, 75, 4, {}
	)
	assert(not boar_def.is_eligible(ctx_no_flag, log))
	log.set_flag(&"boar_warning")
	var ctx_with_flag := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1, 0, {}, 75, 4, {&"boar_warning": true}
	)
	assert(boar_def.is_eligible(ctx_with_flag, log))


func _test_random_outcome_resolution() -> void:
	var reg := EventRegistryScript.new()
	var success_outcomes: Array = [
		EventOutcomeScript.wellbeing(20),
		EventOutcomeScript.message("Success!"),
	]
	var fail_outcomes: Array = [
		EventOutcomeScript.worker_busy(24.0, "Poisoned"),
		EventOutcomeScript.message("Failed!"),
	]
	var random_outcome := EventOutcomeScript.new()
	random_outcome.kind = EventOutcomeScript.Kind.MESSAGE
	random_outcome.random_chance = 0.5
	random_outcome.random_outcomes = success_outcomes + fail_outcomes
	var def := EventDefScript.create(
		&"random_event", "Random", "Desc",
		SettlementStateScript.Era.TENT,
		[EventChoiceScript.create("Try", [random_outcome])],
		[EventConditionScript.era_is(SettlementStateScript.Era.TENT)],
	)
	reg.register(def)
	var service := EventServiceScript.new(reg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var ctx := EventContextScript.create(
		SettlementStateScript.Era.TENT, 1, 0, {}, 75, 4, {}
	)
	service.roll_daily_event(ctx, rng)
	var outcomes := service.resolve_choice(0, ctx, rng)
	assert(outcomes.size() == 2)
	var has_wellbeing := false
	var has_worker_busy := false
	for o in outcomes:
		if o.kind == EventOutcomeScript.Kind.WELLBEING_CHANGE:
			has_wellbeing = true
		if o.kind == EventOutcomeScript.Kind.WORKER_BUSY:
			has_worker_busy = true
	assert(has_wellbeing != has_worker_busy, "Exactly one branch should be picked")
