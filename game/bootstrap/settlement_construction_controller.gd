class_name SettlementConstructionController
extends RefCounted


## Manages construction lifecycle: site creation, ticking, supply labels,
## building completion, and cancellation.
## Extracted from SettlementGame to reduce its method count.

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func create_construction_site(cell: Vector2i, building_type: String, position_on_board: Vector3, rotation_quarters := 0, blueprint: Dictionary = {}, occupied_footprint := Vector2i.ZERO, restored_site_id := 0, required_materials_override: Dictionary = {}) -> ConstructionSite:
	var site := game.construction.start_site(cell, building_type, position_on_board, rotation_quarters, blueprint, occupied_footprint, restored_site_id, required_materials_override)
	game.service_pocket_manager.register_service_pockets(site.node)
	# The reservation refresh runs before the site exists. Publish its entrance
	# pockets immediately so couriers and builders can route to the new site.
	game.world_navigation_controller.refresh_navigation_grid()
	game.request_courier_dispatch()
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
	var paid := 0
	var payment_required := 0
	for payment_type in site.required_payments:
		paid += int(site.paid_payments.get(payment_type, 0))
		payment_required += int(site.required_payments[payment_type])
	label.text = "MATERIALS %d/%d" % [delivered, required]
	if payment_required > 0:
		label.text += "  FUNDS %d/%d" % [paid, payment_required]
	label.modulate = Color("f0c45d") if delivered < required or paid < payment_required else Color("56bd58")


func complete_building(cell: Vector2i, building_type: String, position_on_board: Vector3, building: Node3D, blueprint: Dictionary) -> void:
	game.settlement.buildings[building_type] = int(game.settlement.buildings.get(building_type, 0)) + 1
	building.set_meta("building_type", building_type)
	building.set_meta("condition", 100.0)
	if blueprint.has("blueprint_ref"):
		building.set_meta("blueprint_ref", blueprint["blueprint_ref"])
	if game.building_zone_service != null:
		game.building_zone_service.configure_building(building, blueprint.get("zones", []), blueprint.get("saved_zone_state", []))
	if blueprint.has("routing_anchors"):
		building.set_meta("routing_anchors", blueprint["routing_anchors"])
	if blueprint.has("routes"):
		building.set_meta("zone_routes", blueprint["routes"])
	if blueprint.has("overlays"):
		building.set_meta("zone_overlays", blueprint["overlays"])
	game.service_pocket_manager.unregister_service_pockets(building)
	# Initialize fixtures from the blueprint. The building_instance_id is the
	# cell key, stored on the node so FireManagementService can look it up.
	var building_instance_id := "%d,%d" % [cell.x, cell.y]
	building.set_meta("building_instance_id", building_instance_id)
	var raw_fixtures: Array = blueprint.get("fixtures", [])
	if not raw_fixtures.is_empty() and game.fixture_service != null:
		var bp_for_fixtures := BuildingBlueprint.new()
		bp_for_fixtures.id = StringName(building_type)
		for fd_data in raw_fixtures:
			if fd_data is Dictionary:
				bp_for_fixtures.fixtures.append(FixtureDefinition.from_dict(fd_data))
		var current_minute := int(game.game_minutes) if "game_minutes" in game else 0
		game.fixture_service.initialize_for_building(building_instance_id, bp_for_fixtures, current_minute)
		# For fire_source fixtures, sync initial fire state to node meta so the
		# existing visual system continues to work without changes.
		var fire_states: Array = game.fixture_service.fixtures_with_capability(building_instance_id, FixtureDefinition.CAP_FIRE_SOURCE)
		if not fire_states.is_empty():
			var first_fire: Variant = fire_states[0]
			building.set_meta("fire_fuel", first_fire.fire_state.fuel)
			building.set_meta("fire_lit", first_fire.fire_state.lit)
			building.set_meta("fire_embers_until", first_fire.fire_state.embers_until_minute)
			building.set_meta("fire_phase", "burning")
	if game.workplace_controller.is_staffed_workplace(building):
		game.workplace_priority_counter += 1
		building.set_meta("accepting_workers", true)
		building.set_meta("workplace_priority", game.workplace_priority_counter)
	if BuildingTypes.needs_generic_selector(building_type):
		game.building_visuals.add_building_selector(building, "building_selector", blueprint.footprint)
	if building_type == "entrance_sign":
		game.building_management.setup_entrance_sign_node(building)
	var is_home := BuildingTypes.is_housing(building_type)
	game.service_pocket_manager.register_service_entrance(building, blueprint, is_home, building_type not in ["farm", "park"])
	var service_position: Vector3 = building.get_meta("service_position")
	game.building_lifecycle_service.register_completed_building_type_features(building_type, building, blueprint, service_position)

	game.building_registry.attach_node(cell, building, building_type)
	var occupied_footprint: Vector2i = building.get_meta("occupied_footprint", blueprint.footprint)
	game.village_territory_service.on_building_added(cell, building_type)
	game.world_navigation_controller.refresh_boundary_markers()
	game.building_visuals.add_building_status_indicator(building)
	game.world_navigation_controller.refresh_navigation_grid()
	game.update_workers()
	if game.building_menu_controller != null:
		game.building_menu_controller.refresh_build_menu()
	var completion_message := "%s construction completed." % building_type.capitalize()
	if building_type in ["recycling_factory", "metal_factory"]:
		completion_message += " It requires 3 factory workers."
	game.update_interface(completion_message)
	game.request_courier_dispatch()


func is_construction_site(node: Node3D) -> bool:
	return is_instance_valid(node) and game.construction.has_site(node)


func cancel_selected_construction() -> void:
	if not is_instance_valid(game.selected_building) or not is_construction_site(game.selected_building):
		return
	game.service_pocket_manager.unregister_service_pockets(game.selected_building)
	game.construction.cancel_site(game.selected_building)
	game.input_controller.close_context_menus()
	game.update_interface("Construction cancelled. Delivered materials refunded 50%; cargo in transit returned in full.")


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
	if is_instance_valid(game.player_work_target) and game.player_work_target == site_node and game.player_citizen != null:
		count += 1
	return mini(count, construction_worker_slots(site_node))


func building_power(site_node: Node3D) -> float:
	var efficiencies: Array[float] = []
	for citizen in game.citizens:
		if citizen.is_building_site(site_node):
			efficiencies.append(citizen.get_efficiency("construction"))
	if is_instance_valid(game.player_work_target) and game.player_work_target == site_node and game.player_citizen != null:
		efficiencies.append(game.player_citizen.get_efficiency("construction"))
	efficiencies.sort()
	efficiencies.reverse()
	var contribution := [1.0, 0.75, 0.55, 0.40, 0.30, 0.25]
	var power := 0.0
	for index in mini(efficiencies.size(), construction_worker_slots(site_node)):
		power += efficiencies[index] * contribution[index]
	return power


func construction_worker_slots(site_node: Node3D) -> int:
	var site := game.construction.site_for_node(site_node)
	if site == null:
		return 1
	var footprint: Vector2i = site.blueprint.get("footprint", Vector2i.ONE)
	return clampi(1 + ceili(float(footprint.x * footprint.y) / 20.0), 1, 6)
