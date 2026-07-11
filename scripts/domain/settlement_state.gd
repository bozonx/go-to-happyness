class_name SettlementState
extends RefCounted

## Runtime model for persistent settlement progress.
## Keep scene nodes out of this object so economy rules remain headless-testable.

var wood := 30
var food := 20
var soil := 0
var clay := 0
var boards := 0
var bricks := 0
var wellbeing := 75
var brick_construction_unlocked := false


func amount(resource_type: String) -> int:
	match resource_type:
		"wood": return wood
		"food": return food
		"soil": return soil
		"clay": return clay
		"boards": return boards
		"bricks": return bricks
	return 0


func add(resource_type: String, value: int) -> void:
	match resource_type:
		"wood": wood += value
		"food": food += value
		"soil": soil += value
		"clay": clay += value
		"boards": boards += value
		"bricks": bricks += value


func total_stored_resources() -> int:
	return wood + food + soil + clay + boards + bricks


func can_afford_building(building_type: String) -> bool:
	var cost := BuildingCatalog.cost_for(building_type)
	return amount(BuildingCatalog.currency_for(building_type)) >= cost


func pay_for_building(building_type: String) -> bool:
	if not can_afford_building(building_type):
		return false
	add(BuildingCatalog.currency_for(building_type), -BuildingCatalog.cost_for(building_type))
	return true


func can_afford_research(research_id: String) -> bool:
	for resource_type in BuildingCatalog.research_resources(research_id):
		if amount(resource_type) < BuildingCatalog.research_cost(research_id, resource_type):
			return false
	return true


func pay_for_research(research_id: String) -> bool:
	if not can_afford_research(research_id):
		return false
	for resource_type in BuildingCatalog.research_resources(research_id):
		add(resource_type, -BuildingCatalog.research_cost(research_id, resource_type))
	return true
