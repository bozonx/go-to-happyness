class_name BuildingZoneService
extends RefCounted

## Instantiates authored zone definitions on completed modular buildings and
## reconciles stable citizen assignments. It does not steer citizens; AI reads
## the selected anchor through the world facade.

const BuildingRuntimeStateScript = preload("res://game/features/buildings/application/building_runtime_state.gd")
const ActiveWorkZoneStateScript = preload("res://game/features/buildings/domain/active_work_zone_state.gd")
const SUPPORTED_AI_ROLES: Array[StringName] = [&"cook", &"teacher", &"seller", &"craftsman"]


func configure_building(building: Node3D, zone_definitions: Array, saved_zones: Array = []) -> void:
	if not is_instance_valid(building):
		return
	var source := saved_zones if not saved_zones.is_empty() else zone_definitions
	var state := BuildingRuntimeStateScript.from_node(building)
	state.work_zones.clear()
	for raw_zone in source:
		if raw_zone is Dictionary:
			state.work_zones.append(ActiveWorkZoneStateScript.from_definition(raw_zone))
	state.apply_to_node(building)
	var first_anchor := _first_anchor(state)
	if first_anchor != Vector3.INF:
		building.set_meta("service_position", _to_world(building, first_anchor))


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
		if existing_state.work_zones.is_empty():
			continue
		for zone in existing_state.work_zones:
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
		if state.work_zones.is_empty():
			continue
		for zone in state.work_zones:
			if citizen_id in zone.assigned_citizen_ids and not zone.supports_role(role):
				zone.unassign(citizen_id)
			if zone.supports_role(role) and state.zone_for_citizen(citizen_id, role) == null:
				zone.assign(citizen_id)
		touched[workplace] = state
	for building in touched:
		var state: RefCounted = touched[building]
		state.apply_to_node(building)


func supports_role(building: Node3D, role: StringName) -> bool:
	return role in SUPPORTED_AI_ROLES and is_instance_valid(building) and BuildingRuntimeStateScript.from_node(building).role_capacity(role) > 0


func role_capacity(building: Node3D, role: StringName) -> int:
	return BuildingRuntimeStateScript.from_node(building).role_capacity(role) if role in SUPPORTED_AI_ROLES and is_instance_valid(building) else 0


func assign_to_zone(building: Node3D, zone_id: StringName, role: StringName, citizen_id: int) -> bool:
	if not is_instance_valid(building) or zone_id == &"" or citizen_id <= 0:
		return false
	var state := BuildingRuntimeStateScript.from_node(building)
	var target: Variant = null
	for zone in state.work_zones:
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
	var zone: Variant = state.zone_for_citizen(citizen_id, role)
	if zone == null:
		for candidate in state.work_zones:
			if candidate.supports_role(role):
				zone = candidate
				break
	if zone == null:
		return Vector3.INF
	var anchor: Dictionary = zone.anchor_for(citizen_id)
	var raw_pos: Variant = anchor.get("pos", [])
	if raw_pos is Array and raw_pos.size() >= 3:
		return _to_world(building, Vector3(float(raw_pos[0]), float(raw_pos[1]), float(raw_pos[2])))
	return building.global_position


func zone_snapshot(building: Node3D) -> Array:
	return BuildingRuntimeStateScript.from_node(building).zones_to_dict() if is_instance_valid(building) else []


func zone_id_for(building: Node3D, role: StringName, citizen_id: int) -> StringName:
	if not is_instance_valid(building):
		return &""
	var zone: Variant = BuildingRuntimeStateScript.from_node(building).zone_for_citizen(citizen_id, role)
	return zone.zone_id if zone != null else &""


func _first_anchor(state: RefCounted) -> Vector3:
	for zone in state.work_zones:
		if zone.work_anchors.is_empty():
			continue
		var raw_pos: Variant = zone.work_anchors[0].get("pos", [])
		if raw_pos is Array and raw_pos.size() >= 3:
			return Vector3(float(raw_pos[0]), float(raw_pos[1]), float(raw_pos[2]))
	return Vector3.INF


func _to_world(building: Node3D, local_position: Vector3) -> Vector3:
	if building.is_inside_tree():
		return building.to_global(local_position)
	return building.position + local_position.rotated(Vector3.UP, building.rotation.y)
