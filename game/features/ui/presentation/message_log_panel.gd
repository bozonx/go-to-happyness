class_name MessageLogPanel
extends Control

const _MAX_COMPACT_MESSAGES := 60

var _compact_panel: Panel
var _compact_scroll: ScrollContainer
var _compact_list: VBoxContainer
var _modal_panel: Panel
var _modal_list: VBoxContainer
var _messages: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_compact_panel()
	_build_modal_panel()


func _build_compact_panel() -> void:
	_compact_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.08, 0.92)
	style.border_color = Color(0.15, 0.25, 0.32, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_compact_panel.add_theme_stylebox_override("panel", style)
	_compact_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_compact_panel.offset_left = 20
	_compact_panel.offset_top = -268
	_compact_panel.offset_right = 400
	_compact_panel.offset_bottom = -38
	add_child(_compact_panel)

	var header := HBoxContainer.new()
	header.position = Vector2(10, 6)
	header.size = Vector2(368, 26)
	_compact_panel.add_child(header)

	var title := Label.new()
	title.text = "Messages"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var history_btn := Button.new()
	history_btn.text = "History"
	history_btn.add_theme_font_size_override("font_size", 12)
	history_btn.custom_minimum_size = Vector2(70, 24)
	history_btn.pressed.connect(open_modal)
	header.add_child(history_btn)

	_compact_scroll = ScrollContainer.new()
	_compact_scroll.position = Vector2(6, 34)
	_compact_scroll.size = Vector2(376, 190)
	_compact_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_compact_panel.add_child(_compact_scroll)

	_compact_list = VBoxContainer.new()
	_compact_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_scroll.add_child(_compact_list)


func _build_modal_panel() -> void:
	_modal_panel = Panel.new()
	_modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	_modal_panel.offset_left = -300.0
	_modal_panel.offset_top = -240.0
	_modal_panel.offset_right = 300.0
	_modal_panel.offset_bottom = 240.0
	_modal_panel.visible = false
	add_child(_modal_panel)

	var title := Label.new()
	title.text = "Message History"
	title.position = Vector2(20, 12)
	title.size = Vector2(460, 30)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_modal_panel.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(510, 10)
	close_btn.size = Vector2(78, 30)
	close_btn.pressed.connect(close_modal)
	_modal_panel.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 48)
	scroll.size = Vector2(576, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_panel.add_child(scroll)

	_modal_list = VBoxContainer.new()
	_modal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_modal_list)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		close_modal()


func add_message(text: String, timestamp: String) -> void:
	if text.is_empty() or not _is_gameplay_message(text):
		return
	var msg_type := _classify_message(text)
	var entry := {"text": text, "type": msg_type, "timestamp": timestamp}
	_messages.append(entry)
	var color := _message_color(msg_type)
	var formatted := "[color=%s]%s[/color] %s" % [color, timestamp, text]
	_append_message_label(_compact_list, formatted, 12, 356)
	_scroll_to_bottom.call_deferred()
	while _compact_list.get_child_count() > _MAX_COMPACT_MESSAGES:
		var old_node := _compact_list.get_child(0)
		_compact_list.remove_child(old_node)
		old_node.queue_free()


func open_modal() -> void:
	if _modal_panel == null:
		return
	for child in _modal_list.get_children():
		child.queue_free()
	for entry in _messages:
		var color := _message_color(entry.type)
		var formatted := "[color=%s]%s[/color] %s" % [color, entry.timestamp, entry.text]
		_append_message_label(_modal_list, formatted, 13, 564)
	_modal_panel.visible = true


func close_modal() -> void:
	if _modal_panel != null:
		_modal_panel.visible = false


func is_modal_visible() -> bool:
	return _modal_panel != null and _modal_panel.visible


func _is_gameplay_message(text: String) -> bool:
	var lower := text.to_lower()
	for noise in [" selected", "view enabled", "overview centered", "simulation speed", "workday set", "night shifts", "construction mode cancelled"]:
		if lower.contains(noise):
			return false
	return true


func _classify_message(text: String) -> String:
	var lower := text.to_lower()
	if lower.contains("critical") or lower.contains("missed") or lower.contains("ran out") or lower.contains("left after") or lower.contains("no canteen") or lower.contains("needs a cook") or lower.contains("no storage room") or lower.contains("interrupted") or lower.contains("not allowed") or lower.contains("exhausted") or lower.contains("starving") or lower.contains("dehydrated"):
		return "error"
	if lower.contains("warning") or lower.contains("rebalance") or lower.contains("low wellbeing") or lower.contains("declining") or lower.contains("filling up") or lower.contains("running low") or lower.contains("needs") or lower.contains("requires"):
		return "warning"
	if lower.contains("unlocked") or lower.contains("completed") or lower.contains("delivered") or lower.contains("produced") or lower.contains("joined") or lower.contains("built") or lower.contains("advanced") or lower.contains("received") or lower.contains("research started"):
		return "success"
	return "info"


func _message_color(msg_type: String) -> String:
	match msg_type:
		"error": return "#e85555"
		"warning": return "#f0a030"
		"success": return "#7dce82"
		_: return "#8ab4cc"


func _append_message_label(container: VBoxContainer, formatted_text: String, font_size: int, min_width: float) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.text = formatted_text
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.custom_minimum_size = Vector2(min_width, 0)
	container.add_child(label)


func _scroll_to_bottom() -> void:
	if _compact_scroll != null:
		_compact_scroll.scroll_vertical = int(_compact_scroll.get_v_scroll_bar().max_value)
