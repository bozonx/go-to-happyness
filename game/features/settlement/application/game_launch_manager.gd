extends Node

## Application service for managing active game launch configuration and scene transitions.

const GameLaunchConfigScript = preload("res://game/features/settlement/domain/game_launch_config.gd")
const BUILDING_EDITOR_SCENE := "res://game/features/buildings/presentation/editor/building_editor.tscn"

var active_launch_config: GameLaunchConfigScript = GameLaunchConfigScript.for_tent_era()
var pending_save_path: String = ""
## Read by BuildingEditor to decide dev vs player mode. Set by launch_building_editor.
var editor_player_mode: bool = false


func launch_game(config: GameLaunchConfigScript) -> void:
	pending_save_path = ""
	if config != null:
		active_launch_config = config
	else:
		active_launch_config = GameLaunchConfigScript.for_tent_era()
	get_tree().change_scene_to_file("res://game/bootstrap/settlement_game.tscn")


func launch_from_save(save_path: String) -> void:
	pending_save_path = save_path
	get_tree().change_scene_to_file("res://game/bootstrap/settlement_game.tscn")


func launch_building_editor(player_mode: bool = true) -> void:
	pending_save_path = ""
	editor_player_mode = player_mode
	get_tree().change_scene_to_file(BUILDING_EDITOR_SCENE)


func reset_to_default() -> void:
	pending_save_path = ""
	active_launch_config = GameLaunchConfigScript.for_tent_era()

