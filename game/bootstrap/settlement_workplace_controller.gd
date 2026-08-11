class_name SettlementWorkplaceController
extends RefCounted

## Manages workplace operations: role queries, worker assignments, building
## upgrades, campfire orders, era advancement, night-work/overtime toggles.
## Extracted from SettlementGame to reduce its method count.

const S = preload("res://game/features/ui/domain/game_strings.gd")

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func era_name() -> String:
	return ["Tent", "Earth", "Clay", "Wood", "Stone", "Brick"][game.settlement.era]


func employer_types_for_role(role: String) -> Array[String]:
	match role:
		"construction": return ["builders_guild", "construction_company"]
		"forestry": return ["sawmill"]
		"farming": return ["farm"]
		"gather_food": return ["straw_forager_tent", "tarp_forager_tent"]
		"gather_branches", "gather_grass": return ["straw_materials_yard", "tarp_materials_yard"]
		"cook": return BuildingTypes.KITCHEN_TYPES
		"teacher": return ["school"]
		"seller": return BuildingTypes.MARKET_TYPES
		"factory_worker": return BuildingTypes.FACTORY_TYPES
		"engineer": return ["materials_factory"]
		"craftsman": return ["straw_craft_tent", "tarp_craft_tent"]
		"official": return game.OFFICIAL_WORKPLACE_TYPES
	return []


func is_staffed_workplace(building: Node3D) -> bool:
	if not is_instance_valid(building):
		return false
	var building_type := game.building_registry.building_type_for_node(building)
	for role in ["construction", "forestry", "farming", "gather_food", "gather_branches", "gather_grass", "cook", "teacher", "seller", "factory_worker", "engineer", "craftsman", "official"]:
		if building_type in employer_types_for_role(role) or (game.building_zone_service != null and game.building_zone_service.supports_role(building, StringName(role))):
			return true
	return false


func building_supports_role(building: Node3D, role: String) -> bool:
	if not is_instance_valid(building):
		return false
	var building_type := game.building_registry.building_type_for_node(building)
	return building_type in employer_types_for_role(role) or (game.building_zone_service != null and game.building_zone_service.supports_role(building, StringName(role)))


func employer_capacity(role: String, building: Node3D) -> int:
	if game.building_zone_service != null:
		var zone_capacity: int = int(game.building_zone_service.role_capacity(building, StringName(role)))
		if zone_capacity > 0:
			return zone_capacity
	if role == "construction":
		return 3 if game.building_registry.building_type_for_node(building) == "construction_company" else 1
	if role == "factory_worker":
		return int(building.get_meta("required_factory_workers", 1))
	if role == "craftsman":
		var type := game.building_registry.building_type_for_node(building)
		return 2 if type == "tarp_craft_tent" else 1
	if role == "gather_food":
		var type := game.building_registry.building_type_for_node(building)
		return 4 if type == "tarp_forager_tent" else 2
	if role in ["gather_branches", "gather_grass"]:
		var type := game.building_registry.building_type_for_node(building)
		return 4 if type == "tarp_materials_yard" else 2
	return 1


func assign_work_role(role: String, daily_order := false) -> void:
	if game.selected_builder == null:
		return
	# A work assignment is an explicit hand-off to the settlement AI. Without
	# this, a citizen previously moved in first-person mode keeps the direct
	# control flag and is excluded from every work and courier order.
	game.selected_builder.set_player_controlled(false)
	game.selected_builder.idle()
	if daily_order:
		if role.is_empty():
			game.selected_builder.clear_daily_order()
		else:
			if game.citizen_daily_order_service != null:
				game.citizen_daily_order_service.assign_daily_order(game.selected_builder, role)
		if game.selected_builder.employment_state == Citizen.EmploymentState.UNREGISTERED and game.employment_center_position() != Vector3.INF:
			game.selected_builder.request_no_permanent_work_registration()
	elif role == "excavation":
		game.excavation_service.start_dig_assignment()
		game.build_menu_is_job_menu = false
		game.build_menu_is_daily_order_menu = false
		return
	elif role == "official":
		if not game.research_controller.appoint_official(game.selected_builder, game.employment_centre_building(), false):
			return
	else:
		if role != "official" and not game.workplace_labor_service.player_can_manage_permanent_professions():
			if game.workplace_labor_service != null:
				game.workplace_labor_service.show_labor_command_blocked()
			return
		if game.selected_builder.has_no_permanent_work() or game.selected_builder.is_unregistered():
			if game.employment_center_position() == Vector3.INF:
				game.update_interface("Build the main campfire before assigning permanent jobs.")
				return
			game.selected_builder.clear_daily_order()
			game.selected_builder.begin_employment_processing(game.employment_center_position(), role, employer_for_role(role))
	game.selected_builder.assigned_dig_site = null
	if game.citizen_ai != null:
		game.citizen_ai.request_decision_refresh()
	game.update_workers()
	game.build_menu_is_job_menu = false
	game.build_menu_is_daily_order_menu = false
	game.selection_controller.show_selected_citizen_menu()
	if game.building_menu_controller != null:
		game.building_menu_controller.refresh_build_menu()
	game.update_interface("%s assigned to %s." % ["Hero" if game.selected_builder.is_hero else "Citizen", "automatic work" if role.is_empty() else role.replace("_", " ")])
	if game.workforce_menu_controller != null:
		game.workforce_menu_controller.refresh_campfire_occupancy_button()
	if game.ui_manager.workforce_menu != null and game.ui_manager.workforce_menu.visible:
		if game.workforce_menu_controller != null:
			game.workforce_menu_controller.refresh_workforce_menu()


func available_employer_capacity(role: String) -> int:
	if role == "official":
		var centre: Node3D = game.workplace_labor_service.employment_centre_building() if game.workplace_labor_service != null else null
		return 1 if is_instance_valid(centre) and bool(centre.get_meta("accepting_workers", true)) else 0
	var capacity := 0
	for record in game.building_registry.records():
		var building := record.node
		if not is_instance_valid(building) or not building_supports_role(building, role):
			continue
		if bool(building.get_meta("accepting_workers", true)):
			capacity += employer_capacity(role, building)
	return capacity


func builder_job_capacity() -> int:
	return available_employer_capacity("construction")


func employer_for_role(role: String) -> Node3D:
	if role == "official":
		return game.workplace_labor_service.employment_centre_building() if game.workplace_labor_service != null else null
	if role == "excavation":
		for site in game.dig_sites:
			if game.excavation_service.can_work_at_dig_site(site):
				return site.node
		return null
	if role not in ["construction", "forestry", "farming", "gather_food", "gather_branches", "gather_grass", "cook", "teacher", "seller", "factory_worker", "engineer", "craftsman", "official"]:
		return null
	var best: Node3D
	var best_load := 100000
	var best_priority := -1
	for record in game.building_registry.records():
		var building := record.node
		if not is_instance_valid(building) or not building_supports_role(building, role):
			continue
		if not bool(building.get_meta("accepting_workers", true)):
			continue
		var capacity: int = employer_capacity(role, building)
		var load := 0
		for citizen in game.citizens:
			if citizen.employment_workplace == building or citizen.pending_employment_workplace == building:
				load += 1
		var priority := int(building.get_meta("workplace_priority", 0))
		if load < capacity and (priority > best_priority or (priority == best_priority and load < best_load)):
			best = building
			best_load = load
			best_priority = priority
	return best


func min_era_for_role(role: String) -> SettlementState.Era:
	# Basic outdoor/hand-work roles exist from the tent era even without a dedicated workplace.
	match role:
		"construction", "excavation", "gather_branches", "gather_food", "courier", "craftsman", "official", "":
			return SettlementState.Era.TENT
	var types: Array = employer_types_for_role(role)
	if types.is_empty():
		return SettlementState.Era.TENT
	var min_era := SettlementState.Era.BRICK
	for type in types:
		var era: SettlementState.Era = BuildingCatalog.era_for(type)
		if era < min_era:
			min_era = era
	return min_era


func role_for_workplace(building: Node3D) -> String:
	var building_type := game.building_registry.building_type_for_node(building)
	for candidate in ["forestry", "farming", "gather_food", "gather_branches", "cook", "teacher", "seller", "factory_worker", "engineer", "official"]:
		if building_type in employer_types_for_role(candidate):
			return candidate
	return ""


func workplace_worker(building: Node3D) -> Citizen:
	if not is_instance_valid(building):
		return null
	for citizen in game.citizens:
		if citizen.employment_workplace == building or citizen.pending_employment_workplace == building:
			return citizen
	return null


func workplace_priority_position(building: Node3D) -> int:
	var role := ""
	for candidate_role in ["construction", "forestry", "farming", "gather_food", "cook", "teacher", "seller", "official", "factory_worker", "engineer"]:
		if building_supports_role(building, candidate_role):
			role = candidate_role
			break
	if role.is_empty():
		return 0
	var position := 1
	var priority := int(building.get_meta("workplace_priority", 0))
	for record in game.building_registry.records():
		var candidate := record.node
		if not is_instance_valid(candidate) or candidate == building or not bool(candidate.get_meta("accepting_workers", true)):
			continue
		if building_supports_role(candidate, role) and int(candidate.get_meta("workplace_priority", 0)) > priority:
			position += 1
	return position


func toggle_campfire_acceptance() -> void:
	if not is_instance_valid(game.selected_campfire):
		return
	game.selected_building = game.selected_campfire
	toggle_selected_workplace_acceptance()


func dismiss_campfire_worker() -> void:
	if not is_instance_valid(game.selected_campfire):
		return
	game.selected_building = game.selected_campfire
	dismiss_selected_workplace_worker()


func on_campfire_advance_pressed() -> void:
	if game.selected_campfire == null:
		return
	var housing_slots := game.building_registry.housing_capacity()
	var next_era := SettlementState.Era.TENT
	match game.settlement.era:
		SettlementState.Era.TENT: next_era = SettlementState.Era.EARTH
		SettlementState.Era.EARTH: next_era = SettlementState.Era.CLAY
		SettlementState.Era.CLAY: next_era = SettlementState.Era.WOOD
		SettlementState.Era.WOOD: next_era = SettlementState.Era.STONE
		SettlementState.Era.STONE: next_era = SettlementState.Era.BRICK

	if game.settlement.advance_era(next_era, game.citizens.size(), housing_slots):
		game.village_territory_service.set_era(int(game.settlement.era))
		game.update_interface("Advanced to the %s Era! New buildings unlocked." % era_name())
		if game.campfire_menu_controller != null:
			game.campfire_menu_controller.refresh_campfire_menu()
		if game.building_menu_controller != null:
			game.building_menu_controller.refresh_build_menu()
	else:
		game.update_interface("Failed to advance era. Double-check requirements.")


func refresh_market_menu() -> void:
	if game.market_menu_controller != null:
		game.market_menu_controller.refresh_market_menu()


func available_trade_money() -> int:
	return game.trade_service.available_trade_money()


func demolish_selected_building() -> void:
	if is_instance_valid(game.selected_building):
		game.building_lifecycle_service.mark_building_for_demolition(game.selected_building)


func toggle_selected_workplace_acceptance() -> void:
	if not is_instance_valid(game.selected_building) or not is_staffed_workplace(game.selected_building):
		return
	var accepting := bool(game.selected_building.get_meta("accepting_workers", true))
	if accepting:
		game.selected_building.set_meta("accepting_workers", false)
		game.update_interface("This workplace stopped accepting new workers.")
	else:
		game.workplace_priority_counter += 1
		game.selected_building.set_meta("accepting_workers", true)
		game.selected_building.set_meta("workplace_priority", game.workplace_priority_counter)
		game.update_interface("This workplace is accepting workers at the front of its queue.")
	game.update_workers()
	reopen_workplace_menu()


func dismiss_selected_workplace_worker() -> void:
	var worker := workplace_worker(game.selected_building)
	if worker == null:
		return
	game.selected_building.set_meta("accepting_workers", false)
	if worker.permanent_role == "official":
		game.research_controller.dismiss_official(worker)
	else:
		game.citizen_lifecycle_service.send_to_unemployment_registration(worker)
	game.update_workers()
	reopen_workplace_menu()


func reopen_workplace_menu() -> void:
	# The town hall keeps its own dedicated menu; every other workplace uses the
	# generic building menu.
	if is_instance_valid(game.selected_campfire) and game.selected_building == game.selected_campfire and game.ui_manager.campfire_menu.visible:
		if game.campfire_menu_controller != null:
			game.campfire_menu_controller.refresh_campfire_menu()
	else:
		if game.building_menu_controller != null:
			game.building_menu_controller.show_building_menu()


func upgrade_selected_building() -> void:
	if not is_instance_valid(game.selected_building):
		return
	var source := game.selected_building
	var old_type := game.building_registry.building_type_for_node(source)
	var target_type := game.settlement.next_building_upgrade(old_type)
	if target_type.is_empty():
		return
	if bool(source.get_meta("pending_upgrade", false)):
		game.update_interface("This building is already being upgraded.")
		return
	var old_footprint: Vector2i = source.get_meta("footprint", BuildingBlueprints.get_blueprint(old_type).footprint)
	var blueprint := BuildingBlueprints.get_blueprint(target_type)
	if blueprint.footprint != old_footprint:
		game.update_interface("This upgrade needs rebuilding because its footprint changes.")
		return
	if not game.settlement.can_upgrade_building(old_type):
		game.update_interface("Upgrade needs the required research and era.")
		return
	var record := game.building_registry.record_for_node(source)
	if record == null:
		return
	var rotation_quarters := posmod(roundi(source.rotation_degrees.y / 90.0), 4)
	var site := game.construction_controller.create_construction_site(
		record.cell, target_type, record.center, rotation_quarters, blueprint, record.footprint)
	if site == null:
		return
	site.upgrade_source = source
	site.upgrade_from_type = old_type
	source.set_meta("pending_upgrade", true)
	game.hero_interaction_controller.deliver_pocket_to_site(site, true)
	game.input_controller.close_context_menus()
	game.update_interface("Upgrade marked. The building remains operational while materials and labour are supplied.")


func complete_building_upgrade(site: ConstructionSite) -> void:
	if site == null or not site.is_upgrade():
		return
	var building := site.upgrade_source
	var old_type := site.upgrade_from_type
	var target_type := site.building_type
	var blueprint := site.blueprint
	var old_footprint: Vector2i = building.get_meta("footprint", blueprint.footprint)
	var service_position: Vector3 = building.get_meta("service_position", building.global_position)
	game.service_pocket_manager.unregister_service_pockets(building)
	game.service_pocket_manager.unregister_navigation_footprint(building.global_position, old_footprint)
	for child in building.get_children():
		building.remove_child(child)
		child.queue_free()
	for meta_name in ["status_indicator", "warehouse_fill_label", "entrance_position", "back_entrance_position", "service_position", "service_positions"]:
		if building.has_meta(meta_name):
			building.remove_meta(meta_name)
	for module in blueprint.modules:
		building.add_child(BuildingBlueprints.create_module(module))
	building.set_meta("building_type", target_type)
	building.set_meta("footprint", blueprint.footprint)
	building.set_meta("occupied_footprint", blueprint.footprint)
	building.set_meta("condition", 100.0)
	building.set_meta("pending_upgrade", false)
	if blueprint.has("blueprint_ref"):
		building.set_meta("blueprint_ref", blueprint["blueprint_ref"])
	if blueprint.has("routing_anchors"):
		building.set_meta("routing_anchors", blueprint["routing_anchors"])
	if blueprint.has("routes"):
		building.set_meta("zone_routes", blueprint["routes"])
	if blueprint.has("overlays"):
		building.set_meta("zone_overlays", blueprint["overlays"])
	if game.building_zone_service != null:
		game.building_zone_service.configure_building(building, blueprint.get("zones", []), [])
	var building_instance_id := str(building.get_meta("building_instance_id", "%d,%d" % [site.cell.x, site.cell.y]))
	building.set_meta("building_instance_id", building_instance_id)
	if game.fixture_service != null:
		game.fixture_service.remove_building(building_instance_id)
		var raw_fixtures: Array = blueprint.get("fixtures", [])
		if not raw_fixtures.is_empty():
			var fixture_blueprint := BuildingBlueprint.new()
			fixture_blueprint.id = StringName(target_type)
			for fixture_data in raw_fixtures:
				if fixture_data is Dictionary:
					fixture_blueprint.fixtures.append(FixtureDefinition.from_dict(fixture_data))
			game.fixture_service.initialize_for_building(building_instance_id, fixture_blueprint, int(game.game_minutes))
	game.building_registry.update_building_type(building, target_type)
	if not game.building_placement_controller.update_placement_blueprint(building, target_type):
		push_warning("Upgrade completed without updating its placement blueprint: %s" % target_type)
	game.settlement.buildings[old_type] = maxi(0, int(game.settlement.buildings.get(old_type, 0)) - 1)
	game.settlement.buildings[target_type] = int(game.settlement.buildings.get(target_type, 0)) + 1
	if BuildingTypes.is_warehouse(old_type) and BuildingTypes.is_warehouse(target_type):
		var warehouse_index := game.warehouse_positions.find(service_position)
		if warehouse_index >= 0 and warehouse_index < game.settlement.warehouses.size():
			game.settlement.warehouse_types[warehouse_index] = target_type
			game.settlement.warehouses[warehouse_index].capacity = WarehouseState.capacity_for_building_type(target_type, game.settlement.era)
	var is_home := BuildingTypes.is_housing(target_type)
	game.service_pocket_manager.register_service_entrance(building, blueprint, is_home, target_type not in ["farm", "park"])
	if BuildingTypes.is_civic(target_type):
		game.campfire_node = building
		game.research_controller.activate_employment_centre(building)
		game.building_visuals.add_building_selector(building, "campfire_selector", blueprint.footprint)
		game.building_visuals.add_fire_light(building)
	elif BuildingTypes.is_kitchen(target_type):
		game.building_management.activate_kitchen_if_better(building, building.get_meta("service_position", building.global_position))
		game.building_visuals.add_building_selector(building, "cook_campfire_selector", blueprint.footprint)
		game.building_visuals.add_fire_light(building)
	elif BuildingTypes.needs_generic_selector(target_type):
		game.building_visuals.add_building_selector(building, "building_selector", blueprint.footprint)
	game.building_visuals.add_building_status_indicator(building)
	if BuildingTypes.is_warehouse(target_type):
		game.building_visuals.add_warehouse_fill_label(building)
	game.village_territory_service.recalculate()
	game.world_navigation_controller.refresh_boundary_markers()
	game.world_navigation_controller.refresh_navigation_grid()
	game.update_workers()
	game.update_interface("%s upgraded to %s." % [str(BuildingCatalog.definition_for(old_type).get("name", old_type)), str(BuildingCatalog.definition_for(target_type).get("name", target_type))])
	game.request_courier_dispatch()


func on_construction_site_cancelled(site: ConstructionSite) -> void:
	if site != null and is_instance_valid(site.upgrade_source):
		site.upgrade_source.set_meta("pending_upgrade", false)


func assign_cook_at_campfire() -> void:
	if game.selected_builder == null:
		game.update_interface("Select a resident first, then choose a cooking shift.")
		return
	if game.selected_builder.is_player_controlled:
		game.update_interface("Pick a settler, not the character you are controlling.")
		return
	if game.selected_building != game.canteen:
		game.update_interface("Choose the active kitchen to assign a cook.")
		return
	if not game.workplace_labor_service.player_can_manage_permanent_professions():
		if game.workplace_labor_service != null:
			game.workplace_labor_service.show_labor_command_blocked()
		return
	if not game.research_controller.set_manual_specialist_employment(game.selected_builder, "cook"):
		return
	game.selected_builder.setup_specialization("cook")
	game.update_interface("%s is registering as a cook." % game.selected_builder.role_label())
	game.update_workers()


func assign_teacher_at_school() -> void:
	if not game.workplace_labor_service.player_can_manage_permanent_professions():
		if game.workplace_labor_service != null:
			game.workplace_labor_service.show_labor_command_blocked()
		return
	if game.selected_builder == null:
		game.update_interface("Select a resident first, then click the school to make them the teacher.")
		return
	if game.selected_builder.is_player_controlled:
		game.update_interface("Pick a settler, not the character you are controlling.")
		return
	if not game.research_controller.set_manual_specialist_employment(game.selected_builder, "teacher"):
		return
	game.selected_builder.setup_specialization("teacher")
	game.update_interface("%s is registering as a teacher." % game.selected_builder.role_label())
	game.update_workers()


func assign_seller_at_market() -> void:
	if not game.workplace_labor_service.player_can_manage_permanent_professions():
		if game.workplace_labor_service != null:
			game.workplace_labor_service.show_labor_command_blocked()
		return
	if game.selected_builder == null:
		game.update_interface("Select a resident first, then click the market to make them the seller.")
		return
	if game.selected_builder.is_player_controlled:
		game.update_interface("Pick a settler, not the character you are controlling.")
		return
	if not game.research_controller.set_manual_specialist_employment(game.selected_builder, "seller"):
		return
	game.selected_builder.setup_specialization("seller")
	game.update_interface("%s is registering as a seller." % game.selected_builder.role_label())
	game.update_workers()


func cheer_up_settlement() -> void:
	if game.clock.hour() < 6:
		return
	if game.settlement.apply_cheer_up():
		if game.campfire_menu_controller != null:
			game.campfire_menu_controller.show_campfire_orders_menu()
		game.update_interface("You cheered up the settlement. Wellbeing rose by 5%%.")


func set_road_walking_order(enabled: bool) -> void:
	if game.settlement.era != SettlementState.Era.TENT:
		return
	game.settlement.road_walking_order_enabled = enabled
	game.update_interface(
		"Trail-walking order %s. Residents prefer existing paths automatically and %s shared routes."
		% [
			"enabled" if enabled else "disabled",
			"reinforce" if enabled else "normally wear in",
		]
	)


func has_night_work_candidates() -> bool:
	for citizen in game.citizens:
		if is_instance_valid(citizen) and not citizen.is_player_controlled and not citizen.is_recovering(game.day_cycle.current_day) and (citizen.has_active_daily_order() or citizen.is_employed()):
			return true
	return false


func toggle_settlement_night_work(checked: bool) -> void:
	if checked:
		if game.settlement.night_work_order_day == game.day_cycle.current_day:
			if game.campfire_menu_controller != null:
				game.campfire_menu_controller.show_campfire_orders_menu()
			return
		var affected := 0
		for citizen in game.citizens:
			if not is_instance_valid(citizen) or citizen.is_player_controlled or citizen.is_recovering(game.day_cycle.current_day):
				continue
			if citizen.has_active_daily_order() or citizen.is_employed():
				if game.citizen_daily_order_service.activate_citizen_overtime(citizen, "settlement") if game.citizen_daily_order_service != null else false:
					affected += 1
		if affected <= 0:
			if game.campfire_menu_controller != null:
				game.campfire_menu_controller.show_campfire_orders_menu()
			return
		game.settlement.night_work_order_day = game.day_cycle.current_day
		game.update_interface("Night-work order issued to %d residents. They will work through the night and next day." % affected)
		_post_overtime_change()
	else:
		for citizen in game.citizens:
			if not is_instance_valid(citizen) or citizen.is_player_controlled:
				continue
			if citizen.has_overtime_source("settlement", game.day_cycle.current_day):
				citizen.deactivate_overtime("settlement")
		game.update_interface("Settlement night work cancelled. Workers will return home.")
		_post_overtime_change(true)
	if game.campfire_menu_controller != null:
		game.campfire_menu_controller.show_campfire_orders_menu()


func toggle_double_time_order(checked: bool) -> void:
	if checked:
		if game.settlement.double_time_order_day == game.day_cycle.current_day:
			if game.campfire_menu_controller != null:
				game.campfire_menu_controller.show_campfire_orders_menu()
			return
		game.settlement.double_time_order_day = game.day_cycle.current_day
		game.update_interface("Double time order issued. All residents walk twice as fast today, but fatigue accumulates faster.")
	else:
		game.settlement.double_time_order_day = -1
		game.update_interface("Double time order cancelled. Residents resume normal pace.")
	if game.campfire_menu_controller != null:
		game.campfire_menu_controller.show_campfire_orders_menu()


func toggle_selected_citizen_night_work(checked: bool) -> void:
	if not is_instance_valid(game.selected_builder):
		game.ui_manager.build_menu.personal_night_work_button.set_pressed_no_signal(false)
		return
	if checked:
		if not game.selected_builder.has_daily_order() or game.selected_builder.is_employed() or game.selected_builder.has_overtime_source("personal", game.day_cycle.current_day):
			game.ui_manager.build_menu.personal_night_work_button.set_pressed_no_signal(false)
			return
		# Evening daily orders normally wait for tomorrow. A personal night-work
		# order explicitly starts that new task now and keeps it through tomorrow.
		# Permanent jobs already have an active assignment, including courier jobs
		# that do not belong to a workplace, so they only need the overtime flag.
		if not game.citizen_daily_order_service.activate_citizen_overtime(game.selected_builder, "personal") if game.citizen_daily_order_service != null else false:
			game.ui_manager.build_menu.personal_night_work_button.set_pressed_no_signal(false)
			return
		game.update_interface("%s received a personal night-work order." % game.selected_builder.role_label())
		_post_overtime_change()
	else:
		game.selected_builder.deactivate_overtime("personal")
		game.update_interface("Night work cancelled for %s." % game.selected_builder.role_label())
		_post_overtime_change()
	if game.building_menu_controller != null:
		game.building_menu_controller.refresh_build_menu()


func toggle_worker_overtime(checked: bool) -> void:
	if not is_instance_valid(game.selected_building):
		return
	if checked:
		var night_order_used := int(game.selected_building.get_meta("night_work_order_day", -1)) == game.day_cycle.current_day
		if night_order_used:
			game.ui_manager.building_overtime_button.set_pressed_no_signal(false)
			return
		var workers_found := false
		for citizen in game.citizens:
			if is_instance_valid(citizen) and citizen.is_employed() and citizen.employment_workplace == game.selected_building:
				if game.citizen_daily_order_service.activate_citizen_overtime(citizen, "workplace") if game.citizen_daily_order_service != null else false:
					workers_found = true
		if workers_found:
			game.selected_building.set_meta("night_work_order_day", game.day_cycle.current_day)
			game.add_message("Night-work order issued for %s." % game.building_registry.building_type_for_node(game.selected_building).replace("_", " "))
			game.update_workers()
			_post_overtime_change()
		else:
			game.ui_manager.building_overtime_button.set_pressed_no_signal(false)
	else:
		for citizen in game.citizens:
			if is_instance_valid(citizen) and citizen.employment_workplace == game.selected_building:
				citizen.deactivate_overtime("workplace")
		game.add_message("Night work cancelled for %s." % game.building_registry.building_type_for_node(game.selected_building).replace("_", " "))
		game.update_workers()
		_post_overtime_change(true)


## Common post-change cleanup after any overtime toggle: syncs scope
## indicators (optional), refreshes the skip-night button and requests an
## AI decision refresh so workers react immediately.
func _post_overtime_change(sync_indicators := false) -> void:
	if sync_indicators and game.citizen_daily_order_service != null:
		game.citizen_daily_order_service.sync_overtime_scope_indicators()
	if game.survival_event_controller != null:
		game.survival_event_controller.update_skip_night_button()
	if game.citizen_ai != null:
		game.citizen_ai.request_decision_refresh()


func toggle_campfire_worker_overtime(checked: bool) -> void:
	if not is_instance_valid(game.selected_campfire):
		return
	game.selected_building = game.selected_campfire
	toggle_worker_overtime(checked)
	if game.campfire_menu_controller != null:
		game.campfire_menu_controller.refresh_campfire_menu()
