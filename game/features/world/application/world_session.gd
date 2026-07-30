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
## Stable map-entity identity and lifecycle are session data, not presentation
## metadata. WorldSetup merely projects this instance into the territory.
var entity_runtime := MapEntityRuntime.new()
var cell_size := DEFAULT_CELL_SIZE


func _init(p_map_document: MapDocument = null, p_cell_size := DEFAULT_CELL_SIZE) -> void:
	map_document = p_map_document
	cell_size = p_cell_size
	if map_document != null:
		nav_grid.configure(cell_size, map_document.board_cells())


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
	world_setup.setup(camera, cell_size, board_cells, trail_field, map_document)
	scene_host.add_child(world_setup)
	world_setup.build(scene_host)
	entity_runtime = world_setup.map_entity_runtime
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


## The world projects some visuals into the game host and territory, outside
## `WorldSetup`'s own node subtree. Release those projections before the host
## destroys its scene so a stopped session cannot leave orphan ObjectDB/RID
## objects behind.
func dispose() -> void:
	if world_setup != null:
		world_setup.dispose()
		if is_instance_valid(world_setup):
			world_setup.free()
	world_setup = null
	entity_runtime = MapEntityRuntime.new()
	terrain_navigation_publisher = TerrainNavigationPublisher.new()
