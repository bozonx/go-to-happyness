class_name WorkforceMenu
extends Panel

signal close_requested
signal dismiss_requested(role: String)
signal assign_requested(role: String)
signal register_requested(citizen: Citizen)

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
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(424, 38)
	var label := Label.new()
	label.text = job.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var dismiss := Button.new()
	dismiss.text = "Dismiss"
	dismiss.tooltip_text = job.dismiss_tooltip
	dismiss.custom_minimum_size = Vector2(78, 34)
	dismiss.disabled = job.dismiss_disabled
	dismiss.pressed.connect(dismiss_requested.emit.bind(job.role))
	row.add_child(dismiss)
	var assign := Button.new()
	assign.text = "Assign"
	assign.tooltip_text = job.assign_tooltip
	assign.custom_minimum_size = Vector2(72, 34)
	assign.disabled = job.assign_disabled
	assign.pressed.connect(assign_requested.emit.bind(job.role))
	row.add_child(assign)
	list.add_child(row)


func _add_unregistered_resident_row(resident: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(424, 34)
	var label := Label.new()
	label.text = resident.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var auto_button := Button.new()
	auto_button.text = resident.button_text
	auto_button.tooltip_text = resident.tooltip
	auto_button.custom_minimum_size = Vector2(72, 30)
	auto_button.disabled = resident.disabled
	auto_button.pressed.connect(register_requested.emit.bind(resident.citizen))
	row.add_child(auto_button)
	list.add_child(row)
