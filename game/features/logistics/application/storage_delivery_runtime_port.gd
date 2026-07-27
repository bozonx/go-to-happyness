class_name StorageDeliveryRuntimePort
extends RefCounted

## Explicit integration boundary for delivering carried resources to storage.

var settlement: SettlementState
var warehouse_positions: Array[Vector3]
var courier_dispatcher: CourierDispatcher
var storage_routing: StorageRoutingService
var release_reservation: Callable
var drop_resource_pile: Callable
var update_interface: Callable
var request_courier_dispatch: Callable
var send_citizen_to_leisure: Callable
