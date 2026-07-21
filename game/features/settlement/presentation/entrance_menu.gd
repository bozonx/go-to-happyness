class_name EntranceMenu
extends Panel

signal modal_gui_input_received(event: InputEvent)
signal work_outside_requested
signal send_order_requested
signal close_requested

@onready var title_label: Label = $TitleLabel
@onready var entrance_work_button: Button = $EntranceWorkButton
@onready var create_order_button: Button = $CreateOrderButton
@onready var close_button: Button = $CloseButton

# Modal elements
@onready var entrance_order_modal: Panel = $EntranceOrderModal
@onready var entrance_order_food_spin: SpinBox = $EntranceOrderModal/FoodSpin
@onready var entrance_order_water_spin: SpinBox = $EntranceOrderModal/WaterSpin
@onready var entrance_order_gloves_spin: SpinBox = $EntranceOrderModal/GlovesSpin
@onready var entrance_order_bucket_spin: SpinBox = $EntranceOrderModal/BucketSpin
@onready var entrance_order_total_label: Label = $EntranceOrderModal/TotalLabel
@onready var send_button: Button = $EntranceOrderModal/SendButton
@onready var modal_close_button: Button = $EntranceOrderModal/CloseButton


func _ready() -> void:
	if entrance_order_modal != null:
		entrance_order_modal.gui_input.connect(func(event: InputEvent):
			modal_gui_input_received.emit(event)
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				entrance_order_modal.visible = false
		)
	if create_order_button != null:
		create_order_button.pressed.connect(func(): if entrance_order_modal != null: entrance_order_modal.visible = true)
	if entrance_work_button != null:
		entrance_work_button.pressed.connect(func(): work_outside_requested.emit())
	if close_button != null:
		close_button.pressed.connect(func(): close_requested.emit())
	if send_button != null:
		send_button.pressed.connect(func(): send_order_requested.emit())
	if modal_close_button != null:
		modal_close_button.pressed.connect(func(): if entrance_order_modal != null: entrance_order_modal.visible = false)
