class_name WorldShowcaseModule
extends GameModule

const WorldShowcaseScene = preload("res://game/features/runtime/presentation/world_showcase.tscn")

func module_id() -> StringName:
	return &"gth.world_showcase"


func start(runtime: GameRuntime, session: GameSessionConfig) -> bool:
	var showcase := WorldShowcaseScene.instantiate() as WorldShowcase
	if showcase == null:
		push_error("[launch] failed to instantiate world showcase")
		return false
	runtime.attach_session_content(showcase)
	return showcase.start_session(session)
