class_name ExcavationRuntimePort
extends RefCounted

## Explicit integration boundary for excavation state, editor feedback and scene creation.

var settlement: SettlementState
var citizens: Array
var dig_sites: Array
var dig_cells: Dictionary
var exhausted_dig_cells: Dictionary
var random: RandomNumberGenerator
var update_interface: Callable
var update_workers: Callable
var request_courier_dispatch: Callable
var placement_key: Callable
var is_clear_of_objects: Callable
var employment_center_position: Callable
var show_territory_overlay: Callable
var move_selection: Callable
var show_selected_citizen_menu: Callable
var selected_builder_getter: Callable
var selected_world_position_getter: Callable
var selection_marker_getter: Callable
var selection_material_getter: Callable
var set_dig_mode: Callable
var set_build_mode: Callable
var add_child: Callable
