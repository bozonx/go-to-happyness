extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Tests civic centre activation, officer handoff, registration queue,
## and overtime toggle.

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	var field_officer: Citizen = simulation.citizens[1]
	SimHelper.appoint_test_official(simulation, field_officer)
	assert(SimHelper.registration_official(simulation) == null)

	# Building completion must hand the officer directly to the new centre.
	var civic_centre := Node3D.new()
	civic_centre.position = field_officer.global_position
	civic_centre.set_meta("service_position", field_officer.global_position)
	civic_centre.set_meta("accepting_workers", true)
	simulation.add_child(civic_centre)
	simulation.campfire_node = civic_centre
	simulation.game_minutes = 9.0 * 60.0
	SimHelper.activate_employment_centre(simulation, civic_centre)
	assert(field_officer.state == Citizen.State.TO_OFFICIAL_WORK)
	field_officer.state = Citizen.State.OFFICIAL_WORK
	assert(SimHelper.registration_official(simulation) == field_officer)

	# A delegated officer enables automation, but the player can still issue
	# manual labor commands.
	simulation.selected_building = civic_centre
	simulation.game_minutes = 20.0 * 60.0
	field_officer.overtime_mode = false
	SimHelper.toggle_worker_overtime(simulation, true)
	assert(field_officer.overtime_mode)
	simulation.game_minutes = 9.0 * 60.0

	# Registration queue: only one citizen at a time.
	var first_in_queue: Citizen = simulation.citizens[2]
	var second_in_queue: Citizen = simulation.citizens[3]
	first_in_queue.global_position = civic_centre.global_position
	second_in_queue.global_position = civic_centre.global_position
	simulation.citizen_ai.process_mode = Node.PROCESS_MODE_DISABLED
	first_in_queue.begin_employment_processing(SimHelper.employment_center_position(simulation))
	second_in_queue.begin_employment_processing(SimHelper.employment_center_position(simulation))
	assert(SimHelper.can_start_registration(simulation, first_in_queue))
	assert(not SimHelper.can_start_registration(simulation, second_in_queue))
	first_in_queue.state = Citizen.State.EMPLOYMENT_PROCESSING
	assert(not SimHelper.can_start_registration(simulation, second_in_queue))
	field_officer.global_position += Vector3(10.0, 0.0, 0.0)
	assert(not SimHelper.can_start_registration(simulation, first_in_queue))
	simulation.citizen_ai.process_mode = Node.PROCESS_MODE_INHERIT
	field_officer.overtime_mode = false
	field_officer.overtime_until_workday_id = 0

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
