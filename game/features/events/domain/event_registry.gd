class_name EventRegistry
extends RefCounted

## Registry of all game event definitions. Events are registered once at
## startup and filtered by era when rolling daily events.

var _events: Array = []
var _by_era: Dictionary = {}


func register(def: RefCounted) -> void:
	_events.append(def)
	var era_key: int = def.era
	if not _by_era.has(era_key):
		_by_era[era_key] = []
	(_by_era[era_key] as Array).append(def)


func register_all(defs: Array) -> void:
	for def in defs:
		register(def)


func all() -> Array:
	return _events.duplicate()


func by_era(era: int) -> Array:
	if not _by_era.has(era):
		return []
	return (_by_era[era] as Array).duplicate()


func find_by_id(event_id: StringName) -> RefCounted:
	for def in _events:
		if def.id == event_id:
			return def
	return null
