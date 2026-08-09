class_name EditorPalettePanel
extends PanelContainer

## Shared left-side palette for authoring tools. Feature controllers provide the
## entries and option descriptors; this UI component only owns presentation.

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
var _catalog_controller: Object = null
var _catalog_scope: StringName = &""


func _ready() -> void:
	_catalog_panel = EditorCatalogPanel.new()
	_catalog_panel.visible = false
	_entries.add_child(_catalog_panel)
	_catalog_panel.asset_selected.connect(func(asset_id: StringName) -> void: entry_selected.emit(asset_id))


func set_title(text: String) -> void:
	_title.text = text


func entries_container() -> VBoxContainer:
	return _entries


func show_catalog(controller: Object, scope: StringName) -> void:
	_is_catalog_mode = true
	_entries.visible = true
	_title.visible = true
	_scroll.visible = true
	_catalog_panel.visible = true
	if controller == _catalog_controller and scope == _catalog_scope:
		return
	_catalog_controller = controller
	_catalog_scope = scope
	_catalog_panel.setup(controller, null, scope)
	_catalog_panel.activate()


func show_standard_entries() -> void:
	_is_catalog_mode = false
	if _catalog_panel != null:
		_catalog_panel.visible = false
	_entries.visible = true


func catalog_panel() -> EditorCatalogPanel:
	return _catalog_panel


## Entries are presentation descriptors with `id`, `label`, optional `color`,
## `is_header` and `is_expanded` fields. This keeps the shared UI independent
## from individual editor-mode classes.
func set_entries(entries: Array, selected: StringName) -> void:
	if not _is_catalog_mode:
		show_standard_entries()
		var has_entries := not entries.is_empty()
		_title.visible = has_entries
		_scroll.visible = has_entries
	var previous_scroll := _scroll.scroll_vertical
	for child in _entries.get_children():
		if child != _catalog_panel:
			_entries.remove_child(child)
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
			_set_entry_color(button, Color(0.85, 0.88, 0.95))
		elif entry.color.a > 0.0:
			_set_entry_color(button, _readable(entry.color))
		var entry_id: StringName = entry.id
		button.pressed.connect(func() -> void: entry_selected.emit(entry_id))
		_entries.add_child(button)
		_entry_buttons[entry_id] = button
	if _is_catalog_mode and _catalog_panel != null:
		_entries.move_child(_catalog_panel, _entries.get_child_count() - 1)
	_scroll.scroll_vertical = previous_scroll


func set_selected(selected: StringName) -> void:
	for id: StringName in _entry_buttons:
		(_entry_buttons[id] as Button).button_pressed = id == selected
	if _is_catalog_mode and _catalog_panel != null:
		_catalog_panel.select_asset(selected)


func set_options(options: Array) -> void:
	for child in _options.get_children():
		child.queue_free()
	var has_options := not options.is_empty()
	var has_entries := not _entry_buttons.is_empty() or _is_catalog_mode
	_options_title.visible = has_options and has_entries
	_separator.visible = has_options and has_entries
	_options.visible = has_options
	if not has_options:
		_options.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		return
	var has_push_bottom := false
	for option in options:
		if option.is_header and option.push_bottom:
			has_push_bottom = true
			break
	_options.size_flags_vertical = Control.SIZE_EXPAND_FILL if has_push_bottom else Control.SIZE_SHRINK_BEGIN
	var rows: Dictionary = {}
	for option in options:
		if option.is_header:
			if option.push_bottom:
				var spacer := Control.new()
				spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
				_options.add_child(spacer)
			var header := Label.new()
			header.text = option.label
			header.add_theme_font_size_override("font_size", 14)
			_options.add_child(header)
			continue
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
		if option.color.a > 0.0:
			_set_entry_color(button, _readable(option.color))
		var option_id: StringName = option.id
		button.pressed.connect(func() -> void: option_activated.emit(option_id))
		parent.add_child(button)


static func _set_entry_color(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_hover_color", color.lightened(0.15))


static func _readable(swatch: Color) -> Color:
	var luminance := swatch.get_luminance()
	return swatch if luminance >= 0.45 else swatch.lightened(0.45 - luminance)
