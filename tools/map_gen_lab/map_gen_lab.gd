extends Node3D

## Isolated laboratory for procedural map generation
## (design_docs/engine/procedural_map_generation.md §7).
##
## It runs the real `TerrainGenerationService` over the real `TerrainGrid`,
## `WaterGrid`, chunk mesher and `NavGrid`, with nothing from the game around
## them. The split from `tools/terrain_lab` is deliberate: that laboratory is
## about editing terrain BY HAND — brushes, cascade, ramps — and this one is about
## a RECIPE. They share the world, the water and the camera; the brush has no
## business here.
##
## Three things are worth knowing before judging anything on this screen:
##
## * **Neighbouring seeds are the tool, not the pretty view.** A recipe that gives
##   one good map on one seed is a bad recipe. `[` and `]` step the seed and the
##   metrics panel keeps the previous numbers beside the current ones.
## * **Passability is invisible in a render.** A pass and a wall look identical
##   from this camera. Press `M` before believing a mountain range is crossable.
## * **The structure overlay is what the recipe actually asked for.** `K` draws
##   the crest polylines, the summits, the saddles and the river traces — if the
##   picture disagrees with the recipe, the recipe was not obeyed.
## * **A biome is not judged by its colour on the ground.** `B` cycles the biome,
##   temperature and moisture masks. The rain shadow behind a range is the thing
##   to look for: if the lee side is as wet as the windward one, the wind is doing
##   nothing and the whole of layer 2 is decoration.
##
## Keys: G generate · [ / ] previous/next seed · R random seed
##       M navigation overlay · T traveller profile · K structures · F drainage
##       B climate/biome mask
##       WASD pan · Q/E orbit · MMB drag orbit · wheel zoom · click inspect · Esc quit
##
## Batch: `godot --path . tools/map_gen_lab/map_gen_lab.tscn -- --capture` runs
## every preset over a set of seeds, writes views and a metrics JSON to
## `user://map_gen_lab` and exits — so a change to the algorithm is visible on
## every kind of map at once instead of on the one that happened to be open.

const CELL_SIZE := 1.0
const PRESET_DIRECTORY := "res://tools/map_gen_lab/presets"

const CAMERA_MIN_DISTANCE := 10.0
const CAMERA_MAX_DISTANCE := 320.0
const CAMERA_PAN_SPEED := 40.0
const CAMERA_ORBIT_SPEED := 90.0
const CAMERA_MOUSE_ORBIT := 0.35

## Seeds each preset is photographed on in `--capture`. Three is enough to show
## whether a recipe is stable and few enough to keep a batch run short.
const CAPTURE_SEEDS: Array[int] = [1, 2, 3]
const CAPTURE_SETTLE_FRAMES := 4

## Masks `B` cycles through, in order.
const MASK_OFF := 0
const MASK_BIOME := 1
const MASK_TEMPERATURE := 2
const MASK_MOISTURE := 3
const MASK_NAMES: Array[String] = ["off", "biomes", "temperature", "moisture"]

## Presentation's own table: the domain hands out biome indices and says nothing
## about how they look, exactly as `TerrainMaterialCatalog` does for materials.
const BIOME_COLOURS: Dictionary = {
	BiomeCatalog.POLAR_DESERT: Color(0.88, 0.94, 1.0),
	BiomeCatalog.TUNDRA: Color(0.62, 0.65, 0.58),
	BiomeCatalog.ALPINE: Color(0.55, 0.55, 0.60),
	BiomeCatalog.BOREAL_FOREST: Color(0.16, 0.42, 0.34),
	BiomeCatalog.TEMPERATE_FOREST: Color(0.20, 0.62, 0.26),
	BiomeCatalog.TEMPERATE_GRASSLAND: Color(0.62, 0.76, 0.30),
	BiomeCatalog.SHRUBLAND: Color(0.68, 0.62, 0.32),
	BiomeCatalog.SAVANNA: Color(0.85, 0.72, 0.28),
	BiomeCatalog.TROPICAL_FOREST: Color(0.08, 0.50, 0.20),
	BiomeCatalog.WETLAND: Color(0.28, 0.55, 0.55),
	BiomeCatalog.DESERT: Color(0.90, 0.80, 0.48),
}
## The two continuous masks are read as ramps, so the ends have to be far apart in
## hue as well as in value — °C in particular is judged by "where does it turn
## blue", which is the treeline.
const COLD_COLOUR := Color(0.30, 0.45, 0.95)
const HOT_COLOUR := Color(0.95, 0.35, 0.15)
const DRY_COLOUR := Color(0.78, 0.62, 0.30)
const WET_COLOUR := Color(0.20, 0.55, 0.90)
const MASK_TEMPERATURE_RANGE := Vector2(-25.0, 35.0)
## Nearly opaque: a mask is read as a colour key, and at 0.75 the brown of the
## ground underneath turned every palette entry into a shade of the same beige.
const MASK_ALPHA := 0.92
## Height above the ground the mask sheet floats at. Enough to clear z-fighting,
## small enough that it still reads as painted on the terrain.
const MASK_LIFT := 0.04

@onready var terrain: GridTerrainWorld = $Terrain
@onready var water_world: WaterWorld = $Water
@onready var camera: Camera3D = $Camera3D
@onready var nav_overlay: NavTerrainOverlay = $NavOverlay
@onready var structure_overlay: MeshInstance3D = $StructureOverlay
@onready var climate_overlay: MeshInstance3D = $ClimateOverlay
@onready var hud: Label = $UI/Hud
@onready var recipe_panel := $UI/RecipePanel
@onready var metrics_panel := $UI/MetricsPanel

var grid := TerrainGrid.new()
var water := WaterGrid.new()
var terrain_service := TerrainService.new()
var water_service := WaterService.new()
var nav_grid := NavGrid.new()
var nav_publisher := TerrainNavigationPublisher.new()
var generator := TerrainGenerationService.new()

var NAV_PROFILES: Array[StringName] = TerrainModeController.NAV_PROFILES
var _nav_profile_index := 0

var _recipe: MapRecipe = null
var _result: GenerationResult = null
var _seed := 1
var _preset_paths: Array[String] = []
var _preset_id := "lab_temperate"
var _message := ""
var _inspected := Vector2i.ZERO
var _has_inspection := false
var _drainage_visible := false
var _mask := MASK_OFF

var _camera_target := Vector3.ZERO
var _camera_yaw := 42.0
var _camera_pitch := 52.0
var _camera_distance := 110.0
var _orbiting := false

var _capture_queue: Array = []
var _capture_delay := 0
var _capture_records: Array = []


func _ready() -> void:
	terrain.configure(grid, camera)
	water_world.configure(water, grid, water_service, terrain_service)
	nav_publisher.configure(grid, nav_grid, terrain_service, water, water_service)
	nav_overlay.configure(nav_grid, NAV_PROFILES[_nav_profile_index])
	nav_overlay.visible = false
	structure_overlay.mesh = ImmediateMesh.new()
	structure_overlay.material_override = _overlay_material()
	climate_overlay.mesh = ImmediateMesh.new()
	climate_overlay.material_override = _mask_material()

	_preset_paths = _find_presets()
	recipe_panel.set_presets(_preset_paths)
	recipe_panel.recipe_changed.connect(_on_recipe_changed)
	recipe_panel.generate_requested.connect(_generate)
	recipe_panel.seed_changed.connect(_on_seed_changed)
	recipe_panel.preset_selected.connect(_load_preset)
	recipe_panel.save_requested.connect(_save_recipe)

	if _preset_paths.is_empty():
		_recipe = MapRecipe.default_recipe()
		recipe_panel.load_recipe(_recipe)
	else:
		_load_preset(_preset_paths[0])

	if OS.get_cmdline_user_args().has("--capture"):
		_start_capture()
	else:
		_generate()


func _configure_board(board_cells: int) -> void:
	grid.configure(CELL_SIZE, board_cells)
	water.configure(CELL_SIZE, board_cells)
	terrain_service.configure(grid)
	water_service.configure(water, grid)
	nav_grid.configure(CELL_SIZE, board_cells)
	generator.configure(grid, water, terrain_service, water_service, nav_publisher, nav_grid)
	_camera_distance = clampf(float(board_cells) * 1.15, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)


# --- Generation ---------------------------------------------------------------

func _generate() -> void:
	_recipe = recipe_panel.build_recipe(_preset_id, _seed)
	if not _recipe.is_valid():
		_message = "recipe refused: %s" % "; ".join(_recipe.errors)
		_result = generator.generate(_recipe, _seed)
		metrics_panel.show_report(_recipe, _result.report, _result.attempts.size())
		return
	_configure_board(_recipe.board_size)
	var started := Time.get_ticks_msec()
	_result = generator.generate(_recipe, _seed)
	terrain.rebuild_everything_now()
	water_world.rebuild_pending_now()
	if nav_overlay.visible:
		nav_overlay.rebuild()
	_rebuild_structure_overlay()
	_rebuild_climate_overlay()
	metrics_panel.show_report(_recipe, _result.report, _result.attempts.size())
	_message = "%s — %d ms wall clock, %d attempt(s)" % [
		_result.report.verdict(), Time.get_ticks_msec() - started, _result.attempts.size(),
	]
	_camera_target = Vector3.ZERO


func _on_recipe_changed() -> void:
	# §7.1: changing a parameter regenerates the whole map. There is no
	# incremental generation and there is no need for one — the stages are pure
	# and the board is small enough to redo.
	_generate()


func _on_seed_changed(value: int) -> void:
	_seed = value
	recipe_panel.show_seed(_seed)
	_generate()


func _load_preset(path: String) -> void:
	var loaded := MapRecipe.from_json_path(path)
	_preset_id = path.get_file().replace(".gdmapgen.json", "")
	_recipe = loaded
	_seed = loaded.seed
	recipe_panel.load_recipe(loaded)
	recipe_panel.show_seed(_seed)
	metrics_panel.forget_previous()
	_generate()


## Writes the panel's recipe back out as a preset the batch run will pick up.
## Presets are the regression set of §7.1, so authoring one is a first-class
## action rather than a copy of a JSON file by hand.
func _save_recipe() -> void:
	if _recipe == null:
		return
	var directory := "user://map_gen_lab/recipes"
	DirAccess.make_dir_recursive_absolute(directory)
	var path := "%s/%s.gdmapgen.json" % [directory, _preset_id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_message = "could not write %s" % path
		return
	file.store_string(JSON.stringify(_recipe.to_dictionary(), "\t"))
	file.close()
	_message = "recipe written to %s" % ProjectSettings.globalize_path(path)


static func _find_presets() -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(PRESET_DIRECTORY)
	if directory == null:
		return paths
	for name: String in directory.get_files():
		if name.ends_with(".gdmapgen.json"):
			paths.append("%s/%s" % [PRESET_DIRECTORY, name])
	paths.sort()
	return paths


# --- Overlays -----------------------------------------------------------------

static func _overlay_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	return material


## The climate masks are a sheet lying ON the ground, so unlike the structure
## lines they keep depth testing: a biome behind a mountain must be hidden by the
## mountain, or the mask says nothing about where anything is.
static func _mask_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## One quad per column, coloured by the mask in question. It is rebuilt from the
## context rather than from the grid because temperature, moisture and biome are
## generation buffers: they are baked into materials and objects, never stored on
## the board, so this overlay is the only place they can be seen at all.
##
## The quad sits on the cell's CORNER heights, not on its stored height, and that
## is the difference between a mask and a rumour. §3.4 of the terrain document
## lifts a corner by up to a whole step for the ramps around it, so a flat sheet
## at `height + ε` is buried by its own neighbours everywhere the ground is not
## level — which showed up as a mask that covered the coastal plain and vanished
## over every hill on the board.
func _rebuild_climate_overlay() -> void:
	var mesh := climate_overlay.mesh as ImmediateMesh
	mesh.clear_surfaces()
	climate_overlay.visible = _mask != MASK_OFF
	if _mask == MASK_OFF or _result == null or _result.context == null:
		return
	var context := _result.context
	if context.biomes.size() != context.cell_count:
		return
	var corners := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in context.cell_count:
		var cell := context.cell_of_index(index)
		if not grid.is_inside(cell):
			continue
		mesh.surface_set_color(_mask_colour(context, index))
		grid.corner_heights_into(cell, corners)
		var x0 := float(cell.x) * CELL_SIZE
		var x1 := float(cell.x + 1) * CELL_SIZE
		var z0 := float(cell.y) * CELL_SIZE
		var z1 := float(cell.y + 1) * CELL_SIZE
		var a := Vector3(x0, corners[TerrainGrid.CORNER_NW] * TerrainGrid.HEIGHT_STEP + MASK_LIFT, z0)
		var b := Vector3(x1, corners[TerrainGrid.CORNER_NE] * TerrainGrid.HEIGHT_STEP + MASK_LIFT, z0)
		var c := Vector3(x1, corners[TerrainGrid.CORNER_SE] * TerrainGrid.HEIGHT_STEP + MASK_LIFT, z1)
		var d := Vector3(x0, corners[TerrainGrid.CORNER_SW] * TerrainGrid.HEIGHT_STEP + MASK_LIFT, z1)
		mesh.surface_add_vertex(a)
		mesh.surface_add_vertex(b)
		mesh.surface_add_vertex(c)
		mesh.surface_add_vertex(a)
		mesh.surface_add_vertex(c)
		mesh.surface_add_vertex(d)
	mesh.surface_end()


## The colour of one column under the current mask, converted to linear.
##
## The conversion is not a detail: a vertex colour goes to the GPU as albedo, and
## albedo is linear. Handing it the sRGB values of the table above put every biome
## through a second gamma on the way out — the palette arrived on screen as five
## shades of pale mint, and a colour key nobody can tell apart is not a mask.
func _mask_colour(context: GenerationContext, index: int) -> Color:
	var colour := Color.MAGENTA
	match _mask:
		MASK_TEMPERATURE:
			var warmth := inverse_lerp(
				MASK_TEMPERATURE_RANGE.x, MASK_TEMPERATURE_RANGE.y, context.temperature[index],
			)
			colour = COLD_COLOUR.lerp(HOT_COLOUR, clampf(warmth, 0.0, 1.0))
		MASK_MOISTURE:
			colour = DRY_COLOUR.lerp(WET_COLOUR, clampf(context.moisture[index], 0.0, 1.0))
		_:
			colour = BIOME_COLOURS.get(BiomeCatalog.id_of_index(int(context.biomes[index])), Color.MAGENTA)
	var linear := colour.srgb_to_linear()
	return Color(linear.r, linear.g, linear.b, MASK_ALPHA)


## The skeleton the recipe asked for, drawn over the ground it produced: crest
## polylines, summits, saddles, and the traced river channels. This is the view
## that answers "did I get two ranges from the north-west" without counting
## pixels.
func _rebuild_structure_overlay() -> void:
	var mesh := structure_overlay.mesh as ImmediateMesh
	mesh.clear_surfaces()
	if _result == null or _result.context == null:
		return
	var context := _result.context
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for ridge: PackedVector2Array in context.ridges:
		mesh.surface_set_color(Color(1.0, 0.85, 0.3))
		for index in maxi(ridge.size() - 1, 0):
			mesh.surface_add_vertex(_above(ridge[index], 1.5))
			mesh.surface_add_vertex(_above(ridge[index + 1], 1.5))
	for peak: Dictionary in context.peaks:
		mesh.surface_set_color(Color(1.0, 0.4, 0.2))
		var position: Vector2 = peak["position"]
		mesh.surface_add_vertex(_above(position, 0.0))
		mesh.surface_add_vertex(_above(position, 6.0))
	for saddle: Vector2 in context.passes:
		mesh.surface_set_color(Color(0.35, 1.0, 0.5))
		mesh.surface_add_vertex(_above(saddle, 0.0))
		mesh.surface_add_vertex(_above(saddle, 4.0))
	if _drainage_visible:
		_add_drainage(mesh, context)
	mesh.surface_end()


## Every cell that collects more than a hundredth of the board drawn as a segment
## to the cell it drains into: the river network the trace had to choose from.
func _add_drainage(mesh: ImmediateMesh, context: GenerationContext) -> void:
	var threshold := maxf(float(context.cell_count) * 0.004, 8.0)
	mesh.surface_set_color(Color(0.35, 0.65, 1.0))
	for index in context.cell_count:
		if context.flow_accum[index] < threshold:
			continue
		var direction := int(context.flow_dir[index])
		if direction == GenerationContext.NO_FLOW:
			continue
		var cell := context.cell_of_index(index)
		var target := cell + SlopeCatalog.direction_offset(direction)
		mesh.surface_add_vertex(_above(Vector2(cell) + Vector2(0.5, 0.5), 0.4))
		mesh.surface_add_vertex(_above(Vector2(target) + Vector2(0.5, 0.5), 0.4))


func _above(point: Vector2, lift: float) -> Vector3:
	var cell := Vector2i(floori(point.x), floori(point.y))
	var ground := 0.0
	if grid.is_inside(cell):
		ground = float(grid.height_of(cell)) * TerrainGrid.HEIGHT_STEP
	return Vector3(point.x * CELL_SIZE, ground + lift, point.y * CELL_SIZE)


# --- Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		return
	if event is InputEventMouseMotion and _orbiting:
		var motion := event as InputEventMouseMotion
		_camera_yaw = fposmod(_camera_yaw - motion.relative.x * CAMERA_MOUSE_ORBIT, 360.0)
		_camera_pitch = clampf(_camera_pitch + motion.relative.y * CAMERA_MOUSE_ORBIT, 8.0, 88.0)
		_update_camera()
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		_handle_key(event as InputEventKey)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_inspect_under_mouse()
		MOUSE_BUTTON_MIDDLE:
			_orbiting = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_camera_distance = maxf(CAMERA_MIN_DISTANCE, _camera_distance - _camera_distance * 0.1)
				_update_camera()
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_camera_distance = minf(CAMERA_MAX_DISTANCE, _camera_distance + _camera_distance * 0.1)
				_update_camera()


func _handle_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_G:
			_generate()
		KEY_BRACKETLEFT:
			_on_seed_changed(_seed - 1)
		KEY_BRACKETRIGHT:
			_on_seed_changed(_seed + 1)
		KEY_R:
			_on_seed_changed(randi() % 1000000)
		KEY_M:
			nav_overlay.visible = not nav_overlay.visible
			nav_overlay.rebuild()
			_message = "nav overlay %s" % ("on" if nav_overlay.visible else "off")
		KEY_T:
			_nav_profile_index = (_nav_profile_index + 1) % NAV_PROFILES.size()
			nav_overlay.configure(nav_grid, NAV_PROFILES[_nav_profile_index])
			_message = "nav profile %s" % NAV_PROFILES[_nav_profile_index]
		KEY_K:
			structure_overlay.visible = not structure_overlay.visible
			_message = "structures %s" % ("on" if structure_overlay.visible else "off")
		KEY_F:
			_drainage_visible = not _drainage_visible
			structure_overlay.visible = true
			_rebuild_structure_overlay()
			_message = "drainage %s" % ("on" if _drainage_visible else "off")
		KEY_B:
			_mask = (_mask + 1) % MASK_NAMES.size()
			_rebuild_climate_overlay()
			_message = "mask %s" % MASK_NAMES[_mask]
		KEY_ESCAPE:
			get_tree().quit()


func _process(delta: float) -> void:
	if not _capture_queue.is_empty():
		_process_capture()
		return
	_process_camera_keys(delta)
	_update_hud()


func _process_camera_keys(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		pan.y += 1.0
	if Input.is_key_pressed(KEY_A):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		pan.x += 1.0
	var orbit := 0.0
	if Input.is_key_pressed(KEY_Q):
		orbit -= 1.0
	if Input.is_key_pressed(KEY_E):
		orbit += 1.0
	if pan == Vector2.ZERO and is_zero_approx(orbit):
		return
	var yaw := deg_to_rad(_camera_yaw)
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	_camera_target += (forward * pan.y + right * pan.x) * CAMERA_PAN_SPEED * delta
	_camera_yaw = fposmod(_camera_yaw + orbit * CAMERA_ORBIT_SPEED * delta, 360.0)
	_update_camera()


func _update_camera() -> void:
	var yaw := deg_to_rad(_camera_yaw)
	var pitch := deg_to_rad(_camera_pitch)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * _camera_distance
	camera.global_position = _camera_target + offset
	camera.look_at(_camera_target, Vector3.UP)


# --- Inspection ---------------------------------------------------------------

func _inspect_under_mouse() -> void:
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * 4000.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_has_inspection = false
		return
	_inspected = grid.cell_from_position(hit["position"])
	_has_inspection = grid.is_inside(_inspected)


## Everything one column is: what the ground stores, what hydrology decided and
## which structure claimed it. The point of the inspector is that these three can
## disagree, and the disagreement is always the bug.
func _inspection_line() -> String:
	if not _has_inspection or _result == null or _result.context == null:
		return "cell — (click the ground to inspect)"
	var context := _result.context
	if not context.contains(_inspected.x, _inspected.y):
		return "cell — outside the generated board"
	var index := context.cell_index(_inspected)
	var body := water.body_at(_inspected)
	var direction := int(context.flow_dir[index])
	return "cell (%d, %d)  h=%d  %s  drains %s  accum %.0f  uplift %.1f  %s%s\n%s  %.1f °C  moisture %.2f  %s (snow %d)" % [
		_inspected.x, _inspected.y, grid.height_of(_inspected), grid.slope_of(_inspected),
		"nowhere" if direction == GenerationContext.NO_FLOW else String(_direction_name(direction)),
		context.flow_accum[index], context.uplift[index],
		"river" if context.river_cells.has(_inspected) else "land",
		"  %s at %d (depth %d)" % [
			body.name, body.surface_height, water.depth_steps_at(grid, _inspected),
		] if body != null else "",
		BiomeCatalog.id_of_index(context.biome_at_index(index)),
		context.temperature[index], context.moisture[index],
		grid.material_of(_inspected), grid.snow_depth_at(_inspected),
	]


static func _direction_name(direction: int) -> StringName:
	const NAMES: Array[StringName] = [&"N", &"NE", &"E", &"SE", &"S", &"SW", &"W", &"NW"]
	return NAMES[clampi(direction, 0, 7)]


func _update_hud() -> void:
	var lines: Array[String] = []
	var board := _recipe.board_size if _recipe != null else 0
	lines.append("MAP GEN LAB — %s, %d×%d cells, seed %d" % [_preset_id, board, board, _seed])
	lines.append(_inspection_line())
	lines.append("nav [%s] %s   structures %s   drainage %s   mask %s" % [
		NAV_PROFILES[_nav_profile_index], "on" if nav_overlay.visible else "off",
		"on" if structure_overlay.visible else "off", "on" if _drainage_visible else "off",
		MASK_NAMES[_mask],
	])
	lines.append("> %s" % _message)
	lines.append("G generate · [ ] seed · R random · M nav · T profile · K structures · F drainage · B mask · Esc quit")
	hud.text = "\n".join(lines)


# --- Batch capture ------------------------------------------------------------

func _start_capture() -> void:
	for path: String in _preset_paths:
		for seed_value: int in CAPTURE_SEEDS:
			# Two photographs of the same map: the ground, and the biome mask over it.
			# Layer 2–3 work is invisible in the first one — a temperate meadow and a
			# savanna are both "green from this camera" — so a batch that only shot
			# the render could not show a change of climate at all.
			for mask: int in [MASK_OFF, MASK_BIOME]:
				_capture_queue.append({"preset": path, "seed": seed_value, "mask": mask})
	_capture_delay = CAPTURE_SETTLE_FRAMES
	if _capture_queue.is_empty():
		get_tree().quit()


## One view per entry: generate when the map changes, let the chunk budget settle,
## then write the view and the metrics. The JSON beside the images is the half that
## survives a change of lighting — §6 is measured, not looked at.
func _process_capture() -> void:
	var entry: Dictionary = _capture_queue[0]
	if _capture_delay == CAPTURE_SETTLE_FRAMES:
		_mask = int(entry["mask"])
		# The second entry of a pair is the same map seen through the mask: it must
		# not be regenerated, or the two photographs would be of two worlds.
		var same_map := _result != null and _preset_id == String(entry["preset"]).get_file().replace(".gdmapgen.json", "") and _seed == int(entry["seed"])
		if not same_map:
			var loaded := MapRecipe.from_json_path(entry["preset"])
			_preset_id = String(entry["preset"]).get_file().replace(".gdmapgen.json", "")
			_recipe = loaded
			_seed = int(entry["seed"])
			recipe_panel.load_recipe(loaded)
			recipe_panel.show_preset(entry["preset"])
			recipe_panel.show_seed(_seed)
			_configure_board(loaded.board_size)
			_result = generator.generate(loaded, _seed)
			terrain.rebuild_everything_now()
			water_world.rebuild_pending_now()
			_rebuild_structure_overlay()
			metrics_panel.show_report(_recipe, _result.report, _result.attempts.size())
			_camera_target = Vector3.ZERO
			_camera_yaw = 42.0
			_camera_pitch = 55.0
			_camera_distance = float(loaded.board_size) * 1.15
			_update_camera()
		_rebuild_climate_overlay()
		_message = "batch capture"
		_update_hud()
		if not same_map:
			_capture_records.append(_result.report.to_dictionary())
	if _capture_delay > 0:
		_capture_delay -= 1
		return
	var directory := "user://map_gen_lab"
	DirAccess.make_dir_recursive_absolute(directory)
	var image := get_viewport().get_texture().get_image()
	var suffix := "" if _mask == MASK_OFF else "_%s" % MASK_NAMES[_mask]
	var path := "%s/%s_seed%d%s.png" % [directory, _preset_id, _seed, suffix]
	image.save_png(path)
	print("[map_gen_lab] captured ", ProjectSettings.globalize_path(path), " — ", _result.report.verdict())
	_capture_queue.pop_front()
	_capture_delay = CAPTURE_SETTLE_FRAMES
	if not _capture_queue.is_empty():
		return
	var report_file := FileAccess.open("%s/metrics.json" % directory, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(_capture_records, "\t"))
		report_file.close()
	get_tree().quit()
