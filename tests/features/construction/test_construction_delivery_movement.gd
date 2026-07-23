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
	simulation._create_construction_site(site_cell, "campfire", site_position, 0, blueprint, blueprint.footprint)
	simulation._refresh_navigation_grid()

	assert(simulation.construction_sites.size() == 1, "Expected one construction site")
	var site: ConstructionSite = simulation.construction_sites[0]

	simulation.settlement.add("branches", 5)

	# Spawn the courier right at the warehouse so the pickup phase resolves immediately.
	simulation._add_citizen(warehouse_position, "courier")
	var courier: Citizen = simulation.citizens[-1]
	await process_frame
	await physics_frame

	var delivered := false
	var delivered_resource := ""
	courier.construction_material_delivered.connect(
		func(_worker: Citizen, _site_node: Node3D, resource_type: String, _amount: int):
			delivered = true
			delivered_resource = resource_type
	)

	courier.assign_construction_delivery(site.node, warehouse_position, "branches")

	for frame in range(1200):
		await physics_frame
		if delivered:
			break

	assert(delivered, "Courier should deliver branches to the construction site")
	assert(delivered_resource == "branches", "Expected branches delivery")

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
