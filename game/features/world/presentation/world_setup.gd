class_name WorldSetup
extends Node

const SelectionMarkerScene = preload("res://game/features/world/presentation/selection_marker.tscn")
const PreviewEntranceMarkerScene = preload("res://game/features/world/presentation/preview_entrance_marker.tscn")
const RainEffectScene = preload("res://game/features/world/presentation/rain_effect.tscn")
const SkyAndWeatherControllerScene = preload("res://game/features/world/presentation/sky_and_weather_controller.tscn")
const VillageBoundaryMarkersScene = preload("res://game/features/buildings/presentation/village_boundary_markers.tscn")
const VillageTerritoryOverlayScene = preload("res://game/features/buildings/presentation/village_territory_overlay.tscn")

var environment_node: WorldEnvironment
var world_environment: Environment
var sky_material: ShaderMaterial
var sun: DirectionalLight3D
var rain_effect: RainEffect
var sky_and_weather_controller: SkyAndWeatherController
var ground_body: StaticBody3D
var ground_mesh: MeshInstance3D
var terrain: Terrain3D
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
	environment_node = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node != null:
		world_environment = environment_node.environment
	sun = get_node_or_null("Sun") as DirectionalLight3D
	if DisplayServer.get_name() != "headless":
		var flare_rect := get_node_or_null("LensFlareLayer/ColorRect") as ColorRect
		if flare_rect != null:
			lens_flare_material = flare_rect.material as ShaderMaterial
	_build_sky()
	_build_boundary(parent)
	_build_rain_effect(parent)
	_build_sky_and_weather_controller(parent)
	_build_terrain(parent)
	_build_trail_overlay(parent)
	_build_selection_marker(parent)


func update_daylight(game_minutes: float, overcast: float, runtime_seconds: float) -> void:
	if sky_and_weather_controller != null:
		sky_and_weather_controller.update_daylight(game_minutes, overcast, runtime_seconds)


func _build_boundary(parent: Node) -> void:
	village_boundary_markers = VillageBoundaryMarkersScene.instantiate() as VillageBoundaryMarkers
	village_boundary_markers.configure(_cell_size)
	parent.add_child(village_boundary_markers)
	village_territory_overlay = VillageTerritoryOverlayScene.instantiate() as VillageTerritoryOverlay
	village_territory_overlay.configure(_cell_size)
	parent.add_child(village_territory_overlay)


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


func _build_rain_effect(parent: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	rain_effect = RainEffectScene.instantiate() as RainEffect
	rain_effect.name = "RainEffect"
	rain_effect.set_camera(_camera)
	parent.add_child(rain_effect)


func _build_sky_and_weather_controller(parent: Node) -> void:
	sky_and_weather_controller = SkyAndWeatherControllerScene.instantiate() as SkyAndWeatherController
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


func _build_terrain(parent: Node) -> void:
	terrain = parent.get_node_or_null("Terrain3dWorld/Terrain3D") as Terrain3D
	if terrain == null:
		terrain = parent.find_child("Terrain3D", true, false) as Terrain3D
	if terrain == null:
		push_error("Settlement scene is missing Terrain3D node.")
		return
	# Dynamic collision follows the active camera by default, keeping raycasts and
	# physics accurate without generating collision for the whole data set.


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
	selection_marker = SelectionMarkerScene.instantiate() as MeshInstance3D
	selection_material = selection_marker.material_override as StandardMaterial3D
	parent.add_child(selection_marker)
	preview_entrance_marker = _create_preview_entrance_marker(Color("4ecb71"))
	preview_back_entrance_marker = _create_preview_entrance_marker(Color("30343a"))
	parent.add_child(preview_entrance_marker)
	parent.add_child(preview_back_entrance_marker)


func _create_preview_entrance_marker(color: Color) -> MeshInstance3D:
	var marker := PreviewEntranceMarkerScene.instantiate() as MeshInstance3D
	var material := marker.material_override as StandardMaterial3D
	material.albedo_color = color
	material.emission = color
	return marker
