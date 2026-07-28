class_name MainMenu
extends Control

## Main menu controller supporting era selection, landscape selection, and game launch.

const UI_THEME = preload("res://game/features/ui/presentation/theme/ui_theme.tres")
const GameLaunchConfigScript = preload("res://game/features/settlement/domain/game_launch_config.gd")

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
@onready var landscape_option: OptionButton = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/LandscapeOption
@onready var era_description_label: Label = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/DescriptionLabel
@onready var param_summary_label: Label = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/ParamSummaryLabel

@onready var start_game_btn: Button = $MarginContainer/VBoxContainer/Footer/StartGameButton
@onready var quit_btn: Button = $MarginContainer/VBoxContainer/Footer/QuitButton

var selected_era: StringName = &"tent"
var selected_biome: StringName = &"summer_valley"
## Runtime key of the chosen playable map.
var selected_map: StringName = &"core:green_valley"

var _map_service := MapDocumentService.new()


func _ready() -> void:
	theme = UI_THEME
	_setup_landscape_options()
	_connect_signals()
	_select_era(&"tent")


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
	match selected_era:
		&"tent":
			era_description_label.text = "Палаточная эра: Начало пути вашей кочевой группы. Выживание в дикой природе, сбор ресурсов, постройка первого костра и палаток."
			param_summary_label.text = "• %s\n• Стартовое население: 4 жителей\n• Монеты: 500\n• Запасы: Еда (16), Вода (8), Тент (1)\n• Снаряжение: Кремень и огниво, Рабочие перчатки" % [_landscape_summary()]
		_:
			era_description_label.text = "Эта эра будет доступна в следующих обновлениях."
			param_summary_label.text = ""


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
		launch_mgr.call("launch_game_definition", &"core:settlement", selected_map, {
			&"gth.settlement": {"era": String(selected_era), "biome": String(selected_biome)},
		})
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
	if event is InputEventKey and event.keycode == KEY_6 and event.pressed and not event.echo:
		var save_service = load("res://game/features/save_load/application/save_game_service.gd")
		if save_service != null and save_service.has_quicksave():
			var launch_mgr: Node = get_node_or_null("/root/GameLaunchManager")
			if launch_mgr != null and launch_mgr.has_method("launch_from_save"):
				launch_mgr.call("launch_from_save", save_service.QUICKSAVE_PATH)
				get_viewport().set_input_as_handled()
