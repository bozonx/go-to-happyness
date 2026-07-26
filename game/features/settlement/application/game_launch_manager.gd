extends Node

## Application service for managing active game launch configuration and scene transitions.

const GameLaunchConfigScript = preload("res://game/features/settlement/domain/game_launch_config.gd")
const SaveDataScript = preload("res://game/features/save_load/domain/save_data.gd")
const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")
const BUILDING_EDITOR_SCENE := "res://game/features/buildings/presentation/editor/building_editor.tscn"
const MAP_EDITOR_SCENE := "res://game/features/world/presentation/editor/map_editor.tscn"

var active_launch_config: GameLaunchConfigScript = GameLaunchConfigScript.for_tent_era()
var pending_save_path: String = ""
## Read by BuildingEditor to decide dev vs player mode. Set by launch_building_editor.
var editor_player_mode: bool = false
## Map the territory editor should open on entry, as a runtime key. Empty starts
## the editor on a new unsaved map.
var pending_editor_map: StringName = &""

var _map_service := MapDocumentService.new()


func launch_game(config: GameLaunchConfigScript) -> void:
	pending_save_path = ""
	if config != null:
		active_launch_config = config
	else:
		active_launch_config = GameLaunchConfigScript.for_tent_era()
	_resolve_map(active_launch_config)
	get_tree().change_scene_to_file("res://game/bootstrap/settlement_game.tscn")


## Loads the package before the scene changes. A map that cannot be read is
## reported and the session starts on the legacy flat board rather than on a
## half-built world — the player gets a game, not a crash.
func _resolve_map(config: GameLaunchConfigScript) -> void:
	if config == null or config.map_document != null or String(config.map_ref).is_empty():
		return
	var document := _map_service.load_map(config.map_ref)
	if document == null:
		push_warning("[launch] карта %s не открылась: %s" % [config.map_ref, _map_service.last_error])
		return
	config.map_document = document
	config.apply_map_start()


func launch_from_save(save_path: String) -> void:
	var save_data := SaveDataScript.new()
	if not save_data.load_from_file(save_path):
		push_warning("[launch] сохранение не читается: %s" % save_path)
		return
	var map_reference: Variant = save_data.world_state.get("map_ref", {})
	if map_reference is Dictionary and not (map_reference as Dictionary).is_empty():
		var reference := map_reference as Dictionary
		var source := StringName(reference.get("source", "core"))
		var id := StringName(reference.get("id", ""))
		if String(id).is_empty():
			push_warning("[launch] в сохранении некорректная ссылка на карту")
			return
		active_launch_config = GameLaunchConfigScript.for_tent_era()
		active_launch_config.map_ref = ContentIdScript.runtime_key(source, id)
		_resolve_map(active_launch_config)
		if active_launch_config.map_document == null:
			push_warning("[launch] сохранение не открыто: карта %s не найдена" % active_launch_config.map_ref)
			return
		var saved_revision := String(reference.get("revision", ""))
		if not saved_revision.is_empty() and active_launch_config.map_document.meta.revision != saved_revision:
			push_warning("[launch] карта %s изменилась после сохранения; будет использована текущая версия." % active_launch_config.map_ref)
	pending_save_path = save_path
	get_tree().change_scene_to_file("res://game/bootstrap/settlement_game.tscn")


func launch_building_editor(player_mode: bool = true) -> void:
	pending_save_path = ""
	editor_player_mode = player_mode or not OS.has_feature("editor")
	get_tree().change_scene_to_file(BUILDING_EDITOR_SCENE)


func launch_map_editor(map_key: StringName = &"") -> void:
	pending_save_path = ""
	pending_editor_map = map_key
	get_tree().change_scene_to_file(MAP_EDITOR_SCENE)


func return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://game/features/ui/presentation/main_menu/main_menu.tscn")


func reset_to_default() -> void:
	pending_save_path = ""
	active_launch_config = GameLaunchConfigScript.for_tent_era()
