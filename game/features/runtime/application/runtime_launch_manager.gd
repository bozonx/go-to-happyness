class_name RuntimeLaunchManager
extends Node

## Host-owned entry point for every installed game. It resolves authored
## definitions and maps, then changes into the one generic GameRuntime scene.

const BUILDING_EDITOR_SCENE := "res://game/features/buildings/presentation/editor/building_editor.tscn"
const MAP_EDITOR_SCENE := "res://game/features/world/presentation/editor/map_editor.tscn"
const EDITOR_HUB_SCENE := "res://game/features/content/presentation/editor/editor_hub.tscn"
const GAME_EDITOR_SCENE := "res://game/features/runtime/presentation/editor/game_editor.tscn"
const GAME_RUNTIME_SCENE := "res://game/bootstrap/game_runtime.tscn"
const MAIN_MENU_SCENE := "res://game/features/ui/presentation/main_menu/main_menu.tscn"

var active_session: GameSessionConfig = null
var pending_save_path := ""
var editor_dev_mode := false
var editor_mode_forced := false
var pending_editor_map: StringName = &""
## In-memory hand-off for F5 from the map editor. It is intentionally not a
## save: a test run must see unsaved edits and must not mutate the document.
var pending_editor_document: MapDocument = null
## Where `Esc` returns when the session was started as a test run. Empty means
## the session came from the library, and `Esc` goes back to the main menu.
var editor_return_scene := ""
var active_editor_pack_root := ""
var active_editor_pack_source: StringName = &""

var _map_service := MapDocumentService.new()


func launch_game_definition(
	definition_key: StringName,
	map_ref: StringName = &"",
	module_parameters: Dictionary = {},
	selected_era: StringName = &"",
	resolved_map: MapDocument = null,
) -> void:
	pending_save_path = ""
	editor_return_scene = ""
	pending_editor_document = null
	var definition := GameModuleRegistry.resolve_definition(definition_key)
	if definition == null:
		push_error("[launch] game definition is unavailable: %s" % definition_key)
		return
	var selected_map := map_ref if not map_ref.is_empty() else definition.default_map
	var document := resolved_map if resolved_map != null else _map_service.load_map(selected_map)
	if document == null:
		push_warning("[launch] игровая сессия отменена: карта %s не открылась: %s" % [selected_map, _map_service.last_error])
		return
	active_session = GameSessionConfig.create(definition, selected_map, document, module_parameters, selected_era)
	get_tree().change_scene_to_file(GAME_RUNTIME_SCENE)


## Test run from an editor. The session is identical to a library launch; the
## only difference is that `Esc` returns the author to the editor they came from
## instead of dropping them into the main menu.
func launch_editor_test(
	definition_key: StringName,
	document: MapDocument,
	return_scene: String,
	map_ref: StringName = &"editor:preview",
) -> void:
	if document == null:
		push_warning("[launch] тест-запуск отменён: карта отсутствует")
		return
	var definition := GameModuleRegistry.resolve_definition(definition_key)
	if definition == null:
		push_error("[launch] тест-запуску недоступна игра: %s" % definition_key)
		return
	pending_save_path = ""
	pending_editor_document = document
	editor_return_scene = return_scene
	active_session = GameSessionConfig.create(definition, map_ref, document)
	get_tree().change_scene_to_file(GAME_RUNTIME_SCENE)


func return_from_editor_test() -> void:
	var scene := editor_return_scene if not editor_return_scene.is_empty() else MAP_EDITOR_SCENE
	active_session = null
	editor_return_scene = ""
	get_tree().change_scene_to_file(scene)


func launch_from_save(save_path: String) -> void:
	var save_data := SaveData.new()
	if not save_data.load_from_file(save_path):
		push_warning("[launch] сохранение не читается: %s" % save_path)
		return
	var reference := save_data.map_header
	if reference.is_empty():
		push_warning("[launch] сохранение не открыто: в нём нет ссылки на карту")
		return
	var id := StringName(reference.get("id", ""))
	if id.is_empty():
		push_warning("[launch] в сохранении некорректная ссылка на карту")
		return
	var map_ref := ContentId.runtime_key(StringName(reference.get("source", "core")), id)
	var map := _map_service.load_map(map_ref)
	if map == null:
		push_warning("[launch] сохранение не открыто: карта %s не найдена" % map_ref)
		return
	var definition_key := _save_definition_key(save_data)
	if definition_key.is_empty():
		push_warning("[launch] сохранение не открыто: в нём нет ссылки на игру")
		return
	var definition := GameModuleRegistry.resolve_definition(definition_key)
	if definition == null:
		push_warning("[launch] сохранение не открыто: игра %s не установлена" % definition_key)
		return
	pending_save_path = save_path
	editor_return_scene = ""
	pending_editor_document = null
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


func launch_editor_hub(dev_mode := false) -> void:
	pending_save_path = ""
	active_editor_pack_root = ""
	active_editor_pack_source = &""
	_set_editor_mode(dev_mode)
	get_tree().change_scene_to_file(EDITOR_HUB_SCENE)


func select_editor_pack(root: String, source: StringName) -> void:
	active_editor_pack_root = root
	active_editor_pack_source = source


func launch_game_editor() -> void:
	if active_editor_pack_root.is_empty():
		push_warning("[editor] game editor requires an active project pack")
		return
	get_tree().change_scene_to_file(GAME_EDITOR_SCENE)


func return_to_editor_hub() -> void:
	get_tree().change_scene_to_file(EDITOR_HUB_SCENE)


func return_to_main_menu() -> void:
	reset_to_default()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func reset_to_default() -> void:
	pending_save_path = ""
	pending_editor_document = null
	editor_return_scene = ""
	active_session = null


func _set_editor_mode(dev_mode: bool) -> void:
	editor_dev_mode = dev_mode and OS.has_feature("editor")
	editor_mode_forced = true


## A save names its own game. There is no fallback to Settlement: guessing would
## make one shipped game silently privileged over every installed one.
static func _save_definition_key(save_data: SaveData) -> StringName:
	if save_data == null or save_data.game_header.is_empty():
		return &""
	var pack_id := StringName(save_data.game_header.get("pack", ""))
	var game_id := StringName(save_data.game_header.get("id", ""))
	if pack_id.is_empty() or game_id.is_empty():
		return &""
	return ContentId.runtime_key(pack_id, game_id)
