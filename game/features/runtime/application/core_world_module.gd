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
	errors.append_array(EnvironmentContentLoader.register_all())
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
	var start := session.map_document.meta.start
	if not ClimateCatalog.has_profile(start.climate):
		errors.append("неизвестный климат %s" % start.climate)
	if not WeatherPatternCatalog.has_pattern(start.weather_preset):
		errors.append("неизвестный погодный паттерн %s" % start.weather_preset)
	errors.append_array(session.map_document.meta.start.progression.validate(
		session.definition.progression.era_ids() if session.definition != null else []))
	return errors


func start(runtime: GameRuntime, session: GameSessionConfig) -> bool:
	if session.map_document == null or session.map_ref.is_empty():
		push_error("[launch] core.world requires a resolved map")
		return false
	runtime.world_session = WorldSession.new(
		session.map_document, WorldSession.DEFAULT_CELL_SIZE,
		session.start_option, session.start_flags(), session.seed)
	return true


func stop(runtime: GameRuntime) -> void:
	if runtime != null and runtime.world_session != null:
		runtime.world_session.dispose()
		runtime.world_session = null


## Bumped with the environment section (`world_environment.md` §16). A save
## written before it restores with a default environment rather than being
## refused: a world with no recorded calendar is an old world, not a broken one.
func section_version() -> int:
	return 3


func migrate_section(from_version: int, state: Dictionary) -> Dictionary:
	if from_version < 1 or from_version > 2:
		return {}
	var migrated := state.duplicate(true)
	if from_version == 1:
		migrated["environment"] = {}
		migrated["accumulation"] = {}
	migrated["terrain_surface"] = ""
	migrated["water_ice"] = ""
	return migrated


func save_state(runtime: GameRuntime) -> Dictionary:
	if runtime == null or runtime.world_session == null:
		return {}
	var session := runtime.world_session
	return {
		"entities": session.entity_runtime.lifecycle_snapshot(),
		# Only what does not follow from time: calendar, seed, the rolled pattern
		# and the director's override. Cloud and wind strength are recomputed;
		# integrated displacement keeps only its continuity origin (§16).
		"environment": session.environment.save_state(),
		# Snow depth and ice live in their own layers; this is only where the
		# sweep had got to, so a reload does not restart it from one corner.
		"accumulation": session.environment_accumulation.save_state(),
		"terrain_surface": TerrainSurfaceCodec.to_base64(
			session.world_setup.terrain_grid if session.world_setup != null else null),
		"water_ice": WaterIceCodec.to_base64(
			session.world_setup.water_grid if session.world_setup != null else null),
	}


func restore_state(runtime: GameRuntime, state: Dictionary) -> bool:
	if runtime == null or runtime.world_session == null:
		return false
	var entities: Variant = state.get("entities", {})
	if not (entities is Dictionary):
		return false
	var session := runtime.world_session
	var environment: Variant = state.get("environment", {})
	if environment is Dictionary and not (environment as Dictionary).is_empty():
		if not session.environment.restore_state(environment as Dictionary):
			return false
	if session.world_setup != null:
		var surface := String(state.get("terrain_surface", ""))
		if not surface.is_empty() and not TerrainSurfaceCodec.from_base64(
			surface, session.world_setup.terrain_grid):
			return false
		var ice := String(state.get("water_ice", ""))
		if not ice.is_empty() and not WaterIceCodec.from_base64(
			ice, session.world_setup.water_service):
			return false
	runtime.world_session.entity_runtime.restore_lifecycle(entities as Dictionary)
	if runtime.world_session.world_setup != null:
		# Surface decode is a validated bulk overlay, not an editor transaction. One
		# full publish makes snow/ice weights current without rebuilding services or
		# erasing their restored progress/road state.
		runtime.world_session.terrain_navigation_publisher.publish_all()
		runtime.world_session.nav_grid.set_blocked_cells(
			runtime.world_session.base_navigation_blocked_cells())
		runtime.world_session.nav_grid.refresh_connectivity()
		runtime.world_session.present_environment()
	var accumulation: Variant = state.get("accumulation", {})
	if accumulation is Dictionary:
		session.environment_accumulation.restore_state(accumulation as Dictionary)
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
