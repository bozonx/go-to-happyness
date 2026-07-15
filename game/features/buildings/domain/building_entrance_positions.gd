class_name BuildingEntrancePositions
extends RefCounted

## Computes world-space service/entrance positions for a building or construction site.
## Keeps the calculation in one place so construction sites and completed buildings agree.

const DEFAULT_PAD := 1.0


static func offsets(building_type: String) -> Array[Vector2i]:
	return BuildingBlueprints.worker_entrance_offsets(building_type)


static func visitor_offsets(building_type: String) -> Array[Vector2i]:
	return BuildingBlueprints.visitor_entrance_offsets(building_type)


static func positions(node: Node3D, footprint: Vector2i, pad := DEFAULT_PAD) -> Array[Vector3]:
	var entrance_offsets := offsets(str(node.get_meta("building_type", "")))
	if entrance_offsets.is_empty():
		return []

	var result: Array[Vector3] = []
	var half_x := footprint.x * 0.5
	var half_z := footprint.y * 0.5
	for offset in entrance_offsets:
		var local := Vector3.ZERO
		if offset.x < 0:
			local.x = -half_x - pad
		elif offset.x > 0:
			local.x = half_x + pad
		if offset.y < 0:
			local.z = -half_z - pad
		elif offset.y > 0:
			local.z = half_z + pad
		result.append(_to_world(node, local))
	return result


static func visitor_positions(node: Node3D, footprint: Vector2i, pad := DEFAULT_PAD) -> Array[Vector3]:
	var entrance_offsets := visitor_offsets(str(node.get_meta("building_type", "")))
	if entrance_offsets.is_empty():
		return []

	var result: Array[Vector3] = []
	var half_x := footprint.x * 0.5
	var half_z := footprint.y * 0.5
	for offset in entrance_offsets:
		var local := Vector3.ZERO
		if offset.x < 0:
			local.x = -half_x - pad
		elif offset.x > 0:
			local.x = half_x + pad
		if offset.y < 0:
			local.z = -half_z - pad
		elif offset.y > 0:
			local.z = half_z + pad
		result.append(_to_world(node, local))
	return result


static func local_positions(footprint: Vector2i, offsets: Array[Vector2i], pad := DEFAULT_PAD) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var half_x := footprint.x * 0.5
	var half_z := footprint.y * 0.5
	for offset in offsets:
		var local := Vector3.ZERO
		if offset.x < 0:
			local.x = -half_x - pad
		elif offset.x > 0:
			local.x = half_x + pad
		if offset.y < 0:
			local.z = -half_z - pad
		elif offset.y > 0:
			local.z = half_z + pad
		result.append(local)
	return result


static func _to_world(node: Node3D, local: Vector3) -> Vector3:
	if node.is_inside_tree():
		var world := node.to_global(local)
		world.y = node.global_position.y
		return world
	return node.position + local.rotated(Vector3.UP, node.rotation.y)
