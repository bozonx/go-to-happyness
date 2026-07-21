extends Node3D

const SETTLEMENT_RULES = preload("res://game/features/settlement/domain/settlement_rules.gd")
const CitizenActorScene = preload("res://game/features/citizens/presentation/citizen_actor.tscn")
const UIManagerScene = preload("res://game/features/ui/presentation/ui_manager.tscn")
const CameraControllerScene = preload("res://game/features/world/presentation/camera_controller.tscn")
const FireLightScene = preload("res://game/features/buildings/presentation/fire_light.tscn")
const HouseLightScene = preload("res://game/features/buildings/presentation/house_light.tscn")
const BuildingSelectorScene = preload("res://game/features/buildings/presentation/building_selector.tscn")
const EntranceMarkerScene = preload("res://game/features/buildings/presentation/entrance_marker.tscn")
const BillboardLabelScene = preload("res://game/features/ui/presentation/billboard_label.tscn")
const GatheringPlaceVisualScene = preload("res://game/features/buildings/presentation/gathering_place_visual.tscn")
const PocketTakeItemRowScene = preload("res://game/features/citizens/presentation/pocket_take_item_row.tscn")
const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")
const CampfireMenuControllerScript = preload("res://game/features/settlement/presentation/campfire_menu_controller.gd")
const WorkforceMenuControllerScript = preload("res://game/features/settlement/presentation/workforce_menu_controller.gd")
const ResearchMenuControllerScript = preload("res://game/features/buildings/presentation/research_menu_controller.gd")
const SchoolMenuControllerScript = preload("res://game/features/buildings/presentation/school_menu_controller.gd")
const EntranceMenuControllerScript = preload("res://game/features/buildings/presentation/entrance_menu_controller.gd")
const HouseMenuControllerScript = preload("res://game/features/buildings/presentation/house_menu_controller.gd")
const PocketTakeMenuControllerScript = preload("res://game/features/citizens/presentation/pocket_take_menu_controller.gd")
const FireSourceStateScript = preload("res://game/features/settlement/domain/fire_source_state.gd")
const CourierDispatcherScript = preload("res://game/features/logistics/application/courier_dispatcher.gd")
const CourierTaskServiceScript = preload("res://game/features/logistics/application/courier_task_service.gd")
const CourierTaskPublisherScript = preload("res://game/features/logistics/application/courier_task_publisher.gd")
const CourierTaskScript = preload("res://game/features/logistics/domain/courier_task.gd")
const TradeServiceScript = preload("res://game/features/logistics/application/trade_service.gd")
const MarketMenuControllerScript = preload("res://game/features/logistics/presentation/market_menu_controller.gd")
const WarehouseMenuControllerScript = preload("res://game/features/logistics/presentation/warehouse_menu_controller.gd")
const WarehouseFillLabelControllerScript = preload("res://game/features/logistics/presentation/warehouse_fill_label_controller.gd")
const StorageDeliveryServiceScript = preload("res://game/features/logistics/application/storage_delivery_service.gd")
const StorageRoutingServiceScript = preload("res://game/features/logistics/application/storage_routing_service.gd")
const BuildingAvailabilityServiceScript = preload("res://game/features/buildings/application/building_availability_service.gd")
const BuildingMenuControllerScript = preload("res://game/features/buildings/presentation/building_menu_controller.gd")
const BuildingStatusIndicatorControllerScript = preload("res://game/features/buildings/presentation/building_status_indicator_controller.gd")
const FirstPersonHUDControllerScript = preload("res://game/features/ui/presentation/first_person_hud_controller.gd")
const LabelDistanceFadeControllerScript = preload("res://game/features/ui/presentation/label_distance_fade_controller.gd")
const BuildingLifecycleServiceScript = preload("res://game/features/buildings/application/building_lifecycle_service.gd")
const BuildingResearchServiceScript = preload("res://game/features/buildings/application/building_research_service.gd")
const BuildingQueueServiceScript = preload("res://game/features/citizens/application/building_queue_service.gd")
const CitizenLifecycleServiceScript = preload("res://game/features/citizens/application/citizen_lifecycle_service.gd")
const CitizenLivingStatusServiceScript = preload("res://game/features/citizens/application/citizen_living_status_service.gd")
const CitizenStatusEffectScript = preload("res://game/features/citizens/domain/citizen_status_effect.gd")
const CitizenRegistrationServiceScript = preload("res://game/features/citizens/application/citizen_registration_service.gd")
const SchoolServiceScript = preload("res://game/features/buildings/application/school_service.gd")
const BuildingPlacementServiceScript = preload("res://game/features/buildings/application/building_placement_service.gd")
const BuildingVisualsServiceScript = preload("res://game/features/buildings/presentation/building_visuals_service.gd")
const CitizenDailyOrderServiceScript = preload("res://game/features/citizens/application/citizen_daily_order_service.gd")
const HeroPocketServiceScript = preload("res://game/features/citizens/application/hero_pocket_service.gd")
const HeroInteractionServiceScript = preload("res://game/features/citizens/application/hero_interaction_service.gd")
const WorkplaceLaborServiceScript = preload("res://game/features/settlement/application/workplace_labor_service.gd")
const SleepGoalScript = preload("res://game/features/decision/domain/goals/sleep_goal.gd")
const ReturnHomeWhenIdleGoalScript = preload("res://game/features/decision/domain/goals/return_home_when_idle_goal.gd")
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
const SettlementCitizenActuatorScript = preload("res://game/features/decision/application/settlement_citizen_actuator.gd")
const RegisterGoalScript = preload("res://game/features/decision/domain/goals/register_goal.gd")
const WorkforceOrderProviderScript = preload("res://game/features/decision/application/workforce_order_provider.gd")
const DailyPlayerOrderProviderScript = preload("res://game/features/decision/application/daily_player_order_provider.gd")
const CleaningGoalScript = preload("res://game/features/decision/domain/goals/cleaning_goal.gd")
const RouteRequestScript = preload("res://game/features/routing/application/route_request.gd")
const TrailFieldServiceScript = preload("res://game/features/routing/application/trail_field_service.gd")
const WeatherStateScript = preload("res://game/features/simulation/domain/weather_state.gd")
const CameraControllerScript = preload("res://game/features/world/presentation/camera_controller.gd")
const WorldSetupScene = preload("res://game/features/world/presentation/world_setup.tscn")
const EventServiceScript = preload("res://game/features/events/application/event_service.gd")
const EventRegistryScript = preload("res://game/features/events/domain/event_registry.gd")
const EventLogScript = preload("res://game/features/events/domain/event_log.gd")
const EventContextScript = preload("res://game/features/events/domain/event_context.gd")
const EventOutcomeScript = preload("res://game/features/events/domain/event_outcome.gd")
const TentEraEventsScript = preload("res://game/features/events/application/tent_era_events.gd")
const VillageTerritoryServiceScript = preload("res://game/features/buildings/application/village_territory_service.gd")
const DigSiteScene = preload("res://game/features/world/presentation/dig_site.tscn")
const ExcavationServiceScript = preload("res://game/features/production/application/excavation_service.gd")
const SettlementSurvivalServiceScript = preload("res://game/features/settlement/application/settlement_survival_service.gd")
const SettlementDailyRulesServiceScript = preload("res://game/features/settlement/application/settlement_daily_rules_service.gd")
const TerritoryServiceScript = preload("res://game/features/world/application/territory_service.gd")


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
const PLAYER_SPEED := 4.2
const PLAYER_SPRINT_MULTIPLIER := 1.8
const PLAYER_JUMP_VELOCITY := 6.5
const PLAYER_GRAVITY := 18.0
const PLAYER_EYE_HEIGHT := 1.65
const HARVEST_DURATION := 1.25
const INTERACTION_RANGE := 4.5
const JOB_ENTRANCE_RANGE := 3.5
# Layer 8 carries invisible occluders for the sun-flare raycast only (e.g. tree
# crowns, which have no physics collider of their own), so the flare hides behind
# foliage without the occluders affecting citizen movement or navigation.
const FLARE_OCCLUDER_LAYER := 8
const SUN_FLARE_OCCLUSION_MASK := 1 | FLARE_OCCLUDER_LAYER
const SUN_FLARE_OCCLUSION_DISTANCE := 96.0
const SUN_FLARE_OCCLUSION_SMOOTHING := 0.08
const POCKET_CAPACITY := 8
const POCKET_WOOD_CAPACITY := POCKET_CAPACITY
# The hero gathers raw bootstrap materials in a batch per action, unlike NPCs who
# fetch one-to-two at a time. This is the player's lever to force a direction:
# playing the hero rushes what the officer's plan would otherwise trickle in.
const HERO_GATHER_YIELD := 3
const SAWMILL_PROCESS_DURATION := 4.0
const SAWMILL_WORKER_DELIVERY_THRESHOLD := 4
const COURIER_LATE_SECONDS := 12.0
const DIG_RADIUS := 2.2
const DIG_REACH := 6.0
# In first-person view, 3D labels fade out with camera distance.
const LABEL_FADE_NEAR := 8.0
const LABEL_FADE_FAR := 22.0

var settlement := SettlementState.new()
var wood: int:
	get: return settlement.amount("wood")
	set(value): _set_resource_amount("wood", value)
var food: int:
	get: return settlement.amount("food")
	set(value): _set_resource_amount("food", value)
var soil: int:
	get: return settlement.amount("soil")
	set(value): _set_resource_amount("soil", value)
var clay: int:
	get: return settlement.amount("clay")
	set(value): _set_resource_amount("clay", value)
var boards: int:
	get: return settlement.amount("boards")
	set(value): _set_resource_amount("boards", value)
var bricks: int:
	get: return settlement.amount("bricks")
	set(value): _set_resource_amount("bricks", value)
var stone: int:
	get: return settlement.amount("stone")
	set(value): _set_resource_amount("stone", value)
var branches: int:
	get: return settlement.amount("branches")
	set(value): _set_resource_amount("branches", value)
var grass: int:
	get: return settlement.amount("grass")
	set(value): _set_resource_amount("grass", value)
var water: int:
	get: return settlement.amount("water")
	set(value): _set_resource_amount("water", value)
var hides: int:
	get: return settlement.amount("hides")
	set(value): _set_resource_amount("hides", value)
var goods: int:
	get: return settlement.amount("goods")
	set(value): _set_resource_amount("goods", value)
var tarp: int:
	get: return settlement.amount("tarp")
	set(value): _set_resource_amount("tarp", value)
var logs: int:
	get: return settlement.amount("logs")
	set(value): _set_resource_amount("logs", value)
var money: int:
	get: return settlement.money
	set(value): settlement.money = value


func _set_resource_amount(resource_type: String, value: int) -> void:
	if settlement.uses_virtual_storage():
		settlement.virtual_stock[resource_type] = value
	else:
		match resource_type:
			"wood": settlement.wood = value
			"food": settlement.food = value
			"soil": settlement.soil = value
			"clay": settlement.clay = value
			"boards": settlement.boards = value
			"bricks": settlement.bricks = value
			"stone": settlement.stone = value
			"branches": settlement.branches = value
			"grass": settlement.grass = value
			"water": settlement.water = value
			"hides": settlement.hides = value
			"goods": settlement.goods = value
			"tarp": settlement.tarp = value
			"logs": settlement.logs = value
var wellbeing: int:
	get: return settlement.wellbeing
	set(value): settlement.wellbeing = value
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
const OFFICIAL_WORKPLACE_TYPES: Array[String] = ["campfire", "campfire_lvl2", "campfire_lvl3", "earth_assembly", "clay_lodge", "wood_town_hall", "stone_prefecture", "brick_city_hall"]
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
var tree_cells: Dictionary = {}
var terrain_blocked_cells: Dictionary = {}
var navigation_blocked_cells: Dictionary = {}
var warehouse_positions: Array[Vector3] = []
var sawmill_positions: Array[Vector3] = []
var sawmill_stocks: Dictionary = {}
var grass_sources: Dictionary = {} # cell -> {node, remaining}; finite patches around trees
var forage_sources: Dictionary = {} # cell -> {node}; wild edible plants, one harvest each
var rabbit_sources: Dictionary = {} # cell -> {node, direction}; simple moving meadow animals
var forage_respawn_at: Dictionary = {}
var rabbit_respawn_at: Dictionary = {}
const WILD_FOOD_RESPAWN_SECONDS := 45.0
const RABBIT_RESPAWN_SECONDS := 60.0
const RABBIT_MAX_COUNT := 8
var outside_workers: Dictionary = {} # citizen instance id -> {citizen, return_at_minute}
var last_citizen_positions: Dictionary = {}
var resource_piles: Array[Dictionary] = []
var backpack_node: Node3D
var backpack_position: Vector3
var farm_positions: Array[Vector3] = []
var builders_guild_positions: Array[Vector3] = []
var construction_company_positions: Array[Vector3] = []
var pond_positions: Array[Vector3] = []
var forager_positions: Array[Vector3] = []
var materials_yard_positions: Array[Vector3] = []
var school_positions: Array[Vector3] = []
var market_positions: Array[Vector3] = []
var craft_tent_positions: Array[Vector3] = []
var park_positions: Array[Vector3] = []
var leisure_positions: Array[Vector3] = []
var gathering_place_positions: Array[Vector3] = []
var factories: Array[Node3D] = []
var tree_positions: Array[Vector3] = []
var tree_nodes: Dictionary = {}
var gather_progress_labels: Dictionary = {} # resource Node3D -> Label3D
var citizens: Array[Citizen] = []
var camera: Camera3D:
	get: return camera_controller.camera if camera_controller != null else null
var camera_controller: CameraController
var world_setup: Node
var sun: DirectionalLight3D:
	get: return world_setup.sun if world_setup != null else null
var world_environment: Environment:
	get: return world_setup.world_environment if world_setup != null else null
var sky_material: ShaderMaterial:
	get: return world_setup.sky_material if world_setup != null else null
var weather_state := WeatherStateScript.new()
var rain_effect: RainEffect:
	get: return world_setup.rain_effect if world_setup != null else null
var fireflies: Array[FirefliesEffect]:
	get: return world_setup.fireflies if world_setup != null else []
var lens_flare_material: ShaderMaterial:
	get: return world_setup.lens_flare_material if world_setup != null else null
var lens_flare_visibility := 0.0
var lens_flare_occlusion := 1.0
var sky_and_weather_controller: SkyAndWeatherController:
	get: return world_setup.sky_and_weather_controller if world_setup != null else null
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
var selection_marker: MeshInstance3D:
	get: return world_setup.selection_marker if world_setup != null else null
var selection_material: StandardMaterial3D:
	get: return world_setup.selection_material if world_setup != null else null
var preview_entrance_marker: MeshInstance3D:
	get: return world_setup.preview_entrance_marker if world_setup != null else null
var preview_back_entrance_marker: MeshInstance3D:
	get: return world_setup.preview_back_entrance_marker if world_setup != null else null
var hud: HUD:
	get: return ui_manager.hud if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.hud = val
var message_log_panel: MessageLogPanel:
	get: return ui_manager.message_log_panel if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.message_log_panel = val
var message_panel: Control:
	get: return ui_manager.message_panel if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.message_panel = val
var messages_modal: Control:
	get: return ui_manager.messages_modal if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.messages_modal = val
var current_day: int:
	get: return day_cycle.current_day
var tent_weather: int = TentEraSurvivalRulesScript.Weather.WARMING
var selected_builder: Citizen
var selected_building: Node3D
var build_menu: BuildMenu:
	get: return ui_manager.build_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.build_menu = val
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

var build_toggle_btn: Button:
	get: return ui_manager.build_toggle_btn if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.build_toggle_btn = val
var interaction_hint_panel: Control:
	get: return ui_manager.interaction_hint_panel if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.interaction_hint_panel = val
var interaction_hint_label: Label:
	get: return interaction_hint_panel.hint_label if interaction_hint_panel != null else null
var interaction_progress: ProgressBar:
	get: return interaction_hint_panel.progress_bar if interaction_hint_panel != null else null
var pocket_take_menu: PocketTakeMenu:
	get: return ui_manager.pocket_take_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.pocket_take_menu = val
var crosshair: FirstPersonCrosshair:
	get: return ui_manager.crosshair if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.crosshair = val
var house_menu: Panel:
	get: return ui_manager.house_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.house_menu = val
var house_menu_title: Label:
	get: return ui_manager.house_menu_title if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.house_menu_title = val
var house_spawn_button: Button:
	get: return ui_manager.house_spawn_button if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.house_spawn_button = val
var entrance_menu: Panel:
	get: return ui_manager.entrance_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.entrance_menu = val
var entrance_menu_title: Label:
	get: return ui_manager.entrance_menu_title if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.entrance_menu_title = val
var entrance_work_button: Button:
	get: return ui_manager.entrance_work_button if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.entrance_work_button = val
var entrance_order_modal: Panel:
	get: return ui_manager.entrance_order_modal if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.entrance_order_modal = val
var entrance_order_food_spin: SpinBox:
	get: return ui_manager.entrance_order_food_spin if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.entrance_order_food_spin = val
var entrance_order_water_spin: SpinBox:
	get: return ui_manager.entrance_order_water_spin if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.entrance_order_water_spin = val
var entrance_order_gloves_spin: SpinBox:
	get: return ui_manager.entrance_order_gloves_spin if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.entrance_order_gloves_spin = val
var entrance_order_bucket_spin: SpinBox:
	get: return ui_manager.entrance_order_bucket_spin if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.entrance_order_bucket_spin = val
var entrance_order_total_label: Label:
	get: return ui_manager.entrance_order_total_label if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.entrance_order_total_label = val
var school_menu: Panel:
	get: return ui_manager.school_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.school_menu = val
var materials_factory_menu: Panel:
	get: return ui_manager.materials_factory_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.materials_factory_menu = val
var materials_factory_menu_title: Label:
	get: return ui_manager.materials_factory_menu_title if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.materials_factory_menu_title = val
var campfire_menu: CampfireMenu:
	get: return ui_manager.campfire_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.campfire_menu = val
var workforce_menu: WorkforceMenu:
	get: return ui_manager.workforce_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.workforce_menu = val
var research_menu: ResearchMenu:
	get: return ui_manager.research_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.research_menu = val
var market_menu: MarketMenu:
	get: return ui_manager.market_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.market_menu = val
var warehouse_menu: WarehouseMenu:
	get: return ui_manager.warehouse_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.warehouse_menu = val
var building_menu: Panel:
	get: return ui_manager.building_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.building_menu = val
var building_menu_title: Label:
	get: return ui_manager.building_menu_title if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.building_menu_title = val
var building_cook_button: Button:
	get: return ui_manager.building_cook_button if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.building_cook_button = val
var building_teacher_button: Button:
	get: return ui_manager.building_teacher_button if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.building_teacher_button = val
var building_seller_button: Button:
	get: return ui_manager.building_seller_button if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.building_seller_button = val
var building_accept_workers_button: Button:
	get: return ui_manager.building_accept_workers_button if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.building_accept_workers_button = val
var building_dismiss_worker_button: Button:
	get: return ui_manager.building_dismiss_worker_button if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.building_dismiss_worker_button = val
var building_upgrade_button: Button:
	get: return ui_manager.building_upgrade_button if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.building_upgrade_button = val
var building_demolish_button: Button:
	get: return ui_manager.building_demolish_button if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.building_demolish_button = val
var building_close_button: Button:
	get: return ui_manager.building_close_button if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.building_close_button = val
var building_overtime_button: CheckButton:
	get: return ui_manager.building_overtime_button if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.building_overtime_button = val
var building_relight_button: Button:
	get: return ui_manager.building_relight_button if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.building_relight_button = val
var campfire_story_menu: Control:
	get: return ui_manager.campfire_story_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.campfire_story_menu = val
var building_cancel_construction_button: Button:
	get: return ui_manager.building_cancel_construction_button if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.building_cancel_construction_button = val
var decision_menu: Control:
	get: return ui_manager.decision_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.decision_menu = val
var time_controls_panel: TimeControlsPanel:
	get: return ui_manager.time_controls_panel if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.time_controls_panel = val
var campfire_orders_menu: CampfireOrdersMenu:
	get: return ui_manager.campfire_orders_menu if ui_manager != null else null
	set(val): if ui_manager != null: ui_manager.campfire_orders_menu = val
var pocket_take_menu_title: Label:
	get: return pocket_take_menu.title_label if pocket_take_menu != null else null
var pocket_menu_open := false
var pocket_take_warehouse_index: int = -1
var dig_sites: Array[Dictionary] = []
var dig_cells: Dictionary = {}
var exhausted_dig_cells: Dictionary = {}
var dig_mode := false
var excavation_service: ExcavationServiceScript
var selected_house: Node3D
var tent: Node3D
var entrance_stone: Node3D
var entrance_highlight: MeshInstance3D
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
var _route_reachability_cache: Dictionary = {}
var _route_reachability_cache_revision := -1
const ROUTE_REACHABILITY_CACHE_LIMIT := 1024
var service_pockets: Array[Dictionary] = []
var selected_school: Node3D
var school_developed_professions: Dictionary = {
	"construction": false,
	"forestry": false,
	"farming": false,
	"excavation": false,
	"factory_worker": false,
	"engineer": false,
	"cook": false,
	"teacher": false,
	"seller": false
}
var selected_materials_factory: Node3D
var campfire_node: Node3D = null
var selected_campfire: Node3D = null
var selected_market: Node3D = null
var selected_warehouse: Node3D = null
var campfire_story_buttons: Array[Button] = []
var survival_decision_panel: Control:
	get: return decision_menu
var _decision_buttons: Array[Button] = []
var event_service: EventService
var survival_busy_until: Dictionary = {}
var house_lights: Array[Dictionary] = []
var house_light_update_minute := -1
var entrance_lights: Array[OmniLight3D] = []
var build_category := ""
var build_menu_is_job_menu := false
var build_menu_is_daily_order_menu := false
var build_menu_is_global := false
var skip_night_button: Button:
	get: return time_controls_panel.skip_night_button if time_controls_panel != null else null
var start_workday_button: Button:
	get: return time_controls_panel.start_workday_button if time_controls_panel != null else null
var water_collectors: Array[Dictionary] = []
var pending_trades: Dictionary = {} # worker instance id -> TradeOrder
var queued_trades: Array = []
var building_status_indicators: Array[Label3D] = []
var building_status_update_time := 0.0
var workplace_priority_counter := 0
var citizen_ai: CitizenAISystem
var citizen_needs_service: CitizenNeedsService
var citizen_living_status_service: RefCounted
## Monotonic source of stable citizen AI identity. Persist it alongside the roster
## once save/load is introduced so reloaded games issue non-colliding ids.
var _next_ai_citizen_id := 1
var route_service: GridRouteService
var building_queue_service: RefCounted
var citizen_lifecycle_service: CitizenLifecycleServiceScript
var building_availability_service: RefCounted
var building_research_service: RefCounted
var village_territory_service: RefCounted
var sawmills: SawmillService
var construction: ConstructionService
var demolition: DemolitionService
var water_collector_service: WaterCollectorService
var canteen_service: CanteenService
var trade_service: TradeService
var storage_delivery_service: RefCounted
var storage_routing_service: StorageRoutingServiceScript
var courier_dispatcher: RefCounted
var courier_task_publisher: RefCounted
var courier_task_service: CourierTaskServiceScript
var campfire_menu_controller: RefCounted
var workforce_menu_controller: RefCounted
var research_menu_controller: RefCounted
var school_menu_controller: RefCounted
var entrance_menu_controller: RefCounted
var house_menu_controller: RefCounted
var pocket_take_menu_controller: RefCounted
var market_menu_controller: RefCounted
var warehouse_menu_controller: RefCounted
var warehouse_fill_label_controller: RefCounted
var building_menu_controller: RefCounted
var building_status_indicator_controller: RefCounted
var first_person_hud_controller: RefCounted
var label_distance_fade_controller: RefCounted
var trail_field: TrailFieldService
var trail_overlay: MeshInstance3D:
	get: return world_setup.trail_overlay if world_setup != null else null
var trail_overlay_material: ShaderMaterial:
	get: return world_setup.trail_overlay_material if world_setup != null else null
var village_boundary_markers: Node3D:
	get: return world_setup.village_boundary_markers if world_setup != null else null
var village_territory_overlay: Node3D:
	get: return world_setup.village_territory_overlay if world_setup != null else null
var resource_pile_service: ResourcePileService
var foraging_service: ForagingService
var fire_management_service: FireManagementService
var building_maintenance_service: BuildingMaintenanceService
var building_lifecycle_service: BuildingLifecycleServiceScript
var settlement_survival_service: SettlementSurvivalServiceScript
var settlement_daily_rules_service: SettlementDailyRulesServiceScript
var territory_service: TerritoryServiceScript
var citizen_registration_service: RefCounted
var school_service: RefCounted
var building_placement_service: RefCounted
var citizen_daily_order_service: RefCounted
var hero_pocket_service: RefCounted
var hero_interaction_service: RefCounted
var workplace_labor_service: RefCounted
var building_visuals_service: RefCounted


func _ready() -> void:
	hero_pocket_service = HeroPocketServiceScript.new()
	hero_pocket_service.configure(self)
	hero_interaction_service = HeroInteractionServiceScript.new()
	hero_interaction_service.configure(self)
	workplace_labor_service = WorkplaceLaborServiceScript.new()
	workplace_labor_service.configure(self)
	building_visuals_service = BuildingVisualsServiceScript.new()
	building_visuals_service.configure(self)
	territory_service = TerritoryServiceScript.new()
	var summer_valley_biome := load("res://game/features/world/presentation/biomes/summer/summer_valley/summer_valley_biome.tres") as BiomeDefinition
	var summer_plains_biome := load("res://game/features/world/presentation/biomes/summer/summer_plains/summer_plains_biome.tres") as BiomeDefinition
	if summer_valley_biome != null:
		territory_service.register_biome(summer_valley_biome)
	if summer_plains_biome != null:
		territory_service.register_biome(summer_plains_biome)
	territory_service.set_active_biome(&"summer_valley")

	citizen_ai = CitizenAISystem.new()
	citizen_ai.name = "CitizenAI"
	add_child(citizen_ai)
	nav_grid = NavGrid.new()
	nav_grid.configure(CELL_SIZE, BOARD_CELLS)
	trail_field = TrailFieldServiceScript.new()
	trail_field.configure(BOARD_CELLS * CELL_SIZE, CELL_SIZE, nav_grid)
	route_service = GridRouteService.new()
	route_service.configure(nav_grid)
	building_queue_service = BuildingQueueServiceScript.new()
	building_queue_service.configure(building_registry, nav_grid)
	building_queue_service.set_citizen_alive_checker(_is_ai_citizen_id_alive)
	citizen_lifecycle_service = CitizenLifecycleServiceScript.new()
	citizen_lifecycle_service.configure(self)
	building_availability_service = BuildingAvailabilityServiceScript.new()
	building_availability_service.configure(settlement)
	building_research_service = BuildingResearchServiceScript.new()
	building_research_service.configure(settlement)
	village_territory_service = VillageTerritoryServiceScript.new()
	village_territory_service.configure(building_registry, int(settlement.era))
	sawmills = SawmillService.new()
	sawmills.configure(self)
	var construction_runtime := ConstructionRuntime.new()
	construction_runtime.scene_root = self
	construction_runtime.settlement = settlement
	construction_runtime.building_registry = building_registry
	construction_runtime.citizens = citizens
	construction_runtime.duration = CONSTRUCTION_DURATION
	construction_runtime.builder_power = _building_power
	construction_runtime.builder_count = _builder_count
	construction_runtime.set_status = _set_construction_status
	construction_runtime.building_completed = _complete_building
	construction_runtime.workers_changed = _update_workers
	construction_runtime.navigation_changed = _refresh_navigation_grid
	construction = ConstructionService.new()
	construction.configure(construction_runtime)
	var demolition_runtime := DemolitionRuntime.new()
	demolition_runtime.duration = DEMOLITION_DURATION
	demolition_runtime.building_power = _building_power
	demolition_runtime.is_ready = _demolition_ready
	demolition_runtime.completed = _finish_demolition
	demolition = DemolitionService.new()
	demolition.configure(demolition_runtime)
	water_collector_service = WaterCollectorService.new()
	water_collector_service.configure(self)
	canteen_service = CanteenService.new()
	canteen_service.configure(self)
	resource_pile_service = ResourcePileService.new(self, resource_piles, settlement, weather_state)
	foraging_service = ForagingService.new()
	foraging_service.setup(
		settlement,
		forager_positions,
		forage_sources,
		forage_respawn_at,
		rabbit_sources,
		rabbit_respawn_at,
		grass_sources,
		tree_nodes,
		tree_positions,
		gather_progress_labels,
		_terrain_height_at,
		_cell_from_position,
		_first_person_target
	)
	fire_management_service = FireManagementService.new()
	fire_management_service.setup(
		building_registry,
		event_service,
		settlement,
		day_cycle,
		func() -> int: return int(game_minutes),
		func() -> Node3D: return campfire_node,
		_add_message,
		_refresh_living_statuses,
		func() -> void: wellbeing = maxi(0, wellbeing - 1)
	)
	building_maintenance_service = BuildingMaintenanceService.new()
	building_maintenance_service.setup(
		building_registry,
		settlement,
		village_territory_service,
		resource_pile_service,
		{
			"unregister_pockets": _unregister_service_pockets,
			"move_stored_resources": _move_stored_resources_to_pile,
			"return_supplies": _return_in_transit_building_supplies,
			"remove_services": _remove_building_services,
			"unregister_nav_footprint": _unregister_navigation_footprint,
			"refresh_boundary": _refresh_boundary_markers,
			"select_best_campfire": _select_best_campfire,
			"refresh_nav_grid": _refresh_navigation_grid,
			"update_workers": _update_workers,
			"refresh_living_status": _refresh_living_status
		}
	)
	settlement_survival_service = SettlementSurvivalServiceScript.new()
	settlement_survival_service.configure(self)
	settlement_daily_rules_service = SettlementDailyRulesServiceScript.new()
	settlement_daily_rules_service.configure(self)
	building_lifecycle_service = BuildingLifecycleServiceScript.new()
	building_lifecycle_service.configure(self)
	excavation_service = ExcavationServiceScript.new()
	excavation_service.configure(self)
	citizen_registration_service = CitizenRegistrationServiceScript.new()
	citizen_registration_service.configure(self)
	school_service = SchoolServiceScript.new()
	school_service.configure(self)
	building_placement_service = BuildingPlacementServiceScript.new()
	building_placement_service.configure(self)
	citizen_daily_order_service = CitizenDailyOrderServiceScript.new()
	citizen_daily_order_service.configure(self)

	citizen_needs_service = CitizenNeedsService.new()
	citizen_needs_service.configure(self)
	citizen_living_status_service = CitizenLivingStatusServiceScript.new()
	trade_service = TradeServiceScript.new()
	trade_service.configure(self)
	storage_delivery_service = StorageDeliveryServiceScript.new()
	storage_delivery_service.configure(self)
	storage_routing_service = StorageRoutingServiceScript.new()
	storage_routing_service.configure(self)
	courier_dispatcher = CourierDispatcherScript.new()
	courier_dispatcher.configure(self)
	courier_task_publisher = CourierTaskPublisherScript.new()
	courier_task_publisher.configure(self)
	courier_task_service = CourierTaskServiceScript.new()
	courier_task_service.configure(self)
	campfire_menu_controller = CampfireMenuControllerScript.new()
	campfire_menu_controller.configure(self)
	workforce_menu_controller = WorkforceMenuControllerScript.new()
	workforce_menu_controller.configure(self)
	research_menu_controller = ResearchMenuControllerScript.new()
	research_menu_controller.configure(self)
	school_menu_controller = SchoolMenuControllerScript.new()
	school_menu_controller.configure(self)
	entrance_menu_controller = EntranceMenuControllerScript.new()
	entrance_menu_controller.configure(self)
	house_menu_controller = HouseMenuControllerScript.new()
	house_menu_controller.configure(self)
	pocket_take_menu_controller = PocketTakeMenuControllerScript.new()
	pocket_take_menu_controller.configure(self)
	market_menu_controller = MarketMenuControllerScript.new()
	market_menu_controller.configure(self)
	warehouse_menu_controller = WarehouseMenuControllerScript.new()
	warehouse_menu_controller.configure(self)
	warehouse_fill_label_controller = WarehouseFillLabelControllerScript.new()
	warehouse_fill_label_controller.configure(self)
	building_menu_controller = BuildingMenuControllerScript.new()
	building_menu_controller.configure(self)
	building_status_indicator_controller = BuildingStatusIndicatorControllerScript.new()
	building_status_indicator_controller.configure(self)
	first_person_hud_controller = FirstPersonHUDControllerScript.new()
	first_person_hud_controller.configure(self)
	label_distance_fade_controller = LabelDistanceFadeControllerScript.new()
	label_distance_fade_controller.configure(self)
	settlement.apply_tent_start()
	var _event_registry := EventRegistryScript.new()
	_event_registry.register_all(TentEraEventsScript.build())
	event_service = EventServiceScript.new(_event_registry)
	tent_weather = TentEraSurvivalRulesScript.weather_for_day(day_cycle.current_day)
	weather_state.new_day(tent_weather, random, int(clock.minutes))
	ambient_spawner = AmbientSpawner.new()
	add_child(ambient_spawner)
	ambient_spawner.setup(self)
	player_controller = PlayerController.new()
	add_child(player_controller)
	player_controller.setup(self)
	ui_manager = UIManagerScene.instantiate() as UIManager
	add_child(ui_manager)
	ui_manager.setup(self)
	_create_world()
	_create_interface()
	ambient_spawner.create_forest()
	ambient_spawner.spawn_trash_piles()
	ambient_spawner.spawn_initial_rabbits()
	ambient_spawner.create_ponds()
	ambient_spawner.create_entrance_stone()
	_create_citizens()
	_create_starter_backpack()
	_refresh_living_statuses()
	if not citizen_ai.configure(
		SettlementAIWorldFacade.new(self),
		[SleepGoalScript.new(), MealGoalScript.new(), ToiletGoalScript.new(), RestGoalScript.new(), ReturnHomeWhenIdleGoalScript.new(), RegisterGoalScript.new(), ForestryGoalScript.new(), FarmingGoalScript.new(), ConstructionGoalScript.new(), GatheringGoalScript.new(), CleaningGoalScript.new(), ExcavationGoalScript.new(), ServiceWorkGoalScript.new(), FactoryWorkGoalScript.new(), CourierDeliveryGoalScript.new()],
		[WorkforceOrderProviderScript.new(), DailyPlayerOrderProviderScript.new(), ForestryOrderProviderScript.new(), FarmingOrderProviderScript.new(), ConstructionOrderProviderScript.new(), GatheringOrderProviderScript.new(), ExcavationOrderProviderScript.new(), ServiceWorkOrderProviderScript.new(), FactoryWorkOrderProviderScript.new(), CourierDeliveryOrderProviderScript.new()]
	):
		push_error("Native citizen AI failed to capture its initial world snapshot")

	_update_workers()
	_update_interface("Build a simple store, then gather materials for the first campfire and tents.")
	_enter_first_person(hero_citizen, "Hero view enabled.")

func _process(delta: float) -> void:
	runtime_seconds += delta
	if foraging_service != null:
		foraging_service.runtime_seconds = runtime_seconds
	if citizen_needs_service != null:
		citizen_needs_service.tick(game_minutes)
		_check_player_toilet_request()
	if is_first_person:
		_update_player_control(delta)
		_update_interaction(delta)
		_refresh_interaction_hint()
		_update_first_person_mouse_and_crosshair()
		_update_warehouse_fill_labels()
		if not build_mode.is_empty():
			var viewport_center := get_viewport().get_visible_rect().size * 0.5
			var terrain_point: Variant = _terrain_point_at_screen_position(viewport_center)
			if terrain_point != null:
				_move_selection(terrain_point)
				selection_marker.visible = true
			else:
				selection_marker.visible = false
				preview_entrance_marker.visible = false
				preview_back_entrance_marker.visible = false
	else:
		_update_camera(delta)
	_update_construction(delta)
	_update_demolition(delta)
	_update_water_collectors(delta)
	_update_clock(delta)
	_release_unassigned_overtime_workers()
	_update_survival_busy_workers()
	_return_outside_workers()
	if ambient_spawner != null:
		ambient_spawner.update_wild_food(delta)
	_guard_citizen_positions()
	_update_trail_overlay()
	_update_daylight()
	_update_house_lights()
	_update_canteen_delivery()
	_update_arrivals()
	_update_fire_status()
	trade_service.update()
	# Queued trades are delivered as courier tasks; a dispatch pass picks them up.
	_request_courier_dispatch()
	_update_sawmills(delta)
	_update_building_research(delta)
	_update_building_status_indicators(delta)
	_update_gathering_indicators(delta)
	_update_label_distance_fading()
	_sync_backpack_pile()
	if _is_work_time() or _has_active_night_work_order():
		_update_couriers()
		_worker_poll_timer -= delta
		if _worker_poll_timer <= 0.0:
			_worker_poll_timer = WORKER_POLL_INTERVAL
			_update_workers()
	if selected_builder != null and build_menu.visible:
		_show_selected_citizen_menu()


func _update_label_distance_fading() -> void:
	if label_distance_fade_controller != null:
		label_distance_fade_controller.update_label_distance_fading()


func _update_workers() -> void:
	_check_unstaffed_employment_center()


func daily_order_workday_for_new_order() -> int:
	return citizen_daily_order_service.daily_order_workday_for_new_order() if citizen_daily_order_service != null else day_cycle.current_day


func daily_order_expiration_for_workday(workday_id: int) -> float:
	return citizen_daily_order_service.daily_order_expiration_for_workday(workday_id) if citizen_daily_order_service != null else 0.0


func _workday_hours_for(workday_id: int) -> int:
	return citizen_daily_order_service.workday_hours_for(workday_id) if citizen_daily_order_service != null else settlement.workday_hours


func _activate_citizen_overtime(citizen: Citizen, source: String) -> bool:
	return citizen_daily_order_service.activate_citizen_overtime(citizen, source) if citizen_daily_order_service != null else false


func is_daily_order_active(citizen: Citizen) -> bool:
	return citizen_daily_order_service.is_daily_order_active(citizen) if citizen_daily_order_service != null else false


func _assign_daily_order(citizen: Citizen, role: String) -> void:
	if citizen_daily_order_service != null:
		citizen_daily_order_service.assign_daily_order(citizen, role)


func _clear_daily_orders(workday_id := 0) -> void:
	if citizen_daily_order_service != null:
		citizen_daily_order_service.clear_daily_orders(workday_id)

func _guard_citizen_positions() -> void:
	if not is_instance_valid(entrance_stone):
		return
	for citizen in citizens:
		if not is_instance_valid(citizen) or outside_workers.has(citizen.get_instance_id()):
			continue
		var citizen_id := citizen.get_instance_id()
		var previous: Vector3 = last_citizen_positions.get(citizen_id, citizen.global_position)
		var intentionally_at_entrance := citizen.state in [Citizen.State.TO_ARRIVAL_ENTRANCE, Citizen.State.ARRIVAL_MEETING, Citizen.State.ARRIVAL_WAITING, Citizen.State.TO_ARRIVAL_CENTER, Citizen.State.TO_TRADE_PICKUP, Citizen.State.TO_TRADE_DESTINATION]
		# No normal work transition moves an established resident from across the
		# map to the entrance. Keep the last known world location if that reset is
		# observed, while preserving genuine arrival and trade routes.
		if not intentionally_at_entrance and previous.distance_to(citizen.global_position) > 5.0 and previous.distance_to(entrance_stone.global_position) > 5.0 and citizen.global_position.distance_to(entrance_stone.global_position) < 2.5:
			citizen.global_position = previous
			citizen.velocity = Vector3.ZERO
		last_citizen_positions[citizen_id] = citizen.global_position

func _work_role_for(citizen: Citizen) -> String:
	return workplace_labor_service.work_role_for(citizen) if workplace_labor_service != null else ""

func _factory_for_role(role: String) -> Node3D:
	return _employer_for_role(role)


func _is_factory_worker_active(citizen: Citizen, factory: Node3D) -> bool:
	return workplace_labor_service.is_factory_worker_active(citizen, factory) if workplace_labor_service != null else false

func _has_courier() -> bool:
	return workplace_labor_service.has_courier() if workplace_labor_service != null else false

func _has_cook() -> bool:
	return workplace_labor_service.has_cook() if workplace_labor_service != null else false


func _employment_center_position() -> Vector3:
	return workplace_labor_service.employment_center_position() if workplace_labor_service != null else Vector3.INF


func _employment_centre_building() -> Node3D:
	return workplace_labor_service.employment_centre_building() if workplace_labor_service != null else null


func _officer_holder() -> Citizen:
	return workplace_labor_service.officer_holder() if workplace_labor_service != null else null


func _officer_exists() -> bool:
	return workplace_labor_service.officer_exists() if workplace_labor_service != null else false


func _player_can_command_labor() -> bool:
	return workplace_labor_service.player_can_command_labor() if workplace_labor_service != null else true


func _labor_command_block_message() -> String:
	return workplace_labor_service.labor_command_block_message() if workplace_labor_service != null else ""


func _player_can_manage_permanent_professions() -> bool:
	return workplace_labor_service.player_can_manage_permanent_professions() if workplace_labor_service != null else false


func _permanent_profession_block_message() -> String:
	return workplace_labor_service.permanent_profession_block_message() if workplace_labor_service != null else ""


func _show_labor_command_blocked() -> void:
	if workplace_labor_service != null:
		workplace_labor_service.show_labor_command_blocked()


func _registration_official() -> Citizen:
	return citizen_registration_service.registration_official() if citizen_registration_service != null else null


func _is_registration_staffed() -> bool:
	return citizen_registration_service.is_registration_staffed() if citizen_registration_service != null else false


func _next_registration_ticket() -> int:
	return citizen_registration_service.next_registration_ticket() if citizen_registration_service != null else 0


func _can_start_registration(citizen: Citizen) -> bool:
	return citizen_registration_service.can_start_registration(citizen) if citizen_registration_service != null else false


func _registration_duration() -> float:
	return citizen_registration_service.registration_duration() if citizen_registration_service != null else Citizen.EMPLOYMENT_PROCESS_DURATION


func _is_teacher_present_at_school() -> bool:
	return school_service.is_teacher_present() if school_service != null else false


func _is_seller_present_at(market_node: Node3D) -> bool:
	if not is_instance_valid(market_node):
		return false
	var service_position: Vector3 = market_node.get_meta("service_position", market_node.global_position)
	for citizen in citizens:
		var is_seller := citizen.permanent_role == "seller" or citizen.specialization == "seller"
		if not is_seller:
			continue
		if is_instance_valid(citizen.employment_workplace) and citizen.employment_workplace != market_node:
			continue
		if citizen.is_player_controlled:
			if citizen.global_position.distance_to(service_position) <= 3.5:
				return true
		elif citizen.state in [Citizen.State.TO_MARKET_WORK, Citizen.State.MARKET_WORK]:
			if citizen.global_position.distance_to(service_position) <= 3.5:
				return true
	return false


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
		var overcast := weather_state.intensity_at(clock.minutes)
		world_setup.update_daylight(game_minutes, overcast, runtime_seconds)


func _update_clock(delta: float) -> void:
	var previous_hour := clock.hour()
	var events := day_cycle.advance(delta, GAME_MINUTES_PER_SECOND, settlement.workday_hours)
	if weather_state.update(clock.minutes):
		if weather_state.is_raining:
			_update_interface("Rain has started.")
		else:
			_update_interface("Rain has stopped.")
	if clock.hour() != previous_hour:
		_apply_hourly_tent_survival(clock.hour())
		_apply_hourly_bare_hands_penalty()
		_apply_hourly_work_fatigue()
	if hud != null:
		hud.update_clock("%s  %02d:%02d  x%d" % ["Night" if clock.is_night() else "Day", clock.hour(), clock.minute(), int(time_multiplier)])
	_update_skip_night_button()
	for event in events:
		_handle_day_cycle_event(event)

func _handle_day_cycle_event(event: SimulationDayEvent) -> void:
	match event.kind:
		SimulationDayEvent.Kind.MEAL:
			_start_meal(event.hour)
		SimulationDayEvent.Kind.PARK_REST:
			_start_park_rest(event.cooks_only)
		SimulationDayEvent.Kind.WORKDAY_ENDED:
			_end_ai_work_shift()
			_clear_finished_daily_orders(day_cycle.current_day)
			_update_interface("Workday ended: residents without a night-work order are returning home.")
		SimulationDayEvent.Kind.NIGHTFALL:
			_refresh_living_statuses()
			_update_workers()
			_update_interface("Nightfall: workers are returning to their assigned homes.")
		SimulationDayEvent.Kind.WORKDAY_STARTED:
			_apply_pending_workday_hours()
			_clear_expired_overtime_orders()
			_reset_building_night_work_toggles()
			_resume_overtime_daily_orders()
			_refresh_living_statuses()
			_update_workers()
			# The previous shift cancels all brains. Rebuild the snapshot and player
			# orders as soon as the next workday opens so queued daily orders resume.
			if citizen_ai != null:
				citizen_ai.request_decision_refresh()
			_update_interface("Morning: workers left their homes for their assignments.")
		SimulationDayEvent.Kind.SCHOOL_DAY_ENDED:
			var teacher_ok := _is_teacher_present_at_school()
			for citizen in citizens:
				citizen.finish_school_day(teacher_ok)
			_update_workers()
		SimulationDayEvent.Kind.DAILY_SETTLEMENT_UPDATE:
			tent_weather = TentEraSurvivalRulesScript.weather_for_day(day_cycle.current_day)
			weather_state.new_day(tent_weather, random, int(clock.minutes))
			_update_interface("Forecast: %s." % TentEraSurvivalRulesScript.WEATHER_NAMES[tent_weather])
			if event_service != null:
				event_service.log.clear_flag(&"smoky_firewood")
				event_service.log.clear_flag(&"firewood_protected_today")
				var delayed_outcomes: Array[EventOutcome] = event_service.advance_day(day_cycle.current_day, _build_event_context(), random)
				for outcome in delayed_outcomes:
					_apply_event_outcome(outcome)
			_maybe_present_survival_decision()
			_refresh_living_statuses()
			settlement.cheer_up_used_today = false
			settlement.double_time_order_day = -1
			_remove_expired_temporary_tents()
			_apply_daily_settlement_rules()
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
	_sync_overtime_scope_indicators()


func _clear_expired_overtime_orders() -> void:
	for citizen in citizens:
		if is_instance_valid(citizen):
			citizen.clear_expired_overtime(day_cycle.current_day)


func _reset_building_night_work_toggles() -> void:
	# Keep an active overnight scope visible through the following workday. The
	# previous implementation cleared this at 08:00 while its workers still had
	# overtime, turning the next click into an accidental extension.
	_sync_overtime_scope_indicators()


func _sync_overtime_scope_indicators() -> void:
	settlement.night_work_order_day = day_cycle.current_day if _has_overtime_source("settlement") else -1
	for record in building_registry.records():
		var node := record.node as Node3D
		if is_instance_valid(node) and node.has_meta("night_work_order_day") and not _has_overtime_source("workplace", node):
			node.set_meta("night_work_order_day", -1)


func _has_overtime_source(source: String, workplace: Node3D = null) -> bool:
	for citizen in citizens:
		if not is_instance_valid(citizen) or not citizen.has_overtime_source(source, day_cycle.current_day):
			continue
		if workplace == null or citizen.employment_workplace == workplace:
			return true
	return false


func _resume_overtime_daily_orders() -> void:
	for citizen in citizens:
		if not is_instance_valid(citizen):
			continue
		if citizen.has_active_overtime(day_cycle.current_day) and citizen.daily_order_workday_id == day_cycle.current_day - 1:
			citizen.daily_order_workday_id = day_cycle.current_day
			citizen.daily_order_expires_at = maxf(citizen.daily_order_expires_at, daily_order_expiration_for_workday(day_cycle.current_day))


func _apply_hourly_work_fatigue() -> void:
	settlement_survival_service.apply_hourly_work_fatigue()


func _resolve_exhausted_homecomings() -> void:
	settlement_survival_service.resolve_exhausted_homecomings()


func _apply_hourly_tent_survival(hour: int, survival_day := 0) -> void:
	settlement_survival_service.apply_hourly_tent_survival(hour, survival_day)


func _apply_hourly_bare_hands_penalty() -> void:
	settlement_survival_service.apply_hourly_bare_hands_penalty()


func _check_daily_departures() -> void:
	settlement_survival_service.check_daily_departures()


func _on_citizen_leaving_departed(citizen: Citizen) -> void:
	citizen_lifecycle_service.on_citizen_leaving_departed(citizen)


func _total_game_minutes() -> float:
	return float(day_cycle.current_day - 1) * 24.0 * 60.0 + game_minutes


func _remove_expired_temporary_tents() -> void:
	building_lifecycle_service.remove_expired_temporary_tents()


func _apply_daily_settlement_rules() -> void:
	settlement_daily_rules_service.apply_daily_settlement_rules()

func _update_house_lights() -> void:
	building_lifecycle_service.update_house_lights()

func _house_has_residents(house: Node3D) -> bool:
	return building_lifecycle_service.house_has_residents(house)

func _house_has_people_at_home(house: Node3D) -> bool:
	return building_lifecycle_service.house_has_people_at_home(house)

func _is_night() -> bool:
	return clock.is_night()

func _has_lit_communal_fire() -> bool:
	for record in building_registry.records():
		var building: Node3D = record.node
		if is_instance_valid(building) and str(building.get_meta("building_type", "")) in ["campfire", "campfire_lvl2", "campfire_lvl3", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3"] and _is_fire_lit(building):
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


func _on_meal_finished(citizen: Citizen) -> void:
	canteen_service.on_meal_finished(citizen)


func _update_canteen_delivery() -> void:
	canteen_service.update_canteen_delivery()


func _cancel_canteen_delivery() -> void:
	canteen_service.cancel_canteen_delivery()


func _on_canteen_delivery_finished(worker: Citizen, amount: int) -> void:
	courier_dispatcher.complete_for(worker)
	canteen_service.on_canteen_delivery_finished(worker, amount)

func _update_couriers() -> void:
	if courier_dispatcher != null:
		courier_dispatcher.dispatch()


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
		if not is_instance_valid(building) or not bool(building.get_meta("repair_reserved", false)):
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


func _resource_pile_for_node(pile_node: Node3D) -> Dictionary:
	return storage_routing_service.resource_pile_for_node(pile_node)


func _take_resource_from_pile_at(position: Vector3, resource_type: String, max_amount: int) -> int:
	return storage_routing_service.take_resource_from_pile_at(position, resource_type, max_amount)


func _is_courier_task_valid(task: RefCounted) -> bool:
	return courier_task_service.is_courier_task_valid(task)


func _start_courier_task(courier: Citizen, task: RefCounted) -> bool:
	return courier_task_service.start_courier_task(courier, task)


func _reserve_task_warehouse_space(task: RefCounted, resource_type: String, amount: int) -> bool:
	return courier_task_service.reserve_task_warehouse_space(task, resource_type, amount)


func _release_task_warehouse_reservation(task: RefCounted) -> void:
	courier_task_service.release_task_warehouse_reservation(task)


func _is_courier_task_reachable(courier: Citizen, task: RefCounted) -> bool:
	return courier_task_service.is_courier_task_reachable(courier, task)


func _cancel_courier_task(courier: Citizen, task: RefCounted) -> void:
	courier_task_service.cancel_courier_task(courier, task)


func _reconcile_construction_reservations(site: ConstructionSite) -> void:
	courier_task_service.reconcile_construction_reservations(site)

func _preferred_construction_site() -> ConstructionSite:
	var chosen: ConstructionSite = null
	var best_score := -INF
	var waiting_chosen: ConstructionSite = null
	var waiting_score := -INF
	for site in construction_sites:
		if site == null or not is_instance_valid(site.node) or site.node.is_queued_for_deletion():
			continue
		var score := _construction_development_priority(site)
		if score > waiting_score:
			waiting_chosen = site
			waiting_score = score
		# A builder can only advance up to the fraction of materials already on
		# site. Prefer any project with work available over a higher-priority site
		# where everyone would only wait for a courier.
		if site.material_progress() <= site.progress + 0.0001:
			continue
		if score > best_score:
			chosen = site
			best_score = score
	return chosen if chosen != null else waiting_chosen


func _construction_development_priority(site: ConstructionSite) -> float:
	var building_type := site.building_type
	var score := float(BuildingCatalog.era_for(building_type)) * 100.0
	var population := citizens.size()
	match building_type:
		"warehouse", "straw_warehouse", "tarp_warehouse": score += 1000.0 if warehouse_positions.is_empty() else 180.0
		"campfire", "campfire_lvl2", "campfire_lvl3": score += 950.0 if not is_instance_valid(campfire_node) else 120.0
		"tent", "straw_tent", "tarp_tent", "dugout", "earth_house", "clay_house", "stone_house", "house", "brick_house":
			score += 850.0 if _total_housing_slots() < population else 140.0
		"forager_tent", "straw_forager_tent", "tarp_forager_tent", "farm": score += 700.0 if food < population * 2 else 160.0
		"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen": score += 580.0 if not is_instance_valid(canteen) else 120.0
		"sawmill": score += 420.0 if sawmill_positions.is_empty() else 100.0
		"gathering_place", "park", "leisure_center": score += 80.0
		_: score += 250.0
	# Once a project has started receiving stock, preserve the focus and avoid
	# oscillating between equally valuable plans.
	var supplied := 0
	for resource_type in site.delivered_materials:
		supplied += int(site.delivered_materials[resource_type])
	return score + supplied * 2.0

func _on_construction_material_delivered(_courier: Citizen, site_node: Node3D, resource_type: String, amount: int) -> void:
	if not construction.accept_delivery(site_node, resource_type, amount):
		# The cargo was reserved at pickup, but another courier may have completed
		# the requirement first. Return it instead of silently overfilling the site.
		settlement.add(resource_type, amount)
		var site := construction.site_for_node(site_node)
		if site != null:
			site.reserved_materials[resource_type] = maxi(0, int(site.reserved_materials.get(resource_type, 0)) - amount)
			settlement.release_for_construction(site.site_id, resource_type, amount)
		_update_interface("Construction site is full; courier returned %d %s to storage." % [amount, resource_type])
	courier_dispatcher.complete_for(_courier)
	_request_courier_dispatch()
	# The delivery may have made a waiting construction site buildable. Refresh
	# the snapshot immediately so its builders receive the updated order.
	if citizen_ai != null:
		citizen_ai.request_decision_refresh()

func _on_building_supply_delivered(_courier: Citizen, target: Node3D, supply_kind: String, resource_type: String, amount: int) -> void:
	courier_dispatcher.complete_for(_courier)
	if not is_instance_valid(target):
		settlement.add(resource_type, amount)
		return
	match supply_kind:
		"firewood":
			var fire_state := _fire_state_for(target)
			fire_state.add_delivered(amount, int(game_minutes))
			_apply_fire_state(target, fire_state)
			_refresh_living_statuses()
		"repair":
			target.set_meta("repair_reserved", false)
			var repaired_condition := minf(100.0, float(target.get_meta("condition", 0.0)) + 18.0)
			target.set_meta("condition", repaired_condition)
			target.set_meta("repair_needed", repaired_condition < 82.0)
		"pile":
			settlement.add(resource_type, amount)
			for index in resource_piles.size():
				if resource_piles[index].node == target:
					var reserved: Dictionary = resource_piles[index].reserved
					reserved[resource_type] = maxi(0, int(reserved.get(resource_type, 0)) - amount)
					resource_piles[index].reserved = reserved
					break

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

func _on_resource_delivered(worker: Citizen, resource_type: String, amount: int) -> void:
	storage_delivery_service.on_resource_delivered(worker, resource_type, amount)


func _on_resource_dropped(worker: Citizen, resource_type: String, amount: int) -> void:
	_drop_resource_pile(worker.global_position, resource_type, amount)
	_update_interface("Worker dropped %d %s in a ground pile after the order was interrupted." % [amount, resource_type])

func _on_factory_cycle(worker: Citizen, factory: Node3D) -> void:
	if not is_instance_valid(factory):
		return
	var type: String = factory.get_meta("building_type", "")
	if type == "brick_factory":
		if clay < 1:
			return
		settlement.add("clay", -1)
		var produced := 1
		if worker.skills.get("factory_worker", 0.0) >= 1.0 and randf() < 0.10:
			produced = 2
			_update_interface("Industrialist: Brick factory produced 2 bricks from 1 clay!")
		else:
			_update_interface("Brick factory produced 1 brick.")
		settlement.add("bricks", produced)

func _on_resource_ready(worker: Citizen, resource_type: String, amount: int) -> void:
	worker.register_pending_resource(resource_type, amount)
	_request_courier_dispatch()

func _sawmill_key(position_on_board: Vector3) -> Vector2i:
	return _cell_from_position(position_on_board)

func _sawmill_stock(position_on_board: Vector3) -> Dictionary:
	return sawmills.stock_at(position_on_board, runtime_seconds)

func _store_sawmill_stock(position_on_board: Vector3, stock: Dictionary) -> void:
	sawmills.store(position_on_board, stock)

func _on_logs_delivered(worker: Citizen, sawmill_position: Vector3, amount: int) -> void:
	sawmills.accept_logs(worker, sawmill_position, amount, runtime_seconds)
	_request_courier_dispatch()

func _update_sawmills(delta: float) -> void:
	sawmills.tick(delta, runtime_seconds)

func _decide_forestry_delivery(worker: Citizen, sawmill_position: Vector3) -> void:
	sawmills.decide_delivery(worker, sawmill_position, runtime_seconds)

func _on_sawmill_boards_collected(courier: Citizen, sawmill_position: Vector3) -> void:
	sawmills.collect_boards(courier, sawmill_position, runtime_seconds)
	_request_courier_dispatch()


func _on_dew_collected(courier: Citizen, collector_position: Vector3) -> void:
	var amount := water_collector_service.collect_water(collector_position, courier.courier_capacity())
	courier.collect_dew(amount)
	_request_courier_dispatch()


func _request_courier_dispatch() -> void:
	if _is_work_time() or _has_active_night_work_order():
		_update_couriers()
		if citizen_ai != null:
			citizen_ai.request_decision_refresh()

func _sawmill_with_boards() -> Vector3:
	return sawmills.position_with_boards(runtime_seconds)

func _on_excavation_cycle(worker: Citizen, site_node: Node3D, efficiency: float) -> void:
	excavation_service.on_excavation_cycle(worker, site_node, efficiency)

func _can_work_at_dig_site(site: Dictionary) -> bool:
	return excavation_service.can_work_at_dig_site(site)

func _tool_for_depth(site: Dictionary, depth: int) -> String:
	return excavation_service.tool_for_depth(site, depth)

func _resource_for_depth(site: Dictionary, depth: int) -> String:
	return excavation_service.resource_for_depth(site, depth)

func _count_valid_dig_sites() -> int:
	return excavation_service.count_valid_dig_sites()

func _dig_site_for_node(site_node: Node3D) -> Dictionary:
	return excavation_service.dig_site_for_node(site_node)

func _building_cost() -> int:
	return BuildingCatalog.cost_for(build_mode)

func _format_costs(building_type: String) -> String:
	return building_availability_service.cost_text(building_type)

func _stored_resources() -> int:
	return storage_routing_service.stored_resources()

func _warehouse_capacity() -> int:
	return storage_routing_service.warehouse_capacity()

func _total_housing_slots() -> int:
	return building_registry.housing_capacity()

func _update_camera(delta: float) -> void:
	if camera_controller != null:
		camera_controller.update(delta)

func _pan_camera(mouse_delta: Vector2) -> void:
	if camera_controller != null:
		camera_controller.pan(mouse_delta)

func _rotate_camera(mouse_delta: Vector2) -> void:
	if camera_controller != null:
		camera_controller.rotate_yaw_pitch(mouse_delta)

func _update_camera_position() -> void:
	if camera_controller != null:
		camera_controller.apply_position()

func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * CELL_SIZE, 0.0, (cell.y + 0.5) * CELL_SIZE)

func _cell_from_position(position_on_board: Vector3) -> Vector2i:
	return Vector2i(floori(position_on_board.x / CELL_SIZE), floori(position_on_board.z / CELL_SIZE))

func _is_board_cell(cell: Vector2i) -> bool:
	var half_cells := BOARD_CELLS / 2
	return cell.x >= -half_cells and cell.x < half_cells and cell.y >= -half_cells and cell.y < half_cells

func _find_path_around_houses(from: Vector3, destination: Vector3, may_enter_destination_house: bool) -> RouteResult:
	var request := RouteRequestScript.new()
	request.from = from
	request.destination = destination
	request.allow_destination_cell = may_enter_destination_house
	return route_service.find_route_request(request)


## A repeated physical blockage needs a different first leg; replanning the
## identical A* request would otherwise select the same waypoint forever.
func _find_recovery_path(from: Vector3, destination: Vector3, may_enter_destination_house: bool) -> RouteResult:
	var fallback := _find_path_around_houses(from, destination, may_enter_destination_house)
	if nav_grid == null or route_service == null or not fallback.reachable:
		return fallback
	var from_cell := nav_grid.cell_from_position(from)
	var desired := Vector2(destination.x - from.x, destination.z - from.z)
	if desired.length_squared() <= 0.0001:
		return fallback
	desired = desired.normalized()
	var best: RouteResult = null
	var best_cost := INF
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]:
		var candidate_cell: Vector2i = from_cell + offset
		if not nav_grid.is_walkable(candidate_cell):
			continue
		var candidate: Vector3 = nav_grid.cell_center(candidate_cell)
		var direction := Vector2(candidate.x - from.x, candidate.z - from.z).normalized()
		# Keep the first leg lateral or backward. A forward cell repeats the blocked
		# physical approach that just failed.
		if direction.dot(desired) > 0.25 or not nav_grid.is_segment_clear(from, candidate):
			continue
		var prefix := _find_path_around_houses(from, candidate, false)
		var suffix := _find_path_around_houses(candidate, destination, may_enter_destination_house)
		if not prefix.reachable or not suffix.reachable:
			continue
		var waypoints := prefix.waypoints.duplicate()
		waypoints.append_array(suffix.waypoints)
		var candidate_route := RouteResult.success(waypoints, destination, nav_grid.revision(), nav_grid.topology_revision())
		var cost := _route_cost(from, candidate_route)
		if cost < best_cost:
			best = candidate_route
			best_cost = cost
	return best if best != null else fallback


func _movement_speed_modifier_at(position_on_board: Vector3) -> float:
	return nav_grid.movement_speed_modifier_at(position_on_board) if nav_grid != null else 1.0


func _navigation_revision() -> int:
	return nav_grid.topology_revision() if nav_grid != null else -1


## Candidate discovery asks only whether a destination can be reached. Cache the
## result per topology revision and use connected components, reserving A* for
## blocked interaction destinations that need an approach cell.
func _is_route_reachable(from: Vector3, destination: Vector3, may_enter_destination_house := false) -> bool:
	if nav_grid == null:
		return false
	var topology_revision := nav_grid.topology_revision()
	if _route_reachability_cache_revision != topology_revision:
		_route_reachability_cache.clear()
		_route_reachability_cache_revision = topology_revision
	var key := "%d:%d>%d:%d:%d" % [
		nav_grid.cell_from_position(from).x,
		nav_grid.cell_from_position(from).y,
		nav_grid.cell_from_position(destination).x,
		nav_grid.cell_from_position(destination).y,
		1 if may_enter_destination_house else 0,
	]
	if _route_reachability_cache.has(key):
		return bool(_route_reachability_cache[key])
	var reachable := false
	if not may_enter_destination_house:
		reachable = nav_grid.are_cells_connected(nav_grid.cell_from_position(from), nav_grid.cell_from_position(destination))
	else:
		reachable = _find_path_around_houses(from, destination, true).reachable
	if _route_reachability_cache.size() < ROUTE_REACHABILITY_CACHE_LIMIT:
		_route_reachability_cache[key] = reachable
	return reachable


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
	lines.append("Money: %d" % money)
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
	lines.append("Wellbeing: %d" % wellbeing)
	hud.update_resources("\n".join(lines))
	_add_message(message)
	if is_first_person:
		var build_hint := "  B: стройка" if player_citizen == hero_citizen else ""
		if not build_mode.is_empty():
			build_hint += "  Q/E: поворот"
		hud.update_camera_hint("R: герой/обзор  WASD: ходить  Пробел: прыжок  Shift: бег  Мышь: осмотр  F: действие  Shift+F: всё  ПКМ: копать%s" % build_hint)
	else:
		hud.update_camera_hint("R: вид от героя. Выберите жителя и нажмите Управлять. ПКМ+перетаскивание: поворот  СКМ: панорама  Колесо: масштаб")

const ERA_CATEGORIES := ["tent", "earth", "clay", "wood", "stone", "brick"]

func _era_name() -> String:
	return ["Tent", "Earth", "Clay", "Wood", "Stone", "Brick"][settlement.era]


func _resource_display_name(resource_type: String) -> String:
	match resource_type:
		"wood": return "Timber"
		_: return resource_type.capitalize()


# ---------- Message log system ------------------------------------------------

func _add_message(text: String) -> void:
	if message_log_panel != null:
		var timestamp := "[Day %d, %02d:%02d]" % [current_day, clock.hour(), clock.minute()]
		message_log_panel.add_message(text, timestamp)


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


func _update_trail_overlay() -> void:
	if trail_overlay_material == null or trail_field == null:
		return
	trail_overlay_material.set_shader_parameter("trail_map", trail_field.flush_texture(runtime_seconds))


func _record_trail_movement(citizen_id: int, position_on_board: Vector3) -> void:
	if settlement.era != SettlementState.Era.TENT or trail_field == null:
		return
	trail_field.record_walker_position(citizen_id, position_on_board, settlement.road_walking_order_enabled)

## Recomputes walkable cells (terrain + building footprints with clearance) and
## publishes them to the shared NavGrid. Citizens route entirely through the grid,
## so this is the only navigation structure the settlement maintains.
func _refresh_navigation_grid() -> void:
	_rebuild_navigation_obstacles()
	if nav_grid != null:
		nav_grid.set_blocked_cells(navigation_blocked_cells)
		nav_grid.refresh_connectivity()

func _is_navigation_cell_blocked(cell: Vector2i) -> bool:
	return navigation_blocked_cells.has(cell)

func _rebuild_navigation_obstacles() -> void:
	var building_blocked: Dictionary = {}
	var margin := NAVIGATION_CLEARANCE_MARGIN
	for record in building_registry.records():
		var center: Vector3 = record.center
		var footprint: Vector2i = record.footprint
		# Block every cell the physical footprint (expanded by clearance) overlaps.
		# Deriving the range from the actual world rectangle keeps the clearance
		# symmetric: the old cell-index rounding shifted even footprints, leaving a
		# wall flush against a walkable cell on one side and double margin on the other.
		var min_x := floori(center.x - footprint.x * 0.5 - margin)
		var max_x := ceili(center.x + footprint.x * 0.5 + margin) - 1
		var min_z := floori(center.z - footprint.y * 0.5 - margin)
		var max_z := ceili(center.z + footprint.y * 0.5 + margin) - 1
		for x in range(min_x, max_x + 1):
			for z in range(min_z, max_z + 1):
				building_blocked[Vector2i(x, z)] = true
	for pocket in service_pockets:
		if is_instance_valid(pocket.node):
			building_blocked.erase(pocket.cell)
	navigation_blocked_cells = terrain_blocked_cells.duplicate()
	for cell in building_blocked:
		navigation_blocked_cells[cell] = true



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
		if _is_navigation_cell_blocked(_cell_from_position(candidate)):
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
		if not _is_board_cell(cell) or _is_navigation_cell_blocked(cell):
			continue
		var candidate: Vector3 = _cell_center(cell)
		if not _is_route_reachable(from, candidate):
			continue
		var distance := from.distance_squared_to(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best



func _create_citizens() -> void:
	var spawn_anchor: Vector3 = entrance_stone.global_position + Vector3(0.0, 0.0, 2.0)
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
	add_child(citizen)
	citizen.simulation = self
	citizen.setup_specialization(primary_specialization if not primary_specialization.is_empty() else "unassigned")
	citizen.setup_navigation(_find_path_around_houses, _get_nearest_delivery_position, _resolve_building_queue_position, _movement_speed_modifier_at, _navigation_revision, _record_trail_movement, _is_route_reachable, _complete_building_queue_arrival, _release_building_queue_entry, _find_recovery_path, _is_route_path_clear)
	citizen.setup_registration_service(_can_start_registration, _registration_duration)
	citizen.resource_delivered.connect(_on_resource_delivered)
	citizen.resource_dropped.connect(_on_resource_dropped)
	citizen.construction_material_delivered.connect(_on_construction_material_delivered)
	citizen.building_supply_delivered.connect(_on_building_supply_delivered)
	citizen.excavation_cycle.connect(_on_excavation_cycle)
	citizen.resource_ready.connect(_on_resource_ready)
	citizen.tree_harvested.connect(_on_tree_harvested)
	citizen.logs_delivered.connect(_on_logs_delivered)
	citizen.sawmill_boards_collected.connect(_on_sawmill_boards_collected)
	citizen.dew_collected.connect(_on_dew_collected)
	citizen.meal_finished.connect(_on_meal_finished)
	citizen.relief_finished.connect(_on_relief_finished)
	citizen.leisure_finished.connect(_on_leisure_finished)
	citizen.canteen_delivery_finished.connect(_on_canteen_delivery_finished)
	citizen.factory_cycle.connect(_on_factory_cycle)
	citizen.trade_delivery_finished.connect(_on_trade_delivery_finished)
	citizen.employment_processing_finished.connect(_on_employment_processing_finished)
	citizen.arrival_greeter_ready.connect(_on_arrival_greeter_ready)
	citizen.outside_work_departed.connect(_on_outside_work_departed)
	citizen.citizen_leaving_departed.connect(_on_citizen_leaving_departed)
	citizens.append(citizen)
	citizen.ai_id = _next_ai_citizen_id
	_next_ai_citizen_id += 1
	citizen_ai.register_citizen(citizen.ai_id, SettlementCitizenActuatorScript.new(citizen, _ai_target_for_key))
	citizen.tree_exiting.connect(_on_ai_citizen_exiting.bind(citizen.ai_id), CONNECT_ONE_SHOT)
	if citizens.size() > POPULATION:
		settlement.add("food", random.randi_range(2, 5))
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


func _create_starter_backpack() -> void:
	if settlement.warehouse_ever_built:
		return
	var anchor := entrance_stone.global_position + Vector3(0.0, 0.0, 2.0)
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
			var site := _dig_site_at(cell)
			var node := site.get(&"node") as Node3D
			return node if is_instance_valid(node) else null
		"factory":
			for factory: Node3D in factories:
				if is_instance_valid(factory) and _cell_from_position(factory.global_position) == cell:
					return factory
	return null


func _on_relief_finished(citizen: Citizen) -> void:
	if citizen_needs_service != null:
		citizen_needs_service.fulfill_toilet(citizen.ai_id)


func _player_use_toilet(toilet_node: Node3D) -> void:
	if not is_first_person or player_citizen == null or not is_instance_valid(toilet_node):
		return
	if player_citizen.player_using_toilet:
		return
	player_citizen.begin_player_toilet_use(toilet_node)
	interaction_action = "toilet"
	interaction_time = 0.0
	interaction_progress.visible = true
	interaction_hint_label.text = "Пользуемся туалетом..."
	_update_interface("Туалет используется.")


func _check_player_toilet_request() -> void:
	if not is_first_person or player_citizen == null:
		_player_toilet_notified = false
		return
	var has_request := citizen_needs_service.has_toilet_request(player_citizen.ai_id)
	if has_request and not _player_toilet_notified:
		_player_toilet_notified = true
		var name := player_citizen.role_label() if player_citizen != hero_citizen else "Герой"
		_update_interface("%s хочет в туалет. Подойдите к туалету и нажмите F, либо передайте управление ИИ." % name)
	elif not has_request:
		_player_toilet_notified = false


func _on_leisure_finished(citizen: Citizen) -> void:
	if citizen_needs_service != null:
		citizen_needs_service.fulfill_rest(citizen.ai_id)


func _create_interface() -> void:
	if ui_manager != null:
		ui_manager.create_interface()


func _create_context_menu_panel(ui: CanvasLayer, anchor: int, offsets: Vector4, input_handler: Callable = _on_context_menu_gui_input) -> Panel:
	if ui_manager != null:
		return ui_manager.create_context_menu_panel(anchor, offsets, input_handler)
	return null



func _maybe_present_survival_decision() -> void:
	if decision_menu == null or decision_menu.visible:
		return
	if event_service == null or event_service.has_pending():
		return
	var ctx := _build_event_context()
	var event_def := event_service.roll_daily_event(ctx, random)
	if event_def == null:
		return
	_show_event_decision(event_def)


func _show_event_decision(event_def: GameEventDef) -> void:
	var choice_labels: Array[String] = []
	for choice in event_def.choices:
		choice_labels.append(choice.label)
	decision_menu.show_event(event_def.title, event_def.description, choice_labels)


func _resolve_event_decision(choice_index: int) -> void:
	if event_service == null or not event_service.has_pending():
		decision_menu.visible = false
		return
	var ctx := _build_event_context()
	var outcomes: Array[EventOutcome] = event_service.resolve_choice(choice_index, ctx, random)
	for outcome in outcomes:
		_apply_event_outcome(outcome)
	decision_menu.visible = false


func _build_event_context() -> EventContext:
	var res := {
		"food": food,
		"water": water,
		"branches": branches,
		"grass": grass,
		"wood": wood,
		"stone": stone,
		"hides": hides,
		"goods": settlement.goods,
		"tarp": settlement.tarp,
		"logs": settlement.logs,
	}
	var flags: Dictionary = {}
	if event_service != null and event_service.log != null:
		flags = event_service.log.flags.duplicate()
	return EventContextScript.create(
		settlement.era,
		day_cycle.current_day,
		tent_weather,
		res,
		wellbeing,
		citizens.size(),
		flags,
	)


func _apply_event_outcome(outcome: EventOutcome) -> void:
	match outcome.kind:
		EventOutcome.Kind.MESSAGE:
			if not outcome.text.is_empty():
				_add_message(outcome.text)
		EventOutcome.Kind.RESOURCE_CHANGE:
			settlement.add(outcome.resource, outcome.amount)
		EventOutcome.Kind.WELLBEING_CHANGE:
			wellbeing = clampi(wellbeing + outcome.wellbeing_delta, 0, 100)
		EventOutcome.Kind.WORKER_BUSY:
			_assign_survival_busy_worker(outcome.worker_busy_hours, outcome.worker_busy_label)
		EventOutcome.Kind.SET_FLAG:
			pass
		EventOutcome.Kind.DELAYED:
			pass


func _assign_survival_busy_worker(hours: float, status_label: String) -> void:
	var candidates: Array[Citizen] = []
	for citizen in citizens:
		if is_instance_valid(citizen) and not citizen.is_hero and not citizen.is_player_controlled:
			candidates.append(citizen)
	if candidates.is_empty():
		return
	var worker: Citizen = candidates[random.randi_range(0, candidates.size() - 1)]
	if citizen_ai != null:
		citizen_ai.cancel_citizen_work(worker.ai_id)
	worker.cancel_current_action()
	worker.set_player_controlled(true)
	worker.set_status_effect(&"survival_assignment", status_label, 1.0, hours)
	survival_busy_until[worker.get_instance_id()] = _total_game_minutes() + hours * 60.0


func _update_survival_busy_workers() -> void:
	for worker_id in survival_busy_until.keys().duplicate():
		if _total_game_minutes() < float(survival_busy_until[worker_id]):
			continue
		var worker := instance_from_id(int(worker_id)) as Citizen
		if is_instance_valid(worker):
			worker.set_player_controlled(false)
			worker.clear_status_effect(&"survival_assignment")
			worker.idle()
		survival_busy_until.erase(worker_id)
		_update_workers()

func _can_skip_night() -> bool:
	if _has_active_night_work_order():
		return false
	var hour := clock.hour()
	return hour >= 8 + settlement.workday_hours or hour < 6


func _can_skip_to_workday_start() -> bool:
	if _has_active_night_work_order():
		return false
	var hour := clock.hour()
	return hour >= 6 and hour < 8


func _update_skip_night_button() -> void:
	if time_controls_panel != null:
		time_controls_panel.update_skip_buttons(_can_skip_night(), _can_skip_to_workday_start(), is_first_person)


func _skip_night_survival_hours() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var current_hour := clock.hour()
	var first_hour := current_hour if clock.minute() == 0 else posmod(current_hour + 1, 24)
	if current_hour >= 6 and current_hour < 22:
		first_hour = 22
	var offset := 0
	while offset < 24:
		var hour := posmod(first_hour + offset, 24)
		if hour == 6:
			break
		var survival_day := day_cycle.current_day
		if current_hour >= 6 and hour < current_hour:
			survival_day += 1
		result.append({"day": survival_day, "hour": hour})
		offset += 1
	return result


func _skip_night() -> void:
	if not _can_skip_night():
		_update_skip_night_button()
		return
	# Skipping time must not teleport workers to the entrance. Their current
	# locations are valid even when the morning scheduler assigns fresh work.
	var positions: Dictionary = {}
	for citizen in citizens:
		if is_instance_valid(citizen) and not outside_workers.has(citizen.get_instance_id()):
			positions[citizen.get_instance_id()] = citizen.global_position
	var target_day := day_cycle.current_day + (1 if clock.hour() >= 6 else 0)
	settlement_survival_service.is_skipping_night = true
	settlement_survival_service.skip_zero_wellbeing_departure_applied = false
	for survival_hour in _skip_night_survival_hours():
		_apply_hourly_tent_survival(int(survival_hour.hour), int(survival_hour.day))
	settlement_survival_service.is_skipping_night = false
	day_cycle.current_day = target_day
	tent_weather = TentEraSurvivalRulesScript.weather_for_day(day_cycle.current_day)
	clock.set_time(6 * 60)
	# Living through the night crosses 06:00, when the daily water/food sink runs and
	# frees storage. Skipping must apply the same rules, otherwise stores stay full,
	# no production is assignable, and workers have nothing to wake up for.
	_refresh_living_statuses()
	_apply_daily_settlement_rules()
	# A skipped night has no intervening movement frames for a departing resident.
	# Remove dawn departures immediately so the simulated result matches elapsed time.
	for citizen in citizens.duplicate():
		if is_instance_valid(citizen) and citizen.state == Citizen.State.LEAVING:
			_on_citizen_leaving_departed(citizen)
	_return_outside_workers()
	_apply_skip_night_incident()
	_update_workers()
	for citizen in citizens:
		if is_instance_valid(citizen) and positions.has(citizen.get_instance_id()):
			citizen.global_position = positions[citizen.get_instance_id()]
			citizen.velocity = Vector3.ZERO
			last_citizen_positions[citizen.get_instance_id()] = citizen.global_position
	if citizen_ai != null:
		citizen_ai.request_decision_refresh()
	_update_skip_night_button()
	_update_daylight()
	_update_house_lights()
	_update_interface("Skipped the night. Morning begins at 06:00.")


func _skip_to_workday_start() -> void:
	if not _can_skip_to_workday_start():
		_update_skip_night_button()
		return
	day_cycle.set_to_workday_start()
	_handle_day_cycle_event(SimulationDayEvent.new(SimulationDayEvent.Kind.WORKDAY_STARTED, 8))
	if citizen_ai != null:
		citizen_ai.request_decision_refresh()
	_update_skip_night_button()
	_update_daylight()
	_update_house_lights()
	_update_interface("Workday starts at 08:00.")


func _apply_skip_night_incident() -> void:
	var incidents := [
		{"resource": "food", "min": 3, "max": 5, "message": "Night scavengers took %d food."},
		{"resource": "grass", "min": 10, "max": 15, "message": "A stray animal ate %d grass."},
		{"resource": "branches", "min": 5, "max": 8, "message": "Wind scattered %d branches."},
		{"resource": "gloves", "min": 20, "max": 20, "message": "Night scavengers damaged a glove set by %d%%."},
	]
	var incident: Dictionary = incidents[random.randi_range(0, incidents.size() - 1)]
	if str(incident.resource) == "gloves":
		var gloves: Dictionary = settlement.equipment.get("construction_gloves", {})
		if int(gloves.get("sets", 0)) > 0:
			gloves["active_durability"] = maxf(0.0, float(gloves.get("active_durability", 100.0)) - float(incident.max))
			settlement.equipment["construction_gloves"] = gloves
			_add_message(str(incident.message) % int(incident.max))
		return
	var amount := mini(settlement.amount(str(incident.resource)), random.randi_range(int(incident.min), int(incident.max)))
	if amount > 0:
		settlement.add(str(incident.resource), -amount)
		_add_message(str(incident.message) % amount)


func _set_workday_hours(hours: int) -> void:
	if hours not in [6, 8, 10, 12, 14]:
		return
	settlement.pending_workday_hours = hours
	_update_skip_night_button()
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
		_sync_overtime_scope_indicators()
		_update_skip_night_button()

func _set_time_multiplier(multiplier: float) -> void:
	time_multiplier = multiplier
	if is_first_person:
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = multiplier
	_update_interface("Simulation speed set to x%d." % int(multiplier))

func _toggle_school_development(role: String, pressed: bool) -> void:
	if school_menu_controller != null:
		school_menu_controller.toggle_school_development(role, pressed)

func _start_school_training(role: String) -> void:
	if school_menu_controller != null:
		school_menu_controller.start_school_training(role)

func _show_school_menu() -> void:
	if school_menu_controller != null:
		school_menu_controller.show_school_menu()

func _show_entrance_menu() -> void:
	if entrance_menu_controller != null:
		entrance_menu_controller.show_entrance_menu()


func _show_entrance_order_modal() -> void:
	if entrance_menu_controller != null:
		entrance_menu_controller.show_entrance_order_modal()


func _hide_entrance_order_modal() -> void:
	if entrance_menu_controller != null:
		entrance_menu_controller.hide_entrance_order_modal()


func _update_entrance_order_total(_value := 0.0) -> void:
	if entrance_menu_controller != null:
		entrance_menu_controller.update_entrance_order_total(_value)


func _send_entrance_order() -> void:
	if entrance_menu_controller != null:
		entrance_menu_controller.send_entrance_order()

func _outside_work_reward() -> int:
	if settlement != null and settlement.is_research_completed("outside_work_earnings"):
		return OUTSIDE_WORK_UPGRADE_REWARD
	return random.randi_range(OUTSIDE_WORK_BASE_REWARD_MIN, OUTSIDE_WORK_BASE_REWARD_MAX)


func _outside_work_reward_text() -> String:
	if entrance_menu_controller != null:
		return entrance_menu_controller.outside_work_reward_text()
	return ""


func _send_selected_resident_to_outside_work() -> void:
	if not is_instance_valid(selected_builder) or selected_builder.is_player_controlled:
		_update_interface("Select an AI-controlled Courier before sending them to outside work.")
		return
	if not selected_builder.can_handle_entry_logistics() or not _is_work_time():
		_update_interface("Outside work requires a Courier.")
		return
	var worker_id := selected_builder.get_instance_id()
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
	var worker_id := worker.get_instance_id()
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
	materials_factory_menu.visible = true
	materials_factory_menu_title.text = "Materials factory\nAssign workers to produce materials."

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

	if research_menu != null and research_menu.visible:
		_refresh_research_menu()

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

		_refresh_campfire_menu()
		_refresh_build_menu()
		if research_menu != null and research_menu.visible:
			_refresh_research_menu()

func _show_research_menu() -> void:
	if research_menu_controller != null:
		research_menu_controller.show_research_menu()

func _hide_research_menu() -> void:
	if research_menu_controller != null:
		research_menu_controller.hide_research_menu()

func _get_available_researcher(_required_skill: String) -> Citizen:
	if research_menu_controller != null:
		return research_menu_controller.get_available_researcher(_required_skill)
	return null

func _refresh_research_menu() -> void:
	if research_menu_controller != null:
		research_menu_controller.refresh_research_menu()

func _start_research(tech_id: String) -> void:
	if research_menu_controller != null:
		research_menu_controller.start_research(tech_id)

func _cancel_research() -> void:
	if research_menu_controller != null:
		research_menu_controller.cancel_research()


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
	_refresh_campfire_menu()


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

func _spawn_house_citizen() -> void:
	citizen_lifecycle_service.spawn_house_citizen()


func _find_arrival_greeter(allow_busy := false) -> Citizen:
	return citizen_lifecycle_service.find_arrival_greeter(allow_busy)


func _update_arrivals() -> void:
	citizen_lifecycle_service.update_arrivals()


func _on_arrival_greeter_ready(greeter: Citizen) -> void:
	citizen_lifecycle_service.on_arrival_greeter_ready(greeter)


func _requeue_interrupted_arrivals() -> void:
	citizen_lifecycle_service.requeue_interrupted_arrivals()


func _requeue_arrival_order(order: Dictionary) -> void:
	citizen_lifecycle_service.requeue_arrival_order(order)


func _cancel_arrivals_for_house(house: Node3D) -> void:
	citizen_lifecycle_service.cancel_arrivals_for_house(house)

func _settle_unhoused_resident() -> void:
	citizen_lifecycle_service.settle_unhoused_resident()

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
	_refresh_build_menu()
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
		build_menu.visible = false
		build_menu_is_global = false
		if selected_builder != null:
			selected_builder = null
	get_viewport().set_input_as_handled()

func _refresh_build_menu() -> void:
	if building_menu_controller != null:
		building_menu_controller.refresh_build_menu()

func _open_job_submenu() -> void:
	build_menu_is_job_menu = true
	build_menu_is_daily_order_menu = false
	build_category = ""
	_refresh_build_menu()

func _open_daily_order_submenu() -> void:
	build_menu_is_daily_order_menu = true
	build_menu_is_job_menu = false
	build_category = ""
	_refresh_build_menu()

func _close_assignment_submenu() -> void:
	build_menu_is_job_menu = false
	build_menu_is_daily_order_menu = false
	_refresh_build_menu()

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
			_assign_daily_order(selected_builder, role)
		if selected_builder.employment_state == Citizen.EmploymentState.UNREGISTERED and _employment_center_position() != Vector3.INF:
			selected_builder.request_no_permanent_work_registration()
	elif role == "excavation":
		_start_dig_assignment()
		build_menu_is_job_menu = false
		build_menu_is_daily_order_menu = false
		return
	elif role == "official":
		if not _appoint_official(selected_builder, _employment_centre_building(), false):
			return
	else:
		if role != "official" and not _player_can_manage_permanent_professions():
			_show_labor_command_blocked()
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
	_refresh_build_menu()
	_update_interface("%s assigned to %s." % ["Hero" if selected_builder.is_hero else "Citizen", "automatic work" if role.is_empty() else role.replace("_", " ")])
	_refresh_campfire_occupancy_button()
	if workforce_menu != null and workforce_menu.visible:
		_refresh_workforce_menu()

func _is_role_available(role: String) -> bool:
	if not settlement.construction_gloves_available() and wellbeing < 30 and role in ["construction", "gather_branches", "gather_grass", "gather_food", "forestry", "farming", "excavation", "factory_worker", "craftsman"]:
		return false
	match role:
		"": return true
		"courier": return true
		"construction":
			return (not construction_sites.is_empty() or not demolition_sites.is_empty()) and (settlement.era < SettlementState.Era.STONE or _builder_job_capacity() > 0)
		"forestry": return _available_employer_capacity("forestry") > 0 and bool(settlement.tools.get("axe", false)) and bool(settlement.tools.get("hand_saw", false)) and not tree_positions.is_empty() and not warehouse_positions.is_empty()
		"farming": return _available_employer_capacity("farming") > 0 and not warehouse_positions.is_empty()
		"excavation":
			if dig_sites.is_empty() or warehouse_positions.is_empty():
				return false
			for site in dig_sites:
				if _can_work_at_dig_site(site):
					return true
			return false
		"gather_branches": return not tree_positions.is_empty()
		"gather_grass": return settlement.era == SettlementState.Era.TENT
		"gather_food": return _available_employer_capacity("gather_food") > 0
		"gather_water": return bool(settlement.tools.get("bucket", false)) and not pond_positions.is_empty() and not warehouse_positions.is_empty()
		"cook": return _available_employer_capacity("cook") > 0
		"teacher": return _available_employer_capacity("teacher") > 0
		"seller": return _available_employer_capacity("seller") > 0
		"factory_worker": return _available_employer_capacity("factory_worker") > 0
		"engineer": return _available_employer_capacity("engineer") > 0
		"courier": return not warehouse_positions.is_empty()
		"craftsman": return not craft_tent_positions.is_empty()
		"official": return settlement.is_research_completed("official") and is_instance_valid(_employment_centre_building())
	return false


func _is_daily_order_role_available(role: String) -> bool:
	match role:
		"cook": return _available_employer_capacity("cook") > 0
		"researcher": return not settlement.is_research_completed("official") and is_instance_valid(_employment_centre_building()) and _is_fire_lit(_employment_centre_building())
		"gather_water": return bool(settlement.tools.get("bucket", false)) and not pond_positions.is_empty() and not warehouse_positions.is_empty()
	return true


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


func _builder_job_capacity() -> int:
	return _available_employer_capacity("construction")


func _employer_for_role(role: String) -> Node3D:
	if role == "official":
		return _employment_centre_building()
	if role == "excavation":
			for site in dig_sites:
				if _can_work_at_dig_site(site):
					return site.node
			return null
	var types := _employer_types_for_role(role)
	if types.is_empty():
		return null
	var best: Node3D
	var best_load := 100000
	var best_priority := -1
	for record in building_registry.records():
		var building := record.node
		if not is_instance_valid(building) or str(building.get_meta("building_type", "")) not in types:
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
		"cook": return ["cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant"]
		"teacher": return ["school"]
		"seller": return ["straw_trade_tent", "tarp_trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market"]
		"factory_worker": return ["brick_factory", "materials_factory", "recycling_factory", "metal_factory"]
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
		if not is_instance_valid(building) or str(building.get_meta("building_type", "")) not in _employer_types_for_role(role):
			continue
		if bool(building.get_meta("accepting_workers", true)):
			capacity += _employer_capacity(role, building)
	return capacity


func _is_staffed_workplace(building: Node3D) -> bool:
	if not is_instance_valid(building):
		return false
	var building_type := str(building.get_meta("building_type", ""))
	for role in ["construction", "forestry", "farming", "gather_food", "gather_branches", "gather_grass", "cook", "teacher", "seller", "factory_worker", "engineer", "craftsman", "official"]:
		if building_type in _employer_types_for_role(role):
			return true
	return false


func _employer_capacity(role: String, building: Node3D) -> int:
	if role == "construction":
		return 3 if building.get_meta("building_type", "") == "construction_company" else 1
	if role == "factory_worker":
		return int(building.get_meta("required_factory_workers", 1))
	if role == "craftsman":
		var type := str(building.get_meta("building_type", ""))
		return 2 if type == "tarp_craft_tent" else 1
	if role == "gather_food":
		var type := str(building.get_meta("building_type", ""))
		return 4 if type == "tarp_forager_tent" else 2
	if role in ["gather_branches", "gather_grass"]:
		var type := str(building.get_meta("building_type", ""))
		return 4 if type == "tarp_materials_yard" else 2
	return 1

func _start_dig_assignment() -> void:
	excavation_service.start_dig_assignment()

func _place_dig_site(world_position: Vector3) -> void:
	excavation_service.place_dig_site(world_position)

func _can_excavate(world_position: Vector3) -> bool:
	return excavation_service.can_excavate(world_position)

func _dig_site_at(cell: Vector2i) -> Dictionary:
	return excavation_service.dig_site_at(cell)

func _create_dig_site(cell: Vector2i, world_position: Vector3) -> Dictionary:
	return excavation_service.create_dig_site(cell, world_position)

func _set_build_placement_ui_visible(is_visible: bool) -> void:
	if build_menu != null:
		build_menu.visible = is_visible and (selected_builder != null or build_menu_is_global)
	if build_toggle_btn != null:
		build_toggle_btn.visible = is_visible and not is_first_person
	if message_log_panel != null:
		message_log_panel.visible = is_visible


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
	build_mode = next_mode
	build_rotation_quarters = 0
	selection_marker.visible = true
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
	selection_marker.visible = false
	preview_entrance_marker.visible = false
	preview_back_entrance_marker.visible = false
	build_menu.visible = false
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
	if pocket_menu_open or build_menu.visible:
		return true
	if entrance_menu.visible or house_menu.visible or school_menu.visible or materials_factory_menu.visible or campfire_menu.visible or market_menu.visible or warehouse_menu.visible or building_menu.visible:
		return true
	if entrance_order_modal != null and entrance_order_modal.visible:
		return true
	if campfire_orders_menu != null and campfire_orders_menu.visible:
		return true
	if campfire_story_menu != null and campfire_story_menu.visible:
		return true
	if research_menu != null and research_menu.visible:
		return true
	if workforce_menu != null and workforce_menu.visible:
		return true
	if decision_menu != null and decision_menu.visible:
		return true
	if message_log_panel != null and message_log_panel.is_modal_visible():
		return true
	return false


func _update_first_person_mouse_and_crosshair() -> void:
	if not is_first_person:
		return
	var menu_open := _is_first_person_menu_open()
	if crosshair != null:
		crosshair.visible = not menu_open
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED)


func _close_context_menus() -> void:
	build_mode = ""
	dig_mode = false
	selection_marker.visible = false
	_show_territory_overlay(false)
	is_rotating_camera = false
	entrance_menu.visible = false
	if entrance_highlight != null:
		entrance_highlight.visible = false
	if entrance_order_modal != null:
		entrance_order_modal.visible = false
	house_menu.visible = false
	school_menu.visible = false
	materials_factory_menu.visible = false
	build_menu.visible = false
	campfire_menu.visible = false
	if campfire_orders_menu != null:
		campfire_orders_menu.visible = false
	market_menu.visible = false
	warehouse_menu.visible = false
	building_menu.visible = false
	if research_menu != null:
		research_menu.visible = false
	if decision_menu != null:
		decision_menu.visible = false
	if campfire_story_menu != null:
		campfire_story_menu.visible = false
	if message_log_panel != null:
		message_log_panel.close_modal()
	_close_pocket_take_menu()
	_hide_workforce_menu()
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
	_refresh_build_menu()
	if is_first_person and not _is_first_person_menu_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _handle_menu_right_click():
			get_viewport().set_input_as_handled()


func _handle_menu_right_click() -> bool:
	if build_menu.visible:
		if not build_category.is_empty():
			_open_build_category("")
		elif build_menu_is_job_menu or build_menu_is_daily_order_menu:
			_close_assignment_submenu()
		else:
			build_menu.visible = false
			build_menu_is_global = false
			if selected_builder != null:
				selected_builder = null
			_refresh_build_menu()
		if is_first_person and not _is_first_person_menu_open():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return true
	if pocket_menu_open:
		_close_pocket_take_menu()
		return true
	if campfire_orders_menu != null and campfire_orders_menu.visible:
		campfire_orders_menu.visible = false
		campfire_menu.visible = true
		return true
	if campfire_story_menu != null and campfire_story_menu.visible:
		campfire_story_menu.visible = false
		campfire_menu.visible = true
		return true
	if research_menu != null and research_menu.visible:
		research_menu.visible = false
		campfire_menu.visible = true
		return true
	if workforce_menu != null and workforce_menu.visible:
		_hide_workforce_menu()
		campfire_menu.visible = true
		return true
	if entrance_order_modal != null and entrance_order_modal.visible:
		entrance_order_modal.visible = false
		entrance_menu.visible = true
		return true
	if message_log_panel != null and message_log_panel.is_modal_visible():
		message_log_panel.close_modal()
		return true
	var any_menu_visible := entrance_menu.visible or house_menu.visible or school_menu.visible or materials_factory_menu.visible or campfire_menu.visible or market_menu.visible or warehouse_menu.visible or building_menu.visible
	if decision_menu != null and decision_menu.visible:
		any_menu_visible = true
	if any_menu_visible:
		_close_context_menus()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F and event.ctrl_pressed and event.pressed and not event.echo:
		if OS.is_debug_build():
			_grant_debug_resources()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.keycode == KEY_DELETE and event.pressed and not event.echo:
		if is_instance_valid(selected_building):
			_mark_building_for_demolition(selected_building)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.keycode == KEY_R and event.pressed and not event.echo:
		_toggle_hero_view()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_B and event.pressed and not event.echo:
		if _can_hero_build():
			_toggle_global_build_menu()
			if is_first_person:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if build_menu.visible else Input.MOUSE_MODE_CAPTURED)
		else:
			_update_interface("Только герой может утверждать строительство.")
		get_viewport().set_input_as_handled()
		return
	if not build_mode.is_empty() and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_Q, KEY_E]:
		build_rotation_quarters = posmod(build_rotation_quarters + (-1 if event.keycode == KEY_Q else 1), 4)
		_move_selection(selected_world_position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if pocket_menu_open:
			_close_pocket_take_menu()
			get_viewport().set_input_as_handled()
			return
	if is_first_person:
		if event is InputEventKey and event.keycode == KEY_T and event.pressed and not event.echo:
			if not _is_first_person_menu_open():
				_drop_pocket_on_ground()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo:
			_start_interaction(event.shift_pressed)
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
				_close_pocket_take_menu()
			elif not build_mode.is_empty():
				_cancel_build_action()
			else:
				_leave_first_person_to_hero_overview()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if get_viewport().gui_get_hovered_control() != null:
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		camera_distance = maxf(3.0, camera_distance - 2.0)
		_update_camera_position()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		camera_distance = minf(80.0, camera_distance + 2.0)
		_update_camera_position()
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
			_rotate_camera(event.relative)
		elif is_panning_camera:
			_pan_camera(event.relative)
		elif not build_mode.is_empty() or (selected_builder != null and dig_mode):
			if get_viewport().gui_get_hovered_control() == null:
				var terrain_point: Variant = _terrain_point_at_screen_position(event.position)
				if terrain_point != null:
					_move_selection(terrain_point)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_builder != null and dig_mode:
			var dig_point: Variant = _terrain_point_at_screen_position(event.position)
			if dig_point != null:
				_place_dig_site(dig_point)
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
	build_menu.visible = false
	build_menu_is_global = false
	if hit.collider.is_in_group("entrance_selector"):
		selected_entrance = hit.collider.get_parent() as Node3D
		selected_building = selected_entrance
		_show_entrance_menu()
		return
	if hit.collider.is_in_group("campfire_selector"):
		selected_campfire = hit.collider.get_parent() as Node3D
		selected_building = selected_campfire
		_show_campfire_menu()
		return
	if hit.collider.is_in_group("market_selector"):
		selected_market = hit.collider.get_parent() as Node3D
		selected_building = selected_market
		_show_market_menu()
		return
	if hit.collider.is_in_group("warehouse_selector"):
		selected_warehouse = hit.collider.get_parent() as Node3D
		selected_building = selected_warehouse
		_show_warehouse_menu()
		return
	if hit.collider.is_in_group("cook_campfire_selector"):
		selected_building = hit.collider.get_parent() as Node3D
		_show_building_menu()
		return
	if hit.collider.is_in_group("house_selector"):
		selected_house = hit.collider.get_parent() as Node3D
		selected_building = selected_house
		selected_builder = null
		build_menu.visible = false
		_show_house_menu()
		_update_interface("House selected. Recruit a new resident when a bed is free.")
		return
	if hit.collider.is_in_group("school_selector"):
		selected_school = hit.collider.get_parent() as Node3D
		selected_building = selected_school
		house_menu.visible = false
		build_menu.visible = false
		_show_school_menu()
		return
	if hit.collider.is_in_group("materials_factory_selector"):
		selected_materials_factory = hit.collider.get_parent() as Node3D
		selected_building = selected_materials_factory
		selected_house = null
		selected_school = null
		house_menu.visible = false
		school_menu.visible = false
		build_menu.visible = false
		_show_materials_factory_menu()
		_update_interface("Materials factory selected. Assign workers to produce materials.")
		return
	if hit.collider.is_in_group("construction_selector"):
		selected_building = hit.collider.get_parent() as Node3D
		_show_building_menu()
		return
	if hit.collider.is_in_group("building_selector"):
		selected_building = hit.collider.get_parent() as Node3D
		_show_building_menu()
		return
	if not hit.collider.is_in_group("citizen_selector"):
		return
	_select_citizen(hit.collider.get_parent() as Citizen)


func _first_person_select_at_crosshair() -> void:
	var target := _first_person_target()
	if target.kind == "building" and is_instance_valid(target.node) and str(target.node.get_meta("building_type", "")) in OFFICIAL_WORKPLACE_TYPES:
		selected_campfire = target.node
		selected_building = target.node
		_show_campfire_menu()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	_select_citizen_at(viewport_center)


func _hide_all_selection_menus() -> void:
	# Hides every building context menu and clears their selections, but leaves
	# the currently selected citizen untouched (the school menu needs it).
	house_menu.visible = false
	entrance_menu.visible = false
	if entrance_highlight != null:
		entrance_highlight.visible = false
	school_menu.visible = false
	materials_factory_menu.visible = false
	campfire_menu.visible = false
	if campfire_story_menu != null:
		campfire_story_menu.visible = false
	if campfire_orders_menu != null:
		campfire_orders_menu.visible = false
	market_menu.visible = false
	warehouse_menu.visible = false
	building_menu.visible = false
	if research_menu != null:
		research_menu.visible = false
	if decision_menu != null:
		decision_menu.visible = false
	_hide_workforce_menu()
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

func _mark_building_for_demolition(building: Node3D) -> void:
	building_lifecycle_service.mark_building_for_demolition(building)

func _demolish_selected_house() -> void:
	if selected_house != null:
		_mark_building_for_demolition(selected_house)

func _demolish_selected_school() -> void:
	if selected_school != null:
		_mark_building_for_demolition(selected_school)

func _demolish_selected_warehouse() -> void:
	if selected_warehouse != null:
		_mark_building_for_demolition(selected_warehouse)


func _add_demolition_marker(building: Node3D) -> void:
	building_lifecycle_service.add_demolition_marker(building)

func _demolition_ready(site: DemolitionSite) -> bool:
	return building_lifecycle_service.demolition_ready(site)

func _find_relocation_home(excluded: Node3D) -> Node3D:
	return building_lifecycle_service.find_relocation_home(excluded)

func _update_demolition(delta: float) -> void:
	demolition.tick(delta)

func _finish_demolition(site: DemolitionSite) -> void:
	building_lifecycle_service.finish_demolition(site)

func _remove_building_services(building: Node3D, building_type: String) -> void:
	building_lifecycle_service.remove_building_services(building, building_type)


func _release_employment_at_building(building: Node3D) -> void:
	building_lifecycle_service.release_employment_at_building(building)


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
	selection_marker.visible = false
	_show_territory_overlay(false)
	build_menu.visible = true
	_refresh_build_menu()
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
		build_menu.title_label.text = "%s  Sat: %d/%d%%  Food: %d%%\nHome: %s  Effect: %s\nTask: %s" % [selected_builder.role_label(), roundi(selected_builder.satisfaction), roundi(selected_builder.get_satisfaction_cap()), roundi(selected_builder.hunger), home_label, effect_label, assignment]
		build_menu.citizen_skills_label.text = "Skills\nBuild %.0f%%  Wood %.0f%%\nFarm %.0f%%  Dig %.0f%%" % [float(selected_builder.skills.get("construction", 0.0)) * 100.0, float(selected_builder.skills.get("forestry", 0.0)) * 100.0, float(selected_builder.skills.get("farming", 0.0)) * 100.0, float(selected_builder.skills.get("excavation", 0.0)) * 100.0]
		build_menu.citizen_skills_label.visible = true
	build_menu.title_label.add_theme_color_override("font_color", selected_builder.specialization_color())

func _toggle_hero_view() -> void:
	if player_controller != null:
		player_controller.toggle_hero_view()

func _take_control_of_selected_citizen() -> void:
	if player_controller != null:
		player_controller.take_control_of_selected_citizen()

func _enter_first_person(citizen: Citizen, message: String) -> void:
	if player_controller != null:
		player_controller.enter_first_person(citizen, message)

func _leave_first_person_to_hero_overview() -> void:
	if player_controller != null:
		player_controller.leave_first_person_to_hero_overview()

func _update_player_control(delta: float) -> void:
	if player_controller != null:
		player_controller.update_player_control(delta)

func _start_interaction(all: bool) -> void:
	if player_controller != null:
		player_controller.start_interaction(all)

func _update_interaction(delta: float) -> void:
	if player_controller != null:
		player_controller.update_interaction(delta)

func _gather_action_name(resource_type: String) -> String:
	match resource_type:
		"wood": return "Срубить дерево"
		"branches": return "Собрать ветки"
		"grass": return "Собрать траву"
		"water": return "Набрать воду"
		"food": return "Собрать еду"
	return "Действие"


func _harvest_source_info(resource_type: String) -> String:
	if player_citizen == null:
		return ""
	match resource_type:
		"branches":
			var tree := _nearest_tree_node(player_citizen.global_position)
			if is_instance_valid(tree):
				var rem := int(tree.get_meta("remaining_branches", 0))
				var init := maxi(1, int(tree.get_meta("initial_branches", rem)))
				return "ветки %d/%d" % [rem, init]
			return ""
		"grass":
			var node := _nearest_grass_node(player_citizen.global_position)
			if is_instance_valid(node):
				for cell in grass_sources:
					var source: Dictionary = grass_sources[cell]
					if source.get("node") == node:
						var rem := int(source.get("remaining", 0))
						var init := maxi(1, int(source.get("initial", rem)))
						return "трава %d/%d" % [rem, init]
			return ""
		"wood":
			return "дерево"
		"water":
			return "вода"
		"food":
			return "еда"
	return ""


func _can_continue_harvesting(resource_type: String) -> bool:
	match resource_type:
		"wood": return _nearby_tree()
		"branches": return _nearby_tree_with_branches()
		"food": return _nearby_farm()
		"water": return _nearby_pond()
		"grass": return _nearby_grass_source()
	return false


func _deliver_all_pocket_to_warehouse(warehouse_index := -1) -> void:
	if warehouse_index < 0:
		warehouse_index = _nearby_warehouse_index()
	var delivered_total := 0
	var summary: Array[String] = []
	for resource_type in _pocket_resources():
		var amount := _pocket_amount(resource_type)
		if amount <= 0:
			continue
		if warehouse_index >= 0 and not settlement.uses_virtual_storage() and not settlement.warehouse_accepts(warehouse_index, resource_type):
			_update_interface("Склад не принимает %s." % resource_type)
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
			_remove_from_pocket(resource_type, actually_delivered)
			delivered_total += actually_delivered
			summary.append("%d %s" % [actually_delivered, resource_type])
	if delivered_total > 0:
		_update_interface("Сдано на склад: %s." % ", ".join(summary))
	elif _pocket_resources().is_empty():
		_update_interface("Карман пуст.")
	else:
		_update_interface("Нет места на складе. Постройте или расширьте склад.")


func _deliver_one_pocket_to_warehouse(warehouse_index := -1) -> void:
	if warehouse_index < 0:
		warehouse_index = _nearby_warehouse_index()
	var resource_type := _primary_pocket_resource()
	if resource_type.is_empty():
		return
	var amount := _pocket_amount(resource_type)
	if amount <= 0:
		return
	if warehouse_index >= 0 and not settlement.uses_virtual_storage() and not settlement.warehouse_accepts(warehouse_index, resource_type):
		_update_interface("Склад не принимает %s." % resource_type)
		return
	var to_deliver := 1
	if not settlement.uses_virtual_storage():
		to_deliver = mini(1, settlement.storage_room_for(resource_type))
	if to_deliver <= 0:
		_update_interface("Нет места для %s на складе." % resource_type)
		return
	var overflow := 0
	if warehouse_index >= 0 and not settlement.uses_virtual_storage():
		overflow = settlement.add_to_warehouse(resource_type, to_deliver, warehouse_index)
	else:
		settlement.add(resource_type, to_deliver)
	var actually_delivered := to_deliver - overflow
	if actually_delivered <= 0:
		_update_interface("Нет места для %s в этом складе." % resource_type)
		return
	_remove_from_pocket(resource_type, actually_delivered)
	_update_interface("Сдано %d %s на склад. %s" % [actually_delivered, resource_type, _format_pocket_hint()])


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
		_update_interface("%s покинул пост управляющего." % player_citizen.role_label())
	else:
		_update_interface("%s покинул рабочее место." % player_citizen.role_label())
	_refresh_interaction_hint()


func _occupy_workplace(workplace: Node3D) -> void:
	if not is_instance_valid(workplace) or player_citizen == null:
		return
	var building_type := str(workplace.get_meta("building_type", ""))
	var is_official_building := building_type in OFFICIAL_WORKPLACE_TYPES
	var service_position := _nearest_service_position(workplace, player_citizen.global_position)
	# Move the citizen onto the nearest service position. Smooth walking can be
	# added later; the design requires automatic positioning at the workplace.
	player_citizen.global_position = service_position
	if is_official_building:
		if settlement.is_research_completed("official"):
			var current_officer := _officer_holder()
			if current_officer != null and current_officer != player_citizen:
				_update_interface("Это место уже занято чиновником.")
				return
			player_citizen.enter_work_position(service_position, "official", workplace, false)
			_appoint_official(player_citizen, workplace)
			if player_citizen.permanent_role != "official":
				player_citizen.exit_work_position()
				return
			_update_interface("Ваш герой стал чиновником. Переключитесь на вид сверху для управления посёлком — клавиша R.")
		else:
			player_citizen.enter_work_position(service_position, "researcher", workplace, true)
			_show_research_menu()
			_update_interface("Ваш герой занял позицию исследователя.")
	else:
		var role := _role_for_workplace(workplace)
		if role.is_empty():
			return
		player_citizen.enter_work_position(service_position, role, workplace, true)
		_update_interface("%s занял временную должность %s." % [player_citizen.role_label(), role.replace("_", " ")])
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


func _nearby_warehouse() -> bool:
	return storage_routing_service.nearby_warehouse()

func _nearby_sawmill() -> bool:
	return hero_interaction_service.nearby_sawmill() if hero_interaction_service != null else false

func _nearby_sawmill_position() -> Vector3:
	return hero_interaction_service.nearby_sawmill_position() if hero_interaction_service != null else Vector3.INF

func _nearby_farm() -> bool:
	return hero_interaction_service.nearby_farm() if hero_interaction_service != null else false

func _nearby_pond() -> bool:
	return hero_interaction_service.nearby_pond() if hero_interaction_service != null else false

func _nearby_grass_source() -> bool:
	return hero_interaction_service.nearby_grass_source() if hero_interaction_service != null else false

func _nearby_grass_source_position() -> Vector3:
	return hero_interaction_service.nearby_grass_source_position() if hero_interaction_service != null else Vector3.INF

func _consume_grass_near_player(amount: int) -> void:
	if hero_interaction_service != null:
		hero_interaction_service.consume_grass_near_player(amount)

func _nearby_forage_source() -> bool:
	return hero_interaction_service.nearby_forage_source() if hero_interaction_service != null else false

func _nearby_rabbit_source() -> bool:
	return hero_interaction_service.nearby_rabbit_source() if hero_interaction_service != null else false

func _wild_food_requires_specialist_message() -> String:
	return "Forest gifts and rabbits can only be gathered by a trained specialist. Build a forager/hunter tent first."

func _pocket_total() -> int:
	var total := 0
	for amount in pocket.values():
		total += int(amount)
	return total


func _pocket_space_for(resource_type: String) -> int:
	return POCKET_CAPACITY - _pocket_total()


func _pocket_has_room() -> bool:
	return _pocket_total() < POCKET_CAPACITY


func _pocket_amount(resource_type: String) -> int:
	return int(pocket.get(resource_type, 0))


func _add_to_pocket(resource_type: String, amount: int) -> int:
	if amount <= 0 or resource_type.is_empty():
		return 0
	var added := mini(amount, _pocket_space_for(resource_type))
	if added > 0:
		pocket[resource_type] = _pocket_amount(resource_type) + added
	return added


func _remove_from_pocket(resource_type: String, amount: int) -> int:
	if amount <= 0 or resource_type.is_empty() or not pocket.has(resource_type):
		return 0
	var current := _pocket_amount(resource_type)
	var removed := mini(amount, current)
	if removed <= 0:
		return 0
	if current <= removed:
		pocket.erase(resource_type)
	else:
		pocket[resource_type] = current - removed
	return removed


func _pocket_resources() -> Array:
	return pocket.keys().duplicate()


func _primary_pocket_resource() -> String:
	for resource_type in pocket.keys():
		if int(pocket.get(resource_type, 0)) > 0:
			return str(resource_type)
	return ""


func _pocket_summary() -> String:
	if pocket.is_empty():
		return ""
	var parts: Array[String] = []
	for resource_type in pocket:
		parts.append("%s x%d" % [str(resource_type).capitalize(), int(pocket[resource_type])])
	return " | ".join(parts)


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
	var building_type := str(building.get_meta("building_type", ""))
	for candidate in ["forestry", "farming", "gather_food", "gather_branches", "cook", "teacher", "seller", "factory_worker", "engineer", "official"]:
		if building_type in _employer_types_for_role(candidate):
			return candidate
	return ""


func _resource_remaining_percent(resource_type: String) -> int:
	return hero_interaction_service.resource_remaining_percent(resource_type) if hero_interaction_service != null else 0


func _format_pocket_hint() -> String:
	return "Карман %d/%d%s" % [_pocket_total(), POCKET_CAPACITY, (" | " + _pocket_summary()) if not pocket.is_empty() else ""]


func _drop_pocket_on_ground() -> void:
	if player_citizen == null or pocket.is_empty():
		return
	_create_resource_pile(player_citizen.global_position, pocket.duplicate())
	pocket.clear()
	_update_interface("Содержимое карманов выброшено на землю.")
	_refresh_interaction_hint()


func _home_occupancy_text() -> String:
	if player_citizen == null or player_citizen.home == null or not is_instance_valid(player_citizen.home):
		return ""
	var home := player_citizen.home
	var capacity := int(home.get_meta("housing_capacity", 1))
	var free_slots := int(home.get_meta("spawn_slots", capacity))
	var occupied := clampi(capacity - free_slots, 0, capacity)
	return "Дом: %d/%d" % [occupied, capacity]


func _refresh_interaction_hint() -> void:
	if not is_first_person:
		interaction_hint_panel.visible = false
		return
	if _is_first_person_menu_open():
		interaction_hint_panel.visible = false
		return
	interaction_hint_panel.visible = true
	if pocket_menu_open:
		interaction_hint_label.text = "F / Esc / ПКМ — закрыть меню"
		interaction_progress.visible = false
		return
	if not interaction_action.is_empty():
		return
	var lines: Array[String] = []
	if player_citizen != null and not player_citizen.is_hero:
		var target := _first_person_target()
		if target.kind == "toilet":
			var needs_toilet := citizen_needs_service != null and citizen_needs_service.has_toilet_request(player_citizen.ai_id)
			if needs_toilet:
				lines.append("F: воспользоваться туалетом (потребность)")
			else:
				lines.append("F: воспользоваться туалетом")
		lines.append("Наблюдение: WASD — двигаться, ПКМ — выйти в обзор")
	else:
		var action_hint := _first_person_action_hint()
		if not action_hint.is_empty():
			lines.append(action_hint)
	lines.append(_format_pocket_hint())
	if not pocket.is_empty():
		lines.append("T: выбросить карманы на землю")
	var home_text := _home_occupancy_text()
	if not home_text.is_empty():
		lines.append(home_text)
	interaction_hint_label.text = "\n".join(lines)
	interaction_progress.visible = false


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
		var source: Dictionary = grass_sources[cell]
		if int(source.remaining) <= 0 or not is_instance_valid(source.node):
			continue
		var node_pos: Vector3 = (source.node as Node3D).global_position
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


func _pile_available_resources(pile: Dictionary) -> Array[String]:
	return storage_routing_service.pile_available_resources(pile)


func _handle_sawmill_interaction(all: bool, sawmill_pos: Vector3) -> void:
	var wood_count := _pocket_amount("wood") + _pocket_amount("logs")
	if wood_count > 0:
		var delivered := 0
		if all:
			var wood_delivered := _remove_from_pocket("wood", wood_count)
			var logs_delivered := _remove_from_pocket("logs", wood_count - wood_delivered)
			delivered = wood_delivered + logs_delivered
		else:
			delivered = _remove_from_pocket("wood", 1)
			if delivered == 0:
				delivered = _remove_from_pocket("logs", 1)
		if delivered > 0:
			var stock := _sawmill_stock(sawmill_pos)
			stock.logs = int(stock.logs) + delivered
			_store_sawmill_stock(sawmill_pos, stock)
			_update_interface("Сдано %d дерева на лесопилку." % delivered)
		_refresh_interaction_hint()
		return
	var sawmill_stock := _sawmill_stock(sawmill_pos)
	var available_boards := int(sawmill_stock.boards)
	if available_boards > 0 and _pocket_has_room():
		var take_amount := mini(available_boards, _pocket_space_for("boards")) if all else 1
		take_amount = _add_to_pocket("boards", take_amount)
		if take_amount > 0:
			sawmill_stock.boards = int(sawmill_stock.boards) - take_amount
			_store_sawmill_stock(sawmill_pos, sawmill_stock)
			_update_interface("Взяли %d досок с лесопилки." % take_amount)
	_refresh_interaction_hint()


func _handle_warehouse_interaction(all: bool, warehouse_index := -1) -> void:
	if _pocket_total() > 0:
		if all:
			_deliver_all_pocket_to_warehouse(warehouse_index)
		else:
			_deliver_one_pocket_to_warehouse(warehouse_index)
		_refresh_interaction_hint()
	else:
		_show_pocket_take_menu(warehouse_index)


func _deliver_pocket_to_site(site: ConstructionSite, all: bool) -> void:
	var delivered_any := false
	for resource_type in site.required_materials:
		var required := int(site.required_materials.get(resource_type, 0))
		var delivered := int(site.delivered_materials.get(resource_type, 0))
		var needed := required - delivered
		if needed <= 0:
			continue
		var in_pocket := _pocket_amount(resource_type)
		if in_pocket <= 0:
			continue
		var amount := mini(in_pocket, needed) if all else mini(1, needed)
		amount = mini(amount, in_pocket)
		if amount <= 0:
			continue
		_remove_from_pocket(resource_type, amount)
		construction.accept_delivery(site.node, resource_type, amount)
		delivered_any = true
		if not all:
			break
	if delivered_any:
		_update_interface("Материалы сданы на стройплощадку.")
		_refresh_interaction_hint()
	else:
		var missing := _missing_site_materials_text(site)
		if missing.is_empty():
			_update_interface("Стройплощадка уже полностью снабжена.")
		else:
			_update_interface("В кармане нет нужных материалов: %s." % missing)
		_refresh_interaction_hint()


func _refuel_fire_from_pocket(building: Node3D, all: bool) -> void:
	if not is_instance_valid(building):
		return
	var available := _pocket_amount("branches")
	if available <= 0:
		_update_interface("В кармане нет веток для костра.")
		_refresh_interaction_hint()
		return
	var fire_state := _fire_state_for(building)
	var amount := available if all else 1
	amount = mini(amount, available)
	var delivered := _remove_from_pocket("branches", amount)
	if delivered <= 0:
		return
	fire_state.add_delivered(delivered, int(game_minutes))
	_apply_fire_state(building, fire_state)
	_refresh_living_statuses()
	_update_interface("В костер добавлено веток: %d." % delivered)
	_refresh_interaction_hint()


func _meet_arrival_at_entrance() -> void:
	for index in pending_arrivals.size():
		var order: Dictionary = pending_arrivals[index]
		if bool(order.get("dispatched", false)):
			continue
		order.dispatched = true
		order.greeter_id = player_citizen.get_instance_id()
		pending_arrivals[index] = order
		arrival_greeters[player_citizen.get_instance_id()] = order
		_on_arrival_greeter_ready(player_citizen)
		_refresh_interaction_hint()
		return
	_update_interface("Никого не нужно встречать у входа.")
	_refresh_interaction_hint()


func _take_from_pile(pile: Dictionary, all: bool) -> void:
	var pile_node := pile.get("node") as Node3D
	if not is_instance_valid(pile_node):
		return
	var resources: Dictionary = pile.get("resources", {})
	var taken_any := false
	for resource_type in resources.keys():
		var available := int(resources.get(resource_type, 0))
		if available <= 0:
			continue
		if not _pocket_has_room():
			break
		var amount := mini(available, _pocket_space_for(resource_type)) if all else 1
		amount = mini(amount, available)
		var taken := _add_to_pocket(resource_type, amount)
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
			_update_interface("Карман полон.")
		else:
			_update_interface("Куча пуста или в ней нет подходящих ресурсов.")
		_refresh_interaction_hint()
		return
	pile.resources = resources
	if resources.is_empty():
		for index in range(resource_piles.size()):
			if resource_piles[index].get("node") == pile_node:
				resource_piles.remove_at(index)
				break
		pile_node.queue_free()
	else:
		_refresh_resource_pile_label(pile)
	_update_interface("Взяли из кучи. %s" % _format_pocket_hint())
	_refresh_interaction_hint()


func _citizen_state_name(state: int) -> String:
	match state:
		Citizen.State.TO_EMPLOYMENT_CENTER:
			return "Идет в службу занятости"
		Citizen.State.EMPLOYMENT_PROCESSING:
			return "Оформляется на работу"
		Citizen.State.TO_ARRIVAL_ENTRANCE:
			return "Идет встречать прибывшего"
		Citizen.State.ARRIVAL_MEETING:
			return "Встречает прибывшего"
		Citizen.State.ARRIVAL_WAITING:
			return "Ждет утра у входа"
		Citizen.State.TO_ARRIVAL_CENTER:
			return "Сопровождает прибывшего к регистрации"
	var state_names := Citizen.State.keys()
	if state < 0 or state >= state_names.size():
		return "Unknown state"
	return str(state_names[state]).capitalize().replace("_", " ")


func _warehouse_index_for_building(building: Node3D) -> int:
	return storage_routing_service.warehouse_index_for_building(building)


func _building_action_hint(building: Node3D) -> String:
	if first_person_hud_controller != null:
		return first_person_hud_controller.building_action_hint(building)
	return ""


func _first_person_action_hint() -> String:
	if first_person_hud_controller != null:
		return first_person_hud_controller.first_person_action_hint()
	return ""

func _targeted_grass_info(target: Dictionary) -> Dictionary:
	var target_node := target.get("node") as Node3D
	if not is_instance_valid(target_node):
		return {}
	for cell in grass_sources:
		var source: Dictionary = grass_sources[cell]
		if source.get("node") == target_node:
			return {"remaining": int(source.get("remaining", 0)), "initial": maxi(1, int(source.get("initial", 1)))}
	return {}

func _terrain_point_at_screen_position(screen_position: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.position as Vector3

func _move_selection(world_position: Vector3) -> void:
	selected_world_position = _snapped_build_position(world_position) if not build_mode.is_empty() else world_position
	selected_cell = _placement_key(selected_world_position)
	selection_marker.position = selected_world_position + Vector3(0.0, 0.04, 0.0)
	if not build_mode.is_empty():
		var local_footprint: Vector2i = BuildingBlueprints.get_blueprint(build_mode).footprint
		var footprint := _rotated_footprint(local_footprint)
		(selection_marker.mesh as BoxMesh).size = Vector3(footprint.x, 0.04, footprint.y)
		var forward := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, build_rotation_quarters * PI * 0.5)
		preview_entrance_marker.position = selected_world_position + forward * (local_footprint.y * 0.5 + 0.35) + Vector3.UP * 0.08
		preview_back_entrance_marker.position = selected_world_position - forward * (local_footprint.y * 0.5 + 0.35) + Vector3.UP * 0.08
		preview_entrance_marker.visible = true
		preview_back_entrance_marker.visible = true
	if not build_mode.is_empty():
		selection_material.albedo_color = Color(0.25, 0.85, 0.37, 0.55) if _can_place(selected_world_position) else Color(0.9, 0.2, 0.18, 0.6)

func _rotated_footprint(footprint: Vector2i) -> Vector2i:
	return Vector2i(footprint.y, footprint.x) if build_rotation_quarters % 2 != 0 else footprint


func _place_building(world_position: Vector3) -> void:
	if not _can_hero_build():
		_update_interface("Only the hero can approve construction decisions.")
		return
	world_position = _snapped_build_position(world_position)
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
	if not _can_place(world_position):
		_update_interface("Construction is not allowed at this point.")
		return
	if not _can_pay_building_cost(build_mode):
		var placement_state: Dictionary = building_availability_service.placement_state_with_inventory(build_mode, pocket)
		_update_interface(str(placement_state.message))
		return
	building_registry.reserve(cell, world_position, occupied_footprint)
	_refresh_navigation_grid()
	var site := _create_construction_site(cell, build_mode, world_position, build_rotation_quarters, blueprint, occupied_footprint)
	_deliver_pocket_to_site(site, true)
	building_registry.attach_node(cell, site.node)
	build_mode = ""
	build_rotation_quarters = 0
	selection_marker.visible = false
	preview_entrance_marker.visible = false
	preview_back_entrance_marker.visible = false
	_show_territory_overlay(false)
	build_menu.visible = false
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
	return not is_first_person or player_citizen == hero_citizen

func _can_place(world_position: Vector3) -> bool:
	if build_mode.is_empty():
		return false
	var footprint := _rotated_footprint(BuildingBlueprints.get_blueprint(build_mode).footprint)
	return _is_footprint_level(world_position, footprint) and _is_footprint_clear(world_position, footprint)

func _can_pay_building_cost(building_type: String) -> bool:
	return bool(building_availability_service.placement_state_with_inventory(building_type, pocket).allowed)

func _pay_building_cost(building_type: String) -> void:
	settlement.pay_for_building(building_type)

func _is_footprint_clear(world_position: Vector3, footprint: Vector2i) -> bool:
	if not building_registry.is_footprint_clear(world_position, footprint, BUILDING_CLEARANCE_BLOCKS):
		return false
	if _footprint_overlaps_terrain_obstacle(world_position, footprint):
		return false
	var half := Vector2(footprint.x, footprint.y) * 0.5
	for site in dig_sites:
		if absf(world_position.x - site.node.global_position.x) < half.x + 1.0 and absf(world_position.z - site.node.global_position.z) < half.y + 1.0:
			return false
	return true

func _footprint_overlaps_terrain_obstacle(center: Vector3, footprint: Vector2i) -> bool:
	return building_placement_service.footprint_overlaps_terrain_obstacle(center, footprint) if building_placement_service != null else false

func _is_footprint_level(world_position: Vector3, footprint: Vector2i) -> bool:
	return building_placement_service.is_footprint_level(world_position, footprint) if building_placement_service != null else false

func _terrain_height_at(x: float, z: float, near_y: float) -> float:
	if DisplayServer.get_name() == "headless":
		return 0.0
	var from := Vector3(x, near_y + 12.0, z)
	var query := PhysicsRayQueryParameters3D.create(from, Vector3(x, near_y - 12.0, z))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return NAN if hit.is_empty() else float(hit.position.y)

func _snapped_build_position(world_position: Vector3) -> Vector3:
	var snapped := Vector3(roundf(world_position.x), world_position.y, roundf(world_position.z))
	var ground_height := _terrain_height_at(snapped.x, snapped.z, world_position.y)
	if not is_nan(ground_height):
		snapped.y = ground_height
	return snapped

func _is_clear_of_objects(world_position: Vector3, minimum_distance: float) -> bool:
	return building_placement_service.is_clear_of_objects(world_position, minimum_distance) if building_placement_service != null else false

func _placement_key(world_position: Vector3) -> Vector2i:
	return Vector2i(roundi(world_position.x), roundi(world_position.z))

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
	if hud != null:
		hud.set_status(text)

func _complete_building(cell: Vector2i, building_type: String, position_on_board: Vector3, building: Node3D, blueprint: Dictionary) -> void:
	settlement.buildings[building_type] = int(settlement.buildings.get(building_type, 0)) + 1
	building.set_meta("building_type", building_type)
	building.set_meta("condition", 100.0)
	_unregister_service_pockets(building)
	if building_type in ["campfire", "campfire_lvl2", "campfire_lvl3", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3"]:
		building.set_meta("fire_fuel", 4)
		building.set_meta("fire_lit", true)
		building.set_meta("fire_embers_until", -1)
		building.set_meta("fire_phase", "burning")
	if _is_staffed_workplace(building):
		workplace_priority_counter += 1
		building.set_meta("accepting_workers", true)
		building.set_meta("workplace_priority", workplace_priority_counter)
	if building_type not in ["warehouse", "straw_warehouse", "tarp_warehouse", "campfire", "campfire_lvl2", "campfire_lvl3", "earth_assembly", "clay_lodge", "wood_town_hall", "stone_prefecture", "brick_city_hall", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant", "straw_trade_tent", "tarp_trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market", "school", "materials_factory", "tent", "straw_tent", "tarp_tent", "dugout", "earth_house", "clay_house", "stone_house", "house", "house_lvl2", "house_lvl3", "brick_house", "straw_craft_tent", "tarp_craft_tent", "straw_forager_tent", "tarp_forager_tent", "boundary_post"]:
		_add_building_selector(building, "building_selector", blueprint.footprint)
	var is_home := building_type in ["tent", "straw_tent", "tarp_tent", "dugout", "earth_house", "clay_house", "stone_house", "house", "house_lvl2", "house_lvl3", "brick_house"]
	_register_service_entrance(building, blueprint, is_home, building_type not in ["farm", "park"])
	var service_position: Vector3 = building.get_meta("service_position")
	_register_completed_building_type_features(building_type, building, blueprint, service_position)

	building_registry.attach_node(cell, building)
	var occupied_footprint: Vector2i = building.get_meta("occupied_footprint", blueprint.footprint)
	village_territory_service.on_building_added(cell, building_type)
	_refresh_boundary_markers()
	_add_building_status_indicator(building)
	_refresh_navigation_grid()
	_update_workers()
	_refresh_build_menu()
	var completion_message := "%s construction completed." % building_type.capitalize()
	if building_type in ["recycling_factory", "metal_factory"]:
		completion_message += " It requires 3 factory workers."
	_update_interface(completion_message)
	_request_courier_dispatch()


func _register_completed_building_type_features(building_type: String, building: Node3D, blueprint: Dictionary, service_position: Vector3) -> void:
	match building_type:
		"warehouse", "straw_warehouse", "tarp_warehouse":
			settlement.add_warehouse(building_type)
			warehouse_positions.append(service_position)
			if warehouse_positions.size() == 1:
				_convert_backpack_pile_to_regular()
				settlement.warehouse_ever_built = true
				settlement.backpack.clear()
			_add_building_selector(building, "warehouse_selector", blueprint.footprint)
			_add_warehouse_fill_label(building)
		"sawmill":
			sawmill_positions.append(service_position)
			_sawmill_stock(service_position)
		"farm":
			farm_positions.append(service_position)
		"builders_guild":
			builders_guild_positions.append(service_position)
		"construction_company":
			construction_company_positions.append(service_position)
		"campfire", "campfire_lvl2", "campfire_lvl3", "earth_assembly", "clay_lodge", "wood_town_hall", "stone_prefecture", "brick_city_hall":
			campfire_node = building
			_activate_employment_centre(building)
			_add_building_selector(building, "campfire_selector", blueprint.footprint)
			var fire_light := FireLightScene.instantiate()
			building.add_child(fire_light)
		"gathering_place":
			gathering_place_positions.append(service_position)
			_create_gathering_place_visual(building)
			_add_building_selector(building, "building_selector", blueprint.footprint)
		"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant":
			_activate_kitchen_if_better(building, service_position)
			_add_building_selector(building, "cook_campfire_selector", blueprint.footprint)
			var cook_fire_light := FireLightScene.instantiate()
			building.add_child(cook_fire_light)
		"forager_tent", "straw_forager_tent", "tarp_forager_tent":
			forager_positions.append(service_position)
			_update_interface("Forager tent ready. Assign a resident to forage food, or a free hand will.")
		"materials_yard", "straw_materials_yard", "tarp_materials_yard":
			materials_yard_positions.append(service_position)
			_update_interface("Двор стройматериалов готов. Работники собирают ветки и траву (что в дефиците), или это сделает свободный житель.")
		"tent", "straw_tent", "tarp_tent", "dugout", "earth_house", "clay_house", "stone_house", "house", "house_lvl2", "house_lvl3", "brick_house":
			if building_type in ["house", "house_lvl2", "house_lvl3", "brick_house"]:
				completed_house_count += 1
			var housing_capacity := HOUSE_CAPACITY
			match building_type:
				"straw_tent": housing_capacity = 1
				"tarp_tent": housing_capacity = 2
				"tent", "dugout": housing_capacity = 4
				"earth_house", "clay_house": housing_capacity = 6
				"house": housing_capacity = 8
				"house_lvl2": housing_capacity = 10
				"house_lvl3": housing_capacity = 12
				"stone_house": housing_capacity = 10
				"brick_house": housing_capacity = 12
			building.set_meta("housing_capacity", housing_capacity)
			building.set_meta("spawn_slots", housing_capacity)
			_add_building_selector(building, "house_selector", blueprint.footprint)
			_add_house_light(building)
			if building_type in ["tent", "straw_tent", "tarp_tent"]:
				building.set_meta("is_tent", true)
			_house_initial_residents(building)
		"dew_collector", "advanced_dew_collector":
			var rate := 0.12
			var capacity := 10
			if building_type == "advanced_dew_collector":
				rate = 0.3
				capacity = 25
			water_collectors.append({"node": building, "rate": rate, "accum": 0.0, "stored": 0, "capacity": capacity})
		"craft_tent", "straw_craft_tent", "tarp_craft_tent":
			craft_tent_positions.append(service_position)
		"straw_trade_tent", "tarp_trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market":
			_add_building_selector(building, "market_selector", blueprint.footprint)
			market_positions.append(service_position)
		"employment_office":
			employment_office = building
			employment_office_position = service_position
		"school":
			school_positions.append(service_position)
			_add_building_selector(building, "school_selector", blueprint.footprint)
		"park":
			park_positions.append(service_position)
		"leisure_center":
			leisure_positions.append(service_position)
		"brick_factory", "materials_factory", "recycling_factory", "metal_factory":
			building.set_meta("required_factory_workers", 3 if building_type in ["recycling_factory", "metal_factory"] else 1)
			factories.append(building)
			if building_type == "materials_factory":
				_add_building_selector(building, "materials_factory_selector", blueprint.footprint)
		"boundary_post":
			_add_building_selector(building, "building_selector", blueprint.footprint)


func _activate_kitchen_if_better(building: Node3D, service_position: Vector3) -> void:
	var capacity := BuildingCatalog.kitchen_food_capacity(str(building.get_meta("building_type", "")))
	var active_capacity := BuildingCatalog.kitchen_food_capacity(str(canteen.get_meta("building_type", ""))) if is_instance_valid(canteen) else 0
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
		var capacity := BuildingCatalog.kitchen_food_capacity(str(candidate.get_meta("building_type", "")))
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


func _update_warehouse_fill_labels() -> void:
	if warehouse_fill_label_controller != null:
		warehouse_fill_label_controller.update_warehouse_fill_labels()

func _update_building_status_indicators(delta: float) -> void:
	if building_status_indicator_controller != null:
		building_status_indicator_controller.update_building_status_indicators(delta)

func _required_staff_for_building(building: Node3D) -> Dictionary:
	if building_status_indicator_controller != null:
		return building_status_indicator_controller.required_staff_for_building(building)
	return {}

func _assigned_staff_for_building(building: Node3D, required: Dictionary) -> int:
	if building_status_indicator_controller != null:
		return building_status_indicator_controller.assigned_staff_for_building(building, required)
	return 0

func _has_storage_room_for_role(role: String) -> bool:
	return storage_routing_service.has_storage_room_for_role(role)

func _send_citizen_to_leisure(citizen: Citizen, minimum_hours := 0) -> bool:
	# Returns whether the citizen was actually placed somewhere to rest so the
	# waiting window knows if it needs to keep looking for work.
	if citizen.is_player_controlled or citizen.state not in [Citizen.State.IDLE, Citizen.State.RESTING, Citizen.State.WAITING]:
		return false
	# Dedicated recreation first (parks, leisure centers), picked at random.
	var recreation: Array[Vector3] = park_positions + leisure_positions
	for position in gathering_place_positions:
		var place := _building_at_service_position(position)
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
		_update_interface("Нет складов с заполненностью меньше 90%.")
	elif not result.overflow.is_empty() and not warehouse_positions.is_empty():
		_drop_overflow_as_piles(result.overflow, warehouse_positions[0])
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
				_add_service_entrance_marker(building, local)
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
				_add_visitor_entrance_marker(building, local)

func _add_service_entrance_marker(building: Node3D, marker_local: Vector3) -> void:
	if building_visuals_service != null:
		building_visuals_service.add_service_entrance_marker(building, marker_local)

func _add_visitor_entrance_marker(building: Node3D, marker_local: Vector3) -> void:
	if building_visuals_service != null:
		building_visuals_service.add_visitor_entrance_marker(building, marker_local)

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
			if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
				var consumed := 0
				while consumed < amount:
					var result := _consume_tree_branches(position_on_board)
					if result <= 0:
						break
					consumed += result
				if consumed > 0:
					_update_interface("Собрано веток: %d. Дерево стоит." % consumed)
				else:
					_update_interface("У дерева не осталось веток для ручного сбора.")
				return


func _fell_nearest_tree() -> void:
	if player_citizen == null:
		return
	for position_on_board in tree_positions:
		if player_citizen.global_position.distance_to(position_on_board) <= INTERACTION_RANGE:
			var tree: Node3D = tree_nodes.get(_cell_from_position(position_on_board))
			if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
				_fell_tree_at(position_on_board)
				return


func _fell_tree_at(position_on_board: Vector3) -> void:
	var cell := _cell_from_position(position_on_board)
	var tree: Node3D = tree_nodes.get(cell)
	if not is_instance_valid(tree):
		return
	if bool(tree.get_meta("felled", false)):
		return
	tree.set_meta("felled", true)
	tree.rotation_degrees.z = 82.0
	var collision_body := tree.get_node_or_null("TreeCollision") as CollisionObject3D
	if collision_body != null:
		collision_body.queue_free()
	terrain_blocked_cells.erase(cell)
	_refresh_navigation_grid()
	settlement.add("branches", 3)
	_update_interface("A tree was felled. Its log is ready for delivery; the living tree is no longer available for gathering.")

func _update_water_collectors(delta: float) -> void:
	water_collector_service.tick(delta)


func _toggle_global_build_menu() -> void:
	var was_visible := build_menu.visible and build_menu_is_global
	_close_context_menus()
	build_menu_is_global = not was_visible
	build_menu.visible = build_menu_is_global
	if build_menu.visible:
		build_category = ""
		build_menu_is_job_menu = false
		build_menu_is_daily_order_menu = false
		_refresh_build_menu()


func _show_campfire_menu() -> void:
	if campfire_menu_controller != null:
		campfire_menu_controller.show_campfire_menu()


func _show_campfire_story_menu() -> void:
	if campfire_menu_controller != null:
		campfire_menu_controller.show_campfire_story_menu()


func _close_campfire_story_menu() -> void:
	if campfire_menu_controller != null:
		campfire_menu_controller.close_campfire_story_menu()


func _select_campfire_story(story_id: String) -> void:
	if campfire_menu_controller != null:
		campfire_menu_controller.select_campfire_story(story_id)


func _show_campfire_orders_menu() -> void:
	if campfire_menu_controller != null:
		campfire_menu_controller.show_campfire_orders_menu()


func _close_campfire_orders_menu() -> void:
	if campfire_menu_controller != null:
		campfire_menu_controller.close_campfire_orders_menu()
	campfire_menu.visible = true


func _set_road_walking_order(enabled: bool) -> void:
	if settlement.era != SettlementState.Era.TENT:
		return
	settlement.road_walking_order_enabled = enabled
	_update_interface("Trail-walking order %s. It does not change routes yet." % ("enabled" if enabled else "disabled"))


func _set_balanced_warehouse_mode(enabled: bool) -> void:
	storage_routing_service.set_balanced_warehouse_mode(enabled)


func _cheer_up_settlement() -> void:
	if clock.hour() < 6:
		return
	if settlement.apply_cheer_up():
		_show_campfire_orders_menu()
		_update_interface("You cheered up the settlement. Wellbeing rose by 5%%.")


func _has_night_work_candidates() -> bool:
	for citizen in citizens:
		if is_instance_valid(citizen) and not citizen.is_player_controlled and not citizen.is_recovering(day_cycle.current_day) and (citizen.has_active_daily_order() or citizen.is_employed()):
			return true
	return false


func _toggle_settlement_night_work(checked: bool) -> void:
	if checked:
		if settlement.night_work_order_day == day_cycle.current_day:
			_show_campfire_orders_menu()
			return
		var affected := 0
		for citizen in citizens:
			if not is_instance_valid(citizen) or citizen.is_player_controlled or citizen.is_recovering(day_cycle.current_day):
				continue
			if citizen.has_active_daily_order() or citizen.is_employed():
				if _activate_citizen_overtime(citizen, "settlement"):
					affected += 1
		if affected <= 0:
			_show_campfire_orders_menu()
			return
		settlement.night_work_order_day = day_cycle.current_day
		_update_interface("Night-work order issued to %d residents. They will work through the night and next day." % affected)
		_update_skip_night_button()
		if citizen_ai != null:
			citizen_ai.request_decision_refresh()
	else:
		for citizen in citizens:
			if not is_instance_valid(citizen) or citizen.is_player_controlled:
				continue
			if citizen.has_overtime_source("settlement", day_cycle.current_day):
				citizen.deactivate_overtime("settlement")
		_sync_overtime_scope_indicators()
		_update_interface("Settlement night work cancelled. Workers will return home.")
		_update_skip_night_button()
		if citizen_ai != null:
			citizen_ai.request_decision_refresh()
	_show_campfire_orders_menu()


func _toggle_double_time_order(checked: bool) -> void:
	if checked:
		if settlement.double_time_order_day == day_cycle.current_day:
			_show_campfire_orders_menu()
			return
		settlement.double_time_order_day = day_cycle.current_day
		_update_interface("Double time order issued. All residents walk twice as fast today, but fatigue accumulates faster.")
	else:
		settlement.double_time_order_day = -1
		_update_interface("Double time order cancelled. Residents resume normal pace.")
	_show_campfire_orders_menu()


func _toggle_selected_citizen_night_work(checked: bool) -> void:
	if not is_instance_valid(selected_builder):
		build_menu.personal_night_work_button.set_pressed_no_signal(false)
		return
	if checked:
		if not selected_builder.has_daily_order() or selected_builder.is_employed() or selected_builder.has_overtime_source("personal", day_cycle.current_day):
			build_menu.personal_night_work_button.set_pressed_no_signal(false)
			return
		# Evening daily orders normally wait for tomorrow. A personal night-work
		# order explicitly starts that new task now and keeps it through tomorrow.
		# Permanent jobs already have an active assignment, including courier jobs
		# that do not belong to a workplace, so they only need the overtime flag.
		if not _activate_citizen_overtime(selected_builder, "personal"):
			build_menu.personal_night_work_button.set_pressed_no_signal(false)
			return
		_update_interface("%s received a personal night-work order." % selected_builder.role_label())
		_update_skip_night_button()
		if citizen_ai != null:
			citizen_ai.request_decision_refresh()
	else:
		selected_builder.deactivate_overtime("personal")
		_update_interface("Night work cancelled for %s." % selected_builder.role_label())
		_update_skip_night_button()
		if citizen_ai != null:
			citizen_ai.request_decision_refresh()
	_refresh_build_menu()


func _show_workforce_menu() -> void:
	if workforce_menu_controller != null:
		workforce_menu_controller.show_workforce_menu()


func _hide_workforce_menu() -> void:
	if workforce_menu_controller != null:
		workforce_menu_controller.hide_workforce_menu()


func _close_workforce_menu() -> void:
	if workforce_menu_controller != null:
		workforce_menu_controller.close_workforce_menu()


func _refresh_campfire_occupancy_button() -> void:
	if workforce_menu_controller != null:
		workforce_menu_controller.refresh_campfire_occupancy_button()


func _workforce_roles() -> Array[String]:
	if workforce_menu_controller != null:
		return workforce_menu_controller.workforce_roles()
	return []


func _daily_order_roles() -> Array[String]:
	if workforce_menu_controller != null:
		return workforce_menu_controller.daily_order_roles()
	return []


func _workforce_role_label(role: String) -> String:
	if workforce_menu_controller != null:
		return workforce_menu_controller.workforce_role_label(role)
	return role


func _workforce_role_limit(role: String) -> int:
	if workforce_menu_controller != null:
		return workforce_menu_controller.workforce_role_limit(role)
	return -1


func _workforce_role_count(role: String) -> int:
	if workforce_menu_controller != null:
		return workforce_menu_controller.workforce_role_count(role)
	return 0


func _manually_assigned_count(role: String) -> int:
	if workforce_menu_controller != null:
		return workforce_menu_controller.manually_assigned_count(role)
	return 0


func _auto_or_unassigned_worker_count() -> int:
	if workforce_menu_controller != null:
		return workforce_menu_controller.auto_or_unassigned_worker_count()
	return 0


func _refresh_workforce_menu() -> void:
	if workforce_menu_controller != null:
		workforce_menu_controller.refresh_workforce_menu()


func _employment_resident_count() -> int:
	if workforce_menu_controller != null:
		return workforce_menu_controller.employment_resident_count()
	return 0


func _employment_state_count(state: int) -> int:
	if workforce_menu_controller != null:
		return workforce_menu_controller.employment_state_count(state)
	return 0


func _daily_order_role_count(role: String) -> int:
	if workforce_menu_controller != null:
		return workforce_menu_controller.daily_order_role_count(role)
	return 0


func _employment_role_count(role: String, state: int) -> int:
	if workforce_menu_controller != null:
		return workforce_menu_controller.employment_role_count(role, state)
	return 0


func _citizens_with_employment_states(states: Array) -> Array[Citizen]:
	if workforce_menu_controller != null:
		return workforce_menu_controller.citizens_with_employment_states(states)
	return []


func _has_assignable_resident() -> bool:
	if workforce_menu_controller != null:
		return workforce_menu_controller.has_assignable_resident()
	return false


func _remove_worker_from_role(role: String) -> void:
	if workforce_menu_controller != null:
		workforce_menu_controller.remove_worker_from_role(role)


func _assign_unemployed_worker(role: String) -> void:
	if workforce_menu_controller != null:
		workforce_menu_controller.assign_unemployed_worker(role)


func _enable_auto_for_citizen(citizen: Citizen) -> void:
	if workforce_menu_controller != null:
		workforce_menu_controller.enable_auto_for_citizen(citizen)


func _refresh_campfire_menu() -> void:
	if campfire_menu_controller != null:
		campfire_menu_controller.refresh_campfire_menu()


func _build_campfire_era_requirements(housing_slots: int) -> Array:
	if campfire_menu_controller != null:
		return campfire_menu_controller.build_campfire_era_requirements(housing_slots)
	return ["", false]


func _occupy_selected_campfire_position() -> void:
	if not is_instance_valid(selected_campfire) or not is_instance_valid(player_citizen):
		return
	if player_citizen.global_position.distance_to(_nearest_service_position(selected_campfire, player_citizen.global_position)) > OFFICER_POST_RADIUS:
		return
	_occupy_workplace(selected_campfire)
	_refresh_campfire_menu()


func _handle_campfire_primary_action() -> void:
	if not is_instance_valid(selected_campfire):
		return
	selected_building = selected_campfire
	if not _is_fire_lit(selected_campfire):
		_relight_selected_fire()
		_refresh_campfire_menu()
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
		_refresh_campfire_menu()
		_refresh_build_menu()
	else:
		_update_interface("Failed to advance era. Double-check requirements.")


func _show_market_menu() -> void:
	if market_menu_controller != null:
		market_menu_controller.show_market_menu()


func _refresh_market_menu() -> void:
	if market_menu_controller != null:
		market_menu_controller.refresh_market_menu()


func _buy_food(quantity: int, unit_price: int) -> void:
	trade_service.buy_food(quantity, unit_price)


func _sell_resource(resource_type: String, quantity: int, unit_price: int) -> void:
	trade_service.sell_resource(resource_type, quantity, unit_price)


func _buy_tool(tool_id: String, price: int) -> void:
	trade_service.buy_tool(tool_id, price)


func _buy_courier_equipment(courier: Citizen, equipment_id: String, price: int) -> void:
	trade_service.buy_courier_equipment(courier, equipment_id, price)


func _start_trade(trade: Dictionary, source: Vector3, destination: Vector3) -> void:
	trade_service.start_trade(trade, source, destination)


func _trade_orders() -> Array[Dictionary]:
	return trade_service.trade_orders()


func _trade_reserved_money() -> int:
	return trade_service.trade_reserved_money()


func _available_trade_money() -> int:
	return trade_service.available_trade_money()


func _trade_incoming_resource(resource_type: String) -> int:
	return trade_service.trade_incoming_resource(resource_type)


func _trade_has_tool_order(tool_id: String) -> bool:
	return trade_service.trade_has_tool_order(tool_id)


func _on_trade_delivery_finished(worker: Citizen) -> void:
	trade_service.on_trade_delivery_finished(worker)
	courier_dispatcher.complete_for(worker)

func _show_building_menu() -> void:
	if building_menu_controller != null:
		building_menu_controller.show_building_menu()


func _demolish_selected_building() -> void:
	if is_instance_valid(selected_building):
		_mark_building_for_demolition(selected_building)


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
	if is_instance_valid(selected_campfire) and selected_building == selected_campfire and campfire_menu.visible:
		_refresh_campfire_menu()
	else:
		_show_building_menu()


func _upgrade_selected_building() -> void:
	if not is_instance_valid(selected_building):
		return
	var old_type := str(selected_building.get_meta("building_type", ""))
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
	elif target_type in ["cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant"]:
		_activate_kitchen_if_better(selected_building, service_position)
		_add_building_selector(selected_building, "cook_campfire_selector", blueprint.footprint)
		_add_fire_light(selected_building)
	_add_building_status_indicator(selected_building)
	if target_type in ["warehouse", "straw_warehouse", "tarp_warehouse"]:
		_add_warehouse_fill_label(selected_building)
	village_territory_service.recalculate()
	_refresh_boundary_markers()
	_refresh_navigation_grid()
	_update_workers()
	_update_interface("%s upgraded to %s." % [str(BuildingCatalog.definition_for(old_type).get("name", old_type)), str(BuildingCatalog.definition_for(target_type).get("name", target_type))])
	if campfire_menu.visible and selected_building == selected_campfire:
		_refresh_campfire_menu()
	else:
		_show_building_menu()


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
		if str(building.get_meta("building_type", "")) in _employer_types_for_role(candidate_role):
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
		if str(candidate.get_meta("building_type", "")) in _employer_types_for_role(role) and int(candidate.get_meta("workplace_priority", 0)) > priority:
			position += 1
	return position


func _show_pocket_take_menu(warehouse_index := -1) -> void:
	if pocket_take_menu_controller != null:
		pocket_take_menu_controller.show_pocket_take_menu(warehouse_index)


func _close_pocket_take_menu() -> void:
	if pocket_take_menu_controller != null:
		pocket_take_menu_controller.close_pocket_take_menu()


func _refresh_pocket_take_menu() -> void:
	if pocket_take_menu_controller != null:
		pocket_take_menu_controller.refresh_pocket_take_menu()


func _take_resource_into_pocket(resource_type: String, amount: int) -> void:
	if amount <= 0:
		return
	var warehouse_index := _nearby_warehouse_index()
	if warehouse_index >= 0:
		amount = mini(amount, settlement.warehouses[warehouse_index].amount(resource_type))
	else:
		amount = mini(amount, settlement.amount(resource_type))
	amount = _add_to_pocket(resource_type, amount)
	if amount > 0:
		if warehouse_index >= 0:
			settlement.add_to_warehouse(resource_type, -amount, warehouse_index)
		else:
			settlement.add(resource_type, -amount)
		_update_interface("Взяли %d %s со склада." % [amount, resource_type])
	_refresh_pocket_take_menu()
	_refresh_interaction_hint()


func _show_warehouse_menu() -> void:
	if warehouse_menu_controller != null:
		warehouse_menu_controller.show_warehouse_menu()


func _refresh_warehouse_menu() -> void:
	if warehouse_menu_controller != null:
		warehouse_menu_controller.refresh_warehouse_menu()


func _toggle_warehouse_accept(accepted: bool, resource_type: String) -> void:
	if warehouse_menu_controller != null:
		warehouse_menu_controller.toggle_warehouse_accept(accepted, resource_type)


func _dump_warehouse_resource(resource_type: String) -> void:
	if warehouse_menu_controller != null:
		warehouse_menu_controller.dump_warehouse_resource(resource_type)


func _cover_warehouse_with_tarp() -> void:
	if warehouse_menu_controller != null:
		warehouse_menu_controller.cover_warehouse_with_tarp()


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
		_show_labor_command_blocked()
		return
	if not _set_manual_specialist_employment(selected_builder, "cook"):
		return
	selected_builder.setup_specialization("cook")
	_update_interface("%s is registering as a cook." % selected_builder.role_label())
	_update_workers()


func _assign_teacher_at_school() -> void:
	if not _player_can_manage_permanent_professions():
		_show_labor_command_blocked()
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
		_show_labor_command_blocked()
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
	_update_interface("%s покинул пост управляющего." % citizen.role_label())
	_update_workers()
	_refresh_build_menu()


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
		_show_labor_command_blocked()
		return false
	if citizen.employment_state != Citizen.EmploymentState.NO_PERMANENT_WORK:
		return false
	citizen.idle()
	citizen.begin_employment_processing(_employment_center_position(), role, _employer_for_role(role))
	return true


func _find_forage_position(citizen: Citizen) -> Vector3:
	return foraging_service.find_forage_position(citizen)

func harvest_wild_food(position: Vector3, worker: Citizen) -> String:
	return foraging_service.harvest_wild_food(position, worker)

func _consume_grass_source(position: Vector3) -> int:
	return foraging_service.consume_grass_source(position)

func _consume_tree_branches(position: Vector3) -> int:
	return foraging_service.consume_tree_branches(position)

func _mark_tree_branch_exhausted(tree: Node3D) -> void:
	foraging_service.mark_tree_branch_exhausted(tree)

func _nearest_tree_node(from: Vector3) -> Node3D:
	return foraging_service.nearest_tree_node(from)

func _nearest_grass_node(from: Vector3) -> Node3D:
	return foraging_service.nearest_grass_node(from)

func _player_gather_target_node() -> Node3D:
	return foraging_service.player_gather_target_node(player_citizen, interaction_resource)

func _gather_node_at(position: Vector3, resource_type: String) -> Node3D:
	return foraging_service.gather_node_at(position, resource_type)

func _gather_progress_amounts(resource_type: String, node: Node3D) -> Dictionary:
	return foraging_service.gather_progress_amounts(resource_type, node)

func _ensure_gather_progress_label(node: Node3D) -> Label3D:
	return foraging_service.ensure_gather_progress_label(node)

func _update_gather_progress_label(node: Node3D, resource_type: String, partial: float) -> void:
	foraging_service.update_gather_progress_label(node, resource_type, partial)

func _update_gathering_indicators(_delta: float) -> void:
	foraging_service.update_gathering_indicators(is_first_person, interaction_action, interaction_resource, interaction_time, player_citizen, citizens)


func _create_gathering_place_visual(building: Node3D) -> void:
	var visual := GatheringPlaceVisualScene.instantiate() as Node3D
	building.add_child(visual)

func _building_at_service_position(position: Vector3) -> Node3D:
	return building_registry.building_at_service_position(position)


func _fire_state_for(building: Node3D) -> RefCounted:
	return fire_management_service.fire_state_for(building)

func _is_managed_fire_source(building: Node3D) -> bool:
	return fire_management_service.is_managed_fire_source(building)

func _apply_fire_state(building: Node3D, fire_state: RefCounted) -> void:
	fire_management_service.apply_fire_state(building, fire_state)

func _is_fire_lit(building: Node3D) -> bool:
	return fire_management_service.is_fire_lit(building)

func fire_smoke_work_multiplier(position_on_board: Vector3) -> float:
	return fire_management_service.fire_smoke_work_multiplier(position_on_board)

func campfire_story_efficiency_multiplier(role: String) -> float:
	return fire_management_service.campfire_story_efficiency_multiplier(role)

func _update_fire_status() -> void:
	fire_management_service.update_fire_status(self, branches)

func _update_fire_visual(building: Node3D, fire_state: RefCounted, minute: int) -> void:
	fire_management_service.update_fire_visual(building, fire_state, minute)

func _report_fire_phase_change(building: Node3D, fire_state: RefCounted, minute: int) -> void:
	fire_management_service.report_fire_phase_change(building, fire_state, minute, campfire_node, branches)

func _apply_building_wear_and_repairs() -> void:
	building_maintenance_service.apply_building_wear_and_repairs(_destroy_building_to_pile)

func _has_active_builder() -> bool:
	return building_maintenance_service.has_active_builder(citizens)

func _destroy_building_to_pile(building: Node3D, building_type: String) -> void:
	building_maintenance_service.destroy_building_to_pile(building, building_type, citizens, warehouse_positions, campfire_node)



func _move_stored_resources_to_pile(resources: Dictionary, warehouse_index := -1) -> void:
	building_lifecycle_service.move_stored_resources_to_pile(resources, warehouse_index)


func _select_best_campfire() -> void:
	building_lifecycle_service.select_best_campfire()


func _refresh_boundary_markers() -> void:
	var territory: RefCounted = village_territory_service.territory()
	if village_boundary_markers != null:
		village_boundary_markers.refresh(territory)
	if village_territory_overlay != null:
		village_territory_overlay.refresh(territory)


func _show_territory_overlay(show: bool) -> void:
	if village_territory_overlay != null:
		if show:
			village_territory_overlay.refresh(village_territory_service.territory())
		village_territory_overlay.visible = show

func _create_resource_pile(position: Vector3, resources: Dictionary, is_backpack_pile := false) -> void:
	resource_pile_service.create_resource_pile(position, resources, is_backpack_pile)

func _remove_backpack_pile() -> void:
	backpack_node = resource_pile_service.remove_backpack_pile(backpack_node)

func _sync_backpack_pile() -> void:
	backpack_node = resource_pile_service.sync_backpack_pile(backpack_node)

func _convert_backpack_pile_to_regular() -> void:
	backpack_node = resource_pile_service.convert_backpack_pile_to_regular(backpack_node)

func _drop_overflow_as_piles(overflow: Dictionary, base_position: Vector3) -> void:
	resource_pile_service.drop_overflow_as_piles(overflow, base_position)

func _refresh_resource_pile_label(pile: Dictionary) -> void:
	resource_pile_service.refresh_resource_pile_label(pile)

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
	var warehouse_index := _find_reachable_warehouse_index(from, "", 1, false)
	if warehouse_index >= 0:
		return warehouse_positions[warehouse_index]
	if is_instance_valid(campfire_node) and _is_route_reachable(from, campfire_node.global_position, false):
		return campfire_node.global_position
	if is_instance_valid(entrance_stone):
		return entrance_stone.global_position
	return Vector3.ZERO


func _warehouse_delivery_position(from: Vector3, resource_type: String, amount: int) -> Vector3:
	return storage_routing_service.warehouse_delivery_position(from, resource_type, amount)


func _find_reachable_warehouse_index(from: Vector3, resource_type: String, amount: int, require_room := true) -> int:
	return storage_routing_service.find_reachable_warehouse_index(from, resource_type, amount, require_room)


func _route_cost(from: Vector3, route: RouteResult) -> float:
	return storage_routing_service.route_cost(from, route)

func _is_construction_site(node: Node3D) -> bool:
	return is_instance_valid(node) and construction.has_site(node)

func _get_construction_site_data(node: Node3D) -> ConstructionSite:
	return construction.site_for_node(node)

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
			var b_type: String = record.node.get_meta("building_type", "")
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
			_add_message("Предупреждение: В службе занятости нет чиновника! Оформление жителей приостановлено.")


func _toggle_worker_overtime(checked: bool) -> void:
	if not is_instance_valid(selected_building):
		return
	if checked:
		var night_order_used := int(selected_building.get_meta("night_work_order_day", -1)) == day_cycle.current_day
		if night_order_used:
			building_overtime_button.set_pressed_no_signal(false)
			return
		var workers_found := false
		for citizen in citizens:
			if is_instance_valid(citizen) and citizen.is_employed() and citizen.employment_workplace == selected_building:
				if _activate_citizen_overtime(citizen, "workplace"):
					workers_found = true
		if workers_found:
			selected_building.set_meta("night_work_order_day", day_cycle.current_day)
			_add_message("Night-work order issued for %s." % str(selected_building.get_meta("building_type", "workplace")).replace("_", " "))
			_update_workers()
			_update_skip_night_button()
			if citizen_ai != null:
				citizen_ai.request_decision_refresh()
		else:
			building_overtime_button.set_pressed_no_signal(false)
	else:
		for citizen in citizens:
			if is_instance_valid(citizen) and citizen.employment_workplace == selected_building:
				citizen.deactivate_overtime("workplace")
		_sync_overtime_scope_indicators()
		_add_message("Night work cancelled for %s." % str(selected_building.get_meta("building_type", "workplace")).replace("_", " "))
		_update_workers()
		_update_skip_night_button()
		if citizen_ai != null:
			citizen_ai.request_decision_refresh()


func _toggle_campfire_worker_overtime(checked: bool) -> void:
	if not is_instance_valid(selected_campfire):
		return
	selected_building = selected_campfire
	_toggle_worker_overtime(checked)
	_refresh_campfire_menu()
