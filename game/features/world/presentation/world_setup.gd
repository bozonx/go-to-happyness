class_name WorldSetup
extends Node

const SelectionMarkerScene = preload("res://game/features/world/presentation/selection_marker.tscn")
const PreviewEntranceMarkerScene = preload("res://game/features/world/presentation/preview_entrance_marker.tscn")
const PrecipitationEffectScene = preload("res://game/features/world/presentation/precipitation_effect.tscn")
const SkyAndWeatherControllerScene = preload("res://game/features/world/presentation/sky_and_weather_controller.tscn")
@export var village_boundary_markers_scene: PackedScene = preload("res://game/features/buildings/presentation/village_boundary_markers.tscn")
@export var village_territory_overlay_scene: PackedScene = preload("res://game/features/buildings/presentation/village_territory_overlay.tscn")
@export var trail_overlay_shader: Shader = preload("res://game/features/routing/presentation/trail_overlay.gdshader")

var environment_node: WorldEnvironment
var world_environment: Environment
var sky_material: ShaderMaterial
var sun: DirectionalLight3D
var precipitation_effect: PrecipitationEffect
var sky_and_weather_controller: SkyAndWeatherController
## The board's ground (grid_terrain_system.md §13). Owned by the territory scene,
## published here because it is the one place that answers "how high is the
## ground at X" for everything else.
var terrain_grid: TerrainGrid
## The one owner of writes to that ground (§13, §14). The session has one even
## though nothing in the game sculpts yet: `BuildingPlacementService` writes the
## building pad and its anchors through it, so undo and the cascade see one transaction.
var terrain_service := TerrainService.new()
## The board's water (§9), published beside the ground for the same reason: it is
## what routing and presentation both read.
var water_grid: WaterGrid
## The one owner of writes to that water, for the same reason `terrain_service`
## is here: water is authored and never simulated, but ice is not authoring — the
## environment freezes and thaws bodies during a session (`world_environment.md`
## §13), and a write around the transaction boundary is one navigation never sees.
var water_service := WaterService.new()
## Where a citizen can stand to draw water. Owned here because it is derived from
## the two grids this node publishes and from nothing else (§9.2).
var water_access := WaterAccessService.new()
var trail_overlay: MeshInstance3D
var trail_overlay_material: ShaderMaterial
var selection_marker: MeshInstance3D
var selection_material: StandardMaterial3D
var preview_entrance_marker: MeshInstance3D
var preview_back_entrance_marker: MeshInstance3D
var hero_build_radius_marker: MeshInstance3D
var village_boundary_markers: VillageBoundaryMarkers
var village_territory_overlay: VillageTerritoryOverlay
var sun_glare_material: ShaderMaterial
## Named map entities are loaded once with the map and projected into the
## territory. The runtime record is data; this node owns only its presentation.
var map_entity_runtime := MapEntityRuntime.new()
var map_entity_presenter: MapEntityPresenter = null
## Authored buildings from `placements[]`, projected once from their immutable
## blueprint references. Their zone and routing metadata stays on the root node
## so the same building runtime readers used by constructed buildings can read it.
var map_placement_presenter: MapPlacementPresenter = null
## Безымянное массовое наполнение карты. Отдельная нода, потому что она рисует
## буферами, а не сценами: у объектов этого слоя нод нет вовсе.
var map_scatter_world: ScatterWorld = null

var _camera: Camera3D
var _cell_size: float
var _board_cells: int
var _trail_field: RefCounted
## The launched map. Its terrain and water grids are the session's world.
var _map_document: MapDocument = null
## The territory scene that owns the ground and the water. Kept because the
## retained as the session's territory projection.
var _territory: TerritoryBase = null
## Entrance the session began at; entities bound to another one are not built
## (`map_start.md` §3.2).
var _start_option: StringName = &""
## Components the host module builds itself; the presenter skips their entities
## instead of adding a second, inert copy beside the live one.
var _claimed_components: Array[StringName] = []


func setup(
	p_camera: Camera3D,
	p_cell_size: float,
	p_board_cells: int,
	p_trail_field: RefCounted,
	p_map_document: MapDocument,
	p_start_option: StringName = &"",
	p_claimed_components: Array[StringName] = [],
) -> void:
	_camera = p_camera
	_cell_size = p_cell_size
	_board_cells = p_board_cells
	_trail_field = p_trail_field
	_map_document = p_map_document
	_start_option = p_start_option
	_claimed_components = p_claimed_components


func build(parent: Node) -> void:
	environment_node = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node != null:
		world_environment = environment_node.environment
	sun = get_node_or_null("Sun") as DirectionalLight3D
	if DisplayServer.get_name() != "headless":
		var glare_rect := get_node_or_null("SunGlareLayer/ColorRect") as ColorRect
		if glare_rect != null:
			sun_glare_material = glare_rect.material as ShaderMaterial
	_build_sky()
	_build_terrain(parent)
	_build_map_placements()
	_build_map_entities()
	_build_map_scatter()
	_build_boundary(parent)
	_build_precipitation_effect(parent)
	_build_sky_and_weather_controller(parent)
	_build_trail_overlay(parent)
	_build_selection_marker(parent)


## Frees the projections which are deliberately attached to the game host and
## territory rather than below this setup node. `WorldSession.dispose()` calls
## this before either parent is removed from the scene tree.
func dispose() -> void:
	if _territory != null:
		_territory.clear_session_landscape_objects()
	for node: Node in [
		village_boundary_markers,
		village_territory_overlay,
		precipitation_effect,
		sky_and_weather_controller,
		trail_overlay,
		selection_marker,
		preview_entrance_marker,
		preview_back_entrance_marker,
		hero_build_radius_marker,
	]:
		if is_instance_valid(node):
			node.free()
	village_boundary_markers = null
	village_territory_overlay = null
	precipitation_effect = null
	sky_and_weather_controller = null
	trail_overlay = null
	selection_marker = null
	preview_entrance_marker = null
	preview_back_entrance_marker = null
	hero_build_radius_marker = null
	map_entity_presenter = null
	map_placement_presenter = null
	map_scatter_world = null
	_territory = null


## Hands the environment snapshot to the sky (`world_environment.md` §2). One
## value in, nothing assembled here: this used to be a ten-argument positional
## relay, and every field the environment gained cost an edit in three files.
func update_daylight(snapshot: EnvironmentSnapshot, runtime_seconds: float) -> void:
	if sky_and_weather_controller != null:
		sky_and_weather_controller.update_daylight(snapshot, runtime_seconds)
	# Ветер доезжает до травы террейна и до листвы наполнения из одного места.
	# До этого `GridTerrainWorld.set_wind` существовал и не вызывался никем.
	WorldWind.apply(snapshot, _territory.terrain if _territory != null else null)


## The board gets a real `TerrainGrid`, meshed and collided by `GridTerrainWorld`.
## It replaces the plane the removed Terrain3D addon used to hide behind, so
## height has exactly one owner from here on.
##
## With a map launched, that grid IS the map's — adopted rather than copied, so
## the relief the author built is the relief the citizens walk on and there is no
## second copy to fall out of step with the first.
func _build_terrain(parent: Node) -> void:
	var territory := parent.get_node_or_null("WorldTerritory") as TerritoryBase
	if territory == null:
		return
	_territory = territory
	if _map_document == null:
		push_error("[world] WorldSetup requires a map document")
		return
	terrain_grid = territory.configure_terrain(
		_cell_size, _board_cells, _camera, _map_document.terrain, _map_document.coverage,
	)
	terrain_service.configure(terrain_grid)
	water_grid = territory.configure_water(_board_cells, _cell_size, _map_document.water)
	water_service.configure(water_grid, terrain_grid)
	territory.configure_water_border(_map_document.meta.border_kind, _map_document.meta.border_level)
	water_access.configure(water_grid, terrain_grid)


func _build_map_entities() -> void:
	if _territory == null:
		return
	map_entity_runtime.load_map(_map_document, terrain_grid, _start_option)
	if map_entity_presenter == null:
		map_entity_presenter = MapEntityPresenter.new()
		map_entity_presenter.name = "MapEntities"
	_territory.add_landscape_object(map_entity_presenter)
	map_entity_presenter.present(map_entity_runtime, _territory, _claimed_components)


## Массовое наполнение рисуется чанковыми `MultiMesh`, а не нодами: тридцать
## тысяч деревьев нодами — это шестьсот тысяч нод (`map_fill_mode.md` §9.4).
func _build_map_scatter() -> void:
	if _territory == null or _map_document == null:
		return
	if map_scatter_world == null:
		map_scatter_world = ScatterWorld.new()
		map_scatter_world.name = "MapScatter"
	_territory.add_landscape_object(map_scatter_world)
	map_scatter_world.configure(
		_map_document.scatter, terrain_grid, water_grid, _claimed_components, true)
	map_scatter_world.bind_services(terrain_service, water_service)


func _build_map_placements() -> void:
	if _territory == null or _map_document == null:
		return
	if map_placement_presenter == null:
		map_placement_presenter = MapPlacementPresenter.new()
		map_placement_presenter.name = "MapBuildings"
	_territory.add_landscape_object(map_placement_presenter)
	map_placement_presenter.present(_map_document, _territory)


func _build_boundary(parent: Node) -> void:
	village_boundary_markers = village_boundary_markers_scene.instantiate() as VillageBoundaryMarkers
	village_boundary_markers.configure(_cell_size)
	parent.add_child(village_boundary_markers)
	village_territory_overlay = village_territory_overlay_scene.instantiate() as VillageTerritoryOverlay
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


func _build_precipitation_effect(parent: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	precipitation_effect = PrecipitationEffectScene.instantiate() as PrecipitationEffect
	precipitation_effect.name = "PrecipitationEffect"
	precipitation_effect.set_camera(_camera)
	parent.add_child(precipitation_effect)


func _build_sky_and_weather_controller(parent: Node) -> void:
	sky_and_weather_controller = SkyAndWeatherControllerScene.instantiate() as SkyAndWeatherController
	parent.add_child(sky_and_weather_controller)
	sky_and_weather_controller.setup(
		_camera,
		sun,
		world_environment,
		sky_material,
		precipitation_effect,
		sun_glare_material
	)



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
	trail_overlay_material.shader = trail_overlay_shader
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
	_build_hero_radius_marker(parent)


func _create_preview_entrance_marker(color: Color) -> MeshInstance3D:
	var marker := PreviewEntranceMarkerScene.instantiate() as MeshInstance3D
	var material := marker.material_override as StandardMaterial3D
	material.albedo_color = color
	material.emission = color
	return marker


func _build_hero_radius_marker(parent: Node) -> void:
	hero_build_radius_marker = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 19.8
	torus.outer_radius = 20.2
	hero_build_radius_marker.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hero_build_radius_marker.material_override = mat
	hero_build_radius_marker.visible = false
	parent.add_child(hero_build_radius_marker)
