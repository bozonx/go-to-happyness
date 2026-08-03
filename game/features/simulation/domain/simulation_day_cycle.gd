class_name SimulationDayCycle
extends RefCounted

## Translates clock minutes into gameplay events. Applying those events belongs
## to application code.
##
## The **schedule** is the settlement's — meals, the working day, lights out
## (`world_environment.md` §4: the calendar owns time, not the timetable of a
## game). The **day number** is not: `current_day` is the calendar's day of the
## session, so the settlement and the season cannot disagree about which day it
## is. It is still writable, because a save restores it and a test poses it.

const MEAL_HOURS := [9, 13, 19]

var clock: SimulationClock
var current_day: int:
	get: return clock.calendar.day_of_session
	set(value): clock.calendar.day_of_session = value
var _active_meal_hour := -1


func _init(next_clock: SimulationClock = null) -> void:
	clock = next_clock if next_clock != null else SimulationClock.new()


## Raises the events for whatever minutes the calendar has passed since the last
## call. It does not move time: the environment director does that, once, for
## everything (§2).
func collect_events(workday_hours: int) -> Array[SimulationDayEvent]:
	var events: Array[SimulationDayEvent] = []
	for clock_minute in clock.elapsed_minutes():
		events.append_array(events_for_minute(clock_minute, workday_hours))
	return events


func events_for_minute(clock_minute: int, workday_hours: int) -> Array[SimulationDayEvent]:
	var events: Array[SimulationDayEvent] = []
	var hour := clock_minute / 60
	var minute := clock_minute % 60
	if minute != 0:
		return events

	if hour == 0:
		# The calendar has already crossed midnight and incremented the day; this
		# only announces it to the settlement's own listeners.
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


func set_to_workday_start() -> void:
	clock.set_time(8 * 60)
	_active_meal_hour = -1


func is_work_time(workday_hours: int) -> bool:
	var hour := clock.hour()
	return hour >= 8 and hour < 8 + workday_hours
