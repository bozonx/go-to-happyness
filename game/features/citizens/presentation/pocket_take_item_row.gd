class_name PocketTakeItemRow
extends HBoxContainer

signal take_one_requested
signal take_all_requested

@onready var label: Label = $Label
@onready var take_one_button: Button = $TakeOneButton
@onready var take_all_button: Button = $TakeAllButton

var _resource_name: String = ""
var _amount: int = 0


func setup(resource_name: String, amount: int) -> void:
	_resource_name = resource_name
	_amount = amount
	if is_node_ready():
		_apply_data()


func _ready() -> void:
	take_one_button.pressed.connect(func(): take_one_requested.emit())
	take_all_button.pressed.connect(func(): take_all_requested.emit())
	if _resource_name != "":
		_apply_data()


func _apply_data() -> void:
	label.text = "%s: %d" % [_resource_name.capitalize(), _amount]
