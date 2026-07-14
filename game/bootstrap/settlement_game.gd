extends Node3D

const SETTLEMENT_RULES = preload("res://game/features/settlement/domain/settlement_rules.gd")
const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")
const FireSourceStateScript = preload("res://game/features/settlement/domain/fire_source_state.gd")
const CourierDispatcherScript = preload("res://game/features/logistics/application/courier_dispatcher.gd")
const CourierTaskScript = preload("res://game/features/logistics/domain/courier_task.gd")
const TradeServiceScript = preload("res://game/features/logistics/application/trade_service.gd")
const StorageDeliveryServiceScript = preload("res://game/features/logistics/application/storage_delivery_service.gd")
const BuildingAvailabilityServiceScript = preload("res://game/features/buildings/application/building_availability_service.gd")
const BuildingResearchServiceScript = preload("res://game/features/buildings/application/building_research_service.gd")
const BuildingQueueServiceScript = preload("res://game/features/citizens/application/building_queue_service.gd")
const CitizenLivingStatusServiceScript = preload("res://game/features/citizens/application/citizen_living_status_service.gd")
const SleepGoalScript = preload("res://game/features/decision/domain/goals/sleep_goal.gd")
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
const RouteRequestScript = preload("res://game/features/routing/application/route_request.gd")
const TrailFieldServiceScript = preload("res://game/features/roads/application/trail_field_service.gd")
const TrailOverlayShader = preload("res://game/features/roads/presentation/trail_overlay.gdshader")


const BOARD_CELLS := 48
const CELL_SIZE := BuildingBlueprints.BLOCK_SIZE
const BUILDING_CLEARANCE_BLOCKS := 3.0
const TREE_BUILD_CLEARANCE_BLOCKS := 1.0
const NAVIGATION_CLEARANCE_MARGIN := 1.0
const SERVICE_PAD_OFFSET := 1.0
const MAX_BUILD_SLOPE := 0.35
const BRICK_RESEARCH_DURATION := 20.0
const POPULATION := 4
const WAREHOUSE_CAPACITY := 50
const FOOD_PURCHASE_PRICE := 2
const ENTRANCE_GLOVE_PRICE := 20
const OUTSIDE_WORK_DURATION_MINUTES := SimulationClock.MINUTES_PER_DAY
const OUTSIDE_WORK_REWARD := 8
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
const POCKET_WOOD_CAPACITY := 8
# The hero gathers raw bootstrap materials in a batch per action, unlike NPCs who
# fetch one-to-two at a time. This is the player's lever to force a direction:
# playing the hero rushes what the officer's plan would otherwise trickle in.
const HERO_GATHER_YIELD := 3
const SAWMILL_PROCESS_DURATION := 4.0
const SAWMILL_WORKER_DELIVERY_THRESHOLD := 4
const COURIER_LATE_SECONDS := 12.0
const DIG_RADIUS := 2.2
const DIG_REACH := 6.0

var settlement := SettlementState.new()
var wood: int:
	get: return settlement.wood
	set(value): settlement.wood = value
var food: int:
	get: return settlement.food
	set(value): settlement.food = value
var soil: int:
	get: return settlement.soil
	set(value): settlement.soil = value
var clay: int:
	get: return settlement.clay
	set(value): settlement.clay = value
var boards: int:
	get: return settlement.boards
	set(value): settlement.boards = value
var bricks: int:
	get: return settlement.bricks
	set(value): settlement.bricks = value
var stone: int:
	get: return settlement.stone
	set(value): settlement.stone = value
var branches: int:
	get: return settlement.branches
	set(value): settlement.branches = value
var grass: int:
	get: return settlement.grass
	set(value): settlement.grass = value
var water: int:
	get: return settlement.water
	set(value): settlement.water = value
var money: int:
	get: return settlement.money
	set(value): settlement.money = value
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
var brick_construction_unlocked: bool:
	get: return settlement.brick_construction_unlocked
	set(value): settlement.brick_construction_unlocked = value
var brick_research_progress := -1.0
var brick_research_factory: Node3D
var tree_positions: Array[Vector3] = []
var tree_nodes: Dictionary = {}
var citizens: Array[Citizen] = []
var camera: Camera3D
var sun: DirectionalLight3D
var world_environment: Environment
var camera_target := Vector3.ZERO
var camera_distance := 30.0
var camera_yaw := 42.0
var camera_pitch := 52.0
var selection_marker: MeshInstance3D
var selection_material: StandardMaterial3D
var preview_entrance_marker: MeshInstance3D
var preview_back_entrance_marker: MeshInstance3D
var wood_label: Label
var status_label: Label
var labor_authority_label: Label
var messages: Array[Dictionary] = []
var current_day: int:
	get: return day_cycle.current_day
var tent_weather: int = TentEraSurvivalRulesScript.Weather.WARMING
var last_survival_hour := -1
var recovery_arrival_at_minutes := -1.0
var message_scroll: ScrollContainer
var message_list: VBoxContainer
var messages_modal: Panel
var modal_message_list: VBoxContainer
var selected_builder: Citizen
var selected_building: Node3D
var build_menu: Panel
var build_menu_title: Label
var camera_hint_label: Label
var is_panning_camera := false
var is_rotating_camera := false
var right_mouse_dragged := false
var construction_sites: Array[ConstructionSite]:
	get: return construction.sites if construction != null else []
var demolition_sites: Array[DemolitionSite]:
	get: return demolition.sites if demolition != null else []
var completed_house_count := 0
var player_citizen: Citizen
var hero_citizen: Citizen
var is_first_person := false
var player_yaw := 0.0
var player_pitch := -8.0
var pocket_wood := 0
var pocket_food := 0
var pocket_boards := 0
var pocket_water := 0
var interaction_time := 0.0
var interaction_action := ""
var interaction_resource := ""
var player_work_target: Node3D
var interaction_hint_label: Label
var interaction_progress: ProgressBar
var dig_sites: Array[Dictionary] = []
var dig_cells: Dictionary = {}
var exhausted_dig_cells: Dictionary = {}
var dig_mode := false
var house_menu: Panel
var house_menu_title: Label
var house_spawn_button: Button
var selected_house: Node3D
var tent: Node3D
var entrance_stone: Node3D
var selected_entrance: Node3D
var entrance_menu: Panel
var entrance_menu_title: Label
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
var clock_label: Label
var tent_dismantle_progress := -1.0
var voxel_terrain: VoxelLodTerrain
var voxel_tool: VoxelTool
var nav_grid: NavGrid
var _route_reachability_cache: Dictionary = {}
var _route_reachability_cache_revision := -1
const ROUTE_REACHABILITY_CACHE_LIMIT := 1024
var service_pockets: Array[Dictionary] = []
var selected_school: Node3D
var school_menu: Panel
var school_menu_title: Label
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
var school_retrain_buttons: Array[Button] = []
var school_dev_checkboxes: Dictionary = {}
var materials_factory_menu: Panel
var materials_factory_menu_title: Label
var selected_materials_factory: Node3D
var campfire_node: Node3D = null
var selected_campfire: Node3D = null
var campfire_menu: Panel
var campfire_menu_title: Label
var campfire_requirements_label: Label
var campfire_upgrade_button: Button
var campfire_advance_button: Button
var campfire_orders_button: Button
var campfire_occupancy_button: Button
var campfire_official_button: Button
var campfire_accept_button: Button
var campfire_dismiss_button: Button
var workforce_menu: Panel
var workforce_menu_title: Label
var workforce_list: VBoxContainer
var research_menu: Panel
var research_menu_title: Label
var research_list: VBoxContainer
var selected_market: Node3D = null
var market_menu: Panel
var market_menu_title: Label
var selected_warehouse: Node3D = null
var warehouse_menu: Panel
var warehouse_menu_title: Label
var building_menu: Panel
var building_menu_title: Label
var building_cook_button: Button
var building_teacher_button: Button
var building_seller_button: Button
var building_official_button: Button
var building_accept_workers_button: Button
var building_dismiss_worker_button: Button
var building_upgrade_button: Button
var building_close_button: Button
var building_overtime_button: Button
var building_relight_button: Button
var campfire_overtime_button: Button
var campfire_close_btn: Button
var building_cancel_construction_button: Button
var decision_menu: Panel
var decision_title: Label
var decision_description: Label
var decision_primary_button: Button
var decision_secondary_button: Button
var pending_survival_decision := ""
var survival_busy_until: Dictionary = {}
var protected_firewood_day := -1
var smoky_firewood_day := -1
var job_submenu_btn: Button
var daily_order_submenu_btn: Button
var job_back_btn: Button
var house_lights: Array[Dictionary] = []
var house_light_update_minute := -1
var entrance_lights: Array[OmniLight3D] = []
var build_category := ""
var build_menu_is_job_menu := false
var build_menu_is_daily_order_menu := false
var build_buttons: Array[Button] = []
var build_item_buttons: Array[Button] = []
var skip_night_button: Button
var start_workday_button: Button
var water_collectors: Array[Dictionary] = []
var pending_trades: Dictionary = {} # worker instance id -> TradeOrder
var queued_trades: Array = []
var role_buttons: Array[Button] = []
var building_status_indicators: Array[Label3D] = []
var building_status_update_time := 0.0
var workplace_priority_counter := 0
var manage_citizen_button: Button
var citizen_ai: CitizenAISystem
var citizen_needs_service: CitizenNeedsService
var citizen_living_status_service: RefCounted
## Monotonic source of stable citizen AI identity. Persist it alongside the roster
## once save/load is introduced so reloaded games issue non-colliding ids.
var _next_ai_citizen_id := 1
var route_service: GridRouteService
var building_queue_service: RefCounted
var building_availability_service: RefCounted
var building_research_service: RefCounted
var sawmills: SawmillService
var construction: ConstructionService
var demolition: DemolitionService
var water_collector_service: WaterCollectorService
var canteen_service: CanteenService
var trade_service: TradeService
var storage_delivery_service: RefCounted
var courier_dispatcher: RefCounted
var trail_field: TrailFieldService
var trail_overlay: MeshInstance3D
var trail_overlay_material: ShaderMaterial
var campfire_orders_menu: Panel
var campfire_orders_toggle: CheckButton


func _ready() -> void:
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
	building_availability_service = BuildingAvailabilityServiceScript.new()
	building_availability_service.configure(settlement)
	building_research_service = BuildingResearchServiceScript.new()
	building_research_service.configure(settlement)
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
	citizen_needs_service = CitizenNeedsService.new()
	citizen_needs_service.configure(self)
	citizen_living_status_service = CitizenLivingStatusServiceScript.new()
	trade_service = TradeServiceScript.new()
	trade_service.configure(self)
	storage_delivery_service = StorageDeliveryServiceScript.new()
	storage_delivery_service.configure(self)
	courier_dispatcher = CourierDispatcherScript.new()
	courier_dispatcher.configure(self)
	settlement.apply_tent_start()
	tent_weather = TentEraSurvivalRulesScript.weather_for_day(day_cycle.current_day)
	_create_world()
	_create_interface()
	_create_forest()
	_spawn_initial_rabbits()
	_create_ponds()
	_create_entrance_stone()
	_create_citizens()
	_refresh_living_statuses()
	if not citizen_ai.configure(
		SettlementAIWorldFacade.new(self),
		[SleepGoalScript.new(), MealGoalScript.new(), ToiletGoalScript.new(), RestGoalScript.new(), RegisterGoalScript.new(), ForestryGoalScript.new(), FarmingGoalScript.new(), ConstructionGoalScript.new(), GatheringGoalScript.new(), ExcavationGoalScript.new(), ServiceWorkGoalScript.new(), FactoryWorkGoalScript.new(), CourierDeliveryGoalScript.new()],
		[WorkforceOrderProviderScript.new(), DailyPlayerOrderProviderScript.new(), ForestryOrderProviderScript.new(), FarmingOrderProviderScript.new(), ConstructionOrderProviderScript.new(), GatheringOrderProviderScript.new(), ExcavationOrderProviderScript.new(), ServiceWorkOrderProviderScript.new(), FactoryWorkOrderProviderScript.new(), CourierDeliveryOrderProviderScript.new()]
	):
		push_error("Native citizen AI failed to capture its initial world snapshot")

	settlement.ensure_storage_defaults(warehouse_positions.size())
	_update_workers()
	_update_interface("Build a simple store, then gather materials for the first campfire and tents.")
	_enter_first_person(hero_citizen, "Hero view enabled.")

func _process(delta: float) -> void:
	runtime_seconds += delta
	if citizen_needs_service != null:
		citizen_needs_service.tick(game_minutes)
	if is_first_person:
		_update_player_control(delta)
		_update_interaction(delta)
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
	_update_survival_busy_workers()
	_return_outside_workers()
	_update_wild_food(delta)
	_guard_citizen_positions()
	_update_trail_overlay()
	_update_daylight()
	_update_house_lights()
	_update_canteen_delivery()
	_update_arrivals()
	_update_fire_status()
	_update_recovery_arrival()
	_update_repairs()
	trade_service.update()
	_dispatch_queued_trades()
	_update_sawmills(delta)
	_update_brick_research(delta)
	_update_building_research(delta)
	_update_building_status_indicators(delta)
	if _is_work_time():
		_update_couriers()
		_worker_poll_timer -= delta
		if _worker_poll_timer <= 0.0:
			_worker_poll_timer = WORKER_POLL_INTERVAL
			_update_workers()
	if selected_builder != null and build_menu.visible:
		_show_selected_citizen_menu()

func _update_workers() -> void:
	if _is_work_time():
		for citizen in citizens:
			if is_instance_valid(citizen):
				citizen.overtime_mode = false
	_check_unstaffed_employment_center()
	_refresh_labor_authority_indicator()


func daily_order_workday_for_new_order() -> int:
	if _is_work_time() or clock.hour() < 8:
		return day_cycle.current_day
	return day_cycle.current_day + 1


func daily_order_expiration_for_workday(workday_id: int) -> float:
	var end_minute := (workday_id - 1) * SimulationClock.MINUTES_PER_DAY + (8 + settlement.workday_hours) * 60
	var remaining_minutes := maxi(0, end_minute - _absolute_game_minutes())
	return runtime_seconds + float(remaining_minutes) / GAME_MINUTES_PER_SECOND


func is_daily_order_active(citizen: Citizen) -> bool:
	return (
		is_instance_valid(citizen)
		and citizen.daily_order_workday_id == day_cycle.current_day
		and _is_work_time()
	)


func _assign_daily_order(citizen: Citizen, role: String) -> void:
	if not is_instance_valid(citizen) or citizen.is_player_controlled:
		return
	var workday_id := daily_order_workday_for_new_order()
	citizen.assign_daily_order(role, workday_id, daily_order_expiration_for_workday(workday_id))


func _clear_daily_orders(workday_id := 0) -> void:
	var changed := false
	for citizen in citizens:
		if not is_instance_valid(citizen):
			continue
		if citizen.has_daily_order():
			citizen.clear_daily_order(workday_id)
			changed = true
	if changed and citizen_ai != null:
		citizen_ai.request_decision_refresh()

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
	return citizen.permanent_role

func _factory_for_role(role: String) -> Node3D:
	return _employer_for_role(role)


func _is_factory_worker_active(citizen: Citizen, factory: Node3D) -> bool:
	return citizen.factory == factory and citizen.specialization == "factory_worker" and citizen.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]

func _has_courier() -> bool:
	for citizen in citizens:
		if citizen.can_handle_entry_logistics():
			return true
	return false

func _has_cook() -> bool:
	if not _is_fire_lit(canteen):
		return false
	for citizen in citizens:
		if citizen.specialization == "cook" and is_instance_valid(canteen) and citizen.global_position.distance_to(canteen_position) <= 2.2:
			return true
	return false


func _employment_center_position() -> Vector3:
	if is_instance_valid(campfire_node):
		return campfire_node.get_meta("service_position", campfire_node.global_position)
	return Vector3.INF


func _employment_centre_building() -> Node3D:
	return campfire_node if is_instance_valid(campfire_node) else null


func _officer_holder() -> Citizen:
	for citizen in citizens:
		if is_instance_valid(citizen) and citizen.permanent_role == "official":
			return citizen
	return null


func _officer_exists() -> bool:
	return _officer_holder() != null


func _player_can_command_labor() -> bool:
	return _officer_exists()


func _labor_command_block_message() -> String:
	return "Автоматизация труда требует назначенного чиновника. До этого раздавайте указания жителям вручную."


func _show_labor_command_blocked() -> void:
	_update_interface(_labor_command_block_message())


func _refresh_labor_authority_indicator() -> void:
	if labor_authority_label == null:
		return
	if _officer_exists():
		labor_authority_label.visible = false
	else:
		labor_authority_label.text = "Автоматизация недоступна\nНазначьте officer'а"
		labor_authority_label.add_theme_color_override("font_color", Color("e28c8c"))
		labor_authority_label.visible = true


func _registration_official() -> Citizen:
	# Any citizen can be the officer, but they must physically staff the active
	# civic centre. Player control does not grant remote registration privileges.
	var centre := _employment_centre_building()
	if not is_instance_valid(centre):
		return null
	var center := _employment_center_position()
	for citizen in citizens:
		if not is_instance_valid(citizen) or citizen.permanent_role != "official":
			continue
		if citizen.employment_workplace != centre:
			continue
		if citizen.global_position.distance_to(center) > OFFICER_POST_RADIUS:
			continue
		if citizen.is_player_controlled or citizen.state == Citizen.State.OFFICIAL_WORK:
			return citizen
	return null


func _is_registration_staffed() -> bool:
	return _is_work_time() and _registration_official() != null


func _next_registration_ticket() -> int:
	_registration_queue_counter += 1
	return _registration_queue_counter


func _can_start_registration(citizen: Citizen) -> bool:
	if not _is_registration_staffed() or citizen.employment_state != Citizen.EmploymentState.REGISTERING:
		return false
	for other in citizens:
		if not is_instance_valid(other) or other == citizen:
			continue
		if other.state == Citizen.State.EMPLOYMENT_PROCESSING:
			return false
		if other.employment_state == Citizen.EmploymentState.REGISTERING and other.registration_queue_order >= 0 and other.registration_queue_order < citizen.registration_queue_order:
			return false
	return true


func _registration_duration() -> float:
	var official := _registration_official()
	if official == null:
		return Citizen.EMPLOYMENT_PROCESS_DURATION
	return Citizen.EMPLOYMENT_PROCESS_DURATION / official.get_efficiency("official")


func _is_teacher_present_at_school() -> bool:
	if school_positions.is_empty():
		return false
	var school_pos := school_positions[0]
	for citizen in citizens:
		if citizen.specialization == "teacher":
			if citizen.is_player_controlled:
				if citizen.global_position.distance_to(school_pos) <= 3.5:
					return true
			elif citizen.state == Citizen.State.SCHOOL_WORK:
				if citizen.global_position.distance_to(school_pos) <= 3.5:
					return true
	return false


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
	# Do not grant a profession outside the shift. Keep the reservation/status and
	# restart the one-hour registration at the next working morning.
	if not _is_work_time():
		citizen.state = Citizen.State.IDLE
		return
	citizen.finish_employment_processing()
	# The native runtime observes the employment state in its next snapshot and
	# owns the first work command. Do not invoke a second scheduler here.
	_update_workers()

func _update_daylight() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if sun == null or world_environment == null:
		return
	var hour := game_minutes / 60.0
	var solar_height := sin((hour - 6.0) / 12.0 * PI)
	var direct_light := smoothstep(0.0, 0.28, solar_height)
	var twilight := 1.0 - smoothstep(0.0, 0.28, absf(solar_height))
	var night_color := Color("101a2b")
	var twilight_color := Color("d87850")
	var day_color := Color("78a9c5")
	if solar_height <= 0.0:
		world_environment.background_color = night_color.lerp(twilight_color, twilight)
	else:
		world_environment.background_color = twilight_color.lerp(day_color, direct_light)
	world_environment.ambient_light_color = Color("4b5872").lerp(Color("d7ebef"), maxf(direct_light, twilight * 0.35))
	world_environment.ambient_light_energy = lerpf(0.18, 0.65, maxf(direct_light, twilight * 0.3))
	sun.rotation_degrees = Vector3(-90.0 + (hour - 12.0) * 15.0, -32.0, 0.0)
	sun.light_color = Color("f08a5d").lerp(Color("fff2d1"), direct_light)
	sun.light_energy = lerpf(0.0, 1.2, direct_light)
	sun.shadow_enabled = direct_light > 0.05

func _update_clock(delta: float) -> void:
	var previous_hour := clock.hour()
	var events := day_cycle.advance(delta, GAME_MINUTES_PER_SECOND, settlement.workday_hours)
	if clock.hour() != previous_hour:
		_apply_hourly_tent_survival(clock.hour())
	clock_label.text = "%s  %02d:%02d  x%d" % ["Night" if clock.is_night() else "Day", clock.hour(), clock.minute(), int(time_multiplier)]
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
			_clear_daily_orders(day_cycle.current_day)
			_update_interface("Workday ended: residents are returning to their assigned homes.")
		SimulationDayEvent.Kind.NIGHTFALL:
			_refresh_living_statuses()
			_update_workers()
			_update_interface("Nightfall: workers are returning to their assigned homes.")
		SimulationDayEvent.Kind.WORKDAY_STARTED:
			_refresh_living_statuses()
			_update_workers()
			_update_interface("Morning: workers left their homes for their assignments.")
		SimulationDayEvent.Kind.SCHOOL_DAY_ENDED:
			var teacher_ok := _is_teacher_present_at_school()
			for citizen in citizens:
				citizen.finish_school_day(teacher_ok)
			_update_workers()
		SimulationDayEvent.Kind.DAILY_SETTLEMENT_UPDATE:
			tent_weather = TentEraSurvivalRulesScript.weather_for_day(day_cycle.current_day)
			_update_interface("Forecast: %s." % TentEraSurvivalRulesScript.WEATHER_NAMES[tent_weather])
			_maybe_present_survival_decision()
			_expire_temporary_tents()
			_refresh_living_statuses()
			_apply_daily_settlement_rules()
			_return_outside_workers()


func _apply_hourly_tent_survival(hour: int, survival_day := 0) -> void:
	var day := day_cycle.current_day if survival_day <= 0 else survival_day
	var survival_hour := day * 24 + hour
	if settlement.era != SettlementState.Era.TENT or last_survival_hour == survival_hour:
		return
	last_survival_hour = survival_hour
	var wellbeing_before_hour := wellbeing
	var night := hour >= 22 or hour < 6
	var has_fire := _has_lit_communal_fire()
	var total_loss := 0
	for citizen in citizens:
		if not is_instance_valid(citizen):
			continue
		var has_home := is_instance_valid(citizen.home)
		total_loss += TentEraSurvivalRulesScript.hourly_wellbeing_loss(has_home, has_fire, tent_weather, night)
	if total_loss > 0:
		wellbeing = maxi(0, wellbeing - ceili(float(total_loss) / maxi(1, citizens.size())))
	if not settlement.construction_gloves_available():
		var bare_handed_workers := 0
		for citizen in citizens:
			if is_instance_valid(citizen) and citizen._is_physical_work():
				bare_handed_workers += 1
		if bare_handed_workers > 0:
			wellbeing = maxi(0, wellbeing - ceili(float(bare_handed_workers) / maxi(1, citizens.size())))
	if tent_weather == TentEraSurvivalRulesScript.Weather.RAIN and hour > 0:
		_apply_rain_damage()
	if wellbeing_before_hour > 0 and wellbeing <= 0 and not citizens.is_empty():
		var departing: Citizen = citizens.pop_back()
		departing.queue_free()
		_add_message("A resident left the camp after wellbeing reached zero.")
		_schedule_recovery_arrival()


func _apply_rain_damage() -> void:
	var sheltered_capacity := int(settlement.buildings.get("warehouse_lvl2", 0)) * 48
	var stored_units := settlement.storage_used_units()
	if stored_units <= sheltered_capacity:
		return
	var exposed_ratio := (stored_units - sheltered_capacity) / stored_units
	var rain_amounts := {"food": food, "grass": grass, "branches": 0 if protected_firewood_day == day_cycle.current_day else branches, "wood": wood, "logs": settlement.logs}
	var losses := TentEraSurvivalRulesScript.rain_hourly_decay_losses(rain_amounts, exposed_ratio)
	for resource_type in losses:
		settlement.add(resource_type, -int(losses[resource_type]))
	for record in building_registry.records():
		var building: Node3D = record.node
		if is_instance_valid(building) and str(building.get_meta("building_type", "")) in ["campfire", "campfire_lvl2", "campfire_lvl3", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3"]:
			var fire_state := _fire_state_for(building)
			fire_state.lit = false
			_apply_fire_state(building, fire_state)


func _expire_temporary_tents() -> void:
	for record in building_registry.records().duplicate():
		var building: Node3D = record.node
		if not is_instance_valid(building) or str(building.get_meta("building_type", "")) != "tent":
			continue
		_destroy_building_to_pile(building, "tent")
		_add_message("The temporary tent was dismantled at dawn.")


func _schedule_recovery_arrival() -> void:
	if citizens.size() >= POPULATION:
		return
	if recovery_arrival_at_minutes < 0.0:
		recovery_arrival_at_minutes = _total_game_minutes() + 24.0 * 60.0


func _total_game_minutes() -> float:
	return float(day_cycle.current_day - 1) * 24.0 * 60.0 + game_minutes


func _update_recovery_arrival() -> void:
	if recovery_arrival_at_minutes < 0.0 or _total_game_minutes() < recovery_arrival_at_minutes:
		return
	if citizens.size() < POPULATION and is_instance_valid(entrance_stone):
		_add_citizen(entrance_stone.global_position + Vector3(0.8, 0.1, 1.2), "unassigned")
		money += 100
		food += 4
		settlement.add_construction_glove_set()
		_add_message("A survivor arrived with emergency supplies.")
	recovery_arrival_at_minutes = _total_game_minutes() + random.randi_range(24, 48) * 60.0 if citizens.size() < POPULATION else -1.0

func _apply_daily_settlement_rules() -> void:
	if trail_field != null:
		trail_field.apply_daily_decay()
	var population := citizens.size()
	if population == 0:
		return
	for citizen in citizens:
		citizen.apply_daily_decay()
	if citizen_needs_service != null:
		citizen_needs_service.schedule_daily_toilets(citizens)
	_apply_building_wear_and_repairs()
	
	# Heap (Open-Air) Storage decay:
	var warehouse_lvl2_count := int(settlement.buildings.get("warehouse_lvl2", 0))
	var safe_capacity := warehouse_lvl2_count * 48.0
	var total_stored := settlement.storage_used_units()
	var decay_losses := SETTLEMENT_RULES.open_air_storage_decay_losses({
		"food": food,
		"grass": grass,
		"branches": branches,
		"wood": wood,
		"logs": settlement.logs,
	}, total_stored, safe_capacity)
	if not decay_losses.is_empty():
		var decay_msg := ""
		for res in decay_losses:
			var lost := int(decay_losses[res])
			settlement.add(res, -lost)
			if decay_msg.is_empty():
				decay_msg = "Daily decay: lost "
			else:
				decay_msg += ", "
			decay_msg += "%d %s" % [lost, res]
		if not decay_msg.is_empty():
			decay_msg += " due to open-air Heap storage."
			_add_message(decay_msg)
			_update_interface(decay_msg)

	_decay_resource_piles()
	# Everyone drinks each day. When there is no kitchen running meals, they also
	# eat straight from the stores; a working cooking campfire/canteen already
	# draws food through the meal pipeline, so we don't double-count there.
	water = maxi(0, water - population)
	if not is_instance_valid(canteen):
		food = maxi(0, food - TentEraSurvivalRulesScript.daily_food_consumption(population, tent_weather))
	var housing := _total_housing_slots()
	var change := SETTLEMENT_RULES.daily_wellbeing_change(housing >= population, float(food) / population, float(water) / population, settlement.workday_hours, settlement.night_shifts_allowed)
	wellbeing = clampi(wellbeing + change, 0, 100)
	settlement.low_wellbeing_days = settlement.low_wellbeing_days + 1 if wellbeing < SettlementRules.LOW_WELLBEING else 0
	if SETTLEMENT_RULES.should_volunteer_leave(settlement.low_wellbeing_days) and not citizens.is_empty():
		var departing: Citizen = citizens.pop_back()
		departing.queue_free()
		settlement.low_wellbeing_days = 0
		_update_interface("A volunteer left after several days of poor living conditions.")
	# --- Daily settlement warnings ---
	if food == 0:
		_add_message("CRITICAL: Food supplies exhausted! Workers are starving.")
	elif float(food) / population < 1.0:
		_add_message("Warning: Food is running low (%d for %d people)." % [food, population])
	if water == 0:
		_add_message("CRITICAL: Water supplies exhausted! Settlement is dehydrated.")
	elif float(water) / population < 1.0:
		_add_message("Warning: Water is running low (%d for %d people)." % [water, population])
	var storage_ratio := float(_stored_resources()) / float(maxi(1, _warehouse_capacity()))
	if storage_ratio >= 0.95:
		_add_message("CRITICAL: Storage nearly full (%d%%). Build another warehouse or rebalance." % [int(storage_ratio * 100)])
	elif storage_ratio >= 0.80:
		_add_message("Warning: Storage filling up (%d%% used)." % [int(storage_ratio * 100)])
	if wellbeing < SettlementRules.LOW_WELLBEING:
		_add_message("Warning: Low wellbeing (%d). Unhappiness is accumulating — volunteers may leave!" % wellbeing)
	elif change < 0:
		_add_message("Wellbeing is declining (change: %d). Consider improving living conditions." % change)

func _update_house_lights() -> void:
	var hour := int(game_minutes) / 60
	var minute := int(game_minutes) % 60
	var clock_minute := int(game_minutes)
	if house_light_update_minute == clock_minute:
		return
	house_light_update_minute = clock_minute
	var minute_of_day := hour * 60 + minute
	for record in house_lights:
		var light: OmniLight3D = record.light
		if not is_instance_valid(light):
			continue
		var house: Node3D = record.house
		var off_minute: int = int(house.get_meta("light_off_minute", record.off_minute))
		# A home is lit only after someone moves in. It turns on with evening
		# twilight and each household chooses one stable
		# switch-off time between 22:00 and 02:00, including after midnight.
		var occupied := _house_has_residents(house)
		light.visible = occupied and _house_has_people_at_home(house) and (minute_of_day >= 17 * 60 and minute_of_day < off_minute if off_minute >= 17 * 60 else minute_of_day >= 17 * 60 or minute_of_day < off_minute)
	for light in entrance_lights:
		if is_instance_valid(light):
			light.visible = minute_of_day >= 17 * 60 or minute_of_day < 7 * 60

func _house_has_residents(house: Node3D) -> bool:
	if not is_instance_valid(house):
		return false
	for citizen in citizens:
		if citizen.home == house:
			return true
	return false

func _house_has_people_at_home(house: Node3D) -> bool:
	for citizen in citizens:
		if citizen.home == house and citizen.state == Citizen.State.RESTING:
			return true
	return false

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
	return day_cycle.is_work_time(settlement.workday_hours, settlement.night_shifts_allowed)

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
	if warehouse_positions.is_empty():
		return
	# Repair reservations left by an interrupted or removed carrier before task
	# validity is evaluated. This is the active dispatcher path.
	for construction_site in construction_sites:
		_reconcile_construction_reservations(construction_site)
	# Emergency food is published before every other task.
	if is_instance_valid(canteen) and food > 0 and not pending_canteen_delivery:
		var food_capacity := BuildingCatalog.kitchen_food_capacity(str(canteen.get_meta("building_type", "")))
		if food_capacity > canteen_food:
			dispatcher.publish(&"canteen_food", CourierTask.Kind.CANTEEN, 100, warehouse_positions[0], canteen_position)
	for order in queued_trades:
		var trade: Dictionary = order.trade
		dispatcher.publish(StringName("trade_%s" % str(trade)), CourierTask.Kind.TRADE, 80, order.source, order.destination, {"order": order})
	for position in sawmill_positions:
		if int(sawmills.stock_at(position, runtime_seconds).boards) > 0:
			dispatcher.publish(StringName("sawmill_%s" % _cell_from_position(position)), CourierTask.Kind.SAWMILL_PICKUP, 50, position, warehouse_positions[0], {"position": position})
	for worker in citizens:
		if worker != null and worker.has_pending_resource() and not courier_dispatcher.is_manually_targeted(worker):
			dispatcher.publish(StringName("worker_%d" % worker.get_instance_id()), CourierTask.Kind.WORKER_PICKUP, 45, worker.global_position, warehouse_positions[0], {"worker": worker})
	var site := _preferred_construction_site()
	if site != null:
		for resource_type in site.required_materials:
			var required := int(site.required_materials[resource_type])
			var delivered := int(site.delivered_materials.get(resource_type, 0))
			var reserved := int(site.reserved_materials.get(resource_type, 0))
			if delivered + reserved < required and settlement.amount(resource_type) > 0:
				dispatcher.publish(StringName("construction_%s_%s" % [site.node.get_instance_id(), resource_type]), CourierTask.Kind.CONSTRUCTION, 70, warehouse_positions[0], site.node.global_position, {"site": site, "resource": resource_type})
				break


func _is_courier_task_valid(task: RefCounted) -> bool:
	match task.kind:
		CourierTask.Kind.CANTEEN:
			return is_instance_valid(canteen) and food > 0 and not pending_canteen_delivery and canteen_food < BuildingCatalog.kitchen_food_capacity(str(canteen.get_meta("building_type", "")))
		CourierTask.Kind.TRADE:
			return queued_trades.has(task.payload.order)
		CourierTask.Kind.SAWMILL_PICKUP:
			return int(sawmills.stock_at(task.payload.position, runtime_seconds).boards) > 0
		CourierTask.Kind.WORKER_PICKUP:
			return is_instance_valid(task.payload.worker) and task.payload.worker.has_pending_resource()
		CourierTask.Kind.CONSTRUCTION:
			var site: ConstructionSite = task.payload.site
			if site == null or not is_instance_valid(site.node):
				return false
			var resource_type := str(task.payload.resource)
			return int(site.delivered_materials.get(resource_type, 0)) + int(site.reserved_materials.get(resource_type, 0)) < int(site.required_materials.get(resource_type, 0)) and settlement.amount(resource_type) > 0
	return false


func _start_courier_task(courier: Citizen, task: RefCounted) -> bool:
	match task.kind:
		CourierTask.Kind.CANTEEN:
			var capacity := BuildingCatalog.kitchen_food_capacity(str(canteen.get_meta("building_type", "")))
			var amount := mini(courier.courier_capacity(), mini(food, capacity - canteen_food))
			if amount <= 0:
				return false
			food -= amount
			pending_canteen_delivery = true
			pending_canteen_carrier = courier
			pending_canteen_delivery_amount = amount
			courier.deliver_food_to_canteen(warehouse_positions[0], canteen_position, amount)
			return true
		CourierTask.Kind.TRADE:
			var order: RefCounted = task.payload.order
			if not queued_trades.has(order):
				return false
			queued_trades.erase(order)
			trade_service.assign_order_to_worker(courier, order)
			return true
		CourierTask.Kind.SAWMILL_PICKUP:
			courier.assign_sawmill_pickup(task.payload.position, warehouse_positions[0])
			return true
		CourierTask.Kind.WORKER_PICKUP:
			courier.assign_courier_pickup(task.payload.worker, warehouse_positions[0])
			return true
		CourierTask.Kind.CONSTRUCTION:
			var site: ConstructionSite = task.payload.site
			var resource_type := str(task.payload.resource)
			if site == null or not is_instance_valid(site.node) or settlement.amount(resource_type) <= 0:
				return false
			settlement.add(resource_type, -1)
			var reservations := site.reserved_materials
			reservations[resource_type] = int(reservations.get(resource_type, 0)) + 1
			site.reserved_materials = reservations
			courier.assign_construction_delivery(site.node, warehouse_positions[0], resource_type)
			return true
	return false


func begin_native_construction_supply(worker: Citizen, site_node: Node3D, resource_type: String, warehouse: Vector3) -> bool:
	if worker == null or not is_instance_valid(site_node) or warehouse == Vector3.INF:
		return false
	for site: ConstructionSite in construction_sites:
		if site.node != site_node:
			continue
		var required := int(site.required_materials.get(resource_type, 0))
		var delivered := int(site.delivered_materials.get(resource_type, 0))
		var reserved := int(site.reserved_materials.get(resource_type, 0))
		if required <= delivered + reserved or settlement.amount(resource_type) <= 0:
			return false
		settlement.add(resource_type, -1)
		site.reserved_materials[resource_type] = reserved + 1
		worker.active_role = "construction"
		worker.assign_construction_delivery(site.node, warehouse, resource_type)
		return worker.state in [Citizen.State.TO_CONSTRUCTION_PICKUP, Citizen.State.TO_CONSTRUCTION_SITE]
	return false


func _reconcile_construction_reservations(site: ConstructionSite) -> void:
	# A delivery can be interrupted by the end-of-day scheduler or a route reset.
	# Return its reservation when no courier still owns it, otherwise the final
	# material can remain permanently reserved without ever reaching the site.
	var in_transit: Dictionary = {}
	for citizen in citizens:
		if citizen.construction_site != site.node:
			continue
		if citizen.state not in [Citizen.State.TO_CONSTRUCTION_PICKUP, Citizen.State.TO_CONSTRUCTION_SITE]:
			continue
		if citizen.building_supply_kind != "construction" or citizen.construction_delivery_resource.is_empty():
			continue
		in_transit[citizen.construction_delivery_resource] = int(in_transit.get(citizen.construction_delivery_resource, 0)) + citizen.carried_amount
	var reservations := site.reserved_materials
	for resource_type in reservations:
		var reserved := int(reservations[resource_type])
		var active := int(in_transit.get(resource_type, 0))
		if reserved <= active:
			continue
		settlement.add(resource_type, reserved - active)
		reservations[resource_type] = active
	site.reserved_materials = reservations

func _preferred_construction_site() -> ConstructionSite:
	var chosen: ConstructionSite
	var best_score := -INF
	for site in construction_sites:
		var score := _construction_development_priority(site)
		if score > best_score:
			chosen = site
			best_score = score
	return chosen

func _construction_development_priority(site: ConstructionSite) -> float:
	var building_type := site.building_type
	var score := float(BuildingCatalog.era_for(building_type)) * 100.0
	var population := citizens.size()
	match building_type:
		"warehouse", "warehouse_lvl2": score += 1000.0 if warehouse_positions.is_empty() else 180.0
		"campfire", "campfire_lvl2", "campfire_lvl3": score += 950.0 if not is_instance_valid(campfire_node) else 120.0
		"tent", "living_tent", "dugout", "earth_house", "clay_house", "stone_house", "house", "brick_house":
			score += 850.0 if _total_housing_slots() < population else 140.0
		"forager_tent", "forager_tent_lvl2", "forager_tent_lvl3", "farm": score += 700.0 if food < population * 2 else 160.0
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
		_update_interface("Construction site is full; courier returned %d %s to storage." % [amount, resource_type])
	courier_dispatcher.complete_for(_courier)
	_request_courier_dispatch()

func _on_building_supply_delivered(_courier: Citizen, target: Node3D, supply_kind: String, resource_type: String, amount: int) -> void:
	courier_dispatcher.complete_for(_courier)
	if not is_instance_valid(target):
		settlement.add(resource_type, amount)
		return
	match supply_kind:
		"firewood":
			var fire_state := _fire_state_for(target)
			fire_state.add_delivered(amount)
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

func _update_firewood_supplies() -> void:
	for courier in citizens:
		if not courier.can_handle_entry_logistics() or courier.state != Citizen.State.IDLE:
			continue
		for record in building_registry.records():
			var building := record.node
			if not is_instance_valid(building) or str(building.get_meta("building_type", "")) not in ["campfire", "campfire_lvl2", "campfire_lvl3", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3"]:
				continue
			var fire_state := _fire_state_for(building)
			if not fire_state.needs_supply(4) or branches <= 0:
				continue
			branches -= 1
			fire_state.reserve(1)
			_apply_fire_state(building, fire_state)
			courier.assign_building_supply(building, warehouse_positions[0], "branches", "firewood")
			return

func _update_repairs() -> void:
	if warehouse_positions.is_empty() or branches <= 0 or not _is_work_time():
		return
	for builder in citizens:
		if builder.state != Citizen.State.IDLE or not builder.can_handle_entry_logistics():
			continue
		for record in building_registry.records():
			var building := record.node
			if not is_instance_valid(building) or not bool(building.get_meta("repair_needed", false)) or bool(building.get_meta("repair_reserved", false)):
				continue
			branches -= 1
			building.set_meta("repair_reserved", true)
			builder.assign_building_supply(building, warehouse_positions[0], "branches", "repair")
			return

func _update_resource_pile_supplies() -> void:
	for courier in citizens:
		if not courier.can_handle_entry_logistics() or courier.state != Citizen.State.IDLE:
			continue
		for index in resource_piles.size():
			var pile: Dictionary = resource_piles[index]
			for resource_type in pile.resources:
				var available := int(pile.resources[resource_type]) - int(pile.reserved.get(resource_type, 0))
				if available <= 0:
					continue
				if not settlement.reserve_storage_room_for(resource_type, 1, warehouse_positions.size()):
					continue
				pile.resources[resource_type] = int(pile.resources[resource_type]) - 1
				pile.reserved[resource_type] = int(pile.reserved.get(resource_type, 0)) + 1
				resource_piles[index] = pile
				courier.assign_building_supply(pile.node, warehouse_positions[0], resource_type, "pile")
				return

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

func _on_factory_cycle(worker: Citizen, factory: Node3D) -> void:
	if not is_instance_valid(factory):
		return
	var type: String = factory.get_meta("building_type", "")
	if type == "brick_factory":
		if clay < 1:
			return
		clay -= 1
		var produced := 1
		if worker.skills.get("factory_worker", 0.0) >= 1.0 and randf() < 0.10:
			produced = 2
			_update_interface("Industrialist: Brick factory produced 2 bricks from 1 clay!")
		else:
			_update_interface("Brick factory produced 1 brick.")
		bricks += produced

func _materials_factory_staffed(factory: Node3D) -> bool:
	var has_worker := false
	var has_builder := false
	var has_engineer := false
	for citizen in citizens:
		if citizen.factory != factory:
			continue
		if citizen.is_player_controlled:
			if citizen.global_position.distance_to(factory.global_position) > 6.0:
				continue
		elif citizen.state not in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]:
			continue
		has_worker = has_worker or citizen.specialization == "factory_worker"
		has_builder = has_builder or citizen.specialization == "builder"
		has_engineer = has_engineer or citizen.specialization == "engineer"
	return has_worker and has_builder and has_engineer

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

func _request_courier_dispatch() -> void:
	if _is_work_time():
		_update_couriers()

func _sawmill_with_boards() -> Vector3:
	return sawmills.position_with_boards(runtime_seconds)

func _on_excavation_cycle(worker: Citizen, site_node: Node3D, efficiency: float) -> void:
	for index in range(dig_sites.size()):
		var site: Dictionary = dig_sites[index]
		if site.node != site_node:
			continue
		
		# Check if the next layer is blocked by tool requirement BEFORE incrementing depth
		var next_depth = site.depth + 1
		var tool_id = _tool_for_depth(site, next_depth)
		if tool_id != "" and not bool(settlement.tools.get(tool_id, false)):
			# Settlement doesn't have the tool for this layer! Stop the worker.
			worker.assigned_dig_site = null
			worker.idle()
			_update_interface("Excavation paused: missing tool '%s' for the next layer." % tool_id)
			_update_workers()
			return
			
		site.depth += 1
		if site.depth <= site.grass_limit:
			worker.register_pending_resource("grass", 1)
			var pit_material := StandardMaterial3D.new()
			pit_material.albedo_color = Color("3e612c") # Grass green
			site.pit.material_override = pit_material
			_update_interface("Digger is carrying grass to the warehouse.")
		elif site.depth <= site.soil_limit:
			var res := "soil"
			if worker.skills.get("excavation", 0.0) >= 1.0 and randf() < 0.10:
				res = "clay" if randf() < 0.5 else "stone"
				_update_interface("Deep Digger: Digger found rare %s in soil!" % res.capitalize())
			worker.register_pending_resource(res, 1)
			var pit_material := StandardMaterial3D.new()
			pit_material.albedo_color = Color("78533b") # Soil brown
			site.pit.material_override = pit_material
			_update_interface("Digger is carrying %s to the warehouse." % res)
		elif site.depth <= site.clay_limit:
			worker.register_pending_resource("clay", 1)
			var pit_material := StandardMaterial3D.new()
			pit_material.albedo_color = Color("a96445") # Clay reddish-brown
			site.pit.material_override = pit_material
			_update_interface("Digger is carrying clay to the warehouse.")
		elif site.depth <= site.stone_limit:
			worker.register_pending_resource("stone", 1)
			var pit_material := StandardMaterial3D.new()
			pit_material.albedo_color = Color("62676a") # Stone grey
			site.pit.material_override = pit_material
			_update_interface("Digger is carrying stone to the warehouse.")
		else:
			site_node.queue_free()
			dig_sites.remove_at(index)
			dig_cells.erase(site.cell)
			exhausted_dig_cells[site.cell] = true
			for citizen in citizens:
				if citizen.assigned_dig_site == site_node:
					citizen.assigned_dig_site = null
			_update_workers()
			_update_interface("Stone excavation is exhausted; choose another cell.")
			return
		dig_sites[index] = site
		_request_courier_dispatch()
		return

func _can_work_at_dig_site(site: Dictionary) -> bool:
	var next_depth = site.depth + 1
	if next_depth > site.stone_limit:
		return false
	var tool_id = _tool_for_depth(site, next_depth)
	if tool_id != "" and not bool(settlement.tools.get(tool_id, false)):
		return false
	return true

func _tool_for_depth(site: Dictionary, depth: int) -> String:
	if depth <= site.grass_limit:
		return ""
	elif depth <= site.soil_limit:
		return "shovel"
	elif depth <= site.clay_limit:
		return "hoe"
	elif depth <= site.stone_limit:
		return "pickaxe"
	return ""

func _resource_for_depth(site: Dictionary, depth: int) -> String:
	if depth <= site.grass_limit:
		return "grass"
	elif depth <= site.soil_limit:
		return "soil"
	elif depth <= site.clay_limit:
		return "clay"
	elif depth <= site.stone_limit:
		return "stone"
	return "soil"

func _count_valid_dig_sites() -> int:
	var count := 0
	for site in dig_sites:
		if _can_work_at_dig_site(site):
			count += 1
	return count

func _dig_site_for_node(site_node: Node3D) -> Dictionary:
	for site in dig_sites:
		if site.node == site_node:
			return site
	return {}

func _building_cost() -> int:
	return BuildingCatalog.cost_for(build_mode)

func _format_costs(building_type: String) -> String:
	return building_availability_service.cost_text(building_type)

func _stored_resources() -> int:
	return int(ceil(settlement.storage_used_units()))

func _warehouse_capacity() -> int:
	return settlement.storage_capacity(warehouse_positions.size())

func _total_housing_slots() -> int:
	return building_registry.housing_capacity()

func _update_camera(delta: float) -> void:
	var move_direction := Vector3.ZERO
	var yaw_radians := deg_to_rad(camera_yaw)
	var forward := Vector3(-sin(yaw_radians), 0.0, -cos(yaw_radians))
	var right := Vector3(cos(yaw_radians), 0.0, -sin(yaw_radians))
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move_direction += forward
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move_direction -= forward
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move_direction += right
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move_direction -= right
	if not move_direction.is_zero_approx():
		camera_target += move_direction.normalized() * 9.0 * delta
	_update_camera_position()

func _pan_camera(mouse_delta: Vector2) -> void:
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	camera_target -= right * mouse_delta.x * 0.035
	camera_target += forward * mouse_delta.y * 0.035
	_update_camera_position()

func _rotate_camera(mouse_delta: Vector2) -> void:
	camera_yaw -= mouse_delta.x * 0.35
	camera_pitch = clampf(camera_pitch - mouse_delta.y * 0.25, 8.0, 85.0)
	_update_camera_position()

func _update_camera_position() -> void:
	if camera == null: return
	var yaw_radians := deg_to_rad(camera_yaw)
	var pitch_radians := deg_to_rad(camera_pitch)
	var offset := Vector3(sin(yaw_radians) * cos(pitch_radians), sin(pitch_radians), cos(yaw_radians) * cos(pitch_radians)) * camera_distance
	camera.position = camera_target + offset
	camera.look_at(camera_target)

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


func _movement_speed_modifier_at(position_on_board: Vector3) -> float:
	return nav_grid.movement_speed_modifier_at(position_on_board) if nav_grid != null else 1.0


func _navigation_revision() -> int:
	return nav_grid.topology_revision() if nav_grid != null else -1


## Candidate discovery asks only whether a destination can be reached. Cache the
## result per topology revision so snapshot construction does not repeatedly run
## the same synchronous A* searches before an actor starts moving.
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
	var reachable := _find_path_around_houses(from, destination, may_enter_destination_house).reachable
	if _route_reachability_cache.size() < ROUTE_REACHABILITY_CACHE_LIMIT:
		_route_reachability_cache[key] = reachable
	return reachable

func _resolve_building_queue_position(citizen: Citizen, destination: Vector3) -> Dictionary:
	return building_queue_service.resolve(citizen, destination)


func _complete_building_queue_arrival(citizen: Citizen, destination: Vector3) -> void:
	building_queue_service.complete_arrival(citizen, destination)


func _release_building_queue_entry(citizen: Citizen) -> void:
	building_queue_service.release(citizen)

func _update_interface(message: String) -> void:
	wood_label.text = "Era: %s\nMoney: %d\nBranches: %d\nGrass: %d\nWater: %d\nFood: %d\nSoil: %d\nClay: %d\nLogs: %d\nTimber: %d\nBoards: %d\nStone: %d\nBricks: %d\nStorage: %d/%d\nPopulation: %d\nWellbeing: %d" % [_era_name(), money, branches, grass, water, food, soil, clay, settlement.logs, wood, boards, stone, bricks, _stored_resources(), _warehouse_capacity(), citizens.size(), wellbeing]
	_add_message(message)
	if is_first_person:
		var build_hint := "  B: construction" if player_citizen == hero_citizen else ""
		if not build_mode.is_empty():
			build_hint += "  Q/E: rotate"
		camera_hint_label.text = "R: hero/overview  WASD/arrows: move  Space: jump  Shift: sprint  Mouse: look  LMB: interact  RMB: dig%s" % build_hint
	else:
		camera_hint_label.text = "R: view from hero. Select a citizen and choose Manage. Right drag: rotate  Middle drag: pan  Wheel: zoom"

func _era_name() -> String:
	return ["Tent", "Earth", "Clay", "Wood", "Brick"][settlement.era]


# ---------- Message log system ------------------------------------------------

func _add_message(text: String) -> void:
	if message_list == null or text.is_empty() or not _is_gameplay_message(text):
		return
	var msg_type := _classify_message(text)
	var timestamp := "[Day %d, %02d:%02d]" % [current_day, clock.hour(), clock.minute()]
	var entry := {"text": text, "type": msg_type, "timestamp": timestamp}
	messages.append(entry)
	var color := _message_color(msg_type)
	var formatted := "[color=%s]%s[/color] %s" % [color, timestamp, text]
	_append_message_label(message_list, formatted, 12, 356)
	_scroll_to_bottom.call_deferred()
	# Keep only last 60 visible in the compact panel.
	while message_list.get_child_count() > 60:
		var old_node := message_list.get_child(0)
		message_list.remove_child(old_node)
		old_node.queue_free()

func _is_gameplay_message(text: String) -> bool:
	var lower := text.to_lower()
	for noise in [" selected", "view enabled", "overview centered", "simulation speed", "workday set", "night shifts", "construction mode cancelled"]:
		if lower.contains(noise):
			return false
	return true


func _classify_message(text: String) -> String:
	var lower := text.to_lower()
	# Error-level
	if lower.contains("critical") or lower.contains("missed") or lower.contains("ran out") or lower.contains("left after") or lower.contains("no canteen") or lower.contains("needs a cook") or lower.contains("no storage room") or lower.contains("interrupted") or lower.contains("not allowed") or lower.contains("exhausted") or lower.contains("starving") or lower.contains("dehydrated"):
		return "error"
	# Warning-level
	if lower.contains("warning") or lower.contains("rebalance") or lower.contains("low wellbeing") or lower.contains("declining") or lower.contains("filling up") or lower.contains("running low") or lower.contains("needs") or lower.contains("requires"):
		return "warning"
	# Success-level
	if lower.contains("unlocked") or lower.contains("completed") or lower.contains("delivered") or lower.contains("produced") or lower.contains("joined") or lower.contains("built") or lower.contains("advanced") or lower.contains("received") or lower.contains("research started"):
		return "success"
	return "info"


func _message_color(msg_type: String) -> String:
	match msg_type:
		"error": return "#e85555"
		"warning": return "#f0a030"
		"success": return "#7dce82"
		_: return "#8ab4cc"


func _append_message_label(container: VBoxContainer, formatted_text: String, font_size: int, min_width: float) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.text = formatted_text
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.custom_minimum_size = Vector2(min_width, 0)
	container.add_child(label)


func _scroll_to_bottom() -> void:
	if message_scroll != null:
		message_scroll.scroll_vertical = int(message_scroll.get_v_scroll_bar().max_value)


func _create_message_panel(ui: CanvasLayer) -> void:
	var msg_panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.08, 0.92)
	style.border_color = Color(0.15, 0.25, 0.32, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	msg_panel.add_theme_stylebox_override("panel", style)
	msg_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	msg_panel.offset_left = 20
	msg_panel.offset_top = -268
	msg_panel.offset_right = 400
	msg_panel.offset_bottom = -38
	ui.add_child(msg_panel)

	# Header row
	var header := HBoxContainer.new()
	header.position = Vector2(10, 6)
	header.size = Vector2(368, 26)
	msg_panel.add_child(header)

	var title := Label.new()
	title.text = "Messages"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var history_btn := Button.new()
	history_btn.text = "History"
	history_btn.add_theme_font_size_override("font_size", 12)
	history_btn.custom_minimum_size = Vector2(70, 24)
	history_btn.pressed.connect(_open_messages_modal)
	header.add_child(history_btn)

	# Scrollable message list
	message_scroll = ScrollContainer.new()
	message_scroll.position = Vector2(6, 34)
	message_scroll.size = Vector2(376, 190)
	message_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	msg_panel.add_child(message_scroll)

	message_list = VBoxContainer.new()
	message_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_scroll.add_child(message_list)


func _create_messages_modal(ui: CanvasLayer) -> void:
	messages_modal = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.05, 0.07, 0.96)
	style.border_color = Color(0.2, 0.35, 0.45, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	messages_modal.add_theme_stylebox_override("panel", style)
	messages_modal.set_anchors_preset(Control.PRESET_CENTER)
	messages_modal.offset_left = -300
	messages_modal.offset_top = -240
	messages_modal.offset_right = 300
	messages_modal.offset_bottom = 240
	messages_modal.visible = false
	ui.add_child(messages_modal)

	# Title
	var title := Label.new()
	title.text = "Message History"
	title.position = Vector2(20, 12)
	title.size = Vector2(460, 30)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	messages_modal.add_child(title)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(510, 10)
	close_btn.size = Vector2(78, 30)
	close_btn.pressed.connect(_close_messages_modal)
	messages_modal.add_child(close_btn)

	# Scroll container
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 48)
	scroll.size = Vector2(576, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	messages_modal.add_child(scroll)

	modal_message_list = VBoxContainer.new()
	modal_message_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(modal_message_list)


func _open_messages_modal() -> void:
	if messages_modal == null:
		return
	# Rebuild modal content from full history.
	for child in modal_message_list.get_children():
		child.queue_free()
	for entry in messages:
		var color := _message_color(entry.type)
		var formatted := "[color=%s]%s[/color] %s" % [color, entry.timestamp, entry.text]
		_append_message_label(modal_message_list, formatted, 13, 564)
	messages_modal.visible = true


func _close_messages_modal() -> void:
	if messages_modal != null:
		messages_modal.visible = false

# ---------- End message log system --------------------------------------------

func _create_world() -> void:
	var environment := WorldEnvironment.new()
	world_environment = Environment.new()
	world_environment.background_mode = Environment.BG_COLOR
	world_environment.background_color = Color("78a9c5")
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color("d7ebef")
	world_environment.ambient_light_energy = 0.65
	world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = world_environment
	add_child(environment)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	_update_daylight()

	camera = Camera3D.new()
	add_child(camera)
	_update_camera_position()
	_create_voxel_terrain()
	_create_trail_overlay()
	_refresh_navigation_grid()
	_create_selection_marker()

func _create_voxel_terrain() -> void:
	if DisplayServer.get_name() == "headless":
		_create_headless_ground()
		return
	voxel_terrain = VoxelLodTerrain.new()
	voxel_terrain.mesher = VoxelMesherTransvoxel.new()
	var generator := VoxelGeneratorNoise2D.new()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.025
	generator.noise = noise
	generator.channel = VoxelBuffer.CHANNEL_SDF
	generator.height_start = -0.15
	generator.height_range = 0.3
	voxel_terrain.generator = generator
	voxel_terrain.generate_collisions = true
	voxel_terrain.view_distance = 192
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("5f8953")
	material.roughness = 0.95
	voxel_terrain.material = material
	add_child(voxel_terrain)
	# Стример подгружает воксели вокруг камеры (нужно и для отрисовки, и для копания).
	camera.add_child(VoxelViewer.new())
	voxel_tool = voxel_terrain.get_voxel_tool()
	voxel_tool.channel = VoxelBuffer.CHANNEL_SDF

func _create_headless_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "HeadlessGround"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(BOARD_CELLS * CELL_SIZE * 2.0, 0.2, BOARD_CELLS * CELL_SIZE * 2.0)
	collision.shape = shape
	collision.position.y = -0.1
	ground.add_child(collision)
	add_child(ground)


func _create_trail_overlay() -> void:
	if DisplayServer.get_name() == "headless" or trail_field == null:
		return
	trail_overlay = MeshInstance3D.new()
	trail_overlay.name = "TrailOverlay"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(BOARD_CELLS * CELL_SIZE, BOARD_CELLS * CELL_SIZE)
	trail_overlay.mesh = mesh
	trail_overlay.position.y = 0.12
	trail_overlay_material = ShaderMaterial.new()
	trail_overlay_material.shader = TrailOverlayShader
	trail_overlay.material_override = trail_overlay_material
	add_child(trail_overlay)


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

func _is_navigation_cell_blocked(cell: Vector2i) -> bool:
	return navigation_blocked_cells.has(cell)

func _rebuild_navigation_obstacles() -> void:
	var building_blocked: Dictionary = {}
	var margin := ceili(NAVIGATION_CLEARANCE_MARGIN)
	for record in building_registry.records():
		var center: Vector3 = record.center
		var footprint: Vector2i = record.footprint
		var min_x := roundi(center.x - (footprint.x - 1) * 0.5)
		var min_z := roundi(center.z - (footprint.y - 1) * 0.5)
		for x in range(min_x - margin, min_x + footprint.x + margin):
			for z in range(min_z - margin, min_z + footprint.y + margin):
				building_blocked[Vector2i(x, z)] = true
	for pocket in service_pockets:
		if is_instance_valid(pocket.node):
			building_blocked.erase(pocket.cell)
	navigation_blocked_cells = terrain_blocked_cells.duplicate()
	for cell in building_blocked:
		navigation_blocked_cells[cell] = true

func _create_selection_marker() -> void:
	selection_marker = MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(1.0, 0.04, 1.0)
	selection_marker.mesh = marker_mesh
	selection_material = StandardMaterial3D.new()
	selection_material.albedo_color = Color(0.95, 0.79, 0.24, 0.55)
	selection_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_marker.material_override = selection_material
	selection_marker.visible = false
	add_child(selection_marker)
	preview_entrance_marker = _create_preview_entrance_marker(Color("4ecb71"))
	preview_back_entrance_marker = _create_preview_entrance_marker(Color("30343a"))
	add_child(preview_entrance_marker)
	add_child(preview_back_entrance_marker)
	_move_selection(Vector3.ZERO)

func _create_preview_entrance_marker(color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.32
	mesh.bottom_radius = 0.32
	mesh.height = 0.08
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	marker.material_override = material
	marker.visible = false
	return marker

func _create_forest() -> void:
	var cells := [Vector2i(-16, -15), Vector2i(-15, -18), Vector2i(-18, -12), Vector2i(-12, -19), Vector2i(16, -15), Vector2i(15, -18), Vector2i(18, -12), Vector2i(12, -19), Vector2i(-16, 15), Vector2i(-15, 18), Vector2i(-18, 12), Vector2i(-12, 19), Vector2i(16, 15), Vector2i(15, 18), Vector2i(18, 12), Vector2i(12, 19), Vector2i(-20, -5), Vector2i(-20, 5), Vector2i(20, -5), Vector2i(20, 5), Vector2i(-5, -20), Vector2i(5, -20), Vector2i(-5, 20), Vector2i(5, 20)]
	for cell in cells:
		var tree_position := _cell_center(cell)
		tree_cells[cell] = true
		tree_positions.append(tree_position)
		_create_tree(tree_position)
		_create_grass_sources_near_tree(cell)
		_create_forage_sources_near_tree(cell)
	_refresh_navigation_grid()

func _create_ponds() -> void:
	# Natural ponds are part of the terrain, not a building. Residents cannot fill
	# a bucket automatically, but the player can draw water here once they own one.
	for cell in [Vector2i(-9, 8), Vector2i(10, -7)]:
		var center := _cell_center(cell)
		pond_positions.append(center)
		_create_pond_visual(center)
	_refresh_navigation_grid()

func _create_pond_visual(center: Vector3) -> void:
	var pond := Node3D.new()
	pond.position = center
	add_child(pond)
	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 2.6
	rim_mesh.bottom_radius = 2.6
	rim_mesh.height = 0.3
	rim.mesh = rim_mesh
	rim.position.y = 0.12
	var rim_material := StandardMaterial3D.new()
	rim_material.albedo_color = Color("6f747a")
	rim.material_override = rim_material
	pond.add_child(rim)
	var surface := MeshInstance3D.new()
	var surface_mesh := CylinderMesh.new()
	surface_mesh.top_radius = 2.3
	surface_mesh.bottom_radius = 2.3
	surface_mesh.height = 0.24
	surface.mesh = surface_mesh
	surface.position.y = 0.2
	var surface_material := StandardMaterial3D.new()
	surface_material.albedo_color = Color("3f7fa0")
	surface_material.roughness = 0.2
	surface.material_override = surface_material
	pond.add_child(surface)
	# Ponds and excavated terrain are part of the same routing obstacle map.
	for x in range(-2, 3):
		for z in range(-2, 3):
			terrain_blocked_cells[_cell_from_position(center) + Vector2i(x, z)] = true

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

func _create_tree(position_on_board: Vector3) -> void:
	var tree := Node3D.new()
	tree.position = position_on_board
	tree.set_meta("remaining_wood", random.randi_range(4, 7))
	tree.set_meta("remaining_branches", random.randi_range(5, 9))
	tree.set_meta("hand_branches", 0)
	tree_nodes[_cell_from_position(position_on_board)] = tree
	add_child(tree)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.27
	trunk_mesh.height = 3.6
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.8
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color("684630")
	trunk.material_override = trunk_material
	tree.add_child(trunk)
	for crown_data in [[Vector3(-0.35, 3.75, 0.0), 1.05], [Vector3(0.38, 4.05, 0.1), 1.16], [Vector3(0.0, 4.72, 0.0), 0.96]]:
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = crown_data[1]
		crown_mesh.height = crown_data[1] * 1.35
		crown.mesh = crown_mesh
		crown.position = crown_data[0]
		var crown_material := StandardMaterial3D.new()
		crown_material.albedo_color = Color("2d633b").lightened(random.randf_range(-0.06, 0.08))
		crown.material_override = crown_material
		tree.add_child(crown)

func _create_entrance_stone() -> void:
	entrance_stone = Node3D.new()
	# The entrance is deliberately on the meadow boundary, not in the initial
	# build area: every resident visibly arrives from outside the settlement.
	entrance_stone.position = _cell_center(Vector2i(-22, 1))
	entrance_stone.name = "EntranceSign"
	for x: float in [-0.62, 0.62]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.16, 1.55, 0.16)
		post.mesh = post_mesh
		post.position = Vector3(x, 0.78, 0.0)
		var post_material := StandardMaterial3D.new()
		post_material.albedo_color = Color("5c4033")
		post_material.roughness = 0.95
		post.material_override = post_material
		entrance_stone.add_child(post)
	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(1.8, 0.65, 0.14)
	board.mesh = board_mesh
	board.position = Vector3(0.0, 1.25, 0.0)
	var board_material := StandardMaterial3D.new()
	board_material.albedo_color = Color("8a6549")
	board_material.roughness = 0.9
	board.material_override = board_material
	entrance_stone.add_child(board)
	var label := Label3D.new()
	label.text = "Settlement"
	label.position = Vector3(0.0, 1.26, -0.09)
	label.font_size = 28
	label.modulate = Color("f0dfb2")
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	entrance_stone.add_child(label)
	var selector := Area3D.new()
	selector.add_to_group("entrance_selector")
	selector.collision_layer = 4
	selector.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.4, 1.0)
	collision.shape = shape
	collision.position.y = 1.1
	selector.add_child(collision)
	entrance_stone.add_child(selector)
	add_child(entrance_stone)

func _create_citizens() -> void:
	var spawn_anchor: Vector3 = entrance_stone.global_position + Vector3(0.0, 0.0, 2.0)
	for index in range(POPULATION):
		var spawn_position := spawn_anchor + Vector3(-0.55 + (index % 2) * 1.1, 0.0, (index / 2) * 0.85)
		var terrain_height := _terrain_height_at(spawn_position.x, spawn_position.z, 0.0)
		if not is_nan(terrain_height):
			spawn_position.y = terrain_height + 0.08
		_add_citizen(spawn_position, "unassigned")
	if not citizens.is_empty():
		citizens[random.randi_range(0, citizens.size() - 1)].is_jack_of_all_trades = true

func _add_citizen(spawn_position: Vector3, primary_specialization := "") -> void:
	var citizen := Citizen.new()
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
	citizen.setup_navigation(_find_path_around_houses, _get_nearest_delivery_position, _resolve_building_queue_position, _movement_speed_modifier_at, _navigation_revision, _record_trail_movement, _is_route_reachable, _complete_building_queue_arrival, _release_building_queue_entry)
	citizen.setup_registration_service(_can_start_registration, _registration_duration)
	citizen.resource_delivered.connect(_on_resource_delivered)
	citizen.construction_material_delivered.connect(_on_construction_material_delivered)
	citizen.building_supply_delivered.connect(_on_building_supply_delivered)
	citizen.excavation_cycle.connect(_on_excavation_cycle)
	citizen.resource_ready.connect(_on_resource_ready)
	citizen.tree_harvested.connect(_on_tree_harvested)
	citizen.logs_delivered.connect(_on_logs_delivered)
	citizen.sawmill_boards_collected.connect(_on_sawmill_boards_collected)
	citizen.meal_finished.connect(_on_meal_finished)
	citizen.relief_finished.connect(_on_relief_finished)
	citizen.leisure_finished.connect(_on_leisure_finished)
	citizen.canteen_delivery_finished.connect(_on_canteen_delivery_finished)
	citizen.factory_cycle.connect(_on_factory_cycle)
	citizen.trade_delivery_finished.connect(_on_trade_delivery_finished)
	citizen.employment_processing_finished.connect(_on_employment_processing_finished)
	citizen.arrival_greeter_ready.connect(_on_arrival_greeter_ready)
	citizens.append(citizen)
	citizen.ai_id = _next_ai_citizen_id
	_next_ai_citizen_id += 1
	citizen_ai.register_citizen(citizen.ai_id, SettlementCitizenActuatorScript.new(citizen, _ai_target_for_key))
	citizen.tree_exiting.connect(_on_ai_citizen_exiting.bind(citizen.ai_id), CONNECT_ONE_SHOT)
	if citizens.size() > POPULATION:
		food += random.randi_range(2, 5)
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


func _on_ai_citizen_exiting(citizen_id: int) -> void:
	if trail_field != null:
		trail_field.forget_walker(citizen_id)
	if is_instance_valid(citizen_ai):
		citizen_ai.unregister_citizen(citizen_id)
	if canteen_service != null:
		canteen_service.remove_citizen(citizen_id)
	if citizen_needs_service != null:
		citizen_needs_service.remove_citizen(citizen_id)


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


func _on_leisure_finished(citizen: Citizen) -> void:
	if citizen_needs_service != null:
		citizen_needs_service.fulfill_rest(citizen.ai_id)


func _create_interface() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	# Resources: a compact vertical list in its own small panel.
	var panel := ColorRect.new()
	panel.color = Color(0.035, 0.07, 0.09, 0.88)
	panel.position = Vector2(20, 20)
	panel.size = Vector2(172, 256)
	ui.add_child(panel)
	wood_label = Label.new()
	wood_label.position = Vector2(14, 10)
	wood_label.size = Vector2(150, 240)
	wood_label.add_theme_font_size_override("font_size", 12)
	panel.add_child(wood_label)
	labor_authority_label = Label.new()
	labor_authority_label.position = Vector2(205, 20)
	labor_authority_label.size = Vector2(260, 48)
	labor_authority_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labor_authority_label.add_theme_font_size_override("font_size", 14)
	labor_authority_label.visible = false
	ui.add_child(labor_authority_label)
	# Hidden status label — kept for backward compatibility.
	status_label = Label.new()
	status_label.visible = false
	ui.add_child(status_label)
	# Message log panel — bottom-left.
	_create_message_panel(ui)
	_create_messages_modal(ui)
	camera_hint_label = Label.new()
	camera_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	camera_hint_label.offset_left = 20
	camera_hint_label.offset_top = -30
	camera_hint_label.offset_right = 800
	camera_hint_label.offset_bottom = -6
	camera_hint_label.add_theme_font_size_override("font_size", 14)
	ui.add_child(camera_hint_label)
	clock_label = Label.new()
	clock_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock_label.offset_left = -220
	clock_label.offset_top = 22
	clock_label.offset_right = -22
	clock_label.offset_bottom = 52
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_label.add_theme_font_size_override("font_size", 22)
	ui.add_child(clock_label)
	_create_time_controls(ui)
	interaction_hint_label = Label.new()
	interaction_hint_label.position = Vector2(20, 592)
	interaction_hint_label.size = Vector2(500, 28)
	interaction_hint_label.add_theme_font_size_override("font_size", 18)
	interaction_hint_label.visible = false
	ui.add_child(interaction_hint_label)
	interaction_progress = ProgressBar.new()
	interaction_progress.position = Vector2(20, 625)
	interaction_progress.size = Vector2(310, 22)
	interaction_progress.show_percentage = false
	interaction_progress.visible = false
	ui.add_child(interaction_progress)
	var build_toggle_btn := Button.new()
	build_toggle_btn.text = "Construction Panel"
	build_toggle_btn.position = Vector2(20, 388)
	build_toggle_btn.size = Vector2(180, 36)
	build_toggle_btn.pressed.connect(_toggle_global_build_menu)
	ui.add_child(build_toggle_btn)
	
	_create_build_menu(ui)
	_create_entrance_menu(ui)
	_create_house_menu(ui)
	_create_school_menu(ui)
	_create_materials_factory_menu(ui)
	_create_campfire_menu(ui)
	_create_market_menu(ui)
	_create_warehouse_menu(ui)
	_create_building_menu(ui)
	_create_workforce_menu(ui)
	_create_research_menu(ui)
	_create_campfire_orders_menu(ui)
	_create_survival_decision_menu(ui)


func _create_survival_decision_menu(ui: CanvasLayer) -> void:
	decision_menu = Panel.new()
	decision_menu.set_anchors_preset(Control.PRESET_CENTER)
	decision_menu.offset_left = -240.0
	decision_menu.offset_top = -150.0
	decision_menu.offset_right = 240.0
	decision_menu.offset_bottom = 150.0
	decision_menu.visible = false
	ui.add_child(decision_menu)
	decision_title = Label.new()
	decision_title.position = Vector2(20, 18)
	decision_title.size = Vector2(440, 28)
	decision_title.add_theme_font_size_override("font_size", 19)
	decision_menu.add_child(decision_title)
	decision_description = Label.new()
	decision_description.position = Vector2(20, 58)
	decision_description.size = Vector2(440, 116)
	decision_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	decision_menu.add_child(decision_description)
	decision_primary_button = Button.new()
	decision_primary_button.position = Vector2(20, 194)
	decision_primary_button.size = Vector2(440, 32)
	decision_primary_button.pressed.connect(_resolve_survival_decision.bind(true))
	decision_menu.add_child(decision_primary_button)
	decision_secondary_button = Button.new()
	decision_secondary_button.position = Vector2(20, 236)
	decision_secondary_button.size = Vector2(440, 32)
	decision_secondary_button.pressed.connect(_resolve_survival_decision.bind(false))
	decision_menu.add_child(decision_secondary_button)


func _maybe_present_survival_decision() -> void:
	if settlement.era != SettlementState.Era.TENT or decision_menu == null or decision_menu.visible:
		return
	if tent_weather == TentEraSurvivalRulesScript.Weather.RAIN and branches > 0:
		pending_survival_decision = "protect_firewood"
		decision_title.text = "Threat of wet firewood"
		decision_description.text = "The open storage will be soaked by rain. Protect the branch supply for three hours, or keep everyone working and risk smoky fires tomorrow."
		decision_primary_button.text = "Assign a resident to protect the firewood"
		decision_secondary_button.text = "Ignore the risk"
		decision_menu.visible = true
	elif random.randf() < 0.35:
		pending_survival_decision = "forest_gifts"
		decision_title.text = "Unknown forest gifts"
		decision_description.text = "Foragers found unfamiliar berries. They may lift the camp's spirits or poison one resident for a day."
		decision_primary_button.text = "Try the berries"
		decision_secondary_button.text = "Discard them"
		decision_menu.visible = true


func _resolve_survival_decision(accept: bool) -> void:
	if pending_survival_decision == "protect_firewood":
		if accept:
			protected_firewood_day = day_cycle.current_day
			_assign_survival_busy_worker(3.0, "Protecting firewood")
			_add_message("A resident is protecting the firewood from rain.")
		else:
			smoky_firewood_day = day_cycle.current_day + 1
			_add_message("The firewood was left exposed and will smoke tomorrow.")
	elif pending_survival_decision == "forest_gifts" and accept:
		if random.randf() < 0.5:
			wellbeing = mini(100, wellbeing + 20)
			_add_message("The berries were safe. Wellbeing rose by 20.")
		else:
			_assign_survival_busy_worker(24.0, "Poisoned")
			_add_message("The berries were poisonous. One resident cannot work for 24 hours.")
	elif pending_survival_decision == "forest_gifts":
		_add_message("The unknown berries were discarded.")
	pending_survival_decision = ""
	decision_menu.visible = false


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

func _create_time_controls(ui: CanvasLayer) -> void:
	var controls := HBoxContainer.new()
	controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	controls.offset_left = -220
	controls.offset_top = 58
	controls.offset_right = -22
	controls.offset_bottom = 90
	controls.alignment = BoxContainer.ALIGNMENT_END
	ui.add_child(controls)
	for multiplier in [1.0, 2.0, 5.0]:
		var button := Button.new()
		button.text = "x%d" % int(multiplier)
		button.tooltip_text = "Simulation speed x%d" % int(multiplier)
		button.custom_minimum_size = Vector2(56, 30)
		button.pressed.connect(_set_time_multiplier.bind(multiplier))
		controls.add_child(button)
	# Appears as soon as the selected workday is over, including the evening
	# hours before the world is considered night.
	skip_night_button = Button.new()
	skip_night_button.text = "Skip night »"
	skip_night_button.tooltip_text = "Jump to the next morning (06:00)"
	skip_night_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_night_button.offset_left = -220
	skip_night_button.offset_top = 96
	skip_night_button.offset_right = -22
	skip_night_button.offset_bottom = 128
	skip_night_button.visible = false
	skip_night_button.pressed.connect(_skip_night)
	ui.add_child(skip_night_button)
	start_workday_button = Button.new()
	start_workday_button.text = "К началу рабочего дня"
	start_workday_button.tooltip_text = "Jump to 08:00"
	start_workday_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	start_workday_button.offset_left = -220
	start_workday_button.offset_top = 96
	start_workday_button.offset_right = -22
	start_workday_button.offset_bottom = 128
	start_workday_button.visible = false
	start_workday_button.pressed.connect(_skip_to_workday_start)
	ui.add_child(start_workday_button)


func _can_skip_night() -> bool:
	if settlement.night_shifts_allowed:
		return false
	var hour := clock.hour()
	return hour >= 8 + settlement.workday_hours or hour < 6


func _can_skip_to_workday_start() -> bool:
	if settlement.night_shifts_allowed:
		return false
	var hour := clock.hour()
	return hour >= 6 and hour < 8


func _update_skip_night_button() -> void:
	if skip_night_button != null:
		skip_night_button.visible = _can_skip_night()
	if start_workday_button != null:
		start_workday_button.visible = _can_skip_to_workday_start()


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
	for survival_hour in _skip_night_survival_hours():
		_apply_hourly_tent_survival(int(survival_hour.hour), int(survival_hour.day))
	day_cycle.current_day = target_day
	tent_weather = TentEraSurvivalRulesScript.weather_for_day(day_cycle.current_day)
	clock.set_time(6 * 60)
	# Living through the night crosses 06:00, when the daily water/food sink runs and
	# frees storage. Skipping must apply the same rules, otherwise stores stay full,
	# no production is assignable, and workers have nothing to wake up for.
	_expire_temporary_tents()
	_refresh_living_statuses()
	_apply_daily_settlement_rules()
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
	settlement.workday_hours = hours
	_update_skip_night_button()
	_update_interface("Workday set to %d hours." % hours)

func _set_night_shifts(enabled: bool) -> void:
	settlement.night_shifts_allowed = enabled
	_update_skip_night_button()
	_update_interface("Night shifts %s." % ("allowed" if enabled else "disabled"))

func _set_time_multiplier(multiplier: float) -> void:
	time_multiplier = multiplier
	if is_first_person:
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = multiplier
	_update_interface("Simulation speed set to x%d." % int(multiplier))

func _create_build_menu(ui: CanvasLayer) -> void:
	build_menu = Panel.new()
	build_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	build_menu.offset_left = -324.0
	build_menu.offset_top = -780.0
	build_menu.offset_right = -20.0
	build_menu.offset_bottom = -20.0
	build_menu.visible = false
	ui.add_child(build_menu)
	
	build_menu_title = Label.new()
	build_menu_title.position = Vector2(16, 14)
	build_menu_title.size = Vector2(272, 74)
	build_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_menu_title.add_theme_font_size_override("font_size", 15)
	build_menu.add_child(build_menu_title)

	manage_citizen_button = Button.new()
	manage_citizen_button.text = "Управлять"
	manage_citizen_button.position = Vector2(16, 96)
	manage_citizen_button.size = Vector2(272, 30)
	manage_citizen_button.pressed.connect(_take_control_of_selected_citizen)
	build_menu.add_child(manage_citizen_button)
	
	# Add the citizen assignment submenus.
	daily_order_submenu_btn = Button.new()
	daily_order_submenu_btn.text = "Daily Orders..."
	daily_order_submenu_btn.position = Vector2(16, 276)
	daily_order_submenu_btn.size = Vector2(272, 30)
	daily_order_submenu_btn.pressed.connect(_open_daily_order_submenu)
	build_menu.add_child(daily_order_submenu_btn)

	job_submenu_btn = Button.new()
	job_submenu_btn.text = "Permanent Jobs..."
	job_submenu_btn.position = Vector2(16, 310)
	job_submenu_btn.size = Vector2(272, 30)
	job_submenu_btn.pressed.connect(_open_job_submenu)
	build_menu.add_child(job_submenu_btn)
	
	# Job Back Button
	job_back_btn = Button.new()
	job_back_btn.text = "Back to categories"
	job_back_btn.position = Vector2(16, 96)
	job_back_btn.size = Vector2(272, 30)
	job_back_btn.pressed.connect(_close_assignment_submenu)
	build_menu.add_child(job_back_btn)
	
	# Daily orders do not require an employment officer.
	_add_role_button("Clear daily order", "", 136, false, "daily")
	_add_role_button("Helper", "helper", 170, false, "daily")
	_add_role_button("Construction", "construction", 204, false, "daily")
	_add_role_button("Gather branches", "gather_branches", 238, false, "daily")
	_add_role_button("Gather grass", "gather_grass", 272, false, "daily")
	_add_role_button("Forage food", "gather_food", 306, false, "daily")
	_add_role_button("Collect dew", "gather_dew", 340, false, "daily")
	_add_role_button("Collect water", "gather_water", 374, false, "daily")

	# Permanent jobs require an employment officer, except appointing the officer.
	_add_role_button("Assign: construction", "construction", 136, false, "job")
	_add_role_button("Assign: forestry (logs/timber)", "forestry", 170, false, "job")
	_add_role_button("Assign: farming", "farming", 204, false, "job")
	_add_role_button("Assign: excavation", "excavation", 238, false, "job")
	_add_role_button("Assign: gather branches", "gather_branches", 272, false, "job")
	_add_role_button("Assign: forage food", "gather_food", 306, false, "job")
	_add_role_button("Assign: courier", "courier", 340, false, "job")
	_add_role_button("Assign: craftsman", "craftsman", 374, false, "job")
	_add_role_button("Assign: employment officer", "official", 408, false, "job")
	
	# Era category buttons (shown on main build menu)
	_add_build_category_button("Tent era", "tent", 136)
	_add_build_category_button("Earth era", "earth", 170)
	_add_build_category_button("Clay era", "clay", 204)
	_add_build_category_button("Wooden era", "wood", 238)
	_add_build_category_button("Stone era", "stone", 272)
	_add_build_category_button("Brick era", "brick", 306)
	_add_build_category_back_button()
	
	_add_build_button("Campfire", "campfire", 176, "tent")
	_add_build_button("Campfire Level 2", "campfire_lvl2", 200, "tent")
	_add_build_button("Campfire Level 3", "campfire_lvl3", 200, "tent")
	_add_build_button("Бадминтонная площадка", "gathering_place", 193, "tent")
	_add_build_button("Костер для готовки ур. 1", "cook_campfire", 227, "tent")
	_add_build_button("Временная палатка на 4 жителя", "tent", 244, "tent")
	_add_build_button("Жилая палатка на 1 жителя", "living_tent", 278, "tent")
	_add_build_button("Жилая палатка ур. 2", "living_tent_lvl2", 278, "tent")
	_add_build_button("Жилая палатка ур. 3", "living_tent_lvl3", 278, "tent")
	_add_build_button("Forager tent", "forager_tent", 312, "tent")
	_add_build_button("Forager-Hunter tent", "forager_tent_lvl2", 200, "tent")
	_add_build_button("Hunting lodge", "forager_tent_lvl3", 200, "tent")
	_add_build_button("Двор стройматериалов", "materials_yard", 312, "tent")
	_add_build_button("Двор стройматериалов ур. 2", "materials_yard_lvl2", 200, "tent")
	_add_build_button("Двор стройматериалов ур. 3", "materials_yard_lvl3", 200, "tent")
	_add_build_button("Craft tent", "craft_tent", 346, "tent")
	_add_build_button("Craft tent Level 2", "craft_tent_lvl2", 346, "tent")
	_add_build_button("Craft tent Level 3", "craft_tent_lvl3", 346, "tent")
	_add_build_button("Dew collector", "dew_collector", 380, "tent")
	_add_build_button("Dew collector Level 2", "dew_collector_lvl2", 200, "tent")
	_add_build_button("Dew collector Level 3", "dew_collector_lvl3", 200, "tent")
	_add_build_button("Куча материалов (Склад ур. 1)", "warehouse", 414, "tent")
	_add_build_button("Склад ур. 2 (Палатка)", "warehouse_lvl2", 200, "tent")
	_add_build_button("Trade tent", "trade_tent", 448, "tent")
	_add_build_button("Общественный туалет ур. 1", "toilet_tent", 482, "tent")
	_add_build_button("Общественный туалет ур. 2", "toilet_tent_lvl2", 516, "tent")
	_add_build_button("Общественный туалет ур. 3", "toilet_tent_lvl3", 550, "tent")
	
	_add_build_button("Dugout", "dugout", 176, "earth")
	_add_build_button("Earth house", "earth_house", 210, "earth")
	_add_build_button("Smithy", "smithy", 244, "earth")
	_add_build_button("Hide workshop", "hide_worker", 278, "earth")
	_add_build_button("Earth market", "earth_market", 312, "earth")
	_add_build_button("Earth Assembly", "earth_assembly", 346, "earth")
	_add_build_button("Dugout kitchen", "dugout_kitchen", 380, "earth")
	_add_build_button("Земляной туалет ур. 1", "toilet_earth", 414, "earth")
	_add_build_button("Земляной туалет ур. 2", "toilet_earth_lvl2", 448, "earth")
	_add_build_button("Земляной туалет ур. 3", "toilet_earth_lvl3", 482, "earth")
	
	_add_build_button("Clay house", "clay_house", 176, "clay")
	_add_build_button("Clay workshop", "clay_workshop", 210, "clay")
	_add_build_button("Clay market", "clay_market", 244, "clay")
	_add_build_button("Clay lodge", "clay_lodge", 278, "clay")
	_add_build_button("Clay bakery", "clay_bakery", 312, "clay")
	_add_build_button("School", "school", 346, "clay")
	_add_build_button("Глиняный туалет ур. 1", "toilet_clay", 380, "clay")
	_add_build_button("Глиняный туалет ур. 2", "toilet_clay_lvl2", 414, "clay")
	_add_build_button("Глиняный туалет ур. 3", "toilet_clay_lvl3", 448, "clay")
	
	_add_build_button("Sawmill - logs + kit", "sawmill", 176, "wood")
	_add_build_button("Farm", "farm", 210, "wood")
	_add_build_button("Canteen", "canteen", 244, "wood")
	_add_build_button("Wood house", "house", 278, "wood")
	_add_build_button("Wood house Level 2", "house_lvl2", 278, "wood")
	_add_build_button("Wood house Level 3", "house_lvl3", 278, "wood")
	_add_build_button("Park", "park", 312, "wood")
	_add_build_button("Wood market", "wood_market", 346, "wood")
	_add_build_button("Wooden town hall", "wood_town_hall", 380, "wood")
	_add_build_button("Деревянный туалет ур. 1", "toilet_wood", 414, "wood")
	_add_build_button("Деревянный туалет ур. 2", "toilet_wood_lvl2", 448, "wood")
	_add_build_button("Деревянный туалет ур. 3", "toilet_wood_lvl3", 482, "wood")
	
	_add_build_button("Stone house", "stone_house", 176, "stone")
	_add_build_button("Masonry workshop", "masonry_workshop", 210, "stone")
	_add_build_button("Stone market", "stone_market", 244, "stone")
	_add_build_button("Stone prefecture", "stone_prefecture", 278, "stone")
	_add_build_button("Stone tavern", "stone_tavern", 312, "stone")
	_add_build_button("Гильдия строителей", "builders_guild", 346, "stone")
	_add_build_button("Каменный туалет ур. 1", "toilet_stone", 380, "stone")
	_add_build_button("Каменный туалет ур. 2", "toilet_stone_lvl2", 414, "stone")
	_add_build_button("Каменный туалет ур. 3", "toilet_stone_lvl3", 448, "stone")
	
	_add_build_button("Brick kiln", "brick_factory", 176, "brick")
	_add_build_button("Materials factory", "materials_factory", 210, "brick")
	_add_build_button("Brick market", "brick_market", 244, "brick")
	_add_build_button("Brick City Hall", "brick_city_hall", 278, "brick")
	_add_build_button("Brick restaurant", "brick_restaurant", 312, "brick")
	_add_build_button("Brick house", "brick_house", 346, "brick")
	_add_build_button("Строительная фирма", "construction_company", 380, "brick")
	_add_build_button("Кирпичный туалет ур. 1", "toilet_brick", 414, "brick")
	_add_build_button("Кирпичный туалет ур. 2", "toilet_brick_lvl2", 448, "brick")
	_add_build_button("Кирпичный туалет ур. 3", "toilet_brick_lvl3", 482, "brick")

	_refresh_build_menu()

func _create_school_menu(ui: CanvasLayer) -> void:
	school_menu = Panel.new()
	school_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	school_menu.offset_left = -520.0
	school_menu.offset_top = -550.0
	school_menu.offset_right = -20.0
	school_menu.offset_bottom = -20.0
	school_menu.visible = false
	ui.add_child(school_menu)
	
	school_menu_title = Label.new()
	school_menu_title.position = Vector2(16, 14)
	school_menu_title.size = Vector2(220, 72)
	school_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	school_menu_title.add_theme_font_size_override("font_size", 13)
	school_menu.add_child(school_menu_title)
	
	var dev_title := Label.new()
	dev_title.text = "Global Skill Development\n(Check to train all in morning):"
	dev_title.position = Vector2(250, 14)
	dev_title.size = Vector2(250, 72)
	dev_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dev_title.add_theme_font_size_override("font_size", 13)
	school_menu.add_child(dev_title)
	
	var roles := [
		["Construction", "construction"],
		["Forestry", "forestry"],
		["Farming", "farming"],
		["Excavation", "excavation"],
		["Factory worker", "factory_worker"],
		["Engineer", "engineer"],
		["Cook", "cook"],
		["Teacher", "teacher"],
		["Seller", "seller"]
	]
	
	school_retrain_buttons.clear()
	for index in range(roles.size()):
		var button := Button.new()
		button.text = "Train: %s" % roles[index][0]
		button.position = Vector2(16, 94 + index * 42)
		button.size = Vector2(220, 32)
		button.pressed.connect(_start_school_training.bind(roles[index][1]))
		school_menu.add_child(button)
		school_retrain_buttons.append(button)
		
	school_dev_checkboxes.clear()
	for index in range(roles.size()):
		var role_id: String = roles[index][1]
		var cb := CheckBox.new()
		cb.text = "Develop %s" % roles[index][0]
		cb.position = Vector2(250, 94 + index * 42)
		cb.size = Vector2(250, 32)
		cb.toggled.connect(func(pressed: bool): _toggle_school_development(role_id, pressed))
		school_menu.add_child(cb)
		school_dev_checkboxes[role_id] = cb
		
	var demolish_btn := Button.new()
	demolish_btn.text = "Demolish School"
	demolish_btn.position = Vector2(16, 480)
	demolish_btn.size = Vector2(220, 32)
	demolish_btn.pressed.connect(func():
		if selected_school != null:
			_mark_building_for_demolition(selected_school)
			school_menu.visible = false
	)
	school_menu.add_child(demolish_btn)
	
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(250, 480)
	close_btn.size = Vector2(250, 32)
	close_btn.pressed.connect(func(): school_menu.visible = false)
	school_menu.add_child(close_btn)

func _toggle_school_development(role: String, pressed: bool) -> void:
	if not _player_can_command_labor():
		_show_labor_command_blocked()
		return
	school_developed_professions[role] = pressed
	if pressed:
		_update_interface("School developed: all %ss will train in mornings." % role.capitalize())
	else:
		_update_interface("Stopped school training for %ss." % role.capitalize())

func _start_school_training(role: String) -> void:
	if not _player_can_command_labor():
		_show_labor_command_blocked()
		return
	if selected_builder == null or selected_school == null:
		return
	selected_builder.start_training(role, selected_school.global_position)
	school_menu.visible = false
	_update_interface("Training started: 10 mornings in school, then regular work.")

func _show_school_menu() -> void:
	if selected_school == null:
		return
	build_menu.visible = false
	house_menu.visible = false
	building_menu.visible = false
	
	var can_command_labor := _player_can_command_labor()
	var blocked_tooltip := _labor_command_block_message()
	if selected_builder != null:
		school_menu_title.text = "Student: %s\nSelect individual retraining (takes 10 mornings):" % selected_builder.role_label()
		for btn in school_retrain_buttons:
			btn.disabled = not can_command_labor
			btn.tooltip_text = blocked_tooltip if btn.disabled else ""
	else:
		school_menu_title.text = "Student: None\n(Select a resident first to enable retraining)"
		for btn in school_retrain_buttons:
			btn.disabled = true
			btn.tooltip_text = blocked_tooltip if not can_command_labor else "Select a resident first."
			
	for role in school_developed_professions:
		if school_dev_checkboxes.has(role):
			var cb: CheckBox = school_dev_checkboxes[role]
			cb.set_block_signals(true)
			cb.button_pressed = school_developed_professions[role]
			cb.set_block_signals(false)
			cb.disabled = not can_command_labor
			cb.tooltip_text = blocked_tooltip if cb.disabled else ""
			
	school_menu.visible = true
	_update_interface("School selected: configure morning study and retraining here.")

func _create_entrance_menu(ui: CanvasLayer) -> void:
	entrance_menu = Panel.new()
	entrance_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	entrance_menu.offset_left = -324.0
	entrance_menu.offset_top = -292.0
	entrance_menu.offset_right = -20.0
	entrance_menu.offset_bottom = -20.0
	entrance_menu.visible = false
	ui.add_child(entrance_menu)
	entrance_menu_title = Label.new()
	entrance_menu_title.position = Vector2(16, 14)
	entrance_menu_title.size = Vector2(272, 56)
	entrance_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entrance_menu_title.add_theme_font_size_override("font_size", 16)
	entrance_menu.add_child(entrance_menu_title)
	var food_button := Button.new()
	food_button.text = "Order food"
	food_button.tooltip_text = "Order 4 food; a Helper or Courier makes the trip."
	food_button.position = Vector2(16, 82)
	food_button.size = Vector2(272, 32)
	food_button.pressed.connect(func(): trade_service.buy_entrance_food(4, FOOD_PURCHASE_PRICE))
	entrance_menu.add_child(food_button)
	var gloves_button := Button.new()
	gloves_button.text = "Order construction gloves"
	gloves_button.tooltip_text = "Order one construction glove set."
	gloves_button.position = Vector2(16, 122)
	gloves_button.size = Vector2(272, 32)
	gloves_button.pressed.connect(func(): trade_service.buy_entrance_gloves(ENTRANCE_GLOVE_PRICE))
	entrance_menu.add_child(gloves_button)
	var work_button := Button.new()
	work_button.text = "Send selected resident to outside work"
	work_button.tooltip_text = "Requires a Helper or Courier. The resident leaves for one full day and returns with 8 coins."
	work_button.position = Vector2(16, 162)
	work_button.size = Vector2(272, 32)
	work_button.pressed.connect(_send_selected_resident_to_outside_work)
	entrance_menu.add_child(work_button)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(16, 210)
	close_btn.size = Vector2(272, 30)
	close_btn.pressed.connect(_close_context_menus)
	entrance_menu.add_child(close_btn)


func _show_entrance_menu() -> void:
	if not is_instance_valid(selected_entrance):
		return
	var resident_name := selected_builder.role_label() if is_instance_valid(selected_builder) else "no resident selected"
	entrance_menu_title.text = "Entrance sign\nEmergency orders. Outside work: %s" % resident_name
	entrance_menu.visible = true

func _send_selected_resident_to_outside_work() -> void:
	if not is_instance_valid(selected_builder) or selected_builder.is_player_controlled:
		_update_interface("Select an AI-controlled Helper or Courier before sending them to outside work.")
		return
	if not selected_builder.is_courier() and selected_builder.daily_order_role != "helper":
		_update_interface("Outside work requires a daily Helper or a Courier.")
		return
	var worker_id := selected_builder.get_instance_id()
	if outside_workers.has(worker_id):
		_update_interface("This resident is already working in a neighboring settlement.")
		return
	selected_builder.cancel_current_action()
	selected_builder.visible = false
	selected_builder.process_mode = Node.PROCESS_MODE_DISABLED
	outside_workers[worker_id] = {
		"citizen": selected_builder,
		"return_at_minute": _absolute_game_minutes() + OUTSIDE_WORK_DURATION_MINUTES,
	}
	if citizen_ai != null:
		citizen_ai.request_decision_refresh()
	_update_interface("Resident left for outside work and will return in 24 hours with %d coins." % OUTSIDE_WORK_REWARD)

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
		if is_instance_valid(worker):
			worker.process_mode = Node.PROCESS_MODE_INHERIT
			worker.visible = true
			worker.global_position = entrance_stone.global_position + Vector3(0.8, 0.08, 1.2)
			worker.idle()
			settlement.money += OUTSIDE_WORK_REWARD
			last_citizen_positions[worker_id] = worker.global_position
		outside_workers.erase(worker_id)
		returned_any = true
		_update_interface("A resident returned from outside work with %d coins." % OUTSIDE_WORK_REWARD)
	if returned_any and citizen_ai != null:
		citizen_ai.request_decision_refresh()


func _create_house_menu(ui: CanvasLayer) -> void:
	house_menu = Panel.new()
	house_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	house_menu.offset_left = -324.0
	house_menu.offset_top = -378.0
	house_menu.offset_right = -20.0
	house_menu.offset_bottom = -20.0
	house_menu.visible = false
	ui.add_child(house_menu)
	house_menu_title = Label.new()
	house_menu_title.position = Vector2(16, 14)
	house_menu_title.size = Vector2(272, 42)
	house_menu_title.add_theme_font_size_override("font_size", 17)
	house_menu.add_child(house_menu_title)
	house_spawn_button = Button.new()
	house_spawn_button.text = "Order a resident"
	house_spawn_button.tooltip_text = "A Helper or Courier will meet the newcomer at the entrance sign."
	house_spawn_button.position = Vector2(16, 64)
	house_spawn_button.size = Vector2(272, 30)
	house_spawn_button.pressed.connect(_spawn_house_citizen)
	house_menu.add_child(house_spawn_button)
	var demolish_button := Button.new()
	demolish_button.text = "Mark for demolition"
	demolish_button.position = Vector2(16, 140)
	demolish_button.size = Vector2(272, 30)
	demolish_button.pressed.connect(func(): _mark_building_for_demolition(selected_house))
	house_menu.add_child(demolish_button)
	house_menu.offset_top = -490.0

func _create_materials_factory_menu(ui: CanvasLayer) -> void:
	materials_factory_menu = Panel.new()
	materials_factory_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	materials_factory_menu.offset_left = -324.0
	materials_factory_menu.offset_top = -260.0
	materials_factory_menu.offset_right = -20.0
	materials_factory_menu.offset_bottom = -20.0
	materials_factory_menu.visible = false
	ui.add_child(materials_factory_menu)
	materials_factory_menu_title = Label.new()
	materials_factory_menu_title.position = Vector2(16, 14)
	materials_factory_menu_title.size = Vector2(272, 94)
	materials_factory_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	materials_factory_menu.add_child(materials_factory_menu_title)
	var research_button := Button.new()
	research_button.text = "Research brick construction"
	research_button.position = Vector2(16, 120)
	research_button.size = Vector2(272, 32)
	research_button.pressed.connect(_start_brick_research)
	materials_factory_menu.add_child(research_button)

func _show_materials_factory_menu() -> void:
	if selected_materials_factory == null:
		return
	materials_factory_menu.visible = true
	if brick_construction_unlocked:
		materials_factory_menu_title.text = "Materials factory\nBrick construction unlocked."
	elif brick_research_progress >= 0.0:
		materials_factory_menu_title.text = "Materials factory\nResearch: %d%%" % roundi(brick_research_progress * 100.0)
	else:
		materials_factory_menu_title.text = "Materials factory\nNeeds factory worker, builder and engineer.\nResearch cost: %d bricks, %d boards." % [BuildingCatalog.research_cost("brick_construction", "bricks"), BuildingCatalog.research_cost("brick_construction", "boards")]

func _start_brick_research() -> void:
	if selected_materials_factory == null or brick_construction_unlocked or brick_research_progress >= 0.0:
		return
	if not _materials_factory_staffed(selected_materials_factory):
		_update_interface("Research needs a factory worker, builder and engineer assigned to this factory.")
		return
	var brick_cost := BuildingCatalog.research_cost("brick_construction", "bricks")
	var board_cost := BuildingCatalog.research_cost("brick_construction", "boards")
	if not settlement.can_afford_research("brick_construction"):
		_update_interface("Research needs %d bricks and %d boards." % [brick_cost, board_cost])
		return
	settlement.pay_for_research("brick_construction")
	brick_research_progress = 0.0
	brick_research_factory = selected_materials_factory
	_show_materials_factory_menu()
	_update_interface("Brick construction research started.")

func _update_brick_research(delta: float) -> void:
	if brick_research_progress < 0.0 or brick_construction_unlocked:
		return
	if not is_instance_valid(brick_research_factory) or not _materials_factory_staffed(brick_research_factory):
		if materials_factory_menu != null and materials_factory_menu.visible:
			_show_materials_factory_menu()
		return
	
	var speed_mult := 1.0
	for citizen in citizens:
		if citizen.factory == brick_research_factory and citizen.specialization == "engineer" and citizen.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]:
			if citizen.skills.get("engineer", 0.0) >= 1.0:
				speed_mult = 1.30
				break

	brick_research_progress = minf(1.0, brick_research_progress + (delta * speed_mult) / BRICK_RESEARCH_DURATION)
	if brick_research_progress >= 1.0:
		brick_construction_unlocked = true
		brick_research_progress = -1.0
		brick_research_factory = null
		_update_interface("Brick construction unlocked: recycling, metal, city hall and leisure center are available.")
	if materials_factory_menu != null and materials_factory_menu.visible:
		_show_materials_factory_menu()

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
		if citizen.get_instance_id() == settlement.active_research_worker_id:
			worker = citizen
			break
			
	if worker == null:
		_cancel_active_building_research(true, "Research cancelled: researcher citizen is no longer available. Resources refunded.")
		return
	if worker.state != Citizen.State.RESEARCHING:
		_cancel_active_building_research(true, "Research cancelled: researcher stopped working. Resources refunded.")
		return
		
	var skill_name: String = tech.required_skill
	var skill_val := float(worker.skills.get(skill_name, 0.0))
	var speed_mult := 1.0 + skill_val
	
	if worker.global_position.distance_to(campfire_node.get_meta("service_position", campfire_node.global_position)) > 0.15:
		return
	building_research_service.advance_active(delta, speed_mult)
	
	if research_menu != null and research_menu.visible:
		_refresh_research_menu()

	if building_research_service.is_active_complete():
		var completion: Dictionary = building_research_service.complete_active()
		var skill_to_upgrade: String = str(completion.get("reward_skill", "construction"))
		worker.skills[skill_to_upgrade] = minf(1.0, float(worker.skills.get(skill_to_upgrade, 0.0)) + 0.20)

		worker.idle()
		var b_name := str(completion.get("display_name", tech_id))
		_update_interface("Research completed: %s unlocked! %s skill improved by 20%%." % [b_name, skill_to_upgrade.capitalize()])
		
		_refresh_campfire_menu()
		_refresh_build_menu()
		if research_menu != null and research_menu.visible:
			_refresh_research_menu()

func _create_research_menu(ui: CanvasLayer) -> void:
	research_menu = Panel.new()
	research_menu.set_anchors_preset(Control.PRESET_CENTER)
	research_menu.offset_left = -250.0
	research_menu.offset_top = -250.0
	research_menu.offset_right = 250.0
	research_menu.offset_bottom = 250.0
	research_menu.visible = false
	ui.add_child(research_menu)
	
	research_menu_title = Label.new()
	research_menu_title.position = Vector2(18, 16)
	research_menu_title.size = Vector2(464, 30)
	research_menu_title.add_theme_font_size_override("font_size", 18)
	research_menu.add_child(research_menu_title)
	
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(18, 54)
	scroll.size = Vector2(464, 330)
	research_menu.add_child(scroll)
	
	research_list = VBoxContainer.new()
	research_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	research_list.add_theme_constant_override("separation", 8)
	scroll.add_child(research_list)
	
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(18, 398)
	close_btn.size = Vector2(464, 32)
	close_btn.pressed.connect(_hide_research_menu)
	research_menu.add_child(close_btn)

func _show_research_menu() -> void:
	if research_menu == null:
		return
	research_menu.visible = true
	_refresh_research_menu()

func _hide_research_menu() -> void:
	if research_menu != null:
		research_menu.visible = false

func _get_available_researcher(required_skill: String) -> Citizen:
	var best_researcher: Citizen = null
	var best_skill_val := -1.0
	for citizen in citizens:
		if citizen.is_player_controlled or citizen.state != Citizen.State.IDLE:
			continue
		var skill_val := float(citizen.skills.get(required_skill, 0.0))
		if skill_val > best_skill_val:
			best_researcher = citizen
			best_skill_val = skill_val
	return best_researcher

func _refresh_research_menu() -> void:
	if research_menu == null or research_list == null:
		return
	for child in research_list.get_children():
		child.queue_free()

	research_menu_title.text = "Research (Campfire)"

	for tech_id in building_research_service.visible_tech_ids():
		var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[tech_id]
		var researcher := _get_available_researcher(str(tech.get("required_skill", "construction")))
		var research_state: Dictionary = building_research_service.menu_state(tech_id, researcher != null)

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(464, 40)
		research_list.add_child(row)

		var details_vbox := VBoxContainer.new()
		details_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details_vbox)

		var title_lbl := Label.new()
		title_lbl.text = tech.name
		title_lbl.add_theme_font_size_override("font_size", 14)
		details_vbox.add_child(title_lbl)

		var desc_lbl := Label.new()
		var effect_str: String = str(tech.get("effect", ""))
		desc_lbl.text = "Duration: %ds | Cost: %s | Skill: %s%s" % [int(research_state.duration), str(research_state.cost_text), str(research_state.required_skill).capitalize(), " | %s" % effect_str if not effect_str.is_empty() else ""]
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color("a5b5c5"))
		details_vbox.add_child(desc_lbl)

		if bool(research_state.completed):
			var status_lbl := Label.new()
			status_lbl.text = "Researched"
			status_lbl.add_theme_color_override("font_color", Color("76c893"))
			row.add_child(status_lbl)
		elif bool(research_state.active):
			var progress_vbox := VBoxContainer.new()
			progress_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(progress_vbox)

			var progress_lbl := Label.new()
			progress_lbl.text = "Researching: %d%%" % int(research_state.progress_pct)
			progress_lbl.add_theme_font_size_override("font_size", 11)
			progress_vbox.add_child(progress_lbl)

			var cancel_btn := Button.new()
			cancel_btn.text = "Cancel"
			cancel_btn.pressed.connect(_cancel_research)
			row.add_child(cancel_btn)
		else:
			var start_btn := Button.new()
			start_btn.text = "Start"
			start_btn.disabled = not bool(research_state.can_start)
			start_btn.tooltip_text = building_research_service.message_for_reason(research_state.reason) if start_btn.disabled else ""

			start_btn.pressed.connect(_start_research.bind(tech_id))
			row.add_child(start_btn)

func _start_research(tech_id: String) -> void:
	if not BuildingCatalog.RESEARCH_TECHS.has(tech_id):
		return
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[tech_id]
	if settlement.active_research_tech_id != "":
		_update_interface("Already researching another technology.")
		return
	if not is_instance_valid(campfire_node) or not _is_fire_lit(campfire_node):
		_update_interface("Research requires an active Campfire.")
		return
		
	var researcher := _get_available_researcher(tech.required_skill)
	if researcher == null:
		_update_interface("Requires an idle resident.")
		return
		
	if building_research_service.start_block_reason(tech_id, true) != BuildingResearchServiceScript.REASON_OK:
		_update_interface("Research prerequisites or resources are missing.")
		return
	if not building_research_service.start_research(tech_id, researcher.get_instance_id()):
		_update_interface("Research prerequisites or resources are missing.")
		return
	
	var research_pos := global_position
	if is_instance_valid(campfire_node):
		research_pos = campfire_node.get_meta("service_position", campfire_node.global_position)
	researcher.assign_research_work(research_pos)
	
	_update_interface("Research started: %s. %s is studying at the Campfire." % [tech.name, researcher.role_label()])
	_refresh_research_menu()
	_refresh_campfire_menu()

func _cancel_research() -> void:
	if settlement.active_research_tech_id == "":
		return
	_cancel_active_building_research(true, "Research cancelled. Resources refunded.")
	_refresh_research_menu()
	_refresh_campfire_menu()


func _cancel_active_building_research(refund: bool, message: String) -> void:
	var worker_id := settlement.active_research_worker_id
	for citizen in citizens:
		if citizen.get_instance_id() == worker_id:
			citizen.idle()
			break
	building_research_service.cancel_active(refund)
	_update_interface(message)
	_refresh_campfire_menu()

func _spawn_house_citizen() -> void:
	if selected_house == null or bool(selected_house.get_meta("pending_demolition", false)):
		return
	var slots: int = selected_house.get_meta("spawn_slots", 0)
	if slots <= 0 or _unhoused_citizen_count() > 0:
		return
	selected_house.set_meta("spawn_slots", slots - 1)
	_show_house_menu()
	pending_arrivals.append({"house": selected_house})
	_update_arrivals()
	_update_interface("A resident is expected at the entrance sign. Assign a Helper or use a Courier to meet them.")


func _find_arrival_greeter(allow_busy := false) -> Citizen:
	var best: Citizen = null
	var best_score := INF
	for citizen in citizens:
		if citizen.is_player_controlled or not citizen.can_handle_entry_logistics():
			continue
		if citizen.has_active_arrival_task() or citizen.pending_arrival_entrance != Vector3.INF:
			continue
		var is_free := citizen.state in [Citizen.State.IDLE, Citizen.State.RESTING]
		if not is_free and not allow_busy:
			continue
		if not is_free and citizen.has_active_delivery():
			# Never abandon cargo. The next candidate will be considered instead.
			continue
		var score := citizen.global_position.distance_to(entrance_stone.global_position)
		if not is_free:
			score += citizen.task_timer.remaining * Citizen.WALK_SPEED
		if score < best_score:
			best = citizen
			best_score = score
	return best


func _update_arrivals() -> void:
	if not is_instance_valid(entrance_stone):
		return
	_requeue_interrupted_arrivals()
	# At the start of a workday, visitors and their greeter leave the entrance for
	# the employment centre, or the hero when no office has been built.
	if _is_work_time():
		for citizen in citizens:
			if citizen.state != Citizen.State.ARRIVAL_WAITING:
				continue
			if arrival_escort_ids.has(citizen.get_instance_id()):
				citizen.escort_arrivals_to(_employment_center_position())
				arrival_escort_ids.erase(citizen.get_instance_id())
			else:
				if _employment_center_position() != Vector3.INF:
					citizen.begin_employment_processing(_employment_center_position())
				else:
					citizen.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
					citizen.idle()
	for greeter_id in arrival_waiting_greeters.keys():
		var waiting_greeter := instance_from_id(greeter_id) as Citizen
		var waiting_order: Dictionary = arrival_waiting_greeters[greeter_id]
		if not is_instance_valid(waiting_greeter) or not waiting_greeter.can_handle_entry_logistics():
			arrival_waiting_greeters.erase(greeter_id)
			_requeue_arrival_order(waiting_order)
			continue
		if waiting_greeter.has_active_arrival_task():
			arrival_waiting_greeters.erase(greeter_id)
			arrival_greeters[greeter_id] = waiting_order
			continue
		if waiting_greeter.state in [Citizen.State.IDLE, Citizen.State.RESTING]:
			waiting_greeter.go_to_arrival_entrance(entrance_stone.global_position)
			arrival_waiting_greeters.erase(greeter_id)
			arrival_greeters[greeter_id] = waiting_order
	for index in pending_arrivals.size():
		var order: Dictionary = pending_arrivals[index]
		if bool(order.get("dispatched", false)):
			continue
		var greeter := _find_arrival_greeter()
		var deferred := false
		if greeter == null:
			greeter = _find_arrival_greeter(true)
			deferred = greeter != null
		if greeter == null:
			continue
		order.dispatched = true
		order.greeter_id = greeter.get_instance_id()
		pending_arrivals[index] = order
		if deferred:
			arrival_waiting_greeters[greeter.get_instance_id()] = order
			greeter.request_arrival_greeting(entrance_stone.global_position)
			continue
		arrival_greeters[greeter.get_instance_id()] = order
		if not _is_work_time():
			greeter.satisfaction = maxf(0.0, greeter.satisfaction - 6.0)
		greeter.go_to_arrival_entrance(entrance_stone.global_position)


func _on_arrival_greeter_ready(greeter: Citizen) -> void:
	var order: Dictionary = arrival_greeters.get(greeter.get_instance_id(), {})
	arrival_greeters.erase(greeter.get_instance_id())
	if order.is_empty():
		greeter.idle()
		return
	pending_arrivals.erase(order)
	var house := order.get("house") as Node3D
	if not is_instance_valid(house) or bool(house.get_meta("pending_demolition", false)):
		greeter.idle()
		_update_interface("Arrival cancelled because its assigned home is being demolished.")
		return
	var spawn_position := entrance_stone.global_position + Vector3(0.55, 0.08, 0.55)
	var terrain_height := _terrain_height_at(spawn_position.x, spawn_position.z, spawn_position.y)
	if not is_nan(terrain_height):
		spawn_position.y = terrain_height + 0.08
	_add_citizen(spawn_position, "unassigned")
	var newcomer: Citizen = citizens.back()
	newcomer.assign_home(house)
	_refresh_living_status(newcomer)
	if _is_work_time():
		var centre := _employment_center_position()
		if centre != Vector3.INF:
			greeter.escort_arrivals_to(centre)
			newcomer.begin_employment_processing(centre)
			_update_interface("The newcomer was met at the entrance and is heading to employment registration.")
		else:
			greeter.idle()
			newcomer.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
			newcomer.idle()
			_update_interface("The newcomer joined the settlement without a permanent job.")
	else:
		arrival_escort_ids[greeter.get_instance_id()] = true
		greeter.wait_for_arrival_morning()
		newcomer.wait_for_arrival_morning()
		_update_interface("The newcomer and greeter are waiting at the entrance for the workday.")
	_show_house_menu()


func _requeue_interrupted_arrivals() -> void:
	for greeter_id in arrival_waiting_greeters.keys():
		var waiting_greeter := instance_from_id(greeter_id) as Citizen
		if is_instance_valid(waiting_greeter) and waiting_greeter.has_active_arrival_task():
			arrival_greeters[greeter_id] = arrival_waiting_greeters[greeter_id]
			arrival_waiting_greeters.erase(greeter_id)
			continue
		if is_instance_valid(waiting_greeter) and waiting_greeter.pending_arrival_entrance != Vector3.INF:
			continue
		var waiting_order: Dictionary = arrival_waiting_greeters[greeter_id]
		arrival_waiting_greeters.erase(greeter_id)
		_requeue_arrival_order(waiting_order)
	for greeter_id in arrival_greeters.keys():
		var greeter: Citizen = instance_from_id(greeter_id) as Citizen
		if is_instance_valid(greeter) and greeter.has_active_arrival_task():
			continue
		var order: Dictionary = arrival_greeters[greeter_id]
		arrival_greeters.erase(greeter_id)
		_requeue_arrival_order(order)


func _requeue_arrival_order(order: Dictionary) -> void:
	for index in pending_arrivals.size():
		if pending_arrivals[index] == order:
			order.dispatched = false
			order.erase("greeter_id")
			pending_arrivals[index] = order
			return


func _cancel_arrivals_for_house(house: Node3D) -> void:
	var cancelled := false
	for index in range(pending_arrivals.size() - 1, -1, -1):
		var order: Dictionary = pending_arrivals[index]
		if order.get("house") != house:
			continue
		var greeter_id := int(order.get("greeter_id", -1))
		if greeter_id >= 0:
			arrival_greeters.erase(greeter_id)
			arrival_waiting_greeters.erase(greeter_id)
			var greeter: Citizen = instance_from_id(greeter_id) as Citizen
			if is_instance_valid(greeter):
				greeter.pending_arrival_entrance = Vector3.INF
				if greeter.has_active_arrival_task():
					greeter.idle()
		pending_arrivals.remove_at(index)
		cancelled = true
	if cancelled:
		_update_interface("Pending arrival cancelled because its assigned home is being demolished.")

func _settle_unhoused_resident() -> void:
	if selected_house == null or bool(selected_house.get_meta("pending_demolition", false)):
		return
	var slots: int = selected_house.get_meta("spawn_slots", 0)
	if slots <= 0:
		return
	for citizen in citizens:
		if is_instance_valid(citizen.home):
			continue
		citizen.assign_home(selected_house)
		_refresh_living_status(citizen)
		selected_house.set_meta("spawn_slots", slots - 1)
		_update_interface("%s has been settled in this home." % citizen.role_label())
		_show_house_menu()
		return

func _show_house_menu() -> void:
	if selected_house == null:
		return
	var slots: int = selected_house.get_meta("spawn_slots", 0)
	house_menu.visible = true
	var capacity: int = int(selected_house.get_meta("housing_capacity", HOUSE_CAPACITY))
	var building_type: String = selected_house.get_meta("building_type", "house")
	var home_name := "Жилая палатка" if building_type == "living_tent" else ("Палатка" if building_type == "tent" else "House")
	var unhoused := _unhoused_citizen_count()
	house_menu_title.text = "%s\nFree beds: %d/%d  Unhoused: %d" % [home_name, slots, capacity, unhoused]
	if house_spawn_button != null:
		house_spawn_button.disabled = slots <= 0 or unhoused > 0 or bool(selected_house.get_meta("pending_demolition", false))
		house_spawn_button.text = "House the initial residents first" if unhoused > 0 else ("No free beds" if slots <= 0 else "Order a resident")
	var settle_button := house_menu.get_node_or_null("SettleUnhoused") as Button
	if settle_button == null:
		settle_button = Button.new()
		settle_button.name = "SettleUnhoused"
		settle_button.position = Vector2(16, 102)
		settle_button.size = Vector2(272, 30)
		settle_button.pressed.connect(_settle_unhoused_resident)
		house_menu.add_child(settle_button)
	settle_button.text = "Settle unhoused resident"
	settle_button.disabled = slots <= 0 or unhoused <= 0 or bool(selected_house.get_meta("pending_demolition", false))

func _unhoused_citizen_count() -> int:
	var count := 0
	for citizen in citizens:
		if not is_instance_valid(citizen.home):
			count += 1
	return count

func _house_initial_residents(house: Node3D) -> void:
	# The player explicitly assigns each resident through the house menu.
	pass

func _add_build_button(title: String, building_type: String, y_position: float, category: String) -> void:
	var button := Button.new()
	button.text = title
	button.position = Vector2(16, y_position)
	button.size = Vector2(272, 44)
	button.pressed.connect(_select_build_mode.bind(building_type))
	button.set_meta("category", category)
	button.set_meta("build_type", building_type)
	button.add_theme_font_size_override("font_size", 15)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Small cost line under the building name, dimmed when unaffordable.
	var cost_label := Label.new()
	cost_label.position = Vector2(10, 24)
	cost_label.size = Vector2(252, 16)
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cost_label)
	button.set_meta("cost_label", cost_label)
	build_menu.add_child(button)
	build_buttons.append(button)
	build_item_buttons.append(button)

func _add_build_category_button(title: String, category: String, y_position: float) -> void:
	var button := Button.new()
	button.text = title
	button.position = Vector2(16, y_position)
	button.size = Vector2(272, 30)
	button.pressed.connect(_open_build_category.bind(category))
	build_menu.add_child(button)
	build_buttons.append(button)
	button.set_meta("category_button", category)

func _add_build_category_back_button() -> void:
	var button := Button.new()
	button.text = "Back to categories"
	button.position = Vector2(16, 136)
	button.size = Vector2(272, 30)
	button.pressed.connect(_open_build_category.bind(""))
	button.set_meta("category_back", true)
	build_menu.add_child(button)
	build_buttons.append(button)

func _open_build_category(category: String) -> void:
	build_category = category
	build_menu_is_job_menu = false
	build_menu_is_daily_order_menu = false
	_refresh_build_menu()
	if build_category.is_empty():
		_show_selected_citizen_menu()

func _refresh_build_menu() -> void:
	var selected_exists := selected_builder != null
	var assignment_submenu_open := build_menu_is_job_menu or build_menu_is_daily_order_menu
	var citizen_actions_visible := selected_exists and not assignment_submenu_open and build_category.is_empty()
	if manage_citizen_button != null:
		manage_citizen_button.visible = citizen_actions_visible
		manage_citizen_button.text = "Управлять" if selected_builder != hero_citizen else "Управлять героем"
	
	if daily_order_submenu_btn != null:
		daily_order_submenu_btn.visible = citizen_actions_visible
		daily_order_submenu_btn.disabled = false
		daily_order_submenu_btn.tooltip_text = ""
	if job_submenu_btn != null:
		job_submenu_btn.visible = citizen_actions_visible
		job_submenu_btn.disabled = citizen_actions_visible and not _player_can_command_labor()
		job_submenu_btn.tooltip_text = _labor_command_block_message() if job_submenu_btn.disabled else ""
	if job_back_btn != null:
		job_back_btn.visible = selected_exists and assignment_submenu_open
	
	for button in build_buttons:
		var category_button: String = button.get_meta("category_button", "")
		if button.get_meta("category_back", false):
			button.visible = not build_category.is_empty() and not assignment_submenu_open
		elif not category_button.is_empty():
			button.visible = build_category.is_empty() and not assignment_submenu_open and building_availability_service.is_category_available(category_button)
		else:
			var build_type: String = button.get_meta("build_type", "")
			var menu_state: Dictionary = building_availability_service.menu_state(build_type)
			button.set_meta("build_menu_state", menu_state)
			button.visible = not build_category.is_empty() and button.get_meta("category", "") == build_category and not assignment_submenu_open and bool(menu_state.visible)
			
	for button in role_buttons:
		var role: String = button.get_meta("role", "")
		var hero_only: bool = button.get_meta("hero_only", false)
		var submenu: String = button.get_meta("submenu", "job")
		var is_daily_submenu := submenu == "daily"
		var role_available := _is_daily_order_role_available(role) if is_daily_submenu else _is_role_available(role)
		button.visible = selected_exists and ((is_daily_submenu and build_menu_is_daily_order_menu) or (not is_daily_submenu and build_menu_is_job_menu)) and role_available and (not hero_only or selected_builder.is_hero)
		button.disabled = button.visible and not is_daily_submenu and role != "official" and not _player_can_command_labor()
		button.tooltip_text = _labor_command_block_message() if button.disabled else ""
		if button.visible:
			var base_title: String = button.get_meta("base_title", button.text)
			if role.is_empty():
				button.text = base_title
			else:
				var skill_val := float(selected_builder.skills.get(role, 0.0))
				var active_cnt := _daily_order_role_count(role) if is_daily_submenu else _workforce_role_count(role)
				var limit := -1 if is_daily_submenu else _workforce_role_limit(role)
				var limit_str := ""
				if limit >= 0:
					limit_str = "/%d" % limit
				button.text = "%s (Skill: %d%%) [%d%s]" % [base_title, roundi(skill_val * 100.0), active_cnt, limit_str]

	# Lay the visible building buttons out in a single column and annotate each
	# with its resource cost. Unaffordable buildings are disabled and dimmed.
	var row_y := 176.0
	for button in build_item_buttons:
		if not button.visible:
			continue
		button.position = Vector2(16, row_y)
		row_y += 50.0
		var building_type: String = button.get_meta("build_type", "")
		var menu_state: Dictionary = button.get_meta("build_menu_state", building_availability_service.menu_state(building_type))
		var enabled := bool(menu_state.enabled)
		button.disabled = not enabled
		button.tooltip_text = "" if enabled else building_availability_service.message_for_reason(menu_state.reason)
		button.modulate = Color(1, 1, 1, 1) if enabled else Color(0.55, 0.55, 0.6, 1)
		var cost_label: Label = button.get_meta("cost_label")
		if cost_label != null:
			cost_label.text = str(menu_state.cost_text)
			cost_label.add_theme_color_override("font_color", Color("cdd6df") if enabled else Color("d98a86"))

	if build_menu_title != null:
		if build_menu_is_job_menu:
			build_menu_title.text = "Permanent Jobs\nRequires an employment officer. [n] = assigned residents."
		elif build_menu_is_daily_order_menu:
			build_menu_title.text = "Daily Orders\nNo officer required. Evening orders start next workday."
		elif not build_category.is_empty():
			build_menu_title.text = "%s buildings\nChoose a building to place." % build_category.capitalize()
		else:
			_show_selected_citizen_menu()

func _open_job_submenu() -> void:
	if not _player_can_command_labor():
		_show_labor_command_blocked()
		return
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

func _add_role_button(title: String, role: String, y_position: float, hero_only := false, submenu := "job") -> void:
	var button := Button.new()
	button.text = title
	button.position = Vector2(16, y_position)
	button.size = Vector2(272, 28)
	button.pressed.connect(_set_selected_work_role.bind(role, submenu == "daily"))
	button.set_meta("role", role)
	button.set_meta("base_title", title)
	button.set_meta("hero_only", hero_only)
	button.set_meta("submenu", submenu)
	build_menu.add_child(button)
	role_buttons.append(button)

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
		if not _player_can_command_labor():
			_show_labor_command_blocked()
			return
		_start_dig_assignment()
		build_menu_is_job_menu = false
		build_menu_is_daily_order_menu = false
		return
	elif role == "official":
		# The employment officer is appointed directly by the mayor. They run job
		# registration, so they cannot themselves queue for it — this also breaks
		# the bootstrap deadlock of "you need an officer to appoint an officer".
		_appoint_official(selected_builder)
	else:
		if not _player_can_command_labor():
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
		"helper": return true
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
		"gather_dew": return _has_collected_dew() and not warehouse_positions.is_empty()
		"gather_water": return bool(settlement.tools.get("bucket", false)) and bool(settlement.tools.get("filter_1", false)) and not pond_positions.is_empty() and not warehouse_positions.is_empty()
		"cook": return _available_employer_capacity("cook") > 0
		"teacher": return _available_employer_capacity("teacher") > 0
		"seller": return _available_employer_capacity("seller") > 0
		"factory_worker": return _available_employer_capacity("factory_worker") > 0
		"engineer": return _available_employer_capacity("engineer") > 0
		"courier": return not warehouse_positions.is_empty()
		"craftsman": return not craft_tent_positions.is_empty()
		"official": return is_instance_valid(_employment_centre_building())
	return false


func _is_daily_order_role_available(_role: String) -> bool:
	return true


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
		"gather_food": return ["forager_tent", "forager_tent_lvl2", "forager_tent_lvl3"]
		"gather_branches", "gather_grass": return ["materials_yard", "materials_yard_lvl2", "materials_yard_lvl3"]
		"cook": return ["cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant"]
		"teacher": return ["school"]
		"seller": return ["trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market"]
		"factory_worker": return ["brick_factory", "materials_factory", "recycling_factory", "metal_factory"]
		"engineer": return ["materials_factory"]
		"craftsman": return ["craft_tent", "craft_tent_lvl2", "craft_tent_lvl3"]
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
		if type == "craft_tent_lvl2":
			return 2
		elif type == "craft_tent_lvl3":
			return 3
		return 1
	if role == "gather_food":
		var type := str(building.get_meta("building_type", ""))
		if type == "forager_tent_lvl2":
			return 2
		elif type == "forager_tent_lvl3":
			return 3
		return 1
	if role in ["gather_branches", "gather_grass"]:
		var type := str(building.get_meta("building_type", ""))
		return 4 if type == "materials_yard_lvl3" else 3 if type == "materials_yard_lvl2" else 2
	return 1

func _start_dig_assignment() -> void:
	if not _player_can_command_labor():
		_show_labor_command_blocked()
		return
	if selected_builder == null:
		return
	dig_mode = true
	build_mode = ""
	selection_marker.visible = true
	selection_material.albedo_color = Color(0.65, 0.42, 0.2, 0.55)
	_move_selection(selected_world_position)
	_update_interface("Choose a clear point on the voxel terrain for excavation.")

func _place_dig_site(world_position: Vector3) -> void:
	var cell := _placement_key(world_position)
	if not _can_excavate(world_position):
		_update_interface("Excavation is not allowed at this point.")
		return
	var site := _dig_site_at(cell)
	if site.is_empty():
		site = _create_dig_site(cell, world_position)
	selected_builder.assigned_dig_site = site.node
	if selected_builder.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK:
		selected_builder.begin_employment_processing(_employment_center_position(), "excavation", site.node)
	dig_mode = false
	selection_marker.visible = false
	_update_workers()
	_show_selected_citizen_menu()
	_update_interface("Excavation assigned. Grass, soil and clay will be exposed before stone.")

func _can_excavate(world_position: Vector3) -> bool:
	var cell := _placement_key(world_position)
	return not exhausted_dig_cells.has(cell) and _is_clear_of_objects(world_position, 1.0)

func _dig_site_at(cell: Vector2i) -> Dictionary:
	for site in dig_sites:
		if site.cell == cell:
			return site
	return {}

func _create_dig_site(cell: Vector2i, world_position: Vector3) -> Dictionary:
	var site_node := Node3D.new()
	site_node.position = world_position
	add_child(site_node)
	var pit := MeshInstance3D.new()
	var pit_mesh := CylinderMesh.new()
	pit_mesh.top_radius = 0.62
	pit_mesh.bottom_radius = 0.72
	pit_mesh.height = 0.12
	pit.mesh = pit_mesh
	pit.position.y = 0.03
	var pit_material := StandardMaterial3D.new()
	pit_material.albedo_color = Color("3e612c") # Start with grass green
	pit.material_override = pit_material
	site_node.add_child(pit)
	
	var grass_depth := random.randi_range(2, 4)
	var soil_depth := random.randi_range(3, 6)
	var clay_depth := random.randi_range(4, 8)
	var stone_depth := random.randi_range(5, 10)
	
	var grass_limit := grass_depth
	var soil_limit := grass_limit + soil_depth
	var clay_limit := soil_limit + clay_depth
	var stone_limit := clay_limit + stone_depth
	
	var site := {
		"cell": cell,
		"node": site_node,
		"pit": pit,
		"grass_limit": grass_limit,
		"soil_limit": soil_limit,
		"clay_limit": clay_limit,
		"stone_limit": stone_limit,
		"depth": 0
	}
	dig_sites.append(site)
	dig_cells[cell] = true
	return site

func _select_build_mode(next_mode: String) -> void:
	if not _can_hero_build():
		_update_interface("Only the hero can approve construction decisions.")
		return
	if next_mode == "tent" and clock.hour() >= 22:
		_update_interface("The temporary tent must be marked before 22:00.")
		return
	var placement_state: Dictionary = building_availability_service.placement_state(next_mode)
	if not bool(placement_state.allowed):
		_update_interface(str(placement_state.message))
		return
	build_mode = next_mode
	build_rotation_quarters = 0
	selection_marker.visible = true
	_move_selection(selected_world_position)
	if is_first_person:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		build_menu.visible = false
	_update_interface("%s selected. Choose a clear point; Q/E rotates the building." % build_mode.capitalize())

func _cancel_build_action() -> void:
	build_mode = ""
	build_rotation_quarters = 0
	dig_mode = false
	selection_marker.visible = false
	preview_entrance_marker.visible = false
	preview_back_entrance_marker.visible = false
	build_menu.visible = false
	selected_builder = null
	_update_interface("Construction mode cancelled.")

func _close_context_menus() -> void:
	build_mode = ""
	dig_mode = false
	selection_marker.visible = false
	is_rotating_camera = false
	entrance_menu.visible = false
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
	_refresh_build_menu()


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
	if not build_mode.is_empty() and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_Q, KEY_E]:
		build_rotation_quarters = posmod(build_rotation_quarters + (-1 if event.keycode == KEY_Q else 1), 4)
		_move_selection(selected_world_position)
		get_viewport().set_input_as_handled()
		return
	if is_first_person:
		if event is InputEventKey and event.keycode == KEY_B and event.pressed and not event.echo:
			if _can_hero_build():
				_toggle_global_build_menu()
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if build_menu.visible else Input.MOUSE_MODE_CAPTURED)
			else:
				_update_interface("Only the hero can approve construction decisions.")
		elif event is InputEventMouseMotion:
			if not build_menu.visible:
				player_yaw -= event.relative.x * 0.0035
				player_pitch = clampf(player_pitch - event.relative.y * 0.003, deg_to_rad(-70.0), deg_to_rad(65.0))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not build_mode.is_empty() and _can_hero_build():
				_place_building_at_crosshair()
			else:
				_start_interaction()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if not build_mode.is_empty():
				_cancel_build_action()
			elif player_citizen == hero_citizen:
				_dig_voxel_at_crosshair()
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
		_update_interface("Materials factory selected. Start brick construction research here.")
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

func _hide_all_selection_menus() -> void:
	# Hides every building context menu and clears their selections, but leaves
	# the currently selected citizen untouched (the school menu needs it).
	house_menu.visible = false
	entrance_menu.visible = false
	school_menu.visible = false
	materials_factory_menu.visible = false
	campfire_menu.visible = false
	market_menu.visible = false
	warehouse_menu.visible = false
	building_menu.visible = false
	selected_house = null
	selected_entrance = null
	selected_school = null
	selected_materials_factory = null
	selected_campfire = null
	selected_market = null
	selected_warehouse = null
	selected_building = null

func _mark_building_for_demolition(building: Node3D) -> void:
	if not _can_hero_build() or not is_instance_valid(building):
		return
	if demolition.has_site(building):
		return
	if building == entrance_stone:
		_update_interface("This building cannot be demolished.")
		return
	var building_type := str(building.get_meta("building_type", "house"))
	if not BuildingCatalog.is_demolishable(building_type):
		_update_interface("This landmark cannot be demolished.")
		return
	_release_employment_at_building(building)
	building.set_meta("pending_demolition", true)
	_cancel_arrivals_for_house(building)
	_add_demolition_marker(building)
	demolition.mark(building, building_type)
	_update_workers()
	_update_interface("Building marked for demolition. Residents and stored goods must be relocated first.")

func _add_demolition_marker(building: Node3D) -> void:
	if building.has_meta("demolition_marker"):
		return
	var marker := Label3D.new()
	marker.text = "DEMOLISH"
	marker.position = Vector3(0.0, 5.2, 0.0)
	marker.font_size = 32
	marker.outline_size = 6
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.modulate = Color("ef4f45")
	building.add_child(marker)
	building.set_meta("demolition_marker", marker)

func _demolition_ready(site: DemolitionSite) -> bool:
	var building: Node3D = site.building
	if not is_instance_valid(building):
		return false
	for citizen in citizens:
		if citizen.home != building:
			continue
		var replacement := _find_relocation_home(building)
		if replacement != null:
			citizen.assign_home(replacement)
			_refresh_living_status(citizen)
			replacement.set_meta("spawn_slots", int(replacement.get_meta("spawn_slots", 0)) - 1)
		else:
			citizen.home = null
			_refresh_living_status(citizen)
	return true

func _find_relocation_home(excluded: Node3D) -> Node3D:
	for record in building_registry.records():
		var candidate: Node3D = record.node
		if not is_instance_valid(candidate) or candidate == excluded or bool(candidate.get_meta("pending_demolition", false)):
			continue
		if int(candidate.get_meta("spawn_slots", 0)) > 0:
			return candidate
	return null

func _update_demolition(delta: float) -> void:
	demolition.tick(delta)

func _finish_demolition(site: DemolitionSite) -> void:
	var building: Node3D = site.building
	var building_type := site.building_type
	var active_kitchen_removed := canteen == building
	var pile_resources: Dictionary = BuildingCatalog.demolition_refund(building_type).duplicate(true)
	if building_type in ["warehouse", "warehouse_lvl2"]:
		_move_stored_resources_to_pile(pile_resources)
	_return_in_transit_building_supplies(building)
	if active_kitchen_removed:
		if pending_canteen_delivery:
			_cancel_canteen_delivery()
		food += canteen_food
		canteen_food = 0
	for citizen in citizens:
		citizen.finish_construction(building)
	_remove_building_services(building, building_type)
	var removed_record := building_registry.remove_node(building)
	if removed_record != null:
		_unregister_navigation_footprint(removed_record.center, removed_record.footprint)
	if active_kitchen_removed:
		_select_best_canteen()
	settlement.buildings[building_type] = maxi(0, int(settlement.buildings.get(building_type, 1)) - 1)
	settlement.ensure_storage_defaults(warehouse_positions.size())
	if campfire_node == null:
		_select_best_campfire()
	_create_resource_pile(building.global_position, pile_resources)
	building.queue_free()
	_refresh_navigation_grid()
	_update_workers()
	_update_interface("%s dismantled; recovered materials are waiting in a resource pile." % building_type.capitalize())

func _remove_building_services(building: Node3D, building_type: String) -> void:
	_release_employment_at_building(building)
	var service_position: Vector3 = building.get_meta("service_position", building.global_position)
	match building_type:
		"warehouse", "warehouse_lvl2": warehouse_positions.erase(service_position)
		"sawmill": sawmill_positions.erase(service_position)
		"farm": farm_positions.erase(service_position)
		"builders_guild": builders_guild_positions.erase(service_position)
		"construction_company": construction_company_positions.erase(service_position)
		"forager_tent", "forager_tent_lvl2", "forager_tent_lvl3": forager_positions.erase(service_position)
		"materials_yard", "materials_yard_lvl2", "materials_yard_lvl3": materials_yard_positions.erase(service_position)
		"school": school_positions.erase(service_position)
		"park": park_positions.erase(service_position)
		"gathering_place": gathering_place_positions.erase(service_position)
		"leisure_center": leisure_positions.erase(service_position)
		"craft_tent", "craft_tent_lvl2", "craft_tent_lvl3": craft_tent_positions.erase(service_position)
		"trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market":
			market_positions.erase(service_position)
		"campfire", "campfire_lvl2", "campfire_lvl3", "earth_assembly", "clay_lodge", "wood_town_hall", "stone_prefecture", "brick_city_hall":
			if campfire_node == building: campfire_node = null
		"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant":
			if canteen == building: canteen = null
		"dew_collector", "dew_collector_lvl2", "dew_collector_lvl3":
			for i in range(water_collectors.size() - 1, -1, -1):
				if water_collectors[i].node == building:
					water_collectors.remove_at(i)
		"employment_office":
			if employment_office == building: employment_office = null
		"brick_factory", "materials_factory", "recycling_factory", "metal_factory": factories.erase(building)


func _release_employment_at_building(building: Node3D) -> void:
	for citizen in citizens:
		if citizen.employment_workplace != building and citizen.pending_employment_workplace != building:
			continue
		if citizen.permanent_role == "official":
			# Civic upgrades temporarily remove the post. Keep the appointment so it
			# transfers to the next main campfire instead of silently disappearing.
			if citizen_ai != null:
				citizen_ai.cancel_citizen_work(citizen.ai_id)
			citizen.idle()
			citizen.employment_workplace = null
			citizen.pending_employment_workplace = null
			continue
		_send_to_unemployment_registration(citizen)


func _send_to_unemployment_registration(citizen: Citizen) -> void:
	if citizen.is_player_controlled:
		return
	if citizen_ai != null:
		citizen_ai.cancel_citizen_work(citizen.ai_id)
	citizen.idle()
	citizen.permanent_role = ""
	citizen.pending_employment_role = ""
	citizen.employment_workplace = null
	citizen.pending_employment_workplace = null
	citizen.release_to_no_permanent_work()


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
		if selected_builder.is_courier() and not _player_can_command_labor():
			_show_labor_command_blocked()
			return
		selected_builder.courier_worker = clicked_citizen
		_request_courier_dispatch()
		_update_interface("%s assigned to this worker. Click another worker to reassign." % ("Courier" if selected_builder.is_courier() else "Helper"))
		return
	selected_builder = clicked_citizen
	_hide_all_selection_menus()
	build_mode = ""
	build_category = ""
	selection_marker.visible = false
	build_menu.visible = true
	_refresh_build_menu()
	_show_selected_citizen_menu()
	_update_interface("Citizen selected. Choose a building in the lower-right menu.")

func _show_selected_citizen_menu() -> void:
	if selected_builder == null:
		build_menu_title.text = "Construction Panel\nChoose an era category below."
		build_menu_title.add_theme_color_override("font_color", Color("ffffff"))
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
		build_menu_title.text = "%s  Sat: %d/%d%%  Food: %d%%\nHome: %s  Effect: %s  Task: %s\nBuild %.0f%% Wood %.0f%% Farm %.0f%% Dig %.0f%%" % [selected_builder.role_label(), roundi(selected_builder.satisfaction), roundi(selected_builder.get_satisfaction_cap()), roundi(selected_builder.hunger), home_label, effect_label, assignment, float(selected_builder.skills.get("construction", 0.0)) * 100.0, float(selected_builder.skills.get("forestry", 0.0)) * 100.0, float(selected_builder.skills.get("farming", 0.0)) * 100.0, float(selected_builder.skills.get("excavation", 0.0)) * 100.0]
	build_menu_title.add_theme_color_override("font_color", selected_builder.specialization_color())

func _toggle_hero_view() -> void:
	if is_first_person:
		if player_citizen == hero_citizen:
			_leave_first_person_to_hero_overview()
		else:
			_enter_first_person(hero_citizen, "Returned to the hero.")
		return
	_enter_first_person(hero_citizen, "Hero view enabled.")

func _take_control_of_selected_citizen() -> void:
	if selected_builder == null:
		return
	_enter_first_person(selected_builder, "%s is now under direct control." % selected_builder.role_label())

func _enter_first_person(citizen: Citizen, message: String) -> void:
	if citizen == null:
		return
	if is_first_person and player_citizen != null and player_citizen != citizen:
		player_citizen.set_player_controlled(false)
		player_citizen.set_head_visible(true)
	player_citizen = citizen
	player_citizen.set_head_visible(false)
	# Watching a citizen must not cancel their current AI task. Manual control
	# starts only after the player presses a movement key.
	player_citizen.set_player_controlled(false)
	is_first_person = true
	build_mode = ""
	selection_marker.visible = false
	build_menu.visible = false
	player_yaw = player_citizen.rotation.y
	player_pitch = 0.0
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Engine.time_scale = 1.0
	_update_interface(message)

func _leave_first_person_to_hero_overview() -> void:
	is_first_person = false
	if player_citizen != null:
		player_citizen.set_player_controlled(false)
		player_citizen.set_head_visible(true)
	player_citizen = null
	interaction_action = ""
	interaction_hint_label.visible = false
	interaction_progress.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if hero_citizen != null:
		camera_target = hero_citizen.global_position
	_update_camera_position()
	build_menu.visible = selected_builder != null
	_update_workers()
	Engine.time_scale = time_multiplier
	_update_interface("Overview centered on the hero.")

func _update_player_control(delta: float) -> void:
	if player_citizen == null:
		_leave_first_person_to_hero_overview()
		return
	var move_direction := Vector3.ZERO
	var forward := Vector3(-sin(player_yaw), 0.0, -cos(player_yaw))
	var right := Vector3(cos(player_yaw), 0.0, -sin(player_yaw))
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move_direction += forward
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move_direction -= forward
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move_direction += right
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move_direction -= right
	if not player_citizen.is_player_controlled:
		if move_direction.is_zero_approx():
			camera.global_position = player_citizen.global_position + Vector3(0.0, PLAYER_EYE_HEIGHT, 0.0)
			camera.rotation = Vector3(player_pitch, player_yaw, 0.0)
			_refresh_interaction_hint()
			return
		if citizen_ai != null:
			citizen_ai.cancel_citizen_work(player_citizen.ai_id)
		player_citizen.set_player_controlled(true)
	var speed := PLAYER_SPEED * (PLAYER_SPRINT_MULTIPLIER if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	if not move_direction.is_zero_approx():
		move_direction = move_direction.normalized()
		player_citizen.velocity.x = move_direction.x * speed
		player_citizen.velocity.z = move_direction.z * speed
		player_citizen.rotation.y = player_yaw
	else:
		player_citizen.velocity.x = move_toward(player_citizen.velocity.x, 0.0, speed * 8.0 * delta)
		player_citizen.velocity.z = move_toward(player_citizen.velocity.z, 0.0, speed * 8.0 * delta)
	if player_citizen.is_on_floor():
		player_citizen.velocity.y = -0.5
		if Input.is_key_pressed(KEY_SPACE):
			player_citizen.velocity.y = PLAYER_JUMP_VELOCITY
	else:
		player_citizen.velocity.y -= PLAYER_GRAVITY * delta
	player_citizen.move_and_slide()
	player_citizen.drive_player_animation(Input.is_key_pressed(KEY_SHIFT))
	camera.global_position = player_citizen.global_position + Vector3(0.0, PLAYER_EYE_HEIGHT, 0.0)
	camera.rotation = Vector3(player_pitch, player_yaw, 0.0)
	_refresh_interaction_hint()

func _start_interaction() -> void:
	if not interaction_action.is_empty():
		return
	var work_target := _nearby_player_work_target()
	if work_target != null:
		player_work_target = work_target
		interaction_action = "demolition" if bool(work_target.get_meta("pending_demolition", false)) else "construction"
		interaction_time = 0.0
		interaction_progress.visible = true
		interaction_hint_label.text = "Working on %s..." % ("demolition" if interaction_action == "demolition" else "construction")
		return
	if _nearby_sawmill() and pocket_wood > 0:
		var sawmill_position := _nearby_sawmill_position()
		var stock := _sawmill_stock(sawmill_position)
		stock.logs = int(stock.logs) + pocket_wood
		_store_sawmill_stock(sawmill_position, stock)
		var unloaded := pocket_wood
		pocket_wood = 0
		_update_interface("Unloaded %d logs at the sawmill. Boards will be ready after processing." % unloaded)
		_refresh_interaction_hint()
		return
	if _nearby_sawmill():
		var pickup_sawmill_position := _nearby_sawmill_position()
		var pickup_stock := _sawmill_stock(pickup_sawmill_position)
		var free_capacity := POCKET_WOOD_CAPACITY - pocket_wood - pocket_food - pocket_boards
		var amount := mini(int(pickup_stock.boards), free_capacity)
		if amount > 0:
			pickup_stock.boards = int(pickup_stock.boards) - amount
			_store_sawmill_stock(pickup_sawmill_position, pickup_stock)
			pocket_boards += amount
			_update_interface("Picked up %d boards from the sawmill." % amount)
		else:
			_update_interface("The sawmill has no ready boards, or your pocket is full.")
		_refresh_interaction_hint()
		return
	if _nearby_warehouse() and (pocket_food > 0 or pocket_boards > 0 or pocket_water > 0):
		var delivered_food := mini(pocket_food, settlement.storage_room_for("food"))
		var delivered_boards := mini(pocket_boards, settlement.storage_room_for("boards"))
		var delivered_water := mini(pocket_water, settlement.storage_room_for("water"))
		if delivered_food + delivered_boards + delivered_water <= 0:
			_update_interface("No storage room. Rebalance the warehouse or build another.")
			return
		food += delivered_food
		boards += delivered_boards
		water += delivered_water
		pocket_food -= delivered_food
		pocket_boards -= delivered_boards
		pocket_water -= delivered_water
		_update_interface("Delivered %d food, %d boards, %d water to the warehouse." % [delivered_food, delivered_boards, delivered_water])
		_refresh_interaction_hint()
		return
	if _nearby_pond() and not (_nearby_tree() or _nearby_farm()):
		if not bool(settlement.tools.get("bucket", false)):
			_update_interface("You need a bucket to draw water. Buy one at a market.")
			return
		if _pocket_total() >= POCKET_WOOD_CAPACITY:
			_update_interface("Pocket is full. Take water to the warehouse.")
			_refresh_interaction_hint()
			return
		interaction_resource = "water"
		interaction_action = "harvesting"
		interaction_time = 0.0
		interaction_progress.visible = true
		interaction_hint_label.text = "Filling bucket..."
		return
	if _nearby_grass_source():
		if settlement.storage_room_for("grass") <= 0:
			_update_interface("No storage room for grass. Rebalance the warehouse or build another.")
			return
		interaction_resource = "grass"
		interaction_action = "harvesting"
		interaction_time = 0.0
		interaction_progress.visible = true
		interaction_hint_label.text = "Gathering grass..."
		return
	if _nearby_tree() or _nearby_farm():
		var gathering_branches := _nearby_tree() and settlement.era < SettlementState.Era.WOOD
		if not gathering_branches and _pocket_total() >= POCKET_WOOD_CAPACITY:
			_update_interface("Pocket is full. Take wood to the sawmill or food to the warehouse.")
			_refresh_interaction_hint()
			return
		interaction_resource = "branches" if gathering_branches else ("wood" if _nearby_tree() else "food")
		interaction_action = "harvesting"
		interaction_time = 0.0
		interaction_progress.visible = true
		interaction_hint_label.text = "Gathering %s..." % interaction_resource
		return
	if _nearby_warehouse():
		_update_interface("Food pocket is empty. Wood must go to a sawmill first.")
	else:
		_update_interface("Move closer to a tree, farm, pond, warehouse or sawmill.")

func _dig_voxel_at_crosshair() -> void:
	if voxel_tool == null:
		return
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z
	var hit := voxel_tool.raycast(origin, direction, DIG_REACH)
	if hit == null:
		return
	voxel_tool.mode = VoxelTool.MODE_REMOVE
	voxel_tool.do_sphere(hit.position, DIG_RADIUS)
	_mark_excavation_as_navigation_blocked(hit.position, DIG_RADIUS)
	_refresh_navigation_grid()

func _mark_excavation_as_navigation_blocked(center: Vector3, radius: float) -> void:
	var center_cell := _cell_from_position(center)
	var cell_radius := ceili(radius + 0.75)
	for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for z in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			var cell := Vector2i(x, z)
			if not _is_board_cell(cell):
				continue
			if _cell_center(cell).distance_to(Vector3(center.x, 0.0, center.z)) <= radius + 0.75:
				terrain_blocked_cells[cell] = true

func _update_interaction(delta: float) -> void:
	if interaction_action.is_empty():
		return
	if interaction_action in ["construction", "demolition"]:
		if not is_instance_valid(player_work_target) or player_citizen.global_position.distance_to(player_work_target.global_position) > INTERACTION_RANGE:
			interaction_action = ""
			player_work_target = null
			interaction_progress.visible = false
			_refresh_interaction_hint()
			return
		interaction_progress.value = 100.0
		interaction_hint_label.text = "Working on %s..." % interaction_action
		return
	if (interaction_resource in ["wood", "branches"] and not _nearby_tree()) or (interaction_resource == "food" and not _nearby_farm()) or (interaction_resource == "water" and not _nearby_pond()) or (interaction_resource == "grass" and not _nearby_grass_source()):
		interaction_action = ""
		interaction_progress.visible = false
		_update_interface("Gathering cancelled: you moved away from the resource.")
		return
	interaction_time += delta
	interaction_progress.value = interaction_time / HARVEST_DURATION * 100.0
	interaction_hint_label.text = "Gathering %s: %d%%" % [interaction_resource, roundi(interaction_progress.value)]
	if interaction_time >= HARVEST_DURATION:
		interaction_action = ""
		if interaction_resource == "wood":
			pocket_wood += 1
		elif interaction_resource == "branches":
			var branch_batch := mini(HERO_GATHER_YIELD, settlement.storage_room_for("branches"))
			if branch_batch > 0:
				branches += branch_batch
				_update_interface("Gathered %d branches. Branches: %d." % [branch_batch, branches])
			else:
				_update_interface("No storage room for branches. Rebalance the warehouse or build another.")
		elif interaction_resource == "grass":
			var grass_batch := mini(HERO_GATHER_YIELD, settlement.storage_room_for("grass"))
			if grass_batch > 0:
				grass += grass_batch
				_consume_grass_near_player(grass_batch)
				_update_interface("Gathered %d grass. Grass: %d." % [grass_batch, grass])
			else:
				_update_interface("No storage room for grass. Rebalance the warehouse or build another.")
		elif interaction_resource == "water":
			pocket_water += 1
		else:
			pocket_food += 1
		interaction_progress.visible = false
		_consume_tree_near_player() if interaction_resource == "wood" else null
		if interaction_resource in ["branches", "grass"]:
			pass
		else:
			_update_interface("Gathered. Wood: %d, food: %d, water: %d, boards: %d, pocket: %d/%d." % [pocket_wood, pocket_food, pocket_water, pocket_boards, _pocket_total(), POCKET_WOOD_CAPACITY])
		_refresh_interaction_hint()

func _nearby_tree() -> bool:
	if player_citizen == null:
		return false
	for tree_position in tree_positions:
		if player_citizen.global_position.distance_to(tree_position) <= INTERACTION_RANGE:
			return true
	return false

func _nearby_warehouse() -> bool:
	if player_citizen == null:
		return false
	for warehouse_position in warehouse_positions:
		if player_citizen.global_position.distance_to(warehouse_position) <= INTERACTION_RANGE:
			return true
	return false

func _nearby_sawmill() -> bool:
	return _nearby_sawmill_position() != Vector3.INF

func _nearby_sawmill_position() -> Vector3:
	if player_citizen == null:
		return Vector3.INF
	for sawmill_position in sawmill_positions:
		if player_citizen.global_position.distance_to(sawmill_position) <= INTERACTION_RANGE:
			return sawmill_position
	return Vector3.INF

func _nearby_farm() -> bool:
	if player_citizen == null:
		return false
	for farm_position in farm_positions:
		if player_citizen.global_position.distance_to(farm_position) <= INTERACTION_RANGE:
			return true
	return false

func _nearby_pond() -> bool:
	if player_citizen == null:
		return false
	for pond_position in pond_positions:
		if player_citizen.global_position.distance_to(pond_position) <= INTERACTION_RANGE:
			return true
	return false

func _nearby_grass_source() -> bool:
	return _nearby_grass_source_position() != Vector3.INF

func _nearby_grass_source_position() -> Vector3:
	if player_citizen == null:
		return Vector3.INF
	var best := Vector3.INF
	var best_dist := INTERACTION_RANGE
	for cell in grass_sources:
		var source: Dictionary = grass_sources[cell]
		if int(source.remaining) <= 0 or not is_instance_valid(source.node):
			continue
		var node_pos: Vector3 = (source.node as Node3D).global_position
		var dist := player_citizen.global_position.distance_to(node_pos)
		if dist <= best_dist:
			best_dist = dist
			best = node_pos
	return best

func _consume_grass_near_player(amount: int) -> void:
	# The hero's batch harvest draws from the nearest patch and rolls onto adjacent
	# patches if the closest one is exhausted, so one action can clear a small tuft.
	var remaining_to_take := amount
	while remaining_to_take > 0:
		var pos := _nearby_grass_source_position()
		if pos == Vector3.INF:
			return
		_consume_grass_source(pos)
		remaining_to_take -= 1

func _pocket_total() -> int:
	return pocket_wood + pocket_food + pocket_boards + pocket_water

func _refresh_interaction_hint() -> void:
	if not is_first_person or not interaction_action.is_empty():
		return
	interaction_hint_label.visible = true
	var work_target := _nearby_player_work_target()
	if work_target != null:
		interaction_hint_label.text = "LMB: %s" % ("dismantle marked building" if bool(work_target.get_meta("pending_demolition", false)) else "build marked site")
		return
	if _nearby_sawmill() and pocket_wood > 0:
		interaction_hint_label.text = "LMB: unload wood at sawmill (%d wood)" % pocket_wood
	elif _nearby_sawmill() and int(_sawmill_stock(_nearby_sawmill_position()).boards) > 0:
		interaction_hint_label.text = "LMB: take ready boards from sawmill"
	elif _nearby_warehouse() and (pocket_food > 0 or pocket_boards > 0 or pocket_water > 0):
		interaction_hint_label.text = "LMB: unload food %d / boards %d / water %d at warehouse" % [pocket_food, pocket_boards, pocket_water]
	elif _nearby_grass_source():
		interaction_hint_label.text = "LMB: gather grass (x%d)" % HERO_GATHER_YIELD
	elif _nearby_tree():
		interaction_hint_label.text = "LMB: gather branches" if settlement.era < SettlementState.Era.WOOD else "LMB: gather wood (%d/%d in pocket)" % [_pocket_total(), POCKET_WOOD_CAPACITY]
	elif _nearby_farm():
		interaction_hint_label.text = "LMB: gather food (%d/%d in pocket)" % [_pocket_total(), POCKET_WOOD_CAPACITY]
	elif _nearby_pond():
		if bool(settlement.tools.get("bucket", false)):
			interaction_hint_label.text = "LMB: fill bucket with water (%d/%d in pocket)" % [_pocket_total(), POCKET_WOOD_CAPACITY]
		else:
			interaction_hint_label.text = "Buy a bucket at a market to draw water here."
	else:
		interaction_hint_label.text = "LMB: gather. Logs go to sawmill, boards and food go to warehouse."
	if player_citizen != null and is_instance_valid(player_citizen.employment_workplace):
		var workplace := player_citizen.employment_workplace
		var service_pos: Vector3 = workplace.get_meta("service_position", workplace.global_position)
		if player_citizen.global_position.distance_to(service_pos) <= 3.5:
			var type: String = workplace.get_meta("building_type", "Workplace")
			interaction_hint_label.text = "You are occupying your workplace: %s" % type.capitalize().replace("_", " ")

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
	if build_mode == "trade_tent" and is_instance_valid(entrance_stone) and world_position.distance_to(entrance_stone.global_position) > 8.0:
		_update_interface("The tent market must be built beside the entrance sign.")
		return
	if not _can_place(world_position):
		_update_interface("Construction is not allowed at this point.")
		return
	var cell := _placement_key(world_position)
	if not _can_pay_building_cost(build_mode):
		var placement_state: Dictionary = building_availability_service.placement_state(build_mode)
		_update_interface(str(placement_state.message))
		return
	var blueprint := BuildingBlueprints.get_blueprint(build_mode)
	var occupied_footprint := _rotated_footprint(blueprint.footprint)
	building_registry.reserve(cell, world_position, occupied_footprint)
	_refresh_navigation_grid()
	_create_construction_site(cell, build_mode, world_position, build_rotation_quarters, blueprint, occupied_footprint)
	build_mode = ""
	build_rotation_quarters = 0
	selection_marker.visible = false
	preview_entrance_marker.visible = false
	preview_back_entrance_marker.visible = false
	build_menu.visible = false
	selected_builder = null
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
	return bool(building_availability_service.placement_state(building_type).allowed)

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
	var min_x := roundi(center.x - (footprint.x - 1) * 0.5)
	var min_z := roundi(center.z - (footprint.y - 1) * 0.5)
	for x in range(footprint.x):
		for z in range(footprint.y):
			if terrain_blocked_cells.has(Vector2i(min_x + x, min_z + z)):
				return true
	return false

func _is_footprint_level(world_position: Vector3, footprint: Vector2i) -> bool:
	var heights: Array[float] = []
	var half_x := footprint.x * 0.5 - 0.25
	var half_z := footprint.y * 0.5 - 0.25
	for offset in [Vector2(-half_x, -half_z), Vector2(half_x, -half_z), Vector2(-half_x, half_z), Vector2(half_x, half_z), Vector2.ZERO]:
		var height := _terrain_height_at(world_position.x + offset.x, world_position.z + offset.y, world_position.y)
		if is_nan(height):
			return false
		heights.append(height)
	return heights.max() - heights.min() <= MAX_BUILD_SLOPE

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
	for occupied_position in building_registry.positions() + tree_positions:
		if Vector2(occupied_position.x, occupied_position.z).distance_to(Vector2(world_position.x, world_position.z)) < minimum_distance:
			return false
	for site in dig_sites:
		if Vector2(site.node.global_position.x, site.node.global_position.z).distance_to(Vector2(world_position.x, world_position.z)) < minimum_distance:
			return false
	return true

func _placement_key(world_position: Vector3) -> Vector2i:
	return Vector2i(roundi(world_position.x), roundi(world_position.z))

func _create_construction_site(cell: Vector2i, building_type: String, position_on_board: Vector3, rotation_quarters := 0, blueprint: Dictionary = {}, occupied_footprint := Vector2i.ZERO) -> void:
	construction.start_site(cell, building_type, position_on_board, rotation_quarters, blueprint, occupied_footprint)

func _update_construction(delta: float) -> void:
	construction.tick(delta)


func _set_construction_status(text: String) -> void:
	if status_label != null:
		status_label.text = text

func _complete_building(cell: Vector2i, building_type: String, position_on_board: Vector3, building: Node3D, blueprint: Dictionary) -> void:
	settlement.buildings[building_type] = int(settlement.buildings.get(building_type, 0)) + 1
	building.set_meta("building_type", building_type)
	building.set_meta("condition", 100.0)
	if building_type in ["campfire", "campfire_lvl2", "campfire_lvl3", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3"]:
		building.set_meta("fire_fuel", 4)
		building.set_meta("fire_lit", true)
	if _is_staffed_workplace(building):
		workplace_priority_counter += 1
		building.set_meta("accepting_workers", true)
		building.set_meta("workplace_priority", workplace_priority_counter)
	if building_type not in ["warehouse", "warehouse_lvl2", "campfire", "campfire_lvl2", "campfire_lvl3", "earth_assembly", "clay_lodge", "wood_town_hall", "stone_prefecture", "brick_city_hall", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant", "trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market", "school", "materials_factory", "tent", "living_tent", "living_tent_lvl2", "living_tent_lvl3", "dugout", "earth_house", "clay_house", "stone_house", "house", "house_lvl2", "house_lvl3", "brick_house", "craft_tent", "craft_tent_lvl2", "craft_tent_lvl3", "forager_tent_lvl2", "forager_tent_lvl3"]:
		_add_building_selector(building, "building_selector", blueprint.footprint)
	_register_service_entrance(building, blueprint.footprint, false, building_type not in ["farm", "park"])
	var service_position: Vector3 = building.get_meta("service_position")
	match building_type:
		"warehouse", "warehouse_lvl2":
			warehouse_positions.append(service_position)
			settlement.ensure_storage_defaults(warehouse_positions.size())
			_add_building_selector(building, "warehouse_selector", blueprint.footprint)
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
			var fire_light := OmniLight3D.new()
			fire_light.position = Vector3(0.0, 0.5, 0.0)
			fire_light.light_color = Color("ff9d3b")
			fire_light.light_energy = 2.5
			fire_light.omni_range = 8.0
			building.add_child(fire_light)
		"gathering_place":
			gathering_place_positions.append(service_position)
			_create_gathering_place_visual(building)
			_add_building_selector(building, "building_selector", blueprint.footprint)
		"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant":
			_activate_kitchen_if_better(building, service_position)
			_add_building_selector(building, "cook_campfire_selector", blueprint.footprint)
			var cook_fire_light := OmniLight3D.new()
			cook_fire_light.position = Vector3(0.0, 0.5, 0.0)
			cook_fire_light.light_color = Color("ff9d3b")
			cook_fire_light.light_energy = 2.5
			cook_fire_light.omni_range = 8.0
			building.add_child(cook_fire_light)
		"forager_tent", "forager_tent_lvl2", "forager_tent_lvl3":
			forager_positions.append(service_position)
			_update_interface("Forager tent ready. Assign a resident to forage food, or a free hand will.")
		"materials_yard":
			materials_yard_positions.append(service_position)
			_update_interface("Двор стройматериалов готов. Работники собирают ветки и траву (что в дефиците), или это сделает свободный житель.")
		"tent", "living_tent", "living_tent_lvl2", "living_tent_lvl3", "dugout", "earth_house", "clay_house", "stone_house", "house", "house_lvl2", "house_lvl3", "brick_house":
			if building_type in ["house", "house_lvl2", "house_lvl3", "brick_house"]:
				completed_house_count += 1
			var housing_capacity := HOUSE_CAPACITY
			match building_type:
				"living_tent": housing_capacity = 1
				"living_tent_lvl2": housing_capacity = 2
				"living_tent_lvl3": housing_capacity = 3
				"tent", "dugout": housing_capacity = 4
				"earth_house", "clay_house": housing_capacity = 6
				"house": housing_capacity = 8
				"house_lvl2": housing_capacity = 10
				"house_lvl3": housing_capacity = 12
				"stone_house": housing_capacity = 10
				"brick_house": housing_capacity = 12
			building.set_meta("housing_capacity", housing_capacity)
			building.set_meta("spawn_slots", housing_capacity)
			building.set_meta("entrance_position", service_position)
			_add_building_selector(building, "house_selector", blueprint.footprint)
			_add_house_light(building)
			if building_type in ["tent", "living_tent", "living_tent_lvl2", "living_tent_lvl3"]:
				building.set_meta("is_tent", true)
			_house_initial_residents(building)
		"dew_collector", "dew_collector_lvl2", "dew_collector_lvl3":
			var rate := 0.12
			var capacity := 10
			if building_type == "dew_collector_lvl2":
				rate = 0.24
				capacity = 20
			elif building_type == "dew_collector_lvl3":
				rate = 0.4
				capacity = 35
			water_collectors.append({"node": building, "rate": rate, "accum": 0.0, "stored": 0, "capacity": capacity})
		"craft_tent", "craft_tent_lvl2", "craft_tent_lvl3":
			craft_tent_positions.append(service_position)
		"trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market":
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
	building_registry.attach_node(cell, building)
	var occupied_footprint: Vector2i = building.get_meta("occupied_footprint", blueprint.footprint)
	_add_building_status_indicator(building)
	_refresh_navigation_grid()
	_update_workers()
	var completion_message := "%s construction completed." % building_type.capitalize()
	if building_type in ["recycling_factory", "metal_factory"]:
		completion_message += " It requires 3 factory workers."
	_update_interface(completion_message)
	_request_courier_dispatch()


func _activate_kitchen_if_better(building: Node3D, service_position: Vector3) -> void:
	var capacity := BuildingCatalog.kitchen_food_capacity(str(building.get_meta("building_type", "")))
	var active_capacity := BuildingCatalog.kitchen_food_capacity(str(canteen.get_meta("building_type", ""))) if is_instance_valid(canteen) else 0
	if capacity >= active_capacity:
		canteen = building
		canteen_position = service_position


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
		canteen_position = best_kitchen.get_meta("service_position", best_kitchen.global_position)

func _add_building_selector(building: Node3D, group_name: String, footprint: Vector2i) -> void:
	var selector := Area3D.new()
	selector.add_to_group(group_name)
	selector.collision_layer = 4
	selector.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(footprint.x + 0.25, 4.5, footprint.y + 0.25)
	collision.shape = shape
	collision.position.y = 2.0
	selector.add_child(collision)
	building.add_child(selector)


func _add_fire_light(building: Node3D, energy := 2.5, light_range := 8.0) -> void:
	var fire_light := OmniLight3D.new()
	fire_light.position = Vector3(0.0, 0.5, 0.0)
	fire_light.light_color = Color("ff9d3b")
	fire_light.light_energy = energy
	fire_light.omni_range = light_range
	building.add_child(fire_light)


func _add_building_status_indicator(building: Node3D) -> void:
	if not is_instance_valid(building) or building.has_meta("status_indicator"):
		return
	var indicator := Label3D.new()
	indicator.position = Vector3(0.0, 4.2, 0.0)
	indicator.font_size = 28
	indicator.outline_size = 5
	indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	indicator.no_depth_test = true
	indicator.visible = false
	building.add_child(indicator)
	building.set_meta("status_indicator", indicator)
	building_status_indicators.append(indicator)

func _update_building_status_indicators(delta: float) -> void:
	building_status_update_time -= delta
	if building_status_update_time > 0.0:
		return
	building_status_update_time = 0.5
	for indicator in building_status_indicators:
		if not is_instance_valid(indicator):
			continue
		var building := indicator.get_parent() as Node3D
		if not is_instance_valid(building):
			continue
		var required := _required_staff_for_building(building)
		if required.is_empty():
			indicator.visible = false
			continue
		var assigned := _assigned_staff_for_building(building, required)
		indicator.visible = assigned < int(required.count)
		indicator.text = "NO WORKER" if assigned == 0 else "STAFF %d/%d" % [assigned, int(required.count)]
		indicator.modulate = Color("ef6b5b") if assigned == 0 else Color("f0c45d")

func _required_staff_for_building(building: Node3D) -> Dictionary:
	match str(building.get_meta("building_type", "")):
		"sawmill": return {"role": "forestry", "count": 1}
		"farm": return {"role": "farming", "count": 1}
		"forager_tent": return {"role": "gather_food", "count": 1}
		"forager_tent_lvl2": return {"role": "gather_food", "count": 2}
		"forager_tent_lvl3": return {"role": "gather_food", "count": 3}
		"materials_yard": return {"role": "gather_branches", "count": 2}
		"materials_yard_lvl2": return {"role": "gather_branches", "count": 3}
		"materials_yard_lvl3": return {"role": "gather_branches", "count": 4}
		"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant": return {"role": "cooking", "count": 1}
		"school": return {"role": "teaching", "count": 1}
		"brick_factory", "materials_factory", "recycling_factory", "metal_factory": return {"role": "factory_worker", "count": int(building.get_meta("required_factory_workers", 1))}
	return {}

func _assigned_staff_for_building(building: Node3D, required: Dictionary) -> int:
	var count := 0
	var role: String = required.role
	for citizen in citizens:
		if role == "cooking" and citizen.active_role == "cooking":
			count += 1
		elif role == "teaching" and citizen.active_role == "teaching":
			count += 1
		elif role == "factory_worker" and citizen.factory == building and citizen.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]:
			count += 1
		elif role == "forestry" and citizen.active_role == "forestry":
			count += 1
		elif role == "farming" and citizen.active_role == "farming":
			count += 1
		elif role == "gather_food" and citizen.active_role == "gather_food":
			count += 1
	return count

func _has_storage_room_for_role(role: String) -> bool:
	if role == "excavation":
		for site in dig_sites:
			if _can_work_at_dig_site(site):
				var next_depth = site.depth + 1
				var resource = _resource_for_depth(site, next_depth)
				return settlement.can_make_room_for(resource, 1, warehouse_positions.size())
		return settlement.can_make_room_for("soil", 1, warehouse_positions.size())
		
	var resource_for_role := {"forestry": "logs", "farming": "food", "gather_branches": "branches", "gather_grass": "grass", "gather_food": "food", "gather_water": "water", "gather_dew": "water"}
	if not resource_for_role.has(role):
		return true
	return settlement.can_make_room_for(resource_for_role[role], 1, warehouse_positions.size())

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
	# Approximate early-to-late material demand, rather than equal stacks.
	var grants := {"money": 30, "branches": 36, "grass": 20, "water": 24, "food": 18, "hides": 8, "goods": 8, "logs": 16, "wood": 10, "soil": 28, "clay": 22, "boards": 18, "stone": 15, "bricks": 14}
	for resource_type in grants:
		settlement.add(resource_type, grants[resource_type])
	_update_workers()
	_update_interface("Debug resources added in normal spending proportions.")

func _register_service_entrance(building: Node3D, footprint: Vector2i, home_entrance := false, show_marker := true) -> void:
	var service_position := building.to_global(Vector3(0.0, 0.0, footprint.y * 0.5 + SERVICE_PAD_OFFSET))
	service_position.y = building.global_position.y
	building.set_meta("service_position", service_position)
	if home_entrance:
		building.set_meta("entrance_position", service_position)
	service_pockets.append({"cell": _cell_from_position(service_position), "node": building})
	if show_marker:
		_add_service_entrance_marker(building, footprint)

func _add_service_entrance_marker(building: Node3D, footprint: Vector2i) -> void:
	var marker := MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.72, 1.45, 0.12)
	marker.mesh = marker_mesh
	marker.position = Vector3(0.0, 0.73, footprint.y * 0.5 + 0.08)
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("17191c")
	marker_material.roughness = 0.95
	marker.material_override = marker_material
	building.add_child(marker)
	var sign := Label3D.new()
	sign.text = "STAFF"
	sign.position = Vector3(0.0, 1.72, footprint.y * 0.5 + 0.16)
	sign.font_size = 24
	sign.modulate = Color("e5c86b")
	building.add_child(sign)
	var light := OmniLight3D.new()
	light.light_color = Color("ffd58a")
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.shadow_enabled = true
	light.position = Vector3(0.0, 2.2, footprint.y * 0.5 + 0.45)
	light.visible = false
	building.add_child(light)
	entrance_lights.append(light)

func _nearby_player_work_target() -> Node3D:
	if player_citizen == null:
		return null
	for site in construction_sites:
		var node := site.node as Node3D
		if is_instance_valid(node) and player_citizen.global_position.distance_to(node.global_position) <= INTERACTION_RANGE:
			return node
	for site in demolition_sites:
		var building := site.building as Node3D
		if is_instance_valid(building) and player_citizen.global_position.distance_to(building.global_position) <= INTERACTION_RANGE:
			return building
	return null


func _unregister_navigation_footprint(center: Vector3, footprint: Vector2i) -> void:
	for index in range(service_pockets.size() - 1, -1, -1):
		var pocket: Dictionary = service_pockets[index]
		if is_instance_valid(pocket.node) and pocket.node.global_position == center:
			service_pockets.remove_at(index)

func _add_house_light(house: Node3D) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color("ffd58a")
	light.light_energy = 2.2
	light.omni_range = 5.5
	light.shadow_enabled = true
	var footprint: Vector2i = house.get_meta("footprint", Vector2i(5, 5))
	light.position = Vector3(0.0, 2.0, footprint.y * 0.5 + 0.35)
	light.visible = false
	house.add_child(light)
	house_lights.append({"light": light, "house": house, "off_minute": random.randi_range(22 * 60, 26 * 60) % (24 * 60)})

func _on_tree_harvested(worker: Citizen, position_on_board: Vector3) -> void:
	_fell_tree_at(position_on_board)

func _consume_tree_near_player() -> void:
	if player_citizen == null:
		return
	for position_on_board in tree_positions:
		if player_citizen.global_position.distance_to(position_on_board) <= INTERACTION_RANGE:
			var tree: Node3D = tree_nodes.get(_cell_from_position(position_on_board))
			if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
				branches += 1
				_update_interface("Collected branches. The tree remains standing.")
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
	settlement.branches += 3
	_update_interface("A tree was felled. Its log is ready for delivery; the living tree is no longer available for gathering.")

func _update_water_collectors(delta: float) -> void:
	water_collector_service.tick(delta)


func _reserve_dew_collector() -> Vector3:
	return water_collector_service.reserve_dew_collector()


func _has_collected_dew() -> bool:
	return water_collector_service.has_collected_dew()


func _toggle_global_build_menu() -> void:
	var was_visible := build_menu.visible
	_close_context_menus()
	build_menu.visible = not was_visible
	if build_menu.visible:
		build_category = ""
		_refresh_build_menu()
		_show_selected_citizen_menu()


func _create_campfire_menu(ui: CanvasLayer) -> void:
	campfire_menu = Panel.new()
	campfire_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	campfire_menu.offset_left = -324.0
	campfire_menu.offset_top = -720.0
	campfire_menu.offset_right = -20.0
	campfire_menu.offset_bottom = -20.0
	campfire_menu.visible = false
	ui.add_child(campfire_menu)
	
	campfire_menu_title = Label.new()
	campfire_menu_title.position = Vector2(16, 14)
	campfire_menu_title.size = Vector2(272, 40)
	campfire_menu_title.add_theme_font_size_override("font_size", 17)
	campfire_menu.add_child(campfire_menu_title)
	
	campfire_requirements_label = Label.new()
	campfire_requirements_label.position = Vector2(16, 60)
	campfire_requirements_label.size = Vector2(272, 220)
	campfire_requirements_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	campfire_requirements_label.add_theme_font_size_override("font_size", 13)
	campfire_menu.add_child(campfire_requirements_label)
	
	campfire_advance_button = Button.new()
	campfire_advance_button.text = "Advance Era"
	campfire_advance_button.position = Vector2(16, 290)
	campfire_advance_button.size = Vector2(130, 36)
	campfire_advance_button.pressed.connect(_on_campfire_advance_pressed)
	campfire_menu.add_child(campfire_advance_button)

	campfire_orders_button = Button.new()
	campfire_orders_button.text = "Orders"
	campfire_orders_button.position = Vector2(158, 290)
	campfire_orders_button.size = Vector2(130, 36)
	campfire_orders_button.pressed.connect(_show_campfire_orders_menu)
	campfire_menu.add_child(campfire_orders_button)

	campfire_upgrade_button = Button.new()
	campfire_upgrade_button.text = "Upgrade campfire"
	campfire_upgrade_button.position = Vector2(16, 330)
	campfire_upgrade_button.size = Vector2(272, 32)
	campfire_upgrade_button.pressed.connect(_handle_campfire_primary_action)
	campfire_menu.add_child(campfire_upgrade_button)

	var labour_label := Label.new()
	labour_label.text = "Labor Policy:"
	labour_label.position = Vector2(16, 368)
	campfire_menu.add_child(labour_label)
	
	var labour_controls := HBoxContainer.new()
	labour_controls.position = Vector2(16, 393)
	campfire_menu.add_child(labour_controls)
	for hours in [6, 8, 10, 12]:
		var day_button := Button.new()
		day_button.text = "%dh" % hours
		day_button.tooltip_text = "Set workday duration"
		day_button.pressed.connect(_set_workday_hours.bind(hours))
		labour_controls.add_child(day_button)
	var night_button := CheckButton.new()
	night_button.text = "Night shifts"
	night_button.tooltip_text = "Night shifts increase output and reduce wellbeing"
	night_button.toggled.connect(_set_night_shifts)
	labour_controls.add_child(night_button)
	
	campfire_occupancy_button = Button.new()
	campfire_occupancy_button.position = Vector2(16, 438)
	campfire_occupancy_button.size = Vector2(272, 32)
	campfire_occupancy_button.pressed.connect(_show_workforce_menu)
	campfire_menu.add_child(campfire_occupancy_button)

	var campfire_research_button := Button.new()
	campfire_research_button.text = "Research Building Levels"
	campfire_research_button.position = Vector2(16, 478)
	campfire_research_button.size = Vector2(272, 32)
	campfire_research_button.pressed.connect(_show_research_menu)
	campfire_menu.add_child(campfire_research_button)

	# The town hall is the employment centre: manage its officer here, exactly
	# like assigning a cook/teacher/seller at their own workplace.
	campfire_official_button = Button.new()
	campfire_official_button.text = "Assign selected resident as employment officer"
	campfire_official_button.position = Vector2(16, 518)
	campfire_official_button.size = Vector2(272, 32)
	campfire_official_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	campfire_official_button.pressed.connect(_assign_official_at_campfire)
	campfire_menu.add_child(campfire_official_button)

	campfire_accept_button = Button.new()
	campfire_accept_button.position = Vector2(16, 556)
	campfire_accept_button.size = Vector2(272, 32)
	campfire_accept_button.pressed.connect(_toggle_campfire_acceptance)
	campfire_menu.add_child(campfire_accept_button)

	campfire_dismiss_button = Button.new()
	campfire_dismiss_button.text = "Dismiss employment officer"
	campfire_dismiss_button.position = Vector2(16, 594)
	campfire_dismiss_button.size = Vector2(272, 32)
	campfire_dismiss_button.pressed.connect(_dismiss_campfire_worker)
	campfire_menu.add_child(campfire_dismiss_button)

	campfire_overtime_button = Button.new()
	campfire_overtime_button.text = "Вызвать работника сверхурочно"
	campfire_overtime_button.position = Vector2(16, 632)
	campfire_overtime_button.size = Vector2(272, 32)
	campfire_overtime_button.pressed.connect(_call_campfire_worker_overtime)
	campfire_menu.add_child(campfire_overtime_button)

	campfire_close_btn = Button.new()
	campfire_close_btn.text = "Close Menu"
	campfire_close_btn.position = Vector2(16, 634)
	campfire_close_btn.size = Vector2(272, 28)
	campfire_close_btn.pressed.connect(_close_context_menus)
	campfire_menu.add_child(campfire_close_btn)


func _show_campfire_menu() -> void:
	# Keep any resident the player picked selected so they can be appointed as the
	# employment officer here, just like at a canteen/school/market.
	build_menu.visible = false
	selection_marker.visible = false
	build_mode = ""
	campfire_menu.visible = true
	_refresh_campfire_menu()


func _create_campfire_orders_menu(ui: CanvasLayer) -> void:
	campfire_orders_menu = Panel.new()
	campfire_orders_menu.set_anchors_preset(Control.PRESET_CENTER)
	campfire_orders_menu.offset_left = -210.0
	campfire_orders_menu.offset_top = -125.0
	campfire_orders_menu.offset_right = 210.0
	campfire_orders_menu.offset_bottom = 125.0
	campfire_orders_menu.visible = false
	ui.add_child(campfire_orders_menu)
	var title := Label.new()
	title.text = "Campfire Orders"
	title.position = Vector2(18, 16)
	title.size = Vector2(384, 28)
	title.add_theme_font_size_override("font_size", 18)
	campfire_orders_menu.add_child(title)
	campfire_orders_toggle = CheckButton.new()
	campfire_orders_toggle.text = "Walk as if on roads"
	campfire_orders_toggle.position = Vector2(18, 58)
	campfire_orders_toggle.size = Vector2(384, 32)
	campfire_orders_toggle.tooltip_text = "Residents trample trails faster. Route selection is unchanged."
	campfire_orders_toggle.toggled.connect(_set_road_walking_order)
	campfire_orders_menu.add_child(campfire_orders_toggle)
	var description := Label.new()
	description.text = "This order only strengthens new trail marks. Roads are not used for route selection yet."
	description.position = Vector2(18, 98)
	description.size = Vector2(384, 62)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 13)
	campfire_orders_menu.add_child(description)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.position = Vector2(286, 196)
	close_button.size = Vector2(116, 32)
	close_button.pressed.connect(func() -> void: campfire_orders_menu.visible = false)
	campfire_orders_menu.add_child(close_button)


func _show_campfire_orders_menu() -> void:
	if campfire_orders_menu == null or campfire_orders_toggle == null:
		return
	campfire_orders_toggle.set_pressed_no_signal(settlement.road_walking_order_enabled)
	campfire_orders_toggle.disabled = settlement.era != SettlementState.Era.TENT
	campfire_orders_toggle.tooltip_text = "Available in the Tent Era." if campfire_orders_toggle.disabled else "Residents trample trails faster. Route selection is unchanged."
	campfire_orders_menu.visible = true


func _set_road_walking_order(enabled: bool) -> void:
	if settlement.era != SettlementState.Era.TENT:
		return
	settlement.road_walking_order_enabled = enabled
	_update_interface("Trail-walking order %s. It does not change routes yet." % ("enabled" if enabled else "disabled"))


func _create_workforce_menu(ui: CanvasLayer) -> void:
	workforce_menu = Panel.new()
	workforce_menu.set_anchors_preset(Control.PRESET_CENTER)
	workforce_menu.offset_left = -230.0
	workforce_menu.offset_top = -255.0
	workforce_menu.offset_right = 230.0
	workforce_menu.offset_bottom = 255.0
	workforce_menu.visible = false
	ui.add_child(workforce_menu)
	workforce_menu_title = Label.new()
	workforce_menu_title.position = Vector2(18, 16)
	workforce_menu_title.size = Vector2(424, 30)
	workforce_menu_title.add_theme_font_size_override("font_size", 18)
	workforce_menu.add_child(workforce_menu_title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(18, 54)
	scroll.size = Vector2(424, 390)
	workforce_menu.add_child(scroll)
	workforce_list = VBoxContainer.new()
	workforce_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workforce_list.add_theme_constant_override("separation", 6)
	scroll.add_child(workforce_list)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(18, 458)
	close_btn.size = Vector2(424, 32)
	close_btn.pressed.connect(_hide_workforce_menu)
	workforce_menu.add_child(close_btn)


func _show_workforce_menu() -> void:
	if workforce_menu == null:
		return
	if not _officer_exists():
		_update_interface(_labor_command_block_message())
		return
	workforce_menu.visible = true
	_refresh_workforce_menu()


func _hide_workforce_menu() -> void:
	if workforce_menu != null:
		workforce_menu.visible = false


func _refresh_campfire_occupancy_button() -> void:
	if campfire_occupancy_button == null:
		return
	var total := _employment_resident_count()
	var employed := _employment_state_count(Citizen.EmploymentState.EMPLOYED) + _employment_state_count(Citizen.EmploymentState.REGISTERING)
	var daily_order := _employment_state_count(Citizen.EmploymentState.NO_PERMANENT_WORK)
	if not _officer_exists():
		campfire_occupancy_button.text = "Workers automation: assign officer"
		campfire_occupancy_button.disabled = true
		campfire_occupancy_button.tooltip_text = _labor_command_block_message()
	else:
		campfire_occupancy_button.text = "Employment: %d/%d  No permanent: %d" % [employed, total, daily_order]
		campfire_occupancy_button.disabled = false
		campfire_occupancy_button.tooltip_text = ""


func _workforce_roles() -> Array[String]:
	return ["construction", "forestry", "farming", "excavation", "gather_branches", "gather_food", "cook", "teacher", "seller", "official", "factory_worker", "engineer", "craftsman"]


func _daily_order_roles() -> Array[String]:
	return ["helper", "construction", "gather_branches", "gather_grass", "gather_food", "gather_dew", "gather_water"]


func _workforce_role_label(role: String) -> String:
	var labels := {
		"construction": "Construction", "forestry": "Forestry", "farming": "Farming",
		"excavation": "Excavation", "gather_branches": "Gather branches",
		"gather_grass": "Gather grass", "gather_food": "Foraging",
		"gather_dew": "Collect dew", "gather_water": "Collect water",
		"cook": "Cook", "teacher": "Teacher", "seller": "Seller", "official": "Employment officer",
		"factory_worker": "Factory worker", "engineer": "Engineer",
		"helper": "Helper", "courier": "Courier", "craftsman": "Craftsman"
	}
	return str(labels.get(role, role.replace("_", " ").capitalize()))


func _workforce_role_limit(role: String) -> int:
	match role:
		"construction": return _builder_job_capacity() if settlement.era >= SettlementState.Era.STONE else -1
		"forestry": return sawmill_positions.size()
		"farming": return farm_positions.size()
		"gather_branches": return _available_employer_capacity("gather_branches")
		"gather_food": return _available_employer_capacity("gather_food")
		"courier": return warehouse_positions.size()
		"cook": return 1 if is_instance_valid(canteen) else 0
		"official": return _available_employer_capacity("official")
		"teacher": return school_positions.size()
		"seller": return market_positions.size()
		"factory_worker": return _available_employer_capacity("factory_worker")
		"engineer": return _available_employer_capacity("engineer")
		"craftsman": return _available_employer_capacity("craftsman")
	return -1


func _workforce_role_count(role: String) -> int:
	var count := 0
	for citizen in citizens:
		if citizen.is_player_controlled:
			continue
		if role == "courier":
			if citizen.is_courier():
				count += 1
		else:
			if _work_role_for(citizen) == role:
				count += 1
	return count


func _manually_assigned_count(role: String) -> int:
	var count := 0
	for citizen in citizens:
		if not citizen.is_player_controlled:
			if role == "courier" and citizen.is_courier():
				count += 1
			elif citizen.daily_order_role == role:
				count += 1
	return count


func _auto_or_unassigned_worker_count() -> int:
	var count := 0
	for citizen in citizens:
		if not citizen.is_player_controlled:
			if citizen.daily_order_role.is_empty() and citizen.specialization not in ["courier", "cook", "teacher", "factory_worker", "engineer"]:
				count += 1
	return count


func _refresh_workforce_menu() -> void:
	if workforce_menu == null or workforce_list == null:
		return
	for child in workforce_list.get_children():
		child.queue_free()
	var total := _employment_resident_count()
	var employed := _employment_state_count(Citizen.EmploymentState.EMPLOYED)
	var hiring := _employment_state_count(Citizen.EmploymentState.REGISTERING)
	var no_permanent_work := _employment_state_count(Citizen.EmploymentState.NO_PERMANENT_WORK)
	var unregistered := _employment_state_count(Citizen.EmploymentState.UNREGISTERED)
	workforce_menu_title.text = "Employment: %d residents" % total
	_add_workforce_summary("Employed %d   Registering %d   No permanent work %d   Unregistered %d" % [employed, hiring, no_permanent_work, unregistered])

	var jobs_title := Label.new()
	jobs_title.text = "Employed positions"
	jobs_title.add_theme_font_size_override("font_size", 16)
	workforce_list.add_child(jobs_title)
	var shown_jobs := 0
	for role in _workforce_roles():
		var employed_for_role := _employment_role_count(role, Citizen.EmploymentState.EMPLOYED)
		var pending_for_role := _employment_role_count(role, Citizen.EmploymentState.REGISTERING)
		if not _is_role_available(role) and employed_for_role == 0 and pending_for_role == 0:
			continue
		_add_workforce_job_row(role, employed_for_role, pending_for_role)
		shown_jobs += 1
	if shown_jobs == 0:
		_add_workforce_summary("No workplaces are available. Registered residents remain without permanent work.")

	var daily_orders_title := Label.new()
	daily_orders_title.text = "Daily orders"
	daily_orders_title.add_theme_font_size_override("font_size", 16)
	workforce_list.add_child(daily_orders_title)
	_add_workforce_summary("Available %d" % _daily_order_role_count(""))
	for role in _daily_order_roles():
		_add_workforce_summary("Daily order: %s  %d" % [_workforce_role_label(role), _daily_order_role_count(role)])

	var unregistered_residents := _citizens_with_employment_states([Citizen.EmploymentState.UNREGISTERED, Citizen.EmploymentState.REGISTERING])
	if not unregistered_residents.is_empty():
		var unregistered_title := Label.new()
		unregistered_title.text = "Unregistered residents"
		unregistered_title.add_theme_font_size_override("font_size", 16)
		workforce_list.add_child(unregistered_title)
		for citizen in unregistered_residents:
			_add_unemployed_resident_row(citizen)


func _add_workforce_summary(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("c7d6df"))
	workforce_list.add_child(label)


func _add_workforce_job_row(role: String, employed: int, pending: int) -> void:
	var can_command_labor := _player_can_command_labor()
	var blocked_tooltip := _labor_command_block_message()
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(424, 38)
	var label := Label.new()
	var limit := _workforce_role_limit(role)
	var capacity := " / %d" % limit if limit >= 0 else ""
	label.text = "%s\nEmployed %d%s  Hiring %d" % [_workforce_role_label(role), employed, capacity, pending]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var dismiss := Button.new()
	dismiss.text = "Dismiss"
	dismiss.tooltip_text = "Dismiss one resident from this job"
	dismiss.custom_minimum_size = Vector2(78, 34)
	dismiss.disabled = employed + pending == 0 or not can_command_labor
	if not can_command_labor:
		dismiss.tooltip_text = blocked_tooltip
	dismiss.pressed.connect(_remove_worker_from_role.bind(role))
	row.add_child(dismiss)
	var assign := Button.new()
	assign.text = "Assign"
	assign.tooltip_text = "Assign a resident without permanent work"
	assign.custom_minimum_size = Vector2(72, 34)
	assign.disabled = (role != "official" and not can_command_labor) or not _is_role_available(role) or (limit >= 0 and employed + pending >= limit) or not _has_assignable_resident()
	if assign.disabled and role != "official" and not can_command_labor:
		assign.tooltip_text = blocked_tooltip
	assign.pressed.connect(_assign_unemployed_worker.bind(role))
	row.add_child(assign)
	workforce_list.add_child(row)


func _add_unemployed_resident_row(citizen: Citizen) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(424, 34)
	var label := Label.new()
	label.text = "%s%s" % [citizen.role_label(), " (registering)" if citizen.employment_state == Citizen.EmploymentState.REGISTERING else ""]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var auto_button := Button.new()
	auto_button.text = "Registering" if citizen.employment_state == Citizen.EmploymentState.REGISTERING else "Register"
	auto_button.tooltip_text = "Register this resident for workforce assignment"
	auto_button.custom_minimum_size = Vector2(72, 30)
	auto_button.disabled = not _player_can_command_labor() or citizen.employment_state != Citizen.EmploymentState.UNREGISTERED or _employment_center_position() == Vector3.INF
	if not _player_can_command_labor():
		auto_button.tooltip_text = _labor_command_block_message()
	auto_button.pressed.connect(_enable_auto_for_citizen.bind(citizen))
	row.add_child(auto_button)
	workforce_list.add_child(row)


func _employment_resident_count() -> int:
	var count := 0
	for citizen in citizens:
		count += 1 if not citizen.is_player_controlled else 0
	return count


func _employment_state_count(state: int) -> int:
	var count := 0
	for citizen in citizens:
		if not citizen.is_player_controlled and citizen.employment_state == state:
			count += 1
	return count


func _daily_order_role_count(role: String) -> int:
	var count := 0
	for citizen in citizens:
		if not citizen.is_player_controlled and citizen.daily_order_role == role:
			count += 1
	return count


func _employment_role_count(role: String, state: int) -> int:
	var count := 0
	for citizen in citizens:
		if citizen.is_player_controlled:
			continue
		if citizen.employment_state != state:
			continue
		var citizen_role := citizen.permanent_role if state == Citizen.EmploymentState.EMPLOYED else citizen.pending_employment_role
		if citizen_role == role:
			count += 1
	return count


func _citizens_with_employment_states(states: Array) -> Array[Citizen]:
	var result: Array[Citizen] = []
	for citizen in citizens:
		if not citizen.is_player_controlled and citizen.employment_state in states:
			result.append(citizen)
	return result


func _has_assignable_resident() -> bool:
	for citizen in citizens:
		if not citizen.is_player_controlled and citizen.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK:
			return true
	return false


func _remove_worker_from_role(role: String) -> void:
	if not _player_can_command_labor():
		_show_labor_command_blocked()
		return
	for citizen in citizens:
		if citizen.is_player_controlled:
			continue
		if citizen.daily_order_role == role:
			citizen.clear_daily_order()
		elif citizen.permanent_role == role or citizen.pending_employment_role == role:
			citizen.release_to_no_permanent_work()
			citizen.assigned_dig_site = null
		else:
			continue
		_update_workers()
		_refresh_workforce_menu()
		_refresh_campfire_occupancy_button()
		return


func _assign_unemployed_worker(role: String) -> void:
	if role != "official" and not _player_can_command_labor():
		_show_labor_command_blocked()
		return
	if not _is_role_available(role):
		return
	var best: Citizen = null
	var best_score := -INF
	for citizen in citizens:
		if citizen.is_player_controlled:
			continue
		if citizen.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK:
			var score := float(citizen.skills.get(role, 0.0))
			if citizen.preferred_role() == role:
				score += 1.0
			if score > best_score:
				best = citizen
				best_score = score
	if best != null:
		selected_builder = best
		if role == "gather_branches":
			_set_manual_specialist_employment(best, role)
		else:
			_set_selected_work_role(role)
		_refresh_workforce_menu()
		_refresh_campfire_occupancy_button()


func _enable_auto_for_citizen(citizen: Citizen) -> void:
	if not _player_can_command_labor():
		_show_labor_command_blocked()
		return
	if not is_instance_valid(citizen) or citizen.is_player_controlled:
		return
	citizen.request_no_permanent_work_registration()
	_update_workers()
	_refresh_workforce_menu()
	_refresh_campfire_occupancy_button()


func _refresh_campfire_menu() -> void:
	if selected_campfire == null:
		return
	var era_str := _era_name()
	campfire_menu_title.text = "Campfire (Era: %s)" % era_str
	
	var req_text := ""
	var next_era := SettlementState.Era.TENT
	var can_advance := false
	
	var housing_slots := _total_housing_slots()
	
	match settlement.era:
		SettlementState.Era.TENT:
			next_era = SettlementState.Era.EARTH
			var tools_ok := settlement._has_tools(["axe", "hand_saw", "shovel", "bucket"])
			
			req_text = "Requirements for Earth Era:\n"
			req_text += "- Tools (axe, saw, shovel, bucket): %s\n" % ("OK" if tools_ok else "Missing")
			can_advance = settlement.can_advance_to(next_era, citizens.size(), housing_slots)
		
		SettlementState.Era.EARTH:
			next_era = SettlementState.Era.CLAY
			var has_assembly := settlement.has_building("earth_assembly")
			var has_smithy := settlement.has_building("smithy")
			var has_mkt := settlement.has_building("earth_market")
			var pop_ok := housing_slots >= citizens.size()
			var clay_ok := settlement.clay >= 5
			var money_ok := settlement.money >= 5
			var trade_ok := settlement.trade_sales >= 3
			var shovel_ok := settlement._has_tools(["shovel"])
			
			req_text = "Requirements for Clay Era:\n"
			req_text += "- Earth Assembly built: %s\n" % ("Yes" if has_assembly else "No")
			req_text += "- Smithy built: %s\n" % ("Yes" if has_smithy else "No")
			req_text += "- Earth market built: %s\n" % ("Yes" if has_mkt else "No")
			req_text += "- Housing slots (needs %d): %d (%s)\n" % [citizens.size(), housing_slots, "OK" if pop_ok else "Need more"]
			req_text += "- Clay (needs 5): %d (%s)\n" % [settlement.clay, "OK" if clay_ok else "Need more"]
			req_text += "- Money (needs 5): %d (%s)\n" % [settlement.money, "OK" if money_ok else "Need more"]
			req_text += "- Trade sales (needs 3): %d (%s)\n" % [settlement.trade_sales, "OK" if trade_ok else "Need more"]
			req_text += "- Tool Shovel owned: %s\n" % ("Yes" if shovel_ok else "No")
			can_advance = settlement.can_advance_to(next_era, citizens.size(), housing_slots)
			
		SettlementState.Era.CLAY:
			next_era = SettlementState.Era.WOOD
			var has_lodge := settlement.has_building("clay_lodge")
			var has_mkt := settlement.has_building("clay_market")
			var water_ok := water >= citizens.size()
			var logs_ok := settlement.logs >= 10
			var money_ok := settlement.money >= 10
			
			req_text = "Requirements for Wood Era:\n"
			req_text += "- Clay lodge built: %s\n" % ("Yes" if has_lodge else "No")
			req_text += "- Clay market built: %s\n" % ("Yes" if has_mkt else "No")
			req_text += "- Water (needs %d): %d (%s)\n" % [citizens.size(), water, "OK" if water_ok else "Need more"]
			req_text += "- Logs (needs 10): %d (%s)\n" % [settlement.logs, "OK" if logs_ok else "Need more"]
			req_text += "- Money (needs 10): %d (%s)\n" % [settlement.money, "OK" if money_ok else "Need more"]
			can_advance = settlement.can_advance_to(next_era, citizens.size(), housing_slots)
			
		SettlementState.Era.WOOD:
			next_era = SettlementState.Era.STONE
			var has_th := settlement.has_building("wood_town_hall")
			var has_mkt := settlement.has_building("wood_market")
			var has_sm := settlement.has_building("sawmill")
			var has_house3 := settlement.has_building("house_lvl3")
			var pickaxe_ok := settlement._has_tools(["pickaxe"])
			var money_ok := settlement.money >= 15
			
			req_text = "Requirements for Stone Era:\n"
			req_text += "- Wooden town hall built: %s\n" % ("Yes" if has_th else "No")
			req_text += "- Sawmill built: %s\n" % ("Yes" if has_sm else "No")
			req_text += "- Wood market built: %s\n" % ("Yes" if has_mkt else "No")
			req_text += "- Wood house Level 3 built: %s\n" % ("Yes" if has_house3 else "No")
			req_text += "- Tool Pickaxe owned: %s\n" % ("Yes" if pickaxe_ok else "No")
			req_text += "- Money (needs 15): %d (%s)\n" % [settlement.money, "OK" if money_ok else "Need more"]
			can_advance = settlement.can_advance_to(next_era, citizens.size(), housing_slots)

		SettlementState.Era.STONE:
			next_era = SettlementState.Era.BRICK
			var has_pref := settlement.has_building("stone_prefecture")
			var has_mkt := settlement.has_building("stone_market")
			var has_mw := settlement.has_building("masonry_workshop")
			var stone_ok := settlement.stone >= 20
			var money_ok := settlement.money >= 20
			
			req_text = "Requirements for Brick Era:\n"
			req_text += "- Stone prefecture built: %s\n" % ("Yes" if has_pref else "No")
			req_text += "- Masonry workshop built: %s\n" % ("Yes" if has_mw else "No")
			req_text += "- Stone market built: %s\n" % ("Yes" if has_mkt else "No")
			req_text += "- Stone (needs 20): %d (%s)\n" % [settlement.stone, "OK" if stone_ok else "Need more"]
			req_text += "- Money (needs 20): %d (%s)\n" % [settlement.money, "OK" if money_ok else "Need more"]
			can_advance = settlement.can_advance_to(next_era, citizens.size(), housing_slots)
			
		SettlementState.Era.BRICK:
			req_text = "Maximum era reached! Your settlement is fully advanced."
			can_advance = false
			
	campfire_requirements_label.text = req_text
	var unhoused := _unhoused_citizen_count()
	if unhoused > 0:
		campfire_requirements_label.text += "\nProblems:\n- Unhoused residents: %d. Settle them in a home before inviting anyone new.\n" % unhoused
	if not _officer_exists():
		campfire_requirements_label.text += "\nУправление трудом: officer не назначен. Резерв простаивает, но стройка доступна.\n"
	campfire_advance_button.disabled = not can_advance
	if campfire_upgrade_button != null:
		var selected_type := str(selected_campfire.get_meta("building_type", "campfire")) if is_instance_valid(selected_campfire) else ""
		var next_upgrade := settlement.next_building_upgrade(selected_type)
		if is_instance_valid(selected_campfire) and not _is_fire_lit(selected_campfire):
			var fire_state := _fire_state_for(selected_campfire)
			campfire_upgrade_button.visible = true
			campfire_upgrade_button.text = "Relight with flint and steel"
			campfire_upgrade_button.disabled = fire_state.fuel <= 0
			campfire_upgrade_button.tooltip_text = "Deliver branches before relighting." if campfire_upgrade_button.disabled else "Use the permanent flint and steel."
		else:
			campfire_upgrade_button.visible = not next_upgrade.is_empty()
			campfire_upgrade_button.text = "Upgrade to %s" % str(BuildingCatalog.definition_for(next_upgrade).get("name", next_upgrade))
			campfire_upgrade_button.disabled = not settlement.can_upgrade_building(selected_type)
			campfire_upgrade_button.tooltip_text = "" if not campfire_upgrade_button.disabled else "Research the next level and gather its resources."
	_refresh_campfire_worker_controls()
	_refresh_campfire_occupancy_button()


func _refresh_campfire_worker_controls() -> void:
	if campfire_official_button == null:
		return
	var is_center := is_instance_valid(selected_campfire) and str(selected_campfire.get_meta("building_type", "")) in OFFICIAL_WORKPLACE_TYPES
	var accepting := is_center and bool(selected_campfire.get_meta("accepting_workers", true))
	var can_command_labor := _player_can_command_labor()
	var blocked_tooltip := _labor_command_block_message()
	campfire_official_button.visible = is_center
	campfire_official_button.disabled = selected_builder == null or selected_builder.is_player_controlled or not accepting
	campfire_accept_button.visible = is_center
	campfire_accept_button.text = "Stop accepting officer" if accepting else "Start accepting officer"
	campfire_accept_button.disabled = not can_command_labor
	campfire_accept_button.tooltip_text = blocked_tooltip if campfire_accept_button.disabled else ""
	var officer := _workplace_worker(selected_campfire) if is_center else null
	campfire_dismiss_button.visible = is_center
	campfire_dismiss_button.disabled = officer == null or not can_command_labor
	campfire_dismiss_button.tooltip_text = blocked_tooltip if not can_command_labor else ""
	
	if campfire_overtime_button != null:
		campfire_overtime_button.visible = is_center and not _is_work_time() and officer != null
		campfire_overtime_button.disabled = not can_command_labor
		campfire_overtime_button.tooltip_text = blocked_tooltip if not can_command_labor else ""
		if campfire_overtime_button.visible:
			campfire_overtime_button.position.y = 632.0
			campfire_close_btn.position.y = 670.0
		else:
			campfire_close_btn.position.y = 634.0


func _handle_campfire_primary_action() -> void:
	if not is_instance_valid(selected_campfire):
		return
	selected_building = selected_campfire
	if not _is_fire_lit(selected_campfire):
		_relight_selected_fire()
		_refresh_campfire_menu()
		return
	_upgrade_selected_building()


func _assign_official_at_campfire() -> void:
	if not is_instance_valid(selected_campfire):
		return
	selected_building = selected_campfire
	_assign_official()
	_refresh_campfire_menu()


func _toggle_campfire_acceptance() -> void:
	if not _player_can_command_labor():
		_show_labor_command_blocked()
		return
	if not is_instance_valid(selected_campfire):
		return
	selected_building = selected_campfire
	_toggle_selected_workplace_acceptance()


func _dismiss_campfire_worker() -> void:
	if not _player_can_command_labor():
		_show_labor_command_blocked()
		return
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
		settlement.ensure_storage_defaults(warehouse_positions.size())
		_update_interface("Advanced to the %s Era! New buildings unlocked." % _era_name())
		_refresh_campfire_menu()
		_refresh_build_menu()
	else:
		_update_interface("Failed to advance era. Double-check requirements.")


func _create_market_menu(ui: CanvasLayer) -> void:
	market_menu = Panel.new()
	market_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	market_menu.offset_left = -324.0
	market_menu.offset_top = -650.0
	market_menu.offset_right = -20.0
	market_menu.offset_bottom = -20.0
	market_menu.visible = false
	ui.add_child(market_menu)
	
	market_menu_title = Label.new()
	market_menu_title.position = Vector2(16, 14)
	market_menu_title.size = Vector2(272, 70)
	market_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	market_menu.add_child(market_menu_title)


func _show_market_menu() -> void:
	selected_builder = null
	build_menu.visible = false
	selection_marker.visible = false
	build_mode = ""
	market_menu.visible = true
	_refresh_market_menu()


func _refresh_market_menu() -> void:
	if selected_market == null:
		return
	var market_type: String = selected_market.get_meta("building_type", "trade_tent")
	var available_money := _available_trade_money()
	var seller_ok := _is_seller_present_at(selected_market)
	
	market_menu_title.text = "%s Menu\nCoins: %d  Available: %d\nCompleted sales: %d" % [market_type.capitalize().replace("_", " "), settlement.money, available_money, settlement.trade_sales]
	if not seller_ok:
		market_menu_title.text += "\nINACTIVE: Seller is missing!\n(Seller must be working at the market to trade)"
	
	# Clear previous buttons except title
	for child in market_menu.get_children():
		if child != market_menu_title:
			market_menu.remove_child(child)
			child.queue_free()
			
	var y_offset := 104.0 if not seller_ok else 80.0
	
	var sell_items := []
	var buy_items := []
	
	sell_items.append(["branches", 1])
	sell_items.append(["grass", 1])
	sell_items.append(["water", 1])
	sell_items.append(["goods", 5])
	
	if market_type == "trade_tent":
		buy_items.append(["axe", 15])
		buy_items.append(["hand_saw", 15])
		buy_items.append(["shovel", 15])
		buy_items.append(["bucket", 15])
		buy_items.append(["filter_1", 8])
	elif market_type in ["earth_market", "clay_market"]:
		buy_items.append(["hoe", 18])
		buy_items.append(["filter_1", 8])
	elif market_type in ["wood_market", "stone_market", "brick_market"]:
		buy_items.append(["pickaxe", 25])
		buy_items.append(["filter_1", 8])

	if market_type in ["earth_market", "clay_market", "wood_market", "stone_market", "brick_market"]:
		sell_items.append(["soil", 1])

	if market_type in ["clay_market", "wood_market", "stone_market", "brick_market"]:
		sell_items.append(["clay", 2])
		
	if market_type in ["wood_market", "stone_market", "brick_market"]:
		sell_items.append(["wood", 2])
		sell_items.append(["boards", 3])
		
	if market_type in ["stone_market", "brick_market"]:
		sell_items.append(["stone", 3])
		
	if market_type == "brick_market":
		sell_items.append(["bricks", 4])
		
	for item in sell_items:
		var res: String = item[0]
		var price: int = item[1]
		var sellable := mini(5, settlement.amount(res))
		var btn := Button.new()
		btn.text = "Sell %d %s (+%d)  Stock: %d" % [sellable, res, price * sellable, settlement.amount(res)]
		btn.position = Vector2(16, y_offset)
		btn.size = Vector2(272, 28)
		btn.disabled = sellable <= 0 or not seller_ok
		btn.tooltip_text = "Seller is missing" if not seller_ok else ("Nothing left to sell" if sellable <= 0 else "Sell up to five units from available stock")
		btn.pressed.connect(_sell_resource.bind(res, sellable, price))
		market_menu.add_child(btn)
		y_offset += 32.0
		
	y_offset += 10.0
	
	for item in buy_items:
		var tool_name: String = item[0]
		var price: int = item[1]
		var btn := Button.new()
		btn.text = "Buy %s (%d Coins)" % [tool_name.replace("_", " "), price]
		btn.position = Vector2(16, y_offset)
		btn.size = Vector2(272, 28)
		var already_ordered := _trade_has_tool_order(tool_name)
		var owned := bool(settlement.tools.get(tool_name, false))
		btn.disabled = owned or already_ordered or available_money < price or not seller_ok
		btn.tooltip_text = "Seller is missing" if not seller_ok else ("Already owned" if owned else ("Already ordered" if already_ordered else "Not enough available coins" if available_money < price else ""))
		btn.pressed.connect(_buy_tool.bind(tool_name, price))
		market_menu.add_child(btn)
		y_offset += 32.0

	var equipment_target: Citizen = selected_builder if is_instance_valid(selected_builder) and selected_builder.is_courier() else null
	var equipment_offers: Array[Array] = []
	if settlement.era == SettlementState.Era.TENT:
		equipment_offers.append(["simple_backpack", 12])
	elif settlement.era >= SettlementState.Era.CLAY:
		equipment_offers.append(["reinforced_backpack", 22])
		equipment_offers.append(["bicycle", 30])
		if settlement.era >= SettlementState.Era.WOOD:
			equipment_offers.append(["cargo_backpack", 36])
			equipment_offers.append(["bicycle_trailer", 48])
	if not equipment_offers.is_empty():
		y_offset += 10.0
		var equipment_label := Label.new()
		equipment_label.text = "Courier equipment: %s" % (equipment_target.role_label() if equipment_target != null else "select a courier")
		equipment_label.position = Vector2(16, y_offset)
		equipment_label.size = Vector2(272, 22)
		market_menu.add_child(equipment_label)
		y_offset += 24.0
		for offer in equipment_offers:
			var equipment_id: String = offer[0]
			var equipment_price: int = offer[1]
			var equipment_button := Button.new()
			equipment_button.text = "Buy %s (%d Coins)" % [equipment_id.replace("_", " "), equipment_price]
			equipment_button.position = Vector2(16, y_offset)
			equipment_button.size = Vector2(272, 28)
			equipment_button.disabled = not seller_ok or equipment_target == null or equipment_target.courier_equipment == equipment_id or available_money < equipment_price
			equipment_button.tooltip_text = "Select a pinned courier first" if equipment_target == null else ""
			equipment_button.pressed.connect(_buy_courier_equipment.bind(equipment_target, equipment_id, equipment_price))
			market_menu.add_child(equipment_button)
			y_offset += 32.0

	y_offset += 10.0

	# Emergency food supply: the offer is reduced to what can be paid for and
	# stored after accounting for food orders already on the way.
	var room := maxi(0, settlement.storage_room_for("food") - _trade_incoming_resource("food"))
	var buyable := mini(5, mini(room, available_money / FOOD_PURCHASE_PRICE))
	var food_btn := Button.new()
	food_btn.text = "Buy %d food (%d Coins)  Room: %d" % [buyable, buyable * FOOD_PURCHASE_PRICE, room]
	food_btn.position = Vector2(16, y_offset)
	food_btn.size = Vector2(272, 28)
	food_btn.disabled = buyable <= 0 or not seller_ok
	food_btn.tooltip_text = "Seller is missing" if not seller_ok else ("No storage room or available coins" if buyable <= 0 else "Buy food for the settlement")
	food_btn.pressed.connect(_buy_food.bind(buyable, FOOD_PURCHASE_PRICE))
	market_menu.add_child(food_btn)
	y_offset += 42.0

	var close_btn := Button.new()
	close_btn.text = "Close Menu"
	close_btn.position = Vector2(16, y_offset)
	close_btn.size = Vector2(272, 28)
	close_btn.pressed.connect(_close_context_menus)
	market_menu.add_child(close_btn)
	market_menu.offset_top = -maxf(420.0, y_offset + 66.0)


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


func _dispatch_queued_trades() -> void:
	_request_courier_dispatch()


func _on_trade_delivery_finished(worker: Citizen) -> void:
	trade_service.on_trade_delivery_finished(worker)
	courier_dispatcher.complete_for(worker)

func _create_building_menu(ui: CanvasLayer) -> void:
	building_menu = Panel.new()
	building_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	building_menu.offset_left = -324.0
	building_menu.offset_top = -300.0
	building_menu.offset_right = -20.0
	building_menu.offset_bottom = -20.0
	building_menu.visible = false
	ui.add_child(building_menu)
	building_menu_title = Label.new()
	building_menu_title.position = Vector2(16, 14)
	building_menu_title.size = Vector2(272, 82)
	building_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	building_menu.add_child(building_menu_title)
	building_cook_button = Button.new()
	building_cook_button.text = "Assign selected resident as cook"
	building_cook_button.position = Vector2(16, 104)
	building_cook_button.size = Vector2(272, 30)
	building_cook_button.pressed.connect(_assign_cook_at_campfire)
	building_menu.add_child(building_cook_button)
	
	building_teacher_button = Button.new()
	building_teacher_button.text = "Assign selected resident as teacher"
	building_teacher_button.position = Vector2(16, 104)
	building_teacher_button.size = Vector2(272, 30)
	building_teacher_button.pressed.connect(_assign_teacher_at_school)
	building_menu.add_child(building_teacher_button)
	
	building_seller_button = Button.new()
	building_seller_button.text = "Assign selected resident as seller"
	building_seller_button.position = Vector2(16, 104)
	building_seller_button.size = Vector2(272, 30)
	building_seller_button.pressed.connect(_assign_seller_at_market)
	building_menu.add_child(building_seller_button)

	building_official_button = Button.new()
	building_official_button.text = "Assign selected resident as employment officer"
	building_official_button.position = Vector2(16, 104)
	building_official_button.size = Vector2(272, 30)
	building_official_button.pressed.connect(_assign_official)
	building_menu.add_child(building_official_button)
	building_accept_workers_button = Button.new()
	building_accept_workers_button.position = Vector2(16, 104)
	building_accept_workers_button.size = Vector2(272, 30)
	building_accept_workers_button.pressed.connect(_toggle_selected_workplace_acceptance)
	building_menu.add_child(building_accept_workers_button)
	building_dismiss_worker_button = Button.new()
	building_dismiss_worker_button.text = "Dismiss worker"
	building_dismiss_worker_button.position = Vector2(16, 140)
	building_dismiss_worker_button.size = Vector2(272, 30)
	building_dismiss_worker_button.pressed.connect(_dismiss_selected_workplace_worker)
	building_menu.add_child(building_dismiss_worker_button)
	building_overtime_button = Button.new()
	building_overtime_button.text = "Вызвать работника сверхурочно"
	building_overtime_button.position = Vector2(16, 176)
	building_overtime_button.size = Vector2(272, 30)
	building_overtime_button.pressed.connect(_call_worker_overtime)
	building_menu.add_child(building_overtime_button)
	building_relight_button = Button.new()
	building_relight_button.text = "Relight with flint and steel"
	building_relight_button.size = Vector2(272, 30)
	building_relight_button.pressed.connect(_relight_selected_fire)
	building_menu.add_child(building_relight_button)

	building_upgrade_button = Button.new()
	building_upgrade_button.text = "Upgrade"
	building_upgrade_button.position = Vector2(16, 212)
	building_upgrade_button.size = Vector2(272, 30)
	building_upgrade_button.pressed.connect(_upgrade_selected_building)
	building_menu.add_child(building_upgrade_button)

	building_close_button = Button.new()
	building_close_button.text = "Close"
	building_close_button.position = Vector2(16, 184)
	building_close_button.size = Vector2(272, 30)
	building_close_button.pressed.connect(_close_context_menus)
	building_menu.add_child(building_close_button)
	
	building_cancel_construction_button = Button.new()
	building_cancel_construction_button.text = "Cancel construction"
	building_cancel_construction_button.position = Vector2(16, 140)
	building_cancel_construction_button.size = Vector2(272, 30)
	building_cancel_construction_button.pressed.connect(_cancel_selected_construction)
	building_menu.add_child(building_cancel_construction_button)

func _show_building_menu() -> void:
	if not is_instance_valid(selected_building):
		return
	build_menu.visible = false
	building_menu.visible = true
	
	var is_construction := _is_construction_site(selected_building)
	
	if is_construction:
		var site_data := _get_construction_site_data(selected_building)
		var type := site_data.building_type
		var progress := site_data.progress
		var builders := _builder_count(selected_building)
		var supplied_parts: Array[String] = []
		for resource_type in site_data.required_materials:
			supplied_parts.append("%s %d/%d" % [resource_type, int(site_data.delivered_materials.get(resource_type, 0)), int(site_data.required_materials[resource_type])])
		building_menu_title.text = "Under Construction: %s\nMaterials: %s\nProgress: %d%%  Builders: %d" % [type.capitalize().replace("_", " "), ", ".join(supplied_parts), roundi(progress * 100.0), builders]
		
		building_cook_button.visible = false
		building_teacher_button.visible = false
		building_seller_button.visible = false
		building_official_button.visible = false
		building_accept_workers_button.visible = false
		building_dismiss_worker_button.visible = false
		building_upgrade_button.visible = false
		building_relight_button.visible = false
		building_cancel_construction_button.visible = true
		building_cancel_construction_button.position.y = 104.0
		building_close_button.position.y = 140.0
	else:
		var building_type := str(selected_building.get_meta("building_type", "building"))
		var definition := BuildingCatalog.definition_for(building_type)
		building_menu_title.text = "%s\n%s" % [str(definition.get("name", building_type.capitalize())), "Press Delete to mark this building for demolition."]
		building_cook_button.visible = building_type in ["cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant"]
		var can_command_labor := _player_can_command_labor()
		var blocked_tooltip := _labor_command_block_message()
		building_cook_button.disabled = not can_command_labor or selected_builder == null or selected_builder.is_player_controlled or not bool(selected_building.get_meta("accepting_workers", true))
		building_cook_button.tooltip_text = blocked_tooltip if not can_command_labor else ""
		
		building_teacher_button.visible = building_type == "school"
		building_teacher_button.disabled = not can_command_labor or selected_builder == null or selected_builder.is_player_controlled or not bool(selected_building.get_meta("accepting_workers", true))
		building_teacher_button.tooltip_text = blocked_tooltip if not can_command_labor else ""
		
		building_seller_button.visible = building_type in ["trade_tent", "earth_market", "clay_market", "wood_market", "stone_market", "brick_market"]
		building_seller_button.disabled = not can_command_labor or selected_builder == null or selected_builder.is_player_controlled or not bool(selected_building.get_meta("accepting_workers", true))
		building_seller_button.tooltip_text = blocked_tooltip if not can_command_labor else ""

		building_official_button.visible = building_type in OFFICIAL_WORKPLACE_TYPES
		building_official_button.disabled = selected_builder == null or selected_builder.is_player_controlled or not bool(selected_building.get_meta("accepting_workers", true))

		var is_workplace := _is_staffed_workplace(selected_building)
		building_accept_workers_button.visible = is_workplace
		building_dismiss_worker_button.visible = is_workplace
		var next_upgrade := settlement.next_building_upgrade(building_type)
		building_upgrade_button.visible = not next_upgrade.is_empty()
		building_upgrade_button.text = "Upgrade to %s" % str(BuildingCatalog.definition_for(next_upgrade).get("name", next_upgrade))
		building_upgrade_button.disabled = not settlement.can_upgrade_building(building_type)
		building_upgrade_button.tooltip_text = "" if not building_upgrade_button.disabled else "Research the next level and gather its resources."
		building_accept_workers_button.disabled = not can_command_labor
		building_accept_workers_button.tooltip_text = blocked_tooltip if not can_command_labor else ""
		building_cancel_construction_button.visible = false
		building_relight_button.visible = building_type in ["campfire", "campfire_lvl2", "campfire_lvl3", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3"] and not _is_fire_lit(selected_building)
		
		var officer := _workplace_worker(selected_building)
		building_overtime_button.visible = is_workplace and not _is_work_time() and officer != null
		building_overtime_button.disabled = not can_command_labor
		building_overtime_button.tooltip_text = blocked_tooltip if not can_command_labor else ""
		
		if is_workplace:
			var accepting := bool(selected_building.get_meta("accepting_workers", true))
			building_accept_workers_button.text = "Stop accepting workers" if accepting else "Start accepting workers"
			building_accept_workers_button.tooltip_text = "This workplace is priority #%d among open workplaces of the same profession." % _workplace_priority_position(selected_building) if accepting else "Reopen this workplace and move it to the front of the hiring queue."
			building_dismiss_worker_button.disabled = officer == null or not can_command_labor
			building_dismiss_worker_button.tooltip_text = blocked_tooltip if not can_command_labor else ""
		
		var next_y := 104.0
		if building_accept_workers_button.visible:
			building_accept_workers_button.position.y = next_y
			next_y += 36.0
		if building_dismiss_worker_button.visible:
			building_dismiss_worker_button.position.y = next_y
			next_y += 36.0
		if building_overtime_button.visible:
			building_overtime_button.position.y = next_y
			next_y += 36.0
		if building_relight_button.visible:
			building_relight_button.position.y = next_y
			next_y += 36.0
		if building_upgrade_button.visible:
			building_upgrade_button.position.y = next_y
			next_y += 36.0
			
		var special_button_visible := building_cook_button.visible or building_teacher_button.visible or building_seller_button.visible or building_official_button.visible
		for button in [building_cook_button, building_teacher_button, building_seller_button, building_official_button]:
			if button.visible:
				button.position.y = next_y
		if special_button_visible:
			next_y += 44.0
		else:
			next_y += 8.0
		building_close_button.position.y = next_y


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
	if not _player_can_command_labor():
		_show_labor_command_blocked()
		return
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
	if not _player_can_command_labor():
		_show_labor_command_blocked()
		return
	var worker := _workplace_worker(selected_building)
	if worker == null:
		return
	selected_building.set_meta("accepting_workers", false)
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
	if settlement.pay_for_building_upgrade(old_type).is_empty():
		return
	for child in selected_building.get_children():
		selected_building.remove_child(child)
		child.queue_free()
	if selected_building.has_meta("status_indicator"):
		selected_building.remove_meta("status_indicator")
	selected_building.set_meta("building_type", target_type)
	selected_building.set_meta("footprint", blueprint.footprint)
	selected_building.set_meta("occupied_footprint", blueprint.footprint)
	for module in blueprint.modules:
		selected_building.add_child(BuildingBlueprints.create_module(module))
	_unregister_navigation_footprint(selected_building.global_position, old_footprint)
	_register_service_entrance(selected_building, blueprint.footprint, false, target_type not in ["farm", "park"])
	var service_position: Vector3 = selected_building.get_meta("service_position", selected_building.global_position)
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


func _create_warehouse_menu(ui: CanvasLayer) -> void:
	warehouse_menu = Panel.new()
	warehouse_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	warehouse_menu.offset_left = -344.0
	warehouse_menu.offset_top = -660.0
	warehouse_menu.offset_right = -20.0
	warehouse_menu.offset_bottom = -20.0
	warehouse_menu.visible = false
	ui.add_child(warehouse_menu)

	warehouse_menu_title = Label.new()
	warehouse_menu_title.position = Vector2(16, 12)
	warehouse_menu_title.size = Vector2(292, 60)
	warehouse_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warehouse_menu_title.add_theme_font_size_override("font_size", 15)
	warehouse_menu.add_child(warehouse_menu_title)


func _show_warehouse_menu() -> void:
	selected_builder = null
	build_menu.visible = false
	selection_marker.visible = false
	build_mode = ""
	warehouse_menu.visible = true
	_refresh_warehouse_menu()


func _refresh_warehouse_menu() -> void:
	if selected_warehouse == null:
		return
	var warehouses := warehouse_positions.size()
	var capacity := settlement.storage_capacity(warehouses)
	var used := settlement.storage_used_units()
	var free := settlement.storage_free_units(warehouses)
	warehouse_menu_title.text = "Storage balance\nUsed %d / %d units   Free to assign: %d\nMove capacity between goods (%d units per click)." % [int(ceil(used)), capacity, int(floor(free)), int(SettlementState.STORAGE_STEP)]

	for child in warehouse_menu.get_children():
		if child != warehouse_menu_title:
			child.queue_free()

	var y_offset := 82.0
	for resource_type in SettlementState.STORED_RESOURCES:
		var limit := settlement.storage_limit(resource_type)
		var weight := settlement.storage_weight(resource_type)
		var stored_units := settlement.amount(resource_type) * weight
		var row := Label.new()
		row.position = Vector2(16, y_offset + 4)
		row.size = Vector2(180, 24)
		row.add_theme_font_size_override("font_size", 13)
		row.text = "%s  %d (%d/%d u, x%.1f)" % [resource_type, settlement.amount(resource_type), int(ceil(stored_units)), int(round(limit)), weight]
		warehouse_menu.add_child(row)
		var minus := Button.new()
		minus.text = "-"
		minus.position = Vector2(238, y_offset)
		minus.size = Vector2(32, 28)
		minus.pressed.connect(_adjust_storage.bind(resource_type, -SettlementState.STORAGE_STEP))
		warehouse_menu.add_child(minus)
		var plus := Button.new()
		plus.text = "+"
		plus.position = Vector2(274, y_offset)
		plus.size = Vector2(32, 28)
		plus.pressed.connect(_adjust_storage.bind(resource_type, SettlementState.STORAGE_STEP))
		warehouse_menu.add_child(plus)
		y_offset += 32.0

	var demolish_btn := Button.new()
	demolish_btn.text = "Mark for demolition"
	demolish_btn.position = Vector2(16, y_offset + 8)
	demolish_btn.size = Vector2(290, 28)
	demolish_btn.pressed.connect(func(): _mark_building_for_demolition(selected_warehouse))
	warehouse_menu.add_child(demolish_btn)

	var close_btn := Button.new()
	close_btn.text = "Close Menu"
	close_btn.position = Vector2(16, y_offset + 42)
	close_btn.size = Vector2(290, 28)
	close_btn.pressed.connect(_close_context_menus)
	warehouse_menu.add_child(close_btn)


func _adjust_storage(resource_type: String, delta_units: float) -> void:
	settlement.adjust_storage_limit(resource_type, delta_units, warehouse_positions.size())
	_refresh_warehouse_menu()


func _assign_cook_at_campfire() -> void:
	if not _player_can_command_labor():
		_show_labor_command_blocked()
		return
	if selected_builder == null:
		_update_interface("Select a resident first, then click the cooking campfire to make them the cook.")
		return
	if selected_builder.is_player_controlled:
		_update_interface("Pick a settler, not the character you are controlling.")
		return
	if not _set_manual_specialist_employment(selected_builder, "cook"):
		return
	selected_builder.setup_specialization("cook")
	_update_interface("%s is registering as a cook." % selected_builder.role_label())
	_update_workers()


func _assign_teacher_at_school() -> void:
	if not _player_can_command_labor():
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
	if not _player_can_command_labor():
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


func _assign_official() -> void:
	if selected_builder == null:
		_update_interface("Select a resident first, then assign them as the officer at the main campfire or town hall.")
		return
	if selected_builder.is_player_controlled:
		_update_interface("Pick a settler, not the character you are controlling.")
		return
	_appoint_official(selected_builder)
	_update_interface("%s is now the employment officer." % selected_builder.role_label())
	_update_workers()


func _appoint_official(citizen: Citizen) -> void:
	# A mayoral appointment selects the settlement's single registration officer.
	# It is independent of who the player currently controls.
	if citizen == null:
		return
	for other in citizens:
		if not is_instance_valid(other) or other == citizen or other.permanent_role != "official":
			continue
		other.idle()
		other.setup_specialization("unassigned")
		other.release_to_no_permanent_work()
	citizen.idle()
	citizen.setup_specialization("official")
	citizen.clear_daily_order()
	citizen.assigned_dig_site = null
	citizen.pending_employment_role = ""
	citizen.pending_employment_workplace = null
	citizen.permanent_role = "official"
	citizen.employment_workplace = _employer_for_role("official")
	citizen.employment_state = Citizen.EmploymentState.EMPLOYED
	if not is_instance_valid(citizen.employment_workplace):
		citizen.active_role = ""
	_refresh_labor_authority_indicator()


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
		# Start the post in the same hand-off so another scheduler tick cannot
		# replace the job before the route starts.
		if not citizen.is_player_controlled and _is_work_time():
			citizen.assign_official_work(service_position)
		else:
			citizen.idle()
	_update_workers()


func _set_manual_specialist_employment(citizen: Citizen, role: String) -> bool:
	if not _player_can_command_labor():
		_show_labor_command_blocked()
		return false
	if citizen.employment_state != Citizen.EmploymentState.NO_PERMANENT_WORK:
		return false
	citizen.idle()
	citizen.begin_employment_processing(_employment_center_position(), role, _employer_for_role(role))
	return true


func _find_forage_position(citizen: Citizen) -> Vector3:
	# Foragers wander a short way out from their tent to pick wild food, then carry
	# it back to storage. Without a forager tent there is nowhere to forage.
	if forager_positions.is_empty():
		return Vector3.INF
	var hut := forager_positions[0]
	var closest_dist := INF
	for pos in forager_positions:
		var dist := citizen.global_position.distance_squared_to(pos)
		if dist < closest_dist:
			closest_dist = dist
			hut = pos
	var angle := randf_range(0.0, 2.0 * PI)
	var radius := randf_range(2.5, 6.0)
	var spot := hut + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	var height := _terrain_height_at(spot.x, spot.z, 0.0)
	if not is_nan(height):
		spot.y = height
	return spot

func _create_grass_sources_near_tree(tree_cell: Vector2i) -> void:
	for offset in [Vector2i(2, 0), Vector2i(-2, 1), Vector2i(1, -2)]:
		var cell: Vector2i = tree_cell + offset
		if grass_sources.has(cell) or tree_cells.has(cell):
			continue
		var position := _cell_center(cell)
		var node := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.3
		mesh.bottom_radius = 0.3
		mesh.height = 0.06
		node.mesh = mesh
		node.position = position + Vector3.UP * 0.05
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("4fbc55")
		material.emission_enabled = true
		material.emission = Color("245b2a")
		node.material_override = material
		add_child(node)
		grass_sources[cell] = {"node": node, "remaining": random.randi_range(2, 5)}

func _create_forage_sources_near_tree(tree_cell: Vector2i) -> void:
	for offset in [Vector2i(3, 1), Vector2i(-3, -1)]:
		var cell: Vector2i = tree_cell + offset
		if forage_sources.has(cell) or tree_cells.has(cell) or _is_navigation_cell_blocked(cell):
			continue
		var node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.42, 0.22, 0.42)
		node.mesh = mesh
		node.position = _cell_center(cell) + Vector3.UP * 0.12
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("75a84c")
		material.emission_enabled = true
		material.emission = Color("27451c")
		node.material_override = material
		add_child(node)
		forage_sources[cell] = {"node": node}

func _spawn_initial_rabbits() -> void:
	for tree_cell in tree_cells.keys():
		if rabbit_sources.size() >= RABBIT_MAX_COUNT:
			break
		_spawn_rabbit_near_tree(tree_cell as Vector2i)

func _spawn_rabbit_near_tree(tree_cell: Vector2i) -> void:
	for offset in [Vector2i(4, 0), Vector2i(-4, 2), Vector2i(2, -4)]:
		var cell: Vector2i = tree_cell + offset
		if rabbit_sources.has(cell) or tree_cells.has(cell) or _is_navigation_cell_blocked(cell):
			continue
		var node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.48, 0.32, 0.32)
		node.mesh = mesh
		node.position = _cell_center(cell) + Vector3.UP * 0.16
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("d5d1c3")
		node.material_override = material
		add_child(node)
		rabbit_sources[cell] = {"node": node, "direction": Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()}
		return

func _update_wild_food(delta: float) -> void:
	for source in rabbit_sources.values():
		var rabbit := source.get("node") as Node3D
		if not is_instance_valid(rabbit):
			continue
		var direction: Vector3 = source.get("direction", Vector3.FORWARD)
		if randf() < delta * 0.7:
			direction = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
			source.direction = direction
		var next := rabbit.global_position + direction * delta * 0.7
		if _is_navigation_cell_blocked(_cell_from_position(next)):
			source.direction = -direction
		else:
			rabbit.global_position = next
	for cell in forage_respawn_at.keys().duplicate():
		if runtime_seconds >= float(forage_respawn_at[cell]):
			_create_forage_sources_near_tree((cell as Vector2i) - Vector2i(3, 1))
			forage_respawn_at.erase(cell)
	for cell in rabbit_respawn_at.keys().duplicate():
		if runtime_seconds >= float(rabbit_respawn_at[cell]) and rabbit_sources.size() < RABBIT_MAX_COUNT:
			_spawn_rabbit_near_tree(cell as Vector2i)
			rabbit_respawn_at.erase(cell)

func harvest_wild_food(position: Vector3, worker: Citizen) -> String:
	var plant_cell := _cell_from_position(position)
	if forage_sources.has(plant_cell):
		var plant := (forage_sources[plant_cell] as Dictionary).get("node") as Node3D
		if is_instance_valid(plant):
			plant.queue_free()
		forage_sources.erase(plant_cell)
		forage_respawn_at[plant_cell] = runtime_seconds + WILD_FOOD_RESPAWN_SECONDS
		return "food"
	for cell in rabbit_sources:
		var source := rabbit_sources[cell] as Dictionary
		var rabbit := source.get("node") as Node3D
		if is_instance_valid(rabbit) and rabbit.global_position.distance_to(position) <= 1.6:
			worker.play_hunting_shot()
			rabbit.queue_free()
			rabbit_sources.erase(cell)
			rabbit_respawn_at[cell] = runtime_seconds + RABBIT_RESPAWN_SECONDS
			return "hides" if randf() < 0.35 else "food"
	return ""

func _consume_grass_source(position: Vector3) -> void:
	var cell := _cell_from_position(position)
	if not grass_sources.has(cell):
		return
	var source: Dictionary = grass_sources[cell]
	source.remaining = maxi(0, int(source.remaining) - 1)
	if int(source.remaining) == 0:
		if is_instance_valid(source.node):
			source.node.queue_free()
		grass_sources.erase(cell)
	else:
		grass_sources[cell] = source

func _consume_tree_branches(position: Vector3) -> void:
	var tree: Node3D = tree_nodes.get(_cell_from_position(position))
	if not is_instance_valid(tree):
		return
	var remaining := int(tree.get_meta("remaining_branches", 0))
	var hand_taken := int(tree.get_meta("hand_branches", 0))
	var hand_limit := ceili(float(int(tree.get_meta("initial_branches", remaining))) * 0.3)
	if not tree.has_meta("initial_branches"):
		tree.set_meta("initial_branches", remaining)
		hand_limit = ceili(float(remaining) * 0.3)
	if not bool(settlement.tools.get("axe", false)) and hand_taken >= hand_limit:
		return
	tree.set_meta("remaining_branches", maxi(0, remaining - 1))
	if not bool(settlement.tools.get("axe", false)):
		tree.set_meta("hand_branches", hand_taken + 1)

func _create_gathering_place_visual(building: Node3D) -> void:
	var racket := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.06, 1.0)
	racket.mesh = mesh
	racket.position = Vector3(-1.7, 0.22, -2.6)
	racket.rotation_degrees = Vector3(0.0, 28.0, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("3a3a3a")
	racket.material_override = material
	building.add_child(racket)

func _building_at_service_position(position: Vector3) -> Node3D:
	return building_registry.building_at_service_position(position)


func _fire_state_for(building: Node3D) -> RefCounted:
	if not is_instance_valid(building):
		return FireSourceStateScript.new()
	return FireSourceStateScript.from_values(
		int(building.get_meta("fire_fuel", 0)),
		int(building.get_meta("fire_reserved", 0)),
		bool(building.get_meta("fire_lit", true))
	)


func _apply_fire_state(building: Node3D, fire_state: RefCounted) -> void:
	if not is_instance_valid(building) or fire_state == null:
		return
	building.set_meta("fire_fuel", fire_state.fuel)
	building.set_meta("fire_reserved", fire_state.reserved_fuel)
	building.set_meta("fire_lit", fire_state.lit)


func _is_fire_lit(building: Node3D) -> bool:
	return is_instance_valid(building) and _fire_state_for(building).lit


func fire_smoke_work_multiplier(position_on_board: Vector3) -> float:
	if smoky_firewood_day != day_cycle.current_day:
		return 1.0
	for record in building_registry.records():
		var building: Node3D = record.node
		if is_instance_valid(building) and _is_fire_lit(building) and building.global_position.distance_to(position_on_board) <= 15.0:
			return 0.70
	return 1.0

func _update_fire_status() -> void:
	# Fires consume one large branch each four simulated hours. Keeping them
	# supplied from storage is a logistics task; without branches the service is
	# deliberately unavailable.
	var minute := int(game_minutes)
	if minute % (4 * 60) != 0 or get_meta("last_fire_tick", -1) == minute:
		return
	set_meta("last_fire_tick", minute)
	for record in building_registry.records():
		var building := record.node
		if not is_instance_valid(building) or str(building.get_meta("building_type", "")) not in ["campfire", "campfire_lvl2", "campfire_lvl3", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3"]:
			continue
		var fire_state := _fire_state_for(building)
		fire_state.consume(1)
		_apply_fire_state(building, fire_state)
		for child in building.get_children():
			if child is OmniLight3D:
				child.visible = fire_state.lit
	if is_instance_valid(campfire_node) and not _is_fire_lit(campfire_node):
		wellbeing = maxi(0, wellbeing - 1)
	_refresh_living_statuses()

func _apply_building_wear_and_repairs() -> void:
	for record in building_registry.records():
		var building := record.node
		if not is_instance_valid(building):
			continue
		var building_type := str(building.get_meta("building_type", ""))
		if bool(building.get_meta("ruined", false)):
			continue
		var era := BuildingCatalog.era_for(building_type)
		if era > SettlementState.Era.EARTH:
			continue
		var wear := 8.0 if era == SettlementState.Era.TENT else 3.0
		var condition := maxf(0.0, float(building.get_meta("condition", 100.0)) - wear)
		building.set_meta("condition", condition)
		building.set_meta("repair_needed", condition < 82.0)
		if condition <= 0.0:
			_destroy_building_to_pile(building, building_type)

func _has_active_builder() -> bool:
	for citizen in citizens:
		if citizen.permanent_role == "construction" or citizen.specialization == "builder":
			return true
	return false

func _destroy_building_to_pile(building: Node3D, building_type: String) -> void:
	var resources: Dictionary = BuildingCatalog.demolition_refund(building_type).duplicate(true)
	if building_type in ["warehouse", "warehouse_lvl2"]:
		_move_stored_resources_to_pile(resources)
	for citizen in citizens:
		if citizen.home == building:
			citizen.home = null
			_refresh_living_status(citizen)
	_return_in_transit_building_supplies(building)
	_remove_building_services(building, building_type)
	var removed_record := building_registry.remove_node(building)
	if removed_record != null:
		_unregister_navigation_footprint(removed_record.center, removed_record.footprint)
	settlement.buildings[building_type] = maxi(0, int(settlement.buildings.get(building_type, 1)) - 1)
	settlement.ensure_storage_defaults(warehouse_positions.size())
	if campfire_node == null:
		_select_best_campfire()
	_create_resource_pile(building.global_position, resources)
	building.queue_free()
	_refresh_navigation_grid()
	_update_workers()


func _move_stored_resources_to_pile(resources: Dictionary) -> void:
	for resource_type in SettlementState.STORED_RESOURCES:
		var amount := settlement.amount(resource_type)
		if amount <= 0:
			continue
		resources[resource_type] = int(resources.get(resource_type, 0)) + amount
		settlement.add(resource_type, -amount)


func _select_best_campfire() -> void:
	var best_campfire: Node3D = null
	var best_rank := -1
	var ranks := {
		"campfire": 1, "campfire_lvl2": 2, "campfire_lvl3": 3,
		"earth_assembly": 4, "clay_lodge": 5, "wood_town_hall": 6,
		"stone_prefecture": 7, "brick_city_hall": 8,
	}
	for record in building_registry.records():
		var candidate: Node3D = record.node
		if not is_instance_valid(candidate):
			continue
		var rank := int(ranks.get(str(candidate.get_meta("building_type", "")), -1))
		if rank > best_rank:
			best_campfire = candidate
			best_rank = rank
	campfire_node = best_campfire
	if is_instance_valid(campfire_node):
		_activate_employment_centre(campfire_node)

func _create_resource_pile(position: Vector3, resources: Dictionary) -> void:
	if resources.is_empty():
		return
	var pile := Node3D.new()
	pile.position = position

	# Base dirt mound
	var base_mesh_node := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.8
	base_mesh.bottom_radius = 1.1
	base_mesh.height = 0.4
	base_mesh_node.mesh = base_mesh
	base_mesh_node.position.y = 0.2
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color("5c4033")
	base_mesh_node.material_override = base_mat
	pile.add_child(base_mesh_node)

	# Logs
	var log_mesh := BoxMesh.new()
	log_mesh.size = Vector3(1.2, 0.25, 0.25)
	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color("4a3225")

	var log1 := MeshInstance3D.new()
	log1.mesh = log_mesh
	log1.position = Vector3(-0.3, 0.35, 0.2)
	log1.rotation_degrees = Vector3(10, 25, 5)
	log1.material_override = log_mat
	pile.add_child(log1)

	var log2 := MeshInstance3D.new()
	log2.mesh = log_mesh
	log2.position = Vector3(0.2, 0.4, -0.2)
	log2.rotation_degrees = Vector3(-15, -35, -8)
	log2.material_override = log_mat
	pile.add_child(log2)

	# Grass clump
	var grass_pile := MeshInstance3D.new()
	var grass_mesh := BoxMesh.new()
	grass_mesh.size = Vector3(0.8, 0.3, 0.8)
	grass_pile.mesh = grass_mesh
	grass_pile.position = Vector3(0.3, 0.3, 0.3)
	grass_pile.rotation_degrees = Vector3(5, 12, -5)
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color("739350")
	grass_pile.material_override = grass_mat
	pile.add_child(grass_pile)

	# A stone
	var stone_pile := MeshInstance3D.new()
	var stone_mesh := BoxMesh.new()
	stone_mesh.size = Vector3(0.4, 0.3, 0.4)
	stone_pile.mesh = stone_mesh
	stone_pile.position = Vector3(-0.2, 0.3, -0.4)
	stone_pile.rotation_degrees = Vector3(20, 45, 10)
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color("6f747a")
	stone_pile.material_override = stone_mat
	pile.add_child(stone_pile)

	var label := Label3D.new()
	label.text = "RESOURCES"
	label.position.y = 1.7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pile.add_child(label)
	add_child(pile)
	resource_piles.append({"node": pile, "resources": resources, "reserved": {}})

func _decay_resource_piles() -> void:
	for index in range(resource_piles.size() - 1, -1, -1):
		var pile: Dictionary = resource_piles[index]
		for resource_type in pile.resources.keys():
			var remaining := int(pile.resources[resource_type])
			var daily_rate := 0.10 if resource_type == "food" else 0.05 if resource_type in ["grass", "branches", "wood", "logs"] else 0.0
			if remaining > 0 and daily_rate > 0.0:
				pile.resources[resource_type] = maxi(0, remaining - maxi(1, ceili(remaining * daily_rate)))
		var empty := true
		for amount in pile.resources.values():
			if int(amount) > 0:
				empty = false
		if empty:
			if is_instance_valid(pile.node):
				pile.node.queue_free()
			resource_piles.remove_at(index)
		else:
			resource_piles[index] = pile

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
	if not warehouse_positions.is_empty():
		var nearest := warehouse_positions[0]
		var nearest_distance := from.distance_squared_to(nearest)
		for position in warehouse_positions:
			var distance := from.distance_squared_to(position)
			if distance < nearest_distance:
				nearest = position
				nearest_distance = distance
		return nearest
	elif is_instance_valid(campfire_node):
		return campfire_node.global_position
	else:
		return entrance_stone.global_position

func _is_construction_site(node: Node3D) -> bool:
	return is_instance_valid(node) and construction.has_site(node)

func _get_construction_site_data(node: Node3D) -> ConstructionSite:
	return construction.site_for_node(node)

func _cancel_selected_construction() -> void:
	if not is_instance_valid(selected_building) or not _is_construction_site(selected_building):
		return
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


func _call_worker_overtime() -> void:
	if not _player_can_command_labor():
		_show_labor_command_blocked()
		return
	if not is_instance_valid(selected_building):
		return
	var workers_found := false
	for citizen in citizens:
		if is_instance_valid(citizen) and (citizen.employment_workplace == selected_building or citizen.pending_employment_workplace == selected_building):
			citizen.overtime_mode = true
			citizen.satisfaction = maxf(0.0, citizen.satisfaction - 25.0)
			workers_found = true
			_add_message("Работник %s вызван сверхурочно. Уровень удовольствия снизился." % [citizen.role_label()])
	if workers_found:
		_update_workers()
		_reopen_workplace_menu()


func _call_campfire_worker_overtime() -> void:
	if not is_instance_valid(selected_campfire):
		return
	selected_building = selected_campfire
	_call_worker_overtime()
	_refresh_campfire_menu()
