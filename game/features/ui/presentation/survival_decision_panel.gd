class_name SurvivalDecisionPanel
extends Panel

signal choice_selected(index: int)

var title_label: Label
var description_label: Label
var _choice_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -240.0
	offset_top = -150.0
	offset_right = 240.0
	offset_bottom = 150.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.14, 0.18, 0.75)
	style.border_color = Color(0.25, 0.4, 0.5, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	visible = false

	title_label = Label.new()
	title_label.position = Vector2(20, 18)
	title_label.size = Vector2(440, 28)
	title_label.add_theme_font_size_override("font_size", 19)
	add_child(title_label)

	description_label = Label.new()
	description_label.position = Vector2(20, 58)
	description_label.size = Vector2(440, 116)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(description_label)


func show_event(title: String, description: String, choice_labels: Array[String]) -> void:
	title_label.text = title
	description_label.text = description
	for btn in _choice_buttons:
		btn.queue_free()
	_choice_buttons.clear()
	var y_offset := 194
	for i in range(choice_labels.size()):
		var btn := Button.new()
		btn.position = Vector2(20, y_offset)
		btn.size = Vector2(440, 32)
		btn.text = choice_labels[i]
		btn.pressed.connect(choice_selected.emit.bind(i))
		add_child(btn)
		_choice_buttons.append(btn)
		y_offset += 42
	visible = true


func hide_panel() -> void:
	visible = false
