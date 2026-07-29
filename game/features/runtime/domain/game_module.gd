class_name GameModule
extends RefCounted

## Built-in module contract. User packs select registered modules but never load
## arbitrary GDScript. A module owns its startup validation and its one save
## section; the host never asks a presentation node to serialize itself.

func api_version() -> int:
	return 1


func required_modules() -> Array[StringName]:
	return []

func module_id() -> StringName:
	return &""


func validate_session(_session: GameSessionConfig) -> Array[String]:
	return []


func start(_runtime: GameRuntime, _session: GameSessionConfig) -> bool:
	return false


func stop(_runtime: GameRuntime) -> void:
	pass


func save_state(_runtime: GameRuntime) -> Dictionary:
	return {}


func restore_state(_runtime: GameRuntime, _state: Dictionary) -> bool:
	return true
