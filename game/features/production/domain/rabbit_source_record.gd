class_name RabbitSourceRecord
extends RefCounted

## Runtime state for one rabbit meadow animal that roams and can be hunted.

var node: Node3D = null
var direction: Vector3 = Vector3.ZERO


func _init(next_node: Node3D = null, next_direction: Vector3 = Vector3.ZERO) -> void:
	node = next_node
	direction = next_direction
