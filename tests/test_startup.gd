extends SceneTree


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame
	for _frame in range(10):
		await physics_frame
	assert(simulation.citizens.size() == simulation.POPULATION)
	assert(is_instance_valid(simulation.hero_citizen))
	assert(simulation.hero_citizen.is_hero)
	assert(simulation.hero_citizen.specialization == "official")
	assert(simulation._player_can_command_labor())
	simulation.hero_citizen.permanent_role = ""
	assert(simulation._player_can_command_labor())
	simulation._appoint_official(simulation.hero_citizen)
	var delegated_officer: Citizen = simulation.citizens[1]
	simulation._appoint_official(delegated_officer)
	assert(not simulation._player_can_command_labor())
	simulation._appoint_official(simulation.hero_citizen)
	assert(simulation._player_can_command_labor())
	assert(is_instance_valid(simulation.entrance_stone))
	var hero_count := 0
	for citizen in simulation.citizens:
		hero_count += 1 if citizen.is_hero else 0
	assert(hero_count == 1)
	for citizen in simulation.citizens:
		assert(is_instance_valid(citizen))
		assert(citizen.is_inside_tree())
		assert(citizen.is_in_group("citizens"))
		assert(citizen.home == null)
		assert(is_finite(citizen.global_position.x) and is_finite(citizen.global_position.y) and is_finite(citizen.global_position.z))
		assert(citizen.global_position.y > -1.0)
		assert(citizen.get_children().any(func(child): return child is MeshInstance3D))
		assert(citizen.global_position.distance_to(simulation.entrance_stone.global_position) < 5.0)
		if not citizen.is_hero:
			assert(citizen.specialization == "unassigned")
			assert(citizen.employment_state == Citizen.EmploymentState.FREELANCE)
	var resident: Citizen = simulation.citizens[1]
	simulation.settlement.era = SettlementState.Era.TENT
	assert(resident.is_toilet_user(resident))
	simulation.settlement.era = SettlementState.Era.EARTH
	assert(resident.is_toilet_user(resident))
	simulation.settlement.era = SettlementState.Era.WOOD
	resident.setup_specialization("cook")
	resident.employment_state = Citizen.EmploymentState.EMPLOYED
	assert(resident.is_toilet_user(resident))
	resident.employment_state = Citizen.EmploymentState.FREELANCE
	assert(resident.is_toilet_user(resident))
	resident.freelance_assignment = "courier"
	resident.employment_state = Citizen.EmploymentState.FREELANCE
	assert(resident.is_toilet_user(resident))
	resident.generate_toilet_schedule()
	assert(resident.toilet_times.size() == 1)
	assert(resident.toilet_times[0] >= 480.0 and resident.toilet_times[0] <= 1200.0)
	assert(resident._get_simulation_toilets().is_empty())

	# A relief break must not overwrite the target of an interrupted work task.
	var work_target: Vector3 = simulation._resource_access_position(resident.global_position, simulation.tree_positions[0])
	assert(work_target != Vector3.INF)
	resident.gender = "male"
	resident.state = Citizen.State.TO_TREE
	resident.source_access_position = work_target
	resident._find_and_go_to_toilet_or_bush()
	assert(resident.state == Citizen.State.TO_BUSH)
	assert(resident.toilet_relief_type == "tree")
	assert(resident.source_access_position == work_target)
	resident.state = Citizen.State.USING_BUSH
	resident.toilet_timer.start(0.0)
	resident._process_using_bush(0.1)
	assert(resident.state == Citizen.State.TO_TREE)
	assert(resident.source_access_position == work_target)

	# Women prefer a grass patch, and an idle wander retains its exact destination.
	resident.gender = "female"
	var wander_anchor := resident.global_position + Vector3(2.0, 0.0, 0.0)
	var wander_target := resident.global_position + Vector3(3.0, 0.0, 0.0)
	resident.state = Citizen.State.IDLE
	resident.idle_wander_anchor = wander_anchor
	resident.idle_wander_target = wander_target
	resident.idle_wander_pause = 1.25
	resident._find_and_go_to_toilet_or_bush()
	assert(resident.state == Citizen.State.TO_BUSH)
	assert(resident.toilet_relief_type == "grass")
	resident.state = Citizen.State.USING_BUSH
	resident.toilet_timer.start(0.0)
	resident._process_using_bush(0.1)
	assert(resident.state == Citizen.State.IDLE)
	assert(resident.idle_wander_anchor == wander_anchor)
	assert(resident.idle_wander_target == wander_target)
	assert(is_equal_approx(resident.idle_wander_pause, 1.25))
	resident.go_to_arrival_entrance(simulation.entrance_stone.global_position)
	assert(resident.has_active_arrival_task())
	assert(not resident.is_available_for_schedule())
	var arrival_home := Node3D.new()
	simulation.add_child(arrival_home)
	resident.assign_home(arrival_home)
	resident.go_home()
	assert(resident.state == Citizen.State.TO_ARRIVAL_ENTRANCE)
	var interrupted_order := {"house": arrival_home, "dispatched": true, "greeter_id": resident.get_instance_id()}
	simulation.pending_arrivals.append(interrupted_order)
	simulation.arrival_greeters[resident.get_instance_id()] = interrupted_order
	resident.idle()
	simulation._requeue_interrupted_arrivals()
	assert(not bool(simulation.pending_arrivals[0].get("dispatched", false)))
	simulation._cancel_arrivals_for_house(arrival_home)
	assert(simulation.pending_arrivals.is_empty())
	assert(simulation.tent == null)
	assert(simulation._total_housing_slots() == 0)
	var pond_cell: Vector2i = simulation._cell_from_position(simulation.pond_positions[0])
	assert(simulation._is_navigation_cell_blocked(pond_cell))
	var pond_route: RouteResult = simulation._find_path_around_houses(simulation.citizens[0].global_position, simulation.pond_positions[0], false)
	assert(not pond_route.reachable)
	assert(not simulation.citizens[0]._move_to(simulation.pond_positions[0], 0.1))
	var pond_access: Vector3 = simulation._pond_access_position(simulation.citizens[0].global_position, simulation.pond_positions[0])
	assert(pond_access != Vector3.INF)
	var pond_access_route: RouteResult = simulation._find_path_around_houses(simulation.citizens[0].global_position, pond_access, false)
	assert(pond_access_route.reachable)
	var cell := Vector2i(12, 12)
	var position := Vector3(12.0, 0.0, 12.0)
	var blueprint := BuildingBlueprints.get_blueprint("warehouse")
	simulation.building_registry.reserve(cell, position, blueprint.footprint)
	simulation._create_construction_site(cell, "warehouse", position, 0, blueprint, blueprint.footprint)
	assert(simulation.construction_sites.size() == 1)
	assert(simulation._is_construction_site(simulation.construction_sites[0].node))
	var construction_site: ConstructionSite = simulation.construction_sites[0]
	construction_site.reserved_materials = {"branches": 1}
	var branches_before: int = simulation.settlement.branches
	simulation._reconcile_construction_reservations(construction_site)
	assert(simulation.settlement.branches == branches_before + 1)
	assert(construction_site.reserved_materials.branches == 0)
	assert(simulation.construction.cancel_site(simulation.construction_sites[0].node))
	assert(simulation.construction_sites.is_empty())
	assert(simulation.building_registry.record_at_cell(cell) == null)
	var field_officer: Citizen = simulation.citizens[1]
	simulation._appoint_official(field_officer)
	assert(simulation._employment_center_position() == Vector3.INF)
	assert(simulation._registration_official() == null)
	var civic_centre := Node3D.new()
	civic_centre.position = field_officer.global_position
	civic_centre.set_meta("service_position", field_officer.global_position)
	civic_centre.set_meta("accepting_workers", true)
	simulation.add_child(civic_centre)
	simulation.campfire_node = civic_centre
	simulation._activate_employment_centre(civic_centre)
	simulation.game_minutes = 9.0 * 60.0
	field_officer.state = Citizen.State.OFFICIAL_WORK
	assert(simulation._registration_official() == field_officer)
	# Delegating the officer role blocks every labor command, including overtime.
	simulation.selected_building = civic_centre
	field_officer.overtime_mode = false
	simulation._call_worker_overtime()
	assert(not field_officer.overtime_mode)
	var first_in_queue: Citizen = simulation.citizens[2]
	var second_in_queue: Citizen = simulation.citizens[3]
	first_in_queue.global_position = civic_centre.global_position
	second_in_queue.global_position = civic_centre.global_position
	first_in_queue.begin_employment_processing(simulation._employment_center_position())
	second_in_queue.begin_employment_processing(simulation._employment_center_position())
	assert(simulation._can_start_registration(first_in_queue))
	assert(not simulation._can_start_registration(second_in_queue))
	first_in_queue.state = Citizen.State.EMPLOYMENT_PROCESSING
	assert(not simulation._can_start_registration(second_in_queue))
	field_officer.global_position += Vector3(10.0, 0.0, 0.0)
	assert(not simulation._can_start_registration(first_in_queue))
	# R always enters the hero view; direct management of another citizen is explicit.
	simulation._toggle_hero_view()
	assert(simulation.is_first_person)
	assert(simulation.player_citizen == simulation.hero_citizen)
	simulation._toggle_hero_view()
	assert(not simulation.is_first_person)
	simulation._select_citizen(simulation.citizens[1])
	simulation._take_control_of_selected_citizen()
	assert(simulation.player_citizen == simulation.citizens[1])
	simulation._toggle_hero_view()
	assert(simulation.player_citizen == simulation.hero_citizen)
	root.remove_child(simulation)
	simulation.free()
	scene = null
	quit(0)
