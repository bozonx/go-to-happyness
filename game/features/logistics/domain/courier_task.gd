class_name CourierTask
extends RefCounted

enum Kind { CANTEEN, TRADE, CONSTRUCTION, BUILDING_SUPPLY, SAWMILL_PICKUP, WORKER_PICKUP, DEW_PICKUP }

var id: StringName
var kind: Kind
var priority := 0
var pickup := Vector3.ZERO
var dropoff := Vector3.ZERO
var payload: Dictionary = {}
var created_at := 0.0
var assigned_courier_id := -1


func is_assigned() -> bool:
	return assigned_courier_id >= 0
