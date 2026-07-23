class_name BuildingPlacementController
extends Node

## Owns pure building placement validation and geometry helpers that were
## previously inline in the bootstrap. The bootstrap retains UI-mutating
## functions (move_selection, place_building, select_build_mode, etc.) because
## they are tightly coupled to scene nodes and UI state.

const BuildingCatalog = preload("res://game/features/buildings/domain/building_catalog.gd")
const BuildingBlueprints = preload("res://game/features/buildings/presentation/building_blueprints.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var simulation: Node


func setup(p_simulation: Node) -> void:
	simulation = p_simulation


func can_hero_build() -> bool:
	return not simulation.is_first_person or simulation.player_citizen == simulation.hero_citizen


func building_cost() -> int:
	return BuildingCatalog.cost_for(simulation.build_mode)


func can_pay_building_cost(building_type: String) -> bool:
	return bool(simulation.building_availability_service.placement_state_with_inventory(building_type, simulation.pocket).allowed)


func pay_building_cost(building_type: String) -> void:
	simulation.settlement.pay_for_building(building_type)


func rotated_footprint(footprint: Vector2i, rotation_quarters := simulation.build_rotation_quarters) -> Vector2i:
	return Vector2i(footprint.y, footprint.x) if rotation_quarters % 2 != 0 else footprint


func placement_key(world_position: Vector3) -> Vector2i:
	return Vector2i(roundi(world_position.x), roundi(world_position.z))


func can_place(world_position: Vector3) -> bool:
	if simulation.build_mode.is_empty():
		return false
	var footprint := rotated_footprint(BuildingBlueprints.get_blueprint(simulation.build_mode).footprint)
	return is_footprint_level(world_position, footprint) and is_footprint_clear(world_position, footprint)


func is_footprint_clear(world_position: Vector3, footprint: Vector2i) -> bool:
	if not simulation.building_registry.is_footprint_clear(world_position, footprint, simulation.BUILDING_CLEARANCE_BLOCKS):
		return false
	if footprint_overlaps_terrain_obstacle(world_position, footprint):
		return false
	var half := Vector2(footprint.x, footprint.y) * 0.5
	for site in simulation.dig_sites:
		if absf(world_position.x - site.node.global_position.x) < half.x + 1.0 and absf(world_position.z - site.node.global_position.z) < half.y + 1.0:
			return false
	return true


func footprint_overlaps_terrain_obstacle(center: Vector3, footprint: Vector2i) -> bool:
	return simulation.building_placement_service.footprint_overlaps_terrain_obstacle(center, footprint) if simulation.building_placement_service != null else false


func is_footprint_level(world_position: Vector3, footprint: Vector2i) -> bool:
	return simulation.building_placement_service.is_footprint_level(world_position, footprint) if simulation.building_placement_service != null else false


func is_clear_of_objects(world_position: Vector3, minimum_distance: float) -> bool:
	return simulation.building_placement_service.is_clear_of_objects(world_position, minimum_distance) if simulation.building_placement_service != null else false


func snapped_build_position(world_position: Vector3) -> Vector3:
	var snapped := Vector3(roundf(world_position.x), world_position.y, roundf(world_position.z))
	var ground_height := simulation._terrain_height_at(snapped.x, snapped.z, world_position.y)
	if not is_nan(ground_height):
		snapped.y = ground_height
	return snapped
