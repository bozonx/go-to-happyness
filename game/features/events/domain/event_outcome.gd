class_name EventOutcome
extends RefCounted

## A single effect applied to game state when an event choice is resolved.
## Pure data — no references to nodes, UI, or scene tree.

enum Kind {
	MESSAGE,
	RESOURCE_CHANGE,
	WELLBEING_CHANGE,
	WORKER_BUSY,
	SET_FLAG,
	DELAYED,
}

var kind: int = Kind.MESSAGE
var resource: String = ""
var amount: int = 0
var wellbeing_delta: int = 0
var worker_busy_hours: float = 0.0
var worker_busy_label: String = ""
var text: String = ""
var delay_days: int = 0
var delayed_outcome: RefCounted = null
var flag: StringName = &""
var random_chance: float = 1.0
var random_outcomes: Array = []


const _script = preload("res://game/features/events/domain/event_outcome.gd")


static func message(next_text: String) -> RefCounted:
	var o: RefCounted = _script.new()
	o.kind = Kind.MESSAGE
	o.text = next_text
	return o


static func resource_change(res: String, qty: int) -> RefCounted:
	var o: RefCounted = _script.new()
	o.kind = Kind.RESOURCE_CHANGE
	o.resource = res
	o.amount = qty
	return o


static func wellbeing(delta: int) -> RefCounted:
	var o: RefCounted = _script.new()
	o.kind = Kind.WELLBEING_CHANGE
	o.wellbeing_delta = delta
	return o


static func worker_busy(hours: float, label: String) -> RefCounted:
	var o: RefCounted = _script.new()
	o.kind = Kind.WORKER_BUSY
	o.worker_busy_hours = hours
	o.worker_busy_label = label
	return o


static func set_flag(flag_name: StringName) -> RefCounted:
	var o: RefCounted = _script.new()
	o.kind = Kind.SET_FLAG
	o.flag = flag_name
	return o


static func delayed(days: int, outcome: RefCounted) -> RefCounted:
	var o: RefCounted = _script.new()
	o.kind = Kind.DELAYED
	o.delay_days = days
	o.delayed_outcome = outcome
	return o


static func random_with_chance(chance: float, success: Array, failure: Array) -> RefCounted:
	var o: RefCounted = _script.new()
	o.kind = Kind.MESSAGE
	o.random_chance = chance
	o.random_outcomes = success.duplicate()
	for f in failure:
		o.random_outcomes.append(f)
	return o
