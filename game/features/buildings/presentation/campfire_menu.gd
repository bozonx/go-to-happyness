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


func update_state(state: Dictionary) -> void:
	title_label.text = state.title_text
	requirements_label.text = state.requirements_text
	advance_button.disabled = state.advance_disabled

	var upgrade: Dictionary = state.upgrade
	upgrade_button.visible = upgrade.visible
	upgrade_button.text = upgrade.text
	upgrade_button.disabled = upgrade.disabled
	upgrade_button.tooltip_text = upgrade.tooltip

	accept_button.visible = false
	dismiss_button.visible = false

	var research_post: Dictionary = state.research_post
	research_post_button.visible = research_post.visible
	research_post_button.text = research_post.text
	research_post_button.disabled = research_post.disabled
	research_post_button.tooltip_text = research_post.tooltip

	var occupy: Dictionary = state.occupy_position
	occupy_position_button.visible = occupy.visible
	occupy_position_button.text = occupy.text
	occupy_position_button.disabled = occupy.disabled
	occupy_position_button.tooltip_text = occupy.tooltip

	var overtime: Dictionary = state.overtime
	overtime_button.visible = overtime.visible
	overtime_button.disabled = overtime.disabled
	overtime_button.set_pressed_no_signal(overtime.pressed)
	overtime_button.tooltip_text = overtime.tooltip

	if state.has("close_btn_y"):
		close_btn.position.y = state.close_btn_y


func update_occupancy_button(text: String, disabled: bool, tooltip: String) -> void:
	occupancy_button.text = text
	occupancy_button.disabled = disabled
	occupancy_button.tooltip_text = tooltip
