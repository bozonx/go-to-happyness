extends SceneTree


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame
	for _frame in range(10):
		await physics_frame

	var warehouse_position := Vector3.ZERO
	simulation.warehouse_positions.append(warehouse_position)

	var site_cell := Vector2i(8, 0)
	var site_position := Vector3(8.0, 0.0, 0.0)
	var blueprint := BuildingBlueprints.get_blueprint("campfire")
	simulation.building_registry.reserve(site_cell, site_position, blueprint.footprint)
	simulation._create_construction_site(site_cell, "campfire", site_position, 0, blueprint, blueprint.footprint)
	simulation._refresh_navigation_grid()

	assert(simulation.construction_sites.size() == 1, "Expected one construction site")
	var site: ConstructionSite = simulation.construction_sites[0]

	simulation.settlement.add("branches", 5)

	simulation._add_citizen(warehouse_position, "courier")
	var courier: Citizen = simulation.citizens[-1]
	await process_frame
	await physics_frame

	var delivered := false
	courier.construction_material_delivered.connect(
		func(_worker: Citizen, _site_node: Node3D, _resource_type: String, _amount: int):
			delivered = true
	)

	courier.assign_construction_delivery(site.node, warehouse_position, "branches")
	# Wait until the courier is on the way to the construction site.
	for frame in range(60):
		await physics_frame
		if courier.state == Citizen.State.TO_CONSTRUCTION_SITE:
			break
	assert(courier.state == Citizen.State.TO_CONSTRUCTION_SITE, "Courier should be walking to the construction site")

	# Simulate the construction site being removed mid-delivery.
	site.node.queue_free()

	for frame in range(300):
		await physics_frame
		if courier.state == Citizen.State.IDLE:
			break

	assert(not delivered, "Delivery should not complete after the site is removed")
	assert(courier.carried_amount == 0, "Cargo should be cleared when the site disappears")
	assert(courier.construction_delivery_resource.is_empty(), "Delivery resource should be cleared")
	assert(courier.state == Citizen.State.IDLE, "Courier should return to idle after the site disappears")

	root.remove_child(simulation)
	simulation.free()
	quit(0)
