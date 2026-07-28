class_name GameRuntime
extends SettlementGame

## Generic session root. It temporarily inherits the settlement scene behaviour
## so the migration does not alter gameplay; the selected module is nevertheless
## the sole caller that starts settlement logic.

var active_session: GameSessionConfig = null


func _ready() -> void:
	var launch_manager := get_node_or_null("/root/GameLaunchManager")
	var session: GameSessionConfig = launch_manager.get("active_session") as GameSessionConfig if launch_manager != null else null
	if session == null:
		push_error("[launch] GameRuntime requires an active game session")
		return
	SessionBootstrapper.new().run(self, session)
