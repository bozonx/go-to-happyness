class_name WarehouseMenu
extends Panel

signal accept_toggled(accepted: bool, resource_type: String)
signal dump_requested(resource_type: String)
signal cover_requested
signal demolish_requested
signal close_requested

@onready var title_label: Label = $TitleLabel


func update_state(state: Dictionary) -> void:
	title_label.text = state.title_text

	for child in get_children():
		if child != title_label:
			child.queue_free()

	var y_offset := 100.0
	for item in state.resource_rows:
		var row := Label.new()
		row.position = Vector2(16, y_offset + 4)
		row.size = Vector2(150, 24)
		row.add_theme_font_size_override("font_size", 13)
		row.text = item.label
		add_child(row)
		var accept_cb := CheckBox.new()
		accept_cb.text = "Accept"
		accept_cb.position = Vector2(170, y_offset)
		accept_cb.size = Vector2(80, 28)
		accept_cb.set_pressed_no_signal(item.accepted)
		accept_cb.toggled.connect(accept_toggled.emit.bind(item.resource_type))
		add_child(accept_cb)
		var dump_btn := Button.new()
		dump_btn.text = "Dump"
		dump_btn.position = Vector2(250, y_offset)
		dump_btn.size = Vector2(50, 28)
		dump_btn.disabled = item.stored <= 0
		dump_btn.pressed.connect(dump_requested.emit.bind(item.resource_type))
		add_child(dump_btn)
		y_offset += 32.0

	var cover: Dictionary = state.cover_button
	var cover_btn := Button.new()
	cover_btn.text = cover.text
	cover_btn.disabled = cover.disabled
	cover_btn.position = Vector2(16, y_offset + 8)
	cover_btn.size = Vector2(290, 28)
	if not cover.disabled:
		cover_btn.pressed.connect(cover_requested.emit)
	add_child(cover_btn)

	var demolish_btn := Button.new()
	demolish_btn.text = "Mark for demolition"
	demolish_btn.position = Vector2(16, y_offset + 42)
	demolish_btn.size = Vector2(290, 28)
	demolish_btn.pressed.connect(demolish_requested.emit)
	add_child(demolish_btn)

	var close_btn := Button.new()
	close_btn.text = "Close Menu"
	close_btn.position = Vector2(16, y_offset + 76)
	close_btn.size = Vector2(290, 28)
	close_btn.pressed.connect(close_requested.emit)
	add_child(close_btn)
