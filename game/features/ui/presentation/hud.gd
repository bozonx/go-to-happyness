class_name HUD
extends Control

signal build_toggle_pressed

@onready var wood_label: Label = $ResourcesPanel/WoodLabel
@onready var clock_label: Label = $ClockLabel
@onready var camera_hint_label: Label = $CameraHintLabel
@onready var build_toggle_btn: Button = $BuildToggleButton
@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	build_toggle_btn.pressed.connect(func(): build_toggle_pressed.emit())


func update_resources(text: String) -> void:
	wood_label.text = text


func update_clock(text: String) -> void:
	clock_label.text = text


func update_camera_hint(text: String) -> void:
	camera_hint_label.text = text


func set_status(text: String) -> void:
	status_label.text = text


func set_status_visible(vis: bool) -> void:
	status_label.visible = vis
