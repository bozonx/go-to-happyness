extends SceneTree


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame
	for _frame in range(10):
		await physics_frame

	simulation.selected_builder = simulation.hero_citizen
	simulation._appoint_official(simulation.hero_citizen)
	assert(simulation._player_can_command_labor())

	var position := Vector3(12.0, 0.0, 12.0)
	var blueprint := BuildingBlueprints.get_blueprint("campfire")
	var cell := simulation._placement_key(position) as Vector2i
	simulation.building_registry.reserve(cell, position, blueprint.footprint)
	var site: ConstructionSite = simulation._create_construction_site(cell, "campfire", position, 0, blueprint, blueprint.footprint)
	var construction_resource := str(site.required_materials.keys()[0])
	var required_amount: int = int(site.required_materials.get(construction_resource, 0))
	if required_amount > 0:
		site.delivered_materials[construction_resource] = required_amount
	await physics_frame
	assert(site.is_supplied(), "site should be supplied")

	var builder: Citizen = simulation.citizens[2]
	builder.global_position = Vector3(8.0, 0.0, 8.0)
	builder.idle()
	simulation._assign_daily_order(builder, "construction")

	builder.pathfinder = func(_from: Vector3, target: Vector3, _allow: bool) -> RouteResult:
		return RouteResult.success([target], target)
	builder.route_reachability_query = func(_from: Vector3, _target: Vector3, _allow: bool) -> bool:
		return true

	for i in range(120):
		await physics_frame
		if builder.state == Citizen.State.CONSTRUCTING:
			print("became CONSTRUCTING at frame ", i, " pos ", builder.global_position, " target ", builder.construction_position)
			break

	print("final state ", builder.state, " role ", builder.active_role, " site ", builder.construction_site, " pos ", builder.global_position, " target ", builder.construction_position)
	assert(builder.state == Citizen.State.CONSTRUCTING, "builder should be in CONSTRUCTING state")
	assert(builder.construction_site == site.node, "builder should be assigned to site")
	assert(builder.global_position.distance_to(builder.construction_position) <= 1.0, "builder should reach construction position")
	quit(0)
