class_name DecorAssetDef
extends Resource

## Definition of a decor asset available in the building editor catalog.

@export var id: StringName = &""
@export var name: String = ""
@export var category: StringName = &"camping"
@export var group: StringName = &"outdoor"  ## &"outdoor" | &"interior" | &"architecture"
@export var scene_path: String = ""
@export var size_in_blocks: Vector3i = Vector3i(1, 1, 1)
@export var default_snap_step: float = 0.5  ## 1.0, 0.5, 0.25, 0.0 (free)
@export var controls: Array[Dictionary] = []
@export var icon_path: String = ""


func _init(
	p_id: StringName = &"",
	p_name: String = "",
	p_category: StringName = &"camping",
	p_group: StringName = &"outdoor",
	p_scene_path: String = "",
	p_size: Vector3i = Vector3i(1, 1, 1),
	p_snap_step: float = 0.5,
	p_controls: Array[Dictionary] = []
) -> void:
	id = p_id
	name = p_name
	category = p_category
	group = p_group
	scene_path = p_scene_path
	size_in_blocks = p_size
	default_snap_step = p_snap_step
	controls = p_controls
