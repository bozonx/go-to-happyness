class_name ZoneRuntimeState
extends RefCounted

## Runtime state of one authored area on a built instance
## (design_docs/engine/active_zones.md §9, §13).
##
## The definition comes from the file and never changes; what lives here is the
## part that belongs to the session — occupancy, owner and flags — and it is what
## a save stores and lays back over the definition. Whether this zone employs a
## cook, houses four residents or is a respawn room is read out of
## `function`/`properties`, which a content pack authored, so the same runtime
## carries a settlement, an RPG inn and a shooter objective without knowing what
## any of them are.
##
## Positions are building-local (converted at the load boundary by
## `BuildingBlueprint.runtime_zone_definitions`); presentation resolves them to
## world space.

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

# --- Session state (§13). Saved, and laid over the definition on load. --------

var assigned_citizen_ids: Array[int] = []
## Who currently holds which slot: slot id → ai_id. A slot holds exactly one, and
## the entry *is* the reservation — "he seems to be standing there" is not a
## state anything can rely on.
var reservations: Dictionary = {}
## Whose the zone is right now: a faction tag, an `ai_id`, or empty. Only a rule
## changes it, and the change is what makes the relational `owner` audience work
## (§12): capture, purchase, rent and inheritance are all this one field.
var owner_tag: StringName = &""
## Named booleans and counters of the zone. The engine stores and publishes them
## and never reads their meaning.
var flags: Dictionary = {}


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
	state.apply_session_state(data)
	return state


## Lays saved session state over a definition read from the file (§9). Anything
## that no longer exists in the definition is dropped rather than restored: the
## author is allowed to re-mark a building, and an old save must survive it.
func apply_session_state(data: Dictionary) -> void:
	assigned_citizen_ids.clear()
	for citizen_id in data.get("assigned_citizen_ids", []):
		var parsed_id := int(citizen_id)
		if parsed_id > 0 and parsed_id not in assigned_citizen_ids:
			assigned_citizen_ids.append(parsed_id)
	owner_tag = StringName(data.get("owner", ""))
	var raw_flags: Variant = data.get("flags", {})
	flags = (raw_flags as Dictionary).duplicate(true) if raw_flags is Dictionary else {}
	reservations.clear()
	var raw_reservations: Variant = data.get("reservations", {})
	if raw_reservations is Dictionary:
		for slot_id in raw_reservations:
			var holder := int((raw_reservations as Dictionary)[slot_id])
			if holder > 0 and _slot_by_id(StringName(slot_id)) != -1:
				reservations[StringName(slot_id)] = holder
	_drop_stale_reservations()


## Profession this zone staffs, as declared by its function's properties.
func profession() -> StringName:
	return StringName(properties.get("profession", ""))


func max_workers() -> int:
	return maxi(0, int(properties.get("max_workers", 0)))


## Housing beds in this zone (`core:housing`'s `residents` property). Zero for
## non-housing zones and unmarked rooms, so a building's total is the sum.
func residents() -> int:
	return maxi(0, int(properties.get("residents", 0)))


## Cooked-food storage this zone supplies (`food_capacity` on kitchen, workplace
## and leisure functions). Zero means the zone is not a food source.
func food_capacity() -> int:
	return maxi(0, int(properties.get("food_capacity", 0)))


## Real capacity: a citizen without a place to stand is not employed here. When
## the author placed no slots at all the zone falls back to its centre, and the
## pack's number is taken at face value (§5.2).
func capacity() -> int:
	return mini(max_workers(), slots.size()) if not slots.is_empty() else max_workers()


func supports_role(citizen_role: StringName) -> bool:
	return citizen_role != &"" and profession() == citizen_role and capacity() > 0


func has_capacity() -> bool:
	return assigned_citizen_ids.size() < capacity()


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
	release_slot(citizen_id)


# --- Reservation (§13) -------------------------------------------------------

## The slot held by this citizen, reserving a free one on first ask. Capacity is
## one by definition, so two citizens can never share a place — which is exactly
## what index arithmetic over the slot list used to allow.
func reserve_slot(citizen_id: int) -> Dictionary:
	if citizen_id <= 0 or slots.is_empty():
		return {}
	var held := _slot_of(citizen_id)
	if not held.is_empty():
		return held
	for slot in slots:
		var slot_id := StringName(slot.get("id", ""))
		if slot_id == &"":
			continue
		if not reservations.has(slot_id):
			reservations[slot_id] = citizen_id
			return slot
	return {}


## Releases whatever this citizen held. Called on every interruption — a task cut
## short must not take a place out of circulation for the rest of the session.
func release_slot(citizen_id: int) -> void:
	for slot_id in reservations.keys():
		if int(reservations[slot_id]) == citizen_id:
			reservations.erase(slot_id)


func slot_holder(slot_id: StringName) -> int:
	return int(reservations.get(slot_id, 0))


func free_slot_count() -> int:
	return maxi(0, slots.size() - reservations.size())


func slot_for(citizen_id: int) -> Dictionary:
	return reserve_slot(citizen_id)


func position_for(citizen_id: int) -> Vector3:
	var slot := reserve_slot(citizen_id)
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


# --- Owner and flags (§13) ---------------------------------------------------

## Whether an agent carrying these tags counts as the owner of this zone. The
## `owner` audience is relational: it matches the zone's current owner rather
## than a fixed tag, which is what lets one piece of markup serve a private house
## in an RPG and a capture point in a shooter.
func is_owned_by(agent_tags: Array) -> bool:
	return owner_tag != &"" and owner_tag in agent_tags


func set_owner(new_owner: StringName) -> bool:
	if owner_tag == new_owner:
		return false
	owner_tag = new_owner
	return true


func set_flag(key: StringName, value: Variant) -> bool:
	if flags.get(key) == value:
		return false
	flags[key] = value
	return true


func flag(key: StringName, fallback: Variant = null) -> Variant:
	return flags.get(key, fallback)


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
		"reservations": _reservations_to_dict(),
		"owner": String(owner_tag),
		"flags": flags.duplicate(true),
	}


## Just the session part, for a save: the definition comes back from the file.
func session_state_to_dict() -> Dictionary:
	return {
		"id": String(zone_id),
		"assigned_citizen_ids": assigned_citizen_ids.duplicate(),
		"reservations": _reservations_to_dict(),
		"owner": String(owner_tag),
		"flags": flags.duplicate(true),
	}


func _reservations_to_dict() -> Dictionary:
	var result: Dictionary = {}
	for slot_id in reservations:
		result[String(slot_id)] = int(reservations[slot_id])
	return result


func _slot_of(citizen_id: int) -> Dictionary:
	for slot_id in reservations:
		if int(reservations[slot_id]) == citizen_id:
			var index := _slot_by_id(slot_id)
			if index != -1:
				return slots[index]
	return {}


func _slot_by_id(slot_id: StringName) -> int:
	for index in slots.size():
		if StringName(slots[index].get("id", "")) == slot_id:
			return index
	return -1


## A reservation held by someone who is no longer assigned here is stale — after
## a re-marked building or a restored save it would silently block a place.
func _drop_stale_reservations() -> void:
	for slot_id in reservations.keys():
		if int(reservations[slot_id]) not in assigned_citizen_ids:
			reservations.erase(slot_id)


static func _dict_list(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result
