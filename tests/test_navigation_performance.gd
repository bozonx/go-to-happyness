extends SceneTree


func _init() -> void:
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
	quit(0)
