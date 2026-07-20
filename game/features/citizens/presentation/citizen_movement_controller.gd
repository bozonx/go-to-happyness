class_name CitizenMovementController
extends RefCounted


func move_to(actor: Citizen, destination: Vector3, delta: float, may_enter_destination_house := false, use_building_queue := true, record_trail := true, arrival_radius := 0.08) -> bool:
	if actor == null:
		return false
	var movement_destination := destination
	var is_queue_head := true
	if use_building_queue and actor.queue_position_resolver.is_valid():
		var queue_result: Dictionary = actor.queue_position_resolver.call(actor, destination)
		movement_destination = queue_result.get("position", destination)
		is_queue_head = bool(queue_result.get("is_head", true))
		if not is_queue_head and movement_destination.distance_to(actor.global_position) <= 0.05:
			stop_horizontal_movement(actor)
			return false

	if route_uses_stale_navigation(actor):
		invalidate_route_for_navigation_change(actor)

	var goal_changed := actor.path_destination.distance_to(movement_destination) > arrival_radius or actor.path_allows_destination_house != may_enter_destination_house
	if goal_changed:
		reset_route(actor, movement_destination)
		actor.path_allows_destination_house = may_enter_destination_house
		plan_route(actor, movement_destination)

	if actor.navigation_failed:
		if navigation_topology_changed_since_failure(actor):
			reset_route(actor, movement_destination)
			plan_route(actor, movement_destination)
		else:
			stop_horizontal_movement(actor)
			if actor.ai_move_failure_reason == BehaviorStep.FailureReason.NONE:
				actor.ai_move_failure_reason = BehaviorStep.FailureReason.MOVEMENT_FAILED
			return false

	if actor.active_route == null or not actor.active_route.reachable:
		actor.route_retry_timer = maxf(0.0, actor.route_retry_timer - delta)
		if actor.route_retry_timer <= 0.0:
			plan_route(actor, movement_destination)
		if actor.active_route == null or not actor.active_route.reachable:
			actor.route_unreachable_time += delta
			if actor.route_unreachable_time >= Citizen.ROUTE_UNREACHABLE_FAILURE_TIME:
				raise_navigation_failure(actor, BehaviorStep.FailureReason.UNREACHABLE)
				stop_horizontal_movement(actor)
			return false

	while not actor.movement_path.is_empty():
		var waypoint: Vector3 = actor.movement_path.front()
		var waypoint_offset := waypoint - actor.global_position
		waypoint_offset.y = 0.0
		var is_final_waypoint := actor.movement_path.size() == 1
		var waypoint_radius := maxf(arrival_radius, Citizen.PHYSICAL_ARRIVAL_RADIUS) if is_final_waypoint else 0.08
		if waypoint_offset.length() > waypoint_radius:
			return move_directly_to(actor, waypoint, delta, record_trail, waypoint_radius)
		actor.movement_path.pop_front()
		reset_waypoint_progress(actor)

	stop_horizontal_movement(actor)
	if is_queue_head and use_building_queue and actor.queue_arrival_notifier.is_valid():
		actor.queue_arrival_notifier.call(actor, destination)
	return is_queue_head


func move_directly_to(actor: Citizen, destination: Vector3, delta: float, record_trail := true, arrival_distance := 0.08) -> bool:
	if actor == null:
		return false
	var offset := destination - actor.global_position
	offset.y = 0.0
	if offset.length() <= arrival_distance:
		return true
	var direction := offset.normalized()
	var speed_modifier := float(actor.movement_speed_modifier_query.call(actor.global_position)) if actor.movement_speed_modifier_query.is_valid() else 1.0
	var current_walk_speed := actor.get_walk_speed() * speed_modifier
	var desired_velocity := direction * current_walk_speed
	actor.velocity.x = desired_velocity.x
	actor.velocity.z = desired_velocity.z
	actor.jump_cooldown = maxf(0.0, actor.jump_cooldown - delta)
	var position_before_move := actor.global_position
	var distance_before_move := offset.length()
	actor.move_and_slide()
	var horizontal_progress := Vector2(actor.global_position.x - position_before_move.x, actor.global_position.z - position_before_move.z).length()
	if record_trail and horizontal_progress > 0.01 and actor.trail_movement_recorder.is_valid():
		actor.trail_movement_recorder.call(actor.ai_id, actor.global_position)
	var distance_after_move := Vector2(destination.x - actor.global_position.x, destination.z - actor.global_position.z).length()
	update_route_progress(actor, distance_before_move, distance_after_move, delta, direction)
	if actor.is_on_floor() and horizontal_progress < current_walk_speed * delta * 0.15:
		actor.stuck_time += delta
		if actor.jump_cooldown <= 0.0:
			if actor.stuck_time >= Citizen.STUCK_TIME_BEFORE_REPATH and not actor.recovery_repath_done:
				force_repath(actor)
			elif actor.stuck_time >= Citizen.STUCK_TIME_BEFORE_JUMP and has_low_obstacle_ahead(actor, direction):
				jump_out_of_obstacle(actor)
	else:
		actor.stuck_time = 0.0
		actor.recovery_repath_done = false
	actor.look_at(actor.global_position + direction, Vector3.UP)
	return false


func apply_gravity(actor: Citizen, delta: float) -> void:
	if actor == null:
		return
	if not actor.ground_contact_confirmed:
		if not has_ground_below(actor):
			actor.velocity = Vector3.ZERO
			return
		actor.ground_contact_confirmed = true
	if not actor.is_on_floor() or actor.velocity.y > 0.0:
		actor.velocity.y -= Citizen.GRAVITY * delta
	else:
		actor.velocity.y = -0.5
	if actor.state == Citizen.State.IDLE or actor.state == Citizen.State.RESTING or actor.state == Citizen.State.WAITING:
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		actor.move_and_slide()


func process_idle_wander(actor: Citizen, delta: float) -> void:
	if actor == null:
		return
	if actor.idle_wander_anchor == Vector3.INF:
		actor.idle_wander_anchor = actor.global_position
		actor.idle_wander_pause = randf_range(Citizen.IDLE_WANDER_MIN_PAUSE, Citizen.IDLE_WANDER_MAX_PAUSE)
	if actor.idle_wander_target != Vector3.INF:
		if actor.navigation_failed:
			actor.idle_wander_target = Vector3.INF
			actor.navigation_failed = false
			actor.ai_move_failure_reason = BehaviorStep.FailureReason.NONE
			actor.idle_wander_pause = randf_range(Citizen.IDLE_WANDER_MIN_PAUSE, Citizen.IDLE_WANDER_MAX_PAUSE)
			stop_horizontal_movement(actor)
			return
		if move_to(actor, actor.idle_wander_target, delta, false, false, false):
			actor.idle_wander_target = Vector3.INF
			actor.idle_wander_pause = randf_range(Citizen.IDLE_WANDER_MIN_PAUSE, Citizen.IDLE_WANDER_MAX_PAUSE)
		return
	actor.idle_wander_pause -= delta
	actor.velocity.x = 0.0
	actor.velocity.z = 0.0
	if actor.idle_wander_pause > 0.0:
		return
	actor.idle_wander_target = choose_idle_wander_target(actor)
	if actor.idle_wander_target == Vector3.INF:
		actor.idle_wander_pause = Citizen.IDLE_WANDER_MIN_PAUSE


func choose_idle_wander_target(actor: Citizen) -> Vector3:
	if actor == null:
		return Vector3.INF
	var nearby_positions := nearby_citizen_positions(actor, actor.idle_wander_anchor, Citizen.IDLE_WANDER_RADIUS * 3.0)
	var best := Vector3.INF
	var best_score := -INF
	for ignored in range(Citizen.IDLE_WANDER_CANDIDATES):
		var angle := randf() * TAU
		var radius := randf_range(Citizen.IDLE_PERSONAL_SPACE, Citizen.IDLE_WANDER_RADIUS)
		var candidate := actor.idle_wander_anchor + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var reachable := bool(actor.route_reachability_query.call(actor.global_position, candidate, false)) if actor.route_reachability_query.is_valid() else true
		if not reachable:
			continue
		var nearest_neighbor := Citizen.IDLE_WANDER_RADIUS * 2.0
		for other_position in nearby_positions:
			nearest_neighbor = minf(nearest_neighbor, candidate.distance_to(other_position))
		var score := nearest_neighbor - candidate.distance_to(actor.idle_wander_anchor) * 0.08
		if score > best_score:
			best_score = score
			best = candidate
	return best


func nearby_citizen_positions(actor: Citizen, center: Vector3, radius: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if actor == null or actor.simulation == null:
		return positions
	var radius_squared := radius * radius
	for other in actor.simulation.citizens:
		if other == actor or not is_instance_valid(other):
			continue
		var other_position: Vector3 = other.global_position
		if center.distance_squared_to(other_position) <= radius_squared:
			positions.append(other_position)
	return positions


func plan_route(actor: Citizen, destination: Vector3) -> void:
	if actor == null:
		return
	var result: Variant = RouteResult.success([destination], destination)
	if actor.pathfinder.is_valid():
		result = actor.pathfinder.call(actor.global_position, destination, actor.path_allows_destination_house)
	if actor.recovery_detour_requested:
		actor.recovery_detour_requested = false
		if actor.recovery_pathfinder.is_valid():
			var detour: Variant = actor.recovery_pathfinder.call(actor.global_position, destination, actor.path_allows_destination_house)
			if detour is RouteResult and (detour as RouteResult).reachable:
				result = detour
	if not result is RouteResult or not (result as RouteResult).reachable:
		var failed_revision := int(actor.navigation_revision_query.call()) if actor.navigation_revision_query.is_valid() else -1
		var reason: int = (result as RouteResult).unreachable_reason if result is RouteResult else RouteResult.UnreachableReason.UNKNOWN
		actor.route_unreachable_reason = reason
		actor.active_route = RouteResult.unreachable(failed_revision, failed_revision, reason)
		actor.movement_path.clear()
		actor.route_retry_timer = actor.route_retry_delay
		actor.route_retry_delay = minf(Citizen.ROUTE_MAX_RETRY_INTERVAL, actor.route_retry_delay * 2.0)
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		return
	actor.active_route = result as RouteResult
	actor.movement_path = actor.active_route.waypoints.duplicate()
	actor.route_retry_timer = 0.0
	actor.route_retry_delay = Citizen.ROUTE_RETRY_INTERVAL
	actor.route_unreachable_time = 0.0
	actor.route_unreachable_reason = RouteResult.UnreachableReason.NONE
	actor.ai_move_failure_reason = BehaviorStep.FailureReason.NONE
	actor.recovery_repath_done = false


func raise_navigation_failure(actor: Citizen, reason: int) -> void:
	if actor == null:
		return
	actor.navigation_failed = true
	actor.ai_move_failure_reason = reason
	actor.navigation_failed_topology = int(actor.navigation_revision_query.call()) if actor.navigation_revision_query.is_valid() else -999


func navigation_topology_changed_since_failure(actor: Citizen) -> bool:
	if actor == null or not actor.navigation_revision_query.is_valid():
		return false
	var current := int(actor.navigation_revision_query.call())
	return current >= 0 and current != actor.navigation_failed_topology


func route_uses_stale_navigation(actor: Citizen) -> bool:
	if actor == null or actor.active_route == null or actor.active_route.topology_revision < 0 or not actor.navigation_revision_query.is_valid():
		return false
	var current_revision := int(actor.navigation_revision_query.call())
	if not actor.active_route.is_topologically_stale(current_revision):
		return false
	var route_origin := actor.global_position if actor.is_inside_tree() else actor.position
	if actor.route_safety_query.is_valid() and bool(actor.route_safety_query.call(route_origin, actor.movement_path, actor.path_allows_destination_house)):
		actor.active_route.topology_revision = current_revision
		return false
	return true


func invalidate_route_for_navigation_change(actor: Citizen) -> void:
	if actor == null:
		return
	actor.active_route = null
	actor.movement_path.clear()
	actor.route_retry_timer = randf_range(0.0, Citizen.STALE_NAVIGATION_REPLAN_JITTER)
	actor.route_retry_delay = Citizen.ROUTE_RETRY_INTERVAL
	actor.route_unreachable_time = 0.0
	actor.route_unreachable_reason = RouteResult.UnreachableReason.NONE
	actor.navigation_failed = false
	actor.ai_move_failure_reason = BehaviorStep.FailureReason.STALE_ROUTE
	actor.stuck_time = 0.0
	actor.recovery_repath_done = false
	actor.velocity.x = 0.0
	actor.velocity.z = 0.0


func has_low_obstacle_ahead(actor: Citizen, direction: Vector3) -> bool:
	if actor == null or not actor.is_inside_tree():
		return false
	var space_state := actor.get_world_3d().direct_space_state
	var forward := direction * 0.62
	var low_query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.22, actor.global_position + Vector3.UP * 0.22 + forward, actor.collision_mask)
	low_query.exclude = [actor.get_rid()]
	var low_hit := space_state.intersect_ray(low_query)
	if low_hit.is_empty():
		return false
	var collider: Object = low_hit.get("collider")
	if collider is Node and (collider as Node).has_meta("building_module"):
		return false
	var high_query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.9, actor.global_position + Vector3.UP * 0.9 + forward, actor.collision_mask)
	high_query.exclude = [actor.get_rid()]
	return space_state.intersect_ray(high_query).is_empty()


func jump_out_of_obstacle(actor: Citizen) -> void:
	if actor == null:
		return
	actor.velocity.y = Citizen.AI_JUMP_VELOCITY
	actor.jump_cooldown = 0.45
	actor.stuck_time = 0.0


func force_repath(actor: Citizen) -> void:
	if actor == null or actor.recovery_repath_done:
		return
	actor.route_recovery_attempt += 1
	if actor.route_recovery_attempt >= Citizen.ROUTE_RECOVERY_FAILURE_ATTEMPTS:
		raise_navigation_failure(actor, BehaviorStep.FailureReason.TIMEOUT)
		actor.active_route = null
		actor.movement_path.clear()
		stop_horizontal_movement(actor)
		return
	actor.active_route = null
	actor.movement_path.clear()
	actor.recovery_detour_requested = actor.route_recovery_attempt > 1
	actor.route_retry_timer = 0.0
	actor.route_retry_delay = Citizen.ROUTE_RETRY_INTERVAL
	actor.route_no_progress_time = 0.0
	actor.stuck_time = 0.0
	actor.recovery_repath_done = true


func reset_waypoint_progress(actor: Citizen) -> void:
	if actor == null:
		return
	actor.route_no_progress_time = 0.0
	actor.route_best_distance = INF
	actor.route_recovery_attempt = 0
	actor.stuck_time = 0.0
	actor.recovery_repath_done = false


func stop_horizontal_movement(actor: Citizen) -> void:
	if actor == null:
		return
	actor.velocity.x = 0.0
	actor.velocity.z = 0.0


func reset_route(actor: Citizen, destination: Vector3) -> void:
	if actor == null:
		return
	actor.path_destination = destination
	actor.route_no_progress_time = 0.0
	actor.route_best_distance = INF
	actor.route_recovery_attempt = 0
	actor.recovery_detour_requested = false
	actor.recovery_repath_done = false
	actor.route_retry_delay = Citizen.ROUTE_RETRY_INTERVAL
	actor.route_unreachable_time = 0.0
	actor.route_unreachable_reason = RouteResult.UnreachableReason.NONE
	actor.navigation_failed = false
	actor.ai_move_failure_reason = BehaviorStep.FailureReason.NONE


func update_route_progress(actor: Citizen, distance_before: float, distance_after: float, delta: float, direction: Vector3) -> void:
	if actor == null:
		return
	if distance_after < actor.route_best_distance - Citizen.ROUTE_PROGRESS_EPSILON:
		actor.route_best_distance = distance_after
		actor.route_no_progress_time = 0.0
		actor.route_recovery_attempt = 0
		return
	actor.route_no_progress_time += delta
	if actor.route_no_progress_time < Citizen.ROUTE_RETRY_INTERVAL:
		return
	actor.route_no_progress_time = 0.0
	force_repath(actor)


func has_ground_below(actor: Citizen) -> bool:
	if actor == null or not actor.is_inside_tree():
		return false
	var space_state := actor.get_world_3d().direct_space_state
	var origin := actor.global_position + Vector3.UP * 0.25
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 2.0, actor.collision_mask)
	query.exclude = [actor.get_rid()]
	return not space_state.intersect_ray(query).is_empty()
