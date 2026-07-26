class_name MapEditorPalette
extends PanelContainer

## The palette of the active mode, along the bottom (map_editor.md §3.2).
##
## Materials, tools, later blueprints and point roles. It holds the mode's
## contextual brush inspector directly under the picked entry rather than in a
## far corner of the screen — the arrangement the building editor arrived at,
## where the settings of a thing sit next to the thing.
##
## The panel knows nothing about what it shows. A mode hands it entries and
## options; clicking one calls back into that mode.

signal entry_selected(entry_id: StringName)
signal option_activated(option_id: StringName)

@onready var _title: Label = $Margin/Rows/Title
@onready var _entries: HFlowContainer = $Margin/Rows/Entries
@onready var _options: HBoxContainer = $Margin/Rows/Options

var _entry_buttons: Dictionary = {}


func set_title(text: String) -> void:
	_title.text = text


## `entries` is an array of `MapEditorMode.PaletteEntry`.
func set_entries(entries: Array, selected: StringName) -> void:
	for child in _entries.get_children():
		child.queue_free()
	_entry_buttons.clear()
	for entry in entries:
		var button := Button.new()
		button.text = entry.label
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.button_pressed = entry.id == selected
		if entry.color.a > 0.0:
			# The swatch is the label's colour rather than a separate square: it
			# survives every theme and costs no layout.
			button.add_theme_color_override("font_color", entry.color)
			button.add_theme_color_override("font_pressed_color", entry.color)
			button.add_theme_color_override("font_hover_color", entry.color.lightened(0.25))
		var entry_id: StringName = entry.id
		button.pressed.connect(func() -> void: entry_selected.emit(entry_id))
		_entries.add_child(button)
		_entry_buttons[entry_id] = button


## Cheap refresh for when only the selection moved — rebuilding the whole row
## would drop the author's hover and scroll position mid-drag.
func set_selected(selected: StringName) -> void:
	for id: StringName in _entry_buttons:
		(_entry_buttons[id] as Button).button_pressed = id == selected


## `options` is an array of `MapEditorMode.ToolOption`. Their labels carry live
## values, so this row is rebuilt whenever the mode says its UI changed.
func set_options(options: Array) -> void:
	for child in _options.get_children():
		child.queue_free()
	for option in options:
		var button := Button.new()
		button.text = option.label
		button.focus_mode = Control.FOCUS_NONE
		var option_id: StringName = option.id
		button.pressed.connect(func() -> void: option_activated.emit(option_id))
		_options.add_child(button)
