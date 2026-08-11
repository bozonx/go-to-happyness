class_name CourierTaskRuntimePort
extends RefCounted

## Explicit integration boundary for executing and cancelling courier tasks.

var settlement: SettlementState
var citizens: Array
var queued_trades: Array
var pending_trades: Dictionary
var warehouse_positions: Array[Vector3]
var pending_arrivals: Array
var arrival_greeters: Dictionary
var outside_workers: Dictionary
var building_registry: BuildingRegistry
var sawmills: SawmillService
var water_collector_service: WaterCollectorService
var trade_service: TradeService
var canteen_service: CanteenService
var canteen_getter: Callable
var canteen_food_getter: Callable
var canteen_position_getter: Callable
var pending_canteen_delivery_getter: Callable
var set_canteen_delivery_state: Callable
var entrance_stone_getter: Callable
var runtime_seconds_getter: Callable
var fire_state_for: Callable
var apply_fire_state: Callable
var is_route_reachable: Callable
var construction_source_available: Callable
var take_construction_source: Callable
var return_construction_source: Callable
var citizen_for_ai_id: Callable
