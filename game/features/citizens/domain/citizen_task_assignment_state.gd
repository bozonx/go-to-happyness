class_name CitizenTaskAssignmentState
extends RefCounted

## Deterministic task assignment, production, and courier state for a citizen.
## No nodes, physics, rendering, simulation, or wall-clock time.

var resource_type := "wood"
var gather_resource_type := ""
var gather_source_position := Vector3.ZERO
var gather_access_position := Vector3.ZERO
var source_position := Vector3.ZERO
var source_access_position := Vector3.ZERO
var workplace_position := Vector3.ZERO
var warehouse_position := Vector3.ZERO
var uses_courier := false
var carried_amount := 0
var pending_resources: Dictionary = {}
var construction_position := Vector3.ZERO
var is_waiting_for_materials := false
var construction_delivery_resource := ""
var building_supply_kind := "construction"
var delivery_amount := 0
var returning_to_excavation := false
var role_recheck_remaining := 0.0
var wait_recheck := 0.0
var courier_resource_type := ""
var courier_equipment := "hands"
