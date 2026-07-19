class_name EntranceMenu
extends Panel

signal modal_gui_input_received(event: InputEvent)

@onready var title_label: Label = $TitleLabel
@onready var entrance_work_button: Button = $EntranceWorkButton

# Modal elements
@onready var entrance_order_modal: Panel = $EntranceOrderModal
@onready var entrance_order_food_spin: SpinBox = $EntranceOrderModal/FoodSpin
@onready var entrance_order_water_spin: SpinBox = $EntranceOrderModal/WaterSpin
@onready var entrance_order_gloves_spin: SpinBox = $EntranceOrderModal/GlovesSpin
@onready var entrance_order_bucket_spin: SpinBox = $EntranceOrderModal/BucketSpin
@onready var entrance_order_total_label: Label = $EntranceOrderModal/TotalLabel


func _ready() -> void:
	entrance_order_modal.gui_input.connect(func(event): modal_gui_input_received.emit(event))
