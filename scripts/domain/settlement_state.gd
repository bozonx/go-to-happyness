class_name SettlementState
extends RefCounted

## Persistent, scene-free settlement economy. All progression gates live here so
## UI and simulation code cannot accidentally create a second rule set.

enum Era { TENT, EARTH, CLAY, WOOD, STONE, BRICK }

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
var stone := 0
var bricks := 0
var wellbeing := 75
var workday_hours := 8
var night_shifts_allowed := false
var low_wellbeing_days := 0
var tools := {"axe": false, "hand_saw": false, "shovel": false, "bucket": false, "hoe": false, "pickaxe": false, "filter_1": false}
var tool_uses := {"filter_1": 0}
var trade_sales := 0
var buildings: Dictionary = {}
var brick_construction_unlocked := false

## --- Weighted, reallocatable storage ------------------------------------------
## Every stored good takes up "space units". The warehouse holds a fixed number of
## units for the current era; the player splits that budget between resources in
## the warehouse menu. Heavy goods (logs, bricks) cost more than a unit each;
## water is light and packs several to a unit.
const STORED_RESOURCES := ["branches", "grass", "water", "food", "hides", "goods", "logs", "wood", "soil", "clay", "boards", "stone", "bricks"]
const STORAGE_WEIGHTS := {
	"branches": 1.0, "grass": 1.0, "water": 0.5, "food": 1.0,
	"hides": 1.0, "goods": 1.0, "logs": 2.0, "wood": 2.0,
	"soil": 1.0, "clay": 1.0, "boards": 1.5, "stone": 2.0, "bricks": 2.0,
}
const ERA_STORAGE_PER_WAREHOUSE := {Era.TENT: 32, Era.EARTH: 48, Era.CLAY: 70, Era.WOOD: 100, Era.STONE: 120, Era.BRICK: 150}
const STORAGE_STEP := 4.0

var storage_limits: Dictionary = {} # resource -> allocated space units (float)


func storage_weight(resource_type: String) -> float:
	return float(STORAGE_WEIGHTS.get(resource_type, 1.0))


func storage_capacity(warehouses: int) -> int:
	return maxi(0, warehouses) * int(ERA_STORAGE_PER_WAREHOUSE.get(era, 24))


func storage_used_units() -> float:
	var total := 0.0
	for resource_type in STORED_RESOURCES:
		total += amount(resource_type) * storage_weight(resource_type)
	return total


func _storage_allocated_units() -> float:
	var total := 0.0
	for resource_type in STORED_RESOURCES:
		total += float(storage_limits.get(resource_type, 0.0))
	return total


func storage_free_units(warehouses: int) -> float:
	return maxf(0.0, storage_capacity(warehouses) - _storage_allocated_units())


func storage_limit(resource_type: String) -> float:
	return float(storage_limits.get(resource_type, 0.0))


func ensure_storage_defaults(warehouses: int) -> void:
	# Capacity exists only in placed warehouses. Existing overflow (for example a
	# debug grant) is preserved, but does not create additional free capacity.
	if storage_limits.is_empty():
		for resource_type in STORED_RESOURCES:
			storage_limits[resource_type] = 0.0
		var primary := ["branches", "grass", "water", "food"]
		for resource_type in primary:
			storage_limits[resource_type] = amount(resource_type) * storage_weight(resource_type)
		var share := storage_free_units(warehouses) / primary.size()
		for resource_type in primary:
			storage_limits[resource_type] += share
	_clamp_storage_limits(warehouses)


func _clamp_storage_limits(warehouses: int) -> void:
	# Never let allocations exceed the capacity or drop below what is already stored.
	var capacity := float(storage_capacity(warehouses))
	for resource_type in STORED_RESOURCES:
		var used := amount(resource_type) * storage_weight(resource_type)
		storage_limits[resource_type] = maxf(float(storage_limits.get(resource_type, 0.0)), used)
	if _storage_allocated_units() > capacity:
		# Trim the fat proportionally from any headroom above what is stored.
		var overflow := _storage_allocated_units() - capacity
		for resource_type in STORED_RESOURCES:
			if overflow <= 0.0:
				break
			var used := amount(resource_type) * storage_weight(resource_type)
			var slack := float(storage_limits[resource_type]) - used
			var cut := minf(slack, overflow)
			storage_limits[resource_type] -= cut
			overflow -= cut


func adjust_storage_limit(resource_type: String, delta_units: float, warehouses: int) -> void:
	if not STORED_RESOURCES.has(resource_type):
		return
	var current := float(storage_limits.get(resource_type, 0.0))
	var used := amount(resource_type) * storage_weight(resource_type)
	var target := current + delta_units
	if delta_units > 0.0:
		target = minf(target, current + storage_free_units(warehouses))
	target = maxf(target, used) # cannot squeeze below what is already there
	storage_limits[resource_type] = maxf(0.0, target)


func storage_room_for(resource_type: String) -> int:
	if not STORED_RESOURCES.has(resource_type):
		return 1 << 30
	var weight := storage_weight(resource_type)
	var headroom := float(storage_limits.get(resource_type, 0.0)) - amount(resource_type) * weight
	return maxi(0, int(floor((headroom + 0.001) / weight)))


func storage_can_accept(resource_type: String, count: int) -> bool:
	return storage_room_for(resource_type) >= count

func can_make_room_for(resource_type: String, count: int, warehouses: int) -> bool:
	if not STORED_RESOURCES.has(resource_type):
		return true
	var required := count * storage_weight(resource_type)
	var available := maxf(0.0, float(storage_limits.get(resource_type, 0.0)) - amount(resource_type) * storage_weight(resource_type))
	return available + storage_free_units(warehouses) + 0.001 >= required


func reserve_storage_room_for(resource_type: String, count: int, warehouses: int) -> bool:
	if count <= 0 or not STORED_RESOURCES.has(resource_type):
		return count <= 0
	var required_units := count * storage_weight(resource_type)
	var available_units := maxf(0.0, float(storage_limits.get(resource_type, 0.0)) - amount(resource_type) * storage_weight(resource_type))
	var missing_units := maxf(0.0, required_units - available_units)
	if missing_units > 0.0:
		var expansion := minf(missing_units, storage_free_units(warehouses))
		storage_limits[resource_type] = float(storage_limits.get(resource_type, 0.0)) + expansion
	return storage_can_accept(resource_type, count)


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
		"stone": return stone
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
		"stone": stone += value
		"bricks": bricks += value


func total_stored_resources() -> int:
	return branches + grass + water + food + hides + goods + logs + wood + soil + clay + boards + stone + bricks


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
	if tool_id == "filter_1":
		tool_uses[tool_id] = 12
	return true

func use_filter() -> bool:
	var uses := int(tool_uses.get("filter_1", 0))
	if not bool(tools.get("filter_1", false)) or uses <= 0:
		tools["filter_1"] = false
		return false
	tool_uses["filter_1"] = uses - 1
	if uses == 1:
		tools["filter_1"] = false
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
			return era == Era.TENT and has_building("campfire") and has_building("trade_tent") and housing_slots >= population and food >= population and water >= population and has_building("craft_tent") and trade_sales >= 1 and _has_tools(["axe", "hand_saw", "shovel", "bucket"])
		Era.CLAY:
			return era == Era.EARTH and has_building("earth_assembly") and has_building("smithy") and has_building("earth_market") and housing_slots >= population and clay >= 5 and money >= 5 and trade_sales >= 3 and _has_tools(["hoe"])
		Era.WOOD:
			return era == Era.CLAY and has_building("clay_lodge") and has_building("clay_market") and water >= population and logs >= 10 and money >= 10
		Era.STONE:
			return era == Era.WOOD and has_building("wood_town_hall") and has_building("wood_market") and money >= 15 and _has_tools(["pickaxe"])
		Era.BRICK:
			return era == Era.STONE and has_building("stone_prefecture") and has_building("stone_market") and has_building("masonry_workshop") and stone >= 20 and money >= 20
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
