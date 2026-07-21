class_name HouseMenu
extends Panel

signal spawn_requested
signal demolish_requested

@onready var title_label: Label = $TitleLabel
@onready var spawn_button: Button = $SpawnButton
@onready var demolish_button: Button = $DemolishButton


func _ready() -> void:
	if spawn_button != null:
		spawn_button.pressed.connect(func(): spawn_requested.emit())
	if demolish_button != null:
		demolish_button.pressed.connect(func(): demolish_requested.emit())
