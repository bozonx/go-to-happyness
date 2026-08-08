class_name SettlementBootstrapper
extends RefCounted


const BillboardLabelScene = preload("res://game/features/ui/presentation/billboard_label.tscn")
const ConstructionEntrancePostScene = preload("res://game/features/buildings/presentation/construction_entrance_post.tscn")
const ConstructionSiteScene = preload("res://game/features/buildings/presentation/construction_site.tscn")
const DigSiteScene = preload("res://game/features/world/presentation/dig_site.tscn")
const FireLightScene = preload("res://game/features/buildings/presentation/fire_light.tscn")

## Handles all service initialization for SettlementGame.
## Called from SettlementGame._ready() to keep the Node script focused on runtime.

var game: SettlementGame


func run(p_game: SettlementGame) -> void:
	game = p_game
	# Phase 1 — controllers and world state.
	# Controllers and UI wiring must happen before any service setup,
	# because service lambdas capture controller references.
	_setup_controllers()
	# Event-driven services capture EventService during configuration. Create the
	# registry before any such service so they never retain a stale null reference.
	_setup_world_and_events()
	# Phase 2 — buildings.
	_setup_hero_services()
	_setup_construction_and_demolition()
	_setup_workplace_and_visuals()
	_setup_territory()
	_setup_ai_and_navigation()
	_setup_zone_runtime()
	_setup_citizen_lifecycle()
	_setup_building_services()
	# Phase 3 — logistics and resources.
	_setup_canteen_and_resources()
	_setup_foraging_and_fire()
	_setup_building_maintenance()
	_setup_settlement_survival_and_daily_rules()
	_setup_building_lifecycle()
	_setup_excavation_and_factory()
	# Phase 4 — citizens.
	_setup_citizen_registration_and_school()
	_setup_citizen_needs_and_orders()
	# Phase 5 — logistics and AI/events.
	_setup_trade_and_logistics()
	_setup_courier_system()
	_setup_actuator_and_events()
	# Phase 6 — presentation and launch.
	_setup_ui_controllers()
	_setup_controllers_and_world()
	_setup_citizens_and_ai()


func _setup_controllers() -> void:
	game.research_controller = SettlementResearchController.new(game)
	game.citizen_factory = SettlementCitizenFactory.new(game)
	var add_warehouse_fill_label := func(building: Node3D) -> void:
		if game.warehouse_fill_label_controller != null:
			game.warehouse_fill_label_controller.add_warehouse_fill_label(building)
	var add_house_light := func(house: Node3D) -> void:
		if game.building_visuals_service != null:
			game.building_visuals_service.add_house_light(house)
	game.building_visuals = SettlementBuildingVisuals.new(
		BuildingVisualsPort.new(
			game.building_status_indicators,
			add_warehouse_fill_label,
			add_house_light
		)
	)
	game.simulation_handlers = SettlementSimulationHandlers.new(game)
	game.port_factory = SettlementPortFactory.new(game)
	var add_service_marker := func(building: Node3D, local: Vector3) -> void:
		if game.building_visuals_service != null:
			game.building_visuals_service.add_service_entrance_marker(building, local)
	var add_visitor_marker := func(building: Node3D, local: Vector3) -> void:
		if game.building_visuals_service != null:
			game.building_visuals_service.add_visitor_entrance_marker(building, local)
	game.service_pocket_manager = SettlementServicePocketManager.new(
		BuildingServicePocketPort.new(
			game.service_pockets,
			game.cell_from_position,
			add_service_marker,
			add_visitor_marker
		)
	)
	game.outside_work_controller = SettlementOutsideWorkController.new(game.port_factory.outside_work_runtime_port())
	var nav_grid_getter := func() -> NavGrid: return game.nav_grid
	var entrance_getter := func() -> Node3D: return game.entrance_stone
	var entrance_setter := func(building: Node3D) -> void: game.entrance_stone = building
	var canteen_getter := func() -> Node3D: return game.canteen
	var canteen_setter := func(building: Node3D) -> void: game.canteen = building
	var canteen_position_setter := func(position: Vector3) -> void: game.canteen_position = position
	var add_entrance_selector := func(node: Node3D, group_name: String, shape_size: Vector3, offset: Vector3) -> void:
		game.building_visuals.add_selector_to_node(node, group_name, shape_size, offset)
	var configure_entrance_ambient := func(building: Node3D) -> void:
		if game.ambient_spawner != null:
			game.ambient_spawner.setup_entrance_sign_node(building)
	game.building_management = SettlementBuildingManagement.new(
		BuildingManagementPort.new(
			game.building_registry,
			nav_grid_getter,
			entrance_getter,
			entrance_setter,
			canteen_getter,
			canteen_setter,
			canteen_position_setter,
			add_entrance_selector,
			configure_entrance_ambient
		)
	)
	game.input_controller = SettlementInputController.new(game)
	game.selection_controller = SettlementSelectionController.new(game)
	game.query_helper = SettlementQueryHelper.new(game)
	game.build_controller = SettlementBuildController.new(game)
	game.hero_interaction_controller = SettlementHeroInteractionController.new(game)
	game.construction_controller = SettlementConstructionController.new(game)
	game.workplace_controller = SettlementWorkplaceController.new(game)
	game.simulation_tick_controller = SettlementSimulationTickController.new(game)
	game.logistics_controller = SettlementLogisticsController.new(game)
	game.world_navigation_controller = SettlementWorldNavigationController.new(
		game.port_factory.world_navigation_runtime_port(),
		game.port_factory.world_navigation_presentation_port(),
		game.world_session
	)
	game.ui_manager.setup(game)
	game.ui_manager.bind_delegate_events(SettlementUICallbacks.new(game))


func _setup_hero_services() -> void:
	game.hero_pocket_service = HeroPocketService.new()
	game.hero_pocket_service.configure(func() -> Citizen: return game.player_citizen, func(position, resources, is_backpack_pile): return game.resource_pile_service.create_resource_pile(position, resources, is_backpack_pile), game.update_interface, func(): game.hero_interaction_controller.refresh_interaction_hint())
	game.hero_interaction_service = HeroInteractionService.new()


func _setup_workplace_and_visuals() -> void:
	game.workplace_labor_service = WorkplaceLaborService.new()
	var port := WorkplaceLaborRuntimePort.new()
	port.settlement = game.settlement
	port.citizens = game.citizens
	port.campfire_node_getter = func() -> Node3D: return game.campfire_node
	port.canteen_getter = func() -> Node3D: return game.canteen
	port.canteen_position_getter = func() -> Vector3: return game.canteen_position
	port.warehouse_positions = game.warehouse_positions
	port.construction_sites = game.construction_sites
	port.demolition_sites = game.demolition_sites
	port.tree_positions = game.tree_positions
	port.water_source_positions_getter = func() -> Array[Vector3]: return game.water_source_positions
	port.craft_tent_positions = game.craft_tent_positions
	port.dig_sites = game.dig_sites
	port.is_fire_lit = func(building): return game.fire_management_service.is_fire_lit(building)
	port.update_interface = game.update_interface
	port.available_employer_capacity = game.workplace_controller.available_employer_capacity
	port.builder_job_capacity = game.workplace_controller.builder_job_capacity
	port.can_work_at_dig_site = func(site): return game.excavation_service.can_work_at_dig_site(site)
	port.employment_centre_building_getter = game.employment_centre_building
	game.workplace_labor_service.configure(port)
	game.building_visuals_service = BuildingVisualsService.new()
	game.building_visuals_service.configure(
		game.entrance_lights,
		game.house_lights,
		game.random
	)


func _setup_territory() -> void:
	game.territory_service = TerritoryService.new()
	var summer_valley_biome := load("res://game/features/world/presentation/biomes/summer/summer_valley/summer_valley_biome.tres") as BiomeDefinition
	var summer_plains_biome := load("res://game/features/world/presentation/biomes/summer/summer_plains/summer_plains_biome.tres") as BiomeDefinition
	if summer_valley_biome != null:
		game.territory_service.register_biome(summer_valley_biome)
	if summer_plains_biome != null:
		game.territory_service.register_biome(summer_plains_biome)
	game.territory_service.set_active_biome(game.launch_config.biome_id)


func _setup_ai_and_navigation() -> void:
	if game.citizen_ai == null:
		game.citizen_ai = CitizenAISystem.new()
		game.citizen_ai.name = "CitizenAI"
		game.add_child(game.citizen_ai)
	# One clock for the world (`world_environment.md` §4). The settlement reads the
	# session's calendar rather than running a second one, which is what keeps the
	# hour the citizens work by and the hour the sun is drawn from the same number.
	game.clock.bind(game.world_session.environment.state.calendar)
	game.world_session.environment.minutes_per_second = game.GAME_MINUTES_PER_SECOND
	game.nav_grid = game.world_session.nav_grid
	# Adopted, not created: the world session already seeded it from the map's
	# coverage layer, and a second service would be a second write-owner of road
	# weights in the same grid (map_editor.md §5.2.3).
	game.road_network_service = game.world_session.road_network
	game.navigation_obstacle_publisher = NavigationObstaclePublisher.new()
	game.navigation_obstacle_publisher.configure(
		game.nav_grid,
		game.world_session.entity_navigation_blocked_cells,
	)
	game.trail_field = TrailFieldService.new()
	game.trail_field.configure(game.board_cells * SettlementConstants.CELL_SIZE, SettlementConstants.CELL_SIZE, game.nav_grid)
	game.trail_texture_renderer = TrailTextureRenderer.new()
	game.route_service = GridRouteService.new()
	game.route_service.configure(game.nav_grid)
	game.navigation_facade = NavigationFacade.new()
	game.navigation_facade.configure(game.nav_grid, game.route_service)
	game.navigation_bridge = NavigationBridge.new()
	game.add_child(game.navigation_bridge)
	game.navigation_bridge.configure(game.nav_grid, game.navigation_facade, game.route_service, game.navigation_obstacle_publisher)
	game.building_queue_service = BuildingQueueService.new()
	game.building_queue_service.configure(game.building_registry, game.nav_grid)
	game.building_queue_service.set_citizen_alive_checker(func(citizen_id): return game.citizen_factory.is_ai_citizen_id_alive(citizen_id))


## Builds the map-zone runtime: session state (§13), the presence index and
## tracker (§14), and the event bus they publish on. Runs after the navigation
## stack because the overlay publisher (a prior round) has already read
## `map_document.zones` for cost; this reads the same layer for owner, flags and
## presence. A session without a map document gets empty structures, so the
## no-map fallback board still has services to call without null-checks upstream.
func _setup_zone_runtime() -> void:
	var map_document: MapDocument = game.launch_config.map_document if game.launch_config != null else null
	var board_cells := game.board_cells
	# Session state (§13): owner and flags per zone.
	game.map_zone_registry = MapZoneRegistry.new()
	if map_document != null:
		game.map_zone_registry.build_from(map_document.zones)
	game.map_zone_service = MapZoneService.new()
	game.map_zone_service.configure(game.map_zone_registry)
	# Presence (§14): a cell→areas index, a tracker that diffs citizen cells
	# against it, and the bus both publish to. No consumers are wired yet — a
	# future rules phase subscribes by adding callables to the bus configure.
	game.zone_presence_index = ZonePresenceIndex.new()
	if map_document != null:
		game.zone_presence_index.rebuild(map_document.zones, board_cells)
	# The bus belongs to the session, not to this game: `WorldSession` owns it and
	# has already subscribed the map's scenario runtime to it (map_editor.md §10).
	# Creating a second one here is what would make a rule table work in the
	# showcase and silently do nothing in the settlement.
	game.zone_event_bus = game.world_session.zone_event_bus if game.world_session != null else ZoneEventBus.new()
	# The registry publishes owner/flag mutations onto the same bus presence uses
	# (§14), so a rule sees "captured" and "entered" on one channel. Built here
	# rather than passed into `build_from` so a save restore can replay state
	# before this configure runs.
	game.map_zone_registry.configure(game.zone_event_bus)
	game.zone_presence_tracker = ZonePresenceTracker.new()
	game.zone_presence_tracker.configure(game.zone_presence_index, game.zone_event_bus)


func _setup_citizen_lifecycle() -> void:
	game.citizen_lifecycle_service = CitizenLifecycleService.new()
	var port := CitizenLifecycleRuntimePort.new()
	port.citizens = game.citizens
	port.pending_arrivals = game.logistics_runtime.pending_arrivals
	port.arrival_greeters = game.logistics_runtime.arrival_greeters
	port.arrival_waiting_greeters = game.logistics_runtime.arrival_waiting_greeters
	port.arrival_escort_ids = game.logistics_runtime.arrival_escort_ids
	port.entrance_stone_getter = func() -> Node3D: return game.entrance_stone
	port.entrance_anchor_position = func(): return game.building_management.entrance_anchor_position()
	port.employment_center_position = game.employment_center_position
	port.is_work_time = func(): return game.simulation_tick_controller.is_work_time()
	port.update_interface = game.update_interface
	port.show_house_menu = game.selection_controller.show_house_menu
	port.add_citizen = game.add_citizen
	port.refresh_living_status = func(citizen): game.simulation_tick_controller.refresh_living_status(citizen)
	port.request_courier_dispatch = game.request_courier_dispatch
	port.citizen_for_ai_id = func(citizen_id): return game.citizen_factory.citizen_for_ai_id(citizen_id)
	port.terrain_height_at = game.terrain_height_at
	port.citizen_ai_unregister = func(ai_id: int) -> void: if game.citizen_ai != null: game.citizen_ai.unregister_citizen(ai_id)
	port.citizen_ai_cancel_work = func(ai_id: int) -> void: if game.citizen_ai != null: game.citizen_ai.cancel_citizen_work(ai_id)
	port.canteen_service_remove_citizen = func(ai_id: int) -> void: if game.canteen_service != null: game.canteen_service.remove_citizen(ai_id)
	port.citizen_needs_service_remove_citizen = func(ai_id: int) -> void: if game.citizen_needs_service != null: game.citizen_needs_service.remove_citizen(ai_id)
	port.courier_dispatcher_complete_for = func(courier: Citizen) -> void: game.courier_dispatcher.complete_for(courier)
	port.selected_house_getter = func() -> Node3D: return game.selected_house
	port.day_cycle_current_day_getter = func() -> int: return game.day_cycle.current_day
	game.citizen_lifecycle_service.configure(port)


func _setup_building_services() -> void:
	game.building_zone_service = BuildingZoneService.new()
	game.building_availability_service = BuildingAvailabilityService.new()
	game.building_availability_service.configure(game.settlement)
	game.building_research_service = BuildingResearchService.new()
	game.building_research_service.configure(game.settlement)
	game.village_territory_service = VillageTerritoryService.new()
	game.village_territory_service.configure(game.building_registry, int(game.settlement.era))
	# The ground under a footprint is pinned for as long as the registry holds it
	# (grid_terrain_system.md §4.4). The cascade has always refused to move an
	# anchored column; until now nothing wrote one.
	game.terrain_anchor_service = TerrainAnchorService.new()
	game.sawmills = SawmillService.new()
	game.sawmills.configure(game.sawmill_stocks, game.sawmill_positions, SettlementConstants.SAWMILL_PROCESS_DURATION, game.cell_from_position)


func _setup_construction_and_demolition() -> void:
	var construction_runtime := ConstructionRuntime.new()
	construction_runtime.scene_root = game
	construction_runtime.settlement = game.settlement
	construction_runtime.building_registry = game.building_registry
	construction_runtime.citizens = game.citizens
	construction_runtime.duration = SettlementConstants.CONSTRUCTION_DURATION
	construction_runtime.builder_power = func(site_node): return game.construction_controller.building_power(site_node)
	construction_runtime.builder_count = func(site_node): return game.construction_controller.builder_count(site_node)
	construction_runtime.set_status = func(text): game.construction_controller.set_construction_status(text)
	construction_runtime.building_completed = func(cell, building_type, position_on_board, building, blueprint): game.construction_controller.complete_building(cell, building_type, position_on_board, building, blueprint)
	construction_runtime.workers_changed = game.update_workers
	construction_runtime.navigation_changed = func(): game.world_navigation_controller.refresh_navigation_grid()
	construction_runtime.update_supply_label = func(site): game.construction_controller.update_construction_supply_label(site)
	game.construction = ConstructionService.new()
	game.construction.site_scene = ConstructionSiteScene
	game.construction.entrance_post_scene = ConstructionEntrancePostScene
	game.construction.configure(construction_runtime)
	var demolition_runtime := DemolitionRuntime.new()
	demolition_runtime.duration = SettlementConstants.DEMOLITION_DURATION
	demolition_runtime.building_power = func(site_node): return game.construction_controller.building_power(site_node)
	demolition_runtime.is_ready = func(site): return game.building_lifecycle_service.demolition_ready(site)
	demolition_runtime.completed = game.finish_demolition
	game.demolition = DemolitionService.new()
	game.demolition.configure(demolition_runtime)
	game.water_collector_service = WaterCollectorService.new()
	game.water_collector_service.configure(game.water_collectors)


func _setup_canteen_and_resources() -> void:
	game.canteen_service = CanteenService.new()
	var port := CanteenRuntimePort.new()
	port.settlement = game.settlement
	port.citizens = game.citizens
	port.canteen_getter = func() -> Node3D: return game.canteen
	port.canteen_food_getter = func() -> int: return game.canteen_food
	port.set_canteen_food = func(value): game.logistics_controller.set_canteen_food(value)
	port.canteen_position_getter = func() -> Vector3: return game.canteen_position
	port.pending_canteen_delivery_getter = func() -> bool: return game.pending_canteen_delivery
	port.pending_canteen_carrier_getter = func() -> Citizen: return game.pending_canteen_carrier
	port.pending_canteen_delivery_amount_getter = func() -> int: return game.pending_canteen_delivery_amount
	port.set_canteen_delivery_state = func(active, carrier, amount): game.logistics_controller.set_canteen_delivery_state(active, carrier, amount)
	port.is_canteen_delivery_in_progress = func(): return game.logistics_controller.is_canteen_delivery_in_progress()
	port.is_fire_lit = func(building): return game.fire_management_service.is_fire_lit(building)
	port.has_cook = game.has_cook
	port.update_interface = game.update_interface
	port.request_courier_dispatch = game.request_courier_dispatch
	port.is_work_time = func(): return game.simulation_tick_controller.is_work_time()
	port.update_workers = game.update_workers
	game.canteen_service.configure(port)
	game.resource_pile_service = ResourcePileService.new(
		game, game.resource_piles, game.settlement,
		func() -> EnvironmentSnapshot: return game.simulation_tick_controller.environment())
	game.resource_pile_service.set_visuals(ResourcePileVisuals.new())


func _setup_foraging_and_fire() -> void:
	game.foraging_service = ForagingService.new()
	game.foraging_service.billboard_label_scene = BillboardLabelScene
	game.foraging_service.set_random(game.random)
	game.foraging_service.setup(
		game.settlement,
		game.world_resource_state,
		game.forager_positions,
		game.forage_sources,
		game.rabbit_sources,
		game.grass_sources,
		game.tree_nodes,
		game.tree_positions,
		game.gather_progress_labels,
		game.terrain_height_at,
		game.cell_from_position,
		func(): return game.hero_interaction_controller.first_person_target()
	)
	# Natural-resource dictionaries are owned by ForagingService. Configure hero
	# proximity queries only after that service exists, otherwise the bootstrap
	# getters return temporary empty dictionaries that never receive grass data.
	var hero_port := HeroInteractionRuntimePort.new()
	hero_port.player_citizen_getter = func() -> Citizen: return game.player_citizen
	hero_port.interaction_range = SettlementConstants.INTERACTION_RANGE
	hero_port.tree_positions = game.tree_positions
	hero_port.tree_nodes = game.tree_nodes
	hero_port.sawmill_positions = game.sawmill_positions
	hero_port.farm_positions = game.farm_positions
	hero_port.water_source_positions_getter = func() -> Array[Vector3]: return game.water_source_positions
	hero_port.grass_sources = game.grass_sources
	hero_port.forage_sources = game.forage_sources
	hero_port.rabbit_sources = game.rabbit_sources
	hero_port.cell_from_position = game.cell_from_position
	hero_port.consume_grass_source = func(position): return game.foraging_service.consume_grass_source(position)
	game.hero_interaction_service.configure(hero_port)
	game.fire_management_service = FireManagementService.new()
	game.fire_management_service.setup(
		game.building_registry,
		game.event_service,
		game.settlement,
		game.day_cycle,
		func() -> int: return int(game.game_minutes),
		func() -> Node3D: return game.campfire_node,
		game.add_message,
		func(): game.simulation_tick_controller.refresh_living_statuses(),
		func() -> void: game.settlement.wellbeing = maxi(0, game.settlement.wellbeing - 1)
	)
	game.fixture_service = FixtureService.new()
	game.fire_management_service.set_fixture_service(game.fixture_service)


func _setup_building_maintenance() -> void:
	game.building_maintenance_service = BuildingMaintenanceService.new()
	game.building_maintenance_service.setup(
		game.building_registry,
		game.settlement,
		game.village_territory_service,
		game.resource_pile_service,
		{
			"unregister_pockets": func(node): game.service_pocket_manager.unregister_service_pockets(node),
			"move_stored_resources": func(resources, warehouse_index): game.building_lifecycle_service.move_stored_resources_to_pile(resources, warehouse_index),
			"return_supplies": func(building): game.logistics_controller.return_in_transit_building_supplies(building),
			"remove_services": func(building, building_type): game.building_lifecycle_service.remove_building_services(building, building_type),
			"unregister_nav_footprint": func(center, footprint): game.service_pocket_manager.unregister_navigation_footprint(center, footprint),
			"refresh_boundary": func(): game.world_navigation_controller.refresh_boundary_markers(),
			"select_best_campfire": func(): game.building_lifecycle_service.select_best_campfire(),
			"refresh_nav_grid": func(): game.world_navigation_controller.refresh_navigation_grid(),
			"update_workers": game.update_workers,
			"refresh_living_status": func(citizen): game.simulation_tick_controller.refresh_living_status(citizen)
		}
	)


func _setup_settlement_survival_and_daily_rules() -> void:
	game.settlement_survival_service = SettlementSurvivalService.new()
	var survival_port := SettlementSurvivalRuntimePort.new()
	survival_port.settlement = game.settlement
	survival_port.day_cycle = game.day_cycle
	survival_port.clock = game.clock
	survival_port.citizens = game.citizens
	survival_port.random = game.random
	survival_port.environment_getter = func() -> EnvironmentSnapshot: return game.simulation_tick_controller.environment()
	survival_port.building_registry = game.building_registry
	survival_port.fire_management_service = game.fire_management_service
	survival_port.tent_weather_getter = func() -> int: return game.tent_weather
	survival_port.entrance_stone_getter = func() -> Node3D: return game.entrance_stone
	survival_port.event_service_getter = func() -> Variant: return game.event_service
	survival_port.has_lit_communal_fire = func(): return game.simulation_tick_controller.has_lit_communal_fire()
	survival_port.add_message = game.add_message
	survival_port.is_citizen_work_time = func(citizen): return game.simulation_tick_controller.is_citizen_work_time(citizen)
	survival_port.is_work_time = func(): return game.simulation_tick_controller.is_work_time()
	game.settlement_survival_service.configure(survival_port)
	game.settlement_daily_rules_service = SettlementDailyRulesService.new()
	var daily_port := SettlementDailyRulesRuntimePort.new()
	daily_port.settlement = game.settlement
	daily_port.day_cycle = game.day_cycle
	daily_port.citizens = game.citizens
	daily_port.trail_field = game.trail_field
	daily_port.event_service_getter = func() -> Variant: return game.event_service
	daily_port.citizen_needs_service = game.citizen_needs_service
	daily_port.canteen_getter = func() -> Node3D: return game.canteen
	daily_port.tent_weather_getter = func() -> int: return game.tent_weather
	daily_port.add_message = game.add_message
	daily_port.update_interface = game.update_interface
	daily_port.apply_building_wear_and_repairs = game.apply_building_wear_and_repairs
	daily_port.decay_resource_piles = func(): game.resource_pile_service.decay_resource_piles()
	daily_port.total_housing_slots = func(): return game.building_registry.housing_capacity()
	daily_port.check_daily_departures = func(): game.settlement_survival_service.check_daily_departures()
	daily_port.stored_resources = game.stored_resources
	daily_port.warehouse_capacity = game.warehouse_capacity
	game.settlement_daily_rules_service.configure(daily_port)


func _setup_building_lifecycle() -> void:
	game.building_lifecycle_service = BuildingLifecycleService.new()
	var port := BuildingLifecycleRuntimePort.new()
	port.settlement = game.settlement
	port.citizens = game.citizens
	port.building_registry = game.building_registry
	port.demolition = game.demolition
	port.village_territory_service = game.village_territory_service
	port.warehouse_positions = game.warehouse_positions
	port.sawmill_positions = game.sawmill_positions
	port.farm_positions = game.farm_positions
	port.builders_guild_positions = game.builders_guild_positions
	port.construction_company_positions = game.construction_company_positions
	port.forager_positions = game.forager_positions
	port.materials_yard_positions = game.materials_yard_positions
	port.school_positions = game.school_positions
	port.park_positions = game.park_positions
	port.gathering_place_positions = game.gathering_place_positions
	port.leisure_positions = game.leisure_positions
	port.craft_tent_positions = game.craft_tent_positions
	port.market_positions = game.market_positions
	port.water_collectors = game.water_collectors
	port.factories = game.factories
	port.house_lights = game.house_lights
	port.entrance_lights = game.entrance_lights
	port.house_capacity = SettlementConstants.HOUSE_CAPACITY
	port.fire_light_scene = FireLightScene
	port.entrance_stone_getter = func() -> Node3D: return game.entrance_stone
	port.campfire_node_getter = func() -> Node3D: return game.campfire_node
	port.campfire_node_setter = func(v: Node3D) -> void: game.campfire_node = v
	port.canteen_getter = func() -> Node3D: return game.canteen
	port.canteen_setter = func(v: Node3D) -> void: game.canteen = v
	port.canteen_food_getter = func() -> int: return game.canteen_food
	port.canteen_food_setter = func(v: int) -> void: game.canteen_food = v
	port.pending_canteen_delivery_getter = func() -> bool: return game.pending_canteen_delivery
	port.employment_office_getter = func() -> Node3D: return game.employment_office
	port.employment_office_setter = func(v: Node3D) -> void: game.employment_office = v
	port.employment_office_position_getter = func() -> Vector3: return game.employment_office_position
	port.employment_office_position_setter = func(v: Vector3) -> void: game.employment_office_position = v
	port.completed_house_count_getter = func() -> int: return game.completed_house_count
	port.completed_house_count_setter = func(v: int) -> void: game.completed_house_count = v
	port.house_light_update_minute_getter = func() -> int: return game.house_light_update_minute
	port.house_light_update_minute_setter = func(v: int) -> void: game.house_light_update_minute = v
	port.game_minutes_getter = func() -> float: return game.game_minutes
	port.can_hero_build = game.can_hero_build
	port.update_interface = game.update_interface
	port.update_workers = game.update_workers
	port.cancel_arrivals_for_house = func(house): game.citizen_lifecycle_service.cancel_arrivals_for_house(house)
	port.add_demolition_marker = func(building): game.building_visuals.add_demolition_marker(building)
	port.refresh_living_status = func(citizen): game.simulation_tick_controller.refresh_living_status(citizen)
	port.unregister_service_pockets = func(node): game.service_pocket_manager.unregister_service_pockets(node)
	port.return_in_transit_building_supplies = func(building): game.logistics_controller.return_in_transit_building_supplies(building)
	port.cancel_canteen_delivery = func(): game.canteen_service.cancel_canteen_delivery()
	port.unregister_navigation_footprint = func(center, footprint): game.service_pocket_manager.unregister_navigation_footprint(center, footprint)
	port.refresh_boundary_markers = func(): game.world_navigation_controller.refresh_boundary_markers()
	port.select_best_canteen = func(): game.building_management.select_best_canteen()
	port.create_resource_pile = func(position, resources, is_backpack_pile): return game.resource_pile_service.create_resource_pile(position, resources, is_backpack_pile)
	port.refresh_navigation_grid = func(): game.world_navigation_controller.refresh_navigation_grid()
	port.is_construction_site = game.construction_controller.is_construction_site
	port.activate_employment_centre = func(centre): game.research_controller.activate_employment_centre(centre)
	port.convert_backpack_pile_to_regular = game.convert_backpack_pile_to_regular
	port.add_building_selector = func(building, group_name, footprint): game.building_visuals.add_building_selector(building, group_name, footprint)
	port.add_warehouse_fill_label = func(building): game.building_visuals.add_warehouse_fill_label(building)
	port.sawmill_stock = game.sawmill_stock
	port.create_gathering_place_visual = func(building): game.building_visuals.create_gathering_place_visual(building)
	port.activate_kitchen_if_better = func(building, service_position): game.building_management.activate_kitchen_if_better(building, service_position)
	port.add_house_light = func(house): game.building_visuals.add_house_light(house)
	port.house_initial_residents = func(house): game.citizen_lifecycle_service.house_initial_residents(house)
	port.cancel_active_building_research = func(refund, message): game.research_controller.cancel_active_building_research(refund, message)
	port.dismiss_official = func(citizen): game.research_controller.dismiss_official(citizen)
	port.send_to_unemployment_registration = func(citizen): game.citizen_lifecycle_service.send_to_unemployment_registration(citizen)
	game.building_lifecycle_service.configure(port)
	game.construction_priority_service = ConstructionPriorityService.new()
	var priority_port := ConstructionPriorityRuntimePort.new()
	priority_port.construction_sites = game.construction_sites
	priority_port.warehouse_positions = game.warehouse_positions
	priority_port.sawmill_positions = game.sawmill_positions
	priority_port.campfire_node = game.campfire_node
	priority_port.canteen = game.canteen
	priority_port.population_provider = func() -> int: return game.citizens.size()
	priority_port.housing_slots_provider = func(): return game.building_registry.housing_capacity()
	priority_port.food_amount_provider = func() -> int: return game.settlement.amount(SettlementGame.ResourceIds.FOOD)
	game.construction_priority_service.configure(priority_port)


func _setup_excavation_and_factory() -> void:
	game.excavation_service = ExcavationService.new()
	game.excavation_service.dig_site_scene = DigSiteScene
	var excavation_port := ExcavationRuntimePort.new()
	excavation_port.settlement = game.settlement
	excavation_port.citizens = game.citizens
	excavation_port.dig_sites = game.dig_sites
	excavation_port.dig_cells = game.dig_cells
	excavation_port.exhausted_dig_cells = game.exhausted_dig_cells
	excavation_port.random = game.random
	excavation_port.update_interface = game.update_interface
	excavation_port.update_workers = game.update_workers
	excavation_port.request_courier_dispatch = game.request_courier_dispatch
	excavation_port.placement_key = game.placement_key
	excavation_port.is_clear_of_objects = game.is_clear_of_objects
	excavation_port.employment_center_position = game.employment_center_position
	excavation_port.show_territory_overlay = func(show): game.build_controller.show_territory_overlay(show)
	excavation_port.move_selection = func(world_position): game.build_controller.move_selection(world_position)
	excavation_port.show_selected_citizen_menu = game.selection_controller.show_selected_citizen_menu
	excavation_port.selected_builder_getter = func() -> Citizen: return game.selected_builder
	excavation_port.selected_world_position_getter = func() -> Vector3: return game.selected_world_position
	excavation_port.selection_marker_getter = func() -> Node3D: return game.world_setup.selection_marker
	excavation_port.selection_material_getter = func() -> StandardMaterial3D: return game.world_setup.selection_material
	excavation_port.set_dig_mode = game.set_dig_mode
	excavation_port.set_build_mode = game.set_build_mode
	excavation_port.add_child = func(node: Node) -> void: game.add_child(node)
	game.excavation_service.configure(excavation_port)
	game.factory_service = FactoryService.new()
	game.factory_service.configure(game.settlement, game.building_registry, game.add_message, game.random)


func _setup_citizen_registration_and_school() -> void:
	game.citizen_registration_service = CitizenRegistrationService.new()
	var registration_port := CitizenRegistrationRuntimePort.new()
	registration_port.citizens = game.citizens
	registration_port.officer_post_radius = SettlementConstants.OFFICER_POST_RADIUS
	registration_port.employment_centre_building_getter = game.employment_centre_building
	registration_port.employment_center_position_getter = game.employment_center_position
	registration_port.is_work_time = func(): return game.simulation_tick_controller.is_work_time()
	registration_port.update_workers = game.update_workers
	registration_port.registration_queue_counter_setter = func() -> int:
		game.registration_queue_counter += 1
		return game.registration_queue_counter
	game.citizen_registration_service.configure(registration_port)
	game.school_service = SchoolService.new()
	game.school_service.configure(game.school_positions, game.citizens)
	game.building_site_validator = BuildingSiteValidator.new()
	var placement_port := BuildingPlacementRuntimePort.new()
	placement_port.dig_sites = game.dig_sites
	placement_port.terrain_blocked_cells = game.terrain_blocked_cells
	placement_port.building_registry = game.building_registry
	placement_port.tree_positions = game.tree_positions
	placement_port.terrain_height_at = game.terrain_height_at
	placement_port.max_build_slope = SettlementConstants.MAX_BUILD_SLOPE
	# WorldSetup is built in phase 6, after this application service. The launch
	# document already owns the exact same grids, so placement can enforce board
	# and water constraints from its first call without depending on presentation.
	placement_port.terrain_grid = game.launch_config.map_document.terrain
	placement_port.water_grid = game.launch_config.map_document.water
	game.building_site_validator.configure(placement_port)


func _setup_citizen_needs_and_orders() -> void:
	game.citizen_daily_order_service = CitizenDailyOrderService.new()
	var daily_order_port := CitizenDailyOrderRuntimePort.new()
	daily_order_port.settlement = game.settlement
	daily_order_port.citizens = game.citizens
	daily_order_port.day_cycle = game.day_cycle
	daily_order_port.clock = game.clock
	daily_order_port.building_registry = game.building_registry
	daily_order_port.runtime_seconds_getter = func() -> float: return game.runtime_seconds
	daily_order_port.is_work_time = func(): return game.simulation_tick_controller.is_work_time()
	daily_order_port.is_citizen_work_time = func(citizen): return game.simulation_tick_controller.is_citizen_work_time(citizen)
	daily_order_port.absolute_game_minutes = func(): return game.outside_work_controller.absolute_game_minutes()
	daily_order_port.game_minutes_per_second = SettlementConstants.GAME_MINUTES_PER_SECOND
	daily_order_port.citizen_ai_request_decision_refresh = func() -> void: if game.citizen_ai != null: game.citizen_ai.request_decision_refresh()
	game.citizen_daily_order_service.configure(daily_order_port)
	game.citizen_needs_service = CitizenNeedsService.new()
	game.citizen_needs_service.set_random(game.random)
	var needs_port := CitizenNeedsRuntimePort.new()
	needs_port.nav_grid = game.nav_grid
	needs_port.toilets_getter = game.get_toilets
	needs_port.is_route_reachable = game.is_route_reachable
	needs_port.building_type_for_node = game.building_registry.building_type_for_node
	needs_port.tree_positions = game.tree_positions
	needs_port.grass_sources = game.grass_sources
	game.citizen_needs_service.configure(needs_port)
	game.citizen_living_status_service = CitizenLivingStatusService.new()


func _setup_trade_and_logistics() -> void:
	game.trade_service = TradeService.new()
	var trade_port := TradeRuntimePort.new()
	trade_port.settlement = game.settlement
	trade_port.citizens = game.citizens
	trade_port.queued_trades = game.logistics_runtime.queued_trades
	trade_port.pending_trades = game.logistics_runtime.pending_trades
	trade_port.warehouse_positions = game.warehouse_positions
	trade_port.market_menu = game.ui_manager.market_menu
	trade_port.selected_market_getter = func() -> Node3D: return game.selected_market
	trade_port.entrance_stone_getter = func() -> Node3D: return game.entrance_stone
	trade_port.get_delivery_position = func(): return game.logistics_controller.get_delivery_position()
	trade_port.update_interface = game.update_interface
	trade_port.refresh_market_menu = func(): game.workplace_controller.refresh_market_menu()
	trade_port.request_courier_dispatch = game.request_courier_dispatch
	trade_port.total_game_minutes = func(): return game.simulation_tick_controller.total_game_minutes()
	trade_port.citizen_for_ai_id = func(citizen_id): return game.citizen_factory.citizen_for_ai_id(citizen_id)
	trade_port.create_resource_pile = func(position, resources, is_backpack_pile): return game.resource_pile_service.create_resource_pile(position, resources, is_backpack_pile)
	trade_port.update_workers = game.update_workers
	game.trade_service.configure(trade_port)
	game.storage_routing_service = StorageRoutingService.new()
	var routing_port := StorageRoutingRuntimePort.new()
	routing_port.settlement = game.settlement
	routing_port.warehouse_positions = game.warehouse_positions
	routing_port.resource_piles = game.resource_piles
	routing_port.player_citizen_getter = func() -> Citizen: return game.player_citizen
	routing_port.interaction_range = SettlementConstants.INTERACTION_RANGE
	routing_port.is_route_reachable = game.is_route_reachable
	routing_port.find_path_around_houses = game.find_path_around_houses
	routing_port.nav_grid = game.nav_grid
	routing_port.dig_sites = game.dig_sites
	routing_port.can_work_at_dig_site = func(site): return game.excavation_service.can_work_at_dig_site(site)
	routing_port.resource_for_depth = func(site, depth): return game.excavation_service.resource_for_depth(site, depth)
	routing_port.update_interface = game.update_interface
	game.storage_routing_service.configure(routing_port)


func _setup_courier_system() -> void:
	game.courier_dispatcher = CourierDispatcher.new()
	var dispatch_port := CourierDispatchRuntimePort.new()
	dispatch_port.citizens = game.citizens
	dispatch_port.warehouse_positions = game.warehouse_positions
	dispatch_port.storage_routing = game.storage_routing_service
	dispatch_port.runtime_seconds_getter = func() -> float: return game.runtime_seconds
	dispatch_port.publish_tasks = game.publish_courier_tasks
	dispatch_port.is_task_valid = func(task): return game.courier_task_service.is_courier_task_valid(task)
	dispatch_port.start_task = func(courier, task): return game.courier_task_service.start_courier_task(courier, task)
	dispatch_port.cancel_task = func(courier, task): game.courier_task_service.cancel_courier_task(courier, task)
	dispatch_port.release_reservation = func(task): game.courier_task_service.release_task_warehouse_reservation(task)
	game.courier_dispatcher.configure(dispatch_port)
	game.storage_delivery_service = StorageDeliveryService.new()
	var delivery_port := StorageDeliveryRuntimePort.new()
	delivery_port.settlement = game.settlement
	delivery_port.warehouse_positions = game.warehouse_positions
	delivery_port.courier_dispatcher = game.courier_dispatcher
	delivery_port.storage_routing = game.storage_routing_service
	delivery_port.release_reservation = func(task): game.courier_task_service.release_task_warehouse_reservation(task)
	delivery_port.drop_resource_pile = func(position, resource_type, amount): game.resource_pile_service.drop_resource_pile(position, resource_type, amount)
	delivery_port.update_interface = game.update_interface
	delivery_port.request_courier_dispatch = game.request_courier_dispatch
	delivery_port.send_citizen_to_leisure = func(citizen, minimum_hours): return game.simulation_tick_controller.send_citizen_to_leisure(citizen, minimum_hours)
	game.storage_delivery_service.configure(delivery_port)
	game.courier_task_publisher = CourierTaskPublisher.new()
	var publisher_port := CourierTaskPublisherRuntimePort.new()
	publisher_port.settlement = game.settlement
	publisher_port.citizens = game.citizens
	publisher_port.construction_sites = game.construction_sites
	publisher_port.warehouse_positions = game.warehouse_positions
	publisher_port.pending_arrivals = game.logistics_runtime.pending_arrivals
	publisher_port.queued_trades = game.logistics_runtime.queued_trades
	publisher_port.sawmill_positions = game.sawmill_positions
	publisher_port.water_collectors = game.water_collectors
	publisher_port.building_registry = game.building_registry
	publisher_port.sawmills = game.sawmills
	publisher_port.courier_dispatcher = game.courier_dispatcher
	publisher_port.entrance_stone_getter = func() -> Node3D: return game.entrance_stone
	publisher_port.canteen_getter = func() -> Node3D: return game.canteen
	publisher_port.canteen_food_getter = func() -> int: return game.canteen_food
	publisher_port.canteen_position_getter = func() -> Vector3: return game.canteen_position
	publisher_port.pending_canteen_delivery_getter = func() -> bool: return game.pending_canteen_delivery
	publisher_port.runtime_seconds_getter = func() -> float: return game.runtime_seconds
	publisher_port.reconcile_construction_reservations = func(site): game.construction_controller.reconcile_construction_reservations(site)
	publisher_port.reconcile_repair_reservations = func(): game.logistics_controller.reconcile_repair_reservations()
	publisher_port.cell_from_position = game.cell_from_position
	publisher_port.get_nearest_delivery_position = func(from): return game.logistics_controller.get_nearest_delivery_position(from)
	publisher_port.warehouse_delivery_position = game.warehouse_delivery_position
	publisher_port.construction_priority = func(site): return game.construction_controller.construction_development_priority(site)
	publisher_port.construction_material_sources = func(resource_type, from_position): return game.logistics_controller.construction_material_sources(resource_type, from_position)
	publisher_port.construction_source_available = func(resource_type, source): return game.logistics_controller.construction_source_available(resource_type, source)
	publisher_port.fire_state_for = func(building): return game.fire_management_service.fire_state_for(building)
	publisher_port.firewood_task_priority = func(building, fire_state): return game.logistics_controller.firewood_task_priority(building, fire_state)
	publisher_port.is_managed_fire_source = func(building: Node3D) -> bool: return game.fire_management_service.is_managed_fire_source(building)
	game.courier_task_publisher.configure(publisher_port)
	game.courier_task_service = CourierTaskService.new()
	var task_port := CourierTaskRuntimePort.new()
	task_port.settlement = game.settlement
	task_port.citizens = game.citizens
	task_port.queued_trades = game.logistics_runtime.queued_trades
	task_port.pending_trades = game.logistics_runtime.pending_trades
	task_port.warehouse_positions = game.warehouse_positions
	task_port.pending_arrivals = game.logistics_runtime.pending_arrivals
	task_port.arrival_greeters = game.logistics_runtime.arrival_greeters
	task_port.outside_workers = game.outside_workers
	task_port.building_registry = game.building_registry
	task_port.sawmills = game.sawmills
	task_port.water_collector_service = game.water_collector_service
	task_port.trade_service = game.trade_service
	task_port.canteen_service = game.canteen_service
	task_port.canteen_getter = func() -> Node3D: return game.canteen
	task_port.canteen_food_getter = func() -> int: return game.canteen_food
	task_port.canteen_position_getter = func() -> Vector3: return game.canteen_position
	task_port.pending_canteen_delivery_getter = func() -> bool: return game.pending_canteen_delivery
	task_port.set_canteen_delivery_state = func(active, carrier, amount): game.logistics_controller.set_canteen_delivery_state(active, carrier, amount)
	task_port.entrance_stone_getter = func() -> Node3D: return game.entrance_stone
	task_port.runtime_seconds_getter = func() -> float: return game.runtime_seconds
	task_port.fire_state_for = func(building): return game.fire_management_service.fire_state_for(building)
	task_port.apply_fire_state = func(building, fire_state): game.fire_management_service.apply_fire_state(building, fire_state)
	task_port.is_route_reachable = game.is_route_reachable
	task_port.construction_source_available = func(resource_type, source): return game.logistics_controller.construction_source_available(resource_type, source)
	task_port.citizen_for_ai_id = func(citizen_id): return game.citizen_factory.citizen_for_ai_id(citizen_id)
	game.courier_task_service.configure(task_port)


func _setup_actuator_and_events() -> void:
	game.actuator_bridge = SettlementActuatorBridge.new()
	var actuator_port := SettlementActuatorRuntimePort.new()
	actuator_port.canteen_service = game.canteen_service
	actuator_port.courier_dispatcher = game.courier_dispatcher
	actuator_port.construction = game.construction
	actuator_port.settlement = game.settlement
	actuator_port.building_registry = game.building_registry
	actuator_port.storage_delivery_service = game.storage_delivery_service
	actuator_port.factory_service = game.factory_service
	actuator_port.sawmills = game.sawmills
	actuator_port.water_collector_service = game.water_collector_service
	actuator_port.excavation_service = game.excavation_service
	actuator_port.citizen_needs_service = game.citizen_needs_service
	actuator_port.trade_service = game.trade_service
	actuator_port.resource_piles = game.resource_piles
	actuator_port.game_minutes_query = func() -> float: return game.game_minutes
	actuator_port.runtime_seconds_query = func() -> float: return game.runtime_seconds
	actuator_port.update_interface = game.update_interface
	actuator_port.request_courier_dispatch = game.request_courier_dispatch
	actuator_port.request_decision_refresh = func() -> void: if game.citizen_ai != null: game.citizen_ai.request_decision_refresh()
	actuator_port.refresh_living_statuses = func(): game.simulation_tick_controller.refresh_living_statuses()
	actuator_port.drop_resource_pile = func(position, resource_type, amount): game.resource_pile_service.drop_resource_pile(position, resource_type, amount)
	actuator_port.fire_state_query = func(building): return game.fire_management_service.fire_state_for(building)
	actuator_port.apply_fire_state = func(building, fire_state): game.fire_management_service.apply_fire_state(building, fire_state)
	game.actuator_bridge.configure(actuator_port)
	game.simulation_event_dispatcher = SimulationEventDispatcher.new()
	game.simulation_event_dispatcher.configure({
		"start_meal": func(hour): game.canteen_service.start_meal(hour),
		"start_park_rest": func(cooks_only): game.simulation_tick_controller.start_park_rest(cooks_only),
		"end_ai_work_shift": func(): game.simulation_handlers.end_ai_work_shift(),
		"clear_finished_daily_orders": func(workday_id): game.simulation_handlers.clear_finished_daily_orders(workday_id),
		"refresh_living_statuses": func(): game.simulation_tick_controller.refresh_living_statuses(),
		"update_workers": game.update_workers,
		"apply_pending_workday_hours": game.apply_pending_workday_hours,
		"clear_expired_overtime_orders": func(): game.simulation_handlers.clear_expired_overtime_orders(),
		"reset_building_night_work_toggles": func(): game.simulation_handlers.reset_building_night_work_toggles(),
		"resume_overtime_daily_orders": func(): game.simulation_handlers.resume_overtime_daily_orders(),
		"update_interface": game.update_interface,
		"citizen_ai_refresh": func(): if game.citizen_ai != null: game.citizen_ai.request_decision_refresh(),
		"school_day_ended": func(): game.simulation_handlers.on_school_day_ended(),
		"daily_settlement_update": func(event): game.simulation_handlers.on_daily_settlement_update(event)
	})


func _setup_ui_controllers() -> void:
	game.ui_attacher.create_all_controllers()
	game.ui_attacher.configure_all(game)
	game.warehouse_fill_label_controller = WarehouseFillLabelController.new()
	game.warehouse_fill_label_controller.configure(game)
	game.building_status_indicator_controller = BuildingStatusIndicatorController.new()
	game.building_status_indicator_controller.configure(game)
	game.first_person_hud_controller = FirstPersonHUDController.new()
	game.first_person_hud_controller.configure(game)
	game.label_distance_fade_controller = LabelDistanceFadeController.new()
	game.label_distance_fade_controller.configure(game)


func _setup_world_and_events() -> void:
	game.settlement.apply_launch_config(game.launch_config)
	var _event_registry := EventRegistry.new()
	_event_registry.register_all(TentEraEvents.build())
	game.event_service = EventService.new(_event_registry)
	_apply_daily_forecast()


## The settlement's forecast, announced to the player in its own words and handed
## to the environment as a weather pattern (`world_environment.md` §7). The
## settlement owns which day gets which weather; the sky owns what that looks like.
func _apply_daily_forecast() -> void:
	game.tent_weather = TentEraSurvivalRules.weather_for_day(game.day_cycle.current_day)
	if game.world_session != null:
		game.world_session.environment.set_pattern(
			TentEraSurvivalRules.weather_pattern_for(game.tent_weather),
			int(game.clock.minutes))


func _setup_controllers_and_world() -> void:
	game.ambient_spawner = AmbientSpawner.new()
	game.add_child(game.ambient_spawner)
	game.ambient_spawner.setup(game, game.launch_config.map_document, game.launch_config.start_option)
	game.player_controller = PlayerController.new()
	game.add_child(game.player_controller)
	game.player_controller.setup(game)
	game.building_placement_controller = BuildingPlacementController.new()
	game.add_child(game.building_placement_controller)
	game.building_placement_controller.setup(game)
	game.survival_event_controller = SurvivalEventController.new()
	game.add_child(game.survival_event_controller)
	game.survival_event_controller.setup(game)
	game.create_world()
	# WorldSetup and its TerrainService only exist after create_world(). Anchors
	# subscribe here so every subsequently registered footprint pins its ground.
	game.terrain_anchor_service.configure(game.world_setup.terrain_service, game.building_registry)
	# Surface wear and regrowth need the same `TerrainService`, and the trail field
	# they read their crossings from already exists by now.
	game.surface_controller = SettlementSurfaceController.new()
	game.surface_controller.configure(game.world_setup.terrain_service, game.trail_field)
	if game.ui_manager != null:
		game.ui_manager.create_interface()
	game.ambient_spawner.create_forest()
	game.ambient_spawner.spawn_trash_piles()
	game.ambient_spawner.spawn_initial_rabbits()


func _setup_citizens_and_ai() -> void:
	game.citizen_factory.create_citizens()
	game.citizen_factory.create_party_stash()
	game.simulation_tick_controller.refresh_living_statuses()
	if not game.citizen_ai.configure(
		SettlementAIWorldFacade.new(game),
		CitizenAIRegistry.default_goals(),
		CitizenAIRegistry.default_order_providers()
	):
		push_error("Native citizen AI failed to capture its initial world snapshot")
	game.update_workers()
	game.update_interface("Build a simple store, then gather materials for the first campfire and tents.")
	game.player_controller.enter_first_person(game.hero_citizen, "Hero view enabled.")
