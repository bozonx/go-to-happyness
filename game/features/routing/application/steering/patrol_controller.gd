class_name PatrolController
extends SteeringController

## Manages waypoint patrol routines and bus schedule stops with wait timers.

var patrol_waypoints: Array[Vector3] = []
var current_waypoint_index := 0
var is_looping := true
var wait_time_at_stops := 0.0
var current_wait_timer := 0.0


func configure_patrol(waypoints: Array, loop := true, wait_time := 0.0) -> void:
	patrol_waypoints.clear()
	for wp in waypoints:
		patrol_waypoints.append(Vector3(wp))

	current_waypoint_index = 0
	is_looping = loop
	wait_time_at_stops = wait_time
	current_wait_timer = 0.0
	if not patrol_waypoints.is_empty():
		current_target = patrol_waypoints[0]
		is_active = true


func advance_waypoint() -> Vector3:
	if patrol_waypoints.is_empty():
		is_active = false
		return Vector3.INF
	current_waypoint_index += 1
	if current_waypoint_index >= patrol_waypoints.size():
		if is_looping:
			current_waypoint_index = 0
		else:
			is_active = false
			return Vector3.INF
	current_target = patrol_waypoints[current_waypoint_index]
	return current_target
