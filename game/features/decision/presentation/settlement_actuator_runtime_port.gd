class_name SettlementActuatorRuntimePort
extends RefCounted

## Explicit integration boundary between citizen signals and gameplay services.

var canteen_service: RefCounted
var courier_dispatcher: RefCounted
var construction: RefCounted
var settlement: RefCounted
var building_registry: RefCounted
var storage_delivery_service: RefCounted
var factory_service: RefCounted
var sawmills: RefCounted
var water_collector_service: RefCounted
var excavation_service: RefCounted
var citizen_needs_service: RefCounted
var trade_service: RefCounted
var resource_piles: Array
var game_minutes_query: Callable
var runtime_seconds_query: Callable
var update_interface: Callable
var request_courier_dispatch: Callable
var request_decision_refresh: Callable
var refresh_living_statuses: Callable
var drop_resource_pile: Callable
var fire_state_query: Callable
var apply_fire_state: Callable
