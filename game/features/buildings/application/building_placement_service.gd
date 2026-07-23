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


func configure(
	p_dig_sites: Array,
	p_terrain_blocked_cells: Dictionary,
	p_building_registry: Variant,
	p_tree_positions: Array[Vector3],
	p_terrain_height_at: Callable,
	p_max_build_slope: float
) -> void:
	_dig_sites = p_dig_sites
	_terrain_blocked_cells = p_terrain_blocked_cells
	_building_registry = p_building_registry
	_tree_positions = p_tree_positions
	_terrain_height_at = p_terrain_height_at
	_max_build_slope = p_max_build_slope


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
