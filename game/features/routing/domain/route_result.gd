class_name RouteResult
extends RefCounted

enum UnreachableReason { NONE, UNKNOWN, NO_GRID, OUTSIDE_BOARD, GOAL_BLOCKED, DISCONNECTED }

## Result of a route request. An empty waypoint list is never used as success.

var reachable := false
var waypoints: Array[Vector3] = []
var arrival_position := Vector3.INF
var grid_revision := -1
var topology_revision := -1
var unreachable_reason := UnreachableReason.NONE


## A route stays safe while passability is unchanged. A different grid revision
## may offer a cheaper route, but does not require an actor to abandon its path.
func is_topologically_stale(current_topology_revision: int) -> bool:
	return topology_revision >= 0 and current_topology_revision >= 0 and topology_revision != current_topology_revision


static func success(next_waypoints: Array[Vector3], next_arrival_position: Vector3, next_grid_revision := -1, next_topology_revision := -1) -> RouteResult:
	var result := RouteResult.new()
	result.reachable = true
	result.waypoints = next_waypoints
	result.arrival_position = next_arrival_position
	result.grid_revision = next_grid_revision
	result.topology_revision = next_topology_revision
	result.unreachable_reason = UnreachableReason.NONE
	return result


static func unreachable(
	next_grid_revision := -1,
	next_topology_revision := -1,
	next_unreachable_reason := UnreachableReason.UNKNOWN
) -> RouteResult:
	var result := RouteResult.new()
	result.grid_revision = next_grid_revision
	result.topology_revision = next_topology_revision
	result.unreachable_reason = next_unreachable_reason
	return result
