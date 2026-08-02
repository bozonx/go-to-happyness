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


## Parameters this module accepts in `start.modules[<id>]`. The launch screen, the
## game editor and the map editor's start section all build their controls from
## this list, which is why none of them contains a module-specific widget.
##
## It is `EntityPropertyDef` — the same schema a placed object's properties use
## (`map_start.md` §2.6). The separate `StartParameterDef` that used to be here
## described the same four control types more poorly and had three independently
## written control builders, so every new kind of parameter cost three edits in
## three screens and the map editor got it last.
func start_parameters() -> Array[EntityPropertyDef]:
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
	for parameter: EntityPropertyDef in start_parameters():
		resolved[parameter.name] = parameter.clamp_value(
			supplied.get(parameter.name, parameter.default))
	for key: Variant in supplied:
		if not resolved.has(key):
			resolved[key] = supplied[key]
	return resolved
