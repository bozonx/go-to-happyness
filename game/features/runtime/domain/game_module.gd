class_name GameModule
extends RefCounted

## Built-in module contract. User packs select registered modules but never load
## arbitrary GDScript; a module owns its game state and startup validation.

func module_id() -> StringName:
	return &""


func start(_runtime: GameRuntime, _session: GameSessionConfig) -> bool:
	return false
