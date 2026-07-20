class_name ContextMenuPanel
extends Panel

func setup(anchor: int, offsets: Vector4, input_handler: Callable) -> void:
	set_anchors_preset(anchor)
	offset_left = offsets.x
	offset_top = offsets.y
	offset_right = offsets.z
	offset_bottom = offsets.w
	visible = false
	if input_handler.is_valid() and not gui_input.is_connected(input_handler):
		gui_input.connect(input_handler)
