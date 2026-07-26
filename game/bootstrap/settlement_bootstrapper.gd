class_name SettlementBootstrapper
extends RefCounted


const BillboardLabelScene = preload("res://game/features/ui/presentation/billboard_label.tscn")
const BuildingAvailabilityServiceScript = preload("res://game/features/buildings/application/building_availability_service.gd")
const BuildingLifecycleServiceScript = preload("res://game/features/buildings/application/building_lifecycle_service.gd")
const BuildingPlacementControllerScript = preload("res://game/features/buildings/presentation/building_placement_controller.gd")
const BuildingPlacementServiceScript = preload("res://game/features/buildings/application/building_placement_service.gd")
const BuildingQueueServiceScript = preload("res://game/features/citizens/application/building_queue_service.gd")
const BuildingResearchServiceScript = preload("res://game/features/buildings/application/building_research_service.gd")
const BuildingStatusIndicatorControllerScript = preload("res://game/features/buildings/presentation/building_status_indicator_controller.gd")
const BuildingVisualsServiceScript = preload("res://game/features/buildings/presentation/building_visuals_service.gd")
const BuildingZoneServiceScript = preload("res://game/features/buildings/application/building_zone_service.gd")
const CitizenDailyOrderServiceScript = preload("res://game/features/citizens/application/citizen_daily_order_service.gd")
const CitizenLifecycleServiceScript = preload("res://game/features/citizens/application/citizen_lifecycle_service.gd")
const CitizenLivingStatusServiceScript = preload("res://game/features/citizens/application/citizen_living_status_service.gd")
const CitizenRegistrationServiceScript = preload("res://game/features/citizens/application/citizen_registration_service.gd")
const CleaningGoalScript = preload("res://game/features/decision/domain/goals/cleaning_goal.gd")
const ConstructionEntrancePostScene = preload("res://game/features/buildings/presentation/construction_entrance_post.tscn")
const ConstructionGoalScript = preload("res://game/features/decision/domain/goals/construction_goal.gd")
const ConstructionOrderProviderScript = preload("res://game/features/decision/application/construction_order_provider.gd")
const ConstructionSiteScene = preload("res://game/features/buildings/presentation/construction_site.tscn")
const CourierDeliveryGoalScript = preload("res://game/features/decision/domain/goals/courier_delivery_goal.gd")
const CourierDeliveryOrderProviderScript = preload("res://game/features/decision/application/courier_delivery_order_provider.gd")
const CourierDispatcherScript = preload("res://game/features/logistics/application/courier_dispatcher.gd")
const CourierTaskPublisherScript = preload("res://game/features/logistics/application/courier_task_publisher.gd")
const CourierTaskServiceScript = preload("res://game/features/logistics/application/courier_task_service.gd")
const DailyPlayerOrderProviderScript = preload("res://game/features/decision/application/daily_player_order_provider.gd")
const DigSiteScene = preload("res://game/features/world/presentation/dig_site.tscn")
const EventRegistryScript = preload("res://game/features/events/domain/event_registry.gd")
const EventServiceScript = preload("res://game/features/events/application/event_service.gd")
const ExcavationGoalScript = preload("res://game/features/decision/domain/goals/excavation_goal.gd")
const ExcavationOrderProviderScript = preload("res://game/features/decision/application/excavation_order_provider.gd")
const FactoryWorkGoalScript = preload("res://game/features/decision/domain/goals/factory_work_goal.gd")
const FactoryWorkOrderProviderScript = preload("res://game/features/decision/application/factory_work_order_provider.gd")
const FarmingGoalScript = preload("res://game/features/decision/domain/goals/farming_goal.gd")
const FarmingOrderProviderScript = preload("res://game/features/decision/application/farming_order_provider.gd")
const FireLightScene = preload("res://game/features/buildings/presentation/fire_light.tscn")
const FirstPersonHUDControllerScript = preload("res://game/features/ui/presentation/first_person_hud_controller.gd")
const FollowLeaderGoalScript = preload("res://game/features/decision/domain/goals/follow_leader_goal.gd")
const ForestryGoalScript = preload("res://game/features/decision/domain/goals/forestry_goal.gd")
const ForestryOrderProviderScript = preload("res://game/features/decision/application/forestry_order_provider.gd")
const GatheringGoalScript = preload("res://game/features/decision/domain/goals/gathering_goal.gd")
const GatheringOrderProviderScript = preload("res://game/features/decision/application/gathering_order_provider.gd")
const HeroInteractionServiceScript = preload("res://game/features/citizens/application/hero_interaction_service.gd")
const HeroPocketServiceScript = preload("res://game/features/citizens/application/hero_pocket_service.gd")
const LabelDistanceFadeControllerScript = preload("res://game/features/ui/presentation/label_distance_fade_controller.gd")
const MealGoalScript = preload("res://game/features/decision/domain/goals/meal_goal.gd")
const NavigationBridgeScript = preload("res://game/features/routing/presentation/navigation_bridge.gd")
const NavigationFacadeScript = preload("res://game/features/routing/application/navigation_facade.gd")
const NavigationObstaclePublisherScript = preload("res://game/features/routing/application/navigation_obstacle_publisher.gd")
const RegisterGoalScript = preload("res://game/features/decision/domain/goals/register_goal.gd")
const ResourcePileVisualsScript = preload("res://game/features/logistics/presentation/resource_pile_visuals.gd")
const RestGoalScript = preload("res://game/features/decision/domain/goals/rest_goal.gd")
const ReturnHomeWhenIdleGoalScript = preload("res://game/features/decision/domain/goals/return_home_when_idle_goal.gd")
const RoadNetworkServiceScript = preload("res://game/features/routing/application/road_network_service.gd")
const SchoolServiceScript = preload("res://game/features/buildings/application/school_service.gd")
const ServiceWorkGoalScript = preload("res://game/features/decision/domain/goals/service_work_goal.gd")
const ServiceWorkOrderProviderScript = preload("res://game/features/decision/application/service_work_order_provider.gd")
const SettlementActuatorBridgeScript = preload("res://game/features/decision/presentation/settlement_actuator_bridge.gd")
const SettlementDailyRulesServiceScript = preload("res://game/features/settlement/application/settlement_daily_rules_service.gd")
const SettlementSurvivalServiceScript = preload("res://game/features/settlement/application/settlement_survival_service.gd")
const SimulationEventDispatcherScript = preload("res://game/features/simulation/application/simulation_event_dispatcher.gd")
const SleepGoalScript = preload("res://game/features/decision/domain/goals/sleep_goal.gd")
const StorageDeliveryServiceScript = preload("res://game/features/logistics/application/storage_delivery_service.gd")
const StorageRoutingServiceScript = preload("res://game/features/logistics/application/storage_routing_service.gd")
const SurvivalEventControllerScript = preload("res://game/features/events/presentation/survival_event_controller.gd")
const TentEraEventsScript = preload("res://game/features/events/application/tent_era_events.gd")
const TerritoryServiceScript = preload("res://game/features/world/application/territory_service.gd")
const ToiletGoalScript = preload("res://game/features/decision/domain/goals/toilet_goal.gd")
const TradeServiceScript = preload("res://game/features/logistics/application/trade_service.gd")
const TrailFieldServiceScript = preload("res://game/features/routing/application/trail_field_service.gd")
const TrailTextureRendererScript = preload("res://game/features/routing/presentation/trail_texture_renderer.gd")
const VillageTerritoryServiceScript = preload("res://game/features/buildings/application/village_territory_service.gd")
const WarehouseFillLabelControllerScript = preload("res://game/features/logistics/presentation/warehouse_fill_label_controller.gd")
const WorkforceOrderProviderScript = preload("res://game/features/decision/application/workforce_order_provider.gd")
const WorkplaceLaborServiceScript = preload("res://game/features/settlement/application/workplace_labor_service.gd")

## Handles all service initialization for SettlementGame.
## Called from SettlementGame._ready() to keep the Node script focused on runtime.

var game: SettlementGame


func run(p_game: SettlementGame) -> void:
	game = p_game
	_setup_hero_services()
	_setup_workplace_and_visuals()
	_setup_territory()
	_setup_ai_and_navigation()
	_setup_citizen_lifecycle()
	_setup_building_services()
	_setup_construction_and_demolition()
	_setup_canteen_and_resources()
	_setup_foraging_and_fire()
	_setup_building_maintenance()
	_setup_settlement_survival_and_daily_rules()
	_setup_building_lifecycle()
	_setup_excavation_and_factory()
	_setup_citizen_registration_and_school()
	_setup_citizen_needs_and_orders()
	_setup_trade_and_logistics()
	_setup_courier_system()
	_setup_actuator_and_events()
	_setup_ui_controllers()
	_setup_world_and_events()
	_setup_controllers_and_world()
	_setup_citizens_and_ai()
	_finalize_launch(game.get_node_or_null("/root/GameLaunchManager"))


func _setup_hero_services() -> void:
	game.hero_pocket_service = HeroPocketServiceScript.new()
	game.hero_pocket_service.configure(func() -> Citizen: return game.player_citizen, func(position, resources, is_backpack_pile): return game.resource_pile_service.create_resource_pile(position, resources, is_backpack_pile), game._update_interface, func(): game.hero_interaction_controller.refresh_interaction_hint())
	game.hero_interaction_service = HeroInteractionServiceScript.new()


func _setup_workplace_and_visuals() -> void:
	game.workplace_labor_service = WorkplaceLaborServiceScript.new()
	game.workplace_labor_service.configure(
		game.settlement,
		game.citizens,
		func() -> Node3D: return game.campfire_node,
		func() -> Node3D: return game.canteen,
		func() -> Vector3: return game.canteen_position,
		game.warehouse_positions,
		game.construction_sites,
		game.demolition_sites,
		game.tree_positions,
		game.pond_positions,
		game.craft_tent_positions,
		game.dig_sites,
		func(building): return game.fire_management_service.is_fire_lit(building),
		game._update_interface,
		game.workplace_controller.available_employer_capacity,
		game.workplace_controller.builder_job_capacity,
		func(site): return game.excavation_service.can_work_at_dig_site(site),
		game._employment_centre_building
	)
	game.building_visuals_service = BuildingVisualsServiceScript.new()
	game.building_visuals_service.configure(
		game.entrance_lights,
		game.house_lights,
		game.random
	)


func _setup_territory() -> void:
	game.territory_service = TerritoryServiceScript.new()
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
	game.nav_grid = NavGrid.new()
	game.nav_grid.configure(SettlementGame.CELL_SIZE, game.board_cells)
	game.road_network_service = RoadNetworkServiceScript.new()
	game.road_network_service.configure(game.nav_grid)
	game.navigation_obstacle_publisher = NavigationObstaclePublisherScript.new()
	game.navigation_obstacle_publisher.configure(game.nav_grid)
	game.trail_field = TrailFieldServiceScript.new()
	game.trail_field.configure(game.board_cells * SettlementGame.CELL_SIZE, SettlementGame.CELL_SIZE, game.nav_grid)
	game.trail_texture_renderer = TrailTextureRendererScript.new()
	game.route_service = GridRouteService.new()
	game.route_service.configure(game.nav_grid)
	game.navigation_facade = NavigationFacadeScript.new()
	game.navigation_facade.configure(game.nav_grid, game.route_service)
	game.navigation_bridge = NavigationBridgeScript.new()
	game.add_child(game.navigation_bridge)
	game.navigation_bridge.configure(game.nav_grid, game.navigation_facade, game.route_service, game.navigation_obstacle_publisher)
	game.building_queue_service = BuildingQueueServiceScript.new()
	game.building_queue_service.configure(game.building_registry, game.nav_grid)
	game.building_queue_service.set_citizen_alive_checker(func(citizen_id): return game.citizen_factory.is_ai_citizen_id_alive(citizen_id))


func _setup_citizen_lifecycle() -> void:
	game.citizen_lifecycle_service = CitizenLifecycleServiceScript.new()
	game.citizen_lifecycle_service.configure(
		game.citizens,
		game.pending_arrivals,
		game.arrival_greeters,
		game.arrival_waiting_greeters,
		game.arrival_escort_ids,
		func() -> Node3D: return game.entrance_stone,
		func(): return game.building_management.entrance_anchor_position(),
		game.employment_center_position,
		func(): return game.simulation_tick_controller.is_work_time(),
		game._update_interface,
		game._show_house_menu,
		game._add_citizen,
		func(citizen): game.simulation_tick_controller.refresh_living_status(citizen),
		game._request_courier_dispatch,
		func(citizen_id): return game.citizen_factory.citizen_for_ai_id(citizen_id),
		game._terrain_height_at,
		func(ai_id: int) -> void: if game.citizen_ai != null: game.citizen_ai.unregister_citizen(ai_id),
		func(ai_id: int) -> void: if game.citizen_ai != null: game.citizen_ai.cancel_citizen_work(ai_id),
		func(ai_id: int) -> void: if game.canteen_service != null: game.canteen_service.remove_citizen(ai_id),
		func(ai_id: int) -> void: if game.citizen_needs_service != null: game.citizen_needs_service.remove_citizen(ai_id),
		func(courier: Citizen) -> void: game.courier_dispatcher.complete_for(courier),
		func() -> Node3D: return game.selected_house,
		func() -> int: return game.day_cycle.current_day
	)


func _setup_building_services() -> void:
	game.building_zone_service = BuildingZoneServiceScript.new()
	game.building_availability_service = BuildingAvailabilityServiceScript.new()
	game.building_availability_service.configure(game.settlement)
	game.building_research_service = BuildingResearchServiceScript.new()
	game.building_research_service.configure(game.settlement)
	game.village_territory_service = VillageTerritoryServiceScript.new()
	game.village_territory_service.configure(game.building_registry, int(game.settlement.era))
	game.sawmills = SawmillService.new()
	game.sawmills.configure(game.sawmill_stocks, game.sawmill_positions, SettlementGame.SAWMILL_PROCESS_DURATION, game._cell_from_position)


func _setup_construction_and_demolition() -> void:
	var construction_runtime := ConstructionRuntime.new()
	construction_runtime.scene_root = game
	construction_runtime.settlement = game.settlement
	construction_runtime.building_registry = game.building_registry
	construction_runtime.citizens = game.citizens
	construction_runtime.duration = SettlementGame.CONSTRUCTION_DURATION
	construction_runtime.builder_power = func(site_node): return game.construction_controller.building_power(site_node)
	construction_runtime.builder_count = func(site_node): return game.construction_controller.builder_count(site_node)
	construction_runtime.set_status = func(text): game.construction_controller.set_construction_status(text)
	construction_runtime.building_completed = func(cell, building_type, position_on_board, building, blueprint): game.construction_controller.complete_building(cell, building_type, position_on_board, building, blueprint)
	construction_runtime.workers_changed = game._update_workers
	construction_runtime.navigation_changed = func(): game.world_navigation_controller.refresh_navigation_grid()
	construction_runtime.update_supply_label = func(site): game.construction_controller.update_construction_supply_label(site)
	game.construction = ConstructionService.new()
	game.construction.site_scene = ConstructionSiteScene
	game.construction.entrance_post_scene = ConstructionEntrancePostScene
	game.construction.configure(construction_runtime)
	var demolition_runtime := DemolitionRuntime.new()
	demolition_runtime.duration = SettlementGame.DEMOLITION_DURATION
	demolition_runtime.building_power = func(site_node): return game.construction_controller.building_power(site_node)
	demolition_runtime.is_ready = func(site): return game.building_lifecycle_service.demolition_ready(site)
	demolition_runtime.completed = game._finish_demolition
	game.demolition = DemolitionService.new()
	game.demolition.configure(demolition_runtime)
	game.water_collector_service = WaterCollectorService.new()
	game.water_collector_service.configure(game.water_collectors)


func _setup_canteen_and_resources() -> void:
	game.canteen_service = CanteenService.new()
	game.canteen_service.configure(
		game.settlement,
		game.citizens,
		func() -> Node3D: return game.canteen,
		func() -> int: return game.canteen_food,
		func(value): game.logistics_controller.set_canteen_food(value),
		func() -> Vector3: return game.canteen_position,
		func() -> bool: return game.pending_canteen_delivery,
		func() -> Citizen: return game.pending_canteen_carrier,
		func() -> int: return game.pending_canteen_delivery_amount,
		func(active, carrier, amount): game.logistics_controller.set_canteen_delivery_state(active, carrier, amount),
		func(): return game.logistics_controller.is_canteen_delivery_in_progress(),
		func(building): return game.fire_management_service.is_fire_lit(building),
		game._has_cook,
		game._update_interface,
		game._request_courier_dispatch,
		func(): return game.simulation_tick_controller.is_work_time(),
		game._update_workers
	)
	game.resource_pile_service = ResourcePileService.new(game, game.resource_piles, game.settlement, game.weather_state)
	game.resource_pile_service.set_visuals(ResourcePileVisualsScript.new())


func _setup_foraging_and_fire() -> void:
	game.foraging_service = ForagingService.new()
	game.foraging_service.billboard_label_scene = BillboardLabelScene
	game.foraging_service.set_random(game.random)
	game.foraging_service.setup(
		game.settlement,
		game.world_resource_state,
		game.forager_positions,
		game.forage_sources,
		game.forage_respawn_at,
		game.rabbit_sources,
		game.rabbit_respawn_at,
		game.grass_sources,
		game.tree_nodes,
		game.tree_positions,
		game.gather_progress_labels,
		game._terrain_height_at,
		game._cell_from_position,
		func(): return game.hero_interaction_controller.first_person_target()
	)
	# Natural-resource dictionaries are owned by ForagingService. Configure hero
	# proximity queries only after that service exists, otherwise the bootstrap
	# getters return temporary empty dictionaries that never receive grass data.
	game.hero_interaction_service.configure(
		func() -> Citizen: return game.player_citizen,
		SettlementGame.INTERACTION_RANGE,
		game.tree_positions,
		game.tree_nodes,
		game.sawmill_positions,
		game.farm_positions,
		game.pond_positions,
		game.grass_sources,
		game.forage_sources,
		game.rabbit_sources,
		game._cell_from_position,
		func(position): return game.foraging_service.consume_grass_source(position)
	)
	game.fire_management_service = FireManagementService.new()
	game.fire_management_service.setup(
		game.building_registry,
		game.event_service,
		game.settlement,
		game.day_cycle,
		func() -> int: return int(game.game_minutes),
		func() -> Node3D: return game.campfire_node,
		game._add_message,
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
			"update_workers": game._update_workers,
			"refresh_living_status": func(citizen): game.simulation_tick_controller.refresh_living_status(citizen)
		}
	)


func _setup_settlement_survival_and_daily_rules() -> void:
	game.settlement_survival_service = SettlementSurvivalServiceScript.new()
	game.settlement_survival_service.configure(
		game.settlement,
		game.day_cycle,
		game.clock,
		game.citizens,
		game.random,
		game.weather_state,
		game.building_registry,
		game.fire_management_service,
		func() -> int: return game.tent_weather,
		func() -> Node3D: return game.entrance_stone,
		func() -> Variant: return game.event_service,
		func(): return game.simulation_tick_controller.has_lit_communal_fire(),
		game._add_message,
		func(citizen): return game.simulation_tick_controller.is_citizen_work_time(citizen),
		func(): return game.simulation_tick_controller.is_work_time()
	)
	game.settlement_daily_rules_service = SettlementDailyRulesServiceScript.new()
	game.settlement_daily_rules_service.configure(
		game.settlement,
		game.day_cycle,
		game.citizens,
		game.trail_field,
		func() -> Variant: return game.event_service,
		game.citizen_needs_service,
		func() -> Node3D: return game.canteen,
		func() -> int: return game.tent_weather,
		game._add_message,
		game._update_interface,
		game._apply_building_wear_and_repairs,
		func(): game.resource_pile_service.decay_resource_piles(),
		func(): return game.building_registry.housing_capacity(),
		func(): game.settlement_survival_service.check_daily_departures(),
		game._stored_resources,
		game._warehouse_capacity
	)


func _setup_building_lifecycle() -> void:
	game.building_lifecycle_service = BuildingLifecycleServiceScript.new()
	game.building_lifecycle_service.configure(
		game.settlement,
		game.citizens,
		game.building_registry,
		game.demolition,
		game.village_territory_service,
		game.warehouse_positions,
		game.sawmill_positions,
		game.farm_positions,
		game.builders_guild_positions,
		game.construction_company_positions,
		game.forager_positions,
		game.materials_yard_positions,
		game.school_positions,
		game.park_positions,
		game.gathering_place_positions,
		game.leisure_positions,
		game.craft_tent_positions,
		game.market_positions,
		game.water_collectors,
		game.factories,
		game.house_lights,
		game.entrance_lights,
		SettlementGame.HOUSE_CAPACITY,
		FireLightScene,
		func() -> Node3D: return game.entrance_stone,
		func() -> Node3D: return game.campfire_node,
		func(v: Node3D) -> void: game.campfire_node = v,
		func() -> Node3D: return game.canteen,
		func(v: Node3D) -> void: game.canteen = v,
		func() -> int: return game.canteen_food,
		func(v: int) -> void: game.canteen_food = v,
		func() -> bool: return game.pending_canteen_delivery,
		func() -> Node3D: return game.employment_office,
		func(v: Node3D) -> void: game.employment_office = v,
		func() -> Vector3: return game.employment_office_position,
		func(v: Vector3) -> void: game.employment_office_position = v,
		func() -> int: return game.completed_house_count,
		func(v: int) -> void: game.completed_house_count = v,
		func() -> int: return game.house_light_update_minute,
		func(v: int) -> void: game.house_light_update_minute = v,
		func() -> float: return game.game_minutes,
		game._can_hero_build,
		game._update_interface,
		game._update_workers,
		func(house): game.citizen_lifecycle_service.cancel_arrivals_for_house(house),
		func(building): game.building_visuals.add_demolition_marker(building),
		func(citizen): game.simulation_tick_controller.refresh_living_status(citizen),
		func(node): game.service_pocket_manager.unregister_service_pockets(node),
		func(building): game.logistics_controller.return_in_transit_building_supplies(building),
		func(): game.canteen_service.cancel_canteen_delivery(),
		func(center, footprint): game.service_pocket_manager.unregister_navigation_footprint(center, footprint),
		func(): game.world_navigation_controller.refresh_boundary_markers(),
		func(): game.building_management.select_best_canteen(),
		func(position, resources, is_backpack_pile): return game.resource_pile_service.create_resource_pile(position, resources, is_backpack_pile),
		func(): game.world_navigation_controller.refresh_navigation_grid(),
		game.construction_controller.is_construction_site,
		func(centre): game.research_controller.activate_employment_centre(centre),
		game._convert_backpack_pile_to_regular,
		func(building, group_name, footprint): game.building_visuals.add_building_selector(building, group_name, footprint),
		func(building): game.building_visuals.add_warehouse_fill_label(building),
		game._sawmill_stock,
		func(building): game.building_visuals.create_gathering_place_visual(building),
		func(building, service_position): game.building_management.activate_kitchen_if_better(building, service_position),
		func(house): game.building_visuals.add_house_light(house),
		func(house): game.citizen_lifecycle_service.house_initial_residents(house),
		func(refund, message): game.research_controller.cancel_active_building_research(refund, message),
		func(citizen): game.research_controller.dismiss_official(citizen),
		func(citizen): game.citizen_lifecycle_service.send_to_unemployment_registration(citizen)
	)
	game.construction_priority_service = SettlementGame.ConstructionPriorityServiceScript.new()
	game.construction_priority_service.configure(
		game.construction_sites,
		game.warehouse_positions,
		game.sawmill_positions,
		game.campfire_node,
		game.canteen,
		func() -> int: return game.citizens.size(),
		func(): return game.building_registry.housing_capacity(),
		func() -> int: return game.settlement.amount(SettlementGame.ResourceIds.FOOD)
	)


func _setup_excavation_and_factory() -> void:
	game.excavation_service = SettlementGame.ExcavationServiceScript.new()
	game.excavation_service.dig_site_scene = DigSiteScene
	game.excavation_service.configure(
		game.settlement,
		game.citizens,
		game.dig_sites,
		game.dig_cells,
		game.exhausted_dig_cells,
		game.random,
		game._update_interface,
		game._update_workers,
		game._request_courier_dispatch,
		game._placement_key,
		game._is_clear_of_objects,
		game.employment_center_position,
		func(show): game.build_controller.show_territory_overlay(show),
		func(world_position): game.build_controller.move_selection(world_position),
		game._show_selected_citizen_menu,
		func() -> Citizen: return game.selected_builder,
		func() -> Vector3: return game.selected_world_position,
		func() -> Node3D: return game.world_setup.selection_marker,
		func() -> StandardMaterial3D: return game.world_setup.selection_material,
		game._set_dig_mode,
		game._set_build_mode,
		func(node: Node) -> void: game.add_child(node)
	)
	game.factory_service = SettlementGame.FactoryServiceScript.new()
	game.factory_service.configure(game.settlement, game.building_registry, game._add_message, game.random)


func _setup_citizen_registration_and_school() -> void:
	game.citizen_registration_service = CitizenRegistrationServiceScript.new()
	game.citizen_registration_service.configure(
		game.citizens,
		SettlementGame.OFFICER_POST_RADIUS,
		game._employment_centre_building,
		game.employment_center_position,
		func(): return game.simulation_tick_controller.is_work_time(),
		game._update_workers,
		func() -> int:
			game._registration_queue_counter += 1
			return game._registration_queue_counter
	)
	game.school_service = SchoolServiceScript.new()
	game.school_service.configure(game.school_positions, game.citizens)
	game.building_placement_service = BuildingPlacementServiceScript.new()
	game.building_placement_service.configure(
		game.dig_sites,
		game.terrain_blocked_cells,
		game.building_registry,
		game.tree_positions,
		game._terrain_height_at,
		SettlementGame.MAX_BUILD_SLOPE
	)


func _setup_citizen_needs_and_orders() -> void:
	game.citizen_daily_order_service = CitizenDailyOrderServiceScript.new()
	game.citizen_daily_order_service.configure(
		game.settlement,
		game.citizens,
		game.day_cycle,
		game.clock,
		game.building_registry,
		func() -> float: return game.runtime_seconds,
		func(): return game.simulation_tick_controller.is_work_time(),
		func(citizen): return game.simulation_tick_controller.is_citizen_work_time(citizen),
		func(): return game.outside_work_controller.absolute_game_minutes(),
		SettlementGame.GAME_MINUTES_PER_SECOND,
		func() -> void: if game.citizen_ai != null: game.citizen_ai.request_decision_refresh()
	)
	game.citizen_needs_service = CitizenNeedsService.new()
	game.citizen_needs_service.set_random(game.random)
	game.citizen_needs_service.configure(
		game.nav_grid,
		game.get_toilets,
		game._is_route_reachable,
		game.building_registry.building_type_for_node,
		game.tree_positions,
		game.grass_sources,
	)
	game.citizen_living_status_service = CitizenLivingStatusServiceScript.new()


func _setup_trade_and_logistics() -> void:
	game.trade_service = TradeServiceScript.new()
	game.trade_service.configure(
		game.settlement,
		game.citizens,
		game.queued_trades,
		game.pending_trades,
		game.warehouse_positions,
		game.ui_manager.market_menu,
		func() -> Node3D: return game.selected_market,
		func() -> Node3D: return game.entrance_stone,
		func(): return game.logistics_controller.get_delivery_position(),
		game._update_interface,
		func(): game.workplace_controller.refresh_market_menu(),
		game._request_courier_dispatch,
		func(): return game.simulation_tick_controller.total_game_minutes(),
		func(citizen_id): return game.citizen_factory.citizen_for_ai_id(citizen_id),
		func(position, resources, is_backpack_pile): return game.resource_pile_service.create_resource_pile(position, resources, is_backpack_pile),
		game._update_workers
	)
	game.storage_routing_service = StorageRoutingServiceScript.new()
	game.storage_routing_service.configure(
		game.settlement,
		game.warehouse_positions,
		game.resource_piles,
		func() -> Citizen: return game.player_citizen,
		SettlementGame.INTERACTION_RANGE,
		game._is_route_reachable,
		game._find_path_around_houses,
		game.nav_grid,
		game.dig_sites,
		func(site): return game.excavation_service.can_work_at_dig_site(site),
		func(site, depth): return game.excavation_service.resource_for_depth(site, depth),
		game._update_interface
	)


func _setup_courier_system() -> void:
	game.courier_dispatcher = CourierDispatcherScript.new()
	game.courier_dispatcher.configure(
		game.citizens,
		game.warehouse_positions,
		game.storage_routing_service,
		func() -> float: return game.runtime_seconds,
		game._publish_courier_tasks,
		func(task): return game.courier_task_service.is_courier_task_valid(task),
		func(courier, task): return game.courier_task_service.start_courier_task(courier, task),
		func(courier, task): game.courier_task_service.cancel_courier_task(courier, task),
		func(task): game.courier_task_service.release_task_warehouse_reservation(task)
	)
	game.storage_delivery_service = StorageDeliveryServiceScript.new()
	game.storage_delivery_service.configure(
		game.settlement,
		game.warehouse_positions,
		game.courier_dispatcher,
		game.storage_routing_service,
		func(task): game.courier_task_service.release_task_warehouse_reservation(task),
		func(position, resource_type, amount): game.resource_pile_service.drop_resource_pile(position, resource_type, amount),
		game._update_interface,
		game._request_courier_dispatch,
		func(citizen, minimum_hours): return game.simulation_tick_controller.send_citizen_to_leisure(citizen, minimum_hours)
	)
	game.courier_task_publisher = CourierTaskPublisherScript.new()
	game.courier_task_publisher.configure(
		game.settlement,
		game.citizens,
		game.construction_sites,
		game.warehouse_positions,
		game.pending_arrivals,
		game.queued_trades,
		game.sawmill_positions,
		game.water_collectors,
		game.building_registry,
		game.sawmills,
		game.courier_dispatcher,
		func() -> Node3D: return game.entrance_stone,
		func() -> Node3D: return game.canteen,
		func() -> int: return game.canteen_food,
		func() -> Vector3: return game.canteen_position,
		func() -> bool: return game.pending_canteen_delivery,
		func() -> float: return game.runtime_seconds,
		func(site): game.construction_controller.reconcile_construction_reservations(site),
		func(): game.logistics_controller.reconcile_repair_reservations(),
		game._cell_from_position,
		func(from): return game.logistics_controller.get_nearest_delivery_position(from),
		game._warehouse_delivery_position,
		func(site): return game.construction_controller.construction_development_priority(site),
		func(resource_type, from_position): return game.logistics_controller.construction_material_sources(resource_type, from_position),
		func(resource_type, source): return game.logistics_controller.construction_source_available(resource_type, source),
		func(building): return game.fire_management_service.fire_state_for(building),
		func(building, fire_state): return game.logistics_controller.firewood_task_priority(building, fire_state),
		func(building: Node3D) -> bool: return game.fire_management_service.is_managed_fire_source(building)
	)
	game.courier_task_service = CourierTaskServiceScript.new()
	game.courier_task_service.configure(
		game.settlement,
		game.citizens,
		game.queued_trades,
		game.pending_trades,
		game.warehouse_positions,
		game.pending_arrivals,
		game.arrival_greeters,
		game.outside_workers,
		game.building_registry,
		game.sawmills,
		game.water_collector_service,
		game.trade_service,
		game.canteen_service,
		func() -> Node3D: return game.canteen,
		func() -> int: return game.canteen_food,
		func() -> Vector3: return game.canteen_position,
		func() -> bool: return game.pending_canteen_delivery,
		func(active, carrier, amount): game.logistics_controller.set_canteen_delivery_state(active, carrier, amount),
		func() -> Node3D: return game.entrance_stone,
		func() -> float: return game.runtime_seconds,
		func(building): return game.fire_management_service.fire_state_for(building),
		func(building, fire_state): game.fire_management_service.apply_fire_state(building, fire_state),
		game._is_route_reachable,
		func(resource_type, source): return game.logistics_controller.construction_source_available(resource_type, source),
		func(citizen_id): return game.citizen_factory.citizen_for_ai_id(citizen_id)
	)


func _setup_actuator_and_events() -> void:
	game.actuator_bridge = SettlementActuatorBridgeScript.new()
	game.actuator_bridge.configure(
		game.canteen_service,
		game.courier_dispatcher,
		game.construction,
		game.settlement,
		game.building_registry,
		game.storage_delivery_service,
		game.factory_service,
		game.sawmills,
		game.water_collector_service,
		game.excavation_service,
		game.citizen_needs_service,
		game.trade_service,
		game.resource_piles,
		func() -> float: return game.game_minutes,
		func() -> float: return game.runtime_seconds,
		game._update_interface,
		game._request_courier_dispatch,
		func() -> void: if game.citizen_ai != null: game.citizen_ai.request_decision_refresh(),
		func(): game.simulation_tick_controller.refresh_living_statuses(),
		func(position, resource_type, amount): game.resource_pile_service.drop_resource_pile(position, resource_type, amount),
		func(building): return game.fire_management_service.fire_state_for(building),
		func(building, fire_state): game.fire_management_service.apply_fire_state(building, fire_state)
	)
	game.simulation_event_dispatcher = SimulationEventDispatcherScript.new()
	game.simulation_event_dispatcher.configure({
		"start_meal": func(hour): game.canteen_service.start_meal(hour),
		"start_park_rest": func(cooks_only): game.simulation_tick_controller.start_park_rest(cooks_only),
		"end_ai_work_shift": func(): game.simulation_handlers.end_ai_work_shift(),
		"clear_finished_daily_orders": func(workday_id): game.simulation_handlers.clear_finished_daily_orders(workday_id),
		"refresh_living_statuses": func(): game.simulation_tick_controller.refresh_living_statuses(),
		"update_workers": game._update_workers,
		"apply_pending_workday_hours": game._apply_pending_workday_hours,
		"clear_expired_overtime_orders": func(): game.simulation_handlers.clear_expired_overtime_orders(),
		"reset_building_night_work_toggles": func(): game.simulation_handlers.reset_building_night_work_toggles(),
		"resume_overtime_daily_orders": func(): game.simulation_handlers.resume_overtime_daily_orders(),
		"update_interface": game._update_interface,
		"citizen_ai_refresh": func(): if game.citizen_ai != null: game.citizen_ai.request_decision_refresh(),
		"school_day_ended": func(): game.simulation_handlers.on_school_day_ended(),
		"daily_settlement_update": func(event): game.simulation_handlers.on_daily_settlement_update(event)
	})


func _setup_ui_controllers() -> void:
	game.ui_attacher.create_all_controllers()
	game.ui_attacher.configure_all(game)
	game.warehouse_fill_label_controller = WarehouseFillLabelControllerScript.new()
	game.warehouse_fill_label_controller.configure(game)
	game.building_status_indicator_controller = BuildingStatusIndicatorControllerScript.new()
	game.building_status_indicator_controller.configure(game)
	game.first_person_hud_controller = FirstPersonHUDControllerScript.new()
	game.first_person_hud_controller.configure(game)
	game.label_distance_fade_controller = LabelDistanceFadeControllerScript.new()
	game.label_distance_fade_controller.configure(game)


func _setup_world_and_events() -> void:
	game.settlement.apply_launch_config(game.launch_config)
	var _event_registry := EventRegistryScript.new()
	_event_registry.register_all(TentEraEventsScript.build())
	game.event_service = EventServiceScript.new(_event_registry)
	game.tent_weather = SettlementGame.TentEraSurvivalRulesScript.weather_for_day(game.day_cycle.current_day)
	game.weather_state.new_day(game.tent_weather, game.random, int(game.clock.minutes))


func _setup_controllers_and_world() -> void:
	game.ambient_spawner = AmbientSpawner.new()
	game.add_child(game.ambient_spawner)
	var active_biome: BiomeDefinition = game.territory_service.get_active_biome()
	game.ambient_spawner.setup(game, active_biome.natural_layout if active_biome != null else null)
	game.player_controller = PlayerController.new()
	game.add_child(game.player_controller)
	game.player_controller.setup(game)
	game.building_placement_controller = BuildingPlacementControllerScript.new()
	game.add_child(game.building_placement_controller)
	game.building_placement_controller.setup(game)
	game.survival_event_controller = SurvivalEventControllerScript.new()
	game.add_child(game.survival_event_controller)
	game.survival_event_controller.setup(game)
	game._create_world()
	if game.ui_manager != null:
		game.ui_manager.create_interface()
	game.ambient_spawner.create_forest()
	game.ambient_spawner.spawn_trash_piles()
	game.ambient_spawner.spawn_initial_rabbits()
	game.ambient_spawner.create_ponds()


func _setup_citizens_and_ai() -> void:
	game.citizen_factory.create_citizens()
	game.citizen_factory.create_starter_backpack()
	game.simulation_tick_controller.refresh_living_statuses()
	if not game.citizen_ai.configure(
		SettlementAIWorldFacade.new(game),
		[SleepGoalScript.new(), MealGoalScript.new(), ToiletGoalScript.new(), RestGoalScript.new(), ReturnHomeWhenIdleGoalScript.new(), FollowLeaderGoalScript.new(), RegisterGoalScript.new(), ForestryGoalScript.new(), FarmingGoalScript.new(), ConstructionGoalScript.new(), GatheringGoalScript.new(), CleaningGoalScript.new(), ExcavationGoalScript.new(), ServiceWorkGoalScript.new(), FactoryWorkGoalScript.new(), CourierDeliveryGoalScript.new()],
		[WorkforceOrderProviderScript.new(), DailyPlayerOrderProviderScript.new(), ForestryOrderProviderScript.new(), FarmingOrderProviderScript.new(), ConstructionOrderProviderScript.new(), GatheringOrderProviderScript.new(), ExcavationOrderProviderScript.new(), ServiceWorkOrderProviderScript.new(), FactoryWorkOrderProviderScript.new(), CourierDeliveryOrderProviderScript.new()]
	):
		push_error("Native citizen AI failed to capture its initial world snapshot")
	game._update_workers()
	game._update_interface("Build a simple store, then gather materials for the first campfire and tents.")
	game.player_controller.enter_first_person(game.hero_citizen, "Hero view enabled.")


func _finalize_launch(launch_mgr: Node) -> void:
	var pending_save: String = ""
	if launch_mgr != null and "pending_save_path" in launch_mgr:
		pending_save = str(launch_mgr.get("pending_save_path"))
		if not pending_save.is_empty():
			launch_mgr.set("pending_save_path", "")
	if not pending_save.is_empty():
		SettlementGame.SaveGameServiceScript.load_game(game, pending_save)
