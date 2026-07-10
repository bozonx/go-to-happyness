class_name Citizen
extends Node3D

signal wood_delivered

const WALK_SPEED := 2.2
const WORK_DURATION := 1.4

enum State { IDLE, TO_TREE, CHOPPING, TO_SAWMILL, SAWING, TO_WAREHOUSE }

var state := State.IDLE
var tree_position := Vector3.ZERO
var sawmill_position := Vector3.ZERO
var warehouse_position := Vector3.ZERO
var work_time := 0.0

func _ready() -> void:
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

func assign_work(tree: Vector3, sawmill: Vector3, warehouse: Vector3) -> void:
	tree_position = tree
	sawmill_position = sawmill
	warehouse_position = warehouse
	state = State.TO_TREE

func _process(delta: float) -> void:
	match state:
		State.TO_TREE:
			if _move_to(tree_position, delta):
				state = State.CHOPPING
				work_time = WORK_DURATION
		State.CHOPPING:
			if _work(delta):
				state = State.TO_SAWMILL
		State.TO_SAWMILL:
			if _move_to(sawmill_position, delta):
				state = State.SAWING
				work_time = WORK_DURATION
		State.SAWING:
			if _work(delta):
				state = State.TO_WAREHOUSE
		State.TO_WAREHOUSE:
			if _move_to(warehouse_position, delta):
				wood_delivered.emit()
				state = State.TO_TREE

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
