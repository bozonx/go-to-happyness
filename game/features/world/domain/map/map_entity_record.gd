class_name MapEntityRecord
extends RefCounted

## One named, individually authored thing standing on a map
## (design_docs/engine/map_fill_mode.md §4, §8.1).
##
## Anonymous mass placement belongs to the future binary scatter layer.  This
## record deliberately covers the first Fill Mode slice: stable identity,
## archetype reference and a transform that remains attached to the terrain.

var id: StringName = &""
var archetype_id: StringName = &""
var position := Vector3.ZERO
var yaw_degrees := 0.0
var scale := 1.0
var initial_state: StringName = EntityStateSet.FOLLOW_SEASON
var props: Dictionary = {}
var tags: Array[StringName] = []
var activity: StringName = &""


func cell(terrain: TerrainGrid) -> Vector2i:
	return terrain.cell_from_position(position)


func to_dict() -> Dictionary:
	var result: Dictionary = {
		"id": String(id),
		"archetype": String(archetype_id),
		"transform": {
			"position": [position.x, position.y, position.z],
			"yaw": yaw_degrees,
			"scale": scale,
		},
	}
	if initial_state != EntityStateSet.FOLLOW_SEASON:
		result["state"] = String(initial_state)
	if not props.is_empty():
		result["props"] = _json_safe(props)
	if not tags.is_empty():
		result["tags"] = tags.map(func(tag: StringName) -> String: return String(tag))
	if activity != &"":
		result["activity"] = String(activity)
	return result


static func from_dict(source: Dictionary) -> MapEntityRecord:
	var record := MapEntityRecord.new()
	record.id = StringName(source.get("id", ""))
	record.archetype_id = StringName(source.get("archetype", ""))
	var transform: Variant = source.get("transform", {})
	if transform is Dictionary:
		var raw_position: Variant = (transform as Dictionary).get("position", [])
		if raw_position is Array and (raw_position as Array).size() >= 3:
			record.position = Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
		record.yaw_degrees = float((transform as Dictionary).get("yaw", 0.0))
		record.scale = maxf(float((transform as Dictionary).get("scale", 1.0)), 0.01)
	var state := StringName(source.get("state", EntityStateSet.FOLLOW_SEASON))
	if state != &"":
		record.initial_state = state
	var raw_props: Variant = source.get("props", {})
	if raw_props is Dictionary:
		record.props = (raw_props as Dictionary).duplicate(true)
	for tag: Variant in source.get("tags", []):
		record.tags.append(StringName(tag))
	record.activity = StringName(source.get("activity", ""))
	return record


func is_valid() -> bool:
	return id != &"" and archetype_id != &""


## Entity props are deliberately open data. Convert Godot value types here at the
## persistence boundary so the generic inspector can safely author vectors and
## colours without every component inventing its own JSON codec.
static func _json_safe(value: Variant) -> Variant:
	if value is Color:
		return (value as Color).to_html(true)
	if value is Vector2:
		var vector2 := value as Vector2
		return [vector2.x, vector2.y]
	if value is Vector3:
		var vector3 := value as Vector3
		return [vector3.x, vector3.y, vector3.z]
	if value is Array:
		var array: Array = []
		for item: Variant in value as Array:
			array.append(_json_safe(item))
		return array
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key: Variant in (value as Dictionary).keys():
			dictionary[key] = _json_safe((value as Dictionary)[key])
		return dictionary
	return value
