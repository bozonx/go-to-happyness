class_name SessionBootstrapper
extends RefCounted

## Validates and composes a session through registered modules. The first
## Validates every module before any scene is attached. This prevents a broken
## pack from half-starting a game and makes module dependencies explicit.

func run(runtime: GameRuntime, session: GameSessionConfig) -> bool:
	if session == null or session.definition == null:
		push_error("[launch] game session has no definition")
		return false
	if session.map_document == null:
		push_error("[launch] game session requires a resolved map document")
		return false
	var definition_errors := GameModuleRegistry.validate_definition(session.definition)
	if not definition_errors.is_empty():
		push_error("[launch] invalid game definition: %s" % "; ".join(definition_errors))
		return false
	if not HostInputProfile.is_supported(session.definition.input_profile):
		push_error("[launch] unsupported host input profile: %s" % session.definition.input_profile)
		return false
	var modules: Array[GameModule] = []
	var selected: Dictionary = {}
	for module_id: StringName in session.definition.module_ids:
		if selected.has(module_id):
			push_error("[launch] duplicate module: %s" % module_id)
			return false
		var module := GameModuleRegistry.create_module(module_id)
		if module == null:
			return false
		selected[module_id] = true
		modules.append(module)
	for module: GameModule in modules:
		for dependency: StringName in module.required_modules():
			if not selected.has(dependency):
				push_error("[launch] module %s requires %s" % [module.module_id(), dependency])
				return false
		var errors := module.validate_session(session)
		if not errors.is_empty():
			push_error("[launch] invalid %s parameters: %s" % [module.module_id(), "; ".join(errors)])
			return false
	runtime.active_session = session
	for module: GameModule in modules:
		if not module.start(runtime, session):
			push_error("[launch] failed to start module: %s" % module.module_id())
			return false
		runtime.register_module(module)
	return true
