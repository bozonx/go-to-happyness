extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	var cell := Vector2i(12, 12)
	var site_position := Vector3(12.0, 0.0, 12.0)
	var blueprint := BuildingBlueprints.get_blueprint("warehouse")
	simulation.building_registry.reserve(cell, site_position, blueprint.footprint)
	SimHelper.create_construction_site(simulation, cell, "warehouse", site_position, 0, blueprint, blueprint.footprint)

	var site = simulation.construction_sites[0]
	for resource_type in site.required_materials:
		var required: int = int(site.required_materials.get(resource_type, 0))
		if required > 0:
			site.delivered_materials[resource_type] = required

	var builder: Citizen = simulation.citizens[2]
	builder.global_position = Vector3(10.0, 0.0, 10.0)
	builder.idle()
	SimHelper.assign_daily_order(simulation, builder, "construction")

	var frames := 0
	var max_frames := 1200
	while frames < max_frames:
		await physics_frame
		frames += 1
		if simulation.construction_sites.is_empty():
			break

	assert(simulation.construction_sites.is_empty(), "Daily builder should complete the warehouse construction")
	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
