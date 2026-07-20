class_name WorkforceUnregisteredRow
extends HBoxContainer

signal action_requested

@onready var label: Label = $Label
@onready var action_button: Button = $ActionButton

var _data: Dictionary


func setup(resident_data: Dictionary) -> void:
	_data = resident_data
	if is_node_ready():
		_apply_data()


func _ready() -> void:
	action_button.pressed.connect(func(): action_requested.emit())
	if not _data.is_empty():
		_apply_data()


func _apply_data() -> void:
	label.text = _data.label
	action_button.text = _data.button_text
	action_button.tooltip_text = _data.tooltip
	action_button.disabled = _data.disabled
