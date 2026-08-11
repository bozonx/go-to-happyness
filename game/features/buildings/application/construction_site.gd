class_name ConstructionSite
extends RefCounted

## Mutable runtime state for one construction project. The site is created as soon
## as a footprint is reserved and lives until completion or cancellation.

var cell: Vector2i
var building_type: String
var position: Vector3
var node: Node3D
var blueprint: Dictionary
var site_id: int
var progress := 0.0
var modules_built := 0
var required_materials: Dictionary
var delivered_materials: Dictionary = {}
var reserved_materials: Dictionary = {}
## Virtual obligations (currently money). They never enter a warehouse or a
## courier's hands; the service captures them directly from the settlement.
var required_payments: Dictionary = {}
var paid_payments: Dictionary = {}
## Effective seconds of one-builder labour required by this exact project.
var labor_units := 4.0
## An upgrade is a normal supplied construction project laid over an existing
## building. The completed node remains the registry owner until this project
## finishes, so residents, employment and stable building identity survive.
var upgrade_source: Node3D = null
var upgrade_from_type := ""


func _init(next_cell: Vector2i, next_building_type: String, next_position: Vector3, next_node: Node3D, next_blueprint: Dictionary, next_required_materials: Dictionary) -> void:
	cell = next_cell
	building_type = next_building_type
	position = next_position
	node = next_node
	blueprint = next_blueprint
	required_materials = next_required_materials


func is_supplied() -> bool:
	for resource_type in required_materials:
		if int(delivered_materials.get(resource_type, 0)) < int(required_materials[resource_type]):
			return false
	for payment_type in required_payments:
		if int(paid_payments.get(payment_type, 0)) < int(required_payments[payment_type]):
			return false
	return true


## How far the building can be built based on the least-supplied material class.
## This prevents a large quantity of cheap material from hiding a completely
## missing critical component.
func material_progress() -> float:
	var physical_progress := 1.0
	for resource_type in required_materials:
		var required := int(required_materials[resource_type])
		if required > 0:
			physical_progress = minf(physical_progress, float(delivered_materials.get(resource_type, 0)) / float(required))
	var payment_progress := 1.0
	for payment_type in required_payments:
		var required := int(required_payments[payment_type])
		if required > 0:
			payment_progress = minf(payment_progress, float(paid_payments.get(payment_type, 0)) / float(required))
	return minf(physical_progress, payment_progress)


func is_upgrade() -> bool:
	return is_instance_valid(upgrade_source) and not upgrade_from_type.is_empty()
