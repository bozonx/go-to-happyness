class_name WorldShowcase
extends Node3D

const CELL_SIZE := 2.0

@onready var camera_controller: CameraController = $CameraController
@onready var editor_hint: Label = $EditorHintLayer/EditorHint
var world_setup: WorldSetup = null
var world_session: WorldSession = null


func start_session(session: GameSessionConfig) -> bool:
	if session == null or session.map_document == null:
		push_error("[launch] World Showcase requires a map")
		return false
	var active_world_session := world_session if world_session != null else WorldSession.new(session.map_document)
	world_setup = active_world_session.build(self, camera_controller.camera, CELL_SIZE, session.map_document.board_cells())
	_update_editor_hint()
	return world_setup.terrain_grid != null and world_setup.water_grid != null


## The hint is only relevant for a test run from an editor; a Showcase launched
## from the library has nowhere to return to. It reads the same flag
## `HostInputController` uses to route `Esc` back into the editor.
func _update_editor_hint() -> void:
	if editor_hint == null:
		return
	var launch_manager := get_node_or_null("/root/GameLaunchManager")
	editor_hint.visible = launch_manager != null \
		and not String(launch_manager.get("editor_return_scene")).is_empty()


func _process(delta: float) -> void:
	if camera_controller != null:
		camera_controller.update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		camera_controller.pan(event.relative)
		get_viewport().set_input_as_handled()


## The module's save section: camera only. The host wraps it with the section
## version and the game/map headers.
func save_session_state() -> Dictionary:
	return {
		"camera": {
			"target": SaveData.vector3_to_dict(camera_controller.camera_target),
			"distance": camera_controller.camera_distance,
			"yaw": camera_controller.camera_yaw,
			"pitch": camera_controller.camera_pitch,
		},
	}


func restore_session_state(section: Dictionary) -> void:
	var camera_state: Variant = section.get("camera", {})
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
