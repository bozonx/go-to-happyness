class_name BuildingEntrancePositions
extends RefCounted

## Computes world-space service/entrance positions for a building or construction site.
## Keeps the calculation in one place so construction sites and completed buildings agree.

const DEFAULT_PAD := 1.0

const VISITOR_ONLY_BUILDINGS: Array[String] = [
	"cook_campfire", "gathering_place", "dugout_kitchen",
	"clay_bakery", "stone_tavern", "brick_restaurant"
]

const VISITOR_ENTRANCE_BUILDINGS: Array[String] = [
	"canteen", "school", "park", "leisure_center", "city_hall", "house",
	"dugout_kitchen", "clay_bakery", "stone_tavern", "brick_restaurant"
]

const TWO_WORKER_ENTRANCE_BUILDINGS: Array[String] = [
	"sawmill", "materials_factory", "brick_factory", "metal_factory", "recycling_factory", "construction_company"
]


static func offsets(building_type: String) -> Array[Vector2i]:
	if building_type in VISITOR_ONLY_BUILDINGS:
		return []
	if building_type == "sawmill":
		return [Vector2i(0, -3), Vector2i(0, 3)]
	if building_type == "gathering_place":
		return [Vector2i(0, -5)]
	if building_type == "pond":
		return [Vector2i(0, -2)]
	if building_type in TWO_WORKER_ENTRANCE_BUILDINGS:
		return [Vector2i(0, -2), Vector2i(0, 2)]
	return [Vector2i(0, -1)]


static func visitor_offsets(building_type: String) -> Array[Vector2i]:
	if building_type not in VISITOR_ENTRANCE_BUILDINGS and building_type not in VISITOR_ONLY_BUILDINGS:
		return []
	if building_type == "gathering_place":
		return [Vector2i(0, -5)]
	if building_type == "pond":
		return [Vector2i(0, -2)]
	return [Vector2i(0, -1)]


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


static func local_positions(footprint: Vector2i, offsets_list: Array[Vector2i], pad := DEFAULT_PAD) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var half_x := footprint.x * 0.5
	var half_z := footprint.y * 0.5
	for offset in offsets_list:
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
