class_name GrassSourceRecord
extends RefCounted

## Mutable runtime state for one grass source patch near a tree.

var node: Node3D = null
var remaining: int = 0
var initial: int = 0


func _init(
	next_node: Node3D = null,
	next_remaining: int = 0,
	next_initial: int = 0,
) -> void:
	node = next_node
	remaining = next_remaining
	initial = next_initial
