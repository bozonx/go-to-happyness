class_name Citizen
extends CharacterBody3D

signal resource_delivered(resource_type: String, amount: int)
signal excavation_cycle(worker: Citizen, site: Node3D, efficiency: float)
signal resource_ready(worker: Citizen, resource_type: String, amount: int)
signal meal_finished(worker: Citizen)
signal canteen_delivery_finished(worker: Citizen, amount: int)

const WALK_SPEED := 2.2
const WORK_DURATION := 1.4
const COURIER_WAIT_DURATION := 8.0
const BUILD_WORK_DISTANCE := 2.0
const GRAVITY := 18.0

enum State { IDLE, TO_TREE, CHOPPING, TO_SAWMILL, SAWING, TO_WAREHOUSE, CONSTRUCTING, EXCAVATING, COURIER_TO_WORKER, COURIER_TO_WAREHOUSE, WAITING_COURIER, TO_HOME, RESTING, TO_CANTEEN, EATING, TO_FOOD_PICKUP, TO_CANTEEN_DELIVERY }

var state := State.IDLE
var resource_type := "wood"
var source_position := Vector3.ZERO
var workplace_position := Vector3.ZERO
var warehouse_position := Vector3.ZERO
var work_time := 0.0
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
var courier_wait_time := 0.0
var home: Node3D
var hunger := 78.0
var buffs: Dictionary = {}
var debuffs: Dictionary = {}
var meal_time := 0.0
var delivery_amount := 0
var canteen_position := Vector3.ZERO
var construction_position := Vector3.ZERO
var pathfinder: Callable
var movement_path: Array[Vector3] = []
var path_destination := Vector3.INF
var path_allows_destination_house := false

func _ready() -> void:
	var body_collision := CollisionShape3D.new()
	var body_shape := CapsuleShape3D.new()
	body_shape.radius = 0.28
	body_shape.height = 1.25
	body_collision.shape = body_shape
	body_collision.position.y = 0.63
	add_child(body_collision)
	var selector := Area3D.new()
	selector.add_to_group("citizen_selector")
	var selector_shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.38
	capsule_shape.height = 1.3
	selector_shape.shape = capsule_shape
	selector_shape.position.y = 0.65
	selector.add_child(selector_shape)
	add_child(selector)

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.22
	body_mesh.height = 0.78
	body.mesh = body_mesh
	body.position.y = 0.39
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = Color("5d92b2")
	body.material_override = body_material
	add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.48
	head.mesh = head_mesh
	head.position.y = 0.92
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
	active_role = "forestry" if next_resource_type == "wood" else "farming"
	state = State.TO_TREE

func _physics_process(delta: float) -> void:
	if is_player_controlled:
		return
	_apply_gravity(delta)
	_update_effects(delta)
	_update_satisfaction(delta)
	match state:
		State.TO_TREE:
			if _move_to(source_position, delta):
				state = State.CHOPPING
				work_time = WORK_DURATION / get_efficiency(active_role)
		State.CHOPPING:
			if _work(delta):
				state = State.TO_SAWMILL
		State.TO_SAWMILL:
			if _move_to(workplace_position, delta):
				state = State.SAWING
				work_time = WORK_DURATION / get_efficiency(active_role)
		State.SAWING:
			if _work(delta):
				carried_amount = 2 if get_efficiency(active_role) >= 1.05 else 1
				if uses_courier:
					resource_ready.emit(self, resource_type, carried_amount)
					courier_wait_time = COURIER_WAIT_DURATION
					state = State.WAITING_COURIER
				else:
					state = State.TO_WAREHOUSE
		State.TO_WAREHOUSE:
			if _move_to(warehouse_position, delta):
				resource_delivered.emit(resource_type, carried_amount)
				state = State.EXCAVATING if returning_to_excavation else State.TO_TREE
				returning_to_excavation = false
		State.WAITING_COURIER:
			courier_wait_time -= delta
			if courier_wait_time <= 0.0:
				pending_resources[resource_type] = maxi(0, int(pending_resources.get(resource_type, 0)) - carried_amount)
				state = State.TO_WAREHOUSE
		State.CONSTRUCTING:
			if is_instance_valid(construction_site):
				_move_to(construction_position, delta)
			else:
				state = State.IDLE
				construction_site = null
		State.EXCAVATING:
			if is_instance_valid(assigned_dig_site):
				if _move_to(assigned_dig_site.global_position, delta):
					if work_time <= 0.0:
						work_time = WORK_DURATION / get_efficiency("excavation")
					if _work(delta):
						excavation_cycle.emit(self, assigned_dig_site, get_efficiency("excavation"))
						work_time = 0.0
			else:
				idle()
		State.COURIER_TO_WORKER:
			if is_instance_valid(courier_target) and _move_to(courier_target.global_position, delta):
				var cargo := courier_target.take_pending_resource()
				courier_resource_type = cargo.get("type", "")
				carried_amount = int(cargo.get("amount", 0))
				state = State.COURIER_TO_WAREHOUSE if carried_amount > 0 else State.IDLE
		State.COURIER_TO_WAREHOUSE:
			if _move_to(warehouse_position, delta):
				resource_delivered.emit(courier_resource_type, carried_amount)
				state = State.IDLE
		State.TO_HOME:
			if is_instance_valid(home) and _move_to(home.global_position, delta, true):
				state = State.RESTING
		State.RESTING:
			satisfaction = minf(get_satisfaction_cap(), satisfaction + delta * 2.2)
			hunger = maxf(0.0, hunger - delta * 0.25)
		State.TO_CANTEEN:
			if _move_to(canteen_position, delta):
				state = State.EATING
				meal_time = 1.1
		State.EATING:
			meal_time -= delta
			if meal_time <= 0.0:
				meal_finished.emit(self)
				state = State.IDLE
		State.TO_FOOD_PICKUP:
			if _move_to(warehouse_position, delta):
				state = State.TO_CANTEEN_DELIVERY
		State.TO_CANTEEN_DELIVERY:
			if _move_to(canteen_position, delta):
				canteen_delivery_finished.emit(self, delivery_amount)
				delivery_amount = 0
				state = State.IDLE

func _move_to(destination: Vector3, delta: float, may_enter_destination_house := false) -> bool:
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
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	move_and_slide()
	look_at(global_position + direction, Vector3.UP)
	return false

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	if state == State.IDLE or state == State.RESTING:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()

func _work(delta: float) -> bool:
	work_time -= delta
	return work_time <= 0.0

func set_player_controlled(controlled: bool) -> void:
	is_player_controlled = controlled
	if controlled:
		state = State.IDLE
		construction_site = null
		active_role = ""
		movement_path.clear()

func assign_construction(site: Node3D) -> void:
	if is_player_controlled:
		return
	construction_site = site
	construction_position = _work_position_for(site.global_position)
	movement_path.clear()
	active_role = "construction"
	state = State.CONSTRUCTING

func assign_excavation(site: Node3D) -> void:
	if is_player_controlled:
		return
	assigned_dig_site = site
	active_role = "excavation"
	state = State.EXCAVATING

func deliver_excavation(next_resource_type: String, warehouse: Vector3) -> void:
	resource_type = next_resource_type
	warehouse_position = warehouse
	carried_amount = 1
	returning_to_excavation = true
	state = State.TO_WAREHOUSE

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
	state = State.COURIER_TO_WORKER

func is_building_site(site: Node3D) -> bool:
	return not is_player_controlled and state == State.CONSTRUCTING and construction_site == site and global_position.distance_to(construction_position) <= 0.25

func setup_navigation(next_pathfinder: Callable) -> void:
	pathfinder = next_pathfinder

func _work_position_for(site_position: Vector3) -> Vector3:
	var offset := global_position - site_position
	offset.y = 0.0
	if absf(offset.x) > absf(offset.z):
		return site_position + Vector3(BUILD_WORK_DISTANCE if offset.x >= 0.0 else -BUILD_WORK_DISTANCE, 0.0, 0.0)
	return site_position + Vector3(0.0, 0.0, BUILD_WORK_DISTANCE if offset.z >= 0.0 else -BUILD_WORK_DISTANCE)

func setup_specialization(next_specialization: String) -> void:
	specialization = next_specialization
	skills[preferred_role()] = 4.0
	match specialization:
		"builder": body_material.albedo_color = Color("d8a647")
		"forestry": body_material.albedo_color = Color("3f9b61")
		"farming": body_material.albedo_color = Color("5c8fc9")
		"excavation": body_material.albedo_color = Color("a6744b")
		"courier": body_material.albedo_color = Color("a85d91")
		"cook": body_material.albedo_color = Color("d96f43")

func get_efficiency(role: String) -> float:
	var skill_value: float = skills.get(role, 1.0)
	var skill_bonus := 0.55 + skill_value * 0.18
	var satisfaction_factor := lerpf(0.45, 1.0, satisfaction / 100.0)
	var meal_bonus := 0.15 if buffs.has("canteen_meal") else 0.0
	return skill_bonus * satisfaction_factor * (1.0 + meal_bonus)

func role_label() -> String:
	match specialization:
		"builder": return "Builder"
		"forestry": return "Forester"
		"farming": return "Farmer"
		"excavation": return "Digger"
		"cook": return "Cook"
		_: return "Courier"

func specialization_color() -> Color:
	match specialization:
		"builder": return Color("d8a647")
		"forestry": return Color("3f9b61")
		"farming": return Color("5c8fc9")
		"excavation": return Color("a6744b")
		"cook": return Color("d96f43")
		_: return Color("a85d91")

func preferred_role() -> String:
	return "construction" if specialization == "builder" else specialization

func idle() -> void:
	if is_player_controlled:
		return
	state = State.IDLE
	active_role = ""
	construction_site = null
	assigned_dig_site = null

func assign_home(next_home: Node3D) -> void:
	home = next_home

func go_home() -> void:
	if not is_player_controlled and is_instance_valid(home):
		active_role = ""
		state = State.TO_HOME

func go_to_canteen(next_canteen_position: Vector3) -> void:
	if not is_player_controlled:
		canteen_position = next_canteen_position
		active_role = ""
		state = State.TO_CANTEEN

func deliver_food_to_canteen(warehouse: Vector3, next_canteen_position: Vector3, amount: int) -> void:
	if not is_player_controlled:
		warehouse_position = warehouse
		canteen_position = next_canteen_position
		delivery_amount = amount
		active_role = ""
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
	return not is_player_controlled and state != State.TO_CANTEEN and state != State.EATING and state != State.TO_HOME and state != State.RESTING

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
