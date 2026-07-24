class_name BuildingRegistry
extends RefCounted

## Owns occupied building footprints from construction reservation through removal.
## It deliberately stores runtime nodes here because it is an application registry;
## immutable building definitions remain in the buildings domain.

const BuildingRuntimeStateScript = preload("res://game/features/buildings/application/building_runtime_state.gd")

var _records: Array[BuildingRecord] = []
var _records_by_cell: Dictionary = {}


func reserve(cell: Vector2i, center: Vector3, footprint: Vector2i) -> BuildingRecord:
	var existing := record_at_cell(cell)
	if existing != null:
		return existing
	var record := BuildingRecord.new(cell, center, footprint)
	_records.append(record)
	_records_by_cell[cell] = record
	return record


func attach_node(cell: Vector2i, node: Node3D, building_type: String = "") -> BuildingRecord:
	var record := record_at_cell(cell)
	if record == null:
		return null
	record.node = node
	record.building_type = building_type
	return record


func cancel_reservation(cell: Vector2i) -> BuildingRecord:
	var record := record_at_cell(cell)
	if record == null or is_instance_valid(record.node):
		return null
	return _remove(record)


func record_for_node(node: Node3D) -> BuildingRecord:
	for record in _records:
		if record.node == node:
			return record
	return null


func building_type_for_node(node: Node3D) -> String:
	var record := record_for_node(node)
	if record != null:
		return record.building_type
	return str(node.get_meta("building_type", ""))


func remove_node(node: Node3D) -> BuildingRecord:
	for record in _records:
		if record.node == node:
			return _remove(record)
	return null


func record_at_cell(cell: Vector2i) -> BuildingRecord:
	return _records_by_cell.get(cell) as BuildingRecord


func records() -> Array[BuildingRecord]:
	return _records.duplicate()


func positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for record in _records:
		positions.append(record.center)
	return positions


func is_footprint_clear(center: Vector3, footprint: Vector2i, clearance: float) -> bool:
	var half := Vector2(footprint.x, footprint.y) * 0.5
	for record in _records:
		var other_half := Vector2(record.footprint.x, record.footprint.y) * 0.5
		if absf(center.x - record.center.x) < half.x + other_half.x + clearance and absf(center.z - record.center.z) < half.y + other_half.y + clearance:
			return false
	return true


func housing_capacity() -> int:
	var count := 0
	for record in _records:
		if is_instance_valid(record.node):
			var state: BuildingRuntimeStateScript = record.runtime_state()
			count += state.housing_capacity
	return count


func building_at_service_position(position: Vector3) -> Node3D:
	for record in _records:
		if is_instance_valid(record.node):
			var state: BuildingRuntimeStateScript = record.runtime_state()
			var service_position: Vector3 = state.service_position if state.service_position != Vector3.INF else record.node.global_position
			if service_position.distance_squared_to(position) < 0.01:
				return record.node
	return null


func _remove(record: BuildingRecord) -> BuildingRecord:
	_records.erase(record)
	_records_by_cell.erase(record.cell)
	return record
