class_name BuildingRuntimeState
extends RefCounted

## Typed runtime state for a building node, replacing untyped get_meta/set_meta calls.
## Migrated gradually: fields here cover the most common meta keys used across the codebase.

## Whether this building is accepting new workers.
var accepting_workers: bool = true

## Position where citizens interact with the building (e.g. service counter).
var service_position: Vector3 = Vector3.INF

## Building condition (0-100). Below a threshold, repair is needed.
var condition: float = 100.0

## Whether the building currently needs repair.
var repair_needed: bool = false

## Whether a repair delivery is reserved for this building.
var repair_reserved: bool = false

## Day ID when night work (overtime) was last ordered for this building.
var night_work_order_day: int = -1

## How many factory workers this building requires.
var required_factory_workers: int = 1

## Housing capacity (number of residents this building can house).
var housing_capacity: int = 0
## Authored active zones instantiated on this building (active_zones.md §9).
var zones: Array[ZoneRuntimeState] = []
## Doors and top-level points, for navigation; occupancy never reads them.
var routing_anchors: Array = []
## Access overlays that apply inside this building.
var access_overlays: Array = []


static func from_node(node: Node3D) -> RefCounted:
	var state := new()
	state.accepting_workers = bool(node.get_meta("accepting_workers", true))
	if node.has_meta("service_position"):
		state.service_position = node.get_meta("service_position")
	state.condition = float(node.get_meta("condition", 100.0))
	state.repair_needed = bool(node.get_meta("repair_needed", false))
	state.repair_reserved = bool(node.get_meta("repair_reserved", false))
	state.night_work_order_day = int(node.get_meta("night_work_order_day", -1))
	state.required_factory_workers = int(node.get_meta("required_factory_workers", 1))
	state.housing_capacity = int(node.get_meta("housing_capacity", 0))
	var raw_zones: Variant = node.get_meta("active_zones", [])
	if raw_zones is Array:
		for raw_zone in raw_zones:
			if raw_zone is Dictionary:
				state.zones.append(ZoneRuntimeState.from_definition(raw_zone))
	var raw_routing: Variant = node.get_meta("routing_anchors", [])
	state.routing_anchors = (raw_routing as Array).duplicate(true) if raw_routing is Array else []
	var raw_access: Variant = node.get_meta("access_overlays", [])
	state.access_overlays = (raw_access as Array).duplicate(true) if raw_access is Array else []
	return state


func apply_to_node(node: Node3D) -> void:
	node.set_meta("accepting_workers", accepting_workers)
	if service_position != Vector3.INF:
		node.set_meta("service_position", service_position)
	node.set_meta("condition", condition)
	node.set_meta("repair_needed", repair_needed)
	node.set_meta("repair_reserved", repair_reserved)
	node.set_meta("night_work_order_day", night_work_order_day)
	node.set_meta("required_factory_workers", required_factory_workers)
	node.set_meta("housing_capacity", housing_capacity)
	node.set_meta("active_zones", zones_to_dict())
	node.set_meta("routing_anchors", routing_anchors)
	node.set_meta("access_overlays", access_overlays)


func zones_to_dict() -> Array:
	var result: Array = []
	for zone in zones:
		result.append(zone.to_dict())
	return result


func role_capacity(role: StringName) -> int:
	var capacity := 0
	for zone in zones:
		if zone.supports_role(role):
			capacity += zone.max_workers()
	return capacity


func zone_for_citizen(citizen_id: int, role: StringName) -> ZoneRuntimeState:
	for zone in zones:
		if zone.supports_role(role) and citizen_id in zone.assigned_citizen_ids:
			return zone
	return null


func zone_by_id(zone_id: StringName) -> ZoneRuntimeState:
	for zone in zones:
		if zone.zone_id == zone_id:
			return zone
	return null


## Whether an agent of this audience may stand on a building-local cell, after
## every access overlay of the building has been applied (active_zones.md §4).
func permits(cell: Vector2i, audience: StringName) -> bool:
	for raw_overlay in access_overlays:
		if not (raw_overlay is Dictionary):
			continue
		var overlay: ZoneAreaRecord = ZoneAreaRecord.from_dict(raw_overlay)
		if overlay.contains_cell(cell) and not overlay.permits(audience):
			return false
	return true
