class_name MapEditorModeBar
extends HBoxContainer

## The mode strip across the top bar (map_editor.md §3.2).
##
## Its children are the one part of the editor chrome that cannot be authored in
## the scene: the list of modes is what the editor decides it has, and phases 2–5
## add to it. The container, its styling and its place in the layout are in the
## `.tscn`; only the buttons are built here.
##
## It sits next to the file and undo buttons, the arrangement the building editor
## arrived at: what you are editing along the top, what you edit it with down the
## left.

signal mode_selected(mode_id: StringName)

var _by_id: Dictionary = {}


## `modes` is an array of `MapEditorMode`. The number key shown on each button is
## its position, which is what §3.3 binds `1`–`7` to.
func build(modes: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_by_id.clear()
	var slot := 1
	for mode: MapEditorMode in modes:
		var button := Button.new()
		button.text = "%d. %s" % [slot, mode.title]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		var mode_id: StringName = mode.id
		button.pressed.connect(func() -> void: mode_selected.emit(mode_id))
		add_child(button)
		_by_id[mode_id] = button
		slot += 1


func set_active(mode_id: StringName) -> void:
	for id: StringName in _by_id:
		(_by_id[id] as Button).button_pressed = id == mode_id


## Modes whose feature does not exist yet are shown and disabled rather than
## hidden: the author should be able to see that water and rules are coming and
## that this build does not have them (§5.3).
func set_enabled(mode_id: StringName, enabled: bool, reason := "") -> void:
	var button := _by_id.get(mode_id) as Button
	if button == null:
		return
	button.disabled = not enabled
	button.tooltip_text = reason
