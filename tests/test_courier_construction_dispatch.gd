extends SceneTree


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame
	for _frame in range(10):
		await physics_frame

	var campfire_cell := Vector2i(12, 12)
	var campfire_position := Vector3(12.0, 0.0, 12.0)
	var campfire_blueprint := BuildingBlueprints.get_blueprint("campfire")
	simulation.building_registry.reserve(campfire_cell, campfire_position, campfire_blueprint.footprint)
	simulation._create_construction_site(campfire_cell, "campfire", campfire_position, 0, campfire_blueprint, campfire_blueprint.footprint)

	var tent_cell := Vector2i(14, 14)
	var tent_position := Vector3(14.0, 0.0, 14.0)
	var tent_blueprint := BuildingBlueprints.get_blueprint("tent")
	simulation.building_registry.reserve(tent_cell, tent_position, tent_blueprint.footprint)
	simulation._create_construction_site(tent_cell, "tent", tent_position, 0, tent_blueprint, tent_blueprint.footprint)

	assert(simulation.construction_sites.size() == 2)

	# Stock enough resources for both sites to need deliveries.
	simulation.settlement.add("branches", 20)
	simulation.settlement.add("grass", 20)
	simulation.warehouse_positions.append(Vector3.ZERO)

	simulation._update_couriers()
	var construction_tasks: Array[CourierTask] = simulation.courier_dispatcher.available_tasks().filter(
		func(task: CourierTask) -> bool: return task.kind == CourierTask.Kind.CONSTRUCTION
	)
	assert(construction_tasks.size() >= 2, "Expected construction tasks for multiple sites, got %d" % construction_tasks.size())

	root.remove_child(simulation)
	simulation.free()
	quit(0)
