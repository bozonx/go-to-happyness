class_name SettlementBuildController
extends RefCounted

## Orchestrates build-mode flow: category selection, placement preview,
## building placement, and build menu toggling.
## Extracted from SettlementGame to reduce its method count.
## Low-level placement math lives in BuildingPlacementController (a Node).

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func open_build_category(category: String) -> void:
	game.build_category = category
	game.build_menu_is_job_menu = false
	game.build_menu_is_daily_order_menu = false
	if game.building_menu_controller != null:
		game.building_menu_controller.refresh_build_menu()
	if game.build_category.is_empty() and not game.build_menu_is_global:
		game.selection_controller.show_selected_citizen_menu()


func set_build_placement_ui_visible(is_visible: bool) -> void:
	var ui := game.ui_manager
	if ui.build_menu != null:
		ui.build_menu.visible = is_visible and (game.selected_builder != null or game.build_menu_is_global)
	if ui.build_toggle_btn != null:
		ui.build_toggle_btn.visible = is_visible and not game.is_first_person
	if ui.message_log_panel != null:
		ui.message_log_panel.visible = is_visible


func select_build_mode(next_mode: String) -> void:
	if not game.can_hero_build():
		game.update_interface("Only the hero can approve construction decisions.")
		return
	if next_mode == "tent" and game.clock.hour() >= 22:
		game.update_interface("The temporary tent must be marked before 22:00.")
		return
	var placement_state: Dictionary = game.building_availability_service.placement_state_with_inventory(next_mode, game.pocket)
	if not bool(placement_state.allowed):
		game.update_interface(str(placement_state.message))
		return
	if not game.village_territory_service.has_flag():
		if next_mode != "settlement_flag":
			game.update_interface(game.village_territory_service.placement_message(game.village_territory_service.REASON_NO_FLAG))
			return
	elif not game.village_territory_service.has_campfire():
		if next_mode != "campfire" and next_mode != "warehouse":
			game.update_interface(game.village_territory_service.placement_message(game.village_territory_service.REASON_NO_CAMPFIRE))
			return
	game.build_mode = next_mode
	game.build_rotation_quarters = 0
	game.world_setup.selection_marker.visible = true
	game.build_controller.move_selection(game.selected_world_position)
	set_build_placement_ui_visible(false)
	show_territory_overlay(true)
	if game.is_first_person:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	game.update_interface("%s selected. Choose a clear point; Q/E rotates the building." % game.build_mode.capitalize())


func cancel_build_action() -> void:
	game.build_mode = ""
	game.build_rotation_quarters = 0
	game.dig_mode = false
	game.world_setup.selection_marker.visible = false
	game.world_setup.preview_entrance_marker.visible = false
	game.world_setup.preview_back_entrance_marker.visible = false
	game.ui_manager.build_menu.visible = false
	game.build_menu_is_global = false
	game.selected_builder = null
	show_territory_overlay(false)
	set_build_placement_ui_visible(true)
	game.update_interface("Construction mode cancelled.")


func toggle_global_build_menu() -> void:
	var was_visible := game.ui_manager.build_menu.visible and game.build_menu_is_global
	game.input_controller.close_context_menus()
	game.build_menu_is_global = not was_visible
	game.ui_manager.build_menu.visible = game.build_menu_is_global
	if game.ui_manager.build_menu.visible:
		game.build_category = ""
		game.build_menu_is_job_menu = false
		game.build_menu_is_daily_order_menu = false
		if game.building_menu_controller != null:
			game.building_menu_controller.refresh_build_menu()


func show_territory_overlay(show: bool) -> void:
	if game.world_setup.village_territory_overlay != null:
		if show:
			game.world_setup.village_territory_overlay.refresh(game.village_territory_service.territory())
		game.world_setup.village_territory_overlay.visible = show


func move_selection(world_position: Vector3) -> void:
	var bpc := game.building_placement_controller
	game.selected_world_position = bpc.snapped_build_position(world_position) if bpc != null else world_position
	game.selected_cell = game.placement_key(game.selected_world_position)
	game.world_setup.selection_marker.position = game.selected_world_position + Vector3(0.0, 0.04, 0.0)
	if not game.build_mode.is_empty():
		var local_footprint: Vector2i = BuildingBlueprints.get_blueprint(game.build_mode).footprint
		var footprint := game.rotated_footprint(local_footprint)
		(game.world_setup.selection_marker.mesh as BoxMesh).size = Vector3(footprint.x, 0.04, footprint.y)
		var forward := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, game.build_rotation_quarters * PI * 0.5)
		game.world_setup.preview_entrance_marker.position = game.selected_world_position + forward * (local_footprint.y * 0.5 + 0.35) + Vector3.UP * 0.08
		game.world_setup.preview_back_entrance_marker.position = game.selected_world_position - forward * (local_footprint.y * 0.5 + 0.35) + Vector3.UP * 0.08
		game.world_setup.preview_entrance_marker.visible = true
		game.world_setup.preview_back_entrance_marker.visible = true
	if not game.build_mode.is_empty():
		var can_place := bpc.can_place(game.selected_world_position) if bpc != null else false
		game.world_setup.selection_material.albedo_color = Color(0.25, 0.85, 0.37, 0.55) if can_place else Color(0.9, 0.2, 0.18, 0.6)
	if not game.build_mode.is_empty() and BuildingCatalog.max_hero_radius(game.build_mode) > 0.0 and is_instance_valid(game.hero_citizen):
		if not game.is_first_person and is_instance_valid(game.world_setup.hero_build_radius_marker):
			game.world_setup.hero_build_radius_marker.global_position = game.hero_citizen.global_position + Vector3(0.0, 0.08, 0.0)
			game.world_setup.hero_build_radius_marker.visible = true
		elif is_instance_valid(game.world_setup.hero_build_radius_marker):
			game.world_setup.hero_build_radius_marker.visible = false
	elif is_instance_valid(game.world_setup.hero_build_radius_marker):
		game.world_setup.hero_build_radius_marker.visible = false


func place_building(world_position: Vector3) -> void:
	if not game.can_hero_build():
		game.update_interface("Only the hero can approve construction decisions.")
		return
	var bpc := game.building_placement_controller
	world_position = bpc.snapped_build_position(world_position) if bpc != null else world_position
	var max_hero_radius := BuildingCatalog.max_hero_radius(game.build_mode)
	if max_hero_radius > 0.0 and is_instance_valid(game.hero_citizen):
		if game.hero_citizen.global_position.distance_to(world_position) > max_hero_radius:
			game.update_interface("Too far from Hero (max %.0f tiles)." % max_hero_radius)
			return
	if game.build_mode in ["straw_trade_tent", "tarp_trade_tent"] and is_instance_valid(game.entrance_stone) and world_position.distance_to(game.entrance_stone.global_position) > 8.0:
		game.update_interface("The tent market must be built beside the entrance sign.")
		return
	var cell := game.placement_key(world_position)
	var blueprint := BuildingBlueprints.get_blueprint(game.build_mode)
	var occupied_footprint := game.rotated_footprint(blueprint.footprint)
	var territory_reason: StringName = game.village_territory_service.placement_reason(game.build_mode, cell, occupied_footprint)
	if territory_reason != game.village_territory_service.REASON_OK:
		game.update_interface(game.village_territory_service.placement_message(territory_reason))
		return
	if not (bpc.can_place(world_position) if bpc != null else false):
		game.update_interface("Construction is not allowed at this point.")
		return
	if not (bpc.can_pay_building_cost(game.build_mode) if bpc != null else false):
		var placement_state: Dictionary = game.building_availability_service.placement_state_with_inventory(game.build_mode, game.pocket)
		game.update_interface(str(placement_state.message))
		return

	if BuildingCatalog.is_instant_build(game.build_mode):
		_place_instant_building(cell, world_position, blueprint, occupied_footprint)
		return

	game.building_registry.reserve(cell, world_position, occupied_footprint)
	game.world_navigation_controller.refresh_navigation_grid()
	var site: ConstructionSite = game.construction_controller.create_construction_site(cell, game.build_mode, world_position, game.build_rotation_quarters, blueprint, occupied_footprint)
	game.hero_interaction_controller.deliver_pocket_to_site(site, true)
	game.building_registry.attach_node(cell, site.node, game.build_mode)
	_reset_build_mode_visuals()
	set_build_placement_ui_visible(true)
	game.update_interface("Construction marked. Couriers must deliver the required materials before builders can start.")


func place_building_at_crosshair() -> void:
	var viewport_center := game.get_viewport().get_visible_rect().size * 0.5
	var terrain_point: Variant = game.terrain_point_at_screen_position(viewport_center)
	if terrain_point == null:
		game.update_interface("Aim at clear terrain to place the building.")
		return
	place_building(terrain_point)


func _place_instant_building(cell: Vector2i, world_position: Vector3, blueprint: Dictionary, occupied_footprint: Vector2i) -> void:
	game.building_registry.reserve(cell, world_position, occupied_footprint)
	var site_node: Node3D = game.construction._get_site_scene().instantiate()
	site_node.position = world_position
	site_node.rotation.y = game.build_rotation_quarters * PI * 0.5
	site_node.set_meta("building_type", game.build_mode)
	site_node.set_meta("footprint", blueprint.footprint)
	site_node.set_meta("occupied_footprint", occupied_footprint)
	site_node.set_meta("service_positions", BuildingEntrancePositions.positions(site_node, blueprint.footprint, 1.0))
	game.add_child(site_node)
	for module in blueprint.modules:
		site_node.add_child(BuildingBlueprints.create_module(module))
	for child_name in ["ConstructionTerritory", "ConstructionProgressBack", "ConstructionProgressFill", "SupplyLabel", "ConstructionSelector", "ConstructionEntrance"]:
		var child := site_node.get_node_or_null(child_name)
		if child != null:
			child.queue_free()
	game.construction_controller.complete_building(cell, game.build_mode, world_position, site_node, blueprint)
	if BuildingCatalog.is_flag(game.build_mode):
		game.citizen_factory.bind_hero_squad_to_settlement(&"main_settlement")
	_reset_build_mode_visuals()
	set_build_placement_ui_visible(true)
	game.update_interface("%s placed!" % str(BuildingCatalog.definition_for(game.build_mode).get("name", "Building")))


func _reset_build_mode_visuals() -> void:
	game.build_mode = ""
	game.build_rotation_quarters = 0
	game.world_setup.selection_marker.visible = false
	game.world_setup.preview_entrance_marker.visible = false
	game.world_setup.preview_back_entrance_marker.visible = false
	if is_instance_valid(game.world_setup.hero_build_radius_marker):
		game.world_setup.hero_build_radius_marker.visible = false
	show_territory_overlay(false)
	game.ui_manager.build_menu.visible = false
	game.build_menu_is_global = false
	game.selected_builder = null
