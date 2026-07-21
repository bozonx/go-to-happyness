class_name CitizenWorkLocationState
extends RefCounted

## Deterministic work destination positions and craft/leisure parameters.
## No nodes, physics, rendering, simulation, or wall-clock time.

var school_position := Vector3.ZERO
var official_position := Vector3.ZERO
var research_position := Vector3.ZERO
var factory_position := Vector3.ZERO
var park_position := Vector3.ZERO
var market_position := Vector3.ZERO
var craft_position := Vector3.ZERO
var canteen_position := Vector3.ZERO
var trade_source_position := Vector3.ZERO
var trade_destination_position := Vector3.ZERO
var employment_center_position := Vector3.INF
var park_rest_duration := 4.0
var craft_timer := 0.0
var craft_speed_multiplier := 1.0
