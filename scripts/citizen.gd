class_name Citizen
extends CharacterBody3D

signal resource_delivered(worker: Citizen, resource_type: String, amount: int)
signal excavation_cycle(worker: Citizen, site: Node3D, efficiency: float)
signal resource_ready(worker: Citizen, resource_type: String, amount: int)
signal tree_harvested(worker: Citizen, position_on_board: Vector3)
signal logs_delivered(worker: Citizen, sawmill_position: Vector3, amount: int)
signal forestry_tree_requested(worker: Citizen)
signal sawmill_boards_collected(courier: Citizen, sawmill_position: Vector3)
signal meal_finished(worker: Citizen)
signal canteen_delivery_finished(worker: Citizen, amount: int)
signal factory_cycle(worker: Citizen, factory: Node3D)
signal trade_delivery_finished(worker: Citizen)

const WALK_SPEED := 2.2
const WORK_DURATION := 1.4
const COURIER_WAIT_DURATION := 8.0
# One in-game hour at base speed (1440 game-min / 300 real-sec = 4.8 game-min/s).
# Both this timer and the clock advance with the same scaled delta, so the wait
# always spans exactly one in-game hour regardless of the simulation speed.
const WAIT_DURATION := 12.5
const EMPLOYMENT_PROCESS_DURATION := 12.5
const WAIT_RECHECK_INTERVAL := 1.0
const GRAVITY := 18.0
const AI_JUMP_VELOCITY := 7.6
const STUCK_TIME_BEFORE_JUMP := 0.75
const STUCK_TIME_BEFORE_REPATH := 1.5
const STUCK_TIME_BEFORE_SIDESTEP := 2.25
const SIDESTEP_DURATION := 0.65
const CONSTRUCTION_SLOT_SPACING := 0.42
const CONSTRUCTION_APPROACH_DISTANCE := 1.75
const NAVIGATION_TARGET_CLEARANCE := 0.48
const ROUTE_PROGRESS_EPSILON := 0.06
const ROUTE_RETRY_INTERVAL := 2.0

enum State { IDLE, WAITING, TO_TREE, CHOPPING, TO_SAWMILL, SAWING, TO_WAREHOUSE, CONSTRUCTING, EXCAVATING, COURIER_TO_WORKER, COURIER_TO_WAREHOUSE, WAITING_COURIER, TO_HOME, RESTING, TO_CANTEEN, EATING, TO_FOOD_PICKUP, TO_CANTEEN_DELIVERY, TO_CANTEEN_WORK, TO_SCHOOL, STUDYING, TO_SCHOOL_WORK, TO_FACTORY, FACTORY_WORK, TO_PARK, RELAXING, COURIER_TO_SAWMILL, TO_GATHER, GATHERING, TO_TRADE_PICKUP, TO_TRADE_DESTINATION, TO_EMPLOYMENT_CENTER, EMPLOYMENT_PROCESSING, CANTEEN_WORK, SCHOOL_WORK, TO_MARKET_WORK, MARKET_WORK }

enum EmploymentState { AUTO_RESERVE, EMPLOYED, UNEMPLOYED, PENDING_JOB, PENDING_UNEMPLOYMENT, MANUAL_COURIER }

var state := State.IDLE
var resource_type := "wood"
var gather_resource_type := ""
var gather_source_position := Vector3.ZERO
var source_position := Vector3.ZERO
var workplace_position := Vector3.ZERO
var warehouse_position := Vector3.ZERO
var task_timer := CitizenTaskState.new()
var wait_recheck := 0.0
# Injected by the simulation: work_scheduler(Citizen) -> bool tries to place the
# citizen on a job and reports success; leisure_scheduler(Citizen) -> bool routes
# them to a rest spot (park/pond/home) and reports whether somewhere was found.
var work_scheduler := Callable()
var leisure_scheduler := Callable()
var is_player_controlled := false
var is_hero := false
var construction_site: Node3D
var specialization := "builder"
var previous_specialization := ""
var manual_role := ""
var active_role := ""
var employment_state := EmploymentState.AUTO_RESERVE
var auto_mode_enabled := true
var permanent_role := ""
var pending_employment_role := ""
var employment_center_position := Vector3.INF
var satisfaction := 72.0
var satisfaction_tick := 0.0
var body_material: StandardMaterial3D
var skills := {}
var practiced_today: Dictionary = {}
var temp_training_role := ""

const DEVELOPED_SKILL_THRESHOLD := 0.15
const SKILL_GROWTH_PER_SECOND_WORK := 0.0001
const SKILL_GROWTH_PER_SCHOOL_DAY := 0.01
const SKILL_DECAY_RATE := 0.005
const SKILL_MIN_FLOOR := 0.10
var assigned_dig_site: Node3D
var uses_courier := false
var returning_to_excavation := false
var carried_amount := 0
var pending_resources: Dictionary = {}
var courier_target: Citizen
var courier_resource_type := ""
var courier_worker: Citizen
var home: Node3D
var hunger := 78.0
var buffs: Dictionary = {}
var debuffs: Dictionary = {}
var delivery_amount := 0
var canteen_position := Vector3.ZERO
var market_position := Vector3.ZERO
var construction_position := Vector3.ZERO
var pathfinder: Callable
var delivery_position_resolver: Callable
var movement_path: Array[Vector3] = []
var path_destination := Vector3.INF
var navigation_target_position := Vector3.INF
var path_allows_destination_house := false
var navigation_agent: NavigationAgent3D
var stuck_time := 0.0
var recovery_repath_done := false
var route_no_progress_time := 0.0
var route_best_distance := INF
var route_recovery_attempt := 0
var jump_cooldown := 0.0
var sidestep_time := 0.0
var sidestep_direction := Vector3.ZERO
var ground_contact_confirmed := false
var blocked_by_storage := false
var training_role := ""
var training_days_completed := 0
var school_position := Vector3.ZERO
var factory: Node3D
var factory_position := Vector3.ZERO
var park_position := Vector3.ZERO
var trade_source_position := Vector3.ZERO
var trade_destination_position := Vector3.ZERO
var simulation: Node
var goap_brain: CitizenGoapBrain
var idle_indicator: Label3D

signal employment_processing_finished(citizen: Citizen)

func _ready() -> void:
	skills = {
		"construction": randf_range(0.0, 0.1),
		"forestry": randf_range(0.0, 0.1),
		"farming": randf_range(0.0, 0.1),
		"excavation": randf_range(0.0, 0.1),
		"factory_worker": randf_range(0.0, 0.1),
		"engineer": randf_range(0.0, 0.1)
	}
	add_to_group("citizens")
	_setup_collision()
	_setup_navigation_agent()
	_setup_selector()
	_setup_visuals()

func _setup_navigation_agent() -> void:
	navigation_agent = NavigationAgent3D.new()
	navigation_agent.path_desired_distance = 0.28
	navigation_agent.target_desired_distance = 0.18
	navigation_agent.path_height_offset = 0.0
	# NPC-vs-NPC avoidance is disabled for now: citizens only collide with the
	# terrain and buildings, so a crowded cell can never deadlock movement.
	navigation_agent.avoidance_enabled = false
	add_child(navigation_agent)

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
	var body_collision := CollisionShape3D.new()
	var body_shape := CapsuleShape3D.new()
	body_shape.radius = 0.32
	body_shape.height = 1.75
	body_collision.shape = body_shape
	body_collision.position.y = 0.875
	add_child(body_collision)

func _setup_selector() -> void:
	var selector := Area3D.new()
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

func _setup_visuals() -> void:
	_setup_body_mesh()
	_setup_head_mesh()
	_setup_idle_indicator()

func _setup_idle_indicator() -> void:
	idle_indicator = Label3D.new()
	idle_indicator.position = Vector3(0.0, 2.05, 0.0)
	idle_indicator.text = "Reserve"
	idle_indicator.font_size = 32
	idle_indicator.outline_size = 6
	idle_indicator.modulate = Color("f0c45d")
	idle_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	idle_indicator.no_depth_test = true
	idle_indicator.visible = false
	add_child(idle_indicator)

func _setup_body_mesh() -> void:
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.25
	body_mesh.height = 1.15
	body.mesh = body_mesh
	body.position.y = 0.65
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = Color("5d92b2")
	body.material_override = body_material
	add_child(body)

func _setup_head_mesh() -> void:
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.5
	head.mesh = head_mesh
	head.position.y = 1.5
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color("b8d8c1")
	head.material_override = head_material
	add_child(head)

func assign_work(next_resource_type: String, source: Vector3, workplace: Vector3, warehouse: Vector3, next_uses_courier := false) -> void:
	if is_player_controlled:
		return
	resource_type = next_resource_type
	source_position = source
	workplace_position = workplace
	warehouse_position = warehouse
	uses_courier = next_uses_courier
	factory = null
	active_role = "forestry" if next_resource_type == "wood" else "farming"
	state = State.TO_TREE

func _physics_process(delta: float) -> void:
	if is_player_controlled:
		return
	if goap_brain != null:
		goap_brain.tick(delta)
	_apply_gravity(delta)
	_update_effects(delta)
	_update_satisfaction(delta)
	match state:
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
		State.TO_SCHOOL_WORK:
			_process_school_work(delta)
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
	if idle_indicator != null:
		_update_idle_indicator()

func _process_to_source(delta: float) -> void:
	if _move_to(source_position, delta):
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
		state = State.IDLE
		resource_delivered.emit(self, resource_type, carried_amount)

func _process_courier_wait(delta: float) -> void:
	if task_timer.advance(delta):
		pending_resources[resource_type] = maxi(0, int(pending_resources.get(resource_type, 0)) - carried_amount)
		state = State.TO_WAREHOUSE

func _process_construction(delta: float) -> void:
	if is_instance_valid(construction_site):
		_move_to(construction_position, delta)
	else:
		state = State.IDLE
		construction_site = null

func _process_excavation(delta: float) -> void:
	if not is_instance_valid(assigned_dig_site):
		idle()
		return
	if not _move_to(assigned_dig_site.global_position, delta):
		return
	if task_timer.remaining <= 0.0:
		_start_task(WORK_DURATION / get_efficiency("excavation"))
	if _work(delta):
		excavation_cycle.emit(self, assigned_dig_site, get_efficiency("excavation"))
		task_timer.remaining = 0.0

func _process_courier_pickup(delta: float) -> void:
	if is_instance_valid(courier_target) and _move_to(courier_target.global_position, delta):
		var cargo := courier_target.take_pending_resource()
		courier_resource_type = cargo.get("type", "")
		carried_amount = int(cargo.get("amount", 0))
		state = State.COURIER_TO_WAREHOUSE if carried_amount > 0 else State.IDLE

func _process_sawmill_pickup(delta: float) -> void:
	if _move_to(workplace_position, delta):
		sawmill_boards_collected.emit(self, workplace_position)

func _process_courier_delivery(delta: float) -> void:
	_refresh_warehouse_position()
	if _move_to(warehouse_position, delta):
		state = State.IDLE
		resource_delivered.emit(self, courier_resource_type, carried_amount)

func _process_go_home(delta: float) -> void:
	if not is_instance_valid(home):
		# The home was demolished mid-walk: drop back to IDLE (with its indicator)
		# instead of silently standing in TO_HOME forever.
		idle()
		return
	var home_entrance: Vector3 = home.get_meta("entrance_position", home.global_position)
	if _move_to(home_entrance, delta, true):
		state = State.RESTING

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
		meal_finished.emit(self)

func _process_food_pickup(delta: float) -> void:
	_refresh_warehouse_position()
	if _move_to(warehouse_position, delta):
		state = State.TO_CANTEEN_DELIVERY

func _process_canteen_delivery(delta: float) -> void:
	if _move_to(canteen_position, delta):
		state = State.IDLE
		canteen_delivery_finished.emit(self, delivery_amount)
		delivery_amount = 0

func _process_canteen_work(delta: float) -> void:
	if _move_to(canteen_position, delta):
		state = State.CANTEEN_WORK

func _process_go_to_school(delta: float) -> void:
	if _move_to(school_position, delta):
		state = State.STUDYING
		active_role = "training"

func _process_school_work(delta: float) -> void:
	if _move_to(school_position, delta):
		state = State.SCHOOL_WORK

func _process_market_work_arrival(delta: float) -> void:
	if _move_to(market_position, delta):
		state = State.MARKET_WORK

func _process_to_factory(delta: float) -> void:
	if not is_instance_valid(factory):
		idle()
		return
	if _move_to(factory_position, delta):
		state = State.FACTORY_WORK
		_start_task(WORK_DURATION / get_efficiency(active_role))

func _process_factory_work(delta: float) -> void:
	if not is_instance_valid(factory):
		idle()
		return
	if _work(delta):
		factory_cycle.emit(self, factory)
		_start_task(WORK_DURATION / get_efficiency(active_role))

func _process_go_to_park(delta: float) -> void:
	if _move_to(park_position, delta):
		state = State.RELAXING
		_start_task(4.0)

func _process_relaxing(delta: float) -> void:
	var finished := task_timer.advance(delta)
	satisfaction = minf(get_satisfaction_cap(), satisfaction + delta * 5.0)
	if finished:
		state = State.IDLE

func _process_waiting(delta: float) -> void:
	# While waiting, keep probing for work so the citizen jumps back the moment a
	# job frees up. The recheck is throttled so a genuinely idle settlement does
	# not thrash the scheduler every frame.
	wait_recheck -= delta
	if wait_recheck <= 0.0:
		wait_recheck = WAIT_RECHECK_INTERVAL
		if work_scheduler.is_valid() and bool(work_scheduler.call(self)):
			return
	if task_timer.advance(delta):
		# The full waiting window elapsed with no work. Head to a rest spot.
		var rested := leisure_scheduler.is_valid() and bool(leisure_scheduler.call(self))
		if not rested:
			# Nowhere to rest at all (no park/campfire/pond/home): stand down with
			# the visible IDLE indicator; the worker poll re-enters the waiting
			# window or assigns work as soon as either becomes possible.
			idle()


func begin_employment_processing(center_position: Vector3, next_pending_role := "") -> void:
	if is_player_controlled or center_position == Vector3.INF:
		return
	employment_center_position = center_position
	pending_employment_role = next_pending_role
	employment_state = EmploymentState.PENDING_JOB if not next_pending_role.is_empty() else EmploymentState.PENDING_UNEMPLOYMENT
	active_role = ""
	state = State.TO_EMPLOYMENT_CENTER


func queue_employment_processing(next_pending_role := "") -> void:
	pending_employment_role = next_pending_role
	employment_state = EmploymentState.PENDING_JOB if not next_pending_role.is_empty() else EmploymentState.PENDING_UNEMPLOYMENT
	active_role = ""
	state = State.IDLE


func cancel_employment_processing() -> void:
	if state not in [State.TO_EMPLOYMENT_CENTER, State.EMPLOYMENT_PROCESSING]:
		return
	pending_employment_role = ""
	employment_state = EmploymentState.AUTO_RESERVE
	state = State.IDLE


func _process_to_employment_center(delta: float) -> void:
	if employment_center_position == Vector3.INF:
		state = State.IDLE
		return
	if _move_to(employment_center_position, delta):
		state = State.EMPLOYMENT_PROCESSING
		_start_task(EMPLOYMENT_PROCESS_DURATION)


func _process_employment_processing(delta: float) -> void:
	if _work(delta):
		employment_processing_finished.emit(self)


func finish_employment_processing() -> void:
	if employment_state == EmploymentState.PENDING_JOB:
		permanent_role = pending_employment_role
		employment_state = EmploymentState.EMPLOYED
	else:
		permanent_role = ""
		auto_mode_enabled = false
		employment_state = EmploymentState.UNEMPLOYED
	pending_employment_role = ""
	state = State.IDLE


func has_active_delivery() -> bool:
	return state in [State.COURIER_TO_WORKER, State.COURIER_TO_WAREHOUSE, State.COURIER_TO_SAWMILL, State.TO_FOOD_PICKUP, State.TO_CANTEEN_DELIVERY] or carried_amount > 0

func _move_to(destination: Vector3, delta: float, may_enter_destination_house := false) -> bool:
	if navigation_agent != null and navigation_agent.get_navigation_map().is_valid():
		if path_destination.distance_to(destination) > 0.08:
			_reset_route(destination)
			navigation_target_position = _accessible_navigation_target(destination, 0)
			navigation_agent.target_position = navigation_target_position
		for ignored_start_position in range(2):
			var next_path_position := navigation_agent.get_next_path_position()
			if navigation_agent.is_navigation_finished():
				if _has_arrived_at_navigation_target():
					return true
				_recover_idle_route(delta)
				return false
			var path_offset := next_path_position - global_position
			path_offset.y = 0.0
			if path_offset.length() > 0.08:
				return _move_directly_to(next_path_position, delta)
		_recover_idle_route(delta)
		return false
	if path_destination.distance_to(destination) > 0.08 or path_allows_destination_house != may_enter_destination_house:
		path_destination = destination
		path_allows_destination_house = may_enter_destination_house
		movement_path = pathfinder.call(global_position, destination, may_enter_destination_house) if pathfinder.is_valid() else [destination]
	while not movement_path.is_empty():
		var waypoint: Vector3 = movement_path.front()
		var waypoint_offset := waypoint - global_position
		waypoint_offset.y = 0.0
		if waypoint_offset.length() > 0.08:
			return _move_directly_to(waypoint, delta)
		movement_path.pop_front()
	return true

func _move_directly_to(destination: Vector3, delta: float) -> bool:
	var offset := destination - global_position
	offset.y = 0.0
	if offset.length() <= 0.08:
		global_position = Vector3(destination.x, global_position.y, destination.z)
		return true
	var direction := offset.normalized()
	if sidestep_time > 0.0:
		sidestep_time = maxf(0.0, sidestep_time - delta)
		direction = (direction * 0.35 + sidestep_direction).normalized()
	var desired_velocity := direction * get_walk_speed()
	velocity.x = desired_velocity.x
	velocity.z = desired_velocity.z
	jump_cooldown = maxf(0.0, jump_cooldown - delta)
	var position_before_move := global_position
	var distance_before_move := offset.length()
	move_and_slide()
	var horizontal_progress := Vector2(global_position.x - position_before_move.x, global_position.z - position_before_move.z).length()
	var distance_after_move := Vector2(destination.x - global_position.x, destination.z - global_position.z).length()
	_update_route_progress(distance_before_move, distance_after_move, delta, direction)
	if is_on_floor() and horizontal_progress < get_walk_speed() * delta * 0.15:
		stuck_time += delta
		if jump_cooldown <= 0.0:
			if stuck_time >= STUCK_TIME_BEFORE_SIDESTEP:
				_start_sidestep(direction)
			elif stuck_time >= STUCK_TIME_BEFORE_REPATH and not recovery_repath_done:
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
	if navigation_agent != null:
		route_recovery_attempt += 1
		navigation_target_position = _accessible_navigation_target(path_destination, route_recovery_attempt)
		navigation_agent.target_position = navigation_target_position
	recovery_repath_done = true

func _accessible_navigation_target(destination: Vector3, attempt: int) -> Vector3:
	var navigation_map := navigation_agent.get_navigation_map()
	var closest_point := NavigationServer3D.map_get_closest_point(navigation_map, destination)
	var blocked_offset := closest_point - destination
	blocked_offset.y = 0.0
	if blocked_offset.length() <= 0.05 and attempt == 0:
		return closest_point
	# Keep the capsule away from the exact navmesh boundary, which normally
	# coincides with a building wall or a tree cell.
	var outward := blocked_offset.normalized() if blocked_offset.length() > 0.05 else (global_position - destination).normalized()
	if outward.is_zero_approx():
		outward = Vector3.FORWARD
	var candidates: Array[Vector3] = []
	for direction in [outward, Vector3(-outward.z, 0.0, outward.x), Vector3(outward.z, 0.0, -outward.x), -outward]:
		var candidate := NavigationServer3D.map_get_closest_point(navigation_map, closest_point + direction * NAVIGATION_TARGET_CLEARANCE)
		if not NavigationServer3D.map_get_path(navigation_map, global_position, candidate, true).is_empty():
			candidates.append(candidate)
	if candidates.is_empty():
		return closest_point
	return candidates[attempt % candidates.size()]

func _has_arrived_at_navigation_target() -> bool:
	var offset := navigation_target_position - global_position
	offset.y = 0.0
	return offset.length() <= maxf(0.45, navigation_agent.target_desired_distance + 0.2)

func _reset_route(destination: Vector3) -> void:
	path_destination = destination
	route_no_progress_time = 0.0
	route_best_distance = INF
	route_recovery_attempt = 0
	recovery_repath_done = false

func _update_route_progress(distance_before: float, distance_after: float, delta: float, direction: Vector3) -> void:
	if distance_after + ROUTE_PROGRESS_EPSILON < minf(distance_before, route_best_distance):
		route_best_distance = distance_after
		route_no_progress_time = 0.0
		return
	route_best_distance = minf(route_best_distance, distance_after)
	route_no_progress_time += delta
	if route_no_progress_time < ROUTE_RETRY_INTERVAL:
		return
	route_no_progress_time = 0.0
	if route_recovery_attempt % 2 == 0:
		_force_repath()
	else:
		route_recovery_attempt += 1
		_start_sidestep(direction)

func _recover_idle_route(delta: float) -> void:
	var direction := navigation_target_position - global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	var distance := direction.length()
	_update_route_progress(distance, distance, delta, direction.normalized())

func _start_sidestep(forward: Vector3) -> void:
	var side_sign := -1.0 if get_instance_id() % 2 == 0 else 1.0
	sidestep_direction = Vector3(-forward.z, 0.0, forward.x) * side_sign
	sidestep_time = SIDESTEP_DURATION
	_force_repath()
	stuck_time = 0.0
	recovery_repath_done = false

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
	return task_timer.advance(delta)


func _start_task(duration: float) -> void:
	task_timer.start(duration)

func set_player_controlled(controlled: bool) -> void:
	is_player_controlled = controlled
	if idle_indicator != null:
		idle_indicator.visible = false
	if controlled:
		state = State.IDLE
		construction_site = null
		factory = null
		active_role = ""
		movement_path.clear()
		path_destination = Vector3.INF

func set_hero(hero: bool) -> void:
	is_hero = hero
	if hero:
		add_to_group("hero")
		if body_material != null:
			body_material.albedo_color = Color("e6c857")

func assign_construction(site: Node3D) -> void:
	if is_player_controlled:
		return
	construction_site = site
	factory = null
	construction_position = _work_position_for(site)
	movement_path.clear()
	active_role = "construction"
	state = State.CONSTRUCTING

func assign_demolition(building: Node3D) -> void:
	if is_player_controlled:
		return
	construction_site = building
	factory = null
	construction_position = _work_position_for(building)
	movement_path.clear()
	active_role = "demolition"
	state = State.CONSTRUCTING

func finish_construction(site: Node3D) -> void:
	if construction_site != site:
		return
	construction_site = null
	active_role = ""
	movement_path.clear()
	path_destination = Vector3.INF
	navigation_target_position = Vector3.INF
	state = State.IDLE
	request_goap_decision()

func assign_excavation(site: Node3D) -> void:
	if is_player_controlled:
		return
	assigned_dig_site = site
	factory = null
	active_role = "excavation"
	state = State.EXCAVATING

func deliver_excavation(next_resource_type: String, warehouse: Vector3) -> void:
	resource_type = next_resource_type
	warehouse_position = warehouse
	carried_amount = 1
	returning_to_excavation = true
	state = State.TO_WAREHOUSE

func storage_delivery_result(accepted: bool) -> void:
	if accepted:
		blocked_by_storage = false
		if specialization == "courier":
			state = State.IDLE
			return
		if returning_to_excavation:
			state = State.EXCAVATING
		elif active_role == "forestry":
			forestry_tree_requested.emit(self)
		elif active_role.begins_with("gather_"):
			state = State.IDLE
			request_goap_decision()
		else:
			state = State.TO_TREE
		returning_to_excavation = false
	else:
		blocked_by_storage = true
		go_home()

func register_pending_resource(next_resource_type: String, amount: int) -> void:
	pending_resources[next_resource_type] = int(pending_resources.get(next_resource_type, 0)) + amount

func has_pending_resource() -> bool:
	for amount in pending_resources.values():
		if amount > 0:
			return true
	return false

func take_pending_resource() -> Dictionary:
	for pending_type in pending_resources.keys():
		var amount: int = pending_resources[pending_type]
		if amount > 0:
			pending_resources[pending_type] = 0
			if state == State.WAITING_COURIER:
				state = State.TO_TREE
			return {"type": pending_type, "amount": amount}
	return {}

func assign_courier_pickup(worker: Citizen, warehouse: Vector3) -> void:
	courier_target = worker
	warehouse_position = warehouse
	active_role = ""
	factory = null
	state = State.COURIER_TO_WORKER

func assign_sawmill_pickup(sawmill: Vector3, warehouse: Vector3) -> void:
	workplace_position = sawmill
	warehouse_position = warehouse
	active_role = ""
	factory = null
	state = State.COURIER_TO_SAWMILL

func collect_sawmill_boards(amount: int) -> void:
	carried_amount = amount
	courier_resource_type = "boards"
	state = State.COURIER_TO_WAREHOUSE if amount > 0 else State.IDLE

func deliver_sawmill_boards(amount: int) -> void:
	resource_type = "boards"
	carried_amount = amount
	state = State.TO_WAREHOUSE

func assign_next_forestry_tree(tree_position: Vector3) -> void:
	source_position = tree_position
	state = State.TO_TREE

func assign_canteen_work(next_canteen_position: Vector3) -> void:
	if not is_player_controlled:
		canteen_position = next_canteen_position
		active_role = "cooking"
		factory = null
		state = State.TO_CANTEEN_WORK

func assign_teacher_work(next_school_position: Vector3) -> void:
	if not is_player_controlled:
		school_position = next_school_position
		active_role = "teaching"
		factory = null
		state = State.TO_SCHOOL_WORK

func assign_seller_work(next_market_position: Vector3) -> void:
	if not is_player_controlled:
		market_position = next_market_position
		active_role = "selling"
		factory = null
		state = State.TO_MARKET_WORK

func assign_factory_work(next_factory: Node3D, role: String) -> void:
	if not is_player_controlled:
		factory = next_factory
		factory_position = next_factory.get_meta("service_position", next_factory.global_position)
		active_role = role
		state = State.TO_FACTORY

func go_to_park(next_park_position: Vector3) -> void:
	if not is_player_controlled:
		park_position = next_park_position
		active_role = "relaxing"
		factory = null
		state = State.TO_PARK

func deliver_trade(source: Vector3, destination: Vector3) -> void:
	if is_player_controlled:
		return
	trade_source_position = source
	trade_destination_position = destination
	active_role = "trade"
	factory = null
	state = State.TO_TRADE_PICKUP

func start_training(next_role: String, next_school_position: Vector3) -> void:
	training_role = next_role
	training_days_completed = 0
	school_position = next_school_position

func attend_school(school_pos: Vector3, role_to_train: String) -> void:
	if not is_player_controlled:
		school_position = school_pos
		temp_training_role = role_to_train
		factory = null
		state = State.TO_SCHOOL

func finish_school_day(teacher_present := true) -> void:
	if state != State.STUDYING:
		return
	
	var trained_role := training_role
	if trained_role.is_empty():
		trained_role = temp_training_role
		
	if not trained_role.is_empty() and teacher_present:
		var current_val := float(skills.get(trained_role, 0.0))
		skills[trained_role] = minf(1.0, current_val + SKILL_GROWTH_PER_SCHOOL_DAY)
		practiced_today[trained_role] = true
		
		if not training_role.is_empty():
			training_days_completed += 1
			if training_days_completed >= 10:
				specialization = "builder" if training_role == "construction" else training_role
				manual_role = ""
				setup_specialization(specialization)
				training_role = ""
				training_days_completed = 0
				
	temp_training_role = ""
	state = State.IDLE

func apply_daily_decay() -> void:
	for skill_name in skills.keys():
		if not practiced_today.get(skill_name, false):
			skills[skill_name] = maxf(SKILL_MIN_FLOOR, float(skills.get(skill_name, 0.0)) - SKILL_DECAY_RATE)
	practiced_today.clear()

func is_building_site(site: Node3D) -> bool:
	return not is_player_controlled and state == State.CONSTRUCTING and construction_site == site and global_position.distance_to(construction_position) <= 0.7

func setup_navigation(next_pathfinder: Callable, next_delivery_position_resolver := Callable()) -> void:
	pathfinder = next_pathfinder
	delivery_position_resolver = next_delivery_position_resolver

func setup_scheduler(next_work_scheduler: Callable, next_leisure_scheduler: Callable) -> void:
	work_scheduler = next_work_scheduler
	leisure_scheduler = next_leisure_scheduler

func _refresh_warehouse_position() -> void:
	if not delivery_position_resolver.is_valid():
		return
	var resolved: Vector3 = delivery_position_resolver.call(global_position)
	if resolved != Vector3.INF and warehouse_position.distance_to(resolved) > 0.08:
		warehouse_position = resolved

func setup_goap(next_simulation: Node, worker_index: int) -> void:
	simulation = next_simulation
	goap_brain = CitizenGoapBrain.new()
	add_child(goap_brain)
	goap_brain.setup(self, simulation, worker_index)

func request_goap_decision() -> void:
	if goap_brain != null:
		goap_brain.request_decision()

func request_goap_meal() -> void:
	if goap_brain != null:
		goap_brain.request_meal()

func finish_goap_meal() -> void:
	if goap_brain != null:
		goap_brain.finish_meal_request()

func _work_position_for(site: Node3D) -> Vector3:
	var site_position := site.global_position
	var footprint: Vector2i = site.get_meta("footprint", Vector2i(3, 3))
	var offset := global_position - site_position
	offset.y = 0.0
	var slot := float(int(get_instance_id() % 3) - 1) * CONSTRUCTION_SLOT_SPACING
	if absf(offset.x) > absf(offset.z):
		var x_distance := footprint.x * 0.5 + CONSTRUCTION_APPROACH_DISTANCE
		return site_position + Vector3(x_distance if offset.x >= 0.0 else -x_distance, 0.0, slot)
	var z_distance := footprint.y * 0.5 + CONSTRUCTION_APPROACH_DISTANCE
	return site_position + Vector3(slot, 0.0, z_distance if offset.z >= 0.0 else -z_distance)

func get_core_skill_for_role(role: String) -> String:
	match role:
		"construction", "demolition":
			return "construction"
		"forestry", "gather_branches", "gather_logs":
			return "forestry"
		"farming", "gather_water", "gather_dew", "gather_food":
			return "farming"
		"excavation":
			return "excavation"
		"factory_work", "factory_worker":
			return "factory_worker"
		"engineering", "engineer":
			return "engineer"
		"courier":
			return "courier"
		"cooking", "cook":
			return "cook"
		"teaching", "teacher":
			return "teacher"
		"selling", "seller":
			return "seller"
		_:
			return ""

func has_perk(skill_name: String) -> bool:
	return skills.get(skill_name, 0.0) >= 1.0

func get_walk_speed() -> float:
	if has_perk("construction"):
		return WALK_SPEED * 1.15
	return WALK_SPEED

func setup_specialization(next_specialization: String) -> void:
	specialization = next_specialization
	body_material.albedo_color = Color("e6c857") if is_hero else CitizenRoleProfile.color_for(specialization)

func get_efficiency(role: String) -> float:
	var core_skill := get_core_skill_for_role(role)
	var S := float(skills.get(core_skill, 0.0)) if not core_skill.is_empty() else 0.5
	
	# Determine era index (0 to 5)
	var era_index := 0
	if simulation != null and simulation.settlement != null:
		era_index = int(simulation.settlement.era)
	
	# Max penalty is era-dependent
	var max_penalty := 0.15 + 0.11 * float(era_index)
	var skill_efficiency_factor := lerpf(1.0 - max_penalty, 1.30, S)
	
	# Farmer perk bonus
	if role == "farming" and has_perk("farming"):
		skill_efficiency_factor += 0.15
		
	var satisfaction_factor := lerpf(0.45, 1.0, satisfaction / 100.0)
	var meal_bonus := 0.15 if buffs.has("canteen_meal") else 0.0
	return skill_efficiency_factor * satisfaction_factor * (1.0 + meal_bonus)

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
	state = State.IDLE
	active_role = ""
	construction_site = null
	assigned_dig_site = null
	factory = null

func begin_waiting() -> void:
	# Enter the pre-rest waiting window. Idempotent: repeated calls (e.g. a retry
	# that still fails to find a free work node) preserve the running countdown so
	# the citizen reliably progresses toward rest instead of waiting forever.
	if is_player_controlled or state == State.WAITING:
		return
	state = State.WAITING
	active_role = ""
	construction_site = null
	assigned_dig_site = null
	factory = null
	task_timer.start(WAIT_DURATION)
	wait_recheck = WAIT_RECHECK_INTERVAL

func _update_idle_indicator() -> void:
	if is_player_controlled:
		idle_indicator.visible = false
		return
	idle_indicator.visible = true
	match employment_state:
		EmploymentState.EMPLOYED:
			idle_indicator.text = "Employed: %s" % permanent_role.replace("_", " ")
			idle_indicator.modulate = Color("76c893")
		EmploymentState.PENDING_JOB:
			idle_indicator.text = "Hiring: %s" % pending_employment_role.replace("_", " ")
			idle_indicator.modulate = Color("7bb7e8")
		EmploymentState.PENDING_UNEMPLOYMENT:
			idle_indicator.text = "Registering unemployed"
			idle_indicator.modulate = Color("f0873d")
		EmploymentState.UNEMPLOYED:
			idle_indicator.text = "Unemployed"
			idle_indicator.modulate = Color("c8a96b")
		EmploymentState.MANUAL_COURIER:
			idle_indicator.text = "Courier (manual)"
			idle_indicator.modulate = Color("d18fc1")
		_:
			idle_indicator.text = "Reserve: courier" if specialization == "courier" else "Reserve"
			idle_indicator.modulate = Color("f0c45d")

func assign_home(next_home: Node3D) -> void:
	home = next_home
	if is_instance_valid(home) and home.has_meta("is_tent"):
		add_debuff("tent", 15.0)
	else:
		remove_debuff("tent")

func go_home() -> void:
	if not is_player_controlled and is_instance_valid(home):
		factory = null
		state = State.TO_HOME

func go_to_canteen(next_canteen_position: Vector3) -> void:
	if not is_player_controlled:
		canteen_position = next_canteen_position
		active_role = ""
		factory = null
		state = State.TO_CANTEEN

func deliver_food_to_canteen(warehouse: Vector3, next_canteen_position: Vector3, amount: int) -> void:
	if not is_player_controlled:
		warehouse_position = warehouse
		canteen_position = next_canteen_position
		delivery_amount = amount
		active_role = ""
		factory = null
		state = State.TO_FOOD_PICKUP

func add_debuff(debuff_id: String, value: float) -> void:
	debuffs[debuff_id] = value

func remove_debuff(debuff_id: String) -> void:
	debuffs.erase(debuff_id)

func get_satisfaction_cap() -> float:
	var cap := 100.0
	for penalty in debuffs.values():
		cap -= float(penalty)
	return maxf(10.0, cap)

func receive_meal(served: bool) -> void:
	if served:
		hunger = minf(100.0, hunger + 35.0)
		satisfaction = minf(get_satisfaction_cap(), satisfaction + 8.0)
		buffs["canteen_meal"] = 8.0
	else:
		hunger = maxf(0.0, hunger - 18.0)
		satisfaction = maxf(0.0, satisfaction - 12.0)

func _update_effects(delta: float) -> void:
	for buff_id in buffs.keys():
		var time_left := float(buffs[buff_id]) - delta
		if time_left <= 0.0:
			buffs.erase(buff_id)
		else:
			buffs[buff_id] = time_left

func is_available_for_schedule() -> bool:
	return not is_player_controlled and state != State.TO_CANTEEN and state != State.EATING and state != State.TO_HOME and state != State.RESTING and state != State.STUDYING and state != State.TO_PARK and state != State.RELAXING

func _update_satisfaction(delta: float) -> void:
	satisfaction_tick += delta
	if satisfaction_tick < 1.0:
		return
	if active_role.is_empty():
		satisfaction = minf(get_satisfaction_cap(), satisfaction + 1.2 * satisfaction_tick)
		satisfaction_tick = 0.0
		return
		
	# Satisfaction rules based on job matching and developed skills
	var core_pref_role := get_core_skill_for_role(preferred_role())
	var core_active_role := get_core_skill_for_role(active_role)
	var change := 0.0
	
	if not core_active_role.is_empty() and core_active_role == core_pref_role:
		change = 1.2
	else:
		var has_developed := false
		for val in skills.values():
			if float(val) > DEVELOPED_SKILL_THRESHOLD:
				has_developed = true
				break
		if has_developed:
			change = -2.0
		else:
			change = 0.0
			
	satisfaction = clampf(satisfaction + change * satisfaction_tick, 0.0, get_satisfaction_cap())
	
	# Skill growth with mentor synergy
	var core_skill := get_core_skill_for_role(active_role)
	if not core_skill.is_empty():
		var growth_multiplier := 1.0
		if simulation != null:
			for other in simulation.citizens:
				if other != self and not other.is_player_controlled:
					var other_core: String = other.get_core_skill_for_role(other.active_role)
					if other_core == core_skill and float(other.skills.get(core_skill, 0.0)) >= 0.80:
						if global_position.distance_to(other.global_position) <= 5.0:
							growth_multiplier = 1.5
							break
							
		var current_val = float(skills.get(core_skill, 0.0))
		skills[core_skill] = minf(1.0, current_val + SKILL_GROWTH_PER_SECOND_WORK * growth_multiplier * satisfaction_tick)
		practiced_today[core_skill] = true
		
	satisfaction_tick = 0.0


func assign_gathering(res_type: String, source_pos: Vector3, delivery_pos: Vector3) -> void:
	if is_player_controlled:
		return
	gather_resource_type = res_type
	gather_source_position = source_pos
	warehouse_position = delivery_pos
	active_role = "gather_" + res_type
	state = State.TO_GATHER

func _process_to_gather(delta: float) -> void:
	if _move_to(gather_source_position, delta):
		state = State.GATHERING
		_start_task(2.0 / get_efficiency("forestry" if gather_resource_type in ["branches", "logs"] else "farming"))

func _process_gathering(delta: float) -> void:
	if _work(delta):
		carried_amount = 3 if gather_resource_type == "water" and active_role == "gather_water" else 1
		resource_type = gather_resource_type
		if resource_type == "logs":
			tree_harvested.emit(self, gather_source_position)
			if has_perk("forestry") and randf() < 0.10:
				carried_amount *= 2
				if simulation != null:
					simulation._update_interface("Lumberjack Master: Forester gathered 2 logs!")
		state = State.TO_WAREHOUSE

func _process_trade_pickup(delta: float) -> void:
	if _move_to(trade_source_position, delta):
		state = State.TO_TRADE_DESTINATION

func _process_trade_destination(delta: float) -> void:
	if _move_to(trade_destination_position, delta):
		state = State.IDLE
		trade_delivery_finished.emit(self)
