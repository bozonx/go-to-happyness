class_name FillObjectRecord
extends RefCounted


## A single placed visual object inside a building blueprint — the `objects[]`
## entries of `.gdbuilding.json` (design_docs/engine/modular_building_editor.md
## §3.3). Typed counterpart of BlueprintBlock / ZoneAnchorRecord: the editor and
## the runtime both work on records, and only (de)serialization touches raw
## dictionaries.
##
## `appearance` holds the asset's authored visual control values. Values are kept
## JSON-safe (Color is stored as an html string), because the whole blueprint is
## hashed via `JSON.stringify` for `content_revision()`.
##
## `owner_zone_id` is an organizational label referencing an `areas[]` entry.
## It has no runtime effect (design_docs/engine/building_furnishing.md §3.2).

var id: String = ""
var asset_id: StringName = &""
var owner_zone_id: StringName = &""
var pos: Vector3 = Vector3.ZERO
var rot: Vector3 = Vector3.ZERO  ## degrees
var scale: Vector3 = Vector3.ONE
var appearance: Dictionary = {}


static func make(p_asset_id: StringName, p_pos: Vector3, unique_suffix: int) -> FillObjectRecord:
	var record := FillObjectRecord.new()
	record.id = "fill_%s_%d" % [String(p_asset_id), unique_suffix]
	record.asset_id = p_asset_id
	record.pos = p_pos
	return record


func duplicate_record(unique_suffix: int) -> FillObjectRecord:
	var copy := FillObjectRecord.new()
	copy.id = "fill_%s_%d" % [String(asset_id), unique_suffix]
	copy.asset_id = asset_id
	copy.owner_zone_id = owner_zone_id
	copy.pos = pos
	copy.rot = rot
	copy.scale = scale
	copy.appearance = appearance.duplicate(true)
	return copy


func to_dict() -> Dictionary:
	return {
		"id": id,
		"asset_id": String(asset_id),
		"owner_zone": String(owner_zone_id),
		"pos": [pos.x, pos.y, pos.z],
		"rot": [rot.x, rot.y, rot.z],
		"scale": [scale.x, scale.y, scale.z],
		"appearance": json_safe_appearance(),
	}


## Appearance values with engine types flattened to JSON primitives. Controls
## hand out `Color` defaults, which `JSON.stringify` cannot encode — storing them
## raw broke both save and `content_revision()`.
func json_safe_appearance() -> Dictionary:
	var safe: Dictionary = {}
	for key in appearance.keys():
		safe[str(key)] = json_safe_value(appearance[key])
	return safe


static func json_safe_value(value: Variant) -> Variant:
	if value is Color:
		return (value as Color).to_html(false)
	if value is Vector2 or value is Vector2i:
		return [value.x, value.y]
	if value is Vector3 or value is Vector3i:
		return [value.x, value.y, value.z]
	if value is StringName:
		return String(value)
	return value


## Deserializes an object from the current blueprint format.
static func from_dict(data: Dictionary) -> FillObjectRecord:
	var record := FillObjectRecord.new()
	record.id = String(data.get("id", ""))
	record.asset_id = StringName(data.get("asset_id", ""))
	record.owner_zone_id = StringName(data.get("owner_zone", ""))
	record.pos = _arr_to_vec3(data.get("pos", []), Vector3.ZERO)
	record.rot = _arr_to_vec3(data.get("rot", []), Vector3.ZERO)
	record.scale = _arr_to_vec3(data.get("scale", []), Vector3.ONE)
	var raw_appearance: Variant = data.get("appearance", {})
	record.appearance = (raw_appearance as Dictionary).duplicate() if raw_appearance is Dictionary else {}
	return record


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.strip_edges().is_empty():
		errors.append("Fill object has an empty id")
	if asset_id == &"":
		errors.append("Fill object %s has no asset_id" % id)
	for component in [pos.x, pos.y, pos.z, rot.x, rot.y, rot.z]:
		if not is_finite(component):
			errors.append("Fill object %s has a non-finite transform" % id)
			break
	if scale.x <= 0.0 or scale.y <= 0.0 or scale.z <= 0.0:
		errors.append("Fill object %s has a non-positive scale" % id)
	return errors


## Validates this record against a known asset definition. When `asset` is null
## (the asset is not installed), only a soft warning is returned — the file must
## still load. Scale, rotation and collision policy are checked against
## the asset's declared constraints.
func validation_errors_with_asset(asset: Variant) -> Array[String]:
	var errors := validation_errors()
	if asset == null:
		return errors
	# Scale: must be uniform and allowed by the asset's scale policy.
	var scale_val := scale.x
	if not is_equal_approx(scale.x, scale.y) or not is_equal_approx(scale.x, scale.z):
		errors.append("Fill object %s has non-uniform scale (%.3f, %.3f, %.3f)" % [id, scale.x, scale.y, scale.z])
	elif not asset.is_scale_allowed(scale_val):
		errors.append("Fill object %s has scale %.3f which is not allowed by asset %s" % [id, scale_val, asset.id])
	# Rotation: only allowed axes may have non-zero rotation.
	if not is_equal_approx(rot.x, 0.0) and not asset.is_rotation_axis_allowed("x"):
		errors.append("Fill object %s rotates on X axis but asset %s does not allow it" % [id, asset.id])
	if not is_equal_approx(rot.z, 0.0) and not asset.is_rotation_axis_allowed("z"):
		errors.append("Fill object %s rotates on Z axis but asset %s does not allow it" % [id, asset.id])
	# Collision policy: must be a known value.
	var valid_policies := [
		WorldAssetDef.COLLISION_NONE,
		WorldAssetDef.COLLISION_BOX,
		WorldAssetDef.COLLISION_SCENE,
		WorldAssetDef.COLLISION_FOOTPRINT,
	]
	if not (asset.collision_policy in valid_policies):
		errors.append("Fill object %s: asset %s has unknown collision policy %s" % [id, asset.id, asset.collision_policy])
	return errors


static func _arr_to_vec3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback
