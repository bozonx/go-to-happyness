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

var terrain_grid: TerrainGrid = null


## Builds the flat starting ground. Called once by `WorldSetup`, which owns the
## board dimensions. The mesh is built immediately rather than over the frame
## budget: nothing may run a frame without ground under it.
func configure_terrain(cell_size: float, board_cells: int, camera: Camera3D = null) -> TerrainGrid:
	terrain_grid = TerrainGrid.new()
	terrain_grid.configure(cell_size, board_cells)
	if terrain != null:
		terrain.configure(terrain_grid, camera)
		terrain.rebuild_pending_now()
	return terrain_grid


## Owns visual nodes that are naturally part of this territory: trees, ponds,
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
