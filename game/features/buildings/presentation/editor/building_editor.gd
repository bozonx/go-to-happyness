class_name BuildingEditor
extends Node3D

## Modular building editor for frame construction and active work zones.
##
## Runs in two modes (see design_docs/content/modular_building_editor.md §5):
##   * Dev mode  — launched by opening this scene directly in Godot; saves to
##     res://data/blueprints and exposes the developer panel.
##   * Player mode — launched from the main menu; saves to user://custom_buildings.

signal back_requested

const CameraControllerScript = preload("res://game/features/world/presentation/camera_controller.gd")
const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BuildingGridModelScript = preload("res://game/features/buildings/domain/editor/building_grid_model.gd")
const PlaceZoneRecordScript = preload("res://game/features/buildings/domain/editor/place_zone_record.gd")
const ZoneAnchorRecordScript = preload("res://game/features/buildings/domain/editor/zone_anchor_record.gd")
const BlueprintRepositoryScript = preload("res://game/features/buildings/presentation/editor/blueprint_repository.gd")
const BlockMeshLibraryScript = preload("res://game/features/buildings/presentation/editor/block_mesh_library.gd")
const DecorModeControllerScript = preload("res://game/features/buildings/presentation/editor/decor_mode_controller.gd")

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

var current_block_id: StringName = BuildingBlockCatalogScript.default_block_id()
var current_variant: StringName = BuildingBlockCatalogScript.default_variant(BuildingBlockCatalogScript.default_block_id())
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

## True when there are unsaved changes. Checked before scene transitions.
var _dirty: bool = false

## Frame-mode drag painting state.
var _painting: bool = false
var _last_paint_cell: Vector3i = Vector3i.ZERO
## Fixed corner of the current rectangle brush drag (the cell first pressed).
var _paint_anchor: Vector3i = Vector3i.ZERO

## Zones-mode state. `_armed_tool` is what a grid click does: paint place cells,
## or drop an anchor of the currently selected role.
var _selected_place_index: int = -1
var _armed_tool: StringName = &"cell"  ## &"cell" | &"anchor"
var _anchor_family: StringName = ZoneAnchorRecordScript.FAMILY_OCCUPANCY
var _anchor_role: StringName = ZoneAnchorRecordScript.ROLE_WORK

var _block_nodes: Dictionary = {}  ## Vector3i -> MeshInstance3D
@onready var _camera_controller: CameraController = %CameraController
@onready var _blocks_root: Node3D = %BlocksRoot
@onready var _ghost: MeshInstance3D = %Ghost
@onready var _layer_plane: MeshInstance3D = %LayerPlane
@onready var _zones_visual_root: Node3D = %ZonesVisual
@onready var _export_mesh_btn: Button = %ExportMeshBtn
@onready var _navmesh_preview_btn: Button = %NavMeshPreviewBtn
var _panning: bool = false
var _orbiting: bool = false
var _zone_material_cache: Dictionary = {}

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

@onready var _cost_header_btn: Button = %CostHeaderBtn
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

@onready var _zones_panel: PanelContainer = %ZonesPanel
@onready var _zone_option: OptionButton = %ZoneOption
@onready var _add_place_btn: Button = %AddPlaceBtn
@onready var _del_place_btn: Button = %DelPlaceBtn
@onready var _zone_id_edit: LineEdit = %ZoneIdEdit
@onready var _zone_name_edit: LineEdit = %ZoneNameEdit
@onready var _zone_kind_option: OptionButton = %ZoneKindOption
@onready var _zone_subtype_row: VBoxContainer = %ZoneSubtypeRow
@onready var _zone_subtype_option: OptionButton = %ZoneSubtypeOption
@onready var _zone_profession_option: OptionButton = %ZoneProfessionOption
@onready var _zone_workers_spin: SpinBox = %ZoneWorkersSpin
@onready var _zone_info_label: Label = %ZoneInfoLabel
@onready var _anchor_family_option: OptionButton = %AnchorFamilyOption
@onready var _anchor_role_option: OptionButton = %AnchorRoleOption
@onready var _anchor_world_check: CheckBox = %AnchorWorldCheck
@onready var _zone_marker_yaw_spin: SpinBox = %ZoneMarkerYawSpin
@onready var _zone_capacity_spin: SpinBox = %ZoneCapacitySpin
@onready var _tool_cell_btn: Button = %ToolCellBtn
@onready var _tool_anchor_btn: Button = %ToolAnchorBtn
@onready var _clear_cells_btn: Button = %ClearCellsBtn
@onready var _clear_anchors_btn: Button = %ClearAnchorsBtn
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
var _tool_buttons: Dictionary = {}     ## StringName -> Button

const ZONE_COLORS: Array[Color] = [
	Color(0.35, 0.75, 1.0), Color(1.0, 0.7, 0.3), Color(0.6, 1.0, 0.5),
	Color(1.0, 0.5, 0.8), Color(0.8, 0.8, 0.4), Color(0.5, 0.9, 0.9),
]


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
	_camera_controller.camera_target = Vector3(4.0, 0.0, 4.0)
	_camera_controller.camera_distance = 18.0
	_camera_controller.apply_position()

	var grid_lines := %GridLines as MeshInstance3D
	grid_lines.mesh = _build_grid_mesh(32, Color(0.30, 0.34, 0.40, 0.6))

	_layer_plane.mesh = _build_grid_mesh(24, Color(0.35, 0.7, 1.0, 0.5))

	decor_mode = DecorModeControllerScript.new()
	add_child(decor_mode)


func _build_grid_mesh(half_extent: int, color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(color)
	for i in range(-half_extent, half_extent + 1):
		st.add_vertex(Vector3(i, 0.0, -half_extent))
		st.add_vertex(Vector3(i, 0.0, half_extent))
		st.add_vertex(Vector3(-half_extent, 0.0, i))
		st.add_vertex(Vector3(half_extent, 0.0, i))
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, mat)
	return mesh


# ---------------------------------------------------------------------------
# Input & interaction
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _camera_controller != null:
		_camera_controller.update(delta)
	_update_cursor()
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
				elif current_mode == EditMode.ZONES and _armed_tool == &"cell":
					_paint_zone_line(_last_paint_cell, cursor_cell)
				elif current_mode == EditMode.FRAME and (current_brush == Brush.RECT or event.shift_pressed or Input.is_key_pressed(KEY_SHIFT)):
					_paint_rect(_paint_anchor, cursor_cell)
				else:
					_paint_line(_last_paint_cell, cursor_cell)
				_last_paint_cell = cursor_cell
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and _pointer_over_ui():
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
		MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom(-2.0)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom(2.0)
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				if current_mode == EditMode.ZONES:
					_place_zone_marker_at_cursor()
					_painting = _armed_tool == &"cell"
					_last_paint_cell = cursor_cell
				elif current_mode == EditMode.DECOR:
					decor_mode.on_left_pressed()
					_painting = true
				else:
					_painting = true
					_last_paint_cell = cursor_cell
					_paint_anchor = cursor_cell
					if current_brush == Brush.RECT or event.shift_pressed or Input.is_key_pressed(KEY_SHIFT):
						_paint_rect(_paint_anchor, cursor_cell)
					else:
						_apply_tool_at_cursor()
			else:
				_painting = false
				if current_mode == EditMode.DECOR:
					decor_mode.on_left_released()



func _handle_key(event: InputEventKey) -> void:
	# Decor mode rebinds the shared shortcuts (its own tools, its own rotation),
	# so give it first refusal before the frame bindings run.
	if current_mode == EditMode.DECOR and decor_mode.handle_key(event):
		return
	match event.keycode:
		KEY_Z:
			_cycle_rotation_z()
		KEY_X:
			_cycle_rotation_x()
		KEY_C, KEY_R:
			_cycle_rotation()
		KEY_E:
			_set_tool(Tool.ERASE)
		KEY_B:
			_set_tool(Tool.PLACE)
		KEY_L:
			_on_brush_line_pressed()
		KEY_M:
			_on_brush_rect_pressed()
		KEY_PAGEUP:
			_set_layer(active_layer + 1)
		KEY_PAGEDOWN:
			_set_layer(active_layer - 1)
		KEY_ESCAPE:
			_confirm_back_to_menu()


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
			# A multi-cell block can evict several existing blocks; drop their
			# anchor nodes before spawning the new one.
			var evicted := grid_model.overlapping_anchors(cell, current_block_id, current_variant, current_rot)
			if grid_model.place(cell, current_block_id, current_rot, current_material_id, current_variant, current_anchor, current_rot_x, current_rot_z):
				for anchor in evicted:
					_remove_block_node(anchor)
				_spawn_or_update_block_node(grid_model.get_block_at(cell))
				_update_count()
				_mark_dirty()
		Tool.ERASE:
			var anchor := grid_model.anchor_at(cell)
			if grid_model.erase(cell):
				_remove_block_node(anchor)
				_update_count()
				_mark_dirty()


func _paint_line(from_cell: Vector3i, to_cell: Vector3i) -> void:
	var dx := absi(to_cell.x - from_cell.x)
	var dz := absi(to_cell.z - from_cell.z)
	var sx := 1 if to_cell.x > from_cell.x else -1
	var sz := 1 if to_cell.z > from_cell.z else -1
	var x := from_cell.x
	var z := from_cell.z
	var err := dx - dz
	var y := active_layer
	while true:
		_apply_tool_at_cell(Vector3i(x, y, z))
		if x == to_cell.x and z == to_cell.z:
			break
		var e2 := 2 * err
		if e2 > -dz:
			err -= dz
			x += sx
		if e2 < dx:
			err += dx
			z += sz
	_refresh_ghost()


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


func _paint_zone_line(from_cell: Vector3i, to_cell: Vector3i) -> void:
	var zone := _current_place()
	if zone == null:
		return
	var steps := maxi(absi(to_cell.x - from_cell.x), absi(to_cell.z - from_cell.z))
	var changed := false
	for step in range(steps + 1):
		var t := float(step) / float(maxi(1, steps))
		var cell := Vector3i(
			roundi(lerpf(from_cell.x, to_cell.x, t)),
			active_layer,
			roundi(lerpf(from_cell.z, to_cell.z, t)))
		if cell not in zone.cells:
			zone.cells.append(cell)
			changed = true
	if changed:
		_mark_dirty()
		_refresh_zone_visuals()
		_update_zone_info()


func _pointer_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


# ---------------------------------------------------------------------------
# Block visuals
# ---------------------------------------------------------------------------

func _spawn_or_update_block_node(block: BlueprintBlock) -> void:
	var node: MeshInstance3D = _block_nodes.get(block.pos, null)
	if node == null:
		node = MeshInstance3D.new()
		_blocks_root.add_child(node)
		_block_nodes[block.pos] = node
	node.mesh = mesh_library.mesh_for(block.block_id, block.variant)
	node.material_override = mesh_library.material_for(block.material_id)
	node.position = Vector3(block.pos) + BlockMeshLibraryScript.local_offset(block.block_id, block.variant, block.rot, block.anchor, 0.0, block.rot_x, block.rot_z)
	node.rotation = block.rotation_euler()


func _remove_block_node(cell: Vector3i) -> void:
	var node: MeshInstance3D = _block_nodes.get(cell, null)
	if node != null:
		node.queue_free()
		_block_nodes.erase(cell)


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
		_ghost.material_override = mesh_library.ghost_material(true)


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
	add_child(dialog)
	dialog.popup_centered(Vector2i(420, 140))
	var user_confirmed := false
	dialog.confirmed.connect(func(): user_confirmed = true)
	await dialog.visibility_changed
	if dialog.visible:
		await dialog.hidden
	dialog.queue_free()
	return user_confirmed


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
func _select_block(block_id: StringName, variant: StringName = &"") -> void:
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


func _cycle_rotation() -> void:
	var def := BuildingBlockCatalogScript.get_block(current_block_id)
	if def.is_empty() or not def.get("rotatable", true):
		return
	current_rot = (current_rot + 1) % 4
	_rebuild_brush_inspector()
	_update_rotation_label()
	_refresh_ghost()


func _cycle_rotation_x() -> void:
	var def := BuildingBlockCatalogScript.get_block(current_block_id)
	if def.is_empty() or not def.get("rotatable", true):
		return
	current_rot_x = (current_rot_x + 1) % 4
	_update_rotation_label()
	_refresh_ghost()


func _cycle_rotation_z() -> void:
	var def := BuildingBlockCatalogScript.get_block(current_block_id)
	if def.is_empty() or not def.get("rotatable", true):
		return
	current_rot_z = (current_rot_z + 1) % 4
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
	if _zones_panel != null:
		_zones_panel.visible = mode == EditMode.ZONES
	# The decor inspector occupies the same right-hand strip as the metadata
	# panel, so the two never share the screen.
	if _metadata_panel != null:
		_metadata_panel.visible = mode != EditMode.DECOR

	if mode == EditMode.DECOR:
		decor_mode.activate()
		_update_status("Режим декора: B — поставить, V — выбрать, E — удалить.")
	else:
		decor_mode.deactivate()
		if mode == EditMode.ZONES:
			_set_tool(Tool.PLACE)
			_refresh_zone_visuals()
			_update_status("Режим зон: создайте зону и расставьте якоря работы / поддоны.")
		else:
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
	_selected_place_index = -1
	_dirty = false
	_rebuild_all_block_nodes()
	_rebuild_place_option()
	_refresh_zone_visuals()
	_reset_decor_for_new_blueprint()
	_sync_metadata_fields()
	_set_layer(0)
	_update_status("Новый чертёж.")


func _on_export_mesh_pressed() -> void:
	_update_status("Экспорт меша: функция в разработке.")


func _on_navmesh_preview_pressed() -> void:
	_update_status("Предпросмотр навмеша: функция в разработке.")


func _on_load_pressed() -> void:
	_load_list.clear()
	var entries := repository.list_blueprints()
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
	_selected_place_index = 0 if not blueprint.place_zones.is_empty() else -1
	_dirty = false
	_rebuild_all_block_nodes()
	_rebuild_place_option()
	_refresh_zone_visuals()
	_reset_decor_for_new_blueprint()
	_sync_metadata_fields()
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

	# Zones panel wiring
	_zone_option.item_selected.connect(_on_place_option_selected)
	_add_place_btn.pressed.connect(_add_place)
	_del_place_btn.pressed.connect(_delete_place)
	_zone_id_edit.text_changed.connect(_on_place_id_changed)
	_zone_name_edit.text_changed.connect(_on_place_name_changed)

	_zone_kind_option.clear()
	for kind in PlaceZoneRecordScript.KINDS:
		_zone_kind_option.add_item(PlaceZoneRecordScript.kind_display_name(kind))
		_zone_kind_option.set_item_metadata(_zone_kind_option.item_count - 1, kind)
	_zone_kind_option.item_selected.connect(_on_place_kind_selected)

	_zone_subtype_option.item_selected.connect(_on_place_subtype_selected)

	_zone_profession_option.clear()
	_zone_profession_option.add_item("— нет —")
	_zone_profession_option.set_item_metadata(0, &"")
	for prof in PlaceZoneRecordScript.PROFESSIONS:
		_zone_profession_option.add_item(String(prof))
		_zone_profession_option.set_item_metadata(_zone_profession_option.item_count - 1, prof)
	_zone_profession_option.item_selected.connect(_on_place_profession_selected)

	_zone_workers_spin.value_changed.connect(_on_place_workers_changed)

	_anchor_family_option.clear()
	for family_info in [
		{"id": ZoneAnchorRecordScript.FAMILY_OCCUPANCY, "label": "Занятие (слот)"},
		{"id": ZoneAnchorRecordScript.FAMILY_ROUTING, "label": "Маршрутизация"},
	]:
		_anchor_family_option.add_item(family_info["label"])
		_anchor_family_option.set_item_metadata(_anchor_family_option.item_count - 1, family_info["id"])
	_anchor_family_option.item_selected.connect(_on_anchor_family_selected)

	_anchor_role_option.item_selected.connect(_on_anchor_role_selected)

	_tool_buttons[&"cell"] = _tool_cell_btn
	_tool_buttons[&"anchor"] = _tool_anchor_btn
	_tool_cell_btn.pressed.connect(func(): _arm_tool(&"cell"))
	_tool_anchor_btn.pressed.connect(func(): _arm_tool(&"anchor"))

	_clear_cells_btn.pressed.connect(_clear_place_cells)
	_clear_anchors_btn.pressed.connect(_clear_place_anchors)

	_anchor_family_option.select(0)
	_on_anchor_family_selected(0)
	_arm_tool(&"cell")
	_rebuild_place_option()
	decor_mode.setup(self)


	# Metadata panel wiring
	_category_option.clear()
	for category_id in BuildingMaterialCatalogScript.ERA_ORDER:
		_category_option.add_item(category_id.capitalize())
		_category_option.set_item_metadata(_category_option.item_count - 1, category_id)
	_category_option.item_selected.connect(_on_era_changed)

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

	_cost_container.visible = false
	_cost_header_btn.text = "► Стоимость здания"

	_sync_metadata_fields()
	_select_block(current_block_id, current_variant)
	_set_tool(Tool.PLACE)
	_set_brush(Brush.LINE)
	_set_layer(0)
	_update_count()
	_select_mode(EditMode.FRAME)


func _build_palette_blocks() -> void:
	for child in _palette_container.get_children():
		child.queue_free()
	_palette_buttons.clear()

	var current_category := -1
	for def in BuildingBlockCatalogScript.all():
		if def["category"] != current_category:
			current_category = def["category"]
			var cat_label := Label.new()
			cat_label.text = BuildingBlockCatalogScript.category_name(current_category)
			cat_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
			_palette_container.add_child(cat_label)
		var block_id: StringName = def["id"]
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = def["name"]
		if BuildingBlockCatalogScript.has_variants(block_id):
			btn.tooltip_text = "Размер/профиль выбирается ниже"
		else:
			var s: Vector3 = def["size"]
			btn.tooltip_text = "Размер: %.2f×%.2f×%.2f м" % [s.x, s.y, s.z]
		btn.pressed.connect(func(): _select_block(block_id))
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
			vbtn.pressed.connect(func(): _select_block(current_block_id, v_id))
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
			abtn.pressed.connect(func(): _select_anchor(kind))
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
# Active work zones (Mode 3 logic)
# ---------------------------------------------------------------------------

func _current_place() -> PlaceZoneRecord:
	if _selected_place_index < 0 or _selected_place_index >= blueprint.place_zones.size():
		return null
	return blueprint.place_zones[_selected_place_index]


func _add_place() -> void:
	var place := PlaceZoneRecordScript.new()
	var next_index := 1
	var existing_ids: Array = blueprint.place_zones.map(func(existing): return existing.zone_id)
	while StringName("place_%d" % next_index) in existing_ids:
		next_index += 1
	place.zone_id = StringName("place_%d" % next_index)
	place.zone_name = "Место %d" % (blueprint.place_zones.size() + 1)
	blueprint.place_zones.append(place)
	_selected_place_index = blueprint.place_zones.size() - 1
	_mark_dirty()
	_update_fallback_display()
	_rebuild_place_option()
	_refresh_place_panel_fields()
	_refresh_zone_visuals()
	_update_status("Зона места создана. Задайте назначение и обведите ячейки.")


func _delete_place() -> void:
	var place := _current_place()
	if place == null:
		return
	var deleted_zone_id := place.zone_id
	var kept: Array[ZoneAnchorRecord] = []
	for anchor in blueprint.zone_anchors:
		if anchor.owner_zone_id != deleted_zone_id:
			kept.append(anchor)
	blueprint.zone_anchors = kept
	blueprint.place_zones.remove_at(_selected_place_index)
	_selected_place_index = mini(_selected_place_index, blueprint.place_zones.size() - 1)
	_mark_dirty()
	_update_fallback_display()
	_rebuild_place_option()
	_refresh_place_panel_fields()
	_refresh_zone_visuals()
	if decor_mode != null and decor_mode.is_active():
		decor_mode.on_zone_deleted(deleted_zone_id)


func _rebuild_place_option() -> void:
	if _zone_option == null:
		return
	_zone_option.clear()
	for i in blueprint.place_zones.size():
		var place: PlaceZoneRecord = blueprint.place_zones[i]
		_zone_option.add_item("%s" % place.zone_name)
	if _selected_place_index >= 0 and _selected_place_index < blueprint.place_zones.size():
		_zone_option.select(_selected_place_index)
	_refresh_place_panel_fields()


func _on_place_option_selected(index: int) -> void:
	_selected_place_index = index
	_refresh_place_panel_fields()
	_refresh_zone_visuals()


func _refresh_place_panel_fields() -> void:
	var place := _current_place()
	var has_place := place != null
	if _zone_name_edit != null:
		_zone_name_edit.editable = has_place
	if _zone_id_edit != null:
		_zone_id_edit.editable = has_place
	if _zone_kind_option != null:
		_zone_kind_option.disabled = not has_place
	if _zone_profession_option != null:
		_zone_profession_option.disabled = not has_place
	if _zone_workers_spin != null:
		_zone_workers_spin.editable = has_place
	if not has_place:
		if _zone_name_edit != null:
			_zone_name_edit.text = ""
		if _zone_id_edit != null:
			_zone_id_edit.text = ""
		if _zone_info_label != null:
			_zone_info_label.text = "Нет зон места. Нажмите ＋, чтобы создать."
		_rebuild_subtype_options()
		return
	if _zone_name_edit != null:
		_zone_name_edit.text = place.zone_name
	if _zone_id_edit != null:
		_zone_id_edit.text = String(place.zone_id)
	if _zone_kind_option != null:
		for i in _zone_kind_option.item_count:
			if _zone_kind_option.get_item_metadata(i) == place.kind:
				_zone_kind_option.select(i)
				break
	_rebuild_subtype_options()
	if _zone_profession_option != null:
		var found := 0
		for i in _zone_profession_option.item_count:
			if _zone_profession_option.get_item_metadata(i) == place.profession:
				found = i
				break
		_zone_profession_option.select(found)
	if _zone_workers_spin != null:
		_zone_workers_spin.value = place.max_workers
	_update_zone_info()


func _update_zone_info() -> void:
	if _zone_info_label == null:
		return
	var place := _current_place()
	if place == null:
		return
	var owned := 0
	var trays := 0
	var routing := 0
	var world := 0
	for anchor in blueprint.zone_anchors:
		if anchor.owner_zone_id == &"":
			world += 1
		if anchor.owner_zone_id != place.zone_id:
			continue
		if anchor.is_routing():
			routing += 1
		elif anchor.is_tray():
			trays += 1
		else:
			owned += 1
	var subtype_line := ""
	if place.subtype != &"":
		subtype_line = "\nТип: %s" % PlaceZoneRecordScript.subtype_display_name(place.subtype)
	_zone_info_label.text = "Ячеек: %d · Слотов: %d · Поддонов: %d · Маршрут: %d\nМировых якорей: %d · ID: %s%s" % [
		place.cells.size(), owned, trays, routing, world, place.zone_id, subtype_line]


func _on_place_name_changed(text: String) -> void:
	var place := _current_place()
	if place == null:
		return
	place.zone_name = text
	_mark_dirty()
	if _zone_option != null and _selected_place_index >= 0:
		_zone_option.set_item_text(_selected_place_index, text)


func _on_place_id_changed(text: String) -> void:
	var place := _current_place()
	if place != null:
		var cleaned := text.strip_edges().to_lower()
		place.zone_id = StringName(cleaned)
		_mark_dirty()
		if _zone_id_edit != null:
			var valid := not cleaned.is_empty() and BuildingBlueprintScript._valid_id(cleaned)
			if valid:
				_zone_id_edit.remove_theme_color_override("font_color")
			else:
				_zone_id_edit.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))


func _on_place_kind_selected(index: int) -> void:
	var place := _current_place()
	if place == null:
		return
	place.kind = _zone_kind_option.get_item_metadata(index)
	var subtypes := PlaceZoneRecordScript.subtypes_for_kind(place.kind)
	place.subtype = subtypes[0] if not subtypes.is_empty() else &""
	_mark_dirty()
	_rebuild_subtype_options()
	_update_zone_info()
	_update_fallback_display()


func _on_place_subtype_selected(index: int) -> void:
	var place := _current_place()
	if place == null:
		return
	place.subtype = _zone_subtype_option.get_item_metadata(index)
	_mark_dirty()


func _rebuild_subtype_options() -> void:
	if _zone_subtype_option == null:
		return
	var place := _current_place()
	var subtypes: Array[StringName] = []
	if place != null:
		subtypes = PlaceZoneRecordScript.subtypes_for_kind(place.kind)
	_zone_subtype_row.visible = not subtypes.is_empty()
	_zone_subtype_option.clear()
	for st in subtypes:
		_zone_subtype_option.add_item(PlaceZoneRecordScript.subtype_display_name(st))
		_zone_subtype_option.set_item_metadata(_zone_subtype_option.item_count - 1, st)
	if place != null:
		for i in _zone_subtype_option.item_count:
			if _zone_subtype_option.get_item_metadata(i) == place.subtype:
				_zone_subtype_option.select(i)
				break


func _on_place_profession_selected(index: int) -> void:
	var place := _current_place()
	if place == null:
		return
	place.profession = _zone_profession_option.get_item_metadata(index)
	_mark_dirty()
	_update_fallback_display()


func _on_place_workers_changed(value: float) -> void:
	var place := _current_place()
	if place == null:
		return
	place.max_workers = int(value)
	_mark_dirty()


func _on_anchor_family_selected(index: int) -> void:
	_anchor_family = _anchor_family_option.get_item_metadata(index)
	var routing := _anchor_family == ZoneAnchorRecordScript.FAMILY_ROUTING
	if _anchor_world_check != null:
		_anchor_world_check.disabled = not routing
		if not routing:
			_anchor_world_check.button_pressed = false
	_rebuild_anchor_role_options()


func _rebuild_anchor_role_options() -> void:
	if _anchor_role_option == null:
		return
	_anchor_role_option.clear()
	var roles := ZoneAnchorRecordScript.roles_for_family(_anchor_family)
	for role in roles:
		_anchor_role_option.add_item(ZoneAnchorRecordScript.role_display_name(role))
		_anchor_role_option.set_item_metadata(_anchor_role_option.item_count - 1, role)
	if not roles.is_empty():
		_anchor_role = roles[0]
		_anchor_role_option.select(0)


func _on_anchor_role_selected(index: int) -> void:
	_anchor_role = _anchor_role_option.get_item_metadata(index)


func _arm_tool(tool: StringName) -> void:
	_armed_tool = tool
	for id in _tool_buttons.keys():
		(_tool_buttons[id] as Button).button_pressed = id == tool


func _clear_place_cells() -> void:
	var place := _current_place()
	if place == null:
		return
	place.cells.clear()
	_mark_dirty()
	_refresh_zone_visuals()
	_update_zone_info()


func _clear_place_anchors() -> void:
	var place := _current_place()
	if place == null:
		return
	var kept: Array[ZoneAnchorRecord] = []
	for anchor in blueprint.zone_anchors:
		if anchor.owner_zone_id != place.zone_id:
			kept.append(anchor)
	blueprint.zone_anchors = kept
	_mark_dirty()
	_refresh_zone_visuals()
	_update_zone_info()


func _next_anchor_id() -> StringName:
	var next_index := 1
	var existing: Array = blueprint.zone_anchors.map(func(a): return a.anchor_id)
	while StringName("anchor_%d" % next_index) in existing:
		next_index += 1
	return StringName("anchor_%d" % next_index)


func _place_zone_marker_at_cursor() -> void:
	if not cursor_valid:
		return
	if _armed_tool == &"cell":
		var place := _current_place()
		if place == null:
			_update_status("Сначала создайте зону места (＋).")
			return
		var idx := place.cells.find(cursor_cell)
		if idx >= 0:
			place.cells.remove_at(idx)
		else:
			place.cells.append(cursor_cell)
		_mark_dirty()
		_refresh_zone_visuals()
		_update_zone_info()
		return
	var owner_id: StringName = &""
	var world := _anchor_world_check != null and _anchor_world_check.button_pressed
	if not world:
		var place := _current_place()
		if place == null:
			_update_status("Создайте зону места или включите «мировой якорь».")
			return
		owner_id = place.zone_id
	var anchor := ZoneAnchorRecordScript.new()
	anchor.anchor_id = _next_anchor_id()
	anchor.owner_zone_id = owner_id
	anchor.role = _anchor_role
	anchor.pos = Vector3(cursor_cell) + Vector3(0.5, 0.0, 0.5)
	if _zone_marker_yaw_spin != null:
		anchor.rot = Vector3(0.0, _zone_marker_yaw_spin.value, 0.0)
	if _zone_capacity_spin != null:
		anchor.capacity = int(_zone_capacity_spin.value)
	blueprint.zone_anchors.append(anchor)
	_mark_dirty()
	_refresh_zone_visuals()
	_update_zone_info()


func _refresh_zone_visuals() -> void:
	if _zones_visual_root == null:
		return
	for child in _zones_visual_root.get_children():
		child.free()
	if current_mode != EditMode.ZONES:
		return
	for i in blueprint.place_zones.size():
		var place: PlaceZoneRecord = blueprint.place_zones[i]
		var color := ZONE_COLORS[i % ZONE_COLORS.size()]
		for cell in place.cells:
			_add_zone_marker(Vector3(cell) + Vector3(0.5, 0.0, 0.5), color, Vector3(0.9, 0.04, 0.9), true)
	for anchor in blueprint.zone_anchors:
		var col := Color(0.4, 1.0, 0.4)
		var size := Vector3(0.4, 1.2, 0.4)
		if anchor.is_routing():
			col = Color(1.0, 0.55, 0.2)
			size = Vector3(0.5, 1.6, 0.5)
		elif anchor.is_tray():
			col = Color(0.4, 0.8, 1.0)
			size = Vector3(0.7, 0.3, 0.7)
		_add_zone_marker(anchor.pos, col, size, anchor.is_tray())


func _get_zone_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _zone_material_cache.has(key):
		return _zone_material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_zone_material_cache[key] = mat
	return mat


func _add_zone_marker(pos: Vector3, color: Color, size: Vector3, is_tray: bool) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _get_zone_material(color)
	mi.position = pos + Vector3(0.0, size.y * 0.5 + (0.02 if is_tray else 0.0), 0.0)
	_zones_visual_root.add_child(mi)


# ---------------------------------------------------------------------------
# UI sync helpers
# ---------------------------------------------------------------------------

func _update_fallback_display() -> void:
	if blueprint != null:
		blueprint.fallback_building_id = blueprint.infer_fallback_building_id()
		if _fallback_edit != null:
			_fallback_edit.text = String(blueprint.fallback_building_id)


func _sync_metadata_fields() -> void:
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


func _on_cost_header_pressed() -> void:
	_cost_container.visible = not _cost_container.visible
	var arrow := "▼" if _cost_container.visible else "►"
	_cost_header_btn.text = "%s Стоимость здания" % arrow
	if _cost_container.visible:
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
	if _cost_container == null or not _cost_container.visible:
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
			var row := HBoxContainer.new()
			var name_edit := LineEdit.new()
			name_edit.text = str(res)
			name_edit.custom_minimum_size = Vector2(80, 0)
			var spin := SpinBox.new()
			spin.min_value = 1
			spin.max_value = 9999
			spin.value = int(blueprint.manual_costs[res])
			var del_btn := Button.new()
			del_btn.text = "X"

			var old_key := str(res)
			name_edit.text_submitted.connect(func(new_text: String):
				var val: int = blueprint.manual_costs.get(old_key, 1)
				blueprint.manual_costs.erase(old_key)
				if not new_text.strip_edges().is_empty():
					blueprint.manual_costs[new_text.strip_edges()] = val
				blueprint.recalculate_construction_cost()
				_mark_dirty()
				_refresh_cost_ui()
			)
			spin.value_changed.connect(func(new_val: float):
				blueprint.manual_costs[old_key] = int(new_val)
				blueprint.recalculate_construction_cost()
				_mark_dirty()
				_refresh_cost_ui()
			)
			del_btn.pressed.connect(func():
				blueprint.manual_costs.erase(old_key)
				blueprint.recalculate_construction_cost()
				_mark_dirty()
				_refresh_cost_ui()
			)
			row.add_child(name_edit)
			row.add_child(spin)
			row.add_child(del_btn)
			_extra_costs_vbox.add_child(row)
	else:
		for res in blueprint.extra_costs.keys():
			var row := HBoxContainer.new()
			var name_edit := LineEdit.new()
			name_edit.text = str(res)
			name_edit.custom_minimum_size = Vector2(80, 0)
			var spin := SpinBox.new()
			spin.min_value = 1
			spin.max_value = 9999
			spin.value = int(blueprint.extra_costs[res])
			var del_btn := Button.new()
			del_btn.text = "X"

			var old_res_key := str(res)
			name_edit.text_submitted.connect(func(new_text: String):
				var val: int = blueprint.extra_costs.get(old_res_key, 1)
				blueprint.extra_costs.erase(old_res_key)
				if not new_text.strip_edges().is_empty():
					blueprint.extra_costs[new_text.strip_edges()] = val
				blueprint.recalculate_construction_cost()
				_mark_dirty()
				_refresh_cost_ui()
			)
			spin.value_changed.connect(func(new_val: float):
				blueprint.extra_costs[old_res_key] = int(new_val)
				blueprint.recalculate_construction_cost()
				_mark_dirty()
				_refresh_cost_ui()
			)
			del_btn.pressed.connect(func():
				blueprint.extra_costs.erase(old_res_key)
				blueprint.recalculate_construction_cost()
				_mark_dirty()
				_refresh_cost_ui()
			)

			row.add_child(name_edit)
			row.add_child(spin)
			row.add_child(del_btn)
			_extra_costs_vbox.add_child(row)

	var costs_array: Array[String] = []
	for res in blueprint.construction_cost.keys():
		costs_array.append("%d %s" % [int(blueprint.construction_cost[res]), str(res)])
	if costs_array.is_empty():
		_total_cost_label.text = "Итоговая смета: Бесплатно"
	else:
		_total_cost_label.text = "Итоговая смета: %s" % ", ".join(costs_array)


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
	add_child(dialog)
	dialog.popup_centered(Vector2i(360, 120))
	var user_confirmed := false
	dialog.confirmed.connect(func(): user_confirmed = true)
	await dialog.visibility_changed
	if dialog.visible:
		await dialog.hidden
	dialog.queue_free()
	return user_confirmed



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
