class_name ResearchMenu
extends Panel

signal close_requested
signal start_requested(tech_id: String)
signal cancel_requested

const ResearchItemRowScene = preload("res://game/features/settlement/presentation/research_item_row.tscn")

@onready var title_label: Label = $TitleLabel
@onready var research_list: VBoxContainer = $ScrollContainer/ResearchList


func _ready() -> void:
	$CloseButton.pressed.connect(func(): close_requested.emit())


func update_state(state: Dictionary) -> void:
	title_label.text = state.title_text
	for child in research_list.get_children():
		child.queue_free()

	for item in state.tech_rows:
		var row: ResearchItemRow = ResearchItemRowScene.instantiate()
		row.setup(item)
		row.start_requested.connect(start_requested.emit.bind(item.tech_id))
		row.cancel_requested.connect(func(): cancel_requested.emit())
		research_list.add_child(row)
