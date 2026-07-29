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
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")

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
@onready var _prop_game_option: OptionButton = %PropGameOption
@onready var _prop_era_option: OptionButton = %PropEraOption
@onready var _prop_style_edit: LineEdit = %PropStyleEdit
@onready var _prop_mode_option: OptionButton = %PropModeOption
@onready var _prop_time_spin: SpinBox = %PropTimeSpin
@onready var _prop_day_spin: SpinBox = %PropDaySpin
@onready var _prop_weather_edit: LineEdit = %PropWeatherEdit

## The meta the properties dialog is currently editing. Held only between opening
## and confirming, so a cancelled dialog cannot write anything.
var _editing_meta: MapMeta = null


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
	# Ids are cleaned as they are typed rather than rejected on save
	# (content_packaging.md §3.3).
	for field: LineEdit in [_new_id_edit, _save_as_id_edit, _prop_id_edit, _prop_style_edit]:
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
	_fill_game_options(meta.start.game_definition)
	_select_metadata(_prop_era_option, meta.start.era)
	_prop_style_edit.text = String(meta.start.style)
	_select_metadata(_prop_mode_option, meta.start.mode_id)
	_prop_time_spin.value = meta.start.time_of_day
	_prop_day_spin.value = meta.start.day_of_year
	_prop_weather_edit.text = String(meta.start.weather_preset)
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
	meta.start.game_definition = StringName(_prop_game_option.get_item_metadata(_prop_game_option.selected))
	meta.start.era = StringName(_prop_era_option.get_item_metadata(_prop_era_option.selected))
	var style := ContentIdScript.normalize_id(_prop_style_edit.text)
	meta.start.style = StringName(style) if not style.is_empty() else &"generic"
	meta.start.mode_id = StringName(_prop_mode_option.get_item_metadata(_prop_mode_option.selected))
	meta.start.time_of_day = int(_prop_time_spin.value)
	meta.start.day_of_year = int(_prop_day_spin.value)
	var weather := _prop_weather_edit.text.strip_edges()
	meta.start.weather_preset = StringName(weather) if not weather.is_empty() else &"clear"
	properties_applied.emit()


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
	_add_options(_prop_mode_option, [
		[MapStart.MODE_SETTLEMENT, "Поселение"],
		[MapStart.MODE_HERO, "Герой"],
		[MapStart.MODE_SQUAD, "Отряд"],
		[MapStart.MODE_SANDBOX, "Песочница"],
	])
	var eras: Array = []
	for era: StringName in BuildingMaterialCatalogScript.ERA_ORDER:
		eras.append([era, String(era).capitalize()])
	_add_options(_prop_era_option, eras)


func _fill_game_options(selected_game: StringName) -> void:
	_prop_game_option.clear()
	var index := ContentIndex.new()
	index.rebuild()
	for entry in index.game_entries():
		_prop_game_option.add_item(entry.name)
		_prop_game_option.set_item_metadata(_prop_game_option.item_count - 1, entry.runtime_key)
	_select_metadata(_prop_game_option, selected_game)


static func _add_options(option: OptionButton, pairs: Array) -> void:
	option.clear()
	for pair: Array in pairs:
		option.add_item(String(pair[1]))
		option.set_item_metadata(option.item_count - 1, pair[0])


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
