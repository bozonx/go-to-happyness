class_name SettlementGameModule
extends GameModule

## Transitional settlement module. It owns selection of the existing settlement
## bootstrap while that bootstrap is incrementally extracted from SettlementGame.

func module_id() -> StringName:
	return &"gth.settlement"


func start(runtime: GameRuntime, session: GameSessionConfig) -> bool:
	if session.legacy_settlement_launch == null:
		push_error("[launch] settlement module requires settlement start parameters")
		return false
	runtime.start_settlement_session(session.legacy_settlement_launch)
	return runtime.world_setup != null
