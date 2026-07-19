class_name WorkforceMenu
extends Panel

signal close_requested

@onready var title_label: Label = $TitleLabel
@onready var list: VBoxContainer = $ScrollContainer/List


func _ready() -> void:
	$CloseButton.pressed.connect(func(): close_requested.emit())
