class_name CampfireMenu
extends Panel

signal workday_hours_changed(hours: int)

@onready var title_label: Label = $TitleLabel
@onready var requirements_label: Label = $RequirementsLabel
@onready var advance_button: Button = $AdvanceButton
@onready var orders_button: Button = $OrdersButton
@onready var upgrade_button: Button = $UpgradeButton
@onready var occupancy_button: Button = $OccupancyButton
@onready var research_button: Button = $ResearchButton
@onready var research_post_button: Button = $ResearchPostButton
@onready var occupy_position_button: Button = $OccupyPositionButton
@onready var accept_button: Button = $AcceptButton
@onready var dismiss_button: Button = $DismissButton
@onready var overtime_button: CheckButton = $OvertimeButton
@onready var story_button: Button = $StoryButton
@onready var close_btn: Button = $CloseButton


func _ready() -> void:
	$LabourControls/Hour6.pressed.connect(func(): workday_hours_changed.emit(6))
	$LabourControls/Hour8.pressed.connect(func(): workday_hours_changed.emit(8))
	$LabourControls/Hour10.pressed.connect(func(): workday_hours_changed.emit(10))
	$LabourControls/Hour12.pressed.connect(func(): workday_hours_changed.emit(12))
	$LabourControls/Hour14.pressed.connect(func(): workday_hours_changed.emit(14))
