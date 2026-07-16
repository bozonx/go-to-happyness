class_name FirefliesEffect
extends GPUParticles3D

## Ambient firefly particles that float around a position at night.
## Place at the base of a tree or vegetation cluster; call set_night_factor()
## to fade the swarm in/out with the day-night cycle.

const FIREFLY_COLOR := Color(0.9, 1.0, 0.4)
const FIREFLY_EMISSION := Color(2.0, 2.5, 0.6)

var _night_factor := 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	lifetime = 8.0
	_setup_process_material()
	_setup_draw_material()
	emitting = false
	amount_ratio = 0.0


func set_night_factor(factor: float) -> void:
	_night_factor = clampf(factor, 0.0, 1.0)
	# Smooth fade: only emit when it's reasonably dark
	var visible_factor := smoothstep(0.35, 0.7, _night_factor)
	amount_ratio = visible_factor
	emitting = visible_factor > 0.01


func _setup_process_material() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(3.5, 3.0, 3.5)

	# No gravity — fireflies drift
	mat.gravity = Vector3.ZERO

	# Turbulence for slow organic wandering motion
	mat.turbulence_enabled = true
	mat.turbulence_noise_scale = 0.8
	mat.turbulence_influence_min = 0.03
	mat.turbulence_influence_max = 0.12

	# Small particles
	mat.scale_min = 0.03
	mat.scale_max = 0.06

	mat.color = FIREFLY_COLOR

	# Very slight upward drift
	mat.direction = Vector3(0.0, 0.05, 0.0)
	mat.spread = 15.0
	mat.initial_velocity_min = 0.02
	mat.initial_velocity_max = 0.06

	process_material = mat


func _setup_draw_material() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1

	var draw_mat := StandardMaterial3D.new()
	draw_mat.emission_enabled = true
	draw_mat.emission = FIREFLY_EMISSION
	draw_mat.emission_energy_multiplier = 3.0
	draw_mat.albedo_color = FIREFLY_COLOR
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.no_depth_test = false

	sphere.material = draw_mat
	draw_pass_1 = sphere
