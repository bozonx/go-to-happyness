class_name WorldShowcaseModule
extends GameModule

const WorldShowcaseScene = preload("res://game/features/runtime/presentation/world_showcase.tscn")

func module_id() -> StringName:
	return &"gth.world_showcase"


func required_modules() -> Array[StringName]:
	return [&"core.world"]


func start(runtime: GameRuntime, session: GameSessionConfig) -> bool:
	var showcase := WorldShowcaseScene.instantiate() as WorldShowcase
	if showcase == null:
		push_error("[launch] failed to instantiate world showcase")
		return false
	showcase.world_session = runtime.world_session
	runtime.attach_session_content(showcase)
	return showcase.start_session(session)


func save_state(runtime: GameRuntime) -> Dictionary:
	var showcase := runtime.session_content as WorldShowcase
	return showcase.save_session_state() if showcase != null else {}


func restore_state(runtime: GameRuntime, state: Dictionary) -> bool:
	var showcase := runtime.session_content as WorldShowcase
	if showcase == null:
		return false
	showcase.restore_session_state(state)
	return true
