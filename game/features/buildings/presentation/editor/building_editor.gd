class_name BuildingEditor
extends Node3D

## Modular building editor for frame construction and active work zones.
##
## Runs in two modes (see design_docs/engine/modular_building_editor.md §5):
##   * Dev mode  — launched by opening this scene directly in Godot; saves to
##     res://game/content/core/buildings and exposes the developer panel.
##   * Player mode — launched from the main menu; saves to user://custom_buildings.

signal back_requested

const CameraControllerScript = preload("res://game/features/world/presentation/camera_controller.gd")
const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BuildingGridModelScript = preload("res://game/features/buildings/domain/editor/building_grid_model.gd")
const BlueprintRepositoryScript = preload("res://game/features/buildings/presentation/editor/blueprint_repository.gd")
const BlockMeshLibraryScript = preload("res://game/features/buildings/presentation/editor/block_mesh_library.gd")
const DecorModeControllerScript = preload("res://game/features/buildings/presentation/editor/decor_mode_controller.gd")
const ZonesModeControllerScript = preload("res://game/features/buildings/presentation/editor/zones_mode_controller.gd")

## Footprint centre marks. The band is faint on purpose: it must not compete
## with block colours, only hint where the building's origin will sit in game.
const CENTRE_LINE_COLOR := Color(1.0, 0.82, 0.18, 1.0)
const CENTRE_BAND_COLOR := Color(1.0, 0.82, 0.18, 0.12)

enum Tool { PLACE, ERASE }
enum Brush { LINE, RECT }
enum EditMode { FRAME, FINISHES, DECOR, ZONES }

@export_group("Editor")
## Forces developer mode when the scene is opened/run directly. The main menu
## clears this via GameLaunchManager before switching in player mode.
@export var dev_mode: bool = true

var grid_model: BuildingGridModelScript
var blueprint: BuildingBlueprintScript
var repository: BlueprintRepositoryScript
var mesh_library: BlockMeshLibraryScript

var current_block_id: StringName = &""
var current_variant: StringName = &""
var current_anchor: int = BuildingBlockCatalogScript.ANCHOR_CENTER
var current_material_id: StringName = BuildingMaterialCatalogScript.DEFAULT_ID
var current_rot: int = 0
var current_rot_x: int = 0
var current_rot_z: int = 0
var current_tool: int = Tool.PLACE
var current_brush: int = Brush.LINE
var active_layer: int = 0
var cursor_cell: Vector3i = Vector3i.ZERO
var cursor_valid: bool = false
var cursor_hit_pos: Vector3 = Vector3.ZERO

var current_mode: int = EditMode.FRAME

## Decor mode (design §3.3) lives in its own controller; see decor_mode_controller.gd.
var decor_mode: DecorModeControllerScript = null
## Zones mode lives in its own controller; see zones_mode_controller.gd.
var zones_mode: ZonesModeControllerScript = null

## True when there are unsaved changes. Checked before scene transitions.
var _dirty: bool = false

## Frame-mode drag painting state.
var _painting: bool = false
var _last_paint_cell: Vector3i = Vector3i.ZERO
## Fixed corner of the current rectangle brush drag (the cell first pressed).
var _paint_anchor: Vector3i = Vector3i.ZERO
## Shift + right mouse is a temporary erase stroke, separate from camera orbit.
var _shift_erasing: bool = false
## A picked frame assembly.  It retains every sub-block anchored in the source
## voxel and is stamped as one brush on subsequent normal paint strokes.
var _stamp_brush: Array[BlueprintBlock] = []
var _shift_hover_block: BlueprintBlock = null

var _block_nodes: Dictionary = {}  ## BuildingGridModel placement key -> MeshInstance3D
@onready var _camera_controller: CameraController = %CameraController
@onready var _blocks_root: Node3D = %BlocksRoot
@onready var _ground: MeshInstance3D = get_node("Ground") as MeshInstance3D
@onready var _ghost: MeshInstance3D = %Ghost
@onready var _layer_plane: MeshInstance3D = %LayerPlane
@onready var _export_mesh_btn: Button = %ExportMeshBtn
@onready var _navmesh_preview_btn: Button = %NavMeshPreviewBtn
var _panning: bool = false
var _orbiting: bool = false
var _shift_hover_visual: MeshInstance3D = null

## Cached state to skip redundant ghost updates in _process.
var _ghost_cell: Vector3i = Vector3i.ZERO
var _ghost_tool: int = -1
var _ghost_rot: int = -1
var _ghost_valid: bool = false

# UI bindings (linked to scene unique nodes in building_editor.tscn).
@onready var _name_edit: LineEdit = %NameEdit
@onready var _id_edit: LineEdit = %IdEdit
@onready var _category_option: OptionButton = %CategoryOption
@onready var _style_option: OptionButton = %StyleOption
@onready var _material_option: OptionButton = %MaterialOption
@onready var _brush_line_btn: Button = %BrushLineBtn
@onready var _brush_rect_btn: Button = %BrushRectBtn
@onready var _fallback_edit: LineEdit = %FallbackEdit
@onready var _footprint_x_spin: SpinBox = %FootprintXSpin
@onready var _footprint_z_spin: SpinBox = %FootprintZSpin
@onready var _entrance_x_spin: SpinBox = %EntranceXSpin
@onready var _entrance_z_spin: SpinBox = %EntranceZSpin
@onready var _palette_panel: PanelContainer = %PalettePanel
@onready var _palette_container: VBoxContainer = %PaletteContainer
@onready var _status_label: Label = %StatusLabel
@onready var _layer_label: Label = %LayerLabel
@onready var _count_label: Label = %CountLabel
@onready var _tool_place_btn: Button = %ToolPlaceBtn
@onready var _tool_erase_btn: Button = %ToolEraseBtn
@onready var _metadata_panel: PanelContainer = %MetadataPanel
@onready var _load_popup: PopupPanel = %LoadPopup
@onready var _load_list: ItemList = %LoadList

@onready var _cost_header_btn: Label = %CostHeaderBtn
@onready var _cost_container: VBoxContainer = %CostContainer
@onready var _cost_mode_option: OptionButton = %CostModeOption
@onready var _cost_block_summary_label: Label = %CostBlockSummaryLabel
@onready var _cost_breakdown_vbox: VBoxContainer = %CostBreakdownVBox
@onready var _extra_costs_vbox: VBoxContainer = %ExtraCostsVBox
@onready var _add_extra_cost_btn: Button = %AddExtraCostBtn
@onready var _total_cost_label: Label = %TotalCostLabel

@onready var _mode_frame_btn: Button = %ModeFrameBtn
@onready var _mode_finishes_btn: Button = %ModeFinishesBtn
@onready var _mode_decor_btn: Button = %ModeDecorBtn
@onready var _mode_zones_btn: Button = %ModeZonesBtn
@onready var _frame_toolbar: HBoxContainer = %FrameToolbar

@onready var _back_btn: Button = %BackBtn
@onready var _new_btn: Button = %NewBtn
@onready var _load_btn: Button = %LoadBtn
@onready var _save_btn: Button = %SaveBtn
@onready var _rot_x_btn: Button = %RotXBtn
@onready var _rot_btn: Button = %RotBtn
@onready var _rot_z_btn: Button = %RotZBtn
@onready var _layer_down_btn: Button = %LayerDownBtn
@onready var _layer_up_btn: Button = %LayerUpBtn
@onready var _metadata_vbox: VBoxContainer = %MetadataVBox
@onready var _path_hint_label: Label = %PathHintLabel

var _mode_buttons: Dictionary = {}
var _palette_buttons: Dictionary = {}  ## StringName -> Button
var _brush_inspector: Control = null  ## contextual variant strip + anchor pad
## Prevent value_changed callbacks from overwriting one footprint dimension
## with the stale value of the other while a loaded blueprint updates both UI
## fields.
var _syncing_metadata_fields := false


func _ready() -> void:
	_resolve_launch_mode()
	grid_model = BuildingGridModelScript.new()
	blueprint = BuildingBlueprintScript.new()
	repository = BlueprintRepositoryScript.new(dev_mode)
	mesh_library = BlockMeshLibraryScript.new()

	_init_world()
	_setup_ui()
	_refresh_layer_plane()
	_refresh_ghost()
	_connect_back_navigation()
	_update_status("Готово. Режим: %s" % ("Разработчик" if dev_mode else "Игрок"))


func _resolve_launch_mode() -> void:
	if not OS.has_feature("editor"):
		dev_mode = false
	var launch_mgr := get_node_or_null("/root/GameLaunchManager")
	if launch_mgr != null and "editor_player_mode" in launch_mgr:
		if bool(launch_mgr.get("editor_player_mode")):
			dev_mode = false


func _connect_back_navigation() -> void:
	var launch_mgr := get_node_or_null("/root/GameLaunchManager")
	if launch_mgr != null and launch_mgr.has_method("return_to_main_menu"):
		back_requested.connect(launch_mgr.return_to_main_menu)
	else:
		back_requested.connect(_fallback_back_to_menu)


# ---------------------------------------------------------------------------
# World setup — static nodes come from the scene; only dynamic init here.
# ---------------------------------------------------------------------------

func _init_world() -> void:
	_focus_footprint_center()
	_camera_controller.camera_distance = 18.0
	_camera_controller.apply_position()

	_refresh_building_grid_visuals()
	_shift_hover_visual = MeshInstance3D.new()
	_shift_hover_visual.name = "ShiftHoverBlock"
	_shift_hover_visual.visible = false
	_blocks_root.add_child(_shift_hover_visual)

	decor_mode = DecorModeControllerScript.new()
	add_child(decor_mode)
	zones_mode = ZonesModeControllerScript.new()
	add_child(zones_mode)


## The authored footprint is the only editable board. Its centre axes are
## yellow so even-sized grids still have an obvious visual centre.
func _refresh_building_grid_visuals() -> void:
	if blueprint == null:
		return
	var width := blueprint.footprint.x
	var depth := blueprint.footprint.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for x in range(width + 1):
		st.set_color(Color(0.30, 0.34, 0.40, 0.8))
		st.add_vertex(Vector3(x, 0.0, 0.0)); st.add_vertex(Vector3(x, 0.0, depth))
	for z in range(depth + 1):
		st.set_color(Color(0.30, 0.34, 0.40, 0.8))
		st.add_vertex(Vector3(0.0, 0.0, z)); st.add_vertex(Vector3(width, 0.0, z))
	# An even dimension has its centre on a grid line, so a line marks it exactly.
	# An odd one has its centre inside a cell strip, where a line would cut cells
	# in half — that strip gets tinted instead (see `_append_centre_bands`).
	st.set_color(CENTRE_LINE_COLOR)
	if width % 2 == 0:
		st.add_vertex(Vector3(width * 0.5, 0.012, 0.0)); st.add_vertex(Vector3(width * 0.5, 0.012, depth))
	if depth % 2 == 0:
		st.add_vertex(Vector3(0.0, 0.012, depth * 0.5)); st.add_vertex(Vector3(width, 0.012, depth * 0.5))
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, mat)
	_append_centre_bands(mesh, width, depth)
	%GridLines.mesh = mesh
	_layer_plane.mesh = mesh


## Tinted quad over the middle cell strip of an odd-sized dimension. Needs its
## own surface: the grid surface is a line primitive and cannot carry triangles.
## When both dimensions are odd the two bands overlap on the exact centre cell,
## which reads as a slightly brighter square — that is the intent.
func _append_centre_bands(mesh: ArrayMesh, width: int, depth: int) -> void:
	if width % 2 == 0 and depth % 2 == 0:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(CENTRE_BAND_COLOR)
	if width % 2 == 1:
		var x := float((width - 1) / 2)
		_add_band_quad(st, Vector2(x, 0.0), Vector2(x + 1.0, float(depth)))
	if depth % 2 == 1:
		var z := float((depth - 1) / 2)
		_add_band_quad(st, Vector2(0.0, z), Vector2(float(width), z + 1.0))
	st.commit(mesh)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


## Horizontal quad spanning `from`…`to` on the XZ plane, just under the centre
## lines so the two never z-fight.
func _add_band_quad(st: SurfaceTool, from: Vector2, to: Vector2) -> void:
	const Y := 0.011
	var a := Vector3(from.x, Y, from.y)
	var b := Vector3(to.x, Y, from.y)
	var c := Vector3(to.x, Y, to.y)
	var d := Vector3(from.x, Y, to.y)
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)


## Grid coordinates stay stable (0…width, 0…depth) for saved blueprints;
## only the view moves, so expanding a footprint grows around the screen centre.
func _focus_footprint_center() -> void:
	if _camera_controller == null or blueprint == null:
		return
	var centre := Vector3(blueprint.footprint.x * 0.5, 0.0, blueprint.footprint.y * 0.5)
	_camera_controller.camera_target = centre
	if _ground != null:
		_ground.position = centre + Vector3(0.0, -0.01, 0.0)
		var ground_mesh := _ground.mesh as PlaneMesh
		if ground_mesh != null:
			var margin := 16.0
			ground_mesh.size = Vector2(maxf(64.0, float(blueprint.footprint.x) + margin), maxf(64.0, float(blueprint.footprint.y) + margin))
	_camera_controller.apply_position()


# ---------------------------------------------------------------------------
# Input & interaction
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _camera_controller != null:
		_camera_controller.update(delta)
	# A Shift+RMB erase stroke owns the button until RMB itself is released.  In
	# particular, releasing Shift first must not hand the still-held button back
	# to the camera orbit controller.
	if _shift_erasing:
		_orbiting = false
	_update_cursor()
	_refresh_shift_hover()
	if current_mode == EditMode.DECOR:
		decor_mode.refresh_ghost()
		return
	if current_mode == EditMode.ZONES:
		return
	# Ghost refresh is cheap but redundant when nothing changed; skip via cache.
	if cursor_valid and (cursor_cell != _ghost_cell or current_tool != _ghost_tool or current_rot != _ghost_rot or cursor_valid != _ghost_valid):
		_refresh_ghost()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		if _camera_controller == null:
			pass
		elif _orbiting:
			_camera_controller.rotate_yaw_pitch(event.relative)
		elif _panning:
			_camera_controller.pan(event.relative)
		elif _painting:
			_update_cursor()
			if cursor_valid:
				if current_mode == EditMode.DECOR:
					decor_mode.on_drag()
				elif current_mode == EditMode.ZONES:
					zones_mode.on_mouse_motion(event)
				elif current_mode == EditMode.FRAME and current_brush == Brush.RECT:
					_paint_rect(_paint_anchor, cursor_cell)
				else:
					_paint_line(_last_paint_cell, cursor_cell)
				_last_paint_cell = cursor_cell
		elif _shift_erasing:
			_update_cursor()
			if cursor_valid:
				_erase_line(_last_paint_cell, cursor_cell)
				_last_paint_cell = cursor_cell
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and _pointer_over_ui():
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			if _shift_erasing:
				# This is the release of a Shift-started stroke.  Do not inspect the
				# modifier here: the user may release Shift before the mouse button.
				if not event.pressed:
					_shift_erasing = false
				_orbiting = false
				return
			if current_mode == EditMode.FRAME and event.pressed and event.shift_pressed:
				_shift_erasing = true
				_orbiting = false
				_last_paint_cell = cursor_cell
				_erase_hovered_block_or_cell()
				return
			if current_mode == EditMode.DECOR and event.pressed and event.shift_pressed:
				_orbiting = false
				decor_mode.erase_at_cursor()
				return
			_orbiting = event.pressed
		MOUSE_BUTTON_MIDDLE:
			if event.pressed and current_mode == EditMode.FRAME and event.shift_pressed:
				_pick_stamp_brush()
				return
			_panning = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom(-2.0)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom(2.0)
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				if current_mode == EditMode.FRAME and event.shift_pressed:
					_pick_single_block()
					return
				if current_mode == EditMode.ZONES:
					if zones_mode.handle_mouse_button(event):
						_painting = zones_mode.is_painting()
						_last_paint_cell = cursor_cell
					return
				elif current_mode == EditMode.DECOR:
					decor_mode.on_left_pressed()
					_painting = true
				else:
					_painting = true
					_last_paint_cell = cursor_cell
					_paint_anchor = cursor_cell
					if current_brush == Brush.RECT:
						_paint_rect(_paint_anchor, cursor_cell)
					else:
						_apply_tool_at_cursor()
			else:
				_painting = false
				if current_mode == EditMode.DECOR:
					decor_mode.on_left_released()
				elif current_mode == EditMode.ZONES:
					zones_mode.handle_mouse_button(event)



func _handle_key(event: InputEventKey) -> void:
	# Decor owns its shortcuts. Do not let frame-only bindings (E, etc.) change
	# hidden frame state while the contextual decor mode is active.
	if current_mode == EditMode.DECOR:
		decor_mode.handle_key(event)
		return
	match event.keycode:
		KEY_Z:
			_cycle_rotation_z(-1 if event.shift_pressed else 1)
		KEY_X:
			_cycle_rotation_x(-1 if event.shift_pressed else 1)
		KEY_C, KEY_R:
			_cycle_rotation(-1 if event.shift_pressed else 1)
		KEY_E:
			_set_tool(Tool.ERASE)
		KEY_L:
			_on_brush_line_pressed()
		KEY_M:
			_on_brush_rect_pressed()
		KEY_PAGEUP:
			_set_layer(active_layer + 1)
		KEY_PAGEDOWN:
			_set_layer(active_layer - 1)
		KEY_ESCAPE:
			_clear_block_selection()


func _zoom(amount: float) -> void:
	if _camera_controller == null:
		return
	var dist := _camera_controller.camera_distance
	_camera_controller.camera_distance = clampf(dist + amount, 4.0, 60.0)
	_camera_controller.apply_position()


func _update_cursor() -> void:
	if _camera_controller == null:
		cursor_valid = false
		_refresh_ghost()
		return
	var camera := _camera_controller.camera
	if camera == null:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var plane_y := float(active_layer)
	if absf(dir.y) < 0.0001:
		cursor_valid = false
		_refresh_ghost()
		return
	var t := (plane_y - from.y) / dir.y
	if t < 0.0:
		cursor_valid = false
		_refresh_ghost()
		return
	var hit := from + dir * t
	# Decor placement is sub-cell, so it needs the raw intersection, not just the
	# cell the frame tools work in.
	cursor_hit_pos = hit
	cursor_cell = Vector3i(int(floor(hit.x)), active_layer, int(floor(hit.z)))
	cursor_valid = true
	_refresh_ghost()


func _apply_tool_at_cursor() -> void:
	if not cursor_valid:
		return
	_apply_tool_at_cell(cursor_cell)
	_refresh_ghost()


func _apply_tool_at_cell(cell: Vector3i) -> void:
	match current_tool:
		Tool.PLACE:
			if current_block_id.is_empty() and _stamp_brush.is_empty():
				return
			if not _stamp_brush.is_empty():
				_apply_stamp_at_cell(cell)
			elif _is_block_in_bounds(cell, current_block_id, current_variant, current_rot) and grid_model.place(cell, current_block_id, current_rot, current_material_id, current_variant, current_anchor, current_rot_x, current_rot_z):
				_spawn_or_update_block_node(grid_model.get_block_at(cell))
				_update_count()
				_mark_dirty()
		Tool.ERASE:
			var target := grid_model.get_block_at(cell)
			if grid_model.erase(cell):
				if target != null:
					_remove_block_node(target)
				_update_count()
				_mark_dirty()


## Stamps the sub-block composition collected with Shift + middle click.  The
## source voxel becomes the origin, so this also supports an assembly that
## contains multi-cell pieces anchored around it.
func _apply_stamp_at_cell(cell: Vector3i) -> void:
	if _stamp_brush.is_empty():
		return
	var origin := _stamp_brush[0].pos
	for block in _stamp_brush:
		var target := cell + (block.pos - origin)
		if not _is_block_in_bounds(target, block.block_id, block.variant, block.rot) or not grid_model.can_place(
			target, block.block_id, block.rot, block.material_id, block.variant,
			block.anchor, block.rot_x, block.rot_z):
			return
	for block in _stamp_brush:
		var target := cell + (block.pos - origin)
		if grid_model.place(target, block.block_id, block.rot, block.material_id, block.variant,
			block.anchor, block.rot_x, block.rot_z):
			_spawn_or_update_block_node(grid_model.get_block_at(target))
	_update_count()
	_mark_dirty()


func _erase_hovered_block_or_cell() -> void:
	if not cursor_valid:
		return
	var target := _block_under_mouse()
	if target != null and grid_model.erase_block(target):
		_set_layer(target.pos.y)
		_remove_block_node(target)
		_update_count()
		_mark_dirty()
		_refresh_ghost()
		return
	_apply_erase_at_cell(cursor_cell)


func _apply_erase_at_cell(cell: Vector3i) -> void:
	var target := grid_model.get_block_at(cell)
	if target != null and grid_model.erase_block(target):
		_remove_block_node(target)
		_update_count()
		_mark_dirty()


func _erase_line(from_cell: Vector3i, to_cell: Vector3i) -> void:
	for cell in _bresenham_cells(from_cell, to_cell):
		_apply_erase_at_cell(cell)
	_refresh_ghost()


func _paint_line(from_cell: Vector3i, to_cell: Vector3i) -> void:
	for cell in _bresenham_cells(from_cell, to_cell):
		_apply_tool_at_cell(cell)
	_refresh_ghost()


## Bresenham line algorithm on the XZ plane. Y is always active_layer.
func _bresenham_cells(from_cell: Vector3i, to_cell: Vector3i) -> Array[Vector3i]:
	var dx := absi(to_cell.x - from_cell.x)
	var dz := absi(to_cell.z - from_cell.z)
	var sx := 1 if to_cell.x > from_cell.x else -1
	var sz := 1 if to_cell.z > from_cell.z else -1
	var x := from_cell.x
	var z := from_cell.z
	var err := dx - dz
	var cells: Array[Vector3i] = []
	while true:
		cells.append(Vector3i(x, active_layer, z))
		if x == to_cell.x and z == to_cell.z:
			break
		var e2 := 2 * err
		if e2 > -dz:
			err -= dz
			x += sx
		if e2 < dx:
			err += dx
			z += sz
	return cells


func _paint_rect(from_cell: Vector3i, to_cell: Vector3i) -> void:
	var x0 := mini(from_cell.x, to_cell.x)
	var x1 := maxi(from_cell.x, to_cell.x)
	var z0 := mini(from_cell.z, to_cell.z)
	var z1 := maxi(from_cell.z, to_cell.z)
	var y := active_layer
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			_apply_tool_at_cell(Vector3i(x, y, z))
	_refresh_ghost()


## Shift is a direct manipulation modifier in frame mode.  Unlike the old
## rectangle shortcut it never changes the paint brush: it exposes the exact
## sub-block under the cursor and renders a translucent duplicate over it.
func _refresh_shift_hover() -> void:
	if _shift_hover_visual == null:
		return
	_shift_hover_block = null
	if current_mode != EditMode.FRAME or not Input.is_key_pressed(KEY_SHIFT) or not cursor_valid:
		_shift_hover_visual.visible = false
		return
	var block := _block_under_mouse()
	if block == null:
		_shift_hover_visual.visible = false
		return
	_shift_hover_block = block
	_shift_hover_visual.mesh = mesh_library.mesh_for(block.block_id, block.variant)
	_shift_hover_visual.position = Vector3(block.pos) + BlockMeshLibraryScript.local_offset(
		block.block_id, block.variant, block.rot, block.anchor, 0.0, block.rot_x, block.rot_z)
	_shift_hover_visual.rotation = block.rotation_euler()
	_shift_hover_visual.material_override = mesh_library.ghost_material(true)
	_shift_hover_visual.visible = true


func _block_under_mouse() -> BlueprintBlock:
	if _camera_controller == null or _camera_controller.camera == null:
		return null
	var camera := _camera_controller.camera
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var closest: BlueprintBlock = null
	var closest_distance := INF
	for block: BlueprintBlock in grid_model.all_blocks():
		var aabb := BuildingBlockCatalogScript.occupied_aabb(block.pos, block.block_id,
			block.variant, block.rot, block.anchor, block.rot_x, block.rot_z)
		var distance := _ray_aabb_entry_distance(origin, direction, aabb)
		if distance >= 0.0 and distance < closest_distance:
			closest = block
			closest_distance = distance
	return closest


## Slab intersection gives the nearest hit, whereas a broad-phase cell lookup
## would always choose whichever compatible block happened to be placed last.
func _ray_aabb_entry_distance(origin: Vector3, direction: Vector3, aabb: AABB) -> float:
	var t_min := -INF
	var t_max := INF
	for axis in 3:
		var start: float = origin[axis]
		var ray: float = direction[axis]
		var lower: float = aabb.position[axis]
		var upper: float = aabb.end[axis]
		if absf(ray) < 0.000001:
			if start < lower or start > upper:
				return -1.0
			continue
		var first := (lower - start) / ray
		var last := (upper - start) / ray
		if first > last:
			var swap := first
			first = last
			last = swap
		t_min = maxf(t_min, first)
		t_max = minf(t_max, last)
		if t_min > t_max:
			return -1.0
	if t_max < 0.0:
		return -1.0
	return maxf(0.0, t_min)


func _pick_single_block(retain_stamp: bool = false) -> void:
	var block := _block_under_mouse()
	if block == null:
		_update_status("Под Shift нет блока для выбора.")
		return
	_set_layer(block.pos.y)
	_select_block(block.block_id, block.variant, retain_stamp)
	current_material_id = block.material_id
	current_anchor = block.anchor
	current_rot = block.rot
	current_rot_x = block.rot_x
	current_rot_z = block.rot_z
	_select_material_in_option(current_material_id)
	_rebuild_brush_inspector()
	_update_rotation_label()
	_refresh_ghost()
	_update_status("Выбран элемент %s." % block.block_id)


func _pick_stamp_brush() -> void:
	var block := _block_under_mouse()
	if block == null:
		_update_status("Под Shift нет блока для кисти.")
		return
	_stamp_brush.clear()
	for source in grid_model.blocks_anchored_at(block.pos):
		_stamp_brush.append(BlueprintBlock.new(source.pos, source.block_id, source.rot,
			source.material_id, source.variant, source.anchor, source.rot_x, source.rot_z))
	_pick_single_block(true)
	_update_status("Кисть: узел из %d подблок(ов)." % _stamp_brush.size())


func _select_material_in_option(material_id: StringName) -> void:
	for index in _material_option.item_count:
		if _material_option.get_item_metadata(index) == material_id:
			_material_option.select(index)
			return


func _pointer_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


# ---------------------------------------------------------------------------
# Block visuals
# ---------------------------------------------------------------------------

func _spawn_or_update_block_node(block: BlueprintBlock) -> void:
	var key := grid_model.placement_key_for(block)
	var node: MeshInstance3D = _block_nodes.get(key, null)
	if node == null:
		node = MeshInstance3D.new()
		_blocks_root.add_child(node)
		_block_nodes[key] = node
	node.mesh = mesh_library.mesh_for(block.block_id, block.variant)
	node.material_override = mesh_library.material_for(block.material_id)
	node.position = Vector3(block.pos) + BlockMeshLibraryScript.local_offset(block.block_id, block.variant, block.rot, block.anchor, 0.0, block.rot_x, block.rot_z)
	node.rotation = block.rotation_euler()


func _remove_block_node(block: BlueprintBlock) -> void:
	var key := grid_model.placement_key_for(block)
	var node: MeshInstance3D = _block_nodes.get(key, null)
	if node != null:
		node.queue_free()
		_block_nodes.erase(key)


func _rebuild_all_block_nodes() -> void:
	for node in _block_nodes.values():
		node.queue_free()
	_block_nodes.clear()
	for block in grid_model.all_blocks():
		_spawn_or_update_block_node(block)
	_update_count()


func _refresh_ghost() -> void:
	_ghost_cell = cursor_cell
	_ghost_tool = current_tool
	_ghost_rot = current_rot
	_ghost_valid = cursor_valid
	if current_mode == EditMode.DECOR:
		_ghost.visible = false
		decor_mode.refresh_ghost()
		return
	if current_mode == EditMode.ZONES or not cursor_valid:
		_ghost.visible = false
		return
	if current_tool == Tool.PLACE and current_block_id.is_empty() and _stamp_brush.is_empty():
		_ghost.visible = false
		return

	_ghost.visible = true
	if current_tool == Tool.ERASE:
		var target := grid_model.get_block_at(cursor_cell)
		if target == null:
			_ghost.mesh = mesh_library.mesh_for(current_block_id, current_variant)
			_ghost.rotation = _current_ghost_euler()
			_ghost.position = Vector3(cursor_cell) + BlockMeshLibraryScript.local_offset(current_block_id, current_variant, current_rot, current_anchor, 0.0, current_rot_x, current_rot_z)
			_ghost.material_override = mesh_library.ghost_material(false)
		else:
			_ghost.mesh = mesh_library.mesh_for(target.block_id, target.variant)
			_ghost.rotation = target.rotation_euler()
			_ghost.position = Vector3(target.pos) + BlockMeshLibraryScript.local_offset(target.block_id, target.variant, target.rot, target.anchor, 0.0, target.rot_x, target.rot_z)
			_ghost.material_override = mesh_library.ghost_material(false)
	else:
		_ghost.mesh = mesh_library.mesh_for(current_block_id, current_variant)
		_ghost.rotation = _current_ghost_euler()
		_ghost.position = Vector3(cursor_cell) + BlockMeshLibraryScript.local_offset(current_block_id, current_variant, current_rot, current_anchor, 0.0, current_rot_x, current_rot_z)
		_ghost.material_override = mesh_library.ghost_material(_is_block_in_bounds(cursor_cell, current_block_id, current_variant, current_rot) and grid_model.can_place(
			cursor_cell, current_block_id, current_rot, current_material_id, current_variant,
			current_anchor, current_rot_x, current_rot_z))


func _is_block_in_bounds(cell: Vector3i, block_id: StringName, variant: StringName, rot: int) -> bool:
	for covered: Vector3i in BuildingGridModelScript.occupied_cells(cell, block_id, variant, rot):
		if not _is_cell_in_bounds(covered):
			return false
	return true


func _is_cell_in_bounds(cell: Vector3i) -> bool:
	return cell.x >= 0 and cell.z >= 0 and cell.x < blueprint.footprint.x and cell.z < blueprint.footprint.y


## Euler rotation of the placement ghost, combining all three quarter-turn axes.
func _current_ghost_euler() -> Vector3:
	return Vector3(
		deg_to_rad(90.0 * float(current_rot_x)),
		deg_to_rad(90.0 * float(current_rot)),
		deg_to_rad(90.0 * float(current_rot_z)))


func _refresh_layer_plane() -> void:
	if _layer_plane != null:
		_layer_plane.position = Vector3(0.0, float(active_layer), 0.0)


# ---------------------------------------------------------------------------
# State changes
# ---------------------------------------------------------------------------

func _set_tool(tool_id: int) -> void:
	current_tool = tool_id
	if _tool_place_btn != null:
		_tool_place_btn.button_pressed = tool_id == Tool.PLACE
	if _tool_erase_btn != null:
		_tool_erase_btn.button_pressed = tool_id == Tool.ERASE
	_refresh_ghost()


func _rebuild_material_options() -> void:
	if _material_option == null:
		return
	_material_option.clear()
	var current_ok := false
	for material in BuildingMaterialCatalogScript.materials_for_era(blueprint.category):
		_material_option.add_item(material["name"])
		_material_option.set_item_metadata(_material_option.item_count - 1, material["id"])
		if material["id"] == current_material_id:
			current_ok = true
	if not current_ok:
		current_material_id = BuildingMaterialCatalogScript.default_material_for_era(blueprint.category)
	for i in _material_option.item_count:
		if _material_option.get_item_metadata(i) == current_material_id:
			_material_option.select(i)
			break
	_refresh_ghost()


func _on_era_changed(index: int) -> void:
	var target_era: StringName = StringName(_category_option.get_item_metadata(index))
	if target_era == blueprint.category:
		return

	var offenders := _get_offending_blocks(target_era)
	if not offenders.is_empty():
		var default_mat := BuildingMaterialCatalogScript.default_material_for_era(target_era)
		var mat_info := BuildingMaterialCatalogScript.get_material(default_mat)
		var default_mat_name: String = String(mat_info.get("name", str(default_mat)))

		var user_confirmed := await _confirm_era_material_replacement(target_era, offenders.size(), default_mat_name)
		if not user_confirmed:
			_select_category_in_option(blueprint.category)
			_update_status("Смена эры отменена.")
			return

		for block in offenders:
			block.material_id = default_mat
		_rebuild_all_block_nodes()
		grid_model.write_to_blueprint(blueprint)
		blueprint.recalculate_construction_cost()

	blueprint.category = target_era
	_update_fallback_display()
	_mark_dirty()
	_rebuild_material_options()
	_refresh_underground_availability()
	if not offenders.is_empty():
		_update_status("Эра изменена на %s (%d блоков заменено)." % [blueprint.category, offenders.size()])
	else:
		_update_status("Эра: %s." % blueprint.category)


func _get_offending_blocks(target_era: StringName) -> Array[BlueprintBlock]:
	var offenders: Array[BlueprintBlock] = []
	for block in grid_model.all_blocks():
		if not BuildingMaterialCatalogScript.is_available_in_era(block.material_id, target_era):
			offenders.append(block)
	return offenders


func _confirm_era_material_replacement(target_era: StringName, count: int, default_mat_name: String) -> bool:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Автозамена материалов блоков"
	dialog.dialog_text = "В здании %d блок(ов) используют материалы, недоступные в эре «%s».\nЗаменить их автоматически на «%s»?" % [count, target_era, default_mat_name]
	dialog.ok_button_text = "Заменить"
	dialog.cancel_button_text = "Отмена"
	return await _run_confirmation_dialog(dialog, Vector2i(420, 140))


func _select_category_in_option(category: StringName) -> void:
	if _category_option != null:
		for i in _category_option.item_count:
			if _category_option.get_item_metadata(i) == category:
				_category_option.select(i)
				break


func _refresh_underground_availability() -> void:
	if _style_option == null:
		return
	var earth_rank := BuildingMaterialCatalogScript.era_rank(&"earth")
	var allowed := BuildingMaterialCatalogScript.era_rank(blueprint.category) >= earth_rank
	for i in _style_option.item_count:
		if _style_option.get_item_metadata(i) == &"underground":
			_style_option.set_item_disabled(i, not allowed)
	if not allowed and blueprint.construction_style == &"underground":
		blueprint.construction_style = &"surface"
		_select_style_in_option(&"surface")


func _select_style_in_option(style: StringName) -> void:
	if _style_option == null:
		return
	for i in _style_option.item_count:
		if _style_option.get_item_metadata(i) == style:
			_style_option.select(i)
			break


func _set_brush(brush_id: int) -> void:
	current_brush = brush_id
	if _brush_line_btn != null:
		_brush_line_btn.button_pressed = brush_id == Brush.LINE
	if _brush_rect_btn != null:
		_brush_rect_btn.button_pressed = brush_id == Brush.RECT


## Selects the brush block. `variant` empty means "pick this block's default (or
## keep the current one if it's the same block)"; a concrete id comes from the
## variant strip. The palette lists one button per block; size/profile and the
## in-cell anchor are chosen in the contextual brush inspector below it.
func _select_block(block_id: StringName, variant: StringName = &"", retain_stamp: bool = false) -> void:
	if not retain_stamp:
		_stamp_brush.clear()
	if variant == &"":
		variant = current_variant if block_id == current_block_id else BuildingBlockCatalogScript.default_variant(block_id)
	current_block_id = block_id
	current_variant = BuildingBlockCatalogScript.normalize_variant(block_id, variant)
	var def := BuildingBlockCatalogScript.get_block(block_id)
	if def.is_empty() or not def.get("rotatable", true):
		current_rot = 0
		current_rot_x = 0
		current_rot_z = 0
	_set_tool(Tool.PLACE)
	for key in _palette_buttons.keys():
		(_palette_buttons[key] as Button).button_pressed = key == current_block_id
	_rebuild_brush_inspector()
	_update_rotation_label()
	_refresh_ghost()


func _clear_block_selection() -> void:
	_stamp_brush.clear()
	current_block_id = &""
	current_variant = &""
	for key in _palette_buttons.keys():
		(_palette_buttons[key] as Button).button_pressed = false
	if _brush_inspector != null:
		_brush_inspector.visible = false
	_refresh_ghost()
	_update_status("Элемент для строительства не выбран.")


func _cycle_rotation(direction: int = 1) -> void:
	var def := BuildingBlockCatalogScript.get_block(current_block_id)
	if def.is_empty() or not def.get("rotatable", true):
		return
	current_rot = (current_rot + direction + 4) % 4
	_rebuild_brush_inspector()
	_update_rotation_label()
	_refresh_ghost()


func _cycle_rotation_x(direction: int = 1) -> void:
	var def := BuildingBlockCatalogScript.get_block(current_block_id)
	if def.is_empty() or not def.get("rotatable", true):
		return
	current_rot_x = (current_rot_x + direction + 4) % 4
	_update_rotation_label()
	_refresh_ghost()


func _cycle_rotation_z(direction: int = 1) -> void:
	var def := BuildingBlockCatalogScript.get_block(current_block_id)
	if def.is_empty() or not def.get("rotatable", true):
		return
	current_rot_z = (current_rot_z + direction + 4) % 4
	_update_rotation_label()
	_refresh_ghost()


func _set_layer(layer: int) -> void:
	active_layer = maxi(0, layer)
	_refresh_layer_plane()
	if _layer_label != null:
		_layer_label.text = "Слой %d" % active_layer
	if decor_mode != null:
		decor_mode.on_layer_changed()


## Public entry points used by the mode controllers.
func set_layer(layer: int) -> void:
	_set_layer(layer)


func mark_dirty() -> void:
	_mark_dirty()


func set_status(message: String) -> void:
	_update_status(message)


func is_pointer_over_ui() -> bool:
	return _pointer_over_ui()


func update_cursor() -> void:
	_update_cursor()


func is_cell_in_bounds(cell: Vector3i) -> bool:
	return _is_cell_in_bounds(cell)


func update_fallback_display() -> void:
	_update_fallback_display()


func _select_mode(mode: int) -> void:
	if mode == EditMode.FINISHES:
		_update_status("Этот режим подготовлен в формате и будет реализован следующим срезом.")
		if _mode_buttons.has(current_mode):
			(_mode_buttons[current_mode] as Button).button_pressed = true
		return
	current_mode = mode
	for m in _mode_buttons.keys():
		(_mode_buttons[m] as Button).button_pressed = m == mode
	if _palette_panel != null:
		_palette_panel.visible = mode == EditMode.FRAME
	if _frame_toolbar != null:
		_frame_toolbar.visible = mode == EditMode.FRAME
	# The decor inspector occupies the same right-hand strip as the metadata
	# panel, so the two never share the screen.
	if _metadata_panel != null:
		_metadata_panel.visible = mode != EditMode.DECOR

	if mode == EditMode.DECOR:
		decor_mode.activate()
		_update_status("Режим декора: щелчок — поставить или выбрать, Delete — удалить, Esc — снять выделение.")
	else:
		decor_mode.deactivate()
		if mode == EditMode.ZONES:
			_set_tool(Tool.PLACE)
			zones_mode.activate()
		else:
			zones_mode.deactivate()
			_update_status("Режим каркаса.")
	_refresh_ghost()



# ---------------------------------------------------------------------------
# Save / load / new
# ---------------------------------------------------------------------------

func _on_save_pressed() -> void:
	blueprint.name = _name_edit.text.strip_edges()
	if blueprint.name.is_empty():
		blueprint.name = "Новое здание"
	if _id_edit != null:
		var raw_id := _id_edit.text.strip_edges()
		if not raw_id.is_empty():
			blueprint.id = StringName(raw_id)
	if _category_option != null:
		blueprint.category = StringName(_category_option.get_item_metadata(_category_option.selected))
	_update_fallback_display()
	if _footprint_x_spin != null and _footprint_z_spin != null:
		blueprint.footprint = Vector2i(int(_footprint_x_spin.value), int(_footprint_z_spin.value))
	if _entrance_x_spin != null and _entrance_z_spin != null:
		blueprint.entrance = Vector2i(int(_entrance_x_spin.value), int(_entrance_z_spin.value))
	grid_model.write_to_blueprint(blueprint)
	var result := repository.save(blueprint)
	if result["ok"]:
		_dirty = false
		_update_status("Сохранено: %s (%d блоков)" % [result["path"], blueprint.block_count()])
	else:
		_update_status("Ошибка сохранения: %s" % result["error"])


func _on_new_pressed() -> void:
	if not await _confirm_discard_changes():
		return
	grid_model.clear()
	blueprint = BuildingBlueprintScript.new()
	_rebuild_all_block_nodes()
	zones_mode.on_blueprint_changed()
	_reset_decor_for_new_blueprint()
	_sync_metadata_fields()
	_dirty = false
	_set_layer(0)
	_update_status("Новый чертёж.")


func _on_export_mesh_pressed() -> void:
	_update_status("Экспорт меша: функция в разработке.")


func _on_navmesh_preview_pressed() -> void:
	_update_status("Предпросмотр навмеша: функция в разработке.")


func _on_load_pressed() -> void:
	_load_list.clear()
	var entries := repository.list_blueprints()
	if not repository.last_errors.is_empty():
		_update_status("Ошибка контента: " + "\n".join(repository.last_errors))
	if entries.is_empty():
		_update_status("Нет сохранённых чертежей в %s" % repository.base_dir())
		return
	for entry in entries:
		var idx := _load_list.add_item("%s  (%s)" % [entry["name"], entry["id"]])
		_load_list.set_item_metadata(idx, entry["path"])
	_load_popup.popup_centered(Vector2i(420, 360))


func _on_load_item_activated(index: int) -> void:
	if not await _confirm_discard_changes():
		_load_popup.hide()
		return
	var path := String(_load_list.get_item_metadata(index))
	var loaded := repository.load_blueprint(path)
	if loaded == null:
		_update_status("Не удалось загрузить: %s" % path)
		return
	blueprint = loaded
	grid_model.load_from_blueprint(blueprint)
	_rebuild_all_block_nodes()
	zones_mode.on_blueprint_loaded()
	_reset_decor_for_new_blueprint()
	_sync_metadata_fields()
	_dirty = false
	_load_popup.hide()
	_update_status("Загружено: %s (%d блоков, %d зон, %d объектов)" % [
		blueprint.name, blueprint.block_count(), blueprint.place_zones.size(), blueprint.objects.size()])


func _confirm_back_to_menu() -> void:
	if not await _confirm_discard_changes():
		return
	back_requested.emit()


func _fallback_back_to_menu() -> void:
	get_tree().change_scene_to_file("res://game/features/ui/presentation/main_menu/main_menu.tscn")


func _on_mode_frame_pressed() -> void:
	_select_mode(EditMode.FRAME)


func _on_mode_finishes_pressed() -> void:
	_select_mode(EditMode.FINISHES)


func _on_mode_decor_pressed() -> void:
	_select_mode(EditMode.DECOR)


func _on_mode_zones_pressed() -> void:
	_select_mode(EditMode.ZONES)


func _on_tool_place_pressed() -> void:
	_set_tool(Tool.PLACE)


func _on_tool_erase_pressed() -> void:
	_set_tool(Tool.ERASE)


func _on_brush_line_pressed() -> void:
	_set_brush(Brush.LINE)


func _on_brush_rect_pressed() -> void:
	_set_brush(Brush.RECT)


func _on_layer_down_pressed() -> void:
	_set_layer(active_layer - 1)


func _on_layer_up_pressed() -> void:
	_set_layer(active_layer + 1)


# ---------------------------------------------------------------------------
# UI setup & signal wiring (binds to static nodes in building_editor.tscn)
# ---------------------------------------------------------------------------

func _setup_ui() -> void:
	_mode_buttons[EditMode.FRAME] = _mode_frame_btn
	_mode_buttons[EditMode.FINISHES] = _mode_finishes_btn
	_mode_buttons[EditMode.DECOR] = _mode_decor_btn
	_mode_buttons[EditMode.ZONES] = _mode_zones_btn

	_material_option.item_selected.connect(func(index: int):
		current_material_id = _material_option.get_item_metadata(index)
		_refresh_ghost()
	)

	_build_palette_blocks()

	zones_mode.setup(self)
	decor_mode.setup(self)


	# Metadata panel wiring
	_category_option.clear()
	for category_id in BuildingMaterialCatalogScript.ERA_ORDER:
		_category_option.add_item(category_id.capitalize())
		_category_option.set_item_metadata(_category_option.item_count - 1, category_id)
	_category_option.item_selected.connect(_on_era_changed)
	_footprint_x_spin.value_changed.connect(_on_footprint_changed)
	_footprint_z_spin.value_changed.connect(_on_footprint_changed)

	_style_option.clear()
	for style_info in [
		{"id": &"surface", "label": "Наземная"},
		{"id": &"underground", "label": "Подземная (с земляной эры)"},
	]:
		_style_option.add_item(style_info["label"])
		_style_option.set_item_metadata(_style_option.item_count - 1, style_info["id"])
	_style_option.item_selected.connect(func(index: int):
		blueprint.construction_style = _style_option.get_item_metadata(index)
		_mark_dirty()
	)

	_path_hint_label.text = "Сохранение → %s" % repository.base_dir()
	_back_btn.visible = not dev_mode
	if dev_mode:
		_export_mesh_btn.visible = true
		_navmesh_preview_btn.visible = true
		_export_mesh_btn.pressed.connect(_on_export_mesh_pressed)
		_navmesh_preview_btn.pressed.connect(_on_navmesh_preview_pressed)

	_load_list.item_activated.connect(_on_load_item_activated)

	_cost_mode_option.clear()
	_cost_mode_option.add_item("Авто-расчёт (по блокам)")
	_cost_mode_option.set_item_metadata(0, &"auto")
	_cost_mode_option.add_item("Ручной ввод сметы")
	_cost_mode_option.set_item_metadata(1, &"manual")

	_cost_container.visible = true
	_cost_header_btn.text = "Стоимость здания"

	_sync_metadata_fields()
	_clear_block_selection()
	_set_tool(Tool.PLACE)
	_set_brush(Brush.LINE)
	_set_layer(0)
	_update_count()
	_select_mode(EditMode.FRAME)


func _build_palette_blocks() -> void:
	for child in _palette_container.get_children():
		child.queue_free()
	_palette_buttons.clear()

	# A category may own entries that are declared in separate catalog sections
	# (columns now belong to "Конструкции"). Group before rendering so its header
	# is emitted once, regardless of declaration order.
	var blocks_by_category: Dictionary = {}
	var category_order: Array[int] = []
	for def in BuildingBlockCatalogScript.all():
		var category: int = def["category"]
		if not blocks_by_category.has(category):
			blocks_by_category[category] = []
			category_order.append(category)
		(blocks_by_category[category] as Array).append(def)

	for category in category_order:
		var cat_label := Label.new()
		cat_label.text = BuildingBlockCatalogScript.category_name(category)
		cat_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
		_palette_container.add_child(cat_label)
		for def in blocks_by_category[category]:
			var block_id: StringName = def["id"]
			var btn := Button.new()
			btn.toggle_mode = true
			btn.text = def["name"]
			if BuildingBlockCatalogScript.has_variants(block_id):
				btn.tooltip_text = "Размер/профиль выбирается ниже"
			else:
				var s: Vector3 = def["size"]
				btn.tooltip_text = "Размер: %.2f×%.2f×%.2f м" % [s.x, s.y, s.z]
			btn.pressed.connect(_select_block.bind(block_id))
			_palette_buttons[block_id] = btn
			_palette_container.add_child(btn)


# ---------------------------------------------------------------------------
# Brush inspector: size/profile variant strip + in-cell anchor pad for the
# currently selected block. Rebuilt on selection and rotation.
# ---------------------------------------------------------------------------

func _ensure_brush_inspector() -> Control:
	if _brush_inspector != null and is_instance_valid(_brush_inspector):
		return _brush_inspector
	# Lives inside the palette list itself so it can slot directly beneath the
	# selected block button (moved there in _rebuild_brush_inspector).
	_brush_inspector = VBoxContainer.new()
	_brush_inspector.name = "BrushInspector"
	_palette_container.add_child(_brush_inspector)
	return _brush_inspector


## Places the inspector right after the currently selected block's button so the
## variant/size strip and anchor pad appear under that block, not at the list's
## end.
func _move_brush_inspector_under_selection() -> void:
	if _brush_inspector == null or not is_instance_valid(_brush_inspector):
		return
	var btn: Button = _palette_buttons.get(current_block_id, null)
	if btn == null:
		return
	# move_child takes a final index; a forward move shifts everything down by one
	# once the inspector is lifted out, so compensate to land just after the button.
	var target := btn.get_index() + 1
	if _brush_inspector.get_index() < target:
		target -= 1
	_palette_container.move_child(_brush_inspector, target)


func _rebuild_brush_inspector() -> void:
	var host := _ensure_brush_inspector()
	host.visible = true
	for child in host.get_children():
		child.queue_free()
	_move_brush_inspector_under_selection()

	var variants: Array = BuildingBlockCatalogScript.variants(current_block_id)
	var kinds: Array = BuildingBlockCatalogScript.available_anchors(current_block_id, current_variant)
	if kinds.size() <= 1:
		current_anchor = BuildingBlockCatalogScript.ANCHOR_CENTER
	else:
		current_anchor = BuildingBlockCatalogScript.normalize_anchor(current_block_id, current_variant, current_anchor)

	if variants.is_empty() and kinds.size() <= 1:
		return

	var toolbar := HBoxContainer.new()
	toolbar.name = "BrushToolbar"
	host.add_child(toolbar)

	# Left side: Size / profile variant buttons
	if not variants.is_empty():
		for v in variants:
			var v_id: StringName = v["id"]
			var vbtn := Button.new()
			vbtn.toggle_mode = true
			vbtn.text = v["name"]
			vbtn.button_pressed = v_id == current_variant
			var v_size: Vector3 = v.get("size", Vector3.ONE)
			vbtn.tooltip_text = "Размер: %.2f×%.2f×%.2f м" % [v_size.x, v_size.y, v_size.z]
			vbtn.pressed.connect(_select_block.bind(current_block_id, v_id))
			toolbar.add_child(vbtn)

	# Spacer pushing anchor buttons to the right
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	# Right side: Anchor buttons
	if kinds.size() > 1:
		for kind in kinds:
			var abtn := Button.new()
			abtn.toggle_mode = true
			abtn.text = _anchor_label(kind)
			abtn.button_pressed = kind == current_anchor
			abtn.pressed.connect(_select_anchor.bind(kind))
			toolbar.add_child(abtn)


func _anchor_label(kind: int) -> String:
	match kind:
		BuildingBlockCatalogScript.ANCHOR_EDGE: return "К грани"
		BuildingBlockCatalogScript.ANCHOR_CORNER: return "В угол"
		_: return "Центр"


func _select_anchor(anchor: int) -> void:
	current_anchor = anchor
	_rebuild_brush_inspector()
	_refresh_ghost()


# ---------------------------------------------------------------------------
# UI sync helpers
# ---------------------------------------------------------------------------

func _update_fallback_display() -> void:
	if blueprint != null:
		blueprint.fallback_building_id = blueprint.infer_fallback_building_id()
		if _fallback_edit != null:
			_fallback_edit.text = String(blueprint.fallback_building_id)


func _sync_metadata_fields() -> void:
	_syncing_metadata_fields = true
	if _name_edit != null:
		_name_edit.text = blueprint.name
	if _id_edit != null:
		_id_edit.text = String(blueprint.id)
	_update_fallback_display()
	if _footprint_x_spin != null:
		_footprint_x_spin.value = blueprint.footprint.x
	if _footprint_z_spin != null:
		_footprint_z_spin.value = blueprint.footprint.y
	if _entrance_x_spin != null:
		_entrance_x_spin.value = blueprint.entrance.x
	if _entrance_z_spin != null:
		_entrance_z_spin.value = blueprint.entrance.y
	if _category_option != null:
		for i in _category_option.item_count:
			if _category_option.get_item_metadata(i) == blueprint.category:
				_category_option.select(i)
				break
	_select_style_in_option(blueprint.construction_style)
	_rebuild_material_options()
	_refresh_underground_availability()
	_syncing_metadata_fields = false
	_refresh_building_grid_visuals()
	_focus_footprint_center()
	_refresh_ghost()


func _update_rotation_label() -> void:
	if _rot_x_btn != null:
		var deg_x := current_rot_x * 90
		_rot_x_btn.text = "🔄X %d° (X)" % deg_x if deg_x != 0 else "🔄X (X)"
	if _rot_btn != null:
		var deg_y := current_rot * 90
		_rot_btn.text = "🔄Y %d° (C)" % deg_y if deg_y != 0 else "🔄Y (C)"
	if _rot_z_btn != null:
		var deg_z := current_rot_z * 90
		_rot_z_btn.text = "🔄Z %d° (Z)" % deg_z if deg_z != 0 else "🔄Z (Z)"


func _update_count() -> void:
	if _count_label != null:
		_count_label.text = "Блоков: %d" % grid_model.count()
	if blueprint != null:
		grid_model.write_to_blueprint(blueprint)
		blueprint.recalculate_construction_cost()
		_refresh_cost_ui()


func _on_cost_mode_selected(index: int) -> void:
	var mode: StringName = _cost_mode_option.get_item_metadata(index)
	blueprint.cost_mode = mode
	blueprint.recalculate_construction_cost()
	_mark_dirty()
	_refresh_cost_ui()


func _on_add_extra_cost_pressed() -> void:
	var default_res := "coins"
	var current_qty := int(blueprint.extra_costs.get(default_res, 0))
	blueprint.extra_costs[default_res] = current_qty + 1
	blueprint.recalculate_construction_cost()
	_mark_dirty()
	_refresh_cost_ui()


func _refresh_cost_ui() -> void:
	if _cost_container == null:
		return

	_cost_block_summary_label.text = "Всего блоков: %d" % blueprint.block_count()

	if blueprint.cost_mode == &"manual":
		_cost_mode_option.select(1)
	else:
		_cost_mode_option.select(0)

	for child in _cost_breakdown_vbox.get_children():
		child.queue_free()

	if blueprint.cost_mode == &"auto":
		var mat_counts: Dictionary = {}
		for block in blueprint.blocks:
			mat_counts[block.material_id] = int(mat_counts.get(block.material_id, 0)) + 1

		for mat_id in mat_counts.keys():
			var count: int = mat_counts[mat_id]
			var mat_def := BuildingMaterialCatalogScript.get_material(mat_id)
			var mat_name: String = mat_def.get("name", str(mat_id))
			var comp: Dictionary = BuildingMaterialCatalogScript.resource_composition(mat_id)
			if blueprint.custom_material_costs.has(mat_id) and blueprint.custom_material_costs[mat_id] is Dictionary:
				comp = blueprint.custom_material_costs[mat_id]

			var row := HBoxContainer.new()
			var lbl := Label.new()
			var comp_texts: Array[String] = []
			for r in comp.keys():
				comp_texts.append("%.2f %s" % [float(comp[r]), str(r)])
			lbl.text = "%s (%d бл.) — %s/бл." % [mat_name, count, ", ".join(comp_texts)]
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)
			_cost_breakdown_vbox.add_child(row)

	for child in _extra_costs_vbox.get_children():
		child.queue_free()

	if blueprint.cost_mode == &"manual":
		var manual_title := Label.new()
		manual_title.text = "Ручная смета (все ресурсы):"
		manual_title.add_theme_font_size_override("font_size", 13)
		_extra_costs_vbox.add_child(manual_title)

		for res in blueprint.manual_costs.keys():
			_extra_costs_vbox.add_child(_build_cost_row(
				blueprint.manual_costs, str(res),
				blueprint.manual_costs[res]))
	else:
		for res in blueprint.extra_costs.keys():
			_extra_costs_vbox.add_child(_build_cost_row(
				blueprint.extra_costs, str(res),
				blueprint.extra_costs[res]))

	var costs_array: Array[String] = []
	for res in blueprint.construction_cost.keys():
		costs_array.append("%d %s" % [int(blueprint.construction_cost[res]), str(res)])
	if costs_array.is_empty():
		_total_cost_label.text = "Итоговая смета: Бесплатно"
	else:
		_total_cost_label.text = "Итоговая смета: %s" % ", ".join(costs_array)


## Builds a reusable cost entry row: name edit + spin box + delete button.
## Works for both manual_costs and extra_costs dictionaries.
func _build_cost_row(costs: Dictionary, key: String, value: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_edit := LineEdit.new()
	name_edit.text = key
	name_edit.custom_minimum_size = Vector2(80, 0)
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 9999
	spin.value = value
	var del_btn := Button.new()
	del_btn.text = "X"

	var old_key := key
	name_edit.text_submitted.connect(func(new_text: String):
		var val: int = costs.get(old_key, 1)
		costs.erase(old_key)
		if not new_text.strip_edges().is_empty():
			costs[new_text.strip_edges()] = val
		blueprint.recalculate_construction_cost()
		_mark_dirty()
		_refresh_cost_ui()
	)
	spin.value_changed.connect(func(new_val: float):
		costs[old_key] = int(new_val)
		blueprint.recalculate_construction_cost()
		_mark_dirty()
		_refresh_cost_ui()
	)
	del_btn.pressed.connect(func():
		costs.erase(old_key)
		blueprint.recalculate_construction_cost()
		_mark_dirty()
		_refresh_cost_ui()
	)
	row.add_child(name_edit)
	row.add_child(spin)
	row.add_child(del_btn)
	return row


func _update_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _mark_dirty() -> void:
	_dirty = true


func _confirm_discard_changes() -> bool:
	if not _dirty:
		return true
	var dialog := ConfirmationDialog.new()
	dialog.title = "Несохранённые изменения"
	dialog.dialog_text = "Есть несохранённые изменения. Продолжить?"
	dialog.ok_button_text = "Да"
	dialog.cancel_button_text = "Отмена"
	return await _run_confirmation_dialog(dialog, Vector2i(360, 120))


## Shows `dialog` modally and resolves to `true` only when the user pressed OK.
##
## The confirmation flag lives in an Array because GDScript lambdas capture
## locals by value: writing to a plain `var` from inside the `confirmed`
## handler would leave the outer variable untouched and every dialog would
## read as "cancelled".
func _run_confirmation_dialog(dialog: ConfirmationDialog, size: Vector2i) -> bool:
	var confirmed_flag := [false]
	dialog.confirmed.connect(func(): confirmed_flag[0] = true)
	add_child(dialog)
	dialog.popup_centered(size)
	# `popup_centered` makes the dialog visible synchronously, so the loop
	# body only runs while the user hasn't confirmed or cancelled yet.
	while dialog.visible:
		await get_tree().process_frame
	dialog.queue_free()
	return confirmed_flag[0]


func _on_footprint_changed(_value: float) -> void:
	if blueprint == null or _syncing_metadata_fields:
		return
	blueprint.footprint = Vector2i(int(_footprint_x_spin.value), int(_footprint_z_spin.value))
	# Remove blocks that fall outside the new (possibly smaller) footprint.
	var removed := 0
	for block in grid_model.all_blocks():
		if not _is_block_in_bounds(block.pos, block.block_id, block.variant, block.rot):
			grid_model.erase_block(block)
			_remove_block_node(block)
			removed += 1
	if removed > 0:
		_update_count()
		_update_status("Размер изменён. Удалено блоков вне границ: %d" % removed)
	_refresh_building_grid_visuals()
	_focus_footprint_center()
	_refresh_ghost()
	_mark_dirty()



# ---------------------------------------------------------------------------
# Decor mode bridge — the logic lives in DecorModeController.
# ---------------------------------------------------------------------------

## Drops every spawned decor instance and its undo history after the blueprint
## behind them has been replaced (New / Load). Without this the previous
## building's decor stayed in the scene.
func _reset_decor_for_new_blueprint() -> void:
	if decor_mode == null:
		return
	decor_mode.clear_undo_history()
	decor_mode.select_object("")
	decor_mode.rebuild_nodes()
	if current_mode == EditMode.DECOR:
		decor_mode.activate()
