class_name SkyAndWeatherController
extends Node3D

const SUN_FLARE_OCCLUSION_DISTANCE := 96.0
const SUN_FLARE_OCCLUSION_SMOOTHING := 0.08
const FLARE_OCCLUDER_LAYER := 8
const SUN_FLARE_OCCLUSION_MASK := 1 | FLARE_OCCLUDER_LAYER

var camera: Camera3D
var sun: DirectionalLight3D
var world_environment: Environment
var sky_material: ShaderMaterial
var rain_effect: Node3D # RainEffect
var fireflies: Array = [] # Array of FirefliesEffect
var lens_flare_material: ShaderMaterial

var lens_flare_visibility := 0.0
var lens_flare_occlusion := 1.0


func setup(
	p_camera: Camera3D,
	p_sun: DirectionalLight3D,
	p_world_environment: Environment,
	p_sky_material: ShaderMaterial,
	p_rain_effect: Node3D,
	p_fireflies: Array,
	p_lens_flare_material: ShaderMaterial
) -> void:
	camera = p_camera
	sun = p_sun
	world_environment = p_world_environment
	sky_material = p_sky_material
	rain_effect = p_rain_effect
	fireflies = p_fireflies
	lens_flare_material = p_lens_flare_material


func update_daylight(game_minutes: float, overcast: float, runtime_seconds: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if sun == null or world_environment == null:
		return
	var hour := game_minutes / 60.0
	var solar_height := sin((hour - 6.0) / 12.0 * PI)
	var solar_intensity := smoothstep(0.0, 0.28, solar_height)
	var twilight := 1.0 - smoothstep(0.0, 0.28, absf(solar_height))
	var direct_light := solar_intensity * (1.0 - overcast)
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
	world_environment.background_color = base_background.lerp(overcast_color, overcast)
	var base_ambient_color := Color("4b5872").lerp(Color("d7ebef"), maxf(solar_intensity, twilight * 0.35))
	var base_ambient_energy := lerpf(0.18, 0.65, maxf(solar_intensity, twilight * 0.3))
	world_environment.ambient_light_color = base_ambient_color.lerp(Color("8a9aa3"), overcast)
	world_environment.ambient_light_energy = lerpf(base_ambient_energy, 0.78, overcast)
	var day_progress := clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	var sun_elevation := 3.0 + maxf(solar_height, 0.0) * 45.0
	var sun_azimuth := lerpf(-75.0, 11.0, day_progress)
	sun.rotation_degrees = Vector3(-sun_elevation, sun_azimuth, 0.0)
	var base_sun_color := Color("f08a5d").lerp(Color("fff2d1"), solar_intensity)
	sun.light_color = base_sun_color.lerp(Color("a8b8c0"), overcast)
	sun.light_energy = lerpf(0.0, 1.2, direct_light)
	sun.shadow_enabled = direct_light > 0.05
	sun.shadow_opacity = lerpf(1.0, 0.0, overcast)
	if sky_material != null:
		var sky_horizon := base_background.lerp(overcast_color, overcast)
		var sky_zenith := sky_horizon.darkened(0.18)
		sky_material.set_shader_parameter("u_horizon_color", sky_horizon)
		sky_material.set_shader_parameter("u_zenith_color", sky_zenith)
		sky_material.set_shader_parameter("u_sun_color", sun.light_color)
		sky_material.set_shader_parameter("u_overcast", overcast)
		sky_material.set_shader_parameter("u_solar_intensity", solar_intensity)
		var horizon_glow := Color("ff6a2a").lerp(Color("a8b8c0"), overcast)
		sky_material.set_shader_parameter("u_horizon_glow_color", horizon_glow)
	if rain_effect != null:
		rain_effect.set_intensity(overcast)
	var visible_direct_light := direct_light if solar_height > 0.01 else 0.0
	update_lens_flare(visible_direct_light, overcast, runtime_seconds)
	var night_factor := 1.0 - smoothstep(0.0, 0.28, solar_height)
	var firefly_factor := night_factor * (1.0 - overcast * 0.5)
	for ff in fireflies:
		if is_instance_valid(ff):
			ff.set_night_factor(firefly_factor)


func update_lens_flare(direct_light: float, overcast: float, runtime_seconds: float) -> void:
	if lens_flare_material == null or camera == null or sun == null:
		return
	var sun_dir := sun.global_transform.basis.z.normalized()
	var sun_world_pos := camera.global_position + sun_dir * 1000.0
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or camera.is_position_behind(sun_world_pos):
		lens_flare_visibility = lerpf(lens_flare_visibility, 0.0, 0.2)
		lens_flare_material.set_shader_parameter("u_intensity", lens_flare_visibility)
		return
	var screen_pos := camera.unproject_position(sun_world_pos)
	var uv := Vector2(screen_pos.x / viewport_size.x, screen_pos.y / viewport_size.y)
	lens_flare_material.set_shader_parameter("u_sun_screen_pos", uv)
	lens_flare_material.set_shader_parameter("u_aspect", viewport_size.x / viewport_size.y)
	lens_flare_material.set_shader_parameter("u_sun_color", sun.light_color)
	var edge_distance := minf(minf(uv.x, 1.0 - uv.x), minf(uv.y, 1.0 - uv.y))
	var edge_fade := smoothstep(-0.12, 0.10, edge_distance)
	var occlusion := _sun_flare_occlusion(sun_dir)
	lens_flare_occlusion = lerpf(lens_flare_occlusion, occlusion, SUN_FLARE_OCCLUSION_SMOOTHING)
	var cloud_clear := 1.0 - _sun_cloud_cover(sun_dir, overcast, runtime_seconds)
	var flare_intensity := direct_light * (1.0 - overcast * 0.85) * edge_fade * lens_flare_occlusion * cloud_clear
	if direct_light <= 0.001:
		lens_flare_visibility = 0.0
		lens_flare_material.set_shader_parameter("u_intensity", 0.0)
		lens_flare_material.set_shader_parameter("u_time", runtime_seconds)
		return
	lens_flare_visibility = lerpf(lens_flare_visibility, flare_intensity, 0.16)
	lens_flare_material.set_shader_parameter("u_intensity", lens_flare_visibility)
	lens_flare_material.set_shader_parameter("u_time", runtime_seconds)


func _sun_flare_occlusion(sun_dir: Vector3) -> float:
	var world := get_world_3d()
	if world == null:
		return 1.0
	var right := camera.global_transform.basis.x.normalized()
	var up := camera.global_transform.basis.y.normalized()
	const SPREAD := 0.06
	var dirs: Array[Vector3] = [
		sun_dir,
		(sun_dir + right * SPREAD).normalized(),
		(sun_dir - right * SPREAD).normalized(),
		(sun_dir + up * SPREAD).normalized(),
		(sun_dir - up * SPREAD).normalized(),
	]
	var visible_rays := 0
	for dir in dirs:
		var from := camera.global_position + dir * 0.75
		var to := from + dir * SUN_FLARE_OCCLUSION_DISTANCE
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.collision_mask = SUN_FLARE_OCCLUSION_MASK
		var hit := world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			visible_rays += 1
	return float(visible_rays) / float(dirs.size())


func _cloud_fract(v: Vector2) -> Vector2:
	return Vector2(v.x - floorf(v.x), v.y - floorf(v.y))


func _cloud_hash21(p: Vector2) -> float:
	p = _cloud_fract(Vector2(p.x * 123.34, p.y * 345.45))
	var d := p.dot(p + Vector2(34.345, 34.345))
	p += Vector2(d, d)
	var v := p.x * p.y
	return v - floorf(v)


func _cloud_value_noise(p: Vector2) -> float:
	var i := Vector2(floorf(p.x), floorf(p.y))
	var f := Vector2(p.x - i.x, p.y - i.y)
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _cloud_hash21(i)
	var b := _cloud_hash21(i + Vector2(1.0, 0.0))
	var c := _cloud_hash21(i + Vector2(0.0, 1.0))
	var d := _cloud_hash21(i + Vector2(1.0, 1.0))
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


func _cloud_fbm(p: Vector2) -> float:
	var sum := 0.0
	var amp := 0.5
	for _i in range(4):
		sum += amp * _cloud_value_noise(p)
		p *= 2.02
		amp *= 0.5
	return sum


func _cloud_field(uv: Vector2) -> float:
	var warp := _cloud_fbm(uv * 0.7 + Vector2(11.3, 5.7))
	return _cloud_fbm(uv + Vector2(warp, warp) * 0.6)


func _sun_cloud_cover(sun_dir: Vector3, overcast: float, runtime_seconds: float) -> float:
	var horizon := maxf(sun_dir.y, 0.16)
	var ceil_mask := smoothstep(0.08, 0.34, sun_dir.y)
	if ceil_mask <= 0.0:
		return 0.0
	var uv := Vector2(sun_dir.x, sun_dir.z) / horizon
	uv = uv * 1.15 + Vector2(0.006, 0.002) * runtime_seconds
	var n := _cloud_field(uv)
	var coverage := lerpf(0.52, 0.14, overcast)
	var density := smoothstep(coverage, coverage + 0.16, n)
	return density * ceil_mask
