class_name CourierTaskPublisherRuntimePort
extends RefCounted

## Explicit integration boundary for publishing logistics tasks from settlement state.

var settlement: SettlementState
var citizens: Array
var construction_sites: Array
var warehouse_positions: Array[Vector3]
var pending_arrivals: Array
var queued_trades: Array
var sawmill_positions: Array[Vector3]
var water_collectors: Array
var building_registry: BuildingRegistry
var sawmills: SawmillService
var courier_dispatcher: CourierDispatcher
var entrance_stone_getter: Callable
var canteen_getter: Callable
var canteen_food_getter: Callable
var canteen_position_getter: Callable
var pending_canteen_delivery_getter: Callable
var runtime_seconds_getter: Callable
var reconcile_construction_reservations: Callable
var reconcile_repair_reservations: Callable
var cell_from_position: Callable
var get_nearest_delivery_position: Callable
var warehouse_delivery_position: Callable
var construction_priority: Callable
var construction_material_sources: Callable
var construction_source_available: Callable
var fire_state_for: Callable
var firewood_task_priority: Callable
var is_managed_fire_source: Callable
