class_name ServicePocketRecord
extends RefCounted

## A walkable service position published as a navigation obstacle exception.
## Keeping it typed prevents presentation nodes and grid cells being passed
## around as anonymous dictionaries.

var cell: Vector2i
var node: Node3D


func _init(p_cell: Vector2i, p_node: Node3D) -> void:
	cell = p_cell
	node = p_node
