extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Tests pond navigation blocking, pond access position, and terrain
## connectivity beyond the starter forest.

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	# Pond cells are blocked for navigation and construction.
	var pond_cell: Vector2i = simulation._cell_from_position(simulation.pond_positions[0])
	assert(simulation._is_navigation_cell_blocked(pond_cell))
	var pond_route: RouteResult = simulation._find_path_around_houses(simulation.citizens[0].global_position, simulation.pond_positions[0], false)
	assert(not pond_route.reachable)
	assert(not simulation.citizens[0]._move_to(simulation.pond_positions[0], 0.1))

	# Pond access position is reachable.
	var pond_access: Vector3 = simulation._pond_access_position(simulation.citizens[0].global_position, simulation.pond_positions[0])
	assert(pond_access != Vector3.INF)
	var pond_access_route: RouteResult = simulation._find_path_around_houses(simulation.citizens[0].global_position, pond_access, false)
	assert(pond_access_route.reachable)

	# The terrain continues behind the starter forest. Its cells must remain part
	# of the shared construction and navigation board so citizens can work there.
	var beyond_forest := Vector3(30.5, 0.0, 0.5)
	assert(simulation._is_board_cell(simulation._cell_from_position(beyond_forest)))
	assert(simulation._find_path_around_houses(simulation.citizens[0].global_position, beyond_forest, false).reachable)

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
