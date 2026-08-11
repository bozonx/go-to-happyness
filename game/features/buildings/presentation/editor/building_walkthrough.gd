class_name BuildingWalkthrough
extends Node3D

## "Походить по зданию" — the building editor's test run
## (`modular_building_editor.md`, `map_editor.md` §12 for the map's equivalent).
##
## It is a **walk-through on physics**, not a game session, and that is a
## deliberate narrowing. What an author needs to check about a building they have
## just built is physical: does the doorway admit a person, does the staircase
## carry them up or catch them halfway, is the ceiling of the second floor high
## enough to stand under. None of that is a question about navigation, jobs or a
## settlement, and running a whole session to ask it would tie the building editor
## to a game definition it has no business knowing.
##
## Interior navigation is also not baked yet, so a nav-based preview would answer
## every question with "nowhere is walkable". Collision from the block geometry
## exists today, and it is the thing that actually holds the answers.
##
## **Where it starts.** At the building's entrance — the `door` anchor the author
## already placed for the game to use — because that is where a person arrives
## from and the doorway is the first thing worth testing. Failing that, at the
## middle of the footprint. Named test points are the author's override
## (`BuildingTestPoints`): a second floor is tedious to reach on foot every time
## you change the roof over it.

signal exited

## Roughly a person: 1.8 m tall, shoulder-width. The point of a walk-through is
## that this capsule is the same size as the thing that will live here, so a
## doorway that admits it admits a settler.
const BODY_HEIGHT := 1.8
const BODY_RADIUS := 0.3
const EYE_HEIGHT := 0.75
const WALK_SPEED := 3.2
const RUN_SPEED := 6.0
static var GRAVITY: float = HumanoidMobility.GRAVITY
static var JUMP_SPEED: float = HumanoidMobility.JUMP_VELOCITY
const MOUSE_SENSITIVITY := 0.0022
## How far above the start cell the body is dropped in. A person standing exactly
## on the floor spawns intersecting it and gets pushed through; half a metre of
## fall is invisible and always resolves.
const DROP_HEIGHT := 0.5

var _body: CharacterBody3D = null
var _camera: Camera3D = null
var _collision_root: Node3D = null
var _pitch := 0.0
var _active := false
var _velocity := Vector3.ZERO


func is_active() -> bool:
	return _active


## Builds the colliders, drops the body in and takes the mouse. `sources` are the
## nodes whose visible geometry becomes solid — the block root and the fill root,
## so furniture blocks the way exactly as a wall does. Which nodes those are is
## the editor's business; this asks only for meshes.
func enter(sources: Array[Node], start: Vector3, start_yaw_degrees := 0.0) -> void:
	if _active:
		return
	_active = true
	_build_colliders(sources)
	_build_body(start, start_yaw_degrees)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_physics_process(true)


func exit() -> void:
	if not _active:
		return
	_active = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_physics_process(false)
	# Relinquish the viewport before this camera is deleted at the end of the
	# frame. Otherwise its queued removal can clear the camera which the editor
	# makes current from the `exited` callback, leaving a blank viewport.
	if _camera != null:
		_camera.current = false
	if _body != null:
		_body.queue_free()
		_body = null
	_camera = null
	if _collision_root != null:
		_collision_root.queue_free()
		_collision_root = null
	exited.emit()


## Every mesh under the given roots becomes a static trimesh collider, and a floor
## plane goes under the lot.
##
## Trimesh and not a box per block: a staircase, a wedge and an arch are exactly
## the shapes an author needs to walk through, and a box hull turns all three into
## a wall. The colliders are thrown away on exit rather than kept in sync — the
## author edits nothing while walking, and a stale collider is worse than a
## rebuilt one.
func _build_colliders(sources: Array[Node]) -> void:
	_collision_root = Node3D.new()
	_collision_root.name = "WalkCollision"
	add_child(_collision_root)
	for source: Node in sources:
		if source != null:
			_collide_subtree(source)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var plane := WorldBoundaryShape3D.new()
	floor_shape.shape = plane
	floor_body.add_child(floor_shape)
	_collision_root.add_child(floor_body)


func _collide_subtree(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null and mesh_instance.visible:
		var shape := mesh_instance.mesh.create_trimesh_shape()
		if shape != null:
			var body := StaticBody3D.new()
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
			# Global, because the source tree's own transforms are the block's
			# placement and rotation and must not be re-derived here.
			_collision_root.add_child(body)
			body.global_transform = mesh_instance.global_transform
	for child: Node in node.get_children():
		_collide_subtree(child)


func _build_body(start: Vector3, start_yaw_degrees: float) -> void:
	_body = CharacterBody3D.new()
	_body.name = "WalkBody"
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = BODY_HEIGHT
	capsule.radius = BODY_RADIUS
	collider.shape = capsule
	_body.add_child(collider)
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	_body.add_child(_camera)
	add_child(_body)
	# After the tree, not before: taking the viewport's camera is a thing a node
	# does from inside it, and setting the flag on an orphan leaves the editor's
	# orbit camera rendering while the author walks blind.
	_camera.make_current()
	_body.global_position = start + Vector3(0.0, BODY_HEIGHT * 0.5 + DROP_HEIGHT, 0.0)
	_body.rotation_degrees.y = start_yaw_degrees
	_pitch = 0.0
	_velocity = Vector3.ZERO


## Returns true when the event was the walk-through's. `Esc` leaves, which is the
## same key that leaves everything else in both editors.
func handle_input(event: InputEvent) -> bool:
	if not _active:
		return false
	if event is InputEventKey and event.is_pressed() and not event.is_echo() \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		exit()
		return true
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_body.rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		_pitch = clampf(_pitch - motion.relative.y * MOUSE_SENSITIVITY, -1.4, 1.4)
		_camera.rotation.x = _pitch
		return true
	# Everything else is swallowed while walking: a stray click must not place a
	# block behind the author's back.
	return event is InputEventMouseButton or event is InputEventKey


## Physics process, not idle: `move_and_slide` resolves against the static bodies
## the physics server stepped, and driving it from a frame callback makes a
## staircase climbable at one frame rate and a wall at another.
func _physics_process(delta: float) -> void:
	if not _active or _body == null:
		return
	# Keys read directly rather than through the input map: the editors bind no
	# movement actions, and adding four project-wide actions for a preview would
	# be a change to the game's input map for something only this scene uses.
	var input := Vector2(_axis(KEY_A, KEY_D), _axis(KEY_W, KEY_S))
	var basis := _body.global_transform.basis
	var direction := (basis.x * input.x + basis.z * input.y)
	direction.y = 0.0
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
	var speed := RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	_velocity.x = direction.x * speed
	_velocity.z = direction.z * speed
	if _body.is_on_floor():
		_velocity.y = JUMP_SPEED if Input.is_key_pressed(KEY_SPACE) else 0.0
	else:
		_velocity.y -= GRAVITY * delta
	_body.velocity = _velocity
	_body.move_and_slide()
	_velocity = _body.velocity


static func _axis(negative: Key, positive: Key) -> float:
	return (1.0 if Input.is_key_pressed(positive) else 0.0) \
		- (1.0 if Input.is_key_pressed(negative) else 0.0)
