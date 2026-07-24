class_name ConvoyController
extends SteeringController

## Coordinates vehicle column / convoy movement, maintaining safe following distance,
## adaptive cruise speed matching, and column alignment along a leader's route.

var follow_distance: float = 6.0
var max_speed: float = 10.0
var min_distance: float = 2.5


func compute_follower_speed(follower_pos: Vector3, leader_pos: Vector3, leader_speed: float) -> float:
	var dist := follower_pos.distance_to(leader_pos)
	if dist <= min_distance:
		return 0.0  # Stop to prevent rear-end collision
	if dist >= follow_distance * 2.0:
		return max_speed  # Catch up
	var target_speed := lerpf(0.0, max_speed, (dist - min_distance) / (follow_distance - min_distance))
	return minf(target_speed, max_speed)
