class_name CitizenToiletHandler
extends RefCounted

const TOILET_USE_DURATION := 8.0
const TOILET_WAIT_TIMEOUT := 12.0
const CitizenTaskStateScript = preload("res://game/features/citizens/domain/citizen_task_state.gd")

func go_to_relief(actor: Node3D, destination: Vector3, relief_kind: StringName) -> void:
	if actor == null or bool(actor.get("is_player_controlled")) or destination == Vector3.INF:
		return
	if relief_kind == &"toilet":
		actor.set("current_toilet_target", null)
		var simulation: Variant = actor.get("simulation")
		if simulation != null:
			for toilet_item in simulation.get_toilets():
				var toilet := toilet_item as Node3D
				if not is_instance_valid(toilet):
					continue
				var service_position: Vector3 = toilet.get_meta("service_position") if toilet.has_meta("service_position") else toilet.global_position
				if service_position.distance_squared_to(destination) < 0.01:
					actor.set("current_toilet_target", toilet)
					break
		var target: Node3D = actor.get("current_toilet_target") as Node3D
		if is_instance_valid(target):
			begin_toilet_trip(actor, Citizen.State.TO_TOILET)
		return
	actor.set("toilet_relief_position", destination)
	actor.set("toilet_relief_type", str(relief_kind))
	begin_toilet_trip(actor, Citizen.State.TO_BUSH)

func begin_player_toilet_use(actor: Node3D, toilet_node: Node3D) -> void:
	if not is_instance_valid(toilet_node) or actor == null:
		return
	actor.set("current_toilet_target", toilet_node)
	actor.set("state", Citizen.State.USING_TOILET)
	var timer: Variant = actor.get("toilet_timer")
	if timer is CitizenTaskStateScript:
		timer.start(TOILET_USE_DURATION)
	actor.set("player_using_toilet", true)

func begin_toilet_trip(actor: Node3D, next_state: int) -> void:
	if actor == null:
		return
	if not bool(actor.get("has_toilet_resume_state")):
		actor.set("toilet_resume_state", actor.get("state"))
		actor.set("has_toilet_resume_state", true)
		actor.set("toilet_resume_idle_wander_anchor", actor.get("idle_wander_anchor"))
		actor.set("toilet_resume_idle_wander_target", actor.get("idle_wander_target"))
		actor.set("toilet_resume_idle_wander_pause", actor.get("idle_wander_pause"))
	reset_toilet_navigation(actor)
	actor.set("state", next_state)

func reset_toilet_navigation(actor: Node3D) -> void:
	if actor == null:
		return
	var path: Variant = actor.get("movement_path")
	if path is Array:
		(path as Array).clear()
	actor.set("active_route", null)
	actor.set("path_destination", Vector3.INF)
	actor.set("route_retry_timer", 0.0)
	actor.set("route_unreachable_time", 0.0)
	actor.set("navigation_failed", false)

func resume_after_toilet(actor: Node3D) -> void:
	if actor == null:
		return
	actor.set("player_using_toilet", false)
	actor.set("current_toilet_target", null)
	actor.set("toilet_relief_position", Vector3.INF)
	actor.set("toilet_relief_type", "")
	reset_toilet_navigation(actor)
	var release_notifier: Variant = actor.get("queue_release_notifier")
	if release_notifier is Callable and release_notifier.is_valid():
		release_notifier.call(actor)
	if bool(actor.get("has_toilet_resume_state")):
		actor.set("state", actor.get("toilet_resume_state"))
		actor.set("idle_wander_anchor", actor.get("toilet_resume_idle_wander_anchor"))
		actor.set("idle_wander_target", actor.get("toilet_resume_idle_wander_target"))
		actor.set("idle_wander_pause", actor.get("toilet_resume_idle_wander_pause"))
	else:
		actor.set("state", Citizen.State.IDLE)
	actor.set("has_toilet_resume_state", false)
	actor.set("toilet_resume_state", Citizen.State.IDLE)
	actor.set("toilet_resume_idle_wander_anchor", Vector3.INF)
	actor.set("toilet_resume_idle_wander_target", Vector3.INF)
	actor.set("toilet_resume_idle_wander_pause", 0.0)

func process_to_toilet(actor: Node3D, delta: float) -> void:
	if actor == null:
		return
	var target := actor.get("current_toilet_target") as Node3D
	if not is_instance_valid(target):
		resume_after_toilet(actor)
		return
	var serv_pos: Vector3 = target.get_meta("service_position") if target.has_meta("service_position") else target.global_position
	if bool(actor.call("_move_to", serv_pos, delta)):
		var users_count := 0
		var simulation: Variant = actor.get("simulation")
		if simulation != null and "citizens" in simulation:
			for other_item in simulation.citizens:
				var other := other_item as Node3D
				if is_instance_valid(other) and other != actor and int(other.get("state")) == Citizen.State.USING_TOILET and other.get("current_toilet_target") == target:
					users_count += 1
		var b_type: String = str(target.get_meta("building_type", ""))
		var base_cap := 1
		if "tent" in b_type: base_cap = 1
		elif "earth" in b_type: base_cap = 2
		elif "clay" in b_type: base_cap = 3
		elif "wood" in b_type: base_cap = 4
		elif "stone" in b_type: base_cap = 5
		elif "brick" in b_type: base_cap = 6
		var lvl := 1
		if "lvl2" in b_type: lvl = 2
		elif "lvl3" in b_type: lvl = 3
		var capacity := base_cap + lvl - 1

		if users_count < capacity:
			actor.set("state", Citizen.State.USING_TOILET)
			var timer: Variant = actor.get("toilet_timer")
			if timer is CitizenTaskStateScript:
				timer.start(TOILET_USE_DURATION)
		else:
			actor.set("toilet_wait_time", 0.0)
			actor.set("state", Citizen.State.WAITING_FOR_TOILET)

func process_using_toilet(actor: Node3D, delta: float) -> void:
	if actor == null:
		return
	var target := actor.get("current_toilet_target") as Node3D
	if not is_instance_valid(target):
		resume_after_toilet(actor)
		return
	var timer: Variant = actor.get("toilet_timer")
	if timer is CitizenTaskStateScript and bool(timer.advance(delta)):
		var sat_cap: float = actor.get_satisfaction_cap() if actor is Citizen else 100.0
		var cur_sat: float = float(actor.get("satisfaction"))
		actor.set("satisfaction", minf(sat_cap, cur_sat + 10.0))
		resume_after_toilet(actor)
		if actor is Citizen:
			actor.emit_signal("relief_finished", actor)

func process_waiting_for_toilet(actor: Node3D, delta: float) -> void:
	if actor == null:
		return
	var target := actor.get("current_toilet_target") as Node3D
	if not is_instance_valid(target):
		resume_after_toilet(actor)
		return
	var wait_time: float = float(actor.get("toilet_wait_time")) + delta
	actor.set("toilet_wait_time", wait_time)
	if wait_time >= TOILET_WAIT_TIMEOUT:
		actor.set("toilet_wait_time", 0.0)
		resume_after_toilet(actor)
		return
	var users_count := 0
	var simulation: Variant = actor.get("simulation")
	if simulation != null and "citizens" in simulation:
		for other_item in simulation.citizens:
			var other := other_item as Node3D
			if is_instance_valid(other) and other != actor and int(other.get("state")) == Citizen.State.USING_TOILET and other.get("current_toilet_target") == target:
				users_count += 1
	var b_type: String = str(target.get_meta("building_type", ""))
	var base_cap := 1
	if "tent" in b_type: base_cap = 1
	elif "earth" in b_type: base_cap = 2
	elif "clay" in b_type: base_cap = 3
	elif "wood" in b_type: base_cap = 4
	elif "stone" in b_type: base_cap = 5
	elif "brick" in b_type: base_cap = 6
	var lvl := 1
	if "lvl2" in b_type: lvl = 2
	elif "lvl3" in b_type: lvl = 3
	var capacity := base_cap + lvl - 1

	if users_count < capacity:
		actor.set("state", Citizen.State.USING_TOILET)
		var timer: Variant = actor.get("toilet_timer")
		if timer is CitizenTaskStateScript:
			timer.start(TOILET_USE_DURATION)

func process_to_bush(actor: Node3D, delta: float) -> void:
	if actor == null:
		return
	var pos: Vector3 = actor.get("toilet_relief_position")
	if pos == Vector3.INF:
		resume_after_toilet(actor)
		return
	if bool(actor.call("_move_to", pos, delta)):
		actor.set("state", Citizen.State.USING_BUSH)
		var timer: Variant = actor.get("toilet_timer")
		if timer is CitizenTaskStateScript:
			timer.start(TOILET_USE_DURATION)

func process_using_bush(actor: Node3D, delta: float) -> void:
	if actor == null:
		return
	var timer: Variant = actor.get("toilet_timer")
	if timer is CitizenTaskStateScript and bool(timer.advance(delta)):
		var sat_cap: float = actor.get_satisfaction_cap() if actor is Citizen else 100.0
		var cur_sat: float = float(actor.get("satisfaction"))
		actor.set("satisfaction", minf(sat_cap, cur_sat + 10.0))
		resume_after_toilet(actor)
		if actor is Citizen:
			actor.emit_signal("relief_finished", actor)
