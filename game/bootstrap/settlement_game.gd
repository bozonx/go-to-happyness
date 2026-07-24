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
var selected_cell := Vector2i(0, 0)
var selected_world_position := Vector3.ZERO
var build_mode := ""
var build_rotation_quarters := 0
var building_registry := BuildingRegistry.new()
var tree_cells: Dictionary[Vector2i, bool] = {}
var terrain_blocked_cells: Dictionary[Vector2i, bool] = {}
var navigation_blocked_cells: Dictionary[Vector2i, bool] = {}
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
var outside_workers: Dictionary[int, Dictionary] = {} # citizen stable id -> {citizen, return_at_minute}
var last_citizen_positions: Dictionary[int, Vector3] = {}
var resource_piles: Array[ResourcePileScript] = []
var backpack_node: Node3D
var backpack_position: Vector3

var tree_positions: Array[Vector3] = []
var tree_nodes: Dictionary[Vector2i, Node3D] = {}
var gather_progress_labels: Dictionary[Node3D, Node3D] = {} # resource Node3D -> Label3D
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
var selected_builder: Citizen
var selected_building: Node3D
var is_panning_camera := false
var is_rotating_camera := false
var right_mouse_dragged := false
var construction_sites: Array[ConstructionSite]:
	get: return construction.sites if construction != null else []
var demolition_sites: Array[DemolitionSite]:
	get: return demolition.sites if demolition != null else []
var completed_house_count := 0
var player_controller: PlayerController
var hero_citizen: Citizen

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

var pocket_menu_open := false
var pocket_take_warehouse_index: int = -1
var dig_sites: Array[DigSiteRecordScript] = []
var dig_cells: Dictionary = {}
var exhausted_dig_cells: Dictionary = {}
var dig_mode := false
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
var build_category := ""
var build_menu_is_job_menu := false
var build_menu_is_daily_order_menu := false
var build_menu_is_global := false
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
var resource_pile_service: ResourcePileService
var foraging_service: ForagingService
var fire_management_service: FireManagementService
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

	SettlementBootstrapperScript.new().run(self)


func _next_registration_ticket() -> int:
	return citizen_registration_service.next_registration_ticket() if citizen_registration_service != null else 0


func _resolve_event_decision(choice_index: int) -> void:
	if survival_event_controller != null:
		survival_event_controller.resolve_event_decision(choice_index)


func _toggle_school_development(role: String, pressed: bool) -> void:
	if school_menu_controller != null:
		school_menu_controller.toggle_school_development(role, pressed)

func _start_school_training(role: String) -> void:
	if school_menu_controller != null:
		school_menu_controller.start_school_training(role)

func _update_entrance_order_total(_value := 0.0) -> void:
	if entrance_menu_controller != null:
		entrance_menu_controller.update_entrance_order_total(_value)


func _send_entrance_order() -> void:
	if entrance_menu_controller != null:
		entrance_menu_controller.send_entrance_order()

func _hide_research_menu() -> void:
	if research_menu_controller != null:
		research_menu_controller.hide_research_menu()

func _start_research(tech_id: String) -> void:
	if research_menu_controller != null:
		research_menu_controller.start_research(tech_id)

func _cancel_research() -> void:
	if research_menu_controller != null:
		research_menu_controller.cancel_research()


func _show_campfire_story_menu() -> void:
	if campfire_menu_controller != null:
		campfire_menu_controller.show_campfire_story_menu()


func _close_campfire_story_menu() -> void:
	if campfire_menu_controller != null:
		campfire_menu_controller.close_campfire_story_menu()


func _select_campfire_story(story_id: String) -> void:
	if campfire_menu_controller != null:
		campfire_menu_controller.select_campfire_story(story_id)


func _close_campfire_orders_menu() -> void:
	if campfire_menu_controller != null:
		campfire_menu_controller.close_campfire_orders_menu()
	ui_manager.campfire_menu.visible = true


func _set_balanced_warehouse_mode(enabled: bool) -> void:
	storage_routing_service.set_balanced_warehouse_mode(enabled)


func _show_workforce_menu() -> void:
	if workforce_menu_controller != null:
		workforce_menu_controller.show_workforce_menu()


func _close_workforce_menu() -> void:
	if workforce_menu_controller != null:
		workforce_menu_controller.close_workforce_menu()


func _remove_worker_from_role(role: String) -> void:
	if workforce_menu_controller != null:
		workforce_menu_controller.remove_worker_from_role(role)


func _enable_auto_for_citizen(citizen: Citizen) -> void:
	if workforce_menu_controller != null:
		workforce_menu_controller.enable_auto_for_citizen(citizen)


func _buy_food(quantity: int, unit_price: int) -> void:
	trade_service.buy_food(quantity, unit_price)


func _sell_resource(resource_type: String, quantity: int, unit_price: int) -> void:
	trade_service.sell_resource(resource_type, quantity, unit_price)


func _buy_tool(tool_id: String, price: int) -> void:
	trade_service.buy_tool(tool_id, price)


func _buy_courier_equipment(courier: Citizen, equipment_id: String, price: int) -> void:
	trade_service.buy_courier_equipment(courier, equipment_id, price)


func _toggle_warehouse_accept(accepted: bool, resource_type: String) -> void:
	if warehouse_menu_controller != null:
		warehouse_menu_controller.toggle_warehouse_accept(accepted, resource_type)


func _dump_warehouse_resource(resource_type: String) -> void:
	if warehouse_menu_controller != null:
		warehouse_menu_controller.dump_warehouse_resource(resource_type)


func _cover_warehouse_with_tarp() -> void:
	if warehouse_menu_controller != null:
		warehouse_menu_controller.cover_warehouse_with_tarp()


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
	if not is_instance_valid(entrance_stone):
		return
	for citizen in citizens:
		if not is_instance_valid(citizen) or outside_workers.has(citizen.get_stable_id()):
			continue
		var citizen_id := citizen.get_stable_id()
		var previous: Vector3 = last_citizen_positions.get(citizen_id, citizen.global_position)
		var intentionally_at_entrance := citizen.state in [Citizen.State.TO_ARRIVAL_ENTRANCE, Citizen.State.ARRIVAL_MEETING, Citizen.State.ARRIVAL_WAITING, Citizen.State.TO_ARRIVAL_CENTER, Citizen.State.TO_TRADE_PICKUP, Citizen.State.TO_TRADE_DESTINATION]
		# No normal work transition moves an established resident from across the
		# map to the entrance. Keep the last known world location if that reset is
		# observed, while preserving genuine arrival and trade routes.
		if not intentionally_at_entrance and previous.distance_to(citizen.global_position) > 5.0 and previous.distance_to(entrance_stone.global_position) > 5.0 and citizen.global_position.distance_to(entrance_stone.global_position) < 2.5:
			citizen.global_position = previous
			citizen.velocity = Vector3.ZERO
		last_citizen_positions[citizen_id] = citizen.global_position

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
	if world_setup != null:
		var cloud_cover := weather_state.cloud_cover_at(clock.minutes)
		var rain_intensity := weather_state.intensity_at(clock.minutes)
		world_setup.update_daylight(game_minutes, cloud_cover, rain_intensity, runtime_seconds)


func _update_clock(delta: float) -> void:
	var previous_hour := clock.hour()
	var events := day_cycle.advance(delta, GAME_MINUTES_PER_SECOND, settlement.workday_hours)
	if weather_state.update(clock.minutes):
		if weather_state.is_raining:
			_update_interface("Rain has started.")
		else:
			_update_interface("Rain has stopped.")
	if clock.hour() != previous_hour:
		settlement_survival_service.apply_hourly_tent_survival(clock.hour())
		settlement_survival_service.apply_hourly_bare_hands_penalty()
		settlement_survival_service.apply_hourly_work_fatigue()
	if ui_manager.hud != null:
		ui_manager.hud.update_clock("%s  %02d:%02d  x%d" % ["Night" if clock.is_night() else "Day", clock.hour(), clock.minute(), int(time_multiplier)])
	if survival_event_controller != null:
		survival_event_controller.update_skip_night_button()
	for event in events:
		if simulation_event_dispatcher != null:
			simulation_event_dispatcher.dispatch_event(event, day_cycle.current_day)

func _on_school_day_ended() -> void:
	var teacher_ok := _is_teacher_present_at_school()
	for citizen in citizens:
		citizen.finish_school_day(teacher_ok)

func _on_daily_settlement_update(_event: SimulationDayEvent) -> void:
	tent_weather = TentEraSurvivalRulesScript.weather_for_day(day_cycle.current_day)
	weather_state.new_day(tent_weather, random, int(clock.minutes))
	_update_interface("Forecast: %s." % TentEraSurvivalRulesScript.WEATHER_NAMES[tent_weather])
	if event_service != null:
		event_service.log.clear_flag(&"smoky_firewood")
		event_service.log.clear_flag(&"firewood_protected_today")
		var delayed_outcomes: Array[EventOutcome] = event_service.advance_day(day_cycle.current_day, survival_event_controller.build_event_context() if survival_event_controller != null else EventContextScript.create(0, 1, 0, {}, 0, 0, {}), random)
		for outcome in delayed_outcomes:
			if survival_event_controller != null:
				survival_event_controller.apply_event_outcome(outcome)
	if survival_event_controller != null:
		survival_event_controller.maybe_present_survival_decision()
	_refresh_living_statuses()
	settlement.cheer_up_used_today = false
	settlement.double_time_order_day = -1
	if building_lifecycle_service != null:
		building_lifecycle_service.remove_expired_temporary_tents()
	if settlement_daily_rules_service != null:
		settlement_daily_rules_service.apply_daily_settlement_rules()
	_return_outside_workers()



func _end_ai_work_shift() -> void:
	for citizen: Citizen in citizens:
		if not is_instance_valid(citizen) or citizen.is_player_controlled:
			continue
		if citizen.has_active_overtime(day_cycle.current_day) and citizen.overtime_until_workday_id > day_cycle.current_day:
			continue
		if citizen_ai != null:
			citizen_ai.cancel_citizen_work(citizen.ai_id)
		citizen.end_work_shift()


func _clear_finished_daily_orders(workday_id: int) -> void:
	for citizen in citizens:
		if not is_instance_valid(citizen):
			continue
		if citizen.has_active_overtime(workday_id) and citizen.overtime_until_workday_id > workday_id:
			continue
		citizen.clear_daily_order(workday_id)
		if citizen.overtime_until_workday_id == workday_id:
			citizen.clear_expired_overtime(workday_id + 1)
	if citizen_ai != null:
		citizen_ai.request_decision_refresh()
	if citizen_daily_order_service != null:
		citizen_daily_order_service.sync_overtime_scope_indicators()


func _clear_expired_overtime_orders() -> void:
	for citizen in citizens:
		if is_instance_valid(citizen):
			citizen.clear_expired_overtime(day_cycle.current_day)


func _reset_building_night_work_toggles() -> void:
	# Keep an active overnight scope visible through the following workday. The
	# previous implementation cleared this at 08:00 while its workers still had
	# overtime, turning the next click into an accidental extension.
	if citizen_daily_order_service != null:
		citizen_daily_order_service.sync_overtime_scope_indicators()


func _resume_overtime_daily_orders() -> void:
	if citizen_daily_order_service != null:
		citizen_daily_order_service.resume_overtime_daily_orders()


func _check_daily_departures() -> void:
	settlement_survival_service.check_daily_departures()


func _on_citizen_leaving_departed(citizen: Citizen) -> void:
	citizen_lifecycle_service.on_citizen_leaving_departed(citizen)


func _total_game_minutes() -> float:
	return float(day_cycle.current_day - 1) * 24.0 * 60.0 + game_minutes


func _is_night() -> bool:
	return clock.is_night()

func _has_lit_communal_fire() -> bool:
	for record in building_registry.records():
		var building: Node3D = record.node
		if is_instance_valid(building) and BuildingTypes.is_fire_source(record.building_type) and _is_fire_lit(building):
			return true
	return false

func _refresh_living_statuses() -> void:
	if citizen_living_status_service == null:
		return
	citizen_living_status_service.refresh_all(citizens, _has_lit_communal_fire(), _is_night())

func _refresh_living_status(citizen: Citizen) -> void:
	if citizen_living_status_service == null:
		return
	citizen_living_status_service.refresh_citizen(citizen, _has_lit_communal_fire(), _is_night())

func _is_work_time() -> bool:
	return day_cycle.is_work_time(settlement.workday_hours)


func _is_citizen_work_time(citizen: Citizen) -> bool:
	if not is_instance_valid(citizen) or citizen.is_recovering(day_cycle.current_day):
		return false
	return _is_work_time() or citizen.has_active_overtime(day_cycle.current_day)

func _start_meal(hour: int) -> void:
	canteen_service.start_meal(hour)


func _start_park_rest(cooks_only: bool) -> void:
	if citizen_needs_service == null:
		return
	var sent := citizen_needs_service.request_scheduled_rest(cooks_only, citizens, park_positions)
	if sent > 0:
		_update_interface("%02d:00 park break: %d residents are resting." % [int(game_minutes) / 60, sent])



func _cancel_canteen_delivery() -> void:
	canteen_service.cancel_canteen_delivery()



func _publish_courier_tasks(dispatcher: RefCounted) -> void:
	if courier_task_publisher != null:
		courier_task_publisher.publish_courier_tasks(dispatcher)


func _firewood_task_priority(building: Node3D, fire_state: RefCounted) -> int:
	var phase: int = fire_state.phase_at(int(game_minutes))
	var is_main := building == campfire_node
	if phase == FireSourceStateScript.Phase.EMBERS or fire_state.fuel <= 1:
		return 120 if is_main else 115
	if phase == FireSourceStateScript.Phase.DYING:
		return 112 if is_main else 110
	return 108 if is_main else 105


func _reconcile_repair_reservations() -> void:
	# A repair delivery can be interrupted by the end-of-day scheduler or a route reset.
	# Return its reservation when no courier still owns it, otherwise the building
	# can remain permanently reserved without ever being repaired.
	for record in building_registry.records():
		var building := record.node
		if not is_instance_valid(building):
			continue
		var state: BuildingRuntimeStateScript = record.runtime_state()
		if not state.repair_reserved:
			continue
		var has_carrier := false
		for citizen in citizens:
			if citizen != null and citizen.state in [Citizen.State.TO_CONSTRUCTION_PICKUP, Citizen.State.TO_CONSTRUCTION_SITE] and citizen.building_supply_kind == "repair" and citizen.construction_site == building:
				has_carrier = true
				break
		if not has_carrier:
			building.set_meta("repair_reserved", false)


func _construction_material_sources(resource_type: String, from_position: Vector3 = Vector3.ZERO) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if settlement.amount(resource_type) > 0:
		if not warehouse_positions.is_empty():
			for index in range(mini(warehouse_positions.size(), settlement.warehouses.size())):
				if settlement.warehouse_amount(resource_type, index) <= 0:
					continue
				var position := warehouse_positions[index]
				# The position keeps task identity stable enough to invalidate a task when
				# warehouses are demolished; the index makes pickup remove the same stock.
				sources.append({"kind": "storage", "id": "storage_%s" % _cell_from_position(position), "position": position, "warehouse_index": index})
			sources.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
				return from_position.distance_squared_to(left.position) < from_position.distance_squared_to(right.position)
			)
			return sources
		# Before the first warehouse is built, all resources live in the virtual
		# stockpile. Couriers pull from that unlimited reserve at the camp entrance
		# so the bootstrap warehouse and main campfire can still be supplied.
		sources.append({"kind": "open_storage", "id": "open_storage", "position": _get_nearest_delivery_position(from_position)})
	# Ground piles belong exclusively to cleaners. Construction starts only after
	# their contents have been delivered to the settlement stock.
	return sources


func _construction_source_available(resource_type: String, source: Dictionary) -> int:
	var warehouse_index := int(source.get("warehouse_index", -1))
	return settlement.warehouse_amount(resource_type, warehouse_index) if warehouse_index >= 0 else settlement.amount(resource_type)


func _is_courier_task_valid(task: RefCounted) -> bool:
	return courier_task_service.is_courier_task_valid(task)


func _start_courier_task(courier: Citizen, task: RefCounted) -> bool:
	return courier_task_service.start_courier_task(courier, task)



func _release_task_warehouse_reservation(task: RefCounted) -> void:
	courier_task_service.release_task_warehouse_reservation(task)


func _cancel_courier_task(courier: Citizen, task: RefCounted) -> void:
	courier_task_service.cancel_courier_task(courier, task)


func _set_canteen_delivery_state(active: bool, carrier: Citizen, amount: int) -> void:
	pending_canteen_delivery = active
	pending_canteen_carrier = carrier
	pending_canteen_delivery_amount = amount


func _set_canteen_food(value: int) -> void:
	canteen_food = value


func _is_canteen_delivery_in_progress() -> bool:
	return is_instance_valid(pending_canteen_carrier) and pending_canteen_carrier.state in [Citizen.State.TO_FOOD_PICKUP, Citizen.State.TO_CANTEEN_DELIVERY]


func _set_dig_mode(value: bool) -> void:
	dig_mode = value


func _set_build_mode(value: String) -> void:
	build_mode = value


func _reconcile_construction_reservations(site: ConstructionSite) -> void:
	if courier_task_service != null:
		courier_task_service.reconcile_construction_reservations(site)

func _preferred_construction_site() -> ConstructionSite:
	return construction_priority_service.preferred_construction_site() if construction_priority_service != null else null


func _builder_count(site_node: Node3D) -> int:
	var count := 0
	for citizen in citizens:
		if citizen.is_building_site(site_node):
			count += 1
	return count

func _building_power(site_node: Node3D) -> float:
	var power := 0.0
	for citizen in citizens:
		if citizen.is_building_site(site_node):
			power += citizen.get_efficiency("construction")
	if is_instance_valid(player_work_target) and player_work_target == site_node and player_citizen != null:
		power += player_citizen.get_efficiency("construction")
	return power





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
	return ["Tent", "Earth", "Clay", "Wood", "Stone", "Brick"][settlement.era]


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
	camera_controller = CameraControllerScene.instantiate() as CameraController
	add_child(camera_controller)
	world_setup = WorldSetupScene.instantiate() as WorldSetup
	world_setup.setup(camera, CELL_SIZE, BOARD_CELLS, trail_field)
	add_child(world_setup)
	world_setup.build(self)
	_update_daylight()
	_refresh_navigation_grid()
	_move_selection(Vector3.ZERO)


## Presentation ownership boundary for naturally occurring world objects.
## Their mutable gameplay records remain registered with the relevant feature
## services; reparenting them here must not change routing or resource logic.
func add_landscape_object(node: Node) -> void:
	var territory := get_node_or_null("Terrain3dWorld") as TerritoryBase
	if territory != null:
		territory.add_landscape_object(node)
	else:
		add_child(node)


func _update_trail_overlay() -> void:
	if world_setup.trail_overlay_material == null or trail_field == null:
		return
	world_setup.trail_overlay_material.set_shader_parameter("trail_map", trail_field.flush_texture(runtime_seconds))


func _record_trail_movement(citizen_id: int, position_on_board: Vector3) -> void:
	if settlement.era != SettlementState.Era.TENT or trail_field == null:
		return
	trail_field.record_walker_position(citizen_id, position_on_board, settlement.road_walking_order_enabled)

func _refresh_navigation_grid() -> void:
	if navigation_bridge != null:
		navigation_blocked_cells = navigation_bridge.refresh_navigation_grid(
			terrain_blocked_cells,
			building_registry.records(),
			service_pockets,
			NAVIGATION_CLEARANCE_MARGIN
		)

func _rebuild_navigation_obstacles() -> void:
	_refresh_navigation_grid()



func _pond_access_position(from: Vector3, pond_center: Vector3) -> Vector3:
	var candidates := [
		pond_center + Vector3(3.0, 0.0, 0.0),
		pond_center + Vector3(-3.0, 0.0, 0.0),
		pond_center + Vector3(0.0, 0.0, 3.0),
		pond_center + Vector3(0.0, 0.0, -3.0)
	]
	var best := Vector3.INF
	var best_distance := INF
	for candidate in candidates:
		if navigation_blocked_cells.has(_cell_from_position(candidate)):
			continue
		var distance := from.distance_squared_to(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	if best == Vector3.INF:
		return Vector3.INF
	var terrain_height := _terrain_height_at(best.x, best.z, pond_center.y)
	if not is_nan(terrain_height):
		best.y = terrain_height
	return best


func _resource_access_position(from: Vector3, resource_position: Vector3) -> Vector3:
	var resource_cell := _cell_from_position(resource_position)
	var best := Vector3.INF
	var best_distance := INF
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var cell: Vector2i = resource_cell + offset
		if not _is_board_cell(cell) or navigation_blocked_cells.has(cell):
			continue
		var candidate: Vector3 = nav_grid.cell_center(cell) if nav_grid != null else Vector3((cell.x + 0.5) * CELL_SIZE, 0.0, (cell.y + 0.5) * CELL_SIZE)
		if not _is_route_reachable(from, candidate):
			continue
		var distance := from.distance_squared_to(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best



func _create_citizens() -> void:
	var spawn_anchor: Vector3 = _entrance_anchor_position() + Vector3(0.0, 0.0, 2.0)
	var columns := 3
	for index in range(POPULATION):
		var col := index % columns
		var row := index / columns
		var spawn_position := spawn_anchor + Vector3((col - 1) * 1.5, 0.0, row * 1.4)
		var terrain_height := _terrain_height_at(spawn_position.x, spawn_position.z, 0.0)
		if not is_nan(terrain_height):
			spawn_position.y = terrain_height + 0.08
		_add_citizen(spawn_position, "unassigned")
	if not citizens.is_empty():
		citizens[random.randi_range(0, citizens.size() - 1)].is_jack_of_all_trades = true
	if hero_citizen != null:
		for citizen in citizens:
			citizen.set_squad(&"hero_squad", hero_citizen.ai_id, true)


func _bind_hero_squad_to_settlement(squad_settlement_id: StringName) -> void:
	if hero_citizen == null:
		return
	for citizen in citizens:
		if citizen.squad_state.is_in_squad() and citizen.squad_state.squad_leader_id == hero_citizen.ai_id:
			citizen.settlement_id = squad_settlement_id


func _add_citizen(spawn_position: Vector3, primary_specialization := "") -> void:
	var citizen: Citizen = CitizenActorScene.instantiate()
	citizen.position = spawn_position
	if citizens.size() < POPULATION:
		citizen.gender = "male" if citizens.size() % 2 == 0 else "female"
	if hero_citizen == null:
		citizen.gender = "male"
		citizen.skin_color = Color("f1c09a")
		citizen.hair_color = Color("3b2219")
		citizen.shirt_color = Color("1e3d59")
		citizen.pants_color = Color("ff6e40")
	citizen.random = random
	add_child(citizen)
	citizen.simulation = self
	citizen.setup_specialization(primary_specialization if not primary_specialization.is_empty() else "unassigned")
	_wire_citizen(citizen)
	citizens.append(citizen)
	citizen.ai_id = _next_ai_citizen_id
	_next_ai_citizen_id += 1
	citizen_ai.register_citizen(citizen.ai_id, SettlementCitizenActuatorScript.new(citizen, _ai_target_for_key))
	citizen.tree_exiting.connect(_on_ai_citizen_exiting.bind(citizen.ai_id), CONNECT_ONE_SHOT)
	if citizens.size() > POPULATION:
		settlement.add(ResourceIds.FOOD, random.randi_range(2, 5))
	if hero_citizen == null:
		hero_citizen = citizen
		citizen.set_hero(true)
		citizen.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
	else:
		# Before the first campfire the settlement has no administration. Initial
		# residents can receive explicit daily orders to bootstrap it.
		citizen.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK if not is_instance_valid(campfire_node) else Citizen.EmploymentState.UNREGISTERED
	if citizen_needs_service != null:
		citizen_needs_service.schedule_toilet(citizen.ai_id)


## Attaches navigation, the registration service and every gameplay signal to a
## citizen. The caller must already have added the node to the tree, set
## `simulation` and chosen the specialization. Shared by initial spawning and
## save restore so a new signal only needs to be registered in one place.
func _wire_citizen(citizen: Citizen) -> void:
	citizen.setup_navigation(_find_path_around_houses, _get_nearest_delivery_position, _resolve_building_queue_position, _movement_speed_modifier_at, _navigation_revision, _record_trail_movement, _is_route_reachable, _complete_building_queue_arrival, _release_building_queue_entry, _find_recovery_path, _is_route_path_clear)
	citizen.setup_registration_service(_can_start_registration, _registration_duration)
	if actuator_bridge != null:
		actuator_bridge.wire_citizen(citizen)
	citizen.tree_harvested.connect(_on_tree_harvested)
	citizen.employment_processing_finished.connect(_on_employment_processing_finished)
	citizen.arrival_greeter_ready.connect(_on_arrival_greeter_ready)
	citizen.outside_work_departed.connect(_on_outside_work_departed)
	citizen.citizen_leaving_departed.connect(_on_citizen_leaving_departed)


func _create_starter_backpack() -> void:
	if settlement.warehouse_ever_built:
		return
	var anchor := _entrance_anchor_position() + Vector3(0.0, 0.0, 2.0)
	backpack_position = anchor + Vector3(-1.5, 0.0, 0.7)
	var terrain_height := _terrain_height_at(backpack_position.x, backpack_position.z, 0.0)
	if not is_nan(terrain_height):
		backpack_position.y = terrain_height + 0.08
	_create_resource_pile(backpack_position, settlement.backpack, true)
	if not resource_piles.is_empty():
		backpack_node = resource_piles[resource_piles.size() - 1].node


func _on_ai_citizen_exiting(citizen_id: int) -> void:
	if trail_field != null:
		trail_field.forget_walker(citizen_id)
	if is_instance_valid(citizen_ai):
		citizen_ai.unregister_citizen(citizen_id)
	if canteen_service != null:
		canteen_service.remove_citizen(citizen_id)
	if citizen_needs_service != null:
		citizen_needs_service.remove_citizen(citizen_id)


func _is_ai_citizen_id_alive(citizen_id: int) -> bool:
	for citizen in citizens:
		if is_instance_valid(citizen) and citizen.ai_id == citizen_id:
			return true
	return false


func _citizen_for_ai_id(citizen_id: int) -> Citizen:
	if citizen_id <= 0:
		return null
	for citizen in citizens:
		if is_instance_valid(citizen) and citizen.ai_id == citizen_id:
			return citizen
	return null


func _ai_target_for_key(target_key: StringName) -> Node3D:
	var parts := String(target_key).split(":")
	if parts.size() != 3:
		return null
	var cell := Vector2i(int(parts[1]), int(parts[2]))
	match parts[0]:
		"building":
			for record in building_registry.records():
				var building := record.node as Node3D
				if is_instance_valid(building) and _cell_from_position(building.global_position) == cell:
					return building
		"construction":
			for site: ConstructionSite in construction_sites:
				if site.cell == cell and is_instance_valid(site.node):
					return site.node
		"demolition":
			for site: DemolitionSite in demolition_sites:
				if is_instance_valid(site.building) and _cell_from_position(site.building.global_position) == cell:
					return site.building
		"dig":
			var site := excavation_service.dig_site_at(cell)
			return site.node if is_instance_valid(site.node) else null
		"factory":
			for factory: Node3D in factories:
				if is_instance_valid(factory) and _cell_from_position(factory.global_position) == cell:
					return factory
	return null



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
	if not is_first_person or player_citizen == null:
		_player_toilet_notified = false
		return
	var has_request := citizen_needs_service.has_toilet_request(player_citizen.ai_id)
	if has_request and not _player_toilet_notified:
		_player_toilet_notified = true
		var name := player_citizen.role_label() if player_citizen != hero_citizen else S.HERO_NAME
		_update_interface(S.TOILET_NEED_HINT % name)
	elif not has_request:
		_player_toilet_notified = false



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
	if settlement != null and settlement.is_research_completed("outside_work_earnings"):
		return OUTSIDE_WORK_UPGRADE_REWARD
	return random.randi_range(OUTSIDE_WORK_BASE_REWARD_MIN, OUTSIDE_WORK_BASE_REWARD_MAX)



func _send_selected_resident_to_outside_work() -> void:
	if not is_instance_valid(selected_builder) or selected_builder.is_player_controlled:
		_update_interface("Select an AI-controlled Courier before sending them to outside work.")
		return
	if not selected_builder.can_handle_entry_logistics() or not _is_work_time():
		_update_interface("Outside work requires a Courier.")
		return
	var worker_id := selected_builder.get_stable_id()
	if outside_workers.has(worker_id):
		_update_interface("This resident is already working in a neighboring settlement.")
		return
	var reward := _outside_work_reward()
	if courier_dispatcher.task_for(selected_builder) != null:
		_update_interface("Courier is already assigned to a logistics task.")
		return
	courier_dispatcher.publish(StringName("outside_work_%d" % worker_id), CourierTask.Kind.OUTSIDE_WORK, 85, entrance_stone.global_position, entrance_stone.global_position, {"courier": selected_builder, "reward": reward})
	_request_courier_dispatch()
	_update_interface("Outside work assigned. The courier is heading to the entrance sign.")


func _on_outside_work_departed(worker: Citizen) -> void:
	var task: CourierTask = courier_dispatcher.task_for(worker)
	if task == null or task.kind != CourierTask.Kind.OUTSIDE_WORK:
		return
	var reward := int(task.payload.get("reward", OUTSIDE_WORK_BASE_REWARD_MIN))
	var worker_id := worker.get_stable_id()
	outside_workers[worker_id] = {
		"citizen": worker,
		"return_at_minute": _absolute_game_minutes() + OUTSIDE_WORK_DURATION_MINUTES,
		"reward": reward,
	}
	worker.visible = false
	worker.process_mode = Node.PROCESS_MODE_DISABLED
	courier_dispatcher.complete_for(worker)
	_update_interface("Courier left for outside work and will return in 24 hours with %d coins." % reward)

func _absolute_game_minutes() -> int:
	return (day_cycle.current_day - 1) * SimulationClock.MINUTES_PER_DAY + floori(clock.minutes)

func _return_outside_workers() -> void:
	var returned_any := false
	for worker_id in outside_workers.keys():
		var assignment := outside_workers[worker_id] as Dictionary
		if assignment.has("return_at_minute"):
			if _absolute_game_minutes() < int(assignment.return_at_minute):
				continue
		elif day_cycle.current_day < int(assignment.get("return_day", 0)):
			continue
		var worker := assignment.get("citizen") as Citizen
		var reward: int = int(assignment.get("reward", OUTSIDE_WORK_BASE_REWARD_MIN))
		if is_instance_valid(worker):
			worker.process_mode = Node.PROCESS_MODE_INHERIT
			worker.visible = true
			worker.global_position = entrance_stone.global_position + Vector3(0.8, 0.08, 1.2)
			worker.idle()
			settlement.money += reward
			last_citizen_positions[worker_id] = worker.global_position
		outside_workers.erase(worker_id)
		returned_any = true
		_update_interface("A resident returned from outside work with %d coins." % reward)
	if returned_any and citizen_ai != null:
		citizen_ai.request_decision_refresh()


func _show_materials_factory_menu() -> void:
	if selected_materials_factory == null:
		return
	ui_manager.materials_factory_menu.visible = true
	ui_manager.materials_factory_menu_title.text = "Materials factory\nAssign workers to produce materials."

func _update_building_research(delta: float) -> void:
	if settlement.active_research_tech_id == "":
		return

	var tech_id := settlement.active_research_tech_id
	if not BuildingCatalog.RESEARCH_TECHS.has(tech_id):
		_cancel_active_building_research(true, "Research cancelled: invalid technology.")
		return
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[tech_id]
	if not is_instance_valid(campfire_node) or not _is_fire_lit(campfire_node):
		_cancel_active_building_research(true, "Research cancelled: the Campfire is unavailable. Resources refunded.")
		return
	var worker: Citizen = null

	for citizen in citizens:
		if citizen.ai_id == settlement.active_research_worker_id:
			worker = citizen
			break

	if worker == null:
		_cancel_active_building_research(true, "Research cancelled: researcher citizen is no longer available. Resources refunded.")
		return

	# The researcher must be physically at the campfire work position
	# (FPP researcher/official) or actively performing a daily research order.
	var is_at_research_position := worker.work_position_locked and worker.work_position_role in ["researcher", "official"] and worker.work_position_node == campfire_node
	if not is_at_research_position and worker.state != Citizen.State.RESEARCHING:
		_cancel_active_building_research(true, "Research cancelled: researcher stopped working. Resources refunded.")
		return

	var skill_name: String = tech.required_skill
	var skill_val := float(worker.skills.get(skill_name, 0.0))
	var speed_mult := 1.0 + skill_val

	var research_pos: Vector3 = campfire_node.get_meta("service_position", campfire_node.global_position)
	if worker.global_position.distance_to(research_pos) > 0.5:
		return
	building_research_service.advance_active(delta, speed_mult)

	if ui_manager.research_menu != null and ui_manager.research_menu.visible:
		if research_menu_controller != null:
			research_menu_controller.refresh_research_menu()

	if building_research_service.is_active_complete():
		var completion: Dictionary = building_research_service.complete_active()
		var skill_to_upgrade: String = str(completion.get("reward_skill", "construction"))
		worker.skills[skill_to_upgrade] = minf(1.0, float(worker.skills.get(skill_to_upgrade, 0.0)) + 0.20)

		# Do not disrupt a player-controlled citizen who is still at the post.
		if not worker.is_player_controlled:
			if worker.permanent_role == "official" and is_instance_valid(campfire_node):
				worker.assign_official_work(campfire_node.get_meta("service_position", campfire_node.global_position))
			else:
				worker.idle()
		var b_name := str(completion.get("display_name", tech_id))
		_update_interface("Research completed: %s unlocked! %s skill improved by 20%%." % [b_name, skill_to_upgrade.capitalize()])

		if campfire_menu_controller != null:
			campfire_menu_controller.refresh_campfire_menu()
		if building_menu_controller != null:
			building_menu_controller.refresh_build_menu()
		if ui_manager.research_menu != null and ui_manager.research_menu.visible:
			if research_menu_controller != null:
				research_menu_controller.refresh_research_menu()

func _cancel_active_building_research(refund: bool, message: String) -> void:
	var worker_id := settlement.active_research_worker_id
	var worker: Citizen = null
	for citizen in citizens:
		if citizen.ai_id == worker_id:
			worker = citizen
			break
	if worker != null:
		if worker.permanent_role == "official" and is_instance_valid(campfire_node):
			worker.assign_official_work(campfire_node.get_meta("service_position", campfire_node.global_position))
		else:
			worker.idle()
	building_research_service.cancel_active(refund)
	_update_interface(message)
	if campfire_menu_controller != null:
		campfire_menu_controller.refresh_campfire_menu()


func _handle_civic_post_assignment() -> void:
	var centre := selected_campfire if is_instance_valid(selected_campfire) else _employment_centre_building()
	if not is_instance_valid(centre) or not settlement.is_research_completed("official"):
		return
	var researcher := _daily_researcher_at(centre)
	if researcher == null:
		_update_interface("Assign a daily researcher and wait until they reach the civic post.")
		return
	_appoint_official(researcher, centre)


func _daily_researcher_at(centre: Node3D) -> Citizen:
	if not is_instance_valid(centre):
		return null
	var position: Vector3 = centre.get_meta("service_position", centre.global_position)
	for citizen in citizens:
		if is_instance_valid(citizen) and citizen.daily_order_role == "researcher" and citizen.global_position.distance_to(position) <= OFFICER_POST_RADIUS:
			return citizen
	return null

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
	build_category = category
	build_menu_is_job_menu = false
	build_menu_is_daily_order_menu = false
	if building_menu_controller != null:
		building_menu_controller.refresh_build_menu()
	if build_category.is_empty() and not build_menu_is_global:
		_show_selected_citizen_menu()


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
	match role:
		"construction": return ["builders_guild", "construction_company"]
		"forestry": return ["sawmill"]
		"farming": return ["farm"]
		"gather_food": return ["straw_forager_tent", "tarp_forager_tent"]
		"gather_branches", "gather_grass": return ["straw_materials_yard", "tarp_materials_yard"]
		"cook": return BuildingTypes.KITCHEN_TYPES
		"teacher": return ["school"]
		"seller": return BuildingTypes.MARKET_TYPES
		"factory_worker": return BuildingTypes.FACTORY_TYPES
		"engineer": return ["materials_factory"]
		"craftsman": return ["straw_craft_tent", "tarp_craft_tent"]
		"official": return OFFICIAL_WORKPLACE_TYPES
	return []


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
	if not is_instance_valid(building):
		return false
	var building_type := building_registry.building_type_for_node(building)
	for role in ["construction", "forestry", "farming", "gather_food", "gather_branches", "gather_grass", "cook", "teacher", "seller", "factory_worker", "engineer", "craftsman", "official"]:
		if building_type in _employer_types_for_role(role) or (building_zone_service != null and building_zone_service.supports_role(building, StringName(role))):
			return true
	return false


func _building_supports_role(building: Node3D, role: String) -> bool:
	if not is_instance_valid(building):
		return false
	var building_type := building_registry.building_type_for_node(building)
	return building_type in _employer_types_for_role(role) or (building_zone_service != null and building_zone_service.supports_role(building, StringName(role)))


func _employer_capacity(role: String, building: Node3D) -> int:
	if building_zone_service != null:
		var zone_capacity: int = int(building_zone_service.role_capacity(building, StringName(role)))
		if zone_capacity > 0:
			return zone_capacity
	if role == "construction":
		return 3 if building_registry.building_type_for_node(building) == "construction_company" else 1
	if role == "factory_worker":
		return int(building.get_meta("required_factory_workers", 1))
	if role == "craftsman":
		var type := building_registry.building_type_for_node(building)
		return 2 if type == "tarp_craft_tent" else 1
	if role == "gather_food":
		var type := building_registry.building_type_for_node(building)
		return 4 if type == "tarp_forager_tent" else 2
	if role in ["gather_branches", "gather_grass"]:
		var type := building_registry.building_type_for_node(building)
		return 4 if type == "tarp_materials_yard" else 2
	return 1

func _set_build_placement_ui_visible(is_visible: bool) -> void:
	if ui_manager.build_menu != null:
		ui_manager.build_menu.visible = is_visible and (selected_builder != null or build_menu_is_global)
	if ui_manager.build_toggle_btn != null:
		ui_manager.build_toggle_btn.visible = is_visible and not is_first_person
	if ui_manager.message_log_panel != null:
		ui_manager.message_log_panel.visible = is_visible


func _select_build_mode(next_mode: String) -> void:
	if not _can_hero_build():
		_update_interface("Only the hero can approve construction decisions.")
		return
	if next_mode == "tent" and clock.hour() >= 22:
		_update_interface("The temporary tent must be marked before 22:00.")
		return
	var placement_state: Dictionary = building_availability_service.placement_state_with_inventory(next_mode, pocket)
	if not bool(placement_state.allowed):
		_update_interface(str(placement_state.message))
		return
	if not village_territory_service.has_flag():
		if next_mode != "settlement_flag":
			_update_interface(village_territory_service.placement_message(village_territory_service.REASON_NO_FLAG))
			return
	elif not village_territory_service.has_campfire():
		if next_mode != "campfire" and next_mode != "warehouse":
			_update_interface(village_territory_service.placement_message(village_territory_service.REASON_NO_CAMPFIRE))
			return
	build_mode = next_mode
	build_rotation_quarters = 0
	world_setup.selection_marker.visible = true
	_move_selection(selected_world_position)
	_set_build_placement_ui_visible(false)
	_show_territory_overlay(true)
	if is_first_person:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_interface("%s selected. Choose a clear point; Q/E rotates the building." % build_mode.capitalize())

func _cancel_build_action() -> void:
	build_mode = ""
	build_rotation_quarters = 0
	dig_mode = false
	world_setup.selection_marker.visible = false
	world_setup.preview_entrance_marker.visible = false
	world_setup.preview_back_entrance_marker.visible = false
	ui_manager.build_menu.visible = false
	build_menu_is_global = false
	selected_builder = null
	_show_territory_overlay(false)
	_set_build_placement_ui_visible(true)
	_update_interface("Construction mode cancelled.")

func _on_context_menu_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_close_context_menus()
		get_viewport().set_input_as_handled()


func _is_first_person_menu_open() -> bool:
	if not is_first_person:
		return false
	if pocket_menu_open or ui_manager.build_menu.visible:
		return true
	if ui_manager.entrance_menu.visible or ui_manager.house_menu.visible or ui_manager.school_menu.visible or ui_manager.materials_factory_menu.visible or ui_manager.campfire_menu.visible or ui_manager.market_menu.visible or ui_manager.warehouse_menu.visible or ui_manager.building_menu.visible:
		return true
	if ui_manager.entrance_order_modal != null and ui_manager.entrance_order_modal.visible:
		return true
	if ui_manager.campfire_orders_menu != null and ui_manager.campfire_orders_menu.visible:
		return true
	if ui_manager.campfire_story_menu != null and ui_manager.campfire_story_menu.visible:
		return true
	if ui_manager.research_menu != null and ui_manager.research_menu.visible:
		return true
	if ui_manager.workforce_menu != null and ui_manager.workforce_menu.visible:
		return true
	if ui_manager.decision_menu != null and ui_manager.decision_menu.visible:
		return true
	if ui_manager.message_log_panel != null and ui_manager.message_log_panel.is_modal_visible():
		return true
	return false


func _update_first_person_mouse_and_crosshair() -> void:
	if not is_first_person:
		return
	var menu_open := _is_first_person_menu_open()
	if ui_manager.crosshair != null:
		ui_manager.crosshair.visible = not menu_open
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED)


func _close_context_menus() -> void:
	build_mode = ""
	dig_mode = false
	world_setup.selection_marker.visible = false
	_show_territory_overlay(false)
	is_rotating_camera = false
	ui_manager.entrance_menu.visible = false
	if ui_manager.entrance_order_modal != null:
		ui_manager.entrance_order_modal.visible = false
	ui_manager.house_menu.visible = false
	ui_manager.school_menu.visible = false
	ui_manager.materials_factory_menu.visible = false
	ui_manager.build_menu.visible = false
	ui_manager.campfire_menu.visible = false
	if ui_manager.campfire_orders_menu != null:
		ui_manager.campfire_orders_menu.visible = false
	ui_manager.market_menu.visible = false
	ui_manager.warehouse_menu.visible = false
	ui_manager.building_menu.visible = false
	if ui_manager.research_menu != null:
		ui_manager.research_menu.visible = false
	if ui_manager.decision_menu != null:
		ui_manager.decision_menu.visible = false
	if ui_manager.campfire_story_menu != null:
		ui_manager.campfire_story_menu.visible = false
	if ui_manager.message_log_panel != null:
		ui_manager.message_log_panel.close_modal()
	if pocket_take_menu_controller != null:
		pocket_take_menu_controller.close_pocket_take_menu()
	if workforce_menu_controller != null:
		workforce_menu_controller.hide_workforce_menu()
	selected_house = null
	selected_entrance = null
	selected_school = null
	selected_materials_factory = null
	selected_campfire = null
	selected_market = null
	selected_warehouse = null
	selected_building = null
	selected_builder = null
	build_category = ""
	build_menu_is_job_menu = false
	build_menu_is_daily_order_menu = false
	build_menu_is_global = false
	if building_menu_controller != null:
		building_menu_controller.refresh_build_menu()
	if is_first_person and not _is_first_person_menu_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _handle_menu_right_click():
			get_viewport().set_input_as_handled()


func _handle_menu_right_click() -> bool:
	if ui_manager.build_menu.visible:
		if not build_category.is_empty():
			_open_build_category("")
		elif build_menu_is_job_menu or build_menu_is_daily_order_menu:
			_close_assignment_submenu()
		else:
			ui_manager.build_menu.visible = false
			build_menu_is_global = false
			if selected_builder != null:
				selected_builder = null
			if building_menu_controller != null:
				building_menu_controller.refresh_build_menu()
		if is_first_person and not _is_first_person_menu_open():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return true
	if pocket_menu_open:
		if pocket_take_menu_controller != null:
			pocket_take_menu_controller.close_pocket_take_menu()
		return true
	if ui_manager.campfire_orders_menu != null and ui_manager.campfire_orders_menu.visible:
		ui_manager.campfire_orders_menu.visible = false
		ui_manager.campfire_menu.visible = true
		return true
	if ui_manager.campfire_story_menu != null and ui_manager.campfire_story_menu.visible:
		ui_manager.campfire_story_menu.visible = false
		ui_manager.campfire_menu.visible = true
		return true
	if ui_manager.research_menu != null and ui_manager.research_menu.visible:
		ui_manager.research_menu.visible = false
		ui_manager.campfire_menu.visible = true
		return true
	if ui_manager.workforce_menu != null and ui_manager.workforce_menu.visible:
		if workforce_menu_controller != null:
			workforce_menu_controller.hide_workforce_menu()
		ui_manager.campfire_menu.visible = true
		return true
	if ui_manager.entrance_order_modal != null and ui_manager.entrance_order_modal.visible:
		ui_manager.entrance_order_modal.visible = false
		ui_manager.entrance_menu.visible = true
		return true
	if ui_manager.message_log_panel != null and ui_manager.message_log_panel.is_modal_visible():
		ui_manager.message_log_panel.close_modal()
		return true
	var any_menu_visible := ui_manager.entrance_menu.visible or ui_manager.house_menu.visible or ui_manager.school_menu.visible or ui_manager.materials_factory_menu.visible or ui_manager.campfire_menu.visible or ui_manager.market_menu.visible or ui_manager.warehouse_menu.visible or ui_manager.building_menu.visible
	if ui_manager.decision_menu != null and ui_manager.decision_menu.visible:
		any_menu_visible = true
	if any_menu_visible:
		_close_context_menus()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_5 and event.pressed and not event.echo:
		if SaveGameServiceScript.save_quicksave(self):
			_update_interface("Игра сохранена (клавиша 5)")
		else:
			_update_interface("Ошибка сохранения игры")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_6 and event.pressed and not event.echo:
		if SaveGameServiceScript.has_quicksave():
			if SaveGameServiceScript.load_quicksave(self):
				_update_interface("Игра загружена (клавиша 6)")
			else:
				_update_interface("Ошибка загрузки игры")
		else:
			_update_interface("Сохранение не найдено")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_F and event.ctrl_pressed and event.pressed and not event.echo:

		if OS.is_debug_build():
			_grant_debug_resources()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.keycode == KEY_DELETE and event.pressed and not event.echo:
		if is_instance_valid(selected_building):
			building_lifecycle_service.mark_building_for_demolition(selected_building)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.keycode == KEY_R and event.pressed and not event.echo:
		player_controller.toggle_hero_view()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_B and event.pressed and not event.echo:
		if _can_hero_build():
			_toggle_global_build_menu()
			if is_first_person:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if ui_manager.build_menu.visible else Input.MOUSE_MODE_CAPTURED)
		else:
			_update_interface(S.ONLY_HERO_CAN_APPROVE_BUILD)
		get_viewport().set_input_as_handled()
		return
	if not build_mode.is_empty() and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_Q, KEY_E]:
		build_rotation_quarters = posmod(build_rotation_quarters + (-1 if event.keycode == KEY_Q else 1), 4)
		_move_selection(selected_world_position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if pocket_menu_open:
			if pocket_take_menu_controller != null:
				pocket_take_menu_controller.close_pocket_take_menu()
			get_viewport().set_input_as_handled()
			return
	if is_first_person:
		if event is InputEventKey and event.keycode == KEY_T and event.pressed and not event.echo:
			if not _is_first_person_menu_open():
				if hero_pocket_service != null:
					hero_pocket_service.drop_pocket_on_ground()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo:
			player_controller.start_interaction(event.shift_pressed)
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventMouseMotion:
			if not _is_first_person_menu_open():
				player_yaw -= event.relative.x * 0.0035
				player_pitch = clampf(player_pitch - event.relative.y * 0.003, deg_to_rad(-70.0), deg_to_rad(65.0))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not build_mode.is_empty() and not _is_first_person_menu_open():
				var viewport_center := get_viewport().get_visible_rect().size * 0.5
				var build_point: Variant = _terrain_point_at_screen_position(viewport_center)
				if build_point != null:
					_place_building(build_point)
			elif not _is_first_person_menu_open():
				_first_person_select_at_crosshair()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if pocket_menu_open:
				if pocket_take_menu_controller != null:
					pocket_take_menu_controller.close_pocket_take_menu()
			elif not build_mode.is_empty():
				_cancel_build_action()
			else:
				player_controller.leave_first_person_to_hero_overview()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if get_viewport().gui_get_hovered_control() != null:
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		camera_distance = maxf(3.0, camera_distance - 2.0)
		if camera_controller != null:
			camera_controller.apply_position()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		camera_distance = minf(80.0, camera_distance + 2.0)
		if camera_controller != null:
			camera_controller.apply_position()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		is_panning_camera = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and (not build_mode.is_empty() or (selected_builder != null and dig_mode)):
			_cancel_build_action()
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			is_rotating_camera = true
			right_mouse_dragged = false
		else:
			is_rotating_camera = false
			if not right_mouse_dragged:
				_close_context_menus()
	elif event is InputEventMouseMotion:
		if is_rotating_camera:
			if event.relative.length_squared() > 0.0:
				right_mouse_dragged = true
			if camera_controller != null:
				camera_controller.rotate_yaw_pitch(event.relative)
		elif is_panning_camera:
			if camera_controller != null:
				camera_controller.pan(event.relative)
		elif not build_mode.is_empty() or (selected_builder != null and dig_mode):
			if get_viewport().gui_get_hovered_control() == null:
				var terrain_point: Variant = _terrain_point_at_screen_position(event.position)
				if terrain_point != null:
					_move_selection(terrain_point)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_builder != null and dig_mode:
			var dig_point: Variant = _terrain_point_at_screen_position(event.position)
			if dig_point != null:
				excavation_service.place_dig_site(dig_point)
		elif not build_mode.is_empty():
			var build_point: Variant = _terrain_point_at_screen_position(event.position)
			if build_point != null:
				_place_building(build_point)
		else:
			_select_citizen_at(event.position)

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
	var target := _first_person_target()
	if target.kind == "building" and is_instance_valid(target.node) and building_registry.building_type_for_node(target.node) in OFFICIAL_WORKPLACE_TYPES:
		selected_campfire = target.node
		selected_building = target.node
		if campfire_menu_controller != null:
			campfire_menu_controller.show_campfire_menu()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	_select_citizen_at(viewport_center)


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
	if building.has_meta("demolition_marker"):
		return
	var marker: Label3D = BillboardLabelScene.instantiate() as Label3D
	marker.text = "DEMOLISH"
	marker.position = Vector3(0.0, 5.2, 0.0)
	marker.font_size = 32
	marker.outline_size = 6
	marker.modulate = Color("ef4f45")
	building.add_child(marker)
	building.set_meta("demolition_marker", marker)

func _demolition_ready(site: DemolitionSite) -> bool:
	return building_lifecycle_service.demolition_ready(site)


func _finish_demolition(site: DemolitionSite) -> void:
	building_lifecycle_service.finish_demolition(site)

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
	if warehouse_index < 0:
		warehouse_index = _nearby_warehouse_index()
	var delivered_total := 0
	var summary: Array[String] = []
	for resource_type in _pocket_resources():
		var amount := hero_pocket_service.pocket_amount(resource_type) if hero_pocket_service != null else 0
		if amount <= 0:
			continue
		if warehouse_index >= 0 and not settlement.uses_virtual_storage() and not settlement.warehouse_accepts(warehouse_index, resource_type):
			_update_interface(S.WAREHOUSE_REJECTS_FORMAT % resource_type)
			continue
		var to_deliver := amount
		if not settlement.uses_virtual_storage():
			to_deliver = mini(amount, settlement.storage_room_for(resource_type))
		if to_deliver <= 0:
			continue
		var overflow := 0
		if warehouse_index >= 0 and not settlement.uses_virtual_storage():
			overflow = settlement.add_to_warehouse(resource_type, to_deliver, warehouse_index)
		else:
			settlement.add(resource_type, to_deliver)
		var actually_delivered := to_deliver - overflow
		if actually_delivered > 0:
			hero_pocket_service.remove_from_pocket(resource_type, actually_delivered) if hero_pocket_service != null else 0
			delivered_total += actually_delivered
			summary.append("%d %s" % [actually_delivered, resource_type])
	if delivered_total > 0:
		_update_interface(S.DELIVERED_TO_WAREHOUSE_SUMMARY % ", ".join(summary))
	elif _pocket_resources().is_empty():
		_update_interface(S.POCKET_EMPTY)
	else:
		_update_interface(S.WAREHOUSE_NO_ROOM)


func _deliver_one_pocket_to_warehouse(warehouse_index := -1) -> void:
	if warehouse_index < 0:
		warehouse_index = _nearby_warehouse_index()
	var resource_type := _primary_pocket_resource()
	if resource_type.is_empty():
		return
	var amount := hero_pocket_service.pocket_amount(resource_type) if hero_pocket_service != null else 0
	if amount <= 0:
		return
	if warehouse_index >= 0 and not settlement.uses_virtual_storage() and not settlement.warehouse_accepts(warehouse_index, resource_type):
		_update_interface(S.WAREHOUSE_REJECTS_FORMAT % resource_type)
		return
	var to_deliver := 1
	if not settlement.uses_virtual_storage():
		to_deliver = mini(1, settlement.storage_room_for(resource_type))
	if to_deliver <= 0:
		_update_interface(S.WAREHOUSE_NO_ROOM_FOR_RESOURCE % resource_type)
		return
	var overflow := 0
	if warehouse_index >= 0 and not settlement.uses_virtual_storage():
		overflow = settlement.add_to_warehouse(resource_type, to_deliver, warehouse_index)
	else:
		settlement.add(resource_type, to_deliver)
	var actually_delivered := to_deliver - overflow
	if actually_delivered <= 0:
		_update_interface(S.WAREHOUSE_NO_ROOM_IN_THIS % resource_type)
		return
	hero_pocket_service.remove_from_pocket(resource_type, actually_delivered) if hero_pocket_service != null else 0
	_update_interface(S.DELIVERED_ONE_TO_WAREHOUSE % [actually_delivered, resource_type, _format_pocket_hint()])


func _nearest_service_position(building: Node3D, from: Vector3) -> Vector3:
	if not is_instance_valid(building):
		return Vector3.INF
	if building.has_meta("service_positions"):
		var positions: Array = building.get_meta("service_positions")
		var best := Vector3.INF
		var best_distance := INF
		for value in positions:
			if value is Vector3:
				var position: Vector3 = value
				var distance := from.distance_squared_to(position)
				if distance < best_distance:
					best = position
					best_distance = distance
		if best != Vector3.INF:
			return best
	return building.get_meta("service_position", building.global_position)


func _exit_player_work_position() -> void:
	if player_citizen == null or not player_citizen.work_position_locked:
		return
	var was_official_appointment := player_citizen.work_position_role == "official" and not player_citizen.work_position_temporary
	player_citizen.exit_work_position()
	if was_official_appointment:
		_dismiss_official(player_citizen)
		_update_interface(S.LEFT_OFFICER_POST_FORMAT % player_citizen.role_label())
	else:
		_update_interface(S.LEFT_WORKPLACE_FORMAT % player_citizen.role_label())
	_refresh_interaction_hint()


func _occupy_workplace(workplace: Node3D) -> void:
	if not is_instance_valid(workplace) or player_citizen == null:
		return
	var building_type := building_registry.building_type_for_node(workplace)
	var is_official_building := building_type in OFFICIAL_WORKPLACE_TYPES
	var service_position := _nearest_service_position(workplace, player_citizen.global_position)
	# Move the citizen onto the nearest service position. Smooth walking can be
	# added later; the design requires automatic positioning at the workplace.
	player_citizen.global_position = service_position
	if is_official_building:
		if settlement.is_research_completed("official"):
			var current_officer := _officer_holder()
			if current_officer != null and current_officer != player_citizen:
				_update_interface(S.OFFICER_POSITION_TAKEN)
				return
			player_citizen.enter_work_position(service_position, "official", workplace, false)
			_appoint_official(player_citizen, workplace)
			if player_citizen.permanent_role != "official":
				player_citizen.exit_work_position()
				return
			_update_interface(S.HERO_BECAME_OFFICER)
		else:
			player_citizen.enter_work_position(service_position, "researcher", workplace, true)
			if research_menu_controller != null:
				research_menu_controller.show_research_menu()
			_update_interface(S.HERO_TOOK_RESEARCHER)
	else:
		var role := _role_for_workplace(workplace)
		if role.is_empty():
			return
		player_citizen.enter_work_position(service_position, role, workplace, true)
		_update_interface(S.TOOK_TEMP_ROLE_FORMAT % [player_citizen.role_label(), role.replace("_", " ")])
	_refresh_interaction_hint()


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
	var building_type := building_registry.building_type_for_node(building)
	for candidate in ["forestry", "farming", "gather_food", "gather_branches", "cook", "teacher", "seller", "factory_worker", "engineer", "official"]:
		if building_type in _employer_types_for_role(candidate):
			return candidate
	return ""



func _format_pocket_hint() -> String:
	return hero_pocket_service.format_pocket_hint() if hero_pocket_service != null else ""


func _home_occupancy_text() -> String:
	if player_citizen == null or player_citizen.home == null or not is_instance_valid(player_citizen.home):
		return ""
	var home := player_citizen.home
	var capacity := int(home.get_meta("housing_capacity", 1))
	var free_slots := int(home.get_meta("spawn_slots", capacity))
	var occupied := clampi(capacity - free_slots, 0, capacity)
	return S.HOME_OCCUPANCY_FORMAT % [occupied, capacity]


func _refresh_interaction_hint() -> void:
	if not is_first_person:
		ui_manager.interaction_hint_panel.visible = false
		return
	if _is_first_person_menu_open():
		ui_manager.interaction_hint_panel.visible = false
		return
	ui_manager.interaction_hint_panel.visible = true
	if pocket_menu_open:
		ui_manager.interaction_hint_panel.hint_label.text = S.CLOSE_MENU_HINT
		ui_manager.interaction_hint_panel.progress_bar.visible = false
		return
	if not interaction_action.is_empty():
		return
	var lines: Array[String] = []
	if player_citizen != null and not player_citizen.is_hero:
		var target := _first_person_target()
		if target.kind == "toilet":
			var needs_toilet := citizen_needs_service != null and citizen_needs_service.has_toilet_request(player_citizen.ai_id)
			if needs_toilet:
				lines.append(S.F_USE_TOILET_NEED)
			else:
				lines.append(S.F_USE_TOILET)
		lines.append(S.OBSERVE_HINT)
	else:
		var action_hint := first_person_hud_controller.first_person_action_hint() if first_person_hud_controller != null else ""
		if not action_hint.is_empty():
			lines.append(action_hint)
	lines.append(_format_pocket_hint())
	if not pocket.is_empty():
		lines.append(S.DROP_POCKET_HINT)
	var home_text := _home_occupancy_text()
	if not home_text.is_empty():
		lines.append(home_text)
	ui_manager.interaction_hint_panel.hint_label.text = "\n".join(lines)
	ui_manager.interaction_hint_panel.progress_bar.visible = false


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
	for cell in grass_sources:
		var source: GrassSourceRecordScript = grass_sources[cell]
		if source.remaining <= 0 or not is_instance_valid(source.node):
			continue
		var node_pos: Vector3 = source.node.global_position
		var dist := point.distance_to(node_pos)
		if dist <= best_dist:
			best_dist = dist
			best = node_pos
	return best


func _first_person_target() -> Dictionary:
	if player_controller != null:
		return player_controller.first_person_target()
	return {"kind": ""}


func _missing_site_materials_text(site: ConstructionSite) -> String:
	var parts: Array[String] = []
	for resource_type in site.required_materials:
		var required := int(site.required_materials.get(resource_type, 0))
		var delivered := int(site.delivered_materials.get(resource_type, 0))
		if delivered < required:
			parts.append("%s %d/%d" % [resource_type.capitalize(), delivered, required])
	return ", ".join(parts)


func _handle_sawmill_interaction(all: bool, sawmill_pos: Vector3) -> void:
	var wood_count := (hero_pocket_service.pocket_amount(ResourceIds.WOOD) if hero_pocket_service != null else 0) + (hero_pocket_service.pocket_amount(ResourceIds.LOGS) if hero_pocket_service != null else 0)
	if wood_count > 0:
		var delivered := 0
		if all:
			var wood_delivered := hero_pocket_service.remove_from_pocket(ResourceIds.WOOD, wood_count) if hero_pocket_service != null else 0
			var logs_delivered := hero_pocket_service.remove_from_pocket(ResourceIds.LOGS, wood_count - wood_delivered) if hero_pocket_service != null else 0
			delivered = wood_delivered + logs_delivered
		else:
			delivered = hero_pocket_service.remove_from_pocket(ResourceIds.WOOD, 1) if hero_pocket_service != null else 0
			if delivered == 0:
				delivered = hero_pocket_service.remove_from_pocket(ResourceIds.LOGS, 1) if hero_pocket_service != null else 0
		if delivered > 0:
			var stock := _sawmill_stock(sawmill_pos)
			stock.logs = int(stock.logs) + delivered
			sawmills.store(sawmill_pos, stock)
			_update_interface(S.DELIVERED_WOOD_TO_SAWMILL % delivered)
		_refresh_interaction_hint()
		return
	var sawmill_stock := _sawmill_stock(sawmill_pos)
	var available_boards := int(sawmill_stock.boards)
	if available_boards > 0 and _pocket_has_room():
		var take_amount := mini(available_boards, hero_pocket_service.pocket_space_for(ResourceIds.BOARDS) if hero_pocket_service != null else 0) if all else 1
		take_amount = hero_pocket_service.add_to_pocket(ResourceIds.BOARDS, take_amount) if hero_pocket_service != null else 0
		if take_amount > 0:
			sawmill_stock.boards = int(sawmill_stock.boards) - take_amount
			sawmills.store(sawmill_pos, sawmill_stock)
			_update_interface(S.TOOK_BOARDS_FROM_SAWMILL % take_amount)
	_refresh_interaction_hint()


func _handle_warehouse_interaction(all: bool, warehouse_index := -1) -> void:
	if _pocket_total() > 0:
		if all:
			_deliver_all_pocket_to_warehouse(warehouse_index)
		else:
			_deliver_one_pocket_to_warehouse(warehouse_index)
		_refresh_interaction_hint()
	else:
		if pocket_take_menu_controller != null:
			pocket_take_menu_controller.show_pocket_take_menu(warehouse_index)


func _deliver_pocket_to_site(site: ConstructionSite, all: bool) -> void:
	var delivered_any := false
	for resource_type in site.required_materials:
		var required := int(site.required_materials.get(resource_type, 0))
		var delivered := int(site.delivered_materials.get(resource_type, 0))
		var needed := required - delivered
		if needed <= 0:
			continue
		var in_pocket := hero_pocket_service.pocket_amount(resource_type) if hero_pocket_service != null else 0
		if in_pocket <= 0:
			continue
		var amount := mini(in_pocket, needed) if all else mini(1, needed)
		amount = mini(amount, in_pocket)
		if amount <= 0:
			continue
		hero_pocket_service.remove_from_pocket(resource_type, amount) if hero_pocket_service != null else 0
		construction.accept_delivery(site.node, resource_type, amount)
		delivered_any = true
		if not all:
			break
	if delivered_any:
		_update_interface(S.MATERIALS_DELIVERED_TO_SITE)
		_refresh_interaction_hint()
	else:
		var missing := _missing_site_materials_text(site)
		if missing.is_empty():
			_update_interface(S.SITE_FULLY_SUPPLIED)
		else:
			_update_interface(S.POCKET_MISSING_MATERIALS % missing)
		_refresh_interaction_hint()


func _refuel_fire_from_pocket(building: Node3D, all: bool) -> void:
	if not is_instance_valid(building):
		return
	var available := hero_pocket_service.pocket_amount(ResourceIds.BRANCHES) if hero_pocket_service != null else 0
	if available <= 0:
		_update_interface(S.NO_BRANCHES_FOR_FIRE)
		_refresh_interaction_hint()
		return
	var fire_state := _fire_state_for(building)
	var amount := available if all else 1
	amount = mini(amount, available)
	var delivered := hero_pocket_service.remove_from_pocket(ResourceIds.BRANCHES, amount) if hero_pocket_service != null else 0
	if delivered <= 0:
		return
	fire_state.add_delivered(delivered, int(game_minutes))
	_apply_fire_state(building, fire_state)
	_refresh_living_statuses()
	_update_interface(S.BRANCHES_ADDED_TO_FIRE % delivered)
	_refresh_interaction_hint()


func _meet_arrival_at_entrance() -> void:
	for index in pending_arrivals.size():
		var order: Dictionary = pending_arrivals[index]
		if bool(order.get("dispatched", false)):
			continue
		order.dispatched = true
		order.greeter_id = player_citizen.ai_id
		pending_arrivals[index] = order
		arrival_greeters[player_citizen.ai_id] = order
		_on_arrival_greeter_ready(player_citizen)
		_refresh_interaction_hint()
		return
	_update_interface(S.NO_ONE_TO_MEET)
	_refresh_interaction_hint()


func _take_from_pile(pile: ResourcePileScript, all: bool) -> void:
	if pile == null:
		return
	var pile_node := pile.node
	if not is_instance_valid(pile_node):
		return
	var resources: Dictionary = pile.resources
	var taken_any := false
	for resource_type in resources.keys():
		var available := int(resources.get(resource_type, 0))
		if available <= 0:
			continue
		if not _pocket_has_room():
			break
		var amount := mini(available, hero_pocket_service.pocket_space_for(resource_type) if hero_pocket_service != null else 0) if all else 1
		amount = mini(amount, available)
		var taken := hero_pocket_service.add_to_pocket(resource_type, amount) if hero_pocket_service != null else 0
		if taken <= 0:
			continue
		taken_any = true
		resources[resource_type] = available - taken
		if resources[resource_type] <= 0:
			resources.erase(resource_type)
		if not all:
			break
	if not taken_any:
		if not _pocket_has_room():
			_update_interface(S.POCKET_FULL_SHORT)
		else:
			_update_interface(S.PILE_EMPTY_NO_RESOURCES)
		_refresh_interaction_hint()
		return
	pile.resources = resources
	if resources.is_empty():
		for index in range(resource_piles.size()):
			if resource_piles[index].node == pile_node:
				resource_piles.remove_at(index)
				break
		pile_node.queue_free()
	else:
		resource_pile_service.refresh_resource_pile_label(pile)
	_update_interface(S.TOOK_FROM_PILE % _format_pocket_hint())
	_refresh_interaction_hint()


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
	selected_world_position = building_placement_controller.snapped_build_position(world_position) if building_placement_controller != null else world_position if not build_mode.is_empty() else world_position
	selected_cell = _placement_key(selected_world_position)
	world_setup.selection_marker.position = selected_world_position + Vector3(0.0, 0.04, 0.0)
	if not build_mode.is_empty():
		var local_footprint: Vector2i = BuildingBlueprints.get_blueprint(build_mode).footprint
		var footprint := _rotated_footprint(local_footprint)
		(world_setup.selection_marker.mesh as BoxMesh).size = Vector3(footprint.x, 0.04, footprint.y)
		var forward := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, build_rotation_quarters * PI * 0.5)
		world_setup.preview_entrance_marker.position = selected_world_position + forward * (local_footprint.y * 0.5 + 0.35) + Vector3.UP * 0.08
		world_setup.preview_back_entrance_marker.position = selected_world_position - forward * (local_footprint.y * 0.5 + 0.35) + Vector3.UP * 0.08
		world_setup.preview_entrance_marker.visible = true
		world_setup.preview_back_entrance_marker.visible = true
	if not build_mode.is_empty():
		world_setup.selection_material.albedo_color = Color(0.25, 0.85, 0.37, 0.55) if building_placement_controller.can_place(selected_world_position) if building_placement_controller != null else false else Color(0.9, 0.2, 0.18, 0.6)
	if not build_mode.is_empty() and BuildingCatalog.max_hero_radius(build_mode) > 0.0 and is_instance_valid(hero_citizen):
		if not is_first_person and is_instance_valid(world_setup.hero_build_radius_marker):
			world_setup.hero_build_radius_marker.global_position = hero_citizen.global_position + Vector3(0.0, 0.08, 0.0)
			world_setup.hero_build_radius_marker.visible = true
		elif is_instance_valid(world_setup.hero_build_radius_marker):
			world_setup.hero_build_radius_marker.visible = false
	elif is_instance_valid(world_setup.hero_build_radius_marker):
		world_setup.hero_build_radius_marker.visible = false

func _place_building(world_position: Vector3) -> void:
	if not _can_hero_build():
		_update_interface("Only the hero can approve construction decisions.")
		return
	world_position = building_placement_controller.snapped_build_position(world_position) if building_placement_controller != null else world_position
	var max_hero_radius := BuildingCatalog.max_hero_radius(build_mode)
	if max_hero_radius > 0.0 and is_instance_valid(hero_citizen):
		if hero_citizen.global_position.distance_to(world_position) > max_hero_radius:
			_update_interface("Too far from Hero (max %.0f tiles)." % max_hero_radius)
			return
	if build_mode in ["straw_trade_tent", "tarp_trade_tent"] and is_instance_valid(entrance_stone) and world_position.distance_to(entrance_stone.global_position) > 8.0:
		_update_interface("The tent market must be built beside the entrance sign.")
		return
	var cell := _placement_key(world_position)
	var blueprint := BuildingBlueprints.get_blueprint(build_mode)
	var occupied_footprint := _rotated_footprint(blueprint.footprint)
	var territory_reason: StringName = village_territory_service.placement_reason(build_mode, cell, occupied_footprint)
	if territory_reason != village_territory_service.REASON_OK:
		_update_interface(village_territory_service.placement_message(territory_reason))
		return
	if not (building_placement_controller.can_place(world_position) if building_placement_controller != null else false):
		_update_interface("Construction is not allowed at this point.")
		return
	if not (building_placement_controller.can_pay_building_cost(build_mode) if building_placement_controller != null else false):
		var placement_state: Dictionary = building_availability_service.placement_state_with_inventory(build_mode, pocket)
		_update_interface(str(placement_state.message))
		return

	if BuildingCatalog.is_instant_build(build_mode):
		building_registry.reserve(cell, world_position, occupied_footprint)
		var site_node: Node3D = construction._get_site_scene().instantiate()
		site_node.position = world_position
		site_node.rotation.y = build_rotation_quarters * PI * 0.5
		site_node.set_meta("building_type", build_mode)
		site_node.set_meta("footprint", blueprint.footprint)
		site_node.set_meta("occupied_footprint", occupied_footprint)
		site_node.set_meta("service_positions", BuildingEntrancePositionsScript.positions(site_node, blueprint.footprint, 1.0))
		add_child(site_node)
		for module in blueprint.modules:
			site_node.add_child(BuildingBlueprints.create_module(module))
		for child_name in ["ConstructionTerritory", "ConstructionProgressBack", "ConstructionProgressFill", "SupplyLabel", "ConstructionSelector", "ConstructionEntrance"]:
			var child := site_node.get_node_or_null(child_name)
			if child != null:
				child.queue_free()
		_complete_building(cell, build_mode, world_position, site_node, blueprint)
		if BuildingCatalog.is_flag(build_mode):
			_bind_hero_squad_to_settlement(&"main_settlement")
		build_mode = ""
		build_rotation_quarters = 0
		world_setup.selection_marker.visible = false
		world_setup.preview_entrance_marker.visible = false
		world_setup.preview_back_entrance_marker.visible = false
		if is_instance_valid(world_setup.hero_build_radius_marker):
			world_setup.hero_build_radius_marker.visible = false
		_show_territory_overlay(false)
		ui_manager.build_menu.visible = false
		build_menu_is_global = false
		selected_builder = null
		_set_build_placement_ui_visible(true)
		_update_interface("%s placed!" % str(BuildingCatalog.definition_for(build_mode).get("name", "Building")))
		return

	building_registry.reserve(cell, world_position, occupied_footprint)
	_refresh_navigation_grid()
	var site := _create_construction_site(cell, build_mode, world_position, build_rotation_quarters, blueprint, occupied_footprint)
	_deliver_pocket_to_site(site, true)
	building_registry.attach_node(cell, site.node, build_mode)
	build_mode = ""
	build_rotation_quarters = 0
	world_setup.selection_marker.visible = false
	world_setup.preview_entrance_marker.visible = false
	world_setup.preview_back_entrance_marker.visible = false
	if is_instance_valid(world_setup.hero_build_radius_marker):
		world_setup.hero_build_radius_marker.visible = false
	_show_territory_overlay(false)
	ui_manager.build_menu.visible = false
	build_menu_is_global = false
	selected_builder = null
	_set_build_placement_ui_visible(true)
	_update_interface("Construction marked. Couriers must deliver the required materials before builders can start.")

func _place_building_at_crosshair() -> void:
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	var terrain_point: Variant = _terrain_point_at_screen_position(viewport_center)
	if terrain_point == null:
		_update_interface("Aim at clear terrain to place the building.")
		return
	_place_building(terrain_point)

func _can_hero_build() -> bool:
	return building_placement_controller.can_hero_build() if building_placement_controller != null else false

func _terrain_height_at(x: float, z: float, near_y: float) -> float:
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
	var site := construction.start_site(cell, building_type, position_on_board, rotation_quarters, blueprint, occupied_footprint)
	_register_service_pockets(site.node)
	# The reservation refresh runs before the site exists. Publish its entrance
	# pockets immediately so couriers and builders can route to the new site.
	_refresh_navigation_grid()
	_request_courier_dispatch()
	return site


func _register_service_pockets(node: Node3D) -> void:
	if not node.has_meta("service_positions"):
		return
	var positions: Array = node.get_meta("service_positions")
	for position in positions:
		if position is Vector3:
			service_pockets.append({"cell": _cell_from_position(position), "node": node})


func _unregister_service_pockets(node: Node3D) -> void:
	for index in range(service_pockets.size() - 1, -1, -1):
		if service_pockets[index].node == node:
			service_pockets.remove_at(index)

func _update_construction(delta: float) -> void:
	# Reconcile reservations outside work time as well, so interrupted night
	# deliveries do not strand reserved materials forever.
	for site: ConstructionSite in construction_sites:
		if is_instance_valid(site.node):
			_reconcile_construction_reservations(site)
	construction.tick(delta)


func _set_construction_status(text: String) -> void:
	if ui_manager.hud != null:
		ui_manager.hud.set_status(text)


func _update_construction_supply_label(site: ConstructionSite) -> void:
	if not is_instance_valid(site.node) or site.node.is_queued_for_deletion():
		return
	var label := site.node.get_node_or_null("SupplyLabel") as Label3D
	if label == null:
		return
	var delivered := 0
	var required := 0
	for resource_type in site.required_materials:
		delivered += int(site.delivered_materials.get(resource_type, 0))
		required += int(site.required_materials[resource_type])
	label.text = "MATERIALS %d/%d" % [delivered, required]
	label.modulate = Color("f0c45d") if delivered < required else Color("56bd58")

func _complete_building(cell: Vector2i, building_type: String, position_on_board: Vector3, building: Node3D, blueprint: Dictionary) -> void:
	settlement.buildings[building_type] = int(settlement.buildings.get(building_type, 0)) + 1
	building.set_meta("building_type", building_type)
	building.set_meta("condition", 100.0)
	if blueprint.has("blueprint_ref"):
		building.set_meta("blueprint_ref", blueprint["blueprint_ref"])
	if building_zone_service != null:
		building_zone_service.configure_building(building, blueprint.get("work_zones", []), blueprint.get("saved_zone_state", []))
	if blueprint.has("routing_anchors"):
		building.set_meta("routing_anchors", blueprint["routing_anchors"])
	_unregister_service_pockets(building)
	if BuildingTypes.is_fire_source(building_type):
		building.set_meta("fire_fuel", 4)
		building.set_meta("fire_lit", true)
		building.set_meta("fire_embers_until", -1)
		building.set_meta("fire_phase", "burning")
	if _is_staffed_workplace(building):
		workplace_priority_counter += 1
		building.set_meta("accepting_workers", true)
		building.set_meta("workplace_priority", workplace_priority_counter)
	if building_type not in ["warehouse", "straw_warehouse", "tarp_warehouse", "campfire", "campfire_lvl2", "campfire_lvl3", "earth_assembly", "clay_lodge", "wood_town_hall", "stone_prefecture", "brick_city_hall", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant", "straw_trade_tent", "tarp_trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market", "school", "materials_factory", "tent", "straw_tent", "tarp_tent", "dugout", "earth_house", "clay_house", "stone_house", "house", "house_lvl2", "house_lvl3", "brick_house", "straw_craft_tent", "tarp_craft_tent", "straw_forager_tent", "tarp_forager_tent", "boundary_post", "entrance_sign"]:
		_add_building_selector(building, "building_selector", blueprint.footprint)
	if building_type == "entrance_sign":
		_setup_entrance_sign_node(building)
	var is_home := BuildingTypes.is_housing(building_type)
	_register_service_entrance(building, blueprint, is_home, building_type not in ["farm", "park"])
	var service_position: Vector3 = building.get_meta("service_position")
	building_lifecycle_service.register_completed_building_type_features(building_type, building, blueprint, service_position)

	building_registry.attach_node(cell, building, building_type)
	var occupied_footprint: Vector2i = building.get_meta("occupied_footprint", blueprint.footprint)
	village_territory_service.on_building_added(cell, building_type)
	_refresh_boundary_markers()
	_add_building_status_indicator(building)
	_refresh_navigation_grid()
	_update_workers()
	if building_menu_controller != null:
		building_menu_controller.refresh_build_menu()
	var completion_message := "%s construction completed." % building_type.capitalize()
	if building_type in ["recycling_factory", "metal_factory"]:
		completion_message += " It requires 3 factory workers."
	_update_interface(completion_message)
	_request_courier_dispatch()


func _entrance_anchor_position() -> Vector3:
	if is_instance_valid(entrance_stone):
		return entrance_stone.global_position
	return nav_grid.cell_center(Vector2i(-22, 1)) if nav_grid != null else Vector3((Vector2i(-22, 1).x + 0.5) * CELL_SIZE, 0.0, (Vector2i(-22, 1).y + 0.5) * CELL_SIZE)


func _setup_entrance_sign_node(building: Node3D) -> void:
	if not is_instance_valid(building):
		return
	entrance_stone = building
	_add_selector_to_node(building, "entrance_selector", Vector3(2.2, 2.4, 1.0), Vector3(0.0, 1.1, 0.0))
	var label := Label3D.new()
	label.position = Vector3(0.0, 1.26, 0.09)
	label.text = "Settlement"
	label.font_size = 28
	label.modulate = Color("f0dfb2")
	building.add_child(label)
	var light := OmniLight3D.new()
	light.name = "EntranceSignLight"
	light.position = Vector3(0.0, 2.2, 0.0)
	light.light_color = Color(1.0, 0.8353, 0.5412, 1.0)
	light.light_energy = 2.0
	light.light_volumetric_fog_energy = 0.5
	light.omni_range = 5.0
	light.shadow_enabled = true
	building.add_child(light)
	if ambient_spawner != null:
		ambient_spawner.setup_entrance_sign_node(building)


func _activate_kitchen_if_better(building: Node3D, service_position: Vector3) -> void:
	var capacity := BuildingCatalog.kitchen_food_capacity(building_registry.building_type_for_node(building))
	var active_capacity := BuildingCatalog.kitchen_food_capacity(building_registry.building_type_for_node(canteen)) if is_instance_valid(canteen) else 0
	if capacity >= active_capacity:
		canteen = building
		if building.has_meta("entrance_position"):
			canteen_position = building.get_meta("entrance_position")
		else:
			canteen_position = building.get_meta("service_position", building.global_position)


func _select_best_canteen() -> void:
	var best_kitchen: Node3D = null
	var best_capacity := 0
	for record in building_registry.records():
		var candidate: Node3D = record.node
		if not is_instance_valid(candidate):
			continue
		var capacity := BuildingCatalog.kitchen_food_capacity(record.building_type)
		if capacity > best_capacity:
			best_kitchen = candidate
			best_capacity = capacity
	canteen = best_kitchen
	if best_kitchen != null:
		if best_kitchen.has_meta("entrance_position"):
			canteen_position = best_kitchen.get_meta("entrance_position")
		else:
			canteen_position = best_kitchen.get_meta("service_position", best_kitchen.global_position)

func _add_building_selector(building: Node3D, group_name: String, footprint: Vector2i) -> void:
	var selector := BuildingSelectorScene.instantiate() as Area3D
	selector.add_to_group(group_name)
	var collision := selector.get_node("CollisionShape3D") as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	shape.size = Vector3(footprint.x + 0.25, 4.5, footprint.y + 0.25)
	collision.position.y = 2.0
	building.add_child(selector)


func _add_selector_to_node(node: Node3D, group_name: String, shape_size: Vector3, offset := Vector3.ZERO) -> void:
	var selector := BuildingSelectorScene.instantiate() as Area3D
	selector.add_to_group(group_name)
	var collision := selector.get_node("CollisionShape3D") as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	shape.size = shape_size
	collision.position = offset
	node.add_child(selector)


func _add_fire_light(building: Node3D, energy := 2.5, light_range := 8.0) -> void:
	var fire_light := FireLightScene.instantiate() as OmniLight3D
	fire_light.light_energy = energy
	fire_light.omni_range = light_range
	building.add_child(fire_light)


func _add_building_status_indicator(building: Node3D) -> void:
	if not is_instance_valid(building) or building.has_meta("status_indicator"):
		return
	var indicator := BillboardLabelScene.instantiate() as Label3D
	indicator.position = Vector3(0.0, 4.2, 0.0)
	indicator.font_size = 28
	indicator.outline_size = 5
	indicator.visible = false
	building.add_child(indicator)
	building.set_meta("status_indicator", indicator)
	building_status_indicators.append(indicator)


func _add_warehouse_fill_label(building: Node3D) -> void:
	if warehouse_fill_label_controller != null:
		warehouse_fill_label_controller.add_warehouse_fill_label(building)


func _send_citizen_to_leisure(citizen: Citizen, minimum_hours := 0) -> bool:
	# Returns whether the citizen was actually placed somewhere to rest so the
	# waiting window knows if it needs to keep looking for work.
	if citizen.is_player_controlled or citizen.state not in [Citizen.State.IDLE, Citizen.State.RESTING, Citizen.State.WAITING]:
		return false
	# Dedicated recreation first (parks, leisure centers), picked at random.
	var recreation: Array[Vector3] = park_positions + leisure_positions
	for position in gathering_place_positions:
		var place := building_registry.building_at_service_position(position)
		if is_instance_valid(place):
			recreation.append(position)
	if not recreation.is_empty():
		return citizen_needs_service != null and citizen_needs_service.request_leisure(citizen.ai_id, recreation, minimum_hours)
	# No parks yet (early eras): gather at the main campfire or a natural pond.
	var gathering_spots: Array[Vector3] = []
	if is_instance_valid(campfire_node) and _is_fire_lit(campfire_node):
		gathering_spots.append(campfire_node.global_position)
	for pond in pond_positions:
		# Do not stand in water: choose a stable point at its rim.
		gathering_spots.append(pond + Vector3(2.8, 0.0, 0.0))
	if not gathering_spots.is_empty():
		return citizen_needs_service != null and citizen_needs_service.request_leisure(citizen.ai_id, gathering_spots, minimum_hours)
	# Nothing communal exists at all. During the working day we must NOT send them
	# home to sleep — a RESTING citizen stops re-probing for work and would sleep
	# through the day (the "skip night with full storage" freeze). Return false so
	# the waiting window drops them to IDLE (with its indicator) and the poll keeps
	# checking. Night-time sleep is handled separately by the native sleep goal.
	return false

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
	var building_type := str(blueprint.get("type", ""))
	var service_positions := BuildingEntrancePositions.positions(building, blueprint.footprint, SERVICE_PAD_OFFSET)
	if not service_positions.is_empty():
		building.set_meta("service_positions", service_positions)
		building.set_meta("service_position", service_positions[0])
		for position in service_positions:
			service_pockets.append({"cell": _cell_from_position(position), "node": building})
		if show_marker:
			var offsets := BuildingEntrancePositions.offsets(building_type)
			if offsets.is_empty():
				offsets = [Vector2i(0, -blueprint.footprint.y / 2)]
			var local_positions := BuildingEntrancePositions.local_positions(blueprint.footprint, offsets, SERVICE_PAD_OFFSET)
			for local in local_positions:
				if building_visuals_service != null:
					building_visuals_service.add_service_entrance_marker(building, local)
	var visitor_positions := BuildingEntrancePositions.visitor_positions(building, blueprint.footprint, SERVICE_PAD_OFFSET)
	if visitor_positions.is_empty() and home_entrance and not service_positions.is_empty():
		visitor_positions = service_positions
	if not visitor_positions.is_empty():
		building.set_meta("entrance_positions", visitor_positions)
		building.set_meta("entrance_position", visitor_positions[0])
		if service_positions.is_empty():
			building.set_meta("service_positions", visitor_positions)
			building.set_meta("service_position", visitor_positions[0])
		var v_offsets := BuildingEntrancePositions.visitor_offsets(building_type)
		if not v_offsets.is_empty():
			var v_local_positions := BuildingEntrancePositions.local_positions(blueprint.footprint, v_offsets, SERVICE_PAD_OFFSET)
			for local in v_local_positions:
				if building_visuals_service != null:
					building_visuals_service.add_visitor_entrance_marker(building, local)

func _nearby_player_work_target() -> Node3D:
	if player_citizen == null:
		return null
	for site in construction_sites:
		if not is_instance_valid(site.node):
			continue
		if player_citizen.global_position.distance_to(site.node.global_position) <= INTERACTION_RANGE:
			return site.node
	for site in demolition_sites:
		if not is_instance_valid(site.building):
			continue
		if player_citizen.global_position.distance_to(site.building.global_position) <= INTERACTION_RANGE:
			return site.building
	return null


func _unregister_navigation_footprint(center: Vector3, footprint: Vector2i) -> void:
	for index in range(service_pockets.size() - 1, -1, -1):
		var pocket: Dictionary = service_pockets[index]
		if is_instance_valid(pocket.node) and pocket.node.global_position == center:
			service_pockets.remove_at(index)

func _add_house_light(house: Node3D) -> void:
	if building_visuals_service != null:
		building_visuals_service.add_house_light(house)

func _on_tree_harvested(worker: Citizen, position_on_board: Vector3) -> void:
	_fell_tree_at(position_on_board)

func _consume_tree_near_player(amount: int) -> void:
	if player_citizen == null:
		return
	for position_on_board in tree_positions:
		if player_citizen.global_position.distance_to(position_on_board) <= INTERACTION_RANGE:
			var tree: Node3D = tree_nodes.get(_cell_from_position(position_on_board))
			var tree_state: Variant = world_resource_state.tree_at(_cell_from_position(position_on_board))
			if is_instance_valid(tree) and tree_state != null and not tree_state.felled:
				var consumed := 0
				while consumed < amount:
					var result := foraging_service.consume_tree_branches(position_on_board)
					if result <= 0:
						break
					consumed += result
				if consumed > 0:
					_update_interface(S.BRANCHES_GATHERED_TREE_STANDING % consumed)
				else:
					_update_interface(S.TREE_NO_BRANCHES_LEFT)
				return


func _fell_nearest_tree() -> void:
	if player_citizen == null:
		return
	for position_on_board in tree_positions:
		if player_citizen.global_position.distance_to(position_on_board) <= INTERACTION_RANGE:
			var tree: Node3D = tree_nodes.get(_cell_from_position(position_on_board))
			var tree_state: Variant = world_resource_state.tree_at(_cell_from_position(position_on_board))
			if is_instance_valid(tree) and tree_state != null and not tree_state.felled:
				_fell_tree_at(position_on_board)
				return


func _fell_tree_at(position_on_board: Vector3) -> void:
	var cell := _cell_from_position(position_on_board)
	var tree: Node3D = tree_nodes.get(cell)
	if not is_instance_valid(tree):
		return
	var tree_state: Variant = world_resource_state.tree_at(cell)
	if tree_state == null or tree_state.felled:
		return
	_apply_tree_felled_visual(cell, tree)
	_refresh_navigation_grid()
	settlement.add(ResourceIds.BRANCHES, 3)
	_update_interface("A tree was felled. Its log is ready for delivery; the living tree is no longer available for gathering.")


## Lays a tree down and frees the cell it occupied. Shared by live felling and
## save restore so both paths produce identical geometry and navigation state.
func _apply_tree_felled_visual(cell: Vector2i, tree: Node3D) -> void:
	var tree_state: Variant = world_resource_state.tree_at(cell)
	if tree_state != null:
		tree_state.felled = true
		tree.set_meta("felled", true) # Compatibility projection; state is authoritative.
	tree.rotation_degrees.z = 82.0
	var collision_body := tree.get_node_or_null("TreeCollision") as CollisionObject3D
	if collision_body != null:
		collision_body.queue_free()
	terrain_blocked_cells.erase(cell)

func _toggle_global_build_menu() -> void:
	var was_visible := ui_manager.build_menu.visible and build_menu_is_global
	_close_context_menus()
	build_menu_is_global = not was_visible
	ui_manager.build_menu.visible = build_menu_is_global
	if ui_manager.build_menu.visible:
		build_category = ""
		build_menu_is_job_menu = false
		build_menu_is_daily_order_menu = false
		if building_menu_controller != null:
			building_menu_controller.refresh_build_menu()


func _set_road_walking_order(enabled: bool) -> void:
	if settlement.era != SettlementState.Era.TENT:
		return
	settlement.road_walking_order_enabled = enabled
	_update_interface("Trail-walking order %s. It does not change routes yet." % ("enabled" if enabled else "disabled"))



func _cheer_up_settlement() -> void:
	if clock.hour() < 6:
		return
	if settlement.apply_cheer_up():
		if campfire_menu_controller != null:
			campfire_menu_controller.show_campfire_orders_menu()
		_update_interface("You cheered up the settlement. Wellbeing rose by 5%%.")


func _has_night_work_candidates() -> bool:
	for citizen in citizens:
		if is_instance_valid(citizen) and not citizen.is_player_controlled and not citizen.is_recovering(day_cycle.current_day) and (citizen.has_active_daily_order() or citizen.is_employed()):
			return true
	return false


func _toggle_settlement_night_work(checked: bool) -> void:
	if checked:
		if settlement.night_work_order_day == day_cycle.current_day:
			if campfire_menu_controller != null:
				campfire_menu_controller.show_campfire_orders_menu()
			return
		var affected := 0
		for citizen in citizens:
			if not is_instance_valid(citizen) or citizen.is_player_controlled or citizen.is_recovering(day_cycle.current_day):
				continue
			if citizen.has_active_daily_order() or citizen.is_employed():
				if citizen_daily_order_service.activate_citizen_overtime(citizen, "settlement") if citizen_daily_order_service != null else false:
					affected += 1
		if affected <= 0:
			if campfire_menu_controller != null:
				campfire_menu_controller.show_campfire_orders_menu()
			return
		settlement.night_work_order_day = day_cycle.current_day
		_update_interface("Night-work order issued to %d residents. They will work through the night and next day." % affected)
		if survival_event_controller != null:
			survival_event_controller.update_skip_night_button()
		if citizen_ai != null:
			citizen_ai.request_decision_refresh()
	else:
		for citizen in citizens:
			if not is_instance_valid(citizen) or citizen.is_player_controlled:
				continue
			if citizen.has_overtime_source("settlement", day_cycle.current_day):
				citizen.deactivate_overtime("settlement")
		if citizen_daily_order_service != null:
			citizen_daily_order_service.sync_overtime_scope_indicators()
		_update_interface("Settlement night work cancelled. Workers will return home.")
		if survival_event_controller != null:
			survival_event_controller.update_skip_night_button()
		if citizen_ai != null:
			citizen_ai.request_decision_refresh()
	if campfire_menu_controller != null:
		campfire_menu_controller.show_campfire_orders_menu()


func _toggle_double_time_order(checked: bool) -> void:
	if checked:
		if settlement.double_time_order_day == day_cycle.current_day:
			if campfire_menu_controller != null:
				campfire_menu_controller.show_campfire_orders_menu()
			return
		settlement.double_time_order_day = day_cycle.current_day
		_update_interface("Double time order issued. All residents walk twice as fast today, but fatigue accumulates faster.")
	else:
		settlement.double_time_order_day = -1
		_update_interface("Double time order cancelled. Residents resume normal pace.")
	if campfire_menu_controller != null:
		campfire_menu_controller.show_campfire_orders_menu()


func _toggle_selected_citizen_night_work(checked: bool) -> void:
	if not is_instance_valid(selected_builder):
		ui_manager.build_menu.personal_night_work_button.set_pressed_no_signal(false)
		return
	if checked:
		if not selected_builder.has_daily_order() or selected_builder.is_employed() or selected_builder.has_overtime_source("personal", day_cycle.current_day):
			ui_manager.build_menu.personal_night_work_button.set_pressed_no_signal(false)
			return
		# Evening daily orders normally wait for tomorrow. A personal night-work
		# order explicitly starts that new task now and keeps it through tomorrow.
		# Permanent jobs already have an active assignment, including courier jobs
		# that do not belong to a workplace, so they only need the overtime flag.
		if not citizen_daily_order_service.activate_citizen_overtime(selected_builder, "personal") if citizen_daily_order_service != null else false:
			ui_manager.build_menu.personal_night_work_button.set_pressed_no_signal(false)
			return
		_update_interface("%s received a personal night-work order." % selected_builder.role_label())
		if survival_event_controller != null:
			survival_event_controller.update_skip_night_button()
		if citizen_ai != null:
			citizen_ai.request_decision_refresh()
	else:
		selected_builder.deactivate_overtime("personal")
		_update_interface("Night work cancelled for %s." % selected_builder.role_label())
		if survival_event_controller != null:
			survival_event_controller.update_skip_night_button()
		if citizen_ai != null:
			citizen_ai.request_decision_refresh()
	if building_menu_controller != null:
		building_menu_controller.refresh_build_menu()



func _occupy_selected_campfire_position() -> void:
	if not is_instance_valid(selected_campfire) or not is_instance_valid(player_citizen):
		return
	if player_citizen.global_position.distance_to(_nearest_service_position(selected_campfire, player_citizen.global_position)) > OFFICER_POST_RADIUS:
		return
	_occupy_workplace(selected_campfire)
	if campfire_menu_controller != null:
		campfire_menu_controller.refresh_campfire_menu()


func _handle_campfire_primary_action() -> void:
	if not is_instance_valid(selected_campfire):
		return
	selected_building = selected_campfire
	if not _is_fire_lit(selected_campfire):
		_relight_selected_fire()
		if campfire_menu_controller != null:
			campfire_menu_controller.refresh_campfire_menu()
		return
	_upgrade_selected_building()


func _toggle_campfire_acceptance() -> void:
	if not is_instance_valid(selected_campfire):
		return
	selected_building = selected_campfire
	_toggle_selected_workplace_acceptance()


func _dismiss_campfire_worker() -> void:
	if not is_instance_valid(selected_campfire):
		return
	selected_building = selected_campfire
	_dismiss_selected_workplace_worker()


func _on_campfire_advance_pressed() -> void:
	if selected_campfire == null:
		return
	var housing_slots := _total_housing_slots()
	var next_era := SettlementState.Era.TENT
	match settlement.era:
		SettlementState.Era.TENT: next_era = SettlementState.Era.EARTH
		SettlementState.Era.EARTH: next_era = SettlementState.Era.CLAY
		SettlementState.Era.CLAY: next_era = SettlementState.Era.WOOD
		SettlementState.Era.WOOD: next_era = SettlementState.Era.STONE
		SettlementState.Era.STONE: next_era = SettlementState.Era.BRICK
	
	if settlement.advance_era(next_era, citizens.size(), housing_slots):
		village_territory_service.set_era(int(settlement.era))
		_update_interface("Advanced to the %s Era! New buildings unlocked." % _era_name())
		if campfire_menu_controller != null:
			campfire_menu_controller.refresh_campfire_menu()
		if building_menu_controller != null:
			building_menu_controller.refresh_build_menu()
	else:
		_update_interface("Failed to advance era. Double-check requirements.")


func _refresh_market_menu() -> void:
	if market_menu_controller != null:
		market_menu_controller.refresh_market_menu()









func _available_trade_money() -> int:
	return trade_service.available_trade_money()


func _demolish_selected_building() -> void:
	if is_instance_valid(selected_building):
		building_lifecycle_service.mark_building_for_demolition(selected_building)


func _relight_selected_fire() -> void:
	if not is_instance_valid(selected_building):
		return
	var fire_state := _fire_state_for(selected_building)
	if fire_state.lit:
		return
	if fire_state.fuel <= 0:
		_update_interface("A fire needs branches before it can be relit.")
		return
	fire_state.lit = true
	_apply_fire_state(selected_building, fire_state)
	_refresh_living_statuses()
	_reopen_workplace_menu()
	_update_interface("The fire was relit with flint and steel.")


func _toggle_selected_workplace_acceptance() -> void:
	if not is_instance_valid(selected_building) or not _is_staffed_workplace(selected_building):
		return
	var accepting := bool(selected_building.get_meta("accepting_workers", true))
	if accepting:
		selected_building.set_meta("accepting_workers", false)
		_update_interface("This workplace stopped accepting new workers.")
	else:
		workplace_priority_counter += 1
		selected_building.set_meta("accepting_workers", true)
		selected_building.set_meta("workplace_priority", workplace_priority_counter)
		_update_interface("This workplace is accepting workers at the front of its queue.")
	_update_workers()
	_reopen_workplace_menu()


func _dismiss_selected_workplace_worker() -> void:
	var worker := _workplace_worker(selected_building)
	if worker == null:
		return
	selected_building.set_meta("accepting_workers", false)
	if worker.permanent_role == "official":
		_dismiss_official(worker)
	else:
		_send_to_unemployment_registration(worker)
	_update_workers()
	_reopen_workplace_menu()


func _reopen_workplace_menu() -> void:
	# The town hall keeps its own dedicated menu; every other workplace uses the
	# generic building menu.
	if is_instance_valid(selected_campfire) and selected_building == selected_campfire and ui_manager.campfire_menu.visible:
		if campfire_menu_controller != null:
			campfire_menu_controller.refresh_campfire_menu()
	else:
		if building_menu_controller != null:
			building_menu_controller.show_building_menu()


func _upgrade_selected_building() -> void:
	if not is_instance_valid(selected_building):
		return
	var old_type := building_registry.building_type_for_node(selected_building)
	var target_type := settlement.next_building_upgrade(old_type)
	if target_type.is_empty():
		return
	var old_footprint: Vector2i = selected_building.get_meta("footprint", BuildingBlueprints.get_blueprint(old_type).footprint)
	var blueprint := BuildingBlueprints.get_blueprint(target_type)
	if blueprint.footprint != old_footprint:
		_update_interface("This upgrade needs rebuilding because its footprint changes.")
		return
	if not settlement.can_upgrade_building(old_type):
		_update_interface("Upgrade needs research and resources.")
		return
	var service_position: Vector3 = selected_building.get_meta("service_position", selected_building.global_position)
	var warehouse_index := warehouse_positions.find(service_position)
	if settlement.pay_for_building_upgrade(old_type, warehouse_index).is_empty():
		return
	for child in selected_building.get_children():
		selected_building.remove_child(child)
		child.queue_free()
	if selected_building.has_meta("status_indicator"):
		selected_building.remove_meta("status_indicator")
	if selected_building.has_meta("warehouse_fill_label"):
		selected_building.remove_meta("warehouse_fill_label")
	selected_building.set_meta("building_type", target_type)
	selected_building.set_meta("footprint", blueprint.footprint)
	selected_building.set_meta("occupied_footprint", blueprint.footprint)
	for module in blueprint.modules:
		selected_building.add_child(BuildingBlueprints.create_module(module))
	_unregister_navigation_footprint(selected_building.global_position, old_footprint)
	var is_home := target_type in ["tent", "straw_tent", "tarp_tent", "dugout", "earth_house", "clay_house", "stone_house", "house", "house_lvl2", "house_lvl3", "brick_house"]
	_register_service_entrance(selected_building, blueprint, is_home, target_type not in ["farm", "park"])
	if target_type in ["campfire", "campfire_lvl2", "campfire_lvl3", "earth_assembly", "clay_lodge", "wood_town_hall", "stone_prefecture", "brick_city_hall"]:
		campfire_node = selected_building
		_activate_employment_centre(selected_building)
		_add_building_selector(selected_building, "campfire_selector", blueprint.footprint)
		_add_fire_light(selected_building)
	elif BuildingTypes.is_kitchen(target_type):
		_activate_kitchen_if_better(selected_building, service_position)
		_add_building_selector(selected_building, "cook_campfire_selector", blueprint.footprint)
		_add_fire_light(selected_building)
	_add_building_status_indicator(selected_building)
	if BuildingTypes.is_warehouse(target_type):
		_add_warehouse_fill_label(selected_building)
	village_territory_service.recalculate()
	_refresh_boundary_markers()
	_refresh_navigation_grid()
	_update_workers()
	_update_interface("%s upgraded to %s." % [str(BuildingCatalog.definition_for(old_type).get("name", old_type)), str(BuildingCatalog.definition_for(target_type).get("name", target_type))])
	if ui_manager.campfire_menu.visible and selected_building == selected_campfire:
		if campfire_menu_controller != null:
			campfire_menu_controller.refresh_campfire_menu()
	else:
		if building_menu_controller != null:
			building_menu_controller.show_building_menu()


func _workplace_worker(building: Node3D) -> Citizen:
	if not is_instance_valid(building):
		return null
	for citizen in citizens:
		if citizen.employment_workplace == building or citizen.pending_employment_workplace == building:
			return citizen
	return null


func _workplace_priority_position(building: Node3D) -> int:
	var role := ""
	for candidate_role in ["construction", "forestry", "farming", "gather_food", "cook", "teacher", "seller", "official", "factory_worker", "engineer"]:
		if _building_supports_role(building, candidate_role):
			role = candidate_role
			break
	if role.is_empty():
		return 0
	var position := 1
	var priority := int(building.get_meta("workplace_priority", 0))
	for record in building_registry.records():
		var candidate := record.node
		if not is_instance_valid(candidate) or candidate == building or not bool(candidate.get_meta("accepting_workers", true)):
			continue
		if _building_supports_role(candidate, role) and int(candidate.get_meta("workplace_priority", 0)) > priority:
			position += 1
	return position


func _take_resource_into_pocket(resource_type: String, amount: int) -> void:
	if amount <= 0:
		return
	var warehouse_index := _nearby_warehouse_index()
	if warehouse_index >= 0:
		amount = mini(amount, settlement.warehouses[warehouse_index].amount(resource_type))
	else:
		amount = mini(amount, settlement.amount(resource_type))
	amount = hero_pocket_service.add_to_pocket(resource_type, amount) if hero_pocket_service != null else 0
	if amount > 0:
		if warehouse_index >= 0:
			settlement.add_to_warehouse(resource_type, -amount, warehouse_index)
		else:
			settlement.add(resource_type, -amount)
		_update_interface(S.TOOK_FROM_WAREHOUSE % [amount, resource_type])
	if pocket_take_menu_controller != null:
		pocket_take_menu_controller.refresh_pocket_take_menu()
	_refresh_interaction_hint()


func _assign_cook_at_campfire() -> void:
	if selected_builder == null:
		_update_interface("Select a resident first, then choose a cooking shift.")
		return
	if selected_builder.is_player_controlled:
		_update_interface("Pick a settler, not the character you are controlling.")
		return
	if selected_building != canteen:
		_update_interface("Choose the active kitchen to assign a cook.")
		return
	if not _player_can_manage_permanent_professions():
		if workplace_labor_service != null:
			workplace_labor_service.show_labor_command_blocked()
		return
	if not _set_manual_specialist_employment(selected_builder, "cook"):
		return
	selected_builder.setup_specialization("cook")
	_update_interface("%s is registering as a cook." % selected_builder.role_label())
	_update_workers()


func _assign_teacher_at_school() -> void:
	if not _player_can_manage_permanent_professions():
		if workplace_labor_service != null:
			workplace_labor_service.show_labor_command_blocked()
		return
	if selected_builder == null:
		_update_interface("Select a resident first, then click the school to make them the teacher.")
		return
	if selected_builder.is_player_controlled:
		_update_interface("Pick a settler, not the character you are controlling.")
		return
	if not _set_manual_specialist_employment(selected_builder, "teacher"):
		return
	selected_builder.setup_specialization("teacher")
	_update_interface("%s is registering as a teacher." % selected_builder.role_label())
	_update_workers()


func _assign_seller_at_market() -> void:
	if not _player_can_manage_permanent_professions():
		if workplace_labor_service != null:
			workplace_labor_service.show_labor_command_blocked()
		return
	if selected_builder == null:
		_update_interface("Select a resident first, then click the market to make them the seller.")
		return
	if selected_builder.is_player_controlled:
		_update_interface("Pick a settler, not the character you are controlling.")
		return
	if not _set_manual_specialist_employment(selected_builder, "seller"):
		return
	selected_builder.setup_specialization("seller")
	_update_interface("%s is registering as a seller." % selected_builder.role_label())
	_update_workers()


func _appoint_official(citizen: Citizen, workplace: Node3D = null, require_at_post := true) -> bool:
	# Promotion requires both the researched technology and physical occupation
	# of the civic post. The unit-menu appointment is the explicit exception:
	# it is unlocked by the research and sends the new officer to the post by AI.
	if citizen == null or not settlement.is_research_completed("official"):
		return false
	var centre := workplace if is_instance_valid(workplace) else _employment_centre_building()
	if not is_instance_valid(centre) or (require_at_post and citizen.global_position.distance_to(_employment_center_position()) > OFFICER_POST_RADIUS):
		return false
	for other in citizens:
		if not is_instance_valid(other) or other == citizen or other.permanent_role != "official":
			continue
		_dismiss_official(other)
	citizen.setup_specialization("official")
	citizen.clear_daily_order()
	citizen.assigned_dig_site = null
	citizen.pending_employment_role = ""
	citizen.pending_employment_workplace = null
	citizen.permanent_role = "official"
	citizen.employment_workplace = centre
	citizen.employment_state = Citizen.EmploymentState.EMPLOYED
	if not is_instance_valid(citizen.employment_workplace):
		citizen.active_role = ""
		return false
	if citizen_ai != null:
		citizen_ai.request_decision_refresh()
	return true


func _dismiss_official(citizen: Citizen) -> void:
	if citizen == null or citizen.permanent_role != "official":
		return
	if settlement.active_research_tech_id != "" and settlement.active_research_worker_id == citizen.ai_id:
		_cancel_active_building_research(true, "Research cancelled: the official left the post. Resources refunded.")
	citizen.idle()
	citizen.setup_specialization("unassigned")
	citizen.clear_daily_order()
	citizen.assigned_dig_site = null
	citizen.pending_employment_role = ""
	citizen.pending_employment_workplace = null
	citizen.permanent_role = ""
	citizen.employment_workplace = null
	citizen.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
	citizen.active_role = ""
	_update_interface(S.CITIZEN_LEFT_OFFICER_POST % citizen.role_label())
	_update_workers()
	if building_menu_controller != null:
		building_menu_controller.refresh_build_menu()


func _activate_employment_centre(centre: Node3D) -> void:
	if not is_instance_valid(centre):
		return
	var service_position: Vector3 = centre.get_meta("service_position", centre.global_position)
	for citizen in citizens:
		if not is_instance_valid(citizen) or citizen.permanent_role != "official":
			continue
		citizen.employment_workplace = centre
		citizen.pending_employment_workplace = null
		citizen.employment_state = Citizen.EmploymentState.EMPLOYED
		if citizen.is_player_controlled:
			# A player-controlled official is already physically at a work position;
			# do not cancel their current FPP state.
			continue
		# Start the post in the same hand-off so another scheduler tick cannot
		# replace the job before the route starts.
		if _is_work_time():
			citizen.assign_official_work(service_position)
		else:
			citizen.idle()
	_update_workers()


func _set_manual_specialist_employment(citizen: Citizen, role: String) -> bool:
	if not _player_can_manage_permanent_professions():
		if workplace_labor_service != null:
			workplace_labor_service.show_labor_command_blocked()
		return false
	if citizen.employment_state != Citizen.EmploymentState.NO_PERMANENT_WORK:
		return false
	citizen.idle()
	citizen.begin_employment_processing(_employment_center_position(), role, _employer_for_role(role))
	return true



func _consume_grass_source(position: Vector3) -> int:
	return foraging_service.consume_grass_source(position)

func _create_gathering_place_visual(building: Node3D) -> void:
	var visual := GatheringPlaceVisualScene.instantiate() as Node3D
	building.add_child(visual)

func _fire_state_for(building: Node3D) -> RefCounted:
	return fire_management_service.fire_state_for(building)

func _apply_fire_state(building: Node3D, fire_state: RefCounted) -> void:
	fire_management_service.apply_fire_state(building, fire_state)

func _is_fire_lit(building: Node3D) -> bool:
	return fire_management_service.is_fire_lit(building)

func _apply_building_wear_and_repairs() -> void:
	building_maintenance_service.apply_building_wear_and_repairs(_destroy_building_to_pile)


func _destroy_building_to_pile(building: Node3D, building_type: String) -> void:
	building_maintenance_service.destroy_building_to_pile(building, building_type, citizens, warehouse_positions, campfire_node)



func _move_stored_resources_to_pile(resources: Dictionary, warehouse_index := -1) -> void:
	building_lifecycle_service.move_stored_resources_to_pile(resources, warehouse_index)


func _select_best_campfire() -> void:
	building_lifecycle_service.select_best_campfire()


func _refresh_boundary_markers() -> void:
	var territory: RefCounted = village_territory_service.territory()
	if world_setup.village_boundary_markers != null:
		world_setup.village_boundary_markers.refresh(territory)
	if world_setup.village_territory_overlay != null:
		world_setup.village_territory_overlay.refresh(territory)


func _show_territory_overlay(show: bool) -> void:
	if world_setup.village_territory_overlay != null:
		if show:
			world_setup.village_territory_overlay.refresh(village_territory_service.territory())
		world_setup.village_territory_overlay.visible = show

func _create_resource_pile(position: Vector3, resources: Dictionary, is_backpack_pile := false) -> Node3D:
	return resource_pile_service.create_resource_pile(position, resources, is_backpack_pile)


func _convert_backpack_pile_to_regular() -> void:
	backpack_node = resource_pile_service.convert_backpack_pile_to_regular(backpack_node)

func _drop_resource_pile(position: Vector3, resource_type: String, amount: int) -> void:
	resource_pile_service.drop_resource_pile(position, resource_type, amount)

func _decay_resource_piles() -> void:
	resource_pile_service.decay_resource_piles()


func _return_in_transit_building_supplies(building: Node3D) -> void:
	for citizen in citizens:
		if citizen.construction_site != building or citizen.state not in [Citizen.State.TO_CONSTRUCTION_PICKUP, Citizen.State.TO_CONSTRUCTION_SITE]:
			continue
		if citizen.carried_amount > 0 and not citizen.construction_delivery_resource.is_empty():
			settlement.add(citizen.construction_delivery_resource, citizen.carried_amount)
		citizen.carried_amount = 0
		citizen.construction_site = null
		citizen.idle()

func _get_delivery_position() -> Vector3:
	return _get_nearest_delivery_position(Vector3.ZERO)

func _get_nearest_delivery_position(from: Vector3) -> Vector3:
	var warehouse_index := storage_routing_service.find_reachable_warehouse_index(from, "", 1, false)
	if warehouse_index >= 0:
		return warehouse_positions[warehouse_index]
	if is_instance_valid(campfire_node) and _is_route_reachable(from, campfire_node.global_position, false):
		return campfire_node.global_position
	if is_instance_valid(entrance_stone):
		return entrance_stone.global_position
	return Vector3.ZERO


func _warehouse_delivery_position(from: Vector3, resource_type: String, amount: int) -> Vector3:
	return storage_routing_service.warehouse_delivery_position(from, resource_type, amount)


func _is_construction_site(node: Node3D) -> bool:
	return is_instance_valid(node) and construction.has_site(node)

func _cancel_selected_construction() -> void:
	if not is_instance_valid(selected_building) or not _is_construction_site(selected_building):
		return
	_unregister_service_pockets(selected_building)
	construction.cancel_site(selected_building)
	_close_context_menus()
	_update_interface("Construction cancelled. Refunded 50% of costs.")


func get_toilets() -> Array[Node3D]:
	var toilets: Array[Node3D] = []
	for record in building_registry.records():
		if is_instance_valid(record.node):
			var b_type: String = record.building_type
			if b_type.begins_with("toilet_"):
				toilets.append(record.node)
	return toilets


func _check_unstaffed_employment_center() -> void:
	if not _is_work_time():
		return
	
	var has_waiting_citizen := false
	var center := _employment_center_position()
	if center != Vector3.INF:
		for citizen in citizens:
			if is_instance_valid(citizen) and citizen.state in [Citizen.State.TO_EMPLOYMENT_CENTER, Citizen.State.EMPLOYMENT_PROCESSING]:
				if citizen.global_position.distance_to(center) <= 3.5:
					has_waiting_citizen = true
					break
	
	if has_waiting_citizen and not _is_registration_staffed():
		var current_time := runtime_seconds
		if current_time - _last_unstaffed_warning_time > 60.0:
			_last_unstaffed_warning_time = current_time
			_add_message(S.WARNING_NO_OFFICER)


func _toggle_worker_overtime(checked: bool) -> void:
	if not is_instance_valid(selected_building):
		return
	if checked:
		var night_order_used := int(selected_building.get_meta("night_work_order_day", -1)) == day_cycle.current_day
		if night_order_used:
			ui_manager.building_overtime_button.set_pressed_no_signal(false)
			return
		var workers_found := false
		for citizen in citizens:
			if is_instance_valid(citizen) and citizen.is_employed() and citizen.employment_workplace == selected_building:
				if citizen_daily_order_service.activate_citizen_overtime(citizen, "workplace") if citizen_daily_order_service != null else false:
					workers_found = true
		if workers_found:
			selected_building.set_meta("night_work_order_day", day_cycle.current_day)
			_add_message("Night-work order issued for %s." % building_registry.building_type_for_node(selected_building).replace("_", " "))
			_update_workers()
			if survival_event_controller != null:
				survival_event_controller.update_skip_night_button()
			if citizen_ai != null:
				citizen_ai.request_decision_refresh()
		else:
			ui_manager.building_overtime_button.set_pressed_no_signal(false)
	else:
		for citizen in citizens:
			if is_instance_valid(citizen) and citizen.employment_workplace == selected_building:
				citizen.deactivate_overtime("workplace")
		if citizen_daily_order_service != null:
			citizen_daily_order_service.sync_overtime_scope_indicators()
		_add_message("Night work cancelled for %s." % building_registry.building_type_for_node(selected_building).replace("_", " "))
		_update_workers()
		if survival_event_controller != null:
			survival_event_controller.update_skip_night_button()
		if citizen_ai != null:
			citizen_ai.request_decision_refresh()


func _toggle_campfire_worker_overtime(checked: bool) -> void:
	if not is_instance_valid(selected_campfire):
		return
	selected_building = selected_campfire
	_toggle_worker_overtime(checked)
	if campfire_menu_controller != null:
		campfire_menu_controller.refresh_campfire_menu()


func restore_from_save_data(save_data: SaveDataScript) -> bool:
	if save_data == null:
		return false

	# 1. Despawn current citizens
	for citizen in citizens.duplicate():
		if is_instance_valid(citizen):
			_on_ai_citizen_exiting(citizen.ai_id)
			citizen.queue_free()
	citizens.clear()

	# 2. Despawn current buildings and reset building registry
	for record in building_registry.records():
		if is_instance_valid(record.node):
			record.node.queue_free()
	building_registry = BuildingRegistry.new()
	if building_queue_service != null:
		building_queue_service.configure(building_registry, nav_grid)
	if village_territory_service != null:
		village_territory_service.configure(building_registry, int(settlement.era))
	if construction != null and construction.runtime != null:
		construction.runtime.building_registry = building_registry

	# Despawn current construction sites
	for site in construction_sites.duplicate():
		if is_instance_valid(site.node):
			site.node.queue_free()
	construction_sites.clear()

	# Despawn current resource piles
	for pile in resource_piles.duplicate():
		if pile != null and is_instance_valid(pile.node):
			pile.node.queue_free()
	resource_piles.clear()

	# Reset tracking arrays
	warehouse_positions.clear()
	sawmill_positions.clear()
	farm_positions.clear()
	builders_guild_positions.clear()
	construction_company_positions.clear()
	pond_positions.clear()
	forager_positions.clear()
	materials_yard_positions.clear()
	school_positions.clear()
	market_positions.clear()
	craft_tent_positions.clear()
	park_positions.clear()
	leisure_positions.clear()
	gathering_place_positions.clear()
	factories.clear()
	water_collectors.clear()
	house_lights.clear()
	entrance_lights.clear()
	service_pockets.clear()
	sawmill_stocks.clear()
	completed_house_count = 0
	canteen_food = 0
	settlement.buildings.clear()

	# 3. Restore Settlement State
	var s_dict: Dictionary = save_data.settlement_state
	SaveGameServiceScript.restore_settlement_state(settlement, s_dict)
	SaveGameServiceScript.restore_work_policy(settlement, s_dict.get("work_policy", {}))
	SaveGameServiceScript.restore_research(settlement, s_dict.get("research", {}))


	# 4. Restore Simulation Clock
	SaveGameServiceScript.restore_clock(clock, day_cycle, save_data.clock_state)

	# 5. Restore Camera State
	var cam_state := SaveGameServiceScript.restore_camera(save_data.camera_state)
	if not cam_state.is_empty():
		if cam_state.has("target"):
			camera_target = cam_state["target"]
		camera_distance = cam_state["distance"]
		camera_yaw = cam_state["yaw"]
		camera_pitch = cam_state["pitch"]

	# 6. Restore Placed Buildings
	for b_dict in save_data.buildings_state:
		var cell = SaveDataScript.dict_to_vector2i(b_dict.get("cell", {}))
		var b_type = str(b_dict.get("building_type", ""))
		var pos = SaveDataScript.dict_to_vector3(b_dict.get("position", {}))
		var rot_y = float(b_dict.get("rotation_y", 0.0))
		var rot_quarters = posmod(roundi(rot_y / 90.0), 4)

		var resolved := _resolve_saved_building_blueprint(b_type, b_dict)
		b_type = resolved.type
		var blueprint: Dictionary = resolved.blueprint
		if not blueprint.is_empty():
			var occupied_footprint = building_placement_controller.rotated_footprint(blueprint.footprint, rot_quarters) if building_placement_controller != null else blueprint.footprint
			building_registry.reserve(cell, pos, occupied_footprint)
			var site_node: Node3D = construction._get_site_scene().instantiate()
			site_node.position = pos
			site_node.rotation.y = rot_quarters * PI * 0.5
			site_node.set_meta("building_type", b_type)
			site_node.set_meta("footprint", blueprint.footprint)
			site_node.set_meta("occupied_footprint", occupied_footprint)
			site_node.set_meta("service_positions", BuildingEntrancePositionsScript.positions(site_node, blueprint.footprint, 1.0))
			add_child(site_node)
			for module in blueprint.modules:
				site_node.add_child(BuildingBlueprints.create_module(module))
			for child_name in ["ConstructionTerritory", "ConstructionProgressBack", "ConstructionProgressFill", "SupplyLabel", "ConstructionSelector", "ConstructionEntrance"]:
				var child := site_node.get_node_or_null(child_name)
				if child != null:
					child.queue_free()
			_complete_building(cell, b_type, pos, site_node, blueprint)
		else:
			push_warning("restore_from_save_data: skipping building with unknown type '" + b_type + "' at cell " + str(cell))

	# 7. Restore Construction Sites
	for c_dict in save_data.construction_sites_state:
		var cell = SaveDataScript.dict_to_vector2i(c_dict.get("cell", {}))
		var b_type = str(c_dict.get("building_type", ""))
		var pos = SaveDataScript.dict_to_vector3(c_dict.get("position", {}))
		var rot_y = float(c_dict.get("rotation_y", 0.0))
		var rot_quarters = posmod(roundi(rot_y / 90.0), 4)
		var progress = float(c_dict.get("progress", 0.0))
		var delivered = c_dict.get("delivered_materials", {}).duplicate()

		var resolved := _resolve_saved_building_blueprint(b_type, c_dict)
		b_type = resolved.type
		var blueprint: Dictionary = resolved.blueprint
		if not blueprint.is_empty():
			var occupied_footprint = building_placement_controller.rotated_footprint(blueprint.footprint, rot_quarters) if building_placement_controller != null else blueprint.footprint
			building_registry.reserve(cell, pos, occupied_footprint)
			var site = _create_construction_site(cell, b_type, pos, rot_quarters, blueprint, occupied_footprint)
			if site != null:
				site.progress = progress
				site.delivered_materials = delivered
				building_registry.attach_node(cell, site.node, b_type)
				_update_construction_supply_label(site)
		else:
			push_warning("restore_from_save_data: skipping construction site with unknown type '" + b_type + "' at cell " + str(cell))

	SaveGameServiceScript.restore_warehouses(settlement, s_dict.get("warehouses", []), s_dict.get("warehouse_types", []), bool(s_dict.get("warehouse_ever_built", false)))

	# 8. Restore Resource Piles
	for p_dict in save_data.resource_piles_state:
		if not (p_dict is Dictionary):
			continue
		var resources: Dictionary = p_dict.get("resources", {})
		if resources.is_empty():
			continue
		var pos = SaveDataScript.dict_to_vector3(p_dict.get("position", {}))
		var pile_node := _create_resource_pile(pos, resources, bool(p_dict.get("is_backpack", false)))
		if pile_node != null and bool(p_dict.get("landscape_owned", false)):
			pile_node.set_meta("landscape_owned", true)
			add_landscape_object(pile_node)
		if bool(p_dict.get("is_backpack", false)):
			backpack_node = pile_node

	# 8b. Restore Forest state (felled trees, branch/wood depletion)
	_restore_forest(save_data.forest_state)
	if ambient_spawner != null and save_data.world_state.get("natural_resources", {}) is Dictionary:
		ambient_spawner.restore_resource_state(save_data.world_state.get("natural_resources", {}))
	if road_network_service != null and save_data.world_state.get("roads", []) is Array:
		road_network_service.restore_state(save_data.world_state.get("roads", []))

	# 9. Restore Citizens
	_next_ai_citizen_id = int(save_data.world_state.get("next_ai_citizen_id", 1))
	hero_citizen = null
	for cit_dict in save_data.citizens_state:
		var pos = SaveDataScript.dict_to_vector3(cit_dict.get("position", {}))
		var is_hero = bool(cit_dict.get("is_hero", false))
		var saved_id = int(cit_dict.get("ai_id", 0))

		var citizen: Citizen = CitizenActorScene.instantiate()
		citizen.position = pos
		if cit_dict.has("first_name") and "first_name" in citizen:
			citizen.first_name = str(cit_dict.get("first_name", ""))
		if cit_dict.has("last_name") and "last_name" in citizen:
			citizen.last_name = str(cit_dict.get("last_name", ""))
		if cit_dict.has("age") and "age" in citizen:
			citizen.age = int(cit_dict.get("age", 25))

		citizen.random = random
		add_child(citizen)
		citizen.simulation = self
		citizen.setup_specialization(str(cit_dict.get("specialization", "unassigned")))
		_wire_citizen(citizen)

		citizens.append(citizen)
		citizen.ai_id = saved_id if saved_id > 0 else _next_ai_citizen_id
		if citizen.ai_id >= _next_ai_citizen_id:
			_next_ai_citizen_id = citizen.ai_id + 1

		citizen_ai.register_citizen(citizen.ai_id, SettlementCitizenActuatorScript.new(citizen, _ai_target_for_key))
		citizen.tree_exiting.connect(_on_ai_citizen_exiting.bind(citizen.ai_id), CONNECT_ONE_SHOT)

		var needs_dict: Dictionary = cit_dict.get("needs", {})
		citizen.hunger = float(needs_dict.get("hunger", 100.0))
		citizen.fatigue = float(needs_dict.get("fatigue", 0.0))
		# `comfort` was the v1 name; v2 stores the actual needs-domain field.
		citizen.satisfaction = float(needs_dict.get("satisfaction", needs_dict.get("comfort", 72.0)))
		citizen.continuous_work_hours = maxf(0.0, float(needs_dict.get("continuous_work_hours", 0.0)))
		citizen.satisfaction_tick = float(needs_dict.get("satisfaction_tick", 0.0))
		citizen.recovery_until_workday_id = maxi(0, int(needs_dict.get("recovery_until_workday_id", 0)))
		if needs_dict.get("buffs", {}) is Dictionary:
			citizen.buffs = (needs_dict.get("buffs") as Dictionary).duplicate(true)
		if needs_dict.get("debuffs", {}) is Dictionary:
			citizen.debuffs = (needs_dict.get("debuffs") as Dictionary).duplicate(true)
		citizen.active_role = str(cit_dict.get("active_role", ""))
		citizen.employment_state = int(cit_dict.get("employment_state", Citizen.EmploymentState.NO_PERMANENT_WORK))
		citizen.permanent_role = str(cit_dict.get("permanent_role", ""))
		citizen.daily_order_role = str(cit_dict.get("daily_order_role", ""))
		if cit_dict.get("employment_building_cell", {}) is Dictionary:
			var employment_cell := SaveDataScript.dict_to_vector2i(cit_dict.get("employment_building_cell", {}))
			var employment_record = building_registry.record_at_cell(employment_cell)
			if employment_record != null and is_instance_valid(employment_record.node):
				citizen.employment_workplace = employment_record.node
				var saved_zone_id := StringName(str(cit_dict.get("employment_zone_id", "")))
				if saved_zone_id != &"" and building_zone_service != null:
					building_zone_service.assign_to_zone(
						employment_record.node,
						saved_zone_id,
						StringName(citizen.permanent_role),
						citizen.ai_id
					)

		var pockets: Array = cit_dict.get("pockets", [])
		for p_item in pockets:
			if p_item is Dictionary and p_item.has("resource_id"):
				citizen.pockets_add(str(p_item["resource_id"]), int(p_item.get("amount", 1)))

		if is_hero:
			hero_citizen = citizen
			citizen.set_hero(true)
			citizen.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK

	# 10. Re-initialize AI and Interfaces
	_refresh_living_statuses()
	_refresh_navigation_grid()
	_update_workers()
	if building_menu_controller != null:
		building_menu_controller.refresh_build_menu()

	if hero_citizen != null:
		player_controller.enter_first_person(hero_citizen, "Save loaded.")
	return true


func _resolve_saved_building_blueprint(saved_type: String, data: Dictionary) -> Dictionary:
	var resolved_type := saved_type
	var reference: Dictionary = data.get("blueprint_ref", {})
	if not reference.is_empty():
		var referenced_type := BuildingBlueprintLibraryScript.resolve_reference(reference)
		if not referenced_type.is_empty():
			resolved_type = referenced_type
			var referenced_blueprint: Variant = BuildingBlueprintLibraryScript.get_blueprint(referenced_type)
			var saved_revision: String = str(reference.get("revision", ""))
			if referenced_blueprint != null and not saved_revision.is_empty() and referenced_blueprint.content_revision() != saved_revision:
				push_warning("Blueprint '%s:%s' changed since this save; current file geometry will be used." % [
					reference.get("source", "builtin"), reference.get("id", "")])
		else:
			var fallback := str(reference.get("fallback_building_id", "house"))
			if BuildingCatalog.has_definition(fallback):
				resolved_type = fallback
				push_warning("Missing blueprint '%s:%s'; restored as fallback '%s'." % [
					reference.get("source", "builtin"), reference.get("id", ""), fallback])
			else:
				push_warning("Missing blueprint and invalid fallback for '%s:%s'." % [
					reference.get("source", "builtin"), reference.get("id", "")])
				return {"type": saved_type, "blueprint": {}}
	var blueprint: Dictionary = BuildingBlueprints.get_blueprint(resolved_type)
	var saved_zones: Variant = data.get("zone_state", [])
	if saved_zones is Array and not saved_zones.is_empty() and not blueprint.is_empty():
		blueprint = blueprint.duplicate(true)
		blueprint["saved_zone_state"] = saved_zones.duplicate(true)
		blueprint["work_zones"] = saved_zones.duplicate(true)
		blueprint["blueprint_ref"] = reference.duplicate(true)
	return {"type": resolved_type, "blueprint": blueprint}


## Overlays saved per-tree state onto the freshly generated forest. The forest
## layout is deterministic (fixed cells), so trees are matched by cell rather
## than despawned and rebuilt. Older saves omit `forest` and leave it pristine.
func _restore_forest(tree_states: Array) -> void:
	world_resource_state.restore_tree_state(tree_states)
	for entry in tree_states:
		if not (entry is Dictionary):
			continue
		var cell := SaveDataScript.dict_to_vector2i(entry.get("cell", {}))
		var tree: Node3D = tree_nodes.get(cell)
		if not is_instance_valid(tree):
			continue
		if bool(entry.get("branch_exhausted", false)):
			foraging_service.mark_tree_branch_exhausted(cell)
		var tree_state: Variant = world_resource_state.tree_at(cell)
		if tree_state != null:
			tree.set_meta("initial_wood", tree_state.initial_wood)
			tree.set_meta("remaining_wood", tree_state.remaining_wood)
			tree.set_meta("initial_branches", tree_state.initial_branches)
			tree.set_meta("remaining_branches", tree_state.remaining_branches)
			tree.set_meta("hand_branches", tree_state.hand_branches)
			tree.set_meta("branch_exhausted", tree_state.branch_exhausted)
		if tree_state != null and tree_state.felled:
			_apply_tree_felled_visual(cell, tree)
