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
## The chosen entrance (`map_start.md` §3). One per map, and the map decides what
## `selectable` means; the menu only offers what it is allowed to offer.
var selected_start: StringName = &""
## Start data of the chosen map, read from its header — the entrances, their
## overrides and the defaults every parameter is resolved against.
var _map_start: MapStart = MapStart.new()
## The §2.5 chain behind every control on this screen, recomputed on each change
## so what the player sees is what the session will receive.
var _resolution: StartParameterResolution = StartParameterResolution.new()


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
	# Player choices belong to the game and map they were made under; carrying
	# them across would hand another game a parameter it never declared.
	_module_values.clear()
	selected_start = &""
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
	_module_values.clear()
	selected_start = &""
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
	selected_era = &""
	if _definition == null:
		parameters_title.text = "Параметры"
		return
	_read_map_start()
	_resolve_parameters()
	var progression := SessionProgression.resolve(_definition.progression, _selected_map_policy())
	selected_era = progression.current_era
	var rendered := 0
	if _add_start_control():
		rendered += 1
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
	return _map_start.progression


## The start record of the chosen map, and the entrance chosen inside it. Read
## from the header rather than the package: the launch screen must not decode
## terrain and water to know how many ways into a map there are.
func _read_map_start() -> void:
	_map_start = MapStart.new()
	if selected_map.is_empty():
		selected_start = &""
		return
	var address := MapDocumentService.split_key(selected_map)
	var header := _map_service.read_header(address["source"], address["id"])
	var start: Variant = header.get("start", null)
	if start is MapStart:
		_map_start = start
	var chosen := _map_start.start_by_id(selected_start)
	if chosen == null or not chosen.selectable or not chosen.suits_definition(selected_game):
		var fallback := _map_start.default_option(selected_game)
		selected_start = fallback.id if fallback != null else &""


## Runs the §2.5 chain for what is currently chosen. Every control on the screen
## is drawn from the result, so the numbers the player reads are the numbers the
## session will be created with — not an approximation the launch then redoes.
func _resolve_parameters() -> void:
	var declared: Dictionary = {}
	if _definition != null:
		for module_id: StringName in _definition.module_ids:
			declared[module_id] = GameModuleRegistry.start_parameters_of(module_id)
	var option := _map_start.start_by_id(selected_start)
	_resolution = StartParameterResolver.resolve(
		declared,
		_definition.start_module_parameters if _definition != null else {},
		_map_start.module_settings,
		option.module_overrides if option != null else {},
		_module_values,
	)


## The entrances the player may pick (§12, block 2). A map with one entrance
## draws no picker at all: a choice of one is noise, not information.
func _add_start_control() -> bool:
	var options := _map_start.selectable_options(selected_game)
	if options.size() < 2:
		return false
	var option_button := OptionButton.new()
	option_button.custom_minimum_size = Vector2(0, 40)
	for entrance: MapStartOption in options:
		option_button.add_item(entrance.display_name())
		option_button.set_item_metadata(option_button.item_count - 1, entrance.id)
		option_button.set_item_tooltip(option_button.item_count - 1, entrance.display_description())
		if entrance.id == selected_start:
			option_button.select(option_button.item_count - 1)
	option_button.item_selected.connect(func(index: int) -> void:
		selected_start = StringName(option_button.get_item_metadata(index))
		# An entrance carries its own overrides, so everything below it is stale.
		_rebuild_parameters()
		_update_summary())
	_add_labelled("Место старта", option_button)
	return true


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


## One inspector row, built from the declaring module's own schema. The three
## hand-written control builders this replaces — one here, one in the game editor
## and one static panel in the map editor — are why a new kind of parameter used
## to cost three edits in three screens (`map_start.md` §2.6).
##
## The parameter arrives already resolved (§2.5), so the control shows the
## narrowed range rather than the module's, and a locked parameter is drawn
## disabled instead of vanishing: an empty space explains nothing.
func _add_module_control(module_id: StringName, parameter_id: StringName) -> bool:
	if module_id not in _definition.module_ids:
		return false
	var declared := EntityPropertyDef.find(
		GameModuleRegistry.start_parameters_of(module_id), parameter_id)
	if declared == null:
		return false
	var entry := _resolution.entry(module_id, parameter_id)
	if entry == null:
		return false
	var property := _narrowed_property(declared, entry)
	_set_module_value(module_id, parameter_id, entry.value)
	var inspector := EditorPropertyInspector.new()
	inspector.set_fields([property], {parameter_id: entry.value}, false, entry.is_player_choice())
	# Only the value and the summary change: rebuilding the panel here would free
	# the control under the player's cursor, and a player's own choice cannot
	# narrow anyone's range, so nothing else on screen becomes stale.
	inspector.property_committed.connect(func(_name: StringName, value: Variant) -> void:
		_set_module_value(module_id, parameter_id, value)
		_resolve_parameters()
		_update_summary())
	parameters_box.add_child(inspector)
	parameters_box.add_child(_provenance_label(entry))
	return true


## A copy of the declaration carrying the range the chain agreed on. The module's
## own schema is left alone: it describes what the module can simulate, not what
## this map allows.
func _narrowed_property(declared: EntityPropertyDef, entry: StartParameterResolution.Entry) -> EntityPropertyDef:
	var property := EntityPropertyDef.from_dict(declared.to_dict())
	property.minimum = entry.minimum
	property.maximum = entry.maximum
	property.options = entry.options.duplicate()
	if entry.locked_by != 0:
		property.editable = false
		property.unavailable_reason = "%s закрепил это значение" % StartParameterResolution.level_name(entry.locked_by)
	return property


## Why the slider stops where it does (§12). Without it, a range the map narrowed
## is indistinguishable from a bug in the menu.
func _provenance_label(entry: StartParameterResolution.Entry) -> Label:
	var label := Label.new()
	label.text = "\n".join(entry.explain())
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(1.0, 1.0, 1.0, 0.55)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


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
	var entrance := _map_start.start_by_id(selected_start)
	if entrance != null and _map_start.selectable_options(selected_game).size() > 1:
		lines.append("Место старта: %s" % entrance.display_name())
	# The summary reads the resolved values, not the collected ones: a parameter
	# the map locked never appears in `_module_values`, and leaving it out of the
	# summary would hide exactly the value the player did not get to choose.
	for entry: Dictionary in _definition.menu_parameters:
		var module_id := StringName(entry.get("module", ""))
		var resolved := _resolution.entry(module_id, StringName(entry.get("id", "")))
		if resolved != null:
			lines.append("%s: %s" % [resolved.label, resolved.value])
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
		_module_values.duplicate(true), selected_era, null, selected_start)


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
