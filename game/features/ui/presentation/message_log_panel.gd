class_name MessageLogPanel
extends Control

const _MAX_COMPACT_MESSAGES := 60

@onready var _compact_panel: Panel = $CompactPanel
@onready var _compact_scroll: ScrollContainer = $CompactPanel/CompactScroll
@onready var _compact_list: VBoxContainer = $CompactPanel/CompactScroll/CompactList
@onready var _modal_panel: Panel = $ModalPanel
@onready var _modal_list: VBoxContainer = $ModalPanel/Scroll/ModalList

var _messages: Array[Dictionary] = []


func _ready() -> void:
	$CompactPanel/Header/HistoryButton.pressed.connect(open_modal)
	$ModalPanel/CloseButton.pressed.connect(close_modal)


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
