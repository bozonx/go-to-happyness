class_name SettlementHeroInteractionController
extends RefCounted

## Handles first-person hero interactions: pocket delivery, tree felling,
## workplace occupation, campfire actions, and interaction hint display.
## Extracted from SettlementGame to reduce its method count.

const S = preload("res://game/features/ui/domain/game_strings.gd")

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func check_player_toilet_request() -> void:
	if not game.is_first_person or game.player_citizen == null:
		game._player_toilet_notified = false
		return
	var has_request := game.citizen_needs_service.has_toilet_request(game.player_citizen.ai_id)
	if has_request and not game._player_toilet_notified:
		game._player_toilet_notified = true
		var name := game.player_citizen.role_label() if game.player_citizen != game.hero_citizen else S.HERO_NAME
		game._update_interface(S.TOILET_NEED_HINT % name)
	elif not has_request:
		game._player_toilet_notified = false


func first_person_select_at_crosshair() -> void:
	var target := first_person_target()
	if target.kind == "building" and is_instance_valid(target.node) and game.building_registry.building_type_for_node(target.node) in game.OFFICIAL_WORKPLACE_TYPES:
		game.selected_campfire = target.node
		game.selected_building = target.node
		if game.campfire_menu_controller != null:
			game.campfire_menu_controller.show_campfire_menu()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	var viewport_center := game.get_viewport().get_visible_rect().size * 0.5
	game._select_citizen_at(viewport_center)


func first_person_target() -> Dictionary:
	if game.player_controller != null:
		return game.player_controller.first_person_target()
	return {"kind": ""}


func refresh_interaction_hint() -> void:
	if not game.is_first_person:
		game.ui_manager.interaction_hint_panel.visible = false
		return
	if game.input_controller.is_first_person_menu_open():
		game.ui_manager.interaction_hint_panel.visible = false
		return
	game.ui_manager.interaction_hint_panel.visible = true
	if game.pocket_menu_open:
		game.ui_manager.interaction_hint_panel.hint_label.text = S.CLOSE_MENU_HINT
		game.ui_manager.interaction_hint_panel.progress_bar.visible = false
		return
	if not game.interaction_action.is_empty():
		return
	var lines: Array[String] = []
	if game.player_citizen != null and not game.player_citizen.is_hero:
		var target := first_person_target()
		if target.kind == "toilet":
			var needs_toilet := game.citizen_needs_service != null and game.citizen_needs_service.has_toilet_request(game.player_citizen.ai_id)
			if needs_toilet:
				lines.append(S.F_USE_TOILET_NEED)
			else:
				lines.append(S.F_USE_TOILET)
		lines.append(S.OBSERVE_HINT)
	else:
		var action_hint := game.first_person_hud_controller.first_person_action_hint() if game.first_person_hud_controller != null else ""
		if not action_hint.is_empty():
			lines.append(action_hint)
	lines.append(game.hero_pocket_service.format_pocket_hint())
	if not game.pocket.is_empty():
		lines.append(S.DROP_POCKET_HINT)
	var home_text := _home_occupancy_text()
	if not home_text.is_empty():
		lines.append(home_text)
	game.ui_manager.interaction_hint_panel.hint_label.text = "\n".join(lines)
	game.ui_manager.interaction_hint_panel.progress_bar.visible = false


func _home_occupancy_text() -> String:
	if game.player_citizen == null or game.player_citizen.home == null or not is_instance_valid(game.player_citizen.home):
		return ""
	var home := game.player_citizen.home
	var capacity := int(home.get_meta("housing_capacity", 1))
	var free_slots := int(home.get_meta("spawn_slots", capacity))
	var occupied := clampi(capacity - free_slots, 0, capacity)
	return S.HOME_OCCUPANCY_FORMAT % [occupied, capacity]


func _missing_site_materials_text(site: ConstructionSite) -> String:
	var parts: Array[String] = []
	for resource_type in site.required_materials:
		var required := int(site.required_materials.get(resource_type, 0))
		var delivered := int(site.delivered_materials.get(resource_type, 0))
		if delivered < required:
			parts.append("%s %d/%d" % [resource_type.capitalize(), delivered, required])
	return ", ".join(parts)


func _nearest_service_position(building: Node3D, from: Vector3) -> Vector3:
	if not is_instance_valid(building):
		return Vector3.INF
	if building.has_meta("service_positions"):
		var positions: Array = building.get_meta("service_positions")
		var best := Vector3.INF
		var best_distance := INF
		for value in positions:
			if value is Vector3:
				var position: Vector3 = value
				var distance := from.distance_squared_to(position)
				if distance < best_distance:
					best = position
					best_distance = distance
		if best != Vector3.INF:
			return best
	return building.get_meta("service_position", building.global_position)


func exit_player_work_position() -> void:
	if game.player_citizen == null or not game.player_citizen.work_position_locked:
		return
	var was_official_appointment := game.player_citizen.work_position_role == "official" and not game.player_citizen.work_position_temporary
	game.player_citizen.exit_work_position()
	if was_official_appointment:
		game._dismiss_official(game.player_citizen)
		game._update_interface(S.LEFT_OFFICER_POST_FORMAT % game.player_citizen.role_label())
	else:
		game._update_interface(S.LEFT_WORKPLACE_FORMAT % game.player_citizen.role_label())
	refresh_interaction_hint()


func occupy_workplace(workplace: Node3D) -> void:
	if not is_instance_valid(workplace) or game.player_citizen == null:
		return
	var building_type := game.building_registry.building_type_for_node(workplace)
	var is_official_building := building_type in game.OFFICIAL_WORKPLACE_TYPES
	var service_position := _nearest_service_position(workplace, game.player_citizen.global_position)
	# Move the citizen onto the nearest service position. Smooth walking can be
	# added later; the design requires automatic positioning at the workplace.
	game.player_citizen.global_position = service_position
	if is_official_building:
		if game.settlement.is_research_completed("official"):
			var current_officer := game.workplace_labor_service.officer_holder()
			if current_officer != null and current_officer != game.player_citizen:
				game._update_interface(S.OFFICER_POSITION_TAKEN)
				return
			game.player_citizen.enter_work_position(service_position, "official", workplace, false)
			game.research_controller.appoint_official(game.player_citizen, workplace)
			if game.player_citizen.permanent_role != "official":
				game.player_citizen.exit_work_position()
				return
			game._update_interface(S.HERO_BECAME_OFFICER)
		else:
			game.player_citizen.enter_work_position(service_position, "researcher", workplace, true)
			if game.research_menu_controller != null:
				game.research_menu_controller.show_research_menu()
			game._update_interface(S.HERO_TOOK_RESEARCHER)
	else:
		var role: String = game.workplace_controller.role_for_workplace(workplace)
		if role.is_empty():
			return
		game.player_citizen.enter_work_position(service_position, role, workplace, true)
		game._update_interface(S.TOOK_TEMP_ROLE_FORMAT % [game.player_citizen.role_label(), role.replace("_", " ")])
	refresh_interaction_hint()


func occupy_selected_campfire_position() -> void:
	if not is_instance_valid(game.selected_campfire) or not is_instance_valid(game.player_citizen):
		return
	if game.player_citizen.global_position.distance_to(_nearest_service_position(game.selected_campfire, game.player_citizen.global_position)) > game.OFFICER_POST_RADIUS:
		return
	occupy_workplace(game.selected_campfire)
	if game.campfire_menu_controller != null:
		game.campfire_menu_controller.refresh_campfire_menu()


func handle_campfire_primary_action() -> void:
	if not is_instance_valid(game.selected_campfire):
		return
	game.selected_building = game.selected_campfire
	if not game.fire_management_service.is_fire_lit(game.selected_campfire):
		relight_selected_fire()
		if game.campfire_menu_controller != null:
			game.campfire_menu_controller.refresh_campfire_menu()
		return
	game._upgrade_selected_building()


func relight_selected_fire() -> void:
	if not is_instance_valid(game.selected_building):
		return
	var fire_state := game.fire_management_service.fire_state_for(game.selected_building)
	if fire_state.lit:
		return
	if fire_state.fuel <= 0:
		game._update_interface("A fire needs branches before it can be relit.")
		return
	fire_state.lit = true
	game.fire_management_service.apply_fire_state(game.selected_building, fire_state)
	game._refresh_living_statuses()
	game.workplace_controller.reopen_workplace_menu()
	game._update_interface("The fire was relit with flint and steel.")


func take_from_pile(pile: ResourcePile, all: bool) -> void:
	if pile == null:
		return
	var pile_node := pile.node
	if not is_instance_valid(pile_node):
		return
	var resources: Dictionary = pile.resources
	var taken_any := false
	for resource_type in resources.keys():
		var available := int(resources.get(resource_type, 0))
		if available <= 0:
			continue
		if not game.hero_pocket_service.pocket_has_room():
			break
		var amount := mini(available, game.hero_pocket_service.pocket_space_for(resource_type) if game.hero_pocket_service != null else 0) if all else 1
		amount = mini(amount, available)
		var taken := game.hero_pocket_service.add_to_pocket(resource_type, amount) if game.hero_pocket_service != null else 0
		if taken <= 0:
			continue
		taken_any = true
		resources[resource_type] = available - taken
		if resources[resource_type] <= 0:
			resources.erase(resource_type)
		if not all:
			break
	if not taken_any:
		if not game.hero_pocket_service.pocket_has_room():
			game._update_interface(S.POCKET_FULL_SHORT)
		else:
			game._update_interface(S.PILE_EMPTY_NO_RESOURCES)
		refresh_interaction_hint()
		return
	pile.resources = resources
	if resources.is_empty():
		for index in range(game.resource_piles.size()):
			if game.resource_piles[index].node == pile_node:
				game.resource_piles.remove_at(index)
				break
		pile_node.queue_free()
	else:
		game.resource_pile_service.refresh_resource_pile_label(pile)
	game._update_interface(S.TOOK_FROM_PILE % game.hero_pocket_service.format_pocket_hint())
	refresh_interaction_hint()


func consume_tree_near_player(amount: int) -> void:
	if game.player_citizen == null:
		return
	for position_on_board in game.tree_positions:
		if game.player_citizen.global_position.distance_to(position_on_board) <= game.INTERACTION_RANGE:
			var tree: Node3D = game.tree_nodes.get(game._cell_from_position(position_on_board))
			var tree_state: Variant = game.world_resource_state.tree_at(game._cell_from_position(position_on_board))
			if is_instance_valid(tree) and tree_state != null and not tree_state.felled:
				var consumed := 0
				while consumed < amount:
					var result := game.foraging_service.consume_tree_branches(position_on_board)
					if result <= 0:
						break
					consumed += result
				if consumed > 0:
					game._update_interface(S.BRANCHES_GATHERED_TREE_STANDING % consumed)
				else:
					game._update_interface(S.TREE_NO_BRANCHES_LEFT)
				return


func fell_nearest_tree() -> void:
	if game.player_citizen == null:
		return
	for position_on_board in game.tree_positions:
		if game.player_citizen.global_position.distance_to(position_on_board) <= game.INTERACTION_RANGE:
			var tree: Node3D = game.tree_nodes.get(game._cell_from_position(position_on_board))
			var tree_state: Variant = game.world_resource_state.tree_at(game._cell_from_position(position_on_board))
			if is_instance_valid(tree) and tree_state != null and not tree_state.felled:
				game._fell_tree_at(position_on_board)
				return


func take_resource_into_pocket(resource_type: String, amount: int) -> void:
	if amount <= 0:
		return
	var warehouse_index := game._nearby_warehouse_index()
	if warehouse_index >= 0:
		amount = mini(amount, game.settlement.warehouses[warehouse_index].amount(resource_type))
	else:
		amount = mini(amount, game.settlement.amount(resource_type))
	amount = game.hero_pocket_service.add_to_pocket(resource_type, amount) if game.hero_pocket_service != null else 0
	if amount > 0:
		if warehouse_index >= 0:
			game.settlement.add_to_warehouse(resource_type, -amount, warehouse_index)
		else:
			game.settlement.add(resource_type, -amount)
		game._update_interface(S.TOOK_FROM_WAREHOUSE % [amount, resource_type])
	if game.pocket_take_menu_controller != null:
		game.pocket_take_menu_controller.refresh_pocket_take_menu()
	refresh_interaction_hint()


func handle_sawmill_interaction(all: bool, sawmill_pos: Vector3) -> void:
	var wood_count := (game.hero_pocket_service.pocket_amount(ResourceIds.WOOD) if game.hero_pocket_service != null else 0) + (game.hero_pocket_service.pocket_amount(ResourceIds.LOGS) if game.hero_pocket_service != null else 0)
	if wood_count > 0:
		var delivered := 0
		if all:
			var wood_delivered := game.hero_pocket_service.remove_from_pocket(ResourceIds.WOOD, wood_count) if game.hero_pocket_service != null else 0
			var logs_delivered := game.hero_pocket_service.remove_from_pocket(ResourceIds.LOGS, wood_count - wood_delivered) if game.hero_pocket_service != null else 0
			delivered = wood_delivered + logs_delivered
		else:
			delivered = game.hero_pocket_service.remove_from_pocket(ResourceIds.WOOD, 1) if game.hero_pocket_service != null else 0
			if delivered == 0:
				delivered = game.hero_pocket_service.remove_from_pocket(ResourceIds.LOGS, 1) if game.hero_pocket_service != null else 0
		if delivered > 0:
			var stock := game._sawmill_stock(sawmill_pos)
			stock.logs = int(stock.logs) + delivered
			game.sawmills.store(sawmill_pos, stock)
			game._update_interface(S.DELIVERED_WOOD_TO_SAWMILL % delivered)
		refresh_interaction_hint()
		return
	var sawmill_stock := game._sawmill_stock(sawmill_pos)
	var available_boards := int(sawmill_stock.boards)
	if available_boards > 0 and game.hero_pocket_service.pocket_has_room():
		var take_amount := mini(available_boards, game.hero_pocket_service.pocket_space_for(ResourceIds.BOARDS) if game.hero_pocket_service != null else 0) if all else 1
		take_amount = game.hero_pocket_service.add_to_pocket(ResourceIds.BOARDS, take_amount) if game.hero_pocket_service != null else 0
		if take_amount > 0:
			sawmill_stock.boards = int(sawmill_stock.boards) - take_amount
			game.sawmills.store(sawmill_pos, sawmill_stock)
			game._update_interface(S.TOOK_BOARDS_FROM_SAWMILL % take_amount)
	refresh_interaction_hint()


func handle_warehouse_interaction(all: bool, warehouse_index := -1) -> void:
	if game.hero_pocket_service.pocket_total() > 0:
		if all:
			_deliver_all_pocket_to_warehouse(warehouse_index)
		else:
			_deliver_one_pocket_to_warehouse(warehouse_index)
		refresh_interaction_hint()
	else:
		if game.pocket_take_menu_controller != null:
			game.pocket_take_menu_controller.show_pocket_take_menu(warehouse_index)


func _deliver_all_pocket_to_warehouse(warehouse_index := -1) -> void:
	if warehouse_index < 0:
		warehouse_index = game._nearby_warehouse_index()
	var delivered_total := 0
	var summary: Array[String] = []
	for resource_type in game.hero_pocket_service.pocket_resources():
		var amount := game.hero_pocket_service.pocket_amount(resource_type) if game.hero_pocket_service != null else 0
		if amount <= 0:
			continue
		if warehouse_index >= 0 and not game.settlement.uses_virtual_storage() and not game.settlement.warehouse_accepts(warehouse_index, resource_type):
			game._update_interface(S.WAREHOUSE_REJECTS_FORMAT % resource_type)
			continue
		var to_deliver := amount
		if not game.settlement.uses_virtual_storage():
			to_deliver = mini(amount, game.settlement.storage_room_for(resource_type))
		if to_deliver <= 0:
			continue
		var overflow := 0
		if warehouse_index >= 0 and not game.settlement.uses_virtual_storage():
			overflow = game.settlement.add_to_warehouse(resource_type, to_deliver, warehouse_index)
		else:
			game.settlement.add(resource_type, to_deliver)
		var actually_delivered := to_deliver - overflow
		if actually_delivered > 0:
			game.hero_pocket_service.remove_from_pocket(resource_type, actually_delivered) if game.hero_pocket_service != null else 0
			delivered_total += actually_delivered
			summary.append("%d %s" % [actually_delivered, resource_type])
	if delivered_total > 0:
		game._update_interface(S.DELIVERED_TO_WAREHOUSE_SUMMARY % ", ".join(summary))
	elif game.hero_pocket_service.pocket_resources().is_empty():
		game._update_interface(S.POCKET_EMPTY)
	else:
		game._update_interface(S.WAREHOUSE_NO_ROOM)


func _deliver_one_pocket_to_warehouse(warehouse_index := -1) -> void:
	if warehouse_index < 0:
		warehouse_index = game._nearby_warehouse_index()
	var resource_type := game.hero_pocket_service.primary_pocket_resource()
	if resource_type.is_empty():
		return
	var amount := game.hero_pocket_service.pocket_amount(resource_type) if game.hero_pocket_service != null else 0
	if amount <= 0:
		return
	if warehouse_index >= 0 and not game.settlement.uses_virtual_storage() and not game.settlement.warehouse_accepts(warehouse_index, resource_type):
		game._update_interface(S.WAREHOUSE_REJECTS_FORMAT % resource_type)
		return
	var to_deliver := 1
	if not game.settlement.uses_virtual_storage():
		to_deliver = mini(1, game.settlement.storage_room_for(resource_type))
	if to_deliver <= 0:
		game._update_interface(S.WAREHOUSE_NO_ROOM_FOR_RESOURCE % resource_type)
		return
	var overflow := 0
	if warehouse_index >= 0 and not game.settlement.uses_virtual_storage():
		overflow = game.settlement.add_to_warehouse(resource_type, to_deliver, warehouse_index)
	else:
		game.settlement.add(resource_type, to_deliver)
	var actually_delivered := to_deliver - overflow
	if actually_delivered <= 0:
		game._update_interface(S.WAREHOUSE_NO_ROOM_IN_THIS % resource_type)
		return
	game.hero_pocket_service.remove_from_pocket(resource_type, actually_delivered) if game.hero_pocket_service != null else 0
	game._update_interface(S.DELIVERED_ONE_TO_WAREHOUSE % [actually_delivered, resource_type, game.hero_pocket_service.format_pocket_hint()])


func deliver_pocket_to_site(site: ConstructionSite, all: bool) -> void:
	var delivered_any := false
	for resource_type in site.required_materials:
		var required := int(site.required_materials.get(resource_type, 0))
		var delivered := int(site.delivered_materials.get(resource_type, 0))
		var needed := required - delivered
		if needed <= 0:
			continue
		var in_pocket := game.hero_pocket_service.pocket_amount(resource_type) if game.hero_pocket_service != null else 0
		if in_pocket <= 0:
			continue
		var amount := mini(in_pocket, needed) if all else mini(1, needed)
		amount = mini(amount, in_pocket)
		if amount <= 0:
			continue
		game.hero_pocket_service.remove_from_pocket(resource_type, amount) if game.hero_pocket_service != null else 0
		game.construction.accept_delivery(site.node, resource_type, amount)
		delivered_any = true
		if not all:
			break
	if delivered_any:
		game._update_interface(S.MATERIALS_DELIVERED_TO_SITE)
		refresh_interaction_hint()
	else:
		var missing := _missing_site_materials_text(site)
		if missing.is_empty():
			game._update_interface(S.SITE_FULLY_SUPPLIED)
		else:
			game._update_interface(S.POCKET_MISSING_MATERIALS % missing)
		refresh_interaction_hint()


func refuel_fire_from_pocket(building: Node3D, all: bool) -> void:
	if not is_instance_valid(building):
		return
	var available := game.hero_pocket_service.pocket_amount(ResourceIds.BRANCHES) if game.hero_pocket_service != null else 0
	if available <= 0:
		game._update_interface(S.NO_BRANCHES_FOR_FIRE)
		refresh_interaction_hint()
		return
	var fire_state := game.fire_management_service.fire_state_for(building)
	var amount := available if all else 1
	amount = mini(amount, available)
	var delivered := game.hero_pocket_service.remove_from_pocket(ResourceIds.BRANCHES, amount) if game.hero_pocket_service != null else 0
	if delivered <= 0:
		return
	fire_state.add_delivered(delivered, int(game.game_minutes))
	game.fire_management_service.apply_fire_state(building, fire_state)
	game._refresh_living_statuses()
	game._update_interface(S.BRANCHES_ADDED_TO_FIRE % delivered)
	refresh_interaction_hint()


func meet_arrival_at_entrance() -> void:
	for index in game.pending_arrivals.size():
		var order: Dictionary = game.pending_arrivals[index]
		if bool(order.get("dispatched", false)):
			continue
		order.dispatched = true
		order.greeter_id = game.player_citizen.ai_id
		game.pending_arrivals[index] = order
		game.arrival_greeters[game.player_citizen.ai_id] = order
		game.citizen_lifecycle_service.on_arrival_greeter_ready(game.player_citizen)
		refresh_interaction_hint()
		return
	game._update_interface(S.NO_ONE_TO_MEET)
	refresh_interaction_hint()


func nearby_player_work_target() -> Node3D:
	if game.player_citizen == null:
		return null
	for site in game.construction_sites:
		if not is_instance_valid(site.node):
			continue
		if game.player_citizen.global_position.distance_to(site.node.global_position) <= game.INTERACTION_RANGE:
			return site.node
	for site in game.demolition_sites:
		if not is_instance_valid(site.building):
			continue
		if game.player_citizen.global_position.distance_to(site.building.global_position) <= game.INTERACTION_RANGE:
			return site.building
	return null
