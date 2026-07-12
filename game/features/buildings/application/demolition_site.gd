class_name DemolitionSite
extends RefCounted

## Mutable runtime state for a building marked for demolition.

var building: Node3D
var building_type: String
var progress := 0.0


func _init(next_building: Node3D, next_building_type: String) -> void:
	building = next_building
	building_type = next_building_type
