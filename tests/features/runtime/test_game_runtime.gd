extends SceneTree

## The migration proof: Settlement starts through the generic definition →
## session → runtime → module path, not through settlement_game.tscn.

const GameRuntimeScene := preload("res://game/bootstrap/game_runtime.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var launch_manager := root.get_node_or_null("GameLaunchManager")
	assert(launch_manager != null, "GameLaunchManager autoload is required")
	var config := GameLaunchConfig.for_tent_era()
	config.map_document = MapDocumentService.new().load_map(config.map_ref)
	config.apply_map_start()
	var definition := GameModuleRegistry.resolve_definition(&"core:settlement")
	assert(definition != null)
	assert(definition.module_ids == [&"gth.settlement"])
	launch_manager.set("active_session", GameSessionConfig.create(definition, config.map_ref, config.map_document, {
		&"gth.settlement": GameSessionConfig.settlement_parameters_from(config),
	}))
	var runtime := GameRuntimeScene.instantiate() as GameRuntime
	root.add_child(runtime)
	for _frame in range(4):
		await physics_frame
	assert(runtime.active_session != null)
	assert(runtime.launch_config != null)
	assert(runtime.launch_config != config, "runtime must receive module parameters, not the legacy launch object")
	assert(runtime.launch_config.map_document == config.map_document)
	assert(runtime.launch_config.starting_population == config.starting_population)
	assert(runtime.world_setup != null, "settlement module must initialize the existing game")
	runtime.queue_free()
	print("--- test_game_runtime.gd PASSED ---")
	quit(0)
