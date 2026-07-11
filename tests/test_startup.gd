extends SceneTree


func _init() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	assert(simulation.citizens.size() == simulation.POPULATION)
	for citizen in simulation.citizens:
		assert(is_instance_valid(citizen))
		assert(citizen.is_inside_tree())
	quit(0)
