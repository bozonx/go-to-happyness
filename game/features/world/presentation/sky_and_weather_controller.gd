class_name SkyAndWeatherController
extends Node3D

var sun: DirectionalLight3D
var world_environment: Environment
var sky_material: ShaderMaterial
var rain_effect: Node3D # RainEffect
var fireflies: Array = [] # Array of FirefliesEffect

func setup(
	p_sun: DirectionalLight3D,
	p_world_environment: Environment,
	p_sky_material: ShaderMaterial,
	p_rain_effect: Node3D,
	p_fireflies: Array
) -> void:
	sun = p_sun
	world_environment = p_world_environment
	sky_material = p_sky_material
	rain_effect = p_rain_effect
	fireflies = p_fireflies


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
	var night_factor := 1.0 - smoothstep(0.0, 0.28, solar_height)
	var firefly_factor := night_factor * (1.0 - overcast * 0.5)
	for ff in fireflies:
		if is_instance_valid(ff):
			ff.set_night_factor(firefly_factor)
