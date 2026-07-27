class_name BuildingVisualsPort
extends RefCounted

## Presentation-only dependencies needed by building visuals.
## This avoids making a visual helper reach into the settlement composition root.

var status_indicators: Array[Label3D]
var add_warehouse_fill_label: Callable
var add_house_light: Callable


func _init(
	p_status_indicators: Array[Label3D],
	p_add_warehouse_fill_label: Callable,
	p_add_house_light: Callable
) -> void:
	status_indicators = p_status_indicators
	add_warehouse_fill_label = p_add_warehouse_fill_label
	add_house_light = p_add_house_light
