class_name FirefliesEffect
extends AmbientEffect

## Ambient fireflies that drift as persistent points instead of respawning particles.
## Place at a vegetation cluster; the swarm fades itself in and out with the night.
##
## The night factor is derived here from the snapshot rather than handed in by the
## weather controller. Both worked, but only this way does adding a second night
## effect stop meaning "edit the controller too".

const FIREFLY_WARM := Color(1.0, 0.94, 0.36)
const FIREFLY_SOFT_GREEN := Color(0.62, 1.0, 0.54)

@export var amount := 48
@export var swarm_radius := 5.0
@export var swarm_height := 3.2
@export var minimum_height := 0.45
@export var visibility_distance_begin := 32.0
@export var visibility_distance_end := 58.0


## Authoring hook used by `MapEntityPresenter`: the `core:fireflies` archetype
## carries `amount`/`radius`/`height` props, and the presenter applies them right
## after instantiation, before `_ready` spawns the swarm. The archetype's own
## `@export` defaults stand when a placement omits a prop.
func apply_entity_props(props: Dictionary) -> void:
	if props.has("amount"):
		amount = int(props["amount"])
	if props.has("radius"):
		swarm_radius = float(props["radius"])
	if props.has("height"):
		swarm_height = float(props["height"])

var _rng := RandomNumberGenerator.new()
var _records: Array[FireflyRecord] = []
var _multimesh: MultiMesh
var _instance: MultiMeshInstance3D
var _runtime := 0.0
var _target_visibility := 0.0
var _visibility := 0.0
## Авторский предпросмотр: рой показан целиком и не гаснет, плюс нарисован объём,
## который он занимает. В игре это всегда выключено.
var _authoring_preview := false
var _preview_bounds: MeshInstance3D = null


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
	super()
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_instance = get_node_or_null("FireflyMultimesh") as MultiMeshInstance3D
	if _instance == null:
		_setup_multimesh()
	else:
		_multimesh = _instance.multimesh
	_seed_from_position()
	_configure_multimesh()
	_spawn_fireflies()
	if _authoring_preview:
		_enter_authoring_preview()
	set_process(true)


## Тучи гасят рой мягче, чем рассвет: под плотной облачностью светлячков просто
## меньше, а не «уже день». Коэффициент тот же, что раньше вычислял контроллер
## погоды, — переехало место, а не поведение.
func apply_environment(snapshot: EnvironmentSnapshot) -> void:
	if _authoring_preview:
		return
	var night_factor := 1.0 - smoothstep(0.0, 0.28, snapshot.solar_height)
	set_night_factor(night_factor * (1.0 - snapshot.cloud_cover * 0.5))


func set_night_factor(factor: float) -> void:
	var night_factor := clampf(factor, 0.0, 1.0)
	# Start gently in late twilight and avoid a hard on/off boundary.
	_target_visibility = smoothstep(0.28, 0.82, night_factor)
	if _target_visibility > 0.01:
		visible = true


## Автор ставит светлячков днём и в редакторе без времени суток. Ночной ассет,
## невидимый ровно в тот момент, когда его ставят, — это ассет, который нельзя
## разместить осмысленно, поэтому в предпросмотре рой светит всегда и показывает
## занимаемый объём.
func set_authoring_preview(enabled: bool) -> void:
	if _authoring_preview == enabled:
		return
	_authoring_preview = enabled
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if enabled:
		_enter_authoring_preview()
	else:
		_target_visibility = 0.0
		if _preview_bounds != null:
			_preview_bounds.queue_free()
			_preview_bounds = null


func _enter_authoring_preview() -> void:
	visible = true
	_visibility = 1.0
	_target_visibility = 1.0
	if _preview_bounds == null:
		_preview_bounds = _build_preview_bounds()
		add_child(_preview_bounds)


## Полупрозрачная оболочка роя. Сами точки днём почти не читаются на светлом
## фоне, а автору нужно видеть не столько их, сколько куда достанет рой: радиус и
## высота — как раз те два свойства, которые он и правит в инспекторе.
func _build_preview_bounds() -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = swarm_radius * 0.62
	mesh.height = swarm_height + minimum_height
	mesh.radial_segments = 16
	mesh.rings = 8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.92, 0.4, 0.12)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	mesh.material = material
	var bounds := MeshInstance3D.new()
	bounds.name = "AuthoringBounds"
	bounds.mesh = mesh
	bounds.position.y = (swarm_height + minimum_height) * 0.5
	return bounds


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

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = quad

	_instance = MultiMeshInstance3D.new()
	_instance.name = "FireflyMultimesh"
	_instance.multimesh = _multimesh
	add_child(_instance)


func _configure_multimesh() -> void:
	_multimesh.instance_count = amount
	_multimesh.custom_aabb = AABB(
		Vector3(-swarm_radius * 1.35, minimum_height - 0.6, -swarm_radius * 1.35),
		Vector3(swarm_radius * 2.7, swarm_height + 1.2, swarm_radius * 2.7)
	)


func _create_firefly_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, skip_vertex_transform;

uniform float glow_strength = 3.2;

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
		record.size = _rng.randf_range(0.11, 0.22)
		record.blink_speed = _rng.randf_range(0.62, 1.18)
		record.color = FIREFLY_WARM.lerp(FIREFLY_SOFT_GREEN, _rng.randf_range(0.0, 0.42))
		_records.append(record)
		_multimesh.set_instance_color(index, Color(record.color.r, record.color.g, record.color.b, 0.0))
		_multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * record.size), record.anchor))


func _update_instances() -> void:
	# В предпросмотре дальность не гасит рой: автор смотрит на карту с высоты, и
	# объект, исчезающий именно на рабочей дистанции, бесполезен.
	var distance_factor := 1.0 if _authoring_preview else _camera_distance_factor()
	var final_visibility := _visibility * pow(distance_factor, 2.2)
	_instance.visible = final_visibility > 0.01
	if not _instance.visible:
		return
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
