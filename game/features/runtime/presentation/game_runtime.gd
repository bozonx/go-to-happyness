class_name GameRuntime
extends Node3D

## Generic session root. Modules attach their own session presentation below this
## node; it deliberately owns no settlement scene, UI or gameplay state.

var active_session: GameSessionConfig = null
var session_content: Node = null


func _ready() -> void:
	var launch_manager := get_node_or_null("/root/GameLaunchManager")
	var session: GameSessionConfig = launch_manager.get("active_session") as GameSessionConfig if launch_manager != null else null
	if session == null:
		push_error("[launch] GameRuntime requires an active game session")
		return
	SessionBootstrapper.new().run(self, session)


func attach_session_content(node: Node) -> void:
	if node == null:
		return
	if session_content != null:
		push_error("[launch] session content is already attached")
		return
	session_content = node
	add_child(node)
