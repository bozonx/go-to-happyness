class_name WorldShowcase
extends Node3D

const WorldSetupScene = preload("res://game/features/world/presentation/world_setup.tscn")
const CELL_SIZE := 2.0

@onready var camera_controller: CameraController = $CameraController
var world_setup: WorldSetup = null


func start_session(session: GameSessionConfig) -> bool:
	if session == null or session.map_document == null:
		push_error("[launch] World Showcase requires a map")
		return false
	world_setup = WorldSetupScene.instantiate() as WorldSetup
	world_setup.setup(
		camera_controller.camera,
		CELL_SIZE,
		session.map_document.board_cells(),
		null,
		session.map_document,
	)
	add_child(world_setup)
	world_setup.build(self)
	return world_setup.terrain_grid != null and world_setup.water_grid != null


func _process(delta: float) -> void:
	if camera_controller != null:
		camera_controller.update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		camera_controller.pan(event.relative)
		get_viewport().set_input_as_handled()
