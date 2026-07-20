class_name Citizen
extends CharacterBody3D

const CitizenStatusEffectScript = preload("res://game/features/citizens/domain/citizen_status_effect.gd")
const CitizenProfileScript = preload("res://game/features/citizens/domain/citizen_profile.gd")
const CitizenEmploymentStateScript = preload("res://game/features/citizens/domain/citizen_employment_state.gd")
const CitizenNeedsStateScript = preload("res://game/features/citizens/domain/citizen_needs_state.gd")

signal resource_delivered(worker: Citizen, resource_type: String, amount: int)
signal resource_dropped(worker: Citizen, resource_type: String, amount: int)
signal construction_material_delivered(worker: Citizen, site: Node3D, resource_type: String, amount: int)
signal building_supply_delivered(worker: Citizen, target: Node3D, supply_kind: String, resource_type: String, amount: int)
signal excavation_cycle(worker: Citizen, site: Node3D, efficiency: float)
signal resource_ready(worker: Citizen, resource_type: String, amount: int)
signal tree_harvested(worker: Citizen, position_on_board: Vector3)
signal logs_delivered(worker: Citizen, sawmill_position: Vector3, amount: int)
signal sawmill_boards_collected(courier: Citizen, sawmill_position: Vector3)
signal dew_collected(courier: Citizen, collector_position: Vector3)
signal meal_finished(worker: Citizen)
signal relief_finished(worker: Citizen)
signal leisure_finished(worker: Citizen)
signal canteen_delivery_finished(worker: Citizen, amount: int)
signal factory_cycle(worker: Citizen, factory: Node3D)
signal trade_delivery_finished(worker: Citizen)
signal arrival_greeter_ready(worker: Citizen)
signal outside_work_departed(worker: Citizen)
signal citizen_leaving_departed(citizen: Citizen)

const WALK_SPEED := 2.2
const WORK_DURATION := 1.4
const COURIER_WAIT_DURATION := 8.0
# One in-game hour at base speed (1440 game-min / 300 real-sec = 4.8 game-min/s).
# Both this timer and the clock advance with the same scaled delta, so the wait
# always spans exactly one in-game hour regardless of the simulation speed.
const WAIT_DURATION := 12.5
const EMPLOYMENT_PROCESS_DURATION := 12.5
const ARRIVAL_MEETING_DURATION := 3.0
const WAIT_RECHECK_INTERVAL := 1.0
const GRAVITY := 18.0
const AI_JUMP_VELOCITY := 7.6
const STUCK_TIME_BEFORE_JUMP := 0.75
const STUCK_TIME_BEFORE_REPATH := 1.5
const CONSTRUCTION_SLOT_SPACING := 0.42
const CONSTRUCTION_APPROACH_DISTANCE := 1.0
const ROUTE_PROGRESS_EPSILON := 0.06
const ROUTE_RETRY_INTERVAL := 2.0
const ROUTE_MAX_RETRY_INTERVAL := 16.0
const ROUTE_UNREACHABLE_FAILURE_TIME := 8.0
const ROUTE_RECOVERY_FAILURE_ATTEMPTS := 4
const STALE_NAVIGATION_REPLAN_JITTER := 0.35
const PHYSICAL_ARRIVAL_RADIUS := 0.34
const IDLE_WANDER_RADIUS := 3.0
const IDLE_WANDER_MIN_PAUSE := 2.5
const IDLE_WANDER_MAX_PAUSE := 6.0
const IDLE_WANDER_CANDIDATES := 8
const IDLE_PERSONAL_SPACE := 1.15
const MIN_STATE_DISPLAY_DURATION := 1.0
const MAX_PENDING_STATE_DISPLAY_TRANSITIONS := 6

enum State { IDLE, WAITING, TO_TREE, CHOPPING, TO_SAWMILL, SAWING, TO_WAREHOUSE, CONSTRUCTING, EXCAVATING, COURIER_TO_WORKER, COURIER_TO_WAREHOUSE, WAITING_COURIER, TO_HOME, RESTING, TO_CANTEEN, EATING, TO_FOOD_PICKUP, TO_CANTEEN_DELIVERY, TO_CANTEEN_WORK, TO_SCHOOL, STUDYING, TO_SCHOOL_WORK, TO_FACTORY, FACTORY_WORK, TO_PARK, RELAXING, COURIER_TO_SAWMILL, COURIER_TO_DEW, TO_GATHER, GATHERING, TO_CLEANING_PILE, CLEANING_PILE, TO_TRADE_PICKUP, TO_TRADE_DESTINATION, TO_EMPLOYMENT_CENTER, EMPLOYMENT_PROCESSING, CANTEEN_WORK, SCHOOL_WORK, TO_MARKET_WORK, MARKET_WORK, TO_CRAFT_WORK, CRAFT_WORK, TO_CONSTRUCTION_PICKUP, TO_CONSTRUCTION_SITE, TO_OFFICIAL_WORK, OFFICIAL_WORK, TO_ARRIVAL_ENTRANCE, ARRIVAL_MEETING, ARRIVAL_WAITING, TO_ARRIVAL_CENTER, TO_OUTSIDE_WORK, RESEARCHING, TO_TOILET, USING_TOILET, WAITING_FOR_TOILET, TO_BUSH, USING_BUSH, AI_MOVING, WORK_POSITION, LEAVING }

const EmploymentState = CitizenEmploymentStateScript.EmploymentState

const DAILY_ORDER_ROLES := CitizenEmploymentStateScript.DAILY_ORDER_ROLES

signal state_changed(citizen: Citizen, previous_state: int, next_state: int)

# State changes drive simulation immediately. The label intentionally follows a
# short queue so quick scheduler hand-offs remain observable instead of
# being overwritten in the same frame.
var _state := State.IDLE
var state: int:
	get:
		return _state
	set(next_state):
		if _state == next_state:
			return
		if work_position_locked and not _is_work_position_state(next_state):
			_clear_work_position_lock()
		var previous_state: int = _state
		_state = next_state
		if next_state == State.IDLE and queue_release_notifier.is_valid():
			queue_release_notifier.call(self)
		if _pending_state_display.size() >= MAX_PENDING_STATE_DISPLAY_TRANSITIONS:
			_pending_state_display[-1] = next_state
		else:
			_pending_state_display.append(next_state)
		state_changed.emit(self, previous_state, next_state)
var _displayed_state := State.IDLE
var _displayed_state_elapsed := 0.0
var _pending_state_display: Array[int] = []

# Work-position lock shared by FPP and AI service workers. While locked, the
# citizen is anchored to a workplace and movement input is ignored.
var work_position_locked := false
var work_position_anchor := Vector3.INF
var work_position_role := ""
var work_position_node: Node3D
var work_position_temporary := true
var work_position_target := Vector3.INF
var _work_position_previous_state: int = State.IDLE
var _work_position_previous_active_role := ""
var _work_position_player_controlled := false

var resource_type := "wood"
var gather_resource_type := ""
var gather_source_position := Vector3.ZERO
var gather_access_position := Vector3.ZERO
var source_position := Vector3.ZERO
var source_access_position := Vector3.ZERO
var workplace_position := Vector3.ZERO
var warehouse_position := Vector3.ZERO
var task_timer := CitizenTaskState.new()
var wait_recheck := 0.0
	# Injected: registration_staff_checker(Citizen) -> bool reports whether this
	# citizen is currently first in a staffed employment-centre queue;
	# registration_duration_resolver()
# -> float returns how long that processing should take.
var registration_staff_checker := Callable()
var registration_duration_resolver := Callable()
var is_player_controlled := false
var is_hero := false
## Stable, settlement-issued identity for the native AI. Unlike get_instance_id()
## it is deterministic within a loaded settlement and is designed to be persisted
## with the roster once save/load is introduced.
var ai_id := 0
var construction_site: Node3D
var specialization: String:
	get:
		return profile.specialization
	set(value):
		profile.specialization = value
var active_role := ""
## Human-readable label of the native AI task, supplied through CitizenActuator.
var ai_activity_label := ""
var _employment := CitizenEmploymentStateScript.new()
var employment_state:
	get:
		return _employment.employment_state
	set(value):
		_employment.employment_state = value
var daily_order_role: String:
	get:
		return _employment.daily_order_role
	set(value):
		_employment.daily_order_role = value
var daily_order_workday_id: int:
	get:
		return _employment.daily_order_workday_id
	set(value):
		_employment.daily_order_workday_id = value
var daily_order_expires_at: float:
	get:
		return _employment.daily_order_expires_at
	set(value):
		_employment.daily_order_expires_at = value
var permanent_role: String:
	get:
		return _employment.permanent_role
	set(value):
		_employment.permanent_role = value
var pending_employment_role: String:
	get:
		return _employment.pending_employment_role
	set(value):
		_employment.pending_employment_role = value
var employment_workplace: Node3D
var pending_employment_workplace: Node3D
var employment_center_position := Vector3.INF
var registration_queue_order: int:
	get:
		return _employment.registration_queue_order
	set(value):
		_employment.registration_queue_order = value
var overtime_mode: bool:
	get:
		return _employment.overtime_mode
	set(value):
		_employment.overtime_mode = value
var overtime_until_workday_id: int:
	get:
		return _employment.overtime_until_workday_id
	set(value):
		_employment.overtime_until_workday_id = value
var overtime_source: String:
	get:
		return _employment.overtime_source
	set(value):
		_employment.overtime_source = value
var overtime_sources: Dictionary:
	get:
		return _employment.overtime_sources
	set(value):
		_employment.overtime_sources = value
var overtime_issued_days: Dictionary:
	get:
		return _employment.overtime_issued_days
	set(value):
		_employment.overtime_issued_days = value
var _needs := CitizenNeedsStateScript.new()
var fatigue: float:
	get:
		return _needs.fatigue
	set(value):
		_needs.fatigue = value
var continuous_work_hours: float:
	get:
		return _needs.continuous_work_hours
	set(value):
		_needs.continuous_work_hours = value
var recovery_until_workday_id: int:
	get:
		return _needs.recovery_until_workday_id
	set(value):
		_needs.recovery_until_workday_id = value
var satisfaction: float:
	get:
		return _needs.satisfaction
	set(value):
		_needs.satisfaction = value
var satisfaction_tick: float:
	get:
		return _needs.satisfaction_tick
	set(value):
		_needs.satisfaction_tick = value
var body_material: StandardMaterial3D
var gender: String = ""
var current_model_path: String = ""
var current_character_mesh: Node3D
var current_body_mesh: MeshInstance3D
var current_head_mesh: MeshInstance3D
var animation_player: AnimationPlayer
var skin_color: Color = Color.WHITE
var shirt_color: Color = Color.WHITE
var pants_color: Color = Color.WHITE
var hair_color: Color = Color.WHITE
# Chosen once and reused across every model rebuild so a citizen keeps the same
# face for life, even when a promotion swaps their body model.
var head_model_name: String = ""
var head_visible: bool = true
var profile := CitizenProfileScript.new()
var skills: Dictionary:
	get:
		return profile.skills
	set(value):
		profile.skills = value
var is_jack_of_all_trades: bool:
	get:
		return profile.is_jack_of_all_trades
	set(value):
		profile.is_jack_of_all_trades = value
var practiced_today: Dictionary:
	get:
		return profile.practiced_today
	set(value):
		profile.practiced_today = value
var temp_training_role: String:
	get:
		return _employment.temp_training_role
	set(value):
		_employment.temp_training_role = value

const DEVELOPED_SKILL_THRESHOLD := CitizenProfileScript.DEVELOPED_SKILL_THRESHOLD
const SKILL_GROWTH_PER_SECOND_WORK := CitizenProfileScript.SKILL_GROWTH_PER_SECOND_WORK
const DAILY_CONSTRUCTION_SKILL_CAP := CitizenProfileScript.DAILY_CONSTRUCTION_SKILL_CAP
const COURIER_EQUIPMENT := {
	"hands": {"capacity": 1, "speed": 1.0},
	"simple_backpack": {"capacity": 2, "speed": 1.0},
	"reinforced_backpack": {"capacity": 4, "speed": 1.0},
	"cargo_backpack": {"capacity": 6, "speed": 0.95},
	"bicycle": {"capacity": 4, "speed": 1.40},
	"bicycle_trailer": {"capacity": 6, "speed": 1.30}
}
const SKILL_GROWTH_PER_SCHOOL_DAY := CitizenProfileScript.SKILL_GROWTH_PER_SCHOOL_DAY
const SKILL_DECAY_RATE := CitizenProfileScript.SKILL_DECAY_RATE
const SKILL_MIN_FLOOR := CitizenProfileScript.SKILL_MIN_FLOOR
const ROLE_RECHECK_MIN_DELAY := 0.75
const ROLE_RECHECK_MAX_DELAY := 1.5
var role_recheck_remaining := 0.0
var assigned_dig_site: Node3D
var uses_courier := false
var returning_to_excavation := false
var carried_amount := 0
var pending_resources: Dictionary = {}
var courier_target: Citizen
var courier_resource_type := ""
var courier_worker: Citizen
var courier_equipment := "hands"
var home: Node3D
var hunger: float:
	get:
		return _needs.hunger
	set(value):
		_needs.hunger = value
var buffs: Dictionary:
	get:
		return _needs.buffs
	set(value):
		_needs.buffs = value
var debuffs: Dictionary:
	get:
		return _needs.debuffs
	set(value):
		_needs.debuffs = value
var delivery_amount := 0
var canteen_position := Vector3.ZERO
var current_toilet_target: Node3D = null
const TOILET_USE_DURATION := 5.0
## Upper bound on how long a citizen queues for an occupied toilet before giving
## up, so a permanently-full facility cannot freeze it until the task watchdog.
const TOILET_WAIT_TIMEOUT := 30.0
var toilet_timer := CitizenTaskState.new()
var toilet_wait_time := 0.0
var toilet_relief_position := Vector3.INF
var toilet_relief_type := ""
var toilet_resume_state := State.IDLE
var has_toilet_resume_state := false
var toilet_resume_idle_wander_anchor := Vector3.INF
var toilet_resume_idle_wander_target := Vector3.INF
var toilet_resume_idle_wander_pause := 0.0
var player_using_toilet := false
var market_position := Vector3.ZERO
var craft_position := Vector3.ZERO
var craft_timer := 0.0
var craft_speed_multiplier := 1.0
var construction_position := Vector3.ZERO
var is_waiting_for_materials := false
var construction_delivery_resource := ""
var building_supply_kind := "construction"
var park_rest_duration := 4.0
var pathfinder: Callable
var recovery_pathfinder: Callable
var movement_speed_modifier_query: Callable
var trail_movement_recorder: Callable
var navigation_revision_query: Callable
var delivery_position_resolver: Callable
var queue_position_resolver: Callable
var queue_arrival_notifier: Callable
var queue_release_notifier: Callable
var route_reachability_query: Callable
var route_safety_query: Callable
var idle_wander_anchor := Vector3.INF
var idle_wander_target := Vector3.INF
var idle_wander_pause := 0.0
var movement_path: Array[Vector3] = []
var path_destination := Vector3.INF
var path_allows_destination_house := false
var active_route: RouteResult
var route_retry_timer := 0.0
var route_retry_delay := ROUTE_RETRY_INTERVAL
var route_unreachable_time := 0.0
var route_unreachable_reason := RouteResult.UnreachableReason.NONE
var navigation_failed := false
# Topology revision captured when navigation_failed was raised, so a later
# passability change (demolition/excavation) can retract the give-up.
var navigation_failed_topology := -999
var stuck_time := 0.0
var recovery_repath_done := false
var route_no_progress_time := 0.0
var route_best_distance := INF
var route_recovery_attempt := 0
var recovery_detour_requested := false
var jump_cooldown := 0.0
var ground_contact_confirmed := false
var blocked_by_storage := false
var training_role: String:
	get:
		return _employment.training_role
	set(value):
		_employment.training_role = value
var training_days_completed: int:
	get:
		return _employment.training_days_completed
	set(value):
		_employment.training_days_completed = value
var school_position := Vector3.ZERO
var official_position := Vector3.ZERO
var research_position := Vector3.ZERO
var arrival_position := Vector3.INF
var pending_arrival_entrance := Vector3.INF
var factory: Node3D
var factory_position := Vector3.ZERO
var park_position := Vector3.ZERO
var trade_source_position := Vector3.ZERO
var trade_destination_position := Vector3.ZERO
var status_effects: Dictionary:
	get:
		return _needs.status_effects
	set(value):
		_needs.status_effects = value
var simulation: Node

# Generic AI-controlled movement target. Populated by move_to() and consumed
# by MoveToStep via the actuator.
var ai_move_target := Vector3.INF
var ai_move_arrival_radius := 0.25
var ai_move_arrived := false
var ai_move_failed := false
var ai_move_failure_reason := BehaviorStep.FailureReason.NONE

var idle_indicator: Label3D
var _privacy_blur: MeshInstance3D
# Multiplier set by the game controller to fade the idle indicator with camera distance.
var label_distance_alpha := 1.0

const CitizenToiletHandlerScript = preload("res://game/features/citizens/presentation/citizen_toilet_handler.gd")
const CitizenTaskExecutorScript = preload("res://game/features/citizens/presentation/citizen_task_executor.gd")
const CitizenVisualBuilderScript = preload("res://game/features/citizens/presentation/citizen_visual_builder.gd")
const CitizenAnimationControllerScript = preload("res://game/features/citizens/presentation/citizen_animation_controller.gd")
const CitizenIdleIndicatorScript = preload("res://game/features/citizens/presentation/citizen_idle_indicator.gd")
const CitizenEfficiencyServiceScript = preload("res://game/features/citizens/application/citizen_efficiency_service.gd")
const CitizenSatisfactionServiceScript = preload("res://game/features/citizens/application/citizen_satisfaction_service.gd")

var toilet_handler: RefCounted = CitizenToiletHandlerScript.new()
var task_executor: RefCounted = CitizenTaskExecutorScript.new()
var visual_builder: RefCounted = CitizenVisualBuilderScript.new()
var animation_controller: RefCounted = CitizenAnimationControllerScript.new()
var idle_indicator_controller: RefCounted = CitizenIdleIndicatorScript.new()
var efficiency_service: RefCounted = CitizenEfficiencyServiceScript.new()
var satisfaction_service: RefCounted = CitizenSatisfactionServiceScript.new()

signal employment_processing_finished(citizen: Citizen)

func _ready() -> void:

	if gender.is_empty():
		gender = "male" if randf() > 0.5 else "female"
	skills = {
		"construction": randf_range(0.0, 0.1),
		"forestry": randf_range(0.0, 0.1),
		"farming": randf_range(0.0, 0.1),
		"excavation": randf_range(0.0, 0.1),
		"factory_worker": randf_range(0.0, 0.1),
		"engineer": randf_range(0.0, 0.1),
		"craftsman": randf_range(0.0, 0.1),
		"official": randf_range(0.0, 0.1)
	}
	add_to_group("citizens")
	_setup_collision()
	_setup_selector()
	visual_builder.setup_visuals(self)

func _setup_collision() -> void:
	# Bodies collide with terrain and buildings, but not with each other.
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	up_direction = Vector3.UP
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.38
	floor_constant_speed = true
	floor_stop_on_slope = true
	if not has_node("CollisionShape3D"):
		var body_collision := CollisionShape3D.new()
		body_collision.name = "CollisionShape3D"
		var body_shape := CapsuleShape3D.new()
		body_shape.radius = 0.32
		body_shape.height = 1.75
		body_collision.shape = body_shape
		body_collision.position.y = 0.875
		add_child(body_collision)

func _setup_selector() -> void:
	if not has_node("Selector"):
		var selector := Area3D.new()
		selector.name = "Selector"
		selector.add_to_group("citizen_selector")
		selector.collision_layer = 4
		selector.collision_mask = 0
		var selector_shape := CollisionShape3D.new()
		var capsule_shape := CapsuleShape3D.new()
		capsule_shape.radius = 0.4
		capsule_shape.height = 1.8
		selector_shape.shape = capsule_shape
		selector_shape.position.y = 0.9
		selector.add_child(selector_shape)
		add_child(selector)

func play_one_shot(anim_name: String) -> void:
	animation_controller.play_one_shot(self, anim_name)

func play_hunting_shot() -> void:
	animation_controller.play_hunting_shot(self)

func _play_animation(anim_to_play: String) -> void:
	animation_controller.play_animation(self, anim_to_play)

func _update_animations(delta: float) -> void:
	animation_controller.update_animations(self, delta)

func drive_player_animation(is_sprinting: bool) -> void:
	animation_controller.drive_player_animation(self, is_sprinting)

func start_production_cycle(next_resource_type: String, source: Vector3, workplace: Vector3, warehouse: Vector3, next_uses_courier := false, access_pos := Vector3.INF) -> void:
	if is_player_controlled:
		return
	_reset_assignment_navigation()
	resource_type = next_resource_type
	source_position = source
	source_access_position = source if access_pos == Vector3.INF else access_pos
	workplace_position = workplace
	warehouse_position = warehouse
	uses_courier = next_uses_courier
	factory = null
	active_role = "forestry" if next_resource_type == "wood" else "farming"
	if is_inside_tree() and global_position.distance_to(source_access_position) <= 0.5:
		state = State.CHOPPING
		_start_task(WORK_DURATION / get_efficiency(active_role))
	else:
		state = State.TO_TREE


func _process_to_cleaning_pile(delta: float) -> void:
	if _move_to(gather_access_position, delta, false, false):
		state = State.CLEANING_PILE
		_start_task(WORK_DURATION)


func _process_cleaning_pile(delta: float) -> void:
	if not _work(delta):
		return
	if simulation == null or gather_resource_type.is_empty():
		idle()
		return
	var collected: int = int(simulation._take_resource_from_pile_at(gather_source_position, gather_resource_type, 3))
	if collected <= 0:
		idle()
		return
	resource_type = gather_resource_type
	carried_amount = collected
	state = State.TO_WAREHOUSE



func _physics_process(delta: float) -> void:
	if is_player_controlled and not player_using_toilet:
		return
	# Engine.time_scale accelerates simulation delta. Statuses are a diagnostic
	# surface, so keep their minimum lifetime in real seconds at every speed.
	_advance_state_display(delta / maxf(Engine.time_scale, 0.001))
	role_recheck_remaining = maxf(0.0, role_recheck_remaining - delta)
	if state not in [State.IDLE, State.WAITING]:
		idle_wander_anchor = Vector3.INF
		idle_wander_target = Vector3.INF
	_apply_gravity(delta)
	_update_effects(delta)
	_update_satisfaction(delta)
	
	_process_state_behavior(delta)

	if idle_indicator != null:
		_update_idle_indicator()
		if idle_indicator.visible:
			idle_indicator.modulate.a *= label_distance_alpha
	_update_privacy_blur()
	_update_animations(delta)


func _process_state_behavior(delta: float) -> void:
	match state:
		State.IDLE:
			_process_idle_wander(delta)
		State.WAITING:
			_process_waiting(delta)
		State.TO_TREE:
			_process_to_source(delta)
		State.CHOPPING:
			_process_source_work(delta)
		State.TO_SAWMILL:
			_process_to_workplace(delta)
		State.SAWING:
			_process_workplace_work(delta)
		State.TO_WAREHOUSE:
			_process_resource_delivery(delta)
		State.WAITING_COURIER:
			_process_courier_wait(delta)
		State.CONSTRUCTING:
			_process_construction(delta)
		State.EXCAVATING:
			_process_excavation(delta)
		State.COURIER_TO_WORKER:
			_process_courier_pickup(delta)
		State.COURIER_TO_SAWMILL:
			_process_sawmill_pickup(delta)
		State.COURIER_TO_DEW:
			_process_dew_collector_pickup(delta)
		State.COURIER_TO_WAREHOUSE:
			_process_courier_delivery(delta)
		State.TO_HOME:
			_process_go_home(delta)
		State.RESTING:
			_process_resting(delta)
		State.TO_CANTEEN:
			_process_go_to_canteen(delta)
		State.EATING:
			_process_eating(delta)
		State.TO_FOOD_PICKUP:
			_process_food_pickup(delta)
		State.TO_CANTEEN_DELIVERY:
			_process_canteen_delivery(delta)
		State.TO_CANTEEN_WORK:
			_process_canteen_work(delta)
		State.TO_SCHOOL:
			_process_go_to_school(delta)
		State.STUDYING:
			pass
		State.RESEARCHING:
			_process_research(delta)
		State.TO_SCHOOL_WORK:
			_process_school_work(delta)
		State.TO_OFFICIAL_WORK:
			_process_official_work(delta)
		State.OFFICIAL_WORK:
			pass
		State.TO_FACTORY:
			_process_to_factory(delta)
		State.FACTORY_WORK:
			_process_factory_work(delta)
		State.TO_PARK:
			_process_go_to_park(delta)
		State.RELAXING:
			_process_relaxing(delta)
		State.TO_GATHER:
			_process_to_gather(delta)
		State.GATHERING:
			_process_gathering(delta)
		State.TO_CLEANING_PILE:
			_process_to_cleaning_pile(delta)
		State.CLEANING_PILE:
			_process_cleaning_pile(delta)
		State.TO_TRADE_PICKUP:
			_process_trade_pickup(delta)
		State.TO_TRADE_DESTINATION:
			_process_trade_destination(delta)
		State.TO_EMPLOYMENT_CENTER:
			_process_to_employment_center(delta)
		State.EMPLOYMENT_PROCESSING:
			_process_employment_processing(delta)
		State.CANTEEN_WORK:
			pass
		State.SCHOOL_WORK:
			pass
		State.TO_MARKET_WORK:
			_process_market_work_arrival(delta)
		State.MARKET_WORK:
			pass
		State.TO_CRAFT_WORK:
			_process_craft_work_arrival(delta)
		State.CRAFT_WORK:
			_process_craft_work(delta)
		State.TO_CONSTRUCTION_PICKUP:
			_process_construction_pickup(delta)
		State.TO_CONSTRUCTION_SITE:
			_process_construction_delivery(delta)
		State.TO_ARRIVAL_ENTRANCE:
			_process_arrival_entrance(delta)
		State.ARRIVAL_MEETING:
			_process_arrival_meeting(delta)
		State.TO_ARRIVAL_CENTER:
			_process_arrival_center(delta)
		State.TO_OUTSIDE_WORK:
			_process_outside_work_departure(delta)
		State.LEAVING:
			_process_leaving(delta)
		State.TO_TOILET:
			_process_to_toilet(delta)
		State.USING_TOILET:
			_process_using_toilet(delta)
		State.WAITING_FOR_TOILET:
			_process_waiting_for_toilet(delta)
		State.TO_BUSH:
			_process_to_bush(delta)
		State.USING_BUSH:
			_process_using_bush(delta)
		State.AI_MOVING:
			_process_ai_moving(delta)
		State.WORK_POSITION:
			pass

func _process_to_source(delta: float) -> void:
	if _move_to(source_access_position, delta, false, false):
		state = State.CHOPPING
		_start_task(WORK_DURATION / get_efficiency(active_role))

func _process_source_work(delta: float) -> void:
	if _work(delta):
		if resource_type == "wood":
			tree_harvested.emit(self, source_position)
		state = State.TO_SAWMILL

func _process_to_workplace(delta: float) -> void:
	if _move_to(workplace_position, delta):
		if resource_type == "wood":
			var count := 1
			if has_perk("forestry") and randf() < 0.10:
				count = 2
				if simulation != null:
					simulation._update_interface("Lumberjack Master: Forester delivered 2 logs!")
			logs_delivered.emit(self, workplace_position, count)
			return
		state = State.SAWING
		_start_task(WORK_DURATION / get_efficiency(active_role))

func _process_workplace_work(delta: float) -> void:
	if not _work(delta):
		return
	carried_amount = 2 if get_efficiency(active_role) >= 1.05 else 1
	if uses_courier:
		resource_ready.emit(self, resource_type, carried_amount)
		_start_task(COURIER_WAIT_DURATION)
		state = State.WAITING_COURIER
	else:
		state = State.TO_WAREHOUSE

func _process_resource_delivery(delta: float) -> void:
	_refresh_warehouse_position()
	if _move_to(warehouse_position, delta):
		if active_role == "gather_food":
			# Hunters and gatherers first leave their catch at their own lodge.
			# A courier then collects it from the waiting worker for the warehouse.
			resource_ready.emit(self, resource_type, carried_amount)
			_start_task(COURIER_WAIT_DURATION)
			state = State.WAITING_COURIER
			return
		state = State.IDLE
		play_one_shot("pick-up")
		resource_delivered.emit(self, resource_type, carried_amount)

func _process_courier_wait(delta: float) -> void:
	if task_timer.advance(delta):
		if _start_pending_arrival_if_any():
			return
		if has_pending_resource():
			# Native cycles complete only when a courier takes their pending output.
			# Keep the worker available to the dispatcher without starting another
			# cycle while the previous output is still pending.
			_start_task(COURIER_WAIT_DURATION)
			return
		# The output has already been collected (or none was produced). Return to
		# idle so the native AI can publish the next work order, instead of forcing
		# a stale forestry route via TO_TREE (which misfires for gather/farm roles).
		idle()

func _process_construction(delta: float) -> void:
	if not is_instance_valid(construction_site):
		state = State.IDLE
		construction_site = null
		is_waiting_for_materials = false
		return
	var arrived := _move_to(construction_position, delta, false, false)
	if arrived:
		var site_pos := construction_site.global_position if construction_site.is_inside_tree() else construction_site.position
		var direction := (site_pos - global_position)
		direction.y = 0.0
		if direction.length() > 0.01:
			look_at(global_position + direction.normalized(), Vector3.UP)
		is_waiting_for_materials = not bool(construction_site.get_meta("can_advance", false))
	else:
		is_waiting_for_materials = false

func _process_excavation(delta: float) -> void:
	if not is_instance_valid(assigned_dig_site):
		idle()
		return
	if not _move_to(assigned_dig_site.global_position, delta):
		return
	if task_timer.remaining <= 0.0:
		_start_task(WORK_DURATION / get_efficiency("excavation"))
	if _work(delta):
		task_timer.remaining = 0.0
		excavation_cycle.emit(self, assigned_dig_site, get_efficiency("excavation"))
		if permanent_role == "excavation" and active_role == "excavation" and state == State.EXCAVATING and is_instance_valid(assigned_dig_site):
			_start_task(COURIER_WAIT_DURATION)
			state = State.WAITING_COURIER

func _process_courier_pickup(delta: float) -> void:
	if not is_instance_valid(courier_target):
		# The producer may be removed while a courier is en route. Drop the stale
		# job so the dispatcher can give this courier another task immediately.
		courier_target = null
		courier_resource_type = ""
		carried_amount = 0
		state = State.IDLE
		return
	if _move_to(courier_target.global_position, delta):
		var cargo := courier_target.take_pending_resource(courier_capacity())
		courier_target.set_meta("last_courier_pickup", simulation.runtime_seconds if simulation != null else 0.0)
		courier_resource_type = cargo.get("type", "")
		carried_amount = int(cargo.get("amount", 0))
		if carried_amount > 0:
			play_one_shot("pick-up")
		state = State.COURIER_TO_WAREHOUSE if carried_amount > 0 else State.IDLE

func _process_sawmill_pickup(delta: float) -> void:
	if _move_to(workplace_position, delta):
		play_one_shot("pick-up")
		sawmill_boards_collected.emit(self, workplace_position)


func _process_dew_collector_pickup(delta: float) -> void:
	if _move_to(workplace_position, delta):
		play_one_shot("pick-up")
		dew_collected.emit(self, workplace_position)


func _process_courier_delivery(delta: float) -> void:
	_refresh_warehouse_position()
	if _move_to(warehouse_position, delta):
		state = State.IDLE
		play_one_shot("pick-up")
		resource_delivered.emit(self, courier_resource_type, carried_amount)

func assign_construction_delivery(site: Node3D, warehouse: Vector3, resource_type: String, amount: int = 1) -> void:
	assign_building_supply(site, warehouse, resource_type, "construction", amount)

func assign_building_supply(target: Node3D, warehouse: Vector3, resource_type: String, supply_kind: String, amount: int = 1) -> void:
	if is_player_controlled or not is_instance_valid(target):
		return
	_reset_assignment_navigation()
	construction_site = target
	warehouse_position = warehouse
	construction_delivery_resource = resource_type
	building_supply_kind = supply_kind
	carried_amount = maxi(1, amount)
	state = State.TO_CONSTRUCTION_PICKUP

func _process_construction_pickup(delta: float) -> void:
	# Pickup must not be redirected by another building's service queue; the
	# warehouse/source position is the only valid interaction point here.
	if _move_to(warehouse_position, delta, false, false):
		play_one_shot("pick-up")
		# The courier was admitted to the warehouse queue; release it before
		# walking away so the entrance is not blocked for the whole delivery trip.
		_reset_assignment_navigation()
		construction_position = _reachable_construction_approach(construction_site)
		state = State.TO_CONSTRUCTION_SITE

func _process_construction_delivery(delta: float) -> void:
	if not is_instance_valid(construction_site):
		cancel_current_action()
		return
	# Construction sites are not registered in the building queue system, so using
	# the queue here would only risk misrouting a courier to a different building
	# whose position happens to coincide with the construction approach point.
	if _move_to(construction_position, delta, false, false):
		play_one_shot("pick-up")
		if building_supply_kind == "construction":
			construction_material_delivered.emit(self, construction_site, construction_delivery_resource, carried_amount)
		else:
			building_supply_delivered.emit(self, construction_site, building_supply_kind, construction_delivery_resource, carried_amount)
		carried_amount = 0
		construction_delivery_resource = ""
		building_supply_kind = "construction"
		construction_site = null
		state = State.IDLE
		begin_role_recheck_cooldown()

func _process_go_home(delta: float) -> void:
	if not is_instance_valid(home):
		# The home was demolished mid-walk: drop back to IDLE (with its indicator)
		# instead of silently standing in TO_HOME forever.
		idle()
		return
	var home_entrance: Vector3 = home.get_meta("entrance_position", home.global_position)
	if _move_to(home_entrance, delta, true):
		state = State.RESTING
		if simulation != null:
			var now := int(simulation.game_minutes)
			var hour := now / 60
			home.set_meta("light_off_minute", (now + 60) % (24 * 60) if hour >= 23 else simulation.random.randi_range(22 * 60, 26 * 60) % (24 * 60))

func _process_resting(delta: float) -> void:
	satisfaction = minf(get_satisfaction_cap(), satisfaction + delta * 2.2)
	hunger = maxf(0.0, hunger - delta * 0.25)

func _process_go_to_canteen(delta: float) -> void:
	if _move_to(canteen_position, delta):
		state = State.EATING
		_start_task(1.1)

func _process_eating(delta: float) -> void:
	if task_timer.advance(delta):
		state = State.IDLE
		play_one_shot("emote-yes")
		meal_finished.emit(self)

func _process_food_pickup(delta: float) -> void:
	_refresh_warehouse_position()
	if _move_to(warehouse_position, delta):
		play_one_shot("pick-up")
		state = State.TO_CANTEEN_DELIVERY

func _process_canteen_delivery(delta: float) -> void:
	if _move_to(canteen_position, delta):
		play_one_shot("pick-up")
		state = State.IDLE
		canteen_delivery_finished.emit(self, delivery_amount)
		delivery_amount = 0

func _process_canteen_work(delta: float) -> void:
	if _move_to(canteen_position, delta, false, false):
		state = State.CANTEEN_WORK
		enter_work_position(canteen_position, "cook", null, true, false)

func _process_go_to_school(delta: float) -> void:
	if _move_to(school_position, delta):
		state = State.STUDYING
		active_role = "training"

func _process_school_work(delta: float) -> void:
	if _move_to(school_position, delta, false, false):
		state = State.SCHOOL_WORK
		enter_work_position(school_position, "teacher", null, true, false)

func _process_official_work(delta: float) -> void:
	if _move_to(official_position, delta, false, false):
		state = State.OFFICIAL_WORK
		enter_work_position(official_position, "official", null, false, false)

func _process_market_work_arrival(delta: float) -> void:
	if _move_to(market_position, delta, false, false):
		state = State.MARKET_WORK
		enter_work_position(market_position, "seller", null, true, false)

func _process_to_factory(delta: float) -> void:
	if not is_instance_valid(factory):
		idle()
		return
	if _move_to(factory_position, delta, false, false):
		state = State.FACTORY_WORK
		enter_work_position(factory_position, active_role, factory, true, false)
		_start_task(WORK_DURATION / get_efficiency(active_role))

func _process_factory_work(delta: float) -> void:
	if not is_instance_valid(factory):
		idle()
		return
	if _work(delta):
		factory_cycle.emit(self, factory)
		if _start_pending_arrival_if_any():
			return
		_start_task(WORK_DURATION / get_efficiency(active_role))

func _process_go_to_park(delta: float) -> void:
	if _move_to(park_position, delta):
		state = State.RELAXING
		_start_task(park_rest_duration)

func _process_relaxing(delta: float) -> void:
	var finished := task_timer.advance(delta)
	satisfaction = minf(get_satisfaction_cap(), satisfaction + delta * 5.0)
	if finished:
		state = State.IDLE
		leisure_finished.emit(self)

func _process_waiting(delta: float) -> void:
	# Native AI owns work acquisition. Waiting is only a presentation state while
	# the next snapshot/director cycle publishes a new order.
	wait_recheck -= delta
	_process_idle_wander(delta)
	if task_timer.advance(delta):
		idle()


func _process_idle_wander(delta: float) -> void:
	if idle_wander_anchor == Vector3.INF:
		idle_wander_anchor = global_position
		idle_wander_pause = randf_range(IDLE_WANDER_MIN_PAUSE, IDLE_WANDER_MAX_PAUSE)
	if idle_wander_target != Vector3.INF:
		# A wander stroll is disposable: if it cannot be reached, drop it and clear
		# the failure so the citizen keeps loitering instead of standing frozen.
		if navigation_failed:
			idle_wander_target = Vector3.INF
			navigation_failed = false
			ai_move_failure_reason = BehaviorStep.FailureReason.NONE
			idle_wander_pause = randf_range(IDLE_WANDER_MIN_PAUSE, IDLE_WANDER_MAX_PAUSE)
			_stop_horizontal_movement()
			return
		if _move_to(idle_wander_target, delta, false, false, false):
			idle_wander_target = Vector3.INF
			idle_wander_pause = randf_range(IDLE_WANDER_MIN_PAUSE, IDLE_WANDER_MAX_PAUSE)
		return
	idle_wander_pause -= delta
	velocity.x = 0.0
	velocity.z = 0.0
	if idle_wander_pause > 0.0:
		return
	idle_wander_target = _choose_idle_wander_target()
	if idle_wander_target == Vector3.INF:
		idle_wander_pause = IDLE_WANDER_MIN_PAUSE


func _choose_idle_wander_target() -> Vector3:
	# Gather the neighbours that could affect scoring once, instead of scanning the
	# whole roster per candidate. The personal-space score caps at IDLE_WANDER_RADIUS
	# * 2, and every candidate lies within IDLE_WANDER_RADIUS of the anchor, so a
	# citizen farther than 3x the radius from the anchor can never be the nearest to
	# any candidate and is safely ignored.
	var nearby_positions := _nearby_citizen_positions(idle_wander_anchor, IDLE_WANDER_RADIUS * 3.0)
	var best := Vector3.INF
	var best_score := -INF
	for ignored in range(IDLE_WANDER_CANDIDATES):
		var angle := randf() * TAU
		var radius := randf_range(IDLE_PERSONAL_SPACE, IDLE_WANDER_RADIUS)
		var candidate := idle_wander_anchor + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var reachable := bool(route_reachability_query.call(global_position, candidate, false)) if route_reachability_query.is_valid() else true
		if not reachable:
			continue
		var nearest_neighbor := IDLE_WANDER_RADIUS * 2.0
		for other_position in nearby_positions:
			nearest_neighbor = minf(nearest_neighbor, candidate.distance_to(other_position))
		var score := nearest_neighbor - candidate.distance_to(idle_wander_anchor) * 0.08
		if score > best_score:
			best_score = score
			best = candidate
	return best


func _nearby_citizen_positions(center: Vector3, radius: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if simulation == null:
		return positions
	var radius_squared := radius * radius
	for other in simulation.citizens:
		if other == self or not is_instance_valid(other):
			continue
		var other_position: Vector3 = other.global_position
		if center.distance_squared_to(other_position) <= radius_squared:
			positions.append(other_position)
	return positions


func begin_employment_processing(center_position: Vector3, next_pending_role := "", next_workplace: Node3D = null) -> void:
	if is_player_controlled or center_position == Vector3.INF:
		return
	employment_center_position = center_position
	pending_employment_role = next_pending_role
	pending_employment_workplace = next_workplace
	employment_state = EmploymentState.REGISTERING
	_take_registration_ticket()
	active_role = ""
	state = State.TO_EMPLOYMENT_CENTER


func go_to_arrival_entrance(entrance_position: Vector3) -> void:
	if is_player_controlled:
		return
	arrival_position = entrance_position
	state = State.TO_ARRIVAL_ENTRANCE


func request_arrival_greeting(entrance_position: Vector3) -> void:
	if is_player_controlled or not can_handle_entry_logistics():
		return
	pending_arrival_entrance = entrance_position


func _start_pending_arrival_if_any() -> bool:
	if pending_arrival_entrance == Vector3.INF:
		return false
	var entrance := pending_arrival_entrance
	pending_arrival_entrance = Vector3.INF
	go_to_arrival_entrance(entrance)
	return true


func has_active_arrival_task() -> bool:
	return state in [State.TO_ARRIVAL_ENTRANCE, State.ARRIVAL_MEETING, State.ARRIVAL_WAITING, State.TO_ARRIVAL_CENTER]


func wait_for_arrival_morning() -> void:
	state = State.ARRIVAL_WAITING


func escort_arrivals_to(center_position: Vector3) -> void:
	if center_position == Vector3.INF:
		wait_for_arrival_morning()
		return
	arrival_position = center_position
	state = State.TO_ARRIVAL_CENTER


func _process_arrival_entrance(delta: float) -> void:
	if _move_to(arrival_position, delta):
		state = State.ARRIVAL_MEETING
		_start_task(ARRIVAL_MEETING_DURATION)


func _process_arrival_meeting(delta: float) -> void:
	if task_timer.advance(delta):
		arrival_greeter_ready.emit(self)


func _process_arrival_center(delta: float) -> void:
	if _move_to(arrival_position, delta):
		idle()


func assign_outside_work(entrance_position: Vector3) -> void:
	if is_player_controlled or entrance_position == Vector3.INF:
		return
	_reset_assignment_navigation()
	arrival_position = entrance_position
	state = State.TO_OUTSIDE_WORK


func _process_outside_work_departure(delta: float) -> void:
	if _move_to(arrival_position, delta, false, false):
		state = State.IDLE
		outside_work_departed.emit(self)


func begin_leaving(entrance_position: Vector3) -> void:
	if is_player_controlled or is_hero:
		return
	_reset_assignment_navigation()
	arrival_position = entrance_position
	state = State.LEAVING


func _process_leaving(delta: float) -> void:
	if _move_to(arrival_position, delta, false, false):
		citizen_leaving_departed.emit(self)


func queue_employment_processing(next_pending_role := "", next_workplace: Node3D = null) -> void:
	pending_employment_role = next_pending_role
	pending_employment_workplace = next_workplace
	employment_state = EmploymentState.REGISTERING
	_take_registration_ticket()
	active_role = ""
	state = State.IDLE


func cancel_employment_processing() -> void:
	if state not in [State.TO_EMPLOYMENT_CENTER, State.EMPLOYMENT_PROCESSING]:
		return
	pending_employment_role = ""
	pending_employment_workplace = null
	employment_state = EmploymentState.NO_PERMANENT_WORK
	state = State.IDLE


func _process_to_employment_center(delta: float) -> void:
	if employment_center_position == Vector3.INF:
		state = State.IDLE
		return
	if not _move_to(employment_center_position, delta):
		return
	# Arrived and queuing: stay put (a visible line at the campfire) until
	# someone is actually manning the employment centre.
	if registration_staff_checker.is_valid() and not bool(registration_staff_checker.call(self)):
		return
	if task_timer.remaining <= 0.0:
		var duration := EMPLOYMENT_PROCESS_DURATION
		if registration_duration_resolver.is_valid():
			duration = float(registration_duration_resolver.call())
		_start_task(duration)
	state = State.EMPLOYMENT_PROCESSING


func _process_employment_processing(delta: float) -> void:
	# Registration is suspended, rather than completed remotely, when the
	# official leaves their post or the workplace is no longer staffed.
	if registration_staff_checker.is_valid() and not bool(registration_staff_checker.call(self)):
		state = State.TO_EMPLOYMENT_CENTER
		return
	if _work(delta):
		employment_processing_finished.emit(self)


func finish_employment_processing() -> void:
	if not pending_employment_role.is_empty():
		permanent_role = pending_employment_role
		employment_workplace = pending_employment_workplace
		employment_state = EmploymentState.EMPLOYED
	else:
		permanent_role = ""
		employment_state = EmploymentState.NO_PERMANENT_WORK
	pending_employment_role = ""
	pending_employment_workplace = null
	registration_queue_order = -1
	state = State.IDLE


func assign_daily_order(role: String, workday_id: int, expires_at: float) -> void:
	if is_player_controlled:
		return
	daily_order_role = role
	daily_order_workday_id = workday_id
	daily_order_expires_at = expires_at


func request_no_permanent_work_registration() -> void:
	if is_player_controlled or not is_unregistered():
		return
	queue_employment_processing()


func release_to_no_permanent_work() -> void:
	idle()
	permanent_role = ""
	pending_employment_role = ""
	employment_workplace = null
	pending_employment_workplace = null
	employment_state = EmploymentState.NO_PERMANENT_WORK
	registration_queue_order = -1


# --- Employment status accessors -------------------------------------------
# Single point of truth for reading a citizen's employment situation. Callers
# should prefer these over touching `employment_state`
# directly, so that collapsing the stored EmploymentState later (see
# design_docs/workforce_system.md) only has to change these bodies.
func is_employed() -> bool:
	return _employment.is_employed()

func has_no_permanent_work() -> bool:
	return _employment.has_no_permanent_work()

func is_registering() -> bool:
	return _employment.is_registering()

func is_unregistered() -> bool:
	return _employment.is_unregistered()

func is_daily_courier() -> bool:
	return has_active_daily_order() and daily_order_role == "courier"

func is_daily_order_role(role: String) -> bool:
	return _employment.is_daily_order_role(role)

func has_daily_order() -> bool:
	return _employment.has_daily_order()

func is_courier() -> bool:
	return _employment.is_courier()

func can_handle_entry_logistics() -> bool:
	return is_daily_courier() or is_courier()

func has_active_daily_order() -> bool:
	if not has_daily_order():
		return false
	if simulation == null or not simulation.has_method("is_daily_order_active"):
		return true
	return bool(simulation.is_daily_order_active(self))


func activate_overtime(until_workday_id: int, source: String, issued_day := 0) -> bool:
	return _employment.activate_overtime(until_workday_id, source, issued_day)


func has_active_overtime(current_workday_id: int) -> bool:
	return _employment.has_active_overtime(current_workday_id)


func has_overtime_source(source: String, current_workday_id: int) -> bool:
	return _employment.has_overtime_source(source, current_workday_id)


func clear_expired_overtime(current_workday_id: int) -> void:
	_employment.clear_expired_overtime(current_workday_id)


func deactivate_overtime(source := "") -> void:
	_employment.clear_overtime_source(source)
	if not overtime_mode and simulation != null and not simulation._is_work_time():
		end_work_shift()


func is_recovering(current_workday_id: int) -> bool:
	return _needs.is_recovering(current_workday_id)


func is_dangerously_tired() -> bool:
	return _needs.is_dangerously_tired()

func clear_daily_order(workday_id := 0) -> void:
	if not has_daily_order():
		return
	if workday_id > 0 and daily_order_workday_id != workday_id:
		return
	var cleared_role := daily_order_role
	daily_order_role = ""
	daily_order_workday_id = 0
	daily_order_expires_at = -1.0
	if active_role == cleared_role:
		active_role = ""
	if state in [State.IDLE, State.RESTING, State.WAITING]:
		begin_role_recheck_cooldown()


func _take_registration_ticket() -> void:
	if registration_queue_order >= 0:
		return
	if simulation != null and simulation.has_method("_next_registration_ticket"):
		registration_queue_order = int(simulation.call("_next_registration_ticket"))


func has_active_delivery() -> bool:
	return state in [State.COURIER_TO_WORKER, State.COURIER_TO_WAREHOUSE, State.COURIER_TO_SAWMILL, State.TO_FOOD_PICKUP, State.TO_CANTEEN_DELIVERY, State.TO_CONSTRUCTION_PICKUP, State.TO_CONSTRUCTION_SITE, State.TO_TRADE_PICKUP, State.TO_TRADE_DESTINATION, State.TO_ARRIVAL_ENTRANCE, State.ARRIVAL_MEETING, State.TO_OUTSIDE_WORK]

func _move_to(destination: Vector3, delta: float, may_enter_destination_house := false, use_building_queue := true, record_trail := true, arrival_radius := 0.08) -> bool:
	var movement_destination := destination
	var is_queue_head := true
	if use_building_queue and queue_position_resolver.is_valid():
		var queue_result: Dictionary = queue_position_resolver.call(self, destination)
		movement_destination = queue_result.get("position", destination)
		is_queue_head = bool(queue_result.get("is_head", true))
		# An overflowed queue member has no slot yet. Keep its current position
		# without creating a zero-length route every physics frame.
		if not is_queue_head and movement_destination.distance_to(global_position) <= 0.05:
			_stop_horizontal_movement()
			return false
	if _route_uses_stale_navigation():
		_invalidate_route_for_navigation_change()
	# Detect a changed goal before honouring a prior failure: a new destination
	# (or a house-entry change) is a fresh navigation problem and must clear a
	# stale give-up flag, otherwise the citizen freezes on the old target forever.
	var goal_changed := path_destination.distance_to(movement_destination) > arrival_radius or path_allows_destination_house != may_enter_destination_house
	if goal_changed:
		_reset_route(movement_destination)
		path_allows_destination_house = may_enter_destination_house
		_plan_route(movement_destination)
	if navigation_failed:
		# The world may have opened up since we gave up (a blocking building was
		# demolished, terrain excavated). Retry once when the topology changed.
		if _navigation_topology_changed_since_failure():
			_reset_route(movement_destination)
			_plan_route(movement_destination)
		else:
			_stop_horizontal_movement()
			if ai_move_failure_reason == BehaviorStep.FailureReason.NONE:
				ai_move_failure_reason = BehaviorStep.FailureReason.MOVEMENT_FAILED
			return false
	if active_route == null or not active_route.reachable:
		route_retry_timer = maxf(0.0, route_retry_timer - delta)
		if route_retry_timer <= 0.0:
			_plan_route(movement_destination)
		if active_route == null or not active_route.reachable:
			route_unreachable_time += delta
			if route_unreachable_time >= ROUTE_UNREACHABLE_FAILURE_TIME:
				_raise_navigation_failure(BehaviorStep.FailureReason.UNREACHABLE)
				_stop_horizontal_movement()
			return false
	while not movement_path.is_empty():
		var waypoint: Vector3 = movement_path.front()
		var waypoint_offset := waypoint - global_position
		waypoint_offset.y = 0.0
		var is_final_waypoint := movement_path.size() == 1
		# Do not drive the capsule centre into an entrance marker or wall. The
		# interaction systems already accept a small area around service points.
		var waypoint_radius := maxf(arrival_radius, PHYSICAL_ARRIVAL_RADIUS) if is_final_waypoint else 0.08
		if waypoint_offset.length() > waypoint_radius:
			return _move_directly_to(waypoint, delta, record_trail, waypoint_radius)
		movement_path.pop_front()
		_reset_waypoint_progress()
	_stop_horizontal_movement()
	if is_queue_head and use_building_queue and queue_arrival_notifier.is_valid():
		queue_arrival_notifier.call(self, destination)
	return is_queue_head

func _plan_route(destination: Vector3) -> void:
	var result: Variant = RouteResult.success([destination], destination)
	if pathfinder.is_valid():
		result = pathfinder.call(global_position, destination, path_allows_destination_house)
	if recovery_detour_requested:
		recovery_detour_requested = false
		if recovery_pathfinder.is_valid():
			var detour: Variant = recovery_pathfinder.call(global_position, destination, path_allows_destination_house)
			if detour is RouteResult and (detour as RouteResult).reachable:
				result = detour
	if not result is RouteResult or not (result as RouteResult).reachable:
		var failed_revision := int(navigation_revision_query.call()) if navigation_revision_query.is_valid() else -1
		var reason := (result as RouteResult).unreachable_reason if result is RouteResult else RouteResult.UnreachableReason.UNKNOWN
		route_unreachable_reason = reason
		active_route = RouteResult.unreachable(failed_revision, failed_revision, reason)
		movement_path.clear()
		route_retry_timer = route_retry_delay
		route_retry_delay = minf(ROUTE_MAX_RETRY_INTERVAL, route_retry_delay * 2.0)
		velocity.x = 0.0
		velocity.z = 0.0
		return
	active_route = result as RouteResult
	movement_path = active_route.waypoints.duplicate()
	route_retry_timer = 0.0
	route_retry_delay = ROUTE_RETRY_INTERVAL
	route_unreachable_time = 0.0
	route_unreachable_reason = RouteResult.UnreachableReason.NONE
	ai_move_failure_reason = BehaviorStep.FailureReason.NONE
	recovery_repath_done = false


func _raise_navigation_failure(reason: int) -> void:
	navigation_failed = true
	ai_move_failure_reason = reason
	navigation_failed_topology = int(navigation_revision_query.call()) if navigation_revision_query.is_valid() else -999


func _navigation_topology_changed_since_failure() -> bool:
	if not navigation_revision_query.is_valid():
		return false
	var current := int(navigation_revision_query.call())
	return current >= 0 and current != navigation_failed_topology


func _route_uses_stale_navigation() -> bool:
	if active_route == null or active_route.topology_revision < 0 or not navigation_revision_query.is_valid():
		return false
	var current_revision := int(navigation_revision_query.call())
	if not active_route.is_topologically_stale(current_revision):
		return false
	var route_origin := global_position if is_inside_tree() else position
	if route_safety_query.is_valid() and bool(route_safety_query.call(route_origin, movement_path, path_allows_destination_house)):
		active_route.topology_revision = current_revision
		return false
	return true


func _invalidate_route_for_navigation_change() -> void:
	active_route = null
	movement_path.clear()
	route_retry_timer = randf_range(0.0, STALE_NAVIGATION_REPLAN_JITTER)
	route_retry_delay = ROUTE_RETRY_INTERVAL
	route_unreachable_time = 0.0
	route_unreachable_reason = RouteResult.UnreachableReason.NONE
	navigation_failed = false
	ai_move_failure_reason = BehaviorStep.FailureReason.STALE_ROUTE
	stuck_time = 0.0
	recovery_repath_done = false
	velocity.x = 0.0
	velocity.z = 0.0

func _move_directly_to(destination: Vector3, delta: float, record_trail := true, arrival_distance := 0.08) -> bool:
	var offset := destination - global_position
	offset.y = 0.0
	if offset.length() <= arrival_distance:
		return true
	var direction := offset.normalized()
	var speed_modifier := float(movement_speed_modifier_query.call(global_position)) if movement_speed_modifier_query.is_valid() else 1.0
	var current_walk_speed := get_walk_speed() * speed_modifier
	var desired_velocity := direction * current_walk_speed
	velocity.x = desired_velocity.x
	velocity.z = desired_velocity.z
	jump_cooldown = maxf(0.0, jump_cooldown - delta)
	var position_before_move := global_position
	var distance_before_move := offset.length()
	move_and_slide()
	var horizontal_progress := Vector2(global_position.x - position_before_move.x, global_position.z - position_before_move.z).length()
	if record_trail and horizontal_progress > 0.01 and trail_movement_recorder.is_valid():
		trail_movement_recorder.call(ai_id, global_position)
	var distance_after_move := Vector2(destination.x - global_position.x, destination.z - global_position.z).length()
	_update_route_progress(distance_before_move, distance_after_move, delta, direction)
	if is_on_floor() and horizontal_progress < current_walk_speed * delta * 0.15:
		stuck_time += delta
		if jump_cooldown <= 0.0:
			if stuck_time >= STUCK_TIME_BEFORE_REPATH and not recovery_repath_done:
				_force_repath()
			elif stuck_time >= STUCK_TIME_BEFORE_JUMP and _has_low_obstacle_ahead(direction):
				_jump_out_of_obstacle()
	else:
		stuck_time = 0.0
		recovery_repath_done = false
	look_at(global_position + direction, Vector3.UP)
	return false

func _has_low_obstacle_ahead(direction: Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state
	var forward := direction * 0.62
	var low_query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.22, global_position + Vector3.UP * 0.22 + forward, collision_mask)
	low_query.exclude = [get_rid()]
	var low_hit := space_state.intersect_ray(low_query)
	if low_hit.is_empty():
		return false
	# Never hop onto buildings: a wall or platform ahead means the path must go
	# around it, not over it.
	var collider: Object = low_hit.get("collider")
	if collider is Node and (collider as Node).has_meta("building_module"):
		return false
	var high_query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.9, global_position + Vector3.UP * 0.9 + forward, collision_mask)
	high_query.exclude = [get_rid()]
	return space_state.intersect_ray(high_query).is_empty()

func _jump_out_of_obstacle() -> void:
	velocity.y = AI_JUMP_VELOCITY
	jump_cooldown = 0.45
	stuck_time = 0.0

func _force_repath() -> void:
	if recovery_repath_done:
		return
	route_recovery_attempt += 1
	if route_recovery_attempt >= ROUTE_RECOVERY_FAILURE_ATTEMPTS:
		_raise_navigation_failure(BehaviorStep.FailureReason.TIMEOUT)
		active_route = null
		movement_path.clear()
		_stop_horizontal_movement()
		return
	active_route = null
	movement_path.clear()
	recovery_detour_requested = route_recovery_attempt > 1
	route_retry_timer = 0.0
	route_retry_delay = ROUTE_RETRY_INTERVAL
	route_no_progress_time = 0.0
	stuck_time = 0.0
	recovery_repath_done = true

func _reset_waypoint_progress() -> void:
	route_no_progress_time = 0.0
	route_best_distance = INF
	route_recovery_attempt = 0
	stuck_time = 0.0
	recovery_repath_done = false

func _stop_horizontal_movement() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

func _reset_route(destination: Vector3) -> void:
	path_destination = destination
	route_no_progress_time = 0.0
	route_best_distance = INF
	route_recovery_attempt = 0
	recovery_detour_requested = false
	recovery_repath_done = false
	route_retry_delay = ROUTE_RETRY_INTERVAL
	route_unreachable_time = 0.0
	route_unreachable_reason = RouteResult.UnreachableReason.NONE
	navigation_failed = false
	ai_move_failure_reason = BehaviorStep.FailureReason.NONE

func _update_route_progress(distance_before: float, distance_after: float, delta: float, direction: Vector3) -> void:
	if distance_after < route_best_distance - ROUTE_PROGRESS_EPSILON:
		route_best_distance = distance_after
		route_no_progress_time = 0.0
		route_recovery_attempt = 0
		return
	route_no_progress_time += delta
	if route_no_progress_time < ROUTE_RETRY_INTERVAL:
		return
	route_no_progress_time = 0.0
	_force_repath()

func _apply_gravity(delta: float) -> void:
	if not ground_contact_confirmed:
		if not _has_ground_below():
			velocity = Vector3.ZERO
			return
		ground_contact_confirmed = true
	if not is_on_floor() or velocity.y > 0.0:
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	if state == State.IDLE or state == State.RESTING or state == State.WAITING:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()


func _has_ground_below() -> bool:
	var space_state := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 0.25
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 2.0, collision_mask)
	query.exclude = [get_rid()]
	return not space_state.intersect_ray(query).is_empty()

func _work(delta: float) -> bool:
	var speed_multiplier := 1.0
	if _is_physical_work():
		if simulation != null and simulation.settlement.construction_gloves_available():
			# Durability is measured in collective in-game work hours, not frames.
			simulation.settlement.wear_construction_gloves(delta * simulation.GAME_MINUTES_PER_SECOND / 60.0)
			clear_status_effect(CitizenStatusEffect.BARE_HANDS)
		else:
			set_status_effect(CitizenStatusEffect.BARE_HANDS, "Bare hands", 1.0)
			speed_multiplier = 0.60
	if simulation != null:
		var smoke_multiplier: float = simulation.fire_smoke_work_multiplier(global_position)
		if smoke_multiplier < 1.0:
			set_status_effect(CitizenStatusEffectScript.SMOKY_EYES, "Smoky eyes", 1.0)
		else:
			clear_status_effect(CitizenStatusEffectScript.SMOKY_EYES)
		speed_multiplier *= smoke_multiplier
	else:
		clear_status_effect(CitizenStatusEffectScript.SMOKY_EYES)
	return task_timer.advance(delta * speed_multiplier)


func _is_physical_work() -> bool:
	return active_role in ["construction", "gather_branches", "gather_grass", "gather_food", "gather_water", "forestry", "farming", "excavation", "factory_worker", "craftsman"]


func _start_task(duration: float) -> void:
	task_timer.start(duration)

func set_player_controlled(controlled: bool) -> void:
	is_player_controlled = controlled
	if idle_indicator != null:
		idle_indicator.visible = false
	if controlled:
		current_toilet_target = null
		toilet_relief_position = Vector3.INF
		toilet_relief_type = ""
		has_toilet_resume_state = false
		toilet_resume_state = State.IDLE
		toilet_resume_idle_wander_anchor = Vector3.INF
		toilet_resume_idle_wander_target = Vector3.INF
		toilet_resume_idle_wander_pause = 0.0
		player_using_toilet = false
		if queue_release_notifier.is_valid():
			queue_release_notifier.call(self)
		state = State.IDLE
		construction_site = null
		factory = null
		active_role = ""
		movement_path.clear()
		path_destination = Vector3.INF
		route_unreachable_time = 0.0
		navigation_failed = false
		ai_move_target = Vector3.INF
		ai_move_arrived = false
		ai_move_failed = false

func _is_work_position_state(s: int) -> bool:
	return s in [
		State.WORK_POSITION,
		State.CANTEEN_WORK,
		State.SCHOOL_WORK,
		State.MARKET_WORK,
		State.OFFICIAL_WORK,
		State.CRAFT_WORK,
		State.RESEARCHING,
		State.FACTORY_WORK,
	]


func _clear_work_position_lock() -> void:
	work_position_locked = false
	work_position_anchor = Vector3.INF
	work_position_role = ""
	work_position_node = null
	work_position_temporary = true
	work_position_target = Vector3.INF
	_work_position_previous_state = State.IDLE
	_work_position_previous_active_role = ""
	_work_position_player_controlled = false


func enter_work_position(position: Vector3, role: String, building: Node3D = null, temporary := true, set_state := true) -> void:
	if work_position_locked:
		_clear_work_position_lock()
	_work_position_previous_state = state
	_work_position_previous_active_role = active_role
	_work_position_player_controlled = is_player_controlled
	work_position_locked = true
	work_position_anchor = position
	work_position_role = role
	work_position_node = building
	work_position_temporary = temporary
	work_position_target = Vector3.INF
	_reset_assignment_navigation()
	velocity = Vector3.ZERO
	if set_state:
		state = State.WORK_POSITION


func exit_work_position() -> void:
	if not work_position_locked:
		return
	var was_player_controlled := _work_position_player_controlled
	_clear_work_position_lock()
	if was_player_controlled:
		state = State.IDLE
		active_role = ""
	else:
		if state in [State.WORK_POSITION, State.CANTEEN_WORK, State.SCHOOL_WORK, State.MARKET_WORK, State.OFFICIAL_WORK, State.CRAFT_WORK, State.RESEARCHING, State.FACTORY_WORK]:
			state = _work_position_previous_state if _work_position_previous_state != State.WORK_POSITION else State.IDLE
			active_role = _work_position_previous_active_role


func move_to(destination: Vector3, arrival_radius: float = 0.25) -> bool:
	if is_player_controlled:
		return false
	_reset_assignment_navigation()
	ai_move_target = destination
	ai_move_arrival_radius = maxf(arrival_radius, 0.01)
	ai_move_arrived = false
	ai_move_failed = false
	ai_move_failure_reason = BehaviorStep.FailureReason.NONE
	state = State.AI_MOVING
	return true


func has_arrived() -> bool:
	return ai_move_arrived


func stop_movement() -> void:
	if state == State.AI_MOVING:
		idle()


func set_hero(hero: bool) -> void:
	is_hero = hero
	if hero:
		add_to_group("hero")
		if body_material != null:
			body_material.albedo_color = Color("e6c857")
		# _ready() already built a regular citizen model; rebuild it as the constable
		# so the hero is instantly recognisable (skin-only recolour, fixed head).
		if current_model_path != "":
			visual_builder.update_character_model(self)

func set_head_visible(value: bool) -> void:
	head_visible = value
	if current_head_mesh != null:
		current_head_mesh.visible = value
	var fallback_mesh = get_node_or_null("FallbackMesh")
	if fallback_mesh:
		var fallback_head = fallback_mesh.get_node_or_null("FallbackHead")
		if fallback_head:
			fallback_head.visible = value

func assign_construction(site: Node3D) -> void:
	task_executor.assign_construction(self, site)

func assign_demolition(building: Node3D) -> void:
	task_executor.assign_demolition(self, building)

func finish_construction(site: Node3D) -> void:
	task_executor.finish_construction(self, site)

func assign_excavation(site: Node3D) -> void:
	task_executor.assign_excavation(self, site)

func deliver_excavation(next_resource_type: String, warehouse: Vector3) -> void:
	task_executor.deliver_excavation(self, next_resource_type, warehouse)

func storage_delivery_result(accepted: bool, reason := StringName()) -> void:
	task_executor.storage_delivery_result(self, accepted, reason)

func register_pending_resource(next_resource_type: String, amount: int) -> void:
	task_executor.register_pending_resource(self, next_resource_type, amount)

func has_pending_resource() -> bool:
	return task_executor.has_pending_resource(self)

func take_pending_resource(max_amount := 0) -> Dictionary:
	return task_executor.take_pending_resource(self, max_amount)

func assign_courier_pickup(worker: Citizen, warehouse: Vector3) -> void:
	task_executor.assign_courier_pickup(self, worker, warehouse)

func assign_sawmill_pickup(sawmill: Vector3, warehouse: Vector3) -> void:
	task_executor.assign_sawmill_pickup(self, sawmill, warehouse)

func collect_sawmill_boards(amount: int) -> void:
	task_executor.collect_sawmill_boards(self, amount)

func assign_dew_collector_pickup(collector: Vector3, warehouse: Vector3) -> void:
	task_executor.assign_dew_collector_pickup(self, collector, warehouse)

func collect_dew(amount: int) -> void:
	task_executor.collect_dew(self, amount)

func deliver_sawmill_boards(amount: int) -> void:
	task_executor.deliver_sawmill_boards(self, amount)

func assign_next_forestry_tree(tree_position: Vector3) -> void:
	task_executor.assign_next_forestry_tree(self, tree_position)

func assign_canteen_work(next_canteen_position: Vector3) -> void:
	task_executor.assign_canteen_work(self, next_canteen_position)

func assign_teacher_work(next_school_position: Vector3) -> void:
	task_executor.assign_teacher_work(self, next_school_position)

func assign_seller_work(next_market_position: Vector3) -> void:
	task_executor.assign_seller_work(self, next_market_position)

func assign_official_work(next_office_position: Vector3) -> void:
	task_executor.assign_official_work(self, next_office_position)

func assign_craft_work(next_craft_position: Vector3, next_speed_multiplier := 1.0) -> void:
	task_executor.assign_craft_work(self, next_craft_position, next_speed_multiplier)

func assign_research_work(next_research_position: Vector3) -> void:
	task_executor.assign_research_work(self, next_research_position)

func _process_research(delta: float) -> void:
	task_executor.process_research(self, delta)

func _process_craft_work_arrival(delta: float) -> void:
	task_executor.process_craft_work_arrival(self, delta)

func _process_craft_work(delta: float) -> void:
	task_executor.process_craft_work(self, delta)

func assign_factory_work(next_factory: Node3D, role: String) -> void:
	task_executor.assign_factory_work(self, next_factory, role)

func go_to_park(next_park_position: Vector3, minimum_hours := 0, duration_override := -1.0) -> void:
	task_executor.go_to_park(self, next_park_position, minimum_hours, duration_override)

func deliver_trade(source: Vector3, destination: Vector3) -> void:
	task_executor.deliver_trade(self, source, destination)

func start_training(next_role: String, next_school_position: Vector3) -> void:
	task_executor.start_training(self, next_role, next_school_position)

func attend_school(school_pos: Vector3, role_to_train: String) -> void:
	task_executor.attend_school(self, school_pos, role_to_train)

func finish_school_day(teacher_present := true) -> void:
	task_executor.finish_school_day(self, teacher_present)


func apply_daily_decay() -> void:
	profile.apply_daily_decay()

func is_building_site(site: Node3D) -> bool:
	return not is_player_controlled and state == State.CONSTRUCTING and construction_site == site and global_position.distance_to(construction_position) <= 0.7

func setup_navigation(next_pathfinder: Callable, next_delivery_position_resolver := Callable(), next_queue_position_resolver := Callable(), next_movement_speed_modifier_query := Callable(), next_navigation_revision_query := Callable(), next_trail_movement_recorder := Callable(), next_route_reachability_query := Callable(), next_queue_arrival_notifier := Callable(), next_queue_release_notifier := Callable(), next_recovery_pathfinder := Callable(), next_route_safety_query := Callable()) -> void:
	pathfinder = next_pathfinder
	recovery_pathfinder = next_recovery_pathfinder
	delivery_position_resolver = next_delivery_position_resolver
	queue_position_resolver = next_queue_position_resolver
	queue_arrival_notifier = next_queue_arrival_notifier
	queue_release_notifier = next_queue_release_notifier
	route_reachability_query = next_route_reachability_query
	route_safety_query = next_route_safety_query
	movement_speed_modifier_query = next_movement_speed_modifier_query
	navigation_revision_query = next_navigation_revision_query
	trail_movement_recorder = next_trail_movement_recorder

func setup_registration_service(staff_checker: Callable, duration_resolver: Callable) -> void:
	registration_staff_checker = staff_checker
	registration_duration_resolver = duration_resolver

func _refresh_warehouse_position() -> void:
	# A lodge worker temporarily uses this destination to return food to their
	# workplace before a courier takes over the warehouse leg.
	if active_role == "gather_food":
		return
	if not delivery_position_resolver.is_valid():
		return
	var resolved: Vector3 = delivery_position_resolver.call(global_position)
	if resolved != Vector3.INF and warehouse_position.distance_to(resolved) > 0.08:
		warehouse_position = resolved

func begin_role_recheck_cooldown() -> void:
	if has_no_permanent_work() and daily_order_role.is_empty():
		role_recheck_remaining = randf_range(ROLE_RECHECK_MIN_DELAY, ROLE_RECHECK_MAX_DELAY)


func can_recheck_idle_work() -> bool:
	return role_recheck_remaining <= 0.0

func _work_position_for(site: Node3D) -> Vector3:
	if site.has_meta("service_positions"):
		var positions: Array = site.get_meta("service_positions")
		var best := Vector3.INF
		var best_distance := INF
		for value in positions:
			if value is Vector3:
				var position: Vector3 = value
				var distance := global_position.distance_squared_to(position)
				if distance < best_distance:
					best = position
					best_distance = distance
		if best != Vector3.INF:
			return best

	var site_position := site.global_position if site.is_inside_tree() else site.position
	var footprint: Vector2i = site.get_meta("footprint", Vector2i(3, 3))
	var actor_position := global_position if is_inside_tree() else position
	var offset := actor_position - site_position
	offset.y = 0.0
	var slot := float(int(get_instance_id() % 3) - 1) * CONSTRUCTION_SLOT_SPACING
	if absf(offset.x) > absf(offset.z):
		var x_distance := footprint.x * 0.5 + CONSTRUCTION_APPROACH_DISTANCE
		return site_position + Vector3(x_distance if offset.x >= 0.0 else -x_distance, 0.0, slot)
	var z_distance := footprint.y * 0.5 + CONSTRUCTION_APPROACH_DISTANCE
	return site_position + Vector3(slot, 0.0, z_distance if offset.z >= 0.0 else -z_distance)


func _reachable_construction_approach(site: Node3D) -> Vector3:
	if site.has_meta("service_positions"):
		var positions: Array = site.get_meta("service_positions")
		var best := Vector3.INF
		var best_distance := INF
		for value in positions:
			if value is Vector3:
				var position: Vector3 = value
				if not route_reachability_query.is_valid() or _is_valid_approach_point(position):
					var distance := global_position.distance_squared_to(position)
					if distance < best_distance:
						best = position
						best_distance = distance
		if best != Vector3.INF:
			return best

	var primary := _work_position_for(site)
	if not route_reachability_query.is_valid():
		return primary
	if _is_valid_approach_point(primary):
		return primary
	var site_position := site.global_position if site.is_inside_tree() else site.position
	var footprint: Vector2i = site.get_meta("footprint", Vector2i(3, 3))
	var slot := float(int(get_instance_id() % 3) - 1) * CONSTRUCTION_SLOT_SPACING
	var x_distance := footprint.x * 0.5 + CONSTRUCTION_APPROACH_DISTANCE
	var z_distance := footprint.y * 0.5 + CONSTRUCTION_APPROACH_DISTANCE
	var candidates: Array[Vector3] = [
		site_position + Vector3(x_distance, 0.0, slot),
		site_position + Vector3(-x_distance, 0.0, slot),
		site_position + Vector3(slot, 0.0, z_distance),
		site_position + Vector3(slot, 0.0, -z_distance),
		site_position + Vector3(x_distance, 0.0, 0.0),
		site_position + Vector3(-x_distance, 0.0, 0.0),
		site_position + Vector3(0.0, 0.0, z_distance),
		site_position + Vector3(0.0, 0.0, -z_distance),
	]
	for candidate: Vector3 in candidates:
		if _is_valid_approach_point(candidate):
			return candidate
	return Vector3.INF


func _is_valid_approach_point(point: Vector3) -> bool:
	if not route_reachability_query.is_valid():
		return true
	return bool(route_reachability_query.call(global_position, point, false))

func get_core_skill_for_role(role: String) -> String:
	return CitizenProfileScript.get_core_skill_for_role(role)

func has_perk(skill_name: String) -> bool:
	return profile.has_perk(skill_name)

func get_walk_speed() -> float:
	var speed := WALK_SPEED * float(COURIER_EQUIPMENT.get(courier_equipment, COURIER_EQUIPMENT.hands).speed)
	if has_perk("construction"):
		speed *= 1.15
	if simulation != null and simulation.settlement != null:
		if simulation.settlement.double_time_order_day == simulation.day_cycle.current_day:
			speed *= 2.0
	return speed


func courier_capacity() -> int:
	return int(COURIER_EQUIPMENT.get(courier_equipment, COURIER_EQUIPMENT.hands).capacity)


func set_courier_equipment(next_equipment: String) -> void:
	if COURIER_EQUIPMENT.has(next_equipment):
		courier_equipment = next_equipment

func setup_specialization(next_specialization: String) -> void:
	specialization = next_specialization
	if body_material != null:
		body_material.albedo_color = Color("e6c857") if is_hero else CitizenRoleProfile.color_for(specialization)
	visual_builder.update_character_model(self)

func get_efficiency(role: String) -> float:
	var era_index := 0
	if simulation != null and simulation.settlement != null:
		era_index = int(simulation.settlement.era)
	var story_fn := Callable()
	if simulation != null:
		story_fn = Callable(simulation, "campfire_story_efficiency_multiplier")
	return efficiency_service.compute_efficiency(
		role, skills, satisfaction, fatigue, buffs,
		Callable(self, "has_perk"), is_jack_of_all_trades,
		era_index, story_fn
	)

func role_label() -> String:
	var role := CitizenRoleProfile.label_for(specialization)
	return "Hero (%s)" % role if is_hero else role

func specialization_color() -> Color:
	return Color("e6c857") if is_hero else CitizenRoleProfile.color_for(specialization)

func preferred_role() -> String:
	return CitizenRoleProfile.preferred_role_for(specialization)

func idle() -> void:
	if is_player_controlled:
		return
	_reset_assignment_navigation()
	if queue_release_notifier.is_valid():
		queue_release_notifier.call(self)
	state = State.IDLE
	active_role = ""
	construction_site = null
	assigned_dig_site = null
	factory = null
	_start_pending_arrival_if_any()

func begin_waiting() -> void:
	# Enter the pre-rest waiting window. Idempotent: repeated calls (e.g. a retry
	# that still fails to find a free work node) preserve the running countdown so
	# the citizen reliably progresses toward rest instead of waiting forever.
	if is_player_controlled or state == State.WAITING:
		return
	_reset_assignment_navigation()
	state = State.WAITING
	active_role = ""
	construction_site = null
	assigned_dig_site = null
	factory = null
	task_timer.start(WAIT_DURATION * 24.0)
	wait_recheck = WAIT_RECHECK_INTERVAL

func _update_idle_indicator() -> void:
	idle_indicator_controller.update_idle_indicator(self)


func _update_privacy_blur() -> void:
	idle_indicator_controller.update_privacy_blur(self)


func _advance_state_display(delta: float) -> void:
	_displayed_state_elapsed += delta
	if _pending_state_display.is_empty() or _displayed_state_elapsed < MIN_STATE_DISPLAY_DURATION:
		return
	# Keep the visible state for one real second, then catch up to the newest
	# transition instead of replaying a long stale backlog.
	_displayed_state = _pending_state_display.back()
	_pending_state_display.clear()
	_displayed_state_elapsed = 0.0


func _state_display_name(displayed_state: int) -> String:
	return idle_indicator_controller.state_display_name(displayed_state)


func _employment_workplace_suffix(workplace: Node3D) -> String:
	return idle_indicator_controller.employment_workplace_suffix(workplace)

func assign_home(next_home: Node3D) -> void:
	home = next_home
	if is_instance_valid(home) and home.has_meta("is_tent"):
		add_debuff("tent", 15.0)
	else:
		remove_debuff("tent")

func go_home() -> void:
	if not is_player_controlled and not has_active_arrival_task() and not has_active_delivery() and is_instance_valid(home):
		_reset_assignment_navigation()
		factory = null
		state = State.TO_HOME

func go_to_canteen(next_canteen_position: Vector3) -> void:
	if not is_player_controlled and not has_active_delivery():
		_reset_assignment_navigation()
		canteen_position = next_canteen_position
		active_role = ""
		factory = null
		state = State.TO_CANTEEN

func deliver_food_to_canteen(warehouse: Vector3, next_canteen_position: Vector3, amount: int) -> void:
	if not is_player_controlled:
		_reset_assignment_navigation()
		warehouse_position = warehouse
		canteen_position = next_canteen_position
		delivery_amount = amount
		active_role = ""
		factory = null
		state = State.TO_FOOD_PICKUP

func add_debuff(debuff_id: String, value: float) -> void:
	_needs.add_debuff(debuff_id, value)

func remove_debuff(debuff_id: String) -> void:
	_needs.remove_debuff(debuff_id)

func set_status_effect(status_id: StringName, label: String, severity := 0.0, duration_hours := -1.0) -> void:
	_needs.set_status_effect(status_id, label, severity, duration_hours)

func clear_status_effect(status_id: StringName) -> void:
	_needs.clear_status_effect(status_id)

func has_status_effect(status_id: StringName) -> bool:
	return _needs.has_status_effect(status_id)

func status_effect_labels() -> Array[String]:
	return _needs.status_effect_labels()

func get_satisfaction_cap() -> float:
	return _needs.get_satisfaction_cap()

func receive_meal(served: bool, cooked := true, water_available := true) -> void:
	_needs.receive_meal(served, cooked, water_available)

func _update_effects(delta: float) -> void:
	_needs.update_effects(delta)

func is_available_for_schedule() -> bool:
	if has_active_arrival_task():
		return false
	return not is_player_controlled and not has_active_delivery() and state != State.TO_CANTEEN and state != State.EATING and state != State.TO_HOME and state != State.RESTING and state != State.STUDYING and state != State.TO_PARK and state != State.RELAXING and state != State.RESEARCHING and state != State.TO_TOILET and state != State.USING_TOILET and state != State.WAITING_FOR_TOILET and state != State.TO_BUSH and state != State.USING_BUSH and state != State.WORK_POSITION and state != State.LEAVING

func _update_satisfaction(delta: float) -> void:
	satisfaction_tick += delta
	if satisfaction_tick < 1.0:
		return
	var mentor_fn := Callable()
	if simulation != null:
		mentor_fn = Callable(self, "_check_mentor_synergy")
	var result: RefCounted = satisfaction_service.compute_tick(
		active_role, preferred_role(), overtime_mode,
		satisfaction, satisfaction_tick, skills,
		get_satisfaction_cap(), has_active_daily_order(),
		mentor_fn, global_position
	)
	satisfaction = result.satisfaction
	satisfaction_tick = result.satisfaction_tick
	skills = result.skills
	for skill_name in result.practiced_skills:
		practiced_today[skill_name] = true

func _check_mentor_synergy(core_skill: String, position: Vector3) -> float:
	if simulation == null:
		return 1.0
	for other in simulation.citizens:
		if other != self and not other.is_player_controlled:
			var other_core: String = other.get_core_skill_for_role(other.active_role)
			if other_core == core_skill and float(other.skills.get(core_skill, 0.0)) >= 0.80:
				if position.distance_to(other.global_position) <= 5.0:
					return 1.5
	return 1.0


func assign_gathering(res_type: String, source_pos: Vector3, delivery_pos: Vector3, access_pos := Vector3.INF) -> void:
	if is_player_controlled:
		return
	_reset_assignment_navigation()
	gather_resource_type = res_type
	gather_source_position = source_pos
	gather_access_position = source_pos if access_pos == Vector3.INF else access_pos
	warehouse_position = delivery_pos
	active_role = "gather_" + res_type
	state = State.TO_GATHER

func assign_cleaning(res_type: String, source_pos: Vector3, access_pos: Vector3, delivery_pos: Vector3) -> void:
	if is_player_controlled:
		return
	_reset_assignment_navigation()
	gather_resource_type = res_type
	gather_source_position = source_pos
	gather_access_position = access_pos
	warehouse_position = delivery_pos
	active_role = "cleaning"
	state = State.TO_CLEANING_PILE


func _process_to_gather(delta: float) -> void:
	if _move_to(gather_access_position, delta, false, false):
		state = State.GATHERING
		var base_duration := 2.0 / get_efficiency("forestry" if gather_resource_type in ["branches", "logs"] else "farming")
		if is_instance_valid(employment_workplace):
			var b_type := str(employment_workplace.get_meta("building_type", ""))
			if b_type.ends_with("_lvl2"):
				base_duration /= 1.3
			elif b_type.ends_with("_lvl3"):
				base_duration /= 1.7
		_start_task(base_duration)

func _process_gathering(delta: float) -> void:
	if _work(delta):
		# Raw bootstrap materials (branches/grass) are gathered two-at-a-time so the
		# early tent era is not a one-unit-per-trip slog; skill still governs cycle
		# speed and matters more in later eras. Water hauling keeps its bucket bonus.
		var gathered_amount := 1
		if gather_resource_type == "water" and active_role == "gather_water":
			gathered_amount = 3
		elif gather_resource_type in ["branches", "grass"]:
			gathered_amount = 2
		resource_type = gather_resource_type
		if resource_type == "food" and simulation != null:
			resource_type = simulation.harvest_wild_food(gather_source_position, self)
			if resource_type.is_empty():
				idle()
				return
		if resource_type == "logs":
			tree_harvested.emit(self, gather_source_position)
			if has_perk("forestry") and randf() < 0.10:
				gathered_amount *= 2
				if simulation != null:
					simulation._update_interface("Lumberjack Master: Forester gathered 2 logs!")
		var consumed_amount := 1
		if simulation != null:
			if resource_type == "grass":
				consumed_amount = simulation._consume_grass_source(gather_source_position)
			elif resource_type == "branches":
				consumed_amount = simulation._consume_tree_branches(gather_source_position)
		if consumed_amount <= 0 and resource_type in ["grass", "branches"]:
			idle()
			return
		carried_amount = gathered_amount
		if active_role == "gather_food" and is_instance_valid(employment_workplace):
			warehouse_position = employment_workplace.get_meta("service_position", employment_workplace.global_position)
		# Bootstrap gathering remains self-contained, while food collected by a
		# dedicated lodge is handed to a courier at the lodge.
		state = State.TO_WAREHOUSE

func _process_trade_pickup(delta: float) -> void:
	if _move_to(trade_source_position, delta):
		state = State.TO_TRADE_DESTINATION

func _process_trade_destination(delta: float) -> void:
	if _move_to(trade_destination_position, delta):
		state = State.IDLE
		trade_delivery_finished.emit(self)


func _reset_assignment_navigation() -> void:
	if queue_release_notifier.is_valid():
		queue_release_notifier.call(self)
	idle_wander_anchor = Vector3.INF
	idle_wander_target = Vector3.INF
	movement_path.clear()
	active_route = null
	path_destination = Vector3.INF
	route_retry_timer = 0.0
	route_unreachable_time = 0.0
	navigation_failed = false
	ai_move_target = Vector3.INF
	ai_move_arrived = false
	ai_move_failed = false


func go_to_relief(destination: Vector3, relief_kind: StringName) -> void:

	toilet_handler.go_to_relief(self, destination, relief_kind)

func begin_player_toilet_use(toilet_node: Node3D) -> void:
	toilet_handler.begin_player_toilet_use(self, toilet_node)

func _begin_toilet_trip(next_state: int) -> void:
	toilet_handler.begin_toilet_trip(self, next_state)

func _reset_toilet_navigation() -> void:
	toilet_handler.reset_toilet_navigation(self)

func _resume_after_toilet() -> void:
	toilet_handler.resume_after_toilet(self)

func _process_to_toilet(delta: float) -> void:
	toilet_handler.process_to_toilet(self, delta)

func _process_using_toilet(delta: float) -> void:
	toilet_handler.process_using_toilet(self, delta)

func _process_waiting_for_toilet(delta: float) -> void:
	toilet_handler.process_waiting_for_toilet(self, delta)

func _process_to_bush(delta: float) -> void:
	toilet_handler.process_to_bush(self, delta)

func _process_using_bush(delta: float) -> void:
	toilet_handler.process_using_bush(self, delta)



func _process_ai_moving(delta: float) -> void:
	if navigation_failed:
		ai_move_failed = true
		return
	if _move_to(ai_move_target, delta, false, false, true, ai_move_arrival_radius):
		ai_move_arrived = true


func execute_action(action: StringName, target: Node3D, payload: AIFactSet) -> bool:
	if is_player_controlled:
		return false
	match action:
		&"sleep", &"eat", &"relieve", &"rest", &"relax":
			return _execute_personal_need_action(action, payload)
		&"forestry", &"farming", &"gathering", &"cleaning", &"excavation", &"factory_work":
			return _execute_production_action(action, target, payload)
		&"construction", &"demolition", &"cook", &"teacher", &"seller", &"official", &"craftsman", &"researcher", &"register":
			return _execute_workforce_action(action, target, payload)
		&"courier_delivery":
			return _execute_logistics_action(action, target, payload)
	return false


func _execute_personal_need_action(action: StringName, payload: AIFactSet) -> bool:
	match action:
		&"sleep":
			if not is_instance_valid(home):
				return false
			_reset_assignment_navigation()
			factory = null
			var home_entrance: Vector3 = home.position
			if home.is_inside_tree():
				home_entrance = home.get_meta("entrance_position", home.global_position)
			if is_inside_tree() and global_position.distance_to(home_entrance) <= 0.5:
				state = State.RESTING
			else:
				state = State.TO_HOME
			return state in [State.TO_HOME, State.RESTING]
		&"eat":
			var destination: Variant = payload.value(&"target.position", Vector3.INF) if payload != null else Vector3.INF
			if not (destination is Vector3) or destination == Vector3.INF:
				return false
			_reset_assignment_navigation()
			canteen_position = destination
			active_role = ""
			factory = null
			if is_inside_tree() and global_position.distance_to(destination) <= 0.5:
				state = State.EATING
				_start_task(1.1)
			else:
				state = State.TO_CANTEEN
			return state in [State.TO_CANTEEN, State.EATING]
		&"relieve":
			var relief_position: Variant = payload.value(&"target.position", Vector3.INF) if payload != null else Vector3.INF
			var relief_kind: Variant = payload.value(&"target.kind", &"") if payload != null else &""
			if not (relief_position is Vector3) or relief_position == Vector3.INF or not (relief_kind is StringName):
				return false
			go_to_relief(relief_position, relief_kind)
			return state in [State.TO_TOILET, State.USING_TOILET, State.WAITING_FOR_TOILET, State.TO_BUSH, State.USING_BUSH]
		&"rest":
			var rest_position: Variant = payload.value(&"target.position", Vector3.INF) if payload != null else Vector3.INF
			var rest_duration := float(payload.value(&"action.duration", 4.0)) if payload != null else 4.0
			if not (rest_position is Vector3) or rest_position == Vector3.INF:
				return false
			go_to_park(rest_position, 0, rest_duration)
			return state in [State.TO_PARK, State.RELAXING]
		&"relax":
			var relax_duration := float(payload.value(&"action.duration", 4.0)) if payload != null else 4.0
			state = State.RELAXING
			_start_task(relax_duration)
			return true
	return false


func _execute_production_action(action: StringName, target: Node3D, payload: AIFactSet) -> bool:
	match action:
		&"forestry":
			var tree_position: Variant = payload.value(&"target.position", Vector3.INF) if payload != null else Vector3.INF
			var access_position: Variant = payload.value(&"target.access_position", Vector3.INF) if payload != null else Vector3.INF
			var sawmill_position: Variant = payload.value(&"workplace.position", Vector3.INF) if payload != null else Vector3.INF
			var warehouse_position: Variant = payload.value(&"warehouse.position", Vector3.INF) if payload != null else Vector3.INF
			if not (tree_position is Vector3) or tree_position == Vector3.INF or not (access_position is Vector3) or access_position == Vector3.INF or not (sawmill_position is Vector3) or sawmill_position == Vector3.INF or not (warehouse_position is Vector3) or warehouse_position == Vector3.INF:
				return false
			start_production_cycle("wood", tree_position, sawmill_position, warehouse_position, false, access_position)
			return state in [State.TO_TREE, State.CHOPPING, State.TO_SAWMILL]
		&"farming":
			var farm_position: Variant = payload.value(&"workplace.position", Vector3.INF) if payload != null else Vector3.INF
			var farm_warehouse_position: Variant = payload.value(&"warehouse.position", Vector3.INF) if payload != null else Vector3.INF
			if not (farm_position is Vector3) or farm_position == Vector3.INF or not (farm_warehouse_position is Vector3) or farm_warehouse_position == Vector3.INF:
				return false
			start_production_cycle("food", farm_position, farm_position, farm_warehouse_position, true)
			return state in [State.TO_TREE, State.TO_SAWMILL, State.SAWING, State.WAITING_COURIER]
		&"gathering":
			var resource_type: Variant = payload.value(&"resource.type", "") if payload != null else ""
			var source_position: Variant = payload.value(&"target.position", Vector3.INF) if payload != null else Vector3.INF
			var access_position: Variant = payload.value(&"target.access_position", Vector3.INF) if payload != null else Vector3.INF
			var gathering_warehouse_position: Variant = payload.value(&"warehouse.position", Vector3.INF) if payload != null else Vector3.INF
			if not (resource_type is String) or resource_type.is_empty() or not (source_position is Vector3) or source_position == Vector3.INF or not (access_position is Vector3) or access_position == Vector3.INF or not (gathering_warehouse_position is Vector3) or gathering_warehouse_position == Vector3.INF:
				return false
			assign_gathering(resource_type, source_position, gathering_warehouse_position, access_position)
			return state in [State.TO_GATHER, State.GATHERING, State.TO_WAREHOUSE]
		&"cleaning":
			var cleaning_resource_type: Variant = payload.value(&"resource.type", "") if payload != null else ""
			var pile_position: Variant = payload.value(&"target.position", Vector3.INF) if payload != null else Vector3.INF
			var pile_access_position: Variant = payload.value(&"target.access_position", Vector3.INF) if payload != null else Vector3.INF
			var cleaning_warehouse_position: Variant = payload.value(&"warehouse.position", Vector3.INF) if payload != null else Vector3.INF
			if not (cleaning_resource_type is String) or cleaning_resource_type.is_empty() or not (pile_position is Vector3) or pile_position == Vector3.INF or not (pile_access_position is Vector3) or pile_access_position == Vector3.INF or not (cleaning_warehouse_position is Vector3) or cleaning_warehouse_position == Vector3.INF:
				return false
			assign_cleaning(cleaning_resource_type, pile_position, pile_access_position, cleaning_warehouse_position)
			return state in [State.TO_CLEANING_PILE, State.CLEANING_PILE, State.TO_WAREHOUSE]
		&"excavation":
			if not is_instance_valid(target):
				return false
			assign_excavation(target)
			return state == State.EXCAVATING
		&"factory_work":
			var factory_role: Variant = payload.value(&"factory.role", &"") if payload != null else &""
			if not is_instance_valid(target) or not (factory_role is StringName) or factory_role == &"":
				return false
			assign_factory_work(target, String(factory_role))
			return state in [State.TO_FACTORY, State.FACTORY_WORK]
	return false


func _execute_workforce_action(action: StringName, target: Node3D, payload: AIFactSet) -> bool:
	match action:
		&"construction", &"demolition":
			if not is_instance_valid(target):
				return false
			if action == &"construction":
				assign_construction(target)
			else:
				assign_demolition(target)
			return state == State.CONSTRUCTING
		&"cook", &"teacher", &"seller", &"official", &"craftsman", &"researcher":
			var service_position: Variant = payload.value(&"workplace.position", Vector3.INF) if payload != null else Vector3.INF
			if not (service_position is Vector3) or service_position == Vector3.INF:
				return false
			match action:
				&"cook": assign_canteen_work(service_position)
				&"teacher": assign_teacher_work(service_position)
				&"seller": assign_seller_work(service_position)
				&"official": assign_official_work(service_position)
				&"craftsman": assign_craft_work(service_position, _craft_speed_multiplier_internal())
				&"researcher": assign_research_work(service_position)
			return state in _service_states_for_internal(action)
		&"register":
			var center_position: Variant = payload.value(&"center.position", Vector3.INF) if payload != null else Vector3.INF
			var pending_role: Variant = payload.value(&"workplace.role", "") if payload != null else ""
			if not (center_position is Vector3) or center_position == Vector3.INF or not (pending_role is String) or pending_role.is_empty():
				return false
			begin_employment_processing(center_position, pending_role, target)
			return state in [State.TO_EMPLOYMENT_CENTER, State.EMPLOYMENT_PROCESSING]
	return false


func _execute_logistics_action(action: StringName, target: Node3D, payload: AIFactSet) -> bool:
	if action == &"courier_delivery":
		var task_id: Variant = payload.value(&"courier.task_id", &"") if payload != null else &""
		if not (task_id is StringName) or task_id == &"" or simulation == null or simulation.courier_dispatcher == null:
			return false
		if not simulation.courier_dispatcher.start_task(self, task_id):
			return false
		return has_active_delivery()
	return false


func get_action_status(action: StringName) -> int:
	if navigation_failed:
		return 3 # FAILED
	match action:
		&"sleep":
			if state in [State.TO_HOME, State.RESTING]:
				return 1 # RUNNING
		&"eat":
			if state in [State.TO_CANTEEN, State.EATING]:
				return 1 # RUNNING
			if state == State.IDLE:
				return 2 # SUCCEEDED
		&"relieve":
			if state in [State.TO_TOILET, State.USING_TOILET, State.WAITING_FOR_TOILET, State.TO_BUSH, State.USING_BUSH]:
				return 1 # RUNNING
			if simulation != null and simulation.citizen_needs_service != null and not simulation.citizen_needs_service.has_toilet_request(ai_id):
				return 2 # SUCCEEDED
			if state == State.IDLE:
				return 2 # SUCCEEDED
		&"rest":
			if state in [State.TO_PARK, State.RELAXING]:
				return 1 # RUNNING
			if simulation != null and simulation.citizen_needs_service != null and not simulation.citizen_needs_service.has_rest_request(ai_id):
				return 2 # SUCCEEDED
			if state == State.IDLE:
				return 2 # SUCCEEDED
		&"relax":
			if state == State.RELAXING:
				return 1 # RUNNING
			if state == State.IDLE:
				return 2 # SUCCEEDED
		&"forestry":
			if state in [State.TO_TREE, State.CHOPPING, State.TO_SAWMILL]:
				return 1 # RUNNING
			if state == State.IDLE:
				return 2 # SUCCEEDED
		&"farming":
			if state in [State.TO_TREE, State.CHOPPING, State.TO_SAWMILL, State.SAWING, State.WAITING_COURIER]:
				return 1 # RUNNING
			if state == State.IDLE:
				return 2 # SUCCEEDED
		&"construction", &"demolition":
			if state == State.CONSTRUCTING and active_role == str(action):
				return 1 # RUNNING
			if state == State.IDLE:
				return 2 # SUCCEEDED
		&"gathering":
			if state in [State.TO_GATHER, State.GATHERING, State.TO_WAREHOUSE, State.WAITING_COURIER]:
				return 1 # RUNNING
			if state == State.IDLE:
				return 2 # SUCCEEDED
		&"cleaning":
			if state in [State.TO_CLEANING_PILE, State.CLEANING_PILE, State.TO_WAREHOUSE]:
				return 1 # RUNNING
			if state == State.IDLE:
				return 2 # SUCCEEDED
		&"excavation":
			if state in [State.EXCAVATING, State.WAITING_COURIER]:
				return 1 # RUNNING
			if state == State.IDLE:
				return 2 # SUCCEEDED
		&"cook", &"teacher", &"seller", &"official", &"craftsman", &"researcher":
			if state in _service_states_for_internal(action):
				return 1 # RUNNING
			if state == State.IDLE:
				return 2 # SUCCEEDED
		&"factory_work":
			if state in [State.TO_FACTORY, State.FACTORY_WORK]:
				return 1 # RUNNING
			if state == State.IDLE:
				return 2 # SUCCEEDED
		&"courier_delivery":
			if has_active_delivery():
				return 1 # RUNNING
			if state == State.IDLE:
				return 2 # SUCCEEDED
		&"register":
			if state in [State.TO_EMPLOYMENT_CENTER, State.EMPLOYMENT_PROCESSING]:
				return 1 # RUNNING
			if employment_state == EmploymentState.EMPLOYED or state == State.IDLE:
				return 2 # SUCCEEDED
	return 3 # FAILED


func cancel_current_action() -> void:
	var was_relief_action := state in [State.TO_TOILET, State.USING_TOILET, State.WAITING_FOR_TOILET, State.TO_BUSH, State.USING_BUSH]
	var was_construction_delivery := state in [State.TO_CONSTRUCTION_PICKUP, State.TO_CONSTRUCTION_SITE]
	# A gathering or cleaning action can be interrupted after the resource has been picked
	# up. Put that cargo on the ground rather than leaving it attached to an idle worker.
	if (active_role.begins_with("gather_") or active_role == "cleaning") and carried_amount > 0 and not resource_type.is_empty():
		resource_dropped.emit(self, resource_type, carried_amount)
		carried_amount = 0
	if is_registering():
		pending_employment_role = ""
		pending_employment_workplace = null
		registration_queue_order = -1
		employment_state = EmploymentState.NO_PERMANENT_WORK
	if state in [State.TO_HOME, State.RESTING, State.TO_CANTEEN, State.EATING, State.TO_TOILET, State.USING_TOILET, State.WAITING_FOR_TOILET, State.TO_BUSH, State.USING_BUSH, State.AI_MOVING, State.TO_PARK, State.RELAXING, State.TO_TREE, State.CHOPPING, State.TO_SAWMILL, State.SAWING, State.WAITING_COURIER, State.CONSTRUCTING, State.TO_GATHER, State.GATHERING, State.TO_CLEANING_PILE, State.CLEANING_PILE, State.TO_WAREHOUSE, State.EXCAVATING, State.TO_CANTEEN_WORK, State.CANTEEN_WORK, State.TO_SCHOOL_WORK, State.SCHOOL_WORK, State.TO_MARKET_WORK, State.MARKET_WORK, State.TO_OFFICIAL_WORK, State.OFFICIAL_WORK, State.TO_CRAFT_WORK, State.CRAFT_WORK, State.RESEARCHING, State.TO_FACTORY, State.FACTORY_WORK, State.COURIER_TO_WORKER, State.COURIER_TO_WAREHOUSE, State.COURIER_TO_SAWMILL, State.TO_FOOD_PICKUP, State.TO_CANTEEN_DELIVERY, State.TO_CONSTRUCTION_PICKUP, State.TO_CONSTRUCTION_SITE, State.TO_TRADE_PICKUP, State.TO_TRADE_DESTINATION, State.TO_EMPLOYMENT_CENTER, State.EMPLOYMENT_PROCESSING]:
		idle()
	if was_construction_delivery:
		# The site reservation is reconciled by SettlementGame. Clear the actor-side
		# cargo so a cancelled route cannot remain an assigned delivery forever.
		carried_amount = 0
		construction_delivery_resource = ""
		building_supply_kind = "construction"
	if was_relief_action:
		current_toilet_target = null
		toilet_relief_position = Vector3.INF
		toilet_relief_type = ""
		has_toilet_resume_state = false
		toilet_resume_state = State.IDLE
		toilet_resume_idle_wander_anchor = Vector3.INF
		toilet_resume_idle_wander_target = Vector3.INF
		toilet_resume_idle_wander_pause = 0.0


func end_work_shift() -> void:
	if is_player_controlled:
		return
	if state in [State.TO_TREE, State.CHOPPING, State.TO_SAWMILL, State.SAWING, State.WAITING_COURIER, State.CONSTRUCTING, State.EXCAVATING, State.TO_GATHER, State.GATHERING, State.TO_CLEANING_PILE, State.CLEANING_PILE, State.TO_WAREHOUSE, State.TO_CANTEEN_WORK, State.CANTEEN_WORK, State.TO_SCHOOL_WORK, State.SCHOOL_WORK, State.TO_MARKET_WORK, State.MARKET_WORK, State.TO_OFFICIAL_WORK, State.OFFICIAL_WORK, State.TO_CRAFT_WORK, State.CRAFT_WORK, State.RESEARCHING, State.TO_FACTORY, State.FACTORY_WORK]:
		cancel_current_action()


func _craft_speed_multiplier_internal() -> float:
	if not is_instance_valid(employment_workplace):
		return 1.0
	if str(employment_workplace.get_meta("building_type", "")) == "tarp_craft_tent":
		return 1.3
	return 1.0


func _service_states_for_internal(action: StringName) -> Array:
	match action:
		&"cook": return [State.TO_CANTEEN_WORK, State.CANTEEN_WORK]
		&"teacher": return [State.TO_SCHOOL_WORK, State.SCHOOL_WORK]
		&"seller": return [State.TO_MARKET_WORK, State.MARKET_WORK]
		&"official": return [State.TO_OFFICIAL_WORK, State.OFFICIAL_WORK]
		&"researcher": return [State.RESEARCHING]
		&"craftsman": return [State.TO_CRAFT_WORK, State.CRAFT_WORK]
	return []
