class_name ConstructionRuntime
extends RefCounted

## Narrow integration boundary between construction and the settlement runtime.
## The service receives data and callbacks it needs instead of a broad scene node.

var scene_root: Node
var settlement: SettlementState
var building_registry: BuildingRegistry
var citizens: Array[Citizen]
var duration := 4.0
var builder_power: Callable
var builder_count: Callable
var set_status: Callable
var building_completed: Callable
var workers_changed: Callable
var navigation_changed: Callable
