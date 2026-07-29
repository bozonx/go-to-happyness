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
	assert(runtime.world_session != null, "core.world must own the active map session")
	var settlement := runtime.session_content as SettlementGame
	assert(settlement != null, "settlement must be module-owned session content")
	assert(settlement.world_session == runtime.world_session)
	assert(settlement.launch_config != null)
	assert(settlement.launch_config != config, "runtime must receive module parameters, not the legacy launch object")
	assert(settlement.launch_config.map_document == config.map_document)
	assert(settlement.launch_config.starting_population == config.starting_population)
	assert(settlement.world_setup != null, "settlement module must initialize the existing game")
	assert(SessionSaveCoordinator.save_quicksave(runtime))
	var settlement_save := SaveData.new()
	assert(settlement_save.load_from_file(SessionSaveCoordinator.QUICKSAVE_PATH))
	assert(settlement_save.game_header.get("id") == "settlement")
	assert(settlement_save.module_states.has("gth.settlement"))
	var saved_money := settlement.settlement.money
	settlement.settlement.money = 1
	assert(SessionSaveCoordinator.load_pending(runtime, SessionSaveCoordinator.QUICKSAVE_PATH))
	assert(settlement.settlement.money == saved_money)
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
	assert(runtime.world_session != null)
	var showcase := runtime.session_content as WorldShowcase
	assert(showcase != null, "showcase must not instantiate SettlementGame")
	assert(showcase.world_session == runtime.world_session)
	assert(showcase.world_setup != null)
	assert(showcase.world_setup.terrain_grid == map.terrain)
	showcase.camera_controller.camera_yaw = 17.0
	assert(SessionSaveCoordinator.save_quicksave(runtime))
	var save := SaveData.new()
	assert(save.load_from_file(SessionSaveCoordinator.QUICKSAVE_PATH))
	assert(save.game_header.get("id") == "world_showcase")
	assert(save.module_states.get("gth.world_showcase", {}).get("camera", {}).get("yaw") == 17.0)
	showcase.camera_controller.camera_yaw = 90.0
	assert(SessionSaveCoordinator.load_pending(runtime, SessionSaveCoordinator.QUICKSAVE_PATH))
	assert(showcase.camera_controller.camera_yaw == 17.0)
	runtime.queue_free()
