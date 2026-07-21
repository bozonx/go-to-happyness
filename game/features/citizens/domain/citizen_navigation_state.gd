class_name CitizenNavigationState
extends RefCounted

## Deterministic navigation, pathfinding, and idle-wander state for a citizen.
## No nodes, physics, rendering, simulation, or wall-clock time.

var idle_wander_anchor := Vector3.INF
var idle_wander_target := Vector3.INF
var idle_wander_pause := 0.0
var movement_path: Array[Vector3] = []
var path_destination := Vector3.INF
var path_allows_destination_house := false
var active_route: RouteResult
var route_retry_timer := 0.0
var route_retry_delay := 2.0
var route_unreachable_time := 0.0
var route_unreachable_reason: int = 0
var navigation_failed := false
# Topology revision captured when navigation_failed was raised, so a later
# passability change (demolition/excavation) can retract the give-up.
var navigation_failed_topology := -999
var stuck_time := 0.0
var recovery_repath_done := false
var route_no_progress_time := 0.0
var route_best_distance := INF
var route_recovery_attempt := 0
var recovery_detour_requested := false
var jump_cooldown := 0.0
var ground_contact_confirmed := false
var blocked_by_storage := false
