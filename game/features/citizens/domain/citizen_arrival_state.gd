class_name CitizenArrivalState
extends RefCounted

## Deterministic arrival and greeting logistics state for a citizen.
## No nodes, physics, rendering, simulation, or wall-clock time.

var position := Vector3.INF
var pending_entrance := Vector3.INF


func has_pending() -> bool:
	return pending_entrance != Vector3.INF


func consume_pending() -> Vector3:
	var entrance := pending_entrance
	pending_entrance = Vector3.INF
	return entrance
