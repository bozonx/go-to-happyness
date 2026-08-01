class_name TerritoryBase
extends Node3D

## The ground of one territory plus everything that visually belongs to it.
##
## The ground is a `GridTerrainWorld` over the launched map's real `TerrainGrid`.
## It is the single source of truth for height and collision.

@export var biome_definition: BiomeDefinition
@onready var landscape_objects: Node3D = get_node_or_null("LandscapeObjects") as Node3D
@onready var terrain: GridTerrainWorld = get_node_or_null("Terrain") as GridTerrainWorld
@onready var water: WaterWorld = get_node_or_null("Water") as WaterWorld

var terrain_grid: TerrainGrid
## The built-coverage layer of the launched map, when it has one.
var coverage_layer: CoverageLayer = null
## The board's water (grid_terrain_system.md §9). Adopted from the launched map
## for the same reason the relief is: two copies of a lake would disagree the
## moment anything edited one of them.
var water_grid: WaterGrid = null


## Establishes the board's ground. Called once by `WorldSetup`, which owns the
## board dimensions. The mesh is built immediately rather than over the frame
## budget: nothing may run a frame without ground under it.
##
## `authored` is the grid a launched map brought with it (map_editor.md §14.1).
## It is adopted, not copied: the map's relief and the session's ground have to be
## the same object, or an edit made in play would be invisible to whatever still
## held the other one.
func configure_terrain(
	cell_size: float,
	board_cells: int,
	camera: Camera3D = null,
	authored: TerrainGrid = null,
	authored_coverage: CoverageLayer = null,
) -> TerrainGrid:
	if authored != null and authored.board_cells == board_cells:
		terrain_grid = authored
	else:
		terrain_grid = TerrainGrid.new()
		terrain_grid.configure(cell_size, board_cells)
	# Coverage is adopted the same way the relief is: the paths the author laid are
	# the paths the citizens walk on, and there is no second copy to fall behind.
	coverage_layer = authored_coverage if authored_coverage != null and authored_coverage.board_cells == board_cells else null
	if terrain != null:
		terrain.configure(terrain_grid, camera, coverage_layer)
		terrain.rebuild_pending_now()
	return terrain_grid


## The water layer of the launched map, drawn over the same ground. An empty map
## water layer simply draws nothing and blocks nobody.
func configure_water(
	board_cells: int,
	cell_size: float,
	authored: WaterGrid = null,
) -> WaterGrid:
	if authored != null and authored.board_cells == board_cells:
		water_grid = authored
	else:
		water_grid = WaterGrid.new()
		water_grid.configure(cell_size, board_cells)
	if water != null:
		water.configure(water_grid, terrain_grid)
		water.rebuild_pending_now()
	return water_grid


## What the map says lies past the rim (`map_editor.md` §6.1). Visual only in a
## session: the horizon ocean has no collider and no navigation, and the rule that
## floods the rim belongs to the editor, where columns can still move.
func configure_water_border(kind: StringName, level: int) -> void:
	if water != null:
		water.configure_border(kind, level)
		water.rebuild_pending_now()


## Owns visual nodes that are naturally part of this territory: trees,
## wild plants, animals and their ambience. Gameplay services keep the matching
## runtime records; this method only establishes scene ownership.
func add_landscape_object(node: Node) -> void:
	if node == null:
		return
	if landscape_objects != null:
		if node.get_parent() != null:
			node.reparent(landscape_objects, true)
		else:
			landscape_objects.add_child(node)
	else:
		add_child(node)


## Session-owned visuals are attached beside the static territory scene. They
## must be disposed explicitly before the session root goes away; otherwise a
## host scene transition leaves those detached map-entity and ambient nodes as
## ObjectDB orphans.
func clear_session_landscape_objects() -> void:
	if landscape_objects == null:
		return
	for node: Node in landscape_objects.get_children():
		node.free()
