class_name BuildMenu
extends Panel

signal gui_input_received(event: InputEvent)

@onready var title_label: Label = $TitleLabel
@onready var citizen_skills_label: Label = $CitizenSkillsLabel
@onready var manage_citizen_button: Button = $ManageCitizenButton
@onready var daily_order_submenu_btn: Button = $DailyOrderSubmenuButton
@onready var personal_night_work_button: CheckButton = $PersonalNightWorkButton
@onready var job_submenu_btn: Button = $JobSubmenuButton
@onready var job_back_btn: Button = $JobBackButton


func _ready() -> void:
	gui_input.connect(func(event): gui_input_received.emit(event))
