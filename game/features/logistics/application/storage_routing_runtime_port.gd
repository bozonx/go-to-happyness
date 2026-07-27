class_name StorageRoutingRuntimePort
extends RefCounted

## Explicit integration boundary for warehouse lookup and resource-pile routing.

var settlement: SettlementState
var warehouse_positions: Array[Vector3]
var resource_piles: Array
var player_citizen_getter: Callable
var interaction_range: float
var is_route_reachable: Callable
var find_path_around_houses: Callable
var nav_grid: NavGrid
var dig_sites: Array
var can_work_at_dig_site: Callable
var resource_for_depth: Callable
var update_interface: Callable
