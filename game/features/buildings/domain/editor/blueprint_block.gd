class_name BlueprintBlock
extends RefCounted

## A single placed construction block in a building blueprint.
## `pos` is the anchor voxel on the 1m grid. Rotation is stored as three
## independent quarter-turn indices (0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°) about
## the X, Y and Z axes; `rot` is the Y turn (kept named for compatibility).
## `variant` selects a prepared size/profile option for blocks that expose one
## (empty = default).

var pos: Vector3i = Vector3i.ZERO
var block_id: StringName = &""
var material_id: StringName = &"branches"
var rot: int = 0        ## Y-axis quarter-turns.
var rot_x: int = 0      ## X-axis quarter-turns.
var rot_z: int = 0      ## Z-axis quarter-turns.
var variant: StringName = &""
## Packed in-memory representation of the in-cell offset. New files serialize it
## as the readable `offset: [x, y, z]`; integer values are accepted only to load
## existing v7 content.
var anchor: int = 0


func _init(
	p_pos: Vector3i = Vector3i.ZERO,
	p_block_id: StringName = &"",
	p_rot: int = 0,
	p_material_id: StringName = &"branches",
	p_variant: StringName = &"",
	p_anchor: int = 0,
	p_rot_x: int = 0,
	p_rot_z: int = 0
) -> void:
	pos = p_pos
	block_id = p_block_id
	rot = p_rot
	material_id = p_material_id
	variant = p_variant
	anchor = p_anchor
	rot_x = p_rot_x
	rot_z = p_rot_z


func rotation_radians() -> float:
	return deg_to_rad(90.0 * float(rot % 4))


## Full Euler rotation (radians) combining all three quarter-turn axes.
func rotation_euler() -> Vector3:
	return Vector3(
		deg_to_rad(90.0 * float(rot_x % 4)),
		deg_to_rad(90.0 * float(rot % 4)),
		deg_to_rad(90.0 * float(rot_z % 4)))


func to_dict() -> Dictionary:
	var out := {
		"pos": [pos.x, pos.y, pos.z],
		"block_id": String(block_id),
		"material_id": String(material_id),
		"rot": rot,
	}
	# Only emitted for blocks that carry a chosen variant, keeping single-size
	# block entries unchanged in the saved JSON.
	if variant != &"":
		out["variant"] = String(variant)
	# The open format keeps sub-cell placement readable. `anchor` used to expose
	# this implementation-specific bit packing and remains a load-only legacy field.
	var offset := BuildingBlockCatalog.anchor_base_offset_3d(block_id, variant, anchor)
	if not offset.is_zero_approx():
		out["offset"] = [offset.x, offset.y, offset.z]
	# Only emitted when tilted off the Y axis, keeping flat entries unchanged.
	if rot_x != 0:
		out["rot_x"] = rot_x
	if rot_z != 0:
		out["rot_z"] = rot_z
	return out


static func from_dict(data: Dictionary) -> BlueprintBlock:
	var raw_pos_data: Variant = data.get("pos", [0, 0, 0])
	var raw_pos: Array = raw_pos_data if raw_pos_data is Array and raw_pos_data.size() >= 3 else [0, 0, 0]
	var pos := Vector3i(int(raw_pos[0]), int(raw_pos[1]), int(raw_pos[2]))
	var block_id := StringName(data.get("block_id", ""))
	var material_id := StringName(data.get("material_id", "branches"))
	var rot := ((int(data.get("rot", 0)) % 4) + 4) % 4
	var variant := StringName(data.get("variant", ""))
	var anchor := 0
	var raw_offset: Variant = data.get("offset", null)
	if raw_offset is Array and raw_offset.size() >= 3:
		anchor = BuildingBlockCatalog.pack_subgrid_anchor(
			float(raw_offset[0]), float(raw_offset[2]), float(raw_offset[1]))
	else:
		# Compatibility with v7 files written before readable offsets were added.
		anchor = maxi(0, int(data.get("anchor", 0)))
	var rot_x := ((int(data.get("rot_x", 0)) % 4) + 4) % 4
	var rot_z := ((int(data.get("rot_z", 0)) % 4) + 4) % 4
	return BlueprintBlock.new(pos, block_id, rot, material_id, variant, anchor, rot_x, rot_z)
