class_name Citizen
extends Node3D

signal resource_delivered(resource_type: String)

const WALK_SPEED := 2.2
const WORK_DURATION := 1.4

enum State { IDLE, TO_TREE, CHOPPING, TO_SAWMILL, SAWING, TO_WAREHOUSE, CONSTRUCTING }

var state := State.IDLE
var resource_type := "wood"
var source_position := Vector3.ZERO
var workplace_position := Vector3.ZERO
var warehouse_position := Vector3.ZERO
var work_time := 0.0
var is_player_controlled := false
var construction_site: Node3D

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
	var body_material := StandardMaterial3D.new()
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

func assign_work(next_resource_type: String, source: Vector3, workplace: Vector3, warehouse: Vector3) -> void:
	if is_player_controlled:
		return
	resource_type = next_resource_type
	source_position = source
	workplace_position = workplace
	warehouse_position = warehouse
	state = State.TO_TREE

func _process(delta: float) -> void:
	if is_player_controlled:
		return
	match state:
		State.TO_TREE:
			if _move_to(source_position, delta):
				state = State.CHOPPING
				work_time = WORK_DURATION
		State.CHOPPING:
			if _work(delta):
				state = State.TO_SAWMILL
		State.TO_SAWMILL:
			if _move_to(workplace_position, delta):
				state = State.SAWING
				work_time = WORK_DURATION
		State.SAWING:
			if _work(delta):
				state = State.TO_WAREHOUSE
		State.TO_WAREHOUSE:
			if _move_to(warehouse_position, delta):
				resource_delivered.emit(resource_type)
				state = State.TO_TREE
		State.CONSTRUCTING:
			if is_instance_valid(construction_site):
				_move_to(construction_site.global_position, delta)
			else:
				state = State.IDLE
				construction_site = null

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

func assign_construction(site: Node3D) -> void:
	if is_player_controlled:
		return
	construction_site = site
	state = State.CONSTRUCTING

func is_building_site(site: Node3D) -> bool:
	return not is_player_controlled and state == State.CONSTRUCTING and construction_site == site and global_position.distance_to(site.global_position) <= 0.25
