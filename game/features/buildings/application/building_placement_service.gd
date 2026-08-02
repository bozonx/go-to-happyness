class_name BuildingPlacementService
extends RefCounted

## Handles building placement validation: slope checks, terrain obstacle checks,
## dig site overlaps, and distance clearance checks.

var _dig_sites: Array = []
var _terrain_blocked_cells: Dictionary = {}
var _building_registry: Variant
var _tree_positions: Array[Vector3] = []
var _terrain_height_at: Callable
var _max_build_slope: float
var _terrain_grid: TerrainGrid = null
var _water_grid: WaterGrid = null


func configure(port: BuildingPlacementRuntimePort) -> void:
	_dig_sites = port.dig_sites
	_terrain_blocked_cells = port.terrain_blocked_cells
	_building_registry = port.building_registry
	_tree_positions = port.tree_positions
	_terrain_height_at = port.terrain_height_at
	_max_build_slope = port.max_build_slope
	_terrain_grid = port.terrain_grid
	_water_grid = port.water_grid


func is_clear_of_dig_sites(world_position: Vector3, footprint: Vector2i) -> bool:
	var half := Vector2(footprint.x, footprint.y) * 0.5
	for site in _dig_sites:
		if is_instance_valid(site.node) and absf(world_position.x - site.node.global_position.x) < half.x + 1.0 and absf(world_position.z - site.node.global_position.z) < half.y + 1.0:
			return false
	return true


func footprint_overlaps_terrain_obstacle(center: Vector3, footprint: Vector2i) -> bool:
	var min_x := roundi(center.x - (footprint.x - 1) * 0.5)
	var min_z := roundi(center.z - (footprint.y - 1) * 0.5)
	for x in range(footprint.x):
		for z in range(footprint.y):
			if _terrain_blocked_cells.has(Vector2i(min_x + x, min_z + z)):
				return true
	if _terrain_grid != null:
		var half := Vector2(float(footprint.x), float(footprint.y)) * 0.5
		var minimum := _terrain_grid.cell_from_position(Vector3(center.x - half.x, 0.0, center.z - half.y))
		var maximum := _terrain_grid.cell_from_position(Vector3(center.x + half.x - 0.0001, 0.0, center.z + half.y - 0.0001))
		for cell_z in range(minimum.y, maximum.y + 1):
			for cell_x in range(minimum.x, maximum.x + 1):
				var cell := Vector2i(cell_x, cell_z)
				if not _terrain_grid.is_inside(cell) or _terrain_grid.is_hole(cell):
					return true
				if _water_grid != null and _water_grid.is_wet(_terrain_grid, cell):
					return true
	return false


func is_footprint_level(world_position: Vector3, footprint: Vector2i) -> bool:
	var heights: Array[float] = []
	var half_x := footprint.x * 0.5 - 0.25
	var half_z := footprint.y * 0.5 - 0.25
	for offset in [Vector2(-half_x, -half_z), Vector2(half_x, -half_z), Vector2(-half_x, half_z), Vector2(half_x, half_z), Vector2.ZERO]:
		var height: float = _terrain_height_at.call(world_position.x + offset.x, world_position.z + offset.y, world_position.y)
		if is_nan(height):
			return false
		heights.append(height)
	return heights.max() - heights.min() <= _max_build_slope


func is_clear_of_objects(world_position: Vector3, minimum_distance: float) -> bool:
	for occupied_position in _building_registry.positions() + _tree_positions:
		if Vector2(occupied_position.x, occupied_position.z).distance_to(Vector2(world_position.x, world_position.z)) < minimum_distance:
			return false
	for site in _dig_sites:
		if is_instance_valid(site.node) and Vector2(site.node.global_position.x, site.node.global_position.z).distance_to(Vector2(world_position.x, world_position.z)) < minimum_distance:
			return false
	return true
