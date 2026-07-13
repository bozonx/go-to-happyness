class_name AIBlackboard
extends RefCounted

## Mutable memory owned by one brain. Snapshots are facts about the world;
## blackboard values are local memory about decisions and behavior progress.

var _values: Dictionary = {}
var _cooldowns: Dictionary = {}


## Records that `goal_id` just failed and should be dampened until `expires_at`
## (simulation seconds). Keeps a failing task from being re-selected and re-built
## every think tick — the degenerate idle-loop the old GOAP brain suffered.
func set_cooldown(goal_id: StringName, expires_at: float) -> void:
	_cooldowns[goal_id] = expires_at


## Remaining cooldown fraction in [0, 1] for `goal_id`: 1.0 right after a failure,
## decaying linearly to 0.0 at expiry. Goals whose need keeps rising still win
## eventually, so a genuinely critical need is never permanently suppressed.
func cooldown_penalty(goal_id: StringName, simulation_seconds: float, window: float) -> float:
	var expires_at := float(_cooldowns.get(goal_id, -1.0))
	if expires_at < 0.0 or simulation_seconds >= expires_at or window <= 0.0:
		return 0.0
	return clampf((expires_at - simulation_seconds) / window, 0.0, 1.0)


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
