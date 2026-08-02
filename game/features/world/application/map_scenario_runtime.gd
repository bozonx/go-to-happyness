class_name MapScenarioRuntime
extends RefCounted

## Runs a map's authored scenario during a session (map_editor.md §10.5).
##
## It owns exactly three things: the flag table, the set of rules that have
## already fired, and elapsed session time. Everything else arrives from outside
## as a published event, which is what keeps the engine's rule layer free of any
## particular game: the zone bus publishes presence, the host publishes the tick,
## and a gameplay module publishes whatever moments it has by calling `publish`.
##
## **The extension seam is the unknown kind.** A trigger this build does not
## recognise still matches by name, and an action it does not recognise is handed
## to whatever `register_action` bound to that name. So `gth.settlement:era_reached`
## and `gth.settlement:add_resource` are settlement vocabulary written by the
## settlement module, and this file never learns what an era is. That is the
## reason the existing `events` feature (`GameEventDef`, `EventOutcome`) is not
## reused here: its conditions and outcomes are settlement enums, and building
## the map's rule table on them would put grain and wellbeing inside the map
## format that a shooter also uses.

signal message_emitted(text: String)
signal flag_changed(flag: StringName, value: Variant)
signal rule_fired(rule_id: StringName)
## Emitted once, when a `victory` or `defeat` expression first holds. The host
## decides what an ending looks like; the scenario only says one was reached.
signal outcome_reached(outcome: StringName)

const OUTCOME_VICTORY := &"victory"
const OUTCOME_DEFEAT := &"defeat"

var scenario: MapScenario = MapScenario.new()
## Current value of every declared flag. Undeclared writes are refused, so a
## typo in an action cannot invent state the validator never saw.
var flags: Dictionary = {}
var elapsed_seconds := 0.0
var outcome: StringName = &""

var _fired: Dictionary = {}
var _action_handlers: Dictionary = {}
var _started := false
## Guards the re-entrancy that makes rule tables loop: an action sets a flag,
## `flag_changed` fires rules, one of which sets the flag again. Events raised
## while rules are running are queued and drained after, so a cycle costs a
## frame's worth of queue rather than the stack.
var _dispatching := false
var _queue: Array[Dictionary] = []


## `initial_flags` are the values the chosen start option declares (`map_start.md`
## §3.1, §7.3 step 9). They are applied here, before `start()` fires
## `session_started`, so the first rule of the prologue reads the entrance's
## state rather than the scenario's neutral default. An undeclared flag is
## ignored on purpose: the flag table stays the scenario's contract, and letting
## an entrance create state on write is how a misspelling becomes two flags.
func configure(next_scenario: MapScenario, initial_flags: Dictionary = {}) -> void:
	scenario = next_scenario if next_scenario != null else MapScenario.new()
	flags = scenario.default_flag_values()
	for flag_id: Variant in initial_flags:
		var definition := scenario.flag_by_id(StringName(flag_id))
		if definition == null:
			push_warning("[scenario] вариант старта задаёт необъявленный флаг %s" % flag_id)
			continue
		flags[StringName(flag_id)] = definition.coerce(initial_flags[flag_id])
	elapsed_seconds = 0.0
	outcome = &""
	_fired.clear()
	_started = false


## A module binds its own `then` action here — `gth.settlement:add_resource` —
## and receives the raw authored dictionary plus this runtime. Registering is how
## a game extends the table without the format learning its vocabulary.
func register_action(action_kind: StringName, handler: Callable) -> void:
	_action_handlers[action_kind] = handler


func has_action(action_kind: StringName) -> bool:
	return _action_handlers.has(action_kind)


## Fires `session_started` and evaluates the end conditions once, so a scenario
## whose defeat expression is already true does not wait for an event.
func start() -> void:
	if _started:
		return
	_started = true
	publish(MapRuleTrigger.SESSION_STARTED, {})


func is_started() -> bool:
	return _started


# --- Inputs -------------------------------------------------------------------

## Session time. `elapsed` triggers fire on the tick that crosses their delay, so
## a rule scheduled for second 30 fires once and not on every frame after.
func process(delta: float) -> void:
	if not _started or outcome != &"":
		return
	var previous := elapsed_seconds
	elapsed_seconds += delta
	# Fired under the dispatch guard for the same reason a published event is: an
	# action here sets a flag, which publishes, which must queue rather than
	# re-enter the loop being walked.
	_dispatching = true
	for rule: MapRule in scenario.rules:
		if rule.trigger.kind != MapRuleTrigger.ELAPSED:
			continue
		if rule.trigger.seconds > previous and rule.trigger.seconds <= elapsed_seconds:
			_try_fire(rule, {})
	_dispatching = false
	_check_outcome()
	_drain()


## The zone bus (`active_zones.md` §14) translated into scenario vocabulary. Only
## presence is mapped: the other kinds have no gameplay writing them yet, and a
## trigger the host cannot produce would be a promise the format cannot keep.
func handle_zone_event(event: ZoneEvent) -> void:
	if event == null:
		return
	# No `actor` is put in the payload. The bus identifies the acting agent by
	# `ai_id`, a runtime number an author cannot write into a map, and inventing
	# a name for it here would produce a trigger that matches nothing. Addressing
	# actors by tag is a later stage (`ideas.md`); until then a presence trigger
	# means "anyone", and the validator says so when a map asks for more.
	match event.kind:
		ZoneEvent.Kind.AREA_ENTERED:
			publish(MapRuleTrigger.AREA_ENTERED, {"zone": event.subject_id})
		ZoneEvent.Kind.AREA_EXITED:
			publish(MapRuleTrigger.AREA_EXITED, {"zone": event.subject_id})


## Every moment reaches the table through here, including a module's own. The
## payload keys the built-in triggers read are `zone`, `flag` and `actor`;
## a module's trigger matches on kind and on whichever of those it supplies.
func publish(event_kind: StringName, payload: Dictionary) -> void:
	if outcome != &"":
		return
	if _dispatching:
		_queue.append({"kind": event_kind, "payload": payload})
		return
	_dispatch(event_kind, payload)
	_drain()


# --- Flags --------------------------------------------------------------------

func flag_value(flag_id: StringName) -> Variant:
	return flags.get(flag_id, false)


## Writes a declared flag and publishes the change. Returns false for an
## undeclared one: the flag table is the scenario's contract, and letting an
## action create state on write is what makes a misspelled flag silently split
## into two.
func set_flag(flag_id: StringName, value: Variant) -> bool:
	var definition := scenario.flag_by_id(flag_id)
	if definition == null:
		push_warning("[scenario] запись в необъявленный флаг %s" % flag_id)
		return false
	var next: Variant = definition.coerce(value)
	if flags.get(flag_id) == next:
		return true
	flags[flag_id] = next
	flag_changed.emit(flag_id, next)
	publish(MapRuleTrigger.FLAG_CHANGED, {"flag": flag_id})
	return true


func add_to_flag(flag_id: StringName, delta: int) -> bool:
	var definition := scenario.flag_by_id(flag_id)
	if definition == null:
		push_warning("[scenario] запись в необъявленный флаг %s" % flag_id)
		return false
	if definition.type != MapFlagDef.TYPE_INT:
		return set_flag(flag_id, delta > 0)
	return set_flag(flag_id, int(flags.get(flag_id, 0)) + delta)


# --- Evaluation ---------------------------------------------------------------

func _dispatch(event_kind: StringName, payload: Dictionary) -> void:
	_dispatching = true
	for rule: MapRule in scenario.rules:
		if rule.trigger.matches(event_kind, payload):
			_try_fire(rule, payload)
	_dispatching = false
	_check_outcome()


func _drain() -> void:
	while not _queue.is_empty() and outcome == &"":
		var next: Dictionary = _queue.pop_front()
		_dispatch(next["kind"], next["payload"])


func _try_fire(rule: MapRule, payload: Dictionary) -> void:
	if not rule.enabled or outcome != &"":
		return
	if rule.once and _fired.has(rule.id):
		return
	if not rule.conditions_hold(flags):
		return
	_fired[rule.id] = true
	for action: MapRuleAction in rule.actions:
		_apply(action, rule, payload)
	rule_fired.emit(rule.id)


func _apply(action: MapRuleAction, rule: MapRule, payload: Dictionary) -> void:
	match action.kind:
		MapRuleAction.SET_FLAG:
			set_flag(action.flag, action.value)
		MapRuleAction.ADD_FLAG:
			add_to_flag(action.flag, int(action.value) if (action.value is int or action.value is float) else 1)
		MapRuleAction.MESSAGE:
			message_emitted.emit(action.text)
		_:
			_apply_extension(action, rule, payload)


## An action nobody registered is a no-op with a warning rather than an error: a
## map that uses a module the current session did not load should still run the
## rest of its scenario, the same way a missing pack does not stop the map from
## opening in the editor.
func _apply_extension(action: MapRuleAction, rule: MapRule, payload: Dictionary) -> void:
	var handler: Variant = _action_handlers.get(action.kind)
	if not (handler is Callable) or not (handler as Callable).is_valid():
		push_warning("[scenario] правило %s: действие %s не поддержано этой сессией"
			% [rule.id, action.kind])
		return
	(handler as Callable).call(action.raw.duplicate(true), self, payload)


## Victory is checked before defeat: a scenario whose last rule both completes the
## objective and kills the hero should read as won, not lost.
func _check_outcome() -> void:
	if outcome != &"":
		return
	if _any_holds(scenario.victory):
		_finish(OUTCOME_VICTORY)
	elif _any_holds(scenario.defeat):
		_finish(OUTCOME_DEFEAT)


func _any_holds(conditions: Array[MapRuleCondition]) -> bool:
	for condition: MapRuleCondition in conditions:
		if condition.is_satisfied(flags):
			return true
	return false


func _finish(next_outcome: StringName) -> void:
	outcome = next_outcome
	_queue.clear()
	outcome_reached.emit(next_outcome)
