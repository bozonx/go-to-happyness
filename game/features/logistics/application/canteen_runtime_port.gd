class_name CanteenRuntimePort
extends RefCounted

## Explicit integration boundary for meal service and canteen deliveries.

var settlement: SettlementState
var citizens: Array
var canteen_getter: Callable
var canteen_food_getter: Callable
var set_canteen_food: Callable
var canteen_position_getter: Callable
var pending_canteen_delivery_getter: Callable
var pending_canteen_carrier_getter: Callable
var pending_canteen_delivery_amount_getter: Callable
var set_canteen_delivery_state: Callable
var is_canteen_delivery_in_progress: Callable
var is_fire_lit: Callable
var has_cook: Callable
var update_interface: Callable
var request_courier_dispatch: Callable
var is_work_time: Callable
var update_workers: Callable
