class_name BuildingAccessPoints
extends RefCounted

## Resolves authored building access anchors into local/world positions.
##
## Authored `routing_anchors` are the sole authority for building access.
const DEFAULT_PAD := 1.0


static func worker_local_positions(blueprint: Dictionary, pad := DEFAULT_PAD) -> Array[Vector3]:
	return local_positions_for_audience(blueprint, ZoneAccess.AUDIENCE_STAFF, pad)


static func visitor_local_positions(blueprint: Dictionary, pad := DEFAULT_PAD) -> Array[Vector3]:
	return local_positions_for_audience(blueprint, ZoneAccess.AUDIENCE_VISITOR, pad)


static func construction_local_positions(blueprint: Dictionary, pad := DEFAULT_PAD) -> Array[Vector3]:
	return local_positions_for_audience(blueprint, ZoneAccess.AUDIENCE_BUILDER, pad)


static func local_positions_for_audience(blueprint: Dictionary, audience: StringName, pad := DEFAULT_PAD) -> Array[Vector3]:
	return _authored_door_positions(blueprint, audience)


static func worker_positions(building: Node3D, blueprint: Dictionary, pad := DEFAULT_PAD) -> Array[Vector3]:
	return _to_world(building, worker_local_positions(blueprint, pad))


static func visitor_positions(building: Node3D, blueprint: Dictionary, pad := DEFAULT_PAD) -> Array[Vector3]:
	return _to_world(building, visitor_local_positions(blueprint, pad))


static func construction_positions(building: Node3D, blueprint: Dictionary, pad := DEFAULT_PAD) -> Array[Vector3]:
	return _to_world(building, construction_local_positions(blueprint, pad))


static func authored_door_count(blueprint: Dictionary) -> int:
	var count := 0
	for raw_anchor in blueprint.get("routing_anchors", []):
		if raw_anchor is Dictionary and StringName(raw_anchor.get("role", "")) == ZoneAnchorRecord.ROLE_DOOR:
			count += 1
	return count


## Every constructible building must declare a door that builders may approach.
static func access_errors(blueprint: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if authored_door_count(blueprint) == 0:
		errors.append("authored blueprint has no door anchor")
	elif construction_local_positions(blueprint).is_empty():
		errors.append("no authored door permits the builder audience")
	return errors


static func _authored_door_positions(blueprint: Dictionary, audience: StringName) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for raw_anchor in blueprint.get("routing_anchors", []):
		if not (raw_anchor is Dictionary):
			continue
		var anchor := ZoneAnchorRecord.from_dict(raw_anchor)
		if not anchor.is_door() or not anchor.permits(audience):
			continue
		if anchor.pos not in result:
			result.append(anchor.pos)
	return result


static func _to_world(building: Node3D, local_positions: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for local_position in local_positions:
		if building.is_inside_tree():
			result.append(building.to_global(local_position))
		else:
			result.append(building.position + local_position.rotated(Vector3.UP, building.rotation.y))
	return result
