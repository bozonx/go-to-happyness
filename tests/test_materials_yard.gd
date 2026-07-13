extends SceneTree

## Scene-level smoke test for the materials yard: builds one and verifies it
## registers as a branch-gathering workplace that a resident can be employed at.


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame
	for _frame in range(10):
		await physics_frame

	# Complete a materials yard through the normal building-completion path.
	var cell := Vector2i(14, 14)
	var position := Vector3(14.0, 0.0, 14.0)
	var blueprint := BuildingBlueprints.get_blueprint("materials_yard")
	assert(not blueprint.is_empty())
	simulation.building_registry.reserve(cell, position, blueprint.footprint)
	var yard := Node3D.new()
	yard.position = position
	simulation.add_child(yard)
	simulation._complete_building(cell, "materials_yard", position, yard, blueprint)

	# It registers a service position and advertises two branch-gathering jobs.
	assert(simulation.materials_yard_positions.size() == 1)
	assert(simulation._available_employer_capacity("gather_branches") == 2)
	assert(simulation._employer_for_role("gather_branches") == yard)
	var vacancy: Dictionary = simulation._required_staff_for_building(yard)
	assert(vacancy.get("role", "") == "gather_branches" and int(vacancy.get("count", 0)) == 2)
	assert(simulation._is_staffed_workplace(yard))

	# Stand up an employment centre so registration can start (mirrors test_startup).
	var civic_centre := Node3D.new()
	civic_centre.position = simulation.citizens[1].global_position
	civic_centre.set_meta("service_position", simulation.citizens[1].global_position)
	civic_centre.set_meta("accepting_workers", true)
	simulation.add_child(civic_centre)
	simulation.campfire_node = civic_centre

	# A free resident can be assigned as a permanent branch gatherer at the yard.
	var hand: Citizen = null
	for citizen in simulation.citizens:
		if not citizen.is_hero and not citizen.is_player_controlled:
			hand = citizen
			break
	assert(hand != null)
	hand.employment_state = Citizen.EmploymentState.FREELANCE
	simulation._set_manual_specialist_employment(hand, "gather_branches")
	assert(hand.pending_employment_role == "gather_branches")
	assert(hand.pending_employment_workplace == yard)

	root.remove_child(simulation)
	simulation.free()
	scene = null
	quit(0)
