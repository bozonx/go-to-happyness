class_name WorldSession
extends RefCounted

## Runtime-owned projection of one authored map. A game supplies the scene host
## (territory/camera), but the session guarantees that terrain, water and map
## entities are built once from the same map document for every module.

const WorldSetupScene = preload("res://game/features/world/presentation/world_setup.tscn")
const DEFAULT_CELL_SIZE := 2.0

var map_document: MapDocument
var world_setup: WorldSetup = null
var nav_grid := NavGrid.new()
var terrain_navigation_publisher := TerrainNavigationPublisher.new()
## Built coverage of the launched map, published into routing (map_editor.md
## §5.2.3). The session owns the service so the map seeds it exactly once and
## everything afterwards — construction, demolition, a save being restored — goes
## through that one write-owner instead of a second copy per game.
var road_network := RoadNetworkService.new()
var coverage_navigation_publisher := CoverageNavigationPublisher.new()
## Stable map-entity identity and lifecycle are session data, not presentation
## metadata. WorldSetup merely projects this instance into the territory.
var entity_runtime := MapEntityRuntime.new()
## A game module with additional dynamic obstacles installs its one publisher
## here. Games without one use the base entity layer directly.
var obstacle_refresh_callback: Callable
var cell_size := DEFAULT_CELL_SIZE
## The one zone event bus of the session (`active_zones.md` §14). It lives here
## rather than in a game's bootstrapper because the scenario layer below listens
## to it, and a rule table that worked in only one game would not be an engine
## feature. A game builds its presence tracker and zone registry against this
## bus instead of creating a second one.
var zone_event_bus := ZoneEventBus.new()
## The authored scenario, running (map_editor.md §10). Present for every game:
## flags, rules and win/lose conditions are host functionality, and a map that
## carries none simply has an idle runtime.
var scenario_runtime := MapScenarioRuntime.new()
## The entrance the session began at (`map_start.md` §3). It reaches the world
## because entities may be bound to one, and because a start option's initial
## flags are the first thing the scenario sees.
var start_option: StringName = &""
## Time, calendar, season, temperature and weather of this session
## (`world_environment.md` §2, §18). It lives here rather than in a game because
## every game on the engine has a sky and a clock, and because a cutscene or a
## map rule must reach the environment without knowing which game is running.
##
## **One snapshot out, one director in.** Consumers read `environment.snapshot()`;
## everything that changes the environment goes through the director.
var environment := EnvironmentDirector.new()
## Snow lying on the ground and ice on the water (§13). The environment commands
## it; the terrain and water layers own the data.
var environment_accumulation := EnvironmentAccumulationService.new()
## The environment's actions, flags and moments inside the map scenario (§14).
var environment_scenario := EnvironmentScenarioVocabulary.new()
## Сезонные состояния сущностей карты (`map_fill_mode.md` §6.1). Живёт здесь по
## той же причине, что и директор окружения: сезон есть у мира, а не у игры.
var seasonal_entities := SeasonalEntityService.new()
## Components the attached game module executes itself, declared before `build`.
## Entities carrying one of them are the module's to instantiate, so the generic
## presenter leaves them alone — otherwise a creature exists twice, once inert.
## Empty means "no module claimed anything": every entity gets its generic view.
var claimed_entity_components: Array[StringName] = []


func _init(
	p_map_document: MapDocument = null,
	p_cell_size := DEFAULT_CELL_SIZE,
	p_start_option: StringName = &"",
	p_start_flags: Dictionary = {},
	p_seed := 0,
) -> void:
	map_document = p_map_document
	start_option = p_start_option
	cell_size = p_cell_size
	if map_document != null:
		nav_grid.configure(cell_size, map_document.board_cells())
		scenario_runtime.configure(map_document.scenario, p_start_flags)
	_configure_environment(p_seed)
	# Wired at construction, like the zone bus below: an author's rule that sets
	# the hour must work in every game, not only in the one whose bootstrapper
	# remembered to connect it.
	environment_scenario.install(environment, scenario_runtime)
	environment.time_jumped.connect(_on_time_jumped)
	# Presence reaches the rule table the moment the tracker publishes it. Wired
	# at construction so no game has to remember to connect it — forgetting would
	# leave zone triggers silently dead in exactly one game.
	zone_event_bus.configure({
		"area_entered": scenario_runtime.handle_zone_event,
		"area_exited": scenario_runtime.handle_zone_event,
	})


func build(
	scene_host: Node,
	camera: Camera3D,
	cell_size: float,
	board_cells: int,
	trail_field: RefCounted = null,
) -> WorldSetup:
	if world_setup != null:
		return world_setup
	if scene_host == null or camera == null or map_document == null:
		push_error("[world] session requires scene host, camera and map")
		return null
	world_setup = WorldSetupScene.instantiate() as WorldSetup
	world_setup.setup(
		camera, cell_size, board_cells, trail_field, map_document, start_option,
		claimed_entity_components,
	)
	scene_host.add_child(world_setup)
	world_setup.build(scene_host)
	entity_runtime = world_setup.map_entity_runtime
	if not entity_runtime.entity_changed.is_connected(_on_entity_changed):
		entity_runtime.entity_changed.connect(_on_entity_changed)
	# Лес, расставленный летом, обязан пожелтеть в октябре сам (§6.1). Подключается
	# здесь, а не в игре: сезон принадлежит миру, и карта, запущенная любым
	# модулем, стареет одинаково.
	seasonal_entities.configure(entity_runtime, environment)
	publish_navigation()
	return world_setup


## The environment starts from the values the session resolved (§15). It reads
## them off the document here rather than anywhere deeper, because the order that
## produces them belongs to `map_start.md` §7 and the environment gets answers.
func _configure_environment(p_seed: int) -> void:
	var start := map_document.meta.start if map_document != null else MapStart.new()
	environment.configure(
		start.climate,
		start.day_of_year,
		start.time_of_day,
		start.latitude,
		start.weather_preset,
		p_seed,
		start.dynamic,
	)


## Skipping a night does not skip the snow that fell during it (§13.1).
func _on_time_jumped(samples: Array[Dictionary]) -> void:
	environment_accumulation.catch_up_samples(samples, environment.snapshot())


## Advances the environment and everything it drives. One call per frame from the
## host: nothing downstream advances time, it only reads the snapshot.
func tick_environment(delta: float) -> void:
	environment.tick(delta)
	var current := environment.snapshot()
	environment_accumulation.tick(current)
	environment_scenario.publish_state(current)


func publish_navigation() -> void:
	if world_setup == null or world_setup.terrain_grid == null or world_setup.water_grid == null:
		return
	terrain_navigation_publisher.configure(
		world_setup.terrain_grid,
		nav_grid,
		null,
		world_setup.water_grid,
	)
	world_setup.water_access.configure(world_setup.water_grid, world_setup.terrain_grid, nav_grid)
	# The map seeds the road network and stops there: no editing service is passed,
	# because in a session the settlement's construction is what changes coverage.
	road_network.configure(nav_grid)
	# Accumulation reaches the real layers only once the world is built. Before
	# that the environment still runs — it simply has nothing to snow on.
	environment_accumulation.configure(
		world_setup.terrain_service,
		world_setup.water_service,
		world_setup.terrain_grid,
		world_setup.water_grid,
	)
	if map_document != null:
		coverage_navigation_publisher.configure(map_document.coverage, road_network)
	# Static authored entities are the world's base obstacle layer. Game modules
	# may add buildings or temporary obstacles later, but they start from this set
	# instead of reinterpreting asset metadata themselves.
	nav_grid.set_blocked_cells(base_navigation_blocked_cells())
	nav_grid.refresh_connectivity()


func entity_navigation_blocked_cells() -> Dictionary:
	if world_setup == null:
		return {}
	return entity_runtime.navigation_blocked_cells(world_setup.terrain_grid)


## Static obstacles authored into the map.  Placements must participate in the
## same base set as entities so a game module publishing its dynamic buildings
## cannot accidentally erase the map's buildings from navigation.
func base_navigation_blocked_cells() -> Dictionary:
	var blocked := entity_navigation_blocked_cells()
	if map_document == null or world_setup == null or world_setup.terrain_grid == null:
		return blocked
	# Anonymous generated objects obey the same asset contract as named entities.
	# Keeping this derivation here avoids a second authored "blocked cells" list.
	for record: MapScatterLayer.Record in map_document.scatter.records:
		if record.is_empty():
			continue
		var asset := EntityArchetypeCatalog.asset_of(
			map_document.scatter.archetype_of(record))
		if asset == null or not asset.blocking_navigation:
			continue
		var span := asset.placement_cell_span(record.scale, record.yaw_degrees)
		var first := record.cell - Vector2i(span.x / 2, span.y / 2)
		for x in range(first.x, first.x + span.x):
			for z in range(first.y, first.y + span.y):
				var cell := Vector2i(x, z)
				if world_setup.terrain_grid.is_inside(cell):
					blocked[cell] = true
	for record: MapPlacementRecord in map_document.placements.placements:
		for cell: Vector2i in BuildingPlacementService.footprint_of(record).cells():
			if world_setup.terrain_grid.is_inside(cell):
				blocked[cell] = true
	return blocked


func _on_entity_changed(_entity_id: StringName, change: StringName) -> void:
	if change != &"active":
		return
	if obstacle_refresh_callback.is_valid():
		obstacle_refresh_callback.call()
		return
	nav_grid.set_blocked_cells(base_navigation_blocked_cells())
	nav_grid.refresh_connectivity()


## The world projects some visuals into the game host and territory, outside
## `WorldSetup`'s own node subtree. Release those projections before the host
## destroys its scene so a stopped session cannot leave orphan ObjectDB/RID
## objects behind.
func dispose() -> void:
	if entity_runtime != null and entity_runtime.entity_changed.is_connected(_on_entity_changed):
		entity_runtime.entity_changed.disconnect(_on_entity_changed)
	if world_setup != null:
		world_setup.dispose()
		if is_instance_valid(world_setup):
			world_setup.free()
	world_setup = null
	entity_runtime = MapEntityRuntime.new()
	obstacle_refresh_callback = Callable()
	terrain_navigation_publisher = TerrainNavigationPublisher.new()
	road_network = RoadNetworkService.new()
	coverage_navigation_publisher = CoverageNavigationPublisher.new()
	# The bus holds callables into the scenario runtime; clearing it before the
	# runtime goes is what keeps a stopped session from receiving one more
	# presence event from a tracker that has not been torn down yet.
	zone_event_bus.configure({})
	scenario_runtime = MapScenarioRuntime.new()
