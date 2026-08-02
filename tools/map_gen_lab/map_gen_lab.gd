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
##
## Keys: G generate · [ / ] previous/next seed · R random seed
##       M navigation overlay · T traveller profile · K structures · F drainage
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

@onready var terrain: GridTerrainWorld = $Terrain
@onready var water_world: WaterWorld = $Water
@onready var camera: Camera3D = $Camera3D
@onready var nav_overlay: NavTerrainOverlay = $NavOverlay
@onready var structure_overlay: MeshInstance3D = $StructureOverlay
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
	return "cell (%d, %d)  h=%d  %s  drains %s  accum %.0f  uplift %.1f  %s%s" % [
		_inspected.x, _inspected.y, grid.height_of(_inspected), grid.slope_of(_inspected),
		"nowhere" if direction == GenerationContext.NO_FLOW else String(_direction_name(direction)),
		context.flow_accum[index], context.uplift[index],
		"river" if context.river_cells.has(_inspected) else "land",
		"  %s at %d (depth %d)" % [
			body.name, body.surface_height, water.depth_steps_at(grid, _inspected),
		] if body != null else "",
	]


static func _direction_name(direction: int) -> StringName:
	const NAMES: Array[StringName] = [&"N", &"NE", &"E", &"SE", &"S", &"SW", &"W", &"NW"]
	return NAMES[clampi(direction, 0, 7)]


func _update_hud() -> void:
	var lines: Array[String] = []
	var board := _recipe.board_size if _recipe != null else 0
	lines.append("MAP GEN LAB — %s, %d×%d cells, seed %d" % [_preset_id, board, board, _seed])
	lines.append(_inspection_line())
	lines.append("nav [%s] %s   structures %s   drainage %s" % [
		NAV_PROFILES[_nav_profile_index], "on" if nav_overlay.visible else "off",
		"on" if structure_overlay.visible else "off", "on" if _drainage_visible else "off",
	])
	lines.append("> %s" % _message)
	lines.append("G generate · [ ] seed · R random · M nav · T profile · K structures · F drainage · Esc quit")
	hud.text = "\n".join(lines)


# --- Batch capture ------------------------------------------------------------

func _start_capture() -> void:
	for path: String in _preset_paths:
		for seed_value: int in CAPTURE_SEEDS:
			_capture_queue.append({"preset": path, "seed": seed_value})
	_capture_delay = CAPTURE_SETTLE_FRAMES
	if _capture_queue.is_empty():
		get_tree().quit()


## One preset on one seed per entry: generate, let the chunk budget settle, then
## write the view and the metrics. The JSON beside the images is the half that
## survives a change of lighting — §6 is measured, not looked at.
func _process_capture() -> void:
	var entry: Dictionary = _capture_queue[0]
	if _capture_delay == CAPTURE_SETTLE_FRAMES:
		var loaded := MapRecipe.from_json_path(entry["preset"])
		_preset_id = String(entry["preset"]).get_file().replace(".gdmapgen.json", "")
		_recipe = loaded
		_seed = int(entry["seed"])
		recipe_panel.load_recipe(loaded)
		recipe_panel.show_seed(_seed)
		_configure_board(loaded.board_size)
		_result = generator.generate(loaded, _seed)
		terrain.rebuild_everything_now()
		water_world.rebuild_pending_now()
		_rebuild_structure_overlay()
		_camera_target = Vector3.ZERO
		_camera_yaw = 42.0
		_camera_pitch = 55.0
		_camera_distance = float(loaded.board_size) * 1.15
		_update_camera()
		_capture_records.append(_result.report.to_dictionary())
	if _capture_delay > 0:
		_capture_delay -= 1
		return
	var directory := "user://map_gen_lab"
	DirAccess.make_dir_recursive_absolute(directory)
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s_seed%d.png" % [directory, _preset_id, _seed]
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
