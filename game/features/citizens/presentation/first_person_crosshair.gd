class_name FirstPersonCrosshair
extends Control

@export var radius: float = 6.0
@export var color: Color = Color(1.0, 1.0, 1.0, 0.85)
@export var line_width: float = 2.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(radius * 2.0 + line_width * 2.0, radius * 2.0 + line_width * 2.0)
	set_anchors_preset(PRESET_CENTER)
	offset_left = -size.x * 0.5
	offset_top = -size.y * 0.5
	offset_right = size.x * 0.5
	offset_bottom = size.y * 0.5

func _draw() -> void:
	var center := size * 0.5
	draw_arc(center, radius, 0.0, TAU, 64, color, line_width, true)
	draw_circle(center, radius * 0.15, color)
