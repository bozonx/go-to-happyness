class_name Citizen
extends Node3D

signal resource_delivered(resource_type: String, amount: int)
signal excavation_cycle(worker: Citizen, site: Node3D, efficiency: float)
signal resource_ready(worker: Citizen, resource_type: String, amount: int)

const WALK_SPEED := 2.2
const WORK_DURATION := 1.4

enum State { IDLE, TO_TREE, CHOPPING, TO_SAWMILL, SAWING, TO_WAREHOUSE, CONSTRUCTING, EXCAVATING, COURIER_TO_WORKER, COURIER_TO_WAREHOUSE }

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

func _ready() -> void:
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

func _process(delta: float) -> void:
	if is_player_controlled:
		return
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
					state = State.TO_TREE
				else:
					state = State.TO_WAREHOUSE
		State.TO_WAREHOUSE:
			if _move_to(warehouse_position, delta):
				resource_delivered.emit(resource_type, carried_amount)
				state = State.EXCAVATING if returning_to_excavation else State.TO_TREE
				returning_to_excavation = false
		State.CONSTRUCTING:
			if is_instance_valid(construction_site):
				_move_to(construction_site.global_position, delta)
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

func _move_to(destination: Vector3, delta: float) -> bool:
	var offset := destination - global_position
	offset.y = 0.0
	if offset.length() <= 0.08:
		global_position = Vector3(destination.x, global_position.y, destination.z)
		return true
	var direction := offset.normalized()
	global_position += direction * WALK_SPEED * delta
	look_at(global_position + direction, Vector3.UP)
	return false

func _work(delta: float) -> bool:
	work_time -= delta
	return work_time <= 0.0

func set_player_controlled(controlled: bool) -> void:
	is_player_controlled = controlled
	if controlled:
		state = State.IDLE
		construction_site = null
		active_role = ""

func assign_construction(site: Node3D) -> void:
	if is_player_controlled:
		return
	construction_site = site
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
			return {"type": pending_type, "amount": amount}
	return {}

func assign_courier_pickup(worker: Citizen, warehouse: Vector3) -> void:
	courier_target = worker
	warehouse_position = warehouse
	active_role = ""
	state = State.COURIER_TO_WORKER

func is_building_site(site: Node3D) -> bool:
	return not is_player_controlled and state == State.CONSTRUCTING and construction_site == site and global_position.distance_to(site.global_position) <= 0.25

func setup_specialization(next_specialization: String) -> void:
	specialization = next_specialization
	skills[preferred_role()] = 4.0
	match specialization:
		"builder": body_material.albedo_color = Color("d8a647")
		"forestry": body_material.albedo_color = Color("3f9b61")
		"farming": body_material.albedo_color = Color("5c8fc9")
		"excavation": body_material.albedo_color = Color("a6744b")
		"courier": body_material.albedo_color = Color("a85d91")

func get_efficiency(role: String) -> float:
	var skill_value: float = skills.get(role, 1.0)
	var skill_bonus := 0.55 + skill_value * 0.18
	var satisfaction_factor := lerpf(0.45, 1.0, satisfaction / 100.0)
	return skill_bonus * satisfaction_factor

func role_label() -> String:
	match specialization:
		"builder": return "Builder"
		"forestry": return "Forester"
		"farming": return "Farmer"
		"excavation": return "Digger"
		_: return "Courier"

func specialization_color() -> Color:
	match specialization:
		"builder": return Color("d8a647")
		"forestry": return Color("3f9b61")
		"farming": return Color("5c8fc9")
		"excavation": return Color("a6744b")
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

func _update_satisfaction(delta: float) -> void:
	satisfaction_tick += delta
	if satisfaction_tick < 1.0:
		return
	if active_role.is_empty():
		satisfaction = minf(100.0, satisfaction + 1.2 * satisfaction_tick)
		satisfaction_tick = 0.0
		return
	var change := 1.1 if active_role == preferred_role() else -2.3
	satisfaction = clampf(satisfaction + change * satisfaction_tick, 0.0, 100.0)
	skills[active_role] = minf(5.0, float(skills.get(active_role, 1.0)) + 0.025 * satisfaction_tick)
	satisfaction_tick = 0.0
