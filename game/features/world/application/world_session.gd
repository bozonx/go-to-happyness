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


func _init(
	p_map_document: MapDocument = null,
	p_cell_size := DEFAULT_CELL_SIZE,
	p_start_option: StringName = &"",
	p_start_flags: Dictionary = {},
) -> void:
	map_document = p_map_document
	start_option = p_start_option
	cell_size = p_cell_size
	if map_document != null:
		nav_grid.configure(cell_size, map_document.board_cells())
		scenario_runtime.configure(map_document.scenario, p_start_flags)
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
	world_setup.setup(camera, cell_size, board_cells, trail_field, map_document, start_option)
	scene_host.add_child(world_setup)
	world_setup.build(scene_host)
	entity_runtime = world_setup.map_entity_runtime
	if not entity_runtime.entity_changed.is_connected(_on_entity_changed):
		entity_runtime.entity_changed.connect(_on_entity_changed)
	publish_navigation()
	return world_setup


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
	if map_document != null:
		coverage_navigation_publisher.configure(map_document.coverage, road_network)
	# Static authored entities are the world's base obstacle layer. Game modules
	# may add buildings or temporary obstacles later, but they start from this set
	# instead of reinterpreting asset metadata themselves.
	nav_grid.set_blocked_cells(entity_navigation_blocked_cells())
	nav_grid.refresh_connectivity()


func entity_navigation_blocked_cells() -> Dictionary:
	if world_setup == null:
		return {}
	return entity_runtime.navigation_blocked_cells(world_setup.terrain_grid)


func _on_entity_changed(_entity_id: StringName, change: StringName) -> void:
	if change != &"active":
		return
	if obstacle_refresh_callback.is_valid():
		obstacle_refresh_callback.call()
		return
	nav_grid.set_blocked_cells(entity_navigation_blocked_cells())
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
