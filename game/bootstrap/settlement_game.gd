class_name SettlementGame
extends Node3D

const SETTLEMENT_RULES = preload("res://game/features/settlement/domain/settlement_rules.gd")
const CitizenActorScene = preload("res://game/features/citizens/presentation/citizen_actor.tscn")
const UIManagerScene = preload("res://game/features/ui/presentation/ui_manager.tscn")
const CameraControllerScene = preload("res://game/features/world/presentation/camera_controller.tscn")
const FireLightScene = preload("res://game/features/buildings/presentation/fire_light.tscn")
const HouseLightScene = preload("res://game/features/buildings/presentation/house_light.tscn")
const BuildingSelectorScene = preload("res://game/features/buildings/presentation/building_selector.tscn")
const EntranceMarkerScene = preload("res://game/features/buildings/presentation/entrance_marker.tscn")
const ConstructionSiteScene = preload("res://game/features/buildings/presentation/construction_site.tscn")
const ConstructionEntrancePostScene = preload("res://game/features/buildings/presentation/construction_entrance_post.tscn")
const BillboardLabelScene = preload("res://game/features/ui/presentation/billboard_label.tscn")
const GatheringPlaceVisualScene = preload("res://game/features/buildings/presentation/gathering_place_visual.tscn")
const PocketTakeItemRowScene = preload("res://game/features/citizens/presentation/pocket_take_item_row.tscn")
const GameLaunchConfigScript = preload("res://game/features/settlement/domain/game_launch_config.gd")
const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")
const CampfireMenuControllerScript = preload("res://game/features/settlement/presentation/campfire_menu_controller.gd")
const WorkforceMenuControllerScript = preload("res://game/features/decision/presentation/workforce_menu_controller.gd")
const ResearchMenuControllerScript = preload("res://game/features/settlement/presentation/research_menu_controller.gd")
const SchoolMenuControllerScript = preload("res://game/features/buildings/presentation/school_menu_controller.gd")
const EntranceMenuControllerScript = preload("res://game/features/buildings/presentation/entrance_menu_controller.gd")
const HouseMenuControllerScript = preload("res://game/features/buildings/presentation/house_menu_controller.gd")
const PocketTakeMenuControllerScript = preload("res://game/features/citizens/presentation/pocket_take_menu_controller.gd")
const FireSourceStateScript = preload("res://game/features/settlement/domain/fire_source_state.gd")
const CourierDispatcherScript = preload("res://game/features/logistics/application/courier_dispatcher.gd")
const CourierTaskServiceScript = preload("res://game/features/logistics/application/courier_task_service.gd")
const CourierTaskPublisherScript = preload("res://game/features/logistics/application/courier_task_publisher.gd")
const CourierTaskScript = preload("res://game/features/logistics/domain/courier_task.gd")
const WaterCollectorRecordScript = preload("res://game/features/logistics/domain/water_collector_record.gd")
const DigSiteRecordScript = preload("res://game/features/production/domain/dig_site_record.gd")
const GrassSourceRecordScript = preload("res://game/features/production/domain/grass_source_record.gd")
const ForageSourceRecordScript = preload("res://game/features/production/domain/forage_source_record.gd")
const RabbitSourceRecordScript = preload("res://game/features/production/domain/rabbit_source_record.gd")
const HouseLightRecordScript = preload("res://game/features/buildings/domain/house_light_record.gd")
const TradeServiceScript = preload("res://game/features/logistics/application/trade_service.gd")
const MarketMenuControllerScript = preload("res://game/features/logistics/presentation/market_menu_controller.gd")
const WarehouseMenuControllerScript = preload("res://game/features/logistics/presentation/warehouse_menu_controller.gd")
const WarehouseFillLabelControllerScript = preload("res://game/features/logistics/presentation/warehouse_fill_label_controller.gd")
const StorageDeliveryServiceScript = preload("res://game/features/logistics/application/storage_delivery_service.gd")
const StorageRoutingServiceScript = preload("res://game/features/logistics/application/storage_routing_service.gd")
const BuildingAvailabilityServiceScript = preload("res://game/features/buildings/application/building_availability_service.gd")
const BuildingMenuControllerScript = preload("res://game/features/buildings/presentation/building_menu_controller.gd")
const BuildingPlacementControllerScript = preload("res://game/features/buildings/presentation/building_placement_controller.gd")
const BuildingStatusIndicatorControllerScript = preload("res://game/features/buildings/presentation/building_status_indicator_controller.gd")
const FirstPersonHUDControllerScript = preload("res://game/features/ui/presentation/first_person_hud_controller.gd")
const LabelDistanceFadeControllerScript = preload("res://game/features/ui/presentation/label_distance_fade_controller.gd")
const ResourcePileVisualsScript = preload("res://game/features/logistics/presentation/resource_pile_visuals.gd")
const BuildingLifecycleServiceScript = preload("res://game/features/buildings/application/building_lifecycle_service.gd")
const BuildingZoneServiceScript = preload("res://game/features/buildings/application/building_zone_service.gd")
const ConstructionPriorityServiceScript = preload("res://game/features/buildings/application/construction_priority_service.gd")
const BuildingRuntimeStateScript = preload("res://game/features/buildings/application/building_runtime_state.gd")
const BuildingEntrancePositionsScript = preload("res://game/features/buildings/domain/building_entrance_positions.gd")
const BuildingBlueprintLibraryScript = preload("res://game/features/buildings/presentation/building_blueprint_library.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")
const BuildingResearchServiceScript = preload("res://game/features/buildings/application/building_research_service.gd")
const BuildingQueueServiceScript = preload("res://game/features/citizens/application/building_queue_service.gd")
const CitizenLifecycleServiceScript = preload("res://game/features/citizens/application/citizen_lifecycle_service.gd")
const CitizenLivingStatusServiceScript = preload("res://game/features/citizens/application/citizen_living_status_service.gd")
const CitizenStatusEffectScript = preload("res://game/features/citizens/domain/citizen_status_effect.gd")
const CitizenRegistrationServiceScript = preload("res://game/features/citizens/application/citizen_registration_service.gd")
const SchoolServiceScript = preload("res://game/features/buildings/application/school_service.gd")
const SaveDataScript = preload("res://game/features/save_load/domain/save_data.gd")
const SaveGameServiceScript = preload("res://game/features/save_load/application/save_game_service.gd")

const BuildingPlacementServiceScript = preload("res://game/features/buildings/application/building_placement_service.gd")
const BuildingVisualsServiceScript = preload("res://game/features/buildings/presentation/building_visuals_service.gd")
const CitizenDailyOrderServiceScript = preload("res://game/features/citizens/application/citizen_daily_order_service.gd")
const HeroPocketServiceScript = preload("res://game/features/citizens/application/hero_pocket_service.gd")
const HeroInteractionServiceScript = preload("res://game/features/citizens/application/hero_interaction_service.gd")
const WorkplaceLaborServiceScript = preload("res://game/features/settlement/application/workplace_labor_service.gd")
const SleepGoalScript = preload("res://game/features/decision/domain/goals/sleep_goal.gd")
const ReturnHomeWhenIdleGoalScript = preload("res://game/features/decision/domain/goals/return_home_when_idle_goal.gd")
const FollowLeaderGoalScript = preload("res://game/features/decision/domain/goals/follow_leader_goal.gd")
const MealGoalScript = preload("res://game/features/decision/domain/goals/meal_goal.gd")
const ToiletGoalScript = preload("res://game/features/decision/domain/goals/toilet_goal.gd")
const RestGoalScript = preload("res://game/features/decision/domain/goals/rest_goal.gd")
const ForestryGoalScript = preload("res://game/features/decision/domain/goals/forestry_goal.gd")
const ForestryOrderProviderScript = preload("res://game/features/decision/application/forestry_order_provider.gd")
const FarmingGoalScript = preload("res://game/features/decision/domain/goals/farming_goal.gd")
const FarmingOrderProviderScript = preload("res://game/features/decision/application/farming_order_provider.gd")
const ConstructionGoalScript = preload("res://game/features/decision/domain/goals/construction_goal.gd")
const ConstructionOrderProviderScript = preload("res://game/features/decision/application/construction_order_provider.gd")
const GatheringGoalScript = preload("res://game/features/decision/domain/goals/gathering_goal.gd")
const GatheringOrderProviderScript = preload("res://game/features/decision/application/gathering_order_provider.gd")
const ExcavationGoalScript = preload("res://game/features/decision/domain/goals/excavation_goal.gd")
const ExcavationOrderProviderScript = preload("res://game/features/decision/application/excavation_order_provider.gd")
const ServiceWorkGoalScript = preload("res://game/features/decision/domain/goals/service_work_goal.gd")
const ServiceWorkOrderProviderScript = preload("res://game/features/decision/application/service_work_order_provider.gd")
const FactoryWorkGoalScript = preload("res://game/features/decision/domain/goals/factory_work_goal.gd")
const FactoryWorkOrderProviderScript = preload("res://game/features/decision/application/factory_work_order_provider.gd")
const CourierDeliveryGoalScript = preload("res://game/features/decision/domain/goals/courier_delivery_goal.gd")
const CourierDeliveryOrderProviderScript = preload("res://game/features/decision/application/courier_delivery_order_provider.gd")
const SettlementCitizenActuatorScript = preload("res://game/features/decision/presentation/settlement_citizen_actuator.gd")
const SettlementActuatorBridgeScript = preload("res://game/features/decision/presentation/settlement_actuator_bridge.gd")
const RegisterGoalScript = preload("res://game/features/decision/domain/goals/register_goal.gd")
const WorkforceOrderProviderScript = preload("res://game/features/decision/application/workforce_order_provider.gd")
const DailyPlayerOrderProviderScript = preload("res://game/features/decision/application/daily_player_order_provider.gd")
const CleaningGoalScript = preload("res://game/features/decision/domain/goals/cleaning_goal.gd")
const TrailFieldServiceScript = preload("res://game/features/routing/application/trail_field_service.gd")
const TrailTextureRendererScript = preload("res://game/features/routing/presentation/trail_texture_renderer.gd")
const RoadNetworkServiceScript = preload("res://game/features/routing/application/road_network_service.gd")
const NavigationObstaclePublisherScript = preload("res://game/features/routing/application/navigation_obstacle_publisher.gd")
const NavigationFacadeScript = preload("res://game/features/routing/application/navigation_facade.gd")
const NavigationBridgeScript = preload("res://game/features/routing/presentation/navigation_bridge.gd")
const WeatherStateScript = preload("res://game/features/simulation/domain/weather_state.gd")
const CameraControllerScript = preload("res://game/features/world/presentation/camera_controller.gd")
const WorldSetupScene = preload("res://game/features/world/presentation/world_setup.tscn")
const EventServiceScript = preload("res://game/features/events/application/event_service.gd")
const EventRegistryScript = preload("res://game/features/events/domain/event_registry.gd")
const EventLogScript = preload("res://game/features/events/domain/event_log.gd")
const EventContextScript = preload("res://game/features/events/domain/event_context.gd")
const EventOutcomeScript = preload("res://game/features/events/domain/event_outcome.gd")
const TentEraEventsScript = preload("res://game/features/events/application/tent_era_events.gd")
const SurvivalEventControllerScript = preload("res://game/features/events/presentation/survival_event_controller.gd")
const VillageTerritoryServiceScript = preload("res://game/features/buildings/application/village_territory_service.gd")
const DigSiteScene = preload("res://game/features/world/presentation/dig_site.tscn")
const ExcavationServiceScript = preload("res://game/features/production/application/excavation_service.gd")
const FactoryServiceScript = preload("res://game/features/production/application/factory_service.gd")
const SettlementSurvivalServiceScript = preload("res://game/features/settlement/application/settlement_survival_service.gd")
const SettlementDailyRulesServiceScript = preload("res://game/features/settlement/application/settlement_daily_rules_service.gd")
const TerritoryServiceScript = preload("res://game/features/world/application/territory_service.gd")
const ResourcePileScript = preload("res://game/features/logistics/domain/resource_pile.gd")
const WarehouseStateScript = preload("res://game/features/settlement/domain/warehouse_state.gd")
const WorldResourceStateScript = preload("res://game/features/world/domain/world_resource_state.gd")
const S = preload("res://game/features/ui/domain/game_strings.gd")
const BuildingSpatialRegistryScript = preload("res://game/features/buildings/application/building_spatial_registry.gd")
const SimulationEventDispatcherScript = preload("res://game/features/simulation/application/simulation_event_dispatcher.gd")
const SettlementUIAttacherScript = preload("res://game/features/ui/presentation/settlement_ui_attacher.gd")
const SettlementBootstrapperScript = preload("res://game/bootstrap/settlement_bootstrapper.gd")
const SettlementSaveLoaderScript = preload("res://game/bootstrap/settlement_save_loader.gd")
const SettlementUICallbacksScript = preload("res://game/bootstrap/settlement_ui_callbacks.gd")
const SettlementResearchControllerScript = preload("res://game/bootstrap/settlement_research_controller.gd")
const SettlementCitizenFactoryScript = preload("res://game/bootstrap/settlement_citizen_factory.gd")
const SettlementBuildingVisualsScript = preload("res://game/bootstrap/settlement_building_visuals.gd")
const SettlementSimulationHandlersScript = preload("res://game/bootstrap/settlement_simulation_handlers.gd")
const SettlementServicePocketManagerScript = preload("res://game/bootstrap/settlement_service_pocket_manager.gd")
const SettlementOutsideWorkControllerScript = preload("res://game/bootstrap/settlement_outside_work_controller.gd")
const SettlementBuildingManagementScript = preload("res://game/bootstrap/settlement_building_management.gd")
const SettlementBuildStateScript = preload("res://game/bootstrap/settlement_build_state.gd")
const SettlementHeroStateScript = preload("res://game/bootstrap/settlement_hero_state.gd")
const SettlementCameraStateScript = preload("res://game/bootstrap/settlement_camera_state.gd")
const SettlementWorldStateScript = preload("res://game/bootstrap/settlement_world_state.gd")
const SettlementInputControllerScript = preload("res://game/bootstrap/settlement_input_controller.gd")
const SettlementBuildControllerScript = preload("res://game/bootstrap/settlement_build_controller.gd")
const SettlementHeroInteractionControllerScript = preload("res://game/bootstrap/settlement_hero_interaction_controller.gd")
const SettlementConstructionControllerScript = preload("res://game/bootstrap/settlement_construction_controller.gd")
const SettlementWorkplaceControllerScript = preload("res://game/bootstrap/settlement_workplace_controller.gd")
const SettlementSimulationTickControllerScript = preload("res://game/bootstrap/settlement_simulation_tick_controller.gd")
const SettlementLogisticsControllerScript = preload("res://game/bootstrap/settlement_logistics_controller.gd")
const SettlementWorldNavigationControllerScript = preload("res://game/bootstrap/settlement_world_navigation_controller.gd")



# The playable routing and construction board must cover the terrain visible
# beyond the starter forest. The former 48-cell board ended just behind the
# trees, while the rendered ground continued much farther out.
const BOARD_CELLS := 96
const CELL_SIZE := BuildingBlueprints.BLOCK_SIZE
const BUILDING_CLEARANCE_BLOCKS := 3.0
const TREE_BUILD_CLEARANCE_BLOCKS := 1.0
const NAVIGATION_CLEARANCE_MARGIN := 1.0
const SERVICE_PAD_OFFSET := 1.0
const MAX_BUILD_SLOPE := 0.35
const POPULATION := 4
const WAREHOUSE_CAPACITY := 50
const FOOD_PURCHASE_PRICE := 2
const ENTRANCE_GLOVE_PRICE := 20
const ENTRANCE_BUCKET_PRICE := 15
const ENTRANCE_WATER_PRICE := 2
const OUTSIDE_WORK_DURATION_MINUTES := SimulationClock.MINUTES_PER_DAY
const OUTSIDE_WORK_BASE_REWARD_MIN := 4
const OUTSIDE_WORK_BASE_REWARD_MAX := 12
const OUTSIDE_WORK_UPGRADE_REWARD := 16
const HOUSE_CAPACITY := 4
const TENT_CAPACITY := 4
const CONSTRUCTION_DURATION := 4.0
const DEMOLITION_DURATION := 3.0
const INTERACTION_RANGE := 4.5
const JOB_ENTRANCE_RANGE := 3.5
const POCKET_CAPACITY := 8
const POCKET_WOOD_CAPACITY := POCKET_CAPACITY
const SAWMILL_PROCESS_DURATION := 4.0
const SAWMILL_WORKER_DELIVERY_THRESHOLD := 4
const COURIER_LATE_SECONDS := 12.0
const DIG_RADIUS := 2.2
const DIG_REACH := 6.0

var settlement := SettlementState.new()
var world_resource_state := WorldResourceStateScript.new()
var launch_config: GameLaunchConfigScript
var day_cycle := SimulationDayCycle.new()
var clock: SimulationClock = day_cycle.clock
var game_minutes: float:
	get: return clock.minutes
	set(value): clock.minutes = value
const GAME_DAY_REAL_SECONDS := 300.0
const GAME_MINUTES_PER_SECOND := 1440.0 / GAME_DAY_REAL_SECONDS
var time_multiplier := 1.0
# The scheduler used to run only on discrete events, so a citizen who fell idle
# between events could stand doing nothing indefinitely. Poll it steadily during
# work hours so idle workers are promptly re-assigned or sent to wait/rest.
const WORKER_POLL_INTERVAL := 0.5
# The main campfire progression (town hall) doubles as the employment centre:
# the employment officer must man it to register residents. The civic centre
# is always the main campfire or its town-hall upgrade.
const OFFICIAL_WORKPLACE_TYPES: Array[String] = BuildingTypes.CIVIC_TYPES
# How close the officer must stand to their post to count as manning it.
const OFFICER_POST_RADIUS := 3.5
# Maximum branches a fire source holds before couriers stop delivering.
const FIRE_SUPPLY_TARGET := 4
var _worker_poll_timer := 0.0
var _registration_queue_counter := 0
var _last_unstaffed_warning_time := -1000.0
var runtime_seconds := 0.0
var random := RandomNumberGenerator.new()
var build_state := SettlementBuildStateScript.new()
var selected_cell: Vector2i:
	get: return build_state.selected_cell
	set(v): build_state.selected_cell = v
var selected_world_position: Vector3:
	get: return build_state.selected_world_position
	set(v): build_state.selected_world_position = v
var build_mode: String:
	get: return build_state.build_mode
	set(v): build_state.build_mode = v
var build_rotation_quarters: int:
	get: return build_state.build_rotation_quarters
	set(v): build_state.build_rotation_quarters = v
var building_registry := BuildingRegistry.new()
var world_state := SettlementWorldStateScript.new()
var tree_cells: Dictionary[Vector2i, bool]:
	get: return world_state.tree_cells
var terrain_blocked_cells: Dictionary[Vector2i, bool]:
	get: return world_state.terrain_blocked_cells
	set(v): world_state.terrain_blocked_cells = v
var navigation_blocked_cells: Dictionary[Vector2i, bool]:
	get: return world_state.navigation_blocked_cells
	set(v): world_state.navigation_blocked_cells = v
var building_spatial_registry := BuildingSpatialRegistryScript.new()
# Keep this preload-backed dependency explicit.  Scene-test execution does not
# populate Godot's editor-only global class cache before parsing this script.
var simulation_event_dispatcher: RefCounted
var ui_attacher := SettlementUIAttacherScript.new()

var warehouse_positions: Array[Vector3]:
	get: return building_spatial_registry.warehouse_positions
var sawmill_positions: Array[Vector3]:
	get: return building_spatial_registry.sawmill_positions
var farm_positions: Array[Vector3]:
	get: return building_spatial_registry.farm_positions
var builders_guild_positions: Array[Vector3]:
	get: return building_spatial_registry.builders_guild_positions
var construction_company_positions: Array[Vector3]:
	get: return building_spatial_registry.construction_company_positions
var pond_positions: Array[Vector3]:
	get: return building_spatial_registry.pond_positions
var forager_positions: Array[Vector3]:
	get: return building_spatial_registry.forager_positions
var materials_yard_positions: Array[Vector3]:
	get: return building_spatial_registry.materials_yard_positions
var school_positions: Array[Vector3]:
	get: return building_spatial_registry.school_positions
var market_positions: Array[Vector3]:
	get: return building_spatial_registry.market_positions
var craft_tent_positions: Array[Vector3]:
	get: return building_spatial_registry.craft_tent_positions
var park_positions: Array[Vector3]:
	get: return building_spatial_registry.park_positions
var leisure_positions: Array[Vector3]:
	get: return building_spatial_registry.leisure_positions
var gathering_place_positions: Array[Vector3]:
	get: return building_spatial_registry.gathering_place_positions
var factories: Array[Node3D]:
	get: return building_spatial_registry.factories

var sawmill_stocks: Dictionary = {}
var grass_sources: Dictionary:
	get: return foraging_service.grass_sources if foraging_service != null else {}
var forage_sources: Dictionary:
	get: return foraging_service.forage_sources if foraging_service != null else {}
var forage_respawn_at: Dictionary:
	get: return foraging_service.forage_respawn_at if foraging_service != null else {}
var rabbit_sources: Dictionary:
	get: return foraging_service.rabbit_sources if foraging_service != null else {}
var rabbit_respawn_at: Dictionary:
	get: return foraging_service.rabbit_respawn_at if foraging_service != null else {}
const WILD_FOOD_RESPAWN_SECONDS := 45.0
const RABBIT_RESPAWN_SECONDS := 60.0
const RABBIT_MAX_COUNT := 8
var outside_workers: Dictionary:
	get: return world_state.outside_workers
var last_citizen_positions: Dictionary:
	get: return world_state.last_citizen_positions
var resource_piles: Array[ResourcePileScript]:
	get: return world_state.resource_piles
var backpack_node: Node3D:
	get: return world_state.backpack_node
	set(v): world_state.backpack_node = v
var backpack_position: Vector3:
	get: return world_state.backpack_position
	set(v): world_state.backpack_position = v

var tree_positions: Array[Vector3]:
	get: return world_state.tree_positions
var tree_nodes: Dictionary[Vector2i, Node3D]:
	get: return world_state.tree_nodes
var gather_progress_labels: Dictionary:
	get: return world_state.gather_progress_labels
var citizens: Array[Citizen] = []
var camera: Camera3D:
	get: return camera_controller.camera if camera_controller != null else null
var camera_controller: CameraController
var world_setup: Node
var selection_marker: MeshInstance3D:
	get: return world_setup.selection_marker if world_setup != null else null
var fireflies: Array[FirefliesEffect]:
	get: return world_setup.fireflies if world_setup != null else []
var weather_state := WeatherStateScript.new()
var ambient_spawner: AmbientSpawner
var camera_target: Vector3:
	get: return camera_controller.camera_target if camera_controller != null else Vector3.ZERO
	set(val): if camera_controller != null: camera_controller.camera_target = val
var camera_distance: float:
	get: return camera_controller.camera_distance if camera_controller != null else 30.0
	set(val): if camera_controller != null: camera_controller.camera_distance = val
var camera_yaw: float:
	get: return camera_controller.camera_yaw if camera_controller != null else 42.0
	set(val): if camera_controller != null: camera_controller.camera_yaw = val
var camera_pitch: float:
	get: return camera_controller.camera_pitch if camera_controller != null else 52.0
	set(val): if camera_controller != null: camera_controller.camera_pitch = val
var current_day: int:
	get: return day_cycle.current_day
var tent_weather: int = TentEraSurvivalRulesScript.Weather.WARMING
var selected_builder: Citizen:
	get: return build_state.selected_builder
	set(v): build_state.selected_builder = v
var selected_building: Node3D:
	get: return build_state.selected_building
	set(v): build_state.selected_building = v
var camera_state := SettlementCameraStateScript.new()
var is_panning_camera: bool:
	get: return camera_state.is_panning_camera
	set(v): camera_state.is_panning_camera = v
var is_rotating_camera: bool:
	get: return camera_state.is_rotating_camera
	set(v): camera_state.is_rotating_camera = v
var right_mouse_dragged: bool:
	get: return camera_state.right_mouse_dragged
	set(v): camera_state.right_mouse_dragged = v
var construction_sites: Array[ConstructionSite]:
	get: return construction.sites if construction != null else []
var demolition_sites: Array[DemolitionSite]:
	get: return demolition.sites if demolition != null else []
var completed_house_count := 0
var player_controller: PlayerController
var hero_state := SettlementHeroStateScript.new()
var hero_citizen: Citizen:
	get: return hero_state.hero_citizen
	set(v): hero_state.hero_citizen = v

var is_first_person: bool:
	get: return player_controller.is_first_person if player_controller != null else false
	set(val):
		if player_controller != null: player_controller.is_first_person = val
var player_citizen: Citizen:
	get: return player_controller.player_citizen if player_controller != null else null
	set(val):
		if player_controller != null: player_controller.player_citizen = val
var player_yaw: float:
	get: return player_controller.player_yaw if player_controller != null else 0.0
	set(val):
		if player_controller != null: player_controller.player_yaw = val
var player_pitch: float:
	get: return player_controller.player_pitch if player_controller != null else 0.0
	set(val):
		if player_controller != null: player_controller.player_pitch = val
var interaction_action: String:
	get: return player_controller.interaction_action if player_controller != null else ""
	set(val):
		if player_controller != null: player_controller.interaction_action = val
var interaction_resource: String:
	get: return player_controller.interaction_resource if player_controller != null else ""
	set(val):
		if player_controller != null: player_controller.interaction_resource = val
var interaction_time: float:
	get: return player_controller.interaction_time if player_controller != null else 0.0
	set(val):
		if player_controller != null: player_controller.interaction_time = val
var interaction_start_cell: Vector2i:
	get: return player_controller.interaction_start_cell if player_controller != null else Vector2i(-9999, -9999)
	set(val):
		if player_controller != null: player_controller.interaction_start_cell = val
var interaction_repeat_all: bool:
	get: return player_controller.interaction_repeat_all if player_controller != null else false
	set(val):
		if player_controller != null: player_controller.interaction_repeat_all = val
var player_work_target: Node3D:
	get: return player_controller.player_work_target if player_controller != null else null
	set(val):
		if player_controller != null: player_controller.player_work_target = val
var _player_toilet_notified: bool:
	get: return player_controller.player_toilet_notified if player_controller != null else false
	set(val):
		if player_controller != null: player_controller.player_toilet_notified = val
var pocket: Dictionary:
	get: return hero_pocket_service.pocket if hero_pocket_service != null else {}
	set(val): if hero_pocket_service != null: hero_pocket_service.pocket = val
var ui_manager: UIManager

var pocket_menu_open: bool:
	get: return hero_state.pocket_menu_open
	set(v): hero_state.pocket_menu_open = v
var pocket_take_warehouse_index: int:
	get: return hero_state.pocket_take_warehouse_index
	set(v): hero_state.pocket_take_warehouse_index = v
var dig_sites: Array:
	get: return world_state.dig_sites
var dig_cells: Dictionary:
	get: return world_state.dig_cells
var exhausted_dig_cells: Dictionary:
	get: return world_state.exhausted_dig_cells
var dig_mode: bool:
	get: return build_state.dig_mode
	set(v): build_state.dig_mode = v
var excavation_service: ExcavationServiceScript
var factory_service: FactoryServiceScript
var selected_house: Node3D
var tent: Node3D
var entrance_stone: Node3D
var selected_entrance: Node3D
var pending_arrivals: Array[Dictionary] = []
var arrival_greeters: Dictionary = {}
var arrival_waiting_greeters: Dictionary = {}
var arrival_escort_ids: Dictionary = {}
var tent_cell := Vector2i(0, 0)
var canteen: Node3D
var canteen_position := Vector3.ZERO
var employment_office: Node3D
var employment_office_position := Vector3.ZERO
var canteen_food := 0
var pending_canteen_delivery := false
var pending_canteen_carrier: Citizen
var pending_canteen_delivery_amount := 0
var tent_dismantle_progress := -1.0
var nav_grid: NavGrid
var road_network_service: RefCounted
var navigation_obstacle_publisher: RefCounted
var service_pockets: Array[Dictionary] = []
var selected_school: Node3D
var school_developed_professions: Dictionary:
	get: return school_service.developed_professions if school_service != null else {}
var selected_materials_factory: Node3D
var campfire_node: Node3D = null
var selected_campfire: Node3D = null
var selected_market: Node3D = null
var selected_warehouse: Node3D = null
var campfire_story_buttons: Array[Button] = []
var _decision_buttons: Array[Button] = []
var event_service: EventService
var survival_busy_until: Dictionary = {}
var house_lights: Array[HouseLightRecordScript] = []
var house_light_update_minute := -1
var entrance_lights: Array[OmniLight3D] = []
var build_category: String:
	get: return build_state.build_category
	set(v): build_state.build_category = v
var build_menu_is_job_menu: bool:
	get: return build_state.build_menu_is_job_menu
	set(v): build_state.build_menu_is_job_menu = v
var build_menu_is_daily_order_menu: bool:
	get: return build_state.build_menu_is_daily_order_menu
	set(v): build_state.build_menu_is_daily_order_menu = v
var build_menu_is_global: bool:
	get: return build_state.build_menu_is_global
	set(v): build_state.build_menu_is_global = v
var skip_night_button: Button:
	get: return ui_manager.time_controls_panel.skip_night_button if ui_manager.time_controls_panel != null else null
var start_workday_button: Button:
	get: return ui_manager.time_controls_panel.start_workday_button if ui_manager.time_controls_panel != null else null
var water_collectors: Array[WaterCollectorRecordScript] = []
var pending_trades: Dictionary = {} # worker ai_id -> TradeOrder
var queued_trades: Array = []
var building_status_indicators: Array[Label3D] = []
var building_status_update_time := 0.0
var workplace_priority_counter := 0
var citizen_ai: CitizenAISystem
var citizen_needs_service: CitizenNeedsService
var citizen_living_status_service: CitizenLivingStatusService
## Monotonic source of stable citizen AI identity. Persist it alongside the roster
## once save/load is introduced so reloaded games issue non-colliding ids.
var _next_ai_citizen_id := 1
var route_service: GridRouteService
var navigation_facade: RefCounted
var navigation_bridge: NavigationBridge
var building_queue_service: BuildingQueueService
var citizen_lifecycle_service: CitizenLifecycleService
var building_availability_service: BuildingAvailabilityService
var building_research_service: BuildingResearchService
var village_territory_service: VillageTerritoryService
var sawmills: SawmillService
var construction: ConstructionService
var demolition: DemolitionService
var water_collector_service: WaterCollectorService
var canteen_service: CanteenService
var trade_service: TradeService
var storage_delivery_service: StorageDeliveryService
var storage_routing_service: StorageRoutingService
var courier_dispatcher: CourierDispatcher
var courier_task_publisher: CourierTaskPublisher
var courier_task_service: CourierTaskService
var campfire_menu_controller: RefCounted:
	get: return ui_attacher.campfire_menu_controller
var workforce_menu_controller: RefCounted:
	get: return ui_attacher.workforce_menu_controller
var research_menu_controller: RefCounted:
	get: return ui_attacher.research_menu_controller
var school_menu_controller: RefCounted:
	get: return ui_attacher.school_menu_controller
var entrance_menu_controller: RefCounted:
	get: return ui_attacher.entrance_menu_controller
var house_menu_controller: RefCounted:
	get: return ui_attacher.house_menu_controller
var pocket_take_menu_controller: RefCounted:
	get: return ui_attacher.pocket_take_menu_controller
var market_menu_controller: RefCounted:
	get: return ui_attacher.market_menu_controller
var warehouse_menu_controller: RefCounted:
	get: return ui_attacher.warehouse_menu_controller
var warehouse_fill_label_controller: WarehouseFillLabelController
var building_menu_controller: RefCounted:
	get: return ui_attacher.building_menu_controller
var building_placement_controller: BuildingPlacementController

var building_status_indicator_controller: BuildingStatusIndicatorController
var first_person_hud_controller: FirstPersonHUDController
var label_distance_fade_controller: LabelDistanceFadeController
var trail_field: TrailFieldService
var trail_texture_renderer: TrailTextureRenderer
var resource_pile_service: ResourcePileService
var foraging_service: ForagingService
var fire_management_service: FireManagementService
var fixture_service: FixtureService
var building_maintenance_service: BuildingMaintenanceService
var building_lifecycle_service: BuildingLifecycleService
var building_zone_service: RefCounted
var construction_priority_service: ConstructionPriorityServiceScript
var settlement_survival_service: SettlementSurvivalService
var settlement_daily_rules_service: SettlementDailyRulesService
var territory_service: TerritoryService
var citizen_registration_service: CitizenRegistrationService
var school_service: SchoolService
var building_placement_service: BuildingPlacementService
var citizen_daily_order_service: CitizenDailyOrderService
var hero_pocket_service: HeroPocketService
var hero_interaction_service: HeroInteractionService
var workplace_labor_service: WorkplaceLaborService
var building_visuals_service: BuildingVisualsService
var actuator_bridge: RefCounted
var survival_event_controller: SurvivalEventController
var _research_controller: RefCounted
var _citizen_factory: RefCounted
var _building_visuals: RefCounted
var _simulation_handlers: RefCounted
var _service_pocket_manager: RefCounted
var _outside_work_controller: RefCounted
var _building_management: RefCounted
var _input_controller: RefCounted
var _build_controller: RefCounted
var _hero_interaction_controller: RefCounted
var _construction_controller: RefCounted
var _workplace_controller: RefCounted
var _simulation_tick_controller: RefCounted
var _logistics_controller: RefCounted
var _world_navigation_controller: RefCounted


func _ready() -> void:
	ui_manager = UIManagerScene.instantiate() as UIManager
	add_child(ui_manager)
	ui_manager.setup(self)
	var launch_mgr: Node = get_node_or_null("/root/GameLaunchManager")
	var active_config: GameLaunchConfigScript = null
	if launch_mgr != null:
		active_config = launch_mgr.get("active_launch_config") as GameLaunchConfigScript
	if active_config == null:
		active_config = GameLaunchConfigScript.for_tent_era()
	launch_config = active_config

	_research_controller = SettlementResearchControllerScript.new(self)
	_citizen_factory = SettlementCitizenFactoryScript.new(self)
	_building_visuals = SettlementBuildingVisualsScript.new(self)
	_simulation_handlers = SettlementSimulationHandlersScript.new(self)
	_service_pocket_manager = SettlementServicePocketManagerScript.new(self)
	_outside_work_controller = SettlementOutsideWorkControllerScript.new(self)
	_building_management = SettlementBuildingManagementScript.new(self)
	_input_controller = SettlementInputControllerScript.new(self)
	_build_controller = SettlementBuildControllerScript.new(self)
	_hero_interaction_controller = SettlementHeroInteractionControllerScript.new(self)
	_construction_controller = SettlementConstructionControllerScript.new(self)
	_workplace_controller = SettlementWorkplaceControllerScript.new(self)
	_simulation_tick_controller = SettlementSimulationTickControllerScript.new(self)
	_logistics_controller = SettlementLogisticsControllerScript.new(self)
	_world_navigation_controller = SettlementWorldNavigationControllerScript.new(self)
	ui_manager.bind_delegate_events(SettlementUICallbacksScript.new(self))
	SettlementBootstrapperScript.new().run(self)


func _next_registration_ticket() -> int:
	return citizen_registration_service.next_registration_ticket() if citizen_registration_service != null else 0


func _settle_unhoused_resident() -> void:
	citizen_lifecycle_service.settle_unhoused_resident()


func _process(delta: float) -> void:
	runtime_seconds += delta
	if foraging_service != null:
		foraging_service.runtime_seconds = runtime_seconds
	if citizen_needs_service != null:
		citizen_needs_service.tick(game_minutes)
		_check_player_toilet_request()
	if is_first_person:
		player_controller.update_player_control(delta)
		player_controller.update_interaction(delta)
		_refresh_interaction_hint()
		_update_first_person_mouse_and_crosshair()
		if warehouse_fill_label_controller != null:
			warehouse_fill_label_controller.update_warehouse_fill_labels()
		if not build_mode.is_empty():
			var viewport_center := get_viewport().get_visible_rect().size * 0.5
			var terrain_point: Variant = _terrain_point_at_screen_position(viewport_center)
			if terrain_point != null:
				_move_selection(terrain_point)
				world_setup.selection_marker.visible = true
			else:
				world_setup.selection_marker.visible = false
				world_setup.preview_entrance_marker.visible = false
				world_setup.preview_back_entrance_marker.visible = false
	else:
		if camera_controller != null:
			camera_controller.update(delta)
	_update_construction(delta)
	demolition.tick(delta)
	water_collector_service.tick(delta)
	_update_clock(delta)
	_release_unassigned_overtime_workers()
	if survival_event_controller != null:
		survival_event_controller.update_survival_busy_workers()
	_return_outside_workers()
	if ambient_spawner != null:
		ambient_spawner.update_wild_food(delta)
	_guard_citizen_positions()
	_update_trail_overlay()
	_update_daylight()
	if building_lifecycle_service != null:
		building_lifecycle_service.update_house_lights()
	canteen_service.update_canteen_delivery()
	citizen_lifecycle_service.update_arrivals()
	fire_management_service.update_fire_status(self, settlement.amount(ResourceIds.BRANCHES))
	if trade_service != null:
		trade_service.update()

	# Queued trades are delivered as courier tasks; a dispatch pass picks them up.
	_request_courier_dispatch()
	sawmills.tick(delta, runtime_seconds)
	_update_building_research(delta)
	if building_status_indicator_controller != null:
		building_status_indicator_controller.update_building_status_indicators(delta)
	foraging_service.update_gathering_indicators(is_first_person, interaction_action, interaction_resource, interaction_time, player_citizen, citizens)
	if label_distance_fade_controller != null:
		label_distance_fade_controller.update_label_distance_fading()
	backpack_node = resource_pile_service.sync_backpack_pile(backpack_node)
	if _is_work_time() or _has_active_night_work_order():
		if courier_dispatcher != null:
			courier_dispatcher.dispatch()
		_worker_poll_timer -= delta
		if _worker_poll_timer <= 0.0:
			_worker_poll_timer = WORKER_POLL_INTERVAL
			_update_workers()
	if selected_builder != null and ui_manager.build_menu.visible:
		_show_selected_citizen_menu()


func _update_workers() -> void:
	if building_zone_service != null:
		building_zone_service.reconcile_assignments(citizens, building_registry.records())
	_check_unstaffed_employment_center()


func daily_order_workday_for_new_order() -> int:
	return citizen_daily_order_service.daily_order_workday_for_new_order() if citizen_daily_order_service != null else day_cycle.current_day


func _guard_citizen_positions() -> void:
	_simulation_tick_controller.guard_citizen_positions()

func _factory_for_role(role: String) -> Node3D:
	return _employer_for_role(role)


func _has_cook() -> bool:
	return workplace_labor_service.has_cook() if workplace_labor_service != null else false


func _employment_center_position() -> Vector3:
	return workplace_labor_service.employment_center_position() if workplace_labor_service != null else Vector3.INF


func _employment_centre_building() -> Node3D:
	return workplace_labor_service.employment_centre_building() if workplace_labor_service != null else null


func _officer_holder() -> Citizen:
	return workplace_labor_service.officer_holder() if workplace_labor_service != null else null


func _player_can_manage_permanent_professions() -> bool:
	return workplace_labor_service.player_can_manage_permanent_professions() if workplace_labor_service != null else false


func _registration_official() -> Citizen:
	return citizen_registration_service.registration_official() if citizen_registration_service != null else null


func _is_registration_staffed() -> bool:
	return citizen_registration_service.is_registration_staffed() if citizen_registration_service != null else false



func _can_start_registration(citizen: Citizen) -> bool:
	return citizen_registration_service.can_start_registration(citizen) if citizen_registration_service != null else false


func _registration_duration() -> float:
	return citizen_registration_service.registration_duration() if citizen_registration_service != null else Citizen.EMPLOYMENT_PROCESS_DURATION


func _is_teacher_present_at_school() -> bool:
	return school_service.is_teacher_present() if school_service != null else false


func _on_employment_processing_finished(citizen: Citizen) -> void:
	if citizen_registration_service != null:
		citizen_registration_service.on_employment_processing_finished(citizen)
	else:
		if not _is_work_time():
			citizen.state = Citizen.State.IDLE
			return
		citizen.finish_employment_processing()
		_update_workers()

func _update_daylight() -> void:
	_simulation_tick_controller.update_daylight()


func _update_clock(delta: float) -> void:
	_simulation_tick_controller.update_clock(delta)

func _on_school_day_ended() -> void:
	_simulation_handlers.on_school_day_ended()

func _on_daily_settlement_update(event: SimulationDayEvent) -> void:
	_simulation_handlers.on_daily_settlement_update(event)



func _end_ai_work_shift() -> void:
	_simulation_handlers.end_ai_work_shift()


func _clear_finished_daily_orders(workday_id: int) -> void:
	_simulation_handlers.clear_finished_daily_orders(workday_id)


func _clear_expired_overtime_orders() -> void:
	_simulation_handlers.clear_expired_overtime_orders()


func _reset_building_night_work_toggles() -> void:
	_simulation_handlers.reset_building_night_work_toggles()


func _resume_overtime_daily_orders() -> void:
	_simulation_handlers.resume_overtime_daily_orders()


func _check_daily_departures() -> void:
	settlement_survival_service.check_daily_departures()


func _on_citizen_leaving_departed(citizen: Citizen) -> void:
	citizen_lifecycle_service.on_citizen_leaving_departed(citizen)


func _total_game_minutes() -> float:
	return _simulation_tick_controller.total_game_minutes()


func _is_night() -> bool:
	return _simulation_tick_controller.is_night()

func _has_lit_communal_fire() -> bool:
	return _simulation_tick_controller.has_lit_communal_fire()

func _refresh_living_statuses() -> void:
	_simulation_tick_controller.refresh_living_statuses()

func _refresh_living_status(citizen: Citizen) -> void:
	_simulation_tick_controller.refresh_living_status(citizen)

func _is_work_time() -> bool:
	return _simulation_tick_controller.is_work_time()


func _is_citizen_work_time(citizen: Citizen) -> bool:
	return _simulation_tick_controller.is_citizen_work_time(citizen)

func _start_meal(hour: int) -> void:
	canteen_service.start_meal(hour)


func _start_park_rest(cooks_only: bool) -> void:
	_simulation_tick_controller.start_park_rest(cooks_only)



func _cancel_canteen_delivery() -> void:
	canteen_service.cancel_canteen_delivery()



func _publish_courier_tasks(dispatcher: RefCounted) -> void:
	if courier_task_publisher != null:
		courier_task_publisher.publish_courier_tasks(dispatcher)


func _firewood_task_priority(building: Node3D, fire_state: RefCounted) -> int:
	return _logistics_controller.firewood_task_priority(building, fire_state)


func _reconcile_repair_reservations() -> void:
	_logistics_controller.reconcile_repair_reservations()


func _construction_material_sources(resource_type: String, from_position: Vector3 = Vector3.ZERO) -> Array[Dictionary]:
	return _logistics_controller.construction_material_sources(resource_type, from_position)


func _construction_source_available(resource_type: String, source: Dictionary) -> int:
	return _logistics_controller.construction_source_available(resource_type, source)


func _is_courier_task_valid(task: RefCounted) -> bool:
	return courier_task_service.is_courier_task_valid(task)


func _start_courier_task(courier: Citizen, task: RefCounted) -> bool:
	return courier_task_service.start_courier_task(courier, task)



func _release_task_warehouse_reservation(task: RefCounted) -> void:
	courier_task_service.release_task_warehouse_reservation(task)


func _cancel_courier_task(courier: Citizen, task: RefCounted) -> void:
	courier_task_service.cancel_courier_task(courier, task)


func _set_canteen_delivery_state(active: bool, carrier: Citizen, amount: int) -> void:
	_logistics_controller.set_canteen_delivery_state(active, carrier, amount)


func _set_canteen_food(value: int) -> void:
	_logistics_controller.set_canteen_food(value)


func _is_canteen_delivery_in_progress() -> bool:
	return _logistics_controller.is_canteen_delivery_in_progress()


func _set_dig_mode(value: bool) -> void:
	dig_mode = value


func _set_build_mode(value: String) -> void:
	build_mode = value


func _reconcile_construction_reservations(site: ConstructionSite) -> void:
	_construction_controller.reconcile_construction_reservations(site)

func _preferred_construction_site() -> ConstructionSite:
	return _construction_controller.preferred_construction_site()


func _construction_development_priority(site: ConstructionSite) -> float:
	return _construction_controller.construction_development_priority(site)


func _builder_count(site_node: Node3D) -> int:
	return _construction_controller.builder_count(site_node)

func _building_power(site_node: Node3D) -> float:
	return _construction_controller.building_power(site_node)





func _sawmill_key(position_on_board: Vector3) -> Vector2i:
	return _cell_from_position(position_on_board)

func _sawmill_stock(position_on_board: Vector3) -> Dictionary:
	return sawmills.stock_at(position_on_board, runtime_seconds)

func _request_courier_dispatch() -> void:
	if _is_work_time() or _has_active_night_work_order():
		if courier_dispatcher != null:
			courier_dispatcher.dispatch()
		if citizen_ai != null:
			citizen_ai.request_decision_refresh()



func _can_work_at_dig_site(site: DigSiteRecordScript) -> bool:
	return excavation_service.can_work_at_dig_site(site)


func _resource_for_depth(site: DigSiteRecordScript, depth: int) -> String:
	return excavation_service.resource_for_depth(site, depth)

func _count_valid_dig_sites() -> int:
	return excavation_service.count_valid_dig_sites()

func _stored_resources() -> int:
	return storage_routing_service.stored_resources()

func _warehouse_capacity() -> int:
	return storage_routing_service.warehouse_capacity()

func _total_housing_slots() -> int:
	return building_registry.housing_capacity()

func _cell_from_position(position_on_board: Vector3) -> Vector2i:
	return nav_grid.cell_from_position(position_on_board) if nav_grid != null else Vector2i(floori(position_on_board.x / CELL_SIZE), floori(position_on_board.z / CELL_SIZE))

func _is_board_cell(cell: Vector2i) -> bool:
	if nav_grid != null:
		return nav_grid.is_board_cell(cell)
	var half_cells := BOARD_CELLS / 2
	return cell.x >= -half_cells and cell.x < half_cells and cell.y >= -half_cells and cell.y < half_cells

func _find_path_around_houses(from: Vector3, destination: Vector3, may_enter_destination_house: bool) -> RouteResult:
	if navigation_bridge != null:
		return navigation_bridge.find_path_around_houses(from, destination, may_enter_destination_house)
	return RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)


func _find_recovery_path(from: Vector3, destination: Vector3, may_enter_destination_house: bool) -> RouteResult:
	return navigation_bridge.find_recovery_path(from, destination, may_enter_destination_house) if navigation_bridge != null else RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)


func _movement_speed_modifier_at(position_on_board: Vector3) -> float:
	return navigation_facade.movement_speed_modifier_at(position_on_board) if navigation_facade != null else 1.0


func _navigation_revision() -> int:
	return navigation_facade.topology_revision() if navigation_facade != null else -1


func _is_route_reachable(from: Vector3, destination: Vector3, may_enter_destination_house := false) -> bool:
	return navigation_bridge.is_route_reachable(from, destination, may_enter_destination_house) if navigation_bridge != null else false


func _is_route_path_clear(from: Vector3, waypoints: Array[Vector3], may_enter_destination_house := false) -> bool:
	return nav_grid != null and nav_grid.is_waypoint_path_clear(from, waypoints, may_enter_destination_house)

func _resolve_building_queue_position(citizen: Citizen, destination: Vector3) -> Dictionary:
	return building_queue_service.resolve(citizen, destination)


func _complete_building_queue_arrival(citizen: Citizen, destination: Vector3) -> void:
	building_queue_service.complete_arrival(citizen, destination)


func _release_building_queue_entry(citizen: Citizen) -> void:
	building_queue_service.release(citizen)

func _update_interface(message: String) -> void:
	var lines: Array[String] = []
	lines.append("Era: %s" % _era_name())
	lines.append("Money: %d" % settlement.money)
	var displayed_resources := settlement.era_resources()
	for resource_type in displayed_resources:
		lines.append("%s: %d" % [_resource_display_name(resource_type), settlement.amount(resource_type)])
	if settlement.uses_virtual_storage():
		var backpack_units := 0.0
		for resource_type in displayed_resources:
			backpack_units += settlement.backpack_amount(resource_type) * settlement.storage_weight(resource_type)
		lines.append("Backpack: %.1f u" % backpack_units)
	else:
		lines.append("Storage: %d/%d" % [_stored_resources(), _warehouse_capacity()])
	if not resource_piles.is_empty():
		lines.append("Piles: %d" % resource_piles.size())
	lines.append("Population: %d" % citizens.size())
	lines.append("Wellbeing: %d" % settlement.wellbeing)
	ui_manager.hud.update_resources("\n".join(lines))
	_add_message(message)
	if is_first_person:
		var build_hint := S.HUD_BUILD_HINT_FP if player_citizen == hero_citizen else ""
		if not build_mode.is_empty():
			build_hint += S.HUD_BUILD_ROTATE_HINT
		ui_manager.hud.update_camera_hint(S.HUD_FIRST_PERSON_HINT % build_hint)
	else:
		ui_manager.hud.update_camera_hint(S.HUD_OVERVIEW_HINT)

const ERA_CATEGORIES := ["tent", "earth", "clay", "wood", "stone", "brick"]

func _era_name() -> String:
	return _workplace_controller.era_name()


func _resource_display_name(resource_type: String) -> String:
	match resource_type:
		ResourceIds.WOOD: return "Timber"
		_: return resource_type.capitalize()


# ---------- Message log system ------------------------------------------------

func _add_message(text: String) -> void:
	if ui_manager.message_log_panel != null:
		var timestamp := "[Day %d, %02d:%02d]" % [current_day, clock.hour(), clock.minute()]
		ui_manager.message_log_panel.add_message(text, timestamp)


# ---------- End message log system --------------------------------------------

func _create_world() -> void:
	_world_navigation_controller.create_world()


## Presentation ownership boundary for naturally occurring world objects.
## Their mutable gameplay records remain registered with the relevant feature
## services; reparenting them here must not change routing or resource logic.
func add_landscape_object(node: Node) -> void:
	_world_navigation_controller.add_landscape_object(node)


func _update_trail_overlay() -> void:
	_world_navigation_controller.update_trail_overlay()


func _record_trail_movement(citizen_id: int, position_on_board: Vector3) -> void:
	_world_navigation_controller.record_trail_movement(citizen_id, position_on_board)

func _refresh_navigation_grid() -> void:
	_world_navigation_controller.refresh_navigation_grid()

func _rebuild_navigation_obstacles() -> void:
	_world_navigation_controller.rebuild_navigation_obstacles()



func _pond_access_position(from: Vector3, pond_center: Vector3) -> Vector3:
	return _world_navigation_controller.pond_access_position(from, pond_center)


func _resource_access_position(from: Vector3, resource_position: Vector3) -> Vector3:
	return _world_navigation_controller.resource_access_position(from, resource_position)



func _create_citizens() -> void:
	_citizen_factory.create_citizens()


func _bind_hero_squad_to_settlement(squad_settlement_id: StringName) -> void:
	_citizen_factory.bind_hero_squad_to_settlement(squad_settlement_id)


func _add_citizen(spawn_position: Vector3, primary_specialization := "") -> void:
	_citizen_factory.add_citizen(spawn_position, primary_specialization)


## Attaches navigation, the registration service and every gameplay signal to a
## citizen. The caller must already have added the node to the tree, set
## `simulation` and chosen the specialization. Shared by initial spawning and
## save restore so a new signal only needs to be registered in one place.
func _wire_citizen(citizen: Citizen) -> void:
	_citizen_factory.wire_citizen(citizen)


func _create_starter_backpack() -> void:
	_citizen_factory.create_starter_backpack()


func _on_ai_citizen_exiting(citizen_id: int) -> void:
	_citizen_factory.on_ai_citizen_exiting(citizen_id)


func _is_ai_citizen_id_alive(citizen_id: int) -> bool:
	return _citizen_factory.is_ai_citizen_id_alive(citizen_id)


func _citizen_for_ai_id(citizen_id: int) -> Citizen:
	return _citizen_factory.citizen_for_ai_id(citizen_id)


func _ai_target_for_key(target_key: StringName) -> Node3D:
	return _citizen_factory.ai_target_for_key(target_key)



func _player_use_toilet(toilet_node: Node3D) -> void:
	if not is_first_person or player_citizen == null or not is_instance_valid(toilet_node):
		return
	if player_citizen.player_using_toilet:
		return
	player_citizen.begin_player_toilet_use(toilet_node)
	interaction_action = "toilet"
	interaction_time = 0.0
	ui_manager.interaction_hint_panel.progress_bar.visible = true
	ui_manager.interaction_hint_panel.hint_label.text = S.USING_TOILET
	_update_interface(S.TOILET_IN_USE)


func _check_player_toilet_request() -> void:
	_hero_interaction_controller.check_player_toilet_request()



func _set_workday_hours(hours: int) -> void:
	if hours not in [6, 8, 10, 12, 14]:
		return
	settlement.pending_workday_hours = hours
	if survival_event_controller != null:
		survival_event_controller.update_skip_night_button()
	_update_interface("Workday set to %d hours for the next shift." % hours)


func _apply_pending_workday_hours() -> void:
	if settlement.pending_workday_hours <= 0:
		return
	settlement.workday_hours = settlement.pending_workday_hours
	settlement.pending_workday_hours = 0

func _has_active_night_work_order() -> bool:
	for citizen in citizens:
		if is_instance_valid(citizen) and citizen.has_active_overtime(day_cycle.current_day):
			return true
	return false


func _release_unassigned_overtime_workers() -> void:
	if citizen_ai == null:
		return
	var changed := false
	for citizen in citizens:
		if not is_instance_valid(citizen) or not citizen.has_active_overtime(day_cycle.current_day):
			continue
		# Critical needs may send an otherwise assigned worker home temporarily. Only
		# release overtime after the director has no work proposal left for them.
		if citizen_ai.has_current_order(citizen.ai_id):
			continue
		if citizen.state in [Citizen.State.TO_HOME, Citizen.State.RESTING]:
			citizen.deactivate_overtime()
			changed = true
	if changed:
		if citizen_daily_order_service != null:
			citizen_daily_order_service.sync_overtime_scope_indicators()
		if survival_event_controller != null:
			survival_event_controller.update_skip_night_button()

func _set_time_multiplier(multiplier: float) -> void:
	time_multiplier = multiplier
	if is_first_person:
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = multiplier
	_update_interface("Simulation speed set to x%d." % int(multiplier))



func _outside_work_reward() -> int:
	return _outside_work_controller.outside_work_reward()



func _send_selected_resident_to_outside_work() -> void:
	_outside_work_controller.send_selected_resident_to_outside_work()


func _on_outside_work_departed(worker: Citizen) -> void:
	_outside_work_controller.on_outside_work_departed(worker)

func _absolute_game_minutes() -> int:
	return _outside_work_controller.absolute_game_minutes()

func _return_outside_workers() -> void:
	_outside_work_controller.return_outside_workers()


func _show_materials_factory_menu() -> void:
	if selected_materials_factory == null:
		return
	ui_manager.materials_factory_menu.visible = true
	ui_manager.materials_factory_menu_title.text = "Materials factory\nAssign workers to produce materials."

func _update_building_research(delta: float) -> void:
	_research_controller.update_building_research(delta)

func _cancel_active_building_research(refund: bool, message: String) -> void:
	_research_controller.cancel_active_building_research(refund, message)


func _handle_civic_post_assignment() -> void:
	_research_controller.handle_civic_post_assignment()


func _daily_researcher_at(centre: Node3D) -> Citizen:
	return _research_controller.daily_researcher_at(centre)

func _on_arrival_greeter_ready(greeter: Citizen) -> void:
	citizen_lifecycle_service.on_arrival_greeter_ready(greeter)


func _cancel_arrivals_for_house(house: Node3D) -> void:
	citizen_lifecycle_service.cancel_arrivals_for_house(house)


func _show_house_menu() -> void:
	if house_menu_controller != null:
		house_menu_controller.show_house_menu()

func _unhoused_citizen_count() -> int:
	return citizen_lifecycle_service.unhoused_citizen_count()

func _house_initial_residents(house: Node3D) -> void:
	citizen_lifecycle_service.house_initial_residents(house)

func _open_build_category(category: String) -> void:
	_build_controller.open_build_category(category)


func _on_build_menu_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		return
	if not build_category.is_empty():
		_open_build_category("")
	elif build_menu_is_job_menu or build_menu_is_daily_order_menu:
		_close_assignment_submenu()
	else:
		ui_manager.build_menu.visible = false
		build_menu_is_global = false
		if selected_builder != null:
			selected_builder = null
	get_viewport().set_input_as_handled()

func _open_job_submenu() -> void:
	build_menu_is_job_menu = true
	build_menu_is_daily_order_menu = false
	build_category = ""
	if building_menu_controller != null:
		building_menu_controller.refresh_build_menu()

func _open_daily_order_submenu() -> void:
	build_menu_is_daily_order_menu = true
	build_menu_is_job_menu = false
	build_category = ""
	if building_menu_controller != null:
		building_menu_controller.refresh_build_menu()

func _close_assignment_submenu() -> void:
	build_menu_is_job_menu = false
	build_menu_is_daily_order_menu = false
	if building_menu_controller != null:
		building_menu_controller.refresh_build_menu()

func _set_selected_work_role(role: String, daily_order := false) -> void:
	if selected_builder == null:
		return
	# A work assignment is an explicit hand-off to the settlement AI. Without
	# this, a citizen previously moved in first-person mode keeps the direct
	# control flag and is excluded from every work and courier order.
	selected_builder.set_player_controlled(false)
	selected_builder.idle()
	if daily_order:
		if role.is_empty():
			selected_builder.clear_daily_order()
		else:
			if citizen_daily_order_service != null:
				citizen_daily_order_service.assign_daily_order(selected_builder, role)
		if selected_builder.employment_state == Citizen.EmploymentState.UNREGISTERED and _employment_center_position() != Vector3.INF:
			selected_builder.request_no_permanent_work_registration()
	elif role == "excavation":
		excavation_service.start_dig_assignment()
		build_menu_is_job_menu = false
		build_menu_is_daily_order_menu = false
		return
	elif role == "official":
		if not _appoint_official(selected_builder, _employment_centre_building(), false):
			return
	else:
		if role != "official" and not _player_can_manage_permanent_professions():
			if workplace_labor_service != null:
				workplace_labor_service.show_labor_command_blocked()
			return
		if selected_builder.has_no_permanent_work() or selected_builder.is_unregistered():
			if _employment_center_position() == Vector3.INF:
				_update_interface("Build the main campfire before assigning permanent jobs.")
				return
			selected_builder.clear_daily_order()
			selected_builder.begin_employment_processing(_employment_center_position(), role, _employer_for_role(role))
	selected_builder.assigned_dig_site = null
	if citizen_ai != null:
		citizen_ai.request_decision_refresh()
	_update_workers()
	build_menu_is_job_menu = false
	build_menu_is_daily_order_menu = false
	_show_selected_citizen_menu()
	if building_menu_controller != null:
		building_menu_controller.refresh_build_menu()
	_update_interface("%s assigned to %s." % ["Hero" if selected_builder.is_hero else "Citizen", "automatic work" if role.is_empty() else role.replace("_", " ")])
	if workforce_menu_controller != null:
		workforce_menu_controller.refresh_campfire_occupancy_button()
	if ui_manager.workforce_menu != null and ui_manager.workforce_menu.visible:
		if workforce_menu_controller != null:
			workforce_menu_controller.refresh_workforce_menu()

func _min_era_for_role(role: String) -> SettlementState.Era:
	# Basic outdoor/hand-work roles exist from the tent era even without a dedicated workplace.
	match role:
		"construction", "excavation", "gather_branches", "gather_food", "courier", "craftsman", "official", "":
			return SettlementState.Era.TENT
	var types := _employer_types_for_role(role)
	if types.is_empty():
		return SettlementState.Era.TENT
	var min_era := SettlementState.Era.BRICK
	for type in types:
		var era: SettlementState.Era = BuildingCatalog.era_for(type)
		if era < min_era:
			min_era = era
	return min_era


func _assigned_count_for_role(role: String) -> int:
	var count := 0
	for citizen in citizens:
		if citizen.daily_order_role == role or (role.is_empty() and citizen.daily_order_role.is_empty()):
			count += 1
	return count


func builder_job_capacity() -> int:
	return _available_employer_capacity("construction")


func available_employer_capacity(role: String) -> int:
	return _available_employer_capacity(role)


func officer_exists() -> bool:
	return workplace_labor_service.officer_exists() if workplace_labor_service != null else false


func permanent_profession_block_message() -> String:
	return workplace_labor_service.permanent_profession_block_message() if workplace_labor_service != null else ""


func player_can_manage_permanent_professions() -> bool:
	return _player_can_manage_permanent_professions()


func show_labor_command_blocked() -> void:
	if workplace_labor_service != null:
		workplace_labor_service.show_labor_command_blocked()


func employment_center_position() -> Vector3:
	return _employment_center_position()


func min_era_for_role(role: String) -> int:
	return _min_era_for_role(role)


func era_name() -> String:
	return _era_name()


func is_construction_site(building: Node3D) -> bool:
	return _is_construction_site(building)


func player_can_command_labor() -> bool:
	return workplace_labor_service.player_can_command_labor() if workplace_labor_service != null else true


func labor_command_block_message() -> String:
	return workplace_labor_service.labor_command_block_message() if workplace_labor_service != null else ""


func _builder_job_capacity() -> int:
	return builder_job_capacity()


func _employer_for_role(role: String) -> Node3D:
	if role == "official":
		return _employment_centre_building()
	if role == "excavation":
			for site in dig_sites:
				if _can_work_at_dig_site(site):
					return site.node
			return null
	if role not in ["construction", "forestry", "farming", "gather_food", "gather_branches", "gather_grass", "cook", "teacher", "seller", "factory_worker", "engineer", "craftsman", "official"]:
		return null
	var best: Node3D
	var best_load := 100000
	var best_priority := -1
	for record in building_registry.records():
		var building := record.node
		if not is_instance_valid(building) or not _building_supports_role(building, role):
			continue
		if not bool(building.get_meta("accepting_workers", true)):
			continue
		var capacity := _employer_capacity(role, building)
		var load := 0
		for citizen in citizens:
			if citizen.employment_workplace == building or citizen.pending_employment_workplace == building:
				load += 1
		var priority := int(building.get_meta("workplace_priority", 0))
		if load < capacity and (priority > best_priority or (priority == best_priority and load < best_load)):
			best = building
			best_load = load
			best_priority = priority
	return best


func _employer_types_for_role(role: String) -> Array[String]:
	return _workplace_controller.employer_types_for_role(role)


func _available_employer_capacity(role: String) -> int:
	if role == "official":
		var centre := _employment_centre_building()
		return 1 if is_instance_valid(centre) and bool(centre.get_meta("accepting_workers", true)) else 0
	var capacity := 0
	for record in building_registry.records():
		var building := record.node
		if not is_instance_valid(building) or not _building_supports_role(building, role):
			continue
		if bool(building.get_meta("accepting_workers", true)):
			capacity += _employer_capacity(role, building)
	return capacity


func _is_staffed_workplace(building: Node3D) -> bool:
	return _workplace_controller.is_staffed_workplace(building)


func _building_supports_role(building: Node3D, role: String) -> bool:
	return _workplace_controller.building_supports_role(building, role)


func _employer_capacity(role: String, building: Node3D) -> int:
	return _workplace_controller.employer_capacity(role, building)

func _set_build_placement_ui_visible(is_visible: bool) -> void:
	_build_controller.set_build_placement_ui_visible(is_visible)


func _select_build_mode(next_mode: String) -> void:
	_build_controller.select_build_mode(next_mode)

func _cancel_build_action() -> void:
	_build_controller.cancel_build_action()

func _on_context_menu_gui_input(event: InputEvent) -> void:
	_input_controller.on_context_menu_gui_input(event)


func _is_first_person_menu_open() -> bool:
	return _input_controller.is_first_person_menu_open()


func _update_first_person_mouse_and_crosshair() -> void:
	_input_controller.update_first_person_mouse_and_crosshair()


func _close_context_menus() -> void:
	_input_controller.close_context_menus()


func _input(event: InputEvent) -> void:
	_input_controller.handle_input(event)


func _unhandled_input(event: InputEvent) -> void:
	_input_controller.handle_unhandled_input(event)

func _select_citizen_at(screen_position: Vector2) -> void:
	var visible_citizen := _citizen_at_screen_position(screen_position)
	if visible_citizen != null:
		_select_citizen(visible_citizen)
		return
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collision_mask = 4
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		# Clicking empty ground clears the current selection and its menu.
		_close_context_menus()
		return
	# Switching to a different building always dismisses the previously open
	# menu first, so only one context menu is ever visible at a time.
	_hide_all_selection_menus()
	if not hit.collider.is_in_group("school_selector"):
		selected_builder = null
	ui_manager.build_menu.visible = false
	build_menu_is_global = false
	if hit.collider.is_in_group("entrance_selector"):
		selected_entrance = hit.collider.get_parent() as Node3D
		selected_building = selected_entrance
		if entrance_menu_controller != null:
			entrance_menu_controller.show_entrance_menu()
		return
	if hit.collider.is_in_group("campfire_selector"):
		selected_campfire = hit.collider.get_parent() as Node3D
		selected_building = selected_campfire
		if campfire_menu_controller != null:
			campfire_menu_controller.show_campfire_menu()
		return
	if hit.collider.is_in_group("market_selector"):
		selected_market = hit.collider.get_parent() as Node3D
		selected_building = selected_market
		if market_menu_controller != null:
			market_menu_controller.show_market_menu()
		return
	if hit.collider.is_in_group("warehouse_selector"):
		selected_warehouse = hit.collider.get_parent() as Node3D
		selected_building = selected_warehouse
		if warehouse_menu_controller != null:
			warehouse_menu_controller.show_warehouse_menu()
		return
	if hit.collider.is_in_group("cook_campfire_selector"):
		selected_building = hit.collider.get_parent() as Node3D
		if building_menu_controller != null:
			building_menu_controller.show_building_menu()
		return
	if hit.collider.is_in_group("house_selector"):
		selected_house = hit.collider.get_parent() as Node3D
		selected_building = selected_house
		selected_builder = null
		ui_manager.build_menu.visible = false
		_show_house_menu()
		_update_interface("House selected. Recruit a new resident when a bed is free.")
		return
	if hit.collider.is_in_group("school_selector"):
		selected_school = hit.collider.get_parent() as Node3D
		selected_building = selected_school
		ui_manager.house_menu.visible = false
		ui_manager.build_menu.visible = false
		if school_menu_controller != null:
			school_menu_controller.show_school_menu()
		return
	if hit.collider.is_in_group("materials_factory_selector"):
		selected_materials_factory = hit.collider.get_parent() as Node3D
		selected_building = selected_materials_factory
		selected_house = null
		selected_school = null
		ui_manager.house_menu.visible = false
		ui_manager.school_menu.visible = false
		ui_manager.build_menu.visible = false
		_show_materials_factory_menu()
		_update_interface("Materials factory selected. Assign workers to produce materials.")
		return
	if hit.collider.is_in_group("construction_selector"):
		selected_building = hit.collider.get_parent() as Node3D
		if building_menu_controller != null:
			building_menu_controller.show_building_menu()
		return
	if hit.collider.is_in_group("building_selector"):
		selected_building = hit.collider.get_parent() as Node3D
		if building_menu_controller != null:
			building_menu_controller.show_building_menu()
		return
	if not hit.collider.is_in_group("citizen_selector"):
		return
	_select_citizen(hit.collider.get_parent() as Citizen)


func _first_person_select_at_crosshair() -> void:
	_hero_interaction_controller.first_person_select_at_crosshair()


func _hide_all_selection_menus() -> void:
	# Hides every building context menu and clears their selections, but leaves
	# the currently selected citizen untouched (the school menu needs it).
	ui_manager.house_menu.visible = false
	ui_manager.entrance_menu.visible = false
	ui_manager.school_menu.visible = false
	ui_manager.materials_factory_menu.visible = false
	ui_manager.campfire_menu.visible = false
	if ui_manager.campfire_story_menu != null:
		ui_manager.campfire_story_menu.visible = false
	if ui_manager.campfire_orders_menu != null:
		ui_manager.campfire_orders_menu.visible = false
	ui_manager.market_menu.visible = false
	ui_manager.warehouse_menu.visible = false
	ui_manager.building_menu.visible = false
	if ui_manager.research_menu != null:
		ui_manager.research_menu.visible = false
	if ui_manager.decision_menu != null:
		ui_manager.decision_menu.visible = false
	if workforce_menu_controller != null:
		workforce_menu_controller.hide_workforce_menu()
	build_category = ""
	build_menu_is_job_menu = false
	build_menu_is_daily_order_menu = false
	selected_house = null
	selected_entrance = null
	selected_school = null
	selected_materials_factory = null
	selected_campfire = null
	selected_market = null
	selected_warehouse = null
	selected_building = null

func _demolish_selected_house() -> void:
	if selected_house != null:
		building_lifecycle_service.mark_building_for_demolition(selected_house)

func _demolish_selected_school() -> void:
	if selected_school != null:
		building_lifecycle_service.mark_building_for_demolition(selected_school)

func _demolish_selected_warehouse() -> void:
	if selected_warehouse != null:
		building_lifecycle_service.mark_building_for_demolition(selected_warehouse)


func _add_demolition_marker(building: Node3D) -> void:
	_building_visuals.add_demolition_marker(building)

func _demolition_ready(site: DemolitionSite) -> bool:
	return building_lifecycle_service.demolition_ready(site)


func _finish_demolition(site: DemolitionSite) -> void:
	var building_id := String(site.building.get_meta("building_instance_id", "")) if is_instance_valid(site.building) else ""
	building_lifecycle_service.finish_demolition(site)
	if fixture_service != null and not building_id.is_empty():
		fixture_service.remove_building(building_id)

func _remove_building_services(building: Node3D, building_type: String) -> void:
	building_lifecycle_service.remove_building_services(building, building_type)



func _send_to_unemployment_registration(citizen: Citizen) -> void:
	citizen_lifecycle_service.send_to_unemployment_registration(citizen)


func _citizen_at_screen_position(screen_position: Vector2) -> Citizen:
	var closest: Citizen
	var closest_distance := 22.0
	for citizen in citizens:
		if not is_instance_valid(citizen) or camera.is_position_behind(citizen.global_position):
			continue
		var distance := camera.unproject_position(citizen.global_position + Vector3.UP * 0.9).distance_to(screen_position)
		if distance < closest_distance:
			closest = citizen
			closest_distance = distance
	return closest

func _select_citizen(clicked_citizen: Citizen) -> void:
	if clicked_citizen == null:
		return
	if selected_builder != null and selected_builder.can_handle_entry_logistics() and clicked_citizen != selected_builder:
		selected_builder.courier_worker = clicked_citizen
		_request_courier_dispatch()
		_update_interface("%s assigned to this worker. Click another worker to reassign." % ("Courier" if selected_builder.is_courier() else "Daily courier"))
		return
	selected_builder = clicked_citizen
	_hide_all_selection_menus()
	build_mode = ""
	build_category = ""
	build_menu_is_global = false
	world_setup.selection_marker.visible = false
	_show_territory_overlay(false)
	ui_manager.build_menu.visible = true
	if building_menu_controller != null:
		building_menu_controller.refresh_build_menu()
	_show_selected_citizen_menu()
	_update_interface("Citizen selected. Choose a building in the lower-right menu.")

func _show_selected_citizen_menu() -> void:
	if selected_builder == null:
		return
	var assignment := "Unregistered"
	if selected_builder.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK:
		if selected_builder.has_daily_order():
			assignment = "Daily order: %s" % selected_builder.daily_order_role.replace("_", " ")
		else:
			assignment = "No permanent work%s" % (": " + selected_builder.daily_order_role.replace("_", " ") if not selected_builder.daily_order_role.is_empty() else "")
	elif selected_builder.employment_state == Citizen.EmploymentState.EMPLOYED:
		assignment = "Employed: %s" % selected_builder.permanent_role.replace("_", " ")
	elif selected_builder.employment_state == Citizen.EmploymentState.REGISTERING:
		assignment = "Registering"
	if not selected_builder.training_role.is_empty():
		assignment = "Training %s %d/10" % [selected_builder.training_role.capitalize(), selected_builder.training_days_completed]
	var home_label := "No home" if not is_instance_valid(selected_builder.home) else "House"
	var effect_label := "Meal buff" if selected_builder.buffs.has("canteen_meal") else ("Tent debuff" if selected_builder.debuffs.has("tent") else "None")
	if build_category.is_empty():
		ui_manager.build_menu.title_label.text = "%s  Sat: %d/%d%%  Food: %d%%\nHome: %s  Effect: %s\nTask: %s" % [selected_builder.role_label(), roundi(selected_builder.satisfaction), roundi(selected_builder.get_satisfaction_cap()), roundi(selected_builder.hunger), home_label, effect_label, assignment]
		ui_manager.build_menu.citizen_skills_label.text = "Skills\nBuild %.0f%%  Wood %.0f%%\nFarm %.0f%%  Dig %.0f%%" % [float(selected_builder.skills.get("construction", 0.0)) * 100.0, float(selected_builder.skills.get("forestry", 0.0)) * 100.0, float(selected_builder.skills.get("farming", 0.0)) * 100.0, float(selected_builder.skills.get("excavation", 0.0)) * 100.0]
		ui_manager.build_menu.citizen_skills_label.visible = true
	ui_manager.build_menu.title_label.add_theme_color_override("font_color", selected_builder.specialization_color())

func _gather_action_name(resource_type: String) -> String:
	match resource_type:
		ResourceIds.WOOD: return S.GATHER_ACTION_WOOD
		ResourceIds.BRANCHES: return S.GATHER_ACTION_BRANCHES
		ResourceIds.GRASS: return S.GATHER_ACTION_GRASS
		ResourceIds.WATER: return S.GATHER_ACTION_WATER
		ResourceIds.FOOD: return S.GATHER_ACTION_FOOD
	return S.GATHER_ACTION_DEFAULT


func _harvest_source_info(resource_type: String) -> String:
	if player_citizen == null:
		return ""
	match resource_type:
		ResourceIds.BRANCHES:
			var tree := foraging_service.nearest_tree_node(player_citizen.global_position)
			if is_instance_valid(tree):
				var tree_state: Variant = world_resource_state.tree_at(_cell_from_position(tree.global_position))
				if tree_state != null:
					return S.SOURCE_INFO_BRANCHES % [tree_state.remaining_branches, maxi(1, tree_state.initial_branches)]
			return ""
		ResourceIds.GRASS:
			var node := foraging_service.nearest_grass_node(player_citizen.global_position)
			if is_instance_valid(node):
				for cell in grass_sources:
					var source: GrassSourceRecordScript = grass_sources[cell]
					if source.node == node:
						var rem := source.remaining
						var init := maxi(1, source.initial)
						return S.SOURCE_INFO_GRASS % [rem, init]
			return ""
		ResourceIds.WOOD:
			return S.SOURCE_INFO_WOOD
		ResourceIds.WATER:
			return S.SOURCE_INFO_WATER
		ResourceIds.FOOD:
			return S.SOURCE_INFO_FOOD
	return ""


func _can_continue_harvesting(resource_type: String) -> bool:
	match resource_type:
		ResourceIds.WOOD: return _nearby_tree()
		ResourceIds.BRANCHES: return _nearby_tree_with_branches()
		ResourceIds.FOOD: return _nearby_farm()
		ResourceIds.WATER: return _nearby_pond()
		ResourceIds.GRASS: return _nearby_grass_source()
	return false


func _deliver_all_pocket_to_warehouse(warehouse_index := -1) -> void:
	_hero_interaction_controller._deliver_all_pocket_to_warehouse(warehouse_index)


func _deliver_one_pocket_to_warehouse(warehouse_index := -1) -> void:
	_hero_interaction_controller._deliver_one_pocket_to_warehouse(warehouse_index)


func _nearest_service_position(building: Node3D, from: Vector3) -> Vector3:
	return _hero_interaction_controller._nearest_service_position(building, from)


func _exit_player_work_position() -> void:
	_hero_interaction_controller.exit_player_work_position()


func _occupy_workplace(workplace: Node3D) -> void:
	_hero_interaction_controller.occupy_workplace(workplace)


func _reserve_player_gather_storage(resource_type: String, requested: int) -> int:
	if settlement.uses_virtual_storage():
		return requested
	if player_citizen == null or warehouse_positions.is_empty():
		return 0
	var origin := player_citizen.global_position
	var index := settlement.find_warehouse_index(origin, resource_type, requested, warehouse_positions)
	if index >= 0 and settlement.reserve_warehouse_room(index, resource_type, requested):
		return requested
	for amount in range(requested - 1, 0, -1):
		index = settlement.find_warehouse_index(origin, resource_type, amount, warehouse_positions)
		if index >= 0 and settlement.reserve_warehouse_room(index, resource_type, amount):
			return amount
	return 0


func _nearby_tree() -> bool:
	return hero_interaction_service.nearby_tree() if hero_interaction_service != null else false

func _nearby_tree_with_branches() -> bool:
	return hero_interaction_service.nearby_tree_with_branches() if hero_interaction_service != null else false

func _nearby_warehouse_index() -> int:
	return storage_routing_service.nearby_warehouse_index()





func _nearby_farm() -> bool:
	return hero_interaction_service.nearby_farm() if hero_interaction_service != null else false

func _nearby_pond() -> bool:
	return hero_interaction_service.nearby_pond() if hero_interaction_service != null else false

func _nearby_grass_source() -> bool:
	return hero_interaction_service.nearby_grass_source() if hero_interaction_service != null else false


func _wild_food_requires_specialist_message() -> String:
	return "Forest gifts and rabbits can only be gathered by a trained specialist. Build a forager/hunter tent first."

func _pocket_total() -> int:
	return hero_pocket_service.pocket_total() if hero_pocket_service != null else 0


func _pocket_has_room() -> bool:
	return hero_pocket_service.pocket_has_room() if hero_pocket_service != null else false


func _pocket_resources() -> Array:
	return hero_pocket_service.pocket_resources() if hero_pocket_service != null else []


func _primary_pocket_resource() -> String:
	return hero_pocket_service.primary_pocket_resource() if hero_pocket_service != null else ""



func _nearby_workplace_for_job() -> Node3D:
	if player_citizen == null:
		return null
	var best: Node3D
	var best_dist := JOB_ENTRANCE_RANGE
	for record in building_registry.records():
		var building := record.node as Node3D
		if not is_instance_valid(building):
			continue
		var role := _role_for_workplace(building)
		if role.is_empty():
			continue
		var service_pos: Vector3 = building.get_meta("service_position", building.global_position)
		var dist := player_citizen.global_position.distance_to(service_pos)
		if dist <= best_dist:
			best = building
			best_dist = dist
	return best


func _role_for_workplace(building: Node3D) -> String:
	return _workplace_controller.role_for_workplace(building)



func _format_pocket_hint() -> String:
	return hero_pocket_service.format_pocket_hint() if hero_pocket_service != null else ""


func _home_occupancy_text() -> String:
	return _hero_interaction_controller._home_occupancy_text()


func _refresh_interaction_hint() -> void:
	_hero_interaction_controller.refresh_interaction_hint()


func _nearest_point_to_point_array(points: Array[Vector3], target: Vector3, max_distance: float) -> Vector3:
	var best := Vector3.INF
	var best_dist := max_distance
	for point in points:
		var dist := point.distance_to(target)
		if dist <= best_dist:
			best_dist = dist
			best = point
	return best


func _nearest_grass_source_to_point(point: Vector3, max_distance: float) -> Vector3:
	var best := Vector3.INF
	var best_dist := max_distance
	var point_xz := Vector2(point.x, point.z)
	for cell in grass_sources:
		var source: GrassSourceRecordScript = grass_sources[cell]
		if source.remaining <= 0 or not is_instance_valid(source.node):
			continue
		var node_pos: Vector3 = source.node.global_position
		var dist := point_xz.distance_to(Vector2(node_pos.x, node_pos.z))
		if dist <= best_dist:
			best_dist = dist
			best = node_pos
	return best



func _first_person_target() -> Dictionary:
	return _hero_interaction_controller.first_person_target()


func _missing_site_materials_text(site: ConstructionSite) -> String:
	return _hero_interaction_controller._missing_site_materials_text(site)


func _handle_sawmill_interaction(all: bool, sawmill_pos: Vector3) -> void:
	_hero_interaction_controller.handle_sawmill_interaction(all, sawmill_pos)


func _handle_warehouse_interaction(all: bool, warehouse_index := -1) -> void:
	_hero_interaction_controller.handle_warehouse_interaction(all, warehouse_index)


func _deliver_pocket_to_site(site: ConstructionSite, all: bool) -> void:
	_hero_interaction_controller.deliver_pocket_to_site(site, all)


func _refuel_fire_from_pocket(building: Node3D, all: bool) -> void:
	_hero_interaction_controller.refuel_fire_from_pocket(building, all)


func _meet_arrival_at_entrance() -> void:
	_hero_interaction_controller.meet_arrival_at_entrance()


func _take_from_pile(pile: ResourcePileScript, all: bool) -> void:
	_hero_interaction_controller.take_from_pile(pile, all)


func _citizen_state_name(state: int) -> String:
	match state:
		Citizen.State.TO_EMPLOYMENT_CENTER:
			return S.STATE_GOING_TO_EMPLOYMENT
		Citizen.State.EMPLOYMENT_PROCESSING:
			return S.STATE_PROCESSING_EMPLOYMENT
		Citizen.State.TO_ARRIVAL_ENTRANCE:
			return S.STATE_GOING_TO_MEET_ARRIVAL
		Citizen.State.ARRIVAL_MEETING:
			return S.STATE_MEETING_ARRIVAL
		Citizen.State.ARRIVAL_WAITING:
			return S.STATE_WAITING_MORNING_AT_ENTRANCE
		Citizen.State.TO_ARRIVAL_CENTER:
			return S.STATE_ESCORTING_ARRIVAL
	var state_names := Citizen.State.keys()
	if state < 0 or state >= state_names.size():
		return "Unknown state"
	return str(state_names[state]).capitalize().replace("_", " ")


func _targeted_grass_info(target: Dictionary) -> Dictionary:
	var target_node := target.get("node") as Node3D
	if not is_instance_valid(target_node):
		return {}
	for cell in grass_sources:
		var source: GrassSourceRecordScript = grass_sources[cell]
		if source.node == target_node:
			return {"remaining": source.remaining, "initial": maxi(1, source.initial)}
	return {}

func _terrain_point_at_screen_position(screen_position: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.position as Vector3

func _rotated_footprint(footprint: Vector2i, rotation_quarters := build_rotation_quarters) -> Vector2i:
	return building_placement_controller.rotated_footprint(footprint, rotation_quarters) if building_placement_controller != null else footprint

func _move_selection(world_position: Vector3) -> void:
	_build_controller.move_selection(world_position)

func _place_building(world_position: Vector3) -> void:
	_build_controller.place_building(world_position)

func _place_building_at_crosshair() -> void:
	_build_controller.place_building_at_crosshair()

func _can_hero_build() -> bool:
	return building_placement_controller.can_hero_build() if building_placement_controller != null else false

func _terrain_height_at(x: float, z: float, near_y: float) -> float:
	# The grid terrain is the owner of height (grid_terrain_system.md §10.4), so
	# ask it rather than the physics world: it answers identically headless, before
	# a chunk has been meshed, and without a frame of collision lag after an edit.
	if nav_grid != null and nav_grid.has_terrain_field():
		return nav_grid.height_at(Vector3(x, near_y, z))
	if DisplayServer.get_name() == "headless":
		return 0.0
	var from := Vector3(x, near_y + 12.0, z)
	var query := PhysicsRayQueryParameters3D.create(from, Vector3(x, near_y - 12.0, z))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return NAN if hit.is_empty() else float(hit.position.y)

func _is_clear_of_objects(world_position: Vector3, minimum_distance: float) -> bool:
	return building_placement_controller.is_clear_of_objects(world_position, minimum_distance) if building_placement_controller != null else false

func _placement_key(world_position: Vector3) -> Vector2i:
	return building_placement_controller.placement_key(world_position) if building_placement_controller != null else Vector2i.ZERO

func _create_construction_site(cell: Vector2i, building_type: String, position_on_board: Vector3, rotation_quarters := 0, blueprint: Dictionary = {}, occupied_footprint := Vector2i.ZERO) -> ConstructionSite:
	return _construction_controller.create_construction_site(cell, building_type, position_on_board, rotation_quarters, blueprint, occupied_footprint)


func _register_service_pockets(node: Node3D) -> void:
	_service_pocket_manager.register_service_pockets(node)


func _unregister_service_pockets(node: Node3D) -> void:
	_service_pocket_manager.unregister_service_pockets(node)

func _update_construction(delta: float) -> void:
	_construction_controller.update_construction(delta)


func _set_construction_status(text: String) -> void:
	_construction_controller.set_construction_status(text)


func _update_construction_supply_label(site: ConstructionSite) -> void:
	_construction_controller.update_construction_supply_label(site)

func _complete_building(cell: Vector2i, building_type: String, position_on_board: Vector3, building: Node3D, blueprint: Dictionary) -> void:
	_construction_controller.complete_building(cell, building_type, position_on_board, building, blueprint)


func _entrance_anchor_position() -> Vector3:
	return _building_management.entrance_anchor_position()


func _setup_entrance_sign_node(building: Node3D) -> void:
	_building_management.setup_entrance_sign_node(building)


func _activate_kitchen_if_better(building: Node3D, service_position: Vector3) -> void:
	_building_management.activate_kitchen_if_better(building, service_position)


func _select_best_canteen() -> void:
	_building_management.select_best_canteen()

func _add_building_selector(building: Node3D, group_name: String, footprint: Vector2i) -> void:
	_building_visuals.add_building_selector(building, group_name, footprint)


func _add_selector_to_node(node: Node3D, group_name: String, shape_size: Vector3, offset := Vector3.ZERO) -> void:
	_building_visuals.add_selector_to_node(node, group_name, shape_size, offset)


func _add_fire_light(building: Node3D, energy := 2.5, light_range := 8.0) -> void:
	_building_visuals.add_fire_light(building, energy, light_range)


func _add_building_status_indicator(building: Node3D) -> void:
	_building_visuals.add_building_status_indicator(building)


func _add_warehouse_fill_label(building: Node3D) -> void:
	_building_visuals.add_warehouse_fill_label(building)


func _send_citizen_to_leisure(citizen: Citizen, minimum_hours := 0) -> bool:
	return _simulation_tick_controller.send_citizen_to_leisure(citizen, minimum_hours)

func _grant_debug_resources() -> void:
	if not settlement.warehouse_ever_built:
		_update_interface("Resources can only be added after the first warehouse is built.")
		return
	var result := settlement.fill_least_warehouse_cheat(90.0)
	settlement.money += 30
	if not result.filled:
		_update_interface(S.NO_WAREHOUSE_BELOW_90)
	elif not result.overflow.is_empty() and not warehouse_positions.is_empty():
		resource_pile_service.drop_overflow_as_piles(result.overflow, warehouse_positions[0])
		_update_interface("Debug resources added. Some overflow dropped near the warehouse.")
	else:
		_update_interface("Debug resources added to the least stocked warehouse.")
	_update_workers()
	_request_courier_dispatch()

func _register_service_entrance(building: Node3D, blueprint: Dictionary, home_entrance := false, show_marker := true) -> void:
	_service_pocket_manager.register_service_entrance(building, blueprint, home_entrance, show_marker)

func _nearby_player_work_target() -> Node3D:
	return _hero_interaction_controller.nearby_player_work_target()


func _unregister_navigation_footprint(center: Vector3, footprint: Vector2i) -> void:
	_service_pocket_manager.unregister_navigation_footprint(center, footprint)

func _add_house_light(house: Node3D) -> void:
	_building_visuals.add_house_light(house)

func _on_tree_harvested(worker: Citizen, position_on_board: Vector3) -> void:
	_fell_tree_at(position_on_board)

func _consume_tree_near_player(amount: int) -> void:
	_hero_interaction_controller.consume_tree_near_player(amount)


func _fell_nearest_tree() -> void:
	_hero_interaction_controller.fell_nearest_tree()


func _fell_tree_at(position_on_board: Vector3) -> void:
	_world_navigation_controller.fell_tree_at(position_on_board)


## Lays a tree down and frees the cell it occupied. Shared by live felling and
## save restore so both paths produce identical geometry and navigation state.
func _apply_tree_felled_visual(cell: Vector2i, tree: Node3D) -> void:
	_world_navigation_controller.apply_tree_felled_visual(cell, tree)

func _toggle_global_build_menu() -> void:
	_build_controller.toggle_global_build_menu()


func _set_road_walking_order(enabled: bool) -> void:
	_workplace_controller.set_road_walking_order(enabled)



func _cheer_up_settlement() -> void:
	_workplace_controller.cheer_up_settlement()


func _has_night_work_candidates() -> bool:
	return _workplace_controller.has_night_work_candidates()


func _toggle_settlement_night_work(checked: bool) -> void:
	_workplace_controller.toggle_settlement_night_work(checked)


func _toggle_double_time_order(checked: bool) -> void:
	_workplace_controller.toggle_double_time_order(checked)


func _toggle_selected_citizen_night_work(checked: bool) -> void:
	_workplace_controller.toggle_selected_citizen_night_work(checked)



func _occupy_selected_campfire_position() -> void:
	_hero_interaction_controller.occupy_selected_campfire_position()


func _handle_campfire_primary_action() -> void:
	_hero_interaction_controller.handle_campfire_primary_action()


func _toggle_campfire_acceptance() -> void:
	_workplace_controller.toggle_campfire_acceptance()


func _dismiss_campfire_worker() -> void:
	_workplace_controller.dismiss_campfire_worker()


func _on_campfire_advance_pressed() -> void:
	_workplace_controller.on_campfire_advance_pressed()


func _refresh_market_menu() -> void:
	_workplace_controller.refresh_market_menu()









func _available_trade_money() -> int:
	return _workplace_controller.available_trade_money()


func _demolish_selected_building() -> void:
	_workplace_controller.demolish_selected_building()


func _relight_selected_fire() -> void:
	_hero_interaction_controller.relight_selected_fire()


func _toggle_selected_workplace_acceptance() -> void:
	_workplace_controller.toggle_selected_workplace_acceptance()


func _dismiss_selected_workplace_worker() -> void:
	_workplace_controller.dismiss_selected_workplace_worker()


func _reopen_workplace_menu() -> void:
	_workplace_controller.reopen_workplace_menu()


func _upgrade_selected_building() -> void:
	_workplace_controller.upgrade_selected_building()


func _workplace_worker(building: Node3D) -> Citizen:
	return _workplace_controller.workplace_worker(building)


func _workplace_priority_position(building: Node3D) -> int:
	return _workplace_controller.workplace_priority_position(building)


func _take_resource_into_pocket(resource_type: String, amount: int) -> void:
	_hero_interaction_controller.take_resource_into_pocket(resource_type, amount)


func _assign_cook_at_campfire() -> void:
	_workplace_controller.assign_cook_at_campfire()


func _assign_teacher_at_school() -> void:
	_workplace_controller.assign_teacher_at_school()


func _assign_seller_at_market() -> void:
	_workplace_controller.assign_seller_at_market()


func _appoint_official(citizen: Citizen, workplace: Node3D = null, require_at_post := true) -> bool:
	return _research_controller.appoint_official(citizen, workplace, require_at_post)


func _dismiss_official(citizen: Citizen) -> void:
	_research_controller.dismiss_official(citizen)


func _activate_employment_centre(centre: Node3D) -> void:
	_research_controller.activate_employment_centre(centre)


func _set_manual_specialist_employment(citizen: Citizen, role: String) -> bool:
	return _research_controller.set_manual_specialist_employment(citizen, role)



func _consume_grass_source(position: Vector3) -> int:
	return foraging_service.consume_grass_source(position)

func _create_gathering_place_visual(building: Node3D) -> void:
	_building_visuals.create_gathering_place_visual(building)

func _fire_state_for(building: Node3D) -> RefCounted:
	return fire_management_service.fire_state_for(building)

func _apply_fire_state(building: Node3D, fire_state: RefCounted) -> void:
	fire_management_service.apply_fire_state(building, fire_state)

func _is_fire_lit(building: Node3D) -> bool:
	return fire_management_service.is_fire_lit(building)

func _apply_building_wear_and_repairs() -> void:
	building_maintenance_service.apply_building_wear_and_repairs(_destroy_building_to_pile)


func _destroy_building_to_pile(building: Node3D, building_type: String) -> void:
	var building_id := String(building.get_meta("building_instance_id", "")) if is_instance_valid(building) else ""
	building_maintenance_service.destroy_building_to_pile(building, building_type, citizens, warehouse_positions, campfire_node)
	if fixture_service != null and not building_id.is_empty():
		fixture_service.remove_building(building_id)



func _move_stored_resources_to_pile(resources: Dictionary, warehouse_index := -1) -> void:
	building_lifecycle_service.move_stored_resources_to_pile(resources, warehouse_index)


func _select_best_campfire() -> void:
	building_lifecycle_service.select_best_campfire()


func _refresh_boundary_markers() -> void:
	_world_navigation_controller.refresh_boundary_markers()


func _show_territory_overlay(show: bool) -> void:
	_build_controller.show_territory_overlay(show)

func _create_resource_pile(position: Vector3, resources: Dictionary, is_backpack_pile := false) -> Node3D:
	return resource_pile_service.create_resource_pile(position, resources, is_backpack_pile)


func _convert_backpack_pile_to_regular() -> void:
	backpack_node = resource_pile_service.convert_backpack_pile_to_regular(backpack_node)

func _drop_resource_pile(position: Vector3, resource_type: String, amount: int) -> void:
	resource_pile_service.drop_resource_pile(position, resource_type, amount)

func _decay_resource_piles() -> void:
	resource_pile_service.decay_resource_piles()


func _return_in_transit_building_supplies(building: Node3D) -> void:
	_logistics_controller.return_in_transit_building_supplies(building)

func _get_delivery_position() -> Vector3:
	return _logistics_controller.get_delivery_position()

func _get_nearest_delivery_position(from: Vector3) -> Vector3:
	return _logistics_controller.get_nearest_delivery_position(from)


func _warehouse_delivery_position(from: Vector3, resource_type: String, amount: int) -> Vector3:
	return storage_routing_service.warehouse_delivery_position(from, resource_type, amount)


func _is_construction_site(node: Node3D) -> bool:
	return _construction_controller.is_construction_site(node)

func _cancel_selected_construction() -> void:
	_construction_controller.cancel_selected_construction()


func get_toilets() -> Array[Node3D]:
	var toilets: Array[Node3D] = []
	for record in building_registry.records():
		if is_instance_valid(record.node):
			var b_type: String = record.building_type
			if b_type.begins_with("toilet_"):
				toilets.append(record.node)
	return toilets


func _check_unstaffed_employment_center() -> void:
	_simulation_tick_controller.check_unstaffed_employment_center()


func _toggle_worker_overtime(checked: bool) -> void:
	_workplace_controller.toggle_worker_overtime(checked)


func _toggle_campfire_worker_overtime(checked: bool) -> void:
	_workplace_controller.toggle_campfire_worker_overtime(checked)


func restore_from_save_data(save_data: SaveDataScript) -> bool:
	return SettlementSaveLoaderScript.new().restore(self, save_data)
