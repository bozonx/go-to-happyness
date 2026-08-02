class_name CoreWorldModule
extends GameModule

## The common map contract. Presentation stays with the game that consumes it;
## this module proves that every game validates the same authored world before
## its own startup code runs — including that the content the map references is
## actually installed.

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
	errors.append_array(_missing_required_content(session.map_document))
	errors.append_array(_missing_pack_dependencies(session))
	errors.append_array(session.map_document.meta.start.progression.validate(
		session.definition.progression.era_ids() if session.definition != null else []))
	return errors


func start(runtime: GameRuntime, session: GameSessionConfig) -> bool:
	if session.map_document == null or session.map_ref.is_empty():
		push_error("[launch] core.world requires a resolved map")
		return false
	runtime.world_session = WorldSession.new(
		session.map_document, WorldSession.DEFAULT_CELL_SIZE,
		session.start_option, session.start_flags())
	return true


func stop(runtime: GameRuntime) -> void:
	if runtime != null and runtime.world_session != null:
		runtime.world_session.dispose()
		runtime.world_session = null


func save_state(runtime: GameRuntime) -> Dictionary:
	if runtime == null or runtime.world_session == null:
		return {}
	return {"entities": runtime.world_session.entity_runtime.lifecycle_snapshot()}


func restore_state(runtime: GameRuntime, state: Dictionary) -> bool:
	if runtime == null or runtime.world_session == null:
		return false
	var entities: Variant = state.get("entities", {})
	if not (entities is Dictionary):
		return false
	runtime.world_session.entity_runtime.restore_lifecycle(entities as Dictionary)
	if runtime.world_session.world_setup != null:
		runtime.world_session.nav_grid.set_blocked_cells(runtime.world_session.entity_navigation_blocked_cells())
		runtime.world_session.nav_grid.refresh_connectivity()
	return true


## A map lists the blueprints, archetypes and assets it embeds
## (`content_packaging.md` §13). Starting without them produces a world with
## holes in it, which reads as a broken game rather than as missing content, so
## the session refuses and names what is absent.
static func _missing_required_content(document: MapDocument) -> Array[String]:
	var problems: Array[String] = []
	var index := ContentIndex.shared()
	for reference: Dictionary in document.meta.required_content:
		var id := StringName(reference.get("id", ""))
		if id.is_empty():
			continue
		match StringName(reference.get("kind", "blueprint")):
			&"archetype":
				if not EntityArchetypeCatalog.has_archetype(id):
					problems.append("не найден архетип %s" % id)
			&"asset":
				if not WorldAssetCatalog.has_asset(id):
					problems.append("не найден ассет %s" % id)
			_:
				var key := ContentId.runtime_key(StringName(reference.get("source", "core")), id)
				if index.get_entry(key) == null:
					problems.append("не найден чертёж %s" % key)
	return problems


## Pack-level dependencies of the game being launched (`pack.json` → `requires`).
## The map check above catches what one map embeds; this catches a pack that was
## installed without the library pack it builds on.
static func _missing_pack_dependencies(session: GameSessionConfig) -> Array[String]:
	if session.definition == null or session.definition.runtime_key.is_empty():
		return []
	var address := ContentId.split_runtime_key(session.definition.runtime_key)
	return ContentIndex.shared().missing_requirements(address["source"])
