class_name BuildingTypes
extends RefCounted

## Centralized building type string constants.
## One source of truth for all building category lists used across the codebase.

const FIRE_SOURCE_TYPES: Array[String] = [
	"campfire", "campfire_lvl2", "campfire_lvl3",
	"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3",
]

const CIVIC_TYPES: Array[String] = [
	"campfire", "campfire_lvl2", "campfire_lvl3",
	"earth_assembly", "clay_lodge", "wood_town_hall",
	"stone_prefecture", "brick_city_hall",
]

const KITCHEN_TYPES: Array[String] = [
	"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3",
	"dugout_kitchen", "clay_bakery", "canteen",
	"stone_tavern", "brick_restaurant",
]

const COOK_CAMPFIRE_TYPES: Array[String] = [
	"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3",
]

const MARKET_TYPES: Array[String] = [
	"straw_trade_tent", "tarp_trade_tent",
	"earth_market", "clay_market", "wood_market",
	"stone_market", "brick_market",
]

const FACTORY_TYPES: Array[String] = [
	"brick_factory", "materials_factory",
	"recycling_factory", "metal_factory",
]

const WAREHOUSE_TYPES: Array[String] = [
	"warehouse", "straw_warehouse", "tarp_warehouse",
]

const HOUSING_TYPES: Array[String] = [
	"tent", "straw_tent", "tarp_tent",
	"dugout", "earth_house", "clay_house", "stone_house",
	"house", "house_lvl2", "house_lvl3", "brick_house",
]

const FORAGER_TENT_TYPES: Array[String] = [
	"forager_tent", "straw_forager_tent", "tarp_forager_tent",
]

const MATERIALS_YARD_TYPES: Array[String] = [
	"materials_yard", "straw_materials_yard", "tarp_materials_yard",
]

const CRAFT_TENT_TYPES: Array[String] = [
	"craft_tent", "straw_craft_tent", "tarp_craft_tent",
]


static func is_fire_source(building_type: String) -> bool:
	return building_type in FIRE_SOURCE_TYPES


static func is_civic(building_type: String) -> bool:
	return building_type in CIVIC_TYPES


static func is_kitchen(building_type: String) -> bool:
	return building_type in KITCHEN_TYPES


static func is_cook_campfire(building_type: String) -> bool:
	return building_type in COOK_CAMPFIRE_TYPES


static func is_market(building_type: String) -> bool:
	return building_type in MARKET_TYPES


static func is_factory(building_type: String) -> bool:
	return building_type in FACTORY_TYPES


static func is_warehouse(building_type: String) -> bool:
	return building_type in WAREHOUSE_TYPES


static func is_housing(building_type: String) -> bool:
	return building_type in HOUSING_TYPES


static func is_forager_tent(building_type: String) -> bool:
	return building_type in FORAGER_TENT_TYPES


static func is_materials_yard(building_type: String) -> bool:
	return building_type in MATERIALS_YARD_TYPES


static func is_craft_tent(building_type: String) -> bool:
	return building_type in CRAFT_TENT_TYPES
