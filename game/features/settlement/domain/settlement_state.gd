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
var tarp := 0
var wellbeing := 75
var workday_hours := 8
var night_shifts_allowed := false
var road_walking_order_enabled := false
var low_wellbeing_days := 0
var tools := {"axe": false, "hand_saw": false, "shovel": false, "bucket": false, "hoe": false, "pickaxe": false}
var tool_uses := {}
var equipment: Dictionary = TENT_STARTING_EQUIPMENT.duplicate(true)
var trade_sales := 0
var buildings: Dictionary = {}
var brick_construction_unlocked := false
var warehouse_tarp_covered := false
var campfire_story_effect := "" # "optimistic" | "teaching" | "plan"
var campfire_story_target_role := ""
var campfire_story_target_day := -1
var unlocked_systems := {
	"official": false,
}
var unlocked_building_levels := {
	"tent": false,
	"cook_campfire": false,
	"campfire_lvl2": false,
	"campfire_lvl3": false,
	"gathering_place": false,
	"cook_campfire_lvl2": false,
	"cook_campfire_lvl3": false,
	"forager_tent": false,
	"materials_yard": false,
	"craft_tent": false,
	"dew_collector": false,
	"straw_tent": false,
	"tarp_tent": false,
	"straw_forager_tent": false,
	"tarp_forager_tent": false,
	"straw_materials_yard": false,
	"tarp_materials_yard": false,
	"straw_craft_tent": false,
	"tarp_craft_tent": false,
	"advanced_dew_collector": false,
	"straw_warehouse": false,
	"tarp_warehouse": false,
	"straw_trade_tent": false,
	"tarp_trade_tent": false,
	"toilet_tent": false,
	"tarp_toilet": false,
	"house": false,
	"house_lvl2": false,
	"house_lvl3": false,
	"dugout_kitchen": false,
	"clay_bakery": false,
	"canteen": false,
	"stone_tavern": false,
	"brick_restaurant": false,
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
	food = 0
	hides = 0
	goods = 0
	logs = 0
	wood = 0
	soil = 0
	clay = 0
	boards = 0
	stone = 0
	bricks = 0
	tarp = 1
	water = 8
	wellbeing = TENT_STARTING_WELLBEING
	workday_hours = 8
	night_shifts_allowed = false
	road_walking_order_enabled = false
	low_wellbeing_days = 0
	tools = {"axe": false, "hand_saw": false, "shovel": false, "bucket": false, "hoe": false, "pickaxe": false}
	tool_uses = {}
	equipment = TENT_STARTING_EQUIPMENT.duplicate(true)
	trade_sales = 0
	brick_construction_unlocked = false
	warehouse_tarp_covered = false
	campfire_story_effect = ""
	campfire_story_target_role = ""
	campfire_story_target_day = -1
	active_research_tech_id = ""
	active_research_worker_id = -1
	active_research_remaining_time = 0.0
	active_research_duration = 0.0
	storage_limits.clear()
	virtual_stock.clear()
	warehouse_ever_built = false
	debug_storage_capacity_bonus = 0
	virtual_stock["food"] = TENT_STARTING_FOOD
	if reset_progress:
		buildings.clear()
		for system_id in unlocked_systems.keys():
			unlocked_systems[system_id] = false
		for building_type in unlocked_building_levels.keys():
			unlocked_building_levels[building_type] = _tent_start_unlock_for(building_type)


func _tent_start_unlock_for(building_type: String) -> bool:
	if building_type in ["tent", "cook_campfire", "dew_collector"]:
		return true
	return false


func construction_gloves_available() -> bool:
	return int(equipment.get("construction_gloves", {}).get("sets", 0)) > 0


func wear_construction_gloves(amount: float) -> bool:
	var gloves: Dictionary = equipment.get("construction_gloves", {})
	if int(gloves.get("sets", 0)) <= 0:
		return false
	gloves["active_durability"] = float(gloves.get("active_durability", 100.0)) - amount
	while float(gloves["active_durability"]) <= 0.0 and int(gloves.get("sets", 0)) > 0:
		gloves["sets"] = int(gloves["sets"]) - 1
		gloves["active_durability"] = float(gloves["active_durability"]) + 100.0
	if int(gloves["sets"]) <= 0:
		gloves["active_durability"] = 0.0
	equipment["construction_gloves"] = gloves
	return int(gloves.get("sets", 0)) > 0


func add_construction_glove_set() -> void:
	var gloves: Dictionary = equipment.get("construction_gloves", {})
	gloves["sets"] = int(gloves.get("sets", 0)) + 1
	if float(gloves.get("active_durability", 0.0)) <= 0.0:
		gloves["active_durability"] = 100.0
	equipment["construction_gloves"] = gloves

## --- Weighted, reallocatable storage ------------------------------------------
## Every stored good takes up "space units". The warehouse holds a fixed number of
## units for the current era; the player splits that budget between resources in
## the warehouse menu. Heavy goods (logs, bricks) cost more than a unit each;
## water is light and packs several to a unit.
const STORED_RESOURCES := ["branches", "grass", "water", "food", "hides", "goods", "logs", "wood", "soil", "clay", "boards", "stone", "bricks", "tarp"]
const STORAGE_WEIGHTS := {
	"branches": 1.0, "grass": 1.0, "water": 0.5, "food": 1.0,
	"hides": 1.0, "goods": 1.0, "logs": 2.0, "wood": 2.0,
	"soil": 1.0, "clay": 1.0, "boards": 1.5, "stone": 2.0, "bricks": 2.0,
	"tarp": 1.0,
}
const ERA_STORAGE_PER_WAREHOUSE := {Era.TENT: 32, Era.EARTH: 48, Era.CLAY: 70, Era.WOOD: 100, Era.STONE: 120, Era.BRICK: 150}
const STORAGE_STEP := 4.0

var storage_limits: Dictionary = {} # resource -> allocated space units (float)
## Resources earned before the first warehouse is built live in an unlimited
## virtual stockpile. They migrate to real warehouses on first completion.
var virtual_stock: Dictionary = {}
## Becomes true the first time any warehouse is completed and never reverts.
var warehouse_ever_built: bool = false
## Debug grants are intended to unlock test scenarios, not to consume every
## physical warehouse slot. The bonus is active only while a warehouse exists.
var debug_storage_capacity_bonus := 0


func storage_weight(resource_type: String) -> float:
	return float(STORAGE_WEIGHTS.get(resource_type, 1.0))


func can_cover_warehouse_with_tarp() -> bool:
	return not warehouse_tarp_covered and tarp > 0


func cover_warehouse_with_tarp() -> bool:
	if not can_cover_warehouse_with_tarp():
		return false
	tarp -= 1
	warehouse_tarp_covered = true
	return true


func storage_capacity(warehouses: int) -> int:
	if warehouses <= 0:
		return 0
	var heap_count := int(buildings.get("warehouse", 0))
	var straw_count := int(buildings.get("straw_warehouse", 0))
	var tarp_count := int(buildings.get("tarp_warehouse", 0))
	var capacity := heap_count * 24 + straw_count * 48 + tarp_count * 72
	if capacity == 0 and warehouses > 0:
		capacity = warehouses * int(ERA_STORAGE_PER_WAREHOUSE.get(era, 24))
	return capacity + debug_storage_capacity_bonus


func storage_used_units() -> float:
	var total := 0.0
	for resource_type in STORED_RESOURCES:
		total += _warehouse_amount(resource_type) * storage_weight(resource_type)
	return total


func _storage_allocated_units() -> float:
	var total := 0.0
	for resource_type in STORED_RESOURCES:
		total += float(storage_limits.get(resource_type, 0.0))
	return total


func _storage_committed_units() -> float:
	var total := 0.0
	for resource_type in STORED_RESOURCES:
		var used := amount(resource_type) * storage_weight(resource_type)
		total += maxf(float(storage_limits.get(resource_type, 0.0)), used)
	return total


func storage_free_units(warehouses: int) -> float:
	return maxf(0.0, storage_capacity(warehouses) - _storage_committed_units())


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
	var current_limit := float(storage_limits.get(resource_type, 0.0))
	var used_units := amount(resource_type) * storage_weight(resource_type)
	var current_headroom := maxf(0.0, current_limit - used_units)
	var additional_committed_units := maxf(0.0, required_units - current_headroom)
	if additional_committed_units > storage_free_units(warehouses) + 0.001:
		return false
	storage_limits[resource_type] = maxf(current_limit, used_units + required_units)
	return storage_availability_for(resource_type, count, warehouses) == StorageAvailability.OK


func _warehouse_amount(resource_type: String) -> int:
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
		"tarp": return tarp
	return 0


func amount(resource_type: String) -> int:
	if resource_type == "money":
		return money
	if not warehouse_ever_built:
		return int(virtual_stock.get(resource_type, 0))
	return _warehouse_amount(resource_type)


func _add_to_warehouse(resource_type: String, value: int) -> void:
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
		"tarp": tarp += value


func add(resource_type: String, value: int) -> void:
	if resource_type == "money":
		money += value
		return
	if not warehouse_ever_built:
		virtual_stock[resource_type] = int(virtual_stock.get(resource_type, 0)) + value
	else:
		_add_to_warehouse(resource_type, value)


func total_stored_resources() -> int:
	var total := 0
	if not warehouse_ever_built:
		for value in virtual_stock.values():
			total += int(value)
	else:
		total = branches + grass + water + food + hides + goods + logs + wood + soil + clay + boards + stone + bricks + tarp
	return total


func uses_virtual_storage() -> bool:
	return not warehouse_ever_built


func migrate_virtual_to_warehouse(warehouses: int) -> Dictionary:
	warehouse_ever_built = true
	var overflow := {}
	var capacity_units := float(storage_capacity(warehouses))
	var used_units := 0.0
	for resource_type in STORED_RESOURCES:
		var virtual_count := int(virtual_stock.get(resource_type, 0))
		if virtual_count <= 0:
			continue
		var weight := storage_weight(resource_type)
		var remaining_room := maxf(0.0, capacity_units - used_units)
		var can_fit := int(floor((remaining_room + 0.001) / weight))
		var accepted := mini(virtual_count, maxi(0, can_fit))
		if accepted > 0:
			_add_to_warehouse(resource_type, accepted)
			used_units += accepted * weight
		var leftover := virtual_count - accepted
		if leftover > 0:
			overflow[resource_type] = leftover
	virtual_stock.clear()
	ensure_storage_defaults(warehouses)
	_clamp_storage_limits(warehouses)
	return overflow


func can_afford_building(building_type: String) -> bool:
	if not is_building_unlocked(building_type):
		return false
	if building_type == "campfire" and era == Era.TENT and not has_building("warehouse"):
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

func next_building_upgrade(building_type: String) -> String:
	return BuildingCatalog.next_upgrade_for(building_type)

func can_upgrade_building(building_type: String) -> bool:
	if not has_building(building_type):
		return false
	var target := next_building_upgrade(building_type)
	if target.is_empty() or not is_building_unlocked(target):
		return false
	if BuildingCatalog.era_for(target) > era:
		return false
	for resource_type in BuildingCatalog.cost_resources(target):
		if amount(resource_type) < BuildingCatalog.cost_for_resource(target, resource_type):
			return false
	return true

func pay_for_building_upgrade(building_type: String) -> String:
	if not can_upgrade_building(building_type):
		return ""
	var target := next_building_upgrade(building_type)
	for resource_type in BuildingCatalog.cost_resources(target):
		add(resource_type, -BuildingCatalog.cost_for_resource(target, resource_type))
	buildings[building_type] = maxi(0, int(buildings.get(building_type, 0)) - 1)
	buildings[target] = int(buildings.get(target, 0)) + 1
	return target


func has_building(building_type: String) -> bool:
	return int(buildings.get(building_type, 0)) > 0


func is_building_unlocked(building_type: String) -> bool:
	if building_type == "warehouse":
		return true
	if building_type == "campfire":
		# The landmark must be visible in the initial build menu. Placement still
		# requires the first warehouse so the bootstrap order remains explicit.
		return true
	if unlocked_building_levels.has(building_type):
		return bool(unlocked_building_levels.get(building_type, false))
	return era > Era.TENT


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
			return era == Era.TENT and _has_tools(["axe", "hand_saw", "shovel", "bucket"]) and is_research_completed("earth_buildings") and has_building("tarp_trade_tent")
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
	if is_research_completed(research_id):
		return false
	var target_building := str(tech.get("target_building", ""))
	if not target_building.is_empty() and era < BuildingCatalog.era_for(target_building):
		return false
	for prerequisite in tech.get("prerequisites", []):
		if BuildingCatalog.RESEARCH_TECHS.has(prerequisite):
			if not is_research_completed(str(prerequisite)):
				return false
		elif not has_building(str(prerequisite)):
			return false
	if era == Era.TENT and not target_building.is_empty():
		var target: String = target_building
		# The central campfire is itself the gate which unlocks each technology
		# tier, so it must not require the level it is trying to unlock.
		if target == "campfire_lvl3" and not has_building("campfire_lvl2"):
			return false
		if target != "campfire_lvl2" and target != "campfire_lvl3" and target.ends_with("_lvl2") and not has_building("campfire_lvl2") and not has_building("campfire_lvl3"):
			return false
		if target != "campfire_lvl3" and target.ends_with("_lvl3") and not has_building("campfire_lvl3"):
			return false
	return can_afford_research(research_id)


func is_research_completed(research_id: String) -> bool:
	if not BuildingCatalog.RESEARCH_TECHS.has(research_id):
		return false
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[research_id]
	var target_system := str(tech.get("target_system", ""))
	if not target_system.is_empty():
		return bool(unlocked_systems.get(target_system, false))
	var target_buildings: Array = tech.get("target_buildings", [])
	if not target_buildings.is_empty():
		for building_type in target_buildings:
			if not bool(unlocked_building_levels.get(building_type, false)):
				return false
		return true
	var target_building := str(tech.get("target_building", ""))
	return not target_building.is_empty() and bool(unlocked_building_levels.get(target_building, false))


func complete_research(research_id: String) -> String:
	if not BuildingCatalog.RESEARCH_TECHS.has(research_id):
		return ""
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[research_id]
	var target_system := str(tech.get("target_system", ""))
	if not target_system.is_empty():
		unlocked_systems[target_system] = true
		return target_system
	var target_buildings: Array = tech.get("target_buildings", [])
	if not target_buildings.is_empty():
		for building_type in target_buildings:
			unlocked_building_levels[building_type] = true
		return str(target_buildings[0])
	var target_building := str(tech.get("target_building", ""))
	if not target_building.is_empty():
		unlocked_building_levels[target_building] = true
	return target_building


func pay_for_research(research_id: String) -> bool:
	if not can_afford_research(research_id): return false
	for resource_type in BuildingCatalog.research_resources(research_id): add(resource_type, -BuildingCatalog.research_cost(research_id, resource_type))
	return true
