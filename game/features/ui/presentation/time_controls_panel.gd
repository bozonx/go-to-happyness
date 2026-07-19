class_name TimeControlsPanel
extends Control

signal skip_night_requested
signal skip_to_workday_start_requested
signal time_multiplier_changed(multiplier: float)

var _speed_controls: HBoxContainer
var skip_night_button: Button
var start_workday_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	_speed_controls = HBoxContainer.new()
	_speed_controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_speed_controls.offset_left = -220
	_speed_controls.offset_top = 58
	_speed_controls.offset_right = -22
	_speed_controls.offset_bottom = 90
	_speed_controls.alignment = BoxContainer.ALIGNMENT_END
	add_child(_speed_controls)
	for multiplier in [1.0, 2.0, 5.0]:
		var button := Button.new()
		button.text = "x%d" % int(multiplier)
		button.tooltip_text = "Simulation speed x%d" % int(multiplier)
		button.custom_minimum_size = Vector2(56, 30)
		button.pressed.connect(_on_speed_button_pressed.bind(multiplier))
		_speed_controls.add_child(button)
	# Appears as soon as the selected workday is over, including the evening
	# hours before the world is considered night.
	skip_night_button = Button.new()
	skip_night_button.text = "Skip night »"
	skip_night_button.tooltip_text = "Jump to the next morning (06:00)"
	skip_night_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_night_button.offset_left = -220
	skip_night_button.offset_top = 96
	skip_night_button.offset_right = -22
	skip_night_button.offset_bottom = 128
	skip_night_button.visible = false
	skip_night_button.pressed.connect(skip_night_requested.emit)
	add_child(skip_night_button)
	start_workday_button = Button.new()
	start_workday_button.text = "К началу рабочего дня"
	start_workday_button.tooltip_text = "Jump to 08:00"
	start_workday_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	start_workday_button.offset_left = -220
	start_workday_button.offset_top = 96
	start_workday_button.offset_right = -22
	start_workday_button.offset_bottom = 128
	start_workday_button.visible = false
	start_workday_button.pressed.connect(skip_to_workday_start_requested.emit)
	add_child(start_workday_button)


func _on_speed_button_pressed(multiplier: float) -> void:
	time_multiplier_changed.emit(multiplier)


func set_speed_controls_visible(vis: bool) -> void:
	if _speed_controls != null:
		_speed_controls.visible = vis


func hide_skip_buttons() -> void:
	if skip_night_button != null:
		skip_night_button.visible = false
	if start_workday_button != null:
		start_workday_button.visible = false


func update_skip_buttons(can_skip_night: bool, can_skip_to_workday_start: bool, is_first_person: bool) -> void:
	if is_first_person:
		hide_skip_buttons()
		return
	if skip_night_button != null:
		skip_night_button.visible = can_skip_night
	if start_workday_button != null:
		start_workday_button.visible = can_skip_to_workday_start
