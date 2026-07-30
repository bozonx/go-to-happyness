class_name MainMenu
extends Control

## Host game library. Every installed game definition appears here on equal
## terms. The game definition supplies the progression catalogue; the selected
## map may restrict, fix, or disable it through module-scoped settings.

const UI_THEME = preload("res://game/features/ui/presentation/theme/ui_theme.tres")
@onready var title_label: Label = $MarginContainer/VBoxContainer/Header/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/VBoxContainer/Header/SubtitleLabel

@onready var era_panel_title: Label = $MarginContainer/VBoxContainer/ContentSplit/EraPanel/VBox/EraPanelTitle
@onready var era_option: OptionButton = $MarginContainer/VBoxContainer/ContentSplit/EraPanel/VBox/EraOption
@onready var editor_btn: Button = $MarginContainer/VBoxContainer/ContentSplit/EraPanel/VBox/EditorButton
@onready var dev_mode_btn: Button = $MarginContainer/VBoxContainer/ContentSplit/EraPanel/VBox/DevModeButton

## This picker chooses the authored world for the session.
@onready var game_option: OptionButton = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/GameOption
@onready var game_description_label: Label = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/GameDescriptionLabel
@onready var landscape_option: OptionButton = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/LandscapeOption
@onready var map_preview_rect: TextureRect = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/MapPreviewRect
@onready var era_description_label: Label = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/DescriptionLabel
@onready var param_summary_label: Label = $MarginContainer/VBoxContainer/ContentSplit/ConfigPanel/VBox/ParamSummaryLabel

@onready var start_game_btn: Button = $MarginContainer/VBoxContainer/Footer/StartGameButton
@onready var saves_btn: Button = $MarginContainer/VBoxContainer/Footer/SavesButton
@onready var quit_btn: Button = $MarginContainer/VBoxContainer/Footer/QuitButton

@onready var saves_dialog: AcceptDialog = $SavesDialog
@onready var saves_list: ItemList = $SavesDialog/SavesContent/SavesList
@onready var load_save_btn: Button = $SavesDialog/SavesContent/SavesActions/LoadSaveButton
@onready var delete_save_btn: Button = $SavesDialog/SavesContent/SavesActions/DeleteSaveButton
@onready var close_saves_btn: Button = $SavesDialog/SavesContent/SavesActions/CloseSavesButton

var selected_era: StringName = &"tent"
var selected_game: StringName = &"core:settlement"
## Runtime key of the chosen playable map.
var selected_map: StringName = &"core:green_valley"

var _map_service := MapDocumentService.new()


func _ready() -> void:
	theme = UI_THEME
	_setup_game_options()
	_setup_landscape_options()
	_connect_signals()
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
		var is_builtin := bool(entry.metadata.get("is_builtin", false))
		var badge := "📦 " if is_builtin else "🎮 "
		game_option.add_item("%s%s" % [badge, entry.name], slot)
		game_option.set_item_metadata(slot, {"game": entry.runtime_key, "is_builtin": is_builtin})
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
	era_option.item_selected.connect(_on_era_selected)
	editor_btn.pressed.connect(_on_editor_pressed)
	dev_mode_btn.visible = OS.has_feature("editor")
	dev_mode_btn.pressed.connect(_on_dev_mode_pressed)

	game_option.item_selected.connect(_on_game_selected)
	landscape_option.item_selected.connect(_on_landscape_selected)
	start_game_btn.pressed.connect(_on_start_game_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	saves_btn.pressed.connect(_open_saves_dialog)
	close_saves_btn.pressed.connect(saves_dialog.hide)
	load_save_btn.pressed.connect(_load_selected_save)
	delete_save_btn.pressed.connect(_delete_selected_save)


func _on_landscape_selected(index: int) -> void:
	var metadata: Variant = landscape_option.get_item_metadata(index)
	if metadata is not Dictionary:
		return
	var entry: Dictionary = metadata
	selected_map = entry.get("map", &"")
	_refresh_map_preview()
	_refresh_era_options()
	_update_config_summary()


func _on_game_selected(index: int) -> void:
	var metadata: Variant = game_option.get_item_metadata(index)
	if metadata is Dictionary:
		selected_game = (metadata as Dictionary).get("game", &"")
	_select_game_option()


func _select_game_option() -> void:
	var definition := GameModuleRegistry.resolve_definition(selected_game)
	if definition != null:
		game_description_label.text = definition.description if not definition.description.is_empty() else ""
		if not definition.default_map.is_empty():
			_select_default_map(definition.default_map)
	else:
		game_description_label.text = ""
	start_game_btn.text = "▶ Запустить игру"
	subtitle_label.text = "Библиотека игр, карт и пользовательского контента"
	_refresh_era_options()
	_update_config_summary()


func _select_default_map(map_key: StringName) -> void:
	for index in range(landscape_option.item_count):
		var metadata: Variant = landscape_option.get_item_metadata(index)
		if metadata is Dictionary and (metadata as Dictionary).get("map", &"") == map_key:
			landscape_option.select(index)
			selected_map = map_key
			return


func _on_era_selected(index: int) -> void:
	selected_era = StringName(era_option.get_item_metadata(index))
	_update_config_summary()


func _refresh_era_options() -> void:
	era_option.clear()
	var definition := GameModuleRegistry.resolve_definition(selected_game)
	var map := _map_service.load_map(selected_map)
	if definition == null or map == null or definition.progression.eras.is_empty():
		era_panel_title.text = "Прогрессия"
		era_option.add_item("Без эр")
		era_option.disabled = true
		selected_era = &""
		return
	var policy: Dictionary = map.meta.start.module_settings_for(&"gth.settlement").get("progression", {})
	var mode := StringName(policy.get("mode", "inherit"))
	var allowed: Array[StringName] = definition.progression.era_ids()
	if mode == &"restricted":
		allowed.clear()
		for value: Variant in policy.get("allowed_eras", []):
			var era_id := StringName(value)
			if definition.progression.era_by_id(era_id) != null:
				allowed.append(era_id)
	elif mode == &"fixed":
		allowed = [StringName(policy.get("default_era", definition.progression.eras[0].id))]
	elif mode == &"disabled":
		era_panel_title.text = "Прогрессия карты"
		era_option.add_item("Эры отключены")
		era_option.disabled = true
		selected_era = &""
		return
	if allowed.is_empty():
		allowed = definition.progression.era_ids()
	var preferred := StringName(policy.get("default_era", selected_era))
	if not allowed.has(preferred):
		preferred = allowed[0]
	for era_id: StringName in allowed:
		var era := definition.progression.era_by_id(era_id)
		era_option.add_item(era.display_name())
		era_option.set_item_metadata(era_option.item_count - 1, era_id)
		if era_id == preferred:
			era_option.select(era_option.item_count - 1)
	selected_era = preferred
	era_panel_title.text = "Начальная эра"
	era_option.disabled = mode == &"fixed"


func _update_config_summary() -> void:
	var definition := GameModuleRegistry.resolve_definition(selected_game)
	if definition == null:
		era_description_label.text = "Неизвестная игра"
		param_summary_label.text = ""
		return
	var era := definition.progression.era_by_id(selected_era)
	era_description_label.text = era.display_description() if era != null else definition.name
	var settlement: Dictionary = definition.start_module_parameters.get(&"gth.settlement", {})
	var lines: Array[String] = [_landscape_summary()]
	if era != null:
		lines.append("Начальная эра: %s" % era.display_name())
	if settlement.has("population"):
		lines.append("Стартовое население: %d" % int(settlement["population"]))
	if settlement.has("money"):
		lines.append("Монеты: %d" % int(settlement["money"]))
	param_summary_label.text = "• " + "\n• ".join(lines)


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
	var parameters := {}
	if not selected_era.is_empty():
		parameters = {&"gth.settlement": {"progression": {"default_era": selected_era}}}
	launch_mgr.call("launch_game_definition", selected_game, selected_map, parameters)


func _on_editor_pressed() -> void:
	var launch_mgr: Node = get_node_or_null("/root/GameLaunchManager")
	launch_mgr.call("launch_editor_hub", false)


func _on_dev_mode_pressed() -> void:
	var launch_mgr: Node = get_node_or_null("/root/GameLaunchManager")
	launch_mgr.call("launch_editor_hub", true)


func _on_quit_pressed() -> void:
	get_tree().quit()


## Loads the preview.png from the selected map's package directory.
func _refresh_map_preview() -> void:
	map_preview_rect.texture = null
	if selected_map.is_empty():
		return
	var map_path := _map_service.map_path(selected_map)
	if map_path.is_empty():
		return
	var preview_path := map_path.path_join("preview.png")
	if FileAccess.file_exists(preview_path):
		var image := Image.load_from_file(preview_path)
		if image != null:
			map_preview_rect.texture = ImageTexture.create_from_image(image)


## Populates the saves dialog with all save files found in user://saves/.
func _open_saves_dialog() -> void:
	saves_list.clear()
	var saves := SessionSaveCoordinator.list_saves()
	if saves.is_empty():
		saves_list.add_item("Нет сохранений")
		saves_list.disabled = true
		load_save_btn.disabled = true
		delete_save_btn.disabled = true
		return
	saves_list.disabled = false
	load_save_btn.disabled = false
	delete_save_btn.disabled = false
	for save: Dictionary in saves:
		var datetime := Time.get_datetime_dict_from_unix_time(int(save["modified"]))
		var timestamp := "%04d-%02d-%02d %02d:%02d" % [datetime["year"], datetime["month"], datetime["day"], datetime["hour"], datetime["minute"]]
		var label := "%s · %s/%s · %s" % [save["file_name"], save["pack_id"], save["game_id"], timestamp]
		saves_list.add_item(label)
		saves_list.set_item_metadata(saves_list.item_count - 1, save["path"])
	saves_list.select(0)
	saves_dialog.popup_centered()


func _load_selected_save() -> void:
	var indices := saves_list.get_selected_items()
	if indices.is_empty():
		return
	var path: String = saves_list.get_item_metadata(indices[0])
	saves_dialog.hide()
	var launch_mgr: Node = get_node_or_null("/root/GameLaunchManager")
	launch_mgr.call("launch_from_save", path)


func _delete_selected_save() -> void:
	var indices := saves_list.get_selected_items()
	if indices.is_empty():
		return
	var path: String = saves_list.get_item_metadata(indices[0])
	if SessionSaveCoordinator.delete_save(path):
		_open_saves_dialog()


func _unhandled_input(event: InputEvent) -> void:
	# Load the quicksave through the same host path F5-save uses. The save file
	# and slot are owned by SessionSaveCoordinator; the menu only routes the key.
	if event is InputEventKey and event.keycode == KEY_6 and event.pressed and not event.echo:
		if SessionSaveCoordinator.has_quicksave():
			var launch_mgr: Node = get_node_or_null("/root/GameLaunchManager")
			launch_mgr.call("launch_from_save", SessionSaveCoordinator.QUICKSAVE_PATH)
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# F12 opens the Editor Hub in dev mode when running from the Godot editor.
	# Uses _input (not _unhandled_input) so the key is caught before any focused
	# OptionButton or other UI control can swallow it.
	if event is InputEventKey and event.keycode == KEY_F12 and event.pressed and not event.echo:
		if OS.has_feature("editor"):
			var launch_mgr: Node = get_node_or_null("/root/GameLaunchManager")
			launch_mgr.call("launch_editor_hub", true)
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()
			set_process_input(false)
