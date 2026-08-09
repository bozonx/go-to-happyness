class_name SimulationClock
extends RefCounted

## The settlement's view of the game clock.
##
## It no longer owns time. `WorldCalendar` does (`world_environment.md` §4): the
## day of year, the year and the day of the session live there because a season
## needs them and because a cutscene and another game on the engine need to reach
## them. What stays here is the settlement's reading of that clock — the minute,
## the hour, and "is it night" in the scheduling sense of the word, which is a
## working-day question and not an astronomical one (the sun's real position is
## `EnvironmentSnapshot.solar_height`).
##
## Nothing here advances anything. The environment director advances the calendar
## once per frame, and `elapsed_minutes()` reports which whole minutes went by so
## the day cycle can raise its events for them.

const MINUTES_PER_DAY := 24 * 60

var calendar := WorldCalendar.new()
var _director: EnvironmentDirector = null
var minutes: float:
	get: return _director.snapshot().minute_of_day if _director != null else calendar.minute_of_day
	set(value):
		if _bound_to_session:
			push_error("SimulationClock is read-only while bound; write through EnvironmentDirector")
			return
		calendar.minute_of_day = fposmod(value, MINUTES_PER_DAY)
		# Placing the clock is not living through the interval: forget the last
		# minute seen so a restore does not replay half a day of meal events.
		_previous_minute = int(calendar.minute_of_day)

var _previous_minute := -1
var _bound_to_session := false


## Points this clock at the session's calendar. Called when the settlement scene
## is bound to a world session; until then the clock reads its own calendar so
## tests and tools work without a session.
func bind(director: EnvironmentDirector) -> void:
	if director == null:
		return
	_director = director
	_bound_to_session = true
	_previous_minute = int(minutes)


func day_of_session() -> int:
	return _director.snapshot().day_of_session if _director != null else calendar.day_of_session


func is_bound_to_session() -> bool:
	return _bound_to_session


## The whole game minutes crossed since the previous call, in order. Works across
## a jump for the same reason it works across midnight: it walks from the last
## minute seen to the current one rather than trusting a delta.
func elapsed_minutes() -> PackedInt32Array:
	var current_minute := int(minutes)
	var elapsed := PackedInt32Array()
	if _previous_minute >= 0 and _previous_minute != current_minute:
		var minute_to_process := posmod(_previous_minute + 1, MINUTES_PER_DAY)
		while minute_to_process != posmod(current_minute + 1, MINUTES_PER_DAY):
			elapsed.append(minute_to_process)
			minute_to_process = posmod(minute_to_process + 1, MINUTES_PER_DAY)
	_previous_minute = current_minute
	return elapsed


## Places the clock at a time of day without replaying the skipped minutes and
## without moving the calendar's day. This is the restore-and-test affordance;
## a *scripted* jump goes through `EnvironmentDirector.set_time_of_day`, which
## crosses midnight properly and lets accumulation catch up (§13.1).
func set_time(minute_of_day: int) -> void:
	if _bound_to_session:
		push_error("SimulationClock is read-only while bound; write through EnvironmentDirector")
		return
	calendar.minute_of_day = fposmod(float(minute_of_day), MINUTES_PER_DAY)
	_previous_minute = int(calendar.minute_of_day)


func hour() -> int:
	return int(minutes) / 60


func minute() -> int:
	return int(minutes) % 60


## Night as the settlement schedules it — bedtime, not the sun. Daylight questions
## belong to the snapshot, which knows the day of year and the latitude.
func is_night() -> bool:
	var current_hour := hour()
	return current_hour >= 21 or current_hour < 6
