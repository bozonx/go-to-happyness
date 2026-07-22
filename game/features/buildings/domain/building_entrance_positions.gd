class_name BuildingEntrancePositions
extends RefCounted

## Computes world-space service/entrance positions for a building or construction site.
## Keeps the calculation in one place so construction sites and completed buildings agree.

const DEFAULT_PAD := 1.0


static func offsets(building_type: String) -> Array[Vector2i]:
	return BuildingBlueprints.worker_entrance_offsets(building_type)


static func visitor_offsets(building_type: String) -> Array[Vector2i]:
	return BuildingBlueprints.visitor_entrance_offsets(building_type)


static func positions(node: Object, footprint: Vector2i, pad := DEFAULT_PAD) -> Array[Vector3]:
	var building_type := str(node.get_meta("building_type", "")) if node.has_method("get_meta") else ""
	var entrance_offsets := offsets(building_type)
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


static func visitor_positions(node: Object, footprint: Vector2i, pad := DEFAULT_PAD) -> Array[Vector3]:
	var building_type := str(node.get_meta("building_type", "")) if node.has_method("get_meta") else ""
	var entrance_offsets := visitor_offsets(building_type)
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


static func _to_world(node: Object, local: Vector3) -> Vector3:
	if node.has_method("is_inside_tree") and bool(node.call("is_inside_tree")):
		var world: Vector3 = node.call("to_global", local)
		world.y = float(node.get("global_position").y)
		return world
	var pos: Vector3 = node.get("position") if node.get("position") != null else Vector3.ZERO
	var rot_y: float = float(node.get("rotation").y) if node.get("rotation") != null else 0.0
	return pos + local.rotated(Vector3.UP, rot_y)
