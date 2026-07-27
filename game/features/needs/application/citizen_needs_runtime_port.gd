class_name CitizenNeedsRuntimePort
extends RefCounted

## Explicit integration boundary for personal-need schedules and relief queries.

var nav_grid: Variant
var toilets_getter: Callable
var is_route_reachable: Callable
var building_type_for_node: Callable
var tree_positions: Array[Vector3] = []
var grass_sources: Dictionary = {}
