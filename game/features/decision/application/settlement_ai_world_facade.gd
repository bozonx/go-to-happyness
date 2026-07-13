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
