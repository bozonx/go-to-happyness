class_name AIBlackboard
extends RefCounted

## Mutable memory owned by one brain. Snapshots are facts about the world;
## blackboard values are local memory about decisions and behavior progress.

var _values: Dictionary = {}
var _cooldowns: Dictionary = {}


## Records that `goal_id` just failed and should be dampened until `expires_at`
## (simulation seconds). Keeps a failing task from being re-selected and re-built
## every think tick, preventing a degenerate idle-loop after a failed task.
func set_cooldown(goal_id: StringName, expires_at: float) -> void:
	_cooldowns[goal_id] = expires_at


## True while a failed goal must not be selected again. The arbiter may explicitly
## override this only for a critical utility, so ordinary failures cannot rebuild a
## task every think cycle.
func is_on_cooldown(goal_id: StringName, simulation_seconds: float) -> bool:
	var expires_at := float(_cooldowns.get(goal_id, -1.0))
	return expires_at >= 0.0 and simulation_seconds < expires_at


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
	_cooldowns.clear()
