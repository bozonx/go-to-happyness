class_name DecorAssetDef
extends Resource

## Definition of a decor asset available in the building editor catalog.
##
## `controls` are the authored knobs (design §3.3). Each entry is:
##   {
##     "name": "is_lit", "label": "Горит", "type": "bool"|"float"|"string"|"color",
##     "default": <value>,
##     "min"/"max"/"step": <float>,          # float only
##     "bind": [{"node": "Fire", "prop": "visible"}, ...]
##   }
##
## `bind` declares *where the value lands in the scene*, so DecorObjectController
## stays a generic applier instead of carrying one @export per asset. `prop`
## accepts any node property plus the synthetic `albedo` (tints the mesh material,
## duplicated per instance) and `scale_y`.

const PROP_ALBEDO := "albedo"
const PROP_SCALE_Y := "scale_y"

const TYPE_BOOL := "bool"
const TYPE_FLOAT := "float"
const TYPE_STRING := "string"
const TYPE_COLOR := "color"

@export var id: StringName = &""
@export var name: String = ""
@export var category: StringName = &"camping"
@export var group: StringName = &"outdoor"  ## &"outdoor" | &"interior" | &"architecture"
@export var scene_path: String = ""
@export var size_in_blocks: Vector3i = Vector3i(1, 1, 1)
## Real footprint in metres, used for in-cell anchoring. Falls back to the block size.
@export var size_m: Vector3 = Vector3.ZERO
@export var default_snap_step: float = 0.5  ## 1.0, 0.5, 0.25, 0.0 (free)
@export var controls: Array[Dictionary] = []
@export var icon_path: String = ""
## Short authoring hint shown under the catalog.
@export var description: String = ""


func _init(
	p_id: StringName = &"",
	p_name: String = "",
	p_category: StringName = &"camping",
	p_group: StringName = &"outdoor",
	p_scene_path: String = "",
	p_size: Vector3i = Vector3i(1, 1, 1),
	p_snap_step: float = 0.5,
	p_controls: Array[Dictionary] = [],
	p_size_m: Vector3 = Vector3.ZERO,
	p_description: String = ""
) -> void:
	id = p_id
	name = p_name
	category = p_category
	group = p_group
	scene_path = p_scene_path
	size_in_blocks = p_size
	default_snap_step = p_snap_step
	controls = p_controls
	size_m = p_size_m
	description = p_description


## Footprint used by in-cell anchoring; falls back to the whole block extent.
func footprint_m() -> Vector3:
	if size_m.x > 0.0 and size_m.z > 0.0:
		return size_m
	return Vector3(size_in_blocks)


## Control defaults, already JSON-safe (Color → html string), ready to be stored
## in a DecorObjectRecord.
func default_properties() -> Dictionary:
	var props: Dictionary = {}
	for control in controls:
		var control_name := String(control.get("name", ""))
		if control_name.is_empty():
			continue
		props[control_name] = DecorObjectRecord.json_safe_value(control.get("default", null))
	return props


## Flat map of property name → array of `{"node": ..., "prop": ...}` bindings.
func bindings() -> Dictionary:
	var map: Dictionary = {}
	for control in controls:
		var control_name := String(control.get("name", ""))
		if control_name.is_empty():
			continue
		var raw_binds: Variant = control.get("bind", [])
		if raw_binds is Array and not (raw_binds as Array).is_empty():
			map[control_name] = raw_binds
	return map


func get_control(control_name: String) -> Dictionary:
	for control in controls:
		if String(control.get("name", "")) == control_name:
			return control
	return {}
