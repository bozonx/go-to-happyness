class_name EventLog
extends RefCounted

## Journal of past events and a flag store for event chains.
## Pure domain — no references to nodes or UI.

var entries: Array[EventLogEntry] = []
var flags: Dictionary = {}
var _last_day_for: Dictionary = {}


func record(event_id: StringName, day: int, choice_index: int) -> void:
	entries.append(EventLogEntry.create(event_id, day, choice_index))
	_last_day_for[event_id] = day


func is_on_cooldown(event_id: StringName, current_day: int, cooldown_days: int) -> bool:
	if not _last_day_for.has(event_id):
		return false
	var last_day: int = int(_last_day_for[event_id])
	return current_day - last_day < cooldown_days


func has_flag(flag: StringName) -> bool:
	return flags.has(flag)


func set_flag(flag: StringName) -> void:
	flags[flag] = true


func clear_flag(flag: StringName) -> void:
	flags.erase(flag)


func clear_all_flags() -> void:
	flags.clear()


func reset() -> void:
	entries.clear()
	flags.clear()
	_last_day_for.clear()
