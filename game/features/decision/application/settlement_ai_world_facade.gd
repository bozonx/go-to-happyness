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
	if simulation.courier_dispatcher != null and simulation._is_work_time():
		for task: CourierTask in simulation.courier_dispatcher.available_tasks():
			courier_tasks.append({&"id": task.id, &"priority": task.priority, &"pickup": task.pickup})
	var workforce_world := _world_data()
	var forestry_targets := _forestry_targets()
	var gathering_targets := _gathering_targets()
	var food_gathering_targets := _food_gathering_targets()
	var daily_gathering_cache: Dictionary = {"gather_food": food_gathering_targets}
	var citizens_by_id: Dictionary = {}
	for actor: Citizen in simulation.citizens:
		if not is_instance_valid(actor) or actor.ai_id == 0 or simulation.outside_workers.has(actor.get_instance_id()):
			continue
		var citizen_id := actor.ai_id
		var can_start_personal_need := not actor.has_active_arrival_task() and not actor.has_active_delivery()
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
		if forestry_worker and simulation._is_work_time() and not simulation.sawmill_positions.is_empty() and not simulation.warehouse_positions.is_empty() and simulation._has_storage_room_for_role("forestry"):
			sawmill_position = actor.employment_workplace.get_meta("service_position", actor.employment_workplace.global_position) if is_instance_valid(actor.employment_workplace) else simulation.sawmill_positions[0]
			warehouse_position = simulation._get_nearest_delivery_position(actor.global_position)
		var forestry_in_progress := actor.state in [Citizen.State.TO_TREE, Citizen.State.CHOPPING, Citizen.State.TO_SAWMILL]
		var farming_worker := actor.permanent_role == "farming" and actor.is_employed() and not actor.is_player_controlled
		var farming_in_progress := farming_worker and actor.active_role == "farming" and actor.state in [Citizen.State.TO_TREE, Citizen.State.TO_SAWMILL, Citizen.State.SAWING, Citizen.State.WAITING_COURIER]
		var farming_position := Vector3.INF
		var farming_warehouse_position := Vector3.INF
		if farming_in_progress:
			farming_position = actor.workplace_position
			farming_warehouse_position = actor.warehouse_position
		elif farming_worker and not simulation.farm_positions.is_empty() and not simulation.warehouse_positions.is_empty():
			farming_position = actor.employment_workplace.get_meta("service_position", actor.employment_workplace.global_position) if is_instance_valid(actor.employment_workplace) else simulation.farm_positions[0]
			farming_warehouse_position = simulation._get_nearest_delivery_position(actor.global_position)
		var farming_can_start: bool = farming_worker and simulation._is_work_time() and simulation._has_storage_room_for_role("farming") and farming_position != Vector3.INF and farming_warehouse_position != Vector3.INF
		var construction_worker := actor.permanent_role == "construction" and actor.is_employed() and not actor.is_player_controlled
		var construction_in_progress := construction_worker and actor.active_role in ["construction", "demolition"] and actor.state == Citizen.State.CONSTRUCTING and is_instance_valid(actor.construction_site)
		var construction_can_start := false
		var construction_mode: StringName = &""
		var construction_target_key: StringName = &""
		var construction_position := Vector3.INF
		if construction_in_progress:
			construction_mode = StringName(actor.active_role)
			construction_target_key = _target_key(&"construction", actor.construction_site.global_position)
			construction_position = actor.construction_site.global_position
		elif construction_worker and simulation._is_work_time():
			if not simulation.demolition_sites.is_empty():
				var demolition_site: DemolitionSite = simulation.demolition_sites[(citizen_id - 1) % simulation.demolition_sites.size()]
				if is_instance_valid(demolition_site.building):
					construction_mode = &"demolition"
					construction_target_key = _target_key(&"demolition", demolition_site.building.global_position)
					construction_position = demolition_site.building.global_position
			elif simulation._preferred_construction_site() != null:
				var construction_site: ConstructionSite = simulation._preferred_construction_site()
				if construction_site.is_supplied() and is_instance_valid(construction_site.node):
					construction_mode = &"construction"
					construction_target_key = _target_key(&"construction", construction_site.node.global_position)
					construction_position = construction_site.node.global_position
			construction_can_start = construction_target_key != &""
		var daily_construction_in_progress := daily_order_active and daily_order_role == "construction" and actor.active_role in ["construction", "demolition"] and actor.state == Citizen.State.CONSTRUCTING and is_instance_valid(actor.construction_site)
		var daily_construction_can_start := false
		var daily_construction_mode: StringName = &""
		var daily_construction_target_key: StringName = &""
		var daily_construction_position := Vector3.INF
		if daily_construction_in_progress:
			daily_construction_mode = StringName(actor.active_role)
			daily_construction_target_key = _target_key(&"construction", actor.construction_site.global_position)
			daily_construction_position = actor.construction_site.global_position
		elif daily_order_role == "construction":
			if not simulation.demolition_sites.is_empty():
				var daily_demolition_site: DemolitionSite = simulation.demolition_sites[(citizen_id - 1) % simulation.demolition_sites.size()]
				if is_instance_valid(daily_demolition_site.building):
					daily_construction_mode = &"demolition"
					daily_construction_target_key = _target_key(&"demolition", daily_demolition_site.building.global_position)
					daily_construction_position = daily_demolition_site.building.global_position
			elif simulation._preferred_construction_site() != null:
				var daily_construction_site: ConstructionSite = simulation._preferred_construction_site()
				if daily_construction_site.is_supplied() and is_instance_valid(daily_construction_site.node):
					daily_construction_mode = &"construction"
					daily_construction_target_key = _target_key(&"construction", daily_construction_site.node.global_position)
					daily_construction_position = daily_construction_site.node.global_position
				daily_construction_can_start = daily_construction_target_key != &""
		var gathering_worker: bool = actor.permanent_role in ["gather_branches", "gather_food"] and actor.is_employed() and not actor.is_player_controlled
		var gathering_in_progress: bool = gathering_worker and actor.active_role.begins_with("gather_") and actor.state in [Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_WAREHOUSE]
		var gathering_candidates: Array[Dictionary] = []
		if gathering_worker and simulation._is_work_time() and simulation._has_storage_room_for_role(actor.permanent_role):
			if actor.permanent_role == "gather_food":
				gathering_candidates = food_gathering_targets
		var daily_gathering_in_progress := daily_order_active and daily_order_role.begins_with("gather_") and actor.active_role.begins_with("gather_") and actor.state in [Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_WAREHOUSE]
		var daily_gathering_candidates: Array[Dictionary] = []
		if daily_order_role.begins_with("gather_") and simulation._has_storage_room_for_role(daily_order_role):
			if daily_order_role == "gather_water":
				daily_gathering_candidates = _daily_gathering_targets_for(actor, daily_order_role, food_gathering_targets)
			elif daily_gathering_cache.has(daily_order_role):
				daily_gathering_candidates = (daily_gathering_cache[daily_order_role] as Array[Dictionary]).duplicate(false)
			else:
				daily_gathering_candidates = _daily_gathering_targets_for(actor, daily_order_role, food_gathering_targets)
				daily_gathering_cache[daily_order_role] = daily_gathering_candidates
		var daily_gathering_can_start := daily_order_active and daily_order_role.begins_with("gather_") and not daily_gathering_candidates.is_empty()
		var excavation_worker := actor.permanent_role == "excavation" and actor.is_employed() and not actor.is_player_controlled
		var excavation_in_progress := excavation_worker and actor.active_role == "excavation" and actor.state in [Citizen.State.EXCAVATING, Citizen.State.WAITING_COURIER]
		var excavation_candidates: Array[Dictionary] = []
		if excavation_worker and simulation._is_work_time():
			for dig_site_value in simulation.dig_sites:
				var dig_site := dig_site_value as Dictionary
				var dig_node := dig_site.get(&"node") as Node3D
				if not is_instance_valid(dig_node) or not simulation._can_work_at_dig_site(dig_site):
					continue
				excavation_candidates.append({
					&"id": _target_key(&"dig", dig_node.global_position),
					&"target_key": _target_key(&"dig", dig_node.global_position),
					&"position": dig_node.global_position,
				})
		var service_worker := actor.permanent_role in ["cook", "teacher", "seller", "official", "craftsman"] and actor.is_employed() and not actor.is_player_controlled
		var service_states := {
			"cook": [Citizen.State.TO_CANTEEN_WORK, Citizen.State.CANTEEN_WORK],
			"teacher": [Citizen.State.TO_SCHOOL_WORK, Citizen.State.SCHOOL_WORK],
			"seller": [Citizen.State.TO_MARKET_WORK, Citizen.State.MARKET_WORK],
			"official": [Citizen.State.TO_OFFICIAL_WORK, Citizen.State.OFFICIAL_WORK],
			"craftsman": [Citizen.State.TO_CRAFT_WORK, Citizen.State.CRAFT_WORK],
		}
		var service_in_progress: bool = service_worker and actor.state in (service_states.get(actor.permanent_role, []) as Array)
		var service_position: Vector3 = Vector3.INF
		if service_in_progress:
			match actor.permanent_role:
				"cook": service_position = actor.canteen_position
				"teacher": service_position = actor.school_position
				"seller": service_position = actor.market_position
				"official": service_position = actor.official_position
				"craftsman": service_position = actor.craft_position
		elif service_worker and simulation._is_work_time():
			service_position = actor.employment_workplace.get_meta("service_position", actor.employment_workplace.global_position) if is_instance_valid(actor.employment_workplace) else Vector3.INF
			if actor.permanent_role == "official":
				service_position = simulation._employment_center_position()
		var service_can_start: bool = service_worker and service_position != Vector3.INF
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
		elif factory_worker and simulation._is_work_time() and is_instance_valid(actor.employment_workplace):
			factory_role = &"factory_work" if actor.permanent_role == "factory_worker" else &"engineering"
			factory_node = actor.employment_workplace as Node3D
		elif actor.permanent_role == "construction" and actor.specialization == "builder" and simulation._is_work_time() and simulation.construction_sites.is_empty() and simulation.demolition_sites.is_empty():
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
		var courier_can_start: bool = courier_worker and actor.state == Citizen.State.IDLE and simulation._is_work_time()
		citizens_by_id[citizen_id] = CitizenSnapshot.new(
			citizen_id,
			actor.global_position,
			actor.is_player_controlled,
			not actor.is_player_controlled,
			AIFactSet.new({
				&"hero": actor.is_hero,
				&"needs.should_sleep": not simulation._is_work_time() and not actor.overtime_mode,
				&"needs.has_home": is_instance_valid(actor.home),
				&"needs.can_start_sleep": can_start_personal_need,
				&"needs.meal_requested": canteen_service != null and canteen_service.is_meal_requested(citizen_id),
				&"needs.can_start_meal": canteen_service != null and can_start_personal_need and is_instance_valid(simulation.canteen),
				&"needs.canteen_position": simulation.canteen_position,
				&"needs.toilet_requested": needs_service != null and needs_service.has_toilet_request(citizen_id),
				&"needs.relief_candidates": relief_candidates,
				&"needs.rest_requested": needs_service != null and needs_service.has_rest_request(citizen_id),
				&"needs.can_start_rest": can_start_personal_need and actor.state in [Citizen.State.IDLE, Citizen.State.WAITING],
				&"needs.rest_position": rest_request.get(&"position", Vector3.INF),
				&"needs.rest_duration": rest_request.get(&"duration", 4.0),
				&"work.forestry.worker": forestry_worker,
				&"work.forestry.in_progress": forestry_in_progress,
				&"work.forestry.can_start": sawmill_position != Vector3.INF and warehouse_position != Vector3.INF,
				&"work.forestry.sawmill_position": sawmill_position,
				&"work.forestry.warehouse_position": warehouse_position,
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
				&"work.gathering.can_start": gathering_worker and simulation._is_work_time() and simulation._has_storage_room_for_role(actor.permanent_role),
				&"work.gathering.role": StringName(actor.permanent_role) if gathering_worker else &"",
				&"work.gathering.candidates": gathering_candidates,
				&"work.gathering.warehouse_position": simulation._get_nearest_delivery_position(actor.global_position) if gathering_worker else Vector3.INF,
				&"work.excavation.worker": excavation_worker,
				&"work.excavation.in_progress": excavation_in_progress,
				&"work.excavation.candidates": excavation_candidates,
				&"work.service.worker": service_worker,
				&"work.service.in_progress": service_in_progress,
				&"work.service.can_start": service_can_start,
				&"work.service.role": StringName(actor.permanent_role) if service_worker else &"",
				&"work.service.position": service_position,
				&"work.factory.worker": factory_worker or factory_role == &"construction",
				&"work.factory.in_progress": factory_in_progress,
				&"work.factory.can_start": factory_can_start,
				&"work.factory.role": factory_role,
				&"work.factory.target_key": _target_key(&"factory", factory_node.global_position) if is_instance_valid(factory_node) else &"",
				&"work.factory.position": factory_position,
				&"work.courier.worker": courier_worker,
				&"work.courier.can_start": courier_can_start,
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
				&"daily.gathering.warehouse_position": simulation._get_nearest_delivery_position(actor.global_position) if daily_order_role.begins_with("gather_") else Vector3.INF,
				&"workforce.worker_data": worker_data,
				&"workforce.pending_workplace_key": _workplace_target_key(actor.pending_employment_workplace),
				&"workforce.pending_workplace_position": actor.pending_employment_workplace.global_position if is_instance_valid(actor.pending_employment_workplace) else Vector3.INF,
			})
		)
	var settlement_facts := AIFactSet.new({
		&"population": citizens_by_id.size(),
		&"era": simulation.settlement.era,
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


func _forestry_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if not simulation._is_work_time():
		return targets
	for tree_position: Vector3 in simulation.tree_positions:
		var cell: Vector2i = simulation._cell_from_position(tree_position)
		var tree: Node3D = simulation.tree_nodes.get(cell) as Node3D
		if not is_instance_valid(tree) or bool(tree.get_meta("felled", false)):
			continue
		var access := _resource_access_position(tree_position)
		if access != Vector3.INF:
			targets.append({&"id": StringName("tree:%d:%d" % [cell.x, cell.y]), &"position": tree_position, &"access": access})
	return targets


func _gathering_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if not simulation._is_work_time():
		return targets
	if simulation.settlement.grass < simulation.settlement.branches:
		for grass_cell_value in simulation.grass_sources.keys():
			var grass_cell := grass_cell_value as Vector2i
			var grass_source := simulation.grass_sources.get(grass_cell, {}) as Dictionary
			var grass_node := grass_source.get(&"node") as Node3D
			if int(grass_source.get(&"remaining", 0)) > 0 and is_instance_valid(grass_node):
				targets.append({&"id": StringName("grass:%d:%d" % [grass_cell.x, grass_cell.y]), &"resource_type": "grass", &"position": grass_node.global_position, &"access": grass_node.global_position})
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


func _resource_access_position(resource_position: Vector3) -> Vector3:
	var resource_cell: Vector2i = simulation._cell_from_position(resource_position)
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var cell: Vector2i = resource_cell + offset
		if simulation._is_board_cell(cell) and not simulation._is_navigation_cell_blocked(cell):
			return simulation._cell_center(cell)
	return Vector3.INF


func _workplace_target_key(workplace: Node3D) -> StringName:
	if not is_instance_valid(workplace):
		return &""
	if workplace == simulation._dig_site_for_node(workplace).get(&"node"):
		return _target_key(&"dig", workplace.global_position)
	return _target_key(&"building", workplace.global_position)


func _food_gathering_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if not simulation._is_work_time() or simulation.forager_positions.is_empty() or simulation.warehouse_positions.is_empty():
		return targets
	for cell_value in simulation.forage_sources:
		var cell := cell_value as Vector2i
		var node := (simulation.forage_sources[cell] as Dictionary).get("node") as Node3D
		if is_instance_valid(node):
			targets.append({&"id": StringName("plant:%d:%d" % [cell.x, cell.y]), &"resource_type": "food", &"position": node.global_position, &"access": node.global_position})
	for cell_value in simulation.rabbit_sources:
		var cell := cell_value as Vector2i
		var node := (simulation.rabbit_sources[cell] as Dictionary).get("node") as Node3D
		if is_instance_valid(node):
			targets.append({&"id": StringName("rabbit:%d:%d" % [cell.x, cell.y]), &"resource_type": "food", &"position": node.global_position, &"access": node.global_position})
	return targets


func _daily_gathering_targets_for(actor: Citizen, role: String, food_targets: Array[Dictionary]) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	match role:
		"gather_branches":
			for tree_position: Vector3 in simulation.tree_positions:
				var tree_cell: Vector2i = simulation._cell_from_position(tree_position)
				var tree := simulation.tree_nodes.get(tree_cell) as Node3D
				if not is_instance_valid(tree) or bool(tree.get_meta("felled", false)) or int(tree.get_meta("remaining_branches", 0)) <= 0:
					continue
				var access := _resource_access_position(tree_position)
				if access != Vector3.INF:
					targets.append({&"id": StringName("branch:%d:%d" % [tree_cell.x, tree_cell.y]), &"resource_type": "branches", &"position": tree_position, &"access": access})
		"gather_grass":
			for grass_cell_value in simulation.grass_sources.keys():
				var grass_cell := grass_cell_value as Vector2i
				var grass_source := simulation.grass_sources.get(grass_cell, {}) as Dictionary
				var grass_node := grass_source.get(&"node") as Node3D
				if int(grass_source.get(&"remaining", 0)) > 0 and is_instance_valid(grass_node):
					targets.append({&"id": StringName("grass:%d:%d" % [grass_cell.x, grass_cell.y]), &"resource_type": "grass", &"position": grass_node.global_position, &"access": grass_node.global_position})
		"gather_food":
			targets = food_targets.duplicate(true)
		"gather_dew":
			for collector: Dictionary in simulation.water_collectors:
				if int(collector.get("stored", 0)) <= 0:
					continue
				var collector_node := collector.get("node") as Node3D
				if is_instance_valid(collector_node):
					var position: Vector3 = collector_node.get_meta("service_position", collector_node.global_position)
					targets.append({&"id": _target_key(&"dew", position), &"resource_type": "water", &"position": position, &"access": position})
		"gather_water":
			for pond_position: Vector3 in simulation.pond_positions:
				var access: Vector3 = simulation._pond_access_position(actor.global_position, pond_position)
				if access != Vector3.INF:
					targets.append({&"id": _target_key(&"water", access), &"resource_type": "water", &"position": access, &"access": access})
	return targets


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
		"has_collected_dew": simulation._has_collected_dew(),
		"has_bucket": bool(simulation.settlement.tools.get("bucket", false)),
		"has_filter": bool(simulation.settlement.tools.get("filter_1", false)),
		"population": simulation.citizens.size(),
		"assigned_roles": _assigned_role_counts_internal(),
		"officer_available": _officer_available_internal(),
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
		if role.is_empty():
			role = citizen.active_role
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
				candidates.append({
					"position": workplace.global_position,
					"target_key": _workplace_target_key(workplace),
					"available_slots": available_slots,
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
			employers[role] = candidates
	return employers
