class_name CitizenAIMoveState
extends RefCounted

## Deterministic AI-controlled movement target and arrival status.
## No nodes, physics, rendering, simulation, or wall-clock time.

var target := Vector3.INF
var arrival_radius := 0.25
var arrived := false
var failed := false
var failure_reason: int = 0


func reset() -> void:
	target = Vector3.INF
	arrived = false
	failed = false


func start_move(destination: Vector3, radius: float) -> void:
	target = destination
	arrival_radius = maxf(radius, 0.01)
	arrived = false
	failed = false
	failure_reason = 0
