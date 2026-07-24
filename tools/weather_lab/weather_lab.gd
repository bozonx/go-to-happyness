extends Node3D

## Isolated visual lab for weather, sky, daylight, and atmospheric effects.
##
## Interactive: F1-F19 choose a scenario; 1-4 choose a camera; Left/Right move
## time; Up/Down change cloud cover; PageUp/PageDown change the storm front;
## R changes rain. Batch: godot --path .
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
]

@onready var context_camera: Camera3D = $CameraRig/ContextCamera
@onready var cloud_camera: Camera3D = $CameraRig/CloudCamera
@onready var zenith_camera: Camera3D = $CameraRig/ZenithCamera
@onready var horizon_camera: Camera3D = $CameraRig/HorizonCamera
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

	controller = SkyAndWeatherControllerScene.instantiate() as SkyAndWeatherController
	add_child(controller)
	controller.setup(camera, sun, environment, sky_material, rain, fireflies, null)


func _configure_cameras() -> void:
	context_camera.look_at(Vector3(0.0, 1.4, -1.5))
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
		controller.setup(camera, sun, environment, sky_material, rain, fireflies, null)


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


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode >= KEY_F1 and event.keycode < KEY_F1 + SCENARIOS.size():
		_apply_scenario(event.keycode - KEY_F1)
	if event.keycode >= KEY_1 and event.keycode <= KEY_4:
		_select_camera([&"ContextCamera", &"CloudCamera", &"ZenithCamera", &"HorizonCamera"][event.keycode - KEY_1])
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
	weather_minutes = scenario["minutes"]
	overcast = scenario["overcast"]
	storm_influence = scenario.get("storm", 0.0)
	rain_intensity = scenario["rain"]
	if scenario.has("camera"):
		_select_camera(scenario["camera"])
	else:
		_select_camera(&"ContextCamera")
	_update_status()


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
	print("WEATHER_LAB_CAPTURE ", ProjectSettings.globalize_path(path))


func _update_status() -> void:
	var hour := int(game_minutes) / 60
	var minute := int(game_minutes) % 60
	status.text = "Weather lab · %s | %02d:%02d  sky x%.2f  clouds %.0f%%  front %.0f%%  rain %.0f%%\nF1–F19 presets • 1–4 cameras • Space pause • -/= speed • ←/→ time • ↑/↓ clouds • PgUp/PgDn front • R rain • C screenshot" % [camera.name, hour, minute, weather_time_scale, overcast * 100.0, storm_influence * 100.0, rain_intensity * 100.0]
