class_name EventService
extends RefCounted

## Coordinates event selection, resolution, and delayed effects.
## Handles flag setting and delayed effects internally; returns resolved
## outcomes (RESOURCE_CHANGE, WELLBEING_CHANGE, WORKER_BUSY, MESSAGE)
## for the presentation layer to apply to actual game state.

const EventRegistryScript = preload("res://game/features/events/domain/event_registry.gd")
const EventLogScript = preload("res://game/features/events/domain/event_log.gd")
const EventContextScript = preload("res://game/features/events/domain/event_context.gd")
const EventOutcomeScript = preload("res://game/features/events/domain/event_outcome.gd")
const DelayedEffectScript = preload("res://game/features/events/application/delayed_effect.gd")

var registry: EventRegistry
var log: EventLog
var pending_event: RefCounted = null
var pending_delayed: Array = []


func _init(p_registry: EventRegistry = null, p_log: EventLog = null) -> void:
	registry = p_registry if p_registry != null else EventRegistryScript.new()
	log = p_log if p_log != null else EventLogScript.new()


## Called each in-game day at 06:00. Returns the selected event def or null.
func roll_daily_event(context: EventContext, rng: RandomNumberGenerator) -> RefCounted:
	if pending_event != null:
		return pending_event
	var eligible := _filter_eligible(context)
	if eligible.is_empty():
		return null
	var selected := _weighted_pick(eligible, rng)
	pending_event = selected
	return selected


## Resolves the player's choice. Returns resolved outcomes for the presentation
## layer to apply (RESOURCE_CHANGE, WELLBEING_CHANGE, WORKER_BUSY, MESSAGE).
## SET_FLAG and DELAYED are handled internally.
func resolve_choice(choice_index: int, context: EventContext, rng: RandomNumberGenerator) -> Array:
	if pending_event == null:
		return []
	if choice_index < 0 or choice_index >= pending_event.choices.size():
		return []
	var choice: RefCounted = pending_event.choices[choice_index]
	var resolved: Array = []
	for outcome in choice.outcomes:
		_resolve_outcome(outcome, context, rng, resolved)
	if choice.sets_flag != &"":
		log.set_flag(choice.sets_flag)
	elif pending_event.sets_flag != &"":
		log.set_flag(pending_event.sets_flag)
	log.record(pending_event.id, context.day, choice_index)
	pending_event = null
	return resolved


## Called on day change. Applies any delayed effects whose trigger day has arrived.
## Returns resolved outcomes for the presentation layer to apply.
func advance_day(day: int, context: EventContext, rng: RandomNumberGenerator) -> Array:
	var resolved: Array = []
	var remaining: Array = []
	for effect in pending_delayed:
		if effect.trigger_day <= day:
			_resolve_outcome(effect.outcome, context, rng, resolved)
		else:
			remaining.append(effect)
	pending_delayed = remaining
	return resolved


func has_pending() -> bool:
	return pending_event != null


func clear_pending() -> void:
	pending_event = null


func _filter_eligible(context: EventContext) -> Array:
	var result: Array = []
	for def in registry.by_era(context.era):
		if def.is_eligible(context, log):
			result.append(def)
	return result


func _weighted_pick(eligible: Array, rng: RandomNumberGenerator) -> RefCounted:
	if eligible.size() == 1:
		return eligible[0]
	var total_weight := 0.0
	for def in eligible:
		total_weight += def.weight
	var roll := rng.randf() * total_weight
	var accumulated := 0.0
	for def in eligible:
		accumulated += def.weight
		if roll <= accumulated:
			return def
	return eligible.back()


func _resolve_outcome(outcome: RefCounted, context: EventContext, rng: RandomNumberGenerator, resolved: Array) -> void:
	if outcome.random_chance < 1.0 and not outcome.random_outcomes.is_empty():
		var success: bool = rng.randf() < outcome.random_chance
		var half: int = outcome.random_outcomes.size() / 2
		var picked: Array = []
		if outcome.random_outcomes.size() == 2:
			picked = [outcome.random_outcomes[0]] if success else [outcome.random_outcomes[1]]
		else:
			if success:
				for i in range(0, half):
					picked.append(outcome.random_outcomes[i])
			else:
				for i in range(half, outcome.random_outcomes.size()):
					picked.append(outcome.random_outcomes[i])
		for sub in picked:
			_resolve_outcome(sub, context, rng, resolved)
		return
	match outcome.kind:
		EventOutcome.Kind.SET_FLAG:
			log.set_flag(outcome.flag)
		EventOutcome.Kind.DELAYED:
			if outcome.delayed_outcome != null:
				pending_delayed.append(DelayedEffectScript.create(context.day + outcome.delay_days, outcome.delayed_outcome))
		_:
			resolved.append(outcome)
