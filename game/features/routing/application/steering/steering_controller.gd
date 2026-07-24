class_name SteeringController
extends RefCounted

## Abstract base class for higher-level steering and route execution controllers.
## Subclasses handle squad formations, vehicle convoys, and patrol routes.

var active_route: RouteResult = null
var current_target: Vector3 = Vector3.INF
var is_active := false


func set_route(route: RouteResult) -> void:
	active_route = route
	if route != null and route.reachable and not route.waypoints.is_empty():
		current_target = route.waypoints[0]
		is_active = true
	else:
		current_target = Vector3.INF
		is_active = false


func update_steering(actor_position: Vector3, delta: float) -> Vector3:
	if not is_active or current_target == Vector3.INF:
		return Vector3.ZERO
	return (current_target - actor_position).normalized()
