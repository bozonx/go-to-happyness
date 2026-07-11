class_name CitizenTaskState
extends RefCounted

## Time-based task progression independent from physics and navigation.

var remaining := 0.0


func start(duration: float) -> void:
	remaining = maxf(0.0, duration)


func advance(delta: float) -> bool:
	remaining -= delta
	return remaining <= 0.0
