class_name DelayedEffect
extends RefCounted

## A pending outcome that triggers after a number of in-game days.
## Stored by EventService and applied when advance_day() is called.

var trigger_day: int = 0
var outcome: RefCounted = null


const _script = preload("res://game/features/events/application/delayed_effect.gd")


static func create(p_trigger_day: int, p_outcome: RefCounted) -> RefCounted:
	var d: RefCounted = _script.new()
	d.trigger_day = p_trigger_day
	d.outcome = p_outcome
	return d
