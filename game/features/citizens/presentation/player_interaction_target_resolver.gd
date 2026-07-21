class_name PlayerInteractionTargetResolver
extends RefCounted

## Resolves the interactable target in front of the first-person camera.
## Performs a raycast from the camera and classifies the hit collider
## (building, tree, warehouse, construction site, etc.), then falls back
## to proximity checks for grass, farms, ponds, and trees.

const INTERACTION_RANGE := 4.5


func resolve(camera: Camera3D, player_citizen: Node3D, simulation: Node) -> Dictionary:
	var result := {"kind": ""}
	if camera == null or player_citizen == null or simulation == null:
		return result
	var from: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_transform.basis.z
	var to := from + direction * INTERACTION_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 1 | 4
	var hit: Dictionary = simulation.get_world_3d().direct_space_state.intersect_ray(query)
	var hit_position := Vector3.INF
	if not hit.is_empty():
		hit_position = hit.position
		result = _classify_ray_hit(hit, simulation)
	if result.kind != "":
		return result
	if hit_position == Vector3.INF:
		hit_position = to
	var player_pos: Vector3 = player_citizen.global_position
	if player_pos.distance_to(hit_position) > INTERACTION_RANGE:
		return result
	return _classify_proximity(hit_position, player_pos, simulation)


func _classify_ray_hit(hit: Dictionary, simulation: Node) -> Dictionary:
	var collider: Object = hit.get("collider", null)
	if collider is StaticBody3D and collider.name == "TreeCollision":
		var tree := collider.get_parent() as Node3D
		if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
			return {"kind": "tree", "node": tree, "position": tree.global_position}
		return {"kind": ""}
	if collider is Area3D:
		return _classify_area_hit(collider as Area3D, simulation)
	return {"kind": ""}


func _classify_area_hit(collider: Area3D, simulation: Node) -> Dictionary:
	var area_parent := collider.get_parent() as Node3D
	if collider.is_in_group("construction_selector") and is_instance_valid(area_parent):
		return {"kind": "construction", "node": area_parent, "position": area_parent.global_position}
	if collider.is_in_group("entrance_selector") and is_instance_valid(area_parent):
		return {"kind": "entrance", "node": area_parent, "position": area_parent.global_position}
	if collider.is_in_group("resource_pile_selector"):
		var pile: Dictionary = simulation._resource_pile_for_node(area_parent)
		if not pile.is_empty():
			return {"kind": "pile", "node": area_parent, "pile": pile, "position": area_parent.global_position}
		return {"kind": ""}
	if collider.is_in_group("warehouse_selector"):
		return {"kind": "warehouse", "node": area_parent, "position": area_parent.global_position, "warehouse_index": simulation._warehouse_index_for_building(area_parent)}
	if collider.is_in_group("citizen_selector") and area_parent is Citizen:
		return {"kind": "citizen", "node": area_parent as Citizen, "position": area_parent.global_position}
	if collider.is_in_group("tree_selector") and is_instance_valid(area_parent):
		if not bool(area_parent.get_meta("felled", false)):
			return {"kind": "tree", "node": area_parent, "position": area_parent.global_position}
		return {"kind": ""}
	if collider.is_in_group("forage_selector") and is_instance_valid(area_parent):
		return {"kind": "forage", "node": area_parent, "position": area_parent.global_position}
	if collider.is_in_group("rabbit_selector") and is_instance_valid(area_parent):
		return {"kind": "rabbit", "node": area_parent, "position": area_parent.global_position}
	if collider.is_in_group("building_selector") and is_instance_valid(area_parent):
		return _classify_building_hit(area_parent, simulation)
	if collider.is_in_group("campfire_selector") or collider.is_in_group("cook_campfire_selector") or collider.is_in_group("market_selector") or collider.is_in_group("school_selector") or collider.is_in_group("house_selector") or collider.is_in_group("materials_factory_selector"):
		if is_instance_valid(area_parent):
			return {"kind": "building", "node": area_parent, "position": area_parent.global_position}
	return {"kind": ""}


func _classify_building_hit(area_parent: Node3D, simulation: Node) -> Dictionary:
	var building_type := str(area_parent.get_meta("building_type", ""))
	if bool(area_parent.get_meta("pending_demolition", false)):
		return {"kind": "demolition", "node": area_parent, "position": area_parent.global_position}
	if building_type == "sawmill":
		return {"kind": "sawmill", "node": area_parent, "position": area_parent.global_position}
	if building_type.begins_with("toilet_"):
		return {"kind": "toilet", "node": area_parent, "position": area_parent.global_position}
	if simulation._role_for_workplace(area_parent) != "":
		return {"kind": "workplace", "node": area_parent, "position": area_parent.global_position}
	return {"kind": "building", "node": area_parent, "position": area_parent.global_position}


func _classify_proximity(hit_position: Vector3, player_pos: Vector3, simulation: Node) -> Dictionary:
	var grass_pos: Vector3 = simulation._nearest_grass_source_to_point(hit_position, 1.0)
	if grass_pos != Vector3.INF and player_pos.distance_to(grass_pos) <= INTERACTION_RANGE:
		var grass_cell: Vector2i = simulation._cell_from_position(grass_pos)
		if simulation.grass_sources.has(grass_cell):
			return {"kind": "grass", "position": grass_pos}
	var farm_pos: Vector3 = simulation._nearest_point_to_point_array(simulation.farm_positions, hit_position, 5.0)
	if farm_pos != Vector3.INF and player_pos.distance_to(farm_pos) <= INTERACTION_RANGE:
		return {"kind": "farm", "position": farm_pos}
	var pond_pos: Vector3 = simulation._nearest_point_to_point_array(simulation.pond_positions, hit_position, 2.5)
	if pond_pos != Vector3.INF and player_pos.distance_to(pond_pos) <= INTERACTION_RANGE:
		return {"kind": "pond", "position": pond_pos}
	var tree_pos: Vector3 = simulation._nearest_point_to_point_array(simulation.tree_positions, hit_position, 1.5)
	if tree_pos != Vector3.INF and player_pos.distance_to(tree_pos) <= INTERACTION_RANGE:
		var tree_node: Node3D = simulation.tree_nodes.get(simulation._cell_from_position(tree_pos))
		if is_instance_valid(tree_node) and not bool(tree_node.get_meta("felled", false)):
			return {"kind": "tree", "node": tree_node, "position": tree_pos}
	return {"kind": ""}
