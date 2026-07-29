class_name GameRuntime
extends Node3D

## Generic session root. Modules attach their own session presentation below this
## node; it deliberately owns no settlement scene, UI or gameplay state.

var active_session: GameSessionConfig = null
var session_content: Node = null
## Created by core.world before any gameplay module starts. It owns the map
## session and the single WorldSetup projection for the active scene host.
var world_session: WorldSession = null


func _ready() -> void:
	var launch_manager := get_node_or_null("/root/GameLaunchManager")
	var session: GameSessionConfig = launch_manager.get("active_session") as GameSessionConfig if launch_manager != null else null
	if session == null:
		push_error("[launch] GameRuntime requires an active game session")
		return
	if not SessionBootstrapper.new().run(self, session):
		return
	_restore_pending_save()


func attach_session_content(node: Node) -> void:
	if node == null:
		return
	if session_content != null:
		push_error("[launch] session content is already attached")
		return
	session_content = node
	add_child(node)


func _restore_pending_save() -> void:
	var launch_manager := get_node_or_null("/root/GameLaunchManager")
	if launch_manager == null:
		return
	var path := String(launch_manager.get("pending_save_path"))
	if path.is_empty():
		return
	if SessionSaveCoordinator.load_pending(self, path):
		launch_manager.set("pending_save_path", "")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F5 and event.pressed and not event.echo:
		if SessionSaveCoordinator.save_quicksave(self):
			print("[save] quicksave written")
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		var launch_manager := get_node_or_null("/root/GameLaunchManager")
		if launch_manager != null and launch_manager.has_method("return_to_main_menu"):
			launch_manager.call("return_to_main_menu")
			get_viewport().set_input_as_handled()
