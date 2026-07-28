extends SceneTree

## Actual launch path: an authored record reaches WorldSetup, runtime and a view.

const SettlementGameScene = preload("res://game/bootstrap/settlement_game.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var config := GameLaunchConfig.for_tent_era()
	config.map_document = MapDocumentService.new().load_map(config.map_ref)
	config.apply_map_start()
	var entity := MapEntityRecord.new()
	entity.id = &"launch_campfire"
	entity.archetype_id = &"core:campfire"
	entity.position = Vector3(3.5, 0.0, 3.5)
	entity.initial_state = &"cold"
	config.map_document.entities.entities.append(entity)
	var launch_manager := root.get_node_or_null("GameLaunchManager")
	if launch_manager != null:
		launch_manager.set("active_launch_config", config)
	var simulation := SettlementGameScene.instantiate()
	simulation.launch_config = config
	root.add_child(simulation)
	for _frame in range(4):
		await physics_frame
	var setup: WorldSetup = simulation.world_setup
	assert(setup.map_entity_runtime.by_id(&"launch_campfire") != null)
	var view := setup.map_entity_presenter.view_for(&"launch_campfire")
	assert(view != null and view.get_meta("map_entity_state") == &"cold")
	var fire := view.get_node_or_null("Fire") as Node3D
	assert(fire != null and not fire.visible, "cold state reached the launched view")
	simulation.queue_free()
	print("--- test_map_entity_runtime.gd PASSED ---")
	quit(0)
