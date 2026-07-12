class_name SimulationDayEvent
extends RefCounted

## A deterministic event produced at a whole in-game minute. Runtime systems decide
## how to apply it; this value object does not reference actors, UI or scene nodes.

enum Kind {
	DAY_STARTED,
	MEAL,
	PARK_REST,
	WORKDAY_ENDED,
	RETURN_HOME,
	NIGHTFALL,
	WORKDAY_STARTED,
	SCHOOL_DAY_ENDED,
	DAILY_SETTLEMENT_UPDATE,
}

var kind: int
var hour := -1
var cooks_only := false


func _init(next_kind: int, next_hour := -1, next_cooks_only := false) -> void:
	kind = next_kind
	hour = next_hour
	cooks_only = next_cooks_only
