class_name CitizenWorkPositionState
extends RefCounted

## Deterministic work-position lock state for a citizen.
## No nodes, physics, rendering, simulation, or wall-clock time.

var locked := false
var anchor := Vector3.INF
var role := ""
var temporary := true
var target := Vector3.INF
var previous_state: int = 0
var previous_active_role := ""
var previous_player_controlled := false


func clear() -> void:
	locked = false
	anchor = Vector3.INF
	role = ""
	temporary = true
	target = Vector3.INF
	previous_state = 0
	previous_active_role = ""
	previous_player_controlled = false
