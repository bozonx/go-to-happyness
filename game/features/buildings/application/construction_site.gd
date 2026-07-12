class_name ConstructionSite
extends RefCounted

## Mutable runtime state for one construction project. The site is created as soon
## as a footprint is reserved and lives until completion or cancellation.

var cell: Vector2i
var building_type: String
var position: Vector3
var node: Node3D
var fill: MeshInstance3D
var blueprint: Dictionary
var progress := 0.0
var modules_built := 0
var required_materials: Dictionary
var delivered_materials: Dictionary = {}
var reserved_materials: Dictionary = {}


func _init(next_cell: Vector2i, next_building_type: String, next_position: Vector3, next_node: Node3D, next_fill: MeshInstance3D, next_blueprint: Dictionary, next_required_materials: Dictionary) -> void:
	cell = next_cell
	building_type = next_building_type
	position = next_position
	node = next_node
	fill = next_fill
	blueprint = next_blueprint
	required_materials = next_required_materials


func is_supplied() -> bool:
	for resource_type in required_materials:
		if int(delivered_materials.get(resource_type, 0)) < int(required_materials[resource_type]):
			return false
	return true
