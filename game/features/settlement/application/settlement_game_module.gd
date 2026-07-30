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
	var errors := _validate_progression(session)
	var parameters: Variant = session.module_parameters.get(module_id(), {})
	if not parameters is Dictionary:
		errors.append("start parameters должны быть объектом")
		return errors
	var launch := _launch_config(session, parameters as Dictionary)
	errors.append_array(MapValidator.validate_party_spawns(launch.map_document, launch.starting_population))
	return errors


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
	# World style is map-owned. Progression and economy are module-owned and arrive
	# through the recursively merged game/map/session parameters. Starting resources
	# and equipment are map-owned: they live on the backpack entity.
	if session.map_document != null:
		launch.apply_map_start()
	_apply_progression_policy(launch, session, parameters)
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


func _apply_progression_policy(launch: GameLaunchConfig, session: GameSessionConfig, parameters: Dictionary) -> void:
	var progression: Dictionary = parameters.get("progression", {}) if parameters.get("progression", {}) is Dictionary else {}
	launch.progression_mode = StringName(progression.get("mode", "inherit"))
	launch.progression_enabled = launch.progression_mode != &"disabled"
	for raw: Variant in progression.get("allowed_eras", []):
		launch.allowed_eras.append(StringName(raw))
	var all_eras := session.definition.progression.era_ids()
	for era: EraDefinition in session.definition.progression.eras:
		launch.era_names[era.id] = era.display_name()
	var default_era := StringName(progression.get("default_era", ""))
	if launch.progression_mode in [&"inherit", &"disabled"]:
		launch.allowed_eras = all_eras
	elif launch.progression_mode == &"fixed":
		launch.allowed_eras = [default_era] if not default_era.is_empty() else []
	elif launch.allowed_eras.is_empty():
		launch.allowed_eras = all_eras
	for era_id: StringName in launch.allowed_eras:
		var era_rank := session.definition.progression.rank_of(era_id)
		if era_rank >= 0:
			launch.allowed_era_types.append(era_rank)
	if default_era.is_empty() or default_era not in launch.allowed_eras:
		default_era = launch.allowed_eras[0] if not launch.allowed_eras.is_empty() else &"tent"
	launch.era_id = default_era
	launch.era_type = maxi(0, session.definition.progression.rank_of(default_era))
	if not launch.progression_enabled and not all_eras.is_empty():
		launch.era_id = all_eras[-1]
		launch.era_type = all_eras.size() - 1
		launch.allowed_era_types.clear()
		for era_rank: int in all_eras.size():
			launch.allowed_era_types.append(era_rank)


func _validate_progression(session: GameSessionConfig) -> Array[String]:
	var errors: Array[String] = []
	var parameters: Variant = session.module_parameters.get(module_id(), {})
	if not parameters is Dictionary:
		return errors
	var raw_progression: Variant = (parameters as Dictionary).get("progression", {})
	if not raw_progression is Dictionary:
		return ["gth.settlement.progression должен быть объектом"]
	var policy := raw_progression as Dictionary
	var mode := StringName(policy.get("mode", "inherit"))
	if mode not in [&"inherit", &"restricted", &"fixed", &"disabled"]:
		errors.append("неизвестный режим прогрессии %s" % mode)
	var known := session.definition.progression.era_ids()
	var allowed: Array[StringName] = []
	for raw: Variant in policy.get("allowed_eras", []):
		var era_id := StringName(raw)
		allowed.append(era_id)
		if era_id not in known:
			errors.append("карта разрешает неизвестную эру %s" % era_id)
	if mode == &"restricted" and allowed.is_empty():
		errors.append("режим restricted требует allowed_eras")
	var default_era := StringName(policy.get("default_era", ""))
	if mode == &"fixed" and default_era.is_empty():
		errors.append("режим fixed требует default_era")
	if not default_era.is_empty() and default_era not in known:
		errors.append("неизвестная стартовая эра %s" % default_era)
	if not default_era.is_empty() and not allowed.is_empty() and default_era not in allowed:
		errors.append("стартовая эра %s не входит в allowed_eras" % default_era)
	return errors
