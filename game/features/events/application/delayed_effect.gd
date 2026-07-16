class_name DelayedEffect
extends RefCounted

## A pending outcome that triggers after a number of in-game days.
## Stored by EventService and applied when advance_day() is called.

var trigger_day: int = 0
var outcome: EventOutcome = null


static func create(p_trigger_day: int, p_outcome: EventOutcome) -> DelayedEffect:
	var d := DelayedEffect.new()
	d.trigger_day = p_trigger_day
	d.outcome = p_outcome
	return d
