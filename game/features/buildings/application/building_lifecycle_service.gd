class_name BuildingLifecycleService
extends RefCounted

## Manages building demolition lifecycle: marking buildings, demolition markers,
## readiness checks (resident relocation), finishing demolition (service removal,
## resource recovery, navigation/territory updates), expired tent cleanup,
## house light updates, and campfire selection.

const S = preload("res://game/features/ui/domain/game_strings.gd")
const WaterCollectorRecordScript = preload("res://game/features/logistics/domain/water_collector_record.gd")
const HouseLightRecord = preload("res://game/features/buildings/domain/house_light_record.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")
const BuildingRuntimeStateScript = preload("res://game/features/buildings/application/building_runtime_state.gd")

var _settlement: SettlementState
var _citizens: Array = []
var _building_registry: Variant
var _demolition: Variant
var _village_territory_service: Variant
var _warehouse_positions: Array[Vector3] = []
var _sawmill_positions: Array[Vector3] = []
var _farm_positions: Array[Vector3] = []
var _builders_guild_positions: Array[Vector3] = []
var _construction_company_positions: Array[Vector3] = []
var _forager_positions: Array[Vector3] = []
var _materials_yard_positions: Array[Vector3] = []
var _school_positions: Array[Vector3] = []
var _park_positions: Array[Vector3] = []
var _gathering_place_positions: Array[Vector3] = []
var _leisure_positions: Array[Vector3] = []
var _craft_tent_positions: Array[Vector3] = []
var _market_positions: Array[Vector3] = []
var _water_collectors: Array = []
var _factories: Array = []
var _house_lights: Array = []
var _entrance_lights: Array = []
var _house_capacity: int
var _fire_light_scene: PackedScene
var _entrance_stone_getter: Callable
var _campfire_node_getter: Callable
var _campfire_node_setter: Callable
var _canteen_getter: Callable
var _canteen_setter: Callable
var _canteen_food_getter: Callable
var _canteen_food_setter: Callable
var _pending_canteen_delivery_getter: Callable
var _employment_office_getter: Callable
var _employment_office_setter: Callable
var _employment_office_position_getter: Callable
var _employment_office_position_setter: Callable
var _completed_house_count_getter: Callable
var _completed_house_count_setter: Callable
var _house_light_update_minute_getter: Callable
var _house_light_update_minute_setter: Callable
var _game_minutes_getter: Callable
var _can_hero_build: Callable
var _update_interface: Callable
var _update_workers: Callable
var _cancel_arrivals_for_house: Callable
var _add_demolition_marker: Callable
var _refresh_living_status: Callable
var _unregister_service_pockets: Callable
var _return_in_transit_building_supplies: Callable
var _cancel_canteen_delivery: Callable
var _unregister_navigation_footprint: Callable
var _refresh_boundary_markers: Callable
var _select_best_canteen: Callable
var _create_resource_pile: Callable
var _refresh_navigation_grid: Callable
var _is_construction_site: Callable
var _activate_employment_centre: Callable
var _convert_backpack_pile_to_regular: Callable
var _add_building_selector: Callable
var _add_warehouse_fill_label: Callable
var _sawmill_stock: Callable
var _create_gathering_place_visual: Callable
var _activate_kitchen_if_better: Callable
var _add_house_light: Callable
var _house_initial_residents: Callable
var _cancel_active_building_research: Callable
var _dismiss_official: Callable
var _send_to_unemployment_registration: Callable


func configure(port: BuildingLifecycleRuntimePort) -> void:
	_settlement = port.settlement
	_citizens = port.citizens
	_building_registry = port.building_registry
	_demolition = port.demolition
	_village_territory_service = port.village_territory_service
	_warehouse_positions = port.warehouse_positions
	_sawmill_positions = port.sawmill_positions
	_farm_positions = port.farm_positions
	_builders_guild_positions = port.builders_guild_positions
	_construction_company_positions = port.construction_company_positions
	_forager_positions = port.forager_positions
	_materials_yard_positions = port.materials_yard_positions
	_school_positions = port.school_positions
	_park_positions = port.park_positions
	_gathering_place_positions = port.gathering_place_positions
	_leisure_positions = port.leisure_positions
	_craft_tent_positions = port.craft_tent_positions
	_market_positions = port.market_positions
	_water_collectors = port.water_collectors
	_factories = port.factories
	_house_lights = port.house_lights
	_entrance_lights = port.entrance_lights
	_house_capacity = port.house_capacity
	_fire_light_scene = port.fire_light_scene
	_entrance_stone_getter = port.entrance_stone_getter
	_campfire_node_getter = port.campfire_node_getter
	_campfire_node_setter = port.campfire_node_setter
	_canteen_getter = port.canteen_getter
	_canteen_setter = port.canteen_setter
	_canteen_food_getter = port.canteen_food_getter
	_canteen_food_setter = port.canteen_food_setter
	_pending_canteen_delivery_getter = port.pending_canteen_delivery_getter
	_employment_office_getter = port.employment_office_getter
	_employment_office_setter = port.employment_office_setter
	_employment_office_position_getter = port.employment_office_position_getter
	_employment_office_position_setter = port.employment_office_position_setter
	_completed_house_count_getter = port.completed_house_count_getter
	_completed_house_count_setter = port.completed_house_count_setter
	_house_light_update_minute_getter = port.house_light_update_minute_getter
	_house_light_update_minute_setter = port.house_light_update_minute_setter
	_game_minutes_getter = port.game_minutes_getter
	_can_hero_build = port.can_hero_build
	_update_interface = port.update_interface
	_update_workers = port.update_workers
	_cancel_arrivals_for_house = port.cancel_arrivals_for_house
	_add_demolition_marker = port.add_demolition_marker
	_refresh_living_status = port.refresh_living_status
	_unregister_service_pockets = port.unregister_service_pockets
	_return_in_transit_building_supplies = port.return_in_transit_building_supplies
	_cancel_canteen_delivery = port.cancel_canteen_delivery
	_unregister_navigation_footprint = port.unregister_navigation_footprint
	_refresh_boundary_markers = port.refresh_boundary_markers
	_select_best_canteen = port.select_best_canteen
	_create_resource_pile = port.create_resource_pile
	_refresh_navigation_grid = port.refresh_navigation_grid
	_is_construction_site = port.is_construction_site
	_activate_employment_centre = port.activate_employment_centre
	_convert_backpack_pile_to_regular = port.convert_backpack_pile_to_regular
	_add_building_selector = port.add_building_selector
	_add_warehouse_fill_label = port.add_warehouse_fill_label
	_sawmill_stock = port.sawmill_stock
	_create_gathering_place_visual = port.create_gathering_place_visual
	_activate_kitchen_if_better = port.activate_kitchen_if_better
	_add_house_light = port.add_house_light
	_house_initial_residents = port.house_initial_residents
	_cancel_active_building_research = port.cancel_active_building_research
	_dismiss_official = port.dismiss_official
	_send_to_unemployment_registration = port.send_to_unemployment_registration


func mark_building_for_demolition(building: Node3D) -> void:
	if not _can_hero_build.call() or not is_instance_valid(building):
		return
	if _demolition.has_site(building):
		cancel_building_demolition(building)
		return
	if building == _entrance_stone_getter.call():
		_update_interface.call("This building cannot be demolished.")
		return
	var building_type: String = _building_registry.building_type_for_node(building)
	if not BuildingCatalog.is_demolishable(building_type):
		_update_interface.call("This landmark cannot be demolished.")
		return
	building.set_meta("pending_demolition", true)
	_add_demolition_marker.call(building)
	_demolition.mark(building, building_type)
	_update_workers.call()
	_update_interface.call("Building marked for demolition. Residents and stored goods must be relocated first.")


func cancel_building_demolition(building: Node3D) -> void:
	if not is_instance_valid(building) or not _demolition.cancel(building):
		return
	building.set_meta("pending_demolition", false)
	var marker: Node = building.get_meta("demolition_marker", null) as Node
	if is_instance_valid(marker):
		marker.queue_free()
	if building.has_meta("demolition_marker"):
		building.remove_meta("demolition_marker")
	_update_workers.call()
	_update_interface.call("Demolition cancelled.")


func demolition_ready(site: DemolitionSite) -> bool:
	var building: Node3D = site.building
	if not is_instance_valid(building):
		return false
	var residents_to_relocate := 0
	for citizen in _citizens:
		if citizen.home == building:
			residents_to_relocate += 1
	var available_slots := 0
	for record in _building_registry.records():
		var candidate: Node3D = record.node
		if not is_instance_valid(candidate) or candidate == building or bool(candidate.get_meta("pending_demolition", false)):
			continue
		available_slots += maxi(0, int(candidate.get_meta("spawn_slots", 0)))
	if available_slots < residents_to_relocate:
		return false
	for citizen in _citizens:
		if citizen.home != building:
			continue
		var replacement: Node3D = find_relocation_home(building)
		if replacement == null:
			return false
		citizen.assign_home(replacement)
		_refresh_living_status.call(citizen)
		replacement.set_meta("spawn_slots", int(replacement.get_meta("spawn_slots", 0)) - 1)
	return true


func find_relocation_home(excluded: Node3D) -> Node3D:
	for record in _building_registry.records():
		var candidate: Node3D = record.node
		if not is_instance_valid(candidate) or candidate == excluded or bool(candidate.get_meta("pending_demolition", false)):
			continue
		if int(candidate.get_meta("spawn_slots", 0)) > 0:
			return candidate
	return null


func finish_demolition(site: DemolitionSite) -> void:
	var building: Node3D = site.building
	var building_type: String = site.building_type
	_cancel_arrivals_for_house.call(building)
	var active_kitchen_removed: bool = _canteen_getter.call() == building
	_unregister_service_pockets.call(building)
	var pile_resources: Dictionary = BuildingCatalog.demolition_refund(building_type).duplicate(true)
	if BuildingTypes.is_warehouse(building_type):
		var service_position: Vector3 = building.get_meta("service_position", building.global_position)
		var warehouse_index: int = _warehouse_positions.find(service_position)
		move_stored_resources_to_pile(pile_resources, warehouse_index)
		_return_in_transit_building_supplies.call(building)
	if active_kitchen_removed:
		if _pending_canteen_delivery_getter.call():
			_cancel_canteen_delivery.call()
		_settlement.add(ResourceIds.FOOD, _canteen_food_getter.call())
		_canteen_food_setter.call(0)
	for citizen in _citizens:
		citizen.finish_construction(building)
	remove_building_services(building, building_type)
	var removed_record = _building_registry.remove_node(building)
	if removed_record != null:
		_unregister_navigation_footprint.call(removed_record.center, removed_record.footprint)
		_village_territory_service.on_building_removed(removed_record.cell)
		_refresh_boundary_markers.call()
	if active_kitchen_removed:
		_select_best_canteen.call()
	_settlement.buildings[building_type] = maxi(0, int(_settlement.buildings.get(building_type, 1)) - 1)
	if _campfire_node_getter.call() == null:
		select_best_campfire()
	for i in range(_house_lights.size() - 1, -1, -1):
		if _house_lights[i].house == building:
			_house_lights.remove_at(i)
	for i in range(_entrance_lights.size() - 1, -1, -1):
		if not is_instance_valid(_entrance_lights[i]):
			_entrance_lights.remove_at(i)
		elif _entrance_lights[i].get_parent() == building:
			_entrance_lights.remove_at(i)
	_create_resource_pile.call(building.global_position, pile_resources)
	building.queue_free()
	_refresh_navigation_grid.call()
	_update_workers.call()
	_update_interface.call("%s dismantled; recovered materials are waiting in a resource pile." % building_type.capitalize())


func remove_building_services(building: Node3D, building_type: String) -> void:
	release_employment_at_building(building)
	var service_position: Vector3 = building.get_meta("service_position", building.global_position)
	match building_type:
		"warehouse", "straw_warehouse", "tarp_warehouse":
			var index: int = _warehouse_positions.find(service_position)
			if index >= 0:
				_warehouse_positions.remove_at(index)
				_settlement.warehouses.remove_at(index)
				_settlement.warehouse_types.remove_at(index)
		"sawmill": _sawmill_positions.erase(service_position)
		"farm": _farm_positions.erase(service_position)
		"builders_guild": _builders_guild_positions.erase(service_position)
		"construction_company": _construction_company_positions.erase(service_position)
		"forager_tent", "straw_forager_tent", "tarp_forager_tent": _forager_positions.erase(service_position)
		"materials_yard", "straw_materials_yard", "tarp_materials_yard": _materials_yard_positions.erase(service_position)
		"school": _school_positions.erase(service_position)
		"park": _park_positions.erase(service_position)
		"gathering_place": _gathering_place_positions.erase(service_position)
		"leisure_center": _leisure_positions.erase(service_position)
		"craft_tent", "straw_craft_tent", "tarp_craft_tent": _craft_tent_positions.erase(service_position)
		"straw_trade_tent", "tarp_trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market":
			_market_positions.erase(service_position)
		"campfire", "campfire_lvl2", "campfire_lvl3", "earth_assembly", "clay_lodge", "wood_town_hall", "stone_prefecture", "brick_city_hall":
			if _campfire_node_getter.call() == building: _campfire_node_setter.call(null)
		"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant":
			if _canteen_getter.call() == building: _canteen_setter.call(null)
		"dew_collector", "advanced_dew_collector":
			for i in range(_water_collectors.size() - 1, -1, -1):
				if _water_collectors[i].node == building:
					_water_collectors.remove_at(i)
		"employment_office":
			if _employment_office_getter.call() == building: _employment_office_setter.call(null)
		"brick_factory", "materials_factory", "recycling_factory", "metal_factory": _factories.erase(building)


func release_employment_at_building(building: Node3D) -> void:
	for citizen in _citizens:
		if building == _campfire_node_getter.call() and citizen.daily_order_role == "researcher":
			if _settlement.active_research_tech_id != "" and _settlement.active_research_worker_id == citizen.ai_id:
				_cancel_active_building_research.call(true, "Research cancelled: the civic post was removed. Resources refunded.")
			citizen.clear_daily_order()
			citizen.idle()
		if citizen.employment_workplace != building and citizen.pending_employment_workplace != building:
			continue
		if citizen.permanent_role == "official":
			_dismiss_official.call(citizen)
			continue
		_send_to_unemployment_registration.call(citizen)


func move_stored_resources_to_pile(resources: Dictionary, warehouse_index := -1) -> void:
	if warehouse_index >= 0 and warehouse_index < _settlement.warehouses.size():
		for resource_type in SettlementState.STORED_RESOURCES:
			var amount: int = _settlement.warehouses[warehouse_index].amount(resource_type)
			if amount <= 0:
				continue
			resources[resource_type] = int(resources.get(resource_type, 0)) + amount
			_settlement.warehouses[warehouse_index].set_amount(resource_type, 0)
		return
	for resource_type in SettlementState.STORED_RESOURCES:
		var amount: int = _settlement.amount(resource_type)
		if amount <= 0:
			continue
		resources[resource_type] = int(resources.get(resource_type, 0)) + amount
		_settlement.add(resource_type, -amount)


func remove_expired_temporary_tents() -> void:
	for record in _building_registry.records().duplicate():
		var tent: Node3D = record.node as Node3D
		if not is_instance_valid(tent) or _is_construction_site.call(tent) or record.building_type != "tent":
			continue
		for citizen in _citizens:
			if is_instance_valid(citizen) and citizen.home == tent:
				citizen.home = null
				_refresh_living_status.call(citizen)
		_cancel_arrivals_for_house.call(tent)
		_unregister_service_pockets.call(tent)
		remove_building_services(tent, "tent")
		var removed_record = _building_registry.remove_node(tent)
		if removed_record != null:
			_unregister_navigation_footprint.call(removed_record.center, removed_record.footprint)
			_village_territory_service.on_building_removed(removed_record.cell)
		_settlement.buildings["tent"] = maxi(0, int(_settlement.buildings.get("tent", 1)) - 1)
		tent.queue_free()
	_refresh_navigation_grid.call()
	_update_workers.call()


func update_house_lights() -> void:
	var game_minutes: float = _game_minutes_getter.call()
	var hour: int = int(game_minutes) / 60
	var minute: int = int(game_minutes) % 60
	var clock_minute: int = int(game_minutes)
	if _house_light_update_minute_getter.call() == clock_minute:
		return
	_house_light_update_minute_setter.call(clock_minute)
	var minute_of_day: int = hour * 60 + minute
	for record in _house_lights:
		if not is_instance_valid(record.light):
			continue
		var light: OmniLight3D = record.light
		var house: Node3D = record.house
		var off_minute: int = int(house.get_meta("light_off_minute", record.off_minute))
		var occupied: bool = house_has_residents(house)
		light.visible = occupied and house_has_people_at_home(house) and (minute_of_day >= 17 * 60 and minute_of_day < off_minute if off_minute >= 17 * 60 else minute_of_day >= 17 * 60 or minute_of_day < off_minute)
	for light in _entrance_lights:
		if is_instance_valid(light):
			light.visible = minute_of_day >= 17 * 60 or minute_of_day < 7 * 60


func house_has_residents(house: Node3D) -> bool:
	if not is_instance_valid(house):
		return false
	for citizen in _citizens:
		if citizen.home == house:
			return true
	return false


func house_has_people_at_home(house: Node3D) -> bool:
	for citizen in _citizens:
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
	for record in _building_registry.records():
		var candidate: Node3D = record.node
		if not is_instance_valid(candidate):
			continue
		var rank: int = int(ranks.get(record.building_type, -1))
		if rank > best_rank:
			best_campfire = candidate
			best_rank = rank
	_campfire_node_setter.call(best_campfire)
	if is_instance_valid(best_campfire):
		_activate_employment_centre.call(best_campfire)


func register_completed_building_type_features(building_type: String, building: Node3D, blueprint: Dictionary, service_position: Vector3) -> void:
	match building_type:
		"warehouse", "straw_warehouse", "tarp_warehouse":
			_settlement.add_warehouse(building_type)
			_warehouse_positions.append(service_position)
			if _warehouse_positions.size() == 1:
				_convert_backpack_pile_to_regular.call()
				_settlement.warehouse_ever_built = true
				_settlement.backpack.clear()
			_add_building_selector.call(building, "warehouse_selector", blueprint.footprint)
			_add_warehouse_fill_label.call(building)
		"sawmill":
			_sawmill_positions.append(service_position)
			_sawmill_stock.call(service_position)
		"farm":
			_farm_positions.append(service_position)
		"builders_guild":
			_builders_guild_positions.append(service_position)
		"construction_company":
			_construction_company_positions.append(service_position)
		"campfire", "campfire_lvl2", "campfire_lvl3", "earth_assembly", "clay_lodge", "wood_town_hall", "stone_prefecture", "brick_city_hall":
			_campfire_node_setter.call(building)
			_activate_employment_centre.call(building)
			_add_building_selector.call(building, "campfire_selector", blueprint.footprint)
			var fire_light: Node3D = _fire_light_scene.instantiate()
			building.add_child(fire_light)
		"gathering_place":
			_gathering_place_positions.append(service_position)
			_create_gathering_place_visual.call(building)
			_add_building_selector.call(building, "building_selector", blueprint.footprint)
		"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant":
			_activate_kitchen_if_better.call(building, service_position)
			_add_building_selector.call(building, "cook_campfire_selector", blueprint.footprint)
			var cook_fire_light: Node3D = _fire_light_scene.instantiate()
			building.add_child(cook_fire_light)
		"forager_tent", "straw_forager_tent", "tarp_forager_tent":
			_forager_positions.append(service_position)
			_update_interface.call("Forager tent ready. Assign a resident to forage food, or a free hand will.")
		"materials_yard", "straw_materials_yard", "tarp_materials_yard":
			_materials_yard_positions.append(service_position)
			_update_interface.call(S.MATERIALS_YARD_READY)
		"tent", "straw_tent", "tarp_tent", "dugout", "earth_house", "clay_house", "stone_house", "house", "house_lvl2", "house_lvl3", "brick_house":
			if building_type in ["house", "house_lvl2", "house_lvl3", "brick_house"]:
				_completed_house_count_setter.call(_completed_house_count_getter.call() + 1)
			# Housing capacity is authored on each `core:housing` zone's `residents`
			# property, so the per-type table is gone. The constant remains only as a
			# fallback for buildings without authored zones.
			var state := BuildingRuntimeStateScript.from_node(building)
			var housing_capacity: int = state.compute_housing_capacity()
			if housing_capacity <= 0:
				housing_capacity = _house_capacity
			state.housing_capacity = housing_capacity
			state.apply_to_node(building)
			building.set_meta("spawn_slots", housing_capacity)
			_add_building_selector.call(building, "house_selector", blueprint.footprint)
			_add_house_light.call(building)
			if building_type in ["tent", "straw_tent", "tarp_tent"]:
				building.set_meta("is_tent", true)
			_house_initial_residents.call(building)
		"dew_collector", "advanced_dew_collector":
			var rate := 0.12
			var capacity := 10
			if building_type == "advanced_dew_collector":
				rate = 0.3
				capacity = 25
			_water_collectors.append(WaterCollectorRecordScript.new(building, rate, 0.0, 0, capacity))
		"craft_tent", "straw_craft_tent", "tarp_craft_tent":
			_craft_tent_positions.append(service_position)
		"straw_trade_tent", "tarp_trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market":
			_add_building_selector.call(building, "market_selector", blueprint.footprint)
			_market_positions.append(service_position)
		"employment_office":
			_employment_office_setter.call(building)
			_employment_office_position_setter.call(service_position)
		"school":
			_school_positions.append(service_position)
			_add_building_selector.call(building, "school_selector", blueprint.footprint)
		"park":
			_park_positions.append(service_position)
		"leisure_center":
			_leisure_positions.append(service_position)
			_add_building_selector.call(building, "building_selector", blueprint.footprint)
		"brick_factory", "materials_factory", "recycling_factory", "metal_factory":
			building.set_meta("required_factory_workers", 3 if building_type in ["recycling_factory", "metal_factory"] else 1)
			_factories.append(building)
			if building_type == "materials_factory":
				_add_building_selector.call(building, "materials_factory_selector", blueprint.footprint)
		"boundary_post":
			_add_building_selector.call(building, "building_selector", blueprint.footprint)
