class_name SettlementState
extends RefCounted

## Persistent, scene-free settlement economy. All progression gates live here so
## UI and simulation code cannot accidentally create a second rule set.

enum Era { TENT, EARTH, WOOD, BRICK }

var era := Era.TENT
var money := 20
var branches := 0
var grass := 0
var water := 0
var food := 0
var hides := 0
var goods := 0
var logs := 0
var wood := 0 # Legacy name for hand-cut timber used by existing buildings.
var soil := 0
var clay := 0
var boards := 0
var bricks := 0
var wellbeing := 75
var workday_hours := 8
var night_shifts_allowed := false
var low_wellbeing_days := 0
var tools := {"axe": false, "hand_saw": false, "shovel": false, "bucket": false, "sawmill_kit": false}
var trade_sales := 0
var buildings: Dictionary = {}
var brick_construction_unlocked := false


func amount(resource_type: String) -> int:
	match resource_type:
		"money": return money
		"branches": return branches
		"grass": return grass
		"water": return water
		"food": return food
		"hides": return hides
		"goods": return goods
		"logs": return logs
		"wood": return wood
		"soil": return soil
		"clay": return clay
		"boards": return boards
		"bricks": return bricks
	return 0


func add(resource_type: String, value: int) -> void:
	match resource_type:
		"money": money += value
		"branches": branches += value
		"grass": grass += value
		"water": water += value
		"food": food += value
		"hides": hides += value
		"goods": goods += value
		"logs": logs += value
		"wood": wood += value
		"soil": soil += value
		"clay": clay += value
		"boards": boards += value
		"bricks": bricks += value


func total_stored_resources() -> int:
	return branches + grass + water + food + hides + goods + logs + wood + soil + clay + boards + bricks


func can_afford_building(building_type: String) -> bool:
	for resource_type in BuildingCatalog.cost_resources(building_type):
		if amount(resource_type) < BuildingCatalog.cost_for_resource(building_type, resource_type):
			return false
	return BuildingCatalog.era_for(building_type) <= era


func pay_for_building(building_type: String) -> bool:
	if not can_afford_building(building_type):
		return false
	for resource_type in BuildingCatalog.cost_resources(building_type):
		add(resource_type, -BuildingCatalog.cost_for_resource(building_type, resource_type))
	buildings[building_type] = int(buildings.get(building_type, 0)) + 1
	return true


func has_building(building_type: String) -> bool:
	return int(buildings.get(building_type, 0)) > 0


func buy_tool(tool_id: String, price: int) -> bool:
	if not tools.has(tool_id) or bool(tools[tool_id]) or money < price:
		return false
	money -= price
	tools[tool_id] = true
	return true


func sell(resource_type: String, quantity: int, unit_price: int) -> bool:
	if quantity <= 0 or amount(resource_type) < quantity:
		return false
	add(resource_type, -quantity)
	money += quantity * unit_price
	trade_sales += 1
	return true


func can_advance_to(next_era: Era, population: int, housing_slots: int) -> bool:
	match next_era:
		Era.EARTH:
			return era == Era.TENT and has_building("campfire") and housing_slots >= population and food >= population and water >= population and has_building("craft_tent") and trade_sales >= 1 and _has_tools(["axe", "hand_saw", "shovel", "bucket"])
		Era.WOOD:
			return era == Era.EARTH and has_building("smithy") and water >= population and logs >= 4 and money >= 1 and bool(tools.sawmill_kit) and has_building("sawmill")
		Era.BRICK:
			return era == Era.WOOD and has_building("brick_factory") and clay >= 1
	return false


func advance_era(next_era: Era, population: int, housing_slots: int) -> bool:
	if not can_advance_to(next_era, population, housing_slots):
		return false
	era = next_era
	if era == Era.BRICK:
		brick_construction_unlocked = true
	return true


func _has_tools(required: Array) -> bool:
	for tool_id in required:
		if not bool(tools.get(tool_id, false)):
			return false
	return true


func can_afford_research(research_id: String) -> bool:
	for resource_type in BuildingCatalog.research_resources(research_id):
		if amount(resource_type) < BuildingCatalog.research_cost(research_id, resource_type): return false
	return true


func pay_for_research(research_id: String) -> bool:
	if not can_afford_research(research_id): return false
	for resource_type in BuildingCatalog.research_resources(research_id): add(resource_type, -BuildingCatalog.research_cost(research_id, resource_type))
	return true
