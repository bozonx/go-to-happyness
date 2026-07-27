class_name WorldNavigationPresentationPort
extends RefCounted

## Presentation-facing runtime boundary for SettlementWorldNavigationController.
## Routing facts live in WorldNavigationRuntimePort; scene construction and
## visual updates live here.

var camera_getter: Callable
var trail_field_getter: Callable
var map_document_getter: Callable
var world_setup_getter: Callable
var world_setup_setter: Callable
var water_access_setter: Callable
var add_to_scene: Callable
var build_world_setup: Callable
var update_daylight: Callable
var move_selection: Callable
var territory_getter: Callable
var trail_renderer_getter: Callable
var runtime_seconds_getter: Callable
var is_tent_era: Callable
var road_walking_enabled: Callable
var village_territory_getter: Callable
var cell_size: float
var board_cells: int


func _init(
	p_camera_getter: Callable,
	p_trail_field_getter: Callable,
	p_map_document_getter: Callable,
	p_world_setup_getter: Callable,
	p_world_setup_setter: Callable,
	p_water_access_setter: Callable,
	p_add_to_scene: Callable,
	p_build_world_setup: Callable,
	p_update_daylight: Callable,
	p_move_selection: Callable,
	p_territory_getter: Callable,
	p_trail_renderer_getter: Callable,
	p_runtime_seconds_getter: Callable,
	p_is_tent_era: Callable,
	p_road_walking_enabled: Callable,
	p_village_territory_getter: Callable,
	p_cell_size: float,
	p_board_cells: int
) -> void:
	camera_getter = p_camera_getter
	trail_field_getter = p_trail_field_getter
	map_document_getter = p_map_document_getter
	world_setup_getter = p_world_setup_getter
	world_setup_setter = p_world_setup_setter
	water_access_setter = p_water_access_setter
	add_to_scene = p_add_to_scene
	build_world_setup = p_build_world_setup
	update_daylight = p_update_daylight
	move_selection = p_move_selection
	territory_getter = p_territory_getter
	trail_renderer_getter = p_trail_renderer_getter
	runtime_seconds_getter = p_runtime_seconds_getter
	is_tent_era = p_is_tent_era
	road_walking_enabled = p_road_walking_enabled
	village_territory_getter = p_village_territory_getter
	cell_size = p_cell_size
	board_cells = p_board_cells
