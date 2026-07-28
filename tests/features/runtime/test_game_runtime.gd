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
	assert(definition.module_ids == [&"core.world", &"gth.settlement"])
	launch_manager.set("active_session", GameSessionConfig.create(definition, config.map_ref, config.map_document, {
		&"gth.settlement": GameSessionConfig.settlement_parameters_from(config),
	}))
	var runtime := GameRuntimeScene.instantiate() as GameRuntime
	root.add_child(runtime)
	for _frame in range(4):
		await physics_frame
	assert(runtime.active_session != null)
	var settlement := runtime.session_content as SettlementGame
	assert(settlement != null, "settlement must be module-owned session content")
	assert(settlement.launch_config != null)
	assert(settlement.launch_config != config, "runtime must receive module parameters, not the legacy launch object")
	assert(settlement.launch_config.map_document == config.map_document)
	assert(settlement.launch_config.starting_population == config.starting_population)
	assert(settlement.world_setup != null, "settlement module must initialize the existing game")
	runtime.queue_free()
	await process_frame
	await _assert_world_showcase(launch_manager)
	print("--- test_game_runtime.gd PASSED ---")
	quit(0)


func _assert_world_showcase(launch_manager: Node) -> void:
	var definition := GameModuleRegistry.resolve_definition(&"core:world_showcase")
	assert(definition != null)
	assert(definition.module_ids == [&"core.world", &"gth.world_showcase"])
	var map := MapDocumentService.new().load_map(definition.default_map)
	assert(map != null)
	launch_manager.set("active_session", GameSessionConfig.create(definition, definition.default_map, map))
	var runtime := GameRuntimeScene.instantiate() as GameRuntime
	root.add_child(runtime)
	for _frame in range(4):
		await physics_frame
	assert(runtime.active_session != null)
	var showcase := runtime.session_content as WorldShowcase
	assert(showcase != null, "showcase must not instantiate SettlementGame")
	assert(showcase.world_setup != null)
	assert(showcase.world_setup.terrain_grid == map.terrain)
	runtime.queue_free()
