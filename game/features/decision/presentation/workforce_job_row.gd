class_name WorkforceJobRow
extends HBoxContainer

signal dismiss_requested
signal assign_requested

@onready var label: Label = $Label
@onready var dismiss_button: Button = $DismissButton
@onready var assign_button: Button = $AssignButton

var _data: Dictionary


func setup(job_data: Dictionary) -> void:
	_data = job_data
	if is_node_ready():
		_apply_data()


func _ready() -> void:
	dismiss_button.pressed.connect(func(): dismiss_requested.emit())
	assign_button.pressed.connect(func(): assign_requested.emit())
	if not _data.is_empty():
		_apply_data()


func _apply_data() -> void:
	label.text = _data.label
	dismiss_button.tooltip_text = _data.dismiss_tooltip
	dismiss_button.disabled = _data.dismiss_disabled
	assign_button.tooltip_text = _data.assign_tooltip
	assign_button.disabled = _data.assign_disabled
