class_name GameModule
extends RefCounted

## Built-in module contract. User packs select registered modules but never load
## arbitrary GDScript. A module owns its startup validation, the parameters it
## accepts and its one save section; the host never asks a presentation node to
## serialize itself.

func api_version() -> int:
	return 1


func required_modules() -> Array[StringName]:
	return []


func module_id() -> StringName:
	return &""


## Parameters this module accepts in `start.modules[<id>]`. The launch screen and
## the game editor build their controls from this list, which is why neither of
## them contains a module-specific widget.
func start_parameters() -> Array[StartParameterDef]:
	return []


## Schema version of this module's save section. Bump it in the same change that
## alters the section's shape, and handle the old shape in `migrate_section`.
func section_version() -> int:
	return 1


## Converts a section written by an older `section_version` into the current one.
## The default refuses: an empty result tells the coordinator to reject the save
## with a readable message instead of restoring a half-understood world.
func migrate_section(_from_version: int, _state: Dictionary) -> Dictionary:
	return {}


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


## Applies declared defaults to whatever the definition, map and session supplied.
## Modules call this instead of repeating `parameters.get(key, fallback)`.
func resolve_parameters(supplied: Dictionary) -> Dictionary:
	var resolved: Dictionary = {}
	for parameter: StartParameterDef in start_parameters():
		resolved[parameter.id] = parameter.coerce(supplied.get(parameter.id, parameter.default_value))
	for key: Variant in supplied:
		if not resolved.has(key):
			resolved[key] = supplied[key]
	return resolved
