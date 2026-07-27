extends Node3D

## Isolated lab for the grid terrain system (design_docs/engine/grid_terrain_system.md).
##
## Runs the real domain grid, the real chunk mesher and the real chunk budget with
## nothing from the game around them, so terrain work can be developed and judged
## on its own. No settlement and no editor integration — those come when the
## ground itself is proven here.
##
## Navigation IS here, though, and deliberately so: passability is invisible in a
## rendered mesh. Two terraces and a slope look identical from this camera, and
## the difference — a wall nobody can climb — is exactly the mistake an author
## makes and cannot see. The lab runs the real `NavGrid` over the real published
## field and draws the answer (key M).
##
## The brush itself is NOT here: it lives in `TerrainBrushController`
## (`map_editor.md` §3.1), shared with the map editor and the `Terrain Base`
## layer of the building editor. The lab keeps what is its own — demo
## generators, capture, HUD, overlays and the keyboard binding — and drives that
## one tool through it.
##
## Materials are here in full (`terrain_materials.md`): the thirteen-entry catalog,
## the variant budget, the detail byte (variant | wear | snow) and the two shaders
## that read the index and detail maps. Painting any of them rebuilds no geometry
## at all — the pending-chunk counter in the HUD stays at zero while a material
## brush is dragged, which is the §7.5 promise made visible.
##
## Mouse: hover picks a column, LMB raises, RMB lowers, MMB drag orbits, wheel zooms.
## Keys:  F level brush to the hovered height, P paint material, 1-9/0 pick material,
##        ; / \' cycle the material page, B cycle variant, U wear, J snow,
##        K walk the brush (wear from traffic), H toggle hole, R place ramp,
##        X dissolve ramp, C cycle ramp class,
##        V cycle ramp direction, [ / ] brush size, Tab cycle cascade mode,
##        M toggle the navigation overlay, T cycle the traveller profile,
##        Z undo, Y redo (terrain and water in chronological order), G regenerate
##        demo, N clear to flat, WASD pan, Q/E orbit.
##        The legend is on screen as well.
##
## Batch: `godot --path . tools/terrain_lab/terrain_lab.tscn -- --capture` writes
## reference views of the demo terrain to user://terrain_lab and exits.

const BOARD_CELLS := 48
const CELL_SIZE := 1.0

const CAMERA_MIN_DISTANCE := 6.0
const CAMERA_MAX_DISTANCE := 90.0
const CAMERA_PAN_SPEED := 18.0
const CAMERA_ORBIT_SPEED := 90.0
const CAMERA_MOUSE_ORBIT := 0.35

@onready var terrain: GridTerrainWorld = $Terrain
@onready var camera: Camera3D = $Camera3D
@onready var hover_marker: MeshInstance3D = $HoverMarker
@onready var hud: Label = $UI/Hud
@onready var nav_overlay: NavTerrainOverlay = $NavOverlay
@onready var water_world: WaterWorld = $Water
@onready var smoothing_title: Label = $UI/SmoothingPanel/Margin/Rows/Title
@onready var full_smoothing_toggle: CheckButton = $UI/SmoothingPanel/Margin/Rows/FullSmoothing
@onready var smoothing_slider: HSlider = $UI/SmoothingPanel/Margin/Rows/Controls/Slider
@onready var smoothing_flat_button: Button = $UI/SmoothingPanel/Margin/Rows/Controls/FlatButton
@onready var smoothing_decrease_button: Button = $UI/SmoothingPanel/Margin/Rows/Controls/DecreaseButton
@onready var smoothing_increase_button: Button = $UI/SmoothingPanel/Margin/Rows/Controls/IncreaseButton
@onready var smoothing_smooth_button: Button = $UI/SmoothingPanel/Margin/Rows/Controls/SmoothButton

var grid := TerrainGrid.new()
var water := WaterGrid.new()
var service := TerrainService.new()
var water_service := WaterService.new()
var wear_service := SurfaceWearService.new()
var nav_grid := NavGrid.new()
var nav_publisher := TerrainNavigationPublisher.new()
var brush := TerrainBrushController.new()
var water_brush := WaterBrushController.new()
## The laboratory edits two layers, so its shortcuts must use one chronological
## history rather than whichever brush happened to receive the last key.
var history := MapEditorHistory.new()
var _replaying_history := false

## Profiles worth checking a map against: what a citizen can climb, and what a
## loaded cart can. A ramp that only a walker can use is a supply route that
## silently is not one.
# Keep in sync with terrain_mode_controller.gd — GDScript const cannot reference
# another class's const array.
const NAV_PROFILES: Array[StringName] = [&"pedestrian", &"cart"]
var _nav_profile_index := 0

var _camera_target := Vector3(0.0, 0.0, 0.0)
var _camera_yaw := 42.0
var _camera_pitch := 52.0
var _camera_distance := 34.0
var _orbiting := false

## The catalog no longer fits on the number row, so it is paged ten at a time.
## Paging is a property of this keyboard, not of the brush, so it stays here.
var _material_page := 0


const CAPTURE_VIEWS: Array = [
	{"name": "overview", "target": Vector3(0.0, 0.0, 0.0), "yaw": 42.0, "pitch": 52.0, "distance": 48.0},
	{"name": "ramps", "target": Vector3(0.0, 0.5, 0.0), "yaw": 250.0, "pitch": 22.0, "distance": 18.0},
	{"name": "smoothing_flat", "rounding": 0.0, "full_smoothing": false, "target": Vector3(0.0, 0.5, 0.0), "yaw": 250.0, "pitch": 22.0, "distance": 18.0},
	{"name": "rounding_half", "rounding": 0.5, "full_smoothing": false, "target": Vector3(0.0, 0.5, 0.0), "yaw": 250.0, "pitch": 22.0, "distance": 18.0},
	{"name": "rounding_full", "rounding": 1.0, "full_smoothing": false, "target": Vector3(0.0, 0.5, 0.0), "yaw": 250.0, "pitch": 22.0, "distance": 18.0},
	{"name": "smoothing_full", "rounding": 0.0, "full_smoothing": true, "target": Vector3(0.0, 0.5, 0.0), "yaw": 250.0, "pitch": 22.0, "distance": 18.0},
	{"name": "tower_and_hole", "target": Vector3(12.0, 2.0, 4.0), "yaw": 300.0, "pitch": 28.0, "distance": 26.0},
	{"name": "cascade_repose", "setup": &"cascade", "target": Vector3(0.0, 1.0, 0.0), "yaw": 20.0, "pitch": 30.0, "distance": 40.0},
	{"name": "cascade_closeup", "target": Vector3(-4.0, 1.0, 0.0), "yaw": 35.0, "pitch": 18.0, "distance": 16.0},
	# Passability is invisible in the mesh, so it gets its own reference views:
	# what a walker can cross, and what a cart can. The difference between the two
	# is the whole point of `max_slope_class`.
	{"name": "nav_pedestrian", "setup": &"demo", "nav": &"pedestrian", "target": Vector3(2.0, 0.5, 0.0), "yaw": 42.0, "pitch": 34.0, "distance": 40.0},
	{"name": "nav_cart", "nav": &"cart", "target": Vector3(2.0, 0.5, 0.0), "yaw": 42.0, "pitch": 34.0, "distance": 40.0},
	{"name": "nav_ramps_closeup", "nav": &"pedestrian", "target": Vector3(0.0, 0.5, 0.0), "yaw": 250.0, "pitch": 30.0, "distance": 18.0},
	# Materials get their own two views: the whole catalog with its variants, and
	# a close-up of the boundary where height-based blending either interlocks or
	# turns to mush (§7.3).
	# Water gets the same treatment as passability, because it IS passability: the
	# lake, the river and the lava pool look like three coloured patches until the
	# overlay says which of them anyone can cross (§9.7).
	{"name": "water_overview", "setup": &"demo", "nav": &"", "target": Vector3(-14.0, 0.0, -2.0), "yaw": 42.0, "pitch": 38.0, "distance": 30.0},
	{"name": "water_nav_pedestrian", "nav": &"pedestrian", "target": Vector3(-14.0, 0.0, -2.0), "yaw": 42.0, "pitch": 38.0, "distance": 30.0},
	{"name": "water_lava_closeup", "nav": &"", "target": Vector3(17.5, 1.0, 8.0), "yaw": 130.0, "pitch": 26.0, "distance": 15.0},
	{"name": "materials_catalog", "setup": &"demo", "nav": &"", "target": Vector3(-11.0, 0.0, 17.0), "yaw": 0.0, "pitch": 65.0, "distance": 30.0},
	{"name": "materials_blend_closeup", "target": Vector3(-17.0, 0.0, 14.0), "yaw": 25.0, "pitch": 30.0, "distance": 11.0},
]

## Frames to let the renderer settle before a capture: the chunk budget rebuilds
## two per frame, so a fresh board would be photographed half-meshed.
const CAPTURE_SETTLE_FRAMES := 3

var _capture_queue: Array = []
var _capture_delay := 0


func _ready() -> void:
	grid.configure(CELL_SIZE, BOARD_CELLS)
	water.configure(CELL_SIZE, BOARD_CELLS)
	service.configure(grid)
	water_service.configure(water, grid)
	wear_service.configure(service)
	terrain.configure(grid, camera)
	_connect_smoothing_controls()
	water_world.configure(water, grid, water_service, service)
	# Binds the grids and keeps the field current: every committed edit — ground or
	# water — republishes exactly the columns it touched.
	nav_publisher.configure(grid, nav_grid, service, water, water_service)
	brush.configure(grid, service, wear_service)
	water_brush.configure(grid, water, water_service)
	service.edit_committed.connect(_on_terrain_edited)
	water_service.edit_committed.connect(_on_water_edited)
	nav_overlay.configure(nav_grid, NAV_PROFILES[_nav_profile_index])
	nav_overlay.visible = false
	_generate_demo()
	terrain.rebuild_pending_now()
	water_world.rebuild_pending_now()
	_update_camera()
	if OS.get_cmdline_user_args().has("--capture"):
		_capture_queue = CAPTURE_VIEWS.duplicate()
		_capture_delay = CAPTURE_SETTLE_FRAMES


func _connect_smoothing_controls() -> void:
	smoothing_slider.value_changed.connect(_on_smoothing_changed)
	full_smoothing_toggle.toggled.connect(terrain.set_full_smoothing)
	smoothing_flat_button.pressed.connect(func() -> void: smoothing_slider.value = 0.0)
	smoothing_decrease_button.pressed.connect(func() -> void: smoothing_slider.value -= smoothing_slider.step)
	smoothing_increase_button.pressed.connect(func() -> void: smoothing_slider.value += smoothing_slider.step)
	smoothing_smooth_button.pressed.connect(func() -> void: smoothing_slider.value = 100.0)
	_on_smoothing_changed(smoothing_slider.value)


func _on_smoothing_changed(percent: float) -> void:
	terrain.set_edge_rounding(percent / 100.0)
	smoothing_title.text = "Edge rounding radius: %d%%" % roundi(percent)


func _process(delta: float) -> void:
	if not _capture_queue.is_empty():
		_process_capture()
		return
	_process_camera_keys(delta)
	_update_hover()
	_update_hud()


# --- Input ------------------------------------------------------------------

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
			brush.set_paint_direction(1 if event.pressed else 0)
		MOUSE_BUTTON_RIGHT:
			brush.set_paint_direction(-1 if event.pressed else 0)
		MOUSE_BUTTON_MIDDLE:
			_orbiting = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_camera_distance = maxf(CAMERA_MIN_DISTANCE, _camera_distance - 2.0)
				_update_camera()
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_camera_distance = minf(CAMERA_MAX_DISTANCE, _camera_distance + 2.0)
				_update_camera()


func _handle_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_F:
			brush.apply_flatten()
		KEY_P:
			brush.apply_material()
		KEY_B:
			brush.cycle_variant()
		KEY_U:
			brush.cycle_wear()
		KEY_J:
			brush.cycle_snow()
		KEY_K:
			brush.walk_the_brush()
		KEY_SEMICOLON:
			_material_page = maxi(0, _material_page - 1)
			brush.last_message = "material page %d" % (_material_page + 1)
		KEY_APOSTROPHE:
			_material_page = mini((TerrainMaterialCatalog.count() - 1) / 10, _material_page + 1)
			brush.last_message = "material page %d" % (_material_page + 1)
		KEY_H:
			brush.toggle_hole()
		KEY_R:
			brush.place_ramp()
		KEY_X:
			brush.dissolve_ramp()
		KEY_C:
			brush.cycle_ramp_class()
		KEY_V:
			brush.cycle_ramp_direction()
		KEY_BRACKETLEFT:
			brush.adjust_brush_size(-1)
		KEY_BRACKETRIGHT:
			brush.adjust_brush_size(1)
		KEY_L:
			water_brush.apply()
		KEY_PERIOD:
			water_brush.cycle_tool()
		KEY_COMMA:
			water_brush.pick_level_from_ground()
		KEY_SLASH:
			water_brush.toggle_body_ice()
		KEY_PAGEUP:
			water_brush.adjust_level(1)
		KEY_PAGEDOWN:
			water_brush.adjust_level(-1)
		KEY_O:
			_cycle_water_body()
		KEY_M:
			nav_overlay.visible = not nav_overlay.visible
			nav_overlay.rebuild()
			brush.last_message = "nav overlay %s" % ("on" if nav_overlay.visible else "off")
		KEY_T:
			_nav_profile_index = (_nav_profile_index + 1) % NAV_PROFILES.size()
			nav_overlay.configure(nav_grid, NAV_PROFILES[_nav_profile_index])
			brush.last_message = "nav profile %s" % NAV_PROFILES[_nav_profile_index]
		KEY_TAB:
			brush.cycle_edit_mode()
		KEY_Z:
			_undo()
		KEY_Y:
			_redo()
		KEY_G:
			_generate_demo()
			brush.last_message = "demo terrain regenerated"
		KEY_N:
			grid.configure(CELL_SIZE, BOARD_CELLS)
			water.configure(CELL_SIZE, BOARD_CELLS)
			service.clear_history()
			water_service.clear_history()
			history.clear()
			_republish_navigation()
			brush.last_message = "cleared to flat"
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0:
			var slot := 9 if event.keycode == KEY_0 else event.keycode - KEY_1
			brush.set_material_index(_material_page * 10 + slot)
		KEY_ESCAPE:
			get_tree().quit()


## What navigation makes of the hovered column, next to what the terrain stores.
## This is the line that catches the two disagreeing: a cell reading `flat` in
## the terrain and `steep` here is a cell tilted by its neighbours (§3.4).
func _nav_line() -> String:
	var profile: StringName = NAV_PROFILES[_nav_profile_index]
	var state := "on" if nav_overlay.visible else "off"
	if not brush.has_hover or not nav_grid.has_terrain_field():
		return "nav [%s] %s" % [profile, state]
	var field := nav_grid.terrain_field()
	var walkable := nav_grid.is_walkable(brush.hovered_cell, profile)
	var open_edges := 0
	for direction in NavTerrainField.DIRECTION_COUNT:
		var neighbour: Vector2i = brush.hovered_cell + NavTerrainField.DIRECTION_OFFSETS[direction]
		if nav_grid.is_edge_passable(brush.hovered_cell, neighbour, profile):
			open_edges += 1
	return "nav [%s] %s  surface class %d  %s  exits %d/8  cost ×%.2f" % [
		profile, state, field.slope_class_at(brush.hovered_cell),
		"walkable" if walkable else "BLOCKED", open_edges,
		nav_grid.get_cell_weight(brush.hovered_cell, profile) / NavGrid.DEFAULT_CELL_WEIGHT,
	]


## The publisher already refreshed the field; the overlay is presentation and
## rebuilds only when it is actually being looked at.
func _on_terrain_edited(delta: TerrainDelta) -> void:
	if not _replaying_history:
		history.push(TerrainServiceCommand.of(service, delta, "terrain"))
	if nav_overlay.visible:
		nav_overlay.rebuild()


func _on_water_edited(delta: WaterDelta) -> void:
	if not _replaying_history:
		history.push(WaterServiceCommand.of(water_service, delta, "water"))
	if nav_overlay.visible:
		nav_overlay.rebuild()


func _undo() -> void:
	if not history.can_undo():
		brush.last_message = "nothing to undo"
		return
	_replaying_history = true
	var ok := history.undo()
	_replaying_history = false
	brush.last_message = "undo" if ok else "undo failed"


func _redo() -> void:
	if not history.can_redo():
		brush.last_message = "nothing to redo"
		return
	_replaying_history = true
	var ok := history.redo()
	_replaying_history = false
	brush.last_message = "redo" if ok else "redo failed"


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
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch),
	) * _camera_distance
	camera.global_position = _camera_target + offset
	camera.look_at(_camera_target, Vector3.UP)


# --- Hover ------------------------------------------------------------------

## Picking and drag-painting belong to the brush; the lab only draws the marker
## over whatever column the brush ended up on.
func _update_hover() -> void:
	hover_marker.visible = brush.update_hover(
		camera, get_world_3d().direct_space_state, get_viewport().get_mouse_position(),
	)
	# The water tools pick the same column through the terrain's collider: the
	# water surface has none, which is what lets an author paint the bottom of a
	# lake they are looking through.
	water_brush.hovered_cell = brush.hovered_cell
	water_brush.has_hover = brush.has_hover
	if not brush.has_hover:
		return
	var center := grid.cell_center(brush.hovered_cell)
	hover_marker.position = Vector3(center.x, center.y + 0.03, center.z)
	var span := float(brush.brush_size * 2 - 1)
	hover_marker.scale = Vector3(span, 1.0, span)


# --- HUD --------------------------------------------------------------------

func _update_hud() -> void:
	var lines: Array[String] = []
	lines.append("TERRAIN LAB — %d×%d cells, Δh %.2f m, chunk %d" % [
		BOARD_CELLS, BOARD_CELLS, TerrainGrid.HEIGHT_STEP, TerrainGrid.CHUNK_CELLS,
	])
	if brush.has_hover:
		var cell := grid.cell_at(brush.hovered_cell)
		lines.append("cell (%d, %d)  h=%d (%.2f m)  %s  slope=%s dir=%s idx=%d%s" % [
			brush.hovered_cell.x, brush.hovered_cell.y, cell.height, cell.height * TerrainGrid.HEIGHT_STEP,
			cell.material_id, cell.slope_id, TerrainBrushController.direction_name(cell.slope_dir), cell.slope_index,
			"  HOLE" if cell.is_hole() else "",
		])
		# The surface line: what the column is made of, how worn and snowed it is,
		# and what that costs to walk on. Weight is the only one of the four that
		# the simulation actually feels.
		var material_index := grid.material_index_at(brush.hovered_cell)
		lines.append("surface variant=%s wear=%d snow=%d  weight ×%.2f  repose %s  soil %s  face %s  wear→%d" % [
			TerrainMaterialVariants.variant_name(material_index, cell.variant), cell.wear, cell.snow_depth,
			grid.surface_weight_at(brush.hovered_cell),
			SlopeCatalog.id_of_class(TerrainMaterialCatalog.repose_class_of_index(material_index)),
			TerrainMaterialCatalog.soil_of_index(material_index),
			TerrainMaterialCatalog.cliff_material_of_index(material_index),
			wear_service.progress_at(brush.hovered_cell),
		])
	else:
		lines.append("cell —")
		lines.append("surface —")
	lines.append("mode %s  brush %d  paint %s/%s (page %d)  ramp %s → %s" % [
		TerrainEditOperation.mode_name(brush.edit_mode).to_upper(), brush.brush_size,
		brush.material_id(),
		TerrainMaterialVariants.variant_name(brush.material_index, brush.variant),
		_material_page + 1,
		SlopeCatalog.id_of_class(brush.ramp_class), TerrainBrushController.direction_name(brush.ramp_direction),
	])
	lines.append(_palette_line())
	lines.append("undo %d  redo %d  |  pending chunks: %d" % [
		service.undo_depth(), service.redo_depth(), terrain.pending_chunk_count(),
	])
	lines.append(_water_line())
	lines.append(_nav_line())
	lines.append("> %s" % brush.last_message)
	lines.append("")
	lines.append("LMB raise · RMB lower · MMB orbit · wheel zoom · WASD pan · Q/E turn")
	lines.append("Tab mode (sculpt/terrace/level) · Z undo · Y redo · F level · P paint · 1-9/0 material")
	lines.append("B variant · U wear · J snow · K walk brush · ; \' material page")
	lines.append("H hole · R ramp · X unramp · C class · V dir · [ ] brush · G demo · N clear · Esc quit")
	lines.append("L water tool · . cycle tool · , level from ground · PgUp/PgDn level · O body · / freeze body")
	lines.append("M nav overlay · T traveller profile")
	hud.text = "\n".join(lines)


## The ten materials the number row currently selects, with the picked one marked.
## Thirteen entries no longer fit on one row, and a picker that silently addresses
## only the first five would hide most of the catalog.
func _palette_line() -> String:
	var parts: Array[String] = []
	for slot in 10:
		var index := _material_page * 10 + slot
		if index >= TerrainMaterialCatalog.count():
			break
		var key := "0" if slot == 9 else str(slot + 1)
		var name := String(TerrainMaterialCatalog.ids()[index])
		parts.append("[%s]%s" % [key, name.to_upper() if index == brush.material_index else name])
	return "  ".join(parts)


## Batch capture: one frame to move the camera, a couple to let the renderer
## settle, then the image. Keeps the lab usable as a regression reference for
## meshing changes without a human at the mouse.
func _process_capture() -> void:
	var view: Dictionary = _capture_queue[0]
	if _capture_delay == CAPTURE_SETTLE_FRAMES:
		if view.has("rounding"):
			smoothing_slider.value = float(view["rounding"]) * 100.0
		if view.has("full_smoothing"):
			full_smoothing_toggle.button_pressed = bool(view["full_smoothing"])
		match view.get("setup", &""):
			&"cascade":
				_setup_cascade_scene()
			&"demo":
				_generate_demo()
		# A capture has three frames to settle, and the chunk budget rebuilds two
		# per frame — a fresh board would be photographed half-meshed.
		terrain.rebuild_pending_now()
		var nav_profile: StringName = view.get("nav", &"")
		nav_overlay.visible = not nav_profile.is_empty()
		if nav_overlay.visible:
			# Through the index, so the HUD names the profile the overlay is drawing.
			_nav_profile_index = maxi(NAV_PROFILES.find(nav_profile), 0)
			nav_overlay.configure(nav_grid, NAV_PROFILES[_nav_profile_index])
	if _capture_delay > 0:
		_camera_target = view["target"]
		_camera_yaw = float(view["yaw"])
		_camera_pitch = float(view["pitch"])
		_camera_distance = float(view["distance"])
		_update_camera()
		hover_marker.visible = false
		_update_hud()
		_capture_delay -= 1
		return
	var directory := "user://terrain_lab"
	DirAccess.make_dir_recursive_absolute(directory)
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [directory, view["name"]]
	image.save_png(path)
	print("[terrain_lab] captured ", ProjectSettings.globalize_path(path))
	_capture_queue.pop_front()
	_capture_delay = CAPTURE_SETTLE_FRAMES
	if _capture_queue.is_empty():
		get_tree().quit()


## Three identical +5 sculpt edits on three materials, side by side: grass makes a
## pyramid, sand a wide terraced mound, rock a sheer column (§4.2).
func _setup_cascade_scene() -> void:
	grid.configure(CELL_SIZE, BOARD_CELLS)
	service.clear_history()
	history.clear()
	for z in range(-8, 9):
		for x in range(-4, 5):
			grid.set_material(Vector2i(x, z), TerrainMaterialCatalog.SAND)
		for x in range(8, 17):
			grid.set_material(Vector2i(x, z), TerrainMaterialCatalog.STONE)
		for x in range(-16, -7):
			grid.set_material(Vector2i(x, z), TerrainMaterialCatalog.MUD)
	for center: Vector2i in [Vector2i(-12, 0), Vector2i(0, 0), Vector2i(12, 0)]:
		service.apply_operation(TerrainEditOperation.offset([center] as Array[Vector2i], 5))
	terrain.rebuild_pending_now()
	brush.last_message = "cascade: mud / sand / rock, +5 steps each"


# --- Demo terrain -----------------------------------------------------------

## Hand-built showcase covering every feature the mesher has to get right:
## terraces with vertical faces, a two-stage gentle ramp, a moderate ramp, a
## carved hole, a stone tower and material patches.
func _generate_demo() -> void:
	grid.configure(CELL_SIZE, BOARD_CELLS)
	water.configure(CELL_SIZE, BOARD_CELLS)
	# The demo is scenery, not a player edit: it writes the grid directly and
	# starts the history empty.
	service.clear_history()
	water_service.clear_history()
	history.clear()

	# Stepped plateau to the east: 0 → 1 → 2, all cliffs except where ramps go.
	for z in range(-20, 20):
		for x in range(0, 4):
			grid.set_height(Vector2i(x, z), 1)
		for x in range(4, 20):
			grid.set_height(Vector2i(x, z), 2)
			grid.set_material(Vector2i(x, z), TerrainMaterialCatalog.STONE)

	# Two gentle ramps in series climbing the two steps (§3.1).
	for z in range(-3, 3):
		for x in range(-4, 4):
			grid.set_material(Vector2i(x, z), TerrainMaterialCatalog.DIRT)
		grid.place_ramp(Vector2i(-4, z), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E)
		grid.place_ramp(Vector2i(0, z), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E)

	# A moderate ramp north, climbing the first step in two cells.
	for z in range(-12, -9):
		grid.place_ramp(Vector2i(-2, z), SlopeCatalog.MODERATE, SlopeCatalog.DIR_E)

	# Sand basin to the west, two terraces below zero.
	for z in range(-14, 14):
		for x in range(-20, -14):
			grid.set_height(Vector2i(x, z), -1)
			grid.set_material(Vector2i(x, z), TerrainMaterialCatalog.SAND)
		for x in range(-20, -17):
			grid.set_height(Vector2i(x, z), -2)

	# Stone tower with a glacier cap — the vertical-face case at full height, and
	# the two face kinds that differ most: layered rock under stone, an ice wall
	# under `ice` (§3). Snow is NOT what caps it: snow is a state, and a state
	# cannot be a plateau (§6.2).
	for z in range(8, 13):
		for x in range(8, 13):
			grid.set_height(Vector2i(x, z), 8)
			grid.set_material(Vector2i(x, z), TerrainMaterialCatalog.STONE)
	for z in range(9, 12):
		for x in range(9, 12):
			grid.set_height(Vector2i(x, z), 10)
			grid.set_material(Vector2i(x, z), TerrainMaterialCatalog.ICE)
	# ...and the state that is not a material, lying on the rock shelf around it.
	for z in range(8, 13):
		for x in range(8, 13):
			if grid.material_index_at(Vector2i(x, z)) == TerrainMaterialCatalog.index_of(TerrainMaterialCatalog.STONE):
				grid.set_snow_depth(Vector2i(x, z), 2)

	_generate_material_showcase()

	# Carved tunnel mouth in the plateau: no polygons, therefore no collision (§6).
	for z in range(-2, 2):
		for x in range(14, 17):
			grid.set_hole(Vector2i(x, z), true)

	# Anchored strip: pretend a road runs here. The cascade refuses any operation
	# whose wave reaches it, which is the §4.4 rule made visible in the lab.
	for x in range(-14, -6):
		grid.set_anchor(Vector2i(x, 6), true)

	_generate_water_showcase()

	_republish_navigation()
	brush.last_message = "demo: terraces, ramps, tower, water to the west, and the material catalog to the south-west"


## Every material of the catalog as a strip, each cell carrying a different
## variant, plus a wear gradient across `grass_tall` and a snow gradient across
## `dirt`. This is the reference view for §2, §4, §6.1 and §6.2 at once: what the
## thirteen materials look like, that variants change only the picture, and that
## wear and snow are states painted over whatever is under them.
func _generate_material_showcase() -> void:
	# Two rows in the free south-west corner of the demo board, three cells per
	# material so a boundary has room to blend.
	var per_row := 7
	for material_index in TerrainMaterialCatalog.count():
		var row := material_index / per_row
		var column := material_index % per_row
		var west := -22 + column * 3
		var north := 12 + row * 4
		for z in range(north, north + 3):
			for offset in 3:
				var cell := Vector2i(west + offset, z)
				grid.set_material_index(cell, material_index)
				grid.set_variant(cell, TerrainMaterialVariants.procedural_variant(material_index, cell))
	# Wear 0 → 2 over tall grass: the one material whose weight follows it (§6.1).
	for wear in 3:
		for offset in 3:
			for z in range(20, 23):
				var cell := Vector2i(-22 + wear * 3 + offset, z)
				grid.set_material(cell, TerrainMaterialCatalog.GRASS_TALL)
				grid.set_wear(cell, wear)
	# Snow 0 → 3 over dirt: a state on top of the surface, with no repose of its
	# own — which is why it is painted here and not sculpted.
	for depth in 4:
		for offset in 3:
			for z in range(20, 23):
				var cell := Vector2i(-12 + depth * 3 + offset, z)
				grid.set_material(cell, TerrainMaterialCatalog.DIRT)
				grid.set_snow_depth(cell, depth)


## What the water layer makes of the hovered column. Depth is the number that
## decides everything (§9.7) and it is invisible in the render: a lake and a ford
## look identical from this camera until the overlay is on.
func _water_line() -> String:
	var body := water.body(water_brush.body_id)
	var head := "water [%s] tool %s  level %d  body %s" % [
		"on" if water.wet_cell_count() > 0 else "none", water_brush.tool, water_brush.level,
		body.name if body != null else "—",
	]
	if not brush.has_hover or not water.is_wet(grid, brush.hovered_cell):
		return "%s  |  cell dry" % head
	var cell := brush.hovered_cell
	return "%s  |  %s depth %d (%.1f m) %s%s" % [
		head, water.body_at(cell).name, water.depth_steps_at(grid, cell),
		water.depth_metres_at(grid, cell),
		"FORD" if water.is_ford(grid, cell) else "deep",
		"  ICE %d" % water.ice_thickness_at(cell) if water.is_frozen(cell) else "",
	]


## Steps through the bodies of the demo, so one key reaches every kind of liquid
## the lab has without a palette.
func _cycle_water_body() -> void:
	var bodies := water.bodies()
	if bodies.is_empty():
		water_brush.create_body(WaterBody.Type.LAKE)
		return
	var position := 0
	for index in bodies.size():
		if bodies[index].id == water_brush.body_id:
			position = (index + 1) % bodies.size()
			break
	water_brush.select_body(bodies[position].id)


## The three cases §9 has to get right, side by side and reachable in one view:
##
##   * a LAKE in the sand basin, deep in the middle and a ford around the rim —
##     the difference is invisible in the render and decisive in the overlay;
##   * a RIVER with a current, which is fordable but never freezes (§9.6);
##   * a LAVA pool, impassable at any depth and lighting its own banks (§9.4).
##
## Written straight into the layer, like the rest of the demo: it is scenery, not
## an author's stroke, so it must not fill the undo stack.
func _generate_water_showcase() -> void:
	var lake := water.create_body(WaterBody.Type.LAKE, 0)
	# Stops short of the material rows to the south: the catalog strip is a
	# reference view of its own and must not be flooded.
	for z in range(-14, 10):
		for x in range(-20, -14):
			water.set_cell(Vector2i(x, z), lake.id, 0)

	var river := water.create_body(WaterBody.Type.RIVER, 0)
	for z in range(-20, 5):
		for x in range(-11, -9):
			var cell := Vector2i(x, z)
			grid.set_height(cell, -1)
			grid.set_material(cell, TerrainMaterialCatalog.GRAVEL)
			water.set_cell(cell, river.id, 0)
			# Strength 2: a current strong enough to keep the reach open all winter
			# and still shallow enough to wade (§9.6, §9.7).
			river.set_flow(cell, SlopeCatalog.DIR_S, 2)

	var lava := water.create_body(WaterBody.Type.LAVA, 2)
	for z in range(6, 10):
		for x in range(16, 20):
			var cell := Vector2i(x, z)
			grid.set_height(cell, 1)
			grid.set_material(cell, TerrainMaterialCatalog.SCORCHED)
			water.set_cell(cell, lava.id, 2)

	water_brush.select_body(lake.id)


## The demo writes the grid directly rather than through the service, so nothing
## emitted `edit_committed` and the field is still describing the old board.
func _republish_navigation() -> void:
	nav_publisher.publish_all()
	water_world.rebuild_pending_now()
	if nav_overlay != null and nav_overlay.visible:
		nav_overlay.rebuild()
