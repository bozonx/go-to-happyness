extends Node

## Application service for managing active game launch configuration and scene transitions.

const GameLaunchConfigScript = preload("res://game/features/settlement/domain/game_launch_config.gd")
const SaveDataScript = preload("res://game/features/save_load/domain/save_data.gd")
const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")
const BUILDING_EDITOR_SCENE := "res://game/features/buildings/presentation/editor/building_editor.tscn"
const MAP_EDITOR_SCENE := "res://game/features/world/presentation/editor/map_editor.tscn"
const GAME_RUNTIME_SCENE := "res://game/bootstrap/game_runtime.tscn"

var active_launch_config: GameLaunchConfigScript = GameLaunchConfigScript.for_tent_era()
## Generic session selected by the menu or save loader. The old config remains
## only for settlement compatibility and editor entry points during migration.
var active_session: GameSessionConfig = null
var pending_save_path: String = ""
## Read by both editors to decide dev vs player mode (content_packaging.md §9).
## One flag for both, because the rule is one: dev authors the shipped pack and
## exists only inside Godot; everything launched from the menu is player mode.
var editor_dev_mode: bool = false
## Whether `editor_dev_mode` was actually chosen by a launch. This autoload also
## exists when an editor scene is run straight from Godot (F6), and there the
## scene's own `dev_mode` export is the answer — without this flag that case would
## silently read the default and drop the developer into player mode.
var editor_mode_forced: bool = false
## Map the territory editor should open on entry, as a runtime key. Empty starts
## the editor on a new unsaved map.
var pending_editor_map: StringName = &""

var _map_service := MapDocumentService.new()


func _ready() -> void:
	prepare_game_launch(active_launch_config)


func launch_game(config: GameLaunchConfigScript) -> void:
	pending_save_path = ""
	var prepared := prepare_game_launch(config)
	if prepared.map_document == null:
		push_warning("[launch] игровая сессия отменена: нужна доступная карта")
		return
	launch_game_definition(&"core:settlement", prepared.map_ref, {
		&"gth.settlement": GameSessionConfig.settlement_parameters_from(prepared),
	}, prepared.map_document)


## Generic host entry point. Menu, library, editor test-run and installed packs
## all resolve the same definition -> map -> session -> runtime path.
func launch_game_definition(
	definition_key: StringName,
	map_ref: StringName = &"",
	module_parameters: Dictionary = {},
	resolved_map: MapDocument = null,
) -> void:
	pending_save_path = ""
	var definition := GameModuleRegistry.resolve_definition(definition_key)
	if definition == null:
		push_error("[launch] game definition is unavailable: %s" % definition_key)
		return
	var selected_map := map_ref if not map_ref.is_empty() else definition.default_map
	var document := resolved_map if resolved_map != null else _map_service.load_map(selected_map)
	if document == null:
		push_warning("[launch] игровая сессия отменена: карта %s не открылась: %s" % [selected_map, _map_service.last_error])
		return
	active_session = GameSessionConfig.create(definition, selected_map, document, module_parameters)
	get_tree().change_scene_to_file(GAME_RUNTIME_SCENE)


## Makes a launch configuration ready for the bootstrap scene. Keeping the disk
## read here means `SettlementGame` receives one fully resolved world.
##
## This is public deliberately: launch surfaces other than the main menu (for
## example a future editor test-run) need the same preparation without owning a
## second map-loading path.
func prepare_game_launch(config: GameLaunchConfigScript) -> GameLaunchConfigScript:
	active_launch_config = config if config != null else GameLaunchConfigScript.for_tent_era()
	_resolve_map(active_launch_config)
	return active_launch_config


## Loads the package before the scene changes. A map that cannot be read rejects
## the launch rather than constructing a different world under the same session.
func _resolve_map(config: GameLaunchConfigScript) -> void:
	if config == null or config.map_document != null:
		return
	if String(config.map_ref).is_empty():
		push_warning("[launch] игровая сессия требует карту")
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
	else:
		push_warning("[launch] сохранение не открыто: в нём нет ссылки на карту")
		return
	pending_save_path = save_path
	var definition_key := _save_definition_key(save_data)
	var definition := GameModuleRegistry.resolve_definition(definition_key)
	if definition == null:
		push_error("[launch] game definition is unavailable: %s" % definition_key)
		return
	active_session = GameSessionConfig.create(definition, active_launch_config.map_ref, active_launch_config.map_document, {
		&"gth.settlement": GameSessionConfig.settlement_parameters_from(active_launch_config),
	})
	get_tree().change_scene_to_file(GAME_RUNTIME_SCENE)


func launch_building_editor(dev_mode: bool = false) -> void:
	pending_save_path = ""
	_set_editor_mode(dev_mode)
	get_tree().change_scene_to_file(BUILDING_EDITOR_SCENE)


func launch_map_editor(map_key: StringName = &"", dev_mode: bool = false) -> void:
	pending_save_path = ""
	pending_editor_map = map_key
	_set_editor_mode(dev_mode)
	get_tree().change_scene_to_file(MAP_EDITOR_SCENE)


func _set_editor_mode(dev_mode: bool) -> void:
	editor_dev_mode = dev_mode and OS.has_feature("editor")
	editor_mode_forced = true


func _save_definition_key(save_data: SaveData) -> StringName:
	if save_data != null and not save_data.game_header.is_empty():
		var pack_id := StringName(save_data.game_header.get("pack", ""))
		var game_id := StringName(save_data.game_header.get("id", ""))
		if not pack_id.is_empty() and not game_id.is_empty():
			return ContentIdScript.runtime_key(pack_id, game_id)
	return &"core:settlement"


func return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://game/features/ui/presentation/main_menu/main_menu.tscn")


func reset_to_default() -> void:
	pending_save_path = ""
	active_session = null
	active_launch_config = GameLaunchConfigScript.for_tent_era()
	prepare_game_launch(active_launch_config)
