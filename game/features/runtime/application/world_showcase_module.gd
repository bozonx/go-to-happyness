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
	if showcase == null:
		return {}
	var contribution := showcase.save_session_state()
	return contribution.get("state", {}) as Dictionary


func restore_state(runtime: GameRuntime, state: Dictionary) -> bool:
	var showcase := runtime.session_content as WorldShowcase
	if showcase == null:
		return false
	var save_data := SaveData.new()
	save_data.module_states[module_id()] = state.duplicate(true)
	showcase.restore_session_state(save_data)
	return true
