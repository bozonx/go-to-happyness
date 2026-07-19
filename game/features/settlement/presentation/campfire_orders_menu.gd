class_name CampfireOrdersMenu
extends Panel

signal close_requested
signal road_walking_toggled(enabled: bool)
signal balanced_warehouse_toggled(enabled: bool)
signal night_work_toggled(enabled: bool)
signal double_time_toggled(enabled: bool)
signal cheer_pressed

@onready var _road_walking_toggle: CheckButton = $RoadWalkingToggle
@onready var _balanced_warehouse_toggle: CheckButton = $BalancedWarehouseToggle
@onready var _night_work_button: CheckButton = $NightWorkButton
@onready var _double_time_button: CheckButton = $DoubleTimeButton
@onready var _cheer_button: Button = $CheerButton


func _ready() -> void:
	$CloseButton.pressed.connect(func(): close_requested.emit())
	_road_walking_toggle.toggled.connect(func(pressed): road_walking_toggled.emit(pressed))
	_balanced_warehouse_toggle.toggled.connect(func(pressed): balanced_warehouse_toggled.emit(pressed))
	_night_work_button.toggled.connect(func(pressed): night_work_toggled.emit(pressed))
	_double_time_button.toggled.connect(func(pressed): double_time_toggled.emit(pressed))
	_cheer_button.pressed.connect(func(): cheer_pressed.emit())


func update_state(state: Dictionary) -> void:
	if _road_walking_toggle != null:
		_road_walking_toggle.set_pressed_no_signal(state.road_walking_enabled)
		_road_walking_toggle.disabled = state.road_walking_disabled
		_road_walking_toggle.tooltip_text = state.road_walking_tooltip
	
	if _balanced_warehouse_toggle != null:
		_balanced_warehouse_toggle.set_pressed_no_signal(state.balanced_warehouse_enabled)
		_balanced_warehouse_toggle.disabled = state.balanced_warehouse_disabled
		_balanced_warehouse_toggle.tooltip_text = state.balanced_warehouse_tooltip
		
	if _cheer_button != null:
		_cheer_button.disabled = state.cheer_disabled
		_cheer_button.tooltip_text = state.cheer_tooltip
		
	if _night_work_button != null:
		_night_work_button.disabled = state.night_work_disabled
		_night_work_button.set_pressed_no_signal(state.night_work_enabled)
		_night_work_button.tooltip_text = state.night_work_tooltip
		
	if _double_time_button != null:
		_double_time_button.set_pressed_no_signal(state.double_time_enabled)
		_double_time_button.tooltip_text = state.double_time_tooltip
