class_name PocketTakeMenu
extends Panel

signal close_requested

@onready var title_label: Label = $TitleLabel
@onready var item_list: VBoxContainer = $ScrollContainer/ItemList
@onready var close_button: Button = $CloseButton


func _ready() -> void:
	close_button.pressed.connect(func(): close_requested.emit())


func clear_items() -> void:
	for child in item_list.get_children():
		child.queue_free()
