class_name ZoneRuntimeState
extends RefCounted

## Runtime state of one authored area on a built instance
## (design_docs/engine/active_zones.md §9).
##
## The engine keeps geometry and occupancy here and nothing else. Whether this
## zone employs a cook, houses four residents or is a respawn room is read out of
## `function`/`properties`, which a content pack authored — so the same runtime
## carries a settlement, an RPG inn and a shooter objective without knowing what
## any of them are.
##
## Positions stay local to the building; presentation resolves them to world
## space.

var zone_id: StringName = &""
var zone_name: String = ""
var role: StringName = ZoneAreaRecord.ROLE_ROOM
## Pack-defined meaning and its parameters. Never interpreted by the engine.
var function: StringName = &""
var properties: Dictionary = {}
var slots: Array[Dictionary] = []
var queue: Array[Dictionary] = []
var storage: Array[Dictionary] = []
## Where a citizen stands when the zone has no authored slots.
var fallback_pos: Vector3 = Vector3.INF
var assigned_citizen_ids: Array[int] = []


static func from_definition(data: Dictionary) -> ZoneRuntimeState:
	var state := ZoneRuntimeState.new()
	state.zone_id = StringName(data.get("id", ""))
	state.zone_name = String(data.get("name", ""))
	state.role = StringName(data.get("role", ZoneAreaRecord.ROLE_ROOM))
	state.function = StringName(data.get("function", ""))
	var raw_properties: Variant = data.get("properties", {})
	state.properties = (raw_properties as Dictionary).duplicate(true) if raw_properties is Dictionary else {}
	state.slots = _dict_list(data.get("slots", []))
	state.queue = _dict_list(data.get("queue", []))
	state.storage = _dict_list(data.get("storage", []))
	var raw_fallback: Variant = data.get("fallback_pos", [])
	if raw_fallback is Array and raw_fallback.size() >= 3:
		state.fallback_pos = Vector3(float(raw_fallback[0]), float(raw_fallback[1]), float(raw_fallback[2]))
	for citizen_id in data.get("assigned_citizen_ids", []):
		var parsed_id := int(citizen_id)
		if parsed_id > 0 and parsed_id not in state.assigned_citizen_ids:
			state.assigned_citizen_ids.append(parsed_id)
	return state


## Profession this zone staffs, as declared by its function's properties.
func profession() -> StringName:
	return StringName(properties.get("profession", ""))


func max_workers() -> int:
	return maxi(0, int(properties.get("max_workers", 0)))


func supports_role(citizen_role: StringName) -> bool:
	return citizen_role != &"" and profession() == citizen_role and max_workers() > 0


func has_capacity() -> bool:
	return assigned_citizen_ids.size() < max_workers()


func assign(citizen_id: int) -> bool:
	if citizen_id <= 0:
		return false
	if citizen_id in assigned_citizen_ids:
		return true
	if not has_capacity():
		return false
	assigned_citizen_ids.append(citizen_id)
	return true


func unassign(citizen_id: int) -> void:
	assigned_citizen_ids.erase(citizen_id)


## The slot a citizen works. Slots are capacity-1 by definition, so assignment
## order picks one; when the author left no slots, the zone centre is used.
func slot_for(citizen_id: int) -> Dictionary:
	if slots.is_empty():
		return {}
	var index := assigned_citizen_ids.find(citizen_id)
	if index < 0:
		index = 0
	return slots[index % slots.size()]


func position_for(citizen_id: int) -> Vector3:
	var slot := slot_for(citizen_id)
	if slot.is_empty():
		return fallback_pos
	var raw_pos: Variant = slot.get("pos", [])
	if raw_pos is Array and raw_pos.size() >= 3:
		return Vector3(float(raw_pos[0]), float(raw_pos[1]), float(raw_pos[2]))
	return fallback_pos


## Place in the line leading to a slot, for citizens waiting their turn.
func queue_position(place_in_line: int) -> Vector3:
	for entry in queue:
		if int(entry.get("index", -1)) == place_in_line:
			var raw_pos: Variant = entry.get("pos", [])
			if raw_pos is Array and raw_pos.size() >= 3:
				return Vector3(float(raw_pos[0]), float(raw_pos[1]), float(raw_pos[2]))
	return Vector3.INF


func queue_length() -> int:
	return queue.size()


func storage_capacity(direction: StringName) -> int:
	var total := 0
	for entry in storage:
		if StringName(entry.get("direction", "")) == direction:
			total += int(entry.get("capacity", 0))
	return total


func to_dict() -> Dictionary:
	return {
		"id": String(zone_id),
		"name": zone_name,
		"role": String(role),
		"function": String(function),
		"properties": properties.duplicate(true),
		"slots": slots.duplicate(true),
		"queue": queue.duplicate(true),
		"storage": storage.duplicate(true),
		"fallback_pos": [fallback_pos.x, fallback_pos.y, fallback_pos.z],
		"assigned_citizen_ids": assigned_citizen_ids.duplicate(),
	}


static func _dict_list(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result
