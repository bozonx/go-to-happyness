class_name ActiveWorkZoneState
extends RefCounted

## Runtime state of one authored active zone. Positions remain local to the
## building; presentation/application adapters resolve them to world space.

var zone_id: StringName = &""
var zone_name: String = ""
var kind: StringName = &"workplace"
## Recreation flavour / special marker (LEISURE_SUBTYPES / SPECIAL_SUBTYPES), or
## empty for flat kinds. Preserved so leisure zones know which need they satisfy.
var subtype: StringName = &""
var profession: StringName = &""
var max_workers: int = 0
var cells: Array[Vector3i] = []
var work_anchors: Array[Dictionary] = []
var storage_trays: Dictionary = {}
var assigned_citizen_ids: Array[int] = []


static func from_definition(data: Dictionary) -> RefCounted:
	var state := new()
	state.zone_id = StringName(data.get("id", ""))
	state.zone_name = str(data.get("name", ""))
	state.kind = StringName(data.get("kind", "workplace"))
	state.subtype = StringName(data.get("subtype", ""))
	state.profession = StringName(data.get("profession_type", ""))
	state.max_workers = maxi(0, int(data.get("max_workers", 0)))
	for raw_cell in data.get("cells", []):
		if raw_cell is Array and raw_cell.size() >= 3:
			state.cells.append(Vector3i(int(raw_cell[0]), int(raw_cell[1]), int(raw_cell[2])))
	for raw_anchor in data.get("work_anchors", []):
		if raw_anchor is Dictionary:
			state.work_anchors.append((raw_anchor as Dictionary).duplicate(true))
	state.storage_trays = data.get("storage_trays", {}).duplicate(true) if data.get("storage_trays", {}) is Dictionary else {}
	for citizen_id in data.get("assigned_citizen_ids", []):
		var parsed_id := int(citizen_id)
		if parsed_id > 0 and parsed_id not in state.assigned_citizen_ids:
			state.assigned_citizen_ids.append(parsed_id)
	return state


func supports_role(role: StringName) -> bool:
	return profession == role and max_workers > 0 and kind in [&"workplace", &"civic", &"trade"]


func has_capacity() -> bool:
	return assigned_citizen_ids.size() < max_workers


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


func anchor_for(citizen_id: int) -> Dictionary:
	if work_anchors.is_empty():
		return {}
	var index := assigned_citizen_ids.find(citizen_id)
	if index < 0:
		index = 0
	return work_anchors[index % work_anchors.size()]


## Local occupancy point when the zone has no authored work slots: the centroid
## of its cells (design §3.4 — "citizens occupy places randomly within cells").
func fallback_position() -> Vector3:
	if cells.is_empty():
		return Vector3.INF
	var sum := Vector3.ZERO
	for cell in cells:
		sum += Vector3(cell) + Vector3(0.5, 0.0, 0.5)
	return sum / cells.size()


func to_dict() -> Dictionary:
	return {
		"id": String(zone_id),
		"name": zone_name,
		"kind": String(kind),
		"subtype": String(subtype),
		"profession_type": String(profession),
		"max_workers": max_workers,
		"cells": cells.map(func(cell: Vector3i): return [cell.x, cell.y, cell.z]),
		"work_anchors": work_anchors.duplicate(true),
		"storage_trays": storage_trays.duplicate(true),
		"assigned_citizen_ids": assigned_citizen_ids.duplicate(),
	}
