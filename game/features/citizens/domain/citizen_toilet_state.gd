class_name CitizenToiletState
extends RefCounted

## Deterministic toilet and bush-relief state for a citizen.
## No nodes, physics, rendering, simulation, or wall-clock time.

var timer: RefCounted
var wait_time := 0.0
var relief_position := Vector3.INF
var relief_type := ""
var resume_state: int = 0
var has_resume_state := false
var resume_idle_wander_anchor := Vector3.INF
var resume_idle_wander_target := Vector3.INF
var resume_idle_wander_pause := 0.0
var player_using := false


func _init() -> void:
	timer = CitizenTaskState.new()


func reset_relief() -> void:
	relief_position = Vector3.INF
	relief_type = ""


func clear_resume() -> void:
	has_resume_state = false
	resume_state = 0
	resume_idle_wander_anchor = Vector3.INF
	resume_idle_wander_target = Vector3.INF
	resume_idle_wander_pause = 0.0
