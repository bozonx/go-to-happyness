extends Node3D

## Isolated lab for the grid terrain system (design_docs/core/grid_terrain_system.md).
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
##        Z undo, Y redo, G regenerate demo, N clear to flat, WASD pan, Q/E orbit.
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

var grid := TerrainGrid.new()
var service := TerrainService.new()
var wear_service := SurfaceWearService.new()
var nav_grid := NavGrid.new()
var nav_publisher := TerrainNavigationPublisher.new()

## Profiles worth checking a map against: what a citizen can climb, and what a
## loaded cart can. A ramp that only a walker can use is a supply route that
## silently is not one.
const NAV_PROFILES: Array[StringName] = [&"pedestrian", &"cart"]
var _nav_profile_index := 0

var _camera_target := Vector3(0.0, 0.0, 0.0)
var _camera_yaw := 42.0
var _camera_pitch := 52.0
var _camera_distance := 34.0
var _orbiting := false

var _hovered_cell := Vector2i.ZERO
var _has_hover := false
var _brush_size := 1
var _material_index := 0
var _variant := 0
## The catalog no longer fits on the number row, so it is paged ten at a time.
var _material_page := 0
var _wear_day := 0
var _ramp_class := SlopeCatalog.CLASS_GENTLE
var _ramp_direction := SlopeCatalog.DIR_E
var _edit_mode := TerrainEditOperation.Mode.SCULPT
var _painting := 0
var _last_message := "ready"


const CAPTURE_VIEWS: Array = [
	{"name": "overview", "target": Vector3(0.0, 0.0, 0.0), "yaw": 42.0, "pitch": 52.0, "distance": 48.0},
	{"name": "ramps", "target": Vector3(0.0, 0.5, 0.0), "yaw": 250.0, "pitch": 22.0, "distance": 18.0},
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
	{"name": "materials_catalog", "setup": &"demo", "nav": &"", "target": Vector3(-11.0, 0.0, 17.0), "yaw": 0.0, "pitch": 65.0, "distance": 30.0},
	{"name": "materials_blend_closeup", "target": Vector3(-17.0, 0.0, 14.0), "yaw": 25.0, "pitch": 30.0, "distance": 11.0},
]

var _capture_queue: Array = []
var _capture_delay := 0


func _ready() -> void:
	grid.configure(CELL_SIZE, BOARD_CELLS)
	service.configure(grid)
	wear_service.configure(service)
	terrain.configure(grid, camera)
	# Binds the two grids and keeps the field current: every committed edit
	# republishes exactly the columns it touched.
	nav_publisher.configure(grid, nav_grid, service)
	service.edit_committed.connect(_on_terrain_edited)
	nav_overlay.configure(nav_grid, NAV_PROFILES[_nav_profile_index])
	nav_overlay.visible = false
	_generate_demo()
	terrain.rebuild_pending_now()
	_update_camera()
	if OS.get_cmdline_user_args().has("--capture"):
		_capture_queue = CAPTURE_VIEWS.duplicate()
		_capture_delay = 3


func _process(delta: float) -> void:
	if not _capture_queue.is_empty():
		_process_capture()
		return
	_process_camera_keys(delta)
	_update_hover()
	_update_hud()


# --- Editing ----------------------------------------------------------------

func _brush_cells(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var radius := _brush_size - 1
	for offset_z in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			var cell := center + Vector2i(offset_x, offset_z)
			if grid.is_inside(cell):
				cells.append(cell)
	return cells


func _apply_height_brush(delta: int) -> void:
	if not _has_hover:
		return
	var operation := TerrainEditOperation.offset(_brush_cells(_hovered_cell), delta, _edit_mode)
	if _edit_mode == TerrainEditOperation.Mode.LEVEL:
		# The level tool has no direction of its own: the wheel of the height
		# brush chooses which way the plateau moves from the hovered column.
		operation = TerrainEditOperation.level(_brush_cells(_hovered_cell), grid.height_of(_hovered_cell) + delta)
	if service.apply_operation(operation):
		_last_message = "%s %+d — %d cells changed" % [
			TerrainEditOperation.mode_name(_edit_mode), delta, service.last_delta_size(),
		]
		return
	_last_message = "%s %+d REFUSED (%s)" % [
		TerrainEditOperation.mode_name(_edit_mode), delta, service.last_rejection(),
	]


func _apply_flatten() -> void:
	if not _has_hover:
		return
	var target := grid.height_of(_hovered_cell)
	if service.apply_operation(TerrainEditOperation.level(_brush_cells(_hovered_cell), target)):
		_last_message = "levelled to %d" % target
		return
	_last_message = "level REFUSED (%s)" % service.last_rejection()


func _apply_material() -> void:
	if not _has_hover:
		return
	var material_id := TerrainMaterialCatalog.ids()[_material_index]
	if service.paint_material(_brush_cells(_hovered_cell), material_id, _variant):
		# The count is the point: a material stroke commits a transaction, moves a
		# navigation weight and rebuilds zero chunks (§7.5).
		_last_message = "painted %s/%s — %d chunks queued" % [
			material_id, TerrainMaterialVariants.variant_name(_material_index, _variant),
			terrain.pending_chunk_count(),
		]
		return
	_last_message = "paint %s changed nothing" % material_id


func _apply_variant() -> void:
	if not _has_hover:
		return
	_variant = (_variant + 1) % TerrainMaterialVariants.variant_count(_material_index)
	if service.paint_variant(_brush_cells(_hovered_cell), _variant):
		_last_message = "variant %s" % TerrainMaterialVariants.variant_name(_material_index, _variant)
		return
	_last_message = "variant %d unchanged" % _variant


func _cycle_wear() -> void:
	if not _has_hover:
		return
	var next := (grid.wear_at(_hovered_cell) + 1) % (TerrainDetailCodec.MAX_WEAR + 1)
	if service.set_wear(_brush_cells(_hovered_cell), next):
		_last_message = "wear %d" % next
		return
	_last_message = "wear unchanged"


func _cycle_snow() -> void:
	if not _has_hover:
		return
	var next := (grid.snow_depth_at(_hovered_cell) + 1) % (TerrainDetailCodec.MAX_SNOW_DEPTH + 1)
	if service.set_snow_depth(_brush_cells(_hovered_cell), next):
		_last_message = "snow depth %d" % next
		return
	_last_message = "snow unchanged"


## Fakes a day of traffic over the brush: enough crossings to move the wear level,
## fed through the real `SurfaceWearService` so the throttle, the transaction and
## the navigation weight are the real ones (§6.1).
func _walk_the_brush() -> void:
	if not _has_hover:
		return
	var cells := _brush_cells(_hovered_cell)
	for _pass in SurfaceWearService.CROSSINGS_PER_WEAR_LEVEL:
		wear_service.begin_tick()
		for cell: Vector2i in cells:
			wear_service.record_crossing(cell)
	_wear_day += 1
	var raised := wear_service.flush(_wear_day)
	_last_message = "walked %d cells — %d wore down" % [cells.size(), raised.size()]


func _toggle_hole() -> void:
	if not _has_hover:
		return
	var enabled := not grid.is_hole(_hovered_cell)
	if service.set_hole(_brush_cells(_hovered_cell), enabled):
		_last_message = "hole %s" % ("cut" if enabled else "filled")
		return
	_last_message = "hole unchanged"


func _place_ramp() -> void:
	if not _has_hover:
		return
	var slope_id := SlopeCatalog.id_of_class(_ramp_class)
	if service.place_ramp(_hovered_cell, slope_id, _ramp_direction):
		_last_message = "ramp %s placed" % slope_id
		return
	# Refusal is a normal answer (§3.1): the run must be flat, free, and end at a
	# column exactly `rise` steps higher.
	_last_message = "ramp %s REFUSED (needs %d free flat cells and a +%d step at the top)" % [
		slope_id, SlopeCatalog.run_of(slope_id), SlopeCatalog.rise_of(slope_id),
	]


func _dissolve_ramp() -> void:
	if not _has_hover:
		return
	_last_message = "ramp dissolved" if service.dissolve_ramp(_hovered_cell) else "no ramp here"


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
			_painting = 1 if event.pressed else 0
			if event.pressed:
				_apply_height_brush(1)
		MOUSE_BUTTON_RIGHT:
			_painting = -1 if event.pressed else 0
			if event.pressed:
				_apply_height_brush(-1)
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
			_apply_flatten()
		KEY_P:
			_apply_material()
		KEY_B:
			_apply_variant()
		KEY_U:
			_cycle_wear()
		KEY_J:
			_cycle_snow()
		KEY_K:
			_walk_the_brush()
		KEY_SEMICOLON:
			_material_page = maxi(0, _material_page - 1)
			_last_message = "material page %d" % (_material_page + 1)
		KEY_APOSTROPHE:
			_material_page = mini((TerrainMaterialCatalog.count() - 1) / 10, _material_page + 1)
			_last_message = "material page %d" % (_material_page + 1)
		KEY_H:
			_toggle_hole()
		KEY_R:
			_place_ramp()
		KEY_X:
			_dissolve_ramp()
		KEY_C:
			_ramp_class = _next_ramp_class(_ramp_class)
			_last_message = "ramp class %d (%s)" % [_ramp_class, SlopeCatalog.id_of_class(_ramp_class)]
		KEY_V:
			var order := SlopeCatalog.ORTHOGONAL_DIRECTIONS
			_ramp_direction = order[(order.find(_ramp_direction) + 1) % order.size()]
			_last_message = "ramp direction %s" % _direction_name(_ramp_direction)
		KEY_BRACKETLEFT:
			_brush_size = maxi(1, _brush_size - 1)
		KEY_BRACKETRIGHT:
			_brush_size = mini(8, _brush_size + 1)
		KEY_M:
			nav_overlay.visible = not nav_overlay.visible
			nav_overlay.rebuild()
			_last_message = "nav overlay %s" % ("on" if nav_overlay.visible else "off")
		KEY_T:
			_nav_profile_index = (_nav_profile_index + 1) % NAV_PROFILES.size()
			nav_overlay.configure(nav_grid, NAV_PROFILES[_nav_profile_index])
			_last_message = "nav profile %s" % NAV_PROFILES[_nav_profile_index]
		KEY_TAB:
			_edit_mode = (_edit_mode + 1) % 3
			_last_message = "mode %s" % TerrainEditOperation.mode_name(_edit_mode)
		KEY_Z:
			_last_message = "undo" if service.undo() else "nothing to undo"
		KEY_Y:
			_last_message = "redo" if service.redo() else "nothing to redo"
		KEY_G:
			_generate_demo()
			_last_message = "demo terrain regenerated"
		KEY_N:
			grid.configure(CELL_SIZE, BOARD_CELLS)
			service.clear_history()
			_republish_navigation()
			_last_message = "cleared to flat"
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0:
			var slot := 9 if event.keycode == KEY_0 else event.keycode - KEY_1
			var picked := _material_page * 10 + slot
			if picked < TerrainMaterialCatalog.count():
				_material_index = picked
				_variant = TerrainMaterialVariants.clamp_variant(_material_index, _variant)
				_last_message = "material %s" % TerrainMaterialCatalog.ids()[_material_index]
		KEY_ESCAPE:
			get_tree().quit()


## What navigation makes of the hovered column, next to what the terrain stores.
## This is the line that catches the two disagreeing: a cell reading `flat` in
## the terrain and `steep` here is a cell tilted by its neighbours (§3.4).
func _nav_line() -> String:
	var profile: StringName = NAV_PROFILES[_nav_profile_index]
	var state := "on" if nav_overlay.visible else "off"
	if not _has_hover or not nav_grid.has_terrain_field():
		return "nav [%s] %s" % [profile, state]
	var field := nav_grid.terrain_field()
	var walkable := nav_grid.is_walkable(_hovered_cell, profile)
	var open_edges := 0
	for direction in NavTerrainField.DIRECTION_COUNT:
		var neighbour: Vector2i = _hovered_cell + NavTerrainField.DIRECTION_OFFSETS[direction]
		if nav_grid.is_edge_passable(_hovered_cell, neighbour, profile):
			open_edges += 1
	return "nav [%s] %s  surface class %d  %s  exits %d/8  cost ×%.2f" % [
		profile, state, field.slope_class_at(_hovered_cell),
		"walkable" if walkable else "BLOCKED", open_edges,
		nav_grid.get_cell_weight(_hovered_cell, profile) / NavGrid.DEFAULT_CELL_WEIGHT,
	]


## The publisher already refreshed the field; the overlay is presentation and
## rebuilds only when it is actually being looked at.
func _on_terrain_edited(_delta: TerrainDelta) -> void:
	if nav_overlay.visible:
		nav_overlay.rebuild()


func _next_ramp_class(current: int) -> int:
	var classes: Array[int] = []
	for slope_id: StringName in SlopeCatalog.ramp_ids():
		classes.append(SlopeCatalog.slope_class_of(slope_id))
	var position := classes.find(current)
	return classes[(position + 1) % classes.size()] if position >= 0 else classes[0]


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

func _update_hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		camera.project_ray_origin(mouse),
		camera.project_ray_origin(mouse) + camera.project_ray_normal(mouse) * 500.0,
	)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	var was_hovered := _hovered_cell
	_has_hover = not hit.is_empty()
	if _has_hover:
		# Nudge into the surface so a hit exactly on a shared edge resolves to the
		# column the cursor is visually over.
		var point: Vector3 = hit["position"] - (hit["normal"] as Vector3) * 0.01
		_hovered_cell = grid.cell_from_position(point)
		_has_hover = grid.is_inside(_hovered_cell)
	hover_marker.visible = _has_hover
	if not _has_hover:
		return
	var center := grid.cell_center(_hovered_cell)
	hover_marker.position = Vector3(center.x, center.y + 0.03, center.z)
	hover_marker.scale = Vector3(float(_brush_size * 2 - 1), 1.0, float(_brush_size * 2 - 1))
	if _painting != 0 and was_hovered != _hovered_cell:
		_apply_height_brush(_painting)


# --- HUD --------------------------------------------------------------------

func _update_hud() -> void:
	var lines: Array[String] = []
	lines.append("TERRAIN LAB — %d×%d cells, Δh %.2f m, chunk %d" % [
		BOARD_CELLS, BOARD_CELLS, TerrainGrid.HEIGHT_STEP, TerrainGrid.CHUNK_CELLS,
	])
	if _has_hover:
		var cell := grid.cell_at(_hovered_cell)
		lines.append("cell (%d, %d)  h=%d (%.2f m)  %s  slope=%s dir=%s idx=%d%s" % [
			_hovered_cell.x, _hovered_cell.y, cell.height, cell.height * TerrainGrid.HEIGHT_STEP,
			cell.material_id, cell.slope_id, _direction_name(cell.slope_dir), cell.slope_index,
			"  HOLE" if cell.is_hole() else "",
		])
		# The surface line: what the column is made of, how worn and snowed it is,
		# and what that costs to walk on. Weight is the only one of the four that
		# the simulation actually feels.
		var material_index := grid.material_index_at(_hovered_cell)
		lines.append("surface variant=%s wear=%d snow=%d  weight ×%.2f  repose %s  soil %s  face %s  wear→%d" % [
			TerrainMaterialVariants.variant_name(material_index, cell.variant), cell.wear, cell.snow_depth,
			grid.surface_weight_at(_hovered_cell),
			SlopeCatalog.id_of_class(TerrainMaterialCatalog.repose_class_of_index(material_index)),
			TerrainMaterialCatalog.soil_of_index(material_index),
			TerrainMaterialCatalog.cliff_material_of_index(material_index),
			wear_service.progress_at(_hovered_cell),
		])
	else:
		lines.append("cell —")
		lines.append("surface —")
	lines.append("mode %s  brush %d  paint %s/%s (page %d)  ramp %s → %s" % [
		TerrainEditOperation.mode_name(_edit_mode).to_upper(), _brush_size,
		TerrainMaterialCatalog.ids()[_material_index],
		TerrainMaterialVariants.variant_name(_material_index, _variant),
		_material_page + 1,
		SlopeCatalog.id_of_class(_ramp_class), _direction_name(_ramp_direction),
	])
	lines.append(_palette_line())
	lines.append("undo %d  redo %d  |  pending chunks: %d" % [
		service.undo_depth(), service.redo_depth(), terrain.pending_chunk_count(),
	])
	lines.append(_nav_line())
	lines.append("> %s" % _last_message)
	lines.append("")
	lines.append("LMB raise · RMB lower · MMB orbit · wheel zoom · WASD pan · Q/E turn")
	lines.append("Tab mode (sculpt/terrace/level) · Z undo · Y redo · F level · P paint · 1-5 material")
	lines.append("B variant · U wear · J snow · K walk brush · ; \' material page")
	lines.append("H hole · R ramp · X unramp · C class · V dir · [ ] brush · G demo · N clear · Esc quit")
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
		parts.append("[%s]%s" % [key, name.to_upper() if index == _material_index else name])
	return "  ".join(parts)


## Batch capture: one frame to move the camera, a couple to let the renderer
## settle, then the image. Keeps the lab usable as a regression reference for
## meshing changes without a human at the mouse.
func _process_capture() -> void:
	var view: Dictionary = _capture_queue[0]
	if _capture_delay == 3:
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
	_capture_delay = 3
	if _capture_queue.is_empty():
		get_tree().quit()


## Three identical +5 sculpt edits on three materials, side by side: grass makes a
## pyramid, sand a wide terraced mound, rock a sheer column (§4.2).
func _setup_cascade_scene() -> void:
	grid.configure(CELL_SIZE, BOARD_CELLS)
	service.clear_history()
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
	_last_message = "cascade: mud / sand / rock, +5 steps each"


func _direction_name(direction: int) -> String:
	match direction:
		SlopeCatalog.DIR_N: return "N"
		SlopeCatalog.DIR_E: return "E"
		SlopeCatalog.DIR_S: return "S"
		SlopeCatalog.DIR_W: return "W"
	return str(direction)


# --- Demo terrain -----------------------------------------------------------

## Hand-built showcase covering every feature the mesher has to get right:
## terraces with vertical faces, a two-stage gentle ramp, a moderate ramp, a
## carved hole, a stone tower and material patches.
func _generate_demo() -> void:
	grid.configure(CELL_SIZE, BOARD_CELLS)
	# The demo is scenery, not a player edit: it writes the grid directly and
	# starts the history empty.
	service.clear_history()

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

	_republish_navigation()
	_last_message = "demo: terraces, ramps, tower, and the material catalog to the south-west"


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


## The demo writes the grid directly rather than through the service, so nothing
## emitted `edit_committed` and the field is still describing the old board.
func _republish_navigation() -> void:
	nav_publisher.publish_all()
	if nav_overlay != null and nav_overlay.visible:
		nav_overlay.rebuild()
