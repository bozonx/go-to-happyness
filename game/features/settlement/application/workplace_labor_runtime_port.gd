class_name WorkplaceLaborRuntimePort
extends RefCounted

## Explicit integration boundary for workplace labor rules.

var settlement: SettlementState
var citizens: Array
var campfire_node_getter: Callable
var canteen_getter: Callable
var canteen_position_getter: Callable
var warehouse_positions: Array[Vector3]
var construction_sites: Array
var demolition_sites: Array
var tree_positions: Array[Vector3]
var water_source_positions_getter: Callable
var craft_tent_positions: Array[Vector3]
var dig_sites: Array
var is_fire_lit: Callable
var update_interface: Callable
var available_employer_capacity: Callable
var builder_job_capacity: Callable
var can_work_at_dig_site: Callable
var employment_centre_building_getter: Callable
