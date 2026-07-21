class_name BuildingLifecycleService
extends RefCounted

## Manages building demolition lifecycle: marking buildings, demolition markers,
## readiness checks (resident relocation), finishing demolition (service removal,
## resource recovery, navigation/territory updates), expired tent cleanup,
## house light updates, and campfire selection.

const BillboardLabelScene = preload("res://game/features/ui/presentation/billboard_label.tscn")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func mark_building_for_demolition(building: Node3D) -> void:
	if not simulation._can_hero_build() or not is_instance_valid(building):
		return
	if simulation.demolition.has_site(building):
		return
	if building == simulation.entrance_stone:
		simulation._update_interface("This building cannot be demolished.")
		return
	var building_type: String = str(building.get_meta("building_type", "house"))
	if not BuildingCatalog.is_demolishable(building_type):
		simulation._update_interface("This landmark cannot be demolished.")
		return
	release_employment_at_building(building)
	building.set_meta("pending_demolition", true)
	simulation._cancel_arrivals_for_house(building)
	add_demolition_marker(building)
	simulation.demolition.mark(building, building_type)
	simulation._update_workers()
	simulation._update_interface("Building marked for demolition. Residents and stored goods must be relocated first.")


func add_demolition_marker(building: Node3D) -> void:
	if building.has_meta("demolition_marker"):
		return
	var marker: Label3D = BillboardLabelScene.instantiate() as Label3D
	marker.text = "DEMOLISH"
	marker.position = Vector3(0.0, 5.2, 0.0)
	marker.font_size = 32
	marker.outline_size = 6
	marker.modulate = Color("ef4f45")
	building.add_child(marker)
	building.set_meta("demolition_marker", marker)


func demolition_ready(site: DemolitionSite) -> bool:
	var building: Node3D = site.building
	if not is_instance_valid(building):
		return false
	var residents_to_relocate := 0
	for citizen in simulation.citizens:
		if citizen.home == building:
			residents_to_relocate += 1
	var available_slots := 0
	for record in simulation.building_registry.records():
		var candidate: Node3D = record.node
		if not is_instance_valid(candidate) or candidate == building or bool(candidate.get_meta("pending_demolition", false)):
			continue
		available_slots += maxi(0, int(candidate.get_meta("spawn_slots", 0)))
	if available_slots < residents_to_relocate:
		return false
	for citizen in simulation.citizens:
		if citizen.home != building:
			continue
		var replacement: Node3D = find_relocation_home(building)
		if replacement == null:
			return false
		citizen.assign_home(replacement)
		simulation._refresh_living_status(citizen)
		replacement.set_meta("spawn_slots", int(replacement.get_meta("spawn_slots", 0)) - 1)
	return true


func find_relocation_home(excluded: Node3D) -> Node3D:
	for record in simulation.building_registry.records():
		var candidate: Node3D = record.node
		if not is_instance_valid(candidate) or candidate == excluded or bool(candidate.get_meta("pending_demolition", false)):
			continue
		if int(candidate.get_meta("spawn_slots", 0)) > 0:
			return candidate
	return null


func finish_demolition(site: DemolitionSite) -> void:
	var building: Node3D = site.building
	var building_type: String = site.building_type
	var active_kitchen_removed: bool = simulation.canteen == building
	simulation._unregister_service_pockets(building)
	var pile_resources: Dictionary = BuildingCatalog.demolition_refund(building_type).duplicate(true)
	if building_type in ["warehouse", "straw_warehouse", "tarp_warehouse"]:
		var service_position: Vector3 = building.get_meta("service_position", building.global_position)
		var warehouse_index: int = simulation.warehouse_positions.find(service_position)
		move_stored_resources_to_pile(pile_resources, warehouse_index)
		simulation._return_in_transit_building_supplies(building)
	if active_kitchen_removed:
		if simulation.pending_canteen_delivery:
			simulation._cancel_canteen_delivery()
		simulation.settlement.add("food", simulation.canteen_food)
		simulation.canteen_food = 0
	for citizen in simulation.citizens:
		citizen.finish_construction(building)
	remove_building_services(building, building_type)
	var removed_record = simulation.building_registry.remove_node(building)
	if removed_record != null:
		simulation._unregister_navigation_footprint(removed_record.center, removed_record.footprint)
		simulation.village_territory_service.on_building_removed(removed_record.cell)
		simulation._refresh_boundary_markers()
	if active_kitchen_removed:
		simulation._select_best_canteen()
	simulation.settlement.buildings[building_type] = maxi(0, int(simulation.settlement.buildings.get(building_type, 1)) - 1)
	if simulation.campfire_node == null:
		select_best_campfire()
	for i in range(simulation.house_lights.size() - 1, -1, -1):
		if simulation.house_lights[i].house == building:
			simulation.house_lights.remove_at(i)
	for i in range(simulation.entrance_lights.size() - 1, -1, -1):
		if not is_instance_valid(simulation.entrance_lights[i]):
			simulation.entrance_lights.remove_at(i)
		elif simulation.entrance_lights[i].get_parent() == building:
			simulation.entrance_lights.remove_at(i)
	simulation._create_resource_pile(building.global_position, pile_resources)
	building.queue_free()
	simulation._refresh_navigation_grid()
	simulation._update_workers()
	simulation._update_interface("%s dismantled; recovered materials are waiting in a resource pile." % building_type.capitalize())


func remove_building_services(building: Node3D, building_type: String) -> void:
	release_employment_at_building(building)
	var service_position: Vector3 = building.get_meta("service_position", building.global_position)
	match building_type:
		"warehouse", "straw_warehouse", "tarp_warehouse":
			var index: int = simulation.warehouse_positions.find(service_position)
			if index >= 0:
				simulation.warehouse_positions.remove_at(index)
				simulation.settlement.warehouses.remove_at(index)
				simulation.settlement.warehouse_types.remove_at(index)
		"sawmill": simulation.sawmill_positions.erase(service_position)
		"farm": simulation.farm_positions.erase(service_position)
		"builders_guild": simulation.builders_guild_positions.erase(service_position)
		"construction_company": simulation.construction_company_positions.erase(service_position)
		"forager_tent", "straw_forager_tent", "tarp_forager_tent": simulation.forager_positions.erase(service_position)
		"materials_yard", "straw_materials_yard", "tarp_materials_yard": simulation.materials_yard_positions.erase(service_position)
		"school": simulation.school_positions.erase(service_position)
		"park": simulation.park_positions.erase(service_position)
		"gathering_place": simulation.gathering_place_positions.erase(service_position)
		"leisure_center": simulation.leisure_positions.erase(service_position)
		"craft_tent", "straw_craft_tent", "tarp_craft_tent": simulation.craft_tent_positions.erase(service_position)
		"straw_trade_tent", "tarp_trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market":
			simulation.market_positions.erase(service_position)
		"campfire", "campfire_lvl2", "campfire_lvl3", "earth_assembly", "clay_lodge", "wood_town_hall", "stone_prefecture", "brick_city_hall":
			if simulation.campfire_node == building: simulation.campfire_node = null
		"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant":
			if simulation.canteen == building: simulation.canteen = null
		"dew_collector", "advanced_dew_collector":
			for i in range(simulation.water_collectors.size() - 1, -1, -1):
				if simulation.water_collectors[i].node == building:
					simulation.water_collectors.remove_at(i)
		"employment_office":
			if simulation.employment_office == building: simulation.employment_office = null
		"brick_factory", "materials_factory", "recycling_factory", "metal_factory": simulation.factories.erase(building)


func release_employment_at_building(building: Node3D) -> void:
	for citizen in simulation.citizens:
		if building == simulation.campfire_node and citizen.daily_order_role == "researcher":
			if simulation.settlement.active_research_tech_id != "" and simulation.settlement.active_research_worker_id == citizen.ai_id:
				simulation._cancel_active_building_research(true, "Research cancelled: the civic post was removed. Resources refunded.")
			citizen.clear_daily_order()
			citizen.idle()
		if citizen.employment_workplace != building and citizen.pending_employment_workplace != building:
			continue
		if citizen.permanent_role == "official":
			simulation._dismiss_official(citizen)
			continue
		simulation._send_to_unemployment_registration(citizen)


func move_stored_resources_to_pile(resources: Dictionary, warehouse_index := -1) -> void:
	if warehouse_index >= 0 and warehouse_index < simulation.settlement.warehouses.size():
		for resource_type in SettlementState.STORED_RESOURCES:
			var amount: int = simulation.settlement.warehouses[warehouse_index].amount(resource_type)
			if amount <= 0:
				continue
			resources[resource_type] = int(resources.get(resource_type, 0)) + amount
			simulation.settlement.warehouses[warehouse_index].set_amount(resource_type, 0)
		return
	for resource_type in SettlementState.STORED_RESOURCES:
		var amount: int = simulation.settlement.amount(resource_type)
		if amount <= 0:
			continue
		resources[resource_type] = int(resources.get(resource_type, 0)) + amount
		simulation.settlement.add(resource_type, -amount)


func remove_expired_temporary_tents() -> void:
	for record in simulation.building_registry.records().duplicate():
		var tent: Node3D = record.node as Node3D
		if not is_instance_valid(tent) or simulation._is_construction_site(tent) or str(tent.get_meta("building_type", "")) != "tent":
			continue
		for citizen in simulation.citizens:
			if is_instance_valid(citizen) and citizen.home == tent:
				citizen.home = null
				simulation._refresh_living_status(citizen)
		simulation._cancel_arrivals_for_house(tent)
		simulation._unregister_service_pockets(tent)
		remove_building_services(tent, "tent")
		var removed_record = simulation.building_registry.remove_node(tent)
		if removed_record != null:
			simulation._unregister_navigation_footprint(removed_record.center, removed_record.footprint)
			simulation.village_territory_service.on_building_removed(removed_record.cell)
		simulation.settlement.buildings["tent"] = maxi(0, int(simulation.settlement.buildings.get("tent", 1)) - 1)
		tent.queue_free()
	simulation._refresh_navigation_grid()
	simulation._update_workers()


func update_house_lights() -> void:
	var hour: int = int(simulation.game_minutes) / 60
	var minute: int = int(simulation.game_minutes) % 60
	var clock_minute: int = int(simulation.game_minutes)
	if simulation.house_light_update_minute == clock_minute:
		return
	simulation.house_light_update_minute = clock_minute
	var minute_of_day: int = hour * 60 + minute
	for record in simulation.house_lights:
		if not is_instance_valid(record.light):
			continue
		var light: OmniLight3D = record.light
		var house: Node3D = record.house
		var off_minute: int = int(house.get_meta("light_off_minute", record.off_minute))
		var occupied: bool = house_has_residents(house)
		light.visible = occupied and house_has_people_at_home(house) and (minute_of_day >= 17 * 60 and minute_of_day < off_minute if off_minute >= 17 * 60 else minute_of_day >= 17 * 60 or minute_of_day < off_minute)
	for light in simulation.entrance_lights:
		if is_instance_valid(light):
			light.visible = minute_of_day >= 17 * 60 or minute_of_day < 7 * 60


func house_has_residents(house: Node3D) -> bool:
	if not is_instance_valid(house):
		return false
	for citizen in simulation.citizens:
		if citizen.home == house:
			return true
	return false


func house_has_people_at_home(house: Node3D) -> bool:
	for citizen in simulation.citizens:
		if citizen.home == house and citizen.state == Citizen.State.RESTING:
			return true
	return false


func select_best_campfire() -> void:
	var best_campfire: Node3D = null
	var best_rank := -1
	var ranks := {
		"campfire": 1, "campfire_lvl2": 2, "campfire_lvl3": 3,
		"earth_assembly": 4, "clay_lodge": 5, "wood_town_hall": 6,
		"stone_prefecture": 7, "brick_city_hall": 8,
	}
	for record in simulation.building_registry.records():
		var candidate: Node3D = record.node
		if not is_instance_valid(candidate):
			continue
		var rank: int = int(ranks.get(str(candidate.get_meta("building_type", "")), -1))
		if rank > best_rank:
			best_campfire = candidate
			best_rank = rank
	simulation.campfire_node = best_campfire
	if is_instance_valid(simulation.campfire_node):
		simulation._activate_employment_centre(simulation.campfire_node)


func register_completed_building_type_features(building_type: String, building: Node3D, blueprint: Dictionary, service_position: Vector3) -> void:
	match building_type:
		"warehouse", "straw_warehouse", "tarp_warehouse":
			simulation.settlement.add_warehouse(building_type)
			simulation.warehouse_positions.append(service_position)
			if simulation.warehouse_positions.size() == 1:
				simulation._convert_backpack_pile_to_regular()
				simulation.settlement.warehouse_ever_built = true
				simulation.settlement.backpack.clear()
			simulation._add_building_selector(building, "warehouse_selector", blueprint.footprint)
			simulation._add_warehouse_fill_label(building)
		"sawmill":
			simulation.sawmill_positions.append(service_position)
			simulation._sawmill_stock(service_position)
		"farm":
			simulation.farm_positions.append(service_position)
		"builders_guild":
			simulation.builders_guild_positions.append(service_position)
		"construction_company":
			simulation.construction_company_positions.append(service_position)
		"campfire", "campfire_lvl2", "campfire_lvl3", "earth_assembly", "clay_lodge", "wood_town_hall", "stone_prefecture", "brick_city_hall":
			simulation.campfire_node = building
			simulation._activate_employment_centre(building)
			simulation._add_building_selector(building, "campfire_selector", blueprint.footprint)
			var fire_light: Node3D = simulation.FireLightScene.instantiate()
			building.add_child(fire_light)
		"gathering_place":
			simulation.gathering_place_positions.append(service_position)
			simulation._create_gathering_place_visual(building)
			simulation._add_building_selector(building, "building_selector", blueprint.footprint)
		"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant":
			simulation._activate_kitchen_if_better(building, service_position)
			simulation._add_building_selector(building, "cook_campfire_selector", blueprint.footprint)
			var cook_fire_light: Node3D = simulation.FireLightScene.instantiate()
			building.add_child(cook_fire_light)
		"forager_tent", "straw_forager_tent", "tarp_forager_tent":
			simulation.forager_positions.append(service_position)
			simulation._update_interface("Forager tent ready. Assign a resident to forage food, or a free hand will.")
		"materials_yard", "straw_materials_yard", "tarp_materials_yard":
			simulation.materials_yard_positions.append(service_position)
			simulation._update_interface("Двор стройматериалов готов. Работники собирают ветки и траву (что в дефиците), или это сделает свободный житель.")
		"tent", "straw_tent", "tarp_tent", "dugout", "earth_house", "clay_house", "stone_house", "house", "house_lvl2", "house_lvl3", "brick_house":
			if building_type in ["house", "house_lvl2", "house_lvl3", "brick_house"]:
				simulation.completed_house_count += 1
			var housing_capacity: int = simulation.HOUSE_CAPACITY

			match building_type:
				"straw_tent": housing_capacity = 1
				"tarp_tent": housing_capacity = 2
				"tent", "dugout": housing_capacity = 4
				"earth_house", "clay_house": housing_capacity = 6
				"house": housing_capacity = 8
				"house_lvl2": housing_capacity = 10
				"house_lvl3": housing_capacity = 12
				"stone_house": housing_capacity = 10
				"brick_house": housing_capacity = 12
			building.set_meta("housing_capacity", housing_capacity)
			building.set_meta("spawn_slots", housing_capacity)
			simulation._add_building_selector(building, "house_selector", blueprint.footprint)
			simulation._add_house_light(building)
			if building_type in ["tent", "straw_tent", "tarp_tent"]:
				building.set_meta("is_tent", true)
			simulation._house_initial_residents(building)
		"dew_collector", "advanced_dew_collector":
			var rate := 0.12
			var capacity := 10
			if building_type == "advanced_dew_collector":
				rate = 0.3
				capacity = 25
			simulation.water_collectors.append({"node": building, "rate": rate, "accum": 0.0, "stored": 0, "capacity": capacity})
		"craft_tent", "straw_craft_tent", "tarp_craft_tent":
			simulation.craft_tent_positions.append(service_position)
		"straw_trade_tent", "tarp_trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market":
			simulation._add_building_selector(building, "market_selector", blueprint.footprint)
			simulation.market_positions.append(service_position)
		"employment_office":
			simulation.employment_office = building
			simulation.employment_office_position = service_position
		"school":
			simulation.school_positions.append(service_position)
			simulation._add_building_selector(building, "school_selector", blueprint.footprint)
		"park":
			simulation.park_positions.append(service_position)
		"leisure_center":
			simulation.leisure_positions.append(service_position)
			simulation._add_building_selector(building, "building_selector", blueprint.footprint)
		"brick_factory", "materials_factory", "recycling_factory", "metal_factory":
			building.set_meta("required_factory_workers", 3 if building_type in ["recycling_factory", "metal_factory"] else 1)
			simulation.factories.append(building)
			if building_type == "materials_factory":
				simulation._add_building_selector(building, "materials_factory_selector", blueprint.footprint)
		"boundary_post":
			simulation._add_building_selector(building, "building_selector", blueprint.footprint)


