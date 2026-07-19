class_name WorkforceMenu
extends Panel

signal close_requested

var title_label: Label
var list: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -230.0
	offset_top = -255.0
	offset_right = 230.0
	offset_bottom = 255.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.14, 0.18, 0.75)
	style.border_color = Color(0.25, 0.4, 0.5, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	visible = false

	title_label = Label.new()
	title_label.position = Vector2(18, 16)
	title_label.size = Vector2(424, 30)
	title_label.add_theme_font_size_override("font_size", 18)
	add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(18, 54)
	scroll.size = Vector2(424, 390)
	add_child(scroll)

	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(18, 458)
	close_btn.size = Vector2(424, 32)
	close_btn.pressed.connect(func(): close_requested.emit())
	add_child(close_btn)
