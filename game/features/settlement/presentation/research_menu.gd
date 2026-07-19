class_name ResearchMenu
extends Panel

signal close_requested

@onready var title_label: Label = $TitleLabel
@onready var research_list: VBoxContainer = $ScrollContainer/ResearchList


func _ready() -> void:
	$CloseButton.pressed.connect(func(): close_requested.emit())
