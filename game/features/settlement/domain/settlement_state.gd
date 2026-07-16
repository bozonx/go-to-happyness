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
var night_work_order_day := -1
var road_walking_order_enabled := false
var balanced_warehouse_mode := false
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
	night_work_order_day = -1
	road_walking_order_enabled = false
	balanced_warehouse_mode = false
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
	backpack.clear()
	warehouses.clear()
	warehouse_types.clear()
	warehouse_ever_built = false
	construction_reservations.clear()
	backpack["food"] = TENT_STARTING_FOOD
	backpack["water"] = TENT_STARTING_WATER
	backpack["tarp"] = 1
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

## Resources available in each era. Each era cumulatively adds new resources.
const ERA_RESOURCES := {
	Era.TENT: ["branches", "grass", "water", "food", "hides", "goods", "tarp"],
	Era.EARTH: ["branches", "grass", "water", "food", "hides", "goods", "tarp", "soil", "wood"],
	Era.CLAY: ["branches", "grass", "water", "food", "hides", "goods", "tarp", "soil", "wood", "clay"],
	Era.WOOD: ["branches", "grass", "water", "food", "hides", "goods", "tarp", "soil", "wood", "clay", "logs", "boards"],
	Era.STONE: ["branches", "grass", "water", "food", "hides", "goods", "tarp", "soil", "wood", "clay", "logs", "boards", "stone"],
	Era.BRICK: ["branches", "grass", "water", "food", "hides", "goods", "tarp", "soil", "wood", "clay", "logs", "boards", "stone", "bricks"],
}

static func resources_for_era(p_era: Era) -> Array[String]:
	var list: Array[String] = []
	for key in ERA_RESOURCES.get(p_era, []):
		list.append(str(key))
	return list

func era_resources() -> Array[String]:
	return resources_for_era(era)

## Physical resources before the first warehouse live in the starter backpack.
## The backpack is a special non-replenishable ground pile shown separately in HUD.
var backpack: Dictionary = {}
## Backward-compatible alias used by tests and UI during the refactor.
var virtual_stock: Dictionary:
	get: return backpack
## Becomes true the first time any warehouse is completed and never reverts.
var warehouse_ever_built: bool = false

## Resources committed to active construction sites. Maps a stable site id to
## a Dictionary of resource_type -> reserved amount. These resources are still on
## a warehouse/backpack, but they cannot be spent elsewhere until delivered or
## the site is cancelled.
var construction_reservations: Dictionary = {}


func storage_weight(resource_type: String) -> float:
	return float(STORAGE_WEIGHTS.get(resource_type, 1.0))


func _construction_reserved_total(resource_type: String) -> int:
	var total := 0
	for site_id in construction_reservations:
		var site_reservations: Dictionary = construction_reservations[site_id]
		total += int(site_reservations.get(resource_type, 0))
	return total


## Amount of a resource that is not already committed to a construction site.
## Other spending (research, upgrades, trade, another building) must use this value.
func available_amount(resource_type: String) -> int:
	return maxi(0, amount(resource_type) - _construction_reserved_total(resource_type))


## Reserves up to `amount` units of `resource_type` for the given construction site.
## Returns how many units were actually reserved.
func reserve_for_construction(site_id: int, resource_type: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var reserve := mini(amount, available_amount(resource_type))
	if reserve <= 0:
		return 0
	var site: Dictionary = construction_reservations.get(site_id, {})
	site[resource_type] = int(site.get(resource_type, 0)) + reserve
	construction_reservations[site_id] = site
	return reserve


## Releases a previously reserved amount for a construction site.
func release_for_construction(site_id: int, resource_type: String, amount: int) -> void:
	var site: Dictionary = construction_reservations.get(site_id, {})
	var current := int(site.get(resource_type, 0))
	var release := mini(amount, current)
	if release <= 0:
		return
	current -= release
	if current <= 0:
		site.erase(resource_type)
	else:
		site[resource_type] = current
	if site.is_empty():
		construction_reservations.erase(site_id)
	else:
		construction_reservations[site_id] = site


## Releases all reservations belonging to a single construction site.
func release_site_construction_reservations(site_id: int) -> void:
	construction_reservations.erase(site_id)


## Returns how many units of a resource are reserved for a specific construction site.
func construction_reserved_for_site(site_id: int, resource_type: String) -> int:
	var site: Dictionary = construction_reservations.get(site_id, {})
	return int(site.get(resource_type, 0))


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
	var warehouse := WarehouseState.new(capacity)
	_ensure_warehouse_accepts_era_resources(warehouse)
	warehouses.append(warehouse)
	warehouse_types.append(building_type)


func _ensure_warehouse_accepts_era_resources(warehouse: WarehouseState) -> void:
	for resource_type in era_resources():
		warehouse.set_accepted(resource_type, true)


func storage_capacity(_warehouses: int) -> int:
	var total := 0
	for warehouse in warehouses:
		total += warehouse.capacity
	return total


func storage_used_units() -> float:
	var total := 0.0
	for warehouse in warehouses:
		total += warehouse.used_units(STORAGE_WEIGHTS)
	return total


func storage_committed_units() -> float:
	var total := 0.0
	for warehouse in warehouses:
		total += warehouse.committed_units(STORAGE_WEIGHTS)
	return total


func storage_free_units(_warehouses: int) -> float:
	return maxf(0.0, float(storage_capacity(warehouses.size())) - storage_committed_units())


func warehouse_accepts(index: int, resource_type: String) -> bool:
	if index < 0 or index >= warehouses.size():
		return false
	return warehouses[index].accepts(resource_type)


func set_warehouse_accepted(index: int, resource_type: String, accepted: bool) -> void:
	if index < 0 or index >= warehouses.size():
		return
	warehouses[index].set_accepted(resource_type, accepted)


## Moves up to `count` units of the resource out of the given warehouse.
## Returns how many units were actually removed.
func dump_warehouse_resource(index: int, resource_type: String, count: int) -> int:
	if index < 0 or index >= warehouses.size():
		return 0
	return warehouses[index].dump_resource(resource_type, count)


func storage_room_for(resource_type: String) -> int:
	if not STORED_RESOURCES.has(resource_type):
		return 1 << 30
	var total := 0
	for warehouse in warehouses:
		total += warehouse.room_for(resource_type, STORAGE_WEIGHTS)
	return total


func storage_can_accept(resource_type: String, count: int) -> bool:
	return storage_room_for(resource_type) >= count


## Pick the best warehouse that can hold `count` units of the resource.
## In balanced mode the warehouse with the lowest fill percentage for this
## resource is chosen; otherwise the nearest eligible warehouse wins.
func find_warehouse_index(from_position: Vector3, resource_type: String, count: int, positions: Array[Vector3]) -> int:
	if warehouses.is_empty() or positions.is_empty() or count <= 0:
		return -1
	var candidates: Array[int] = []
	for i in range(warehouses.size()):
		if i >= positions.size():
			continue
		if warehouses[i].room_for(resource_type, STORAGE_WEIGHTS) < count:
			continue
		candidates.append(i)
	if candidates.is_empty():
		return -1
	if balanced_warehouse_mode:
		var best_index := candidates[0]
		var best_ratio := INF
		for i in candidates:
			var capacity := maxi(1, warehouses[i].capacity)
			var ratio := float(warehouses[i].amount(resource_type)) / float(capacity)
			if ratio < best_ratio:
				best_ratio = ratio
				best_index = i
		return best_index
	var best_index := -1
	var best_distance := INF
	for i in candidates:
		var distance := from_position.distance_squared_to(positions[i])
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index


func reserve_warehouse_room(index: int, resource_type: String, count: int) -> bool:
	if index < 0 or index >= warehouses.size():
		return false
	return warehouses[index].reserve(resource_type, count, STORAGE_WEIGHTS)


func release_warehouse_reservation(index: int, resource_type: String, count: int) -> void:
	if index < 0 or index >= warehouses.size():
		return
	warehouses[index].release(resource_type, count)


func warehouse_room_for(index: int, resource_type: String) -> int:
	if index < 0 or index >= warehouses.size():
		return 0
	return warehouses[index].room_for(resource_type, STORAGE_WEIGHTS)


func storage_availability_for(resource_type: String, count: int, warehouses: int) -> StorageAvailability:
	if count <= 0:
		return StorageAvailability.OK
	if not STORED_RESOURCES.has(resource_type):
		return StorageAvailability.UNKNOWN_RESOURCE
	if warehouses <= 0:
		return StorageAvailability.NO_WAREHOUSE
	return StorageAvailability.OK if storage_room_for(resource_type) >= count else StorageAvailability.NO_ROOM

func can_make_room_for(resource_type: String, count: int, _warehouses: int) -> bool:
	return storage_room_for(resource_type) >= count


func reserve_storage_room_for(resource_type: String, count: int, warehouses: int) -> bool:
	if count <= 0 or not STORED_RESOURCES.has(resource_type):
		return count <= 0
	if warehouses <= 0:
		return false
	for i in range(min(warehouses, self.warehouses.size())):
		if reserve_warehouse_room(i, resource_type, count):
			return true
	return false


func _set_resource_aggregate(resource_type: String, value: int) -> void:
	if resource_type == "money":
		return
	if not warehouse_ever_built:
		backpack[resource_type] = value
		return
	for i in range(warehouses.size()):
		warehouses[i].set_amount(resource_type, value if i == 0 else 0)


func amount(resource_type: String) -> int:
	if resource_type == "money":
		return money
	if not warehouse_ever_built:
		return int(backpack.get(resource_type, 0))
	var total := 0
	for warehouse in warehouses:
		total += warehouse.amount(resource_type)
	return total


func backpack_amount(resource_type: String) -> int:
	if resource_type == "money":
		return 0
	return int(backpack.get(resource_type, 0))


func warehouse_amount(resource_type: String, index: int) -> int:
	if index < 0 or index >= warehouses.size():
		return 0
	return warehouses[index].amount(resource_type)


## Add resources to a specific warehouse by index. Returns how many could not fit.
## Callers typically reserve the room first; this helper releases a matching
## reservation so the cargo actually fits.
func add_to_warehouse(resource_type: String, value: int, index: int) -> int:
	if resource_type == "money" or not warehouse_ever_built:
		return value
	if index < 0 or index >= warehouses.size():
		return value
	if value > 0:
		warehouses[index].release(resource_type, value)
	return warehouses[index].add(resource_type, value, STORAGE_WEIGHTS)


## Default delivery behaviour: fill warehouses sequentially and remove from them
## sequentially. Keeps the first warehouses stocked until they are full, then spills
## into the next ones. Excess is silently discarded to preserve the no-overflow
## invariant; callers that need overflow handling should use add_to_warehouse.
func add(resource_type: String, value: int) -> void:
	if resource_type == "money":
		money += value
		return
	if not warehouse_ever_built:
		backpack[resource_type] = int(backpack.get(resource_type, 0)) + value
		return
	if warehouses.is_empty():
		# Resources received while no physical warehouse exists fall back to the backpack
		# rather than being silently lost; this matches demolition edge cases.
		backpack[resource_type] = maxi(0, int(backpack.get(resource_type, 0)) + value)
		return
	if value >= 0:
		_distribute_add(resource_type, value)
	else:
		_distribute_remove(resource_type, -value)


## Used for debug/cheat grants: pull every warehouse toward the average amount of
## the given resource. Never overfills a warehouse; excess is returned as overflow.
func add_cheat(resource_type: String, value: int) -> int:
	if value <= 0:
		add(resource_type, value)
		return 0
	if resource_type == "money":
		money += value
		return 0
	if not warehouse_ever_built or warehouses.is_empty():
		return value
	# Cheat resources are only bounded by the physical warehouse capacity and accept filters.
	var total_room := 0
	for warehouse in warehouses:
		total_room += warehouse.room_for(resource_type, STORAGE_WEIGHTS)
	var to_add := mini(value, total_room)
	if to_add <= 0:
		return value
	var remaining := to_add
	while remaining > 0:
		var target := _find_least_stocked_warehouse(resource_type)
		if target < 0:
			break
		var accepted := warehouses[target].add(resource_type, remaining, STORAGE_WEIGHTS)
		var added := remaining - accepted
		remaining = accepted
		if added == 0:
			break
	return value - to_add + remaining


func _distribute_add(resource_type: String, value: int) -> void:
	var remaining := value
	for warehouse in warehouses:
		remaining = warehouse.add(resource_type, remaining, STORAGE_WEIGHTS)
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
	var best := -1
	var best_amount := INF
	for i in range(warehouses.size()):
		if not warehouses[i].accepts(resource_type):
			continue
		var count := warehouses[i].amount(resource_type)
		if count < best_amount:
			best_amount = count
			best = i
	return best


## Fills the least-stocked warehouse up to `percent` of its capacity.
## Only warehouses below the threshold are considered; repeated calls move to
## the next least-stocked qualifying warehouse. Resources are added evenly,
## prioritising types that are currently low in the chosen warehouse.
## Returns a dictionary with `filled` (bool) and `overflow` (resource -> leftover).
func fill_least_warehouse_cheat(percent: float) -> Dictionary:
	var result := {"filled": false, "overflow": {}}
	if not warehouse_ever_built or warehouses.is_empty():
		return result
	var threshold := clampf(percent / 100.0, 0.0, 1.0)
	var era_res := era_resources()
	var candidates: Array[int] = []
	for i in range(warehouses.size()):
		var warehouse := warehouses[i]
		var used := warehouse.used_units(STORAGE_WEIGHTS)
		if used >= float(warehouse.capacity) * threshold:
			continue
		var accepts_any := false
		for resource_type in era_res:
			if warehouse.accepts(resource_type):
				accepts_any = true
				break
		if not accepts_any:
			continue
		candidates.append(i)
	if candidates.is_empty():
		return result
	candidates.sort_custom(func(a: int, b: int) -> bool:
		return warehouses[a].used_units(STORAGE_WEIGHTS) < warehouses[b].used_units(STORAGE_WEIGHTS)
	)
	var target_index := candidates[0]
	var target := warehouses[target_index]
	result["target_index"] = target_index
	var accepted_era_res: Array[String] = []
	for resource_type in era_res:
		if target.accepts(resource_type):
			accepted_era_res.append(resource_type)
	if accepted_era_res.is_empty():
		return result
	var fill_target := float(target.capacity) * threshold
	var free_units := maxf(0.0, fill_target - target.used_units(STORAGE_WEIGHTS))
	if free_units <= 0.0:
		return result
	var share := free_units / float(accepted_era_res.size())
	for resource_type in accepted_era_res:
		var weight := storage_weight(resource_type)
		if weight <= 0.0:
			continue
		var current_units := float(target.amount(resource_type)) * weight
		var needed_units := maxf(0.0, share - current_units)
		var grant_count := int(floor(needed_units / weight))
		if grant_count <= 0:
			continue
		var leftover := target.add(resource_type, grant_count, STORAGE_WEIGHTS)
		if leftover > 0:
			result.overflow[resource_type] = leftover
		result.filled = true
	return result


func _find_least_used_warehouse() -> int:
	var best := 0
	var best_used := warehouses[0].used_units(STORAGE_WEIGHTS)
	for i in range(1, warehouses.size()):
		var used := warehouses[i].used_units(STORAGE_WEIGHTS)
		if used < best_used:
			best_used = used
			best = i
	return best


func total_stored_resources() -> int:
	var total := 0
	if not warehouse_ever_built:
		for value in backpack.values():
			total += int(value)
	else:
		for warehouse in warehouses:
			for resource_type in STORED_RESOURCES:
				total += warehouse.amount(resource_type)
	return total


func uses_virtual_storage() -> bool:
	return not warehouse_ever_built


func migrate_backpack_to_warehouse() -> Dictionary:
	warehouse_ever_built = true
	var overflow := {}
	if warehouses.is_empty():
		overflow = backpack.duplicate()
	else:
		for resource_type in STORED_RESOURCES:
			var backpack_count := int(backpack.get(resource_type, 0))
			var remaining := backpack_count
			for warehouse in warehouses:
				remaining = warehouse.add(resource_type, remaining, STORAGE_WEIGHTS)
				if remaining <= 0:
					break
			if remaining > 0:
				overflow[resource_type] = remaining
	backpack.clear()
	return overflow


## Backward-compatible alias kept during the refactor.
func migrate_virtual_to_warehouse(_warehouses: int) -> Dictionary:
	return migrate_backpack_to_warehouse()


func can_afford_building(building_type: String) -> bool:
	if not is_building_unlocked(building_type):
		return false
	for resource_type in BuildingCatalog.cost_resources(building_type):
		if available_amount(resource_type) < BuildingCatalog.cost_for_resource(building_type, resource_type):
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
		if available_amount(resource_type) < BuildingCatalog.cost_for_resource(target, resource_type):
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
	if quantity <= 0 or available_amount(resource_type) < quantity:
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
			return era == Era.EARTH and has_building("earth_assembly") and has_building("smithy") and has_building("earth_market") and housing_slots >= population and available_amount("clay") >= 5 and money >= 5 and trade_sales >= 3 and _has_tools(["hoe"]) and has_building("toilet_earth_lvl3")
		Era.WOOD:
			return era == Era.CLAY and has_building("clay_lodge") and has_building("clay_market") and available_amount("water") >= population and available_amount("logs") >= 10 and money >= 10 and has_building("toilet_clay_lvl3")
		Era.STONE:
			return era == Era.WOOD and has_building("wood_town_hall") and has_building("wood_market") and money >= 15 and _has_tools(["pickaxe"]) and has_building("house_lvl3") and has_building("toilet_wood_lvl3")
		Era.BRICK:
			return era == Era.STONE and has_building("stone_prefecture") and has_building("stone_market") and has_building("masonry_workshop") and available_amount("stone") >= 20 and money >= 20 and has_building("toilet_stone_lvl3")
	return false


func advance_era(next_era: Era, population: int, housing_slots: int) -> bool:
	if not can_advance_to(next_era, population, housing_slots):
		return false
	era = next_era
	_refresh_warehouse_accepted_resources()
	return true


func _refresh_warehouse_accepted_resources() -> void:
	for warehouse in warehouses:
		_ensure_warehouse_accepts_era_resources(warehouse)


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
		if available_amount(resource_type) < BuildingCatalog.research_cost(research_id, resource_type): return false
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
