class_name WorkforceMenu
extends Panel

signal close_requested
signal dismiss_requested(role: String)
signal assign_requested(role: String)
signal register_requested(citizen: Citizen)

const WorkforceJobRowScene = preload("res://game/features/decision/presentation/workforce_job_row.tscn")
const WorkforceUnregisteredRowScene = preload("res://game/features/decision/presentation/workforce_unregistered_row.tscn")

@onready var title_label: Label = $TitleLabel
@onready var list: VBoxContainer = $ScrollContainer/List


func _ready() -> void:
	$CloseButton.pressed.connect(func(): close_requested.emit())


func update_state(state: Dictionary) -> void:
	title_label.text = state.title_text
	for child in list.get_children():
		child.queue_free()

	_add_summary(state.summary_text)

	_add_section_label("Employed positions")
	for job in state.job_rows:
		_add_job_row(job)
	if state.no_jobs_text != "":
		_add_summary(state.no_jobs_text)

	_add_section_label("Daily orders")
	_add_summary(state.daily_orders_available)
	for entry in state.daily_order_rows:
		_add_summary(entry)

	if state.unregistered_header != "":
		_add_section_label(state.unregistered_header)
		for resident in state.unregistered_rows:
			_add_unregistered_resident_row(resident)


func _add_section_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	list.add_child(label)


func _add_summary(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("c7d6df"))
	list.add_child(label)


func _add_job_row(job: Dictionary) -> void:
	var row: WorkforceJobRow = WorkforceJobRowScene.instantiate()
	row.setup(job)
	row.dismiss_requested.connect(dismiss_requested.emit.bind(job.role))
	row.assign_requested.connect(assign_requested.emit.bind(job.role))
	list.add_child(row)


func _add_unregistered_resident_row(resident: Dictionary) -> void:
	var row: WorkforceUnregisteredRow = WorkforceUnregisteredRowScene.instantiate()
	row.setup(resident)
	row.action_requested.connect(register_requested.emit.bind(resident.citizen))
	list.add_child(row)
