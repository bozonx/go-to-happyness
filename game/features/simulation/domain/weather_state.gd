class_name WeatherState
extends RefCounted

## Deterministic rain scheduling for a single in-game day.
## The forecast is announced at a known minute; actual rain starts randomly after
## that and lasts at least a configurable minimum. Intensity fades in/out smoothly
## for visual transitions.

const MINUTES_PER_DAY := 24 * 60
const DEFAULT_TRANSITION_MINUTES := 30.0
const MIN_DURATION_MINUTES := 180

enum Phase { CLEAR, FADE_IN, FULL_RAIN, FADE_OUT }

var forecast_weather: int = -1
var is_raining: bool = false
var rain_start_minute: float = -1.0
var rain_end_minute: float = -1.0
var transition_minutes: float = DEFAULT_TRANSITION_MINUTES
var _previous_minute: float = -1.0


func new_day(weather: int, rng: RandomNumberGenerator, announcement_minute: int = 6 * 60) -> void:
	forecast_weather = weather
	is_raining = false
	rain_start_minute = -1.0
	rain_end_minute = -1.0
	_previous_minute = -1.0

	if weather != TentEraSurvivalRules.Weather.RAIN:
		return

	var latest_start := MINUTES_PER_DAY - MIN_DURATION_MINUTES
	if announcement_minute >= latest_start:
		announcement_minute = maxi(0, latest_start - 1)
	var start_minute := rng.randi_range(announcement_minute, latest_start)
	var end_minute := rng.randi_range(start_minute + MIN_DURATION_MINUTES, MINUTES_PER_DAY)
	rain_start_minute = float(start_minute)
	rain_end_minute = float(end_minute)


func update(current_minute: float) -> bool:
	var previous := is_raining
	_previous_minute = current_minute
	if forecast_weather != TentEraSurvivalRules.Weather.RAIN or rain_start_minute < 0.0:
		is_raining = false
	else:
		is_raining = current_minute >= rain_start_minute and current_minute < rain_end_minute
	return previous != is_raining


func intensity_at(current_minute: float) -> float:
	if forecast_weather != TentEraSurvivalRules.Weather.RAIN or rain_start_minute < 0.0:
		return 0.0
	if current_minute < rain_start_minute:
		return 0.0
	if current_minute >= rain_end_minute:
		return 0.0
	if current_minute < rain_start_minute + transition_minutes:
		return (current_minute - rain_start_minute) / transition_minutes
	if current_minute > rain_end_minute - transition_minutes:
		return (rain_end_minute - current_minute) / transition_minutes
	return 1.0


func phase_at(current_minute: float) -> int:
	var intensity := intensity_at(current_minute)
	if intensity <= 0.0:
		return Phase.CLEAR
	if intensity >= 1.0:
		return Phase.FULL_RAIN
	if current_minute < rain_start_minute + transition_minutes:
		return Phase.FADE_IN
	return Phase.FADE_OUT
