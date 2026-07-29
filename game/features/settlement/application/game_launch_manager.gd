class_name SettlementLaunchManager
extends RuntimeLaunchManager

## Compatibility adapter for direct Settlement scene runs and old tests. The
## autoload is RuntimeLaunchManager; no host path should use this class.

var active_launch_config: GameLaunchConfig = GameLaunchConfig.for_tent_era()


func _ready() -> void:
	prepare_game_launch(active_launch_config)


func launch_game(config: GameLaunchConfig) -> void:
	var prepared := prepare_game_launch(config)
	if prepared.map_document == null:
		push_warning("[launch] игровая сессия отменена: нужна доступная карта")
		return
	launch_game_definition(&"core:settlement", prepared.map_ref, {
		&"gth.settlement": GameSessionConfig.settlement_parameters_from(prepared),
	}, prepared.map_document)


func prepare_game_launch(config: GameLaunchConfig) -> GameLaunchConfig:
	active_launch_config = config if config != null else GameLaunchConfig.for_tent_era()
	if active_launch_config.map_document == null and not active_launch_config.map_ref.is_empty():
		active_launch_config.map_document = _map_service.load_map(active_launch_config.map_ref)
		if active_launch_config.map_document != null:
			active_launch_config.apply_map_start()
	return active_launch_config
