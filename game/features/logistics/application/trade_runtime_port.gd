class_name TradeRuntimePort
extends RefCounted

## Explicit integration boundary for market and entrance trade orders.

var settlement: SettlementState
var citizens: Array
var queued_trades: Array
var pending_trades: Dictionary
var warehouse_positions: Array[Vector3]
var market_menu: Variant
var selected_market_getter: Callable
var entrance_stone_getter: Callable
var get_delivery_position: Callable
var update_interface: Callable
var refresh_market_menu: Callable
var request_courier_dispatch: Callable
var total_game_minutes: Callable
var citizen_for_ai_id: Callable
var create_resource_pile: Callable
var update_workers: Callable
