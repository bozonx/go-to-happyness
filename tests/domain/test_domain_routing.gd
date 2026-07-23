class_name TestDomainRouting
extends RefCounted

const GridRouteServiceScript = preload("res://game/features/routing/application/grid_route_service.gd")
const RouteRequestScript = preload("res://game/features/routing/domain/route_request.gd")
const BuildingQueueServiceScript = preload("res://game/features/citizens/application/building_queue_service.gd")
const TrailFieldServiceScript = preload("res://game/features/routing/application/trail_field_service.gd")
const RoadNetworkServiceScript = preload("res://game/features/routing/application/road_network_service.gd")
const NavigationObstaclePublisherScript = preload("res://game/features/routing/application/navigation_obstacle_publisher.gd")
const RoadTypeScript = preload("res://game/features/routing/domain/road_type.gd")
const NavigationFacadeScript = preload("res://game/features/routing/application/navigation_facade.gd")


static func run_all() -> void:
	_test_grid_routing()
	_test_weighted_grid_routing()
	_test_route_result_unreachable_reasons()
	_test_navigation_grid_revision()
	_test_navigation_weight_validation()
	_test_weight_change_stales_active_route()
	_test_navigation_recovery_guards()
	_test_trail_field()
	_test_citizen_replans_on_navigation_revision()
	_test_citizen_keeps_unaffected_route_on_navigation_revision()
	_test_citizen_route_failure_marks_action_failed()
	_test_building_queue_routing()
	_test_route_for_traveler_profile()
	_test_segment_cost_with_profile()
	_test_trail_degrading_state()
	_test_trail_forget_walker()
	_test_refresh_connectivity()
	_test_route_result_is_topologically_stale()
	_test_incremental_weight_and_deferred_minimum()
	_test_is_segment_clear()
	_test_waypoint_path_clear_blocked_destination()
	_test_waypoint_path_clear_empty()
	_test_configure_noop()
	_test_route_start_equals_destination()
	_test_cell_center_round_trip()
	_test_diagonal_corner_cutting_prevented()
	_test_segment_cost_zero_length()
	_test_smooth_empty_fallback()
	_test_navigation_topology_changed_since_failure()
	_test_force_repath_recovery_limit()
	_test_update_route_progress_no_progress_repath()
	_test_plan_route_recovery_detour()
	_test_trail_cell_strength()
	_test_trail_decay_without_content()
	_test_constructed_roads_override_trails_and_restore_them()
	_test_road_network_validates_and_batches_changes()
	_test_navigation_obstacle_publisher()
	_test_navigation_facade_metrics()
	_test_nav_grid_and_facade_route_cost()
	_test_navigation_bridge_direct_configuration()


static func _route_polyline_cost(grid: NavGrid, start: Vector3, waypoints: Array[Vector3]) -> float:
	var total := 0.0
	var previous := start
	for waypoint in waypoints:
		total += grid.segment_cost(previous, waypoint)
		previous = waypoint
	return total


static func _test_grid_routing() -> void:
	var blocked: Dictionary = {}
	for y in range(-3, 3):
		blocked[Vector2i(1, y)] = true
	var grid := NavGrid.new()
	grid.configure(1.0, 6)
	grid.set_blocked_cells(blocked)
	var router: RefCounted = GridRouteServiceScript.new()
	router.configure(grid)
	var unreachable: RouteResult = router.find_route(Vector3(0.5, 0.0, 0.5), Vector3(2.5, 0.0, 0.5))
	assert(not unreachable.reachable and unreachable.waypoints.is_empty())

	blocked.erase(Vector2i(1, 2))
	grid.set_blocked_cells(blocked)
	var route: RouteResult = router.find_route(Vector3(0.5, 0.0, 0.5), Vector3(2.5, 0.0, 0.5))
	assert(route.reachable and route.arrival_position == Vector3(2.5, 0.0, 0.5))
	for waypoint in route.waypoints:
		assert(not blocked.has(Vector2i(floori(waypoint.x), floori(waypoint.z))))


static func _test_weighted_grid_routing() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var router: RefCounted = GridRouteServiceScript.new()
	router.configure(grid)

	var diagonal_destination := Vector3(3.5, 0.0, 3.5)
	var diagonal_route: RouteResult = router.find_route(Vector3(0.5, 0.0, 0.5), diagonal_destination)
	assert(diagonal_route.reachable and diagonal_route.waypoints == [diagonal_destination])

	grid.set_blocked_cells({Vector2i(1, 0): true, Vector2i(0, 1): true, Vector2i(-1, 0): true, Vector2i(0, -1): true})
	var corner_route: RouteResult = router.find_route(Vector3(0.5, 0.0, 0.5), Vector3(1.5, 0.0, 1.5))
	assert(not corner_route.reachable)
	grid.set_blocked_cells({})

	var weights: Dictionary = {}
	for x in range(-2, 3):
		weights[Vector2i(x, 0)] = 10.0
	for x in range(-2, 3):
		weights[Vector2i(x, 1)] = 0.5
	grid.set_cell_weights(weights)
	var start := Vector3(-2.5, 0.0, 0.5)
	var destination := Vector3(3.5, 0.0, 0.5)
	var weighted_route: RouteResult = router.find_route(start, destination)
	assert(weighted_route.reachable)
	var uses_cheap_corridor := false
	for waypoint in weighted_route.waypoints:
		uses_cheap_corridor = uses_cheap_corridor or waypoint.z > 1.0
	assert(uses_cheap_corridor)
	assert(grid.segment_cost(start, destination) > 1.08 * _route_polyline_cost(grid, start, weighted_route.waypoints))

	grid.set_blocked_cells({Vector2i(3, 0): true})
	var blocked_destination: RouteResult = router.find_route(start, destination)
	assert(not blocked_destination.reachable)
	var allowed_request: RefCounted = RouteRequestScript.new()
	allowed_request.from = start
	allowed_request.destination = destination
	allowed_request.allow_destination_cell = true
	assert(router.find_route_request(allowed_request).reachable)


static func _test_route_result_unreachable_reasons() -> void:
	var router_without_grid: RefCounted = GridRouteServiceScript.new()
	var no_grid: RouteResult = router_without_grid.find_route(Vector3.ZERO, Vector3.ONE)
	assert(not no_grid.reachable)
	assert(no_grid.unreachable_reason == RouteResult.UnreachableReason.NO_GRID)

	var grid := NavGrid.new()
	grid.configure(1.0, 6)
	var router: RefCounted = GridRouteServiceScript.new()
	router.configure(grid)
	var outside: RouteResult = router.find_route(Vector3.ZERO, Vector3(20.0, 0.0, 0.0))
	assert(not outside.reachable)
	assert(outside.unreachable_reason == RouteResult.UnreachableReason.OUTSIDE_BOARD)

	var destination := Vector3(2.5, 0.0, 0.5)
	grid.set_blocked_cells({Vector2i(2, 0): true})
	var goal_blocked: RouteResult = router.find_route(Vector3(-2.5, 0.0, 0.5), destination)
	assert(not goal_blocked.reachable)
	assert(goal_blocked.unreachable_reason == RouteResult.UnreachableReason.GOAL_BLOCKED)

	grid.set_blocked_cells({
		Vector2i(0, -3): true,
		Vector2i(0, -2): true,
		Vector2i(0, -1): true,
		Vector2i(0, 0): true,
		Vector2i(0, 1): true,
		Vector2i(0, 2): true,
	})
	var disconnected: RouteResult = router.find_route(Vector3(-2.5, 0.0, 0.5), destination)
	assert(not disconnected.reachable)
	assert(disconnected.unreachable_reason == RouteResult.UnreachableReason.DISCONNECTED)


static func _test_navigation_grid_revision() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var router: RefCounted = GridRouteServiceScript.new()
	router.configure(grid)
	var initial_revision := grid.revision()
	grid.set_blocked_cells({})
	grid.set_cell_weights({})
	assert(grid.revision() == initial_revision)

	var route: RouteResult = router.find_route(Vector3(-2.5, 0.0, 0.5), Vector3(2.5, 0.0, 0.5))
	assert(route.reachable and route.grid_revision == initial_revision)
	grid.set_cell_weights({Vector2i(0, 1): 0.5})
	assert(grid.revision() == initial_revision + 1)
	assert(grid.minimum_cell_weight() == 0.5)
	assert(route.grid_revision != grid.revision())
	assert(is_equal_approx(grid.get_cell_weight(Vector2i(4, 4)), NavGrid.DEFAULT_CELL_WEIGHT))
	grid.set_cell_weights({Vector2i(0, 1): 0.5})
	assert(grid.revision() == initial_revision + 1)
	grid.set_blocked_cells({Vector2i(0, 0): true})
	assert(grid.revision() == initial_revision + 2)
	assert(grid.topology_revision() == route.grid_revision + 1)


static func _test_navigation_weight_validation() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var cell := Vector2i(1, 1)
	grid.set_cell_weights({
		cell: 999.0,
		Vector2i(2, 2): -4.0,
		Vector2i(3, 3): INF,
		"not_a_cell": 0.5,
	})
	assert(is_equal_approx(grid.get_cell_weight(cell), NavGrid.MAX_CELL_WEIGHT))
	assert(is_equal_approx(grid.get_cell_weight(Vector2i(2, 2)), NavGrid.DEFAULT_CELL_WEIGHT))
	assert(is_equal_approx(grid.get_cell_weight(Vector2i(3, 3)), NavGrid.DEFAULT_CELL_WEIGHT))
	assert(is_equal_approx(grid.movement_speed_modifier_at(grid.cell_center(cell)), 1.0 / NavGrid.MAX_CELL_WEIGHT))
	grid.set_profile_cell_weights(&"cart", {cell: 0.0001})
	assert(is_equal_approx(grid.get_cell_weight(cell, &"cart"), NavGrid.MIN_CELL_WEIGHT))


static func _test_weight_change_stales_active_route() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var router: RefCounted = GridRouteServiceScript.new()
	router.configure(grid)
	var route: RouteResult = router.find_route(Vector3(-2.5, 0.0, 0.5), Vector3(2.5, 0.0, 0.5))
	assert(route.reachable)
	var citizen := Citizen.new()
	citizen.navigation_revision_query = func() -> int: return grid.topology_revision()
	citizen.active_route = route
	assert(not citizen._route_uses_stale_navigation())
	grid.set_cell_weights({Vector2i(0, 1): 0.5})
	assert(not citizen._route_uses_stale_navigation())
	grid.set_blocked_cells({Vector2i(0, 1): true})
	assert(citizen._route_uses_stale_navigation())
	citizen.free()


static func _test_navigation_recovery_guards() -> void:
	var citizen := Citizen.new()
	var revisions := [5]
	citizen.navigation_revision_query = func() -> int: return revisions[0]
	citizen.active_route = RouteResult.unreachable(4)
	citizen.navigation_failed = true
	citizen._invalidate_route_for_navigation_change()
	assert(not citizen.navigation_failed)
	assert(citizen.active_route == null)
	citizen._force_repath()
	var attempts := citizen.route_recovery_attempt
	citizen._force_repath()
	assert(citizen.route_recovery_attempt == attempts)
	citizen.route_recovery_attempt = 3
	citizen.recovery_repath_done = false
	citizen.velocity = Vector3(1.0, 0.0, 1.0)
	citizen._force_repath()
	assert(citizen.navigation_failed)
	assert(is_zero_approx(citizen.velocity.x) and is_zero_approx(citizen.velocity.z))
	citizen.navigation_failed = false
	citizen.route_recovery_attempt = 2
	citizen._reset_waypoint_progress()
	assert(citizen.route_recovery_attempt == 0)
	citizen.free()


static func _test_trail_field() -> void:
	var normal: RefCounted = TrailFieldServiceScript.new()
	normal.configure(12.0)
	normal.record_walker_position(1, Vector3.ZERO, false)
	normal.record_walker_position(1, Vector3(0.2, 0.0, 0.0), false)
	assert(normal.total_strength() == 0)
	normal.record_walker_position(1, Vector3(0.6, 0.0, 0.0), false)
	var normal_strength: float = normal.total_strength()
	assert(normal_strength > 0)
	var ordered: RefCounted = TrailFieldServiceScript.new()
	ordered.configure(12.0)
	ordered.record_walker_position(1, Vector3.ZERO, true)
	ordered.record_walker_position(1, Vector3(0.6, 0.0, 0.0), true)
	assert(ordered.total_strength() > normal_strength)
	for _day in range(40):
		normal.apply_daily_decay()
	assert(normal.total_strength() == 0)

	var grid := NavGrid.new()
	grid.configure(1.0, 12)
	var trails: RefCounted = TrailFieldServiceScript.new()
	trails.configure(12.0, 1.0, grid)
	var initial_revision := grid.revision()
	var path_cell := Vector2i(1, 0)
	trails.record_walker_position(2, Vector3(0.1, 0.0, 0.1), false)
	for _entry in range(3):
		trails.record_walker_position(2, Vector3(1.1, 0.0, 0.1), false)
		trails.record_walker_position(2, Vector3(0.1, 0.0, 0.1), false)
	assert(trails.cell_state(path_cell) == TrailFieldService.TrailState.NONE)
	assert(is_equal_approx(grid.get_cell_weight(path_cell), NavGrid.DEFAULT_CELL_WEIGHT))
	trails.record_walker_position(2, Vector3(1.1, 0.0, 0.1), false)
	assert(trails.cell_state(path_cell) == TrailFieldService.TrailState.YOUNG)
	assert(is_equal_approx(grid.get_cell_weight(path_cell), TrailFieldService.YOUNG_PATH_WEIGHT))
	assert(is_equal_approx(grid.get_cell_weight(path_cell, &"cart"), NavGrid.DEFAULT_CELL_WEIGHT))
	assert(grid.revision() > initial_revision)
	var young_revision := grid.revision()
	for _entry in range(5):
		trails.record_walker_position(2, Vector3(0.1, 0.0, 0.1), false)
		trails.record_walker_position(2, Vector3(1.1, 0.0, 0.1), false)
	assert(trails.cell_state(path_cell) == TrailFieldService.TrailState.MATURE)
	assert(is_equal_approx(grid.get_cell_weight(path_cell), TrailFieldService.MATURE_PATH_WEIGHT))
	assert(grid.revision() > young_revision)

	var ordered_grid := NavGrid.new()
	ordered_grid.configure(1.0, 12)
	var ordered_trails: RefCounted = TrailFieldServiceScript.new()
	ordered_trails.configure(12.0, 1.0, ordered_grid)
	ordered_trails.record_walker_position(3, Vector3(0.1, 0.0, 0.1), true)
	ordered_trails.record_walker_position(3, Vector3(1.1, 0.0, 0.1), true)
	ordered_trails.record_walker_position(3, Vector3(0.1, 0.0, 0.1), true)
	ordered_trails.record_walker_position(3, Vector3(1.1, 0.0, 0.1), true)
	assert(ordered_trails.cell_state(path_cell) == TrailFieldService.TrailState.YOUNG)

	for _day in range(20):
		trails.apply_daily_decay()
	assert(trails.cell_state(path_cell) == TrailFieldService.TrailState.NONE)
	assert(not trails.active_weight_overrides().has(path_cell))
	assert(is_equal_approx(grid.get_cell_weight(path_cell), NavGrid.DEFAULT_CELL_WEIGHT))


static func _test_citizen_replans_on_navigation_revision() -> void:
	var citizen := Citizen.new()
	var navigation_revisions := [3]
	citizen.navigation_revision_query = func() -> int: return navigation_revisions[0]
	citizen.active_route = RouteResult.success([Vector3(1.0, 0.0, 0.0)], Vector3(1.0, 0.0, 0.0), navigation_revisions[0], navigation_revisions[0])
	assert(not citizen._route_uses_stale_navigation())
	navigation_revisions[0] += 1
	assert(citizen._route_uses_stale_navigation())
	citizen._invalidate_route_for_navigation_change()
	assert(citizen.active_route == null)
	assert(citizen.route_retry_timer >= 0.0 and citizen.route_retry_timer <= Citizen.STALE_NAVIGATION_REPLAN_JITTER)
	citizen.free()


static func _test_citizen_keeps_unaffected_route_on_navigation_revision() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var router: RefCounted = GridRouteServiceScript.new()
	router.configure(grid)
	var start := Vector3(-3.5, 0.0, 0.5)
	var destination := Vector3(3.5, 0.0, 0.5)
	var route: RouteResult = router.find_route(start, destination)
	assert(route.reachable)
	var citizen := Citizen.new()
	citizen.position = start
	citizen.active_route = route
	citizen.movement_path = route.waypoints.duplicate()
	citizen.navigation_revision_query = func() -> int: return grid.topology_revision()
	citizen.route_safety_query = func(from: Vector3, waypoints: Array[Vector3], allow_blocked: bool) -> bool:
		return grid.is_waypoint_path_clear(from, waypoints, allow_blocked)
	grid.set_blocked_cells({Vector2i(0, 3): true})
	assert(not citizen._route_uses_stale_navigation())
	assert(citizen.active_route.topology_revision == grid.topology_revision())
	grid.set_blocked_cells({Vector2i(0, 0): true})
	assert(citizen._route_uses_stale_navigation())
	citizen.free()


static func _test_citizen_route_failure_marks_action_failed() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 11
	citizen.navigation_revision_query = func() -> int:
		return 4
	citizen.start_production_cycle("wood", Vector3(3.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0), false, Vector3(1.0, 0.0, 0.0))
	citizen.path_destination = Vector3(1.0, 0.0, 0.0)
	citizen.active_route = RouteResult.unreachable(4)
	citizen.route_retry_timer = Citizen.ROUTE_UNREACHABLE_FAILURE_TIME * 2.0
	for _i in range(ceili(Citizen.ROUTE_UNREACHABLE_FAILURE_TIME / 0.5) + 1):
		citizen._process_to_source(0.5)
	assert(citizen.get_action_status(&"forestry") == CitizenActuator.ActionStatus.FAILED)
	assert(citizen.ai_move_failure_reason == BehaviorStep.FailureReason.UNREACHABLE)
	citizen.free()


static func _test_building_queue_routing() -> void:
	var registry := BuildingRegistry.new()
	var building := Node3D.new()
	building.position = Vector3(1.5, 0.0, 1.5)
	building.set_meta("service_position", Vector3(2.5, 0.0, 1.5))
	registry.reserve(Vector2i(1, 1), building.position, Vector2i.ONE)
	registry.attach_node(Vector2i(1, 1), building)
	var blocked := {Vector2i(3, 1): true}
	var grid := NavGrid.new()
	grid.configure(1.0, 12)
	grid.set_blocked_cells(blocked)
	var queues: RefCounted = BuildingQueueServiceScript.new()
	queues.configure(registry, grid)
	var first := Node3D.new()
	var second := Node3D.new()
	var third := Node3D.new()
	var service_position: Vector3 = building.get_meta("service_position")
	var head: Dictionary = queues.resolve(first, service_position)
	var middle: Dictionary = queues.resolve(second, service_position)
	var tail: Dictionary = queues.resolve(third, service_position)
	assert(head.is_head and head.position == service_position)
	assert(not middle.is_head and not blocked.has(Vector2i(floori(middle.position.x), floori(middle.position.z))))
	assert(not tail.is_head and tail.position != middle.position)
	queues.complete_arrival(first, service_position)
	assert(not queues.resolve(second, service_position).is_head)
	queues._last_admitted_frame[building.get_instance_id()][0] = Engine.get_physics_frames() - 1
	assert(not queues.resolve(second, service_position).is_head)
	queues.release(first)
	assert(queues.resolve(second, service_position).is_head)
	queues.release(second)
	assert(queues.resolve(third, service_position).is_head)
	var overflow_positions: Dictionary = {}
	var overflow_nodes: Array[Node3D] = []
	for index in range(24):
		var queued := Node3D.new()
		queued.position = Vector3(-5.0 + index * 0.1, 0.0, -5.0)
		overflow_nodes.append(queued)
		var result: Dictionary = queues.resolve(queued, service_position)
		var key := "%0.3f:%0.3f" % [result.position.x, result.position.z]
		assert(not overflow_positions.has(key))
		overflow_positions[key] = true
	for queued in overflow_nodes:
		queues.release(queued)
		queued.free()
	first.free()
	second.free()
	third.free()
	building.free()


static func _test_route_for_traveler_profile() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var router: RefCounted = GridRouteServiceScript.new()
	router.configure(grid)
	var start := Vector3(-2.5, 0.0, 0.5)
	var destination := Vector3(2.5, 0.0, 0.5)
	# Baseline: pedestrian sees no cheap corridor, takes the direct route.
	var pedestrian_route: RouteResult = router.find_route(start, destination)
	assert(pedestrian_route.reachable)
	# Give the cart profile a cheap corridor along y=1 so the cart route
	# diverges from the straight pedestrian line.
	var cart_weights: Dictionary = {}
	for x in range(-2, 3):
		cart_weights[Vector2i(x, 1)] = 0.1
	grid.set_profile_cell_weights(&"cart", cart_weights)
	var cart_route: RouteResult = router.find_route_for_profile(start, destination, &"cart")
	assert(cart_route.reachable)
	# The cart route must use the cheap corridor (some waypoint has z > 1.0).
	var cart_uses_corridor := false
	for waypoint in cart_route.waypoints:
		cart_uses_corridor = cart_uses_corridor or waypoint.z > 1.0
	assert(cart_uses_corridor)
	# The pedestrian route must NOT use the corridor — profile weights are isolated.
	var ped_uses_corridor := false
	for waypoint in pedestrian_route.waypoints:
		ped_uses_corridor = ped_uses_corridor or waypoint.z > 1.0
	assert(not ped_uses_corridor)


static func _test_segment_cost_with_profile() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var from := Vector3(0.5, 0.0, 0.5)
	var to := Vector3(2.5, 0.0, 0.5)
	var pedestrian_cost := grid.segment_cost(from, to)
	assert(is_finite(pedestrian_cost))
	# Make the cart profile cheaper on the middle cell.
	grid.set_profile_cell_weights(&"cart", {Vector2i(1, 0): 0.1})
	var cart_cost := grid.segment_cost(from, to, &"cart")
	assert(is_finite(cart_cost))
	assert(cart_cost < pedestrian_cost)
	# Pedestrian cost must be unchanged after setting a cart-only weight.
	assert(is_equal_approx(grid.segment_cost(from, to), pedestrian_cost))
	# segment_cost on a blocked cell returns INF for any profile.
	grid.set_blocked_cells({Vector2i(1, 0): true})
	assert(not is_finite(grid.segment_cost(from, to)))
	assert(not is_finite(grid.segment_cost(from, to, &"cart")))


static func _test_trail_degrading_state() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 12)
	var trails: RefCounted = TrailFieldServiceScript.new()
	trails.configure(12.0, 1.0, grid)
	var path_cell := Vector2i(1, 0)
	# Build up to MATURE.
	for _entry in range(10):
		trails.record_walker_position(1, Vector3(0.1, 0.0, 0.1), false)
		trails.record_walker_position(1, Vector3(1.1, 0.0, 0.1), false)
	assert(trails.cell_state(path_cell) == TrailFieldService.TrailState.MATURE)
	# One day of decay drops strength but not below PATH_DEGRADE_THRESHOLD yet —
	# the cell must still be MATURE or YOUNG, not NONE.
	trails.apply_daily_decay()
	assert(trails.cell_state(path_cell) != TrailFieldService.TrailState.NONE)
	# Continue decaying until strength falls below PATH_DEGRADE_THRESHOLD.
	# The cell should enter DEGRADING (low_days < PATH_DEGRADE_DAYS) before NONE.
	var saw_degrading := false
	for _day in range(20):
		trails.apply_daily_decay()
		var state: int = trails.cell_state(path_cell)
		if state == TrailFieldService.TrailState.DEGRADING:
			saw_degrading = true
		elif state == TrailFieldService.TrailState.NONE:
			break
	assert(saw_degrading)
	# After enough decay days the cell returns to NONE.
	for _day in range(10):
		trails.apply_daily_decay()
	assert(trails.cell_state(path_cell) == TrailFieldService.TrailState.NONE)


static func _test_trail_forget_walker() -> void:
	var trails: RefCounted = TrailFieldServiceScript.new()
	trails.configure(12.0)
	# Record a first position, then forget the walker.
	trails.record_walker_position(1, Vector3.ZERO, false)
	trails.forget_walker(1)
	# After forgetting, the next call must register as a first position (no stamp).
	trails.record_walker_position(1, Vector3(0.6, 0.0, 0.0), false)
	assert(trails.total_strength() == 0)
	# A subsequent move beyond SAMPLE_DISTANCE stamps normally.
	trails.record_walker_position(1, Vector3(1.2, 0.0, 0.0), false)
	assert(trails.total_strength() > 0)


static func _test_refresh_connectivity() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 6)
	# Before any topology change, refresh_connectivity builds the component cache.
	grid.refresh_connectivity()
	assert(grid.are_cells_connected(Vector2i(-2, 0), Vector2i(2, 0)))
	# Split the board with a wall.
	var barrier: Dictionary = {}
	for y in range(-3, 3):
		barrier[Vector2i(0, y)] = true
	grid.set_blocked_cells(barrier)
	# After a topology change, the old component cache is stale.
	# refresh_connectivity rebuilds it so are_cells_connected reflects the split.
	grid.refresh_connectivity()
	assert(not grid.are_cells_connected(Vector2i(-2, 0), Vector2i(2, 0)))
	# Open a gap in the wall.
	barrier.erase(Vector2i(0, 0))
	grid.set_blocked_cells(barrier)
	grid.refresh_connectivity()
	assert(grid.are_cells_connected(Vector2i(-2, 0), Vector2i(2, 0)))


static func _test_route_result_is_topologically_stale() -> void:
	var result := RouteResult.success([Vector3(1.0, 0.0, 0.0)], Vector3(1.0, 0.0, 0.0), 5, 5)
	# Same topology revision → not stale.
	assert(not result.is_topologically_stale(5))
	# Different topology revision → stale.
	assert(result.is_topologically_stale(6))
	# An unreachable result with no topology revision is never stale.
	var unreachable := RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)
	assert(not unreachable.is_topologically_stale(10))


static func _test_incremental_weight_and_deferred_minimum() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	# Set a low wholesale weight so the minimum is 0.1.
	grid.set_cell_weights({Vector2i(0, 0): 0.1})
	assert(is_equal_approx(grid.minimum_cell_weight(), 0.1))
	# Incremental single-cell update with an even lower weight.
	grid.set_profile_cell_weight(&"cart", Vector2i(1, 0), 0.08)
	assert(is_equal_approx(grid.minimum_cell_weight(), 0.08))
	# Erase the cell that held the minimum — the recompute is deferred.
	grid.erase_profile_cell_weight(&"cart", Vector2i(1, 0))
	# The minimum must be recomputed on the next query, restoring 0.1.
	assert(is_equal_approx(grid.minimum_cell_weight(), 0.1))
	# Erasing a non-existent profile weight is a no-op (no revision bump).
	var revision_before := grid.revision()
	grid.erase_profile_cell_weight(&"cart", Vector2i(99, 99))
	assert(grid.revision() == revision_before)
	# set_profile_cell_weight with invalid weight erases the cell instead.
	grid.set_profile_cell_weight(&"cart", Vector2i(2, 2), 0.05)
	assert(is_equal_approx(grid.get_cell_weight(Vector2i(2, 2), &"cart"), NavGrid.MIN_CELL_WEIGHT))
	grid.set_profile_cell_weight(&"cart", Vector2i(2, 2), -1.0)
	assert(is_equal_approx(grid.get_cell_weight(Vector2i(2, 2), &"cart"), NavGrid.DEFAULT_CELL_WEIGHT))


static func _test_is_segment_clear() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	# Clear segment on an open board.
	assert(grid.is_segment_clear(Vector3(0.5, 0.0, 0.5), Vector3(2.5, 0.0, 0.5)))
	# Segment crossing a blocked cell is not clear.
	grid.set_blocked_cells({Vector2i(1, 0): true})
	assert(not grid.is_segment_clear(Vector3(0.5, 0.0, 0.5), Vector3(2.5, 0.0, 0.5)))
	# Segment that only touches the corner of a blocked cell is not clear.
	grid.set_blocked_cells({Vector2i(1, 1): true})
	assert(not grid.is_segment_clear(Vector3(0.5, 0.0, 0.5), Vector3(2.5, 0.0, 2.5)))
	# Segment parallel to a blocked cell but not touching it is clear.
	grid.set_blocked_cells({Vector2i(2, 2): true})
	assert(grid.is_segment_clear(Vector3(0.5, 0.0, 0.5), Vector3(4.5, 0.0, 0.5)))


static func _test_waypoint_path_clear_blocked_destination() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var from := Vector3(0.5, 0.0, 0.5)
	var destination := Vector3(2.5, 0.0, 0.5)
	grid.set_blocked_cells({Vector2i(2, 0): true})
	# Without allow_blocked_destination, the path to a blocked destination is not clear.
	assert(not grid.is_waypoint_path_clear(from, [destination], false))
	# With allow_blocked_destination and a blocked destination cell, the path is clear
	# because the final waypoint is the destination cell itself.
	assert(grid.is_waypoint_path_clear(from, [destination], true))
	# Intermediate blocked cell still makes the path not clear even with allow.
	grid.set_blocked_cells({Vector2i(1, 0): true, Vector2i(2, 0): true})
	assert(not grid.is_waypoint_path_clear(from, [Vector3(1.5, 0.0, 0.5), destination], true))


static func _test_waypoint_path_clear_empty() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	assert(grid.is_waypoint_path_clear(Vector3(0.5, 0.0, 0.5), []))
	assert(grid.is_waypoint_path_clear(Vector3(0.5, 0.0, 0.5), [], true))


static func _test_configure_noop() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var revision := grid.revision()
	var topology_revision := grid.topology_revision()
	# Calling configure with the same parameters must not bump revisions.
	grid.configure(1.0, 10)
	assert(grid.revision() == revision)
	assert(grid.topology_revision() == topology_revision)
	# Different cell size bumps both revisions.
	grid.configure(2.0, 10)
	assert(grid.revision() == revision + 1)
	assert(grid.topology_revision() == topology_revision + 1)


static func _test_route_start_equals_destination() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var router: RefCounted = GridRouteServiceScript.new()
	router.configure(grid)
	var pos := Vector3(0.5, 0.0, 0.5)
	var route: RouteResult = router.find_route(pos, pos)
	assert(route.reachable)
	assert(route.arrival_position == pos)
	# A route from a point to itself should have at least one waypoint.
	assert(not route.waypoints.is_empty())


static func _test_cell_center_round_trip() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	for cell in [Vector2i(0, 0), Vector2i(-3, 2), Vector2i(4, -1), Vector2i(-5, 5)]:
		var center := grid.cell_center(cell)
		var round_trip := grid.cell_from_position(center)
		assert(round_trip == cell)
	# cell_center places the point at the middle of the cell.
	assert(grid.cell_center(Vector2i(0, 0)) == Vector3(0.5, 0.0, 0.5))
	assert(grid.cell_center(Vector2i(-1, -1)) == Vector3(-0.5, 0.0, -0.5))


static func _test_diagonal_corner_cutting_prevented() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var router: RefCounted = GridRouteServiceScript.new()
	router.configure(grid)
	# Block the two orthogonal neighbors of a diagonal step so the diagonal
	# corner-cutting guard in _search rejects the move.
	# To go from (0,0) to (1,1) diagonally, both (1,0) and (0,1) must be walkable.
	grid.set_blocked_cells({Vector2i(1, 0): true, Vector2i(0, 1): true})
	var start := Vector3(0.5, 0.0, 0.5)
	var destination := Vector3(1.5, 0.0, 1.5)
	var route: RouteResult = router.find_route(start, destination)
	# The direct diagonal is blocked, but a path around should still exist.
	assert(route.reachable)
	# No waypoint may sit on a blocked cell.
	for waypoint in route.waypoints:
		assert(not grid.is_blocked(grid.cell_from_position(waypoint)))
	# Now wall off the destination completely so no path exists.
	grid.set_blocked_cells({
		Vector2i(1, 0): true, Vector2i(0, 1): true,
		Vector2i(2, 0): true, Vector2i(1, 2): true, Vector2i(0, 2): true,
		Vector2i(2, 1): true,
	})
	var walled: RouteResult = router.find_route(start, destination)
	assert(not walled.reachable)


static func _test_segment_cost_zero_length() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var pos := Vector3(0.5, 0.0, 0.5)
	assert(is_zero_approx(grid.segment_cost(pos, pos)))
	# Zero-length on a blocked cell still returns INF (start/end not walkable).
	grid.set_blocked_cells({Vector2i(0, 0): true})
	assert(not is_finite(grid.segment_cost(pos, pos)))


static func _test_smooth_empty_fallback() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var router: RefCounted = GridRouteServiceScript.new()
	router.configure(grid)
	# A route where start and destination are in the same cell produces a
	# single-point path. _smooth returns empty for single-point input, so the
	# fallback at line 77-78 must supply [destination].
	var pos := Vector3(0.5, 0.0, 0.5)
	var nearby := Vector3(0.6, 0.0, 0.6)
	var route: RouteResult = router.find_route(pos, nearby)
	assert(route.reachable)
	assert(not route.waypoints.is_empty())
	assert(route.waypoints[0] == nearby)


static func _test_navigation_topology_changed_since_failure() -> void:
	var citizen := Citizen.new()
	var revisions := [5]
	citizen.navigation_revision_query = func() -> int: return revisions[0]
	citizen.navigation_failed = true
	citizen.navigation_failed_topology = 5
	# Same topology revision → no change detected.
	assert(not citizen._navigation_topology_changed_since_failure())
	# Different topology revision → change detected.
	revisions[0] = 6
	assert(citizen._navigation_topology_changed_since_failure())
	# No navigation_revision_query → always false.
	citizen.navigation_revision_query = Callable()
	assert(not citizen._navigation_topology_changed_since_failure())
	citizen.free()


static func _test_force_repath_recovery_limit() -> void:
	var citizen := Citizen.new()
	citizen.navigation_revision_query = func() -> int: return 1
	# Each force_repath increments route_recovery_attempt.
	citizen._force_repath()
	assert(citizen.route_recovery_attempt == 1)
	assert(citizen.recovery_repath_done)
	citizen.recovery_repath_done = false
	citizen._force_repath()
	assert(citizen.route_recovery_attempt == 2)
	# After ROUTE_RECOVERY_FAILURE_ATTEMPTS, force_repath raises navigation_failure.
	citizen.recovery_repath_done = false
	citizen.route_recovery_attempt = Citizen.ROUTE_RECOVERY_FAILURE_ATTEMPTS - 1
	citizen._force_repath()
	assert(citizen.navigation_failed)
	assert(citizen.ai_move_failure_reason == BehaviorStep.FailureReason.TIMEOUT)
	assert(citizen.active_route == null)
	assert(citizen.movement_path.is_empty())
	# After failure, recovery_repath_done is NOT set, so a subsequent _force_repath
	# re-enters and increments route_recovery_attempt again (the guard is
	# recovery_repath_done, not the attempt count).
	var attempts_after_failure := citizen.route_recovery_attempt
	citizen._force_repath()
	assert(citizen.route_recovery_attempt == attempts_after_failure + 1)
	citizen.free()


static func _test_update_route_progress_no_progress_repath() -> void:
	var citizen := Citizen.new()
	citizen.navigation_revision_query = func() -> int: return 1
	citizen.pathfinder = func(_from: Vector3, target: Vector3, _allow: bool) -> RouteResult:
		return RouteResult.success([target], target)
	citizen.active_route = RouteResult.success([Vector3(5.0, 0.0, 0.0)], Vector3(5.0, 0.0, 0.0), 1, 1)
	citizen.movement_path = [Vector3(5.0, 0.0, 0.0)]
	citizen.route_best_distance = 10.0
	# Progress: distance_after improves by more than epsilon → resets no_progress_time.
	citizen._update_route_progress(10.0, 5.0, 0.5, Vector3(1.0, 0.0, 0.0))
	assert(is_equal_approx(citizen.route_best_distance, 5.0))
	assert(citizen.route_no_progress_time == 0.0)
	# No progress: distance_after doesn't improve → accumulates no_progress_time.
	citizen._update_route_progress(5.0, 5.0, 0.5, Vector3(1.0, 0.0, 0.0))
	assert(citizen.route_no_progress_time > 0.0)
	# After enough no-progress time, force_repath is triggered.
	citizen.route_no_progress_time = Citizen.ROUTE_RETRY_INTERVAL
	citizen._update_route_progress(5.0, 5.0, 0.5, Vector3(1.0, 0.0, 0.0))
	assert(citizen.route_no_progress_time == 0.0)
	assert(citizen.recovery_repath_done)
	citizen.free()


static func _test_plan_route_recovery_detour() -> void:
	var citizen := Citizen.new()
	citizen.position = Vector3.ZERO
	citizen.navigation_revision_query = func() -> int: return 1
	var path_calls := [0]
	var detour_calls := [0]
	citizen.pathfinder = func(_from: Vector3, target: Vector3, _allow: bool) -> RouteResult:
		path_calls[0] += 1
		return RouteResult.success([target], target)
	citizen.recovery_pathfinder = func(_from: Vector3, target: Vector3, _allow: bool) -> RouteResult:
		detour_calls[0] += 1
		return RouteResult.success([target + Vector3(2.0, 0.0, 0.0)], target)
	# Normal plan_route: only pathfinder is called.
	citizen._plan_route(Vector3(5.0, 0.0, 0.0))
	assert(path_calls[0] == 1)
	assert(detour_calls[0] == 0)
	assert(not citizen.recovery_detour_requested)
	# With recovery_detour_requested, recovery_pathfinder is called and its result used.
	citizen.recovery_detour_requested = true
	citizen._plan_route(Vector3(5.0, 0.0, 0.0))
	assert(detour_calls[0] == 1)
	assert(not citizen.recovery_detour_requested)
	assert(citizen.active_route.reachable)
	assert(citizen.active_route.waypoints[0] == Vector3(7.0, 0.0, 0.0))
	citizen.free()


static func _test_trail_cell_strength() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 12)
	var trails: RefCounted = TrailFieldServiceScript.new()
	trails.configure(12.0, 1.0, grid)
	var path_cell := Vector2i(1, 0)
	# Before any walking, cell_strength is zero.
	assert(is_zero_approx(trails.cell_strength(path_cell)))
	# Walk enough to register cell entries.
	trails.record_walker_position(1, Vector3(0.1, 0.0, 0.1), false)
	trails.record_walker_position(1, Vector3(1.1, 0.0, 0.1), false)
	trails.record_walker_position(1, Vector3(0.1, 0.0, 0.1), false)
	trails.record_walker_position(1, Vector3(1.1, 0.0, 0.1), false)
	trails.record_walker_position(1, Vector3(0.1, 0.0, 0.1), false)
	trails.record_walker_position(1, Vector3(1.1, 0.0, 0.1), false)
	# After enough traffic, cell_strength must be positive.
	assert(trails.cell_strength(path_cell) > 0.0)
	# A cell that was never walked must have zero strength.
	assert(is_zero_approx(trails.cell_strength(Vector2i(5, 5))))


static func _test_trail_decay_without_content() -> void:
	var trails: RefCounted = TrailFieldServiceScript.new()
	trails.configure(12.0)
	# Without any visible trail content (_has_content == false), apply_daily_decay
	# still decays nav cells. Record some cell entries first.
	trails.record_walker_position(1, Vector3.ZERO, false)
	trails.record_walker_position(1, Vector3(0.6, 0.0, 0.0), false)
	# _has_content is true after stamping, so clear it to test the no-content branch.
	# We can't directly set _has_content, but we can verify that apply_daily_decay
	# with _has_content=true still decays. Instead, test the edge: a freshly
	# configured field with no walkers at all.
	var fresh: RefCounted = TrailFieldServiceScript.new()
	fresh.configure(12.0)
	# No content at all — apply_daily_decay must be a no-op (no crash, no error).
	fresh.apply_daily_decay()
	assert(fresh.total_strength() == 0)


static func _test_constructed_roads_override_trails_and_restore_them() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 12)
	var trails: RefCounted = TrailFieldServiceScript.new()
	trails.configure(12.0, 1.0, grid)
	var cell := Vector2i(1, 0)
	for _entry in range(10):
		trails.record_walker_position(1, Vector3(0.1, 0.0, 0.1), false)
		trails.record_walker_position(1, Vector3(1.1, 0.0, 0.1), false)
	assert(trails.cell_state(cell) == TrailFieldService.TrailState.MATURE)
	var roads: RefCounted = RoadNetworkServiceScript.new()
	roads.configure(grid)
	var road_cells: Array[Vector2i] = [cell]
	assert(roads.complete_cells(road_cells, RoadTypeScript.STONE))
	assert(is_equal_approx(grid.get_cell_weight(cell), RoadTypeScript.traversal_weight(RoadTypeScript.STONE)))
	assert(roads.remove_cells(road_cells))
	assert(is_equal_approx(grid.get_cell_weight(cell), TrailFieldService.MATURE_PATH_WEIGHT))


static func _test_road_network_validates_and_batches_changes() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 12)
	var roads: RefCounted = RoadNetworkServiceScript.new()
	roads.configure(grid)
	var revision := grid.revision()
	var one_cell: Array[Vector2i] = [Vector2i.ZERO]
	var two_cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	assert(not roads.complete_cells(one_cell, &"unknown"))
	assert(grid.revision() == revision)
	assert(roads.complete_cells(two_cells, RoadTypeScript.DIRT))
	assert(grid.revision() == revision + 1)
	assert(roads.road_type_at(Vector2i.ZERO) == RoadTypeScript.DIRT)
	assert(is_equal_approx(grid.get_cell_weight(Vector2i(1, 0), &"cart"), 1.0))
	assert(not roads.complete_cells(one_cell, RoadTypeScript.STONE, 3))
	assert(roads.complete_cells(one_cell, RoadTypeScript.STONE, 4))
	assert(is_finite(roads.road_weight_for_profile(Vector2i.ZERO, RoadTypeScript.CART)))
	assert(not is_finite(roads.road_weight_for_profile(Vector2i.ZERO, &"boat")))
	var reloaded: RefCounted = RoadNetworkServiceScript.new()
	reloaded.configure(grid)
	reloaded.restore_state(roads.export_state())
	assert(reloaded.road_type_at(Vector2i.ZERO) == RoadTypeScript.STONE)


static func _test_navigation_obstacle_publisher() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 12)
	var publisher: RefCounted = NavigationObstaclePublisherScript.new()
	publisher.configure(grid)
	var building := Node3D.new()
	var record := BuildingRecord.new(Vector2i.ZERO, Vector3(0.5, 0.0, 0.5), Vector2i.ONE)
	var blocked: Dictionary = publisher.publish({Vector2i(-2, 0): true}, [record], [], 0.0)
	assert(blocked.has(Vector2i(-2, 0)))
	assert(grid.is_blocked(Vector2i(0, 0)))
	var opened: Dictionary = publisher.publish({}, [record], [{"cell": Vector2i(0, 0), "node": building}], 0.0)
	assert(not opened.has(Vector2i(0, 0)))
	building.free()


static func _test_navigation_facade_metrics() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 8)
	var router: GridRouteService = GridRouteServiceScript.new()
	router.configure(grid)
	var navigation: RefCounted = NavigationFacadeScript.new()
	navigation.configure(grid, router)
	assert(navigation.find_route(Vector3(0.5, 0.0, 0.5), Vector3(2.5, 0.0, 0.5)).reachable)
	assert(not navigation.find_route(Vector3.ZERO, Vector3(99.0, 0.0, 0.0)).reachable)
	var metrics: Dictionary = navigation.metrics()
	assert(metrics.requests == 2 and metrics.failures == 1 and int(metrics.expanded_nodes) > 0)


static func _test_nav_grid_and_facade_route_cost() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var router: GridRouteService = GridRouteServiceScript.new()
	router.configure(grid)
	var facade: RefCounted = NavigationFacadeScript.new()
	facade.configure(grid, router)

	var start := Vector3(0.5, 0.0, 0.5)
	var destination := Vector3(2.5, 0.0, 0.5)
	var route: RouteResult = facade.find_route(start, destination)
	assert(route.reachable)

	var grid_cost: float = grid.route_cost(start, route)
	var facade_cost: float = facade.route_cost(start, route)
	assert(is_finite(grid_cost) and grid_cost > 0.0)
	assert(is_equal_approx(grid_cost, facade_cost))

	# Blocked path segment cost must be INF
	grid.set_blocked_cells({Vector2i(1, 0): true})
	assert(is_inf(grid.route_cost(start, route)))
	assert(is_inf(facade.route_cost(start, route)))
	assert(is_inf(grid.route_cost(start, null)))


static func _test_navigation_bridge_direct_configuration() -> void:
	var bridge_script = load("res://game/features/routing/presentation/navigation_bridge.gd")
	var bridge: Node = bridge_script.new()
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var router: GridRouteService = GridRouteServiceScript.new()
	router.configure(grid)
	var facade: RefCounted = NavigationFacadeScript.new()
	facade.configure(grid, router)

	bridge.configure(grid, facade, router)
	var from := Vector3(0.5, 0.0, 0.5)
	var destination := Vector3(2.5, 0.0, 0.5)

	assert(bridge.is_route_reachable(from, destination))
	var path: RouteResult = bridge.find_path_around_houses(from, destination, false)
	assert(path.reachable)

	var recovery: RouteResult = bridge.find_recovery_path(from, destination, false)
	assert(recovery.reachable)

	bridge.free()
