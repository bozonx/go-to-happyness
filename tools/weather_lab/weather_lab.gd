extends Node3D

## Isolated visual lab for weather, sky, daylight, and atmospheric effects.
##
## Interactive: F1-F11 choose a scenario; 1-4 choose a camera; Left/Right move
## time; Up/Down change cloud cover; R changes rain. Batch: godot --path .
## res://tools/weather_lab/weather_lab.tscn -- --capture. Captures go to user://weather_lab.

const RainEffectScene := preload("res://game/features/world/presentation/rain_effect.tscn")
const FirefliesEffectScene := preload("res://game/features/world/presentation/fireflies_effect.tscn")
const SkyAndWeatherControllerScene := preload("res://game/features/world/presentation/sky_and_weather_controller.tscn")
const SkyShader := preload("res://game/features/world/presentation/sky_clouds.gdshader")

const SCENARIOS := [
	{"name": "dawn_clear", "minutes": 360.0, "overcast": 0.0, "rain": 0.0},
	{"name": "noon_clear", "minutes": 720.0, "overcast": 0.0, "rain": 0.0},
	{"name": "noon_fair", "minutes": 720.0, "overcast": 0.14, "rain": 0.0, "camera": &"CloudCamera"},
	{"name": "noon_partly_cloudy", "minutes": 720.0, "overcast": 0.32, "rain": 0.0, "camera": &"CloudCamera"},
	{"name": "sunset_cloudy", "minutes": 1080.0, "overcast": 0.58, "rain": 0.0, "camera": &"CloudCamera"},
	{"name": "noon_overcast", "minutes": 720.0, "overcast": 0.82, "rain": 0.0, "camera": &"CloudCamera"},
	{"name": "cloud_storm", "minutes": 840.0, "overcast": 0.96, "rain": 0.8, "camera": &"CloudCamera"},
	{"name": "night_stars", "minutes": 60.0, "overcast": 0.0, "rain": 0.0},
	{"name": "night_partly_cloudy", "minutes": 60.0, "overcast": 0.36, "rain": 0.0, "camera": &"ZenithCamera"},
	{"name": "night_overcast", "minutes": 60.0, "overcast": 0.84, "rain": 0.0, "camera": &"ZenithCamera"},
	{"name": "night_rain", "minutes": 1320.0, "overcast": 0.96, "rain": 1.0},
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
var rain_intensity := 0.0
var runtime_seconds := 0.0
var _capture_mode := false
var _capture_index := 0
var _frames_after_apply := 0


func _ready() -> void:
	_configure_cameras()
	_select_camera(&"ContextCamera")
	_build_weather_rig()
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
	if event.keycode == KEY_C:
		_save_capture("manual")


func _handle_input(delta: float) -> void:
	var changed := false
	if Input.is_key_pressed(KEY_LEFT):
		game_minutes -= delta * 180.0
		changed = true
	if Input.is_key_pressed(KEY_RIGHT):
		game_minutes += delta * 180.0
		changed = true
	if Input.is_key_pressed(KEY_UP):
		overcast += delta * 0.5
		changed = true
	if Input.is_key_pressed(KEY_DOWN):
		overcast -= delta * 0.5
		changed = true
	game_minutes = fposmod(game_minutes, 1440.0)
	overcast = clampf(overcast, 0.0, 1.0)
	if changed:
		_update_status()


func _apply_scenario(index: int) -> void:
	if index < 0 or index >= SCENARIOS.size():
		return
	var scenario: Dictionary = SCENARIOS[index]
	game_minutes = scenario["minutes"]
	overcast = scenario["overcast"]
	rain_intensity = scenario["rain"]
	if scenario.has("camera"):
		_select_camera(scenario["camera"])
	else:
		_select_camera(&"ContextCamera")
	_update_status()


func _apply_state() -> void:
	controller.update_daylight(game_minutes, overcast, rain_intensity, runtime_seconds)


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
	status.text = "Weather lab · %s | %02d:%02d  clouds %.0f%%  rain %.0f%%\nF1–F11 presets • 1 context · 2 clouds · 3 zenith · 4 horizon • ←/→ time • ↑/↓ clouds • R rain • C screenshot" % [camera.name, hour, minute, overcast * 100.0, rain_intensity * 100.0]
