class_name MarketMenu
extends Panel

signal sell_requested(resource_type: String, quantity: int, unit_price: int)
signal buy_tool_requested(tool_id: String, price: int)
signal buy_equipment_requested(courier, equipment_id: String, price: int)
signal buy_food_requested(quantity: int, unit_price: int)
signal close_requested

@onready var title_label: Label = $TitleLabel


func update_state(state: Dictionary) -> void:
	title_label.text = state.title_text

	# Clear previous buttons except title
	for child in get_children():
		if child != title_label:
			remove_child(child)
			child.queue_free()

	var y_offset: float = state.y_offset

	for item in state.sell_items:
		var btn := Button.new()
		btn.text = item.text
		btn.position = Vector2(16, y_offset)
		btn.size = Vector2(272, 28)
		btn.disabled = item.disabled
		btn.tooltip_text = item.tooltip
		btn.pressed.connect(sell_requested.emit.bind(item.resource, item.quantity, item.price))
		add_child(btn)
		y_offset += 32.0

	y_offset += 10.0

	for item in state.buy_items:
		var btn := Button.new()
		btn.text = item.text
		btn.position = Vector2(16, y_offset)
		btn.size = Vector2(272, 28)
		btn.disabled = item.disabled
		btn.tooltip_text = item.tooltip
		btn.pressed.connect(buy_tool_requested.emit.bind(item.tool_id, item.price))
		add_child(btn)
		y_offset += 32.0

	if state.has("equipment_label"):
		var equipment_label := Label.new()
		equipment_label.text = state.equipment_label
		equipment_label.position = Vector2(16, y_offset)
		equipment_label.size = Vector2(272, 22)
		add_child(equipment_label)
		y_offset += 24.0
		for item in state.equipment_offers:
			var btn := Button.new()
			btn.text = item.text
			btn.position = Vector2(16, y_offset)
			btn.size = Vector2(272, 28)
			btn.disabled = item.disabled
			btn.tooltip_text = item.tooltip
			btn.pressed.connect(buy_equipment_requested.emit.bind(item.courier, item.equipment_id, item.price))
			add_child(btn)
			y_offset += 32.0

	y_offset += 10.0

	var food: Dictionary = state.food_button
	var food_btn := Button.new()
	food_btn.text = food.text
	food_btn.position = Vector2(16, y_offset)
	food_btn.size = Vector2(272, 28)
	food_btn.disabled = food.disabled
	food_btn.tooltip_text = food.tooltip
	food_btn.pressed.connect(buy_food_requested.emit.bind(food.quantity, food.unit_price))
	add_child(food_btn)
	y_offset += 42.0

	var close_btn := Button.new()
	close_btn.text = "Close Menu"
	close_btn.position = Vector2(16, y_offset)
	close_btn.size = Vector2(272, 28)
	close_btn.pressed.connect(close_requested.emit)
	add_child(close_btn)
	offset_top = -maxf(420.0, y_offset + 66.0)
