class_name RouteResult
extends RefCounted

## Result of a route request. An empty waypoint list is never used as success.

var reachable := false
var waypoints: Array[Vector3] = []
var arrival_position := Vector3.INF


static func success(next_waypoints: Array[Vector3], next_arrival_position: Vector3) -> RouteResult:
	var result := RouteResult.new()
	result.reachable = true
	result.waypoints = next_waypoints
	result.arrival_position = next_arrival_position
	return result


static func unreachable() -> RouteResult:
	return RouteResult.new()
