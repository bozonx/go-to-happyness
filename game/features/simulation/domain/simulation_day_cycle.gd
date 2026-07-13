class_name SimulationDayCycle
extends RefCounted

## Owns deterministic day progression and translates clock minutes into gameplay
## events. Applying those events belongs to application code.

const MEAL_HOURS := [9, 13, 19]

var clock: SimulationClock
var current_day := 1
var _active_meal_hour := -1


func _init(next_clock: SimulationClock = null) -> void:
	clock = next_clock if next_clock != null else SimulationClock.new()


func advance(delta: float, game_minutes_per_second: float, workday_hours: int) -> Array[SimulationDayEvent]:
	var events: Array[SimulationDayEvent] = []
	for clock_minute in clock.advance(delta, game_minutes_per_second):
		events.append_array(events_for_minute(clock_minute, workday_hours))
	return events


func events_for_minute(clock_minute: int, workday_hours: int) -> Array[SimulationDayEvent]:
	var events: Array[SimulationDayEvent] = []
	var hour := clock_minute / 60
	var minute := clock_minute % 60
	if minute != 0:
		return events

	if hour == 0:
		current_day += 1
		events.append(SimulationDayEvent.new(SimulationDayEvent.Kind.DAY_STARTED, hour))
	if MEAL_HOURS.has(hour) and _active_meal_hour != hour:
		_active_meal_hour = hour
		events.append(SimulationDayEvent.new(SimulationDayEvent.Kind.MEAL, hour))
	if hour == 14:
		events.append(SimulationDayEvent.new(SimulationDayEvent.Kind.PARK_REST, hour, false))
	if hour == 16:
		events.append(SimulationDayEvent.new(SimulationDayEvent.Kind.PARK_REST, hour, true))
	if hour == 18:
		events.append(SimulationDayEvent.new(SimulationDayEvent.Kind.PARK_REST, hour, false))
	if hour == 8 + workday_hours:
		events.append(SimulationDayEvent.new(SimulationDayEvent.Kind.WORKDAY_ENDED, hour))
	if hour == 21:
		events.append(SimulationDayEvent.new(SimulationDayEvent.Kind.NIGHTFALL, hour))
	if hour == 8:
		_active_meal_hour = -1
		events.append(SimulationDayEvent.new(SimulationDayEvent.Kind.WORKDAY_STARTED, hour))
	if hour == 12:
		events.append(SimulationDayEvent.new(SimulationDayEvent.Kind.SCHOOL_DAY_ENDED, hour))
	if hour == 6:
		events.append(SimulationDayEvent.new(SimulationDayEvent.Kind.DAILY_SETTLEMENT_UPDATE, hour))
	return events


func start_next_day() -> void:
	current_day += 1


func set_to_workday_start() -> void:
	clock.set_time(8 * 60)
	_active_meal_hour = -1


func is_work_time(workday_hours: int, night_shifts_allowed: bool) -> bool:
	if night_shifts_allowed:
		return true
	var hour := clock.hour()
	return hour >= 8 and hour < 8 + workday_hours
