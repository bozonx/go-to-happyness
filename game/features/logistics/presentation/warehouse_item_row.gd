class_name WarehouseItemRow
extends HBoxContainer

signal accept_toggled(accepted: bool)
signal dump_requested

@onready var label: Label = $Label
@onready var accept_checkbox: CheckBox = $AcceptCheckBox
@onready var dump_button: Button = $DumpButton

var _data: Dictionary


func setup(item_data: Dictionary) -> void:
	_data = item_data
	if is_node_ready():
		_apply_data()


func _ready() -> void:
	accept_checkbox.toggled.connect(func(pressed: bool): accept_toggled.emit(pressed))
	dump_button.pressed.connect(func(): dump_requested.emit())
	if not _data.is_empty():
		_apply_data()


func _apply_data() -> void:
	label.text = _data.label
	accept_checkbox.set_pressed_no_signal(_data.accepted)
	dump_button.disabled = _data.stored <= 0
