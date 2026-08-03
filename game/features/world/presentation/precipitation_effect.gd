class_name PrecipitationEffect
extends Node3D

## A world-anchored, GPU-particle precipitation volume. It is only recentered on
## a coarse grid, which keeps the weather from visibly sliding with the camera.
##
## Rain and snow are **one effect with two modes**, not two subsystems
## (`world_environment.md` §10). They share the window, the fade in and out, the
## intensity in the snapshot and the wind that carries them; what differs is the
## particle, the fall speed, how much the wind pushes it and what it does to
## visibility. The changeover when the temperature crosses the threshold during a
## shower is therefore a blend of this one effect's mode — which is the only way
## it can be gradual at all.

## `0` all rain, `1` all snow. Everything mode-dependent below is a lerp along it.
const RAIN_STREAK_SIZE := Vector2(0.028, 0.42)
## Far larger than a real flake, and deliberately: at the gameplay camera's twenty
## to thirty metres a physically sized flake is sub-pixel, so a correct snowfall
## would be an empty sky. Same reasoning as the sun and moon discs (§11).
const SNOW_FLAKE_SIZE := Vector2(0.20, 0.20)
const RAIN_COLOR := Color("b6d0df", 0.38)
const SNOW_COLOR := Color("f2f8ff", 0.85)
const RAIN_FALL_SPEED := Vector2(17.0, 23.0)
const SNOW_FALL_SPEED := Vector2(2.6, 4.6)
const RAIN_GRAVITY := -14.0
const SNOW_GRAVITY := -1.1
const RAIN_SPREAD := 3.0
const SNOW_SPREAD := 26.0
## How hard the wind pushes each. A flake is carried; a drop barely notices.
const RAIN_WIND_RESPONSE := 0.10
const SNOW_WIND_RESPONSE := 1.35
## Game-seconds the mode takes to cross over. Slow on purpose: rain turning to
## snow is a moment the player should catch happening.
const MODE_BLEND_RATE := 0.15

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
var _target_snow := 0.0
var _snow_mix := -1.0
var _wind := Vector2.ZERO
var _streak_material: StandardMaterial3D
var _drop_material: StandardMaterial3D
var _streak_mesh: QuadMesh
var _drop_mesh: QuadMesh


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
	_adopt_mode_resources()
	_apply_dynamic_params()
	_set_layer_intensity(0.0)
	visible = false
	set_process(true)


## Takes private copies of the meshes and materials the mode reshapes. Sub-
## resources authored in a `.tscn` are shared by every instance of that scene, so
## without this the weather lab's snow would also fall in the running game.
func _adopt_mode_resources() -> void:
	_streak_mesh = _unique_quad(_streaks)
	_drop_mesh = _unique_quad(_near_drops)
	_streak_material = _unique_material(_streak_mesh)
	_drop_material = _unique_material(_drop_mesh)
	for emitter: GPUParticles3D in [_streaks, _near_drops]:
		if emitter != null and emitter.process_material != null:
			emitter.process_material = emitter.process_material.duplicate()


func _unique_quad(emitter: GPUParticles3D) -> QuadMesh:
	if emitter == null or emitter.draw_pass_1 == null:
		return null
	var quad := emitter.draw_pass_1.duplicate() as QuadMesh
	emitter.draw_pass_1 = quad
	return quad


func _unique_material(quad: QuadMesh) -> StandardMaterial3D:
	if quad == null or quad.material == null:
		return null
	var material := quad.material.duplicate() as StandardMaterial3D
	quad.material = material
	return material


func set_camera(camera: Camera3D) -> void:
	_camera = camera


## The whole driving interface: what is falling, how hard, and which way the wind
## is taking it. Everything comes off the snapshot, so this node decides nothing.
func set_precipitation(kind: int, intensity: float, wind: Vector2 = Vector2.ZERO) -> void:
	_target_intensity = clampf(intensity, 0.0, 1.0)
	_wind = wind
	if kind != EnvironmentSnapshot.Precipitation.NONE:
		_target_snow = 1.0 if kind == EnvironmentSnapshot.Precipitation.SNOW else 0.0
	if _snow_mix < 0.0 or _visible_intensity <= 0.005:
		# Nothing is falling yet, so there is nothing to cross over *from*: adopt the
		# mode outright. The gradual blend is for the shower that turns to snow while
		# the player watches it — starting a snowfall as sleet is just a wrong start.
		_snow_mix = _target_snow
		_apply_mode(_snow_mix)
		# `preprocess` only takes effect on a restart, and without it the first
		# seconds of a snowfall are a band of flakes hanging at the emitter with an
		# empty sky beneath. Safe here and only here: nothing is falling yet, so
		# there is no visible stream to interrupt.
		for emitter: GPUParticles3D in [_streaks, _near_drops, _splashes]:
			if emitter != null:
				emitter.restart()
	if _target_intensity > 0.005:
		visible = true


func _process(delta: float) -> void:
	_visible_intensity = move_toward(_visible_intensity, _target_intensity, delta * 2.8)
	var next_mix := move_toward(maxf(_snow_mix, 0.0), _target_snow, delta * MODE_BLEND_RATE)
	if not is_equal_approx(next_mix, _snow_mix):
		_snow_mix = next_mix
		_apply_mode(_snow_mix)
	var active := _visible_intensity > 0.005 or _target_intensity > 0.005
	if not active:
		_set_layer_intensity(0.0)
		visible = false
		return
	visible = true
	_follow_camera()
	_set_layer_intensity(_visible_intensity, _horizontal_view_factor)


## Reshapes the shared particle layers along the rain↔snow axis. One set of
## emitters throughout: a second pair of nodes for snow is exactly the "two
## subsystems" §10 forbids, and it could not cross over gradually.
func _apply_mode(snow: float) -> void:
	if _streaks == null or _near_drops == null or _splashes == null:
		return
	var fall := RAIN_FALL_SPEED.lerp(SNOW_FALL_SPEED, snow)
	var drift := Vector3(_wind.x, 0.0, _wind.y) * lerpf(RAIN_WIND_RESPONSE, SNOW_WIND_RESPONSE, snow)
	for emitter: GPUParticles3D in [_streaks, _near_drops]:
		var material := emitter.process_material as ParticleProcessMaterial
		if material == null:
			continue
		var vertical := lerpf(-1.0, -0.35, snow)
		material.direction = (Vector3(drift.x, vertical, drift.z)).normalized()
		material.spread = lerpf(RAIN_SPREAD, SNOW_SPREAD, snow)
		material.initial_velocity_min = fall.x
		material.initial_velocity_max = fall.y
		material.gravity = Vector3(drift.x * 0.5, lerpf(RAIN_GRAVITY, SNOW_GRAVITY, snow), drift.z * 0.5)
		material.set_particle_flag(
			ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, snow < 0.5)
	# Flakes take longer to cross the volume than drops; without this they vanish a
	# metre below the emitter and the snow reads as a thin band in the air. The
	# preprocess is what fills that longer volume the instant the mode changes —
	# otherwise the first four seconds of a snowfall are an empty sky.
	_streaks.lifetime = lerpf(0.9, 5.0, snow)
	_near_drops.lifetime = lerpf(0.65, 3.6, snow)
	_streaks.preprocess = lerpf(0.35, 4.5, snow)
	_near_drops.preprocess = lerpf(0.18, 3.2, snow)
	if _streak_mesh != null:
		_streak_mesh.size = RAIN_STREAK_SIZE.lerp(SNOW_FLAKE_SIZE, snow)
	if _drop_mesh != null:
		_drop_mesh.size = Vector2(0.018, 0.14).lerp(SNOW_FLAKE_SIZE * 0.8, snow)
	if _streak_material != null:
		_streak_material.albedo_color = RAIN_COLOR.lerp(SNOW_COLOR, snow)
		_streak_material.billboard_mode = (
			BaseMaterial3D.BILLBOARD_ENABLED if snow >= 0.5 else BaseMaterial3D.BILLBOARD_PARTICLES)
	if _drop_material != null:
		_drop_material.albedo_color = Color("d7edf7", 0.32).lerp(SNOW_COLOR, snow)


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
	# Splashes are a rain thing: snow settles, it does not bounce off the ground.
	var splash_factor := eased * lerpf(1.0, 0.45, horizontal_view_factor) * (1.0 - maxf(_snow_mix, 0.0))
	_streaks.amount_ratio = lerpf(0.18, 1.0, streak_factor) if streak_factor > 0.005 else 0.0
	_streaks.emitting = streak_factor > 0.005
	_near_drops.amount_ratio = lerpf(0.12, 0.85, streak_factor) if streak_factor > 0.005 else 0.0
	_near_drops.emitting = streak_factor > 0.005
	_splashes.amount_ratio = lerpf(0.0, 0.8, splash_factor)
	_splashes.emitting = splash_factor > 0.08
