class_name SimulationClock
extends RefCounted

const MINUTES_PER_DAY := 24 * 60

# Start at the beginning of the workday: the initial freelance reserve can
# immediately gather the materials required for the first warehouse and fire.
var minutes := 8.0 * 60.0
var _previous_minute := -1


func advance(delta: float, game_minutes_per_second: float) -> PackedInt32Array:
	minutes = fposmod(minutes + delta * game_minutes_per_second, MINUTES_PER_DAY)
	var current_minute := int(minutes)
	var elapsed_minutes := PackedInt32Array()
	if _previous_minute >= 0:
		var minute_to_process := posmod(_previous_minute + 1, MINUTES_PER_DAY)
		while minute_to_process != posmod(current_minute + 1, MINUTES_PER_DAY):
			elapsed_minutes.append(minute_to_process)
			minute_to_process = posmod(minute_to_process + 1, MINUTES_PER_DAY)
	_previous_minute = current_minute
	return elapsed_minutes


func set_time(minute_of_day: int) -> void:
	# Jump straight to a time of day without replaying the skipped minutes.
	minutes = fposmod(float(minute_of_day), MINUTES_PER_DAY)
	_previous_minute = int(minutes)


func hour() -> int:
	return int(minutes) / 60


func minute() -> int:
	return int(minutes) % 60


func is_night() -> bool:
	var current_hour := hour()
	return current_hour >= 21 or current_hour < 6
