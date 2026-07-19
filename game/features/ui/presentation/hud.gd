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
