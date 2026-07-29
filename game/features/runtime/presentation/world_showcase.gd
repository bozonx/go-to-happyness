class_name WorldShowcase
extends Node3D

const CELL_SIZE := 2.0

@onready var camera_controller: CameraController = $CameraController
var world_setup: WorldSetup = null
var world_session: WorldSession = null


func start_session(session: GameSessionConfig) -> bool:
	if session == null or session.map_document == null:
		push_error("[launch] World Showcase requires a map")
		return false
	var active_world_session := world_session if world_session != null else WorldSession.new(session.map_document)
	world_setup = active_world_session.build(self, camera_controller.camera, CELL_SIZE, session.map_document.board_cells())
	return world_setup.terrain_grid != null and world_setup.water_grid != null


func _process(delta: float) -> void:
	if camera_controller != null:
		camera_controller.update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		camera_controller.pan(event.relative)
		get_viewport().set_input_as_handled()


func save_session_state() -> Dictionary:
	return {
		"module": "gth.world_showcase",
		"state": {
			"camera": {
				"target": SaveData.vector3_to_dict(camera_controller.camera_target),
				"distance": camera_controller.camera_distance,
				"yaw": camera_controller.camera_yaw,
				"pitch": camera_controller.camera_pitch,
			},
		},
	}


func restore_session_state(save_data: SaveData) -> void:
	var section: Variant = save_data.module_states.get("gth.world_showcase", {})
	if not section is Dictionary:
		return
	var camera_state: Variant = (section as Dictionary).get("camera", {})
	if not camera_state is Dictionary:
		return
	var state := camera_state as Dictionary
	var target: Variant = state.get("target", {})
	if target is Dictionary:
		camera_controller.camera_target = SaveData.dict_to_vector3(target as Dictionary)
	camera_controller.camera_distance = float(state.get("distance", camera_controller.camera_distance))
	camera_controller.camera_yaw = float(state.get("yaw", camera_controller.camera_yaw))
	camera_controller.camera_pitch = float(state.get("pitch", camera_controller.camera_pitch))
	camera_controller.apply_position()
