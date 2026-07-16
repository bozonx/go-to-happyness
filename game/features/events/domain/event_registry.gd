class_name EventRegistry
extends RefCounted

## Registry of all game event definitions. Events are registered once at
## startup and filtered by era when rolling daily events.

var _events: Array[GameEventDef] = []
var _by_era: Dictionary = {}


func register(def: GameEventDef) -> void:
	_events.append(def)
	var era_key: int = def.era
	if not _by_era.has(era_key):
		_by_era[era_key] = [] as Array[GameEventDef]
	(_by_era[era_key] as Array[GameEventDef]).append(def)


func register_all(defs: Array[GameEventDef]) -> void:
	for def in defs:
		register(def)


func all() -> Array[GameEventDef]:
	return _events.duplicate()


func by_era(era: int) -> Array[GameEventDef]:
	if not _by_era.has(era):
		return []
	return (_by_era[era] as Array[GameEventDef]).duplicate()


func find_by_id(event_id: StringName) -> GameEventDef:
	for def in _events:
		if def.id == event_id:
			return def
	return null
