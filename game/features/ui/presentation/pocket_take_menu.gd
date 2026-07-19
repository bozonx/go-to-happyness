class_name PocketTakeMenu
extends Panel

var title_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -220.0
	offset_top = -260.0
	offset_right = 220.0
	offset_bottom = 260.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.14, 0.18, 0.75)
	style.border_color = Color(0.25, 0.4, 0.5, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	visible = false

	title_label = Label.new()
	title_label.text = "Взять товары со склада"
	title_label.position = Vector2(20, 12)
	title_label.size = Vector2(400, 28)
	title_label.add_theme_font_size_override("font_size", 17)
	add_child(title_label)
