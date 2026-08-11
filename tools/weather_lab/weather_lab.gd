extends Node3D

## Isolated visual lab for the world environment: weather, sky, daylight, season
## and atmospherics (`world_environment.md` §17).
##
## It has **no weather logic of its own**. It drives a real `EnvironmentDirector`
## and renders the snapshot that comes back, exactly as a cutscene will — which is
## what makes it evidence about the game rather than about the lab.
##
## Interactive: F-keys choose a scenario; 1-7 choose a camera; Left/Right move
## time; Up/Down change cloud cover; PageUp/PageDown change the storm front;
## R toggles precipitation; `[`/`]` step the **day of year**, because a low winter
## sun, a short day and a snowfall cannot be inspected with an hour dial alone.
## GameplayCamera and GameplayLowCamera reproduce the in-game rig, which is the
## only way to judge effects that depend on where the player is looking.
## Batch: godot --path .
## res://tools/weather_lab/weather_lab.tscn -- --capture. Captures go to user://weather_lab.

const PrecipitationEffectScene := preload("res://game/features/world/presentation/precipitation_effect.tscn")
const FirefliesEffectScene := preload("res://game/features/world/presentation/ambient/fireflies_effect.tscn")
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
	# Season. None of these can be reached with an hour dial: the sun's arc, the
	# length of the day and what falls out of the sky are all functions of the day
	# of year (`world_environment.md` §11, §19.14), so the lab has that axis too.
	# `solar_arc_*` are the same hour on the two solstices — the pair is the proof
	# that winter reads visually at all.
	{"name": "solar_arc_summer", "minutes": 720.0, "overcast": 0.1, "rain": 0.0, "day_of_year": 172, "camera": &"HorizonCamera"},
	{"name": "solar_arc_winter", "minutes": 720.0, "overcast": 0.1, "rain": 0.0, "day_of_year": 355, "camera": &"HorizonCamera"},
	{"name": "winter_noon", "minutes": 720.0, "overcast": 0.35, "rain": 0.0, "day_of_year": 20, "camera": &"ContextCamera"},
	{"name": "winter_snowfall", "minutes": 660.0, "overcast": 0.62, "storm": 0.6, "rain": 0.9, "day_of_year": 20, "climate": &"polar", "camera": &"ContextCamera"},
	{"name": "winter_dusk_low_sun", "minutes": 930.0, "overcast": 0.2, "rain": 0.0, "day_of_year": 355, "camera": &"TrackingCamera", "track": "sun"},
	# Fog is a snapshot value with the scene atmosphere as its consumer (§12); the
	# pre-dawn window on a clear night is where it is thickest.
	{"name": "foggy_morning", "minutes": 330.0, "overcast": 0.05, "rain": 0.0, "day_of_year": 280, "camera": &"HorizonCamera"},
	{"name": "polar_summer_midnight", "minutes": 0.0, "overcast": 0.15, "rain": 0.0, "day_of_year": 172, "climate": &"polar", "latitude": 78.0, "camera": &"HorizonCamera"},
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
var precipitation: PrecipitationEffect
var camera: Camera3D
var game_minutes := 720.0
var overcast := 0.0
var storm_influence := 0.0
var rain_intensity := 0.0
var cloud_pattern_seed := 2.4
var runtime_seconds := 0.0
## The production director, not a lab-local weather model (`world_environment.md`
## §17). The lab poses the environment through it exactly as a cutscene does, so
## what these captures show is what the game will show.
var director := EnvironmentDirector.new()
var day_of_year := 172
var climate: StringName = &"temperate"
var latitude := 54.0
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
	_configure_director()
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


## Poses the environment for the current lab settings. Every scenario goes
## through here, so a preset is a set of director calls and never a private path
## into the sky. The session is created frozen (`dynamic: false`), which is the
## same SCRIPTED mode a staged scene uses (§14).
func _configure_director() -> void:
	director.configure(climate, day_of_year, int(game_minutes), latitude, &"clear", 7, false)
	director.minutes_per_second = WEATHER_PASSIVE_RATE


func _build_weather_rig() -> void:
	sky_material = ShaderMaterial.new()
	sky_material.shader = SkyShader
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky

	precipitation = PrecipitationEffectScene.instantiate() as PrecipitationEffect
	precipitation.set_camera(camera)
	add_child(precipitation)
	# The swarm needs no wiring any more: it joins the ambient-effect group in
	# `_ready` and the controller publishes the snapshot to the whole group.
	var swarm := FirefliesEffectScene.instantiate() as FirefliesEffect
	swarm.position = Vector3(-2.8, 0.0, -1.6)
	add_child(swarm)

	# The production glare material, not null: passing null made the lab silently skip
	# the entire screen-space glare path it is supposed to be validating.
	glare_material = glare_rect.material as ShaderMaterial

	controller = SkyAndWeatherControllerScene.instantiate() as SkyAndWeatherController
	add_child(controller)
	controller.setup(camera, sun, environment, sky_material, precipitation, glare_material)


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
	if precipitation != null:
		precipitation.set_camera(camera)
	if controller != null:
		controller.setup(camera, sun, environment, sky_material, precipitation, glare_material)


func _process(delta: float) -> void:
	runtime_seconds += delta
	if _capture_mode:
		_process_capture()
		return
	# One lab clock drives daylight, stars, cloud evolution and wind. Space proves
	# that every sky animation freezes when game time does.
	director.scrub_minutes(delta * WEATHER_PASSIVE_RATE * weather_time_scale)
	game_minutes = director.minute_of_day()
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
	# The day-of-year axis. Without it there is nothing to inspect a winter sun,
	# a short day or a snowfall with (§17).
	if event.keycode == KEY_BRACKETLEFT:
		_step_day(-7)
	if event.keycode == KEY_BRACKETRIGHT:
		_step_day(7)


func _step_day(days: int) -> void:
	director.scrub_minutes(float(days) * 1440.0)
	day_of_year = director.day_of_year()
	_update_status()


func _handle_input(delta: float) -> void:
	var changed := false
	if Input.is_key_pressed(KEY_LEFT):
		director.scrub_minutes(-delta * 180.0)
		changed = true
	if Input.is_key_pressed(KEY_RIGHT):
		director.scrub_minutes(delta * 180.0)
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
	game_minutes = director.minute_of_day()
	overcast = clampf(overcast, 0.0, 1.0)
	storm_influence = clampf(storm_influence, 0.0, 1.0)
	if changed:
		_update_status()


func _apply_scenario(index: int) -> void:
	if index < 0 or index >= SCENARIOS.size():
		return
	var scenario: Dictionary = SCENARIOS[index]
	game_minutes = scenario["minutes"]
	climate = StringName(scenario.get("climate", &"temperate"))
	latitude = float(scenario.get("latitude", 54.0))
	day_of_year = int(scenario.get("day_of_year", 172))
	_configure_director()
	# The `day` index moves the moon along its synodic cycle, which is the only way
	# to capture different phases: the phase is emergent geometry, not a parameter.
	director.scrub_minutes(float(scenario.get("day", 0)) * 1440.0)
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
	# The lab holds the sky through the director's scripted mode, with a zero
	# transition so a capture is a function of the preset and not of the frame it
	# was taken on. It never reaches into the sky controller or the weather rules —
	# that second path is exactly what §2 exists to prevent.
	director.set_sky(overcast, storm_influence, 0.0)
	if rain_intensity > 0.0:
		director.force_precipitation(600.0, 0.0)
	else:
		director.stop_precipitation(0.0)
	var snapshot := director.snapshot()
	# The regulators are absolute here: a blend is what a cutscene gets, but a
	# preset asking for 62 % cover must capture 62 % cover.
	snapshot.cloud_cover = overcast
	snapshot.storm_influence = storm_influence
	snapshot.precipitation_intensity = rain_intensity
	# The lab poses a moment rather than living through one, so the fade-in at the
	# edge of the forced window would otherwise report "nothing is falling" at the
	# very minute the preset asks for precipitation. What falls is still decided the
	# one way it is decided anywhere — by the climate's snow chance (§10).
	if rain_intensity > 0.0:
		snapshot.precipitation = (
			EnvironmentSnapshot.Precipitation.SNOW if snapshot.snow_chance >= 0.5
			else EnvironmentSnapshot.Precipitation.RAIN
		)
	else:
		snapshot.precipitation = EnvironmentSnapshot.Precipitation.NONE
	snapshot.cloud_seed = cloud_pattern_seed
	controller.update_daylight(snapshot, runtime_seconds)
	# Ветер — часть снимка, и лаборатория обязана рисовать его так же, как игра
	# (`world_environment.md` §9). Без этой строки шторм в лаборатории выглядел
	# штилем: облака неслись, а листва под ними стояла, — и снимок переставал быть
	# свидетельством об игре.
	WorldWind.apply(snapshot)


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
	var snapshot := director.snapshot()
	print("WEATHER_LAB_CAPTURE %s sun_visibility=%.2f key_energy=%.2f moon_light=%.3f season=%s day=%d temp=%.1f daylight=%.1f visibility=%.0f" % [
		ProjectSettings.globalize_path(path),
		controller.current_sun_visibility,
		sun.light_energy,
		0.0 if controller.moon_light == null else controller.moon_light.light_energy,
		snapshot.season,
		snapshot.day_of_year,
		snapshot.temperature,
		snapshot.daylight_hours,
		snapshot.visibility_range,
	])


func _update_status() -> void:
	var snapshot := director.snapshot()
	var hour := int(game_minutes) / 60
	var minute := int(game_minutes) % 60
	var falling := "снег" if snapshot.is_snowing() else ("дождь" if snapshot.is_precipitating() else "сухо")
	status.text = "Weather lab \u00b7 %s%s | %s д.%d %02d:%02d  x%.2f  облака %.0f%%  фронт %.0f%%  осадки %.0f%%\n%+.0f\u00b0C \u00b7 %s \u00b7 св.день %.1f ч \u00b7 видимость %.0f м\nF1\u2013F%d пресеты \u2022 1\u2013%d камеры \u2022 Space пауза \u2022 -/= скорость \u2022 \u2190/\u2192 время \u2022 [/] день года \u2022 \u2191/\u2193 облака \u2022 PgUp/PgDn фронт \u2022 R осадки \u2022 C снимок" % [
		camera.name,
		"" if track_body == "" else " \u2192" + track_body,
		snapshot.season,
		snapshot.day_of_year,
		hour,
		minute,
		weather_time_scale,
		overcast * 100.0,
		storm_influence * 100.0,
		rain_intensity * 100.0,
		snapshot.temperature,
		falling,
		snapshot.daylight_hours,
		snapshot.visibility_range,
		SCENARIOS.size(),
		CAMERA_KEYS.size(),
	]
