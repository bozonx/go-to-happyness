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
## Авторская подстройка внутри своих клеток. Занятые клетки считаются по якорю
## (`position - offset`), поэтому смещение никогда не «переселяет» объект в
## соседнюю клетку и не ломает проверку занятости
## (`map_fill_mode.md` §9.3.1). Y — подъём над поверхностью.
var offset := Vector3.ZERO
## Whole authored blocks above the supporting surface. Fine vertical adjustment
## belongs to offset.y; keeping the two separate prevents X/Z moves from turning
## a terrain-height change into an apparent object jump.
var elevation_blocks := 0
var pitch_degrees := 0.0
var yaw_degrees := 0.0
var roll_degrees := 0.0
var scale := 1.0
var initial_state: StringName = EntityStateSet.FOLLOW_SEASON
var props: Dictionary = {}
## Visual overrides declared by the asset's appearance_controls. They are kept
## separate from gameplay props: a blue sign is not a game rule.
var appearance: Dictionary = {}
var tags: Array[StringName] = []
var activity: StringName = &""
## Pack-defined meaning, exactly as a zone carries one (`map_start.md` §6.5). The
## engine stores it and interprets only its own handful (`MapEntityFunction`).
var function: StringName = &""
## Start options this entity belongs to (§3.2). Empty — the default — means it
## exists always, which is every entity a v7 map ever authored. A non-empty list
## is what makes a cart at the north gate and a backpack at the south gate two
## genuinely different entrances without copying the map or branching a scenario.
var starts: Array[StringName] = []


## Whether this entity is created for the entrance the session begins at.
func belongs_to_start(option_id: StringName) -> bool:
	return starts.is_empty() or option_id in starts


## Клетка, которой объект принадлежит: она выводится из якоря, а не из
## итоговой позиции.
func cell(terrain: TerrainGrid) -> Vector2i:
	return terrain.cell_from_position(anchor_position())


func anchor_position() -> Vector3:
	return position - offset


func to_dict() -> Dictionary:
	var result: Dictionary = {
		"id": String(id),
		"archetype": String(archetype_id),
		"transform": {
			"position": [position.x, position.y, position.z],
			"offset": [offset.x, offset.y, offset.z],
			"elevation": elevation_blocks,
			"rotation": [pitch_degrees, yaw_degrees, roll_degrees],
			"yaw": yaw_degrees,
			"scale": scale,
		},
	}
	if initial_state != EntityStateSet.FOLLOW_SEASON:
		result["state"] = String(initial_state)
	if not props.is_empty():
		result["props"] = json_safe(props)
	if not appearance.is_empty():
		result["appearance"] = json_safe(appearance)
	if not tags.is_empty():
		result["tags"] = tags.map(func(tag: StringName) -> String: return String(tag))
	if activity != &"":
		result["activity"] = String(activity)
	if function != &"":
		result["function"] = String(function)
	if not starts.is_empty():
		result["starts"] = starts.map(func(value: StringName) -> String: return String(value))
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
		var raw_offset: Variant = (transform as Dictionary).get("offset", [])
		if raw_offset is Array and (raw_offset as Array).size() >= 3:
			record.offset = Vector3(float(raw_offset[0]), float(raw_offset[1]), float(raw_offset[2]))
		record.elevation_blocks = int((transform as Dictionary).get("elevation", 0))
		var raw_rotation: Variant = (transform as Dictionary).get("rotation", [])
		if raw_rotation is Array and (raw_rotation as Array).size() >= 3:
			record.pitch_degrees = float(raw_rotation[0])
			record.yaw_degrees = float(raw_rotation[1])
			record.roll_degrees = float(raw_rotation[2])
		else:
			record.yaw_degrees = float((transform as Dictionary).get("yaw", 0.0))
		record.scale = maxf(float((transform as Dictionary).get("scale", 1.0)), 0.01)
	var state := StringName(source.get("state", EntityStateSet.FOLLOW_SEASON))
	if state != &"":
		record.initial_state = state
	var raw_props: Variant = source.get("props", {})
	if raw_props is Dictionary:
		record.props = (raw_props as Dictionary).duplicate(true)
	var raw_appearance: Variant = source.get("appearance", {})
	if raw_appearance is Dictionary:
		record.appearance = (raw_appearance as Dictionary).duplicate(true)
	for tag: Variant in source.get("tags", []):
		record.tags.append(StringName(tag))
	record.activity = StringName(source.get("activity", ""))
	record.function = StringName(source.get("function", ""))
	for option_id: Variant in source.get("starts", []):
		record.starts.append(StringName(option_id))
	return record


func is_valid() -> bool:
	return id != &"" and archetype_id != &""


## Entity props are deliberately open data. Convert Godot value types here at the
## persistence boundary so the generic inspector can safely author vectors and
## colours without every component inventing its own JSON codec.
static func json_safe(value: Variant) -> Variant:
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
			array.append(json_safe(item))
		return array
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key: Variant in (value as Dictionary).keys():
			dictionary[key] = json_safe((value as Dictionary)[key])
		return dictionary
	return value
