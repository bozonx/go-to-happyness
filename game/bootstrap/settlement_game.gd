class_name SettlementGame
extends Node3D

const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

const S = preload("res://game/features/ui/domain/game_strings.gd")


const CELL_SIZE = SettlementConstants.CELL_SIZE
const BUILDING_CLEARANCE_BLOCKS = SettlementConstants.BUILDING_CLEARANCE_BLOCKS
const NAVIGATION_CLEARANCE_MARGIN = SettlementConstants.NAVIGATION_CLEARANCE_MARGIN
const MAX_BUILD_SLOPE = SettlementConstants.MAX_BUILD_SLOPE
const POPULATION = SettlementConstants.POPULATION
const FOOD_PURCHASE_PRICE = SettlementConstants.FOOD_PURCHASE_PRICE
const ENTRANCE_BUCKET_PRICE = SettlementConstants.ENTRANCE_BUCKET_PRICE
const ENTRANCE_WATER_PRICE = SettlementConstants.ENTRANCE_WATER_PRICE
const OUTSIDE_WORK_BASE_REWARD_MIN = SettlementConstants.OUTSIDE_WORK_BASE_REWARD_MIN
const OUTSIDE_WORK_BASE_REWARD_MAX = SettlementConstants.OUTSIDE_WORK_BASE_REWARD_MAX
const OUTSIDE_WORK_UPGRADE_REWARD = SettlementConstants.OUTSIDE_WORK_UPGRADE_REWARD
const HOUSE_CAPACITY = SettlementConstants.HOUSE_CAPACITY
const CONSTRUCTION_DURATION = SettlementConstants.CONSTRUCTION_DURATION
const DEMOLITION_DURATION = SettlementConstants.DEMOLITION_DURATION
const INTERACTION_RANGE = SettlementConstants.INTERACTION_RANGE
const POCKET_CAPACITY = SettlementConstants.POCKET_CAPACITY
const SAWMILL_PROCESS_DURATION = SettlementConstants.SAWMILL_PROCESS_DURATION

var settlement := SettlementState.new()
var world_resource_state := WorldResourceState.new()
var launch_config: GameLaunchConfig
## Supplied by core.world before the settlement module starts the scene.
var world_session: WorldSession = null
## Board size actually in play, always from the launched map.
var board_cells := 0
var day_cycle := SimulationDayCycle.new()
var clock: SimulationClock = day_cycle.clock
var game_minutes: float:
	get: return clock.minutes
	set(value): clock.minutes = value
const GAME_DAY_REAL_SECONDS = SettlementConstants.GAME_DAY_REAL_SECONDS
const GAME_MINUTES_PER_SECOND = SettlementConstants.GAME_MINUTES_PER_SECOND
var time_multiplier := 1.0
# The scheduler used to run only on discrete events, so a citizen who fell idle
# between events could stand doing nothing indefinitely. Poll it steadily during
# work hours so idle workers are promptly re-assigned or sent to wait/rest.
const WORKER_POLL_INTERVAL = SettlementConstants.WORKER_POLL_INTERVAL
# The main campfire progression (town hall) doubles as the employment centre:
# the employment officer must man it to register residents. The civic centre
# is always the main campfire or its town-hall upgrade.
const OFFICIAL_WORKPLACE_TYPES: Array[String] = SettlementConstants.OFFICIAL_WORKPLACE_TYPES
const OFFICER_POST_RADIUS = SettlementConstants.OFFICER_POST_RADIUS
const FIRE_SUPPLY_TARGET = SettlementConstants.FIRE_SUPPLY_TARGET
var worker_poll_timer := 0.0
var registration_queue_counter := 0
var last_unstaffed_warning_time := -1000.0
var runtime_seconds := 0.0
var random := RandomNumberGenerator.new()
var build_state := SettlementBuildState.new()
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
var world_state := SettlementWorldState.new()
var tree_cells: Dictionary[Vector2i, bool]:
	get: return world_state.tree_cells
var terrain_blocked_cells: Dictionary[Vector2i, bool]:
	get: return world_state.terrain_blocked_cells
	set(v): world_state.terrain_blocked_cells = v
var navigation_blocked_cells: Dictionary[Vector2i, bool]:
	get: return world_state.navigation_blocked_cells
	set(v): world_state.navigation_blocked_cells = v
var building_spatial_registry := BuildingSpatialRegistry.new()
var simulation_event_dispatcher: SimulationEventDispatcher
## Session-state of every authored map zone (active_zones.md §13): owner and
## flags per region/overlay. In-memory for now; a future block adds the
## `map_zones` save slot. Built by `SettlementBootstrapper._setup_zone_runtime`.
var map_zone_registry: MapZoneRegistry
## Stateless facade over `map_zone_registry`, the surface rules will call.
var map_zone_service: MapZoneService
## The presence index (cell → addressable areas) and the tracker that diffs
## citizen cells against it, publishing `area_entered`/`area_exited` on the bus.
## Fed by `guard_citizen_positions` every tick.
var zone_presence_index: ZonePresenceIndex
var zone_presence_tracker: ZonePresenceTracker
## One bus for every zone event (active_zones.md §14). Driven from outside by
## the tracker and the registry; holds no knowledge of who listens.
var zone_event_bus: ZoneEventBus
var ui_attacher := SettlementUIAttacher.new()

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
## Bank positions where a citizen can draw water (grid_terrain_system.md §9.2).
## Derived from the water layer, not from spawned scenery: there is one owner of
## "is there water here" and it is `WaterGrid`.
var water_source_positions: Array[Vector3]:
	get: return (world_setup as WorldSetup).water_access.source_positions() if world_setup != null else []
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
	get: return foraging_service.grass_sources
var forage_sources: Dictionary:
	get: return foraging_service.forage_sources
var rabbit_sources: Dictionary:
	get: return foraging_service.rabbit_sources
const RABBIT_MAX_COUNT = SettlementConstants.RABBIT_MAX_COUNT
var outside_workers: Dictionary:
	get: return world_state.outside_workers
var last_citizen_positions: Dictionary:
	get: return world_state.last_citizen_positions
var last_citizen_cells: Dictionary:
	get: return world_state.last_citizen_cells
var resource_piles: Array[ResourcePile]:
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
	get: return camera_controller.camera
## Declared in settlement_game.tscn, not built here: it is a fixed, single-instance
## part of the main scene, so the scene owns it (architecture rule 7).
@onready var camera_controller: CameraController = $CameraController
var world_setup: Node
var selection_marker: MeshInstance3D:
	get: return world_setup.selection_marker
var fireflies: Array[FirefliesEffect]:
	get: return world_setup.fireflies
## Whether anything is falling right now, as of the last tick. Cached only so the
## "rain has started/stopped" message can notice the edge; every other weather
## question goes to `simulation_tick_controller.environment()`
## (`world_environment.md` §2).
var is_precipitating := false
var ambient_spawner: AmbientSpawner
var camera_target: Vector3:
	get: return camera_controller.camera_target
	set(val): camera_controller.camera_target = val
var camera_distance: float:
	get: return camera_controller.camera_distance
	set(val): camera_controller.camera_distance = val
var camera_yaw: float:
	get: return camera_controller.camera_yaw
	set(val): camera_controller.camera_yaw = val
var camera_pitch: float:
	get: return camera_controller.camera_pitch
	set(val): camera_controller.camera_pitch = val
var current_day: int:
	get: return day_cycle.current_day
var tent_weather: int = TentEraSurvivalRules.Weather.WARMING
var selected_builder: Citizen:
	get: return build_state.selected_builder
	set(v): build_state.selected_builder = v
var selected_building: Node3D:
	get: return build_state.selected_building
	set(v): build_state.selected_building = v
var camera_state := SettlementCameraState.new()
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
	get: return construction.sites
var demolition_sites: Array[DemolitionSite]:
	get: return demolition.sites
var completed_house_count := 0
var player_controller: PlayerController
var hero_state := SettlementHeroState.new()
var hero_citizen: Citizen:
	get: return hero_state.hero_citizen
	set(v): hero_state.hero_citizen = v

var is_first_person: bool:
	get: return player_controller.is_first_person
	set(val):
		player_controller.is_first_person = val
var player_citizen: Citizen:
	get: return player_controller.player_citizen
	set(val):
		player_controller.player_citizen = val
var player_yaw: float:
	get: return player_controller.player_yaw
	set(val):
		player_controller.player_yaw = val
var player_pitch: float:
	get: return player_controller.player_pitch
	set(val):
		player_controller.player_pitch = val
var interaction_action: String:
	get: return player_controller.interaction_action
	set(val):
		player_controller.interaction_action = val
var interaction_resource: String:
	get: return player_controller.interaction_resource
	set(val):
		player_controller.interaction_resource = val
var interaction_time: float:
	get: return player_controller.interaction_time
	set(val):
		player_controller.interaction_time = val
var interaction_start_cell: Vector2i:
	get: return player_controller.interaction_start_cell
	set(val):
		player_controller.interaction_start_cell = val
var interaction_repeat_all: bool:
	get: return player_controller.interaction_repeat_all
	set(val):
		player_controller.interaction_repeat_all = val
var player_work_target: Node3D:
	get: return player_controller.player_work_target
	set(val):
		player_controller.player_work_target = val
var player_toilet_notified: bool:
	get: return player_controller.player_toilet_notified
	set(val):
		player_controller.player_toilet_notified = val
var pocket: Dictionary:
	get: return hero_pocket_service.pocket
	set(val): hero_pocket_service.pocket = val
## Declared in settlement_game.tscn, not built here: it is a fixed, single-instance
## part of the main scene, so the scene owns it (architecture rule 7).
@onready var ui_manager: UIManager = $UIManager

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
var excavation_service: ExcavationService
var factory_service: FactoryService
var selected_house: Node3D
var tent: Node3D
var entrance_stone: Node3D
var selected_entrance: Node3D
var logistics_runtime := SettlementLogisticsRuntimeState.new()
var canteen: Node3D
var canteen_position := Vector3.ZERO
var employment_office: Node3D
var employment_office_position := Vector3.ZERO
var canteen_food := 0
var pending_canteen_delivery := false
var pending_canteen_carrier: Citizen
var pending_canteen_delivery_amount := 0
var nav_grid: NavGrid
var road_network_service: RoadNetworkService
var navigation_obstacle_publisher: NavigationObstaclePublisher
var service_pockets: Array[ServicePocketRecord] = []
var selected_school: Node3D
var school_developed_professions: Dictionary:
	get: return school_service.developed_professions
var selected_materials_factory: Node3D
var campfire_node: Node3D = null
var selected_campfire: Node3D = null
var selected_market: Node3D = null
var selected_warehouse: Node3D = null
var event_service: EventService
var survival_busy_until: Dictionary = {}
var house_lights: Array[HouseLightRecord] = []
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
	get: return ui_manager.time_controls_panel.skip_night_button
var start_workday_button: Button:
	get: return ui_manager.time_controls_panel.start_workday_button
var water_collectors: Array[WaterCollectorRecord] = []
var water_access_service: WaterAccessService
var building_status_indicators: Array[Label3D] = []
var building_status_update_time := 0.0
var workplace_priority_counter := 0
var citizen_ai: CitizenAISystem
var citizen_needs_service: CitizenNeedsService
var citizen_living_status_service: CitizenLivingStatusService
## Monotonic source of stable citizen AI identity. Persist it alongside the roster
## once save/load is introduced so reloaded games issue non-colliding ids.
var next_ai_citizen_id := 1
var route_service: GridRouteService
var navigation_facade: NavigationFacade
var navigation_bridge: NavigationBridge
var building_queue_service: BuildingQueueService
var citizen_lifecycle_service: CitizenLifecycleService
var building_availability_service: BuildingAvailabilityService
var building_research_service: BuildingResearchService
var village_territory_service: VillageTerritoryService
## Writes `IS_ANCHOR` under placed footprints, so the cascade refuses to move the
## ground a building stands on (grid_terrain_system.md §4.4).
var terrain_anchor_service: TerrainAnchorService
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
var campfire_menu_controller: CampfireMenuController:
	get: return ui_attacher.campfire_menu_controller
var workforce_menu_controller: WorkforceMenuController:
	get: return ui_attacher.workforce_menu_controller
var research_menu_controller: ResearchMenuController:
	get: return ui_attacher.research_menu_controller
var school_menu_controller: SchoolMenuController:
	get: return ui_attacher.school_menu_controller
var entrance_menu_controller: EntranceMenuController:
	get: return ui_attacher.entrance_menu_controller
var house_menu_controller: HouseMenuController:
	get: return ui_attacher.house_menu_controller
var pocket_take_menu_controller: PocketTakeMenuController:
	get: return ui_attacher.pocket_take_menu_controller
var market_menu_controller: MarketMenuController:
	get: return ui_attacher.market_menu_controller
var warehouse_menu_controller: WarehouseMenuController:
	get: return ui_attacher.warehouse_menu_controller
var warehouse_fill_label_controller: WarehouseFillLabelController
var building_menu_controller: BuildingMenuController:
	get: return ui_attacher.building_menu_controller
var building_placement_controller: BuildingPlacementController

var building_status_indicator_controller: BuildingStatusIndicatorController
var first_person_hud_controller: FirstPersonHUDController
var label_distance_fade_controller: LabelDistanceFadeController
var trail_field: TrailFieldService
## Wear and regrowth of the ground itself (`terrain_materials.md` §6.1, §6.4).
var surface_controller: SettlementSurfaceController
var trail_texture_renderer: TrailTextureRenderer
var resource_pile_service: ResourcePileService
var foraging_service: ForagingService
var fire_management_service: FireManagementService
var fixture_service: FixtureService
var building_maintenance_service: BuildingMaintenanceService
var building_lifecycle_service: BuildingLifecycleService
var building_zone_service: BuildingZoneService
var construction_priority_service: ConstructionPriorityService
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
var actuator_bridge: SettlementActuatorBridge
var survival_event_controller: SurvivalEventController
var research_controller: SettlementResearchController
var citizen_factory: SettlementCitizenFactory
var building_visuals: SettlementBuildingVisuals
var simulation_handlers: SettlementSimulationHandlers
var service_pocket_manager: SettlementServicePocketManager
var outside_work_controller: SettlementOutsideWorkController
var building_management: SettlementBuildingManagement
var input_controller: SettlementInputController
var selection_controller: SettlementSelectionController
var port_factory: SettlementPortFactory
var query_helper: SettlementQueryHelper
var build_controller: SettlementBuildController
var hero_interaction_controller: SettlementHeroInteractionController
var construction_controller: SettlementConstructionController
var workplace_controller: SettlementWorkplaceController
var simulation_tick_controller: SettlementSimulationTickController
var logistics_controller: SettlementLogisticsController
var world_navigation_controller: SettlementWorldNavigationController


## Module-owned session boundary. SettlementGame is not an independently
## launchable scene: the host runtime resolves a definition and map first.
func start_session(active_config: GameLaunchConfig) -> void:
	if active_config == null:
		push_error("[launch] SettlementGame requires module launch configuration")
		return
	launch_config = active_config
	if launch_config.map_document == null:
		push_error("[launch] SettlementGame requires a resolved map document")
		return
	var map_errors := MapValidator.validate(
		launch_config.map_document,
		launch_config.map_document.terrain,
		launch_config.map_document.water,
		null
	)
	map_errors.append_array(MapValidator.validate_party_capacity(
		launch_config.map_document, launch_config.start_option, POPULATION,
		launch_config.has_spawn_override()))
	if not map_errors.is_empty():
		push_error("[launch] Invalid map: %s" % "; ".join(map_errors))
		return
	board_cells = launch_config.board_cells()
	SettlementBootstrapper.new().run(self)
	if ui_manager != null and ui_manager.build_menu != null:
		ui_manager.build_menu.apply_era_names(launch_config.era_names)
func next_registration_ticket() -> int:
	return citizen_registration_service.next_registration_ticket() if citizen_registration_service != null else 0


func _input(event: InputEvent) -> void:
	input_controller.handle_input(event)


func _unhandled_input(event: InputEvent) -> void:
	input_controller.handle_unhandled_input(event)


func _process(delta: float) -> void:
	runtime_seconds += delta
	if foraging_service != null:
		foraging_service.runtime_seconds = runtime_seconds
	if citizen_needs_service != null:
		citizen_needs_service.tick(game_minutes)
		hero_interaction_controller.check_player_toilet_request()
	if is_first_person:
		player_controller.update_player_control(delta)
		player_controller.update_interaction(delta)
		hero_interaction_controller.refresh_interaction_hint()
		input_controller.update_first_person_mouse_and_crosshair()
		if warehouse_fill_label_controller != null:
			warehouse_fill_label_controller.update_warehouse_fill_labels()
		if not build_mode.is_empty():
			var viewport_center := get_viewport().get_visible_rect().size * 0.5
			var terrain_point: Variant = query_helper.terrain_point_at_screen_position(viewport_center)
			if terrain_point != null:
				build_controller.move_selection(terrain_point)
				world_setup.selection_marker.visible = true
			else:
				world_setup.selection_marker.visible = false
				world_setup.preview_entrance_marker.visible = false
				world_setup.preview_back_entrance_marker.visible = false
	else:
		if camera_controller != null:
			camera_controller.update(delta)
	simulation_tick_controller.tick(delta)


func _exit_tree() -> void:
	# Time scaling is process-global. Never let a closed settlement scene affect
	# menus, tests, or a subsequently loaded scene.
	Engine.time_scale = 1.0


func update_workers() -> void:
	if building_zone_service != null:
		building_zone_service.reconcile_assignments(citizens, building_registry.records())
	simulation_tick_controller.check_unstaffed_employment_center()


func has_cook() -> bool:
	return workplace_labor_service.has_cook() if workplace_labor_service != null else false


func employment_center_position() -> Vector3:
	return workplace_labor_service.employment_center_position() if workplace_labor_service != null else Vector3.INF


func employment_centre_building() -> Node3D:
	return workplace_labor_service.employment_centre_building() if workplace_labor_service != null else null


func can_start_registration(citizen: Citizen) -> bool:
	return citizen_registration_service.can_start_registration(citizen) if citizen_registration_service != null else false


func _registration_official() -> Citizen:
	return citizen_registration_service.registration_official() if citizen_registration_service != null else null


func registration_duration() -> float:
	return citizen_registration_service.registration_duration() if citizen_registration_service != null else Citizen.EMPLOYMENT_PROCESS_DURATION


func on_employment_processing_finished(citizen: Citizen) -> void:
	if citizen_registration_service != null:
		citizen_registration_service.on_employment_processing_finished(citizen)
	else:
		if not simulation_tick_controller.is_work_time():
			citizen.state = Citizen.State.IDLE
			return
		citizen.finish_employment_processing()
		update_workers()

func publish_courier_tasks(dispatcher: CourierDispatcher) -> void:
	if courier_task_publisher != null:
		courier_task_publisher.publish_courier_tasks(dispatcher)


func set_dig_mode(value: bool) -> void:
	dig_mode = value


func set_build_mode(value: String) -> void:
	build_mode = value


func sawmill_stock(position_on_board: Vector3) -> Dictionary:
	return sawmills.stock_at(position_on_board, runtime_seconds)

func request_courier_dispatch() -> void:
	if simulation_tick_controller.is_work_time() or has_active_night_work_order():
		if courier_dispatcher != null:
			courier_dispatcher.dispatch()
		if citizen_ai != null:
			citizen_ai.request_decision_refresh()


func stored_resources() -> int:
	return storage_routing_service.stored_resources()

func warehouse_capacity() -> int:
	return storage_routing_service.warehouse_capacity()

func cell_from_position(position_on_board: Vector3) -> Vector2i:
	return nav_grid.cell_from_position(position_on_board) if nav_grid != null else Vector2i(floori(position_on_board.x / CELL_SIZE), floori(position_on_board.z / CELL_SIZE))

func is_board_cell(cell: Vector2i) -> bool:
	if nav_grid != null:
		return nav_grid.is_board_cell(cell)
	var half_cells := board_cells / 2
	return cell.x >= -half_cells and cell.x < half_cells and cell.y >= -half_cells and cell.y < half_cells

func find_path_around_houses(from: Vector3, destination: Vector3, may_enter_destination_house: bool) -> RouteResult:
	if navigation_bridge != null:
		return navigation_bridge.find_path_around_houses(from, destination, may_enter_destination_house)
	return RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)


func find_recovery_path(from: Vector3, destination: Vector3, may_enter_destination_house: bool) -> RouteResult:
	return navigation_bridge.find_recovery_path(from, destination, may_enter_destination_house) if navigation_bridge != null else RouteResult.unreachable(-1, -1, RouteResult.UnreachableReason.NO_GRID)


func movement_speed_modifier_at(position_on_board: Vector3) -> float:
	return navigation_facade.movement_speed_modifier_at(position_on_board) if navigation_facade != null else 1.0


func navigation_revision() -> int:
	return navigation_facade.topology_revision() if navigation_facade != null else -1


func is_route_reachable(from: Vector3, destination: Vector3, may_enter_destination_house := false) -> bool:
	return navigation_bridge.is_route_reachable(from, destination, may_enter_destination_house) if navigation_bridge != null else false


func is_route_path_clear(from: Vector3, waypoints: Array[Vector3], may_enter_destination_house := false) -> bool:
	return nav_grid != null and nav_grid.is_waypoint_path_clear(from, waypoints, may_enter_destination_house)

func update_interface(message: String) -> void:
	var lines: Array[String] = []
	lines.append("Era: %s" % workplace_controller.era_name())
	lines.append("Money: %d" % settlement.money)
	var displayed_resources := settlement.era_resources()
	for resource_type in displayed_resources:
		lines.append("%s: %d" % [resource_display_name(resource_type), settlement.amount(resource_type)])
	if settlement.uses_virtual_storage():
		var backpack_units := 0.0
		for resource_type in displayed_resources:
			backpack_units += settlement.backpack_amount(resource_type) * settlement.storage_weight(resource_type)
		lines.append("Backpack: %.1f u" % backpack_units)
	else:
		lines.append("Storage: %d/%d" % [stored_resources(), warehouse_capacity()])
	if not resource_piles.is_empty():
		lines.append("Piles: %d" % resource_piles.size())
	lines.append("Population: %d" % citizens.size())
	lines.append("Wellbeing: %d" % settlement.wellbeing)
	ui_manager.hud.update_resources("\n".join(lines))
	add_message(message)
	if is_first_person:
		var build_hint := S.HUD_BUILD_HINT_FP if player_citizen == hero_citizen else ""
		if not build_mode.is_empty():
			build_hint += S.HUD_BUILD_ROTATE_HINT
		ui_manager.hud.update_camera_hint(S.HUD_FIRST_PERSON_HINT % build_hint)
	else:
		ui_manager.hud.update_camera_hint(S.HUD_OVERVIEW_HINT)

const ERA_CATEGORIES = SettlementConstants.ERA_CATEGORIES

func resource_display_name(resource_type: String) -> String:
	match resource_type:
		ResourceIds.WOOD: return "Timber"
		_: return resource_type.capitalize()


# ---------- Message log system ------------------------------------------------

func add_message(text: String) -> void:
	if ui_manager.message_log_panel != null:
		var timestamp := "[Day %d, %02d:%02d]" % [current_day, clock.hour(), clock.minute()]
		ui_manager.message_log_panel.add_message(text, timestamp)


# ---------- End message log system --------------------------------------------

func create_world() -> void:
	world_navigation_controller.create_world()


## Presentation ownership boundary for naturally occurring world objects.
## Their mutable gameplay records remain registered with the relevant feature
## services; reparenting them here must not change routing or resource logic.
func add_citizen(spawn_position: Vector3, primary_specialization := "") -> void:
	citizen_factory.add_citizen(spawn_position, primary_specialization)


## Attaches navigation, the registration service and every gameplay signal to a
## citizen. The caller must already have added the node to the tree, set
## `simulation` and chosen the specialization. Shared by initial spawning and
## save restore so a new signal only needs to be registered in one place.
func player_use_toilet(toilet_node: Node3D) -> void:
	if not is_first_person or player_citizen == null or not is_instance_valid(toilet_node):
		return
	if player_citizen.player_using_toilet:
		return
	player_citizen.begin_player_toilet_use(toilet_node)
	interaction_action = "toilet"
	interaction_time = 0.0
	ui_manager.interaction_hint_panel.progress_bar.visible = true
	ui_manager.interaction_hint_panel.hint_label.text = S.USING_TOILET
	update_interface(S.TOILET_IN_USE)


func set_workday_hours(hours: int) -> void:
	if hours not in [6, 8, 10, 12, 14]:
		return
	settlement.pending_workday_hours = hours
	if survival_event_controller != null:
		survival_event_controller.update_skip_night_button()
	update_interface("Workday set to %d hours for the next shift." % hours)


func apply_pending_workday_hours() -> void:
	if settlement.pending_workday_hours <= 0:
		return
	settlement.workday_hours = settlement.pending_workday_hours
	settlement.pending_workday_hours = 0

func has_active_night_work_order() -> bool:
	for citizen in citizens:
		if is_instance_valid(citizen) and citizen.has_active_overtime(day_cycle.current_day):
			return true
	return false


func release_unassigned_overtime_workers() -> void:
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

func set_time_multiplier(multiplier: float) -> void:
	time_multiplier = multiplier
	if is_first_person:
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = multiplier
	update_interface("Simulation speed set to x%d." % int(multiplier))


func finish_demolition(site: DemolitionSite) -> void:
	var building_id := String(site.building.get_meta("building_instance_id", "")) if is_instance_valid(site.building) else ""
	building_lifecycle_service.finish_demolition(site)
	if fixture_service != null and not building_id.is_empty():
		fixture_service.remove_building(building_id)

func nearby_warehouse_index() -> int:
	return storage_routing_service.nearby_warehouse_index()

func rotated_footprint(footprint: Vector2i, rotation_quarters := build_rotation_quarters) -> Vector2i:
	return building_placement_controller.rotated_footprint(footprint, rotation_quarters) if building_placement_controller != null else footprint

func can_hero_build() -> bool:
	return building_placement_controller.can_hero_build() if building_placement_controller != null else false

func terrain_height_at(x: float, z: float, near_y: float) -> float:
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

func is_clear_of_objects(world_position: Vector3, minimum_distance: float) -> bool:
	return building_placement_controller.is_clear_of_objects(world_position, minimum_distance) if building_placement_controller != null else false

func placement_key(world_position: Vector3) -> Vector2i:
	return building_placement_controller.placement_key(world_position) if building_placement_controller != null else Vector2i.ZERO

func grant_debug_resources() -> void:
	if not settlement.warehouse_ever_built:
		update_interface("Resources can only be added after the first warehouse is built.")
		return
	var result := settlement.fill_least_warehouse_cheat(90.0)
	settlement.money += 30
	if not result.filled:
		update_interface(S.NO_WAREHOUSE_BELOW_90)
	elif not result.overflow.is_empty() and not warehouse_positions.is_empty():
		resource_pile_service.drop_overflow_as_piles(result.overflow, warehouse_positions[0])
		update_interface("Debug resources added. Some overflow dropped near the warehouse.")
	else:
		update_interface("Debug resources added to the least stocked warehouse.")
	update_workers()
	request_courier_dispatch()

func on_tree_harvested(worker: Citizen, position_on_board: Vector3) -> void:
	fell_tree_at(position_on_board)

func fell_tree_at(position_on_board: Vector3) -> void:
	world_navigation_controller.fell_tree_at(position_on_board)


## Lays a tree down and frees the cell it occupied. Shared by live felling and
## save restore so both paths produce identical geometry and navigation state.
func apply_building_wear_and_repairs() -> void:
	building_maintenance_service.apply_building_wear_and_repairs(_destroy_building_to_pile)


func _destroy_building_to_pile(building: Node3D, building_type: String) -> void:
	var building_id := String(building.get_meta("building_instance_id", "")) if is_instance_valid(building) else ""
	building_maintenance_service.destroy_building_to_pile(building, building_type, citizens, warehouse_positions, campfire_node)
	if fixture_service != null and not building_id.is_empty():
		fixture_service.remove_building(building_id)


func convert_backpack_pile_to_regular() -> void:
	backpack_node = resource_pile_service.convert_backpack_pile_to_regular(backpack_node)

func warehouse_delivery_position(from: Vector3, resource_type: String, amount: int) -> Vector3:
	return storage_routing_service.warehouse_delivery_position(from, resource_type, amount)


func get_toilets() -> Array[Node3D]:
	var toilets: Array[Node3D] = []
	for record in building_registry.records():
		if is_instance_valid(record.node):
			var b_type: String = record.building_type
			if b_type.begins_with("toilet_"):
				toilets.append(record.node)
	return toilets


## Save and restore belong to `SettlementGameModule`: it owns the section, its
## version and its migration. This scene is the module's presentation adapter and
## must not grow a second entry point into the save file.
