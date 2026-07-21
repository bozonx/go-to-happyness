class_name BuildingMenu
extends Panel

signal cook_assigned
signal teacher_assigned
signal seller_assigned
signal acceptance_toggled
signal worker_dismissed
signal overtime_toggled(toggled_on: bool)
signal relight_requested
signal upgrade_requested
signal demolish_requested
signal close_requested
signal cancel_construction_requested

@onready var title_label: Label = $TitleLabel
@onready var cook_button: Button = $CookButton
@onready var teacher_button: Button = $TeacherButton
@onready var seller_button: Button = $SellerButton
@onready var accept_workers_button: Button = $AcceptWorkersButton
@onready var dismiss_worker_button: Button = $DismissWorkerButton
@onready var overtime_button: CheckButton = $OvertimeButton
@onready var relight_button: Button = $RelightButton
@onready var upgrade_button: Button = $UpgradeButton
@onready var demolish_button: Button = $DemolishButton
@onready var close_button: Button = $CloseButton
@onready var cancel_construction_button: Button = $CancelConstructionButton


func _ready() -> void:
	if cook_button != null:
		cook_button.pressed.connect(func(): cook_assigned.emit())
	if teacher_button != null:
		teacher_button.pressed.connect(func(): teacher_assigned.emit())
	if seller_button != null:
		seller_button.pressed.connect(func(): seller_assigned.emit())
	if accept_workers_button != null:
		accept_workers_button.pressed.connect(func(): acceptance_toggled.emit())
	if dismiss_worker_button != null:
		dismiss_worker_button.pressed.connect(func(): worker_dismissed.emit())
	if overtime_button != null:
		overtime_button.toggled.connect(func(toggled_on: bool): overtime_toggled.emit(toggled_on))
	if relight_button != null:
		relight_button.pressed.connect(func(): relight_requested.emit())
	if upgrade_button != null:
		upgrade_button.pressed.connect(func(): upgrade_requested.emit())
	if demolish_button != null:
		demolish_button.pressed.connect(func(): demolish_requested.emit())
	if close_button != null:
		close_button.pressed.connect(func(): close_requested.emit())
	if cancel_construction_button != null:
		cancel_construction_button.pressed.connect(func(): cancel_construction_requested.emit())
