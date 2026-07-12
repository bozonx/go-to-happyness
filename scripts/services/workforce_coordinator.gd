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
		if citizen.employment_state in [Citizen.EmploymentState.PENDING_JOB, Citizen.EmploymentState.PENDING_UNEMPLOYMENT] and citizen.state in [Citizen.State.IDLE, Citizen.State.RESTING, Citizen.State.TO_HOME]:
			if citizen.employment_state == Citizen.EmploymentState.PENDING_UNEMPLOYMENT:
				var queued_vacancy := WorkforcePolicy.permanent_vacancy_for(_worker_data(citizen), _world_data())
				if not queued_vacancy.is_empty():
					citizen.queue_employment_processing(queued_vacancy)
			if _can_finish_registration_today(citizen):
				citizen.begin_employment_processing(simulation._employment_center_position(), citizen.pending_employment_role)
			continue
		if citizen.state in [Citizen.State.TO_EMPLOYMENT_CENTER, Citizen.State.EMPLOYMENT_PROCESSING]:
			_update_employment_processing(citizen)
			continue
		# Couriers and service runs keep their current task; an automatic courier is
		# considered for a vacancy only after its delivery has completed.
		if citizen.state in BUSY_STATES or citizen.state == Citizen.State.WAITING:
			continue
		if citizen.blocked_by_storage:
			if not simulation.settlement.reserve_storage_room_for(citizen.resource_type, maxi(1, citizen.carried_amount), simulation.warehouse_positions.size()):
				_send_to_waiting(citizen)
				continue
			citizen.blocked_by_storage = false
		if citizen.employment_state == Citizen.EmploymentState.EMPLOYED:
			if can_assign_work(citizen) and citizen.state in [Citizen.State.IDLE, Citizen.State.RESTING]:
				citizen.request_goap_decision()
			continue
		if citizen.employment_state == Citizen.EmploymentState.MANUAL_COURIER:
			continue
		if citizen.employment_state == Citizen.EmploymentState.UNEMPLOYED or not citizen.auto_mode_enabled:
			continue
		# A free productive workplace turns an automatic reserve worker into a
		# permanent employee only after registration at the employment centre.
		if citizen.state in [Citizen.State.IDLE, Citizen.State.RESTING]:
			var vacancy := WorkforcePolicy.permanent_vacancy_for(_worker_data(citizen), _world_data())
			if not vacancy.is_empty():
				if _can_finish_registration_today(citizen):
					citizen.begin_employment_processing(simulation._employment_center_position(), vacancy)
				else:
					citizen.queue_employment_processing(vacancy)
				continue
		if can_assign_work(citizen):
			# Pull free citizens onto work: the genuinely idle and the ones resting
			# at home (morning wake-up / rest-fallback from an earlier work drought).
			# Park breaks (RELAXING) and active work states are left alone.
			if citizen.state == Citizen.State.IDLE or citizen.state == Citizen.State.RESTING:
				citizen.request_goap_decision()
		else:
			_send_to_waiting(citizen)


func _update_employment_processing(citizen: Citizen) -> void:
	# A newly opened productive workplace interrupts unemployment registration.
	# The citizen is already unburdened here; active deliveries are never routed
	# into this state and therefore always finish before any transfer.
	if citizen.employment_state == Citizen.EmploymentState.PENDING_UNEMPLOYMENT:
		var vacancy := WorkforcePolicy.permanent_vacancy_for(_worker_data(citizen), _world_data())
		if not vacancy.is_empty():
			if _can_finish_registration_today(citizen):
				citizen.begin_employment_processing(simulation._employment_center_position(), vacancy)
			else:
				citizen.queue_employment_processing(vacancy)


func _can_finish_registration_today(citizen: Citizen) -> bool:
	var center: Vector3 = simulation._employment_center_position()
	if center == Vector3.INF:
		return false
	var minutes_to_walk: float = citizen.global_position.distance_to(center) / Citizen.WALK_SPEED * float(simulation.GAME_MINUTES_PER_SECOND)
	var shift_end := 8.0 + float(simulation.settlement.workday_hours)
	var finish_hour: float = float(simulation.game_minutes) / 60.0 + minutes_to_walk / 60.0 + 1.0
	return finish_hour <= shift_end

func _get_sorted_citizens() -> Array[Citizen]:
	var list: Array[Citizen] = []
	for citizen in simulation.citizens:
		list.append(citizen)
	list.sort_custom(func(a: Citizen, b: Citizen):
		var a_pref := a.preferred_role()
		var b_pref := b.preferred_role()
		var a_skill := float(a.skills.get(a_pref, 0.0))
		var b_skill := float(b.skills.get(b_pref, 0.0))
		return a_skill > b_skill
	)
	return list


func _send_to_waiting(citizen: Citizen) -> void:
	# Lack of reserve work is registered at the employment centre rather than an
	# indefinite waiting state. The coordinator can still replace this process with
	# a newly opened productive vacancy before the paperwork completes.
	if citizen.state == Citizen.State.IDLE or citizen.state == Citizen.State.RESTING:
		if _can_finish_registration_today(citizen):
			citizen.begin_employment_processing(simulation._employment_center_position())
		else:
			citizen.queue_employment_processing()


func can_assign_work(citizen: Citizen) -> bool:
	if not WorkforcePolicy.can_assign(_worker_data(citizen), _world_data()):
		return false
	return simulation._has_storage_room_for_role(work_role_for(citizen))


func assign_work(citizen: Citizen, index: int) -> void:
	if not can_assign_work(citizen):
		return
	if citizen.specialization == "cook":
		citizen.assign_canteen_work(simulation.canteen_position)
		return
	if citizen.specialization == "teacher":
		citizen.assign_teacher_work(simulation.school_positions[0])
		return
	if citizen.specialization == "factory_worker":
		citizen.assign_factory_work(factory_for_role("factory_worker"), "factory_work")
		return
	if citizen.specialization == "engineer":
		citizen.assign_factory_work(factory_for_role("engineer"), "engineering")
		return
	var should_study := false
	var target_role := ""
	if not citizen.training_role.is_empty() and citizen.training_days_completed < 10:
		should_study = true
		target_role = citizen.training_role
	elif simulation.school_developed_professions.get(citizen.preferred_role(), false) and float(citizen.skills.get(citizen.preferred_role(), 0.0)) < 1.0:
		should_study = true
		target_role = citizen.preferred_role()
		
	if should_study and not simulation.school_positions.is_empty() and int(simulation.game_minutes) / 60 < 12:
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
	match work_role_for(citizen):
		"gather_dew":
			var collector_position: Vector3 = simulation._reserve_dew_collector()
			if collector_position != Vector3.INF:
				citizen.assign_gathering("water", collector_position, simulation._get_delivery_position())
		"construction":
			if not simulation.demolition_sites.is_empty():
				citizen.assign_demolition(simulation.demolition_sites[index % simulation.demolition_sites.size()].building)
			elif not simulation.construction_sites.is_empty():
				var construction: Dictionary = simulation.construction_sites[index % simulation.construction_sites.size()]
				citizen.assign_construction(construction.node)
		"forestry":
			var tree_position: Vector3 = simulation._reserve_closest_tree_for_sawmill(citizen, Vector3.ZERO)
			if tree_position != Vector3.INF:
				if simulation.sawmill_positions.is_empty():
					citizen.assign_gathering("logs", tree_position, simulation._get_delivery_position())
				else:
					var sawmill_position: Vector3 = simulation.sawmill_positions[index % simulation.sawmill_positions.size()]
					citizen.assign_work("wood", tree_position, sawmill_position, simulation.warehouse_positions[index % simulation.warehouse_positions.size()])
		"farming":
			var farm_position: Vector3 = simulation.farm_positions[index % simulation.farm_positions.size()]
			citizen.assign_work("food", farm_position, farm_position, simulation.warehouse_positions[index % simulation.warehouse_positions.size()], simulation._has_courier())
		"excavation":
			var dig_site := citizen.assigned_dig_site
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
				citizen.assign_gathering("branches", tree_pos, simulation._get_delivery_position())
		"gather_grass":
			var grass_pos: Vector3 = simulation._find_grass_gathering_position(citizen)
			citizen.assign_gathering("grass", grass_pos, simulation._get_delivery_position())
		"gather_food":
			var forage_pos: Vector3 = simulation._find_forage_position(citizen)
			if forage_pos != Vector3.INF:
				citizen.assign_gathering("food", forage_pos, simulation._get_delivery_position())
		"gather_water":
			if not simulation.pond_positions.is_empty():
				var pond: Vector3 = simulation.pond_positions[index % simulation.pond_positions.size()]
				citizen.assign_gathering("water", pond, simulation._get_delivery_position())
	# A role can be available in policy while its concrete source is exhausted.
	# Register unemployment instead of returning to the obsolete waiting loop.
	if citizen.state == Citizen.State.IDLE or citizen.state == Citizen.State.RESTING:
		_send_to_waiting(citizen)


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
		"training_role": citizen.training_role,
		"training_days_completed": citizen.training_days_completed,
		"permanent_role": citizen.permanent_role,
		"skills": citizen.skills,
		"should_study": should_study,
	}


func _world_data() -> Dictionary:
	return {
		"era": simulation.settlement.era,
		"hour": int(simulation.game_minutes) / 60,
		"has_canteen": is_instance_valid(simulation.canteen),
		"schools": simulation.school_positions.size(),
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


func _assigned_role_counts() -> Dictionary:
	var counts: Dictionary = {}
	for citizen in simulation.citizens:
		if citizen.is_player_controlled:
			continue
		var role: String = citizen.permanent_role
		if role.is_empty() and citizen.employment_state == Citizen.EmploymentState.PENDING_JOB:
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
