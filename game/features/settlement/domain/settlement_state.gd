class_name SettlementState
extends RefCounted

## Persistent, scene-free settlement economy. All progression gates live here so
## UI and simulation code cannot accidentally create a second rule set.

enum Era { TENT, EARTH, CLAY, WOOD, STONE, BRICK }
enum StorageAvailability { OK, UNKNOWN_RESOURCE, NO_WAREHOUSE, NO_ROOM }

const TENT_STARTING_MONEY := 500
const TENT_STARTING_FOOD := 16
const TENT_STARTING_POPULATION := 4
const TENT_STARTING_WELLBEING := 75
const TENT_STARTING_EQUIPMENT := {
	"flint_steel": {"owned": true},
	"construction_gloves": {"sets": 1, "active_durability": 100.0},
}

var era := Era.TENT
var money := 20
var branches := 0
var grass := 0
var water := 0
var food := 0
var hides := 0
var goods := 0
var logs := 0
var wood := 0 # Hand-cut timber used by existing buildings.
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
var equipment: Dictionary = TENT_STARTING_EQUIPMENT.duplicate(true)
var trade_sales := 0
var buildings: Dictionary = {}
var brick_construction_unlocked := false
var unlocked_building_levels := {
	"living_tent": true,
	"craft_tent": false,
	"house": false,
	"living_tent_lvl2": false,
	"living_tent_lvl3": false,
	"craft_tent_lvl2": false,
	"craft_tent_lvl3": false,
	"house_lvl2": false,
	"house_lvl3": false,
	"dugout_kitchen": false,
	"clay_bakery": false,
	"canteen": false,
	"stone_tavern": false,
	"brick_restaurant": false,
	"toilet_tent_lvl2": false,
	"toilet_tent_lvl3": false,
	"toilet_earth_lvl2": false,
	"toilet_earth_lvl3": false,
	"toilet_clay_lvl2": false,
	"toilet_clay_lvl3": false,
	"toilet_wood_lvl2": false,
	"toilet_wood_lvl3": false,
	"toilet_stone_lvl2": false,
	"toilet_stone_lvl3": false,
	"toilet_brick_lvl2": false,
	"toilet_brick_lvl3": false,
	"tent": false,
	"campfire_lvl2": false,
	"campfire_lvl3": false,
	"warehouse_lvl2": false,
	"dew_collector": true,
	"dew_collector_lvl2": false,
	"dew_collector_lvl3": false,
	"forager_tent": true,
	"forager_tent_lvl2": false,
	"forager_tent_lvl3": false,
}
var active_research_tech_id := ""
var active_research_worker_id := -1
var active_research_remaining_time := 0.0
var active_research_duration := 0.0


func apply_tent_start(reset_progress := true) -> void:
	era = Era.TENT
	money = TENT_STARTING_MONEY
	branches = 0
	grass = 0
	water = 0
	food = TENT_STARTING_FOOD
	hides = 0
	goods = 0
	logs = 0
	wood = 0
	soil = 0
	clay = 0
	boards = 0
	stone = 0
	bricks = 0
	wellbeing = TENT_STARTING_WELLBEING
	workday_hours = 8
	night_shifts_allowed = false
	low_wellbeing_days = 0
	tools = {"axe": false, "hand_saw": false, "shovel": false, "bucket": false, "hoe": false, "pickaxe": false, "filter_1": false}
	tool_uses = {"filter_1": 0}
	equipment = TENT_STARTING_EQUIPMENT.duplicate(true)
	trade_sales = 0
	brick_construction_unlocked = false
	active_research_tech_id = ""
	active_research_worker_id = -1
	active_research_remaining_time = 0.0
	active_research_duration = 0.0
	storage_limits.clear()
	if reset_progress:
		buildings.clear()
		for building_type in unlocked_building_levels.keys():
			unlocked_building_levels[building_type] = _tent_start_unlock_for(building_type)


func _tent_start_unlock_for(building_type: String) -> bool:
	return false

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
	if warehouses <= 0:
		return 0
	var heap_count := int(buildings.get("warehouse", 0))
	var tent_count := int(buildings.get("warehouse_lvl2", 0))
	var capacity := heap_count * 24 + tent_count * 48
	if capacity == 0 and warehouses > 0:
		capacity = warehouses * int(ERA_STORAGE_PER_WAREHOUSE.get(era, 24))
	return capacity


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


func storage_availability_for(resource_type: String, count: int, warehouses: int) -> StorageAvailability:
	if count <= 0:
		return StorageAvailability.OK
	if not STORED_RESOURCES.has(resource_type):
		return StorageAvailability.UNKNOWN_RESOURCE
	if warehouses <= 0:
		return StorageAvailability.NO_WAREHOUSE
	return StorageAvailability.OK if storage_room_for(resource_type) >= count else StorageAvailability.NO_ROOM

func can_make_room_for(resource_type: String, count: int, warehouses: int) -> bool:
	if not STORED_RESOURCES.has(resource_type):
		return true
	var required := count * storage_weight(resource_type)
	var available := maxf(0.0, float(storage_limits.get(resource_type, 0.0)) - amount(resource_type) * storage_weight(resource_type))
	return available + storage_free_units(warehouses) + 0.001 >= required


func reserve_storage_room_for(resource_type: String, count: int, warehouses: int) -> bool:
	if count <= 0 or not STORED_RESOURCES.has(resource_type):
		return count <= 0
	if storage_availability_for(resource_type, count, warehouses) == StorageAvailability.NO_WAREHOUSE:
		return false
	var required_units := count * storage_weight(resource_type)
	var available_units := maxf(0.0, float(storage_limits.get(resource_type, 0.0)) - amount(resource_type) * storage_weight(resource_type))
	var missing_units := maxf(0.0, required_units - available_units)
	if missing_units > 0.0:
		var expansion := minf(missing_units, storage_free_units(warehouses))
		storage_limits[resource_type] = float(storage_limits.get(resource_type, 0.0)) + expansion
	return storage_availability_for(resource_type, count, warehouses) == StorageAvailability.OK


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
	if not is_building_unlocked(building_type):
		return false
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


func is_building_unlocked(building_type: String) -> bool:
	if building_type == "warehouse":
		return true
	if building_type == "campfire":
		return era > Era.TENT or has_building("warehouse") or has_building("campfire")
	if unlocked_building_levels.has(building_type):
		return bool(unlocked_building_levels.get(building_type, false))
	return true


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
			return era == Era.TENT and has_building("campfire") and has_building("trade_tent") and housing_slots >= population and food >= population and water >= population and has_building("craft_tent_lvl3") and has_building("living_tent_lvl3") and trade_sales >= 1 and _has_tools(["axe", "hand_saw", "shovel", "bucket"]) and has_building("toilet_tent_lvl3")
		Era.CLAY:
			return era == Era.EARTH and has_building("earth_assembly") and has_building("smithy") and has_building("earth_market") and housing_slots >= population and clay >= 5 and money >= 5 and trade_sales >= 3 and _has_tools(["hoe"]) and has_building("toilet_earth_lvl3")
		Era.WOOD:
			return era == Era.CLAY and has_building("clay_lodge") and has_building("clay_market") and water >= population and logs >= 10 and money >= 10 and has_building("toilet_clay_lvl3")
		Era.STONE:
			return era == Era.WOOD and has_building("wood_town_hall") and has_building("wood_market") and money >= 15 and _has_tools(["pickaxe"]) and has_building("house_lvl3") and has_building("toilet_wood_lvl3")
		Era.BRICK:
			return era == Era.STONE and has_building("stone_prefecture") and has_building("stone_market") and has_building("masonry_workshop") and stone >= 20 and money >= 20 and has_building("toilet_stone_lvl3")
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
	if not BuildingCatalog.RESEARCH_COSTS.has(research_id):
		return false
	for resource_type in BuildingCatalog.research_resources(research_id):
		if amount(resource_type) < BuildingCatalog.research_cost(research_id, resource_type): return false
	return true


func can_start_building_research(research_id: String) -> bool:
	if not BuildingCatalog.RESEARCH_TECHS.has(research_id):
		return false
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[research_id]
	if era < BuildingCatalog.era_for(str(tech.target_building)) or unlocked_building_levels.get(tech.target_building, false):
		return false
	for prerequisite in tech.get("prerequisites", []):
		if BuildingCatalog.RESEARCH_TECHS.has(prerequisite):
			if not unlocked_building_levels.get(prerequisite, false):
				return false
		elif not has_building(str(prerequisite)):
			return false
	if era == Era.TENT:
		var target: String = str(tech.target_building)
		# The central campfire is itself the gate which unlocks each technology
		# tier, so it must not require the level it is trying to unlock.
		if target == "campfire_lvl3" and not has_building("campfire_lvl2"):
			return false
		if target != "campfire_lvl2" and target != "campfire_lvl3" and target.ends_with("_lvl2") and not has_building("campfire_lvl2") and not has_building("campfire_lvl3"):
			return false
		if target != "campfire_lvl3" and target.ends_with("_lvl3") and not has_building("campfire_lvl3"):
			return false
	return can_afford_research(research_id)


func pay_for_research(research_id: String) -> bool:
	if not can_afford_research(research_id): return false
	for resource_type in BuildingCatalog.research_resources(research_id): add(resource_type, -BuildingCatalog.research_cost(research_id, resource_type))
	return true
