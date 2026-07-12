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
	assert(not simulation.hero_citizen.auto_mode_enabled)
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
			assert(not citizen.auto_mode_enabled)
			assert(citizen.employment_state == Citizen.EmploymentState.UNEMPLOYED)
	assert(simulation.tent == null)
	assert(simulation._total_housing_slots() == 0)
	var cell := Vector2i(12, 12)
	var position := Vector3(12.0, 0.0, 12.0)
	var blueprint := BuildingBlueprints.get_blueprint("warehouse")
	simulation.building_registry.reserve(cell, position, blueprint.footprint)
	simulation._create_construction_site(cell, "warehouse", position, 0, blueprint, blueprint.footprint)
	assert(simulation.construction_sites.size() == 1)
	assert(simulation._is_construction_site(simulation.construction_sites[0].node))
	assert(simulation.construction.cancel_site(simulation.construction_sites[0].node))
	assert(simulation.construction_sites.is_empty())
	assert(simulation.building_registry.record_at_cell(cell) == null)
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
