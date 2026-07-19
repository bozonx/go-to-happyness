class_name CampfireOrdersMenu
extends Panel

signal close_requested

@onready var road_walking_toggle: CheckButton = $RoadWalkingToggle
@onready var balanced_warehouse_toggle: CheckButton = $BalancedWarehouseToggle
@onready var night_work_button: CheckButton = $NightWorkButton
@onready var double_time_button: CheckButton = $DoubleTimeButton
@onready var cheer_button: Button = $CheerButton


func _ready() -> void:
	$CloseButton.pressed.connect(func(): close_requested.emit())
