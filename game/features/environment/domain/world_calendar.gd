class_name WorldCalendar
extends RefCounted

## The one owner of game time (`world_environment.md` §4).
##
## Before this, time was the minute of day and it belonged to the settlement.
## That was wrong twice over: without a day of year there can be no season, and
## without an owner in the session no other game and no cutscene can reach the
## clock.
##
## `day_of_session` and `day_of_year` are **different numbers**. The settlement
## counts its own days from the start of the run ("on the third night"), the
## season counts the day of the year. They coincide today only because runs start
## on day one, and nothing may be built on that coincidence.
##
## Jumps — skipping a night, a cutscene setting the hour — are operations *of the
## calendar*, not an addition to somebody's clock behind its back. The calendar
## announces the crossing so every other system subscribes instead of each
## noticing the new day its own way.

signal day_started(day_of_session: int)
signal day_of_year_changed(day_of_year: int)
## Emitted for every jump that is not the ordinary flow of time, with how many
## game minutes were skipped. Accumulations use it to catch up (§13.1).
signal time_jumped(skipped_minutes: float)

const MINUTES_PER_DAY := 24 * 60

var minute_of_day := 8.0 * 60.0
var day_of_year := 120
var year := 1
var day_of_session := 1
var latitude := 54.0
## Multiplier on the flow of time, zero included — a paused world is a calendar
## with `time_scale == 0`, not a special case somewhere else.
var time_scale := 1.0
var days_per_year := 365

## Minutes consumed since the calendar was created, never wrapped. Continuous
## animation (cloud drift, the star sphere, the lunar month) reads this, so a
## jump forward scrolls them rather than restarting them.
var elapsed_minutes := 0.0


func configure(
	p_minute_of_day: float,
	p_day_of_year: int,
	p_latitude: float,
	p_days_per_year: int,
) -> void:
	days_per_year = maxi(1, p_days_per_year)
	minute_of_day = fposmod(p_minute_of_day, float(MINUTES_PER_DAY))
	day_of_year = _wrap_day(p_day_of_year)
	latitude = clampf(p_latitude, -90.0, 90.0)
	year = 1
	day_of_session = 1
	elapsed_minutes = 0.0


## Advances by real seconds. Returns the whole game minutes that elapsed, in
## order, so a caller that reacts per minute keeps working across a skip.
func advance(delta: float, game_minutes_per_second: float) -> float:
	var minutes := delta * game_minutes_per_second * time_scale
	if minutes <= 0.0:
		return 0.0
	_consume(minutes, false)
	return minutes


## Moves time forward by game minutes without replaying anything in between. This
## is what "skip the night" and a cutscene's `set_time` become: crossings are
## still announced, and `time_jumped` tells accumulation how much to catch up on.
func jump_minutes(minutes: float) -> void:
	if minutes <= 0.0:
		return
	_consume(minutes, true)


## Sets the time of day, moving forward to reach it — a calendar never runs
## backwards on its own, because accumulation cannot be un-accumulated. Asking
## for an hour already past therefore lands on it tomorrow.
func set_time_of_day(minute: int) -> void:
	var target := fposmod(float(minute), float(MINUTES_PER_DAY))
	var delta := target - minute_of_day
	if delta <= 0.0:
		delta += float(MINUTES_PER_DAY)
	jump_minutes(delta)


## Sets the day of year, moving forward to reach it. Same reasoning as above; a
## scripted "make it winter" therefore fast-forwards the world into winter and
## the snow that should be lying is lying.
func set_day_of_year(target_day: int) -> void:
	var target := _wrap_day(target_day)
	var days := posmod(target - day_of_year, days_per_year)
	if days == 0:
		return
	jump_minutes(float(days) * float(MINUTES_PER_DAY))


## Moves the clock in **either** direction without announcing a crossing and
## without letting anything accumulate. This is an inspection affordance for the
## laboratory (§17) and nothing else: a world cannot run backwards, because snow
## that fell cannot un-fall (§13.1). A lab has no snow to un-fall.
func scrub(minutes: float) -> void:
	elapsed_minutes += minutes
	var total := minute_of_day + minutes
	var crossed := floori(total / float(MINUTES_PER_DAY))
	minute_of_day = fposmod(total, float(MINUTES_PER_DAY))
	if crossed == 0:
		return
	day_of_session += crossed
	day_of_year = _wrap_day(day_of_year + crossed)


func hour() -> int:
	return int(minute_of_day) / 60


func minute() -> int:
	return int(minute_of_day) % 60


## Fraction of the year elapsed, for anything sampling the annual curve directly.
func year_phase() -> float:
	return float(day_of_year - 1) / float(days_per_year)


func snapshot_state() -> Dictionary:
	return {
		"minute_of_day": minute_of_day,
		"day_of_year": day_of_year,
		"year": year,
		"day_of_session": day_of_session,
		"latitude": latitude,
		"time_scale": time_scale,
		"days_per_year": days_per_year,
		"elapsed_minutes": elapsed_minutes,
	}


func restore_state(state: Dictionary) -> void:
	days_per_year = maxi(1, int(state.get("days_per_year", days_per_year)))
	minute_of_day = fposmod(float(state.get("minute_of_day", minute_of_day)), float(MINUTES_PER_DAY))
	day_of_year = _wrap_day(int(state.get("day_of_year", day_of_year)))
	year = int(state.get("year", year))
	day_of_session = int(state.get("day_of_session", day_of_session))
	latitude = clampf(float(state.get("latitude", latitude)), -90.0, 90.0)
	time_scale = float(state.get("time_scale", time_scale))
	elapsed_minutes = float(state.get("elapsed_minutes", elapsed_minutes))


## The single place minutes are added. Both the ordinary flow and every jump go
## through it, which is why a skipped night crosses midnight exactly the way a
## lived one does.
func _consume(minutes: float, is_jump: bool) -> void:
	elapsed_minutes += minutes
	var total := minute_of_day + minutes
	var crossed := int(floorf(total / float(MINUTES_PER_DAY)))
	minute_of_day = fposmod(total, float(MINUTES_PER_DAY))
	if is_jump:
		time_jumped.emit(minutes)
	for _crossing in range(crossed):
		day_of_session += 1
		day_of_year += 1
		if day_of_year > days_per_year:
			day_of_year = 1
			year += 1
		day_of_year_changed.emit(day_of_year)
		day_started.emit(day_of_session)


func _wrap_day(day: int) -> int:
	return posmod(day - 1, days_per_year) + 1
