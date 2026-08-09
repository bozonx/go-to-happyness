class_name SettlementGameModule
extends GameModule

const SettlementScene = preload("res://game/bootstrap/settlement_game.tscn")

## Settlement game module. Owns the settlement session lifecycle: it resolves
## start parameters into a GameLaunchConfig, instantiates the settlement scene,
## and manages save/restore. Gameplay constants live in SettlementConstants;
## the scene script remains a presentation adapter for the bootstrap.
##
## Progression is not resolved here. Eras are host functionality, so the session
## arrives with a `SessionProgression` already narrowed by the map policy, and
## this module only maps it onto its own stage enum.

func module_id() -> StringName:
	return &"gth.settlement"


func required_modules() -> Array[StringName]:
	return [&"core.world"]


## Party size is a `party`-scoped parameter offered to the player: a map narrows
## it with `restrict` and a start option proposes its own, but no map decides it
## by how many anchors somebody drew (`map_start.md` §5.3).
func start_parameters() -> Array[EntityPropertyDef]:
	return [
		EntityPropertyDef.integer(&"starting_population", "Стартовое население", 4, 1, 24,
			EntityPropertyDef.SCOPE_PARTY).offered_to_player(),
		EntityPropertyDef.integer(&"starting_money", "Монеты", 500, 0, 100000).offered_to_player(),
		EntityPropertyDef.integer(&"starting_wellbeing", "Благополучие", 75, 0, 100).offered_to_player(),
		EntityPropertyDef.text(&"biome", "Биом", "summer_valley", EntityPropertyDef.SCOPE_WORLD),
	]


func validate_session(session: GameSessionConfig) -> Array[String]:
	var errors: Array[String] = []
	var raw: Variant = session.module_parameters.get(module_id(), {})
	if not raw is Dictionary:
		return ["start parameters должны быть объектом"]
	var launch := _launch_config(session)
	errors.append_array(MapValidator.validate_party_capacity(
		launch.map_document, session.start_option, launch.starting_population,
		launch.has_spawn_override()))
	return errors


func start(runtime: GameRuntime, session: GameSessionConfig) -> bool:
	if not session.module_parameters.get(module_id(), {}) is Dictionary:
		push_error("[launch] settlement module requires settlement start parameters")
		return false
	var launch := _launch_config(session)
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
	return SettlementSaveLoader.new().restore(settlement, state)


func _launch_config(session: GameSessionConfig) -> GameLaunchConfig:
	var parameters := resolve_parameters(session.parameters_for(module_id()))
	var launch := GameLaunchConfig.for_tent_era()
	launch.map_ref = session.map_ref
	launch.map_document = session.map_document
	launch.spawn_override = session.spawn_override
	launch.start_option = session.start_option
	var option := session.start_option_record()
	if option != null:
		launch.spawn_group = option.spawn_group
		# The entrance's establishing shot (§4.1). It was authorable, validated and
		# then read by nobody — a map could name a camera and the first overview
		# frame still hung over the party.
		if option.camera != &"" and session.map_document != null:
			launch.camera_start = MapSpawnService.new().camera_position(
				session.map_document.zones, option.camera, session.map_document.meta.cell_size)
	# World style is map-owned. Starting resources and equipment are map-owned too:
	# they live on the backpack entity. Everything else arrives through the
	# recursively merged game/map/session parameters.
	if session.map_document != null:
		launch.apply_map_start()
	_apply_progression(launch, session.progression)
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


## Projects the resolved session progression onto the settlement stage enum. The
## rank is the era's position in the game's own catalogue, which is what makes
## `SettlementState.Era` a view of authored data rather than a second source.
func _apply_progression(launch: GameLaunchConfig, progression: SessionProgression) -> void:
	launch.progression_enabled = progression.enabled
	launch.era_names = progression.display_names()
	if progression.is_empty():
		return
	launch.allowed_eras = progression.era_ids.duplicate()
	launch.allowed_era_types = progression.allowed_ranks()
	launch.era_id = progression.current_era
	launch.era_type = progression.current_rank()
