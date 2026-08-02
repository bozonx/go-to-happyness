class_name BuildingPlacementRuntimePort
extends RefCounted

## Explicit integration boundary for building placement validation:
## slope checks, terrain obstacles, dig site and object clearance.

var dig_sites: Array = []
var terrain_blocked_cells: Dictionary = {}
var building_registry: Variant
var tree_positions: Array[Vector3] = []
var terrain_height_at: Callable
var max_build_slope: float
var terrain_grid: TerrainGrid = null
var water_grid: WaterGrid = null
