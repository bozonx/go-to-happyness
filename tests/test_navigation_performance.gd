extends SceneTree


func _init() -> void:
	_test_connected_component_invalidation()
	_test_route_search_budget()
	quit(0)


func _test_connected_component_invalidation() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 6)
	assert(grid.are_positions_connected(Vector3(-2.5, 0.0, 0.5), Vector3(2.5, 0.0, 0.5)))

	var barrier: Dictionary = {}
	for y in range(-3, 3):
		barrier[Vector2i(0, y)] = true
	grid.set_blocked_cells(barrier)
	assert(not grid.are_cells_connected(Vector2i(-2, 0), Vector2i(2, 0)))

	barrier.erase(Vector2i(0, 0))
	grid.set_blocked_cells(barrier)
	assert(grid.are_cells_connected(Vector2i(-2, 0), Vector2i(2, 0)))

	# Traversal weights change route choice, not topological connectivity.
	grid.set_cell_weights({Vector2i(-1, 0): 0.5})
	assert(grid.are_cells_connected(Vector2i(-2, 0), Vector2i(2, 0)))


func _test_route_search_budget() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 48)
	var router := GridRouteService.new()
	router.configure(grid)
	var started_at := Time.get_ticks_usec()
	for _index in range(128):
		var route := router.find_route(Vector3(-23.5, 0.0, -23.5), Vector3(23.5, 0.0, 23.5))
		assert(route.reachable)
		assert(router.last_search_expanded_nodes <= 48 * 48)
		assert(router.last_search_peak_frontier <= 48 * 48)
	var elapsed_usec := Time.get_ticks_usec() - started_at
	assert(elapsed_usec < 5_000_000)
