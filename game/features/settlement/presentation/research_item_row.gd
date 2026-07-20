class_name ResearchItemRow
extends HBoxContainer

signal start_requested
signal cancel_requested

@onready var title_label: Label = $DetailsVBox/TitleLabel
@onready var desc_label: Label = $DetailsVBox/DescLabel
@onready var status_label: Label = $StatusLabel
@onready var progress_vbox: VBoxContainer = $ProgressVBox
@onready var progress_label: Label = $ProgressVBox/ProgressLabel
@onready var cancel_button: Button = $ProgressVBox/CancelButton
@onready var start_button: Button = $StartButton

var _data: Dictionary


func setup(item_data: Dictionary) -> void:
	_data = item_data
	if is_node_ready():
		_apply_data()


func _ready() -> void:
	cancel_button.pressed.connect(func(): cancel_requested.emit())
	start_button.pressed.connect(func(): start_requested.emit())
	if not _data.is_empty():
		_apply_data()


func _apply_data() -> void:
	title_label.text = _data.title
	desc_label.text = _data.description

	status_label.visible = false
	progress_vbox.visible = false
	start_button.visible = false

	if _data.completed:
		status_label.text = "Researched"
		status_label.visible = true
	elif _data.active:
		progress_label.text = "Researching: %d%%" % int(_data.progress_pct)
		progress_vbox.visible = true
	else:
		start_button.disabled = not _data.can_start
		start_button.tooltip_text = _data.tooltip
		start_button.visible = true
