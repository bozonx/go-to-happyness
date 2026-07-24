class_name SquadController
extends SteeringController

## Coordinates squad formation movement where followers maintain dynamic offsets
## relative to a squad leader's path.

var leader_position := Vector3.ZERO
var leader_forward := Vector3.FORWARD
var member_offsets: Dictionary = {}  # member_id (int/StringName) -> Vector3 offset


func register_member(member_id: Variant, local_offset: Vector3) -> void:
	member_offsets[member_id] = local_offset


func unregister_member(member_id: Variant) -> void:
	member_offsets.erase(member_id)


func get_member_target(member_id: Variant, current_leader_pos: Vector3, heading: Vector3) -> Vector3:
	if not member_offsets.has(member_id):
		return current_leader_pos
	var offset: Vector3 = member_offsets[member_id]
	var norm_heading := heading.normalized()
	if norm_heading.length_squared() <= 0.001:
		norm_heading = Vector3.FORWARD
	var right := norm_heading.cross(Vector3.UP).normalized()
	var world_offset := right * offset.x + Vector3.UP * offset.y + norm_heading * offset.z
	return current_leader_pos + world_offset
