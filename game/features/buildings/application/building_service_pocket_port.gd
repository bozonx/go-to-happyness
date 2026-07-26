class_name BuildingServicePocketPort
extends RefCounted

## Narrow bootstrap port for service-entry navigation pockets. It keeps this
## building concern independent from SettlementGame and its unrelated systems.

var service_pockets: Array[ServicePocketRecord]
var cell_from_position: Callable
var add_service_marker: Callable
var add_visitor_marker: Callable


func _init(
	p_service_pockets: Array[ServicePocketRecord],
	p_cell_from_position: Callable,
	p_add_service_marker: Callable,
	p_add_visitor_marker: Callable
) -> void:
	service_pockets = p_service_pockets
	cell_from_position = p_cell_from_position
	add_service_marker = p_add_service_marker
	add_visitor_marker = p_add_visitor_marker
