class_name RainEffect
extends Node3D

## A world-anchored, GPU-particle rain volume. It is only recentered on a coarse
## grid, which keeps the weather from visibly sliding with the camera.

@export var streak_amount := 620
@export var near_drop_amount := 80
@export var splash_amount := 75
@export var follow_radius := 20.0
@export var overhead_height := 8.0
@export var anchor_grid_size := 10.0

var _camera: Camera3D
var _streaks: GPUParticles3D
var _near_drops: GPUParticles3D
var _splashes: GPUParticles3D
var _target_intensity := 0.0
var _visible_intensity := 0.0
var _horizontal_view_factor := 1.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_streaks = get_node_or_null("RainStreaks") as GPUParticles3D
	_near_drops = get_node_or_null("RainNearDrops") as GPUParticles3D
	_splashes = get_node_or_null("RainSplashes") as GPUParticles3D
	if _streaks == null:
		_create_streak_layer()
	if _near_drops == null:
		_create_near_drop_layer()
	if _splashes == null:
		_create_splash_layer()
	_apply_dynamic_params()
	_set_layer_intensity(0.0)
	visible = false
	set_process(true)


func set_camera(camera: Camera3D) -> void:
	_camera = camera


func set_intensity(intensity: float) -> void:
	_target_intensity = clampf(intensity, 0.0, 1.0)
	if _target_intensity > 0.005:
		visible = true


func _process(delta: float) -> void:
	_visible_intensity = move_toward(_visible_intensity, _target_intensity, delta * 2.8)
	var active := _visible_intensity > 0.005 or _target_intensity > 0.005
	if not active:
		_set_layer_intensity(0.0)
		visible = false
		return
	visible = true
	_follow_camera()
	_set_layer_intensity(_visible_intensity, _horizontal_view_factor)


func _create_streak_layer() -> void:
	_streaks = GPUParticles3D.new()
	_streaks.name = "RainStreaks"
	_streaks.amount = streak_amount
	_streaks.lifetime = 0.9
	_streaks.preprocess = 0.35
	_streaks.local_coords = false
	_streaks.visibility_aabb = AABB(Vector3(-follow_radius - 4.0, -18.0, -follow_radius - 4.0), Vector3((follow_radius + 4.0) * 2.0, 34.0, (follow_radius + 4.0) * 2.0))

	var rain_material := ParticleProcessMaterial.new()
	rain_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_material.emission_box_extents = Vector3(follow_radius, 1.4, follow_radius)
	rain_material.direction = Vector3(0.18, -1.0, 0.07).normalized()
	rain_material.spread = 3.0
	rain_material.initial_velocity_min = 17.0
	rain_material.initial_velocity_max = 23.0
	rain_material.gravity = Vector3(0.0, -14.0, 0.0)
	rain_material.scale_min = 0.75
	rain_material.scale_max = 1.2
	rain_material.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	_streaks.process_material = rain_material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.028, 0.42)
	quad.material = _create_particle_material(Color("b6d0df", 0.38), BaseMaterial3D.BILLBOARD_PARTICLES)
	_streaks.draw_pass_1 = quad
	add_child(_streaks)


func _apply_dynamic_params() -> void:
	if _streaks != null:
		_streaks.amount = streak_amount
		_streaks.visibility_aabb = AABB(Vector3(-follow_radius - 4.0, -18.0, -follow_radius - 4.0), Vector3((follow_radius + 4.0) * 2.0, 34.0, (follow_radius + 4.0) * 2.0))
		var streak_mat := _streaks.process_material as ParticleProcessMaterial
		if streak_mat != null:
			streak_mat.emission_box_extents = Vector3(follow_radius, 1.4, follow_radius)
	if _near_drops != null:
		_near_drops.amount = near_drop_amount
	if _splashes != null:
		_splashes.amount = splash_amount
		_splashes.visibility_aabb = AABB(Vector3(-follow_radius * 0.75, -0.5, -follow_radius * 0.75), Vector3(follow_radius * 1.5, 1.8, follow_radius * 1.5))
		var splash_mat := _splashes.process_material as ParticleProcessMaterial
		if splash_mat != null:
			splash_mat.emission_box_extents = Vector3(follow_radius * 0.55, 0.03, follow_radius * 0.55)


func _create_near_drop_layer() -> void:
	_near_drops = GPUParticles3D.new()
	_near_drops.name = "RainNearDrops"
	_near_drops.amount = near_drop_amount
	_near_drops.lifetime = 0.65
	_near_drops.preprocess = 0.18
	_near_drops.local_coords = false
	_near_drops.visibility_aabb = AABB(Vector3(-8.0, -18.0, -8.0), Vector3(16.0, 28.0, 16.0))

	var drop_material := ParticleProcessMaterial.new()
	drop_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	drop_material.emission_box_extents = Vector3(7.0, 1.8, 7.0)
	drop_material.direction = Vector3(0.08, -1.0, 0.0).normalized()
	drop_material.spread = 8.0
	drop_material.initial_velocity_min = 12.0
	drop_material.initial_velocity_max = 16.0
	drop_material.gravity = Vector3(0.0, -8.0, 0.0)
	drop_material.scale_min = 0.7
	drop_material.scale_max = 1.25
	drop_material.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	_near_drops.process_material = drop_material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.14)
	quad.material = _create_particle_material(Color("d7edf7", 0.32), BaseMaterial3D.BILLBOARD_PARTICLES)
	_near_drops.draw_pass_1 = quad
	add_child(_near_drops)


func _create_splash_layer() -> void:
	_splashes = GPUParticles3D.new()
	_splashes.name = "RainSplashes"
	_splashes.amount = splash_amount
	_splashes.lifetime = 0.22
	_splashes.preprocess = 0.1
	_splashes.local_coords = false
	_splashes.visibility_aabb = AABB(Vector3(-follow_radius * 0.75, -0.5, -follow_radius * 0.75), Vector3(follow_radius * 1.5, 1.8, follow_radius * 1.5))

	var splash_material := ParticleProcessMaterial.new()
	splash_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	splash_material.emission_box_extents = Vector3(follow_radius * 0.55, 0.03, follow_radius * 0.55)
	splash_material.direction = Vector3(0.0, 1.0, 0.0)
	splash_material.spread = 55.0
	splash_material.initial_velocity_min = 0.45
	splash_material.initial_velocity_max = 1.1
	splash_material.gravity = Vector3(0.0, -5.0, 0.0)
	splash_material.scale_min = 0.45
	splash_material.scale_max = 1.0
	_splashes.process_material = splash_material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.055, 0.055)
	quad.material = _create_particle_material(Color("d9edf5", 0.24), BaseMaterial3D.BILLBOARD_ENABLED)
	_splashes.draw_pass_1 = quad
	_splashes.top_level = true
	add_child(_splashes)


func _create_particle_material(color: Color, billboard_mode: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.billboard_mode = billboard_mode
	return material


func _follow_camera() -> void:
	var active_camera := _camera
	if active_camera == null:
		var viewport := get_viewport()
		if viewport != null:
			active_camera = viewport.get_camera_3d()
	if active_camera == null:
		return

	var focus := _camera_focus_point(active_camera)
	var anchor := Vector3(
		snappedf(focus.x, anchor_grid_size),
		maxf(active_camera.global_position.y + overhead_height, 9.0),
		snappedf(focus.z, anchor_grid_size),
	)
	global_position = anchor
	_splashes.global_position = Vector3(anchor.x, 0.22, anchor.z)
	var forward := -active_camera.global_transform.basis.z.normalized()
	# Long streaks read as poles from above. Surface hits carry the rain there.
	_horizontal_view_factor = 1.0 - smoothstep(0.48, 0.86, absf(forward.y))


func _camera_focus_point(active_camera: Camera3D) -> Vector3:
	var camera_position := active_camera.global_position
	var forward := -active_camera.global_transform.basis.z
	if forward.y < -0.08:
		var distance_to_ground := (0.22 - camera_position.y) / forward.y
		var clamped_distance := clampf(distance_to_ground, 4.0, 30.0)
		return camera_position + forward * clamped_distance

	var flat_forward := Vector3(forward.x, 0.0, forward.z)
	if flat_forward.length_squared() < 0.001:
		return camera_position
	return camera_position + flat_forward.normalized() * 6.0


func _set_layer_intensity(intensity: float, horizontal_view_factor: float = 1.0) -> void:
	if _streaks == null or _near_drops == null or _splashes == null:
		return
	var eased := smoothstep(0.0, 1.0, intensity)
	var streak_factor := eased * horizontal_view_factor
	var splash_factor := eased * lerpf(1.0, 0.45, horizontal_view_factor)
	_streaks.amount_ratio = lerpf(0.18, 1.0, streak_factor) if streak_factor > 0.005 else 0.0
	_streaks.emitting = streak_factor > 0.005
	_near_drops.amount_ratio = lerpf(0.12, 0.85, streak_factor) if streak_factor > 0.005 else 0.0
	_near_drops.emitting = streak_factor > 0.005
	_splashes.amount_ratio = lerpf(0.0, 0.8, splash_factor)
	_splashes.emitting = splash_factor > 0.08
