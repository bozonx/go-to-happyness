class_name WeatherState
extends RefCounted

## Deterministic rain and cloud scheduling for a single in-game day.
##
## Cloud cover is deliberately separate from precipitation: a cool day can be
## cloudy without raining, while rain builds a storm ceiling before the first
## drops fall. Presentation consumes only the continuous cover value and never
## needs to know how the forecast was chosen.

const MINUTES_PER_DAY := 24 * 60
const DEFAULT_TRANSITION_MINUTES := 30.0
const MIN_DURATION_MINUTES := 180
const CLOUD_BUILDUP_MINUTES := 150.0
const CLOUD_CLEARING_MINUTES := 105.0

enum Phase { CLEAR, FADE_IN, FULL_RAIN, FADE_OUT }
enum CloudPhase { CLEAR, FAIR, PARTLY_CLOUDY, CLOUDY, OVERCAST, STORM }

var forecast_weather: int = -1
var is_raining: bool = false
var rain_start_minute: float = -1.0
var rain_end_minute: float = -1.0
var transition_minutes: float = DEFAULT_TRANSITION_MINUTES
var cloud_base_cover := 0.0
var cloud_variation := 0.0
var cloud_seed := 0.0
var _previous_minute: float = -1.0


func new_day(weather: int, rng: RandomNumberGenerator, announcement_minute: int = 6 * 60) -> void:
	forecast_weather = weather
	is_raining = false
	rain_start_minute = -1.0
	rain_end_minute = -1.0
	_previous_minute = -1.0
	_match_cloud_profile(weather, rng)

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


func cloud_cover_at(current_minute: float) -> float:
	var minutes := fposmod(current_minute, float(MINUTES_PER_DAY))
	var cover := cloud_base_cover + sin(minutes / MINUTES_PER_DAY * TAU + cloud_seed) * cloud_variation
	if forecast_weather == TentEraSurvivalRules.Weather.RAIN and rain_start_minute >= 0.0:
		var storm_arrival := smoothstep(rain_start_minute - CLOUD_BUILDUP_MINUTES, rain_start_minute + transition_minutes, minutes)
		var storm_departure := 1.0 - smoothstep(rain_end_minute - transition_minutes, rain_end_minute + CLOUD_CLEARING_MINUTES, minutes)
		cover = lerpf(cover, 0.96, storm_arrival * storm_departure)
	return clampf(cover, 0.0, 1.0)


func cloud_phase_at(current_minute: float) -> int:
	var cover := cloud_cover_at(current_minute)
	if cover < 0.08:
		return CloudPhase.CLEAR
	if cover < 0.22:
		return CloudPhase.FAIR
	if cover < 0.42:
		return CloudPhase.PARTLY_CLOUDY
	if cover < 0.67:
		return CloudPhase.CLOUDY
	if cover < 0.88:
		return CloudPhase.OVERCAST
	return CloudPhase.STORM


func _match_cloud_profile(weather: int, rng: RandomNumberGenerator) -> void:
	cloud_seed = rng.randf_range(0.0, TAU)
	match weather:
		TentEraSurvivalRules.Weather.WARMING:
			cloud_base_cover = 0.10
			cloud_variation = 0.07
		TentEraSurvivalRules.Weather.COOLING:
			cloud_base_cover = 0.52
			cloud_variation = 0.14
		TentEraSurvivalRules.Weather.RAIN:
			cloud_base_cover = 0.34
			cloud_variation = 0.10
		_:
			cloud_base_cover = 0.18
			cloud_variation = 0.08
