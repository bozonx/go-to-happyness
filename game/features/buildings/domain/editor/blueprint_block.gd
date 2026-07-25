class_name BlueprintBlock
extends RefCounted

## A single placed construction block in a building blueprint.
## `pos` is the anchor voxel on the 1m grid, `rot` is a quarter-turn index
## (0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°) around the Y axis. `variant` selects a
## prepared size/profile option for blocks that expose one (empty = default).

var pos: Vector3i = Vector3i.ZERO
var block_id: StringName = &""
var material_id: StringName = &"branches"
var rot: int = 0
var variant: StringName = &""
## In-cell snap kind for sub-cell blocks: 0 = centre, 1 = edge, 2 = corner (see
## BuildingBlockCatalog.ANCHOR_*). The concrete side/corner follows from `rot`.
var anchor: int = 0


func _init(
	p_pos: Vector3i = Vector3i.ZERO,
	p_block_id: StringName = &"",
	p_rot: int = 0,
	p_material_id: StringName = &"branches",
	p_variant: StringName = &"",
	p_anchor: int = 0
) -> void:
	pos = p_pos
	block_id = p_block_id
	rot = p_rot
	material_id = p_material_id
	variant = p_variant
	anchor = p_anchor


func rotation_radians() -> float:
	return deg_to_rad(90.0 * float(rot % 4))


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
	# Only emitted when snapped off-centre.
	if anchor != 0:
		out["anchor"] = anchor
	return out


static func from_dict(data: Dictionary) -> BlueprintBlock:
	var raw_pos_data: Variant = data.get("pos", [0, 0, 0])
	var raw_pos: Array = raw_pos_data if raw_pos_data is Array and raw_pos_data.size() >= 3 else [0, 0, 0]
	var pos := Vector3i(int(raw_pos[0]), int(raw_pos[1]), int(raw_pos[2]))
	var block_id := StringName(data.get("block_id", ""))
	var material_id := StringName(data.get("material_id", "branches"))
	var rot := ((int(data.get("rot", 0)) % 4) + 4) % 4
	var variant := StringName(data.get("variant", ""))
	var anchor := clampi(int(data.get("anchor", 0)), 0, 2)
	return BlueprintBlock.new(pos, block_id, rot, material_id, variant, anchor)
