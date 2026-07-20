class_name ResearchProgress
extends RefCounted

## Tracks the currently active building research: which tech, which worker,
## and how much time remains.

var tech_id := ""
var worker_id := -1
var remaining_time := 0.0
var duration := 0.0


func is_active() -> bool:
	return not tech_id.is_empty()


func start(p_tech_id: String, p_worker_id: int, p_duration: float) -> void:
	tech_id = p_tech_id
	worker_id = p_worker_id
	duration = p_duration
	remaining_time = p_duration


func advance(delta: float, speed_multiplier: float) -> void:
	remaining_time -= delta * maxf(0.0, speed_multiplier)


func is_complete() -> bool:
	return is_active() and remaining_time <= 0.0


func progress_pct() -> float:
	if duration <= 0.0:
		return 0.0
	return clampf((1.0 - (remaining_time / duration)) * 100.0, 0.0, 100.0)


func clear() -> void:
	tech_id = ""
	worker_id = -1
	remaining_time = 0.0
	duration = 0.0


func reset() -> void:
	clear()
