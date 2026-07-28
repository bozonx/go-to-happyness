class_name SettlementGameModule
extends GameModule

const SettlementScene = preload("res://game/bootstrap/settlement_game.tscn")

## Transitional settlement module. It owns selection of the existing settlement
## bootstrap while that bootstrap is incrementally extracted from SettlementGame.

func module_id() -> StringName:
	return &"gth.settlement"


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
	settlement.start_on_ready = false
	runtime.attach_session_content(settlement)
	settlement.start_settlement_session(launch)
	return settlement.world_setup != null


func _launch_config(session: GameSessionConfig, parameters: Dictionary) -> GameLaunchConfig:
	var launch := GameLaunchConfig.for_tent_era()
	launch.map_ref = session.map_ref
	launch.map_document = session.map_document
	# Map-authored settlement overrides stay module-owned. This preserves the
	# former launch path while the host passes only generic session data.
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
