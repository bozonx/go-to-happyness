class_name FrameModeController
extends Node

## Frame mode of the building editor (design §3.1): places, erases and picks
## the `blocks[]` of a blueprint on a voxel grid.
##
## Lives as a child of BuildingEditor and owns everything frame-specific — the
## block palette, the brush inspector, the placement ghost, the shift-hover
## preview, the stamp brush, the 3D block nodes — so the editor script only
## routes input and mode switching here.

const CENTRE_LINE_COLOR := Color(1.0, 0.82, 0.18, 1.0)
const CENTRE_BAND_COLOR := Color(1.0, 0.82, 0.18, 0.12)

enum Tool { PLACE, ERASE }
enum Brush { LINE, RECT }

var _editor: BuildingEditor = null

var painting: bool = false
var last_paint_cell: Vector3i = Vector3i.ZERO
var paint_anchor: Vector3i = Vector3i.ZERO
var shift_erasing: bool = false
var _stamp_brush: Array[BlueprintBlock] = []
var _shift_hover_block: BlueprintBlock = null

var _block_nodes: Dictionary = {}
var _shift_hover_visual: MeshInstance3D = null

var _ghost_cell: Vector3i = Vector3i.ZERO
var _ghost_tool: int = -1
var _ghost_rot: int = -1
var _ghost_valid: bool = false

# UI bindings
var _ghost: MeshInstance3D = null
var _layer_plane: MeshInstance3D = null
var _blocks_root: Node3D = null
var _ground: MeshInstance3D = null
var _camera_controller: CameraController = null
var _material_option: OptionButton = null
var _brush_line_btn: Button = null
var _brush_rect_btn: Button = null
var _palette_panel: PanelContainer = null
var _palette_container: VBoxContainer = null
var _tool_place_btn: Button = null
var _tool_erase_btn: Button = null
var _frame_toolbar: HBoxContainer = null
var _rot_x_btn: Button = null
var _rot_btn: Button = null
var _rot_z_btn: Button = null
var _layer_label: Label = null
var _count_label: Label = null
var _fallback_edit: LineEdit = null
var _footprint_x_spin: SpinBox = null
var _footprint_z_spin: SpinBox = null
var _category_option: OptionButton = null
var _style_option: OptionButton = null
var _path_hint_label: Label = null
var _cost_header_btn: Label = null
var _cost_container: VBoxContainer = null
var _cost_mode_option: OptionButton = null
var _cost_block_summary_label: Label = null
var _cost_breakdown_vbox: VBoxContainer = null
var _extra_costs_vbox: VBoxContainer = null
var _add_extra_cost_btn: Button = null
var _total_cost_label: Label = null

var _palette_buttons: Dictionary = {}
var _brush_inspector: Control = null


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(editor: Node) -> void:
	_editor = editor
	name = "FrameModeController"

	_camera_controller = editor.get_node("%CameraController")
	_blocks_root = editor.get_node("%BlocksRoot")
	_ground = editor.get_node("Ground") as MeshInstance3D
	_ghost = editor.get_node("%Ghost")
	_layer_plane = editor.get_node("%LayerPlane")
	_material_option = editor.get_node("%MaterialOption")
	_brush_line_btn = editor.get_node("%BrushLineBtn")
	_brush_rect_btn = editor.get_node("%BrushRectBtn")
	_palette_panel = editor.get_node("%PalettePanel")
	_palette_container = editor.get_node("%PaletteContainer")
	_tool_place_btn = editor.get_node("%ToolPlaceBtn")
	_tool_erase_btn = editor.get_node("%ToolEraseBtn")
	_frame_toolbar = editor.get_node("%FrameToolbar")
	_rot_x_btn = editor.get_node("%RotXBtn")
	_rot_btn = editor.get_node("%RotBtn")
	_rot_z_btn = editor.get_node("%RotZBtn")
	_layer_label = editor.get_node("%LayerLabel")
	_count_label = editor.get_node("%CountLabel")
	_fallback_edit = editor.get_node("%FallbackEdit")
	_footprint_x_spin = editor.get_node("%FootprintXSpin")
	_footprint_z_spin = editor.get_node("%FootprintZSpin")
	_category_option = editor.get_node("%CategoryOption")
	_style_option = editor.get_node("%StyleOption")
	_path_hint_label = editor.get_node("%PathHintLabel")
	_cost_header_btn = editor.get_node("%CostHeaderBtn")
	_cost_container = editor.get_node("%CostContainer")
	_cost_mode_option = editor.get_node("%CostModeOption")
	_cost_block_summary_label = editor.get_node("%CostBlockSummaryLabel")
	_cost_breakdown_vbox = editor.get_node("%CostBreakdownVBox")
	_extra_costs_vbox = editor.get_node("%ExtraCostsVBox")
	_add_extra_cost_btn = editor.get_node("%AddExtraCostBtn")
	_total_cost_label = editor.get_node("%TotalCostLabel")

	_material_option.item_selected.connect(func(index: int):
		_editor.current_material_id = _material_option.get_item_metadata(index)
		refresh_ghost()
	)

	_build_palette_blocks()

	_category_option.clear()
	for category_id in BuildingMaterialCatalog.ERA_ORDER:
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
		_editor.blueprint.construction_style = _style_option.get_item_metadata(index)
		_editor.mark_dirty()
	)

	_path_hint_label.text = "Сохранение → %s" % _editor.repository.base_dir()

	_cost_mode_option.clear()
	_cost_mode_option.add_item("Авто-расчёт (по блокам)")
	_cost_mode_option.set_item_metadata(0, &"auto")
	_cost_mode_option.add_item("Ручной ввод сметы")
	_cost_mode_option.set_item_metadata(1, &"manual")

	_cost_container.visible = true
	_cost_header_btn.text = "Стоимость здания"

	_cost_mode_option.item_selected.connect(_on_cost_mode_selected)
	_add_extra_cost_btn.pressed.connect(_on_add_extra_cost_pressed)

	_shift_hover_visual = MeshInstance3D.new()
	_shift_hover_visual.name = "ShiftHoverBlock"
	_shift_hover_visual.visible = false
	_blocks_root.add_child(_shift_hover_visual)


# ---------------------------------------------------------------------------
# Mode lifecycle
# ---------------------------------------------------------------------------

func activate() -> void:
	if _palette_panel != null:
		_palette_panel.visible = true
	if _frame_toolbar != null:
		_frame_toolbar.visible = true


func deactivate() -> void:
	painting = false
	shift_erasing = false
	# The frame ghost is shared scene UI, not part of the palette.  It must not
	# survive a switch to decor/zones and look like a stray block in the world.
	if _ghost != null:
		_ghost.visible = false
	if _shift_hover_visual != null:
		_shift_hover_visual.visible = false
	if _palette_panel != null:
		_palette_panel.visible = false
	if _frame_toolbar != null:
		_frame_toolbar.visible = false


func is_active() -> bool:
	return _editor.current_mode == BuildingEditor.EditMode.FRAME


func is_painting() -> bool:
	return painting


func is_shift_erasing() -> bool:
	return shift_erasing


# ---------------------------------------------------------------------------
# Process & ghost
# ---------------------------------------------------------------------------

func process(_delta: float) -> void:
	if shift_erasing:
		_editor._orbiting = false
	refresh_shift_hover()
	if _editor.cursor_valid and (_editor.cursor_cell != _ghost_cell or _editor.current_tool != _ghost_tool or _editor.current_rot != _ghost_rot or _editor.cursor_valid != _ghost_valid):
		refresh_ghost()


func refresh_ghost() -> void:
	_ghost_cell = _editor.cursor_cell
	_ghost_tool = _editor.current_tool
	_ghost_rot = _editor.current_rot
	_ghost_valid = _editor.cursor_valid
	if not _editor.cursor_valid:
		_ghost.visible = false
		return
	if _editor.current_tool == Tool.PLACE and _editor.current_block_id.is_empty() and _stamp_brush.is_empty():
		_ghost.visible = false
		return
	_ghost.visible = true
	if _editor.current_tool == Tool.ERASE:
		var target := _editor.grid_model.get_block_at(_editor.cursor_cell)
		if target == null:
			_ghost.mesh = _editor.mesh_library.mesh_for(_editor.current_block_id, _editor.current_variant)
			_ghost.rotation = _current_ghost_euler()
			_ghost.position = Vector3(_editor.cursor_cell) + BlockMeshLibrary.local_offset(_editor.current_block_id, _editor.current_variant, _editor.current_rot, _editor.current_anchor, 0.0, _editor.current_rot_x, _editor.current_rot_z)
			_ghost.material_override = _editor.mesh_library.ghost_material(false)
		else:
			_ghost.mesh = _editor.mesh_library.mesh_for(target.block_id, target.variant)
			_ghost.rotation = target.rotation_euler()
			_ghost.position = Vector3(target.pos) + BlockMeshLibrary.local_offset(target.block_id, target.variant, target.rot, target.anchor, 0.0, target.rot_x, target.rot_z)
			_ghost.material_override = _editor.mesh_library.ghost_material(false)
	else:
		_ghost.mesh = _editor.mesh_library.mesh_for(_editor.current_block_id, _editor.current_variant)
		_ghost.rotation = _current_ghost_euler()
		_ghost.position = Vector3(_editor.cursor_cell) + BlockMeshLibrary.local_offset(_editor.current_block_id, _editor.current_variant, _editor.current_rot, _editor.current_anchor, 0.0, _editor.current_rot_x, _editor.current_rot_z)
		_ghost.material_override = _editor.mesh_library.ghost_material(is_block_in_bounds(_editor.cursor_cell, _editor.current_block_id, _editor.current_variant, _editor.current_rot) and _editor.grid_model.can_place(
			_editor.cursor_cell, _editor.current_block_id, _editor.current_rot, _editor.current_material_id, _editor.current_variant,
			_editor.current_anchor, _editor.current_rot_x, _editor.current_rot_z))


func _current_ghost_euler() -> Vector3:
	return Vector3(
		deg_to_rad(90.0 * float(_editor.current_rot_x)),
		deg_to_rad(90.0 * float(_editor.current_rot)),
		deg_to_rad(90.0 * float(_editor.current_rot_z)))


# ---------------------------------------------------------------------------
# Block placement & erasing
# ---------------------------------------------------------------------------

func apply_tool_at_cursor() -> void:
	if not _editor.cursor_valid:
		return
	_apply_tool_at_cell(_editor.cursor_cell)
	refresh_ghost()


func _apply_tool_at_cell(cell: Vector3i) -> void:
	match _editor.current_tool:
		Tool.PLACE:
			if _editor.current_block_id.is_empty() and _stamp_brush.is_empty():
				return
			if not _stamp_brush.is_empty():
				_apply_stamp_at_cell(cell)
			elif is_block_in_bounds(cell, _editor.current_block_id, _editor.current_variant, _editor.current_rot) and _editor.grid_model.place(cell, _editor.current_block_id, _editor.current_rot, _editor.current_material_id, _editor.current_variant, _editor.current_anchor, _editor.current_rot_x, _editor.current_rot_z):
				_spawn_or_update_block_node(_editor.grid_model.get_block_at(cell))
				_update_count()
				_editor.mark_dirty()
		Tool.ERASE:
			var target := _editor.grid_model.get_block_at(cell)
			if _editor.grid_model.erase(cell):
				if target != null:
					_remove_block_node(target)
				_update_count()
				_editor.mark_dirty()


func _apply_stamp_at_cell(cell: Vector3i) -> void:
	if _stamp_brush.is_empty():
		return
	var origin := _stamp_brush[0].pos
	for block in _stamp_brush:
		var target := cell + (block.pos - origin)
		if not is_block_in_bounds(target, block.block_id, block.variant, block.rot) or not _editor.grid_model.can_place(
			target, block.block_id, block.rot, block.material_id, block.variant,
			block.anchor, block.rot_x, block.rot_z):
			return
	for block in _stamp_brush:
		var target := cell + (block.pos - origin)
		if _editor.grid_model.place(target, block.block_id, block.rot, block.material_id, block.variant,
			block.anchor, block.rot_x, block.rot_z):
			_spawn_or_update_block_node(_editor.grid_model.get_block_at(target))
	_update_count()
	_editor.mark_dirty()


func erase_hovered_block_or_cell() -> void:
	if not _editor.cursor_valid:
		return
	var target := _block_under_mouse()
	if target != null and _editor.grid_model.erase_block(target):
		_editor._set_layer(target.pos.y)
		_remove_block_node(target)
		_update_count()
		_editor.mark_dirty()
		refresh_ghost()
		return
	_apply_erase_at_cell(_editor.cursor_cell)


func _apply_erase_at_cell(cell: Vector3i) -> void:
	var target := _editor.grid_model.get_block_at(cell)
	if target != null and _editor.grid_model.erase_block(target):
		_remove_block_node(target)
		_update_count()
		_editor.mark_dirty()


func erase_line(from_cell: Vector3i, to_cell: Vector3i) -> void:
	for cell in _bresenham_cells(from_cell, to_cell):
		_apply_erase_at_cell(cell)
	refresh_ghost()


func paint_line(from_cell: Vector3i, to_cell: Vector3i) -> void:
	for cell in _bresenham_cells(from_cell, to_cell):
		_apply_tool_at_cell(cell)
	refresh_ghost()


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
		cells.append(Vector3i(x, _editor.active_layer, z))
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


func paint_rect(from_cell: Vector3i, to_cell: Vector3i) -> void:
	var x0 := mini(from_cell.x, to_cell.x)
	var x1 := maxi(from_cell.x, to_cell.x)
	var z0 := mini(from_cell.z, to_cell.z)
	var z1 := maxi(from_cell.z, to_cell.z)
	var y := _editor.active_layer
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			_apply_tool_at_cell(Vector3i(x, y, z))
	refresh_ghost()


# ---------------------------------------------------------------------------
# Shift hover & block picking
# ---------------------------------------------------------------------------

func refresh_shift_hover() -> void:
	if _shift_hover_visual == null:
		return
	_shift_hover_block = null
	if not is_active() or not Input.is_key_pressed(KEY_SHIFT) or not _editor.cursor_valid:
		_shift_hover_visual.visible = false
		return
	var block := _block_under_mouse()
	if block == null:
		_shift_hover_visual.visible = false
		return
	_shift_hover_block = block
	_shift_hover_visual.mesh = _editor.mesh_library.mesh_for(block.block_id, block.variant)
	_shift_hover_visual.position = Vector3(block.pos) + BlockMeshLibrary.local_offset(
		block.block_id, block.variant, block.rot, block.anchor, 0.0, block.rot_x, block.rot_z)
	_shift_hover_visual.rotation = block.rotation_euler()
	_shift_hover_visual.material_override = _editor.mesh_library.ghost_material(true)
	_shift_hover_visual.visible = true


func _block_under_mouse() -> BlueprintBlock:
	if _camera_controller == null or _camera_controller.camera == null:
		return null
	var camera := _camera_controller.camera
	var mouse_pos := _editor.get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var closest: BlueprintBlock = null
	var closest_distance := INF
	for block: BlueprintBlock in _editor.grid_model.all_blocks():
		var aabb := BuildingBlockCatalog.occupied_aabb(block.pos, block.block_id,
			block.variant, block.rot, block.anchor, block.rot_x, block.rot_z)
		var distance := _ray_aabb_entry_distance(origin, direction, aabb)
		if distance >= 0.0 and distance < closest_distance:
			closest = block
			closest_distance = distance
	return closest


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


func pick_single_block(retain_stamp: bool = false) -> void:
	var block := _block_under_mouse()
	if block == null:
		_editor.set_status("Под Shift нет блока для выбора.")
		return
	_editor._set_layer(block.pos.y)
	select_block(block.block_id, block.variant, retain_stamp)
	_editor.current_material_id = block.material_id
	_editor.current_anchor = block.anchor
	_editor.current_rot = block.rot
	_editor.current_rot_x = block.rot_x
	_editor.current_rot_z = block.rot_z
	_select_material_in_option(_editor.current_material_id)
	_rebuild_brush_inspector()
	_update_rotation_label()
	refresh_ghost()
	_editor.set_status("Выбран элемент %s." % block.block_id)


func pick_stamp_brush() -> void:
	var block := _block_under_mouse()
	if block == null:
		_editor.set_status("Под Shift нет блока для кисти.")
		return
	_stamp_brush.clear()
	for source in _editor.grid_model.blocks_anchored_at(block.pos):
		_stamp_brush.append(BlueprintBlock.new(source.pos, source.block_id, source.rot,
			source.material_id, source.variant, source.anchor, source.rot_x, source.rot_z))
	pick_single_block(true)
	_editor.set_status("Кисть: узел из %d подблок(ов)." % _stamp_brush.size())


func _select_material_in_option(material_id: StringName) -> void:
	for index in _material_option.item_count:
		if _material_option.get_item_metadata(index) == material_id:
			_material_option.select(index)
			return


# ---------------------------------------------------------------------------
# Block visuals
# ---------------------------------------------------------------------------

func spawn_or_update_block_node(block: BlueprintBlock) -> void:
	_spawn_or_update_block_node(block)


func _spawn_or_update_block_node(block: BlueprintBlock) -> void:
	var key := _editor.grid_model.placement_key_for(block)
	var node: MeshInstance3D = _block_nodes.get(key, null)
	if node == null:
		node = MeshInstance3D.new()
		_blocks_root.add_child(node)
		_block_nodes[key] = node
	node.mesh = _editor.mesh_library.mesh_for(block.block_id, block.variant)
	node.material_override = _editor.mesh_library.material_for(block.material_id)
	node.position = Vector3(block.pos) + BlockMeshLibrary.local_offset(block.block_id, block.variant, block.rot, block.anchor, 0.0, block.rot_x, block.rot_z)
	node.rotation = block.rotation_euler()


func remove_block_node(block: BlueprintBlock) -> void:
	_remove_block_node(block)


func _remove_block_node(block: BlueprintBlock) -> void:
	var key := _editor.grid_model.placement_key_for(block)
	var node: MeshInstance3D = _block_nodes.get(key, null)
	if node != null:
		node.queue_free()
		_block_nodes.erase(key)


func rebuild_all_block_nodes() -> void:
	for node in _block_nodes.values():
		node.queue_free()
	_block_nodes.clear()
	for block in _editor.grid_model.all_blocks():
		_spawn_or_update_block_node(block)
	_update_count()


# ---------------------------------------------------------------------------
# Bounds helpers
# ---------------------------------------------------------------------------

func is_block_in_bounds(cell: Vector3i, block_id: StringName, variant: StringName, rot: int) -> bool:
	for covered: Vector3i in BuildingGridModel.occupied_cells(cell, block_id, variant, rot):
		if not _editor.is_cell_in_bounds(covered):
			return false
	return true


# ---------------------------------------------------------------------------
# State changes
# ---------------------------------------------------------------------------

func set_tool(tool_id: int) -> void:
	_editor.current_tool = tool_id
	if _tool_place_btn != null:
		_tool_place_btn.button_pressed = tool_id == Tool.PLACE
	if _tool_erase_btn != null:
		_tool_erase_btn.button_pressed = tool_id == Tool.ERASE
	refresh_ghost()


func set_brush(brush_id: int) -> void:
	_editor.current_brush = brush_id
	if _brush_line_btn != null:
		_brush_line_btn.button_pressed = brush_id == Brush.LINE
	if _brush_rect_btn != null:
		_brush_rect_btn.button_pressed = brush_id == Brush.RECT


func select_block(block_id: StringName, variant: StringName = &"", retain_stamp: bool = false) -> void:
	if not retain_stamp:
		_stamp_brush.clear()
	if variant == &"":
		variant = _editor.current_variant if block_id == _editor.current_block_id else BuildingBlockCatalog.default_variant(block_id)
	_editor.current_block_id = block_id
	_editor.current_variant = BuildingBlockCatalog.normalize_variant(block_id, variant)
	var def := BuildingBlockCatalog.get_block(block_id)
	if def.is_empty() or not def.get("rotatable", true):
		_editor.current_rot = 0
		_editor.current_rot_x = 0
		_editor.current_rot_z = 0
	set_tool(Tool.PLACE)
	for key in _palette_buttons.keys():
		(_palette_buttons[key] as Button).button_pressed = key == _editor.current_block_id
	_rebuild_brush_inspector()
	_update_rotation_label()
	refresh_ghost()


func clear_block_selection() -> void:
	_stamp_brush.clear()
	_editor.current_block_id = &""
	_editor.current_variant = &""
	for key in _palette_buttons.keys():
		(_palette_buttons[key] as Button).button_pressed = false
	if _brush_inspector != null:
		_brush_inspector.visible = false
	refresh_ghost()
	_editor.set_status("Элемент для строительства не выбран.")


func cycle_rotation(direction: int = 1) -> void:
	var def := BuildingBlockCatalog.get_block(_editor.current_block_id)
	if def.is_empty() or not def.get("rotatable", true):
		return
	_editor.current_rot = (_editor.current_rot + direction + 4) % 4
	_rebuild_brush_inspector()
	_update_rotation_label()
	refresh_ghost()


func cycle_rotation_x(direction: int = 1) -> void:
	var def := BuildingBlockCatalog.get_block(_editor.current_block_id)
	if def.is_empty() or not def.get("rotatable", true):
		return
	_editor.current_rot_x = (_editor.current_rot_x + direction + 4) % 4
	_update_rotation_label()
	refresh_ghost()


func cycle_rotation_z(direction: int = 1) -> void:
	var def := BuildingBlockCatalog.get_block(_editor.current_block_id)
	if def.is_empty() or not def.get("rotatable", true):
		return
	_editor.current_rot_z = (_editor.current_rot_z + direction + 4) % 4
	_update_rotation_label()
	refresh_ghost()


func select_anchor(anchor: int) -> void:
	_editor.current_anchor = anchor
	_rebuild_brush_inspector()
	refresh_ghost()


func update_fallback_display() -> void:
	_editor.update_fallback_display()
	if _fallback_edit != null:
		_fallback_edit.text = String(_editor.blueprint.fallback_building_id)


# ---------------------------------------------------------------------------
# Material / era
# ---------------------------------------------------------------------------

func rebuild_material_options() -> void:
	if _material_option == null:
		return
	_material_option.clear()
	var current_ok := false
	for material in BuildingMaterialCatalog.materials_for_era(_editor.blueprint.category):
		_material_option.add_item(material["name"])
		_material_option.set_item_metadata(_material_option.item_count - 1, material["id"])
		if material["id"] == _editor.current_material_id:
			current_ok = true
	if not current_ok:
		_editor.current_material_id = BuildingMaterialCatalog.default_material_for_era(_editor.blueprint.category)
	for i in _material_option.item_count:
		if _material_option.get_item_metadata(i) == _editor.current_material_id:
			_material_option.select(i)
			break
	refresh_ghost()


func _on_era_changed(index: int) -> void:
	var target_era: StringName = StringName(_category_option.get_item_metadata(index))
	if target_era == _editor.blueprint.category:
		return

	var offenders := _get_offending_blocks(target_era)
	if not offenders.is_empty():
		var default_mat := BuildingMaterialCatalog.default_material_for_era(target_era)
		var mat_info := BuildingMaterialCatalog.get_material(default_mat)
		var default_mat_name: String = String(mat_info.get("name", str(default_mat)))

		var user_confirmed := await _confirm_era_material_replacement(target_era, offenders.size(), default_mat_name)
		if not user_confirmed:
			select_category_in_option(_editor.blueprint.category)
			_editor.set_status("Смена эры отменена.")
			return

		for block in offenders:
			block.material_id = default_mat
		rebuild_all_block_nodes()
		_editor.grid_model.write_to_blueprint(_editor.blueprint)
		_editor.blueprint.recalculate_construction_cost()

	_editor.blueprint.category = target_era
	update_fallback_display()
	_editor.mark_dirty()
	rebuild_material_options()
	refresh_underground_availability()
	if not offenders.is_empty():
		_editor.set_status("Эра изменена на %s (%d блоков заменено)." % [_editor.blueprint.category, offenders.size()])
	else:
		_editor.set_status("Эра: %s." % _editor.blueprint.category)


func _get_offending_blocks(target_era: StringName) -> Array[BlueprintBlock]:
	var offenders: Array[BlueprintBlock] = []
	for block in _editor.grid_model.all_blocks():
		if not BuildingMaterialCatalog.is_available_in_era(block.material_id, target_era):
			offenders.append(block)
	return offenders


func _confirm_era_material_replacement(target_era: StringName, count: int, default_mat_name: String) -> bool:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Автозамена материалов блоков"
	dialog.dialog_text = "В здании %d блок(ов) используют материалы, недоступные в эре «%s».\nЗаменить их автоматически на «%s»?" % [count, target_era, default_mat_name]
	dialog.ok_button_text = "Заменить"
	dialog.cancel_button_text = "Отмена"
	return await _editor._run_confirmation_dialog(dialog, Vector2i(420, 140))


func select_category_in_option(category: StringName) -> void:
	if _category_option != null:
		for i in _category_option.item_count:
			if _category_option.get_item_metadata(i) == category:
				_category_option.select(i)
				break


func refresh_underground_availability() -> void:
	if _style_option == null:
		return
	var earth_rank := BuildingMaterialCatalog.era_rank(&"earth")
	var allowed := BuildingMaterialCatalog.era_rank(_editor.blueprint.category) >= earth_rank
	for i in _style_option.item_count:
		if _style_option.get_item_metadata(i) == &"underground":
			_style_option.set_item_disabled(i, not allowed)
	if not allowed and _editor.blueprint.construction_style == &"underground":
		_editor.blueprint.construction_style = &"surface"
		select_style_in_option(&"surface")


func select_style_in_option(style: StringName) -> void:
	if _style_option == null:
		return
	for i in _style_option.item_count:
		if _style_option.get_item_metadata(i) == style:
			_style_option.select(i)
			break


# ---------------------------------------------------------------------------
# Palette & brush inspector
# ---------------------------------------------------------------------------

func _build_palette_blocks() -> void:
	for child in _palette_container.get_children():
		child.queue_free()
	_palette_buttons.clear()

	var blocks_by_category: Dictionary = {}
	var category_order: Array[int] = []
	for def in BuildingBlockCatalog.all():
		var category: int = def["category"]
		if not blocks_by_category.has(category):
			blocks_by_category[category] = []
			category_order.append(category)
		(blocks_by_category[category] as Array).append(def)

	for category in category_order:
		var cat_label := Label.new()
		cat_label.text = BuildingBlockCatalog.category_name(category)
		cat_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
		_palette_container.add_child(cat_label)
		for def in blocks_by_category[category]:
			var block_id: StringName = def["id"]
			var btn := Button.new()
			btn.toggle_mode = true
			btn.text = def["name"]
			if BuildingBlockCatalog.has_variants(block_id):
				btn.tooltip_text = "Размер/профиль выбирается ниже"
			else:
				var s: Vector3 = def["size"]
				btn.tooltip_text = "Размер: %.2f×%.2f×%.2f м" % [s.x, s.y, s.z]
			btn.pressed.connect(select_block.bind(block_id))
			_palette_buttons[block_id] = btn
			_palette_container.add_child(btn)


func _ensure_brush_inspector() -> Control:
	if _brush_inspector != null and is_instance_valid(_brush_inspector):
		return _brush_inspector
	_brush_inspector = VBoxContainer.new()
	_brush_inspector.name = "BrushInspector"
	_palette_container.add_child(_brush_inspector)
	return _brush_inspector


func _move_brush_inspector_under_selection() -> void:
	if _brush_inspector == null or not is_instance_valid(_brush_inspector):
		return
	var btn: Button = _palette_buttons.get(_editor.current_block_id, null)
	if btn == null:
		return
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

	var variants: Array = BuildingBlockCatalog.variants(_editor.current_block_id)
	var kinds: Array = BuildingBlockCatalog.available_anchors(_editor.current_block_id, _editor.current_variant)
	if kinds.size() <= 1:
		_editor.current_anchor = BuildingBlockCatalog.ANCHOR_CENTER
	else:
		_editor.current_anchor = BuildingBlockCatalog.normalize_anchor(_editor.current_block_id, _editor.current_variant, _editor.current_anchor)

	if variants.is_empty() and kinds.size() <= 1:
		return

	var toolbar := HBoxContainer.new()
	toolbar.name = "BrushToolbar"
	host.add_child(toolbar)

	if not variants.is_empty():
		for v in variants:
			var v_id: StringName = v["id"]
			var vbtn := Button.new()
			vbtn.toggle_mode = true
			vbtn.text = v["name"]
			vbtn.button_pressed = v_id == _editor.current_variant
			var v_size: Vector3 = v.get("size", Vector3.ONE)
			vbtn.tooltip_text = "Размер: %.2f×%.2f×%.2f м" % [v_size.x, v_size.y, v_size.z]
			vbtn.pressed.connect(select_block.bind(_editor.current_block_id, v_id))
			toolbar.add_child(vbtn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	if kinds.size() > 1:
		for kind in kinds:
			var abtn := Button.new()
			abtn.toggle_mode = true
			abtn.text = _anchor_label(kind)
			abtn.button_pressed = kind == _editor.current_anchor
			abtn.pressed.connect(select_anchor.bind(kind))
			toolbar.add_child(abtn)


func _anchor_label(kind: int) -> String:
	match kind:
		BuildingBlockCatalog.ANCHOR_EDGE: return "К грани"
		BuildingBlockCatalog.ANCHOR_CORNER: return "В угол"
		_: return "Центр"


# ---------------------------------------------------------------------------
# UI sync helpers
# ---------------------------------------------------------------------------

func _update_rotation_label() -> void:
	if _rot_x_btn != null:
		var deg_x := _editor.current_rot_x * 90
		_rot_x_btn.text = "🔄X %d° (X)" % deg_x if deg_x != 0 else "🔄X (X)"
	if _rot_btn != null:
		var deg_y := _editor.current_rot * 90
		_rot_btn.text = "🔄Y %d° (C)" % deg_y if deg_y != 0 else "🔄Y (C)"
	if _rot_z_btn != null:
		var deg_z := _editor.current_rot_z * 90
		_rot_z_btn.text = "🔄Z %d° (Z)" % deg_z if deg_z != 0 else "🔄Z (Z)"


func _update_count() -> void:
	if _count_label != null:
		_count_label.text = "Блоков: %d" % _editor.grid_model.count()
	if _editor.blueprint != null:
		_editor.grid_model.write_to_blueprint(_editor.blueprint)
		_editor.blueprint.recalculate_construction_cost()
		_refresh_cost_ui()


func _refresh_cost_ui() -> void:
	if _cost_container == null:
		return

	_cost_block_summary_label.text = "Всего блоков: %d" % _editor.blueprint.block_count()

	if _editor.blueprint.cost_mode == &"manual":
		_cost_mode_option.select(1)
	else:
		_cost_mode_option.select(0)

	for child in _cost_breakdown_vbox.get_children():
		child.queue_free()

	if _editor.blueprint.cost_mode == &"auto":
		var mat_counts: Dictionary = {}
		for block in _editor.blueprint.blocks:
			mat_counts[block.material_id] = int(mat_counts.get(block.material_id, 0)) + 1

		for mat_id in mat_counts.keys():
			var count: int = mat_counts[mat_id]
			var mat_def := BuildingMaterialCatalog.get_material(mat_id)
			var mat_name: String = mat_def.get("name", str(mat_id))
			var comp: Dictionary = BuildingMaterialCatalog.resource_composition(mat_id)
			if _editor.blueprint.custom_material_costs.has(mat_id) and _editor.blueprint.custom_material_costs[mat_id] is Dictionary:
				comp = _editor.blueprint.custom_material_costs[mat_id]

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

	if _editor.blueprint.cost_mode == &"manual":
		var manual_title := Label.new()
		manual_title.text = "Ручная смета (все ресурсы):"
		manual_title.add_theme_font_size_override("font_size", 13)
		_extra_costs_vbox.add_child(manual_title)

		for res in _editor.blueprint.manual_costs.keys():
			_extra_costs_vbox.add_child(_build_cost_row(
				_editor.blueprint.manual_costs, str(res),
				_editor.blueprint.manual_costs[res]))
	else:
		for res in _editor.blueprint.extra_costs.keys():
			_extra_costs_vbox.add_child(_build_cost_row(
				_editor.blueprint.extra_costs, str(res),
				_editor.blueprint.extra_costs[res]))

	var costs_array: Array[String] = []
	for res in _editor.blueprint.construction_cost.keys():
		costs_array.append("%d %s" % [int(_editor.blueprint.construction_cost[res]), str(res)])
	if costs_array.is_empty():
		_total_cost_label.text = "Итоговая смета: Бесплатно"
	else:
		_total_cost_label.text = "Итоговая смета: %s" % ", ".join(costs_array)


func _on_cost_mode_selected(index: int) -> void:
	var mode: StringName = _cost_mode_option.get_item_metadata(index)
	_editor.blueprint.cost_mode = mode
	_editor.blueprint.recalculate_construction_cost()
	_editor.mark_dirty()
	_refresh_cost_ui()


func _on_add_extra_cost_pressed() -> void:
	var default_res := "coins"
	var current_qty := int(_editor.blueprint.extra_costs.get(default_res, 0))
	_editor.blueprint.extra_costs[default_res] = current_qty + 1
	_editor.blueprint.recalculate_construction_cost()
	_editor.mark_dirty()
	_refresh_cost_ui()


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
		_editor.blueprint.recalculate_construction_cost()
		_editor.mark_dirty()
		_refresh_cost_ui()
	)
	spin.value_changed.connect(func(new_val: float):
		costs[old_key] = int(new_val)
		_editor.blueprint.recalculate_construction_cost()
		_editor.mark_dirty()
		_refresh_cost_ui()
	)
	del_btn.pressed.connect(func():
		costs.erase(old_key)
		_editor.blueprint.recalculate_construction_cost()
		_editor.mark_dirty()
		_refresh_cost_ui()
	)
	row.add_child(name_edit)
	row.add_child(spin)
	row.add_child(del_btn)
	return row


# ---------------------------------------------------------------------------
# Grid visuals & footprint
# ---------------------------------------------------------------------------

func refresh_building_grid_visuals() -> void:
	if _editor.blueprint == null:
		return
	var width := _editor.blueprint.footprint.x
	var depth := _editor.blueprint.footprint.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for x in range(width + 1):
		st.set_color(Color(0.30, 0.34, 0.40, 0.8))
		st.add_vertex(Vector3(x, 0.0, 0.0)); st.add_vertex(Vector3(x, 0.0, depth))
	for z in range(depth + 1):
		st.set_color(Color(0.30, 0.34, 0.40, 0.8))
		st.add_vertex(Vector3(0.0, 0.0, z)); st.add_vertex(Vector3(width, 0.0, z))
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
	_editor.get_node("%GridLines").mesh = mesh
	_layer_plane.mesh = mesh


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


func _add_band_quad(st: SurfaceTool, from: Vector2, to: Vector2) -> void:
	const Y := 0.011
	var a := Vector3(from.x, Y, from.y)
	var b := Vector3(to.x, Y, from.y)
	var c := Vector3(to.x, Y, to.y)
	var d := Vector3(from.x, Y, to.y)
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)


func focus_footprint_center() -> void:
	if _camera_controller == null or _editor.blueprint == null:
		return
	var centre := Vector3(_editor.blueprint.footprint.x * 0.5, 0.0, _editor.blueprint.footprint.y * 0.5)
	_camera_controller.camera_target = centre
	if _ground != null:
		_ground.position = centre + Vector3(0.0, -0.01, 0.0)
		var ground_mesh := _ground.mesh as PlaneMesh
		if ground_mesh != null:
			var margin := 16.0
			ground_mesh.size = Vector2(maxf(64.0, float(_editor.blueprint.footprint.x) + margin), maxf(64.0, float(_editor.blueprint.footprint.y) + margin))
	_camera_controller.apply_position()


func refresh_layer_plane() -> void:
	if _layer_plane != null:
		_layer_plane.position = Vector3(0.0, float(_editor.active_layer), 0.0)
	if _layer_label != null:
		_layer_label.text = "Слой %d" % _editor.active_layer


func _on_footprint_changed(_value: float) -> void:
	if _editor.blueprint == null or _editor._syncing_metadata_fields:
		return
	_editor.blueprint.footprint = Vector2i(int(_footprint_x_spin.value), int(_footprint_z_spin.value))
	var removed := 0
	for block in _editor.grid_model.all_blocks():
		if not is_block_in_bounds(block.pos, block.block_id, block.variant, block.rot):
			_editor.grid_model.erase_block(block)
			_remove_block_node(block)
			removed += 1
	if removed > 0:
		_update_count()
		_editor.set_status("Размер изменён. Удалено блоков вне границ: %d" % removed)
	refresh_building_grid_visuals()
	focus_footprint_center()
	refresh_ghost()
	_editor.mark_dirty()


# ---------------------------------------------------------------------------
# Metadata sync
# ---------------------------------------------------------------------------

func sync_metadata_fields() -> void:
	_editor._syncing_metadata_fields = true
	if _editor._name_edit != null:
		_editor._name_edit.text = _editor.blueprint.name
	if _editor._id_edit != null:
		_editor._id_edit.text = String(_editor.blueprint.id)
	update_fallback_display()
	if _footprint_x_spin != null:
		_footprint_x_spin.value = _editor.blueprint.footprint.x
	if _footprint_z_spin != null:
		_footprint_z_spin.value = _editor.blueprint.footprint.y
	if _editor._entrance_x_spin != null:
		_editor._entrance_x_spin.value = _editor.blueprint.entrance.x
	if _editor._entrance_z_spin != null:
		_editor._entrance_z_spin.value = _editor.blueprint.entrance.y
	if _category_option != null:
		for i in _category_option.item_count:
			if _category_option.get_item_metadata(i) == _editor.blueprint.category:
				_category_option.select(i)
				break
	select_style_in_option(_editor.blueprint.construction_style)
	rebuild_material_options()
	refresh_underground_availability()
	_editor._syncing_metadata_fields = false
	_update_count()
	refresh_building_grid_visuals()
	focus_footprint_center()
	refresh_ghost()


# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

func on_save_pressed() -> void:
	_editor.blueprint.name = _editor._name_edit.text.strip_edges()
	if _editor.blueprint.name.is_empty():
		_editor.blueprint.name = "Новое здание"
	if _editor._id_edit != null:
		var raw_id := _editor._id_edit.text.strip_edges()
		if not raw_id.is_empty():
			_editor.blueprint.id = StringName(raw_id)
	if _category_option != null:
		_editor.blueprint.category = StringName(_category_option.get_item_metadata(_category_option.selected))
	update_fallback_display()
	if _footprint_x_spin != null and _footprint_z_spin != null:
		_editor.blueprint.footprint = Vector2i(int(_footprint_x_spin.value), int(_footprint_z_spin.value))
	if _editor._entrance_x_spin != null and _editor._entrance_z_spin != null:
		_editor.blueprint.entrance = Vector2i(int(_editor._entrance_x_spin.value), int(_editor._entrance_z_spin.value))
	_editor.grid_model.write_to_blueprint(_editor.blueprint)
	var result := _editor.repository.save(_editor.blueprint)
	if result["ok"]:
		_editor._dirty = false
		_editor.reset_history()
		_editor.set_status("Сохранено: %s (%d блоков)" % [result["path"], _editor.blueprint.block_count()])
	else:
		_editor.set_status("Ошибка сохранения: %s" % result["error"])
