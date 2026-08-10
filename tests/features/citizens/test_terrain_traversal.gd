extends SceneTree

## Regression for finite-body traversal at a terrace ramp. Domain routing can
## prove that a centre line is topologically valid; only a real CharacterBody3D
## over the production collision mesh proves that its capsule fits.

const CitizenScene := preload("res://game/features/citizens/presentation/citizen_actor.tscn")


func _init() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, 32)
	for z in range(-8, 9):
		for x in range(4, 9):
			assert(terrain.set_height(Vector2i(x, z), 2))
	assert(terrain.place_ramp(Vector2i(3, 0), SlopeCatalog.VERY_STEEP, SlopeCatalog.DIR_E))

	var terrain_world := GridTerrainWorld.new()
	fixture.add_child(terrain_world)
	terrain_world.configure(terrain)
	terrain_world.rebuild_pending_now()
	var nav_grid := NavGrid.new()
	nav_grid.configure(1.0, 32)
	TerrainNavigationPublisher.publish(terrain, nav_grid)
	var route_service := GridRouteService.new()
	route_service.configure(nav_grid)
	var facade := NavigationFacade.new()
	facade.configure(nav_grid, route_service)
	var navigation := NavigationService.new()
	navigation.configure(nav_grid, facade)

	var actor: Citizen = CitizenScene.instantiate()
	actor.position = Vector3(0.5, 0.05, 2.5)
	fixture.add_child(actor)
	# Drive the production movement controller explicitly so the fixture owns one
	# physics tick and the actor's state machine cannot issue a second movement.
	actor.set_physics_process(false)
	actor.setup_navigation(
		func(from: Vector3, to: Vector3, allow: bool) -> RouteResult: return navigation.find_route(from, to, allow),
		Callable(),
		Callable(),
		# Keep the physical smoke test comfortably inside the runner's 300-frame
		# budget; this changes only speed, not the capsule or collision path.
		func(_position: Vector3) -> float: return 1.5,
		func() -> int: return nav_grid.topology_revision(),
		Callable(),
		Callable(),
		Callable(),
		Callable(),
		func(from: Vector3, to: Vector3, allow: bool) -> RouteResult: return navigation.find_recovery_path(from, to, allow),
		func(from: Vector3, points: Array[Vector3], allow: bool) -> bool: return nav_grid.is_waypoint_path_clear(from, points, allow),
	)
	await physics_frame
	await physics_frame

	var destination := Vector3(6.5, 1.0, 2.5)
	var arrived := false
	for _frame in 300:
		actor.movement_controller.apply_gravity(actor, 1.0 / 60.0)
		arrived = actor.movement_controller.move_to(actor, destination, 1.0 / 60.0, false, false, false, 0.08)
		await physics_frame
		if arrived or actor.navigation_failed:
			break
	assert(arrived, "the physical capsule must reach the terrace through the ramp without stalling")
	assert(not actor.navigation_failed)

	fixture.queue_free()
	await process_frame
	quit(0)
