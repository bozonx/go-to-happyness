extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## The starter pond is real water now (grid_terrain_system.md §9): a basin dug in
## the `TerrainGrid` and filled from the `WaterGrid`, not a prop plus a hand-drawn
## blot in `terrain_blocked_cells`. What used to be asserted about the blot is
## asserted here about the layer that replaced it — that its middle is unreachable
## because it is deep, that its bank is reachable because it is ground, and that
## the two answers come from the published navigation field rather than from a
## second list nobody publishes.

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	# The biome's water became access points on the bank, and there is at least one.
	var banks: Array[Vector3] = simulation.water_source_positions
	assert(not banks.is_empty(), "the starter biome must leave somewhere to draw water")

	# Every access point is dry standable ground a citizen can route to.
	var bank: Vector3 = banks[0]
	assert(SimHelper.find_path_around_houses(simulation, simulation.citizens[0].global_position, bank, false).reachable)

	# ...and the water it touches is not. Deep water is refused by the navigation
	# field itself (§9.7), with nothing written into the blocked-cell map.
	var water_grid: WaterGrid = simulation.world_setup.water_grid
	var terrain_grid: TerrainGrid = simulation.world_setup.terrain_grid
	var bank_cell: Vector2i = SimHelper.cell_from_position(simulation, bank)
	var deep := Vector2i.ZERO
	var found_deep := false
	var found_ford := false
	for offset_z in range(-4, 5):
		for offset_x in range(-4, 5):
			var cell := bank_cell + Vector2i(offset_x, offset_z)
			if not water_grid.is_wet(terrain_grid, cell):
				continue
			if water_grid.is_ford(terrain_grid, cell):
				found_ford = true
				continue
			deep = cell
			found_deep = true
	assert(found_ford, "the rim of the pond is one step deep, which is a ford")
	assert(found_deep, "and its middle is deeper than that, which is not")
	assert(not simulation.nav_grid.is_walkable(deep), "deep water is not standable")
	assert(not simulation.navigation_blocked_cells.has(deep), "and nothing else says so on its behalf")

	# The terrain continues behind the starter forest. Its cells must remain part
	# of the shared construction and navigation board so citizens can work there.
	var beyond_forest := Vector3(30.5, 0.0, 0.5)
	assert(SimHelper.is_board_cell(simulation, SimHelper.cell_from_position(simulation, beyond_forest)))
	assert(SimHelper.find_path_around_houses(simulation, simulation.citizens[0].global_position, beyond_forest, false).reachable)

	await SimHelper.cleanup_simulation(self, simulation)
	quit(0)
