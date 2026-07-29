class_name GameRuntime
extends Node3D

## Generic session root. Modules attach their own session presentation below this
## node; it deliberately owns no settlement scene, UI or gameplay state.

var active_session: GameSessionConfig = null
var active_modules: Dictionary = {}
var session_content: Node = null
## Created by core.world before any gameplay module starts. It owns the map
## session and the single WorldSetup projection for the active scene host.
var world_session: WorldSession = null
var host_input := HostInputController.new()


func _ready() -> void:
	var launch_manager := get_node_or_null("/root/GameLaunchManager")
	var session: GameSessionConfig = launch_manager.get("active_session") as GameSessionConfig if launch_manager != null else null
	if session == null:
		push_error("[launch] GameRuntime requires an active game session")
		return
	if not SessionBootstrapper.new().run(self, session):
		return
	host_input.configure(session.definition.input_profile)
	_restore_pending_save()


func attach_session_content(node: Node) -> void:
	if node == null:
		return
	if session_content != null:
		push_error("[launch] session content is already attached")
		return
	session_content = node
	add_child(node)


func register_module(module: GameModule) -> void:
	if module != null:
		active_modules[module.module_id()] = module


func _exit_tree() -> void:
	var module_ids: Array = active_modules.keys()
	module_ids.reverse()
	for module_id: StringName in module_ids:
		var module: GameModule = active_modules[module_id]
		module.stop(self)
	active_modules.clear()


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
	if host_input.handle_unhandled_input(event, self):
		get_viewport().set_input_as_handled()
