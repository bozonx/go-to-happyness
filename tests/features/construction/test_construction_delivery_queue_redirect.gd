extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")


func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	var warehouse_position := Vector3.ZERO
	simulation.warehouse_positions.append(warehouse_position)
	simulation.settlement.add_warehouse("warehouse")

	var site_cell := Vector2i(8, 0)
	var site_position := Vector3(8.0, 0.0, 0.0)
	var blueprint := BuildingBlueprints.get_blueprint("campfire")
	simulation.building_registry.reserve(site_cell, site_position, blueprint.footprint)
	SimHelper.create_construction_site(simulation, site_cell, "campfire", site_position, 0, blueprint, blueprint.footprint)
	SimHelper.refresh_navigation_grid(simulation)

	assert(simulation.construction_sites.size() == 1, "Expected one construction site")
	simulation.settlement.add("branches", 5)

	SimHelper.add_citizen(simulation, warehouse_position, "courier")
	var courier: Citizen = simulation.citizens[-1]
	await process_frame
	await physics_frame

	var delivered := false
	var delivered_position := Vector3.INF
	courier.construction_material_delivered.connect(
		func(worker: Citizen, _site_node: Node3D, _resource_type: String, _amount: int):
			delivered = true
			delivered_position = worker.global_position
	)

	courier.assign_construction_delivery(simulation.construction_sites[0].node, warehouse_position, "branches")
	# Let the pickup phase finish so the construction approach position is known.
	await physics_frame
	var construction_position: Vector3 = courier.construction_position

	# Place a decoy building whose service position coincides with the construction
	# approach point. With the queue system enabled for delivery, the courier would
	# be redirected to this building instead of dropping materials at the site.
	# A decoy building whose node sits on the construction approach point but
	# whose registry footprint is far away (so it does not block the approach cell).
	# Its service entrance is reachable on the board; if delivery uses the building
	# queue, the courier will be redirected there instead of dropping materials at
	# the construction site.
	var decoy_entrance := Vector3(0.0, 0.0, 5.0)
	var decoy_cell := Vector2i(100, 100)
	var decoy_node := Node3D.new()
	decoy_node.position = construction_position
	decoy_node.set_meta("service_position", decoy_entrance)
	simulation.add_child(decoy_node)
	simulation.building_registry.reserve(decoy_cell, Vector3(100.0, 0.0, 100.0), Vector2i(1, 1))
	simulation.building_registry.attach_node(decoy_cell, decoy_node)

	for frame in range(1200):
		await physics_frame
		if delivered:
			break

	assert(delivered, "Courier should deliver branches to the construction site")
	assert(delivered_position.distance_squared_to(construction_position) < 0.25, "Courier should stop at the construction approach point, not the decoy building")

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
