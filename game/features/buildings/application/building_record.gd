class_name BuildingRecord
extends RefCounted

## Runtime placement data shared by construction, navigation and building services.
## A record exists while a site is reserved, before its visual Node3D is completed.

var cell: Vector2i
var center: Vector3
var footprint: Vector2i
var node: Node3D


func _init(next_cell: Vector2i, next_center: Vector3, next_footprint: Vector2i) -> void:
	cell = next_cell
	center = next_center
	footprint = next_footprint
