class_name MarketItemButton
extends Button

var _btn_text: String = ""
var _is_disabled: bool = false
var _tooltip: String = ""


func setup(button_text: String, is_disabled: bool, tooltip: String) -> void:
	_btn_text = button_text
	_is_disabled = is_disabled
	_tooltip = tooltip
	if is_node_ready():
		_apply_data()


func _ready() -> void:
	if _btn_text != "":
		_apply_data()


func _apply_data() -> void:
	text = _btn_text
	disabled = _is_disabled
	tooltip_text = _tooltip
