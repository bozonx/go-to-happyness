class_name InteractionHintPanel
extends Panel


var hint_label: Label
var progress_bar: ProgressBar


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -340
	offset_top = -80
	offset_right = 340
	offset_bottom = -12
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.14, 0.18, 0.75)
	style.border_color = Color(0.25, 0.4, 0.5, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	visible = false

	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint_label.offset_left = 12
	hint_label.offset_top = 8
	hint_label.offset_right = -12
	hint_label.offset_bottom = 34
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 16)
	add_child(hint_label)

	progress_bar = ProgressBar.new()
	progress_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	progress_bar.offset_left = 20
	progress_bar.offset_top = 40
	progress_bar.offset_right = -20
	progress_bar.offset_bottom = 60
	progress_bar.show_percentage = true
	progress_bar.visible = false
	add_child(progress_bar)
