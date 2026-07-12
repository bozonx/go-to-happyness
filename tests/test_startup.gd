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
	assert(simulation.tent == null)
	assert(simulation._total_housing_slots() == 0)
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
