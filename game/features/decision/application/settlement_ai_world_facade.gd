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
	var citizens_by_id: Dictionary = {}
	for actor: Citizen in simulation.citizens:
		if not is_instance_valid(actor) or actor.ai_id == 0:
			continue
		var citizen_id := actor.ai_id
		var can_start_personal_need := not actor.has_active_arrival_task() and not actor.has_active_delivery()
		var needs_service: CitizenNeedsService = simulation.citizen_needs_service
		var rest_request := needs_service.rest_request(citizen_id) if needs_service != null else {}
		var relief_candidates: Array[Dictionary] = []
		if needs_service != null and needs_service.has_toilet_request(citizen_id):
			relief_candidates = needs_service.relief_candidates_for(actor)
		var forestry_worker := actor.permanent_role == "forestry" and actor.is_employed() and not actor.is_player_controlled
		var forestry_candidates: Array[Dictionary] = []
		var sawmill_position := Vector3.INF
		var warehouse_position := Vector3.INF
		if forestry_worker and simulation._is_work_time() and not simulation.sawmill_positions.is_empty() and not simulation.warehouse_positions.is_empty() and simulation._has_storage_room_for_role("forestry"):
			sawmill_position = actor.employment_workplace.get_meta("service_position", actor.employment_workplace.global_position) if is_instance_valid(actor.employment_workplace) else simulation.sawmill_positions[0]
			warehouse_position = simulation._get_nearest_delivery_position(actor.global_position)
			for tree_position in simulation.tree_positions:
				var cell: Vector2i = simulation._cell_from_position(tree_position)
				var tree: Node3D = simulation.tree_nodes.get(cell) as Node3D
				if not is_instance_valid(tree) or bool(tree.get_meta("felled", false)):
					continue
				var access_position: Vector3 = simulation._resource_access_position(actor.global_position, tree_position)
				if access_position == Vector3.INF:
					continue
				forestry_candidates.append({
					&"id": StringName("tree:%d:%d" % [cell.x, cell.y]),
					&"position": tree_position,
					&"access": access_position,
					&"sawmill_position": sawmill_position,
					&"warehouse_position": warehouse_position,
				})
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
		var construction_target_id := -1
		var construction_position := Vector3.INF
		if construction_in_progress:
			construction_mode = StringName(actor.active_role)
			construction_target_id = actor.construction_site.get_instance_id()
			construction_position = actor.construction_site.global_position
		elif construction_worker and simulation._is_work_time():
			if not simulation.demolition_sites.is_empty():
				var demolition_site: DemolitionSite = simulation.demolition_sites[(citizen_id - 1) % simulation.demolition_sites.size()]
				if is_instance_valid(demolition_site.building):
					construction_mode = &"demolition"
					construction_target_id = demolition_site.building.get_instance_id()
					construction_position = demolition_site.building.global_position
			elif simulation._preferred_construction_site() != null:
				var construction_site: ConstructionSite = simulation._preferred_construction_site()
				if construction_site.is_supplied() and is_instance_valid(construction_site.node):
					construction_mode = &"construction"
					construction_target_id = construction_site.node.get_instance_id()
					construction_position = construction_site.node.global_position
			construction_can_start = construction_target_id >= 0
		var gathering_worker := actor.permanent_role in ["gather_branches", "gather_food"] and actor.is_employed() and not actor.is_player_controlled
		var gathering_in_progress := gathering_worker and actor.active_role.begins_with("gather_") and actor.state in [Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_WAREHOUSE]
		var gathering_candidates: Array[Dictionary] = []
		if gathering_worker and simulation._is_work_time() and simulation._has_storage_room_for_role(actor.permanent_role):
			gathering_candidates = _gathering_candidates_for(actor)
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
					&"id": StringName("dig:%d" % dig_node.get_instance_id()),
					&"target_id": dig_node.get_instance_id(),
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
				&"work.construction.target_id": construction_target_id,
				&"work.construction.position": construction_position,
				&"work.gathering.worker": gathering_worker,
				&"work.gathering.in_progress": gathering_in_progress,
				&"work.gathering.candidates": gathering_candidates,
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
				&"work.factory.target_id": factory_node.get_instance_id() if is_instance_valid(factory_node) else -1,
				&"work.factory.position": factory_position,
			})
		)
	var settlement_facts := AIFactSet.new({
		&"population": citizens_by_id.size(),
		&"era": simulation.settlement.era,
	})
	return WorldSnapshot.new(
		sequence,
		simulation.runtime_seconds,
		simulation.game_minutes,
		settlement_facts,
		citizens_by_id
	)


func _gathering_candidates_for(actor: Citizen) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if actor.permanent_role == "gather_food":
		var forage_position: Vector3 = actor.employment_workplace.get_meta("service_position", actor.employment_workplace.global_position) if is_instance_valid(actor.employment_workplace) else Vector3.INF
		if forage_position != Vector3.INF and not simulation.warehouse_positions.is_empty():
			candidates.append({
				&"id": StringName("forage:%d" % actor.ai_id),
				&"resource_type": "food",
				&"position": forage_position,
				&"access": forage_position,
				&"warehouse_position": simulation._get_nearest_delivery_position(actor.global_position),
			})
		return candidates
	if actor.permanent_role != "gather_branches" or simulation.warehouse_positions.is_empty():
		return candidates
	if simulation.settlement.grass < simulation.settlement.branches:
		for grass_cell_value in simulation.grass_sources.keys():
			var grass_cell := grass_cell_value as Vector2i
			var grass_source := simulation.grass_sources.get(grass_cell, {}) as Dictionary
			var grass_node := grass_source.get(&"node") as Node3D
			if int(grass_source.get(&"remaining", 0)) <= 0 or not is_instance_valid(grass_node) or simulation.grass_reservations.has(grass_cell):
				continue
			candidates.append({
				&"id": StringName("grass:%d:%d" % [grass_cell.x, grass_cell.y]),
				&"resource_type": "grass",
				&"position": grass_node.global_position,
				&"access": grass_node.global_position,
				&"warehouse_position": simulation._get_nearest_delivery_position(actor.global_position),
			})
		if not candidates.is_empty():
			return candidates
	for tree_position in simulation.tree_positions:
		var tree_cell: Vector2i = simulation._cell_from_position(tree_position)
		if simulation.tree_reservations.has(tree_cell):
			continue
		var tree := simulation.tree_nodes.get(tree_cell) as Node3D
		if not is_instance_valid(tree) or bool(tree.get_meta("felled", false)) or int(tree.get_meta("remaining_branches", 0)) <= 0:
			continue
		var hand_limit := ceili(float(int(tree.get_meta("initial_branches", tree.get_meta("remaining_branches", 0)))) * 0.3)
		if not bool(simulation.settlement.tools.get("axe", false)) and int(tree.get_meta("hand_branches", 0)) >= hand_limit:
			continue
		var access_position: Vector3 = simulation._resource_access_position(actor.global_position, tree_position)
		if access_position == Vector3.INF:
			continue
		candidates.append({
			&"id": StringName("branch:%d:%d" % [tree_cell.x, tree_cell.y]),
			&"resource_type": "branches",
			&"position": tree_position,
			&"access": access_position,
			&"warehouse_position": simulation._get_nearest_delivery_position(actor.global_position),
		})
	return candidates
