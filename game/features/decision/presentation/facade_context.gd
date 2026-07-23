## Godot-facing input for fact collectors.
class_name FacadeContext
extends RefCounted

## Shared per-citizen context passed to fact collectors. Holds references that
## every collector needs without exposing facade internals.

var simulation: Node
var helpers: FacadeTargetHelpers
var actor: Citizen
var citizen_id: int
var actor_work_time: bool
var daily_order_active: bool
var daily_order_role: String


func _init(
	next_simulation: Node,
	next_helpers: FacadeTargetHelpers,
	next_actor: Citizen,
	next_citizen_id: int,
	next_actor_work_time: bool,
	next_daily_order_active: bool,
	next_daily_order_role: String,
) -> void:
	simulation = next_simulation
	helpers = next_helpers
	actor = next_actor
	citizen_id = next_citizen_id
	actor_work_time = next_actor_work_time
	daily_order_active = next_daily_order_active
	daily_order_role = next_daily_order_role


func has_tool(tool_name: String) -> bool:
	if is_instance_valid(simulation) and simulation.get("settlement") != null:
		var settlement: Object = simulation.get("settlement")
		var tools: Variant = settlement.get("tools")
		if tools is Dictionary:
			return bool((tools as Dictionary).get(tool_name, false))
	return false


func backpack_resources() -> Dictionary:
	if is_instance_valid(simulation) and simulation.get("settlement") != null:
		var settlement: Object = simulation.get("settlement")
		var backpack: Variant = settlement.get("backpack")
		if backpack is Dictionary:
			return (backpack as Dictionary).duplicate(true)
	return {}
