class_name SettlementConstructionController
extends RefCounted

## Manages construction lifecycle: site creation, ticking, supply labels,
## building completion, and cancellation.
## Extracted from SettlementGame to reduce its method count.

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func create_construction_site(cell: Vector2i, building_type: String, position_on_board: Vector3, rotation_quarters := 0, blueprint: Dictionary = {}, occupied_footprint := Vector2i.ZERO) -> ConstructionSite:
	var site := game.construction.start_site(cell, building_type, position_on_board, rotation_quarters, blueprint, occupied_footprint)
	game._register_service_pockets(site.node)
	# The reservation refresh runs before the site exists. Publish its entrance
	# pockets immediately so couriers and builders can route to the new site.
	game._refresh_navigation_grid()
	game._request_courier_dispatch()
	return site


func update_construction(delta: float) -> void:
	# Reconcile reservations outside work time as well, so interrupted night
	# deliveries do not strand reserved materials forever.
	for site: ConstructionSite in game.construction_sites:
		if is_instance_valid(site.node):
			reconcile_construction_reservations(site)
	game.construction.tick(delta)


func set_construction_status(text: String) -> void:
	if game.ui_manager.hud != null:
		game.ui_manager.hud.set_status(text)


func update_construction_supply_label(site: ConstructionSite) -> void:
	if not is_instance_valid(site.node) or site.node.is_queued_for_deletion():
		return
	var label := site.node.get_node_or_null("SupplyLabel") as Label3D
	if label == null:
		return
	var delivered := 0
	var required := 0
	for resource_type in site.required_materials:
		delivered += int(site.delivered_materials.get(resource_type, 0))
		required += int(site.required_materials[resource_type])
	label.text = "MATERIALS %d/%d" % [delivered, required]
	label.modulate = Color("f0c45d") if delivered < required else Color("56bd58")


func complete_building(cell: Vector2i, building_type: String, position_on_board: Vector3, building: Node3D, blueprint: Dictionary) -> void:
	game.settlement.buildings[building_type] = int(game.settlement.buildings.get(building_type, 0)) + 1
	building.set_meta("building_type", building_type)
	building.set_meta("condition", 100.0)
	if blueprint.has("blueprint_ref"):
		building.set_meta("blueprint_ref", blueprint["blueprint_ref"])
	if game.building_zone_service != null:
		game.building_zone_service.configure_building(building, blueprint.get("work_zones", []), blueprint.get("saved_zone_state", []))
	if blueprint.has("routing_anchors"):
		building.set_meta("routing_anchors", blueprint["routing_anchors"])
	game._unregister_service_pockets(building)
	if BuildingTypes.is_fire_source(building_type):
		building.set_meta("fire_fuel", 4)
		building.set_meta("fire_lit", true)
		building.set_meta("fire_embers_until", -1)
		building.set_meta("fire_phase", "burning")
	if game._is_staffed_workplace(building):
		game.workplace_priority_counter += 1
		building.set_meta("accepting_workers", true)
		building.set_meta("workplace_priority", game.workplace_priority_counter)
	if building_type not in ["warehouse", "straw_warehouse", "tarp_warehouse", "campfire", "campfire_lvl2", "campfire_lvl3", "earth_assembly", "clay_lodge", "wood_town_hall", "stone_prefecture", "brick_city_hall", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant", "straw_trade_tent", "tarp_trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market", "school", "materials_factory", "tent", "straw_tent", "tarp_tent", "dugout", "earth_house", "clay_house", "stone_house", "house", "house_lvl2", "house_lvl3", "brick_house", "straw_craft_tent", "tarp_craft_tent", "straw_forager_tent", "tarp_forager_tent", "boundary_post", "entrance_sign"]:
		game._add_building_selector(building, "building_selector", blueprint.footprint)
	if building_type == "entrance_sign":
		game._setup_entrance_sign_node(building)
	var is_home := BuildingTypes.is_housing(building_type)
	game._register_service_entrance(building, blueprint, is_home, building_type not in ["farm", "park"])
	var service_position: Vector3 = building.get_meta("service_position")
	game.building_lifecycle_service.register_completed_building_type_features(building_type, building, blueprint, service_position)

	game.building_registry.attach_node(cell, building, building_type)
	var occupied_footprint: Vector2i = building.get_meta("occupied_footprint", blueprint.footprint)
	game.village_territory_service.on_building_added(cell, building_type)
	game._refresh_boundary_markers()
	game._add_building_status_indicator(building)
	game._refresh_navigation_grid()
	game._update_workers()
	if game.building_menu_controller != null:
		game.building_menu_controller.refresh_build_menu()
	var completion_message := "%s construction completed." % building_type.capitalize()
	if building_type in ["recycling_factory", "metal_factory"]:
		completion_message += " It requires 3 factory workers."
	game._update_interface(completion_message)
	game._request_courier_dispatch()


func is_construction_site(node: Node3D) -> bool:
	return is_instance_valid(node) and game.construction.has_site(node)


func cancel_selected_construction() -> void:
	if not is_instance_valid(game.selected_building) or not is_construction_site(game.selected_building):
		return
	game._unregister_service_pockets(game.selected_building)
	game.construction.cancel_site(game.selected_building)
	game._close_context_menus()
	game._update_interface("Construction cancelled. Refunded 50% of costs.")


func reconcile_construction_reservations(site: ConstructionSite) -> void:
	if game.courier_task_service != null:
		game.courier_task_service.reconcile_construction_reservations(site)


func preferred_construction_site() -> ConstructionSite:
	return game.construction_priority_service.preferred_construction_site() if game.construction_priority_service != null else null


func construction_development_priority(site: ConstructionSite) -> float:
	return game.construction_priority_service.development_priority(site) if game.construction_priority_service != null and site != null else 0.0


func builder_count(site_node: Node3D) -> int:
	var count := 0
	for citizen in game.citizens:
		if citizen.is_building_site(site_node):
			count += 1
	return count


func building_power(site_node: Node3D) -> float:
	var power := 0.0
	for citizen in game.citizens:
		if citizen.is_building_site(site_node):
			power += citizen.get_efficiency("construction")
	if is_instance_valid(game.player_work_target) and game.player_work_target == site_node and game.player_citizen != null:
		power += game.player_citizen.get_efficiency("construction")
	return power
