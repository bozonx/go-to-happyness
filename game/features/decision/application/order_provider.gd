class_name OrderProvider
extends RefCounted

## A global scheduling policy. Providers publish a complete set of current
## proposals on each director tick, allowing stale assignments to be reconciled.

var id: StringName


func _init(next_id: StringName = &"") -> void:
	id = next_id


func collect_orders(_snapshot: WorldSnapshot) -> Array[CitizenOrder]:
	return []
