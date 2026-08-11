class_name ConstructionPriorityRuntimePort
extends RefCounted

## Explicit integration boundary for construction site priority evaluation.

var construction_sites: Array[ConstructionSite]
var warehouse_positions: Array[Vector3]
var sawmill_positions: Array[Vector3]
var campfire_node_getter: Callable
var canteen_getter: Callable
var population_provider: Callable
var housing_slots_provider: Callable
var food_amount_provider: Callable
