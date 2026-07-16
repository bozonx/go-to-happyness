class_name SettlementAIWorldFacade
extends AIWorldFacade

## Scene adapter for the native AI. Each migrated mechanic adds only its owned
## facts here, without mirroring SettlementGame's private API.

var simulation: Node


func _init(next_simulation: Node = null) -> void:
	simulation = next_simulation


func capture(sequence: int) -> WorldSnapshot:
	if not is_instance_valid(simulation):
		return WorldSnapshot.new(sequence)
	var canteen_service: CanteenService = simulation.canteen_service
	var courier_tasks: Array[Dictionary] = []
	if simulation.courier_dispatcher != null:
		for task: CourierTask in simulation.courier_dispatcher.available_tasks():
			courier_tasks.append({&"id": task.id, &"priority": task.priority, &"pickup": task.pickup, &"requested_courier_id": int(task.payload.get("courier_ai_id", 0))})
	var workforce_world := _world_data()
	var forestry_targets := _forestry_targets()
	var gathering_targets := _gathering_targets()
	var citizens_by_id: Dictionary = {}
	for actor: Citizen in simulation.citizens:
		if not is_instance_valid(actor) or actor.ai_id == 0 or simulation.outside_workers.has(actor.get_instance_id()):
			continue
		var citizen_id := actor.ai_id
		var actor_work_time: bool = simulation._is_citizen_work_time(actor)
		var can_start_personal_need := not actor.is_player_controlled and actor.state in [Citizen.State.IDLE, Citizen.State.WAITING]
		var worker_data := _worker_data(actor)
		var daily_order_active := actor.has_active_daily_order() and not actor.is_player_controlled
		var daily_order_role := actor.daily_order_role if daily_order_active else ""
		var needs_service: CitizenNeedsService = simulation.citizen_needs_service
		var rest_request := needs_service.rest_request(citizen_id) if needs_service != null else {}
		var relief_candidates: Array[Dictionary] = []
		if needs_service != null and needs_service.has_toilet_request(citizen_id):
			relief_candidates = needs_service.relief_candidates_for(actor)
		var forestry_worker := actor.permanent_role == "forestry" and actor.is_employed() and not actor.is_player_controlled
		var sawmill_position := Vector3.INF
		var warehouse_position := Vector3.INF
		if forestry_worker and actor_work_time and not simulation.sawmill_positions.is_empty() and not simulation.warehouse_positions.is_empty() and simulation._has_storage_room_for_role("forestry"):
			sawmill_position = actor.employment_workplace.get_meta("service_position", actor.employment_workplace.global_position) if is_instance_valid(actor.employment_workplace) else simulation.sawmill_positions[0]
			warehouse_position = _storage_position_for(actor.global_position, "boards")
		var forestry_in_progress := actor.state in [Citizen.State.TO_TREE, Citizen.State.CHOPPING, Citizen.State.TO_SAWMILL]
		var forestry_candidates: Array[Dictionary] = []
		if forestry_worker and actor_work_time:
			# Tree validity and walkable interaction cells are snapshot-wide facts.
			# Reusing the shared list avoids rebuilding it once per forestry worker.
			forestry_candidates = _forestry_targets(actor.global_position)
		var farming_worker := actor.permanent_role == "farming" and actor.is_employed() and not actor.is_player_controlled
		var farming_in_progress := farming_worker and actor.active_role == "farming" and actor.state in [Citizen.State.TO_TREE, Citizen.State.TO_SAWMILL, Citizen.State.SAWING, Citizen.State.WAITING_COURIER]
		var farming_position := Vector3.INF
		var farming_warehouse_position := Vector3.INF
		if farming_in_progress:
			farming_position = actor.workplace_position
			farming_warehouse_position = actor.warehouse_position
		elif farming_worker and not simulation.farm_positions.is_empty() and not simulation.warehouse_positions.is_empty():
			farming_position = actor.employment_workplace.get_meta("service_position", actor.employment_workplace.global_position) if is_instance_valid(actor.employment_workplace) else simulation.farm_positions[0]
			farming_warehouse_position = _storage_position_for(actor.global_position, "food")
		var farming_can_start: bool = farming_worker and actor_work_time and simulation._has_storage_room_for_role("farming") and farming_position != Vector3.INF and farming_warehouse_position != Vector3.INF
		var construction_worker := actor.permanent_role == "construction" and actor.is_employed() and not actor.is_player_controlled
		var construction_in_progress := construction_worker and actor.active_role in ["construction", "demolition"] and actor.state == Citizen.State.CONSTRUCTING and is_instance_valid(actor.construction_site)
		var construction_can_start := false
		var construction_mode: StringName = &""
		var construction_target_key: StringName = &""
		var construction_position := Vector3.INF
		if construction_in_progress:
			construction_mode = StringName(actor.active_role)
			construction_target_key = _target_key(construction_mode, actor.construction_site.global_position)
			construction_position = actor._reachable_construction_approach(actor.construction_site)
		elif construction_worker and actor_work_time:
			if not simulation.demolition_sites.is_empty():
				var demolition_site: DemolitionSite = simulation.demolition_sites[(citizen_id - 1) % simulation.demolition_sites.size()]
				if is_instance_valid(demolition_site.building):
					construction_mode = &"demolition"
					construction_target_key = _target_key(&"demolition", demolition_site.building.global_position)
					construction_position = actor._reachable_construction_approach(demolition_site.building)
			elif _construction_site_for(actor) != null:
				var construction_site: ConstructionSite = _construction_site_for(actor)
				if is_instance_valid(construction_site.node):
					construction_mode = &"construction"
					construction_target_key = _target_key(&"construction", construction_site.node.global_position)
					construction_position = actor._reachable_construction_approach(construction_site.node)
			construction_can_start = construction_target_key != &"" and construction_position != Vector3.INF
		var daily_construction_in_progress := daily_order_active and daily_order_role == "construction" and actor.active_role in ["construction", "demolition"] and actor.state == Citizen.State.CONSTRUCTING and is_instance_valid(actor.construction_site)
		var daily_construction_can_start := false
		var daily_construction_mode: StringName = &""
		var daily_construction_target_key: StringName = &""
		var daily_construction_position := Vector3.INF
		if daily_construction_in_progress:
			daily_construction_mode = StringName(actor.active_role)
			daily_construction_target_key = _target_key(daily_construction_mode, actor.construction_site.global_position)
			daily_construction_position = actor._reachable_construction_approach(actor.construction_site)
		elif daily_order_role == "construction":
			if not simulation.demolition_sites.is_empty():
				var daily_demolition_site: DemolitionSite = simulation.demolition_sites[(citizen_id - 1) % simulation.demolition_sites.size()]
				if is_instance_valid(daily_demolition_site.building):
					daily_construction_mode = &"demolition"
					daily_construction_target_key = _target_key(&"demolition", daily_demolition_site.building.global_position)
					daily_construction_position = actor._reachable_construction_approach(daily_demolition_site.building)
			elif _construction_site_for(actor) != null:
				var daily_construction_site: ConstructionSite = _construction_site_for(actor)
				if is_instance_valid(daily_construction_site.node):
					daily_construction_mode = &"construction"
					daily_construction_target_key = _target_key(&"construction", daily_construction_site.node.global_position)
					daily_construction_position = actor._reachable_construction_approach(daily_construction_site.node)
			daily_construction_can_start = daily_construction_target_key != &"" and daily_construction_position != Vector3.INF
		var gathering_worker: bool = actor.permanent_role in ["gather_branches", "gather_food"] and actor.is_employed() and not actor.is_player_controlled
		var gathering_in_progress: bool = gathering_worker and actor.active_role.begins_with("gather_") and actor.state in [Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_WAREHOUSE]
		var gathering_candidates: Array[Dictionary] = []
		if gathering_worker and actor_work_time and simulation._has_storage_room_for_role(actor.permanent_role):
			if actor.permanent_role == "gather_food":
				gathering_candidates = _food_gathering_targets(actor)
			elif actor.permanent_role == "gather_branches":
				gathering_candidates = _daily_gathering_targets_for(actor, "gather_branches")
		var daily_gathering_in_progress := daily_order_active and daily_order_role.begins_with("gather_") and actor.active_role.begins_with("gather_") and actor.state in [Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_WAREHOUSE]
		var daily_gathering_candidates: Array[Dictionary] = []
		if daily_order_role.begins_with("gather_") and simulation._has_storage_room_for_role(daily_order_role):
			daily_gathering_candidates = _daily_gathering_targets_for(actor, daily_order_role)
		var daily_gathering_can_start := daily_order_active and daily_order_role.begins_with("gather_") and not daily_gathering_candidates.is_empty()
		var daily_cleaning_in_progress := daily_order_active and daily_order_role == "cleaning" and actor.active_role == "cleaning" and actor.state in [Citizen.State.TO_CLEANING_PILE, Citizen.State.CLEANING_PILE, Citizen.State.TO_WAREHOUSE]
		var daily_cleaning_candidates: Array[Dictionary] = []
		if daily_order_role == "cleaning" and daily_order_active and actor_work_time:
			daily_cleaning_candidates = _cleaning_targets(actor)
		var daily_cleaning_can_start: bool = daily_order_active and daily_order_role == "cleaning" and actor_work_time and not daily_cleaning_candidates.is_empty()
		var excavation_worker := actor.permanent_role == "excavation" and actor.is_employed() and not actor.is_player_controlled
		var excavation_in_progress := excavation_worker and actor.active_role == "excavation" and actor.state in [Citizen.State.EXCAVATING, Citizen.State.WAITING_COURIER]
		var excavation_candidates: Array[Dictionary] = []
		if excavation_worker and actor_work_time:
			for dig_site_value in simulation.dig_sites:
				var dig_site := dig_site_value as Dictionary
				var dig_node := dig_site.get(&"node") as Node3D
				if not is_instance_valid(dig_node) or not simulation._can_work_at_dig_site(dig_site):
					continue
				if not simulation._is_route_reachable(actor.global_position, dig_node.global_position):
					continue
				excavation_candidates.append({
					&"id": _target_key(&"dig", dig_node.global_position),
					&"target_key": _target_key(&"dig", dig_node.global_position),
					&"position": dig_node.global_position,
				})
		var service_role := ""
		if actor.permanent_role in ["cook", "teacher", "seller", "official", "craftsman"] and actor.is_employed() and not actor.is_player_controlled:
			service_role = actor.permanent_role
		elif daily_order_active and daily_order_role == "cook" and not actor.is_player_controlled:
			service_role = "cook"
		var service_states := {
			"cook": [Citizen.State.TO_CANTEEN_WORK, Citizen.State.CANTEEN_WORK],
			"teacher": [Citizen.State.TO_SCHOOL_WORK, Citizen.State.SCHOOL_WORK],
			"seller": [Citizen.State.TO_MARKET_WORK, Citizen.State.MARKET_WORK],
			"official": [Citizen.State.TO_OFFICIAL_WORK, Citizen.State.OFFICIAL_WORK],
			"craftsman": [Citizen.State.TO_CRAFT_WORK, Citizen.State.CRAFT_WORK],
		}
		var service_in_progress: bool = not service_role.is_empty() and actor.state in (service_states.get(service_role, []) as Array)
		var service_position: Vector3 = Vector3.INF
		if service_in_progress:
			match service_role:
				"cook": service_position = actor.canteen_position
				"teacher": service_position = actor.school_position
				"seller": service_position = actor.market_position
				"official": service_position = actor.official_position
				"craftsman": service_position = actor.craft_position
		elif not service_role.is_empty() and actor_work_time:
			if service_role == "cook":
				service_position = simulation.canteen_position if is_instance_valid(simulation.canteen) else Vector3.INF
			elif service_role == "official":
				service_position = simulation._employment_center_position()
			else:
				service_position = actor.employment_workplace.get_meta("service_position", actor.employment_workplace.global_position) if is_instance_valid(actor.employment_workplace) else Vector3.INF
		var service_can_start: bool = not service_role.is_empty() and service_position != Vector3.INF
		var factory_worker := actor.permanent_role in ["factory_worker", "engineer"] and actor.is_employed() and not actor.is_player_controlled
		var factory_role: StringName = &""
		var factory_node: Node3D
		if actor.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK] and is_instance_valid(actor.factory):
			if factory_worker:
				factory_role = &"factory_work" if actor.permanent_role == "factory_worker" else &"engineering"
				factory_node = actor.factory
			elif actor.permanent_role == "construction" and actor.specialization == "builder":
				factory_role = &"construction"
				factory_node = actor.factory
		elif factory_worker and actor_work_time and is_instance_valid(actor.employment_workplace):
			factory_role = &"factory_work" if actor.permanent_role == "factory_worker" else &"engineering"
			factory_node = actor.employment_workplace as Node3D
		elif actor.permanent_role == "construction" and actor.specialization == "builder" and actor_work_time and simulation.construction_sites.is_empty() and simulation.demolition_sites.is_empty():
			for factory_value in simulation.factories:
				var candidate_factory := factory_value as Node3D
				if is_instance_valid(candidate_factory) and candidate_factory.get_meta("building_type", "") == "materials_factory":
					factory_node = candidate_factory
					factory_role = &"construction"
					break
		var factory_in_progress: bool = factory_role != &"" and actor.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]
		var factory_can_start: bool = factory_role != &"" and is_instance_valid(factory_node)
		var factory_position: Vector3 = Vector3.INF
		if is_instance_valid(factory_node):
			var factory_position_value: Variant = factory_node.get_meta("service_position", factory_node.global_position)
			if factory_position_value is Vector3:
				factory_position = factory_position_value
		var courier_worker: bool = actor.can_handle_entry_logistics() and not actor.is_player_controlled
		var courier_task_candidates: Array[Dictionary] = []
		if courier_worker and simulation.courier_dispatcher != null:
			for task_data in courier_tasks:
				var task_id := task_data.get(&"id", &"") as StringName
				var task := simulation.courier_dispatcher.tasks.get(task_id) as CourierTask
				if task != null and simulation._is_courier_task_reachable(actor, task):
					courier_task_candidates.append(task_data)
		var courier_active_task_id: StringName = &""
		var courier_active_pickup := Vector3.INF
		var courier_active_priority := 0
		if courier_worker and simulation.courier_dispatcher != null:
			var active_courier_task: CourierTask = simulation.courier_dispatcher.task_for(actor)
			if active_courier_task != null and actor.has_active_delivery():
				courier_active_task_id = active_courier_task.id
				courier_active_pickup = active_courier_task.pickup
				courier_active_priority = active_courier_task.priority
		var courier_in_progress := courier_active_task_id != &""
		var courier_can_start: bool = courier_worker and actor.state == Citizen.State.IDLE and actor_work_time
		citizens_by_id[citizen_id] = CitizenSnapshot.new(
			citizen_id,
			actor.global_position,
			actor.is_player_controlled,
			not actor.is_player_controlled,
			AIFactSet.from_owned_values({
				&"hero": actor.is_hero,
				&"needs.should_sleep": not actor_work_time,
				&"needs.fatigue_level": actor.fatigue,
				&"needs.dangerously_tired": actor.is_dangerously_tired(),
				&"needs.recovering": actor.is_recovering(simulation.day_cycle.current_day),
				&"needs.has_home": is_instance_valid(actor.home),
				&"needs.home_position": actor.home.global_position if is_instance_valid(actor.home) else Vector3.INF,
				&"needs.can_start_sleep": can_start_personal_need,
				&"needs.meal_requested": canteen_service != null and canteen_service.is_meal_requested(citizen_id),
				&"needs.can_start_meal": canteen_service != null and can_start_personal_need and is_instance_valid(simulation.canteen),
				&"needs.canteen_position": simulation.canteen_position,
				&"needs.toilet_requested": needs_service != null and needs_service.has_toilet_request(citizen_id),
				&"needs.can_start_toilet": can_start_personal_need,
				&"needs.relief_candidates": relief_candidates,
				&"needs.rest_requested": needs_service != null and needs_service.has_rest_request(citizen_id),
				&"needs.can_start_rest": can_start_personal_need,
				&"needs.rest_position": rest_request.get(&"position", Vector3.INF),
				&"needs.rest_duration": rest_request.get(&"duration", 4.0),
				&"work.forestry.worker": forestry_worker,
				&"work.forestry.in_progress": forestry_in_progress,
				&"work.forestry.can_start": sawmill_position != Vector3.INF and warehouse_position != Vector3.INF,
				&"work.forestry.sawmill_position": sawmill_position,
				&"work.forestry.warehouse_position": warehouse_position,
				&"work.forestry.candidates": forestry_candidates,
				&"work.farming.worker": farming_worker,
				&"work.farming.in_progress": farming_in_progress,
				&"work.farming.can_start": farming_can_start,
				&"work.farming.position": farming_position,
				&"work.farming.warehouse_position": farming_warehouse_position,
				&"work.construction.worker": construction_worker,
				&"work.construction.in_progress": construction_in_progress,
				&"work.construction.can_start": construction_can_start,
				&"work.construction.mode": construction_mode,
				&"work.construction.target_key": construction_target_key,
				&"work.construction.position": construction_position,
				&"work.gathering.worker": gathering_worker,
				&"work.gathering.in_progress": gathering_in_progress,
				&"work.gathering.can_start": gathering_worker and actor_work_time and simulation._has_storage_room_for_role(actor.permanent_role),
				&"work.gathering.role": StringName(actor.permanent_role) if gathering_worker else &"",
				&"work.gathering.candidates": gathering_candidates,
				&"work.gathering.warehouse_position": _gathering_warehouse_position(actor, gathering_candidates, actor.permanent_role) if gathering_worker else Vector3.INF,
				&"work.excavation.worker": excavation_worker,
				&"work.excavation.in_progress": excavation_in_progress,
				&"work.excavation.candidates": excavation_candidates,
				&"work.service.worker": not service_role.is_empty(),
				&"work.service.in_progress": service_in_progress,
				&"work.service.can_start": service_can_start,
				&"work.service.role": StringName(service_role),
				&"work.service.position": service_position,
				&"work.factory.worker": factory_worker or factory_role == &"construction",
				&"work.factory.in_progress": factory_in_progress,
				&"work.factory.can_start": factory_can_start,
				&"work.factory.role": factory_role,
				&"work.factory.target_key": _target_key(&"factory", factory_node.global_position) if is_instance_valid(factory_node) else &"",
				&"work.factory.position": factory_position,
				&"work.courier.worker": courier_worker,
				&"work.courier.permanent": actor.is_courier(),
				&"work.courier.actor_id": citizen_id,
				&"work.courier.in_progress": courier_in_progress,
				&"work.courier.can_start": courier_can_start,
				&"work.courier.active_task_id": courier_active_task_id,
				&"work.courier.active_pickup": courier_active_pickup,
				&"work.courier.active_priority": courier_active_priority,
				&"work.courier.tasks": courier_task_candidates,
				&"work.courier.use_personal_tasks": true,
				&"daily.order.active": daily_order_active,
				&"daily.order.role": daily_order_role,
				&"daily.order.workday_id": actor.daily_order_workday_id,
				&"daily.order.expires_at": actor.daily_order_expires_at,
				&"daily.construction.in_progress": daily_construction_in_progress,
				&"daily.construction.can_start": daily_construction_can_start,
				&"daily.construction.mode": daily_construction_mode,
				&"daily.construction.target_key": daily_construction_target_key,
				&"daily.construction.position": daily_construction_position,
				&"daily.gathering.in_progress": daily_gathering_in_progress,
				&"daily.gathering.can_start": daily_gathering_can_start,
				&"daily.gathering.role": StringName(daily_order_role) if daily_order_role.begins_with("gather_") else &"",
				&"daily.gathering.candidates": daily_gathering_candidates,
				&"daily.gathering.warehouse_position": _gathering_warehouse_position(actor, daily_gathering_candidates, daily_order_role) if daily_order_role.begins_with("gather_") else Vector3.INF,
				&"daily.cleaning.in_progress": daily_cleaning_in_progress,
				&"daily.cleaning.can_start": daily_cleaning_can_start,
				&"daily.cleaning.candidates": daily_cleaning_candidates,
				&"daily.cleaning.warehouse_position": _cleaning_warehouse_position(actor, daily_cleaning_candidates) if daily_order_role == "cleaning" else Vector3.INF,
				&"workforce.worker_data": worker_data,
				&"workforce.pending_workplace_key": _workplace_target_key(actor.pending_employment_workplace),
				&"workforce.pending_workplace_position": actor.pending_employment_workplace.global_position if is_instance_valid(actor.pending_employment_workplace) else Vector3.INF,
			})
		)
	var settlement_facts := AIFactSet.from_owned_values({
		&"population": citizens_by_id.size(),
		&"era": simulation.settlement.era,
		&"settlement.wellbeing": simulation.wellbeing,
		&"workforce.world_data": workforce_world,
		&"workforce.employment_center_position": simulation._employment_center_position(),
		&"workforce.role_employers": _role_employers(),
		&"work.forestry.targets": forestry_targets,
		&"work.gathering.targets": gathering_targets,
		&"work.courier.tasks": courier_tasks,
	})
	return WorldSnapshot.new(
		sequence,
		simulation.runtime_seconds,
		simulation.game_minutes,
		settlement_facts,
		citizens_by_id
	)


func _target_key(kind: StringName, position: Vector3) -> StringName:
	var cell: Vector2i = simulation._cell_from_position(position)
	return StringName("%s:%d:%d" % [kind, cell.x, cell.y])


func _forestry_targets(from: Vector3 = Vector3.INF) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for tree_position: Vector3 in simulation.tree_positions:
		var cell: Vector2i = simulation._cell_from_position(tree_position)
		var tree: Node3D = simulation.tree_nodes.get(cell) as Node3D
		if not is_instance_valid(tree) or bool(tree.get_meta("felled", false)):
			continue
		var access := _resource_access_position(tree_position, from)
		if access != Vector3.INF:
			var cost := _route_cost(from, access)
			if cost < INF:
				targets.append({&"id": StringName("tree:%d:%d" % [cell.x, cell.y]), &"position": tree_position, &"access": access, &"route_cost": cost})
	return targets


func _construction_site_for(actor: Citizen) -> ConstructionSite:
	if not is_instance_valid(actor):
		return null
	var preferred: ConstructionSite = simulation._preferred_construction_site()
	if preferred != null and is_instance_valid(preferred.node) and actor._reachable_construction_approach(preferred.node) != Vector3.INF:
		return preferred
	var best: ConstructionSite = null
	var best_score := -INF
	for candidate: ConstructionSite in simulation.construction_sites:
		if candidate == null or not is_instance_valid(candidate.node) or candidate.node.is_queued_for_deletion():
			continue
		if actor._reachable_construction_approach(candidate.node) == Vector3.INF:
			continue
		var score: float = simulation._construction_development_priority(candidate)
		if score > best_score:
			best = candidate
			best_score = score
	return best


func _gathering_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if simulation.settlement.amount("grass") < simulation.settlement.amount("branches"):
		for grass_cell_value in simulation.grass_sources.keys():
			var grass_cell := grass_cell_value as Vector2i
			var grass_source := simulation.grass_sources.get(grass_cell, {}) as Dictionary
			var grass_node := grass_source.get(&"node") as Node3D
			if int(grass_source.get(&"remaining", 0)) > 0 and is_instance_valid(grass_node):
				var access := _resource_access_position(grass_node.global_position)
				if access != Vector3.INF:
					targets.append({&"id": StringName("grass:%d:%d" % [grass_cell.x, grass_cell.y]), &"resource_type": "grass", &"position": grass_node.global_position, &"access": access})
		if not targets.is_empty():
			return targets
	for tree_position: Vector3 in simulation.tree_positions:
		var tree_cell: Vector2i = simulation._cell_from_position(tree_position)
		var tree := simulation.tree_nodes.get(tree_cell) as Node3D
		if not is_instance_valid(tree) or bool(tree.get_meta("felled", false)) or int(tree.get_meta("remaining_branches", 0)) <= 0:
			continue
		var hand_limit := ceili(float(int(tree.get_meta("initial_branches", tree.get_meta("remaining_branches", 0)))) * 0.3)
		if not bool(simulation.settlement.tools.get("axe", false)) and int(tree.get_meta("hand_branches", 0)) >= hand_limit:
			continue
		var access := _resource_access_position(tree_position)
		if access != Vector3.INF:
			targets.append({&"id": StringName("branch:%d:%d" % [tree_cell.x, tree_cell.y]), &"resource_type": "branches", &"position": tree_position, &"access": access})
	return targets


func _resource_access_position(resource_position: Vector3, from: Vector3 = Vector3.INF) -> Vector3:
	if from != Vector3.INF and simulation.has_method(&"_resource_access_position"):
		return simulation._resource_access_position(from, resource_position)
	var resource_cell: Vector2i = simulation._cell_from_position(resource_position)
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var cell: Vector2i = resource_cell + offset
		if simulation._is_board_cell(cell) and not simulation._is_navigation_cell_blocked(cell):
			return simulation._cell_center(cell)
	return Vector3.INF


func _route_cost(from: Vector3, destination: Vector3) -> float:
	if from == Vector3.INF or destination == Vector3.INF:
		return INF
	var route: RouteResult = simulation._find_path_around_houses(from, destination, false)
	return simulation._route_cost(from, route)


func _cleaning_targets(actor: Citizen) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if not is_instance_valid(actor) or simulation.warehouse_positions.is_empty():
		return targets
	for pile: Dictionary in simulation.resource_piles:
		var pile_node := pile.get(&"node") as Node3D
		if not is_instance_valid(pile_node) or not simulation._is_route_reachable(actor.global_position, pile_node.global_position):
			continue
		var pile_cell: Vector2i = simulation._cell_from_position(pile_node.global_position)
		for resource_type in pile.resources:
			var available := int(pile.resources[resource_type]) - int(pile.reserved.get(resource_type, 0))
			if available <= 0 or not simulation.settlement.can_make_room_for(str(resource_type), 1, simulation.warehouse_positions.size()):
				continue
			targets.append({
				&"id": StringName("pile:%d:%d:%s" % [pile_cell.x, pile_cell.y, str(resource_type)]),
				&"pile_id": StringName("pile:%d:%d" % [pile_cell.x, pile_cell.y]),
				&"resource_type": str(resource_type),
				&"position": pile_node.global_position,
				&"access": pile_node.global_position,
			})
	# The starter backpack is a non-decaying pile that couriers can empty into warehouses.
	if simulation.backpack_position != Vector3.ZERO and simulation._is_route_reachable(actor.global_position, simulation.backpack_position):
		var backpack_cell: Vector2i = simulation._cell_from_position(simulation.backpack_position)
		for resource_type in simulation.settlement.backpack:
			var available := int(simulation.settlement.backpack.get(resource_type, 0))
			if available <= 0 or not simulation.settlement.can_make_room_for(str(resource_type), 1, simulation.warehouse_positions.size()):
				continue
			targets.append({
				&"id": StringName("backpack:%d:%d:%s" % [backpack_cell.x, backpack_cell.y, str(resource_type)]),
				&"pile_id": StringName("backpack:%d:%d" % [backpack_cell.x, backpack_cell.y]),
				&"resource_type": str(resource_type),
				&"position": simulation.backpack_position,
				&"access": simulation.backpack_position,
			})
	return targets


func _workplace_target_key(workplace: Node3D) -> StringName:
	if not is_instance_valid(workplace):
		return &""
	if workplace == simulation._dig_site_for_node(workplace).get(&"node"):
		return _target_key(&"dig", workplace.global_position)
	return _target_key(&"building", workplace.global_position)


func _food_gathering_targets(actor: Citizen) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if not is_instance_valid(actor) or simulation.forager_positions.is_empty() or simulation.warehouse_positions.is_empty():
		return targets
	for cell_value in simulation.forage_sources:
		var cell := cell_value as Vector2i
		var node := (simulation.forage_sources[cell] as Dictionary).get("node") as Node3D
		if is_instance_valid(node) and simulation._is_route_reachable(actor.global_position, node.global_position):
			targets.append({&"id": StringName("plant:%d:%d" % [cell.x, cell.y]), &"resource_type": "food", &"position": node.global_position, &"access": node.global_position, &"route_cost": _route_cost(actor.global_position, node.global_position)})
	for cell_value in simulation.rabbit_sources:
		var cell := cell_value as Vector2i
		var node := (simulation.rabbit_sources[cell] as Dictionary).get("node") as Node3D
		if is_instance_valid(node) and simulation._is_route_reachable(actor.global_position, node.global_position):
			targets.append({&"id": StringName("rabbit:%d:%d" % [cell.x, cell.y]), &"resource_type": "food", &"position": node.global_position, &"access": node.global_position, &"route_cost": _route_cost(actor.global_position, node.global_position)})
	return targets


func _daily_gathering_targets_for(actor: Citizen, role: String) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	match role:
		"gather_branches":
			for tree_position: Vector3 in simulation.tree_positions:
				var tree_cell: Vector2i = simulation._cell_from_position(tree_position)
				var tree := simulation.tree_nodes.get(tree_cell) as Node3D
				if not is_instance_valid(tree) or bool(tree.get_meta("felled", false)) or int(tree.get_meta("remaining_branches", 0)) <= 0:
					continue
				if not bool(simulation.settlement.tools.get("axe", false)):
					var initial_branches := int(tree.get_meta("initial_branches", tree.get_meta("remaining_branches", 0)))
					var hand_limit := ceili(float(initial_branches) * 0.3)
					if int(tree.get_meta("hand_branches", 0)) >= hand_limit:
						continue
				var access: Vector3 = simulation._resource_access_position(actor.global_position, tree_position)
				if access != Vector3.INF:
					targets.append({&"id": StringName("branch:%d:%d" % [tree_cell.x, tree_cell.y]), &"resource_type": "branches", &"position": tree_position, &"access": access, &"route_cost": _route_cost(actor.global_position, access)})
		"gather_grass":
			for grass_cell_value in simulation.grass_sources.keys():
				var grass_cell := grass_cell_value as Vector2i
				var grass_source := simulation.grass_sources.get(grass_cell, {}) as Dictionary
				var grass_node := grass_source.get(&"node") as Node3D
				if int(grass_source.get(&"remaining", 0)) > 0 and is_instance_valid(grass_node):
					var access: Vector3 = simulation._resource_access_position(actor.global_position, grass_node.global_position)
					if access != Vector3.INF:
						targets.append({&"id": StringName("grass:%d:%d" % [grass_cell.x, grass_cell.y]), &"resource_type": "grass", &"position": grass_node.global_position, &"access": access, &"route_cost": _route_cost(actor.global_position, access)})
		"gather_water":
			for pond_position: Vector3 in simulation.pond_positions:
				var access: Vector3 = simulation._pond_access_position(actor.global_position, pond_position)
				if access != Vector3.INF:
					targets.append({&"id": _target_key(&"water", access), &"resource_type": "water", &"position": access, &"access": access, &"route_cost": _route_cost(actor.global_position, access)})
	return targets


func _gathering_warehouse_position(actor: Citizen, candidates: Array[Dictionary], role: String) -> Vector3:
	if role == "gather_food" and is_instance_valid(actor.employment_workplace):
		return actor.employment_workplace.get_meta("service_position", actor.employment_workplace.global_position)
	if not candidates.is_empty():
		var first_position: Variant = candidates[0].get(&"position", actor.global_position)
		var resource_type := str(candidates[0].get(&"resource_type", ""))
		if first_position is Vector3:
			return _storage_position_for(first_position as Vector3, resource_type)
	return Vector3.INF


func _cleaning_warehouse_position(actor: Citizen, candidates: Array[Dictionary]) -> Vector3:
	if not candidates.is_empty():
		var resource_type := str(candidates[0].get(&"resource_type", ""))
		return _storage_position_for(actor.global_position, resource_type)
	return Vector3.INF


func _storage_position_for(from: Vector3, resource_type: String) -> Vector3:
	var index: int = simulation._find_reachable_warehouse_index(from, resource_type, 1)
	return simulation.warehouse_positions[index] if index >= 0 else Vector3.INF


func _worker_data(actor: Citizen) -> Dictionary:
	var should_study := false
	if not actor.training_role.is_empty() and actor.training_days_completed < 10:
		should_study = true
	elif simulation.school_developed_professions.get(actor.preferred_role(), false) and float(actor.skills.get(actor.preferred_role(), 0.0)) < 1.0:
		should_study = true

	return {
		"player_controlled": actor.is_player_controlled,
		"blocked_by_storage": actor.blocked_by_storage,
		"status_effects": actor.status_effect_labels(),
		"specialization": actor.specialization,
		"daily_order_role": actor.daily_order_role if actor.has_active_daily_order() else "",
		"daily_order_workday_id": actor.daily_order_workday_id,
		"training_role": actor.training_role,
		"training_days_completed": actor.training_days_completed,
		"permanent_role": actor.permanent_role,
		"pending_employment_role": actor.pending_employment_role,
		"skills": actor.skills,
		"should_study": should_study,
		"workforce_status": "unregistered" if actor.is_unregistered() else "registering" if actor.is_registering() else "active",
		"is_hero": actor.is_hero,
	}


func _world_data() -> Dictionary:
	@warning_ignore("integer_division")
	var current_hour: int = int(simulation.game_minutes) / 60
	return {
		"era": simulation.settlement.era,
		"hour": current_hour,
		"has_canteen": is_instance_valid(simulation.canteen),
		"cooking_jobs": simulation._available_employer_capacity("cook"),
		"schools": simulation.school_positions.size(),
		"markets": simulation.market_positions.size(),
		"builder_jobs": simulation._available_employer_capacity("construction"),
		"forestry_jobs": simulation._available_employer_capacity("forestry"),
		"farming_jobs": simulation._available_employer_capacity("farming"),
		"forager_jobs": simulation._available_employer_capacity("gather_food"),
		"materials_yard_jobs": simulation._available_employer_capacity("gather_branches"),
		"teacher_jobs": simulation._available_employer_capacity("teacher"),
		"seller_jobs": simulation._available_employer_capacity("seller"),
		"official_jobs": simulation._available_employer_capacity("official"),
		"factory_jobs": simulation._available_employer_capacity("factory_worker"),
		"engineer_jobs": simulation._available_employer_capacity("engineer"),
		"craftsman_jobs": simulation._available_employer_capacity("craftsman"),
		"courier_jobs": simulation._available_employer_capacity("courier"),
		"construction_sites": simulation.construction_sites.size() + simulation.demolition_sites.size(),
		"warehouses": simulation.warehouse_positions.size(),
		"sawmills": simulation.sawmill_positions.size(),
		"trees": simulation.tree_positions.size(),
		"farms": simulation.farm_positions.size(),
		"forager_tents": simulation.forager_positions.size(),
		"dig_sites": simulation._count_valid_dig_sites(),
		"has_factory_job": _factory_for_role_internal("factory_worker") != null,
		"has_engineer_job": _factory_for_role_internal("engineer") != null,
		"food": simulation.food,
		"water": simulation.water,
		"wood": simulation.wood,
		"ponds": simulation.pond_positions.size(),
		"has_bucket": bool(simulation.settlement.tools.get("bucket", false)),
		"population": simulation.citizens.size(),
		"assigned_roles": _assigned_role_counts_internal(),
		"officer_available": _officer_available_internal(),
		"workday_start_hour": 8,
	}


func _officer_available_internal() -> bool:
	for citizen in simulation.citizens:
		if is_instance_valid(citizen) and citizen.permanent_role == "official":
			return true
	return false


func _factory_job_capacity() -> int:
	var capacity := 0
	for factory in simulation.factories:
		if is_instance_valid(factory):
			capacity += int(factory.get_meta("required_factory_workers", 1))
	return capacity


func _engineer_job_capacity() -> int:
	var capacity := 0
	for factory in simulation.factories:
		if is_instance_valid(factory) and factory.get_meta("building_type", "") == "materials_factory":
			capacity += 1
	return capacity


func _assigned_role_counts_internal() -> Dictionary:
	var counts: Dictionary = {}
	for citizen in simulation.citizens:
		if citizen.is_player_controlled:
			continue
		if not citizen.permanent_role.is_empty() and is_instance_valid(citizen.employment_workplace) and not bool(citizen.employment_workplace.get_meta("accepting_workers", true)):
			continue
		var role: String = citizen.permanent_role
		if role.is_empty() and citizen.is_registering():
			role = citizen.pending_employment_role
		if role.is_empty() or role in ["trade", "relaxing", "training"]:
			continue
		if role == "gather_wood":
			role = "forestry"
		counts[role] = int(counts.get(role, 0)) + 1
	return counts


func _factory_for_role_internal(role: String) -> Node3D:
	if role == "factory_worker":
		for building_type in ["materials_factory", "brick_factory", "recycling_factory", "metal_factory"]:
			for factory in simulation.factories:
				if factory.get_meta("building_type", "") != building_type:
					continue
				var assigned_workers := 0
				for citizen in simulation.citizens:
					assigned_workers += 1 if simulation._is_factory_worker_active(citizen, factory) else 0
				if assigned_workers < int(factory.get_meta("required_factory_workers", 1)):
					return factory
	for factory in simulation.factories:
		if not is_instance_valid(factory):
			continue
		var building_type: String = factory.get_meta("building_type", "")
		if role == "factory_worker" and building_type in ["brick_factory", "materials_factory", "recycling_factory", "metal_factory"]:
			return factory
		if role == "engineer" and building_type == "materials_factory":
			return factory
	return null


func _role_employers() -> Dictionary:
	var employers := {}
	var employment_center: Vector3 = simulation._employment_center_position()
	var occupancy: Dictionary = {}
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen):
			continue
		var assigned_role: String = citizen.permanent_role if citizen.is_employed() else citizen.pending_employment_role
		var workplace: Node3D = citizen.employment_workplace if citizen.is_employed() else citizen.pending_employment_workplace
		if assigned_role.is_empty() or not is_instance_valid(workplace):
			continue
		var occupancy_key := "%s:%d" % [assigned_role, workplace.get_instance_id()]
		occupancy[occupancy_key] = int(occupancy.get(occupancy_key, 0)) + 1
	var roles := [
		"forestry", "farming", "construction", "gather_branches", "gather_food",
		"excavation", "cook", "teacher", "seller", "official", "craftsman",
		"factory_worker", "engineer"
	]
	for role in roles:
		var candidates: Array[Dictionary] = []
		for record in simulation.building_registry.records():
			var workplace: Node3D = record.node
			if not is_instance_valid(workplace) or str(workplace.get_meta("building_type", "")) not in simulation._employer_types_for_role(role):
				continue
			if not bool(workplace.get_meta("accepting_workers", true)):
				continue
			var occupied := int(occupancy.get("%s:%d" % [role, workplace.get_instance_id()], 0))
			var available_slots: int = simulation._employer_capacity(role, workplace) - occupied
			if available_slots > 0:
				var service_position: Vector3 = workplace.get_meta("service_position", workplace.global_position)
				if employment_center == Vector3.INF or not simulation._is_route_reachable(employment_center, service_position):
					continue
				candidates.append({
					"position": service_position,
					"target_key": _workplace_target_key(workplace),
					"available_slots": available_slots,
					"route_cost": _route_cost(employment_center, service_position),
				})
		if candidates.is_empty():
			var fallback: Node3D = simulation._employer_for_role(role)
			if is_instance_valid(fallback):
				candidates.append({
					"position": fallback.global_position,
					"target_key": _workplace_target_key(fallback),
					"available_slots": 1,
				})
		if not candidates.is_empty():
			candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
				return float(left.get("route_cost", INF)) < float(right.get("route_cost", INF))
			)
			employers[role] = candidates
	# Couriers are formally employed in the tent era but do not yet own a
	# workplace node. The employment centre is only the registration destination.
	var courier_slots: int = simulation._available_employer_capacity("courier") - int(_assigned_role_counts_internal().get("courier", 0))
	var centre_position: Vector3 = simulation._employment_center_position()
	if courier_slots > 0 and centre_position != Vector3.INF:
		employers["courier"] = [{
			"position": centre_position,
			"target_key": &"",
			"available_slots": courier_slots,
		}]
	return employers
