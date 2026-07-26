class_name WorldNavigationRuntimePort
extends RefCounted

## Routing-facing slice of the settlement runtime. World presentation setup is
## intentionally outside this port; it is migrated separately because
## WorldSetup currently owns a legacy build(Node) integration boundary.

var navigation_bridge_getter: Callable
var terrain_blocked_cells_getter: Callable
var navigation_blocked_cells_getter: Callable
var navigation_blocked_cells_setter: Callable
var building_records_getter: Callable
var service_pockets_getter: Callable
var cell_from_position: Callable
var is_board_cell: Callable
var nav_grid_getter: Callable
var is_route_reachable: Callable
var terrain_height_at: Callable
var tree_nodes_getter: Callable
var tree_at: Callable
var settlement_add: Callable
var update_interface: Callable
var terrain_blocked_cell_erase: Callable
var clearance_margin: float
var cell_size: float


func _init(
	p_navigation_bridge_getter: Callable,
	p_terrain_blocked_cells_getter: Callable,
	p_navigation_blocked_cells_getter: Callable,
	p_navigation_blocked_cells_setter: Callable,
	p_building_records_getter: Callable,
	p_service_pockets_getter: Callable,
	p_cell_from_position: Callable,
	p_is_board_cell: Callable,
	p_nav_grid_getter: Callable,
	p_is_route_reachable: Callable,
	p_terrain_height_at: Callable,
	p_tree_nodes_getter: Callable,
	p_tree_at: Callable,
	p_settlement_add: Callable,
	p_update_interface: Callable,
	p_terrain_blocked_cell_erase: Callable,
	p_clearance_margin: float,
	p_cell_size: float
) -> void:
	navigation_bridge_getter = p_navigation_bridge_getter
	terrain_blocked_cells_getter = p_terrain_blocked_cells_getter
	navigation_blocked_cells_getter = p_navigation_blocked_cells_getter
	navigation_blocked_cells_setter = p_navigation_blocked_cells_setter
	building_records_getter = p_building_records_getter
	service_pockets_getter = p_service_pockets_getter
	cell_from_position = p_cell_from_position
	is_board_cell = p_is_board_cell
	nav_grid_getter = p_nav_grid_getter
	is_route_reachable = p_is_route_reachable
	terrain_height_at = p_terrain_height_at
	tree_nodes_getter = p_tree_nodes_getter
	tree_at = p_tree_at
	settlement_add = p_settlement_add
	update_interface = p_update_interface
	terrain_blocked_cell_erase = p_terrain_blocked_cell_erase
	clearance_margin = p_clearance_margin
	cell_size = p_cell_size
