class_name MapEditorMode
extends RefCounted

## One mode of the territory editor (map_editor.md §3.5).
##
## The rule this base class exists to enforce: **the editor scene contains no mode
## logic**. `map_editor.gd` loads and saves the document, switches modes, routes
## input and owns the undo stack — nothing else. The moment an `if mode == ...`
## appears inside its click handling, logic has leaked out of a controller.
##
## A mode is given the document, the shared services and the right to push
## commands. It knows nothing else about the editor: not the scene tree, not the
## other modes, not how the palette is drawn. It describes what it wants shown and
## the editor's panels render it.

## What a palette entry looks like to the editor: an id the mode gets back on
## click, a label, and an optional colour swatch.
class PaletteEntry:
	extends RefCounted
	var id: StringName
	var label: String
	var color := Color(0, 0, 0, 0)
	var is_header := false
	var is_expanded := false

	static func of(entry_id: StringName, entry_label: String, swatch := Color(0, 0, 0, 0)) -> PaletteEntry:
		var entry := PaletteEntry.new()
		entry.id = entry_id
		entry.label = entry_label
		entry.color = swatch
		return entry

	static func header(header_id: StringName, header_label: String, expanded := false) -> PaletteEntry:
		var entry := PaletteEntry.new()
		entry.id = header_id
		entry.label = ("▼ " if expanded else "► ") + header_label
		entry.is_header = true
		entry.is_expanded = expanded
		return entry


## A tool option the mode wants as a button under the palette — brush size, edit
## mode, ramp class. Pressing it calls back into `activate_option`.
class ToolOption:
	extends RefCounted
	var id: StringName
	var label: String
	## Options with the same non-empty row id are rendered beside one another.
	var row: StringName = &""
	var selected := false
	var disabled := false

	static func of(option_id: StringName, option_label: String, option_row: StringName = &"", is_selected := false, is_disabled := false) -> ToolOption:
		var option := ToolOption.new()
		option.id = option_id
		option.label = option_label
		option.row = option_row
		option.selected = is_selected
		option.disabled = is_disabled
		return option


signal ui_changed()

var id: StringName = &""
var title := ""
var icon := ""
var context: MapEditorContext = null


func configure(next_context: MapEditorContext) -> void:
	context = next_context


## Called when the author switches to and away from this mode. A mode must leave
## no visual or input state behind when it is deactivated.
func activate() -> void:
	pass


func deactivate() -> void:
	pass


## The document changed through another mode or shared-history replay. Modes with
## presentation caches rebuild them here without making `map_editor.gd` know
## their data shape.
func document_changed() -> void:
	pass


func process(_delta: float) -> void:
	pass


## Clears the hover state of whatever brush this mode uses. The editor calls this
## when the pointer leaves the 3D viewport, so a brush does not keep painting
## under a panel.
func clear_hover() -> void:
	pass


## The brush the hover marker should follow, or null when the mode has no brush.
## The editor reads this to position and scale the hover marker without knowing
## which brush the active mode uses.
func hover_brush() -> BaseBrushController:
	return null


## Adjusts the active brush's size. The editor delegates Shift+wheel here instead
## of reaching into a specific brush.
func adjust_brush_size(_delta: int) -> void:
	pass


## Samples properties from the hovered cell under the cursor.
func pick_from_cell() -> void:
	pass


## Input the camera did not claim. Return true to consume it.
func handle_input(_event: InputEvent) -> bool:
	return false


## Handles common mouse shortcuts shared across modes: Shift+wheel adjusts the
## brush size. Modes can call this from their own `handle_input` before
## mode-specific logic.
func _handle_common_mouse(event: InputEventMouseButton) -> bool:
	if event.shift_pressed and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				adjust_brush_size(1)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				adjust_brush_size(-1)
				return true
	return false


# --- What the panels show -----------------------------------------------------

func palette_entries() -> Array:
	return []


func selected_palette_entry() -> StringName:
	return &""


func select_palette_entry(_entry_id: StringName) -> void:
	pass


func tool_options() -> Array:
	return []


func activate_option(_option_id: StringName) -> void:
	pass


## Key/value lines for the inspector. With nothing selected these are the current
## tool's settings, which is what §3.2 asks the inspector to fall back to.
func inspector_lines() -> Array[String]:
	return []


func inspector_properties() -> Array[EntityPropertyDef]:
	return []


func inspector_values() -> Dictionary:
	return {}


func apply_inspector_value(_property_name: StringName, _value: Variant) -> bool:
	return false


func reset_inspector_value(_property_name: StringName) -> bool:
	return false


## Entities of this mode for the side list. Empty until phase 4 brings zones,
## points and routes.
func list_entries() -> Array[String]:
	return []


## The mode owns the side-list wording.  Placeholder copy must not claim that
## every mode is about zones and routes while the list is intentionally empty.
func list_title() -> String:
	return "Объекты"


func selected_list_index() -> int:
	return -1


func select_list_entry(_index: int) -> void:
	pass


func empty_list_hint() -> String:
	return "Объекты этого режима появятся в следующих фазах"


## The part of the status line this mode owns — what is under the cursor.
func status_text() -> String:
	return ""


func notify_ui_changed() -> void:
	ui_changed.emit()
