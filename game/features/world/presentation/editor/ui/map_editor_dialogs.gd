class_name MapEditorDialogs
extends Control

## Every modal the territory editor owns: create, open, save as, properties
## (map_editor.md §3.2.1).
##
## It exists so `map_editor.gd` stays what it claims to be — document, modes,
## input, undo — instead of growing a second job. Nothing here touches the
## document: dialogs collect intent and emit it, and the editor decides what that
## means. That is also what makes them testable without a map.

## Emitted with a sanitized id, a display name and a board size in cells.
signal create_requested(id: StringName, name: String, board_cells: int)
## Emitted with the package path the author picked.
signal open_requested(path: String)
signal save_as_requested(id: StringName)
## Emitted after the properties dialog has written its fields into the meta it was
## given. The editor re-reads whatever it needs and marks the document dirty.
signal properties_applied

const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")
@onready var _new_dialog: ConfirmationDialog = $NewDialog
@onready var _new_id_edit: LineEdit = %NewIdEdit
@onready var _new_name_edit: LineEdit = %NewNameEdit
@onready var _new_board_option: OptionButton = %NewBoardOption

@onready var _load_dialog: ConfirmationDialog = $LoadDialog
@onready var _load_list: ItemList = %LoadList
@onready var _load_error_label: Label = %LoadErrorLabel

@onready var _save_as_dialog: ConfirmationDialog = $SaveAsDialog
@onready var _save_as_id_edit: LineEdit = %SaveAsIdEdit
@onready var _save_as_hint: Label = %SaveAsHint

@onready var _properties_dialog: ConfirmationDialog = $PropertiesDialog
@onready var _prop_id_edit: LineEdit = %PropIdEdit
@onready var _prop_name_edit: LineEdit = %PropNameEdit
@onready var _prop_author_edit: LineEdit = %PropAuthorEdit
@onready var _prop_map_kind_option: OptionButton = %PropMapKindOption
@onready var _prop_players_spin: SpinBox = %PropPlayersSpin
@onready var _prop_biomes_edit: LineEdit = %PropBiomesEdit
@onready var _prop_tags_edit: LineEdit = %PropTagsEdit
@onready var _prop_board_label: Label = %PropBoardLabel
@onready var _prop_border_option: OptionButton = %PropBorderOption
@onready var _prop_border_level_spin: SpinBox = %PropBorderLevelSpin
@onready var _start_dialog: ConfirmationDialog = $StartSettingsDialog
@onready var _start_game_option: OptionButton = %StartGameOption
@onready var _progression_mode_option: OptionButton = %ProgressionModeOption
@onready var _allowed_eras_list: ItemList = %AllowedErasList
@onready var _default_era_option: OptionButton = %DefaultEraOption
@onready var _start_style_edit: LineEdit = %StartStyleEdit
@onready var _start_time_spin: SpinBox = %StartTimeSpin
@onready var _start_day_spin: SpinBox = %StartDaySpin
@onready var _start_latitude_spin: SpinBox = %StartLatitudeSpin
@onready var _start_weather_edit: LineEdit = %StartWeatherEdit
## Climate is a world fact, not a module setting (`world_environment.md` §5): the
## season, the temperature and the length of the day all come off its curve.
@onready var _start_climate_option: OptionButton = %StartClimateOption
@onready var _start_dynamic_check: CheckBox = %StartDynamicCheck

@onready var _starts_list: ItemList = %StartsList
@onready var _add_start_button: Button = %AddStartButton
@onready var _remove_start_button: Button = %RemoveStartButton
@onready var _default_start_button: Button = %DefaultStartButton
@onready var _start_option_id_edit: LineEdit = %StartOptionIdEdit
@onready var _start_option_name_edit: LineEdit = %StartOptionNameEdit
@onready var _start_option_description_edit: LineEdit = %StartOptionDescriptionEdit
@onready var _start_option_group_option: OptionButton = %StartOptionGroupOption
@onready var _start_option_camera_option: OptionButton = %StartOptionCameraOption
@onready var _start_option_selectable_check: CheckBox = %StartOptionSelectableCheck
@onready var _module_parameters_box: VBoxContainer = %ModuleParametersBox

## The meta the properties dialog is currently editing. Held only between opening
## and confirming, so a cancelled dialog cannot write anything.
var _editing_meta: MapMeta = null
## Working copies of the start options and the map's module sections. The dialog
## edits these and writes them into the meta only on confirmation, which is what
## makes «Отмена» mean something for a list the author has been adding rows to.
var _editing_starts: Array[MapStartOption] = []
var _editing_default_start: StringName = &""
var _editing_sections: Dictionary = {}
var _selected_start := -1
## The map being edited, needed for the spawn groups and camera anchors a start
## option points at. Zones are the map's, not the header's.
var _editing_document: MapDocument = null


func _ready() -> void:
	_fill_board_presets()
	_fill_static_options()
	_new_dialog.confirmed.connect(_on_new_confirmed)
	_load_dialog.confirmed.connect(_on_load_confirmed)
	_load_list.item_activated.connect(func(_index: int) -> void:
		_load_dialog.hide()
		_on_load_confirmed())
	_save_as_dialog.confirmed.connect(_on_save_as_confirmed)
	_properties_dialog.confirmed.connect(_on_properties_confirmed)
	_start_dialog.confirmed.connect(_on_start_settings_confirmed)
	_start_game_option.item_selected.connect(func(_index: int) -> void:
		_refresh_progression_fields()
		# Module parameters belong to the game's modules, so changing the game
		# changes which controls exist at all.
		_rebuild_module_parameters())
	_starts_list.item_selected.connect(_on_start_option_selected)
	_add_start_button.pressed.connect(_add_start_option)
	_remove_start_button.pressed.connect(_remove_start_option)
	_default_start_button.pressed.connect(_make_start_option_default)
	_start_option_id_edit.text_submitted.connect(func(_text: String) -> void: _commit_start_option_fields())
	_start_option_id_edit.focus_exited.connect(_commit_start_option_fields)
	_start_option_name_edit.text_submitted.connect(func(_text: String) -> void: _commit_start_option_fields())
	_start_option_name_edit.focus_exited.connect(_commit_start_option_fields)
	_start_option_description_edit.focus_exited.connect(_commit_start_option_fields)
	_start_option_group_option.item_selected.connect(func(_index: int) -> void: _commit_start_option_fields())
	_start_option_camera_option.item_selected.connect(func(_index: int) -> void: _commit_start_option_fields())
	_start_option_selectable_check.toggled.connect(func(_pressed: bool) -> void: _commit_start_option_fields())
	_progression_mode_option.item_selected.connect(func(_index: int) -> void: _update_progression_controls())
	# Ids are cleaned as they are typed rather than rejected on save
	# (content_packaging.md §3.3).
	for field: LineEdit in [_new_id_edit, _save_as_id_edit, _prop_id_edit, _start_style_edit, _start_option_id_edit]:
		field.text_changed.connect(_sanitize_field.bind(field))


# --- Create -------------------------------------------------------------------

## New is a dialog and not a button because the board size cannot be changed
## afterwards (map_editor.md §6.2), and because a silent default id means the
## second map an author makes overwrites the first.
func open_new_dialog() -> void:
	_new_id_edit.text = ""
	_new_name_edit.text = ""
	_select_metadata(_new_board_option, MapMeta.DEFAULT_BOARD_CELLS)
	_new_dialog.popup_centered()
	_new_id_edit.grab_focus()


func _on_new_confirmed() -> void:
	var id := ContentIdScript.normalize_id(_new_id_edit.text)
	if id.is_empty():
		# Reopening beats a silent placeholder: the author has to see that the id
		# they typed produced nothing usable.
		_new_dialog.popup_centered()
		_new_id_edit.grab_focus()
		return
	var display_name := _new_name_edit.text.strip_edges()
	if display_name.is_empty():
		display_name = id
	create_requested.emit(StringName(id), display_name,
		int(_new_board_option.get_item_metadata(_new_board_option.selected)))


# --- Open ---------------------------------------------------------------------

## `entries` come from `MapDocumentService.list_maps()` and cover every source;
## `errors` are content problems worth showing rather than swallowing.
func open_load_dialog(entries: Array, errors: Array) -> void:
	_load_list.clear()
	for entry: Dictionary in entries:
		var suffix := "" if entry.get("writable", false) else "  · только чтение"
		var index := _load_list.add_item("%s  (%s)  %d×%d%s" % [
			entry["name"], entry["key"], entry["board_cells"], entry["board_cells"], suffix])
		_load_list.set_item_metadata(index, entry["path"])
	_load_error_label.visible = not errors.is_empty()
	_load_error_label.text = "\n".join(errors)
	_load_dialog.popup_centered()


func _on_load_confirmed() -> void:
	var selected := _load_list.get_selected_items()
	if selected.is_empty():
		return
	open_requested.emit(String(_load_list.get_item_metadata(selected[0])))


# --- Save as ------------------------------------------------------------------

func open_save_as_dialog(default_id: StringName, target_dir: String) -> void:
	_save_as_id_edit.text = String(default_id)
	_save_as_hint.text = "ID новой карты (сохранится в %s):" % target_dir
	_save_as_dialog.popup_centered()
	_save_as_id_edit.grab_focus()


func _on_save_as_confirmed() -> void:
	var id := ContentIdScript.normalize_id(_save_as_id_edit.text)
	if id.is_empty():
		_save_as_dialog.popup_centered()
		_save_as_id_edit.grab_focus()
		return
	save_as_requested.emit(StringName(id))


# --- Properties ---------------------------------------------------------------

## Edits `meta` in place on confirmation. The board size is shown and not offered:
## resizing moves every absolute coordinate and rebuilds navigation, so it is a
## migration rather than a property (map_editor.md §17.2).
func open_properties_dialog(meta: MapMeta) -> void:
	_editing_meta = meta
	_prop_id_edit.text = String(meta.id)
	_prop_name_edit.text = meta.name
	_prop_author_edit.text = meta.author
	_select_metadata(_prop_map_kind_option, meta.map_kind)
	_prop_players_spin.value = meta.players
	_prop_biomes_edit.text = _join_names(meta.biomes)
	_prop_tags_edit.text = _join_names(meta.tags)
	_prop_board_label.text = "%d×%d (%s)" % [
		meta.board_cells, meta.board_cells, MapMeta.preset_name(meta.board_cells)]
	_select_metadata(_prop_border_option, meta.border_kind)
	_prop_border_level_spin.value = meta.border_level
	_properties_dialog.popup_centered()


func _on_properties_confirmed() -> void:
	if _editing_meta == null:
		return
	var meta := _editing_meta
	_editing_meta = null
	# An emptied id would make the map unsaveable, so the previous one stands.
	var id := ContentIdScript.normalize_id(_prop_id_edit.text)
	if not id.is_empty():
		meta.id = StringName(id)
	meta.name = _prop_name_edit.text.strip_edges()
	meta.author = _prop_author_edit.text.strip_edges()
	meta.map_kind = StringName(_prop_map_kind_option.get_item_metadata(_prop_map_kind_option.selected))
	meta.players = int(_prop_players_spin.value)
	meta.biomes = _split_names(_prop_biomes_edit.text)
	meta.tags = _split_names(_prop_tags_edit.text)
	meta.border_kind = StringName(_prop_border_option.get_item_metadata(_prop_border_option.selected))
	meta.border_level = int(_prop_border_level_spin.value)
	properties_applied.emit()


# --- Start settings -----------------------------------------------------------

## Gameplay start is intentionally separate from map identity and world bounds:
## it grows with game modules, while the base properties dialog stays stable.
##
## `document` supplies the spawn groups and camera anchors a start option points
## at (`map_start.md` §3.1): an entrance is a reference into the zone layer, and
## offering the author a free-text field for it would produce dangling links the
## validator then has to explain.
func open_start_settings_dialog(meta: MapMeta, document: MapDocument = null) -> void:
	_editing_meta = meta
	_editing_document = document
	_fill_game_options(meta.start.game_definition)
	_start_style_edit.text = String(meta.start.style)
	_start_time_spin.value = meta.start.time_of_day
	_start_day_spin.value = meta.start.day_of_year
	_start_latitude_spin.value = meta.start.latitude
	_start_weather_edit.text = String(meta.start.weather_preset)
	_fill_climate_options(meta.start.climate)
	_start_dynamic_check.button_pressed = meta.start.dynamic
	_refresh_progression_fields(meta.start.progression)
	_copy_starts_for_editing(meta.start)
	_rebuild_module_parameters()
	_start_dialog.popup_centered()


func _on_start_settings_confirmed() -> void:
	if _editing_meta == null:
		return
	_commit_start_option_fields()
	var meta := _editing_meta
	_editing_meta = null
	_editing_document = null
	meta.start.game_definition = StringName(_start_game_option.get_item_metadata(_start_game_option.selected))
	var style := ContentIdScript.normalize_id(_start_style_edit.text)
	meta.start.style = StringName(style) if not style.is_empty() else &"generic"
	meta.start.time_of_day = int(_start_time_spin.value)
	meta.start.day_of_year = int(_start_day_spin.value)
	meta.start.latitude = float(_start_latitude_spin.value)
	var weather := _start_weather_edit.text.strip_edges()
	meta.start.weather_preset = StringName(weather) if not weather.is_empty() else &"clear"
	if _start_climate_option.selected >= 0:
		meta.start.climate = StringName(_start_climate_option.get_item_text(_start_climate_option.selected))
	meta.start.dynamic = _start_dynamic_check.button_pressed
	_write_progression_policy(meta)
	meta.start.starts = _editing_starts.duplicate()
	meta.start.default_start = _editing_default_start
	meta.start.module_settings = _editing_sections.duplicate()
	properties_applied.emit()


# --- Start options ------------------------------------------------------------

## Deep copies of what the meta holds, so «Отмена» discards the whole session of
## edits rather than half of them.
func _copy_starts_for_editing(start: MapStart) -> void:
	_editing_starts.clear()
	for option: MapStartOption in start.starts:
		_editing_starts.append(MapStartOption.from_dict(option.to_dict()))
	_editing_default_start = start.default_start
	_editing_sections.clear()
	for module_id: Variant in start.module_settings:
		var section: ModuleSettingsSection = start.module_settings[module_id]
		_editing_sections[StringName(module_id)] = ModuleSettingsSection.from_dict(section.to_dict())
	_selected_start = 0 if not _editing_starts.is_empty() else -1
	_refresh_starts_list()


func _refresh_starts_list() -> void:
	_starts_list.clear()
	for option: MapStartOption in _editing_starts:
		var marks := []
		if option.id == _editing_default_start:
			marks.append("по умолчанию")
		if not option.selectable:
			marks.append("не выбирается")
		var suffix := "  · %s" % ", ".join(marks) if not marks.is_empty() else ""
		_starts_list.add_item("%s%s" % [option.display_name(), suffix])
	if _selected_start >= 0 and _selected_start < _starts_list.item_count:
		_starts_list.select(_selected_start)
	_refresh_start_option_fields()


func _on_start_option_selected(index: int) -> void:
	# The fields belong to the row that was selected a moment ago; writing them
	# after the switch would copy one entrance's name onto another.
	_commit_start_option_fields()
	_selected_start = index
	_refresh_start_option_fields()


func _refresh_start_option_fields() -> void:
	_fill_spawn_group_options()
	_fill_camera_options()
	var option := _selected_start_option()
	var editable := option != null
	for control: Control in [_start_option_id_edit, _start_option_name_edit,
			_start_option_description_edit, _start_option_group_option,
			_start_option_camera_option, _start_option_selectable_check,
			_remove_start_button, _default_start_button]:
		if control is LineEdit:
			(control as LineEdit).editable = editable
		elif control is BaseButton:
			(control as BaseButton).disabled = not editable
	if option == null:
		_start_option_id_edit.text = ""
		_start_option_name_edit.text = ""
		_start_option_description_edit.text = ""
		return
	_start_option_id_edit.text = String(option.id)
	_start_option_name_edit.text = option.display_name()
	_start_option_description_edit.text = option.display_description()
	_select_metadata(_start_option_group_option, option.spawn_group)
	_select_metadata(_start_option_camera_option, option.camera)
	_start_option_selectable_check.set_pressed_no_signal(option.selectable)


## Writes the visible fields back into the selected entrance. Called on every
## field commit and before anything that changes the selection, because the
## dialog holds no other copy of what the author typed.
func _commit_start_option_fields() -> void:
	var option := _selected_start_option()
	if option == null:
		return
	var next_id := StringName(ContentIdScript.normalize_id(_start_option_id_edit.text))
	if next_id != &"" and next_id != option.id and not _has_start_id(next_id):
		# Entities and saves address an entrance by id, so a rename has to carry
		# `default_start` with it or the map silently loses its default.
		if _editing_default_start == option.id:
			_editing_default_start = next_id
		option.id = next_id
	option.name = MapLocalizedText.of(_start_option_name_edit.text)
	option.description = MapLocalizedText.of(_start_option_description_edit.text)
	option.spawn_group = StringName(_selected_metadata(_start_option_group_option))
	option.camera = StringName(_selected_metadata(_start_option_camera_option))
	option.selectable = _start_option_selectable_check.button_pressed
	_refresh_starts_list_labels()


## Only the row captions, so committing a field does not steal the selection.
func _refresh_starts_list_labels() -> void:
	for index in mini(_starts_list.item_count, _editing_starts.size()):
		var option := _editing_starts[index]
		var marks := []
		if option.id == _editing_default_start:
			marks.append("по умолчанию")
		if not option.selectable:
			marks.append("не выбирается")
		var suffix := "  · %s" % ", ".join(marks) if not marks.is_empty() else ""
		_starts_list.set_item_text(index, "%s%s" % [option.display_name(), suffix])


func _selected_start_option() -> MapStartOption:
	if _selected_start < 0 or _selected_start >= _editing_starts.size():
		return null
	return _editing_starts[_selected_start]


func _has_start_id(id: StringName) -> bool:
	for option: MapStartOption in _editing_starts:
		if option.id == id:
			return true
	return false


func _add_start_option() -> void:
	_commit_start_option_fields()
	var option := MapStartOption.new()
	var index := _editing_starts.size() + 1
	while _has_start_id(StringName("start_%d" % index)):
		index += 1
	option.id = StringName("start_%d" % index)
	option.name = MapLocalizedText.of("Вариант %d" % index)
	# A new entrance points at the only group there is, when there is only one:
	# an author who drew a single clearing means that one.
	if _editing_document != null and _editing_document.zones.spawn_groups.size() == 1:
		option.spawn_group = _editing_document.zones.spawn_groups[0].id
	_editing_starts.append(option)
	if _editing_default_start == &"":
		_editing_default_start = option.id
	_selected_start = _editing_starts.size() - 1
	_refresh_starts_list()


func _remove_start_option() -> void:
	var option := _selected_start_option()
	if option == null:
		return
	_editing_starts.remove_at(_selected_start)
	if _editing_default_start == option.id:
		_editing_default_start = _editing_starts[0].id if not _editing_starts.is_empty() else &""
	_selected_start = mini(_selected_start, _editing_starts.size() - 1)
	_refresh_starts_list()


func _make_start_option_default() -> void:
	_commit_start_option_fields()
	var option := _selected_start_option()
	if option != null:
		_editing_default_start = option.id
		_refresh_starts_list()


func _fill_spawn_group_options() -> void:
	_start_option_group_option.clear()
	_start_option_group_option.add_item("— не выбрана —")
	_start_option_group_option.set_item_metadata(0, "")
	if _editing_document == null:
		return
	for group: MapSpawnGroup in _editing_document.zones.spawn_groups:
		_start_option_group_option.add_item(group.display_name())
		_start_option_group_option.set_item_metadata(
			_start_option_group_option.item_count - 1, String(group.id))


func _fill_camera_options() -> void:
	_start_option_camera_option.clear()
	_start_option_camera_option.add_item("— без камеры —")
	_start_option_camera_option.set_item_metadata(0, "")
	if _editing_document == null:
		return
	for anchor: ZoneAnchorRecord in _editing_document.zones.anchors:
		if MapSpawnService.canonical_function(anchor.function) != MapSpawnService.CAMERA_START:
			continue
		_start_option_camera_option.add_item(String(anchor.id))
		_start_option_camera_option.set_item_metadata(
			_start_option_camera_option.item_count - 1, String(anchor.id))


# --- Module parameters --------------------------------------------------------

## Controls for every parameter the selected game's modules declare, built from
## the same schema and the same inspector the launch screen uses (§2.6, §11.2).
## The static fields that used to stand here knew four types and no module at
## all, so a map could not override a single gameplay value.
func _rebuild_module_parameters() -> void:
	for child in _module_parameters_box.get_children():
		_module_parameters_box.remove_child(child)
		child.queue_free()
	var definition := GameModuleRegistry.resolve_definition(
		StringName(_start_game_option.get_item_metadata(_start_game_option.selected)))
	if definition == null:
		return
	for module_id: StringName in definition.module_ids:
		var declared := GameModuleRegistry.start_parameters_of(module_id)
		if declared.is_empty():
			continue
		var header := Label.new()
		header.text = String(module_id)
		header.add_theme_font_size_override("font_size", 12)
		_module_parameters_box.add_child(header)
		var section := _section_for(module_id)
		var values: Dictionary = {}
		for parameter: EntityPropertyDef in declared:
			# A parameter the map does not override shows the game's own value, so
			# the author sees what the map will actually start with rather than a
			# blank the format has no way to express.
			values[parameter.name] = section.value_of(parameter.name) if section.has_value(parameter.name) \
				else definition.parameters_for(module_id).get(String(parameter.name), parameter.default)
		var inspector := EditorPropertyInspector.new()
		inspector.set_fields(declared, values, false)
		inspector.property_committed.connect(func(parameter: StringName, value: Variant) -> void:
			_section_for(module_id).values[String(parameter)] = value)
		inspector.property_reset_requested.connect(func(parameter: StringName) -> void:
			# Reset means "stop overriding", not "write the default back": a map
			# that copied the game's value would silently freeze it there.
			_section_for(module_id).values.erase(String(parameter))
			_rebuild_module_parameters())
		_module_parameters_box.add_child(inspector)


func _section_for(module_id: StringName) -> ModuleSettingsSection:
	if not _editing_sections.has(module_id):
		_editing_sections[module_id] = ModuleSettingsSection.new()
	return _editing_sections[module_id]


func _refresh_progression_fields(authored_policy: ProgressionPolicy = null) -> void:
	var policy := authored_policy if authored_policy != null else ProgressionPolicy.new()
	_allowed_eras_list.clear()
	_default_era_option.clear()
	var game_key := StringName(_start_game_option.get_item_metadata(_start_game_option.selected))
	var definition := GameModuleRegistry.resolve_definition(game_key)
	var eras: Array[EraDefinition] = definition.progression.eras if definition != null else []
	for era: EraDefinition in eras:
		var item := _allowed_eras_list.add_item(era.display_name())
		_allowed_eras_list.set_item_metadata(item, era.id)
		_default_era_option.add_item(era.display_name())
		_default_era_option.set_item_metadata(_default_era_option.item_count - 1, era.id)
	_select_metadata(_progression_mode_option, policy.mode)
	for index in _allowed_eras_list.item_count:
		var era_id: StringName = _allowed_eras_list.get_item_metadata(index)
		if policy.mode != ProgressionPolicy.MODE_RESTRICTED or era_id in policy.allowed_eras:
			_allowed_eras_list.select(index, false)
	var default_era := policy.default_era
	if default_era.is_empty() and _default_era_option.item_count > 0:
		default_era = _default_era_option.get_item_metadata(0)
	_select_metadata(_default_era_option, default_era)
	_progression_mode_option.disabled = eras.is_empty()
	_update_progression_controls()


func _update_progression_controls() -> void:
	var has_eras := _default_era_option.item_count > 0
	var mode := StringName(_progression_mode_option.get_item_metadata(_progression_mode_option.selected))
	var restricted := mode == ProgressionPolicy.MODE_RESTRICTED
	_allowed_eras_list.visible = has_eras
	_allowed_eras_list.mouse_filter = Control.MOUSE_FILTER_STOP if restricted else Control.MOUSE_FILTER_IGNORE
	_allowed_eras_list.modulate.a = 1.0 if restricted else 0.55
	_default_era_option.disabled = not has_eras or mode == ProgressionPolicy.MODE_DISABLED


func _write_progression_policy(meta: MapMeta) -> void:
	var policy := ProgressionPolicy.new()
	if _default_era_option.item_count > 0:
		policy.mode = StringName(_progression_mode_option.get_item_metadata(_progression_mode_option.selected))
		if policy.mode == ProgressionPolicy.MODE_RESTRICTED:
			for index: int in _allowed_eras_list.get_selected_items():
				policy.allowed_eras.append(StringName(_allowed_eras_list.get_item_metadata(index)))
		if policy.mode != ProgressionPolicy.MODE_DISABLED:
			policy.default_era = StringName(_default_era_option.get_item_metadata(_default_era_option.selected))
	meta.start.progression = policy


# --- Option plumbing ----------------------------------------------------------

func _fill_board_presets() -> void:
	_new_board_option.clear()
	for cells: int in MapMeta.BOARD_PRESETS:
		_new_board_option.add_item("%s — %d×%d" % [MapMeta.preset_name(cells), cells, cells])
		_new_board_option.set_item_metadata(_new_board_option.item_count - 1, cells)
	_select_metadata(_new_board_option, MapMeta.DEFAULT_BOARD_CELLS)


func _fill_static_options() -> void:
	_add_options(_prop_map_kind_option, [
		[MapMeta.MAP_KIND_MAP, "Карта"],
		[MapMeta.MAP_KIND_SCENARIO, "Сценарий"],
		[MapMeta.MAP_KIND_ARENA, "Арена"],
	])
	_add_options(_prop_border_option, [
		[MapMeta.BORDER_OCEAN, "Океан"],
		[MapMeta.BORDER_LAVA, "Лава"],
		[MapMeta.BORDER_NOTHING, "Ничего"],
	])
	_add_options(_progression_mode_option, [
		[ProgressionPolicy.MODE_INHERIT, "Все эры игры"],
		[ProgressionPolicy.MODE_RESTRICTED, "Только выбранные эры"],
		[ProgressionPolicy.MODE_FIXED, "Одна фиксированная эра"],
		[ProgressionPolicy.MODE_DISABLED, "Без эр"],
	])


func _fill_game_options(selected_game: StringName) -> void:
	_start_game_option.clear()
	for entry in ContentIndex.shared().game_entries():
		_start_game_option.add_item(entry.name)
		_start_game_option.set_item_metadata(_start_game_option.item_count - 1, entry.runtime_key)
	_select_metadata(_start_game_option, selected_game)


static func _add_options(option: OptionButton, pairs: Array) -> void:
	option.clear()
	for pair: Array in pairs:
		option.add_item(String(pair[1]))
		option.set_item_metadata(option.item_count - 1, pair[0])


static func _selected_metadata(option: OptionButton) -> String:
	return String(option.get_item_metadata(option.selected)) if option.selected >= 0 else ""


static func _select_metadata(option: OptionButton, value: Variant) -> void:
	for i in option.item_count:
		if option.get_item_metadata(i) == value:
			option.select(i)
			return
	if option.item_count > 0:
		option.select(0)


func _sanitize_field(new_text: String, field: LineEdit) -> void:
	var cleaned := ContentIdScript.sanitize_id(new_text)
	if cleaned == new_text:
		return
	# Assigning `text` resets the caret, which would make the field type backwards.
	var caret := field.caret_column - (new_text.length() - cleaned.length())
	field.text = cleaned
	field.caret_column = clampi(caret, 0, cleaned.length())


static func _join_names(values: Array[StringName]) -> String:
	return ", ".join(values.map(func(value: StringName) -> String: return String(value)))


## Free text to a tag list. Empty entries are dropped rather than stored, so a
## trailing comma does not become a nameless biome.
static func _split_names(text: String) -> Array[StringName]:
	var result: Array[StringName] = []
	for part: String in text.split(",", false):
		var cleaned := ContentIdScript.normalize_id(part)
		if not cleaned.is_empty():
			result.append(StringName(cleaned))
	return result


## The climates this build knows, plus whatever a pack registered. Listing them
## rather than typing an id is what keeps a misspelled climate from silently
## becoming the temperate default at launch.
func _fill_climate_options(current: StringName) -> void:
	_start_climate_option.clear()
	var ids := ClimateCatalog.ids()
	for index in range(ids.size()):
		_start_climate_option.add_item(String(ids[index]), index)
		if ids[index] == current:
			_start_climate_option.select(index)
	if _start_climate_option.selected < 0 and not ids.is_empty():
		_start_climate_option.select(0)
