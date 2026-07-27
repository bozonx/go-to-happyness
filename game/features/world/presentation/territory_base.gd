class_name TerritoryBase
extends Node3D

## The ground of one territory plus everything that visually belongs to it.
##
## Since the Terrain3D addon was removed (grid_terrain_system.md §13), the ground
## is a `GridTerrainWorld` over a real `TerrainGrid` — flat at world zero for now
## (Phase 0's stub), but already the single source of truth for height and
## collision. The 1000 m plane below it is a backdrop with no collider: it fills
## the horizon beyond the board and must never answer a height query.

@export var biome_definition: BiomeDefinition
@onready var landscape_objects: Node3D = get_node_or_null("LandscapeObjects") as Node3D
@onready var terrain: GridTerrainWorld = get_node_or_null("Terrain") as GridTerrainWorld
@onready var water: WaterWorld = get_node_or_null("Water") as WaterWorld

var terrain_grid: TerrainGrid = null
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
## held the other one. Without a map the board is flat, as it was before maps.
func configure_terrain(cell_size: float, board_cells: int, camera: Camera3D = null, authored: TerrainGrid = null) -> TerrainGrid:
	if authored != null and authored.board_cells == board_cells:
		terrain_grid = authored
	else:
		terrain_grid = TerrainGrid.new()
		terrain_grid.configure(cell_size, board_cells)
	if terrain != null:
		terrain.configure(terrain_grid, camera)
		terrain.rebuild_pending_now()
	return terrain_grid


## The water layer of the launched map, drawn over the same ground. Without a map
## — or with one that has no water — this is an empty layer, and an empty layer
## draws nothing and blocks nobody.
##
## `starter_cells` are the biome's pond seeds for a session with no map at all
## (`StarterWater`). They are dug here, before the ground is meshed, because the
## basin they cut is terrain: doing it afterwards would need a second remesh and
## a second navigation publish for water that was always going to be there.
func configure_water(
	board_cells: int,
	cell_size: float,
	authored: WaterGrid = null,
	starter_cells: Array[Vector2i] = [],
) -> WaterGrid:
	if authored != null and authored.board_cells == board_cells:
		water_grid = authored
	else:
		water_grid = WaterGrid.new()
		water_grid.configure(cell_size, board_cells)
	if not starter_cells.is_empty():
		StarterWater.carve(terrain_grid, water_grid, starter_cells)
		if terrain != null:
			terrain.rebuild_pending_now()
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
