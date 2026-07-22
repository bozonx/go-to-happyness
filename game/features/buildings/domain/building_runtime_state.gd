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
