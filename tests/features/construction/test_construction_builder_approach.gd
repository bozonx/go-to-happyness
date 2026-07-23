extends SceneTree


func _init() -> void:
	var scene_root := Node3D.new()
	root.add_child(scene_root)
	await process_frame
	await physics_frame

	var runtime := ConstructionRuntime.new()
	runtime.scene_root = scene_root
	runtime.settlement = SettlementState.new()
	runtime.building_registry = BuildingRegistry.new()
	runtime.citizens = []
	runtime.workers_changed = func() -> void: pass
	runtime.navigation_changed = func() -> void: pass
	var service := ConstructionService.new()
	service.configure(runtime)
	service.configure_scenes(load("res://game/features/buildings/presentation/construction_site.tscn") as PackedScene, load("res://game/features/buildings/presentation/construction_entrance_post.tscn") as PackedScene)

	var cell := Vector2i(2, 3)
	runtime.building_registry.reserve(cell, Vector3(2.0, 0.0, 3.0), Vector2i(3, 3))
	var site: ConstructionSite = service.start_site(cell, "campfire", Vector3(2.0, 0.0, 3.0))
	var service_positions: Array = site.node.get_meta("service_positions")
	assert(service_positions.size() > 0)
	# Make the site supplied so a construction order can be issued.
	var resource := str(site.required_materials.keys()[0])
	var required: int = int(site.required_materials.get(resource, 0))
	if required > 0:
		site.delivered_materials[resource] = required

	var builder := Citizen.new()
	builder.ai_id = 1
	scene_root.add_child(builder)
	builder.global_position = Vector3(2.0, 0.0, -2.0)
	await physics_frame

	# Find the nearest service position (south side) and block it.
	var nearest_position := Vector3.INF
	var nearest_distance := INF
	for candidate in service_positions:
		if not candidate is Vector3:
			continue
		var candidate_position: Vector3 = candidate as Vector3
		var distance := builder.global_position.distance_squared_to(candidate_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_position = candidate_position
	assert(nearest_position != Vector3.INF)

	builder.route_reachability_query = func(_from: Vector3, target: Vector3, _allow_house: bool) -> bool:
		return target.distance_squared_to(nearest_position) > 0.01
	builder.pathfinder = func(_from: Vector3, target: Vector3, _allow: bool) -> RouteResult:
		return RouteResult.success([target], target, -1)
	builder.navigation_revision_query = func() -> int:
		return -1

	builder.assign_construction(site.node)
	assert(builder.state == Citizen.State.CONSTRUCTING)
	assert(builder.construction_site == site.node)
	assert(builder.construction_position.distance_squared_to(nearest_position) > 0.01, "Builder must avoid the blocked nearest entrance and choose a reachable approach")

	# Simulate movement until arrival.
	var reached := false
	for _i in range(400):
		await physics_frame
		if builder.global_position.distance_to(builder.construction_position) < 0.5:
			reached = true
			break
	assert(reached, "Builder should reach the chosen construction approach within the time budget")
	quit(0)
