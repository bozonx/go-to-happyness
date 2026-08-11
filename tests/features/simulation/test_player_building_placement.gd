extends SceneTree

const SimHelper := preload("res://tests/helpers/simulation_test_helper.gd")

## Player construction uses the world placement transaction from preview through
## cancellation. This catches regressions where BuildingRegistry starts writing
## anchors again or a cancelled site leaves an invisible occupied record.


func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)
	simulation.build_mode = "entrance_sign"
	simulation.build_rotation_quarters = 0
	var blueprint: Dictionary = BuildingBlueprints.get_blueprint(simulation.build_mode)
	var authored: BuildingBlueprint = simulation.building_placement_controller.authored_blueprint(simulation.build_mode)
	assert(authored != null)

	var plan: PlacementPlan = null
	var terrain: TerrainGrid = simulation.world_setup.terrain_grid
	for z in range(terrain.min_cell().y + 2, terrain.max_cell().y - authored.footprint.y - 1):
		for x in range(terrain.min_cell().x + 2, terrain.max_cell().x - authored.footprint.x - 1):
			var candidate := Vector3(
				(float(x) + float(authored.footprint.x) * 0.5) * terrain.cell_size,
				0.0,
				(float(z) + float(authored.footprint.y) * 0.5) * terrain.cell_size)
			plan = simulation.building_placement_controller.plan_placement(candidate)
			if plan.ok:
				break
		if plan != null and plan.ok:
			break
	assert(plan != null and plan.ok, "fixture needs one legal player placement")

	var record: MapPlacementRecord = simulation.building_placement_controller.commit_placement(plan)
	assert(record != null and record.owner == &"session")
	var anchored_cell: Vector2i = plan.footprint.cells()[0]
	assert(terrain.is_anchor(anchored_cell), "commit pins the exact placement footprint")

	var cell: Vector2i = simulation.building_placement_controller.registry_cell_for_plan(plan)
	var position: Vector3 = simulation.building_placement_controller.world_position_for_plan(plan)
	var occupied: Vector2i = plan.footprint.span()
	simulation.building_registry.reserve(cell, position, occupied)
	var site: ConstructionSite = simulation.construction_controller.create_construction_site(
		cell, simulation.build_mode, position, 0, blueprint, occupied)
	simulation.building_placement_controller.bind_placement(site.node, record)
	simulation.building_registry.attach_node(cell, site.node, simulation.build_mode)
	assert(simulation.construction.cancel_site(site.node), "site cancellation succeeds")
	assert(simulation.world_session.placement_layer.by_id(record.id) == null,
		"cancel removes the runtime placement record")
	assert(not terrain.is_anchor(anchored_cell), "cancel releases placement anchors")
	assert(simulation.building_registry.record_at_cell(cell) == null,
		"cancel releases the gameplay registry too")

	await SimHelper.cleanup_simulation(self, simulation)
	print("  => Player Building Placement Test PASSED!")
	quit(0)
