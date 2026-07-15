class_name BuildingCatalog
extends RefCounted

const DEFINITIONS := {
	"campfire": {"name": "Главный костер ур. 1", "category": "tent", "costs": {"branches": 4}, "landmark": true, "demolishable": false},
	"campfire_lvl2": {"name": "Главный костер ур. 2", "category": "tent", "costs": {"branches": 15, "grass": 10}, "landmark": true, "demolishable": false, "upgrade_only": true, "upgrades_from": "campfire"},
	"campfire_lvl3": {"name": "Главный костер ур. 3", "category": "tent", "costs": {"branches": 25, "grass": 18}, "landmark": true, "demolishable": false, "upgrade_only": true, "upgrades_from": "campfire_lvl2"},
	"gathering_place": {"name": "Бадминтонная площадка", "category": "tent", "costs": {"branches": 8, "grass": 6}},
	"cook_campfire": {"name": "Костер для готовки ур. 1", "category": "tent", "costs": {"branches": 8, "grass": 6}},
	"cook_campfire_lvl2": {"name": "Костер для готовки ур. 2", "category": "tent", "costs": {"branches": 14, "grass": 10}, "upgrade_only": true, "upgrades_from": "cook_campfire"},
	"cook_campfire_lvl3": {"name": "Костер для готовки ур. 3", "category": "tent", "costs": {"branches": 22, "grass": 16}, "upgrade_only": true, "upgrades_from": "cook_campfire_lvl2"},
	"tent": {"name": "Временная палатка на 4 жителя", "category": "tent", "costs": {"branches": 4, "grass": 4}},
	"straw_tent": {"name": "Соломенная палатка", "category": "tent", "costs": {"branches": 10, "grass": 8}},
	"tarp_tent": {"name": "Брезентовая палатка", "category": "tent", "costs": {"branches": 8, "grass": 4, "tarp": 1}},
	"straw_forager_tent": {"name": "Соломенная палатка собирателя", "category": "tent", "costs": {"branches": 10, "grass": 4}},
	"tarp_forager_tent": {"name": "Брезентовая палатка собирателя", "category": "tent", "costs": {"branches": 8, "grass": 3, "tarp": 1}},
	"straw_materials_yard": {"name": "Соломенный двор материалов", "category": "tent", "costs": {"branches": 10, "grass": 6}},
	"tarp_materials_yard": {"name": "Брезентовый двор материалов", "category": "tent", "costs": {"branches": 8, "grass": 4, "tarp": 1}},
	"straw_craft_tent": {"name": "Соломенная ремесленная палатка", "category": "tent", "costs": {"branches": 10, "grass": 5}},
	"tarp_craft_tent": {"name": "Брезентовая ремесленная палатка", "category": "tent", "costs": {"branches": 8, "grass": 4, "tarp": 1}},
	"dew_collector": {"name": "Сборщик росы", "category": "tent", "costs": {"branches": 1, "tarp": 1}},
	"advanced_dew_collector": {"name": "Улучшенный сборщик росы", "category": "tent", "costs": {"branches": 12, "grass": 8}},
	"pond": {"name": "Pond", "category": "tent", "costs": {"branches": 8, "grass": 6}},
	"warehouse": {"name": "Склад под открытым небом", "category": "tent", "costs": {}},
	"straw_warehouse": {"name": "Склад с соломенным навесом", "category": "tent", "costs": {"branches": 15, "grass": 12}},
	"tarp_warehouse": {"name": "Склад с брезентовым навесом", "category": "tent", "costs": {"branches": 12, "grass": 8, "tarp": 2}},
	"straw_trade_tent": {"name": "Соломенный торговый шатер", "category": "tent", "costs": {"branches": 10, "grass": 5}},
	"tarp_trade_tent": {"name": "Брезентовый торговый шатер", "category": "tent", "costs": {"branches": 8, "grass": 4, "tarp": 1}},
	"toilet_tent": {"name": "Соломенный общественный туалет", "category": "tent", "costs": {"branches": 8, "grass": 4}},
	"tarp_toilet": {"name": "Брезентовый общественный туалет", "category": "tent", "costs": {"branches": 6, "grass": 3, "tarp": 1}},
	"dugout": {"name": "Dugout", "category": "earth", "costs": {"soil": 12, "branches": 8}},
	"earth_house": {"name": "Earth house", "category": "earth", "costs": {"soil": 20, "branches": 12}},
	"earth_assembly": {"name": "Earth Assembly", "category": "earth", "costs": {"soil": 15, "branches": 10}},
	"dugout_kitchen": {"name": "Dugout kitchen", "category": "earth", "costs": {"soil": 14, "branches": 8}},
	"smithy": {"name": "Smithy", "category": "earth", "costs": {"soil": 18, "branches": 16}},
	"hide_worker": {"name": "Hide workshop", "category": "earth", "costs": {"soil": 12, "branches": 10}},
	"earth_market": {"name": "Earth market", "category": "earth", "costs": {"soil": 15, "branches": 10}},
	"clay_house": {"name": "Clay house", "category": "clay", "costs": {"clay": 12, "grass": 10, "branches": 8}},
	"clay_lodge": {"name": "Clay lodge", "category": "clay", "costs": {"clay": 12, "branches": 10, "grass": 8}},
	"clay_bakery": {"name": "Clay bakery", "category": "clay", "costs": {"clay": 16, "branches": 10, "grass": 6}},
	"clay_workshop": {"name": "Clay workshop", "category": "clay", "costs": {"clay": 15, "grass": 10, "branches": 10}},
	"clay_market": {"name": "Clay market", "category": "clay", "costs": {"clay": 12, "grass": 8, "branches": 6}},
	"stone_house": {"name": "Stone house", "category": "stone", "costs": {"stone": 15, "clay": 8}},
	"stone_prefecture": {"name": "Stone prefecture", "category": "stone", "costs": {"stone": 25, "boards": 12}},
	"stone_tavern": {"name": "Stone tavern", "category": "stone", "costs": {"stone": 20, "boards": 10}},
	"builders_guild": {"name": "Гильдия строителей", "category": "stone", "costs": {"stone": 18, "boards": 8}},
	"masonry_workshop": {"name": "Masonry workshop", "category": "stone", "costs": {"stone": 12, "boards": 12}},
	"stone_market": {"name": "Stone market", "category": "stone", "costs": {"stone": 18, "boards": 8}},
	"sawmill": {"name": "Sawmill", "category": "wood", "costs": {"logs": 4, "money": 1}},
	"farm": {"name": "Farm", "category": "wood", "costs": {"boards": 12}},
	"canteen": {"name": "Canteen", "category": "wood", "costs": {"boards": 16}},
	"wood_town_hall": {"name": "Wooden town hall", "category": "wood", "costs": {"boards": 20}},
	"house": {"name": "Wood house", "category": "wood", "costs": {"boards": 12}},
	"house_lvl2": {"name": "Wood house Level 2", "category": "wood", "costs": {"boards": 18, "logs": 5}},
	"house_lvl3": {"name": "Wood house Level 3", "category": "wood", "costs": {"boards": 24, "logs": 10}},
	"school": {"name": "School", "category": "clay", "costs": {"clay": 15, "branches": 10, "grass": 8}},
	"park": {"name": "Park", "category": "wood", "costs": {"boards": 14}},
	"wood_market": {"name": "Wood market", "category": "wood", "costs": {"boards": 15}},
	"brick_factory": {"name": "Brick kiln", "category": "brick", "costs": {"boards": 12, "soil": 12}},
	"materials_factory": {"name": "Materials factory", "category": "brick", "costs": {"bricks": 18, "boards": 8}},
	"brick_market": {"name": "Brick market", "category": "brick", "costs": {"bricks": 20}},
	"brick_city_hall": {"name": "Brick City Hall", "category": "brick", "costs": {"bricks": 30, "boards": 15}},
	"brick_restaurant": {"name": "Brick restaurant", "category": "brick", "costs": {"bricks": 24, "boards": 12}},
	"brick_house": {"name": "Brick house", "category": "brick", "costs": {"bricks": 22, "boards": 10}},
	"construction_company": {"name": "Строительная фирма", "category": "brick", "costs": {"bricks": 26, "boards": 14}},
	"employment_office": {"name": "Служба занятости", "category": "brick", "costs": {"bricks": 22, "boards": 12}},
	"toilet_earth": {"name": "Земляной туалет ур. 1", "category": "earth", "costs": {"soil": 10, "branches": 6}},
	"toilet_earth_lvl2": {"name": "Земляной туалет ур. 2", "category": "earth", "costs": {"soil": 15, "branches": 8}},
	"toilet_earth_lvl3": {"name": "Земляной туалет ур. 3", "category": "earth", "costs": {"soil": 22, "branches": 12}},
	"toilet_clay": {"name": "Глиняный туалет ур. 1", "category": "clay", "costs": {"clay": 10, "grass": 6}},
	"toilet_clay_lvl2": {"name": "Глиняный туалет ур. 2", "category": "clay", "costs": {"clay": 15, "grass": 8}},
	"toilet_clay_lvl3": {"name": "Глиняный туалет ур. 3", "category": "clay", "costs": {"clay": 22, "grass": 12}},
	"toilet_wood": {"name": "Деревянный туалет ур. 1", "category": "wood", "costs": {"boards": 10, "logs": 3}},
	"toilet_wood_lvl2": {"name": "Деревянный туалет ур. 2", "category": "wood", "costs": {"boards": 15, "logs": 5}},
	"toilet_wood_lvl3": {"name": "Деревянный туалет ур. 3", "category": "wood", "costs": {"boards": 22, "logs": 8}},
	"toilet_stone": {"name": "Каменный туалет ур. 1", "category": "stone", "costs": {"stone": 10, "boards": 6}},
	"toilet_stone_lvl2": {"name": "Каменный туалет ур. 2", "category": "stone", "costs": {"stone": 15, "boards": 8}},
	"toilet_stone_lvl3": {"name": "Каменный туалет ур. 3", "category": "stone", "costs": {"stone": 22, "boards": 12}},
	"toilet_brick": {"name": "Кирпичный туалет ур. 1", "category": "brick", "costs": {"bricks": 10, "boards": 6}},
	"toilet_brick_lvl2": {"name": "Кирпичный туалет ур. 2", "category": "brick", "costs": {"bricks": 15, "boards": 8}},
	"toilet_brick_lvl3": {"name": "Кирпичный туалет ур. 3", "category": "brick", "costs": {"bricks": 22, "boards": 12}},
}

const RESEARCH_COSTS := {
	"brick_construction": {"bricks": 15, "boards": 10},
	"straw_tents": {"branches": 8, "grass": 6},
	"tarp_tents": {"branches": 12, "grass": 8, "tarp": 1},
	"trade": {"branches": 10, "grass": 6},
	"tarp_trade_tent": {"branches": 12, "grass": 6, "tarp": 2},
	"advanced_dew_collector": {"branches": 8, "grass": 4},
	"earth_buildings": {"branches": 12, "grass": 8, "tarp": 2},
	"official": {"branches": 4, "grass": 4},
	"campfire_lvl2": {"branches": 8, "grass": 6},
	"campfire_lvl3": {"branches": 15, "grass": 12},
	"gathering_place": {"branches": 6, "grass": 4},
	"cook_campfire_lvl2": {"branches": 8, "grass": 6},
	"cook_campfire_lvl3": {"branches": 12, "grass": 10},
	"house": {"boards": 10, "logs": 5},
	"house_lvl2": {"boards": 15, "logs": 10},
	"house_lvl3": {"boards": 20, "logs": 15},
	"dugout_kitchen": {"soil": 8, "branches": 4},
	"clay_bakery": {"clay": 8, "branches": 4},
	"canteen": {"boards": 8, "logs": 4},
	"stone_tavern": {"stone": 10, "boards": 6},
	"brick_restaurant": {"bricks": 14, "boards": 8},
	"toilet_earth_lvl2": {"soil": 8, "branches": 6},
	"toilet_earth_lvl3": {"soil": 12, "branches": 10},
	"toilet_clay_lvl2": {"clay": 8, "grass": 6},
	"toilet_clay_lvl3": {"clay": 12, "grass": 10},
	"toilet_wood_lvl2": {"boards": 8, "logs": 4},
	"toilet_wood_lvl3": {"boards": 12, "logs": 6},
	"toilet_stone_lvl2": {"stone": 8, "boards": 6},
	"toilet_stone_lvl3": {"stone": 12, "boards": 10},
	"toilet_brick_lvl2": {"bricks": 8, "boards": 6},
	"toilet_brick_lvl3": {"bricks": 12, "boards": 10},
}

const KITCHEN_FOOD_CAPACITIES := {
	"cook_campfire": 4,
	"cook_campfire_lvl2": 6,
	"cook_campfire_lvl3": 8,
	"dugout_kitchen": 6,
	"clay_bakery": 8,
	"canteen": 12,
	"stone_tavern": 16,
	"brick_restaurant": 20,
}

const RESEARCH_TECHS := {
	"straw_tents": {
		"name": "Палатки из соломы",
		"base_duration": 20.0,
		"required_skill": "construction",
		"target_buildings": ["straw_tent", "straw_forager_tent", "straw_materials_yard", "straw_craft_tent", "straw_warehouse", "toilet_tent"],
		"prerequisites": ["campfire"],
	},
	"tarp_tents": {
		"name": "Использование брезентового тента",
		"base_duration": 40.0,
		"required_skill": "construction",
		"target_buildings": ["tarp_tent", "tarp_forager_tent", "tarp_materials_yard", "tarp_craft_tent", "tarp_warehouse", "tarp_toilet"],
		"prerequisites": ["straw_tents", "campfire_lvl2"],
	},
	"trade": {
		"name": "Торговля",
		"base_duration": 30.0,
		"required_skill": "construction",
		"target_building": "straw_trade_tent",
		"prerequisites": ["straw_tents", "campfire_lvl2"],
	},
	"tarp_trade_tent": {
		"name": "Брезентовый торговый шатер",
		"base_duration": 35.0,
		"required_skill": "construction",
		"target_building": "tarp_trade_tent",
		"prerequisites": ["trade", "tarp_tents", "campfire_lvl2"],
	},
	"advanced_dew_collector": {
		"name": "Улучшенный сборщик росы",
		"base_duration": 30.0,
		"required_skill": "construction",
		"target_building": "advanced_dew_collector",
		"prerequisites": ["campfire"],
	},
	"earth_buildings": {
		"name": "Земляные постройки",
		"base_duration": 50.0,
		"required_skill": "construction",
		"target_buildings": ["dugout", "earth_house", "earth_assembly", "smithy", "hide_worker", "earth_market", "dugout_kitchen"],
		"prerequisites": ["tarp_tents", "campfire_lvl3"],
	},
	"official": {
		"name": "Чиновник",
		"base_duration": 30.0,
		"required_skill": "construction",
		"target_system": "official",
		"prerequisites": ["campfire"],
		"effect": "Enables formal workforce automation.",
		"reward_skill": "official",
	},
	"campfire_lvl2": {
		"name": "Главный костер ур. 2",
		"base_duration": 30.0,
		"required_skill": "construction",
		"target_building": "campfire_lvl2",
		"prerequisites": ["campfire"],
	},
	"campfire_lvl3": {
		"name": "Главный костер ур. 3",
		"base_duration": 50.0,
		"required_skill": "construction",
		"target_building": "campfire_lvl3",
		"prerequisites": ["campfire_lvl2"],
	},
	"gathering_place": {
		"name": "Бадминтонная площадка",
		"base_duration": 25.0,
		"required_skill": "construction",
		"target_building": "gathering_place",
		"prerequisites": ["campfire_lvl2"],
		"effect": "Место отдыха жителей.",
	},
	"cook_campfire_lvl2": {
		"name": "Костер для готовки ур. 2",
		"base_duration": 30.0,
		"required_skill": "construction",
		"target_building": "cook_campfire_lvl2",
		"prerequisites": ["cook_campfire"],
		"effect": "Запас еды: 6",
		"reward_skill": "cook",
	},
	"cook_campfire_lvl3": {
		"name": "Костер для готовки ур. 3",
		"base_duration": 45.0,
		"required_skill": "construction",
		"target_building": "cook_campfire_lvl3",
		"prerequisites": ["cook_campfire_lvl2"],
		"effect": "Запас еды: 8",
		"reward_skill": "cook",
	},
	"house": {
		"name": "Дом ур. 1",
		"base_duration": 40.0,
		"required_skill": "construction",
		"target_building": "house",
		"prerequisites": [],
	},
	"house_lvl2": {
		"name": "Дом ур. 2",
		"base_duration": 60.0,
		"required_skill": "construction",
		"target_building": "house_lvl2",
		"prerequisites": ["house"],
	},
	"house_lvl3": {
		"name": "Дом ур. 3",
		"base_duration": 80.0,
		"required_skill": "construction",
		"target_building": "house_lvl3",
		"prerequisites": ["house_lvl2"],
	},
	"dugout_kitchen": {
		"name": "Земляная кухня",
		"base_duration": 25.0,
		"required_skill": "construction",
		"target_building": "dugout_kitchen",
		"prerequisites": ["cook_campfire_lvl3"],
		"effect": "Запас еды: 6",
		"reward_skill": "cook",
	},
	"clay_bakery": {
		"name": "Глиняная пекарня",
		"base_duration": 40.0,
		"required_skill": "construction",
		"target_building": "clay_bakery",
		"prerequisites": ["dugout_kitchen"],
		"effect": "Запас еды: 8",
		"reward_skill": "cook",
	},
	"canteen": {
		"name": "Столовая",
		"base_duration": 55.0,
		"required_skill": "construction",
		"target_building": "canteen",
		"prerequisites": ["clay_bakery"],
		"effect": "Запас еды: 12",
		"reward_skill": "cook",
	},
	"stone_tavern": {
		"name": "Каменная таверна",
		"base_duration": 70.0,
		"required_skill": "construction",
		"target_building": "stone_tavern",
		"prerequisites": ["canteen"],
		"effect": "Запас еды: 16",
		"reward_skill": "cook",
	},
	"brick_restaurant": {
		"name": "Кирпичный ресторан",
		"base_duration": 90.0,
		"required_skill": "construction",
		"target_building": "brick_restaurant",
		"prerequisites": ["stone_tavern"],
		"effect": "Запас еды: 20",
		"reward_skill": "cook",
	},
	"toilet_earth_lvl2": {
		"name": "Земляной туалет ур. 2",
		"base_duration": 30.0,
		"required_skill": "construction",
		"target_building": "toilet_earth_lvl2",
		"prerequisites": ["toilet_earth"],
	},
	"toilet_earth_lvl3": {
		"name": "Земляной туалет ур. 3",
		"base_duration": 50.0,
		"required_skill": "construction",
		"target_building": "toilet_earth_lvl3",
		"prerequisites": ["toilet_earth_lvl2"],
	},
	"toilet_clay_lvl2": {
		"name": "Глиняный туалет ур. 2",
		"base_duration": 35.0,
		"required_skill": "construction",
		"target_building": "toilet_clay_lvl2",
		"prerequisites": ["toilet_clay"],
	},
	"toilet_clay_lvl3": {
		"name": "Глиняный туалет ур. 3",
		"base_duration": 55.0,
		"required_skill": "construction",
		"target_building": "toilet_clay_lvl3",
		"prerequisites": ["toilet_clay_lvl2"],
	},
	"toilet_wood_lvl2": {
		"name": "Деревянный туалет ур. 2",
		"base_duration": 40.0,
		"required_skill": "construction",
		"target_building": "toilet_wood_lvl2",
		"prerequisites": ["toilet_wood"],
	},
	"toilet_wood_lvl3": {
		"name": "Деревянный туалет ур. 3",
		"base_duration": 60.0,
		"required_skill": "construction",
		"target_building": "toilet_wood_lvl3",
		"prerequisites": ["toilet_wood_lvl2"],
	},
	"toilet_stone_lvl2": {
		"name": "Каменный туалет ур. 2",
		"base_duration": 45.0,
		"required_skill": "construction",
		"target_building": "toilet_stone_lvl2",
		"prerequisites": ["toilet_stone"],
	},
	"toilet_stone_lvl3": {
		"name": "Каменный туалет ур. 3",
		"base_duration": 65.0,
		"required_skill": "construction",
		"target_building": "toilet_stone_lvl3",
		"prerequisites": ["toilet_stone_lvl2"],
	},
	"toilet_brick_lvl2": {
		"name": "Кирпичный туалет ур. 2",
		"base_duration": 50.0,
		"required_skill": "construction",
		"target_building": "toilet_brick_lvl2",
		"prerequisites": ["toilet_brick"],
	},
	"toilet_brick_lvl3": {
		"name": "Кирпичный туалет ур. 3",
		"base_duration": 70.0,
		"required_skill": "construction",
		"target_building": "toilet_brick_lvl3",
		"prerequisites": ["toilet_brick_lvl2"],
	}
}

static func definition_for(building_type: String) -> Dictionary: return DEFINITIONS.get(building_type, DEFINITIONS.house).duplicate(true)
static func cost_resources(building_type: String) -> Array[String]:
	var result: Array[String] = []
	for resource_type in definition_for(building_type).get("costs", {}): result.append(resource_type)
	return result
static func cost_for_resource(building_type: String, resource_type: String) -> int: return int(definition_for(building_type).get("costs", {}).get(resource_type, 0))
static func cost_for(building_type: String) -> int:
	var costs: Dictionary = definition_for(building_type).get("costs", {})
	return int(costs.values()[0]) if costs.size() == 1 else 0
static func demolition_refund(building_type: String) -> Dictionary:
	var recovered := {}
	var costs: Dictionary = definition_for(building_type).get("costs", {})
	for resource_type in costs:
		var refund_ratio := 0.30 if building_type == "tent" else 0.35
		var refund_amount := floori(int(costs[resource_type]) * refund_ratio)
		recovered[resource_type] = refund_amount if building_type == "tent" else maxi(1, refund_amount)
	return recovered
static func currency_for(building_type: String) -> String:
	var resources := cost_resources(building_type)
	return resources[0] if resources.size() == 1 else ""
static func is_landmark(building_type: String) -> bool:
	return bool(definition_for(building_type).get("landmark", false))
static func is_demolishable(building_type: String) -> bool:
	return bool(definition_for(building_type).get("demolishable", true))
static func is_upgrade_only(building_type: String) -> bool:
	return bool(definition_for(building_type).get("upgrade_only", false))
static func upgrades_from(building_type: String) -> String:
	return str(definition_for(building_type).get("upgrades_from", ""))
static func next_upgrade_for(building_type: String) -> String:
	for candidate in DEFINITIONS.keys():
		if upgrades_from(str(candidate)) == building_type:
			return str(candidate)
	return ""
static func era_for(building_type: String) -> SettlementState.Era:
	match str(definition_for(building_type).get("category", "tent")):
		"earth": return SettlementState.Era.EARTH
		"clay": return SettlementState.Era.CLAY
		"wood": return SettlementState.Era.WOOD
		"stone": return SettlementState.Era.STONE
		"brick": return SettlementState.Era.BRICK
	return SettlementState.Era.TENT
static func research_cost(research_id: String, resource_type: String) -> int: return int(RESEARCH_COSTS.get(research_id, {}).get(resource_type, 0))
static func research_resources(research_id: String) -> Array[String]:
	var resources: Array[String] = []
	for resource_type in RESEARCH_COSTS.get(research_id, {}): resources.append(resource_type)
	return resources

static func kitchen_food_capacity(building_type: String) -> int:
	return int(KITCHEN_FOOD_CAPACITIES.get(building_type, 0))
