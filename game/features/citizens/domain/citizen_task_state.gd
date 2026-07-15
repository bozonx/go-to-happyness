class_name CitizenTaskState
extends RefCounted

## Time-based task progression independent from physics and navigation.

var remaining := 0.0
var duration := 0.0


func start(next_duration: float) -> void:
	duration = maxf(0.0, next_duration)
	remaining = duration


func advance(delta: float) -> bool:
	remaining -= delta
	return remaining <= 0.0


func progress() -> float:
	if duration <= 0.0:
		return 0.0
	return clampf(1.0 - remaining / duration, 0.0, 1.0)
