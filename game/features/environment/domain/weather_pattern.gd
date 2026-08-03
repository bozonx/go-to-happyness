class_name WeatherPattern
extends RefCounted

## A named profile for one day's weather (`world_environment.md` §7).
##
## This exists to break an ownership error: the forecast used to be
## `TentEraSurvivalRules.Weather`, a settlement enum that the engine's weather
## accepted as input — so a shooter or a racing map inherited the tent era's
## "warming" and "cooling" along with the sky. A pattern speaks only about the
## sky: how much cloud, how much wind, whether and when it rains.
##
## A game keeps its own forecast vocabulary and maps onto these **from outside**.
## The settlement still announces "Потепление" to the player while handing the
## environment `clear`.

const DEFAULT_ID := &"fair"

var id: StringName = DEFAULT_ID
var display_name := "Переменная облачность"
## Fair-weather cloudiness this day settles around, and how far it breathes from
## there over the hours (§8). Never grey by itself — murk is the front's alone.
var cloud_base := 0.24
var cloud_variation := 0.20
var wind_base_strength := 0.35
var wind_gust_amount := 0.22
## Chance the day carries precipitation at all. `1.0` for a rain pattern, `0.0`
## for a clear one; values between are what makes a "showers possible" day.
var precipitation_chance := 0.0
## The window precipitation may occupy and the shortest it may last, in minutes
## of the day. Precipitation takes part of a day, never all of it (§7).
var precipitation_earliest := 6 * 60
var precipitation_latest_end := 24 * 60
var precipitation_min_duration := 180
## How hard the front presses when this pattern does precipitate. Scales the grey
## ceiling and the gale, so `rain` and `storm` differ by a number rather than by
## a second code path.
var storm_scale := 1.0
## Relative likelihood per season id, for the generator that will replace the
## fixed cycle later (§7). Absent season means the pattern's base weight of 1.
var season_weights: Dictionary = {}


static func from_dict(source: Dictionary) -> WeatherPattern:
	var pattern := WeatherPattern.new()
	pattern.id = StringName(source.get("id", pattern.id))
	pattern.display_name = String(source.get("display_name", pattern.display_name))
	pattern.cloud_base = clampf(float(source.get("cloud_base", pattern.cloud_base)), 0.0, 1.0)
	pattern.cloud_variation = clampf(float(source.get("cloud_variation", pattern.cloud_variation)), 0.0, 1.0)
	pattern.wind_base_strength = clampf(float(source.get("wind_base_strength", pattern.wind_base_strength)), 0.0, 1.0)
	pattern.wind_gust_amount = clampf(float(source.get("wind_gust_amount", pattern.wind_gust_amount)), 0.0, 1.0)
	pattern.precipitation_chance = clampf(float(source.get("precipitation_chance", pattern.precipitation_chance)), 0.0, 1.0)
	pattern.precipitation_earliest = int(source.get("precipitation_earliest", pattern.precipitation_earliest))
	pattern.precipitation_latest_end = int(source.get("precipitation_latest_end", pattern.precipitation_latest_end))
	pattern.precipitation_min_duration = maxi(1, int(source.get("precipitation_min_duration", pattern.precipitation_min_duration)))
	pattern.storm_scale = clampf(float(source.get("storm_scale", pattern.storm_scale)), 0.0, 1.0)
	var weights: Variant = source.get("season_weights", {})
	if weights is Dictionary:
		for key: Variant in weights as Dictionary:
			pattern.season_weights[StringName(key)] = float((weights as Dictionary)[key])
	return pattern


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"display_name": display_name,
		"cloud_base": cloud_base,
		"cloud_variation": cloud_variation,
		"wind_base_strength": wind_base_strength,
		"wind_gust_amount": wind_gust_amount,
		"precipitation_chance": precipitation_chance,
		"precipitation_earliest": precipitation_earliest,
		"precipitation_latest_end": precipitation_latest_end,
		"precipitation_min_duration": precipitation_min_duration,
		"storm_scale": storm_scale,
		"season_weights": season_weights.duplicate(true),
	}


func weight_for_season(season: StringName) -> float:
	return float(season_weights.get(season, 1.0))
