class_name SettlementGameModule
extends GameModule

const SettlementScene = preload("res://game/bootstrap/settlement_game.tscn")

## Settlement game module. Owns the settlement session lifecycle: it resolves
## start parameters into a GameLaunchConfig, instantiates the settlement scene,
## and manages save/restore. Gameplay constants live in SettlementConstants;
## the scene script remains a presentation adapter for the bootstrap.

func module_id() -> StringName:
	return &"gth.settlement"


func required_modules() -> Array[StringName]:
	return [&"core.world"]


func validate_session(session: GameSessionConfig) -> Array[String]:
	var parameters: Variant = session.module_parameters.get(module_id(), {})
	if not parameters is Dictionary:
		return ["start parameters должны быть объектом"]
	var launch := _launch_config(session, parameters as Dictionary)
	return MapValidator.validate_party_spawns(launch.map_document, launch.starting_population)


func start(runtime: GameRuntime, session: GameSessionConfig) -> bool:
	var parameters: Variant = session.module_parameters.get(module_id(), {})
	if not parameters is Dictionary:
		push_error("[launch] settlement module requires settlement start parameters")
		return false
	var launch := _launch_config(session, parameters as Dictionary)
	var settlement := SettlementScene.instantiate() as SettlementGame
	if settlement == null:
		push_error("[launch] failed to instantiate settlement session")
		return false
	settlement.world_session = runtime.world_session
	runtime.attach_session_content(settlement)
	settlement.start_session(launch)
	return settlement.world_setup != null


func save_state(runtime: GameRuntime) -> Dictionary:
	var settlement := runtime.session_content as SettlementGame
	return SaveGameService.capture_settlement_section(settlement)


func restore_state(runtime: GameRuntime, state: Dictionary) -> bool:
	var settlement := runtime.session_content as SettlementGame
	if settlement == null:
		return false
	var save_data := SaveData.new()
	save_data.module_states[module_id()] = state.duplicate(true)
	return SettlementSaveLoader.new().restore(settlement, save_data)


func _launch_config(session: GameSessionConfig, parameters: Dictionary) -> GameLaunchConfig:
	var launch := GameLaunchConfig.for_tent_era()
	launch.map_ref = session.map_ref
	launch.map_document = session.map_document
	# Map-owned visual overrides: era and world style are properties of the map,
	# not of the settlement module. Economy (money, population) is module-owned
	# and comes from the game definition's start_parameters. Starting resources
	# and equipment are map-owned: they live on the backpack entity.
	if session.map_document != null:
		launch.apply_map_start()
	launch.era_id = StringName(parameters.get("era", launch.era_id))
	launch.era_type = int(parameters.get("era_type", launch.era_type))
	launch.biome_id = StringName(parameters.get("biome", launch.biome_id))
	launch.world_style = StringName(parameters.get("world_style", launch.world_style))
	launch.starting_money = int(parameters.get("starting_money", launch.starting_money))
	launch.starting_wellbeing = int(parameters.get("starting_wellbeing", launch.starting_wellbeing))
	launch.starting_population = int(parameters.get("starting_population", launch.starting_population))
	if parameters.get("starting_resources") is Dictionary:
		launch.starting_resources = (parameters["starting_resources"] as Dictionary).duplicate(true)
	if parameters.get("starting_equipment") is Dictionary:
		launch.starting_equipment = (parameters["starting_equipment"] as Dictionary).duplicate(true)
	if parameters.get("custom_parameters") is Dictionary:
		launch.custom_parameters = (parameters["custom_parameters"] as Dictionary).duplicate(true)
	return launch
