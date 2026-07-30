class_name MapEditorPalette
extends PanelContainer

## The palette of the active mode, down the left edge (map_editor.md §3.2).
##
## Materials, tools, later blueprints and point roles. It holds the mode's
## contextual brush inspector directly under the picked entry rather than in a
## far corner of the screen — the arrangement the building editor arrived at,
## where the settings of a thing sit next to the thing.
##
## Supports both standard entries (for relief/surface/water) and the shared
## EditorCatalogPanel (for fill mode).

signal entry_selected(entry_id: StringName)
signal option_activated(option_id: StringName)

@onready var _title: Label = $Margin/Rows/Title
@onready var _scroll: ScrollContainer = $Margin/Rows/Scroll
@onready var _entries: VBoxContainer = $Margin/Rows/Scroll/Entries
@onready var _options: VBoxContainer = $Margin/Rows/Options
@onready var _options_title: Label = $Margin/Rows/OptionsTitle
@onready var _separator: HSeparator = $Margin/Rows/Separator

var _catalog_panel: EditorCatalogPanel = null
var _entry_buttons: Dictionary = {}
var _is_catalog_mode := false


func _ready() -> void:
	_catalog_panel = EditorCatalogPanel.new()
	_catalog_panel.visible = false
	_scroll.add_child(_catalog_panel)
	_catalog_panel.asset_selected.connect(func(asset_id: StringName) -> void:
		entry_selected.emit(asset_id))


func set_title(text: String) -> void:
	_title.text = text


func show_catalog(controller: Object, scope: StringName) -> void:
	_is_catalog_mode = true
	_entries.visible = false
	_catalog_panel.visible = true
	_catalog_panel.setup(controller, null, scope)
	_catalog_panel.activate()


func show_standard_entries() -> void:
	_is_catalog_mode = false
	if _catalog_panel != null:
		_catalog_panel.visible = false
	_entries.visible = true


func catalog_panel() -> EditorCatalogPanel:
	return _catalog_panel


## `entries` is an array of `MapEditorMode.PaletteEntry`.
func set_entries(entries: Array, selected: StringName) -> void:
	show_standard_entries()
	var prev_scroll := _scroll.scroll_vertical if _scroll != null else 0
	for child in _entries.get_children():
		child.queue_free()
	_entry_buttons.clear()
	for entry in entries:
		var button := Button.new()
		button.text = entry.label
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = entry.id == selected or (entry.is_header and entry.is_expanded)
		if entry.is_header:
			var header_color := Color(0.85, 0.88, 0.95)
			button.add_theme_color_override("font_color", header_color)
			button.add_theme_color_override("font_pressed_color", header_color)
			button.add_theme_color_override("font_hover_color", header_color.lightened(0.15))
		elif entry.color.a > 0.0:
			var readable := _readable(entry.color)
			button.add_theme_color_override("font_color", readable)
			button.add_theme_color_override("font_pressed_color", readable)
			button.add_theme_color_override("font_hover_color", readable.lightened(0.25))
		var entry_id: StringName = entry.id
		button.pressed.connect(func() -> void: entry_selected.emit(entry_id))
		_entries.add_child(button)
		_entry_buttons[entry_id] = button
	if _scroll != null:
		_scroll.scroll_vertical = prev_scroll


func set_selected(selected: StringName) -> void:
	if _is_catalog_mode and _catalog_panel != null:
		_catalog_panel.select_asset(selected)
		return
	for id: StringName in _entry_buttons:
		(_entry_buttons[id] as Button).button_pressed = id == selected


const MIN_SWATCH_LUMINANCE := 0.45


static func _readable(swatch: Color) -> Color:
	var luminance := swatch.get_luminance()
	if luminance >= MIN_SWATCH_LUMINANCE:
		return swatch
	return swatch.lightened(MIN_SWATCH_LUMINANCE - luminance)


func set_options(options: Array) -> void:
	for child in _options.get_children():
		child.queue_free()
	var has_options := not options.is_empty()
	_options_title.visible = has_options
	_separator.visible = has_options
	_options.visible = has_options
	if not has_options:
		return
	var rows: Dictionary = {}
	for option in options:
		var parent: Container = _options
		if option.row != &"":
			if not rows.has(option.row):
				var row := HFlowContainer.new()
				row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_theme_constant_override("h_separation", 4)
				row.add_theme_constant_override("v_separation", 4)
				_options.add_child(row)
				rows[option.row] = row
			parent = rows[option.row]
		var button := Button.new()
		button.text = option.label
		button.toggle_mode = option.row != &""
		button.button_pressed = option.selected
		button.disabled = option.disabled
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if option.row != &"" else Control.SIZE_EXPAND_FILL
		var option_id: StringName = option.id
		button.pressed.connect(func() -> void: option_activated.emit(option_id))
		parent.add_child(button)
