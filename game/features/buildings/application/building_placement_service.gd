class_name BuildingPlacementService
extends RefCounted

## Handles building placement validation: slope checks, terrain obstacle checks,
## dig site overlaps, and distance clearance checks.

var simulation: Node


func configure(p_simulation: Node) -> void:
	simulation = p_simulation


func is_clear_of_dig_sites(world_position: Vector3, footprint: Vector2i) -> bool:
	var half := Vector2(footprint.x, footprint.y) * 0.5
	for site in simulation.dig_sites:
		if is_instance_valid(site.node) and absf(world_position.x - site.node.global_position.x) < half.x + 1.0 and absf(world_position.z - site.node.global_position.z) < half.y + 1.0:
			return false
	return true


func footprint_overlaps_terrain_obstacle(center: Vector3, footprint: Vector2i) -> bool:
	var min_x := roundi(center.x - (footprint.x - 1) * 0.5)
	var min_z := roundi(center.z - (footprint.y - 1) * 0.5)
	for x in range(footprint.x):
		for z in range(footprint.y):
			if simulation.terrain_blocked_cells.has(Vector2i(min_x + x, min_z + z)):
				return true
	return false


func is_footprint_level(world_position: Vector3, footprint: Vector2i) -> bool:
	var heights: Array[float] = []
	var half_x := footprint.x * 0.5 - 0.25
	var half_z := footprint.y * 0.5 - 0.25
	for offset in [Vector2(-half_x, -half_z), Vector2(half_x, -half_z), Vector2(-half_x, half_z), Vector2(half_x, half_z), Vector2.ZERO]:
		var height: float = simulation._terrain_height_at(world_position.x + offset.x, world_position.z + offset.y, world_position.y)
		if is_nan(height):
			return false
		heights.append(height)
	return heights.max() - heights.min() <= simulation.MAX_BUILD_SLOPE


func is_clear_of_objects(world_position: Vector3, minimum_distance: float) -> bool:
	for occupied_position in simulation.building_registry.positions() + simulation.tree_positions:
		if Vector2(occupied_position.x, occupied_position.z).distance_to(Vector2(world_position.x, world_position.z)) < minimum_distance:
			return false
	for site in simulation.dig_sites:
		if is_instance_valid(site.node) and Vector2(site.node.global_position.x, site.node.global_position.z).distance_to(Vector2(world_position.x, world_position.z)) < minimum_distance:
			return false
	return true
