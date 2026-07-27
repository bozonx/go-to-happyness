class_name CourierDispatchRuntimePort
extends RefCounted

## Explicit integration boundary for a courier scheduling pass.

var citizens: Array
var warehouse_positions: Array[Vector3]
var storage_routing: StorageRoutingService
var runtime_seconds_getter: Callable
var publish_tasks: Callable
var is_task_valid: Callable
var start_task: Callable
var cancel_task: Callable
var release_reservation: Callable
