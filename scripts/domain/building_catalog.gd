class_name BuildingCatalog
extends RefCounted

const DEFINITIONS := {
	"campfire": {"name": "Campfire", "category": "tent", "costs": {"branches": 6}},
	"tent": {"name": "Tent", "category": "tent", "costs": {"branches": 8, "grass": 6}},
	"forager_tent": {"name": "Forager tent", "category": "tent", "costs": {"branches": 10, "grass": 4}},
	"craft_tent": {"name": "Craft tent", "category": "tent", "costs": {"branches": 10, "grass": 5}},
	"water_store": {"name": "Water store", "category": "tent", "costs": {"branches": 6, "grass": 4}},
	"warehouse": {"name": "Simple store", "category": "tent", "costs": {"branches": 12, "grass": 4}},
	"dugout": {"name": "Dugout", "category": "earth", "costs": {"soil": 12, "branches": 8}},
	"earth_house": {"name": "Earth house", "category": "earth", "costs": {"soil": 20, "wood": 6}},
	"smithy": {"name": "Smithy", "category": "earth", "costs": {"soil": 18, "wood": 8}},
	"hide_worker": {"name": "Hide workshop", "category": "earth", "costs": {"soil": 12, "wood": 6}},
	"sawmill": {"name": "Sawmill", "category": "wood", "costs": {"logs": 4, "money": 1}},
	"farm": {"name": "Farm", "category": "wood", "costs": {"boards": 12}},
	"canteen": {"name": "Canteen", "category": "wood", "costs": {"boards": 16}},
	"house": {"name": "Wood house", "category": "wood", "costs": {"boards": 12}},
	"school": {"name": "School", "category": "wood", "costs": {"boards": 18}},
	"park": {"name": "Park", "category": "wood", "costs": {"boards": 14}},
	"brick_factory": {"name": "Brick kiln", "category": "brick", "costs": {"wood": 12, "soil": 12}},
	"materials_factory": {"name": "Materials factory", "category": "brick", "costs": {"bricks": 18, "boards": 8}},
}

const RESEARCH_COSTS := {"brick_construction": {"bricks": 15, "boards": 10}}

static func definition_for(building_type: String) -> Dictionary: return DEFINITIONS.get(building_type, DEFINITIONS.house).duplicate(true)
static func cost_resources(building_type: String) -> Array[String]:
	var result: Array[String] = []
	for resource_type in definition_for(building_type).get("costs", {}): result.append(resource_type)
	return result
static func cost_for_resource(building_type: String, resource_type: String) -> int: return int(definition_for(building_type).get("costs", {}).get(resource_type, 0))
static func cost_for(building_type: String) -> int:
	var costs: Dictionary = definition_for(building_type).get("costs", {})
	return int(costs.values()[0]) if costs.size() == 1 else 0
static func currency_for(building_type: String) -> String:
	var resources := cost_resources(building_type)
	return resources[0] if resources.size() == 1 else ""
static func era_for(building_type: String) -> SettlementState.Era:
	match str(definition_for(building_type).get("category", "tent")):
		"earth": return SettlementState.Era.EARTH
		"wood": return SettlementState.Era.WOOD
		"brick": return SettlementState.Era.BRICK
	return SettlementState.Era.TENT
static func research_cost(research_id: String, resource_type: String) -> int: return int(RESEARCH_COSTS.get(research_id, {}).get(resource_type, 0))
static func research_resources(research_id: String) -> Array[String]:
	var resources: Array[String] = []
	for resource_type in RESEARCH_COSTS.get(research_id, {}): resources.append(resource_type)
	return resources
