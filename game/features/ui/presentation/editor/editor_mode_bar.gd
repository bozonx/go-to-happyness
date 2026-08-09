class_name EditorModeBar
extends HBoxContainer

## Shared mode switcher for authoring tools. It consumes presentation-only
## dictionaries, so the UI feature does not depend on map or building modes.

signal mode_selected(mode_id: StringName)

var _by_id: Dictionary = {}


func build(items: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_by_id.clear()
	for item: Dictionary in items:
		var id := StringName(item.get("id", &""))
		var button := Button.new()
		button.text = String(item.get("icon", item.get("title", id)))
		button.custom_minimum_size = Vector2(38, 0)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = String(item.get("tooltip", item.get("title", id)))
		button.disabled = not bool(item.get("enabled", true))
		button.pressed.connect(func() -> void: mode_selected.emit(id))
		add_child(button)
		_by_id[id] = button


func set_active(mode_id: StringName) -> void:
	for id: StringName in _by_id:
		(_by_id[id] as Button).button_pressed = id == mode_id


func set_enabled(mode_id: StringName, enabled: bool, reason := "") -> void:
	var button := _by_id.get(mode_id) as Button
	if button == null:
		return
	button.disabled = not enabled
	if not reason.is_empty():
		button.tooltip_text += " — " + reason
