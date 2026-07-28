class_name CoreWorldModule
extends GameModule

## The common map contract. Presentation stays with the game that consumes it;
## this module proves that every game validates the same authored world before
## its own startup code runs.

func module_id() -> StringName:
	return &"core.world"


func start(_runtime: GameRuntime, session: GameSessionConfig) -> bool:
	if session.map_document == null or session.map_ref.is_empty():
		push_error("[launch] core.world requires a resolved map")
		return false
	var errors := MapValidator.validate(
		session.map_document,
		session.map_document.terrain,
		session.map_document.water,
		null,
	)
	if not errors.is_empty():
		push_error("[launch] invalid world map: %s" % "; ".join(errors))
		return false
	return true
