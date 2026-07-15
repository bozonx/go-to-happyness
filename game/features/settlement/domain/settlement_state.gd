class_name SettlementState
extends RefCounted

## Persistent, scene-free settlement economy. All progression gates live here so
## UI and simulation code cannot accidentally create a second rule set.

enum Era { TENT, EARTH, CLAY, WOOD, STONE, BRICK }
enum StorageAvailability { OK, UNKNOWN_RESOURCE, NO_WAREHOUSE, NO_ROOM }

const TENT_STARTING_MONEY := 500
const TENT_STARTING_FOOD := 16
const TENT_STARTING_WATER := 8
const TENT_STARTING_POPULATION := 4
const TENT_STARTING_WELLBEING := 75
const TENT_STARTING_EQUIPMENT := {
	"flint_steel": {"owned": true},
	"construction_gloves": {"sets": 1, "active_durability": 100.0},
}

var era := Era.TENT
var money := 20

## Per-warehouse inventories. Each WarehouseState holds the contents of one
## physical warehouse; the scalar resource properties below aggregate across
## all of them. The virtual stock is used only before the first warehouse.
var warehouses: Array[WarehouseState] = []
var warehouse_types: Array[String] = []

var branches: int:
	get: return amount("branches")
	set(value): _set_resource_aggregate("branches", value)
var grass: int:
	get: return amount("grass")
	set(value): _set_resource_aggregate("grass", value)
var water: int:
	get: return amount("water")
	set(value): _set_resource_aggregate("water", value)
var food: int:
	get: return amount("food")
	set(value): _set_resource_aggregate("food", value)
var hides: int:
	get: return amount("hides")
	set(value): _set_resource_aggregate("hides", value)
var goods: int:
	get: return amount("goods")
	set(value): _set_resource_aggregate("goods", value)
var logs: int:
	get: return amount("logs")
	set(value): _set_resource_aggregate("logs", value)
var wood: int:
	get: return amount("wood")
	set(value): _set_resource_aggregate("wood", value)
var soil: int:
	get: return amount("soil")
	set(value): _set_resource_aggregate("soil", value)
var clay: int:
	get: return amount("clay")
	set(value): _set_resource_aggregate("clay", value)
var boards: int:
	get: return amount("boards")
	set(value): _set_resource_aggregate("boards", value)
var stone: int:
	get: return amount("stone")
	set(value): _set_resource_aggregate("stone", value)
var bricks: int:
	get: return amount("bricks")
	set(value): _set_resource_aggregate("bricks", value)
var tarp: int:
	get: return amount("tarp")
	set(value): _set_resource_aggregate("tarp", value)

var wellbeing := 75
var workday_hours := 8
var night_shifts_allowed := false
var road_walking_order_enabled := false
var cheer_up_used_today := false
var low_wellbeing_days := 0
var tools := {"axe": false, "hand_saw": false, "shovel": false, "bucket": false, "hoe": false, "pickaxe": false}
var tool_uses := {}
var equipment: Dictionary = TENT_STARTING_EQUIPMENT.duplicate(true)
var trade_sales := 0
var buildings: Dictionary = {}
var warehouse_tarp_covered := false
var campfire_story_effect := "" # "optimistic" | "teaching" | "plan"
var campfire_story_target_role := ""
var campfire_story_target_day := -1
var unlocked_systems := {
	"official": false,
	"outside_work_bonus": false,
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
	wellbeing = TENT_STARTING_WELLBEING
	workday_hours = 8
	night_shifts_allowed = false
	road_walking_order_enabled = false
	cheer_up_used_today = false
	low_wellbeing_days = 0
	tools = {"axe": false, "hand_saw": false, "shovel": false, "bucket": false, "hoe": false, "pickaxe": false}
	tool_uses = {}
	equipment = TENT_STARTING_EQUIPMENT.duplicate(true)
	trade_sales = 0
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
	warehouses.clear()
	warehouse_types.clear()
	warehouse_ever_built = false
	debug_storage_capacity_bonus = 0
	virtual_stock["food"] = TENT_STARTING_FOOD
	virtual_stock["water"] = TENT_STARTING_WATER
	virtual_stock["tarp"] = 1
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


func add_warehouse(building_type: String) -> void:
	var capacity := WarehouseState.capacity_for_building_type(building_type, era)
	warehouses.append(WarehouseState.new(capacity))
	warehouse_types.append(building_type)
	if storage_limits.is_empty():
		ensure_storage_defaults(warehouses.size())


func storage_capacity(_warehouses: int) -> int:
	var total := debug_storage_capacity_bonus
	for warehouse in warehouses:
		total += warehouse.capacity
	return total


func storage_used_units() -> float:
	var total := 0.0
	for warehouse in warehouses:
		total += warehouse.used_units(STORAGE_WEIGHTS)
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


func _set_resource_aggregate(resource_type: String, value: int) -> void:
	if resource_type == "money":
		return
	if not warehouse_ever_built:
		virtual_stock[resource_type] = value
		return
	for i in range(warehouses.size()):
		warehouses[i].set_amount(resource_type, value if i == 0 else 0)


func amount(resource_type: String) -> int:
	if resource_type == "money":
		return money
	if not warehouse_ever_built:
		return int(virtual_stock.get(resource_type, 0))
	var total := 0
	for warehouse in warehouses:
		total += warehouse.amount(resource_type)
	return total


## Add resources to a specific warehouse by index. Returns how many could not fit.
func add_to_warehouse(resource_type: String, value: int, index: int) -> int:
	if resource_type == "money" or not warehouse_ever_built:
		return value
	if index < 0 or index >= warehouses.size():
		return value
	var weight := storage_weight(resource_type)
	return warehouses[index].add(resource_type, value, weight)


## Default delivery behaviour: fill warehouses sequentially and remove from them
## sequentially. Keeps the first warehouses stocked until they are full, then spills
## into the next ones, matching the "new warehouse is empty and can be filled"
## expectation.
func add(resource_type: String, value: int) -> void:
	if resource_type == "money":
		money += value
		return
	if not warehouse_ever_built:
		virtual_stock[resource_type] = int(virtual_stock.get(resource_type, 0)) + value
		return
	if value >= 0:
		_distribute_add(resource_type, value)
	else:
		_distribute_remove(resource_type, -value)


## Used for debug/cheat grants: pull every warehouse toward the average amount of
## the given resource. Falls back to overfilling the least-stocked warehouse if the
## total physical capacity is exceeded.
func add_cheat(resource_type: String, value: int) -> void:
	if value <= 0:
		add(resource_type, value)
		return
	if not warehouse_ever_built:
		virtual_stock[resource_type] = int(virtual_stock.get(resource_type, 0)) + value
		return
	var weight := storage_weight(resource_type)
	var remaining := value
	while remaining > 0:
		var target := _find_least_stocked_warehouse(resource_type)
		var before := warehouses[target].amount(resource_type)
		var accepted := warehouses[target].add(resource_type, remaining, weight)
		var added := remaining - accepted
		if added == 0:
			warehouses[target].resources[resource_type] = before + remaining
			remaining = 0
		else:
			remaining = accepted


func _distribute_add(resource_type: String, value: int) -> void:
	var weight := storage_weight(resource_type)
	var remaining := value
	for warehouse in warehouses:
		remaining = warehouse.add(resource_type, remaining, weight)
		if remaining <= 0:
			break


func _distribute_remove(resource_type: String, value: int) -> void:
	var remaining := value
	for warehouse in warehouses:
		var current := warehouse.amount(resource_type)
		var removed := mini(remaining, current)
		warehouse.set_amount(resource_type, current - removed)
		remaining -= removed
		if remaining <= 0:
			break


func _find_least_stocked_warehouse(resource_type: String) -> int:
	var best := 0
	var best_amount := warehouses[0].amount(resource_type)
	for i in range(1, warehouses.size()):
		var count := warehouses[i].amount(resource_type)
		if count < best_amount:
			best_amount = count
			best = i
	return best


func total_stored_resources() -> int:
	var total := 0
	if not warehouse_ever_built:
		for value in virtual_stock.values():
			total += int(value)
	else:
		for warehouse in warehouses:
			for resource_type in STORED_RESOURCES:
				total += warehouse.amount(resource_type)
	return total


func uses_virtual_storage() -> bool:
	return not warehouse_ever_built


func migrate_virtual_to_warehouse(_warehouses: int) -> Dictionary:
	warehouse_ever_built = true
	var overflow := {}
	if warehouses.is_empty():
		overflow = virtual_stock.duplicate()
	else:
		var first := warehouses[0]
		for resource_type in STORED_RESOURCES:
			var virtual_count := int(virtual_stock.get(resource_type, 0))
			if virtual_count > 0:
				first.resources[resource_type] = first.amount(resource_type) + virtual_count
	virtual_stock.clear()
	ensure_storage_defaults(warehouses.size())
	_clamp_storage_limits(warehouses.size())
	return overflow


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
	if building_type in ["warehouse", "straw_warehouse", "tarp_warehouse"]:
		add_warehouse(building_type)
		warehouse_ever_built = true
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

func pay_for_building_upgrade(building_type: String, warehouse_index := -1) -> String:
	if not can_upgrade_building(building_type):
		return ""
	var target := next_building_upgrade(building_type)
	for resource_type in BuildingCatalog.cost_resources(target):
		add(resource_type, -BuildingCatalog.cost_for_resource(target, resource_type))
	buildings[building_type] = maxi(0, int(buildings.get(building_type, 0)) - 1)
	buildings[target] = int(buildings.get(target, 0)) + 1
	if building_type in ["warehouse", "straw_warehouse", "tarp_warehouse"] and target in ["warehouse", "straw_warehouse", "tarp_warehouse"]:
		var index := warehouse_index
		if index < 0 or index >= warehouse_types.size():
			for i in range(warehouse_types.size()):
				if warehouse_types[i] == building_type:
					index = i
					break
		if index >= 0 and index < warehouse_types.size():
			warehouse_types[index] = target
			warehouses[index].capacity = WarehouseState.capacity_for_building_type(target, era)
	return target


func has_building(building_type: String) -> bool:
	return int(buildings.get(building_type, 0)) > 0


func is_building_unlocked(building_type: String) -> bool:
	if building_type == "warehouse":
		return true
	if building_type == "campfire":
		# The landmark must be visible and placeable from the start of the tent era.
		return true
	if unlocked_building_levels.has(building_type):
		return bool(unlocked_building_levels.get(building_type, false))
	return era >= BuildingCatalog.era_for(building_type)


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
			return era == Era.TENT and _has_tools(["axe", "hand_saw", "shovel", "bucket"]) and is_research_completed("earth_buildings")
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
	return true


func apply_cheer_up() -> bool:
	if cheer_up_used_today:
		return false
	wellbeing = mini(100, wellbeing + 5)
	cheer_up_used_today = true
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


func outside_work_reward_multiplier() -> int:
	return 2 if is_research_completed("outside_work_earnings") else 1


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
