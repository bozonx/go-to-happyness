class_name BuildingCatalog
extends RefCounted

## Single source of truth for buildable content and its economy rules.
## Geometry stays in BuildingBlueprints; this catalog describes game rules.

const WOOD := "wood"
const BRICKS := "bricks"

const DEFINITIONS := {
	"warehouse": {"name": "Warehouse", "category": "wood", "cost": 10, "currency": WOOD},
	"sawmill": {"name": "Sawmill", "category": "wood", "cost": 10, "currency": WOOD},
	"farm": {"name": "Farm", "category": "wood", "cost": 12, "currency": WOOD},
	"canteen": {"name": "Canteen", "category": "wood", "cost": 16, "currency": WOOD},
	"house": {"name": "House", "category": "wood", "cost": 12, "currency": WOOD},
	"school": {"name": "School", "category": "wood", "cost": 18, "currency": WOOD},
	"park": {"name": "Park", "category": "wood", "cost": 14, "currency": WOOD},
	"brick_factory": {"name": "Brick factory", "category": "brick", "cost": 24, "currency": WOOD},
	"materials_factory": {"name": "Materials factory", "category": "brick", "cost": 28, "currency": WOOD},
	"recycling_factory": {"name": "Recycling factory", "category": "brick", "cost": 25, "currency": BRICKS},
	"metal_factory": {"name": "Metal factory", "category": "brick", "cost": 25, "currency": BRICKS},
	"city_hall": {"name": "City hall", "category": "brick", "cost": 35, "currency": BRICKS},
	"leisure_center": {"name": "Leisure center", "category": "brick", "cost": 30, "currency": BRICKS},
}

const RESEARCH_COSTS := {
	"brick_construction": {"bricks": 15, "boards": 10},
}


static func definition_for(building_type: String) -> Dictionary:
	return DEFINITIONS.get(building_type, DEFINITIONS.house).duplicate()


static func cost_for(building_type: String) -> int:
	return int(definition_for(building_type).cost)


static func currency_for(building_type: String) -> String:
	return str(definition_for(building_type).currency)


static func research_cost(research_id: String, resource_type: String) -> int:
	return int(RESEARCH_COSTS.get(research_id, {}).get(resource_type, 0))
