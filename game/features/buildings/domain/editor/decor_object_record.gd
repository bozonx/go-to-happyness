class_name DecorObjectRecord
extends RefCounted

## A single placed decor object inside a building blueprint — the `objects[]`
## entries of `.gdbuilding.json` (design_docs/content/modular_building_editor.md
## §3.3). Typed counterpart of BlueprintBlock / ZoneAnchorRecord: the editor and
## the runtime both work on records, and only (de)serialization touches raw
## dictionaries.
##
## `properties` holds the asset's authored control values. Values are kept
## JSON-safe (Color is stored as an html string), because the whole blueprint is
## hashed via `JSON.stringify` for `content_revision()`.

var id: String = ""
var asset_id: StringName = &""
var pos: Vector3 = Vector3.ZERO
var rot: Vector3 = Vector3.ZERO  ## degrees
var scale: Vector3 = Vector3.ONE
## In-cell 3×3 selector, each component ∈ {−1, 0, +1}; see design §3.3.
var anchor: Vector2i = Vector2i.ZERO
var properties: Dictionary = {}


static func make(p_asset_id: StringName, p_pos: Vector3, unique_suffix: int) -> DecorObjectRecord:
	var record := DecorObjectRecord.new()
	record.id = "decor_%s_%d" % [String(p_asset_id), unique_suffix]
	record.asset_id = p_asset_id
	record.pos = p_pos
	return record


func duplicate_record(unique_suffix: int) -> DecorObjectRecord:
	var copy := DecorObjectRecord.new()
	copy.id = "decor_%s_%d" % [String(asset_id), unique_suffix]
	copy.asset_id = asset_id
	copy.pos = pos
	copy.rot = rot
	copy.scale = scale
	copy.anchor = anchor
	copy.properties = properties.duplicate(true)
	return copy


func to_dict() -> Dictionary:
	return {
		"id": id,
		"asset_id": String(asset_id),
		"pos": [pos.x, pos.y, pos.z],
		"rot": [rot.x, rot.y, rot.z],
		"scale": [scale.x, scale.y, scale.z],
		"anchor": [anchor.x, anchor.y],
		"properties": json_safe_properties(),
	}


## Properties with engine types flattened to JSON primitives. Controls hand out
## `Color` defaults, which `JSON.stringify` cannot encode — storing them raw broke
## both save and `content_revision()`.
func json_safe_properties() -> Dictionary:
	var safe: Dictionary = {}
	for key in properties.keys():
		safe[str(key)] = json_safe_value(properties[key])
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


static func from_dict(data: Dictionary) -> DecorObjectRecord:
	var record := DecorObjectRecord.new()
	record.id = String(data.get("id", ""))
	record.asset_id = StringName(data.get("asset_id", ""))
	record.pos = _arr_to_vec3(data.get("pos", []), Vector3.ZERO)
	record.rot = _arr_to_vec3(data.get("rot", []), Vector3.ZERO)
	record.scale = _arr_to_vec3(data.get("scale", []), Vector3.ONE)
	record.anchor = _arr_to_vec2i(data.get("anchor", []))
	var raw_props: Variant = data.get("properties", {})
	record.properties = (raw_props as Dictionary).duplicate() if raw_props is Dictionary else {}
	return record


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.strip_edges().is_empty():
		errors.append("Decor object has an empty id")
	if asset_id == &"":
		errors.append("Decor object %s has no asset_id" % id)
	for component in [pos.x, pos.y, pos.z, rot.x, rot.y, rot.z]:
		if not is_finite(component):
			errors.append("Decor object %s has a non-finite transform" % id)
			break
	if scale.x <= 0.0 or scale.y <= 0.0 or scale.z <= 0.0:
		errors.append("Decor object %s has a non-positive scale" % id)
	for component in [anchor.x, anchor.y]:
		if component < -1 or component > 1:
			errors.append("Decor object %s has an out-of-range anchor" % id)
			break
	return errors


static func _arr_to_vec3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback


static func _arr_to_vec2i(value: Variant) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(clampi(int(value[0]), -1, 1), clampi(int(value[1]), -1, 1))
	return Vector2i.ZERO
