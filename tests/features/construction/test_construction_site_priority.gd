extends SceneTree


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame

	var warehouse_position := Vector3(12.0, 0.0, 12.0)
	var warehouse_blueprint := BuildingBlueprints.get_blueprint("straw_warehouse")
	simulation.building_registry.reserve(Vector2i(12, 12), warehouse_position, warehouse_blueprint.footprint)
	var waiting_site: ConstructionSite = simulation._create_construction_site(Vector2i(12, 12), "straw_warehouse", warehouse_position, 0, warehouse_blueprint, warehouse_blueprint.footprint)

	var tent_position := Vector3(16.0, 0.0, 12.0)
	var tent_blueprint := BuildingBlueprints.get_blueprint("tent")
	simulation.building_registry.reserve(Vector2i(16, 12), tent_position, tent_blueprint.footprint)
	var supplied_site: ConstructionSite = simulation._create_construction_site(Vector2i(16, 12), "tent", tent_position, 0, tent_blueprint, tent_blueprint.footprint)
	for resource_type in supplied_site.required_materials:
		var required := int(supplied_site.required_materials.get(resource_type, 0))
		if required > 0:
			supplied_site.delivered_materials[resource_type] = required

	assert(waiting_site.material_progress() == 0.0)
	assert(supplied_site.material_progress() > supplied_site.progress)
	assert(simulation._preferred_construction_site() == supplied_site, "Builders must not wait at an unsupplied higher-priority project while another site can advance")

	root.remove_child(simulation)
	simulation.free()
	quit(0)
