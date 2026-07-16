class_name CourierTask
extends RefCounted

enum Kind { CANTEEN, TRADE, CONSTRUCTION, BUILDING_SUPPLY, SAWMILL_PICKUP, WORKER_PICKUP, DEW_PICKUP, ARRIVAL, OUTSIDE_WORK }

var id: StringName
var kind: Kind
var priority := 0
var pickup := Vector3.ZERO
var dropoff := Vector3.ZERO
var payload: Dictionary = {}
var created_at := 0.0
var assigned_courier_id := -1
## Warehouse reservation made when the task was assigned; used to free space if the delivery is cancelled.
var reserved_warehouse_index := -1
var reserved_resource_type := ""
var reserved_amount := 0


func is_assigned() -> bool:
	return assigned_courier_id >= 0


func has_reservation() -> bool:
	return reserved_warehouse_index >= 0 and reserved_amount > 0 and not reserved_resource_type.is_empty()
