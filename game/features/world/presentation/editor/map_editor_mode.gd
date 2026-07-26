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

	static func of(entry_id: StringName, entry_label: String, swatch := Color(0, 0, 0, 0)) -> PaletteEntry:
		var entry := PaletteEntry.new()
		entry.id = entry_id
		entry.label = entry_label
		entry.color = swatch
		return entry


## A tool option the mode wants as a button under the palette — brush size, edit
## mode, ramp class. Pressing it calls back into `activate_option`.
class ToolOption:
	extends RefCounted
	var id: StringName
	var label: String

	static func of(option_id: StringName, option_label: String) -> ToolOption:
		var option := ToolOption.new()
		option.id = option_id
		option.label = option_label
		return option


signal ui_changed()

var id: StringName = &""
var title := ""
var context: MapEditorContext = null


func configure(next_context: MapEditorContext) -> void:
	context = next_context


## Called when the author switches to and away from this mode. A mode must leave
## no visual or input state behind when it is deactivated.
func activate() -> void:
	pass


func deactivate() -> void:
	pass


func process(_delta: float) -> void:
	pass


## Input the camera did not claim. Return true to consume it.
func handle_input(_event: InputEvent) -> bool:
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


## Entities of this mode for the side list. Empty until phase 4 brings zones,
## points and routes.
func list_entries() -> Array[String]:
	return []


## The part of the status line this mode owns — what is under the cursor.
func status_text() -> String:
	return ""


func notify_ui_changed() -> void:
	ui_changed.emit()
