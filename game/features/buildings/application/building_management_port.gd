class_name BuildingManagementPort
extends RefCounted

## Runtime boundary for building-management decisions used during bootstrap.

var building_registry: BuildingRegistry
var nav_grid_getter: Callable
var entrance_getter: Callable
var entrance_setter: Callable
var canteen_getter: Callable
var canteen_setter: Callable
var canteen_position_setter: Callable
var add_selector: Callable
var configure_entrance_ambient: Callable


func _init(
	p_building_registry: BuildingRegistry,
	p_nav_grid_getter: Callable,
	p_entrance_getter: Callable,
	p_entrance_setter: Callable,
	p_canteen_getter: Callable,
	p_canteen_setter: Callable,
	p_canteen_position_setter: Callable,
	p_add_selector: Callable,
	p_configure_entrance_ambient: Callable
) -> void:
	building_registry = p_building_registry
	nav_grid_getter = p_nav_grid_getter
	entrance_getter = p_entrance_getter
	entrance_setter = p_entrance_setter
	canteen_getter = p_canteen_getter
	canteen_setter = p_canteen_setter
	canteen_position_setter = p_canteen_position_setter
	add_selector = p_add_selector
	configure_entrance_ambient = p_configure_entrance_ambient
