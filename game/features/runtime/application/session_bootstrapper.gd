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
	var pending := modules.duplicate()
	var started: Array[GameModule] = []
	while not pending.is_empty():
		var started_this_pass := false
		for index in range(pending.size()):
			var module: GameModule = pending[index]
			if not _dependencies_started(module, started):
				continue
			runtime.register_module(module)
			started.append(module)
			pending.remove_at(index)
			started_this_pass = true
			if not module.start(runtime, session):
				push_error("[launch] failed to start module: %s" % module.module_id())
				_rollback(runtime, started)
				return false
			break
		if not started_this_pass:
			push_error("[launch] module dependency cycle")
			_rollback(runtime, started)
			return false
	return true


func _dependencies_started(module: GameModule, started: Array[GameModule]) -> bool:
	for dependency: StringName in module.required_modules():
		if not started.any(func(candidate: GameModule) -> bool: return candidate.module_id() == dependency):
			return false
	return true


func _rollback(runtime: GameRuntime, started: Array[GameModule]) -> void:
	started.reverse()
	for module: GameModule in started:
		module.stop(runtime)
	runtime.abort_session()
