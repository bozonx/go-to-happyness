class_name FirstPersonHUDController
extends RefCounted

const BuildingCatalogScript = preload("res://game/features/buildings/domain/building_catalog.gd")
const WarehouseStateScript = preload("res://game/features/settlement/domain/warehouse_state.gd")
const SettlementStateScript = preload("res://game/features/settlement/domain/settlement_state.gd")
const ResourcePileScript = preload("res://game/features/logistics/domain/resource_pile.gd")
const S = preload("res://game/features/ui/domain/game_strings.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func building_action_hint(building: Node3D) -> String:
	if not is_instance_valid(building) or simulation == null:
		return ""
	var building_type: String = simulation.building_registry.building_type_for_node(building)
	var name: String = str(BuildingCatalogScript.definition_for(building_type).get("name", building_type)).capitalize()
	var info_parts: Array[String] = []
	if BuildingTypes.is_fire_source(building_type):
		var fire_state = simulation._fire_state_for(building)
		var phase: int = fire_state.phase_at(int(simulation.game_minutes))
		var phase_label: String = ["burning", "dying", "embers", "out"][phase]
		var delivery_hint := ", %d in transit" % fire_state.reserved_fuel if fire_state.reserved_fuel > 0 else ""
		info_parts.append("Fire: %s (%d fuel%s)" % [phase_label, fire_state.fuel, delivery_hint])
	if building_type in BuildingCatalogScript.KITCHEN_FOOD_CAPACITIES:
		info_parts.append("Food cap: %d" % BuildingCatalogScript.kitchen_food_capacity(building_type))
	var required: Dictionary = simulation._required_staff_for_building(building)
	if not required.is_empty():
		var assigned: int = simulation._assigned_staff_for_building(building, required)
		info_parts.append("Staff %d/%d" % [assigned, int(required.count)])
	if building.has_meta("housing_capacity"):
		var capacity: int = int(building.get_meta("housing_capacity", 1))
		var free_slots: int = int(building.get_meta("spawn_slots", capacity))
		var occupied: int = clampi(capacity - free_slots, 0, capacity)
		info_parts.append("Residents %d/%d" % [occupied, capacity])
	if info_parts.is_empty():
		return name
	return "%s | %s" % [name, " | ".join(info_parts)]


func first_person_action_hint() -> String:
	if simulation == null:
		return ""
	if simulation.player_citizen != null and simulation.player_citizen.work_position_locked:
		return S.F_LEAVE_WORK_POSITION
	if simulation.player_citizen != null and simulation.player_citizen.player_using_toilet:
		return S.USING_TOILET
	var target: Dictionary = simulation._first_person_target()
	match target.get("kind", ""):
		"entrance":
			for order: Dictionary in simulation.pending_arrivals:
				if not bool(order.get("dispatched", false)):
					return S.F_MEET_ARRIVAL
			return S.ENTRANCE_SIGN
		"building":
			if simulation._is_managed_fire_source(target.node):
				var branch_count: int = simulation._pocket_amount(ResourceIds.BRANCHES)
				return S.F_ADD_BRANCH_TO_FIRE % branch_count if branch_count > 0 else S.NEED_BRANCHES_FOR_FIRE
			return building_action_hint(target.node)
		"construction":
			var site = simulation.construction.site_for_node(target.node)
			if site != null and not site.is_supplied():
				var missing: String = simulation._missing_site_materials_text(site)
				if not missing.is_empty():
					return S.F_DELIVER_MATERIALS % missing
			return S.F_WORK_ON_CONSTRUCTION
		"demolition":
			return S.F_DEMOLISH
		"pile":
			var pile: ResourcePileScript = target.pile
			var available: Array[String] = simulation._pile_available_resources(pile)
			if available.is_empty():
				return ""
			if not simulation._pocket_has_room():
				return S.POCKET_FULL
			return S.F_TAKE_FROM_PILE % simulation._resource_display_name(available[0]).to_lower()
		"warehouse":
			var wh_index: int = int(target.get("warehouse_index", -1))
			if wh_index < 0:
				wh_index = simulation._warehouse_index_for_building(target.node)
			if wh_index < 0:
				wh_index = simulation._nearby_warehouse_index()
			if simulation._pocket_total() > 0:
				var primary_res: String = simulation._primary_pocket_resource()
				if wh_index >= 0 and not simulation.settlement.warehouse_accepts(wh_index, primary_res):
					return S.WAREHOUSE_REJECTS % primary_res.capitalize()
				var wh_room: int = simulation.settlement.warehouse_room_for(wh_index, primary_res) if wh_index >= 0 else simulation.settlement.storage_room_for(primary_res)
				if wh_room <= 0:
					return S.WAREHOUSE_FULL
				return S.F_DEPOSIT_ONE % primary_res.capitalize()
			if wh_index >= 0 and wh_index < simulation.settlement.warehouses.size():
				var wh_state: WarehouseState = simulation.settlement.warehouses[wh_index]
				var used := int(ceil(wh_state.used_units(SettlementStateScript.STORAGE_WEIGHTS)))
				return S.WAREHOUSE_FILL_FORMAT % [used, wh_state.capacity]
			return S.WAREHOUSE
		"sawmill":
			var sawmill_pos: Vector3 = target.position
			var sawmill_stock = simulation._sawmill_stock(sawmill_pos)
			if simulation._pocket_amount(ResourceIds.WOOD) > 0 or simulation._pocket_amount(ResourceIds.LOGS) > 0:
				var wood_count: int = simulation._pocket_amount(ResourceIds.WOOD) + simulation._pocket_amount(ResourceIds.LOGS)
				return S.F_DEPOSIT_WOOD_SAWMILL % wood_count
			if int(sawmill_stock.boards) > 0 and simulation._pocket_has_room():
				return S.F_TAKE_BOARD
			return ""
		"workplace":
			var building_type: String = simulation.building_registry.building_type_for_node(target.node)
			var is_official_building: bool = building_type in simulation.OFFICIAL_WORKPLACE_TYPES
			if is_official_building:
				return S.OPEN_CAMPFIRE_MENU_FOR_OFFICIAL
			var role: String = simulation._role_for_workplace(target.node)
			if role.is_empty():
				return ""
			match role:
				"cook":
					return S.F_COOK
				"teacher":
					return S.F_TEACH
				"seller":
					return S.F_TRADE
				"craftsman":
					return S.F_CRAFT
				_:
					return S.F_OCCUPY_WORKPLACE % role.replace("_", " ")
		"tree":
			var tree_node := target.node as Node3D
			if simulation.settlement.era < SettlementStateScript.Era.WOOD:
				var rem: int = int(tree_node.get_meta("remaining_branches", 0))
				if rem <= 0:
					return S.BRANCHES_DEPLETED
				var init: int = maxi(1, int(tree_node.get_meta("initial_branches", rem)))
				return S.F_GATHER_BRANCHES % [rem, init]
			return S.F_CHOP_TREE
		"grass":
			var grass_info: Dictionary = simulation._targeted_grass_info(target)
			if grass_info.is_empty():
				return S.F_GATHER_GRASS
			return S.F_GATHER_GRASS_COUNT % [int(grass_info.remaining), int(grass_info.initial)]
		"farm":
			return S.F_HARVEST_FARM
		"pond":
			if bool(simulation.settlement.tools.get("bucket", false)):
				return S.F_COLLECT_WATER
			return S.NEED_BUCKET_FOR_WATER
		"forage", "rabbit":
			return S.FORAGE_SPECIALIST_ONLY
		"toilet":
			var needs_toilet: bool = simulation.citizen_needs_service != null and simulation.citizen_needs_service.has_toilet_request(simulation.player_citizen.ai_id)
			if needs_toilet:
				return S.F_USE_TOILET_NEED
			return S.F_USE_TOILET
		"citizen":
			var citizen := target.node as Citizen
			if not is_instance_valid(citizen):
				return ""
			var status: Array[String] = citizen.status_effect_labels()
			var status_text: String = ", ".join(status) if not status.is_empty() else "OK"
			return "%s | %s | %s" % [citizen.role_label(), simulation._citizen_state_name(citizen.state), status_text]
	return ""
