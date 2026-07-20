class_name MarketMenu
extends Panel

signal sell_requested(resource_type: String, quantity: int, unit_price: int)
signal buy_tool_requested(tool_id: String, price: int)
signal buy_equipment_requested(courier, equipment_id: String, price: int)
signal buy_food_requested(quantity: int, unit_price: int)
signal close_requested

const MarketItemButtonScene = preload("res://game/features/logistics/presentation/market_item_button.tscn")

@onready var title_label: Label = $TitleLabel
@onready var item_list: VBoxContainer = $ScrollContainer/ItemList
@onready var close_btn: Button = $CloseButton


func _ready() -> void:
	close_btn.pressed.connect(func(): close_requested.emit())


func update_state(state: Dictionary) -> void:
	title_label.text = state.title_text

	for child in item_list.get_children():
		child.queue_free()

	for item in state.sell_items:
		var btn: MarketItemButton = MarketItemButtonScene.instantiate()
		btn.setup(item.text, item.disabled, item.tooltip)
		btn.pressed.connect(sell_requested.emit.bind(item.resource, item.quantity, item.price))
		item_list.add_child(btn)

	for item in state.buy_items:
		var btn: MarketItemButton = MarketItemButtonScene.instantiate()
		btn.setup(item.text, item.disabled, item.tooltip)
		btn.pressed.connect(buy_tool_requested.emit.bind(item.tool_id, item.price))
		item_list.add_child(btn)

	if state.has("equipment_label"):
		var equipment_label := Label.new()
		equipment_label.text = state.equipment_label
		item_list.add_child(equipment_label)
		for item in state.equipment_offers:
			var btn: MarketItemButton = MarketItemButtonScene.instantiate()
			btn.setup(item.text, item.disabled, item.tooltip)
			btn.pressed.connect(buy_equipment_requested.emit.bind(item.courier, item.equipment_id, item.price))
			item_list.add_child(btn)

	var food: Dictionary = state.food_button
	var food_btn: MarketItemButton = MarketItemButtonScene.instantiate()
	food_btn.setup(food.text, food.disabled, food.tooltip)
	food_btn.pressed.connect(buy_food_requested.emit.bind(food.quantity, food.unit_price))
	item_list.add_child(food_btn)
