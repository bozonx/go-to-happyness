class_name FirefliesEffect
extends Node3D

## Ambient fireflies that drift as persistent points instead of respawning particles.
## Place at a vegetation cluster; call set_night_factor() to fade the swarm in/out.

const FIREFLY_WARM := Color(1.0, 0.94, 0.36)
const FIREFLY_SOFT_GREEN := Color(0.62, 1.0, 0.54)

@export var amount := 48
@export var swarm_radius := 5.0
@export var swarm_height := 3.2
@export var minimum_height := 0.45
@export var visibility_distance_begin := 46.0
@export var visibility_distance_end := 78.0

var _rng := RandomNumberGenerator.new()
var _records: Array[FireflyRecord] = []
var _multimesh := MultiMesh.new()
var _instance := MultiMeshInstance3D.new()
var _runtime := 0.0
var _target_visibility := 0.0
var _visibility := 0.0


class FireflyRecord:
	var anchor := Vector3.ZERO
	var phase := 0.0
	var drift_speed := 0.0
	var radius_scale := 1.0
	var height_scale := 1.0
	var size := 1.0
	var blink_speed := 1.0
	var color := Color.WHITE


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_seed_from_position()
	_setup_multimesh()
	_spawn_fireflies()
	add_child(_instance)
	set_process(true)


func set_night_factor(factor: float) -> void:
	var night_factor := clampf(factor, 0.0, 1.0)
	# Start gently in late twilight and avoid a hard on/off boundary.
	_target_visibility = smoothstep(0.28, 0.82, night_factor)
	if _target_visibility > 0.01:
		visible = true


func _process(delta: float) -> void:
	_runtime += delta
	_visibility = move_toward(_visibility, _target_visibility, delta * 0.55)
	if _visibility <= 0.005 and _target_visibility <= 0.005:
		visible = false
		return
	_update_instances()


func _seed_from_position() -> void:
	var seed_position := global_position if is_inside_tree() else position
	var hash_value := hash("%s:%s" % [name, seed_position])
	_rng.seed = hash_value if hash_value > 0 else -hash_value + 1


func _setup_multimesh() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _create_firefly_material()

	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.instance_count = amount
	_multimesh.mesh = quad
	_multimesh.custom_aabb = AABB(
		Vector3(-swarm_radius * 1.35, minimum_height - 0.6, -swarm_radius * 1.35),
		Vector3(swarm_radius * 2.7, swarm_height + 1.2, swarm_radius * 2.7)
	)

	_instance.name = "FireflyMultimesh"
	_instance.multimesh = _multimesh


func _create_firefly_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, skip_vertex_transform;

uniform float glow_strength = 3.8;

void vertex() {
	vec3 center = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX = center + vec3(VERTEX.x, VERTEX.y, 0.0);
}

void fragment() {
	vec2 centered_uv = UV * 2.0 - 1.0;
	float distance_from_center = length(centered_uv);
	float halo = smoothstep(1.0, 0.0, distance_from_center);
	float core = smoothstep(0.22, 0.0, distance_from_center);
	float alpha = COLOR.a * pow(halo, 1.7);
	vec3 warm_color = COLOR.rgb;
	ALBEDO = warm_color * (0.25 + core * 0.75);
	EMISSION = warm_color * glow_strength * (halo * 0.75 + core * 2.4) * COLOR.a;
	ALPHA = alpha;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _spawn_fireflies() -> void:
	_records.clear()
	for index in amount:
		var record := FireflyRecord.new()
		var angle := _rng.randf_range(0.0, TAU)
		var distance := sqrt(_rng.randf()) * swarm_radius * 0.62
		record.anchor = Vector3(
			cos(angle) * distance,
			_rng.randf_range(minimum_height, minimum_height + swarm_height),
			sin(angle) * distance
		)
		record.phase = _rng.randf_range(0.0, TAU)
		record.drift_speed = _rng.randf_range(0.18, 0.42)
		record.radius_scale = _rng.randf_range(0.55, 1.15)
		record.height_scale = _rng.randf_range(0.55, 1.05)
		record.size = _rng.randf_range(0.18, 0.34)
		record.blink_speed = _rng.randf_range(0.62, 1.18)
		record.color = FIREFLY_WARM.lerp(FIREFLY_SOFT_GREEN, _rng.randf_range(0.0, 0.42))
		_records.append(record)
		_multimesh.set_instance_color(index, Color(record.color.r, record.color.g, record.color.b, 0.0))
		_multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * record.size), record.anchor))


func _update_instances() -> void:
	var distance_factor := _camera_distance_factor()
	var final_visibility := _visibility * distance_factor
	for index in _records.size():
		var record := _records[index]
		var position := _position_for(record)
		var blink := _blink_for(record)
		var alpha := final_visibility * blink
		var size := record.size * lerpf(0.86, 1.18, blink) * lerpf(1.08, 0.72, 1.0 - distance_factor)
		var basis := Basis.IDENTITY.scaled(Vector3.ONE * size)
		_multimesh.set_instance_transform(index, Transform3D(basis, position))
		_multimesh.set_instance_color(index, Color(record.color.r, record.color.g, record.color.b, alpha))


func _position_for(record: FireflyRecord) -> Vector3:
	var t := _runtime * record.drift_speed
	var x := sin(t + record.phase) * swarm_radius * 0.34 * record.radius_scale
	x += sin(t * 0.37 + record.phase * 1.9) * swarm_radius * 0.16
	var z := cos(t * 0.83 + record.phase * 1.4) * swarm_radius * 0.30 * record.radius_scale
	z += sin(t * 0.29 + record.phase * 0.7) * swarm_radius * 0.18
	var y := sin(t * 1.21 + record.phase * 0.6) * swarm_height * 0.17 * record.height_scale
	y += sin(t * 0.43 + record.phase * 2.2) * 0.18
	return record.anchor + Vector3(x, y, z)


func _blink_for(record: FireflyRecord) -> float:
	var pulse := 0.5 + 0.5 * sin(_runtime * record.blink_speed + record.phase)
	var slow_breath := 0.5 + 0.5 * sin(_runtime * 0.23 + record.phase * 0.31)
	return lerpf(0.42, 1.0, pow(pulse, 1.65)) * lerpf(0.82, 1.0, slow_breath)


func _camera_distance_factor() -> float:
	var viewport := get_viewport()
	if viewport == null:
		return 1.0
	var camera := viewport.get_camera_3d()
	if camera == null:
		return 1.0
	var distance := camera.global_position.distance_to(global_position)
	return 1.0 - smoothstep(visibility_distance_begin, visibility_distance_end, distance)
