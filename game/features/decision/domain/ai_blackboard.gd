class_name AIBlackboard
extends RefCounted

## Mutable memory owned by one brain. Snapshots are facts about the world;
## blackboard values are local memory about decisions and behavior progress.

var _values: Dictionary = {}


func has(key: StringName) -> bool:
	return _values.has(key)


func value(key: StringName, default_value: Variant = null) -> Variant:
	return _values.get(key, default_value)


func set_value(key: StringName, next_value: Variant) -> void:
	_values[key] = next_value


func erase(key: StringName) -> void:
	_values.erase(key)


func clear() -> void:
	_values.clear()
