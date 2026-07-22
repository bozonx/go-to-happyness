class_name WaterCollectorRecord
extends RefCounted

## Mutable runtime state for one dew/water collector building.

var node: Node3D = null
var rate: float = 0.12
var accum: float = 0.0
var stored: int = 0
var capacity: int = 10


func _init(
	next_node: Node3D = null,
	next_rate: float = 0.12,
	next_accum: float = 0.0,
	next_stored: int = 0,
	next_capacity: int = 10,
) -> void:
	node = next_node
	rate = next_rate
	accum = next_accum
	stored = next_stored
	capacity = next_capacity
