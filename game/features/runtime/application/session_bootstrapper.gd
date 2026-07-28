class_name SessionBootstrapper
extends RefCounted

## Validates and composes a session through registered modules. The first
## migration deliberately has one module; the ordering contract is here before
## additional modules arrive, so launch never again depends on a game scene.

func run(runtime: GameRuntime, session: GameSessionConfig) -> bool:
	if session == null or session.definition == null:
		push_error("[launch] game session has no definition")
		return false
	if session.map_document == null:
		push_error("[launch] game session requires a resolved map document")
		return false
	runtime.active_session = session
	for module_id: StringName in session.definition.module_ids:
		var module := GameModuleRegistry.create_module(module_id)
		if module == null or not module.start(runtime, session):
			push_error("[launch] failed to start module: %s" % module_id)
			return false
	return true
