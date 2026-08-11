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
var _stroke_changed := false
var _shift_hover_block: BlueprintBlock = null

var _block_nodes: Dictionary = {}
var _shift_hover_visual: MeshInstance3D = null

var _ghost_cell: Vector3i = Vector3i.ZERO
var _ghost_tool: int = -1
var _ghost_rot: int = -1
var _ghost_valid: bool = false

## Blocks that existed when the current paint stroke began. Newly placed
## blocks must not become a new snap surface and make a held brush climb or
## jump to another sub-slot.
var _paint_snap_blocks: Array[BlueprintBlock] = []
var _paint_anchor: int = BuildingBlockCatalog.ANCHOR_CENTER

# UI bindings
var _ghost: MeshInstance3D = null
var _layer_plane: MeshInstance3D = null
var _blocks_root: Node3D = null
var _ground: MeshInstance3D = null
var _camera_controller: CameraController = null
var _material_option: OptionButton = null
var _brush_line_btn: Button = null
var _brush_rect_btn: Button = null
var _palette_panel: EditorPalettePanel = null
var _palette_container: VBoxContainer = null
var _palette_content: VBoxContainer = null
var _tool_place_btn: Button = null
var _tool_erase_btn: Button = null
var _frame_toolbar: HBoxContainer = null
var _rot_x_btn: Button = null
var _rot_btn: Button = null
var _rot_z_btn: Button = null
var _layer_label: Label = null
var _footprint_x_spin: SpinBox = null
var _footprint_z_spin: SpinBox = null
var _variant_edit: LineEdit = null
## `construction_style` (surface / underground), not the visual style below.
var _style_option: OptionButton = null
var _role_edit: LineEdit = null
var _visual_style_edit: LineEdit = null
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
	_brush_line_btn = editor.get_node("%BrushLineBtn")
	_brush_rect_btn = editor.get_node("%BrushRectBtn")
	_palette_panel = editor.get_node("%PalettePanel")
	_palette_panel.set_title("Каркас")
	_palette_container = _palette_panel.entries_container()
	_build_palette_header()
	_tool_place_btn = editor.get_node("%ToolPlaceBtn")
	_tool_erase_btn = editor.get_node("%ToolEraseBtn")
	_frame_toolbar = editor.get_node("%FrameToolbar")
	_rot_x_btn = editor.get_node("%RotXBtn")
	_rot_btn = editor.get_node("%RotBtn")
	_rot_z_btn = editor.get_node("%RotZBtn")
	_layer_label = editor.get_node("%LayerLabel")
	_footprint_x_spin = editor.get_node("%FootprintXSpin")
	_footprint_z_spin = editor.get_node("%FootprintZSpin")
	_variant_edit = editor.get_node("%VariantEdit")
	_style_option = editor.get_node("%StyleOption")
	_role_edit = editor.get_node("%RoleEdit")
	_visual_style_edit = editor.get_node("%VisualStyleEdit")
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

	_footprint_x_spin.value_changed.connect(_on_footprint_changed)
	_footprint_z_spin.value_changed.connect(_on_footprint_changed)

	_style_option.clear()
	_style_option.add_item("Наземная")
	_style_option.set_item_metadata(0, &"surface")
	_style_option.tooltip_text = "Подземные здания пока не реализованы"
	_style_option.item_selected.connect(func(index: int):
		_editor.blueprint.construction_style = _style_option.get_item_metadata(index)
		_editor.mark_dirty()
	)

	# The alphabet is enforced as the author types rather than at save time
	# (content_packaging.md §3.3): a field that silently drops what you typed is
	# still better than a file named `untitled_building` discovered later.
	for field: LineEdit in [_editor._id_edit, _role_edit, _visual_style_edit, _variant_edit]:
		if field != null:
			field.text_changed.connect(_on_id_like_field_changed.bind(field))

	refresh_path_hint()

	_cost_mode_option.clear()
	_cost_mode_option.add_item("Ручная смета")
	_cost_mode_option.set_item_metadata(0, &"manual")
	_cost_mode_option.disabled = true

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
	end_paint_stroke()
	shift_erasing = false
	# The frame ghost is shared scene UI, not part of the palette.  It must not
	# survive a switch to fill/zones and look like a stray block in the world.
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
	if _editor.cursor_valid:
		var prev_anchor := _editor.current_anchor
		_update_current_subgrid_anchor()
		if _editor.cursor_cell != _ghost_cell or _editor.current_tool != _ghost_tool or _editor.current_rot != _ghost_rot or _editor.cursor_valid != _ghost_valid or _editor.current_anchor != prev_anchor:
			refresh_ghost()


var manual_subgrid_y: float = 0.0


func step_manual_subgrid_y(delta_y: float) -> void:
	manual_subgrid_y = clampf(manual_subgrid_y + delta_y, 0.0, 0.75)
	refresh_ghost()


func _update_current_subgrid_anchor() -> void:
	if not _editor.cursor_valid or _editor.current_block_id.is_empty():
		return

	# The editor cursor first intersects the active layer.  A frame block may
	# replace that target only when it is actually in front of that layer on the
	# same ray; otherwise a block below a deliberately selected upper layer would
	# steal the ghost.
	var hit_info := _placement_block_hit_info_under_mouse()
	var placement := _placement_target_from_hit(_editor.cursor_cell, hit_info)
	_editor.cursor_cell = placement["cell"]
	_editor.current_anchor = placement["anchor"]


## Resolves the snapped frame target from one cursor-plane cell and an optional
## nearer block hit.  Kept separate from camera input so the placement rule is
## directly covered by the scene regression tests.
func _placement_target_from_hit(cursor_plane_cell: Vector3i, hit_info: Dictionary) -> Dictionary:
	var target_cell := cursor_plane_cell
	var local_p3 := Vector3.ZERO

	if not hit_info.is_empty():
		var normal: Vector3 = hit_info["normal"]
		var hit_pos: Vector3 = hit_info["hit_pos"]
		var hit_block := hit_info["block"] as BlueprintBlock
		var hit_aabb := BuildingBlockCatalog.occupied_aabb(hit_block.pos, hit_block.block_id,
			hit_block.variant, hit_block.rot, hit_block.anchor, hit_block.rot_x, hit_block.rot_z)
		var probe := hit_pos + normal * 0.0001
		# At an exact edge, keep tangential coordinates on the face that was hit;
		# otherwise floor() can redirect a side snap into the cell above/beside it.
		var hit_center := hit_aabb.get_center()
		for axis in 3:
			if absf(normal[axis]) < 0.5:
				probe[axis] += signf(hit_center[axis] - hit_pos[axis]) * 0.0001
		target_cell = Vector3i(int(floor(probe.x)), maxi(0, int(floor(probe.y))), int(floor(probe.z)))

		# Put the candidate flush against whichever face the ray reached. The
		# remaining two axes follow the pointer, so the same rule covers tops and
		# all four sides of full blocks and sub-blocks.
		var size := BuildingBlockCatalog.size_of(_editor.current_block_id, _editor.current_variant)
		var basis := Basis.from_euler(_current_ghost_euler())
		var half := size * 0.5
		var extent := Vector3(
			absf(basis.x.x) * half.x + absf(basis.y.x) * half.y + absf(basis.z.x) * half.z,
			absf(basis.x.y) * half.x + absf(basis.y.y) * half.y + absf(basis.z.y) * half.z,
			absf(basis.x.z) * half.x + absf(basis.y.z) * half.y + absf(basis.z.z) * half.z)
		var desired_center := hit_pos
		for axis in 3:
			if absf(normal[axis]) > 0.5:
				desired_center[axis] += normal[axis] * extent[axis]
		var cell_center := Vector3(target_cell) + Vector3(0.5, 0.5, 0.5)
		var unrotated := basis.inverse() * (desired_center - cell_center
			- Vector3.UP * BuildingBlockCatalog.vertical_offset_of(_editor.current_block_id, _editor.current_variant))
		local_p3 = Vector3(unrotated.x, unrotated.y - size.y * 0.5 + 0.5, unrotated.z)
	else:
		var cell_center_x := float(target_cell.x) + 0.5
		var cell_center_z := float(target_cell.z) + 0.5
		var local_xz := Vector2(_editor.cursor_hit_pos.x - cell_center_x, _editor.cursor_hit_pos.z - cell_center_z)
		var rot_basis := Basis(Vector3.UP, deg_to_rad(-90.0 * float(_editor.current_rot)))
		var unrot_xz3 := rot_basis * Vector3(local_xz.x, 0.0, local_xz.y)
		local_p3 = Vector3(unrot_xz3.x, manual_subgrid_y, unrot_xz3.z)

	return {
		"cell": target_cell,
		"anchor": BuildingBlockCatalog.snap_subgrid_anchor_3d(_editor.current_block_id, _editor.current_variant, local_p3),
	}


func refresh_ghost() -> void:
	if not is_active():
		_ghost.visible = false
		return
	_update_current_subgrid_anchor()
	_ghost_cell = _editor.cursor_cell
	_ghost_tool = _editor.current_tool
	_ghost_rot = _editor.current_rot
	_ghost_valid = _editor.cursor_valid
	if not _editor.cursor_valid or _editor._eyedropper_active:
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


func begin_paint_stroke() -> void:
	_stroke_changed = false
	_paint_snap_blocks.clear()
	for block: BlueprintBlock in _editor.grid_model.all_blocks():
		_paint_snap_blocks.append(block)
	_update_current_subgrid_anchor()
	painting = true
	last_paint_cell = _editor.cursor_cell
	paint_anchor = _editor.cursor_cell
	_paint_anchor = _editor.current_anchor
	if _editor.current_brush == Brush.RECT:
		paint_rect(paint_anchor, _editor.cursor_cell, _paint_anchor)
	else:
		_apply_tool_at_cell(_editor.cursor_cell, _paint_anchor)
	refresh_ghost()


func continue_paint_stroke() -> void:
	if not painting or not _editor.cursor_valid:
		return
	_update_current_subgrid_anchor()
	_continue_paint_to_target(_editor.cursor_cell, _editor.current_anchor)


func _continue_paint_to_target(target_cell: Vector3i, target_anchor: int) -> void:
	if _editor.current_brush == Brush.RECT:
		paint_rect(paint_anchor, target_cell, _paint_anchor)
	elif target_cell.y == last_paint_cell.y and target_anchor == _paint_anchor:
		paint_line(last_paint_cell, target_cell, _paint_anchor)
	else:
		# A discontinuous surface/slot change is a new target, not a line through
		# unrelated cells. This is the guard against stray blocks during a drag.
		_apply_tool_at_cell(target_cell, target_anchor)
		refresh_ghost()
	last_paint_cell = target_cell
	_paint_anchor = target_anchor


func end_paint_stroke() -> void:
	painting = false
	_paint_snap_blocks.clear()
	if _stroke_changed:
		_update_count()
		_editor.mark_dirty()
		_stroke_changed = false


func _mark_frame_changed() -> void:
	if painting:
		_stroke_changed = true
		_editor.set_status_context("Блоков: %d" % _editor.grid_model.count())
		return
	_update_count()
	_editor.mark_dirty()


func _apply_tool_at_cell(cell: Vector3i, anchor_override: int = -1) -> void:
	var placement_anchor := _editor.current_anchor if anchor_override < 0 else anchor_override
	match _editor.current_tool:
		Tool.PLACE:
			if _editor.current_block_id.is_empty() and _stamp_brush.is_empty():
				return
			if not _stamp_brush.is_empty():
				_apply_stamp_at_cell(cell)
			elif is_block_in_bounds(cell, _editor.current_block_id, _editor.current_variant, _editor.current_rot) and _editor.grid_model.place(cell, _editor.current_block_id, _editor.current_rot, _editor.current_material_id, _editor.current_variant, placement_anchor, _editor.current_rot_x, _editor.current_rot_z):
				_spawn_or_update_block_node(_editor.grid_model.get_block_at(cell))
				_mark_frame_changed()
		Tool.ERASE:
			var target := _editor.grid_model.get_block_at(cell)
			if _editor.grid_model.erase(cell):
				if target != null:
					_remove_block_node(target)
				_mark_frame_changed()


func _apply_stamp_at_cell(cell: Vector3i) -> void:
	if _stamp_brush.is_empty():
		return
	var origin := _stamp_brush[0].pos
	for block in _stamp_brush:
		var target := cell + (block.pos - origin)
		if not is_block_in_bounds(target, block.block_id, block.variant, block.rot,
			block.anchor, block.rot_x, block.rot_z) or not _editor.grid_model.can_place(
			target, block.block_id, block.rot, block.material_id, block.variant,
			block.anchor, block.rot_x, block.rot_z):
			return
	for block in _stamp_brush:
		var target := cell + (block.pos - origin)
		if _editor.grid_model.place(target, block.block_id, block.rot, block.material_id, block.variant,
			block.anchor, block.rot_x, block.rot_z):
			_spawn_or_update_block_node(_editor.grid_model.get_block_at(target))
	_mark_frame_changed()


func erase_hovered_block_or_cell() -> void:
	if not _editor.cursor_valid:
		return
	var target := _block_under_mouse()
	if target != null and _editor.grid_model.erase_block(target):
		_editor._set_layer(target.pos.y)
		_remove_block_node(target)
		_mark_frame_changed()
		refresh_ghost()
		return
	_apply_erase_at_cell(_editor.cursor_cell)


func _apply_erase_at_cell(cell: Vector3i) -> void:
	var target := _editor.grid_model.get_block_at(cell)
	if target != null and _editor.grid_model.erase_block(target):
		_remove_block_node(target)
		_mark_frame_changed()


func erase_line(from_cell: Vector3i, to_cell: Vector3i) -> void:
	for cell in _bresenham_cells(from_cell, to_cell):
		_apply_erase_at_cell(cell)
	refresh_ghost()


func paint_line(from_cell: Vector3i, to_cell: Vector3i, anchor_override: int = -1) -> void:
	for cell in _bresenham_cells(from_cell, to_cell):
		_apply_tool_at_cell(cell, anchor_override)
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
		cells.append(Vector3i(x, from_cell.y, z))
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


func paint_rect(from_cell: Vector3i, to_cell: Vector3i, anchor_override: int = -1) -> void:
	var x0 := mini(from_cell.x, to_cell.x)
	var x1 := maxi(from_cell.x, to_cell.x)
	var z0 := mini(from_cell.z, to_cell.z)
	var z1 := maxi(from_cell.z, to_cell.z)
	var y := from_cell.y
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			_apply_tool_at_cell(Vector3i(x, y, z), anchor_override)
	refresh_ghost()


# ---------------------------------------------------------------------------
# Shift hover & block picking
# ---------------------------------------------------------------------------

func refresh_shift_hover() -> void:
	if _shift_hover_visual == null:
		return
	_shift_hover_block = null
	if not is_active() or (not Input.is_key_pressed(KEY_SHIFT) and not _editor._eyedropper_active) \
			or not _editor.cursor_valid:
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


func hide_cursor_feedback() -> void:
	if _ghost != null:
		_ghost.visible = false
	if _shift_hover_visual != null:
		_shift_hover_visual.visible = false


func _block_under_mouse() -> BlueprintBlock:
	var info := _block_hit_info_under_mouse()
	return info.get("block", null) as BlueprintBlock


func _block_hit_info_under_mouse() -> Dictionary:
	return _block_hit_info_on_ray(INF)


## Returns the closest block before `max_distance` on the current camera ray.
## The placement cursor uses the active-layer hit as that limit; Shift picking
## deliberately keeps the unbounded version above.
func _placement_block_hit_info_under_mouse() -> Dictionary:
	if _camera_controller == null or _camera_controller.camera == null:
		return {}
	var camera := _camera_controller.camera
	var mouse_pos := _editor.get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	return _placement_block_hit_info_on_ray(origin, direction, _editor.active_layer)


func _placement_block_hit_info_on_ray(origin: Vector3, direction: Vector3, active_layer: int) -> Dictionary:
	if absf(direction.y) < 0.000001:
		return {}
	var plane_distance := (float(active_layer) - origin.y) / direction.y
	if plane_distance < 0.0:
		return {}
	var candidates: Variant = _paint_snap_blocks if painting else null
	return _block_hit_info_on_ray(plane_distance + 0.0001, origin, direction, candidates)


func _block_hit_info_on_ray(max_distance: float, origin := Vector3.INF, direction := Vector3.ZERO, candidates: Variant = null) -> Dictionary:
	if _camera_controller == null or _camera_controller.camera == null:
		return {}
	if origin == Vector3.INF:
		var camera := _camera_controller.camera
		var mouse_pos := _editor.get_viewport().get_mouse_position()
		origin = camera.project_ray_origin(mouse_pos)
		direction = camera.project_ray_normal(mouse_pos)
	var closest_block: BlueprintBlock = null
	var closest_distance := max_distance
	var hit_normal := Vector3.UP
	var hit_pos := Vector3.ZERO
	var source_blocks: Array = _editor.grid_model.all_blocks() if candidates == null else candidates
	for block: BlueprintBlock in source_blocks:
		var aabb := BuildingBlockCatalog.occupied_aabb(block.pos, block.block_id,
			block.variant, block.rot, block.anchor, block.rot_x, block.rot_z)
		var hit_info := _ray_aabb_hit_info(origin, direction, aabb)
		if not hit_info.is_empty():
			var dist: float = hit_info["distance"]
			if dist >= 0.0 and dist < closest_distance - 0.000001:
				closest_block = block
				closest_distance = dist
				hit_normal = hit_info["normal"]
				hit_pos = hit_info["hit_pos"]
	if closest_block == null:
		return {}
	return {
		"block": closest_block,
		"distance": closest_distance,
		"normal": hit_normal,
		"hit_pos": hit_pos
	}


func _ray_aabb_hit_info(origin: Vector3, direction: Vector3, aabb: AABB) -> Dictionary:
	var t_min := -INF
	var t_max := INF
	var hit_normal := Vector3.UP
	for axis in 3:
		var start: float = origin[axis]
		var ray: float = direction[axis]
		var lower: float = aabb.position[axis]
		var upper: float = aabb.end[axis]
		if absf(ray) < 0.000001:
			if start < lower or start > upper:
				return {}
			continue
		var first := (lower - start) / ray
		var last := (upper - start) / ray
		var axis_normal_dir := -1.0
		if first > last:
			var swap := first
			first = last
			last = swap
			axis_normal_dir = 1.0
		if first > t_min:
			t_min = first
			var norm := Vector3.ZERO
			norm[axis] = axis_normal_dir
			hit_normal = norm
		t_max = minf(t_max, last)
		if t_min > t_max:
			return {}
	if t_min < 0.0:
		return {}
	var hit := origin + direction * t_min
	return {"hit_pos": hit, "normal": hit_normal, "distance": t_min}


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


func pick_single_block(retain_stamp: bool = false) -> bool:
	var block := _block_under_mouse()
	if block == null:
		_editor.set_status("Под Shift нет блока для выбора.")
		return false
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
	return true


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


## Re-assigns `material_override` on every spawned block node without touching
## geometry. Called when the texture toggle flips — the mesh cache stays valid,
## only the material cache was cleared in `BlockMeshLibrary.set_textures_enabled`.
func refresh_all_block_materials() -> void:
	for block in _editor.grid_model.all_blocks():
		var key := _editor.grid_model.placement_key_for(block)
		var node: MeshInstance3D = _block_nodes.get(key, null)
		if node != null:
			node.material_override = _editor.mesh_library.material_for(block.material_id)


# ---------------------------------------------------------------------------
# Bounds helpers
# ---------------------------------------------------------------------------

func is_block_in_bounds(
	cell: Vector3i,
	block_id: StringName,
	variant: StringName,
	rot: int,
	anchor: int = -1,
	rot_x: int = -1,
	rot_z: int = -1
) -> bool:
	if anchor < 0:
		anchor = _editor.current_anchor
	if rot_x < 0:
		rot_x = _editor.current_rot_x
	if rot_z < 0:
		rot_z = _editor.current_rot_z
	var occupied := BuildingBlockCatalog.occupied_aabb(cell, block_id, variant, rot,
		anchor, rot_x, rot_z)
	var bounds := AABB(Vector3.ZERO, Vector3(_editor.blueprint.grid_bounds))
	return occupied.position.x >= -0.0001 and occupied.position.y >= -0.0001 \
		and occupied.position.z >= -0.0001 and occupied.end.x <= bounds.end.x + 0.0001 \
		and occupied.end.y <= bounds.end.y + 0.0001 and occupied.end.z <= bounds.end.z + 0.0001


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


# ---------------------------------------------------------------------------
# Material
# ---------------------------------------------------------------------------

func rebuild_material_options() -> void:
	if _material_option == null:
		return
	_material_option.clear()
	var current_ok := false
	for material in BuildingMaterialCatalog.all():
		_material_option.add_item(material["name"])
		_material_option.set_item_metadata(_material_option.item_count - 1, material["id"])
		if material["id"] == _editor.current_material_id:
			current_ok = true
	if not current_ok:
		_editor.current_material_id = BuildingMaterialCatalog.DEFAULT_ID
	for i in _material_option.item_count:
		if _material_option.get_item_metadata(i) == _editor.current_material_id:
			_material_option.select(i)
			break
	refresh_ghost()


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
	for child in _palette_content.get_children():
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
		_palette_content.add_child(cat_label)
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
			_palette_content.add_child(btn)


func _build_palette_header() -> void:
	var material_label := Label.new()
	material_label.text = "Материал каркаса (по эре)"
	material_label.add_theme_font_size_override("font_size", 14)
	_palette_container.add_child(material_label)
	_material_option = OptionButton.new()
	_material_option.tooltip_text = "Материал новых блоков каркаса"
	_palette_container.add_child(_material_option)
	var separator := HSeparator.new()
	_palette_container.add_child(separator)
	var blocks_label := Label.new()
	blocks_label.text = "Блоки"
	blocks_label.add_theme_font_size_override("font_size", 14)
	_palette_container.add_child(blocks_label)
	_palette_content = VBoxContainer.new()
	_palette_content.add_theme_constant_override("separation", 4)
	_palette_container.add_child(_palette_content)


func _ensure_brush_inspector() -> Control:
	if _brush_inspector != null and is_instance_valid(_brush_inspector):
		return _brush_inspector
	_brush_inspector = VBoxContainer.new()
	_brush_inspector.name = "BrushInspector"
	_palette_content.add_child(_brush_inspector)
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
	_palette_content.move_child(_brush_inspector, target)


func _rebuild_brush_inspector() -> void:
	var host := _ensure_brush_inspector()
	host.visible = true
	for child in host.get_children():
		child.queue_free()
	_move_brush_inspector_under_selection()

	var variants: Array = BuildingBlockCatalog.variants(_editor.current_block_id)
	if variants.is_empty():
		return

	var toolbar := HBoxContainer.new()
	toolbar.name = "BrushToolbar"
	host.add_child(toolbar)

	var grouped_options: bool = not variants.is_empty() and variants[0].has("section")
	if grouped_options:
		_build_column_option_buttons(toolbar, variants, &"section", &"section_name")
	elif not variants.is_empty():
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

	if grouped_options:
		var seen_lengths: Dictionary = {}
		for v in variants:
			seen_lengths[v.get("length", &"")] = true
		if seen_lengths.size() > 1:
			var length_toolbar := HBoxContainer.new()
			length_toolbar.name = "LengthToolbar"
			host.add_child(length_toolbar)
			_build_column_option_buttons(length_toolbar, variants, &"length", &"length_name")


func _build_column_option_buttons(toolbar: HBoxContainer, variants: Array, option: StringName, label_key: StringName) -> void:
	var current := BuildingBlockCatalog.variant_option(_editor.current_block_id, _editor.current_variant, option)
	var seen: Dictionary = {}
	for variant in variants:
		var value: StringName = variant.get(option, &"")
		if seen.has(value):
			continue
		seen[value] = true
		var button := Button.new()
		button.toggle_mode = true
		button.text = variant.get(label_key, str(value))
		button.button_pressed = value == current
		button.pressed.connect(_select_column_option.bind(option, value))
		toolbar.add_child(button)


func _select_column_option(option: StringName, value: StringName) -> void:
	var section := BuildingBlockCatalog.variant_option(_editor.current_block_id, _editor.current_variant, &"section")
	var length := BuildingBlockCatalog.variant_option(_editor.current_block_id, _editor.current_variant, &"length")
	if option == &"section":
		section = value
	else:
		length = value
	var new_variant := BuildingBlockCatalog.variant_for_options(_editor.current_block_id, section, length)
	# variant_for_options returns default_variant when no match is found.
	# If the current section doesn't have the selected length, fall back to
	# the first variant that does.
	if option == &"length":
		var resolved_section := BuildingBlockCatalog.variant_option(_editor.current_block_id, new_variant, &"section")
		var resolved_length := BuildingBlockCatalog.variant_option(_editor.current_block_id, new_variant, &"length")
		if resolved_length != length or resolved_section != section:
			var fallback := BuildingBlockCatalog.variant_for_length(_editor.current_block_id, length)
			if fallback != &"":
				new_variant = fallback
	select_block(_editor.current_block_id, new_variant)


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
		_rot_x_btn.text = "🔄X %d°" % deg_x if deg_x != 0 else "🔄X"
		_rot_x_btn.tooltip_text = "Поворот вокруг оси X: %d°" % deg_x if deg_x != 0 else "Поворот вокруг оси X"
	if _rot_btn != null:
		var deg_y := _editor.current_rot * 90
		_rot_btn.text = "🔄Y %d°" % deg_y if deg_y != 0 else "🔄Y"
		_rot_btn.tooltip_text = "Поворот вокруг оси Y: %d° (C / R)" % deg_y if deg_y != 0 else "Поворот вокруг оси Y (C / R)"
	if _rot_z_btn != null:
		var deg_z := _editor.current_rot_z * 90
		_rot_z_btn.text = "🔄Z %d°" % deg_z if deg_z != 0 else "🔄Z"
		_rot_z_btn.tooltip_text = "Поворот вокруг оси Z: %d°" % deg_z if deg_z != 0 else "Поворот вокруг оси Z"


func _update_count() -> void:
	_editor.set_status_context("Блоков: %d" % _editor.grid_model.count())
	if _editor.blueprint != null:
		_editor.grid_model.write_to_blueprint(_editor.blueprint)
		_editor.blueprint.recalculate_construction_cost()
		_refresh_cost_ui()


func _refresh_cost_ui() -> void:
	if _cost_container == null:
		return

	_cost_block_summary_label.text = "Всего блоков: %d" % _editor.blueprint.block_count()

	_cost_mode_option.select(0)

	for child in _cost_breakdown_vbox.get_children():
		child.queue_free()

	var mat_counts := _editor.blueprint.block_counts_by_material()
	for mat_id in mat_counts.keys():
		var mat_def := BuildingMaterialCatalog.get_material(mat_id)
		var lbl := Label.new()
		lbl.text = "%s — %d блоков" % [mat_def.get("name", str(mat_id)), int(mat_counts[mat_id])]
		_cost_breakdown_vbox.add_child(lbl)

	for child in _extra_costs_vbox.get_children():
		child.queue_free()

	var manual_title := Label.new()
	manual_title.text = "Стоимость ресурсов задаётся вручную:"
	manual_title.add_theme_font_size_override("font_size", 13)
	_extra_costs_vbox.add_child(manual_title)
	var used_resources: Array[String] = []
	for res in _editor.blueprint.manual_costs.keys():
		used_resources.append(str(res))
	for res in used_resources:
		_extra_costs_vbox.add_child(_build_cost_row(
			_editor.blueprint.manual_costs, res, _editor.blueprint.manual_costs[res], used_resources))

	var costs_array: Array[String] = []
	for res in _editor.blueprint.construction_cost.keys():
		costs_array.append("%d %s" % [int(_editor.blueprint.construction_cost[res]), str(res)])
	if costs_array.is_empty():
		_total_cost_label.text = "Итоговая смета: Бесплатно"
	else:
		_total_cost_label.text = "Итоговая смета: %s" % ", ".join(costs_array)


func _on_cost_mode_selected(index: int) -> void:
	pass


func _on_add_extra_cost_pressed() -> void:
	var default_res := String(BuildingMaterialCatalog.resource_id(_editor.current_material_id))
	if default_res.is_empty() or not (default_res in ResourceIds.ALL):
		default_res = String(ResourceIds.ALL[0])
	var current_qty := int(_editor.blueprint.manual_costs.get(default_res, 0))
	_editor.blueprint.manual_costs[default_res] = current_qty + 1
	_editor.blueprint.recalculate_construction_cost()
	_editor.mark_dirty()
	_refresh_cost_ui()


func _build_cost_row(costs: Dictionary, key: String, value: int, used_resources: Array[String]) -> HBoxContainer:
	var row := HBoxContainer.new()
	var resource_option := OptionButton.new()
	for res_id in ResourceIds.ALL:
		var res_str := str(res_id)
		resource_option.add_item(res_str)
		var idx := resource_option.item_count - 1
		resource_option.set_item_metadata(idx, res_str)
		# Disable resources already used in other rows to prevent duplicate keys
		if res_str in used_resources and res_str != key:
			resource_option.set_item_disabled(idx, true)
	# Select the current resource
	for i in resource_option.item_count:
		if str(resource_option.get_item_metadata(i)) == key:
			resource_option.select(i)
			break
	resource_option.custom_minimum_size = Vector2(80, 0)
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 9999
	spin.value = value
	var del_btn := Button.new()
	del_btn.text = "X"

	var old_key := key
	resource_option.item_selected.connect(func(index: int):
		var val: int = costs.get(old_key, 1)
		costs.erase(old_key)
		var new_res := str(resource_option.get_item_metadata(index))
		costs[new_res] = val
		old_key = new_res
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
	row.add_child(resource_option)
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
	_editor.blueprint.grid_bounds.x = _editor.blueprint.footprint.x
	_editor.blueprint.grid_bounds.z = _editor.blueprint.footprint.y
	var removed := 0
	for block in _editor.grid_model.all_blocks():
		if not is_block_in_bounds(block.pos, block.block_id, block.variant, block.rot,
			block.anchor, block.rot_x, block.rot_z):
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

## Public wrapper so the editor can refresh the cost block when the settings
## modal opens — the cost nodes now live inside the metadata dialog.
func refresh_cost_ui() -> void:
	_refresh_cost_ui()


func sync_metadata_fields() -> void:
	_editor._syncing_metadata_fields = true
	if _editor._name_edit != null:
		_editor._name_edit.text = _editor.blueprint.name
	if _editor._id_edit != null:
		_editor._id_edit.text = String(_editor.blueprint.id)
	if _role_edit != null:
		_role_edit.text = String(_editor.blueprint.role)
	if _visual_style_edit != null:
		_visual_style_edit.text = String(_editor.blueprint.style)
	if _variant_edit != null:
		_variant_edit.text = String(_editor.blueprint.variant)
	refresh_path_hint()
	if _footprint_x_spin != null:
		_footprint_x_spin.value = _editor.blueprint.footprint.x
	if _footprint_z_spin != null:
		_footprint_z_spin.value = _editor.blueprint.footprint.y
	if _editor._entrance_label != null:
		var doors := _editor.blueprint.doors()
		if doors.is_empty():
			_editor._entrance_label.text = "Двери нет — вход берётся у ближней грани. Поставьте дверь в режиме зон."
		else:
			var offset := _editor.blueprint.entrance_offset()
			_editor._entrance_label.text = "Из двери «%s», смещение %d × %d от центра." % [
				doors[0].id, offset.x, offset.y]
	select_style_in_option(_editor.blueprint.construction_style)
	rebuild_material_options()
	_editor._syncing_metadata_fields = false
	_update_count()
	refresh_building_grid_visuals()
	focus_footprint_center()
	refresh_ghost()


# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

## Rewrites an id-like field to the allowed alphabet, keeping the caret where the
## author expects it. Assigning `text` resets the caret to 0, which would make the
## field type backwards.
func _on_id_like_field_changed(new_text: String, field: LineEdit) -> void:
	var cleaned := ContentId.sanitize_id(new_text)
	if cleaned == new_text:
		return
	var caret := field.caret_column - (new_text.length() - cleaned.length())
	field.text = cleaned
	field.caret_column = clampi(caret, 0, cleaned.length())
	_editor.mark_dirty()


## Where a save would land right now, and whether the document is attached to a
## file of its own. Silent write redirection is the failure this line exists to
## prevent (content_packaging.md §6.4).
func refresh_path_hint() -> void:
	if _path_hint_label == null:
		return
	if _editor.current_path.is_empty():
		_path_hint_label.text = "Новый файл → %s" % _editor.repository.base_dir()
	else:
		_path_hint_label.text = "Сохранение → %s" % _editor.current_path


## Pulls every inspector field into the blueprint. Split out of `on_save_pressed`
## because Save As needs the same values before it can propose an id, and two
## copies of this would drift the first time a field is added.
func collect_metadata_from_ui() -> void:
	_editor.blueprint.name = _editor._name_edit.text.strip_edges()
	if _editor.blueprint.name.is_empty():
		_editor.blueprint.name = "Новое здание"
	if _editor._id_edit != null:
		var raw_id := ContentId.normalize_id(_editor._id_edit.text)
		if not raw_id.is_empty():
			_editor.blueprint.id = StringName(raw_id)
	# `role` defaults to the id and only diverges when the author says so — that
	# divergence is the entire style mechanism (content_packaging.md §3.1).
	if _role_edit != null:
		var raw_role := ContentId.normalize_id(_role_edit.text)
		_editor.blueprint.role = StringName(raw_role) if not raw_role.is_empty() else _editor.blueprint.id
	if _visual_style_edit != null:
		var raw_style := ContentId.normalize_id(_visual_style_edit.text)
		_editor.blueprint.style = StringName(raw_style) if not raw_style.is_empty() else &"generic"
	if _variant_edit != null:
		var raw_variant := ContentId.normalize_id(_variant_edit.text)
		_editor.blueprint.variant = StringName(raw_variant) if not raw_variant.is_empty() else &"default"
	if _footprint_x_spin != null and _footprint_z_spin != null:
		_editor.blueprint.footprint = Vector2i(int(_footprint_x_spin.value), int(_footprint_z_spin.value))
		_editor.blueprint.grid_bounds.x = _editor.blueprint.footprint.x
		_editor.blueprint.grid_bounds.z = _editor.blueprint.footprint.y
	_editor.grid_model.write_to_blueprint(_editor.blueprint)


func on_save_pressed() -> void:
	collect_metadata_from_ui()
	# An empty `current_path` means "no file of our own yet": either a new blueprint
	# or one detached from a read-only source. Both save under the current id into
	# the mode's own folder.
	var result := _editor.repository.save(_editor.blueprint, _editor.current_path)
	if result["ok"]:
		_editor.current_path = result["path"]
		_editor._dirty = false
		_editor.reset_history()
		# Save As gives the blueprint a file for the first time, or a different one;
		# the places the author walks from follow it rather than staying beside a
		# file that is no longer the document.
		_editor.persist_test_points()
		_editor.set_status("Сохранено: %s (%d блоков, %d объектов)" % [
			result["path"], _editor.blueprint.block_count(), _editor.blueprint.objects.size()])
	else:
		_editor.set_status("Ошибка сохранения: %s" % result["error"])
	refresh_path_hint()
