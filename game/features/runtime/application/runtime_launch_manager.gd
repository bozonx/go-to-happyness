class_name RuntimeLaunchManager
extends Node

## Host-owned entry point for every installed game. It resolves authored
## definitions and maps, then changes into the one generic GameRuntime scene.

const BUILDING_EDITOR_SCENE := "res://game/features/buildings/presentation/editor/building_editor.tscn"
const MAP_EDITOR_SCENE := "res://game/features/world/presentation/editor/map_editor.tscn"
const GAME_RUNTIME_SCENE := "res://game/bootstrap/game_runtime.tscn"

var active_session: GameSessionConfig = null
var pending_save_path := ""
var editor_dev_mode := false
var editor_mode_forced := false
var pending_editor_map: StringName = &""

var _map_service := MapDocumentService.new()


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


func launch_from_save(save_path: String) -> void:
	var save_data := SaveData.new()
	if not save_data.load_from_file(save_path):
		push_warning("[launch] сохранение не читается: %s" % save_path)
		return
	# The map ref always lives in the host map header now: a v4 save writes it
	# there directly, and the v1–v3 adapter lifts the embedded map_ref into the
	# same header during migration. There is no projection to fall back to.
	var map_reference: Dictionary = save_data.map_header
	if map_reference.is_empty():
		push_warning("[launch] сохранение не открыто: в нём нет ссылки на карту")
		return
	var reference := map_reference as Dictionary
	var source := StringName(reference.get("source", "core"))
	var id := StringName(reference.get("id", ""))
	if id.is_empty():
		push_warning("[launch] в сохранении некорректная ссылка на карту")
		return
	var map_ref := ContentId.runtime_key(source, id)
	var map := _map_service.load_map(map_ref)
	if map == null:
		push_warning("[launch] сохранение не открыто: карта %s не найдена" % map_ref)
		return
	var saved_revision := String(reference.get("revision", ""))
	if not saved_revision.is_empty() and map.meta.revision != saved_revision:
		push_warning("[launch] карта %s изменилась после сохранения; будет использована текущая версия." % map_ref)
	var definition := GameModuleRegistry.resolve_definition(_save_definition_key(save_data))
	if definition == null:
		push_error("[launch] game definition from save is unavailable")
		return
	pending_save_path = save_path
	active_session = GameSessionConfig.create(definition, map_ref, map)
	get_tree().change_scene_to_file(GAME_RUNTIME_SCENE)


func launch_building_editor(dev_mode := false) -> void:
	pending_save_path = ""
	_set_editor_mode(dev_mode)
	get_tree().change_scene_to_file(BUILDING_EDITOR_SCENE)


func launch_map_editor(map_key: StringName = &"", dev_mode := false) -> void:
	pending_save_path = ""
	pending_editor_map = map_key
	_set_editor_mode(dev_mode)
	get_tree().change_scene_to_file(MAP_EDITOR_SCENE)


func return_to_main_menu() -> void:
	reset_to_default()
	get_tree().change_scene_to_file("res://game/features/ui/presentation/main_menu/main_menu.tscn")


func reset_to_default() -> void:
	pending_save_path = ""
	active_session = null


func _set_editor_mode(dev_mode: bool) -> void:
	editor_dev_mode = dev_mode and OS.has_feature("editor")
	editor_mode_forced = true


func _save_definition_key(save_data: SaveData) -> StringName:
	if save_data != null and not save_data.game_header.is_empty():
		var pack_id := StringName(save_data.game_header.get("pack", ""))
		var game_id := StringName(save_data.game_header.get("id", ""))
		if not pack_id.is_empty() and not game_id.is_empty():
			return ContentId.runtime_key(pack_id, game_id)
	return &"core:settlement"
