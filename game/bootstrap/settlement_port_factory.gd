class_name SettlementPortFactory
extends RefCounted

## Builds the runtime/presentation port objects that wire SettlementGame
## state to the navigation, outside-work and water subsystems.
## Extracted from SettlementGame to reduce its method count.

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func world_navigation_runtime_port() -> WorldNavigationRuntimePort:
	return WorldNavigationRuntimePort.new(
		func() -> NavigationBridge: return game.navigation_bridge,
		func() -> Dictionary: return game.terrain_blocked_cells,
		func() -> Dictionary: return game.navigation_blocked_cells,
		func(cells: Dictionary) -> void: game.navigation_blocked_cells = cells,
		func() -> Array: return game.building_registry.records(),
		func() -> Array[ServicePocketRecord]: return game.service_pockets,
		game.cell_from_position,
		game.is_board_cell,
		func() -> NavGrid: return game.nav_grid,
		game.is_route_reachable,
		game.terrain_height_at,
		func() -> Dictionary: return game.tree_nodes,
		func(cell: Vector2i) -> Variant: return game.world_resource_state.tree_at(cell),
		func(resource_type: String, amount: int) -> void: game.settlement.add(resource_type, amount),
		game.update_interface,
		func(cell: Vector2i) -> void: game.terrain_blocked_cells.erase(cell),
		game.NAVIGATION_CLEARANCE_MARGIN,
		game.CELL_SIZE
	)


## Pond seeds of the active biome (grid_terrain_system.md §9). A session launched
## with a map ignores them — that map's author owns its water — but a plain new
## game still needs somewhere to fill a bucket, and it gets a dug basin in the
## real grids instead of the decorative prop this used to be.
func starter_water_cells() -> Array[Vector2i]:
	var biome: BiomeDefinition = game.territory_service.get_active_biome()
	var layout: Resource = biome.natural_layout if biome != null else null
	if layout == null:
		return []
	var cells: Array[Vector2i] = []
	for cell: Variant in layout.get("water_cells"):
		if cell is Vector2i:
			cells.append(cell as Vector2i)
	return cells


func world_navigation_presentation_port() -> WorldNavigationPresentationPort:
	return WorldNavigationPresentationPort.new(
		func() -> Camera3D: return game.camera,
		func() -> TrailFieldService: return game.trail_field,
		func() -> MapDocument: return game.launch_config.map_document,
		starter_water_cells,
		func() -> WorldSetup: return game.world_setup as WorldSetup,
		func(next_world_setup: WorldSetup) -> void: game.world_setup = next_world_setup,
		func(next_water_access_service: WaterAccessService) -> void: game.water_access_service = next_water_access_service,
		func(node: Node) -> void: game.add_child(node),
		func(next_world_setup: WorldSetup) -> void: next_world_setup.build(game),
		func() -> void: game.simulation_tick_controller.update_daylight(),
		func(position: Vector3) -> void: game.build_controller.move_selection(position),
		func() -> TerritoryBase: return game.get_node_or_null("WorldTerritory") as TerritoryBase,
		func() -> TrailTextureRenderer: return game.trail_texture_renderer,
		func() -> float: return game.runtime_seconds,
		func() -> bool: return game.settlement.era == SettlementState.Era.TENT,
		func() -> bool: return game.settlement.road_walking_order_enabled,
		func() -> RefCounted: return game.village_territory_service.territory(),
		game.CELL_SIZE,
		game.board_cells
	)


func outside_work_runtime_port() -> OutsideWorkRuntimePort:
	return OutsideWorkRuntimePort.new(
		game.settlement,
		game.random,
		game.outside_workers,
		game.last_citizen_positions,
		func() -> Citizen: return game.selected_builder,
		func() -> bool: return game.simulation_tick_controller.is_work_time(),
		game.update_interface,
		func() -> CourierDispatcher: return game.courier_dispatcher,
		func() -> Node3D: return game.entrance_stone,
		game.request_courier_dispatch,
		func() -> int: return (game.day_cycle.current_day - 1) * SimulationClock.MINUTES_PER_DAY + floori(game.clock.minutes),
		func() -> int: return game.day_cycle.current_day,
		func() -> void:
			if game.citizen_ai != null:
				game.citizen_ai.request_decision_refresh()
	)
