class_name TestMapScenario
extends RefCounted

## Domain tests for the map scenario layer (map_editor.md §10): the authored
## table (`MapScenario`) and the thing that runs it (`MapScenarioRuntime`).
##
## The tests that matter most here are the round-trip ones. A scenario is the
## part of a map that an editor is most likely to be one version behind on, and
## the format's promise is that an old editor opening a new map hands it back
## whole — including the rows it did not understand.

const BOARD_CELLS := 16


static func run_all() -> void:
	_test_flags_and_rules_round_trip()
	_test_unknown_trigger_and_action_survive_round_trip()
	_test_area_entered_rule_fires_once()
	_test_conditions_gate_the_rule()
	_test_counter_flag_reaches_victory()
	_test_undeclared_flag_write_is_refused()
	_test_module_action_reaches_its_handler()
	_test_defeat_is_reported_and_stops_the_table()
	_test_elapsed_trigger_fires_on_the_crossing_tick()
	_test_validator_reports_dangling_zone_and_flag()
	_test_editor_mode_authors_a_rule_and_undoes_it()
	_test_editor_mode_renames_a_flag_everywhere()
	print("    [PASS] Map Scenario Tests")


# --- Format -------------------------------------------------------------------

## Everything an author writes comes back byte-equivalent through the document.
static func _test_flags_and_rules_round_trip() -> void:
	var document := MapDocument.create(&"scen", "Scenario", BOARD_CELLS)
	document.scenario.flags.append(MapFlagDef.create(&"has_key", MapFlagDef.TYPE_BOOL, false))
	document.scenario.flags.append(MapFlagDef.create(&"kills", MapFlagDef.TYPE_INT, 0))
	var rule := MapRule.create(&"gate", MapRuleTrigger.on_area_entered(&"gate_yard"))
	rule.conditions.append(MapRuleCondition.flag_is(&"has_key", false))
	rule.actions.append(MapRuleAction.say("Вас заметили."))
	rule.actions.append(MapRuleAction.add_to_flag(&"kills", 2))
	document.scenario.rules.append(rule)
	document.scenario.victory.append(MapRuleCondition.flag_is(&"kills", 3, MapRuleCondition.OP_GE))

	var reloaded := MapDocument.from_json(document.to_json())
	assert(reloaded.scenario.flags.size() == 2, "both flags survive the round trip")
	assert(reloaded.scenario.flag_by_id(&"kills").type == MapFlagDef.TYPE_INT, "counter stays a counter")
	var restored := reloaded.scenario.rule_by_id(&"gate")
	assert(restored != null, "rule survives by id")
	assert(restored.trigger.zone == &"gate_yard", "trigger keeps its zone")
	assert(restored.conditions.size() == 1 and restored.actions.size() == 2, "if/then survive")
	assert(reloaded.scenario.victory.size() == 1, "victory expression survives")
	assert(reloaded.to_json()["rules"] == document.to_json()["rules"], "second trip is stable")


## The reason the scenario is typed rather than passed through: a build that does
## not know `gth.settlement:era_reached` must still hand it back untouched, or
## every editor silently truncates every map authored by a newer one.
static func _test_unknown_trigger_and_action_survive_round_trip() -> void:
	var source := {
		"flags": {"ready": {"type": "bool", "default": false}},
		"rules": [{
			"id": "future",
			"enabled": true,
			"once": false,
			"when": {"trigger": "gth.settlement:era_reached", "era": "clay"},
			"if": [{"unknown_test": {"nested": 1}}],
			"then": [{"action": "gth.settlement:add_resource", "resource": "grain", "amount": 5}],
			"comment": "written by a newer build",
		}],
		"victory": [],
		"defeat": [],
	}
	var scenario := MapScenario.from_json(source)
	var written := scenario.to_json()
	var rule: Dictionary = (written["rules"] as Array)[0]
	assert(rule["when"] == source["rules"][0]["when"], "unknown trigger kept verbatim")
	assert(rule["then"] == source["rules"][0]["then"], "unknown action kept verbatim")
	assert(rule["if"] == source["rules"][0]["if"], "unknown condition kept verbatim")
	assert(rule.get("comment", "") == "written by a newer build", "unknown rule key kept")


# --- Runtime ------------------------------------------------------------------

## The whole point of the zone bus having a consumer: an agent crosses a region
## border and a rule fires — once, because the rule says `once`.
static func _test_area_entered_rule_fires_once() -> void:
	var scenario := MapScenario.new()
	scenario.flags.append(MapFlagDef.create(&"alarm", MapFlagDef.TYPE_BOOL, false))
	var rule := MapRule.create(&"ambush", MapRuleTrigger.on_area_entered(&"gate_yard"))
	rule.actions.append(MapRuleAction.set_flag_to(&"alarm", true))
	scenario.rules.append(rule)

	var runtime := MapScenarioRuntime.new()
	runtime.configure(scenario)
	var fired: Array[StringName] = []
	runtime.rule_fired.connect(func(rule_id: StringName) -> void: fired.append(rule_id))
	runtime.start()
	assert(fired.is_empty(), "nothing fires before the agent arrives")

	runtime.handle_zone_event(ZoneEvent.area_entered(&"gate_yard", 7))
	assert(runtime.flag_value(&"alarm") == true, "the rule set its flag")
	runtime.handle_zone_event(ZoneEvent.area_entered(&"gate_yard", 8))
	assert(fired.size() == 1, "a `once` rule fires exactly once: %d" % fired.size())

	# A different area must not match a rule that named one.
	runtime.handle_zone_event(ZoneEvent.area_entered(&"other_yard", 9))
	assert(fired.size() == 1, "a rule bound to a zone ignores other zones")


static func _test_conditions_gate_the_rule() -> void:
	var scenario := MapScenario.new()
	scenario.flags.append(MapFlagDef.create(&"has_key", MapFlagDef.TYPE_BOOL, true))
	scenario.flags.append(MapFlagDef.create(&"alarm", MapFlagDef.TYPE_BOOL, false))
	var rule := MapRule.create(&"ambush", MapRuleTrigger.on_area_entered(&"gate_yard"))
	rule.conditions.append(MapRuleCondition.flag_is(&"has_key", false))
	rule.actions.append(MapRuleAction.set_flag_to(&"alarm", true))
	scenario.rules.append(rule)

	var runtime := MapScenarioRuntime.new()
	runtime.configure(scenario)
	runtime.start()
	runtime.handle_zone_event(ZoneEvent.area_entered(&"gate_yard", 7))
	assert(runtime.flag_value(&"alarm") == false, "the key holder walks through unchallenged")

	runtime.set_flag(&"has_key", false)
	runtime.handle_zone_event(ZoneEvent.area_entered(&"gate_yard", 7))
	assert(runtime.flag_value(&"alarm") == true, "without the key the ambush fires")


## A counter, a rule that increments it and a victory expression over it — the
## smallest complete scenario, end to end.
static func _test_counter_flag_reaches_victory() -> void:
	var scenario := MapScenario.new()
	scenario.flags.append(MapFlagDef.create(&"kills", MapFlagDef.TYPE_INT, 0))
	var rule := MapRule.create(&"kill", MapRuleTrigger.on_area_entered(&"arena"))
	rule.once = false
	rule.actions.append(MapRuleAction.add_to_flag(&"kills", 1))
	scenario.rules.append(rule)
	scenario.victory.append(MapRuleCondition.flag_is(&"kills", 2, MapRuleCondition.OP_GE))

	var runtime := MapScenarioRuntime.new()
	runtime.configure(scenario)
	var outcomes: Array[StringName] = []
	runtime.outcome_reached.connect(func(outcome: StringName) -> void: outcomes.append(outcome))
	runtime.start()
	runtime.handle_zone_event(ZoneEvent.area_entered(&"arena", 1))
	assert(outcomes.is_empty(), "one kill is not the objective")
	runtime.handle_zone_event(ZoneEvent.area_entered(&"arena", 2))
	assert(outcomes.size() == 1 and outcomes[0] == MapScenarioRuntime.OUTCOME_VICTORY,
		"the second kill wins the map: %s" % [outcomes])


## A misspelled flag must not become state. Letting a write declare its own flag
## is what turns one typo into a scenario that can never be completed and never
## reports why.
static func _test_undeclared_flag_write_is_refused() -> void:
	var scenario := MapScenario.new()
	scenario.flags.append(MapFlagDef.create(&"has_key", MapFlagDef.TYPE_BOOL, false))
	var runtime := MapScenarioRuntime.new()
	runtime.configure(scenario)
	assert(not runtime.set_flag(&"has_kye", true), "an undeclared flag is refused")
	assert(not runtime.flags.has(&"has_kye"), "and does not appear in the table")


## The extension seam: a module registers its own action and the table calls it
## without the engine learning what a resource is.
static func _test_module_action_reaches_its_handler() -> void:
	var scenario := MapScenario.from_json({
		"flags": {},
		"rules": [{
			"id": "payout",
			"when": {"trigger": "session_started"},
			"then": [{"action": "gth.settlement:add_resource", "resource": "grain", "amount": 5}],
		}],
	})
	var runtime := MapScenarioRuntime.new()
	runtime.configure(scenario)
	var received: Array[Dictionary] = []
	runtime.register_action(&"gth.settlement:add_resource",
		func(raw: Dictionary, _runtime: MapScenarioRuntime, _payload: Dictionary) -> void:
			received.append(raw))
	runtime.start()
	assert(received.size() == 1, "the module handler was called")
	assert(String(received[0]["resource"]) == "grain" and int(received[0]["amount"]) == 5,
		"the handler gets the authored payload verbatim")


static func _test_defeat_is_reported_and_stops_the_table() -> void:
	var scenario := MapScenario.new()
	scenario.flags.append(MapFlagDef.create(&"hero_dead", MapFlagDef.TYPE_BOOL, false))
	scenario.flags.append(MapFlagDef.create(&"after", MapFlagDef.TYPE_BOOL, false))
	var rule := MapRule.create(&"post_mortem", MapRuleTrigger.on_area_entered(&"anywhere"))
	rule.actions.append(MapRuleAction.set_flag_to(&"after", true))
	scenario.rules.append(rule)
	scenario.defeat.append(MapRuleCondition.flag_is(&"hero_dead", true))

	var runtime := MapScenarioRuntime.new()
	runtime.configure(scenario)
	runtime.start()
	runtime.set_flag(&"hero_dead", true)
	assert(runtime.outcome == MapScenarioRuntime.OUTCOME_DEFEAT, "defeat was reached")
	runtime.handle_zone_event(ZoneEvent.area_entered(&"anywhere", 3))
	assert(runtime.flag_value(&"after") == false, "no rule fires after the session ended")


## An `elapsed` rule fires on the tick that crosses its delay, and only then —
## the alternative is a rule that fires on every frame for the rest of the map.
static func _test_elapsed_trigger_fires_on_the_crossing_tick() -> void:
	var scenario := MapScenario.new()
	scenario.flags.append(MapFlagDef.create(&"ticks", MapFlagDef.TYPE_INT, 0))
	var rule := MapRule.create(&"briefing", MapRuleTrigger.after_seconds(1.0))
	rule.once = false
	rule.actions.append(MapRuleAction.add_to_flag(&"ticks", 1))
	scenario.rules.append(rule)

	var runtime := MapScenarioRuntime.new()
	runtime.configure(scenario)
	runtime.start()
	runtime.process(0.5)
	assert(int(runtime.flag_value(&"ticks")) == 0, "not yet")
	runtime.process(0.6)
	assert(int(runtime.flag_value(&"ticks")) == 1, "fires on the crossing tick")
	runtime.process(5.0)
	assert(int(runtime.flag_value(&"ticks")) == 1, "and not again afterwards")


# --- Validation ---------------------------------------------------------------

static func _test_validator_reports_dangling_zone_and_flag() -> void:
	var document := MapDocument.create(&"scen", "Scenario", BOARD_CELLS)
	var rule := MapRule.create(&"gate", MapRuleTrigger.on_area_entered(&"missing_yard"))
	rule.actions.append(MapRuleAction.set_flag_to(&"undeclared", true))
	document.scenario.rules.append(rule)

	var errors := MapValidator.validate(document, document.terrain, document.water, null)
	assert(errors.any(func(message: String) -> bool: return message.contains("missing_yard")),
		"a trigger on a deleted area is an error: %s" % "; ".join(errors))
	assert(errors.any(func(message: String) -> bool: return message.contains("undeclared")),
		"an action writing an undeclared flag is an error: %s" % "; ".join(errors))


# --- Editor mode --------------------------------------------------------------

## The scenario mode has no brush and no viewport, so its whole behaviour is
## reachable headless: pick a section, press the add buttons, edit through the
## inspector, undo. Which is the point — a rule table that could only be tested
## by clicking is a rule table nobody tests.
static func _test_editor_mode_authors_a_rule_and_undoes_it() -> void:
	var document := MapDocument.create(&"scen", "Scenario", BOARD_CELLS)
	var mode := _mode_over(document)

	mode.select_palette_entry(&"flags")
	mode.activate_option(&"add_flag_bool")
	assert(document.scenario.flags.size() == 1, "the flag button declares a flag")
	assert(mode.selected_list_index() >= 0, "and selects it, so it can be renamed at once")
	assert(mode.apply_inspector_value(&"id", "alarm"), "the id field renames it")
	# Read through the document, never through a held reference: a commit replays
	# the whole layer out of its snapshot, so `document.scenario` is a new object
	# after every edit. That is the same contract `MapZoneCommand` has.
	assert(document.scenario.flags[0].id == &"alarm",
		"rename landed: %s" % document.scenario.flags[0].id)

	mode.select_palette_entry(&"rules")
	mode.activate_option(&"add_rule")
	assert(document.scenario.rules.size() == 1, "the rule button adds a rule")
	mode.activate_option(&"add_action")
	assert(document.scenario.rules[0].actions.size() == 1, "an action goes under the selected rule")
	assert(document.scenario.rules[0].actions[0].flag == &"alarm", "and defaults to the declared flag")

	# Every gesture is one undoable command, on the editor's single stack.
	var history: MapEditorHistory = mode.context.history
	assert(history.can_undo(), "the edits are undoable")
	history.undo()
	assert(document.scenario.rules[0].actions.is_empty(), "undo removed the action")
	history.undo()
	assert(document.scenario.rules.is_empty(), "undo removed the rule")


## Renaming a flag has to carry every reference with it. The alternative is a
## scenario that validates clean before the rename and is broken after it, with
## nothing on screen having changed.
static func _test_editor_mode_renames_a_flag_everywhere() -> void:
	var document := MapDocument.create(&"scen", "Scenario", BOARD_CELLS)
	document.scenario.flags.append(MapFlagDef.create(&"alarm", MapFlagDef.TYPE_BOOL, false))
	var rule := MapRule.create(&"gate", MapRuleTrigger.of(MapRuleTrigger.SESSION_STARTED))
	rule.conditions.append(MapRuleCondition.flag_is(&"alarm", false))
	rule.actions.append(MapRuleAction.set_flag_to(&"alarm", true))
	document.scenario.rules.append(rule)
	document.scenario.victory.append(MapRuleCondition.flag_is(&"alarm", true))

	var mode := _mode_over(document)
	mode.select_palette_entry(&"flags")
	mode.select_list_entry(0)
	assert(mode.apply_inspector_value(&"id", "raised"), "the flag was renamed")

	assert(document.scenario.flag_by_id(&"raised") != null, "the declaration moved")
	assert(document.scenario.rules[0].conditions[0].flag == &"raised", "the condition followed")
	assert(document.scenario.rules[0].actions[0].flag == &"raised", "the action followed")
	assert(document.scenario.victory[0].flag == &"raised", "victory followed")
	assert(MapValidator.validate(document, document.terrain, document.water, null).is_empty(),
		"and the scenario still validates clean")


static func _mode_over(document: MapDocument) -> ScenarioModeController:
	var context := MapEditorContext.new()
	context.document = document
	context.terrain = document.terrain
	context.history = MapEditorHistory.new()
	var mode := ScenarioModeController.new()
	mode.configure(context)
	mode.activate()
	return mode
