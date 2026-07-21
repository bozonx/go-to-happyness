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

var era_progress := EraProgress.new()
var unlock_state := UnlockState.new()

var era: Era:
	get: return era_progress.era as Era
	set(value): era_progress.era = value
var money := 20

var storage := StorageState.new()

## Per-warehouse inventories. Each WarehouseState holds the contents of one
## physical warehouse; the scalar resource properties below aggregate across
## all of them. The virtual stock is used only before the first warehouse.
var warehouses: Array[WarehouseState]:
	get: return storage.warehouses
	set(value): storage.warehouses = value
var warehouse_types: Array[String]:
	get: return storage.warehouse_types
	set(value): storage.warehouse_types = value

var branches: int:
	get: return amount("branches")
	set(value): storage._set_resource_aggregate("branches", value)
var grass: int:
	get: return amount("grass")
	set(value): storage._set_resource_aggregate("grass", value)
var water: int:
	get: return amount("water")
	set(value): storage._set_resource_aggregate("water", value)
var food: int:
	get: return amount("food")
	set(value): storage._set_resource_aggregate("food", value)
var hides: int:
	get: return amount("hides")
	set(value): storage._set_resource_aggregate("hides", value)
var goods: int:
	get: return amount("goods")
	set(value): storage._set_resource_aggregate("goods", value)
var logs: int:
	get: return amount("logs")
	set(value): storage._set_resource_aggregate("logs", value)
var wood: int:
	get: return amount("wood")
	set(value): storage._set_resource_aggregate("wood", value)
var soil: int:
	get: return amount("soil")
	set(value): storage._set_resource_aggregate("soil", value)
var clay: int:
	get: return amount("clay")
	set(value): storage._set_resource_aggregate("clay", value)
var boards: int:
	get: return amount("boards")
	set(value): storage._set_resource_aggregate("boards", value)
var stone: int:
	get: return amount("stone")
	set(value): storage._set_resource_aggregate("stone", value)
var bricks: int:
	get: return amount("bricks")
	set(value): storage._set_resource_aggregate("bricks", value)
var tarp: int:
	get: return amount("tarp")
	set(value): storage._set_resource_aggregate("tarp", value)

var work_policy := WorkPolicy.new()
var equipment_state := EquipmentState.new()

var wellbeing := 75
var workday_hours: int:
	get: return work_policy.workday_hours
	set(value): work_policy.workday_hours = value
## Chosen during a shift and applied when the next workday opens.
var pending_workday_hours: int:
	get: return work_policy.pending_workday_hours
	set(value): work_policy.pending_workday_hours = value
var night_work_order_day: int:
	get: return work_policy.night_work_order_day
	set(value): work_policy.night_work_order_day = value
var double_time_order_day: int:
	get: return work_policy.double_time_order_day
	set(value): work_policy.double_time_order_day = value
var road_walking_order_enabled: bool:
	get: return work_policy.road_walking_order_enabled
	set(value): work_policy.road_walking_order_enabled = value
var cheer_up_used_today: bool:
	get: return work_policy.cheer_up_used_today
	set(value): work_policy.cheer_up_used_today = value
var tools: Dictionary:
	get: return equipment_state.tools
var tool_uses: Dictionary:
	get: return equipment_state.tool_uses
var equipment: Dictionary:
	get: return equipment_state.equipment
	set(value): equipment_state.equipment = value
var trade_sales := 0
var balanced_warehouse_mode: bool:
	get: return storage.balanced_warehouse_mode
	set(value): storage.balanced_warehouse_mode = value
var buildings: Dictionary = {}
var warehouse_tarp_covered: bool:
	get: return storage.warehouse_tarp_covered
	set(value): storage.warehouse_tarp_covered = value
var campfire_story_effect := "" # "optimistic" | "teaching" | "plan"
var campfire_story_target_role := ""
var campfire_story_target_day := -1
var unlocked_systems: Dictionary:
	get: return unlock_state.unlocked_systems
var unlocked_building_levels: Dictionary:
	get: return unlock_state.unlocked_building_levels
var research := ResearchProgress.new()
var active_research_tech_id: String:
	get: return research.tech_id
	set(value): research.tech_id = value
var active_research_worker_id: int:
	get: return research.worker_id
	set(value): research.worker_id = value
var active_research_remaining_time: float:
	get: return research.remaining_time
	set(value): research.remaining_time = value
var active_research_duration: float:
	get: return research.duration
	set(value): research.duration = value


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
	work_policy.reset()
	equipment_state.reset()
	trade_sales = 0
	warehouse_tarp_covered = false
	campfire_story_effect = ""
	campfire_story_target_role = ""
	campfire_story_target_day = -1
	research.clear()
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
		unlock_state.reset()


func construction_gloves_available() -> bool:
	return equipment_state.construction_gloves_available(amount("construction_gloves"))


func wear_construction_gloves(wear_amount: float) -> bool:
	return equipment_state.wear_construction_gloves(wear_amount, _take_construction_gloves_from_storage)


func add_construction_glove_set() -> void:
	add("construction_gloves", 1)


func _take_construction_gloves_from_storage() -> bool:
	if equipment_state.take_construction_gloves_from_storage(amount("construction_gloves")):
		add("construction_gloves", -1)
		return true
	return false

## --- Weighted, reallocatable storage ------------------------------------------
## Every stored good takes up "space units". The warehouse holds a fixed number of
## units for the current era; the player splits that budget between resources in
## the warehouse menu. Heavy goods (logs, bricks) cost more than a unit each;
## water is light and packs several to a unit.
## Compatibility aliases — use StorageState.STORED_RESOURCES / STORAGE_WEIGHTS in new code.
const STORED_RESOURCES = StorageState.STORED_RESOURCES
const STORAGE_WEIGHTS = StorageState.STORAGE_WEIGHTS

## Compatibility alias — use EraProgress.ERA_RESOURCES in new code.
const ERA_RESOURCES = EraProgress.ERA_RESOURCES


static func resources_for_era(p_era: Era) -> Array[String]:
	return EraProgress.resources_for_era(p_era)

func era_resources() -> Array[String]:
	return era_progress.era_resources()

## Physical resources before the first warehouse live in the starter backpack.
## The backpack is a special non-replenishable ground pile shown separately in HUD.
var backpack: Dictionary:
	get: return storage.backpack
## Backward-compatible alias used by tests and UI during the refactor.
var virtual_stock: Dictionary:
	get: return storage.virtual_stock
## Becomes true the first time any warehouse is completed and never reverts.
var warehouse_ever_built: bool:
	get: return storage.warehouse_ever_built
	set(value): storage.warehouse_ever_built = value

## Resources committed to active construction sites. Maps a stable site id to
## a Dictionary of resource_type -> reserved amount. These resources are still on
## a warehouse/backpack, but they cannot be spent elsewhere until delivered or
## the site is cancelled.
var construction_reservations: ConstructionReservations = ConstructionReservations.new()


func storage_weight(resource_type: String) -> float:
	return storage.storage_weight(resource_type)


func _construction_reserved_total(resource_type: String) -> int:
	return construction_reservations.reserved_total(resource_type)


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
	return construction_reservations.reserve(site_id, resource_type, reserve)


## Releases a previously reserved amount for a construction site.
func release_for_construction(site_id: int, resource_type: String, amount: int) -> void:
	construction_reservations.release(site_id, resource_type, amount)


## Releases all reservations belonging to a single construction site.
func release_site_construction_reservations(site_id: int) -> void:
	construction_reservations.release_site(site_id)


## Returns how many units of a resource are reserved for a specific construction site.
func construction_reserved_for_site(site_id: int, resource_type: String) -> int:
	return construction_reservations.reserved_for_site(site_id, resource_type)


func can_cover_warehouse_with_tarp() -> bool:
	return storage.can_cover_warehouse_with_tarp()


func cover_warehouse_with_tarp() -> bool:
	return storage.cover_warehouse_with_tarp()


func add_warehouse(building_type: String) -> void:
	storage.add_warehouse(building_type, era_resources(), era)


func storage_capacity(_warehouses: int) -> int:
	return storage.storage_capacity(_warehouses)


func storage_used_units() -> float:
	return storage.storage_used_units()


func storage_committed_units() -> float:
	return storage.storage_committed_units()


func storage_free_units(_warehouses: int) -> float:
	return storage.storage_free_units(_warehouses)


func warehouse_accepts(index: int, resource_type: String) -> bool:
	return storage.warehouse_accepts(index, resource_type)


func set_warehouse_accepted(index: int, resource_type: String, accepted: bool) -> void:
	storage.set_warehouse_accepted(index, resource_type, accepted)


func dump_warehouse_resource(index: int, resource_type: String, count: int) -> int:
	return storage.dump_warehouse_resource(index, resource_type, count)


func storage_room_for(resource_type: String) -> int:
	return storage.storage_room_for(resource_type)


func storage_can_accept(resource_type: String, count: int) -> bool:
	return storage.storage_can_accept(resource_type, count)


func find_warehouse_index(from_position: Vector3, resource_type: String, count: int, positions: Array[Vector3]) -> int:
	return storage.find_warehouse_index(from_position, resource_type, count, positions)


func reserve_warehouse_room(index: int, resource_type: String, count: int) -> bool:
	return storage.reserve_warehouse_room(index, resource_type, count)


func release_warehouse_reservation(index: int, resource_type: String, count: int) -> void:
	storage.release_warehouse_reservation(index, resource_type, count)


func warehouse_room_for(index: int, resource_type: String) -> int:
	return storage.warehouse_room_for(index, resource_type)


func storage_availability_for(resource_type: String, count: int, warehouses: int) -> StorageAvailability:
	return storage.storage_availability_for(resource_type, count, warehouses)

func can_make_room_for(resource_type: String, count: int, _warehouses: int) -> bool:
	return storage.can_make_room_for(resource_type, count, _warehouses)


func reserve_storage_room_for(resource_type: String, count: int, warehouses: int) -> bool:
	return storage.reserve_storage_room_for(resource_type, count, warehouses)


func amount(resource_type: String) -> int:
	if resource_type == "money":
		return money
	return storage.amount(resource_type)


func set_amount(resource_type: String, value: int) -> void:
	if resource_type == "money":
		money = value
		return
	storage._set_resource_aggregate(resource_type, value)


func backpack_amount(resource_type: String) -> int:
	if resource_type == "money":
		return 0
	return storage.backpack_amount(resource_type)


func warehouse_amount(resource_type: String, index: int) -> int:
	return storage.warehouse_amount(resource_type, index)


## Add resources to a specific warehouse by index. Returns how many could not fit.
## Callers typically reserve the room first; this helper releases a matching
## reservation so the cargo actually fits.
func add_to_warehouse(resource_type: String, value: int, index: int) -> int:
	if resource_type == "money":
		return value
	return storage.add_to_warehouse(resource_type, value, index)


## Default delivery behaviour: fill warehouses sequentially and remove from them
## sequentially. Keeps the first warehouses stocked until they are full, then spills
## into the next ones. Excess is silently discarded to preserve the no-overflow
## invariant; callers that need overflow handling should use add_to_warehouse.
func add(resource_type: String, value: int) -> void:
	if resource_type == "money":
		money += value
		return
	storage.add(resource_type, value)


## Used for debug/cheat grants: pull every warehouse toward the average amount of
## the given resource. Never overfills a warehouse; excess is returned as overflow.
func add_cheat(resource_type: String, value: int) -> int:
	if value <= 0:
		add(resource_type, value)
		return 0
	if resource_type == "money":
		money += value
		return 0
	return storage.add_cheat(resource_type, value)


## Fills the least-stocked warehouse up to `percent` of its capacity.
## Only warehouses below the threshold are considered; repeated calls move to
## the next least-stocked qualifying warehouse. Resources are added evenly,
## prioritising types that are currently low in the chosen warehouse.
## Returns a dictionary with `filled` (bool) and `overflow` (resource -> leftover).
func fill_least_warehouse_cheat(percent: float) -> Dictionary:
	return storage.fill_least_warehouse_cheat(percent, era_resources())


func total_stored_resources() -> int:
	return storage.total_stored_resources()


func uses_virtual_storage() -> bool:
	return storage.uses_virtual_storage()


func migrate_backpack_to_warehouse() -> Dictionary:
	return storage.migrate_backpack_to_warehouse()


## Backward-compatible alias kept during the refactor.
func migrate_virtual_to_warehouse(_warehouses: int) -> Dictionary:
	return storage.migrate_virtual_to_warehouse(_warehouses)


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
	return unlock_state.is_building_unlocked(building_type, era)


func buy_tool(tool_id: String, price: int) -> bool:
	if not equipment_state.buy_tool(tool_id, price, money):
		return false
	money -= price
	return true


func sell(resource_type: String, quantity: int, unit_price: int) -> bool:
	if quantity <= 0 or available_amount(resource_type) < quantity:
		return false
	add(resource_type, -quantity)
	money += quantity * unit_price
	trade_sales += 1
	return true


func can_advance_to(next_era: Era, population: int, housing_slots: int) -> bool:
	var context := {
		"has_tools": _has_tools,
		"is_research_completed": is_research_completed,
		"has_building": has_building,
		"available_amount": available_amount,
		"money": money,
		"trade_sales": trade_sales,
	}
	return era_progress.can_advance_to(int(next_era), population, housing_slots, context)


func advance_era(next_era: Era, population: int, housing_slots: int) -> bool:
	var context := {
		"has_tools": _has_tools,
		"is_research_completed": is_research_completed,
		"has_building": has_building,
		"available_amount": available_amount,
		"money": money,
		"trade_sales": trade_sales,
	}
	return era_progress.advance_era(int(next_era), population, housing_slots, context, _refresh_warehouse_accepted_resources)


func _refresh_warehouse_accepted_resources() -> void:
	storage.refresh_warehouse_accepted_resources(era_resources())


func apply_cheer_up() -> bool:
	if cheer_up_used_today:
		return false
	wellbeing = mini(100, wellbeing + 5)
	cheer_up_used_today = true
	return true


func _has_tools(required: Array) -> bool:
	return equipment_state.has_tools(required)


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
	return unlock_state.is_research_completed(research_id)


func complete_research(research_id: String) -> String:
	return unlock_state.complete_research(research_id)


func pay_for_research(research_id: String) -> bool:
	if not can_afford_research(research_id): return false
	for resource_type in BuildingCatalog.research_resources(research_id): add(resource_type, -BuildingCatalog.research_cost(research_id, resource_type))
	return true
