extends SceneTree

## The migration proof: Settlement starts through the generic definition →
## session → runtime → module path, not through settlement_game.tscn.

const GameRuntimeScene := preload("res://game/bootstrap/game_runtime.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var launch_manager := root.get_node_or_null("GameLaunchManager")
	assert(launch_manager != null, "GameLaunchManager autoload is required")
	var definition := GameModuleRegistry.resolve_definition(&"core:settlement")
	assert(definition != null)
	assert(definition.module_ids == [&"core.world", &"gth.settlement"])
	var map := MapDocumentService.new().load_map(definition.default_map)
	assert(map != null, "settlement default map must load")
	launch_manager.set("active_session", GameSessionConfig.create(definition, definition.default_map, map))
	var runtime := GameRuntimeScene.instantiate() as GameRuntime
	root.add_child(runtime)
	for _frame in range(4):
		await physics_frame
	assert(runtime.active_session != null)
	assert(runtime.active_modules.has(&"core.world"))
	assert(runtime.active_modules.has(&"gth.settlement"))
	assert(runtime.world_session != null, "core.world must own the active map session")
	assert(runtime.world_session.nav_grid != null)
	var settlement := runtime.session_content as SettlementGame
	assert(settlement != null, "settlement must be module-owned session content")
	assert(settlement.world_session == runtime.world_session)
	assert(settlement.nav_grid == runtime.world_session.nav_grid)
	assert(settlement.launch_config != null)
	assert(settlement.launch_config.map_document == map)
	assert(settlement.launch_config.starting_population == 4)
	assert(settlement.world_setup != null, "settlement module must initialize the existing game")
	assert(SessionSaveCoordinator.save_quicksave(runtime))
	var settlement_save := SaveData.new()
	assert(settlement_save.load_from_file(SessionSaveCoordinator.QUICKSAVE_PATH))
	assert(settlement_save.game_header.get("id") == "settlement")
	assert(settlement_save.game_header.get("revision") == definition.revision,
		"the save must record which revision of the game wrote it")
	assert(settlement_save.module_sections.has("gth.settlement"))
	assert(settlement_save.module_section_version(&"gth.settlement") == SettlementGameModule.new().section_version())
	var saved_money := settlement.settlement.money
	settlement.settlement.money = 1
	assert(SessionSaveCoordinator.load_pending(runtime, SessionSaveCoordinator.QUICKSAVE_PATH))
	assert(settlement.settlement.money == saved_money)
	runtime.stop_session()
	root.remove_child(runtime)
	runtime.free()
	await process_frame
	await physics_frame
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
	assert(runtime.active_modules.has(&"core.world"))
	assert(runtime.active_modules.has(&"gth.world_showcase"))
	assert(runtime.world_session != null)
	var showcase := runtime.session_content as WorldShowcase
	assert(showcase != null, "showcase must not instantiate SettlementGame")
	assert(showcase.world_session == runtime.world_session)
	assert(showcase.world_setup != null)
	assert(showcase.world_setup.terrain_grid == map.terrain)
	assert(showcase.world_session.nav_grid.terrain_field() != null)
	showcase.camera_controller.camera_yaw = 17.0
	assert(SessionSaveCoordinator.save_quicksave(runtime))
	var save := SaveData.new()
	assert(save.load_from_file(SessionSaveCoordinator.QUICKSAVE_PATH))
	assert(save.game_header.get("id") == "world_showcase")
	assert(save.module_section(&"gth.world_showcase").get("camera", {}).get("yaw") == 17.0)
	showcase.camera_controller.camera_yaw = 90.0
	assert(SessionSaveCoordinator.load_pending(runtime, SessionSaveCoordinator.QUICKSAVE_PATH))
	assert(showcase.camera_controller.camera_yaw == 17.0)
	runtime.stop_session()
	root.remove_child(runtime)
	runtime.free()
	await process_frame
	await physics_frame
