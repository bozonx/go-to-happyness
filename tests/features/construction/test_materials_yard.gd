extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Scene-level smoke test for the materials yard: builds one and verifies it
## registers as a branch-gathering workplace that a resident can be employed at.


func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	# Complete a materials yard through the normal building-completion path.
	var cell := Vector2i(14, 14)
	var position := Vector3(14.0, 0.0, 14.0)
	var blueprint := BuildingBlueprints.get_blueprint("straw_materials_yard")
	assert(not blueprint.is_empty())
	simulation.building_registry.reserve(cell, position, blueprint.footprint)
	var yard := Node3D.new()
	yard.position = position
	simulation.add_child(yard)
	SimHelper.complete_building(simulation, cell, "straw_materials_yard", position, yard, blueprint)

	# It registers a service position and advertises two branch-gathering jobs.
	assert(simulation.materials_yard_positions.size() == 1)
	assert(SimHelper.available_employer_capacity(simulation, "gather_branches") == 2)
	assert(SimHelper.employer_for_role(simulation, "gather_branches") == yard)
	var vacancy: Dictionary = SimHelper.required_staff_for_building(simulation, yard)
	assert(vacancy.get("role", "") == "gather_branches" and int(vacancy.get("count", 0)) == 2)
	assert(SimHelper.is_staffed_workplace(simulation, yard))

	# Stand up an employment centre so registration can start (mirrors test_startup).
	var civic_centre := Node3D.new()
	civic_centre.position = simulation.citizens[1].global_position
	civic_centre.set_meta("service_position", simulation.citizens[1].global_position)
	civic_centre.set_meta("accepting_workers", true)
	simulation.add_child(civic_centre)
	simulation.campfire_node = civic_centre
	SimHelper.appoint_test_official(simulation, simulation.citizens[1])

	# The workforce menu's Assign action must create a permanent yard contract;
	# this is the same handler connected to the visible UI button.
	SimHelper.assign_unemployed_worker(simulation, "gather_branches")
	var pending_yard_worker: Citizen = null
	for citizen in simulation.citizens:
		if citizen.pending_employment_role == "gather_branches":
			pending_yard_worker = citizen
			break
	assert(pending_yard_worker != null)
	assert(pending_yard_worker.pending_employment_workplace == yard)

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
