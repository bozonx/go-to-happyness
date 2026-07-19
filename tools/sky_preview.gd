extends Node3D

# Standalone sky preview: reuses sky_clouds.gdshader with a sun, renders a few
# frames and saves screenshots at a couple of overcast/sun settings, then quits.
# Run: godot --path . res://tools/sky_preview.tscn

const OUT := "user://sky_preview"

var sky_material: ShaderMaterial
var sun: DirectionalLight3D
var shots := [
	{"name": "clear_noon", "overcast": 0.0, "sun_deg": Vector3(48.0, -32.0, 0.0)},
	{"name": "clear_low", "overcast": 0.0, "sun_deg": Vector3(8.0, -60.0, 0.0)},
	{"name": "storm", "overcast": 1.0, "sun_deg": Vector3(48.0, -32.0, 0.0)},
]
var idx := 0
var frame := 0

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var sky := Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://game/features/world/presentation/sky_clouds.gdshader")
	sky.sky_material = sky_material
	env.sky = sky
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color("fff2d1")
	add_child(sun)

	var cam := Camera3D.new()
	cam.rotation_degrees = Vector3(20.0, -32.0, 0.0) # look up toward the sun
	add_child(cam)
	cam.make_current()

	_apply(shots[0])

func _apply(s: Dictionary) -> void:
	sun.rotation_degrees = s["sun_deg"]
	var horizon := Color("6fa9d6")
	sky_material.set_shader_parameter("u_horizon_color", horizon)
	sky_material.set_shader_parameter("u_zenith_color", horizon.darkened(0.18))
	sky_material.set_shader_parameter("u_sun_color", Color("fff2d1"))
	sky_material.set_shader_parameter("u_overcast", s["overcast"])
	sky_material.set_shader_parameter("u_solar_intensity", 1.0)

func _process(_dt: float) -> void:
	frame += 1
	if frame < 8:
		return
	frame = 0
	var img := get_viewport().get_texture().get_image()
	var path := "%s_%s.png" % [OUT, shots[idx]["name"]]
	img.save_png(path)
	print("SAVED ", ProjectSettings.globalize_path(path))
	idx += 1
	if idx >= shots.size():
		get_tree().quit()
		return
	_apply(shots[idx])
