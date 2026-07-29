class_name CoreWorldModule
extends GameModule

## The common map contract. Presentation stays with the game that consumes it;
## this module proves that every game validates the same authored world before
## its own startup code runs.

func module_id() -> StringName:
	return &"core.world"


func validate_session(session: GameSessionConfig) -> Array[String]:
	var errors: Array[String] = []
	if session.map_document == null or session.map_ref.is_empty():
		errors.append("требуется разрешённая карта")
		return errors
	errors.append_array(MapValidator.validate(
		session.map_document,
		session.map_document.terrain,
		session.map_document.water,
		null,
	))
	return errors


func start(_runtime: GameRuntime, session: GameSessionConfig) -> bool:
	if session.map_document == null or session.map_ref.is_empty():
		push_error("[launch] core.world requires a resolved map")
		return false
	_runtime.world_session = WorldSession.new(session.map_document)
	return true
