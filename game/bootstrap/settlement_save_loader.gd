class_name SettlementSaveLoader
extends RefCounted

## Handles restoration of saved game state onto a running SettlementGame instance.

var game: SettlementGame


func restore(p_game: SettlementGame, save_data: SaveData) -> bool:
	game = p_game
	if save_data == null:
		return false

	# 1. Despawn current citizens
	for citizen in game.citizens.duplicate():
		if is_instance_valid(citizen):
			game._on_ai_citizen_exiting(citizen.ai_id)
			citizen.queue_free()
	game.citizens.clear()

	# 2. Despawn current buildings and reset building registry
	for record in game.building_registry.records():
		if is_instance_valid(record.node):
			record.node.queue_free()
	game.building_registry = BuildingRegistry.new()
	if game.building_queue_service != null:
		game.building_queue_service.configure(game.building_registry, game.nav_grid)
	if game.village_territory_service != null:
		game.village_territory_service.configure(game.building_registry, int(game.settlement.era))
	if game.construction != null and game.construction.runtime != null:
		game.construction.runtime.building_registry = game.building_registry

	# Despawn current construction sites
	for site in game.construction_sites.duplicate():
		if is_instance_valid(site.node):
			site.node.queue_free()
	game.construction_sites.clear()

	# Despawn current resource piles
	for pile in game.resource_piles.duplicate():
		if pile != null and is_instance_valid(pile.node):
			pile.node.queue_free()
	game.resource_piles.clear()

	# Reset tracking arrays
	game.warehouse_positions.clear()
	game.sawmill_positions.clear()
	game.farm_positions.clear()
	game.builders_guild_positions.clear()
	game.construction_company_positions.clear()
	game.pond_positions.clear()
	game.forager_positions.clear()
	game.materials_yard_positions.clear()
	game.school_positions.clear()
	game.market_positions.clear()
	game.craft_tent_positions.clear()
	game.park_positions.clear()
	game.leisure_positions.clear()
	game.gathering_place_positions.clear()
	game.factories.clear()
	game.water_collectors.clear()
	game.house_lights.clear()
	game.entrance_lights.clear()
	game.service_pockets.clear()
	game.sawmill_stocks.clear()
	game.completed_house_count = 0
	game.canteen_food = 0
	game.settlement.buildings.clear()

	# 3. Restore Settlement State
	var s_dict: Dictionary = save_data.settlement_state
	SettlementGame.SaveGameServiceScript.restore_settlement_state(game.settlement, s_dict)
	SettlementGame.SaveGameServiceScript.restore_work_policy(game.settlement, s_dict.get("work_policy", {}))
	SettlementGame.SaveGameServiceScript.restore_research(game.settlement, s_dict.get("research", {}))

	# 4. Restore Simulation Clock
	SettlementGame.SaveGameServiceScript.restore_clock(game.clock, game.day_cycle, save_data.clock_state)

	# 5. Restore Camera State
	var cam_state := SettlementGame.SaveGameServiceScript.restore_camera(save_data.camera_state)
	if not cam_state.is_empty():
		if cam_state.has("target"):
			game.camera_target = cam_state["target"]
		game.camera_distance = cam_state["distance"]
		game.camera_yaw = cam_state["yaw"]
		game.camera_pitch = cam_state["pitch"]

	# 6. Restore Placed Buildings
	for b_dict in save_data.buildings_state:
		var cell = SettlementGame.SaveDataScript.dict_to_vector2i(b_dict.get("cell", {}))
		var b_type = str(b_dict.get("building_type", ""))
		var pos = SettlementGame.SaveDataScript.dict_to_vector3(b_dict.get("position", {}))
		var rot_y = float(b_dict.get("rotation_y", 0.0))
		var rot_quarters = posmod(roundi(rot_y / 90.0), 4)

		var resolved := _resolve_saved_building_blueprint(b_type, b_dict)
		b_type = resolved.type
		var blueprint: Dictionary = resolved.blueprint
		if not blueprint.is_empty():
			var occupied_footprint = game.building_placement_controller.rotated_footprint(blueprint.footprint, rot_quarters) if game.building_placement_controller != null else blueprint.footprint
			game.building_registry.reserve(cell, pos, occupied_footprint)
			var site_node: Node3D = game.construction._get_site_scene().instantiate()
			site_node.position = pos
			site_node.rotation.y = rot_quarters * PI * 0.5
			site_node.set_meta("building_type", b_type)
			site_node.set_meta("footprint", blueprint.footprint)
			site_node.set_meta("occupied_footprint", occupied_footprint)
			site_node.set_meta("service_positions", SettlementGame.BuildingEntrancePositionsScript.positions(site_node, blueprint.footprint, 1.0))
			game.add_child(site_node)
			for module in blueprint.modules:
				site_node.add_child(BuildingBlueprints.create_module(module))
			for child_name in ["ConstructionTerritory", "ConstructionProgressBack", "ConstructionProgressFill", "SupplyLabel", "ConstructionSelector", "ConstructionEntrance"]:
				var child := site_node.get_node_or_null(child_name)
				if child != null:
					child.queue_free()
			game._complete_building(cell, b_type, pos, site_node, blueprint)
		else:
			push_warning("restore_from_save_data: skipping building with unknown type '" + b_type + "' at cell " + str(cell))

	# 7. Restore Construction Sites
	for c_dict in save_data.construction_sites_state:
		var cell = SettlementGame.SaveDataScript.dict_to_vector2i(c_dict.get("cell", {}))
		var b_type = str(c_dict.get("building_type", ""))
		var pos = SettlementGame.SaveDataScript.dict_to_vector3(c_dict.get("position", {}))
		var rot_y = float(c_dict.get("rotation_y", 0.0))
		var rot_quarters = posmod(roundi(rot_y / 90.0), 4)
		var progress = float(c_dict.get("progress", 0.0))
		var delivered = c_dict.get("delivered_materials", {}).duplicate()

		var resolved := _resolve_saved_building_blueprint(b_type, c_dict)
		b_type = resolved.type
		var blueprint: Dictionary = resolved.blueprint
		if not blueprint.is_empty():
			var occupied_footprint = game.building_placement_controller.rotated_footprint(blueprint.footprint, rot_quarters) if game.building_placement_controller != null else blueprint.footprint
			game.building_registry.reserve(cell, pos, occupied_footprint)
			var site = game._create_construction_site(cell, b_type, pos, rot_quarters, blueprint, occupied_footprint)
			if site != null:
				site.progress = progress
				site.delivered_materials = delivered
				game.building_registry.attach_node(cell, site.node, b_type)
				game._update_construction_supply_label(site)
		else:
			push_warning("restore_from_save_data: skipping construction site with unknown type '" + b_type + "' at cell " + str(cell))

	SettlementGame.SaveGameServiceScript.restore_warehouses(game.settlement, s_dict.get("warehouses", []), s_dict.get("warehouse_types", []), bool(s_dict.get("warehouse_ever_built", false)))

	# 8. Restore Resource Piles
	for p_dict in save_data.resource_piles_state:
		if not (p_dict is Dictionary):
			continue
		var resources: Dictionary = p_dict.get("resources", {})
		if resources.is_empty():
			continue
		var pos = SettlementGame.SaveDataScript.dict_to_vector3(p_dict.get("position", {}))
		var pile_node := game._create_resource_pile(pos, resources, bool(p_dict.get("is_backpack", false)))
		if pile_node != null and bool(p_dict.get("landscape_owned", false)):
			pile_node.set_meta("landscape_owned", true)
			game.add_landscape_object(pile_node)
		if bool(p_dict.get("is_backpack", false)):
			game.backpack_node = pile_node

	# 8b. Restore Forest state (felled trees, branch/wood depletion)
	_restore_forest(save_data.forest_state)
	if game.ambient_spawner != null and save_data.world_state.get("natural_resources", {}) is Dictionary:
		game.ambient_spawner.restore_resource_state(save_data.world_state.get("natural_resources", {}))
	if game.road_network_service != null and save_data.world_state.get("roads", []) is Array:
		game.road_network_service.restore_state(save_data.world_state.get("roads", []))

	# 9. Restore Citizens
	game._next_ai_citizen_id = int(save_data.world_state.get("next_ai_citizen_id", 1))
	game.hero_citizen = null
	for cit_dict in save_data.citizens_state:
		var pos = SettlementGame.SaveDataScript.dict_to_vector3(cit_dict.get("position", {}))
		var is_hero = bool(cit_dict.get("is_hero", false))
		var saved_id = int(cit_dict.get("ai_id", 0))

		var citizen: Citizen = SettlementGame.CitizenActorScene.instantiate()
		citizen.position = pos
		if cit_dict.has("first_name") and "first_name" in citizen:
			citizen.first_name = str(cit_dict.get("first_name", ""))
		if cit_dict.has("last_name") and "last_name" in citizen:
			citizen.last_name = str(cit_dict.get("last_name", ""))
		if cit_dict.has("age") and "age" in citizen:
			citizen.age = int(cit_dict.get("age", 25))

		citizen.random = game.random
		game.add_child(citizen)
		citizen.simulation = game
		citizen.setup_specialization(str(cit_dict.get("specialization", "unassigned")))
		game._wire_citizen(citizen)

		game.citizens.append(citizen)
		citizen.ai_id = saved_id if saved_id > 0 else game._next_ai_citizen_id
		if citizen.ai_id >= game._next_ai_citizen_id:
			game._next_ai_citizen_id = citizen.ai_id + 1

		game.citizen_ai.register_citizen(citizen.ai_id, SettlementGame.SettlementCitizenActuatorScript.new(citizen, game._ai_target_for_key))
		citizen.tree_exiting.connect(game._on_ai_citizen_exiting.bind(citizen.ai_id), CONNECT_ONE_SHOT)

		var needs_dict: Dictionary = cit_dict.get("needs", {})
		citizen.hunger = float(needs_dict.get("hunger", 100.0))
		citizen.fatigue = float(needs_dict.get("fatigue", 0.0))
		# `comfort` was the v1 name; v2 stores the actual needs-domain field.
		citizen.satisfaction = float(needs_dict.get("satisfaction", needs_dict.get("comfort", 72.0)))
		citizen.continuous_work_hours = maxf(0.0, float(needs_dict.get("continuous_work_hours", 0.0)))
		citizen.satisfaction_tick = float(needs_dict.get("satisfaction_tick", 0.0))
		citizen.recovery_until_workday_id = maxi(0, int(needs_dict.get("recovery_until_workday_id", 0)))
		if needs_dict.get("buffs", {}) is Dictionary:
			citizen.buffs = (needs_dict.get("buffs") as Dictionary).duplicate(true)
		if needs_dict.get("debuffs", {}) is Dictionary:
			citizen.debuffs = (needs_dict.get("debuffs") as Dictionary).duplicate(true)
		citizen.active_role = str(cit_dict.get("active_role", ""))
		citizen.employment_state = int(cit_dict.get("employment_state", Citizen.EmploymentState.NO_PERMANENT_WORK))
		citizen.permanent_role = str(cit_dict.get("permanent_role", ""))
		citizen.daily_order_role = str(cit_dict.get("daily_order_role", ""))
		if cit_dict.get("employment_building_cell", {}) is Dictionary:
			var employment_cell := SettlementGame.SaveDataScript.dict_to_vector2i(cit_dict.get("employment_building_cell", {}))
			var employment_record = game.building_registry.record_at_cell(employment_cell)
			if employment_record != null and is_instance_valid(employment_record.node):
				citizen.employment_workplace = employment_record.node
				var saved_zone_id := StringName(str(cit_dict.get("employment_zone_id", "")))
				if saved_zone_id != &"" and game.building_zone_service != null:
					game.building_zone_service.assign_to_zone(
						employment_record.node,
						saved_zone_id,
						StringName(citizen.permanent_role),
						citizen.ai_id
					)

		var pockets: Array = cit_dict.get("pockets", [])
		for p_item in pockets:
			if p_item is Dictionary and p_item.has("resource_id"):
				citizen.pockets_add(str(p_item["resource_id"]), int(p_item.get("amount", 1)))

		if is_hero:
			game.hero_citizen = citizen
			citizen.set_hero(true)
			citizen.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK

	# 10. Re-initialize AI and Interfaces
	game._refresh_living_statuses()
	game._refresh_navigation_grid()
	game._update_workers()
	if game.building_menu_controller != null:
		game.building_menu_controller.refresh_build_menu()

	if game.hero_citizen != null:
		game.player_controller.enter_first_person(game.hero_citizen, "Save loaded.")
	return true


func _resolve_saved_building_blueprint(saved_type: String, data: Dictionary) -> Dictionary:
	var resolved_type := saved_type
	var reference: Dictionary = data.get("blueprint_ref", {})
	if not reference.is_empty():
		var referenced_type := SettlementGame.BuildingBlueprintLibraryScript.resolve_reference(reference)
		if not referenced_type.is_empty():
			resolved_type = referenced_type
			var referenced_blueprint: Variant = SettlementGame.BuildingBlueprintLibraryScript.get_blueprint(referenced_type)
			var saved_revision: String = str(reference.get("revision", ""))
			if referenced_blueprint != null and not saved_revision.is_empty() and referenced_blueprint.content_revision() != saved_revision:
				push_warning("Blueprint '%s:%s' changed since this save; current file geometry will be used." % [
					reference.get("source", "builtin"), reference.get("id", "")])
		else:
			var fallback := str(reference.get("fallback_building_id", "house"))
			if BuildingCatalog.has_definition(fallback):
				resolved_type = fallback
				push_warning("Missing blueprint '%s:%s'; restored as fallback '%s'." % [
					reference.get("source", "builtin"), reference.get("id", ""), fallback])
			else:
				push_warning("Missing blueprint and invalid fallback for '%s:%s'." % [
					reference.get("source", "builtin"), reference.get("id", "")])
				return {"type": saved_type, "blueprint": {}}
	var blueprint: Dictionary = BuildingBlueprints.get_blueprint(resolved_type)
	var saved_zones: Variant = data.get("zone_state", [])
	if saved_zones is Array and not saved_zones.is_empty() and not blueprint.is_empty():
		blueprint = blueprint.duplicate(true)
		blueprint["saved_zone_state"] = saved_zones.duplicate(true)
		blueprint["work_zones"] = saved_zones.duplicate(true)
		blueprint["blueprint_ref"] = reference.duplicate(true)
	return {"type": resolved_type, "blueprint": blueprint}


## Overlays saved per-tree state onto the freshly generated forest. The forest
## layout is deterministic (fixed cells), so trees are matched by cell rather
## than despawned and rebuilt. Older saves omit `forest` and leave it pristine.
func _restore_forest(tree_states: Array) -> void:
	game.world_resource_state.restore_tree_state(tree_states)
	for entry in tree_states:
		if not (entry is Dictionary):
			continue
		var cell := SettlementGame.SaveDataScript.dict_to_vector2i(entry.get("cell", {}))
		var tree: Node3D = game.tree_nodes.get(cell)
		if not is_instance_valid(tree):
			continue
		if bool(entry.get("branch_exhausted", false)):
			game.foraging_service.mark_tree_branch_exhausted(cell)
		var tree_state: Variant = game.world_resource_state.tree_at(cell)
		if tree_state != null:
			tree.set_meta("initial_wood", tree_state.initial_wood)
			tree.set_meta("remaining_wood", tree_state.remaining_wood)
			tree.set_meta("initial_branches", tree_state.initial_branches)
			tree.set_meta("remaining_branches", tree_state.remaining_branches)
			tree.set_meta("hand_branches", tree_state.hand_branches)
			tree.set_meta("branch_exhausted", tree_state.branch_exhausted)
		if tree_state != null and tree_state.felled:
			game._apply_tree_felled_visual(cell, tree)
