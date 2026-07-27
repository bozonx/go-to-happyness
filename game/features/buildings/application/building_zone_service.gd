class_name BuildingZoneService
extends RefCounted

## Instantiates authored zone definitions on completed modular buildings and
## reconciles stable citizen assignments. It does not steer citizens; AI reads
## the selected anchor through the world facade.

const BuildingRuntimeStateScript = preload("res://game/features/buildings/application/building_runtime_state.gd")


## Instantiates the authored definitions and **lays saved session state over
## them** (active_zones.md §9). The definition always comes from the file: a save
## that replaced it wholesale would freeze the building's markup at the moment it
## was saved, so a content patch would never reach anyone already playing.
func configure_building(building: Node3D, zone_definitions: Array, saved_zones: Array = []) -> void:
	if not is_instance_valid(building):
		return
	var saved_by_id: Dictionary = {}
	for raw_saved in saved_zones:
		if raw_saved is Dictionary:
			saved_by_id[StringName((raw_saved as Dictionary).get("id", ""))] = raw_saved
	var state := BuildingRuntimeStateScript.from_node(building)
	state.zones.clear()
	for raw_zone in zone_definitions:
		if not (raw_zone is Dictionary):
			continue
		var zone := ZoneRuntimeState.from_definition(raw_zone)
		var saved: Variant = saved_by_id.get(zone.zone_id)
		if saved is Dictionary:
			zone.apply_session_state(saved)
		state.zones.append(zone)
	state.apply_to_node(building)
	var first_slot := _first_slot(state)
	if first_slot != Vector3.INF:
		building.set_meta("service_position", _to_world(building, first_slot))


func reconcile_assignments(citizens: Array, building_records: Array = []) -> void:
	var touched: Dictionary = {}
	var valid_assignments: Dictionary = {}
	for citizen in citizens:
		if is_instance_valid(citizen) and is_instance_valid(citizen.employment_workplace):
			valid_assignments[int(citizen.ai_id)] = {
				"building": citizen.employment_workplace,
				"role": StringName(citizen.permanent_role),
			}
	for record in building_records:
		if not is_instance_valid(record.node):
			continue
		var existing_state: RefCounted = BuildingRuntimeStateScript.from_node(record.node)
		if existing_state.zones.is_empty():
			continue
		for zone in existing_state.zones:
			for citizen_id in zone.assigned_citizen_ids.duplicate():
				var assignment: Dictionary = valid_assignments.get(citizen_id, {})
				if assignment.is_empty() or assignment.get("building") != record.node or not zone.supports_role(StringName(assignment.get("role", &""))):
					zone.unassign(citizen_id)
		touched[record.node] = existing_state
	for citizen in citizens:
		if not is_instance_valid(citizen):
			continue
		var workplace: Node3D = citizen.employment_workplace
		if not is_instance_valid(workplace):
			continue
		var role := StringName(citizen.permanent_role)
		var citizen_id := int(citizen.ai_id)
		var state: RefCounted = touched.get(workplace, BuildingRuntimeStateScript.from_node(workplace))
		if state.zones.is_empty():
			continue
		for zone in state.zones:
			if citizen_id in zone.assigned_citizen_ids and not zone.supports_role(role):
				zone.unassign(citizen_id)
			if zone.supports_role(role) and state.zone_for_citizen(citizen_id, role) == null:
				zone.assign(citizen_id)
		touched[workplace] = state
	for building in touched:
		var state: RefCounted = touched[building]
		state.apply_to_node(building)


## Whether the building has a zone staffing this role. There is no engine-side
## list of valid roles any more: a role is valid exactly when some zone function
## declares it (active_zones.md §2), so the question is answered by the data.
func supports_role(building: Node3D, role: StringName) -> bool:
	return role != &"" and is_instance_valid(building) and BuildingRuntimeStateScript.from_node(building).role_capacity(role) > 0


func role_capacity(building: Node3D, role: StringName) -> int:
	return BuildingRuntimeStateScript.from_node(building).role_capacity(role) if role != &"" and is_instance_valid(building) else 0


func assign_to_zone(building: Node3D, zone_id: StringName, role: StringName, citizen_id: int) -> bool:
	if not is_instance_valid(building) or zone_id == &"" or citizen_id <= 0:
		return false
	var state := BuildingRuntimeStateScript.from_node(building)
	var target: ZoneRuntimeState = null
	for zone in state.zones:
		zone.unassign(citizen_id)
		if zone.zone_id == zone_id:
			target = zone
	if target == null or not target.supports_role(role) or not target.assign(citizen_id):
		state.apply_to_node(building)
		return false
	state.apply_to_node(building)
	return true


func work_position(building: Node3D, role: StringName, citizen_id: int) -> Vector3:
	if not is_instance_valid(building):
		return Vector3.INF
	var state := BuildingRuntimeStateScript.from_node(building)
	var zone: ZoneRuntimeState = state.zone_for_citizen(citizen_id, role)
	if zone == null:
		for candidate in state.zones:
			if candidate.supports_role(role) and candidate.assign(citizen_id):
				zone = candidate
				break
	if zone == null:
		return Vector3.INF
	# The slot, or the zone centre when the author placed no slots (§5.2).
	var local := zone.position_for(citizen_id)
	state.apply_to_node(building)
	return _to_world(building, local) if local != Vector3.INF else building.global_position


## What a save stores: session state only (§13). Definitions are re-read from the
## blueprint on load, so re-marked buildings reach old saves.
func zone_state_snapshot(building: Node3D) -> Array:
	if not is_instance_valid(building):
		return []
	var snapshot: Array = []
	for zone in BuildingRuntimeStateScript.from_node(building).zones:
		snapshot.append(zone.session_state_to_dict())
	return snapshot


## Owner of a zone (§13). Changing it is a rule's business, not the engine's —
## the service only stores the change and reports whether anything moved.
func set_zone_owner(building: Node3D, zone_id: StringName, owner_tag: StringName) -> bool:
	if not is_instance_valid(building):
		return false
	var state := BuildingRuntimeStateScript.from_node(building)
	var zone: ZoneRuntimeState = state.zone_by_id(zone_id)
	if zone == null or not zone.set_owner(owner_tag):
		return false
	state.apply_to_node(building)
	return true


func zone_owner(building: Node3D, zone_id: StringName) -> StringName:
	if not is_instance_valid(building):
		return &""
	var zone: ZoneRuntimeState = BuildingRuntimeStateScript.from_node(building).zone_by_id(zone_id)
	return zone.owner_tag if zone != null else &""


func set_zone_flag(building: Node3D, zone_id: StringName, key: StringName, value: Variant) -> bool:
	if not is_instance_valid(building):
		return false
	var state := BuildingRuntimeStateScript.from_node(building)
	var zone: ZoneRuntimeState = state.zone_by_id(zone_id)
	if zone == null or not zone.set_flag(key, value):
		return false
	state.apply_to_node(building)
	return true


func zone_flag(building: Node3D, zone_id: StringName, key: StringName, fallback: Variant = null) -> Variant:
	if not is_instance_valid(building):
		return fallback
	var zone: ZoneRuntimeState = BuildingRuntimeStateScript.from_node(building).zone_by_id(zone_id)
	return zone.flag(key, fallback) if zone != null else fallback


## Frees the place a citizen held, whatever building it was in. Called when a
## task is interrupted: a reservation that outlives its task takes a slot out of
## circulation for good (§13).
func release_slot(building: Node3D, citizen_id: int) -> void:
	if not is_instance_valid(building):
		return
	var state := BuildingRuntimeStateScript.from_node(building)
	for zone in state.zones:
		zone.release_slot(citizen_id)
	state.apply_to_node(building)


func zone_id_for(building: Node3D, role: StringName, citizen_id: int) -> StringName:
	if not is_instance_valid(building):
		return &""
	var zone: ZoneRuntimeState = BuildingRuntimeStateScript.from_node(building).zone_for_citizen(citizen_id, role)
	return zone.zone_id if zone != null else &""


func _first_slot(state: RefCounted) -> Vector3:
	for zone in state.zones:
		if zone.slots.is_empty():
			continue
		var raw_pos: Variant = zone.slots[0].get("pos", [])
		if raw_pos is Array and raw_pos.size() >= 3:
			return Vector3(float(raw_pos[0]), float(raw_pos[1]), float(raw_pos[2]))
	return Vector3.INF


func _to_world(building: Node3D, local_position: Vector3) -> Vector3:
	if building.is_inside_tree():
		return building.to_global(local_position)
	return building.position + local_position.rotated(Vector3.UP, building.rotation.y)
