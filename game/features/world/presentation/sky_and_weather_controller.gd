class_name SkyAndWeatherController
extends Node3D

const SUN_GLARE_OCCLUSION_DISTANCE := 96.0
const SUN_GLARE_OCCLUSION_MASK := 1 | 8
const SUN_GLARE_EDGE_ALLOWANCE := 0.18
const SUN_GLARE_OCCLUSION_SAMPLE_RADIUS := 0.24
const CLOUD_SCALE := 1.55
# Wind vector arrives as a 0..1 bearing*strength from the weather model; this scales
# it into cloud-UV drift per game-minute. The shader then applies per-altitude speed
# multipliers on top (fast cirrus, slow cumulus).
const CLOUD_WIND_UV_SCALE := 0.0045
# Fallback wind used only when a caller passes no wind (calm-ish default drift).
const CLOUD_WIND_FALLBACK := Vector2(0.006, 0.002)
# Shape-morph rate per game-minute; a full day now produces one slow evolution
# cycle rather than several restless reshapes.
const CLOUD_EVOLVE_SCALE := 0.0007
const CLOUD_EDGE_SOFTNESS := 0.048
# Fair-weather coverage stays in a gapped range no matter how high cloud_cover goes,
# so raising cover only makes more/bigger cumulus — never a sealed grey sheet. The
# storm front owns the full ceiling separately (u_storm_amount in the shader).
const CLOUD_COVERAGE_MIN_CLOUDS := 0.60
const CLOUD_COVERAGE_MAX_CLOUDS := 0.24
const CLOUD_MINIMUM_SUN_VISIBILITY := 0.12

class CloudLayerMix:
	var cumulus := 0.0
	var cirrus := 0.0
	var elongated := 0.0
	var storm := 0.0


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


func update_daylight(
	game_minutes: float,
	cloud_cover: float,
	rain_intensity: float,
	runtime_seconds: float,
	storm_influence: float = 0.0,
	cloud_pattern_seed: float = 0.0,
	wind_vector: Vector2 = Vector2.ZERO,
	weather_minutes: float = -1.0,
	precipitation_type: int = WeatherState.Precipitation.RAIN,
	wind_displacement: Vector2 = Vector2.ZERO
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if sun == null or world_environment == null:
		return
	var hour := game_minutes / 60.0
	var solar_height := sin((hour - 6.0) / 12.0 * PI)
	var solar_intensity := smoothstep(0.0, 0.28, solar_height)
	var twilight := 1.0 - smoothstep(0.0, 0.28, absf(solar_height))
	var cloud_night := 1.0 - smoothstep(-0.25, 0.05, solar_height)
	# Two independent weather regulators drive everything else:
	#   cloud_cover      -> fair-weather cloudiness (keeps a blue, saturated sky)
	#   storm_influence  -> storm front (grey murk, darkening, rain)
	# "Murk" is the grey, flat, desaturating atmosphere. It belongs solely to the
	# storm front: no amount of fair-weather cloud coverage ever greys the sky.
	var storm := clampf(storm_influence, 0.0, 1.0)
	var murk := storm
	# Cloud motion runs on the continuous game clock, so drifting/scrubbing the time
	# of day scrolls and morphs the clouds with it. Falls back to real seconds when a
	# caller supplies no game clock (e.g. an isolated preview).
	var motion_clock := weather_minutes if weather_minutes >= 0.0 else runtime_seconds
	# Wind is authored by the shared weather model (bearing*strength, 0..1). Anything
	# else that reacts to wind reads the same source, so clouds agree with it.
	var wind := wind_vector
	var wind_offset: Vector2
	if wind_displacement != Vector2.ZERO:
		wind_offset = wind_displacement * CLOUD_WIND_UV_SCALE
	elif wind == Vector2.ZERO:
		wind = CLOUD_WIND_FALLBACK
		wind_offset = wind * motion_clock
	else:
		wind = wind * CLOUD_WIND_UV_SCALE
		wind_offset = wind * motion_clock
	var wind_direction := wind.normalized()
	# Slow shape-morph clock: cumulus swell and dissolve rather than only scrolling.
	var cloud_evolve := motion_clock * CLOUD_EVOLVE_SCALE
	var cloud_layers := _cloud_layer_mix(
		cloud_cover,
		storm_influence,
		cloud_pattern_seed,
		cloud_night,
		motion_clock
	)
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
	world_environment.background_color = base_background.lerp(overcast_color, murk)
	var base_ambient_color := Color("4b5872").lerp(Color("d7ebef"), maxf(solar_intensity, twilight * 0.35))
	var base_ambient_energy := lerpf(0.18, 0.65, maxf(solar_intensity, twilight * 0.3))
	# Ground light desaturates toward grey only under murk; a full white cloud sheet
	# still lifts overall ambient energy.
	world_environment.ambient_light_color = base_ambient_color.lerp(Color("8a9aa3"), murk)
	world_environment.ambient_light_energy = lerpf(base_ambient_energy, 0.78, cloud_cover * 0.6 + murk * 0.4)
	var day_progress := clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	var sun_elevation := 3.0 + maxf(solar_height, 0.0) * 45.0
	var sun_azimuth := lerpf(-75.0, 11.0, day_progress)
	sun.rotation_degrees = Vector3(-sun_elevation, sun_azimuth, 0.0)
	var sun_direction := sun.global_transform.basis.z.normalized()
	var cloud_sun_visibility := _cloud_sun_visibility(
		sun_direction,
		cloud_cover,
		wind_offset,
		cloud_layers
	)
	# Fair clouds only dapple the sun; a storm front is what actually smothers it.
	var direct_light := solar_intensity * (1.0 - cloud_cover * 0.6) * (1.0 - murk) * cloud_sun_visibility
	var base_sun_color := Color("f08a5d").lerp(Color("fff2d1"), solar_intensity)
	sun.light_color = base_sun_color.lerp(Color("a8b8c0"), murk)
	sun.light_energy = lerpf(0.0, 1.2, direct_light)
	sun.shadow_enabled = direct_light > 0.05
	sun.shadow_opacity = lerpf(1.0, 0.0, murk)
	var night_factor := 1.0 - smoothstep(0.0, 0.28, solar_height)
	# Twilight is still bright after the sun reaches the horizon. Keep stars out
	# until the sun is meaningfully below it, then fade them in during dusk.
	var star_visibility := 1.0 - smoothstep(-0.42, -0.08, solar_height)
	# How dark the clouds paint. Asymmetric on purpose: just after sunset the sun
	# still rims the clouds warm, but by the pre-dawn deep twilight they must read
	# as dim night masses instead of daytime white.
	# The moon runs its own arc across the night, twelve hours out of phase with
	# the sun: it rises at dusk, peaks at midnight and sets at dawn, tracing the
	# sky instead of hanging in one spot. Same euler convention as the sun so the
	# shader reads its direction identically.
	var moon_hour := fmod(hour + 12.0, 24.0)
	var moon_height := sin((moon_hour - 6.0) / 12.0 * PI)
	var moon_progress := clampf((moon_hour - 6.0) / 12.0, 0.0, 1.0)
	var moon_elevation := 3.0 + maxf(moon_height, 0.0) * 52.0
	var moon_azimuth := lerpf(-75.0, 11.0, moon_progress) + 180.0
	var moon_basis := Basis.from_euler(Vector3(deg_to_rad(-moon_elevation), deg_to_rad(moon_azimuth), 0.0))
	var moon_direction := moon_basis.z.normalized()
	if sky_material != null:
		var sky_horizon := base_background.lerp(overcast_color, murk)
		# Clear (non-murky) skies deepen toward a saturated anime blue at the zenith,
		# even when busy with fair-weather clouds; only murk flattens it to grey.
		var deep_zenith := Color("2b6fd6")
		var sky_zenith := sky_horizon.darkened(0.22).lerp(deep_zenith, (1.0 - murk) * 0.6)
		sky_material.set_shader_parameter("u_horizon_color", sky_horizon)
		sky_material.set_shader_parameter("u_zenith_color", sky_zenith)
		sky_material.set_shader_parameter("u_sun_color", sun.light_color)
		sky_material.set_shader_parameter("u_overcast", cloud_cover)
		sky_material.set_shader_parameter("u_murk", murk)
		sky_material.set_shader_parameter("u_solar_intensity", solar_intensity)
		sky_material.set_shader_parameter("u_sun_visibility", cloud_sun_visibility)
		sky_material.set_shader_parameter("u_time", motion_clock)
		sky_material.set_shader_parameter("u_cloud_evolve", cloud_evolve)
		sky_material.set_shader_parameter("u_cloud_scale", CLOUD_SCALE)
		sky_material.set_shader_parameter("u_wind_offset", wind_offset)
		sky_material.set_shader_parameter("u_wind_direction", wind_direction)
		sky_material.set_shader_parameter("u_edge_softness", CLOUD_EDGE_SOFTNESS)
		sky_material.set_shader_parameter("u_coverage_clear", CLOUD_COVERAGE_MIN_CLOUDS)
		sky_material.set_shader_parameter("u_coverage_storm", CLOUD_COVERAGE_MAX_CLOUDS)
		sky_material.set_shader_parameter("u_cumulus_amount", cloud_layers.cumulus)
		sky_material.set_shader_parameter("u_cirrus_amount", cloud_layers.cirrus)
		sky_material.set_shader_parameter("u_elongated_amount", cloud_layers.elongated)
		sky_material.set_shader_parameter("u_storm_amount", cloud_layers.storm)
		# Cloud cover desaturates the sunset much more slowly than the rest of the
		# sky: broken clouds should catch peach light instead of turning uniformly
		# grey as soon as the forecast passes fifty percent.
		var horizon_glow := Color("ff6a2a").lerp(Color("a8b8c0"), murk * 0.45)
		sky_material.set_shader_parameter("u_horizon_glow_color", horizon_glow)
		sky_material.set_shader_parameter("u_night_factor", cloud_night)
		sky_material.set_shader_parameter("u_star_visibility", star_visibility)
		# Atmospheric horizon band. Two separate contributions:
		#   * clear-weather glow: a soft light band by day, warm at dawn/dusk, and
		#     fully absent at clear night (day_light -> 0) so the stars sit on clean
		#     deep blue with no grey dome.
		#   * storm murk: a grey haze that hangs any time of day, including night.
		var day_light := maxf(solar_intensity, twilight)
		var haze_day := sky_horizon.lightened(0.30)
		var haze_color := haze_day.lerp(Color("ff9a5c"), twilight * (1.0 - murk) * 0.7)
		haze_color = haze_color.lerp(overcast_color.darkened(0.1), murk * 0.8)
		var clear_haze := (0.14 + twilight * 0.40) * day_light * (1.0 - murk * 0.6)
		var storm_haze := murk * 0.5
		var haze_strength := clampf(clear_haze + storm_haze, 0.0, 0.85)
		sky_material.set_shader_parameter("u_haze_color", haze_color)
		sky_material.set_shader_parameter("u_haze_strength", haze_strength)
		# Night moon, opposite the sun and fading in with the deepening twilight.
		sky_material.set_shader_parameter("u_moon_dir", moon_direction)
		sky_material.set_shader_parameter("u_moon_energy", cloud_night)
	if rain_effect != null:
		rain_effect.set_intensity(rain_intensity)
	_update_sun_glare(direct_light, cloud_cover)
	var firefly_factor := night_factor * (1.0 - cloud_cover * 0.5)
	for ff in fireflies:
		if is_instance_valid(ff):
			ff.set_night_factor(firefly_factor)


func _cloud_layer_mix(
	cloud_cover: float,
	storm_influence: float,
	cloud_pattern_seed: float,
	night_factor: float,
	clock: float
) -> CloudLayerMix:
	var result := CloudLayerMix.new()
	var ordinary_weather := 1.0 - clampf(storm_influence, 0.0, 1.0)
	# Each layer waxes and wanes on its own slow, non-periodic clock (layered value
	# noise over elapsed time), so the sky is a shifting blend of different layers in
	# different proportions rather than one looping pulse. Thin high layers appear at
	# a lower coverage than the heavy cumulus, so partly-cloudy skies read as a mix.
	var t := clock * 0.004
	var cumulus_drift := _drift(t, cloud_pattern_seed + 3.0, 1.0)
	var cirrus_drift := _drift(t, cloud_pattern_seed + 21.0, 0.62)
	var elongated_drift := _drift(t, cloud_pattern_seed + 47.0, 0.83)
	var cumulus_presence := smoothstep(0.06, 0.34, cloud_cover)
	var thin_presence := smoothstep(0.0, 0.22, cloud_cover)

	result.cumulus = cumulus_presence * lerpf(0.32, 1.0, cumulus_drift)
	result.cumulus *= lerpf(1.0, 0.22, storm_influence)
	result.cumulus = maxf(result.cumulus, smoothstep(0.5, 0.85, cloud_cover) * 0.7)

	# Cirrus streaks coexist with cumulus (like the reference sky) instead of
	# vanishing as cover rises. A storm front scrubs them out.
	result.cirrus = lerpf(0.2, 0.62, cirrus_drift) * thin_presence * ordinary_weather

	# Elongated mid-altitude ribbons carry most of the "partly cloudy" texture.
	result.elongated = (0.25 + smoothstep(0.05, 0.55, cloud_cover) * 0.75)
	result.elongated *= lerpf(0.3, 1.0, elongated_drift)
	result.elongated *= smoothstep(0.03, 0.4, cloud_cover) * lerpf(1.0, 0.3, storm_influence)
	result.elongated = clampf(result.elongated, 0.0, 1.0)

	result.storm = clampf(storm_influence, 0.0, 1.0)

	# Night simplifies to the big readable cumulus masses; the high-frequency thin
	# layers fade to almost nothing so they do not smear the star field.
	result.cumulus *= lerpf(1.0, 0.85, night_factor)
	result.cirrus *= lerpf(1.0, 0.06, night_factor)
	result.elongated *= lerpf(1.0, 0.1, night_factor)
	return result


func _drift(t: float, seed: float, freq: float) -> float:
	# Smooth, non-periodic 0..1 wander from layered value noise sampled along the
	# weather clock. Remapped so it uses most of the 0..1 range.
	var raw := _fbm(Vector2(t * freq + seed, seed * 1.7 + 4.0))
	return clampf((raw - 0.28) / 0.44, 0.0, 1.0)


func _cloud_sun_visibility(
	sun_direction: Vector3,
	cover: float,
	wind_offset: Vector2,
	cloud_layers: CloudLayerMix
) -> float:
	var horizon := sun_direction.y
	var projection_scale := maxf(horizon + 0.55, 0.55)
	var uv := Vector2(sun_direction.x, sun_direction.z) / projection_scale
	uv *= CLOUD_SCALE * 1.6
	# Match the shader's slow cumulus drift using integrated wind displacement.
	uv += wind_offset
	var tower_direction := (
		sun_direction
		+ Vector3(wind_offset.x * 0.12, 0.0, wind_offset.y * 0.12)
	).normalized()
	var cloud_field := maxf(
		_layered_cloud_field(uv, cover),
		_tower_cloud_field(tower_direction)
	)
	var coverage_curve := pow(cover, 0.55)
	var coverage := lerpf(CLOUD_COVERAGE_MIN_CLOUDS, CLOUD_COVERAGE_MAX_CLOUDS, coverage_curve)
	var cumulus_dissolve := pow(1.0 - cloud_layers.cumulus, 1.4)
	var shape_coverage := coverage + cumulus_dissolve * 0.22
	var density := smoothstep(shape_coverage, shape_coverage + CLOUD_EDGE_SOFTNESS, cloud_field)
	density *= smoothstep(0.0, 0.14, cloud_layers.cumulus)
	# Only a storm seals the sun away; fair coverage just dapples it.
	var ceiling_amount := smoothstep(0.08, 0.96, cloud_layers.storm) * 0.92
	var cloud_alpha := maxf(density, ceiling_amount) * smoothstep(0.08, 0.34, horizon)
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


func _layered_cloud_field(uv: Vector2, overcast: float) -> float:
	var primary := _cloud_field(uv)
	var satellites := _cloud_field(uv * 1.62 + Vector2(7.4, -3.1))
	var satellite_cut := lerpf(0.20, 0.36, smoothstep(0.42, 0.88, overcast))
	return maxf(primary, satellites - satellite_cut)


func _tower_cloud_field(direction: Vector3) -> float:
	var height := maxf(direction.y, 0.0)
	var bearing := Vector2(direction.x, direction.z)
	bearing /= maxf(bearing.length(), 0.001)
	var family_seed := _fbm(bearing * 1.35 + Vector2(0.0, 4.0))
	var family := smoothstep(0.48, 0.67, family_seed)
	var crown_seed := _fbm(bearing * 2.1 + Vector2(5.0, 2.0))
	var crown_height := lerpf(0.20, 0.64, pow(crown_seed, 1.65))
	var base := smoothstep(0.015, 0.075, height)
	var crown := 1.0 - smoothstep(crown_height - 0.055, crown_height + 0.035, height)
	var along := bearing.dot(Vector2(0.82, 0.57).normalized())
	var across := bearing.dot(Vector2(-0.57, 0.82).normalized())
	var billows := _cellular_billow(Vector2(along * 3.15 + across * 0.72, height * 7.2) + Vector2(1.7, 9.4))
	var erosion := _fbm(Vector2(across * 5.4 + along, height * 9.0) + Vector2(12.0, 3.0))
	var body := 0.50 + billows * 0.31 + erosion * 0.12
	return family * base * crown * body


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
