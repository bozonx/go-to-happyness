class_name FurnishingAssetDef
extends Resource

## Definition of a furnishing asset available in the building editor catalog
## (design_docs/content/building_furnishing.md §4).
##
## `appearance_controls` are the authored visual knobs (design §3.3). Each entry is:
##   {
##     "name": "visual_flame_visible", "label": "Горит", "type": "bool"|"float"|"string"|"color",
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

const SURFACE_FLOOR := "floor"
const SURFACE_WALL := "wall"
const SURFACE_CEILING := "ceiling"
const SURFACE_ANY := "any"

const SCALE_LOCKED := "locked"
const SCALE_UNIFORM_STEPS := "uniform_steps"
const SCALE_FREE_UNIFORM := "free_uniform"

const COLLISION_NONE := "none"
const COLLISION_BOX := "box"
const COLLISION_SCENE := "scene"
const COLLISION_FOOTPRINT := "footprint"

@export var id: StringName = &""
@export var name: String = ""
@export var category: StringName = &"camping"
@export var group: StringName = &"outdoor"
@export var scene_path: String = ""
@export var size_in_blocks: Vector3i = Vector3i(1, 1, 1)
## Real footprint in metres, used for in-cell anchoring. Falls back to the block size.
@export var size_m: Vector3 = Vector3.ZERO
@export var default_snap_step: float = 1.0
## Allowed snap steps for this asset (design §4.1). Empty means use editor defaults.
@export var snap_steps: Array[float] = []
## Authoring appearance knobs (renamed from `controls`).
@export var appearance_controls: Array[Dictionary] = []
@export var icon_path: String = ""
## Short authoring hint shown under the catalog.
@export var description: String = ""
## Search tags for catalog filtering (design §5.1).
@export var tags: Array[StringName] = []
## Era when this asset becomes available (design §4).
@export var available_from_era: StringName = &""
## Placement surface restriction (design §4.1).
@export var placement_surface: String = SURFACE_ANY
## Allowed rotation axes, e.g. ["y"]. Empty means Y-only.
@export var rotation_axes: Array[String] = ["y"]
## Quick rotation step in degrees (design §4.1).
@export var quick_rotation_step: float = 15.0
## Scale policy (design §4.1): locked, uniform_steps, free_uniform.
@export var scale_mode: String = SCALE_LOCKED
## Allowed scale values for uniform_steps mode.
@export var allowed_scales: Array[float] = [1.0]
## Collision policy (design §4.2): none, box, scene, footprint.
@export var collision_policy: String = COLLISION_NONE
## Whether this asset blocks navigation routing (separate from physical collision).
@export var blocking_navigation: bool = false
## Supported capabilities stub (design §4). Not used by editor in phase 1.
@export var supported_capabilities: Array[StringName] = []


func _init(
	p_id: StringName = &"",
	p_name: String = "",
	p_category: StringName = &"camping",
	p_group: StringName = &"outdoor",
	p_scene_path: String = "",
	p_size: Vector3i = Vector3i(1, 1, 1),
	p_snap_step: float = 1.0,
	p_appearance_controls: Array[Dictionary] = [],
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
	appearance_controls = p_appearance_controls
	size_m = p_size_m
	description = p_description


## Footprint used by in-cell anchoring; falls back to the whole block extent.
func footprint_m() -> Vector3:
	if size_m.x > 0.0 and size_m.z > 0.0:
		return size_m
	return Vector3(size_in_blocks)


## Control defaults, already JSON-safe (Color → html string), ready to be stored
## in a DecorObjectRecord.
func default_appearance() -> Dictionary:
	var props: Dictionary = {}
	for control in appearance_controls:
		var control_name := String(control.get("name", ""))
		if control_name.is_empty():
			continue
		props[control_name] = DecorObjectRecord.json_safe_value(control.get("default", null))
	return props


## Flat map of property name → array of `{"node": ..., "prop": ...}` bindings.
func bindings() -> Dictionary:
	var map: Dictionary = {}
	for control in appearance_controls:
		var control_name := String(control.get("name", ""))
		if control_name.is_empty():
			continue
		var raw_binds: Variant = control.get("bind", [])
		if raw_binds is Array and not (raw_binds as Array).is_empty():
			map[control_name] = raw_binds
	return map


func get_control(control_name: String) -> Dictionary:
	for control in appearance_controls:
		if String(control.get("name", "")) == control_name:
			return control
	return {}


## Whether this asset can be placed on the given surface type.
## If the asset's placement_surface is SURFACE_ANY, it accepts any surface.
## If the queried surface is SURFACE_ANY, it means 'any surface is fine'.
func can_place_on(surface: String) -> bool:
	if placement_surface == SURFACE_ANY or surface == SURFACE_ANY:
		return true
	return placement_surface == surface


## Whether the given scale value is allowed by this asset's scale policy.
func is_scale_allowed(scale_value: float) -> bool:
	match scale_mode:
		SCALE_LOCKED:
			return is_equal_approx(scale_value, 1.0)
		SCALE_UNIFORM_STEPS:
			for allowed in allowed_scales:
				if is_equal_approx(scale_value, allowed):
					return true
			return false
		SCALE_FREE_UNIFORM:
			if allowed_scales.size() >= 2:
				return scale_value >= allowed_scales[0] and scale_value <= allowed_scales[-1]
			return scale_value > 0.0
		_:
			return is_equal_approx(scale_value, 1.0)


## Whether the given rotation axis is allowed by this asset.
func is_rotation_axis_allowed(axis: String) -> bool:
	if rotation_axes.is_empty():
		return axis == "y"
	return axis in rotation_axes
