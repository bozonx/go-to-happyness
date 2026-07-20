class_name WorldSetup
extends Node

var environment_node: WorldEnvironment
var world_environment: Environment
var sky_material: ShaderMaterial
var sun: DirectionalLight3D
var rain_effect: RainEffect
var sky_and_weather_controller: SkyAndWeatherController
var voxel_terrain: VoxelLodTerrain
var voxel_tool: VoxelTool
var trail_overlay: MeshInstance3D
var trail_overlay_material: ShaderMaterial
var selection_marker: MeshInstance3D
var selection_material: StandardMaterial3D
var preview_entrance_marker: MeshInstance3D
var preview_back_entrance_marker: MeshInstance3D
var village_boundary_markers: VillageBoundaryMarkers
var village_territory_overlay: VillageTerritoryOverlay
var lens_flare_material: ShaderMaterial
var fireflies: Array[FirefliesEffect] = []

var _camera: Camera3D
var _cell_size: float
var _board_cells: int
var _trail_field: RefCounted


func setup(p_camera: Camera3D, p_cell_size: float, p_board_cells: int, p_trail_field: RefCounted) -> void:
	_camera = p_camera
	_cell_size = p_cell_size
	_board_cells = p_board_cells
	_trail_field = p_trail_field


func build(parent: Node) -> void:
	_build_environment(parent)
	_build_boundary(parent)
	_build_sun(parent)
	_build_sky()
	_build_lens_flare(parent)
	_build_rain_effect(parent)
	_build_sky_and_weather_controller(parent)
	_build_voxel_terrain(parent)
	_build_trail_overlay(parent)
	_build_selection_marker(parent)


func update_daylight(game_minutes: float, overcast: float, runtime_seconds: float) -> void:
	if sky_and_weather_controller != null:
		sky_and_weather_controller.update_daylight(game_minutes, overcast, runtime_seconds)


func _build_environment(parent: Node) -> void:
	environment_node = WorldEnvironment.new()
	world_environment = Environment.new()
	world_environment.background_mode = Environment.BG_COLOR
	world_environment.background_color = Color("78a9c5")
	_build_sky()
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color("d7ebef")
	world_environment.ambient_light_energy = 0.65
	world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.glow_enabled = true
	world_environment.glow_normalized = false
	world_environment.glow_intensity = 0.18
	world_environment.glow_strength = 0.72
	world_environment.glow_bloom = 0.05
	world_environment.volumetric_fog_enabled = true
	world_environment.volumetric_fog_density = 0.012
	world_environment.volumetric_fog_anisotropy = 0.35
	world_environment.volumetric_fog_length = 64.0
	world_environment.volumetric_fog_detail_spread = 0.5
	world_environment.fog_enabled = true
	world_environment.fog_light_color = Color("cfe2ed")
	world_environment.fog_density = 0.00035
	world_environment.fog_sky_affect = 0.0
	world_environment.volumetric_fog_sky_affect = 0.0
	environment_node.environment = world_environment
	parent.add_child(environment_node)


func _build_boundary(parent: Node) -> void:
	village_boundary_markers = VillageBoundaryMarkers.new()
	village_boundary_markers.configure(_cell_size)
	parent.add_child(village_boundary_markers)
	village_territory_overlay = VillageTerritoryOverlay.new()
	village_territory_overlay.configure(_cell_size)
	parent.add_child(village_territory_overlay)


func _build_sun(parent: Node) -> void:
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.light_volumetric_fog_energy = 2.0
	parent.add_child(sun)


func _build_sky() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var shader := load("res://game/features/world/presentation/sky_clouds.gdshader")
	sky_material = ShaderMaterial.new()
	sky_material.shader = shader
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	world_environment.background_mode = Environment.BG_SKY
	world_environment.sky = sky


func _build_lens_flare(parent: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var shader := load("res://game/features/world/presentation/lens_flare.gdshader")
	lens_flare_material = ShaderMaterial.new()
	lens_flare_material.shader = shader
	lens_flare_material.set_shader_parameter("u_sun_screen_pos", Vector2(0.5, 0.5))
	lens_flare_material.set_shader_parameter("u_intensity", 0.0)
	lens_flare_material.set_shader_parameter("u_aspect", 1.0)
	lens_flare_material.set_shader_parameter("u_sun_color", Color("fff2d1"))
	lens_flare_material.set_shader_parameter("u_time", 0.0)
	var rect := ColorRect.new()
	rect.material = lens_flare_material
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(rect)
	parent.add_child(layer)


func _build_rain_effect(parent: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	rain_effect = RainEffect.new()
	rain_effect.name = "RainEffect"
	rain_effect.set_camera(_camera)
	parent.add_child(rain_effect)


func _build_sky_and_weather_controller(parent: Node) -> void:
	sky_and_weather_controller = SkyAndWeatherController.new()
	parent.add_child(sky_and_weather_controller)
	sky_and_weather_controller.setup(
		_camera,
		sun,
		world_environment,
		sky_material,
		rain_effect,
		fireflies,
		lens_flare_material
	)


func _build_voxel_terrain(parent: Node) -> void:
	if DisplayServer.get_name() == "headless":
		_build_headless_ground(parent)
		return
	voxel_terrain = VoxelLodTerrain.new()
	voxel_terrain.mesher = VoxelMesherTransvoxel.new()
	var generator := VoxelGeneratorNoise2D.new()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.025
	generator.noise = noise
	generator.channel = VoxelBuffer.CHANNEL_SDF
	generator.height_start = -0.15
	generator.height_range = 0.3
	voxel_terrain.generator = generator
	voxel_terrain.generate_collisions = true
	voxel_terrain.view_distance = 192
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("5f8953")
	material.roughness = 0.95
	voxel_terrain.material = material
	parent.add_child(voxel_terrain)
	_camera.add_child(VoxelViewer.new())
	voxel_tool = voxel_terrain.get_voxel_tool()
	voxel_tool.channel = VoxelBuffer.CHANNEL_SDF


func _build_headless_ground(parent: Node) -> void:
	var ground := StaticBody3D.new()
	ground.name = "HeadlessGround"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_board_cells * _cell_size, 0.2, _board_cells * _cell_size)
	collision.shape = shape
	collision.position.y = -0.1
	ground.add_child(collision)
	parent.add_child(ground)


func _build_trail_overlay(parent: Node) -> void:
	if DisplayServer.get_name() == "headless" or _trail_field == null:
		return
	trail_overlay = MeshInstance3D.new()
	trail_overlay.name = "TrailOverlay"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(_board_cells * _cell_size, _board_cells * _cell_size)
	trail_overlay.mesh = mesh
	trail_overlay.position.y = 0.12
	trail_overlay_material = ShaderMaterial.new()
	trail_overlay_material.shader = load("res://game/features/routing/presentation/trail_overlay.gdshader")
	trail_overlay.material_override = trail_overlay_material
	parent.add_child(trail_overlay)


func _build_selection_marker(parent: Node) -> void:
	selection_marker = MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(1.0, 0.04, 1.0)
	selection_marker.mesh = marker_mesh
	selection_material = StandardMaterial3D.new()
	selection_material.albedo_color = Color(0.95, 0.79, 0.24, 0.55)
	selection_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_marker.material_override = selection_material
	selection_marker.visible = false
	parent.add_child(selection_marker)
	preview_entrance_marker = _create_preview_entrance_marker(Color("4ecb71"))
	preview_back_entrance_marker = _create_preview_entrance_marker(Color("30343a"))
	parent.add_child(preview_entrance_marker)
	parent.add_child(preview_back_entrance_marker)


func _create_preview_entrance_marker(color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.32
	mesh.bottom_radius = 0.32
	mesh.height = 0.08
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	marker.material_override = material
	marker.visible = false
	return marker
