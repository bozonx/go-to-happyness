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

const WALK_SPEED := 2.2
const WORK_DURATION := 1.4
const COURIER_WAIT_DURATION := 8.0
const GRAVITY := 18.0
const AI_JUMP_VELOCITY := 7.6
const STUCK_TIME_BEFORE_JUMP := 0.75
const STUCK_TIME_BEFORE_REPATH := 1.5
const STUCK_TIME_BEFORE_SIDESTEP := 2.25
const SIDESTEP_DURATION := 0.65
const CONSTRUCTION_SLOT_SPACING := 0.42
const CONSTRUCTION_APPROACH_DISTANCE := 1.75
const NAVIGATION_TARGET_CLEARANCE := 0.48

enum State { IDLE, TO_TREE, CHOPPING, TO_SAWMILL, SAWING, TO_WAREHOUSE, CONSTRUCTING, EXCAVATING, COURIER_TO_WORKER, COURIER_TO_WAREHOUSE, WAITING_COURIER, TO_HOME, RESTING, TO_CANTEEN, EATING, TO_FOOD_PICKUP, TO_CANTEEN_DELIVERY, TO_CANTEEN_WORK, TO_SCHOOL, STUDYING, TO_SCHOOL_WORK, TO_FACTORY, FACTORY_WORK, TO_PARK, RELAXING, COURIER_TO_SAWMILL }

var state := State.IDLE
var resource_type := "wood"
var source_position := Vector3.ZERO
var workplace_position := Vector3.ZERO
var warehouse_position := Vector3.ZERO
var task_timer := CitizenTaskState.new()
var is_player_controlled := false
var construction_site: Node3D
var specialization := "builder"
var manual_role := ""
var active_role := ""
var satisfaction := 72.0
var satisfaction_tick := 0.0
var body_material: StandardMaterial3D
var skills := {"construction": 1.2, "forestry": 1.2, "farming": 1.2, "excavation": 1.2}
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
var construction_position := Vector3.ZERO
var pathfinder: Callable
var movement_path: Array[Vector3] = []
var path_destination := Vector3.INF
var navigation_target_position := Vector3.INF
var path_allows_destination_house := false
var navigation_agent: NavigationAgent3D
var stuck_time := 0.0
var recovery_repath_done := false
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
var goap_brain: CitizenGoapBrain

func _ready() -> void:
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
			logs_delivered.emit(self, workplace_position, 1)
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
	if _move_to(warehouse_position, delta):
		state = State.IDLE
		resource_delivered.emit(self, courier_resource_type, carried_amount)

func _process_go_home(delta: float) -> void:
	if not is_instance_valid(home):
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
	if _move_to(warehouse_position, delta):
		state = State.TO_CANTEEN_DELIVERY

func _process_canteen_delivery(delta: float) -> void:
	if _move_to(canteen_position, delta):
		state = State.IDLE
		canteen_delivery_finished.emit(self, delivery_amount)
		delivery_amount = 0

func _process_canteen_work(delta: float) -> void:
	if _move_to(canteen_position, delta):
		state = State.IDLE

func _process_go_to_school(delta: float) -> void:
	if _move_to(school_position, delta):
		state = State.STUDYING
		active_role = "training"

func _process_school_work(delta: float) -> void:
	if _move_to(school_position, delta):
		state = State.IDLE

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

func _move_to(destination: Vector3, delta: float, may_enter_destination_house := false) -> bool:
	if navigation_agent != null and navigation_agent.get_navigation_map().is_valid():
		if path_destination.distance_to(destination) > 0.08:
			path_destination = destination
			navigation_target_position = _accessible_navigation_target(destination)
			navigation_agent.target_position = navigation_target_position
		for ignored_start_position in range(2):
			var next_path_position := navigation_agent.get_next_path_position()
			if navigation_agent.is_navigation_finished():
				return true
			var path_offset := next_path_position - global_position
			path_offset.y = 0.0
			if path_offset.length() > 0.08:
				return _move_directly_to(next_path_position, delta)
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
	var desired_velocity := direction * WALK_SPEED
	velocity.x = desired_velocity.x
	velocity.z = desired_velocity.z
	jump_cooldown = maxf(0.0, jump_cooldown - delta)
	var position_before_move := global_position
	move_and_slide()
	var horizontal_progress := Vector2(global_position.x - position_before_move.x, global_position.z - position_before_move.z).length()
	if is_on_floor() and horizontal_progress < WALK_SPEED * delta * 0.15:
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
		navigation_target_position = _accessible_navigation_target(path_destination)
		navigation_agent.target_position = navigation_target_position
	recovery_repath_done = true

func _accessible_navigation_target(destination: Vector3) -> Vector3:
	var navigation_map := navigation_agent.get_navigation_map()
	var closest_point := NavigationServer3D.map_get_closest_point(navigation_map, destination)
	var blocked_offset := closest_point - destination
	blocked_offset.y = 0.0
	if blocked_offset.length() <= 0.05:
		return closest_point
	# Keep the capsule away from the exact navmesh boundary, which normally
	# coincides with a building wall or a tree cell.
	var cleared_target := closest_point + blocked_offset.normalized() * NAVIGATION_TARGET_CLEARANCE
	return NavigationServer3D.map_get_closest_point(navigation_map, cleared_target)

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
	if state == State.IDLE or state == State.RESTING:
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
	if controlled:
		state = State.IDLE
		construction_site = null
		factory = null
		active_role = ""
		movement_path.clear()
		path_destination = Vector3.INF

func assign_construction(site: Node3D) -> void:
	if is_player_controlled:
		return
	construction_site = site
	factory = null
	construction_position = _work_position_for(site)
	movement_path.clear()
	active_role = "construction"
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

func start_training(next_role: String, next_school_position: Vector3) -> void:
	training_role = next_role
	training_days_completed = 0
	school_position = next_school_position

func attend_school() -> void:
	if not is_player_controlled and not training_role.is_empty() and training_days_completed < 10:
		factory = null
		state = State.TO_SCHOOL

func finish_school_day() -> void:
	if state != State.STUDYING:
		return
	training_days_completed += 1
	skills[training_role] = minf(5.0, float(skills.get(training_role, 1.0)) + 0.4)
	if training_days_completed >= 10:
		var final_skill := float(skills[training_role])
		specialization = "builder" if training_role == "construction" else training_role
		manual_role = ""
		setup_specialization(specialization)
		skills[training_role] = maxf(final_skill, float(skills[training_role]))
		training_role = ""
	state = State.IDLE

func is_building_site(site: Node3D) -> bool:
	return not is_player_controlled and state == State.CONSTRUCTING and construction_site == site and global_position.distance_to(construction_position) <= 0.7

func setup_navigation(next_pathfinder: Callable) -> void:
	pathfinder = next_pathfinder

func setup_goap(simulation: Node, worker_index: int) -> void:
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

func setup_specialization(next_specialization: String) -> void:
	specialization = next_specialization
	skills[preferred_role()] = 4.0
	body_material.albedo_color = CitizenRoleProfile.color_for(specialization)

func get_efficiency(role: String) -> float:
	var skill_value: float = skills.get(role, 1.0)
	var skill_bonus := 0.55 + skill_value * 0.18
	var satisfaction_factor := lerpf(0.45, 1.0, satisfaction / 100.0)
	var meal_bonus := 0.15 if buffs.has("canteen_meal") else 0.0
	return skill_bonus * satisfaction_factor * (1.0 + meal_bonus)

func role_label() -> String:
	return CitizenRoleProfile.label_for(specialization)

func specialization_color() -> Color:
	return CitizenRoleProfile.color_for(specialization)

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

func assign_home(next_home: Node3D) -> void:
	home = next_home

func go_home() -> void:
	if not is_player_controlled and is_instance_valid(home):
		active_role = ""
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
	var change := 1.1 if active_role == preferred_role() else -2.3
	satisfaction = clampf(satisfaction + change * satisfaction_tick, 0.0, get_satisfaction_cap())
	skills[active_role] = minf(5.0, float(skills.get(active_role, 1.0)) + 0.025 * satisfaction_tick)
	satisfaction_tick = 0.0
