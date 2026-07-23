class_name GameLaunchManager
extends Node

## Application service for managing active game launch configuration and scene transitions.

var active_launch_config: GameLaunchConfig = GameLaunchConfig.for_tent_era()


func launch_game(config: GameLaunchConfig) -> void:
	if config != null:
		active_launch_config = config
	else:
		active_launch_config = GameLaunchConfig.for_tent_era()
	get_tree().change_scene_to_file("res://game/bootstrap/settlement_game.tscn")


func reset_to_default() -> void:
	active_launch_config = GameLaunchConfig.for_tent_era()
