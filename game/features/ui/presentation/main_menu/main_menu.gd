class_name MainMenu
extends Control

## Host game library. Every installed game definition appears here on equal
## terms; settlement-specific configuration (era/biome) is driven by the
## definition's start_parameters, not by hardcoded module or game id checks.

const UI_THEME = preload("res://game/features/ui/presentation/theme/ui_theme.tres")
@onready var title_label: Label = $MarginContainer/VBoxContainer/Header/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/VBoxContainer/Header/SubtitleLabel

@onready var tent_era_btn: Button = $MarginContainer/VBoxContainer/ContentSplit/EraPanel/VBox/TentEraButton
@onready var earth_era_btn: Button = $MarginContainer/VBoxContainer/ContentSplit/EraPanel/VBox/EarthEraButton
@onready var clay_era_btn: Button = $MarginContainer/VBoxContainer/ContentSplit/EraPanel/VBox/ClayEraButton
@onready var wood_era_btn: Button = $MarginContainer/VBoxContainer/ContentSplit/EraPanel/VBox/WoodEraButton
@onready var stone_era_btn: Button = $MarginContainer/VBoxContainer/ContentSplit/EraPanel/VBox/StoneEraButton
@onready var building_editor_btn: Button = $MarginContainer/VBoxContainer/ContentSplit/EraPanel/VBox/BuildingEditorButton
@onready var map_editor_btn: Button = $MarginContainer/VBoxContainer/ContentSplit/EraPanel/VBox/MapEditorButton

## This picker chooses the authored world for the session.
@onready var game_option: OptionButton = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/GameOption
@onready var landscape_option: OptionButton = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/LandscapeOption
@onready var era_description_label: Label = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/DescriptionLabel
@onready var param_summary_label: Label = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/ParamSummaryLabel

@onready var start_game_btn: Button = $MarginContainer/VBoxContainer/Footer/StartGameButton
@onready var quit_btn: Button = $MarginContainer/VBoxContainer/Footer/QuitButton

var selected_era: StringName = &"tent"
var selected_biome: StringName = &"summer_valley"
var selected_game: StringName = &"core:settlement"
## Runtime key of the chosen playable map.
var selected_map: StringName = &"core:green_valley"

var _map_service := MapDocumentService.new()


func _ready() -> void:
	theme = UI_THEME
	_setup_game_options()
	_setup_landscape_options()
	_connect_signals()
	_select_era(&"tent")
	_select_game_option()


## The host library indexes every installed game definition. The first UI is a
## picker rather than a store: installation and remote publishing come later,
## but an installed pack already becomes launchable here without a menu rewrite.
func _setup_game_options() -> void:
	game_option.clear()
	var index := ContentIndex.new()
	index.rebuild()
	var slot := 0
	var settlement_slot := -1
	for entry in index.game_entries():
		game_option.add_item("🎮 %s" % entry.name, slot)
		game_option.set_item_metadata(slot, {"game": entry.runtime_key})
		if entry.runtime_key == &"core:settlement":
			settlement_slot = slot
		slot += 1
	if slot == 0:
		game_option.add_item("Нет доступных игр")
		game_option.disabled = true
		start_game_btn.disabled = true
		return
	game_option.disabled = false
	game_option.select(settlement_slot if settlement_slot >= 0 else 0)


## Every game session starts from an authored map. Player maps saved by the
## territory editor are indexed alongside the shipped maps on the next visit.
func _setup_landscape_options() -> void:
	landscape_option.clear()
	var slot := 0
	for entry: Dictionary in _map_service.list_maps():
		if entry["kind"] == MapMeta.KIND_PREFAB:
			continue
		var suffix := " · %d×%d" % [entry["board_cells"], entry["board_cells"]]
		var origin := "" if entry["source"] == MapDocumentService.SOURCE_BUILTIN else " · своя"
		landscape_option.add_item("🗺 %s%s%s" % [entry["name"], suffix, origin], slot)
		landscape_option.set_item_metadata(slot, {"map": entry["key"]})
		slot += 1
	if slot == 0:
		landscape_option.add_item("Нет доступных карт")
		landscape_option.disabled = true
		start_game_btn.disabled = true
		param_summary_label.text = "Сохраните карту в редакторе территорий, чтобы начать игру."
		return
	landscape_option.disabled = false
	start_game_btn.disabled = false
	landscape_option.select(0)
	_on_landscape_selected(0)


func _connect_signals() -> void:
	tent_era_btn.pressed.connect(func(): _select_era(&"tent"))
	earth_era_btn.pressed.connect(func(): _select_era(&"earth"))
	clay_era_btn.pressed.connect(func(): _select_era(&"clay"))
	wood_era_btn.pressed.connect(func(): _select_era(&"wood"))
	stone_era_btn.pressed.connect(func(): _select_era(&"stone"))
	building_editor_btn.pressed.connect(_on_building_editor_pressed)
	map_editor_btn.pressed.connect(_on_map_editor_pressed)

	game_option.item_selected.connect(_on_game_selected)
	landscape_option.item_selected.connect(_on_landscape_selected)
	start_game_btn.pressed.connect(_on_start_game_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)


func _on_landscape_selected(index: int) -> void:
	var metadata: Variant = landscape_option.get_item_metadata(index)
	if metadata is not Dictionary:
		return
	var entry: Dictionary = metadata
	selected_map = entry.get("map", &"")
	_update_config_summary()


func _on_game_selected(index: int) -> void:
	var metadata: Variant = game_option.get_item_metadata(index)
	if metadata is Dictionary:
		selected_game = (metadata as Dictionary).get("game", &"")
	_select_game_option()


func _select_game_option() -> void:
	var definition := GameModuleRegistry.resolve_definition(selected_game)
	# Launch options are module-owned. Phase A has no generic parameter editor,
	# so the host starts the definition exactly as authored instead of interpreting
	# settlement fields such as `era` or `biome`.
	tent_era_btn.get_parent().get_parent().visible = false
	if definition != null and not definition.default_map.is_empty():
		_select_default_map(definition.default_map)
	start_game_btn.text = "▶ Запустить игру"
	subtitle_label.text = "Главное меню — библиотека установленных игр"
	_update_config_summary()


func _select_default_map(map_key: StringName) -> void:
	for index in range(landscape_option.item_count):
		var metadata: Variant = landscape_option.get_item_metadata(index)
		if metadata is Dictionary and (metadata as Dictionary).get("map", &"") == map_key:
			landscape_option.select(index)
			selected_map = map_key
			return


func _select_era(era_id: StringName) -> void:
	selected_era = era_id
	_update_era_buttons_state()
	_update_config_summary()


func _update_era_buttons_state() -> void:
	tent_era_btn.text = "⛺ Палаточная эра" + (" [Выбрано]" if selected_era == &"tent" else "")
	earth_era_btn.text = "🧱 Земляная эра (Скоро)"
	clay_era_btn.text = "🏺 Глиняная эра (Скоро)"
	wood_era_btn.text = "🪵 Деревянная эра (Скоро)"
	stone_era_btn.text = "🪨 Каменная эра (Скоро)"
	building_editor_btn.text = "🏗️ Редактор зданий"
	map_editor_btn.text = "🗺 Редактор территорий"

	earth_era_btn.disabled = true
	clay_era_btn.disabled = true
	wood_era_btn.disabled = true
	stone_era_btn.disabled = true
	building_editor_btn.disabled = false
	map_editor_btn.disabled = false


func _update_config_summary() -> void:
	var definition := GameModuleRegistry.resolve_definition(selected_game)
	if definition == null:
		era_description_label.text = "Неизвестная игра"
		param_summary_label.text = ""
		return
	era_description_label.text = definition.name
	if definition.start_parameters.has("era"):
		match selected_era:
			&"tent":
				param_summary_label.text = "• %s\n• Стартовое население: 4 жителей\n• Монеты: 500\n• Запасы: Еда (16), Вода (8), Тент (1)\n• Снаряжение: Кремень и огниво, Рабочие перчатки" % [_landscape_summary()]
			_:
				param_summary_label.text = "• %s\n• Эта эра будет доступна в следующих обновлениях." % [_landscape_summary()]
	else:
		param_summary_label.text = "• %s\n• Запускается внутри Go To Happyness" % [_landscape_summary()]


## What the chosen entry actually decides. A map states its own board and start
## conditions, so saying "ландшафт" about it would be wrong.
func _landscape_summary() -> String:
	var address := MapDocumentService.split_key(selected_map)
	var header := _map_service.read_header(address["source"], address["id"])
	if header.is_empty():
		return "Карта: %s" % selected_map
	return "Карта: %s (%d×%d м)" % [header["name"], header["board_cells"], header["board_cells"]]


func _on_start_game_pressed() -> void:
	var launch_mgr: Node = get_node_or_null("/root/GameLaunchManager")
	if launch_mgr != null and launch_mgr.has_method("launch_game_definition"):
		launch_mgr.call("launch_game_definition", selected_game, selected_map)
	else:
		get_tree().change_scene_to_file("res://game/bootstrap/game_runtime.tscn")


func _on_building_editor_pressed() -> void:
	var launch_mgr: Node = get_node_or_null("/root/GameLaunchManager")
	if launch_mgr != null and launch_mgr.has_method("launch_building_editor"):
		# Player mode: the menu is the player's entry point. Dev mode is reached by
		# opening the editor scene inside Godot (content_packaging.md §9).
		launch_mgr.call("launch_building_editor", false)
	else:
		get_tree().change_scene_to_file("res://game/features/buildings/presentation/editor/building_editor.tscn")


func _on_map_editor_pressed() -> void:
	var launch_mgr: Node = get_node_or_null("/root/GameLaunchManager")
	if launch_mgr != null and launch_mgr.has_method("launch_map_editor"):
		# Editing opens the chosen map when one is chosen, and a new map otherwise.
		launch_mgr.call("launch_map_editor", selected_map)
		return
	get_tree().change_scene_to_file("res://game/features/world/presentation/editor/map_editor.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	# Load the quicksave through the same host path F5-save uses. The save file
	# and slot are owned by SessionSaveCoordinator; the menu only routes the key.
	if event is InputEventKey and event.keycode == KEY_6 and event.pressed and not event.echo:
		if SessionSaveCoordinator.has_quicksave():
			var launch_mgr: Node = get_node_or_null("/root/GameLaunchManager")
			if launch_mgr != null and launch_mgr.has_method("launch_from_save"):
				launch_mgr.call("launch_from_save", SessionSaveCoordinator.QUICKSAVE_PATH)
				get_viewport().set_input_as_handled()
