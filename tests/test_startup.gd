extends SceneTree


func _init() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame
	for _frame in range(10):
		await physics_frame
	assert(simulation.citizens.size() == simulation.POPULATION)
	for citizen in simulation.citizens:
		assert(is_instance_valid(citizen))
		assert(citizen.is_inside_tree())
		assert(citizen.is_in_group("citizens"))
		assert(is_finite(citizen.global_position.x) and is_finite(citizen.global_position.y) and is_finite(citizen.global_position.z))
		assert(citizen.global_position.z >= simulation.entrance_stone.global_position.z + 1.5)
		assert(citizen.global_position.y > -1.0)
		assert(citizen.get_children().any(func(child): return child is MeshInstance3D))
	root.remove_child(simulation)
	simulation.free()
	scene = null
	quit(0)
