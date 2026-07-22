class_name TentEraSurvivalRules
extends RefCounted

## Rules specific to the fragile first era. Keeping them scene-free makes the
## daily simulation, UI and future events use the same survival contract.

const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

enum Weather { WARMING, COOLING, RAIN }

const WEATHER_NAMES := {
	Weather.WARMING: "Warming",
	Weather.COOLING: "Cooling",
	Weather.RAIN: "Rain",
}

static func weather_for_day(day: int) -> int:
	# Stable cycle is intentional for now: it is testable and lets the player
	# plan around the morning forecast. A future event generator may replace it.
	return posmod(day - 1, 3)

static func hourly_wellbeing_loss(has_home: bool, has_lit_fire: bool, weather: int, is_night: bool) -> int:
	var loss := 0
	if is_night and not has_home:
		loss += 6 if weather == Weather.COOLING else 3
	if not has_lit_fire:
		loss += 2
	return loss

static func daily_food_consumption(population: int, weather: int) -> int:
	var multiplier := 1.25 if weather == Weather.COOLING else 1.0
	return ceili(population * multiplier)

static func rain_hourly_decay_losses(amounts: Dictionary, exposed_ratio := 1.0) -> Dictionary:
	var losses := {}
	for resource_type in [ResourceIds.FOOD, ResourceIds.GRASS, ResourceIds.BRANCHES, ResourceIds.WOOD, ResourceIds.LOGS]:
		var amount := int(amounts.get(resource_type, 0))
		if amount > 0:
			var exposed_amount := amount * clampf(exposed_ratio, 0.0, 1.0)
			losses[resource_type] = mini(amount, ceili(exposed_amount * 0.05))
	return losses


## Daily decay for ground piles. Biological goods rot (5% per day, 10% in rain),
## crafted goods rot slowly only while it is raining, stone/clay/bricks are
## inert, and water evaporates under the sun (non-rain days).
const PILE_BIOLOGICAL := [ResourceIds.FOOD, ResourceIds.GRASS, ResourceIds.BRANCHES, ResourceIds.LOGS, ResourceIds.WOOD, ResourceIds.HIDES]
const PILE_CRAFTED := [ResourceIds.GOODS, ResourceIds.BOARDS, ResourceIds.TARP]
const PILE_INERT := [ResourceIds.STONE, ResourceIds.CLAY, ResourceIds.BRICKS, ResourceIds.SOIL]

static func pile_decay_rate(resource_type: String, is_raining: bool) -> float:
	if resource_type in PILE_BIOLOGICAL:
		return 0.10 if is_raining else 0.05
	if resource_type in PILE_CRAFTED:
		return 0.03 if is_raining else 0.0
	if resource_type == ResourceIds.WATER:
		return 0.0 if is_raining else 0.05
	return 0.0
