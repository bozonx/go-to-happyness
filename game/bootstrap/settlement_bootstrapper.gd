class_name SettlementBootstrapper
extends RefCounted

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
	game.hero_pocket_service = SettlementGame.HeroPocketServiceScript.new()
	game.hero_pocket_service.configure(func() -> Citizen: return game.player_citizen, game._create_resource_pile, game._update_interface, game._refresh_interaction_hint)
	game.hero_interaction_service = SettlementGame.HeroInteractionServiceScript.new()
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
		game._consume_grass_source
	)


func _setup_workplace_and_visuals() -> void:
	game.workplace_labor_service = SettlementGame.WorkplaceLaborServiceScript.new()
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
		game._is_fire_lit,
		game._update_interface,
		game._available_employer_capacity,
		game._builder_job_capacity,
		game._can_work_at_dig_site,
		game._employment_centre_building
	)
	game.building_visuals_service = SettlementGame.BuildingVisualsServiceScript.new()
	game.building_visuals_service.configure(
		game.entrance_lights,
		game.house_lights,
		game.random
	)


func _setup_territory() -> void:
	game.territory_service = SettlementGame.TerritoryServiceScript.new()
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
	game.nav_grid.configure(SettlementGame.CELL_SIZE, SettlementGame.BOARD_CELLS)
	game.road_network_service = SettlementGame.RoadNetworkServiceScript.new()
	game.road_network_service.configure(game.nav_grid)
	game.navigation_obstacle_publisher = SettlementGame.NavigationObstaclePublisherScript.new()
	game.navigation_obstacle_publisher.configure(game.nav_grid)
	game.trail_field = SettlementGame.TrailFieldServiceScript.new()
	game.trail_field.configure(SettlementGame.BOARD_CELLS * SettlementGame.CELL_SIZE, SettlementGame.CELL_SIZE, game.nav_grid)
	game.route_service = GridRouteService.new()
	game.route_service.configure(game.nav_grid)
	game.navigation_facade = SettlementGame.NavigationFacadeScript.new()
	game.navigation_facade.configure(game.nav_grid, game.route_service)
	game.navigation_bridge = SettlementGame.NavigationBridgeScript.new()
	game.add_child(game.navigation_bridge)
	game.navigation_bridge.configure(game.nav_grid, game.navigation_facade, game.route_service, game.navigation_obstacle_publisher)
	game.building_queue_service = SettlementGame.BuildingQueueServiceScript.new()
	game.building_queue_service.configure(game.building_registry, game.nav_grid)
	game.building_queue_service.set_citizen_alive_checker(game._is_ai_citizen_id_alive)


func _setup_citizen_lifecycle() -> void:
	game.citizen_lifecycle_service = SettlementGame.CitizenLifecycleServiceScript.new()
	game.citizen_lifecycle_service.configure(
		game.citizens,
		game.pending_arrivals,
		game.arrival_greeters,
		game.arrival_waiting_greeters,
		game.arrival_escort_ids,
		func() -> Node3D: return game.entrance_stone,
		game._entrance_anchor_position,
		game._employment_center_position,
		game._is_work_time,
		game._update_interface,
		game._show_house_menu,
		game._add_citizen,
		game._refresh_living_status,
		game._request_courier_dispatch,
		game._citizen_for_ai_id,
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
	game.building_availability_service = SettlementGame.BuildingAvailabilityServiceScript.new()
	game.building_availability_service.configure(game.settlement)
	game.building_research_service = SettlementGame.BuildingResearchServiceScript.new()
	game.building_research_service.configure(game.settlement)
	game.village_territory_service = SettlementGame.VillageTerritoryServiceScript.new()
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
	construction_runtime.builder_power = game._building_power
	construction_runtime.builder_count = game._builder_count
	construction_runtime.set_status = game._set_construction_status
	construction_runtime.building_completed = game._complete_building
	construction_runtime.workers_changed = game._update_workers
	construction_runtime.navigation_changed = game._refresh_navigation_grid
	construction_runtime.update_supply_label = game._update_construction_supply_label
	game.construction = ConstructionService.new()
	game.construction.site_scene = SettlementGame.ConstructionSiteScene
	game.construction.entrance_post_scene = SettlementGame.ConstructionEntrancePostScene
	game.construction.configure(construction_runtime)
	var demolition_runtime := DemolitionRuntime.new()
	demolition_runtime.duration = SettlementGame.DEMOLITION_DURATION
	demolition_runtime.building_power = game._building_power
	demolition_runtime.is_ready = game._demolition_ready
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
		game._set_canteen_food,
		func() -> Vector3: return game.canteen_position,
		func() -> bool: return game.pending_canteen_delivery,
		func() -> Citizen: return game.pending_canteen_carrier,
		func() -> int: return game.pending_canteen_delivery_amount,
		game._set_canteen_delivery_state,
		game._is_canteen_delivery_in_progress,
		game._is_fire_lit,
		game._has_cook,
		game._update_interface,
		game._request_courier_dispatch,
		game._is_work_time,
		game._update_workers
	)
	game.resource_pile_service = ResourcePileService.new(game, game.resource_piles, game.settlement, game.weather_state)
	game.resource_pile_service.set_visuals(SettlementGame.ResourcePileVisualsScript.new())


func _setup_foraging_and_fire() -> void:
	game.foraging_service = ForagingService.new()
	game.foraging_service.billboard_label_scene = SettlementGame.BillboardLabelScene
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
		game._first_person_target
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
		game._refresh_living_statuses,
		func() -> void: game.settlement.wellbeing = maxi(0, game.settlement.wellbeing - 1)
	)


func _setup_building_maintenance() -> void:
	game.building_maintenance_service = BuildingMaintenanceService.new()
	game.building_maintenance_service.setup(
		game.building_registry,
		game.settlement,
		game.village_territory_service,
		game.resource_pile_service,
		{
			"unregister_pockets": game._unregister_service_pockets,
			"move_stored_resources": game._move_stored_resources_to_pile,
			"return_supplies": game._return_in_transit_building_supplies,
			"remove_services": game._remove_building_services,
			"unregister_nav_footprint": game._unregister_navigation_footprint,
			"refresh_boundary": game._refresh_boundary_markers,
			"select_best_campfire": game._select_best_campfire,
			"refresh_nav_grid": game._refresh_navigation_grid,
			"update_workers": game._update_workers,
			"refresh_living_status": game._refresh_living_status
		}
	)


func _setup_settlement_survival_and_daily_rules() -> void:
	game.settlement_survival_service = SettlementGame.SettlementSurvivalServiceScript.new()
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
		game._has_lit_communal_fire,
		game._add_message,
		game._is_citizen_work_time,
		game._is_work_time
	)
	game.settlement_daily_rules_service = SettlementGame.SettlementDailyRulesServiceScript.new()
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
		game._decay_resource_piles,
		game._total_housing_slots,
		game._check_daily_departures,
		game._stored_resources,
		game._warehouse_capacity
	)


func _setup_building_lifecycle() -> void:
	game.building_lifecycle_service = SettlementGame.BuildingLifecycleServiceScript.new()
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
		SettlementGame.FireLightScene,
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
		game._cancel_arrivals_for_house,
		game._add_demolition_marker,
		game._refresh_living_status,
		game._unregister_service_pockets,
		game._return_in_transit_building_supplies,
		game._cancel_canteen_delivery,
		game._unregister_navigation_footprint,
		game._refresh_boundary_markers,
		game._select_best_canteen,
		game._create_resource_pile,
		game._refresh_navigation_grid,
		game._is_construction_site,
		game._activate_employment_centre,
		game._convert_backpack_pile_to_regular,
		game._add_building_selector,
		game._add_warehouse_fill_label,
		game._sawmill_stock,
		game._create_gathering_place_visual,
		game._activate_kitchen_if_better,
		game._add_house_light,
		game._house_initial_residents,
		game._cancel_active_building_research,
		game._dismiss_official,
		game._send_to_unemployment_registration
	)
	game.construction_priority_service = SettlementGame.ConstructionPriorityServiceScript.new()
	game.construction_priority_service.configure(
		game.construction_sites,
		game.warehouse_positions,
		game.sawmill_positions,
		game.campfire_node,
		game.canteen,
		func() -> int: return game.citizens.size(),
		game._total_housing_slots,
		func() -> int: return game.settlement.amount(SettlementGame.ResourceIds.FOOD)
	)


func _setup_excavation_and_factory() -> void:
	game.excavation_service = SettlementGame.ExcavationServiceScript.new()
	game.excavation_service.dig_site_scene = SettlementGame.DigSiteScene
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
		game._employment_center_position,
		game._show_territory_overlay,
		game._move_selection,
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
	game.citizen_registration_service = SettlementGame.CitizenRegistrationServiceScript.new()
	game.citizen_registration_service.configure(
		game.citizens,
		SettlementGame.OFFICER_POST_RADIUS,
		game._employment_centre_building,
		game._employment_center_position,
		game._is_work_time,
		game._update_workers,
		func() -> int:
			game._registration_queue_counter += 1
			return game._registration_queue_counter
	)
	game.school_service = SettlementGame.SchoolServiceScript.new()
	game.school_service.configure(game.school_positions, game.citizens)
	game.building_placement_service = SettlementGame.BuildingPlacementServiceScript.new()
	game.building_placement_service.configure(
		game.dig_sites,
		game.terrain_blocked_cells,
		game.building_registry,
		game.tree_positions,
		game._terrain_height_at,
		SettlementGame.MAX_BUILD_SLOPE
	)


func _setup_citizen_needs_and_orders() -> void:
	game.citizen_daily_order_service = SettlementGame.CitizenDailyOrderServiceScript.new()
	game.citizen_daily_order_service.configure(
		game.settlement,
		game.citizens,
		game.day_cycle,
		game.clock,
		game.building_registry,
		func() -> float: return game.runtime_seconds,
		game._is_work_time,
		game._is_citizen_work_time,
		game._absolute_game_minutes,
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
	game.citizen_living_status_service = SettlementGame.CitizenLivingStatusServiceScript.new()


func _setup_trade_and_logistics() -> void:
	game.trade_service = SettlementGame.TradeServiceScript.new()
	game.trade_service.configure(
		game.settlement,
		game.citizens,
		game.queued_trades,
		game.pending_trades,
		game.warehouse_positions,
		game.ui_manager.market_menu,
		func() -> Node3D: return game.selected_market,
		func() -> Node3D: return game.entrance_stone,
		game._get_delivery_position,
		game._update_interface,
		game._refresh_market_menu,
		game._request_courier_dispatch,
		game._total_game_minutes,
		game._citizen_for_ai_id,
		game._create_resource_pile,
		game._update_workers
	)
	game.storage_delivery_service = SettlementGame.StorageDeliveryServiceScript.new()
	game.storage_delivery_service.configure(
		game.settlement,
		game.warehouse_positions,
		game.courier_dispatcher,
		game.storage_routing_service,
		game._release_task_warehouse_reservation,
		game._drop_resource_pile,
		game._update_interface,
		game._request_courier_dispatch,
		game._send_citizen_to_leisure
	)
	game.storage_routing_service = SettlementGame.StorageRoutingServiceScript.new()
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
		game._can_work_at_dig_site,
		game._resource_for_depth,
		game._update_interface
	)


func _setup_courier_system() -> void:
	game.courier_dispatcher = SettlementGame.CourierDispatcherScript.new()
	game.courier_dispatcher.configure(
		game.citizens,
		game.warehouse_positions,
		game.storage_routing_service,
		func() -> float: return game.runtime_seconds,
		game._publish_courier_tasks,
		game._is_courier_task_valid,
		game._start_courier_task,
		game._cancel_courier_task,
		game._release_task_warehouse_reservation
	)
	game.courier_task_publisher = SettlementGame.CourierTaskPublisherScript.new()
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
		game._reconcile_construction_reservations,
		game._reconcile_repair_reservations,
		game._cell_from_position,
		game._get_nearest_delivery_position,
		game._warehouse_delivery_position,
		game._preferred_construction_site,
		game._construction_material_sources,
		game._construction_source_available,
		game._fire_state_for,
		game._firewood_task_priority
	)
	game.courier_task_service = SettlementGame.CourierTaskServiceScript.new()
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
		game._set_canteen_delivery_state,
		func() -> Node3D: return game.entrance_stone,
		func() -> float: return game.runtime_seconds,
		game._fire_state_for,
		game._apply_fire_state,
		game._is_route_reachable,
		game._preferred_construction_site,
		game._construction_source_available,
		game._citizen_for_ai_id
	)


func _setup_actuator_and_events() -> void:
	game.actuator_bridge = SettlementGame.SettlementActuatorBridgeScript.new()
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
		game._refresh_living_statuses,
		game._drop_resource_pile,
		game._fire_state_for,
		game._apply_fire_state
	)
	game.simulation_event_dispatcher = SettlementGame.SimulationEventDispatcherScript.new()
	game.simulation_event_dispatcher.configure({
		"start_meal": game._start_meal,
		"start_park_rest": game._start_park_rest,
		"end_ai_work_shift": game._end_ai_work_shift,
		"clear_finished_daily_orders": game._clear_finished_daily_orders,
		"refresh_living_statuses": game._refresh_living_statuses,
		"update_workers": game._update_workers,
		"apply_pending_workday_hours": game._apply_pending_workday_hours,
		"clear_expired_overtime_orders": game._clear_expired_overtime_orders,
		"reset_building_night_work_toggles": game._reset_building_night_work_toggles,
		"resume_overtime_daily_orders": game._resume_overtime_daily_orders,
		"update_interface": game._update_interface,
		"citizen_ai_refresh": func(): if game.citizen_ai != null: game.citizen_ai.request_decision_refresh(),
		"school_day_ended": game._on_school_day_ended,
		"daily_settlement_update": game._on_daily_settlement_update
	})


func _setup_ui_controllers() -> void:
	game.ui_attacher.create_all_controllers()
	game.ui_attacher.configure_all(game)
	game.warehouse_fill_label_controller = SettlementGame.WarehouseFillLabelControllerScript.new()
	game.warehouse_fill_label_controller.configure(game)
	game.building_status_indicator_controller = SettlementGame.BuildingStatusIndicatorControllerScript.new()
	game.building_status_indicator_controller.configure(game)
	game.first_person_hud_controller = SettlementGame.FirstPersonHUDControllerScript.new()
	game.first_person_hud_controller.configure(game)
	game.label_distance_fade_controller = SettlementGame.LabelDistanceFadeControllerScript.new()
	game.label_distance_fade_controller.configure(game)


func _setup_world_and_events() -> void:
	game.settlement.apply_launch_config(game.launch_config)
	var _event_registry := SettlementGame.EventRegistryScript.new()
	_event_registry.register_all(SettlementGame.TentEraEventsScript.build())
	game.event_service = SettlementGame.EventServiceScript.new(_event_registry)
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
	game.building_placement_controller = SettlementGame.BuildingPlacementControllerScript.new()
	game.add_child(game.building_placement_controller)
	game.building_placement_controller.setup(game)
	game.survival_event_controller = SettlementGame.SurvivalEventControllerScript.new()
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
	game._create_citizens()
	game._create_starter_backpack()
	game._refresh_living_statuses()
	if not game.citizen_ai.configure(
		SettlementAIWorldFacade.new(game),
		[SettlementGame.SleepGoalScript.new(), SettlementGame.MealGoalScript.new(), SettlementGame.ToiletGoalScript.new(), SettlementGame.RestGoalScript.new(), SettlementGame.ReturnHomeWhenIdleGoalScript.new(), SettlementGame.FollowLeaderGoalScript.new(), SettlementGame.RegisterGoalScript.new(), SettlementGame.ForestryGoalScript.new(), SettlementGame.FarmingGoalScript.new(), SettlementGame.ConstructionGoalScript.new(), SettlementGame.GatheringGoalScript.new(), SettlementGame.CleaningGoalScript.new(), SettlementGame.ExcavationGoalScript.new(), SettlementGame.ServiceWorkGoalScript.new(), SettlementGame.FactoryWorkGoalScript.new(), SettlementGame.CourierDeliveryGoalScript.new()],
		[SettlementGame.WorkforceOrderProviderScript.new(), SettlementGame.DailyPlayerOrderProviderScript.new(), SettlementGame.ForestryOrderProviderScript.new(), SettlementGame.FarmingOrderProviderScript.new(), SettlementGame.ConstructionOrderProviderScript.new(), SettlementGame.GatheringOrderProviderScript.new(), SettlementGame.ExcavationOrderProviderScript.new(), SettlementGame.ServiceWorkOrderProviderScript.new(), SettlementGame.FactoryWorkOrderProviderScript.new(), SettlementGame.CourierDeliveryOrderProviderScript.new()]
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
