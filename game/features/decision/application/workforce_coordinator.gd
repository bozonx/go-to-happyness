class_name WorkforceCoordinator
extends Node

## Schedules citizens while keeping scene-specific state behind MainSimulation's API.
## This is intentionally a Node so it can later own timers, signals and debug UI.

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


const BUSY_STATES := [
	Citizen.State.TO_CANTEEN, Citizen.State.EATING, Citizen.State.TO_FOOD_PICKUP,
	Citizen.State.TO_CANTEEN_DELIVERY, Citizen.State.COURIER_TO_WORKER,
	Citizen.State.COURIER_TO_WAREHOUSE, Citizen.State.COURIER_TO_SAWMILL,
	Citizen.State.WAITING_COURIER,
	Citizen.State.TO_CANTEEN_WORK, Citizen.State.CANTEEN_WORK,
	Citizen.State.TO_SCHOOL_WORK, Citizen.State.SCHOOL_WORK,
	Citizen.State.TO_MARKET_WORK, Citizen.State.MARKET_WORK,
	Citizen.State.TO_TRADE_PICKUP, Citizen.State.TO_TRADE_DESTINATION,
	Citizen.State.TO_OFFICIAL_WORK, Citizen.State.OFFICIAL_WORK
]


func update_workers() -> void:
	if not simulation._is_work_time():
		for citizen in simulation.citizens:
			citizen.request_goap_decision()
		return
	var sorted_citizens := _get_sorted_citizens()
	for citizen in sorted_citizens:
		if citizen.is_player_controlled:
			continue
		if citizen.employment_state == Citizen.EmploymentState.REGISTERING and not citizen.pending_employment_role.is_empty() and not _employer_exists(citizen.pending_employment_role):
			citizen.queue_employment_processing()
			continue
		if citizen.employment_state == Citizen.EmploymentState.REGISTERING and citizen.state in [Citizen.State.IDLE, Citizen.State.RESTING, Citizen.State.TO_HOME]:
			if _can_finish_registration_today(citizen):
				citizen.begin_employment_processing(simulation._employment_center_position(), citizen.pending_employment_role, citizen.pending_employment_workplace)
			continue
		if citizen.state in [Citizen.State.TO_EMPLOYMENT_CENTER, Citizen.State.EMPLOYMENT_PROCESSING]:
			_update_employment_processing(citizen)
			continue
		# Couriers and service runs keep their current task; an automatic courier is
		# considered for a vacancy only after its delivery has completed.
		if citizen.state in BUSY_STATES or citizen.state == Citizen.State.WAITING:
			continue
		if citizen.no_work_wait_complete:
			citizen.no_work_wait_complete = false
		if citizen.blocked_by_storage:
			if not simulation.settlement.reserve_storage_room_for(citizen.resource_type, maxi(1, citizen.carried_amount), simulation.warehouse_positions.size()):
				citizen.begin_waiting()
				continue
			citizen.blocked_by_storage = false
		if citizen.employment_state == Citizen.EmploymentState.EMPLOYED:
			if not _employer_exists(citizen.permanent_role):
				_release_employment(citizen)
				continue
			if can_assign_work(citizen) and citizen.state in [Citizen.State.IDLE, Citizen.State.RESTING]:
				citizen.request_goap_decision()
			continue
		if citizen.employment_state == Citizen.EmploymentState.UNREGISTERED:
			continue
		if citizen.employment_state != Citizen.EmploymentState.FREELANCE:
			continue
		# Pinned couriers are dispatched by logistics and must not enter the
		# generic work scorer while they are waiting for an order.
		if citizen.freelance_assignment == "courier":
			continue
		if can_assign_work(citizen):
			# Pull free citizens onto work: the genuinely idle and the ones resting
			# at home (morning wake-up / rest-fallback from an earlier work drought).
			# Park breaks (RELAXING) and active work states are left alone.
			if citizen.state == Citizen.State.IDLE or citizen.state == Citizen.State.RESTING:
				citizen.request_goap_decision()
		else:
			citizen.begin_waiting()


func _update_employment_processing(_citizen: Citizen) -> void:
	pass


func _can_finish_registration_today(citizen: Citizen) -> bool:
	var center: Vector3 = simulation._employment_center_position()
	if center == Vector3.INF:
		return false
	var minutes_to_walk: float = citizen.global_position.distance_to(center) / Citizen.WALK_SPEED * float(simulation.GAME_MINUTES_PER_SECOND)
	var shift_end := 8.0 + float(simulation.settlement.workday_hours)
	var process_minutes: float = simulation._registration_duration() * float(simulation.GAME_MINUTES_PER_SECOND)
	var finish_hour: float = float(simulation.game_minutes) / 60.0 + (minutes_to_walk + process_minutes) / 60.0
	return finish_hour <= shift_end

func _get_sorted_citizens() -> Array[Citizen]:
	var list: Array[Citizen] = []
	for citizen in simulation.citizens:
		list.append(citizen)
	var early_construction: bool = simulation.settlement.era < SettlementState.Era.STONE and not simulation.construction_sites.is_empty()
	list.sort_custom(func(a: Citizen, b: Citizen):
		var a_pref := "construction" if early_construction else a.preferred_role()
		var b_pref := "construction" if early_construction else b.preferred_role()
		var a_skill := float(a.skills.get(a_pref, 0.0))
		var b_skill := float(b.skills.get(b_pref, 0.0))
		return a_skill > b_skill
	)
	return list


func _employer_exists(role: String) -> bool:
	match role:
		"construction":
			if simulation.settlement.era < SettlementState.Era.STONE:
				return not simulation.construction_sites.is_empty() or not simulation.demolition_sites.is_empty()
			return int(_world_data().get("builder_jobs", 0)) > 0
		"forestry": return not simulation.sawmill_positions.is_empty()
		"farming": return not simulation.farm_positions.is_empty()
		"gather_food": return not simulation.forager_positions.is_empty()
		"cook": return is_instance_valid(simulation.canteen)
		"teacher": return not simulation.school_positions.is_empty()
		"seller": return not simulation.market_positions.is_empty()
		"factory_worker": return _factory_job_capacity() > 0
		"engineer": return _engineer_job_capacity() > 0
		"official": return is_instance_valid(simulation._employment_centre_building())
	return true


func _release_employment(citizen: Citizen) -> void:
	# The workplace disappeared out from under the worker — a change the player
	# did not choose. Return them to the reserve pool so they immediately look for
	# other work instead of becoming a permanently idle "unemployed" body.
	if citizen.permanent_role == "official":
		# The appointment belongs to the settlement, not to a demolished civic
		# building. Keep it ready for the next campfire/town-hall upgrade.
		citizen.idle()
		citizen.employment_workplace = null
		return
	citizen.idle()
	citizen.release_to_freelance()


func can_assign_work(citizen: Citizen) -> bool:
	if not WorkforcePolicy.can_assign(_worker_data(citizen), _world_data()):
		return false
	return simulation._has_storage_room_for_role(work_role_for(citizen))


func assign_work(citizen: Citizen, index: int) -> void:
	if not can_assign_work(citizen):
		return
	var role := work_role_for(citizen)
	if role == "cook":
		citizen.assign_canteen_work(_workplace_position(citizen, simulation.canteen_position))
		return
	if role == "teacher":
		citizen.assign_teacher_work(_workplace_position(citizen, simulation.school_positions[0]))
		return
	if role == "seller":
		if not simulation.market_positions.is_empty():
			var market_pos: Vector3 = _workplace_position(citizen, simulation.market_positions[index % simulation.market_positions.size()])
			citizen.assign_seller_work(market_pos)
		return
	if role == "official":
		if is_instance_valid(citizen.employment_workplace):
			citizen.assign_official_work(_workplace_position(citizen, simulation._employment_center_position()))
		return
	if role == "factory_worker":
		var factory_worker_node: Node3D = citizen.employment_workplace if is_instance_valid(citizen.employment_workplace) else factory_for_role("factory_worker")
		citizen.assign_factory_work(factory_worker_node, "factory_work")
		return
	if role == "engineer":
		var engineer_node: Node3D = citizen.employment_workplace if is_instance_valid(citizen.employment_workplace) else factory_for_role("engineer")
		citizen.assign_factory_work(engineer_node, "engineering")
		return
	var should_study := false
	var target_role := ""
	if not citizen.training_role.is_empty() and citizen.training_days_completed < 10:
		should_study = true
		target_role = citizen.training_role
	elif simulation.school_developed_professions.get(citizen.preferred_role(), false) and float(citizen.skills.get(citizen.preferred_role(), 0.0)) < 1.0:
		should_study = true
		target_role = citizen.preferred_role()

	@warning_ignore("integer_division")
	var current_hour: int = int(simulation.game_minutes) / 60
	if should_study and not simulation.school_positions.is_empty() and current_hour < 12:
		citizen.attend_school(simulation.school_positions[0], target_role)
		return
	if citizen.specialization == "builder" and simulation.construction_sites.is_empty():
		if not simulation.demolition_sites.is_empty():
			citizen.assign_demolition(simulation.demolition_sites[index % simulation.demolition_sites.size()].building)
			return
		var materials_plant := factory_for_role("engineer")
		if materials_plant != null:
			citizen.assign_factory_work(materials_plant, "construction")
			return
	match role:
		"construction":
			if not simulation.demolition_sites.is_empty():
				citizen.assign_demolition(simulation.demolition_sites[index % simulation.demolition_sites.size()].building)
			else:
				var construction: ConstructionSite = simulation._preferred_construction_site()
				if construction == null:
					return
				if not construction.is_supplied() and simulation._assign_construction_support(citizen, construction):
					return
				citizen.assign_construction(construction.node)
		"forestry":
			var tree_position: Vector3 = simulation._reserve_closest_tree_for_sawmill(citizen, Vector3.ZERO)
			if tree_position != Vector3.INF:
				var tree_access: Vector3 = simulation._resource_access_position(citizen.global_position, tree_position)
				if simulation.sawmill_positions.is_empty():
					if tree_access != Vector3.INF:
						citizen.assign_gathering("logs", tree_position, simulation._get_delivery_position(), tree_access)
				else:
					var sawmill_position: Vector3 = _workplace_position(citizen, simulation.sawmill_positions[index % simulation.sawmill_positions.size()])
					if tree_access != Vector3.INF:
						citizen.assign_work("wood", tree_position, sawmill_position, simulation.warehouse_positions[index % simulation.warehouse_positions.size()], false, tree_access)
		"farming":
			var farm_position: Vector3 = _workplace_position(citizen, simulation.farm_positions[index % simulation.farm_positions.size()])
			# Farm output is always collected by couriers; production staff never
			# switch to transport when the courier pool is empty.
			citizen.assign_work("food", farm_position, farm_position, simulation.warehouse_positions[index % simulation.warehouse_positions.size()], true)
		"excavation":
			var dig_site := citizen.employment_workplace if is_instance_valid(citizen.employment_workplace) else citizen.assigned_dig_site
			if not is_instance_valid(dig_site) or not simulation._can_work_at_dig_site(simulation._dig_site_for_node(dig_site)):
				# Find the first valid dig site
				var valid_sites := []
				for site in simulation.dig_sites:
					if simulation._can_work_at_dig_site(site):
						valid_sites.append(site.node)
				if not valid_sites.is_empty():
					dig_site = valid_sites[index % valid_sites.size()]
				else:
					dig_site = null
			if is_instance_valid(dig_site):
				citizen.assign_excavation(dig_site)
		"gather_branches":
			var tree_pos: Vector3 = simulation._find_closest_tree_for_citizen(citizen)
			if tree_pos != Vector3.INF:
				var tree_access: Vector3 = simulation._resource_access_position(citizen.global_position, tree_pos)
				if tree_access != Vector3.INF:
					citizen.assign_gathering("branches", tree_pos, simulation._get_delivery_position(), tree_access)
		"gather_grass":
			var grass_pos: Vector3 = simulation._find_grass_gathering_position(citizen)
			if grass_pos != Vector3.INF:
				citizen.assign_gathering("grass", grass_pos, simulation._get_delivery_position())
		"gather_food":
			var forage_pos: Vector3 = _workplace_position(citizen, simulation._find_forage_position(citizen))
			if forage_pos != Vector3.INF:
				citizen.assign_gathering("food", forage_pos, simulation._get_delivery_position())
		"gather_dew":
			var collector_position: Vector3 = simulation._reserve_dew_collector()
			if collector_position != Vector3.INF:
				citizen.assign_gathering("water", collector_position, simulation._get_delivery_position())
		"gather_water":
			if not simulation.pond_positions.is_empty():
				var pond_center: Vector3 = simulation.pond_positions[index % simulation.pond_positions.size()]
				var pond_access: Vector3 = simulation._pond_access_position(citizen.global_position, pond_center)
				if pond_access != Vector3.INF:
					citizen.assign_gathering("water", pond_access, simulation._get_delivery_position())
		"craftsman":
			if not simulation.craft_tent_positions.is_empty():
				var craft_pos: Vector3 = _workplace_position(citizen, simulation.craft_tent_positions[index % simulation.craft_tent_positions.size()])
				citizen.assign_craft_work(craft_pos)
	# A role can be available in policy while its concrete source is exhausted.
	# Keep the freelance worker available for a later task instead of changing
	# their employment status.
	if citizen.state == Citizen.State.IDLE or citizen.state == Citizen.State.RESTING:
		citizen.begin_waiting()


func _workplace_position(citizen: Citizen, fallback: Vector3) -> Vector3:
	if is_instance_valid(citizen.employment_workplace):
		return citizen.employment_workplace.get_meta("service_position", citizen.employment_workplace.global_position)
	return fallback


func work_role_for(citizen: Citizen) -> String:
	return WorkforcePolicy.role_for(_worker_data(citizen), _world_data())


func _worker_data(citizen: Citizen) -> Dictionary:
	var should_study := false
	if not citizen.training_role.is_empty() and citizen.training_days_completed < 10:
		should_study = true
	elif simulation.school_developed_professions.get(citizen.preferred_role(), false) and float(citizen.skills.get(citizen.preferred_role(), 0.0)) < 1.0:
		should_study = true
		
	return {
		"player_controlled": citizen.is_player_controlled,
		"blocked_by_storage": citizen.blocked_by_storage,
		"specialization": citizen.specialization,
		"manual_role": citizen.manual_role,
		"freelance_assignment": citizen.freelance_assignment,
		"training_role": citizen.training_role,
		"training_days_completed": citizen.training_days_completed,
		"permanent_role": citizen.permanent_role,
		"skills": citizen.skills,
		"should_study": should_study,
		"workforce_status": "unregistered" if citizen.employment_state == Citizen.EmploymentState.UNREGISTERED else "active",
		"is_hero": citizen.is_hero,
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
		"teacher_jobs": simulation._available_employer_capacity("teacher"),
		"seller_jobs": simulation._available_employer_capacity("seller"),
		"official_jobs": simulation._available_employer_capacity("official"),
		"factory_jobs": simulation._available_employer_capacity("factory_worker"),
		"engineer_jobs": simulation._available_employer_capacity("engineer"),
		"construction_sites": simulation.construction_sites.size() + simulation.demolition_sites.size(),
		"warehouses": simulation.warehouse_positions.size(),
		"sawmills": simulation.sawmill_positions.size(),
		"trees": simulation.tree_positions.size(),
		"farms": simulation.farm_positions.size(),
		"forager_tents": simulation.forager_positions.size(),
		"dig_sites": simulation._count_valid_dig_sites(),
		"has_factory_job": factory_for_role("factory_worker") != null,
		"has_engineer_job": factory_for_role("engineer") != null,
		"food": simulation.food,
		"water": simulation.water,
		"wood": simulation.wood,
		"ponds": simulation.pond_positions.size(),
		"has_collected_dew": simulation._has_collected_dew(),
		"has_bucket": bool(simulation.settlement.tools.get("bucket", false)),
		"has_filter": bool(simulation.settlement.tools.get("filter_1", false)),
		"population": simulation.citizens.size(),
		"assigned_roles": _assigned_role_counts(),
	}


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


func _assigned_role_counts() -> Dictionary:
	var counts: Dictionary = {}
	for citizen in simulation.citizens:
		if citizen.is_player_controlled:
			continue
		if not citizen.permanent_role.is_empty() and is_instance_valid(citizen.employment_workplace) and not bool(citizen.employment_workplace.get_meta("accepting_workers", true)):
			# A retained worker at a closed workplace must not consume a vacancy
			# at another employer that is still accepting staff.
			continue
		var role: String = citizen.permanent_role
		if role.is_empty() and citizen.employment_state == Citizen.EmploymentState.REGISTERING:
			role = citizen.pending_employment_role
		if role.is_empty():
			role = citizen.active_role
		if role.is_empty() or role in ["trade", "relaxing", "training"]:
			continue
		if role == "gather_wood":
			role = "forestry"
		counts[role] = int(counts.get(role, 0)) + 1
	return counts

func factory_for_role(role: String) -> Node3D:
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
