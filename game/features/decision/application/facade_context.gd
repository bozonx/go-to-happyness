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
