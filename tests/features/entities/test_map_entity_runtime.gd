extends SceneTree

## Actual launch path: an authored record reaches WorldSetup, runtime and a view.

const GameRuntimeScene = preload("res://game/bootstrap/game_runtime.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition := GameModuleRegistry.resolve_definition(&"core:settlement")
	assert(definition != null)
	var map := MapDocumentService.new().load_map(definition.default_map)
	assert(map != null)
	var entity := MapEntityRecord.new()
	entity.id = &"launch_campfire"
	entity.archetype_id = &"core:campfire"
	entity.position = Vector3(3.5, 0.0, 3.5)
	entity.initial_state = &"cold"
	map.entities.entities.append(entity)
	var obstacle := MapScatterLayer.Record.new()
	obstacle.archetype_index = map.scatter.archetype_index_of(&"core:boulder")
	obstacle.cell = Vector2i(-10, -10)
	map.scatter.add(obstacle)
	var launch_manager := root.get_node_or_null("GameLaunchManager")
	assert(launch_manager != null)
	launch_manager.active_session = GameSessionConfig.create(definition, &"editor:preview", map)
	var runtime := GameRuntimeScene.instantiate() as GameRuntime
	root.add_child(runtime)
	for _frame in range(4):
		await physics_frame
	var simulation := runtime.session_content as SettlementGame
	assert(simulation != null)
	var setup: WorldSetup = simulation.world_setup
	assert(setup.map_entity_runtime.by_id(&"launch_campfire") != null)
	var view := setup.map_entity_presenter.view_for(&"launch_campfire")
	assert(view != null and view.get_meta("map_entity_state") == &"cold")
	var fire := view.get_node_or_null("Fire") as Node3D
	assert(fire != null and not fire.visible, "cold state reached the launched view")
	assert(simulation.world_session.nav_grid.is_blocked(Vector2i(-10, -10)),
		"blocking_navigation массового объекта не дошёл до базового NavGrid")
	assert(_has_collision_proxy(setup.map_scatter_world),
		"scene-owned коллизия массового препятствия не поднята в runtime")
	runtime.stop_session()
	root.remove_child(runtime)
	runtime.free()
	await process_frame
	await physics_frame
	print("--- test_map_entity_runtime.gd PASSED ---")
	quit(0)


static func _has_collision_proxy(root_node: Node) -> bool:
	if root_node == null:
		return false
	if String(root_node.name).begins_with("ScatterCollision_"):
		return true
	for child: Node in root_node.get_children():
		if _has_collision_proxy(child):
			return true
	return false
