class_name FirstPersonHUDController
extends RefCounted

const BuildingCatalogScript = preload("res://game/features/buildings/domain/building_catalog.gd")
const WarehouseStateScript = preload("res://game/features/settlement/domain/warehouse_state.gd")
const SettlementStateScript = preload("res://game/features/settlement/domain/settlement_state.gd")
const ResourcePileScript = preload("res://game/features/logistics/domain/resource_pile.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func building_action_hint(building: Node3D) -> String:
	if not is_instance_valid(building) or simulation == null:
		return ""
	var building_type: String = str(building.get_meta("building_type", ""))
	var name: String = str(BuildingCatalogScript.definition_for(building_type).get("name", building_type)).capitalize()
	var info_parts: Array[String] = []
	if building_type in ["campfire", "campfire_lvl2", "campfire_lvl3", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3"]:
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
		return "F — покинуть рабочее место"
	if simulation.player_citizen != null and simulation.player_citizen.player_using_toilet:
		return "Пользуемся туалетом..."
	var target: Dictionary = simulation._first_person_target()
	match target.get("kind", ""):
		"entrance":
			for order: Dictionary in simulation.pending_arrivals:
				if not bool(order.get("dispatched", false)):
					return "F: встретить прибывшего жителя"
			return "Входной знак"
		"building":
			if simulation._is_managed_fire_source(target.node):
				var branch_count: int = simulation._pocket_amount("branches")
				return "F: добавить 1 ветку в костер | Shift+F: добавить все (%d)" % branch_count if branch_count > 0 else "Нужны ветки в кармане, чтобы пополнить костер"
			return building_action_hint(target.node)
		"construction":
			var site = simulation.construction.site_for_node(target.node)
			if site != null and not site.is_supplied():
				var missing: String = simulation._missing_site_materials_text(site)
				if not missing.is_empty():
					return "F: сдать стройматериалы (%s)" % missing
			return "F: работать на стройке"
		"demolition":
			return "F: разбирать отмеченное здание"
		"pile":
			var pile: ResourcePileScript = target.pile
			var available: Array[String] = simulation._pile_available_resources(pile)
			if available.is_empty():
				return ""
			if not simulation._pocket_has_room():
				return "Карман полон"
			return "F: взять %s из кучи | Shift+F: взять всё" % simulation._resource_display_name(available[0]).to_lower()
		"warehouse":
			var wh_index: int = int(target.get("warehouse_index", -1))
			if wh_index < 0:
				wh_index = simulation._warehouse_index_for_building(target.node)
			if wh_index < 0:
				wh_index = simulation._nearby_warehouse_index()
			if simulation._pocket_total() > 0:
				var primary_res: String = simulation._primary_pocket_resource()
				if wh_index >= 0 and not simulation.settlement.warehouse_accepts(wh_index, primary_res):
					return "Склад не принимает %s" % primary_res.capitalize()
				var wh_room: int = simulation.settlement.warehouse_room_for(wh_index, primary_res) if wh_index >= 0 else simulation.settlement.storage_room_for(primary_res)
				if wh_room <= 0:
					return "Склад заполнен"
				return "F: сдать 1 (%s) | Shift+F: сдать всё" % primary_res.capitalize()
			if wh_index >= 0 and wh_index < simulation.settlement.warehouses.size():
				var wh_state: WarehouseState = simulation.settlement.warehouses[wh_index]
				var used := int(ceil(wh_state.used_units(SettlementStateScript.STORAGE_WEIGHTS)))
				return "Склад: %d/%d заполнено" % [used, wh_state.capacity]
			return "Склад"
		"sawmill":
			var sawmill_pos: Vector3 = target.position
			var sawmill_stock = simulation._sawmill_stock(sawmill_pos)
			if simulation._pocket_amount("wood") > 0 or simulation._pocket_amount("logs") > 0:
				var wood_count: int = simulation._pocket_amount("wood") + simulation._pocket_amount("logs")
				return "F: сдать 1 дерево на лесопилку | Shift+F: сдать всё (%d)" % wood_count
			if int(sawmill_stock.boards) > 0 and simulation._pocket_has_room():
				return "F: взять 1 доску | Shift+F: взять до заполнения"
			return ""
		"workplace":
			var building_type: String = str(target.node.get_meta("building_type", " workplace"))
			var is_official_building: bool = building_type in simulation.OFFICIAL_WORKPLACE_TYPES
			if is_official_building:
				return "Откройте меню главного костра, чтобы занять место"
			var role: String = simulation._role_for_workplace(target.node)
			if role.is_empty():
				return ""
			match role:
				"cook":
					return "F — готовить еду"
				"teacher":
					return "F — учить"
				"seller":
					return "F — торговать"
				"craftsman":
					return "F — ремесло"
				_:
					return "F — занять рабочее место (%s)" % role.replace("_", " ")
		"tree":
			var tree_node := target.node as Node3D
			if simulation.settlement.era < SettlementStateScript.Era.WOOD:
				var rem: int = int(tree_node.get_meta("remaining_branches", 0))
				if rem <= 0:
					return "Ветки иссякли (топор откроет полный сбор)"
				var init: int = maxi(1, int(tree_node.get_meta("initial_branches", rem)))
				return "F: собрать ветки (%d/%d) | Shift+F: до полноты" % [rem, init]
			return "F: срубить дерево | Shift+F: рубить до полноты"
		"grass":
			var grass_info: Dictionary = simulation._targeted_grass_info(target)
			if grass_info.is_empty():
				return "F: собрать траву | Shift+F: собирать до полноты"
			return "F: собрать траву (%d/%d) | Shift+F: до полноты" % [int(grass_info.remaining), int(grass_info.initial)]
		"farm":
			return "F: собрать еду | Shift+F: собирать до полноты"
		"pond":
			if bool(simulation.settlement.tools.get("bucket", false)):
				return "F: набрать воды | Shift+F: набирать до полноты"
			return "Нужно ведро, чтобы черпать воду. Купите его на рынке."
		"forage", "rabbit":
			return "Лесные дары и зайца может собирать только специалист. Постройте палатку охотников-собирателей."
		"toilet":
			var needs_toilet: bool = simulation.citizen_needs_service != null and simulation.citizen_needs_service.has_toilet_request(simulation.player_citizen.ai_id)
			if needs_toilet:
				return "F: воспользоваться туалетом (потребность)"
			return "F: воспользоваться туалетом"
		"citizen":
			var citizen := target.node as Citizen
			if not is_instance_valid(citizen):
				return ""
			var status: Array[String] = citizen.status_effect_labels()
			var status_text: String = ", ".join(status) if not status.is_empty() else "OK"
			return "%s | %s | %s" % [citizen.role_label(), simulation._citizen_state_name(citizen.state), status_text]
	return ""
