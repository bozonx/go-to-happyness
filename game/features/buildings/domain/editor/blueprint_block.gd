class_name BlueprintBlock
extends RefCounted

## A single placed construction block in a building blueprint.
## `pos` is the anchor voxel on the 1m grid, `rot` is a quarter-turn index
## (0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°) around the Y axis.

var pos: Vector3i = Vector3i.ZERO
var block_id: StringName = &""
var rot: int = 0


func _init(p_pos: Vector3i = Vector3i.ZERO, p_block_id: StringName = &"", p_rot: int = 0) -> void:
	pos = p_pos
	block_id = p_block_id
	rot = p_rot


func rotation_radians() -> float:
	return deg_to_rad(90.0 * float(rot % 4))


func to_dict() -> Dictionary:
	return {
		"pos": [pos.x, pos.y, pos.z],
		"block_id": String(block_id),
		"rot": rot,
	}


static func from_dict(data: Dictionary) -> BlueprintBlock:
	var raw_pos: Array = data.get("pos", [0, 0, 0])
	var pos := Vector3i(int(raw_pos[0]), int(raw_pos[1]), int(raw_pos[2]))
	var block_id := StringName(data.get("block_id", ""))
	var rot := int(data.get("rot", 0)) % 4
	return BlueprintBlock.new(pos, block_id, rot)
