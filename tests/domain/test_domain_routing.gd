class_name TestDomainRouting
extends RefCounted

const GridRouteServiceScript = preload("res://game/features/routing/application/grid_route_service.gd")
const RouteRequestScript = preload("res://game/features/routing/application/route_request.gd")
const BuildingQueueServiceScript = preload("res://game/features/citizens/application/building_queue_service.gd")
const TrailFieldServiceScript = preload("res://game/features/routing/application/trail_field_service.gd")


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
