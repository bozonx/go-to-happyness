class_name SettlementAIWorldFacade
extends AIWorldFacade

## Scene adapter for the native AI. Each migrated mechanic adds only its owned
## facts here, without mirroring SettlementGame's private API.

const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var simulation: Node
var _route_cache := RouteCandidateCache.new()
var _helpers: FacadeTargetHelpers
var _construction_collector := ConstructionFactCollector.new()
var _forestry_collector := ForestryFactCollector.new()
var _farming_collector := FarmingFactCollector.new()
var _gathering_collector := GatheringFactCollector.new()
var _excavation_collector := ExcavationFactCollector.new()
var _service_collector := ServiceFactCollector.new()
var _factory_collector := FactoryFactCollector.new()
var _courier_collector := CourierFactCollector.new()
var _needs_collector := NeedsFactCollector.new()


func _init(next_simulation: Node = null) -> void:
	simulation = next_simulation
	_helpers = FacadeTargetHelpers.new(simulation, _route_cache)


func capture(sequence: int) -> WorldSnapshot:
	if not is_instance_valid(simulation):
		return WorldSnapshot.new(sequence)
	var canteen_service: CanteenService = simulation.canteen_service
	var courier_tasks: Array[Dictionary] = []
	if simulation.courier_dispatcher != null:
		for task: CourierTask in simulation.courier_dispatcher.available_tasks():
			courier_tasks.append({&"id": task.id, &"priority": task.priority, &"pickup": task.pickup, &"requested_courier_id": int(task.payload.get("courier_ai_id", 0))})


	var workforce_world := _world_data()
	var citizens_by_id: Dictionary = {}
	for actor: Citizen in simulation.citizens:
		if not is_instance_valid(actor) or actor.ai_id == 0 or simulation.outside_workers.has(actor.get_stable_id()):
			continue
		var citizen_id := actor.ai_id
		var actor_work_time: bool = simulation._is_citizen_work_time(actor)
		var daily_order_active := actor.has_active_daily_order() and not actor.is_player_controlled
		var daily_order_role := actor.daily_order_role if daily_order_active else ""
		var ctx := FacadeContext.new(simulation, _helpers, actor, citizen_id, actor_work_time, daily_order_active, daily_order_role)
		var needs_facts := _needs_collector.collect(ctx, canteen_service)
		var forestry_facts := _forestry_collector.collect(ctx)
		var farming_facts := _farming_collector.collect(ctx)
		var construction_facts := _construction_collector.collect(ctx)
		var gathering_facts := _gathering_collector.collect(ctx)
		var excavation_facts := _excavation_collector.collect(ctx)
		var service_facts := _service_collector.collect(ctx)
		var factory_facts := _factory_collector.collect(ctx)
		var courier_facts := _courier_collector.collect(ctx, courier_tasks)
		var squad_leader_pos := Vector3.INF
		if actor.squad_state.is_in_squad() and not actor.is_squad_leader():
			var leader: Citizen = _find_citizen_by_id(actor.squad_state.squad_leader_id)
			if is_instance_valid(leader):
				squad_leader_pos = leader.global_position
		var squad_facts := {
			&"squad.in_squad": actor.squad_state.is_in_squad(),
			&"squad.is_leader": actor.is_squad_leader(),
			&"squad.leader_position": squad_leader_pos,
		}

		var base_facts := AIFactSet.from_owned_values({
			&"work.permanent.active": actor.is_employed(),
			&"daily.order.active": daily_order_active,
			&"daily.order.role": daily_order_role,
			&"daily.order.workday_id": actor.daily_order_workday_id,
			&"daily.order.expires_at": actor.daily_order_expires_at,
			&"workforce.worker_data": _worker_data(actor),
			&"workforce.pending_workplace_key": _helpers.workplace_target_key(actor.pending_employment_workplace),
			&"workforce.pending_workplace_position": actor.pending_employment_workplace.global_position if is_instance_valid(actor.pending_employment_workplace) else Vector3.INF,
		})
		var merged_facts := base_facts \
			.merged(AIFactSet.from_owned_values(needs_facts)) \
			.merged(AIFactSet.from_owned_values(forestry_facts)) \
			.merged(AIFactSet.from_owned_values(farming_facts)) \
			.merged(AIFactSet.from_owned_values(construction_facts)) \
			.merged(AIFactSet.from_owned_values(gathering_facts)) \
			.merged(AIFactSet.from_owned_values(excavation_facts)) \
			.merged(AIFactSet.from_owned_values(service_facts)) \
			.merged(AIFactSet.from_owned_values(factory_facts)) \
			.merged(AIFactSet.from_owned_values(courier_facts)) \
			.merged(AIFactSet.from_owned_values(squad_facts))
		citizens_by_id[citizen_id] = CitizenSnapshot.new(
			citizen_id,
			actor.global_position,
			actor.is_player_controlled,
			not actor.is_player_controlled,
			merged_facts
		)
	var settlement_facts := AIFactSet.from_owned_values({
		&"population": citizens_by_id.size(),
		&"era": simulation.settlement.era,
		&"settlement.wellbeing": simulation.settlement.wellbeing,
		&"settlement.tools": simulation.settlement.tools.duplicate(true) if simulation.settlement != null else {},
		&"settlement.backpack": simulation.settlement.backpack.duplicate(true) if simulation.settlement != null else {},
		&"warehouse_positions_count": simulation.warehouse_positions.size() if simulation != null else 0,
		&"workforce.world_data": workforce_world,
		&"workforce.employment_center_position": simulation._employment_center_position(),
		&"workforce.role_employers": _role_employers(),
		&"work.courier.tasks": courier_tasks,
	})
	return WorldSnapshot.new(
		sequence,
		simulation.runtime_seconds,
		simulation.game_minutes,
		settlement_facts,
		citizens_by_id
	)


func _cached_route_candidates(key: StringName, origin: Vector3, producer: Callable) -> Array[Dictionary]:
	return _helpers.cached_route_candidates(key, origin, producer)


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
		"skills": actor.skills.duplicate(true),
		"should_study": should_study,
		"workforce_status": "unregistered" if actor.is_unregistered() else "registering" if actor.is_registering() else "no_permanent_work" if actor.has_no_permanent_work() else "active",
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
		"food": simulation.settlement.amount(ResourceIds.FOOD),
		"water": simulation.settlement.amount(ResourceIds.WATER),
		"wood": simulation.settlement.amount(ResourceIds.WOOD),
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
		if is_instance_valid(factory) and simulation.building_registry.building_type_for_node(factory) == "materials_factory":
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
		for building_type in BuildingTypes.FACTORY_TYPES:
			for factory in simulation.factories:
				if simulation.building_registry.building_type_for_node(factory) != building_type:
					continue
				var assigned_workers := 0
				for citizen in simulation.citizens:
					assigned_workers += 1 if simulation._is_factory_worker_active(citizen, factory) else 0
				if assigned_workers < int(factory.get_meta("required_factory_workers", 1)):
					return factory
	for factory in simulation.factories:
		if not is_instance_valid(factory):
			continue
		var building_type: String = simulation.building_registry.building_type_for_node(factory)
		if role == "factory_worker" and BuildingTypes.is_factory(building_type):
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
		var occupancy_key := "%s:%s" % [assigned_role, simulation._cell_from_position(workplace.global_position)]
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
			if not is_instance_valid(workplace) or record.building_type not in simulation._employer_types_for_role(role):
				continue
			if not bool(workplace.get_meta("accepting_workers", true)):
				continue
			var occupied := int(occupancy.get("%s:%s" % [role, simulation._cell_from_position(workplace.global_position)], 0))
			var available_slots: int = simulation._employer_capacity(role, workplace) - occupied
			if available_slots > 0:
				var service_position: Vector3 = workplace.get_meta("service_position", workplace.global_position)
				if employment_center == Vector3.INF or not simulation._is_route_reachable(employment_center, service_position):
					continue
				candidates.append({
					"position": service_position,
					"target_key": _helpers.workplace_target_key(workplace),
					"available_slots": available_slots,
					"route_cost": _helpers.route_cost(employment_center, service_position),
				})
		if candidates.is_empty():
			var fallback: Node3D = simulation._employer_for_role(role)
			if is_instance_valid(fallback):
				candidates.append({
					"position": fallback.global_position,
					"target_key": _helpers.workplace_target_key(fallback),
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


func _find_citizen_by_id(citizen_id: int) -> Citizen:
	if not is_instance_valid(simulation):
		return null
	for citizen: Citizen in simulation.citizens:
		if is_instance_valid(citizen) and citizen.ai_id == citizen_id:
			return citizen
	return null
