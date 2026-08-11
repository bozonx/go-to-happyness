class_name SettlementSaveLoader
extends RefCounted


const CitizenActorScene = preload("res://game/features/citizens/presentation/citizen_actor.tscn")

## Handles restoration of saved game state onto a running SettlementGame instance.

var game: SettlementGame


## Restores one `gth.settlement` save section onto a running session. The host
## envelope, its headers and the section version are the coordinator's business;
## this loader only ever sees the module's own contents.
func restore(p_game: SettlementGame, section: Dictionary) -> bool:
	game = p_game
	if section.is_empty():
		push_warning("SettlementSaveLoader: save has no gth.settlement section")
		return false
	var settlement_state: Dictionary = section.get("settlement", {})
	var clock_state: Dictionary = section.get("clock", {})
	var camera_state: Dictionary = section.get("camera", {})
	var world_state: Dictionary = section.get("world", {})
	var buildings_state: Array = section.get("buildings", [])
	var construction_sites_state: Array = section.get("construction_sites", [])
	var citizens_state: Array = section.get("citizens", [])
	var resource_piles_state: Array = section.get("resource_piles", [])
	var forest_state: Array = section.get("forest", [])

	# 1. Despawn current citizens
	for citizen in game.citizens.duplicate():
		if is_instance_valid(citizen):
			game.citizen_factory.on_ai_citizen_exiting(citizen.ai_id)
			citizen.queue_free()
	game.citizens.clear()

	# 2. Release session-owned placement records before despawning their nodes.
	# Authored map placements remain in the runtime layer; player construction is
	# replayed below from the save through BuildingPlacementService.
	game.building_placement_controller.reset_session_placements()
	# Clear the long-lived registry rather than replacing it: runtime ports retain
	# this instance.
	for record in game.building_registry.records():
		if is_instance_valid(record.node):
			record.node.queue_free()
	game.building_registry.clear()

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
	game.settlement.warehouses.clear()
	game.settlement.warehouse_types.clear()
	game.settlement.backpack.clear()
	game.settlement.warehouse_ever_built = false
	game.settlement.construction_reservations.clear()

	# 3. Restore Settlement State
	var s_dict: Dictionary = settlement_state
	SaveGameService.restore_settlement_state(game.settlement, s_dict)
	SaveGameService.restore_work_policy(game.settlement, s_dict.get("work_policy", {}))
	SaveGameService.restore_research(game.settlement, s_dict.get("research", {}))

	# 4. Restore Simulation Clock
	if game.world_session != null and not clock_state.is_empty():
		game.world_session.environment.restore_legacy_clock(
			float(clock_state.get("minutes", 0.0)),
			maxi(1, int(clock_state.get("current_day", 1))))

	# 5. Restore Camera State
	var cam_state := SaveGameService.restore_camera(camera_state)
	if not cam_state.is_empty():
		if cam_state.has("target"):
			game.camera_target = cam_state["target"]
		game.camera_distance = cam_state["distance"]
		game.camera_yaw = cam_state["yaw"]
		game.camera_pitch = cam_state["pitch"]

	# 6. Restore Placed Buildings
	for b_dict in buildings_state:
		var cell = SaveData.dict_to_vector2i(b_dict.get("cell", {}))
		var b_type = str(b_dict.get("building_type", ""))
		var pos = SaveData.dict_to_vector3(b_dict.get("position", {}))
		var rot_y = float(b_dict.get("rotation_y", 0.0))
		var rot_quarters = posmod(roundi(rot_y / 90.0), 4)

		var resolved := _resolve_saved_building_blueprint(b_type, b_dict)
		b_type = resolved.type
		var blueprint: Dictionary = resolved.blueprint
		if not blueprint.is_empty():
			var restored := game.building_placement_controller.restore_placement(
				b_type, b_dict.get("placement", {}), pos, rot_quarters, MapPlacementRecord.STATE_READY)
			if restored.is_empty():
				push_warning("SettlementSaveLoader: placement refused for building '%s' at %s" % [b_type, cell])
				continue
			var placement_record: MapPlacementRecord = restored.record
			pos = restored.position
			cell = restored.cell
			rot_quarters = restored.orientation
			var occupied_footprint: Vector2i = restored.footprint
			game.building_registry.reserve(cell, pos, occupied_footprint)
			var site_node: Node3D = game.construction._get_site_scene().instantiate()
			site_node.position = pos
			site_node.rotation.y = rot_quarters * PI * 0.5
			site_node.set_meta("building_type", b_type)
			site_node.set_meta("footprint", blueprint.footprint)
			site_node.set_meta("occupied_footprint", occupied_footprint)
			site_node.set_meta("service_positions", BuildingAccessPoints.construction_positions(site_node, blueprint, 1.0))
			game.add_child(site_node)
			for module in blueprint.modules:
				site_node.add_child(BuildingBlueprints.create_module(module))
			game.building_placement_controller.bind_placement(site_node, placement_record)
			for child_name in ["ConstructionTerritory", "ConstructionProgressBack", "ConstructionProgressFill", "SupplyLabel", "ConstructionSelector", "ConstructionEntrance"]:
				var child := site_node.get_node_or_null(child_name)
				if child != null:
					child.queue_free()
			game.construction_controller.complete_building(cell, b_type, pos, site_node, blueprint)
		else:
			push_warning("SettlementSaveLoader: skipping building with unknown type '" + b_type + "' at cell " + str(cell))

	# Completed warehouses now exist, so restore their exact inventories before
	# construction sites rebuild reservations against the saved stock.
	SaveGameService.restore_warehouses(game.settlement, s_dict.get("warehouses", []), s_dict.get("warehouse_types", []), bool(s_dict.get("warehouse_ever_built", false)))

	# 7. Restore Construction Sites
	for c_dict in construction_sites_state:
		var cell = SaveData.dict_to_vector2i(c_dict.get("cell", {}))
		var b_type = str(c_dict.get("building_type", ""))
		var pos = SaveData.dict_to_vector3(c_dict.get("position", {}))
		var rot_y = float(c_dict.get("rotation_y", 0.0))
		var rot_quarters = posmod(roundi(rot_y / 90.0), 4)
		var progress = float(c_dict.get("progress", 0.0))
		var delivered = c_dict.get("delivered_materials", {}).duplicate()
		var saved_site_id := int(c_dict.get("site_id", 0))
		var required_materials: Dictionary = c_dict.get("required_materials", {}).duplicate()
		var required_payments: Dictionary = c_dict.get("required_payments", {}).duplicate()
		var paid_payments: Dictionary = c_dict.get("paid_payments", {}).duplicate()
		var upgrade_from_type := str(c_dict.get("upgrade_from_type", ""))
		var in_transit: Dictionary = c_dict.get("in_transit_materials", {}).duplicate()
		# Active courier assignments are intentionally not saved. Put their cargo
		# back before recreating the site so it can be reserved and dispatched anew.
		for resource_type in in_transit:
			game.settlement.add(str(resource_type), int(in_transit[resource_type]))

		var resolved := _resolve_saved_building_blueprint(b_type, c_dict)
		b_type = resolved.type
		var blueprint: Dictionary = resolved.blueprint
		if not blueprint.is_empty():
			var occupied_footprint: Vector2i
			var placement_record: MapPlacementRecord = null
			if upgrade_from_type.is_empty():
				var restored := game.building_placement_controller.restore_placement(
					b_type, c_dict.get("placement", {}), pos, rot_quarters, &"construction_site")
				if restored.is_empty():
					push_warning("SettlementSaveLoader: placement refused for construction site '%s' at %s" % [b_type, cell])
					continue
				placement_record = restored.record
				pos = restored.position
				cell = restored.cell
				rot_quarters = restored.orientation
				occupied_footprint = restored.footprint
				game.building_registry.reserve(cell, pos, occupied_footprint)
			else:
				occupied_footprint = game.building_placement_controller.rotated_footprint(blueprint.footprint, rot_quarters)
			var site = game.construction_controller.create_construction_site(cell, b_type, pos, rot_quarters, blueprint, occupied_footprint, saved_site_id, required_materials)
			if site != null:
				if placement_record != null:
					game.building_placement_controller.bind_placement(site.node, placement_record)
				site.progress = progress
				site.delivered_materials = delivered
				if c_dict.has("required_payments"):
					site.required_payments = required_payments
				if c_dict.has("paid_payments"):
					site.paid_payments = paid_payments
				site.labor_units = maxf(0.001, float(c_dict.get("labor_units", site.labor_units)))
				var restored_modules := mini(site.blueprint.get("modules", []).size(), floori(site.progress * site.blueprint.get("modules", []).size()))
				for module_index in restored_modules:
					site.node.add_child(BuildingBlueprints.create_module(site.blueprint.modules[module_index]))
				site.modules_built = restored_modules
				if upgrade_from_type.is_empty():
					game.building_registry.attach_node(cell, site.node, b_type)
				else:
					var source_record := game.building_registry.record_at_cell(cell)
					if source_record != null and is_instance_valid(source_record.node) and source_record.building_type == upgrade_from_type:
						site.upgrade_source = source_record.node
						site.upgrade_from_type = upgrade_from_type
						source_record.node.set_meta("pending_upgrade", true)
					else:
						push_warning("SettlementSaveLoader: discarded orphaned upgrade at " + str(cell))
						game.construction.cancel_site(site.node)
				game.construction_controller.update_construction_supply_label(site)
		else:
			push_warning("SettlementSaveLoader: skipping construction site with unknown type '" + b_type + "' at cell " + str(cell))

	# 8. Restore Resource Piles
	for p_dict in resource_piles_state:
		if not (p_dict is Dictionary):
			continue
		var resources: Dictionary = p_dict.get("resources", {})
		if resources.is_empty():
			continue
		var pos = SaveData.dict_to_vector3(p_dict.get("position", {}))
		var pile_node := game.resource_pile_service.create_resource_pile(pos, resources, bool(p_dict.get("is_backpack", false)))
		if pile_node != null and bool(p_dict.get("landscape_owned", false)):
			pile_node.set_meta("landscape_owned", true)
			game.world_navigation_controller.add_landscape_object(pile_node)
		if bool(p_dict.get("is_backpack", false)):
			game.backpack_node = pile_node

	# 8b. Restore Forest state (felled trees, branch/wood depletion)
	_restore_forest(forest_state)
	if game.ambient_spawner != null and world_state.get("natural_resources", {}) is Dictionary:
		game.ambient_spawner.restore_resource_state(world_state.get("natural_resources", {}))
	if game.road_network_service != null and world_state.get("roads", []) is Array:
		game.road_network_service.restore_state(world_state.get("roads", []))
	# Map-zone session state (§13) is laid over the freshly-built registry: the
	# geometry and roles came back from the map document in `_setup_zone_runtime`,
	# and only what a session mutated (owner, flags) is restored from the save.
	# An absent key is the default for saves predating this slot.
	if game.map_zone_registry != null and world_state.get("map_zones", []) is Array:
		game.map_zone_registry.apply_session_state(world_state.get("map_zones", []))

	# 9. Restore Citizens
	game.next_ai_citizen_id = int(world_state.get("next_ai_citizen_id", 1))
	game.hero_citizen = null
	for cit_dict in citizens_state:
		var pos = SaveData.dict_to_vector3(cit_dict.get("position", {}))
		var is_hero = bool(cit_dict.get("is_hero", false))
		var saved_id = int(cit_dict.get("ai_id", 0))

		var citizen: Citizen = CitizenActorScene.instantiate()
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
		game.citizen_factory.wire_citizen(citizen)

		game.citizens.append(citizen)
		citizen.ai_id = saved_id if saved_id > 0 else game.next_ai_citizen_id
		if citizen.ai_id >= game.next_ai_citizen_id:
			game.next_ai_citizen_id = citizen.ai_id + 1

		game.citizen_ai.register_citizen(citizen.ai_id, SettlementCitizenActuator.new(citizen, game.citizen_factory.ai_target_for_key))
		citizen.tree_exiting.connect(game.citizen_factory.on_ai_citizen_exiting.bind(citizen.ai_id), CONNECT_ONE_SHOT)

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
			var employment_cell := SaveData.dict_to_vector2i(cit_dict.get("employment_building_cell", {}))
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
	game.simulation_tick_controller.refresh_living_statuses()
	game.world_navigation_controller.refresh_navigation_grid()
	game.update_workers()
	if game.building_menu_controller != null:
		game.building_menu_controller.refresh_build_menu()

	if game.hero_citizen != null:
		game.player_controller.enter_first_person(game.hero_citizen, "Save loaded.")
	return true


func _resolve_saved_building_blueprint(saved_type: String, data: Dictionary) -> Dictionary:
	var resolved_type := saved_type
	var reference: Dictionary = data.get("blueprint_ref", {})
	if not reference.is_empty():
		var referenced_type := BuildingBlueprintLibrary.resolve_reference(reference)
		if not referenced_type.is_empty():
			resolved_type = referenced_type
			var referenced_blueprint: Variant = BuildingBlueprintLibrary.get_blueprint(referenced_type)
			var saved_revision: String = str(reference.get("revision", ""))
			if referenced_blueprint != null and not saved_revision.is_empty() and referenced_blueprint.revision_id() != saved_revision:
				push_warning("Blueprint '%s:%s' changed since this save; current file geometry will be used." % [
					reference.get("source", "builtin"), reference.get("id", "")])
		else:
			var role := StringName(reference.get("role", ""))
			var role_variant := BuildingBlueprintLibrary.resolve_role(role) if not String(role).is_empty() else ""
			if not role_variant.is_empty():
				resolved_type = role_variant
				push_warning("Missing blueprint '%s:%s'; restored using current variant for role '%s'." % [
					reference.get("source", "builtin"), reference.get("id", ""), role])
			else:
				push_warning("Missing authored blueprint '%s:%s' and no current variant for role '%s'." % [
					reference.get("source", "core"), reference.get("id", ""), role])
				return {"type": saved_type, "blueprint": {}}
	var blueprint: Dictionary = BuildingBlueprints.get_blueprint(resolved_type)
	var saved_zones: Variant = data.get("zone_state", [])
	if saved_zones is Array and not saved_zones.is_empty() and not blueprint.is_empty():
		blueprint = blueprint.duplicate(true)
		blueprint["saved_zone_state"] = saved_zones.duplicate(true)
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
		var cell := SaveData.dict_to_vector2i(entry.get("cell", {}))
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
			game.world_navigation_controller.apply_tree_felled_visual(cell, tree)
