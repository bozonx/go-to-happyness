class_name MainMenu
extends Control

## Host game library. Every installed game definition appears here on equal
## terms.
##
## The launch screen knows no module. A definition declares which start
## parameters it wants surfaced (`menu_parameters`); the era picker comes from
## the host's own progression, and every other control is built from the schema
## the owning module declares. That is what lets a pack without code ship a
## start screen of its own.

const UI_THEME = preload("res://game/features/ui/presentation/theme/ui_theme.tres")

@onready var title_label: Label = $MarginContainer/VBoxContainer/Header/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/VBoxContainer/Header/SubtitleLabel

@onready var parameters_title: Label = %ParametersTitle
@onready var parameters_box: VBoxContainer = %ParametersBox
@onready var editor_btn: Button = %EditorButton
@onready var dev_mode_btn: Button = %DevModeButton

@onready var game_option: OptionButton = %GameOption
@onready var game_description_label: Label = %GameDescriptionLabel
@onready var landscape_option: OptionButton = %LandscapeOption
@onready var map_preview_rect: TextureRect = %MapPreviewRect
@onready var description_label: Label = %DescriptionLabel
@onready var param_summary_label: Label = %ParamSummaryLabel

@onready var start_game_btn: Button = %StartGameButton
@onready var saves_btn: Button = %SavesButton
@onready var quit_btn: Button = %QuitButton

@onready var saves_dialog: AcceptDialog = %SavesDialog
@onready var saves_list: ItemList = %SavesList
@onready var load_save_btn: Button = %LoadSaveButton
@onready var delete_save_btn: Button = %DeleteSaveButton
@onready var close_saves_btn: Button = %CloseSavesButton

var selected_game: StringName = &""
## Runtime key of the chosen playable map.
var selected_map: StringName = &""
var selected_era: StringName = &""

var _definition: GameDefinition = null
## `module_id -> { parameter_id: value }`, collected from the declared controls.
var _module_values: Dictionary = {}
var _map_service := MapDocumentService.new()


func _ready() -> void:
	theme = UI_THEME
	_connect_signals()
	_setup_game_options()


func _connect_signals() -> void:
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


## The host library indexes every installed game definition. The first UI is a
## picker rather than a store: installation and remote publishing come later,
## but an installed pack already becomes launchable here without a menu rewrite.
func _setup_game_options() -> void:
	game_option.clear()
	var entries := ContentIndex.shared().game_entries()
	for entry in entries:
		var badge := "📦 " if bool(entry.metadata.get("is_builtin", false)) else "🎮 "
		game_option.add_item("%s%s" % [badge, entry.name])
		game_option.set_item_metadata(game_option.item_count - 1, entry.runtime_key)
	if entries.is_empty():
		game_option.add_item("Нет доступных игр")
		game_option.disabled = true
		start_game_btn.disabled = true
		return
	game_option.disabled = false
	game_option.select(0)
	_on_game_selected(0)


func _on_game_selected(index: int) -> void:
	selected_game = StringName(game_option.get_item_metadata(index))
	_definition = GameModuleRegistry.resolve_definition(selected_game)
	game_description_label.text = _definition.description if _definition != null else "Игра не читается"
	_setup_map_options()
	_rebuild_parameters()
	_update_summary()


## Only maps this game can run: the one it ships as its default, plus every map
## authored against it. Listing the rest would offer the player a world whose
## spawns and zones the selected game cannot interpret.
func _setup_map_options() -> void:
	landscape_option.clear()
	var default_map := _definition.default_map if _definition != null else &""
	for entry: Dictionary in _map_service.list_maps():
		if entry["kind"] == MapMeta.KIND_PREFAB:
			continue
		var key: StringName = entry["key"]
		if key != default_map and StringName(entry.get("game_definition", &"")) != selected_game:
			continue
		var origin := "" if entry["source"] == MapDocumentService.SOURCE_BUILTIN else " · своя"
		landscape_option.add_item("🗺 %s · %d×%d%s" % [entry["name"], entry["board_cells"], entry["board_cells"], origin])
		landscape_option.set_item_metadata(landscape_option.item_count - 1, key)
	if landscape_option.item_count == 0:
		landscape_option.add_item("Нет карт для этой игры")
		landscape_option.disabled = true
		start_game_btn.disabled = true
		selected_map = &""
		param_summary_label.text = "Соберите карту для этой игры в редакторе территорий."
		return
	landscape_option.disabled = false
	start_game_btn.disabled = false
	landscape_option.select(0)
	for index in landscape_option.item_count:
		if StringName(landscape_option.get_item_metadata(index)) == default_map:
			landscape_option.select(index)
			break
	selected_map = StringName(landscape_option.get_item_metadata(landscape_option.selected))
	_refresh_map_preview()


func _on_landscape_selected(index: int) -> void:
	selected_map = StringName(landscape_option.get_item_metadata(index))
	_refresh_map_preview()
	_rebuild_parameters()
	_update_summary()


# --- Declared start parameters ------------------------------------------------

## Builds one control per entry in `menu_parameters`. Nothing here is keyed by a
## module id: an era picker is host progression, everything else is looked up in
## the declaring module's own schema.
func _rebuild_parameters() -> void:
	# Detached before freeing: `queue_free` alone leaves the old controls in the
	# tree until the end of the frame, and the panel would show them beside the
	# new ones after every change of game or map.
	for child in parameters_box.get_children():
		parameters_box.remove_child(child)
		child.queue_free()
	_module_values.clear()
	selected_era = &""
	if _definition == null:
		parameters_title.text = "Параметры"
		return
	var progression := SessionProgression.resolve(_definition.progression, _selected_map_policy())
	selected_era = progression.current_era
	var rendered := 0
	for entry: Dictionary in _definition.menu_parameters:
		if StringName(entry.get("type", "")) == GameDefinition.MENU_PARAMETER_ERA:
			if _add_era_control(progression, String(entry.get("label", "Начальная эра"))):
				rendered += 1
			continue
		if _add_module_control(StringName(entry.get("module", "")), StringName(entry.get("id", ""))):
			rendered += 1
	parameters_title.text = "Параметры запуска" if rendered > 0 else "Без настроек"
	if rendered == 0:
		var hint := Label.new()
		hint.text = "Эта игра запускается без настроек."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parameters_box.add_child(hint)


## The era policy of the selected map, read from its header. Loading the package
## here would decode terrain and water on every click in the map list.
func _selected_map_policy() -> ProgressionPolicy:
	if selected_map.is_empty():
		return ProgressionPolicy.new()
	var address := MapDocumentService.split_key(selected_map)
	var header := _map_service.read_header(address["source"], address["id"])
	var policy: Variant = header.get("progression", null)
	return policy if policy is ProgressionPolicy else ProgressionPolicy.new()


func _add_era_control(progression: SessionProgression, label_text: String) -> bool:
	if progression.is_empty():
		return false
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(0, 40)
	for era_id: StringName in progression.era_ids:
		var era := progression.era(era_id)
		option.add_item(era.display_name() if era != null else String(era_id))
		option.set_item_metadata(option.item_count - 1, era_id)
		if era_id == progression.current_era:
			option.select(option.item_count - 1)
	option.disabled = not progression.is_selectable()
	option.item_selected.connect(func(index: int) -> void:
		selected_era = StringName(option.get_item_metadata(index))
		_update_summary())
	_add_labelled(label_text, option)
	return true


func _add_module_control(module_id: StringName, parameter_id: StringName) -> bool:
	if module_id not in _definition.module_ids:
		return false
	var parameter := StartParameterDef.find(GameModuleRegistry.start_parameters_of(module_id), parameter_id)
	if parameter == null:
		return false
	var authored: Variant = _definition.parameters_for(module_id).get(parameter_id, parameter.default_value)
	var value: Variant = parameter.coerce(authored)
	_set_module_value(module_id, parameter_id, value)
	match parameter.type:
		StartParameterDef.TYPE_INT:
			var spin := SpinBox.new()
			spin.min_value = parameter.min_value
			spin.max_value = parameter.max_value
			spin.value = int(value)
			spin.value_changed.connect(func(new_value: float) -> void:
				_set_module_value(module_id, parameter_id, int(new_value))
				_update_summary())
			_add_labelled(parameter.label, spin)
		StartParameterDef.TYPE_BOOL:
			var check := CheckBox.new()
			check.text = parameter.label
			check.button_pressed = bool(value)
			check.toggled.connect(func(pressed: bool) -> void:
				_set_module_value(module_id, parameter_id, pressed)
				_update_summary())
			parameters_box.add_child(check)
		StartParameterDef.TYPE_ENUM:
			var option := OptionButton.new()
			for choice: Dictionary in parameter.options:
				option.add_item(String(choice.get("label", choice.get("value", ""))))
				option.set_item_metadata(option.item_count - 1, choice.get("value"))
				if choice.get("value") == value:
					option.select(option.item_count - 1)
			option.item_selected.connect(func(index: int) -> void:
				_set_module_value(module_id, parameter_id, option.get_item_metadata(index))
				_update_summary())
			_add_labelled(parameter.label, option)
		_:
			var edit := LineEdit.new()
			edit.text = String(value)
			edit.text_changed.connect(func(new_text: String) -> void:
				_set_module_value(module_id, parameter_id, new_text)
				_update_summary())
			_add_labelled(parameter.label, edit)
	return true


func _add_labelled(label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	parameters_box.add_child(label)
	parameters_box.add_child(control)


func _set_module_value(module_id: StringName, parameter_id: StringName, value: Variant) -> void:
	var values: Dictionary = _module_values.get(module_id, {})
	values[parameter_id] = value
	_module_values[module_id] = values


func _update_summary() -> void:
	if _definition == null:
		description_label.text = "Неизвестная игра"
		param_summary_label.text = ""
		return
	var lines: Array[String] = [_map_summary()]
	if not selected_era.is_empty():
		var era := _definition.progression.era_by_id(selected_era)
		if era != null:
			lines.append("Начальная эра: %s" % era.display_name())
			description_label.text = era.display_description()
	if selected_era.is_empty():
		description_label.text = _definition.name
	for module_id: StringName in _module_values:
		var declared := GameModuleRegistry.start_parameters_of(module_id)
		var values: Dictionary = _module_values[module_id]
		for parameter_id: StringName in values:
			var parameter := StartParameterDef.find(declared, parameter_id)
			if parameter != null:
				lines.append("%s: %s" % [parameter.label, values[parameter_id]])
	param_summary_label.text = "• " + "\n• ".join(lines)


func _map_summary() -> String:
	if selected_map.is_empty():
		return "Карта не выбрана"
	var address := MapDocumentService.split_key(selected_map)
	var header := _map_service.read_header(address["source"], address["id"])
	if header.is_empty():
		return "Карта: %s" % selected_map
	return "Карта: %s (%d×%d м)" % [header["name"], header["board_cells"], header["board_cells"]]


func _on_start_game_pressed() -> void:
	if selected_game.is_empty() or selected_map.is_empty():
		return
	var launch_mgr: Node = get_node_or_null("/root/GameLaunchManager")
	launch_mgr.call("launch_game_definition", selected_game, selected_map,
		_module_values.duplicate(true), selected_era)


func _on_editor_pressed() -> void:
	get_node("/root/GameLaunchManager").call("launch_editor_hub", false)


func _on_dev_mode_pressed() -> void:
	get_node("/root/GameLaunchManager").call("launch_editor_hub", true)


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


func _open_saves_dialog() -> void:
	saves_list.clear()
	var saves := SessionSaveCoordinator.list_saves()
	if saves.is_empty():
		saves_list.add_item("Нет сохранений")
		saves_list.disabled = true
		load_save_btn.disabled = true
		delete_save_btn.disabled = true
		saves_dialog.popup_centered()
		return
	saves_list.disabled = false
	load_save_btn.disabled = false
	delete_save_btn.disabled = false
	for save: Dictionary in saves:
		var datetime := Time.get_datetime_dict_from_unix_time(int(save["modified"]))
		var timestamp := "%04d-%02d-%02d %02d:%02d" % [datetime["year"], datetime["month"], datetime["day"], datetime["hour"], datetime["minute"]]
		saves_list.add_item("%s · %s/%s · %s" % [save["file_name"], save["pack_id"], save["game_id"], timestamp])
		saves_list.set_item_metadata(saves_list.item_count - 1, save["path"])
	saves_list.select(0)
	saves_dialog.popup_centered()


func _load_selected_save() -> void:
	var indices := saves_list.get_selected_items()
	if indices.is_empty():
		return
	var path: String = saves_list.get_item_metadata(indices[0])
	saves_dialog.hide()
	get_node("/root/GameLaunchManager").call("launch_from_save", path)


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
			get_node("/root/GameLaunchManager").call("launch_from_save", SessionSaveCoordinator.QUICKSAVE_PATH)
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# F12 opens the Editor Hub in dev mode when running from the Godot editor.
	# Uses _input (not _unhandled_input) so the key is caught before any focused
	# OptionButton or other UI control can swallow it.
	if event is InputEventKey and event.keycode == KEY_F12 and event.pressed and not event.echo:
		if OS.has_feature("editor"):
			get_node("/root/GameLaunchManager").call("launch_editor_hub", true)
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()
			set_process_input(false)
