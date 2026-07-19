class_name TimeControlsPanel
extends Control

signal skip_night_requested
signal skip_to_workday_start_requested
signal time_multiplier_changed(multiplier: float)

@onready var _speed_controls: HBoxContainer = $SpeedControls
@onready var skip_night_button: Button = $SkipNightButton
@onready var start_workday_button: Button = $StartWorkdayButton


func _ready() -> void:
	$SpeedControls/Speed1.pressed.connect(_on_speed_button_pressed.bind(1.0))
	$SpeedControls/Speed2.pressed.connect(_on_speed_button_pressed.bind(2.0))
	$SpeedControls/Speed5.pressed.connect(_on_speed_button_pressed.bind(5.0))
	
	skip_night_button.pressed.connect(skip_night_requested.emit)
	start_workday_button.pressed.connect(skip_to_workday_start_requested.emit)


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
