class_name SkyAndWeatherController
extends Node3D

const SUN_GLARE_OCCLUSION_DISTANCE := 96.0
const SUN_GLARE_OCCLUSION_MASK := 1 | 8
const SUN_GLARE_EDGE_ALLOWANCE := 0.18
const SUN_GLARE_OCCLUSION_SAMPLE_RADIUS := 0.24
const CLOUD_SCALE := 1.55
const CLOUD_WIND := Vector2(0.006, 0.002)
const CLOUD_EDGE_SOFTNESS := 0.07
const CLOUD_COVERAGE_CLEAR := 0.56
const CLOUD_COVERAGE_STORM := 0.14
const CLOUD_MINIMUM_SUN_VISIBILITY := 0.12

var camera: Camera3D
var sun: DirectionalLight3D
var world_environment: Environment
var sky_material: ShaderMaterial
var rain_effect: Node3D # RainEffect
var fireflies: Array = [] # Array of FirefliesEffect
var sun_glare_material: ShaderMaterial
var sun_glare_visibility := 0.0

func setup(
	p_camera: Camera3D,
	p_sun: DirectionalLight3D,
	p_world_environment: Environment,
	p_sky_material: ShaderMaterial,
	p_rain_effect: Node3D,
	p_fireflies: Array,
	p_sun_glare_material: ShaderMaterial
) -> void:
	camera = p_camera
	sun = p_sun
	world_environment = p_world_environment
	sky_material = p_sky_material
	rain_effect = p_rain_effect
	fireflies = p_fireflies
	sun_glare_material = p_sun_glare_material


func update_daylight(game_minutes: float, cloud_cover: float, rain_intensity: float, runtime_seconds: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if sun == null or world_environment == null:
		return
	var hour := game_minutes / 60.0
	var solar_height := sin((hour - 6.0) / 12.0 * PI)
	var solar_intensity := smoothstep(0.0, 0.28, solar_height)
	var twilight := 1.0 - smoothstep(0.0, 0.28, absf(solar_height))
	var night_color := Color("101a2b")
	var twilight_color := Color("c66b52")
	var night_twilight_color := Color("503149")
	var day_color := Color("6fa9d6")
	var overcast_color := Color("60707a")
	var base_background: Color
	if solar_height <= 0.0:
		base_background = night_color.lerp(night_twilight_color, twilight * 0.55)
	else:
		base_background = twilight_color.lerp(day_color, smoothstep(0.0, 0.42, solar_height))
	world_environment.background_color = base_background.lerp(overcast_color, cloud_cover)
	var base_ambient_color := Color("4b5872").lerp(Color("d7ebef"), maxf(solar_intensity, twilight * 0.35))
	var base_ambient_energy := lerpf(0.18, 0.65, maxf(solar_intensity, twilight * 0.3))
	world_environment.ambient_light_color = base_ambient_color.lerp(Color("8a9aa3"), cloud_cover)
	world_environment.ambient_light_energy = lerpf(base_ambient_energy, 0.78, cloud_cover)
	var day_progress := clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	var sun_elevation := 3.0 + maxf(solar_height, 0.0) * 45.0
	var sun_azimuth := lerpf(-75.0, 11.0, day_progress)
	sun.rotation_degrees = Vector3(-sun_elevation, sun_azimuth, 0.0)
	var sun_direction := sun.global_transform.basis.z.normalized()
	var cloud_sun_visibility := _cloud_sun_visibility(sun_direction, cloud_cover, runtime_seconds)
	var direct_light := solar_intensity * (1.0 - cloud_cover) * cloud_sun_visibility
	var base_sun_color := Color("f08a5d").lerp(Color("fff2d1"), solar_intensity)
	sun.light_color = base_sun_color.lerp(Color("a8b8c0"), cloud_cover)
	sun.light_energy = lerpf(0.0, 1.2, direct_light)
	sun.shadow_enabled = direct_light > 0.05
	sun.shadow_opacity = lerpf(1.0, 0.0, cloud_cover)
	var night_factor := 1.0 - smoothstep(0.0, 0.28, solar_height)
	# Twilight is still bright after the sun reaches the horizon. Keep stars out
	# until the sun is meaningfully below it, then fade them in during dusk.
	var star_visibility := 1.0 - smoothstep(-0.42, -0.08, solar_height)
	if sky_material != null:
		var sky_horizon := base_background.lerp(overcast_color, cloud_cover)
		# Clear skies deepen toward a saturated anime blue at the zenith; overcast
		# keeps the flat grey ceiling.
		var deep_zenith := Color("2b6fd6")
		var sky_zenith := sky_horizon.darkened(0.22).lerp(deep_zenith, (1.0 - cloud_cover) * 0.5)
		sky_material.set_shader_parameter("u_horizon_color", sky_horizon)
		sky_material.set_shader_parameter("u_zenith_color", sky_zenith)
		sky_material.set_shader_parameter("u_sun_color", sun.light_color)
		sky_material.set_shader_parameter("u_overcast", cloud_cover)
		sky_material.set_shader_parameter("u_solar_intensity", solar_intensity)
		sky_material.set_shader_parameter("u_sun_visibility", cloud_sun_visibility)
		sky_material.set_shader_parameter("u_time", runtime_seconds)
		sky_material.set_shader_parameter("u_cloud_scale", CLOUD_SCALE)
		sky_material.set_shader_parameter("u_wind", CLOUD_WIND)
		sky_material.set_shader_parameter("u_edge_softness", CLOUD_EDGE_SOFTNESS)
		sky_material.set_shader_parameter("u_coverage_clear", CLOUD_COVERAGE_CLEAR)
		sky_material.set_shader_parameter("u_coverage_storm", CLOUD_COVERAGE_STORM)
		var horizon_glow := Color("ff6a2a").lerp(Color("a8b8c0"), cloud_cover)
		sky_material.set_shader_parameter("u_horizon_glow_color", horizon_glow)
		sky_material.set_shader_parameter("u_night_factor", night_factor)
		sky_material.set_shader_parameter("u_star_visibility", star_visibility)
	if rain_effect != null:
		rain_effect.set_intensity(rain_intensity)
	_update_sun_glare(direct_light, cloud_cover)
	var firefly_factor := night_factor * (1.0 - cloud_cover * 0.5)
	for ff in fireflies:
		if is_instance_valid(ff):
			ff.set_night_factor(firefly_factor)


func _cloud_sun_visibility(sun_direction: Vector3, overcast: float, runtime_seconds: float) -> float:
	var horizon := sun_direction.y
	var projection_scale := maxf(horizon + 0.28, 0.28)
	var uv := Vector2(sun_direction.x, sun_direction.z) / projection_scale
	uv = uv * CLOUD_SCALE + CLOUD_WIND * runtime_seconds
	var coverage_curve := pow(overcast, 0.55)
	var coverage := lerpf(CLOUD_COVERAGE_CLEAR, CLOUD_COVERAGE_STORM, coverage_curve)
	var density := smoothstep(coverage, coverage + CLOUD_EDGE_SOFTNESS, _cloud_field(uv))
	var cloud_alpha := density * smoothstep(0.08, 0.34, horizon)
	return lerpf(1.0, CLOUD_MINIMUM_SUN_VISIBILITY, cloud_alpha)


func _cloud_field(uv: Vector2) -> float:
	var q := Vector2(
		_fbm(uv * 0.75),
		_fbm(uv * 0.75 + Vector2(5.2, 1.3))
	)
	var macro := _fbm(uv * 0.32 + q * 0.45)
	var lobes := _cellular_billow(uv * 0.92 + q * 0.8)
	var detail := _fbm(uv * 2.15 + q * 1.25)
	var islands := smoothstep(0.40, 0.67, macro)
	var body := macro * 0.54 + lobes * 0.34 + detail * 0.12
	return body * lerpf(0.24, 1.0, islands)


func _cellular_billow(p: Vector2) -> float:
	var cell := p.floor()
	var local := p - cell
	var nearest := 2.0
	for y in range(-1, 2):
		for x in range(-1, 2):
			var neighbour := Vector2(x, y)
			var sample_cell := cell + neighbour
			var point := Vector2(
				_hash21(sample_cell + Vector2(7.1, 3.7)),
				_hash21(sample_cell + Vector2(19.3, 11.8))
			)
			nearest = minf(nearest, (neighbour + point - local).length())
	return 1.0 - smoothstep(0.18, 0.78, nearest)


func _fbm(p: Vector2) -> float:
	var value := 0.0
	var amplitude := 0.5
	for _octave in range(4):
		value += amplitude * _value_noise(p)
		p *= 2.02
		amplitude *= 0.5
	return value


func _value_noise(p: Vector2) -> float:
	var cell := p.floor()
	var fraction := p - cell
	fraction = fraction * fraction * (Vector2.ONE * 3.0 - fraction * 2.0)
	var a := _hash21(cell)
	var b := _hash21(cell + Vector2(1.0, 0.0))
	var c := _hash21(cell + Vector2(0.0, 1.0))
	var d := _hash21(cell + Vector2.ONE)
	return lerpf(lerpf(a, b, fraction.x), lerpf(c, d, fraction.x), fraction.y)


func _hash21(p: Vector2) -> float:
	p = Vector2(_fract(p.x * 123.34), _fract(p.y * 345.45))
	p += Vector2.ONE * p.dot(p + Vector2.ONE * 34.345)
	return _fract(p.x * p.y)


func _fract(value: float) -> float:
	return value - floorf(value)


func _update_sun_glare(direct_light: float, overcast: float) -> void:
	if sun_glare_material == null or camera == null or sun == null:
		return
	var sun_direction := sun.global_transform.basis.z.normalized()
	var sun_position := camera.global_position + sun_direction * 1000.0
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or camera.is_position_behind(sun_position):
		sun_glare_visibility = lerpf(sun_glare_visibility, 0.0, 0.22)
		sun_glare_material.set_shader_parameter("u_intensity", sun_glare_visibility)
		return
	var screen_position := camera.unproject_position(sun_position)
	var raw_uv := Vector2(screen_position.x / viewport_size.x, screen_position.y / viewport_size.y)
	var outside_distance := maxf(maxf(-raw_uv.x, raw_uv.x - 1.0), maxf(-raw_uv.y, raw_uv.y - 1.0))
	var edge_fade := 1.0 - smoothstep(0.0, SUN_GLARE_EDGE_ALLOWANCE, outside_distance)
	var uv := raw_uv.clamp(Vector2(-0.04, -0.04), Vector2(1.04, 1.04))
	var target_visibility := direct_light * (1.0 - overcast * 0.9) * edge_fade * _sun_glare_occlusion(sun_direction)
	sun_glare_visibility = lerpf(sun_glare_visibility, target_visibility, 0.14)
	sun_glare_material.set_shader_parameter("u_sun_screen_pos", uv)
	sun_glare_material.set_shader_parameter("u_aspect", viewport_size.x / viewport_size.y)
	sun_glare_material.set_shader_parameter("u_sun_color", sun.light_color)
	sun_glare_material.set_shader_parameter("u_intensity", sun_glare_visibility)


func _sun_glare_occlusion(sun_direction: Vector3) -> float:
	var world := get_world_3d()
	if world == null:
		return 1.0
	var right := camera.global_transform.basis.x.normalized() * SUN_GLARE_OCCLUSION_SAMPLE_RADIUS
	var up := camera.global_transform.basis.y.normalized() * SUN_GLARE_OCCLUSION_SAMPLE_RADIUS
	var sample_offsets: Array[Vector3] = [Vector3.ZERO, right, -right, up, -up]
	var clear_samples := 0
	for offset in sample_offsets:
		var from := camera.global_position + sun_direction * 0.75 + offset
		var query := PhysicsRayQueryParameters3D.create(from, from + sun_direction * SUN_GLARE_OCCLUSION_DISTANCE)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.collision_mask = SUN_GLARE_OCCLUSION_MASK
		if world.direct_space_state.intersect_ray(query).is_empty():
			clear_samples += 1
	return float(clear_samples) / float(sample_offsets.size())
