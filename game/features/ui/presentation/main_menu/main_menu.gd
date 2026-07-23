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

@onready var landscape_option: OptionButton = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/LandscapeOption
@onready var era_description_label: Label = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/DescriptionLabel
@onready var param_summary_label: Label = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/ParamSummaryLabel

@onready var start_game_btn: Button = $MarginContainer/VBoxContainer/Footer/StartGameButton
@onready var quit_btn: Button = $MarginContainer/VBoxContainer/Footer/QuitButton

var selected_era: StringName = &"tent"
var selected_biome: StringName = &"summer_valley"


func _ready() -> void:
	theme = UI_THEME
	_setup_landscape_options()
	_connect_signals()
	_select_era(&"tent")


func _setup_landscape_options() -> void:
	landscape_option.clear()
	landscape_option.add_item("Летняя долина (Summer Valley)", 0)
	landscape_option.set_item_metadata(0, &"summer_valley")
	landscape_option.add_item("Летняя равнина (Summer Plains)", 1)
	landscape_option.set_item_metadata(1, &"summer_plains")
	landscape_option.select(0)


func _connect_signals() -> void:
	tent_era_btn.pressed.connect(func(): _select_era(&"tent"))
	earth_era_btn.pressed.connect(func(): _select_era(&"earth"))
	clay_era_btn.pressed.connect(func(): _select_era(&"clay"))
	wood_era_btn.pressed.connect(func(): _select_era(&"wood"))
	stone_era_btn.pressed.connect(func(): _select_era(&"stone"))
	building_editor_btn.pressed.connect(func(): _select_era(&"building_editor"))

	landscape_option.item_selected.connect(_on_landscape_selected)
	start_game_btn.pressed.connect(_on_start_game_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)


func _on_landscape_selected(index: int) -> void:
	selected_biome = landscape_option.get_item_metadata(index) as StringName
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
	building_editor_btn.text = "🏗️ Редактор зданий (Скоро)"

	earth_era_btn.disabled = true
	clay_era_btn.disabled = true
	wood_era_btn.disabled = true
	stone_era_btn.disabled = true
	building_editor_btn.disabled = true


func _update_config_summary() -> void:
	match selected_era:
		&"tent":
			era_description_label.text = "Палаточная эра: Начало пути вашей кочевой группы. Выживание в дикой природе, сбор ресурсов, постройка первого костра и палаток."
			param_summary_label.text = "• Ландшафт: %s\n• Стартовое население: 4 жителей\n• Монеты: 500\n• Запасы: Еда (16), Вода (8), Тент (1)\n• Снаряжение: Кремень и огниво, Рабочие перчатки" % [_biome_display_name(selected_biome)]
		_:
			era_description_label.text = "Эта эра будет доступна в следующих обновлениях."
			param_summary_label.text = ""


func _biome_display_name(biome: StringName) -> String:
	match biome:
		&"summer_valley":
			return "Летняя долина (Summer Valley)"
		&"summer_plains":
			return "Летняя равнина (Summer Plains)"
		_:
			return str(biome)


func _on_start_game_pressed() -> void:
	var config := GameLaunchConfigScript.for_tent_era()
	config.biome_id = selected_biome
	var launch_mgr: Node = get_node_or_null("/root/GameLaunchManager")
	if launch_mgr != null and launch_mgr.has_method("launch_game"):
		launch_mgr.call("launch_game", config)
	else:
		get_tree().change_scene_to_file("res://game/bootstrap/settlement_game.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
