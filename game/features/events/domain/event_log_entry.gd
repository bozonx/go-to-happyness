class_name EventLogEntry
extends RefCounted

## A single recorded event in the event log history.

var event_id: StringName = &""
var day: int = 0
var choice_index: int = 0


const _script = preload("res://game/features/events/domain/event_log_entry.gd")


static func create(p_event_id: StringName, p_day: int, p_choice_index: int) -> RefCounted:
	var e: RefCounted = _script.new()
	e.event_id = p_event_id
	e.day = p_day
	e.choice_index = p_choice_index
	return e
