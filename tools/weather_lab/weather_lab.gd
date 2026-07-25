extends Node3D

## Isolated visual lab for weather, sky, daylight, and atmospheric effects.
##
## Interactive: F-keys choose a scenario; 1-7 choose a camera; Left/Right move
## time; Up/Down change cloud cover; PageUp/PageDown change the storm front;
## R changes rain. GameplayCamera and GameplayLowCamera reproduce the in-game rig,
## which is the only way to judge effects that depend on where the player is looking.
## Batch: godot --path .
## res://tools/weather_lab/weather_lab.tscn -- --capture. Captures go to user://weather_lab.

const RainEffectScene := preload("res://game/features/world/presentation/rain_effect.tscn")
const FirefliesEffectScene := preload("res://game/features/world/presentation/fireflies_effect.tscn")
const SkyAndWeatherControllerScene := preload("res://game/features/world/presentation/sky_and_weather_controller.tscn")
const SkyShader := preload("res://game/features/world/presentation/sky_clouds.gdshader")

# Two authored regulators: "overcast" is fair-weather cloudiness (more/bigger white
# cumulus, sky stays blue) and "storm" is the storm front (grey murk + sealed ceiling
# + rain). Grey and haze come ONLY from storm, never from cloudiness.
const SCENARIOS := [
	{"name": "dawn_clear", "minutes": 360.0, "overcast": 0.0, "rain": 0.0},
	{"name": "noon_clear", "minutes": 720.0, "overcast": 0.0, "rain": 0.0},
	{"name": "noon_fair", "minutes": 720.0, "overcast": 0.2, "rain": 0.0, "camera": &"CloudCamera"},
	{"name": "noon_partly_cloudy", "minutes": 720.0, "overcast": 0.42, "rain": 0.0, "camera": &"CloudCamera"},
	{"name": "noon_cumulus_max", "minutes": 720.0, "overcast": 0.9, "rain": 0.0, "camera": &"CloudCamera"},
	{"name": "clear_cirrus", "minutes": 780.0, "overcast": 0.14, "rain": 0.0, "camera": &"CloudCamera"},
	{"name": "thin_elongated", "minutes": 630.0, "overcast": 0.4, "rain": 0.0, "camera": &"CloudCamera"},
	{"name": "cloud_context", "minutes": 720.0, "overcast": 0.45, "rain": 0.0, "camera": &"ContextCamera"},
	{"name": "cloud_zenith", "minutes": 720.0, "overcast": 0.5, "rain": 0.0, "camera": &"ZenithCamera"},
	{"name": "sunset_cloudy", "minutes": 1080.0, "overcast": 0.5, "rain": 0.0, "camera": &"CloudCamera"},
	{"name": "pre_storm", "minutes": 780.0, "overcast": 0.55, "storm": 0.55, "rain": 0.0, "camera": &"CloudCamera"},
	{"name": "cloud_storm", "minutes": 840.0, "overcast": 0.6, "storm": 1.0, "rain": 0.8, "camera": &"CloudCamera"},
	{"name": "storm_breakup", "minutes": 990.0, "overcast": 0.45, "storm": 0.32, "rain": 0.0, "camera": &"CloudCamera"},
	{"name": "night_stars", "minutes": 60.0, "overcast": 0.0, "rain": 0.0},
	{"name": "night_cloud_close", "minutes": 169.0, "overcast": 0.3, "rain": 0.0, "camera": &"CloudCamera"},
	{"name": "night_cumulus", "minutes": 60.0, "overcast": 0.55, "rain": 0.0, "camera": &"ZenithCamera"},
	{"name": "night_storm", "minutes": 60.0, "overcast": 0.6, "storm": 0.85, "rain": 0.4, "camera": &"ZenithCamera"},
	{"name": "night_rain", "minutes": 1320.0, "overcast": 0.6, "storm": 1.0, "rain": 1.0},
	{"name": "wind_aligned_layers", "minutes": 690.0, "overcast": 0.32, "rain": 0.0, "camera": &"ZenithCamera"},
	# Sun and moon as subjects. TrackingCamera aims itself at the body being studied,
	# so "the disc is in frame" holds at any time of day instead of depending on a
	# hand-placed viewpoint that only happens to catch it.
	{"name": "sun_noon", "minutes": 720.0, "overcast": 0.0, "rain": 0.0, "camera": &"TrackingCamera", "track": "sun"},
	# 17:30, not 18:30: solar_height reaches zero at hour 18, so a "golden hour" past
	# that point is simply after sunset with the disc already gone.
	{"name": "sun_golden_hour", "minutes": 1050.0, "overcast": 0.08, "rain": 0.0, "camera": &"TrackingCamera", "track": "sun"},
	# A moment the sun is genuinely covered. Occlusion depends on where the drifting
	# cloud field happens to sit, so the day and minute here are not decorative: at a
	# fixed noon the sun sits in the same gap of the noise field every time.
	{"name": "sun_behind_cloud", "minutes": 485.0, "overcast": 0.62, "rain": 0.0, "camera": &"TrackingCamera", "track": "sun", "day": 2},
	{"name": "sun_edge_of_cloud", "minutes": 500.0, "overcast": 0.62, "rain": 0.0, "camera": &"TrackingCamera", "track": "sun", "day": 2},
	{"name": "sunrise_low", "minutes": 400.0, "overcast": 0.18, "rain": 0.0, "camera": &"TrackingCamera", "track": "sun"},
	{"name": "moon_high", "minutes": 60.0, "overcast": 0.12, "rain": 0.0, "camera": &"TrackingCamera", "track": "moon"},
	{"name": "moon_rising", "minutes": 1290.0, "overcast": 0.15, "rain": 0.0, "camera": &"TrackingCamera", "track": "moon"},
	# Three nights spread across the synodic month, each at an hour when that night's
	# moon is actually above the horizon, so the captures compare phases rather than
	# an empty sky.
	{"name": "moon_phase_full", "minutes": 60.0, "overcast": 0.1, "rain": 0.0, "camera": &"TrackingCamera", "track": "moon", "day": 0},
	{"name": "moon_phase_gibbous", "minutes": 1320.0, "overcast": 0.1, "rain": 0.0, "camera": &"TrackingCamera", "track": "moon", "day": 11},
	{"name": "moon_phase_half", "minutes": 60.0, "overcast": 0.1, "rain": 0.0, "camera": &"TrackingCamera", "track": "moon", "day": 15},
	{"name": "moonlit_ground", "minutes": 90.0, "overcast": 0.25, "rain": 0.0, "camera": &"ContextCamera", "day": 0},
	# The flare as the player actually meets it. At the default gameplay pitch the sun
	# is off screen entirely, so only the veil can reach the frame; tilting down to the
	# horizon is what brings the disc and its full flare into view.
	{"name": "flare_gameplay_default", "minutes": 1020.0, "overcast": 0.1, "rain": 0.0, "camera": &"GameplayCamera", "track": "sun"},
	{"name": "flare_gameplay_low", "minutes": 1020.0, "overcast": 0.1, "rain": 0.0, "camera": &"GameplayLowCamera", "track": "sun"},
	{"name": "flare_gameplay_morning", "minutes": 430.0, "overcast": 0.1, "rain": 0.0, "camera": &"GameplayLowCamera", "track": "sun"},
	{"name": "flare_gameplay_edge", "minutes": 1020.0, "overcast": 0.1, "rain": 0.0, "camera": &"GameplayLowCamera", "track": "sun", "pitch": 30.0},
	{"name": "flare_centred", "minutes": 1020.0, "overcast": 0.1, "rain": 0.0, "camera": &"TrackingCamera", "track": "sun"},
]

const CAMERA_KEYS := [
	&"ContextCamera", &"CloudCamera", &"ZenithCamera", &"HorizonCamera", &"TrackingCamera",
	&"GameplayCamera", &"GameplayLowCamera",
]
# Mirrors the defaults in game/features/world/presentation/camera_controller.gd.
const GAMEPLAY_YAW := 42.0
const GAMEPLAY_PITCH := 52.0
const GAMEPLAY_DISTANCE := 30.0
const GAMEPLAY_TARGET := Vector3(0.0, 0.6, 0.0)
# The lowest pitch the player can tilt to, where the horizon and the sun come into
# view. clampf in rotate_yaw_pitch() stops at eight degrees.
const GAMEPLAY_LOW_PITCH := 10.0
# Roughly where the sun crosses the top edge of the frame: with a 75 degree vertical
# field of view the disc enters the picture once pitch + solar elevation drops under
# about 37 degrees. Just past that the disc is gone but its wash still reaches in,
# which is the case worth having a capture of.
const GAMEPLAY_EDGE_PITCH := 30.0
# Where the tracking camera parks the body it follows: a little above centre, the
# way a landscape painter frames a sky.
const TRACK_FRAMING_HEIGHT := 0.18

@onready var context_camera: Camera3D = $CameraRig/ContextCamera
@onready var cloud_camera: Camera3D = $CameraRig/CloudCamera
@onready var zenith_camera: Camera3D = $CameraRig/ZenithCamera
@onready var horizon_camera: Camera3D = $CameraRig/HorizonCamera
@onready var tracking_camera: Camera3D = $CameraRig/TrackingCamera
@onready var gameplay_camera: Camera3D = $CameraRig/GameplayCamera
@onready var gameplay_low_camera: Camera3D = $CameraRig/GameplayLowCamera
@onready var glare_rect: ColorRect = $SunGlareLayer/ColorRect
@onready var sun: DirectionalLight3D = $Sun
@onready var environment: Environment = $WorldEnvironment.environment
@onready var status: Label = $Interface/Status
@onready var interface: CanvasLayer = $Interface

var controller: SkyAndWeatherController
var sky_material: ShaderMaterial
var rain: RainEffect
var fireflies: Array = []
var camera: Camera3D
var game_minutes := 720.0
var overcast := 0.0
var storm_influence := 0.0
var rain_intensity := 0.0
var cloud_pattern_seed := 2.4
var runtime_seconds := 0.0
var lab_weather := WeatherState.new()
# Continuous game-time clock (never wraps) that drives cloud drift/morph, so scrubbing
# time scrolls the clouds. It also creeps forward on its own for a live preview.
var weather_minutes := 720.0
# Passive game-minutes per real second so the preview clouds always drift a little.
const WEATHER_PASSIVE_RATE := 24.0
var weather_time_scale := 1.0
var _capture_mode := false
var _capture_index := 0
var _frames_after_apply := 0
var glare_material: ShaderMaterial
# Which body the tracking camera frames: "" (free), "sun" or "moon".
var track_body := ""
# Pitch the gameplay-low rig uses for this scenario, so one camera can cover the whole
# range from "sun well in frame" to "sun just past the edge".
var track_pitch := GAMEPLAY_LOW_PITCH


func _ready() -> void:
	_configure_cameras()
	_select_camera(&"ContextCamera")
	_build_weather_rig()
	lab_weather.cloud_seed = cloud_pattern_seed
	lab_weather.wind_previous_direction = cloud_pattern_seed
	lab_weather.wind_direction = cloud_pattern_seed
	lab_weather.wind_base_strength = 0.42
	lab_weather.wind_gust_amount = 0.18
	lab_weather._rebuild_wind_displacement_samples()
	_capture_mode = OS.get_cmdline_user_args().has("--capture")
	if _capture_mode and DisplayServer.get_name() == "headless":
		push_error("Weather lab captures require a rendering driver. Run the documented non-headless capture command.")
		get_tree().quit()
		return
	if _capture_mode:
		_apply_scenario(0)
	_apply_state()
	_update_status()
	if _capture_mode:
		interface.visible = false


func _build_weather_rig() -> void:
	sky_material = ShaderMaterial.new()
	sky_material.shader = SkyShader
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky

	rain = RainEffectScene.instantiate() as RainEffect
	rain.set_camera(camera)
	add_child(rain)
	var swarm := FirefliesEffectScene.instantiate() as FirefliesEffect
	swarm.position = Vector3(-2.8, 0.0, -1.6)
	add_child(swarm)
	fireflies.append(swarm)

	# The production glare material, not null: passing null made the lab silently skip
	# the entire screen-space glare path it is supposed to be validating.
	glare_material = glare_rect.material as ShaderMaterial

	controller = SkyAndWeatherControllerScene.instantiate() as SkyAndWeatherController
	add_child(controller)
	controller.setup(camera, sun, environment, sky_material, rain, fireflies, glare_material)


func _configure_cameras() -> void:
	context_camera.look_at(Vector3(0.0, 1.4, -1.5))
	tracking_camera.look_at(Vector3(0.0, 8.0, -9.0))
	# Reproduce CameraController's rig exactly. The gameplay pitch is what decides
	# whether the sun is on screen at all, so a lab that only ever uses hand-placed
	# viewpoints cannot tell you what the player actually sees.
	_place_gameplay_camera(gameplay_camera, GAMEPLAY_PITCH)
	_place_gameplay_camera(gameplay_low_camera, GAMEPLAY_LOW_PITCH)


func _place_gameplay_camera(target: Camera3D, pitch_degrees: float, yaw_degrees := GAMEPLAY_YAW) -> void:
	var yaw := deg_to_rad(yaw_degrees)
	var pitch := deg_to_rad(pitch_degrees)
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)
	) * GAMEPLAY_DISTANCE
	target.position = GAMEPLAY_TARGET + offset
	target.look_at(GAMEPLAY_TARGET)
	cloud_camera.look_at(Vector3(0.0, 8.0, -9.0))
	zenith_camera.look_at(Vector3(0.0, 18.0, 0.0))
	horizon_camera.look_at(Vector3(0.0, 1.5, -22.0))


func _select_camera(camera_name: StringName) -> void:
	var next_camera := get_node_or_null(NodePath("CameraRig/%s" % camera_name)) as Camera3D
	if next_camera == null:
		push_error("Weather lab has no camera named %s" % camera_name)
		return
	camera = next_camera
	camera.make_current()
	if rain != null:
		rain.set_camera(camera)
	if controller != null:
		controller.setup(camera, sun, environment, sky_material, rain, fireflies, glare_material)


func _process(delta: float) -> void:
	runtime_seconds += delta
	if _capture_mode:
		_process_capture()
		return
	# One lab clock drives daylight, stars, cloud evolution and wind. Space proves
	# that every sky animation freezes when game time does.
	weather_minutes += delta * WEATHER_PASSIVE_RATE * weather_time_scale
	game_minutes = fposmod(weather_minutes, 1440.0)
	_handle_input(delta)
	_apply_state()
	_aim_tracking_camera()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode >= KEY_F1 and event.keycode < KEY_F1 + SCENARIOS.size():
		_apply_scenario(event.keycode - KEY_F1)
	if event.keycode >= KEY_1 and event.keycode < KEY_1 + CAMERA_KEYS.size():
		_select_camera(CAMERA_KEYS[event.keycode - KEY_1])
		_update_status()
	if event.keycode == KEY_R:
		rain_intensity = 1.0 - rain_intensity
		_update_status()
	if event.keycode == KEY_SPACE:
		weather_time_scale = 0.0 if weather_time_scale > 0.0 else 1.0
		_update_status()
	if event.keycode == KEY_EQUAL:
		weather_time_scale = minf(weather_time_scale * 2.0, 8.0) if weather_time_scale > 0.0 else 1.0
		_update_status()
	if event.keycode == KEY_MINUS:
		weather_time_scale = maxf(weather_time_scale * 0.5, 0.25)
		_update_status()
	if event.keycode == KEY_C:
		_save_capture("manual")


func _handle_input(delta: float) -> void:
	var changed := false
	if Input.is_key_pressed(KEY_LEFT):
		weather_minutes -= delta * 180.0
		changed = true
	if Input.is_key_pressed(KEY_RIGHT):
		weather_minutes += delta * 180.0
		changed = true
	if Input.is_key_pressed(KEY_UP):
		overcast += delta * 0.5
		changed = true
	if Input.is_key_pressed(KEY_DOWN):
		overcast -= delta * 0.5
		changed = true
	if Input.is_key_pressed(KEY_PAGEUP):
		storm_influence += delta * 0.5
		changed = true
	if Input.is_key_pressed(KEY_PAGEDOWN):
		storm_influence -= delta * 0.5
		changed = true
	game_minutes = fposmod(weather_minutes, 1440.0)
	overcast = clampf(overcast, 0.0, 1.0)
	storm_influence = clampf(storm_influence, 0.0, 1.0)
	if changed:
		_update_status()


func _apply_scenario(index: int) -> void:
	if index < 0 or index >= SCENARIOS.size():
		return
	var scenario: Dictionary = SCENARIOS[index]
	game_minutes = scenario["minutes"]
	# The day index moves the moon along its synodic cycle, which is the only way to
	# capture different phases: the phase is emergent geometry, not a parameter.
	weather_minutes = float(scenario.get("day", 0)) * 1440.0 + scenario["minutes"]
	overcast = scenario["overcast"]
	storm_influence = scenario.get("storm", 0.0)
	rain_intensity = scenario["rain"]
	track_body = str(scenario.get("track", ""))
	track_pitch = float(scenario.get("pitch", GAMEPLAY_LOW_PITCH))
	if scenario.has("camera"):
		_select_camera(scenario["camera"])
	else:
		_select_camera(&"ContextCamera")
	_update_status()


func _aim_tracking_camera() -> void:
	# Frames whichever body the scenario studies, using the very directions the sky
	# was drawn from, so a "sun in frame" preset holds at every hour.
	if track_body == "" or controller == null:
		return
	var direction := (
		controller.current_moon_direction if track_body == "moon"
		else controller.current_sun_direction
	)
	if direction.length_squared() < 0.001:
		return
	if camera == gameplay_camera or camera == gameplay_low_camera:
		# The gameplay rig keeps its pitch — that is the whole point of these presets —
		# and only turns to face the body. Without this the default yaw of 42 degrees
		# points away from the sun, and "no flare" would only mean "wrong direction".
		var yaw := rad_to_deg(atan2(-direction.x, -direction.z))
		var pitch := GAMEPLAY_PITCH if camera == gameplay_camera else track_pitch
		_place_gameplay_camera(camera, pitch, yaw)
		return
	if camera != tracking_camera:
		return
	var target := tracking_camera.global_position + direction * 200.0
	# Drop the aim point slightly so the body sits above centre rather than dead on it.
	target.y -= 200.0 * TRACK_FRAMING_HEIGHT
	tracking_camera.look_at(target, Vector3.UP)


func _apply_state() -> void:
	var precipitation := (
		WeatherState.Precipitation.RAIN if rain_intensity > 0.0
		else WeatherState.Precipitation.NONE
	)
	controller.update_daylight(
		game_minutes,
		overcast,
		rain_intensity,
		runtime_seconds,
		storm_influence,
		cloud_pattern_seed,
		_lab_wind(),
		weather_minutes,
		precipitation,
		lab_weather.wind_displacement_at(weather_minutes)
	)


func _lab_wind() -> Vector2:
	# Exercise the same stable daily bearing and broad strength changes as gameplay.
	var angle := lab_weather.wind_direction_at(weather_minutes)
	var strength := lab_weather.wind_strength_at(weather_minutes)
	strength = lerpf(strength, 1.0, storm_influence * 0.85)
	return Vector2(cos(angle), sin(angle)) * strength


func _process_capture() -> void:
	_frames_after_apply += 1
	_apply_state()
	_aim_tracking_camera()
	# Let the sky and GPU particles settle before every deterministic capture.
	if _frames_after_apply < 24:
		return
	_save_capture(str(SCENARIOS[_capture_index]["name"]))
	_capture_index += 1
	if _capture_index >= SCENARIOS.size():
		get_tree().quit()
		return
	_apply_scenario(_capture_index)
	_frames_after_apply = 0


func _save_capture(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("Weather lab capture needs a rendering driver; the active headless dummy renderer has no viewport texture.")
		return
	var path := "user://weather_lab/%s.png" % name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://weather_lab"))
	var result := image.save_png(path)
	if result != OK:
		push_error("Weather lab could not save %s (error %s)" % [path, result])
		return
	# Sun visibility and key energy are printed alongside every capture: how the world
	# lighting answers a cloud crossing the sun is a number, not something to squint at.
	print("WEATHER_LAB_CAPTURE %s sun_visibility=%.2f key_energy=%.2f moon_light=%.3f" % [
		ProjectSettings.globalize_path(path),
		controller.current_sun_visibility,
		sun.light_energy,
		0.0 if controller.moon_light == null else controller.moon_light.light_energy,
	])


func _update_status() -> void:
	var hour := int(game_minutes) / 60
	var minute := int(game_minutes) % 60
	var lunar_day := weather_minutes / 1440.0
	status.text = "Weather lab · %s%s | day %.1f %02d:%02d  sky x%.2f  clouds %.0f%%  front %.0f%%  rain %.0f%%\nF1–F%d presets • 1–%d cameras • Space pause • -/= speed • ←/→ time • ↑/↓ clouds • PgUp/PgDn front • R rain • C screenshot" % [
		camera.name,
		"" if track_body == "" else " →" + track_body,
		lunar_day,
		hour,
		minute,
		weather_time_scale,
		overcast * 100.0,
		storm_influence * 100.0,
		rain_intensity * 100.0,
		SCENARIOS.size(),
		CAMERA_KEYS.size(),
	]
