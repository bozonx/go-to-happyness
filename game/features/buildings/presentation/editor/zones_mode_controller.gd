class_name ZonesModeController
extends Node

## Zones mode of the building editor — authoring of `areas[]` and `anchors[]`
## (design_docs/engine/active_zones.md §11).
##
## The panel follows the same order the model does: **tool, then role, then
## function**. The tool says what geometry is being drawn, the role says what the
## engine does with it, the function says what it means in a game — and the
## function list comes from content packs, not from here. That order is why the
## previous panel felt like "too many kinds of zones": it showed every field of
## every kind at once and hid them behind conditions.
##
## Lives as a child of BuildingEditor and owns everything zones-specific: the two
## panels, the tools, the 3D markers.

const TOOL_AREA := &"area"
const TOOL_POINT := &"point"
const TOOL_NONE := &"none"

## Colours and marker sizes are shared with the map editor's zones mode
## (`ZoneMarkerStyle`): the model is one for both editors, and a waypoint that
## looks different in each costs the author exactly what the shared model bought.
const AREA_COLORS := ZoneMarkerStyle.AREA_COLORS
const OVERLAY_COLOR := ZoneMarkerStyle.OVERLAY_COLOR
const SELECTION_COLOR := ZoneMarkerStyle.SELECTION_COLOR
const ANCHOR_STYLE := ZoneMarkerStyle.ANCHOR_STYLE

var _editor: Node = null
var _zones_visual_root: Node3D = null

# Top toolbar
var _toolbar: Control = null
var _tool_area_btn: Button = null
var _tool_point_btn: Button = null
var _role_option: OptionButton = null
var _role_hint: Label = null
var _append_area_check: CheckBox = null
var _advanced_check: CheckBox = null
var _creation_function_option: OptionButton = null
var _creation_pack_label: Label = null
var _creation_function_row: VBoxContainer = null
var _layer_label: Label = null
var _layer_down_btn: Button = null
var _layer_up_btn: Button = null
var _delete_selection_btn: Button = null
var _validate_btn: Button = null
var _show_rooms_check: CheckBox = null
var _show_overlays_check: CheckBox = null
var _show_anchors_check: CheckBox = null
var _show_routes_check: CheckBox = null
var _xray_check: CheckBox = null

# Right inspector
var _inspector_panel: PanelContainer = null
var _building_summary_label: Label = null
var _inspector_title: Label = null
var _inspector_body: VBoxContainer = null
var _id_edit: LineEdit = null
var _name_edit: LineEdit = null
var _inspector_role_option: OptionButton = null
var _function_row: VBoxContainer = null
var _inspector_function_option: OptionButton = null
var _inspector_pack_label: Label = null
var _props_container: VBoxContainer = null
var _equipment_title: Label = null
var _equipment_container: VBoxContainer = null
var _overlay_row: VBoxContainer = null
var _overlay_permissions_container: HFlowContainer = null
var _overlay_effects_container: VBoxContainer = null
var _anchor_props: VBoxContainer = null
var _req_checklist: VBoxContainer = null
var _req_empty_label: Label = null
var _zone_tree: Tree = null
var _issues_container: VBoxContainer = null

# Mode state
var _tool: StringName = TOOL_AREA
## Role armed for the next created zone; contextual to the tool.
var _area_role: StringName = ZoneAreaRecord.ROLE_ROOM
var _anchor_role: StringName = ZoneAnchorRecord.ROLE_SLOT
var _armed_area_function: StringName = &""
## Selection is either an area or an anchor; ids are unique per collection.
var _selected_area_id: StringName = &""
var _selected_anchor_id: StringName = &""
var _selected_route_id: StringName = &""
var _material_cache: Dictionary = {}
var _suppress_ui_events: bool = false

# Linking mode: after pressing «В маршрут» on a selected anchor, subsequent
# clicks on eligible anchors append them to the route being built.
var _linking: bool = false
var _link_route_id: StringName = &""

# Rectangle drag for the area tool.
var _dragging: bool = false
var _drag_start: Vector2i = Vector2i.ZERO
var _moving_anchor: bool = false
var _move_start_pos: Vector3 = Vector3.INF
var _erasing: bool = false
var _last_erased_cell: Vector3i = Vector3i(-999999, -999999, -999999)

# Ghost preview of the active tool under the cursor.
var _ghost: MeshInstance3D = null
var _ghost_material: StandardMaterial3D = null
# Drag rectangle preview for the area tool.
var _drag_preview: MeshInstance3D = null
var _drag_preview_material: StandardMaterial3D = null


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(editor: Node) -> void:
	_editor = editor
	name = "ZonesModeController"

	_toolbar = editor.get_node("%ZonesToolbar")
	_tool_area_btn = editor.get_node("%ToolAreaBtn")
	_tool_point_btn = editor.get_node("%ToolPointBtn")
	_role_option = editor.get_node("%ZoneRoleOption")
	_role_hint = editor.get_node("%ZoneRoleHint")
	_append_area_check = editor.get_node("%ZoneAppendAreaCheck")
	_advanced_check = editor.get_node("%ZoneAdvancedCheck")
	_creation_function_option = editor.get_node("%ZoneCreationFunctionOption")
	_creation_pack_label = editor.get_node("%ZoneCreationPackLabel")
	_creation_function_row = editor.get_node("%ZoneCreationFunctionRow")
	_layer_label = editor.get_node("%ZoneLayerLabel")
	_layer_down_btn = editor.get_node("%ZoneLayerDownBtn")
	_layer_up_btn = editor.get_node("%ZoneLayerUpBtn")
	_delete_selection_btn = editor.get_node("%ZoneDeleteSelectionBtn")
	_validate_btn = editor.get_node("%ZoneValidateBtn")
	_show_rooms_check = editor.get_node("%ZoneShowRoomsCheck")
	_show_overlays_check = editor.get_node("%ZoneShowOverlaysCheck")
	_show_anchors_check = editor.get_node("%ZoneShowAnchorsCheck")
	_show_routes_check = editor.get_node("%ZoneShowRoutesCheck")
	_xray_check = editor.get_node("%ZoneXrayCheck")

	_inspector_panel = editor.get_node("%ZonesInspectorPanel")
	_building_summary_label = editor.get_node("%ZoneBuildingSummaryLabel")
	_inspector_title = editor.get_node("%ZoneInspectorTitle")
	_inspector_body = editor.get_node("%ZoneInspectorBody")
	_id_edit = editor.get_node("%ZoneIdEdit")
	_name_edit = editor.get_node("%ZoneNameEdit")
	_inspector_role_option = editor.get_node("%ZoneInspectorRoleOption")
	_function_row = editor.get_node("%ZoneFunctionRow")
	_inspector_function_option = editor.get_node("%ZoneInspectorFunctionOption")
	_inspector_pack_label = editor.get_node("%ZoneInspectorPackLbl")
	_props_container = editor.get_node("%ZonePropsContainer")
	_equipment_title = editor.get_node("%ZoneEquipmentTitle")
	_equipment_container = editor.get_node("%ZoneEquipmentContainer")
	_overlay_row = editor.get_node("%ZoneOverlayRow")
	_overlay_permissions_container = editor.get_node("%ZoneOverlayPermissionsContainer")
	_overlay_effects_container = editor.get_node("%ZoneOverlayEffectsContainer")
	_anchor_props = editor.get_node("%ZoneAnchorProps")
	_req_checklist = editor.get_node("%ZoneReqChecklist")
	_req_empty_label = editor.get_node("%ZoneReqEmptyLabel")
	_zone_tree = editor.get_node("%ZoneTree")
	_issues_container = editor.get_node("%ZoneIssuesContainer")
	_zones_visual_root = editor.get_node("%ZonesVisual")
	# Existing entities are the primary navigation in an editor. Keep their tree at
	# the top of the right rail, with the selected entity's inspector below it.
	var inspector_rows := _zone_tree.get_parent()
	var zone_list_title := editor.get_node("EditorUI/Root/ZonesInspectorPanel/Scroll/InspectorVBox/ZoneListTitle")
	var issues_title := editor.get_node("EditorUI/Root/ZonesInspectorPanel/Scroll/InspectorVBox/ZoneIssuesTitle")
	inspector_rows.move_child(_building_summary_label, 0)
	inspector_rows.move_child(zone_list_title, 1)
	inspector_rows.move_child(_zone_tree, 2)
	inspector_rows.move_child(issues_title, 3)
	inspector_rows.move_child(_issues_container, 4)

	_tool_area_btn.pressed.connect(func() -> void: _arm_tool(TOOL_AREA))
	_tool_point_btn.pressed.connect(func() -> void: _arm_tool(TOOL_POINT))
	_role_option.item_selected.connect(_on_palette_role_selected)
	_advanced_check.toggled.connect(func(_pressed: bool) -> void: _rebuild_role_options())
	_creation_function_option.item_selected.connect(_on_creation_function_selected)
	_layer_down_btn.pressed.connect(func() -> void: _editor.set_layer(_editor.active_layer - 1))
	_layer_up_btn.pressed.connect(func() -> void: _editor.set_layer(_editor.active_layer + 1))
	_delete_selection_btn.pressed.connect(_delete_selection)
	_validate_btn.pressed.connect(_run_validation)
	for check in [_show_rooms_check, _show_overlays_check, _show_anchors_check, _show_routes_check]:
		check.toggled.connect(func(_pressed: bool) -> void: _refresh_visuals())
	_xray_check.toggled.connect(func(_pressed: bool) -> void: _apply_xray())

	_id_edit.text_submitted.connect(_on_id_submitted)
	_id_edit.focus_exited.connect(func() -> void: _on_id_submitted(_id_edit.text))
	_name_edit.text_submitted.connect(_on_name_changed)
	_name_edit.focus_exited.connect(func() -> void: _on_name_changed(_name_edit.text))
	_inspector_role_option.item_selected.connect(_on_inspector_role_selected)
	_inspector_function_option.item_selected.connect(_on_inspector_function_selected)
	_zone_tree.item_selected.connect(_on_tree_item_selected)

	_arm_tool(TOOL_AREA)


# ---------------------------------------------------------------------------
# Mode lifecycle
# ---------------------------------------------------------------------------

func activate() -> void:
	_toolbar.visible = true
	_inspector_panel.visible = true
	_apply_xray()
	_refresh_all()
	_editor.set_status("Режим зон.")


func deactivate() -> void:
	_toolbar.visible = false
	_inspector_panel.visible = false
	_dragging = false
	_erasing = false
	_linking = false
	_link_route_id = &""
	_hide_ghost()
	_hide_drag_preview()
	_clear_visuals()
	_clear_selection()
	_set_frame_transparency(0.0)


func is_active() -> bool:
	return _toolbar != null and _toolbar.visible


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

## Returns true when the mouse button was consumed by zones mode.
func handle_mouse_button(event: InputEventMouseButton) -> bool:
	if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed and _erasing:
		_erasing = false
		return true
	if event.button_index == MOUSE_BUTTON_RIGHT and event.shift_pressed:
		if event.pressed:
			if _editor.is_pointer_over_ui():
				return false
			_erasing = true
			_last_erased_cell = Vector3i(-999999, -999999, -999999)
			_erase_once_at_cursor()
		else:
			_erasing = false
		return true
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if _linking and event.pressed:
			_stop_linking()
			return true
		return false
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if event.pressed:
		if _editor.is_pointer_over_ui():
			return false
		if _linking:
			_link_click_at_cursor()
			return true
		match _tool:
			TOOL_AREA:
				# Hybrid: over an existing area → select it (not anchors);
				# over empty space → start drawing a rectangle.
				var area := _area_at_cursor()
				if area != null:
					_selected_area_id = area.id
					_selected_anchor_id = &""
					_selected_route_id = &""
					_refresh_all()
				else:
					if not _cursor_in_bounds():
						return false
					_dragging = true
					_drag_start = _cursor_cell_2d()
			TOOL_POINT:
				# Hybrid: over an existing anchor → select it (not areas);
				# over empty space → place a new anchor.
				var anchor := _anchor_at_cursor()
				if anchor != null:
					_selected_anchor_id = anchor.id
					_selected_area_id = &""
					_selected_route_id = &""
					_refresh_all()
					_moving_anchor = true
					_move_start_pos = anchor.pos
				else:
					_place_anchor_at_cursor()
			TOOL_NONE:
				# Idle mode: select whatever is under the cursor.
				_select_at_cursor()
				_moving_anchor = _selected_anchor() != null
				if _moving_anchor:
					_move_start_pos = _selected_anchor().pos
		return true
	if _dragging:
		_dragging = false
		_hide_drag_preview()
		_commit_area_rect(_drag_start, _cursor_cell_2d())
	elif _moving_anchor:
		_moving_anchor = false
		_move_selected_anchor_to_cursor()
		_move_start_pos = Vector3.INF
	return true


func on_mouse_motion(_event: InputEventMouseMotion) -> void:
	if _dragging or _moving_anchor or _erasing:
		_editor.update_cursor()
	if _erasing:
		_erase_once_at_cursor()
	_refresh_cursor_status()


## Returns true when the key was consumed by zones mode.
func handle_key(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	match event.keycode:
		KEY_P:
			pick_at_cursor()
		KEY_Q:
			_arm_tool(TOOL_AREA)
		KEY_W:
			_arm_tool(TOOL_POINT)
		KEY_TAB:
			_cycle_role()
		KEY_F:
			_rotate_selected_anchor()
		KEY_ESCAPE:
			if _linking:
				_stop_linking()
				return true
			# First Esc clears the selection; second Esc disarms the tool
			# into the idle mode where the cursor selects without creating.
			if _selected_area() != null or _selected_anchor() != null or _selected_route() != null:
				_clear_selection()
				_refresh_all()
				return true
			if _tool != TOOL_NONE:
				_arm_tool(TOOL_NONE)
				return true
			return false
		KEY_DELETE:
			_delete_selection()
		_:
			return false
	return true


func is_painting() -> bool:
	return _dragging or _moving_anchor or _erasing


func process(_delta: float) -> void:
	pass


func refresh_ghost() -> void:
	if not is_active() or not _editor.cursor_valid:
		_hide_ghost()
		return
	if _editor.is_pointer_over_ui():
		_hide_ghost()
		return
	if _linking:
		_ensure_ghost()
		_ghost.mesh = SphereMesh.new()
		(_ghost.mesh as SphereMesh).radius = 0.25
		(_ghost.mesh as SphereMesh).height = 0.5
		_ghost.position = Vector3(_editor.cursor_cell) + Vector3(0.5, 0.25, 0.5)
		_ghost.rotation = Vector3.ZERO
		_ghost.visible = true
		return
	if _tool == TOOL_NONE:
		_hide_ghost()
		return
	if _dragging:
		_hide_ghost()
		_update_drag_preview()
		return
	# Hybrid tools hide the creation ghost when the cursor is over something
	# the click would select instead of create.
	if _tool == TOOL_AREA and _area_at_cursor() != null:
		_hide_ghost()
		return
	if _tool == TOOL_POINT and _anchor_at_cursor() != null:
		_hide_ghost()
		return
	_ensure_ghost()
	var cell: Vector3i = _editor.cursor_cell
	var pos := Vector3(cell.x + 0.5, float(cell.y), cell.z + 0.5)
	match _tool:
		TOOL_AREA:
			if not _cursor_in_bounds():
				_hide_ghost()
				return
			_ghost.mesh = BoxMesh.new()
			(_ghost.mesh as BoxMesh).size = Vector3(0.94, 0.04, 0.94)
			_ghost.position = pos + Vector3(0.0, 0.02, 0.0)
			_ghost.rotation = Vector3.ZERO
		TOOL_POINT:
			if not _anchor_cursor_in_bounds(_anchor_role):
				_hide_ghost()
				return
			var style: Dictionary = ANCHOR_STYLE.get(_anchor_role, ANCHOR_STYLE[&"poi"])
			_ghost.mesh = BoxMesh.new()
			(_ghost.mesh as BoxMesh).size = style["size"]
			_ghost.position = pos + Vector3(0.0, style["size"].y * 0.5, 0.0)
			_ghost.rotation = Vector3.ZERO
	_ghost.visible = true


func _hide_ghost() -> void:
	if _ghost != null:
		_ghost.visible = false


func hide_cursor_feedback() -> void:
	_hide_ghost()
	_hide_drag_preview()


func _hide_drag_preview() -> void:
	if _drag_preview != null:
		_drag_preview.visible = false


func _ensure_drag_preview() -> void:
	if _drag_preview == null:
		_drag_preview = MeshInstance3D.new()
		_drag_preview.material_override = _get_drag_preview_material()
		_zones_visual_root.add_child(_drag_preview)


func _get_drag_preview_material() -> StandardMaterial3D:
	if _drag_preview_material == null:
		_drag_preview_material = StandardMaterial3D.new()
		_drag_preview_material.albedo_color = Color(0.3, 0.9, 0.4, 0.35)
		_drag_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_drag_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _drag_preview_material


func _update_drag_preview() -> void:
	if not _dragging:
		return
	if not _editor.cursor_valid:
		_hide_drag_preview()
		return
	_ensure_drag_preview()
	var from_cell := _drag_start
	var to_cell := _cursor_cell_2d()
	# Clamp to building footprint so the preview stays inside the bounds.
	var fp: Vector2i = _editor.blueprint.footprint
	# One helper for the preview and for the commit, so what the author sees under
	# the cursor is exactly the rectangle that lands in the document.
	var rect := ZoneAuthoring.rect_from_drag(
		from_cell, to_cell, Vector2i.ZERO, fp - Vector2i.ONE)
	var w := float(rect.size.x)
	var d := float(rect.size.y)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, 0.06, d)
	_drag_preview.mesh = mesh
	_drag_preview.position = Vector3(
		float(rect.position.x) + w * 0.5,
		float(_editor.active_layer) + 0.03,
		float(rect.position.y) + d * 0.5)
	_drag_preview.rotation = Vector3.ZERO
	_drag_preview.visible = true


func _ensure_ghost() -> void:
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.material_override = _get_ghost_material()
		_zones_visual_root.add_child(_ghost)


func _get_ghost_material() -> StandardMaterial3D:
	if _ghost_material == null:
		_ghost_material = StandardMaterial3D.new()
		_ghost_material.albedo_color = Color(0.45, 0.85, 1.0, 0.4)
		_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _ghost_material


func on_layer_changed() -> void:
	if _layer_label != null and _editor != null:
		_layer_label.text = "Слой Y: %d" % _editor.active_layer
	_refresh_visuals()


# ---------------------------------------------------------------------------
# Blueprint lifecycle — called by the editor after load/new.
# ---------------------------------------------------------------------------

func on_blueprint_loaded() -> void:
	_clear_selection()
	if is_active():
		_refresh_all()


func on_blueprint_changed() -> void:
	_clear_selection()
	if is_active():
		_refresh_all()
	else:
		_clear_visuals()


func on_blueprint_created() -> void:
	on_blueprint_loaded()


# ---------------------------------------------------------------------------
# Tool and role arming
# ---------------------------------------------------------------------------

func _arm_tool(tool_id: StringName) -> void:
	_tool = tool_id
	_tool_area_btn.button_pressed = tool_id == TOOL_AREA
	_tool_point_btn.button_pressed = tool_id == TOOL_POINT
	if _linking:
		_stop_linking()
	_rebuild_role_options()


## The role list is contextual: an area tool offers area roles, a point tool
## offers point roles. One dropdown, never both vocabularies at once.
func _rebuild_role_options() -> void:
	_suppress_ui_events = true
	_role_option.clear()
	_role_option.disabled = _tool == TOOL_NONE
	if _tool == TOOL_AREA:
		# `region` belongs to maps; a building authors rooms and overlays.
		for role in [ZoneAreaRecord.ROLE_ROOM, ZoneAreaRecord.ROLE_OVERLAY]:
			_role_option.add_item(ZoneAreaRecord.role_display_name(role))
			_role_option.set_item_metadata(_role_option.item_count - 1, role)
			if role == _area_role:
				_role_option.select(_role_option.item_count - 1)
	elif _tool == TOOL_POINT:
		var basic_roles: Array[StringName] = [
			ZoneAnchorRecord.ROLE_DOOR, ZoneAnchorRecord.ROLE_SLOT,
			ZoneAnchorRecord.ROLE_QUEUE, ZoneAnchorRecord.ROLE_STORAGE]
		var roles: Array[StringName] = ZoneAnchorRecord.BUILDING_ROLES if \
			_advanced_check.button_pressed else basic_roles
		if _anchor_role not in roles:
			_anchor_role = ZoneAnchorRecord.ROLE_SLOT
		for role in roles:
			_role_option.add_item(ZoneAnchorRecord.role_display_name(role))
			_role_option.set_item_metadata(_role_option.item_count - 1, role)
			if role == _anchor_role:
				_role_option.select(_role_option.item_count - 1)
	_suppress_ui_events = false
	_update_role_hint()
	_rebuild_creation_functions()


func _on_palette_role_selected(index: int) -> void:
	if _suppress_ui_events:
		return
	var role: StringName = _role_option.get_item_metadata(index)
	if _tool == TOOL_AREA:
		_area_role = role
	else:
		_anchor_role = role
	_update_role_hint()
	_rebuild_creation_functions()


func _update_role_hint() -> void:
	if _role_hint == null:
		return
	if _tool == TOOL_AREA:
		_role_hint.text = ZoneAreaRecord.role_hint(_area_role)
	elif _tool == TOOL_POINT:
		_role_hint.text = ZoneAnchorRecord.role_hint(_anchor_role)
	else:
		_role_hint.text = "Инструмент отключён: щелчок только выделяет."
	_append_area_check.visible = _tool == TOOL_AREA
	_advanced_check.visible = _tool == TOOL_POINT


func _rebuild_creation_functions() -> void:
	var visible := _tool == TOOL_AREA and _area_role != ZoneAreaRecord.ROLE_OVERLAY
	_creation_function_row.visible = visible
	if not visible:
		return
	var entries := ZoneFunctionCatalog.for_area_role(_area_role)
	if not ZoneFunctionCatalog.supports_area_role(_armed_area_function, _area_role):
		_armed_area_function = &""
	_fill_function_option(_creation_function_option, entries, _armed_area_function)
	_update_pack_label(_creation_pack_label, _armed_area_function, entries.is_empty())


func _on_creation_function_selected(index: int) -> void:
	if _suppress_ui_events:
		return
	_armed_area_function = _creation_function_option.get_item_metadata(index)
	_update_pack_label(_creation_pack_label, _armed_area_function,
		_creation_function_option.item_count <= 1)


func _cycle_role() -> void:
	if _role_option.item_count == 0:
		return
	var next := (_role_option.selected + 1) % _role_option.item_count
	_role_option.select(next)
	_on_palette_role_selected(next)


## Naming the pack is deliberate: the author must see that "Пекарня" is content,
## not engine, because that is what makes their own pack thinkable.
func _update_pack_label(label: Label, function_id: StringName, no_functions: bool) -> void:
	if label == null:
		return
	if no_functions:
		label.text = "Ни один пак не даёт функций для этой роли."
		return
	if function_id == &"":
		label.text = "Смысл зоны приходит из пака контента."
		return
	label.text = "Из пака «%s»" % ZoneFunctionCatalog.pack_of(function_id)


# ---------------------------------------------------------------------------
# Editing
# ---------------------------------------------------------------------------

func _cursor_cell_2d() -> Vector2i:
	return Vector2i(_editor.cursor_cell.x, _editor.cursor_cell.z)


func _cursor_in_bounds() -> bool:
	if not _editor.cursor_valid:
		return false
	var fp: Vector2i = _editor.blueprint.footprint
	var cell := _cursor_cell_2d()
	return cell.x >= 0 and cell.y >= 0 and cell.x < fp.x and cell.y < fp.y


func _commit_area_rect(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if not _editor.cursor_valid:
		return
	var fp: Vector2i = _editor.blueprint.footprint
	# One helper for the preview and for the commit, so what the author sees under
	# the cursor is exactly the rectangle that lands in the document.
	var rect := ZoneAuthoring.rect_from_drag(
		from_cell, to_cell, Vector2i.ZERO, fp - Vector2i.ONE)
	var area := _selected_area() if _append_area_check.button_pressed else null
	if area == null or area.role != _area_role:
		area = _create_area()
	area.add_rect(rect)
	area.y_min = mini(area.y_min, _editor.active_layer)
	area.y_max = maxi(area.y_max, _editor.active_layer)
	_selected_area_id = area.id
	_selected_anchor_id = &""
	_selected_route_id = &""
	_editor.mark_dirty()
	_refresh_all()


func _create_area() -> ZoneAreaRecord:
	var area := ZoneAreaRecord.new()
	area.role = _area_role
	area.id = _unique_id("area", func(candidate: StringName) -> bool:
		return _editor.blueprint.zone_id_taken(candidate))
	var template := "Комната %d" if _area_role == ZoneAreaRecord.ROLE_ROOM else "Оверлей %d"
	area.area_name = template % (_editor.blueprint.areas.size() + 1)
	area.y_min = _editor.active_layer
	area.y_max = _editor.active_layer
	if area.role != ZoneAreaRecord.ROLE_OVERLAY:
		area.function = _armed_area_function
		area.properties = ZoneFunctionCatalog.default_properties(_armed_area_function)
	if _area_role == ZoneAreaRecord.ROLE_OVERLAY:
		# An overlay that forbids nobody is a no-op; start from the case the
		# author almost always wants and let them widen it.
		area.deny = [ZoneAccess.AUDIENCE_VISITOR]
	_editor.blueprint.areas.append(area)
	return area


func _place_anchor_at_cursor() -> void:
	if not _editor.cursor_valid:
		return
	if not _anchor_cursor_in_bounds(_anchor_role):
		_editor.set_status("Эту точку нельзя поставить за границами здания. Дверь допускается на его кромке.")
		return
	var anchor := ZoneAnchorRecord.new()
	anchor.id = _unique_id(String(_anchor_role), func(candidate: StringName) -> bool:
		return _editor.blueprint.zone_id_taken(candidate))
	anchor.role = _anchor_role
	anchor.pos = Vector3(_editor.cursor_cell) + Vector3(0.5, 0.0, 0.5)
	anchor.pos.y = float(_editor.active_layer)
	# Ownership is explicit, but the obvious owner is filled in for the author:
	# the room under the point. Doors stay building-wide unless retargeted.
	if not anchor.is_door():
		for area in _editor.blueprint.rooms():
			if area.contains_cell_3d(Vector3i(
					_cursor_cell_2d().x, _editor.active_layer, _cursor_cell_2d().y)):
				anchor.owner_id = area.id
				break
	if anchor.is_slot():
		anchor.capacity = 50
	if anchor.is_queue():
		var target := _nearest_slot(anchor.pos, anchor.owner_id)
		if target == null:
			_editor.set_status("Сначала поставьте место на этом этаже и в этой комнате.")
			return
		anchor.target_id = target.id
		anchor.index = _next_queue_index(target.id)
	_editor.blueprint.anchors.append(anchor)
	_selected_anchor_id = anchor.id
	_selected_area_id = &""
	_selected_route_id = &""
	_editor.mark_dirty()
	_refresh_all()


## Begins linking mode from the selected anchor: subsequent clicks on
## door/slot/waypoint anchors in 3D append them to the route being built.
## Esc or right-click finishes.
func _start_linking() -> void:
	var anchor := _selected_anchor()
	if anchor == null:
		return
	if not _anchor_can_route(anchor):
		_editor.set_status("Эту точку нельзя добавить в маршрут.")
		return
	var route: ZoneRouteRecord = null
	if _link_route_id != &"":
		route = _editor.blueprint.route_by_id(_link_route_id)
	if route == null:
		route = ZoneRouteRecord.new()
		route.id = _unique_id("route", func(candidate: StringName) -> bool:
			return _editor.blueprint.route_by_id(candidate) != null)
		_editor.blueprint.routes.append(route)
		_selected_route_id = route.id
		_selected_area_id = &""
		_selected_anchor_id = &""
	if route.stops.is_empty() or route.stops[-1] != anchor.id:
		route.stops.append(anchor.id)
	_link_route_id = route.id
	_linking = true
	_editor.set_status("Редактируется маршрут «%s»." % route.id)
	_editor.mark_dirty()
	_refresh_all()


func _stop_linking() -> void:
	_linking = false
	var route_id := _link_route_id
	_link_route_id = &""
	if route_id != &"":
		_selected_route_id = route_id
		var route := _selected_route()
		if route != null and route.stops.size() < 2:
			_editor.blueprint.routes.erase(route)
			_clear_selection()
			_editor.set_status("Маршрут отменён: нужно минимум две точки.")
		else:
			_editor.set_status("Маршрут «%s» готов: %d точек." % [route_id,
				route.stops.size() if route != null else 0])
	_editor.mark_dirty()
	_refresh_all()


func _link_click_at_cursor() -> void:
	if not _editor.cursor_valid:
		return
	var stop: ZoneAnchorRecord = null
	for anchor in _editor.blueprint.anchors:
		if anchor.cell() == _cursor_cell_2d() and _anchor_can_route(anchor):
			stop = anchor
			break
	if stop == null:
		_editor.set_status("Кликайте по двери, слоту или путевой точке.")
		return
	var route: ZoneRouteRecord = _editor.blueprint.route_by_id(_link_route_id)
	if route == null:
		_stop_linking()
		return
	if route.stops.is_empty() or route.stops[-1] != stop.id:
		route.stops.append(stop.id)
		_editor.mark_dirty()
		_refresh_all()


static func _anchor_can_route(anchor: ZoneAnchorRecord) -> bool:
	return anchor.role in [ZoneAnchorRecord.ROLE_DOOR, ZoneAnchorRecord.ROLE_SLOT,
		ZoneAnchorRecord.ROLE_WAYPOINT]


func _nearest_slot(pos: Vector3, owner_id: StringName = &"") -> ZoneAnchorRecord:
	var best: ZoneAnchorRecord = null
	var best_distance := INF
	for anchor in _editor.blueprint.anchors:
		if not anchor.is_slot():
			continue
		if owner_id != &"" and anchor.owner_id != owner_id:
			continue
		if not is_equal_approx(anchor.pos.y, pos.y):
			continue
		var distance: float = anchor.pos.distance_to(pos)
		if distance < best_distance:
			best_distance = distance
			best = anchor
	return best


func _anchor_cursor_in_bounds(role: StringName) -> bool:
	if not _editor.cursor_valid or _editor.active_layer < 0 \
			or _editor.active_layer >= _editor.blueprint.grid_bounds.y:
		return false
	var cell := _cursor_cell_2d()
	var fp: Vector2i = _editor.blueprint.footprint
	if role != ZoneAnchorRecord.ROLE_DOOR:
		return cell.x >= 0 and cell.y >= 0 and cell.x < fp.x and cell.y < fp.y
	var within_x := cell.x >= 0 and cell.x < fp.x
	var within_z := cell.y >= 0 and cell.y < fp.y
	return (within_x and cell.y >= -1 and cell.y <= fp.y) \
		or (within_z and cell.x >= -1 and cell.x <= fp.x)


func _next_queue_index(target_id: StringName) -> int:
	return ZoneAuthoring.next_queue_index(_editor.blueprint.anchors, target_id)


func _erase_once_at_cursor() -> void:
	if not _editor.cursor_valid or _editor.cursor_cell == _last_erased_cell:
		return
	_last_erased_cell = _editor.cursor_cell
	_erase_at_cursor()


func _erase_at_cursor() -> void:
	if not _editor.cursor_valid:
		return
	if _tool == TOOL_POINT:
		_erase_anchor_at_cursor()
		return
	if _tool == TOOL_NONE and _selected_anchor() != null:
		_erase_anchor_at_cursor()
		return
	_erase_area_at_cursor()


func _erase_anchor_at_cursor() -> void:
	var anchor := _anchor_at_cursor()
	if anchor != null:
		_remove_anchor(anchor)


func _erase_area_at_cursor() -> void:
	var cell := _cursor_cell_2d()
	var area := _selected_area()
	if area == null or not area.contains_cell_3d(Vector3i(cell.x, _editor.active_layer, cell.y)):
		area = null
		for candidate in _editor.blueprint.areas:
			if candidate.role == _area_role and candidate.contains_cell_3d(
					Vector3i(cell.x, _editor.active_layer, cell.y)):
				area = candidate
				break
	if area == null:
		for candidate in _editor.blueprint.areas:
			if candidate.contains_cell_3d(Vector3i(cell.x, _editor.active_layer, cell.y)):
				area = candidate
				break
	if area == null:
		return
	# Area erasing removes exactly one cell; ZoneAreaRecord preserves the rest by
	# splitting its rectangles deterministically.
	if area.cell_count() == 1 and _area_has_owned_content(area.id):
		_editor.set_status("Последнюю клетку занятой комнаты удаляйте кнопкой — будет показан состав изменений.")
		return
	if area.remove_cell(cell):
		if area.is_empty():
			_remove_area(area)
		else:
			_editor.mark_dirty()
			_refresh_all()


func _area_at_cursor() -> ZoneAreaRecord:
	if not _editor.cursor_valid:
		return null
	var cell := _cursor_cell_2d()
	var candidates: Array[ZoneAreaRecord] = []
	for area in _editor.blueprint.areas:
		if area.contains_cell_3d(Vector3i(cell.x, _editor.active_layer, cell.y)):
			candidates.append(area)
	if candidates.is_empty():
		return null
	# Prefer the role armed by the current tool, then cycle repeated clicks through
	# overlapping areas instead of making the later one unreachable.
	candidates.sort_custom(func(left: ZoneAreaRecord, right: ZoneAreaRecord) -> bool:
		return (left.role == _area_role) and right.role != _area_role)
	for index in candidates.size():
		if candidates[index].id == _selected_area_id:
			return candidates[(index + 1) % candidates.size()]
	return candidates[0]


func _anchor_at_cursor() -> ZoneAnchorRecord:
	if not _editor.cursor_valid:
		return null
	var cell := _cursor_cell_2d()
	var candidates: Array[ZoneAnchorRecord] = []
	for anchor in _editor.blueprint.anchors:
		if anchor.cell() == cell and int(floor(anchor.pos.y)) == _editor.active_layer:
			candidates.append(anchor)
	if candidates.is_empty():
		return null
	for index in candidates.size():
		if candidates[index].id == _selected_anchor_id:
			return candidates[(index + 1) % candidates.size()]
	return candidates[0]


## Eyedropper: sample the anchor point or zone area at cursor and arm its tool and role/function.
func pick_at_cursor() -> bool:
	if not _editor.cursor_valid:
		_editor.set_status("Курсор вне сетки.")
		return false
	var anchor := _anchor_at_cursor()
	if anchor != null:
		_arm_tool(TOOL_POINT)
		_anchor_role = anchor.role
		var basic_roles: Array[StringName] = [
			ZoneAnchorRecord.ROLE_DOOR, ZoneAnchorRecord.ROLE_SLOT,
			ZoneAnchorRecord.ROLE_QUEUE, ZoneAnchorRecord.ROLE_STORAGE]
		if _anchor_role not in basic_roles and _anchor_role in ZoneAnchorRecord.BUILDING_ROLES:
			_advanced_check.button_pressed = true
		_rebuild_role_options()
		_editor.set_status("Пипетка: выбран точечный якорь роли «%s»." % ZoneAnchorRecord.role_display_name(anchor.role))
		_refresh_all()
		return true
	var area := _area_at_cursor()
	if area != null:
		_arm_tool(TOOL_AREA)
		_area_role = area.role
		_armed_area_function = area.function
		_rebuild_role_options()
		_editor.set_status("Пипетка: выбрана область роли «%s»." % ZoneAreaRecord.role_display_name(area.role))
		_refresh_all()
		return true
	_editor.set_status("Под курсором нет зоны или точки для пипетки.")
	return false


func _select_at_cursor() -> void:

	if not _editor.cursor_valid:
		return
	var anchor := _anchor_at_cursor()
	if anchor != null:
		_selected_anchor_id = anchor.id
		_selected_area_id = &""
		_selected_route_id = &""
		_refresh_all()
		return
	var area := _area_at_cursor()
	if area != null:
		_selected_area_id = area.id
		_selected_anchor_id = &""
		_selected_route_id = &""
		_refresh_all()
		return
	_clear_selection()
	_refresh_all()


func _rotate_selected_anchor() -> void:
	var anchor := _selected_anchor()
	if anchor == null:
		return
	anchor.facing = fmod(anchor.facing + 45.0, 360.0)
	_editor.mark_dirty()
	_refresh_all()


func _move_selected_anchor_to_cursor() -> void:
	var anchor := _selected_anchor()
	if anchor == null or not _editor.cursor_valid:
		return
	if not _anchor_cursor_in_bounds(anchor.role):
		_editor.set_status("Точка оставлена на месте: новая позиция вне допустимых границ.")
		return
	var next_pos := Vector3(_editor.cursor_cell) + Vector3(0.5, 0.0, 0.5)
	next_pos.y = float(_editor.active_layer)
	if next_pos.is_equal_approx(anchor.pos):
		return
	anchor.pos = next_pos
	_editor.mark_dirty()
	_refresh_all()


func _delete_selection() -> void:
	var anchor := _selected_anchor()
	if anchor != null:
		_remove_anchor(anchor)
		return
	var area := _selected_area()
	if area != null:
		var anchors_count: int = _editor.blueprint.anchors_of(area.id).size()
		var fixtures_count := 0
		var objects_count := 0
		for fixture in _editor.blueprint.fixtures:
			if fixture.owner_zone_id == area.id:
				fixtures_count += 1
		for fill_object in _editor.blueprint.objects:
			if fill_object.owner_zone_id == area.id:
				objects_count += 1
		if anchors_count + fixtures_count + objects_count > 0:
			var confirmed: bool = await _editor.confirm_action(
				"Будет удалена область «%s» и %d принадлежащих ей точек. " % [
					area.display_name(), anchors_count]
				+ "%d fixtures и %d предметов станут общими для здания." % [fixtures_count, objects_count],
				"Удалить область?")
			if not confirmed:
				return
		_inspector_role_option.disabled = false
		_remove_area(area)
		return
	var route := _selected_route()
	if route != null:
		_editor.blueprint.routes.erase(route)
		_clear_selection()
		_editor.mark_dirty()
		_refresh_all()


## Deleting an area cascades to everything it owns — orphaned anchors and
## fixtures are the invariant this rule exists to protect (active_zones.md §7.7).
func _remove_area(area: ZoneAreaRecord) -> void:
	# Anchors, queues and route stops are the shared half of the cascade; fixtures
	# and fill objects are the building's own and stay here.
	for fixture in _editor.blueprint.fixtures:
		if fixture.owner_zone_id == area.id:
			fixture.owner_zone_id = &""
	for fill_object in _editor.blueprint.objects:
		if fill_object.owner_zone_id == area.id:
			fill_object.owner_zone_id = &""
	ZoneAuthoring.remove_area_cascade(
		_editor.blueprint.areas, _editor.blueprint.anchors, _editor.blueprint.routes, area.id)
	_clear_selection()
	_editor.mark_dirty()
	_refresh_all()


func _remove_anchor(anchor: ZoneAnchorRecord) -> void:
	ZoneAuthoring.remove_anchor_cascade(
		_editor.blueprint.anchors, _editor.blueprint.routes, anchor.id)
	_clear_selection()
	_editor.mark_dirty()
	_refresh_all()


func _unique_id(prefix: String, taken: Callable) -> StringName:
	return ZoneAuthoring.unique_id(prefix, taken)


# ---------------------------------------------------------------------------
# Selection helpers
# ---------------------------------------------------------------------------

func _clear_selection() -> void:
	_selected_area_id = &""
	_selected_anchor_id = &""
	_selected_route_id = &""


func _selected_area() -> ZoneAreaRecord:
	return _editor.blueprint.area_by_id(_selected_area_id) if _selected_area_id != &"" else null


func _selected_anchor() -> ZoneAnchorRecord:
	return _anchor_by_id(_selected_anchor_id) if _selected_anchor_id != &"" else null


func _selected_route() -> ZoneRouteRecord:
	return _editor.blueprint.route_by_id(_selected_route_id) if _selected_route_id != &"" else null


func _anchor_by_id(anchor_id: StringName) -> ZoneAnchorRecord:
	for anchor in _editor.blueprint.anchors:
		if anchor.id == anchor_id:
			return anchor
	return null


# ---------------------------------------------------------------------------
# Inspector
# ---------------------------------------------------------------------------

func _refresh_delete_button() -> void:
	if _delete_selection_btn == null:
		return
	_delete_selection_btn.disabled = _selected_area() == null and _selected_anchor() == null and _selected_route() == null


func _refresh_all() -> void:
	on_layer_changed()
	_refresh_building_summary()
	_refresh_inspector()
	_refresh_tree()
	_refresh_requirements()
	_refresh_warnings()
	_refresh_visuals()
	_refresh_delete_button()
	_apply_xray()


func _refresh_building_summary() -> void:
	if _building_summary_label == null or _editor.blueprint == null:
		return
	var bp: BuildingBlueprint = _editor.blueprint
	_building_summary_label.text = "%s%s\n%s · %d×%d×%d · %s / %s\n%d областей · %d точек · отмен: %d" % [
		bp.name, " *" if _editor.is_document_dirty() else "", bp.id,
		bp.grid_bounds.x, bp.grid_bounds.y, bp.grid_bounds.z, bp.style, bp.variant,
		bp.areas.size(), bp.anchors.size(), _editor.undo_step_count()]


## Shows the fields of the selected role and nothing else. The old panel showed
## every field of every kind and hid them behind conditions; that is what made
## the model look bigger than it is.
func _refresh_inspector() -> void:
	var area := _selected_area()
	var anchor := _selected_anchor()
	var route := _selected_route()
	_suppress_ui_events = true
	_inspector_body.visible = area != null or anchor != null or route != null
	if area == null and anchor == null and route == null:
		_inspector_title.text = "Ничего не выбрано"
		_clear_container(_props_container)
		_clear_container(_anchor_props)
		_suppress_ui_events = false
		return
	if area != null:
		_inspector_title.text = "▣ %s" % area.display_name()
		_id_edit.text = String(area.id)
		_name_edit.text = area.area_name
		_name_edit.editable = true
		_fill_role_option(_inspector_role_option, [ZoneAreaRecord.ROLE_ROOM,
			ZoneAreaRecord.ROLE_OVERLAY], area.role,
			func(r: StringName) -> String: return ZoneAreaRecord.role_display_name(r))
		_function_row.visible = not area.is_overlay()
		_fill_function_option(_inspector_function_option,
			ZoneFunctionCatalog.for_area_role(area.role), area.function)
		_update_pack_label(_inspector_pack_label, area.function, false)
		_build_property_rows(area.properties, area.function)
		_refresh_equipment(area)
		_overlay_row.visible = area.is_overlay()
		if area.is_overlay():
			_build_permission_checkboxes(area.deny, func(list: Array[StringName]) -> void:
				area.deny = list)
			_build_effect_rows(area)
		_clear_container(_anchor_props)
	elif anchor != null:
		_inspector_role_option.disabled = false
		_inspector_title.text = "%s %s" % [_role_glyph(anchor.role), anchor.id]
		_id_edit.text = String(anchor.id)
		_name_edit.text = ""
		_name_edit.editable = false
		_fill_role_option(_inspector_role_option, ZoneAnchorRecord.BUILDING_ROLES, anchor.role,
			func(r: StringName) -> String: return ZoneAnchorRecord.role_display_name(r))
		var anchor_functions := ZoneFunctionCatalog.for_anchor_role(anchor.role)
		_function_row.visible = anchor.is_slot() or not anchor_functions.is_empty() or anchor.function != &""
		if anchor.is_slot():
			_fill_function_option(_inspector_function_option,
				ZoneFunctionCatalog.activities(), anchor.activity)
			_update_pack_label(_inspector_pack_label, anchor.activity, false)
		elif _function_row.visible:
			_fill_function_option(_inspector_function_option, anchor_functions, anchor.function)
			_update_pack_label(_inspector_pack_label, anchor.function, anchor_functions.is_empty())
		_build_property_rows(anchor.properties, anchor.function)
		_refresh_equipment(null)
		_overlay_row.visible = anchor.is_door()
		if anchor.is_door():
			_build_permission_checkboxes(anchor.deny, func(list: Array[StringName]) -> void:
				anchor.deny = list)
			_clear_container(_overlay_effects_container)
		_build_anchor_rows(anchor)
	else:
		_inspector_title.text = "／ %s" % route.id
		_id_edit.text = String(route.id)
		_name_edit.text = ""
		_name_edit.editable = false
		_inspector_role_option.clear()
		_inspector_role_option.disabled = true
		_function_row.visible = false
		_clear_container(_props_container)
		_refresh_equipment(null)
		_overlay_row.visible = false
		_build_route_rows(route)
	_suppress_ui_events = false


func _role_glyph(role: StringName) -> String:
	match role:
		ZoneAnchorRecord.ROLE_DOOR: return "▽"
		ZoneAnchorRecord.ROLE_SLOT: return "◆"
		ZoneAnchorRecord.ROLE_QUEUE: return "•"
		ZoneAnchorRecord.ROLE_STORAGE: return "▰"
		ZoneAnchorRecord.ROLE_WAYPOINT: return "○"
		ZoneAnchorRecord.ROLE_SPAWN: return "✦"
		ZoneAnchorRecord.ROLE_POI: return "◇"
		_: return "◆"


func _fill_role_option(option: OptionButton, roles: Array, current: StringName, labeller: Callable) -> void:
	option.clear()
	for role in roles:
		option.add_item(labeller.call(role))
		option.set_item_metadata(option.item_count - 1, role)
		if role == current:
			option.select(option.item_count - 1)


func _fill_function_option(option: OptionButton, entries: Array[Dictionary], current: StringName) -> void:
	option.clear()
	option.add_item("— без функции —")
	option.set_item_metadata(0, &"")
	option.select(0)
	for entry in entries:
		option.add_item(String(entry.get("label", "")))
		option.set_item_metadata(option.item_count - 1, entry.get("id", &""))
		if entry.get("id", &"") == current:
			option.select(option.item_count - 1)


## Property rows are generated from the schema the pack declared, so a pack can
## add a field without a single line of editor code.
func _build_property_rows(properties: Dictionary, function_id: StringName) -> void:
	_clear_container(_props_container)
	for descriptor in ZoneFunctionCatalog.property_schema(function_id):
		var key := String(descriptor.get("key", ""))
		if key.is_empty():
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = String(descriptor.get("label", key))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var value: Variant = properties.get(key, descriptor.get("default", ""))
		match String(descriptor.get("type", "string")):
			"int":
				var spin := SpinBox.new()
				spin.min_value = float(descriptor.get("min", 0))
				spin.max_value = float(descriptor.get("max", 999))
				spin.value = float(value)
				spin.value_changed.connect(func(v: float) -> void:
					if int(properties.get(key, descriptor.get("default", 0))) == int(v):
						return
					properties[key] = int(v)
					_editor.mark_dirty()
					_refresh_warnings())
				row.add_child(spin)
			"enum":
				var option := OptionButton.new()
				var options: Array = descriptor.get("options", [])
				for i in options.size():
					option.add_item(String(options[i]))
					option.set_item_metadata(i, StringName(options[i]))
					if String(options[i]) == String(value):
						option.select(i)
				option.item_selected.connect(func(index: int) -> void:
					properties[key] = String(option.get_item_metadata(index))
					_editor.mark_dirty())
				row.add_child(option)
			_:
				var edit := LineEdit.new()
				edit.text = String(value)
				edit.custom_minimum_size = Vector2(120, 0)
				var commit_text := func(text: String) -> void:
					if String(properties.get(key, "")) == text:
						return
					properties[key] = text
					_editor.mark_dirty()
					_refresh_warnings()
				edit.text_submitted.connect(commit_text)
				edit.focus_exited.connect(func() -> void: commit_text.call(edit.text))
				row.add_child(edit)
		_props_container.add_child(row)


func _build_anchor_rows(anchor: ZoneAnchorRecord) -> void:
	_clear_container(_anchor_props)
	_add_anchor_row("Поворот", _make_spin(0.0, 359.0, anchor.facing, 15.0, func(v: float) -> void:
		anchor.facing = v
		_editor.mark_dirty()
		_refresh_visuals()))
	if anchor.supports_arc():
		_add_anchor_row("Сектор обзора", _make_spin(0.0, 360.0, anchor.arc, 5.0, func(v: float) -> void:
			anchor.arc = v
			_editor.mark_dirty()
			_refresh_visuals()))
	if anchor.is_slot():
		var pose_option := OptionButton.new()
		for i in ZoneAnchorRecord.POSES.size():
			var pose: StringName = ZoneAnchorRecord.POSES[i]
			pose_option.add_item(ZoneAnchorRecord.pose_display_name(pose))
			pose_option.set_item_metadata(i, pose)
			if pose == anchor.pose:
				pose_option.select(i)
		pose_option.item_selected.connect(func(index: int) -> void:
			anchor.pose = pose_option.get_item_metadata(index)
			_editor.mark_dirty())
		_add_anchor_row("Поза", pose_option)
		var fixture_option := OptionButton.new()
		fixture_option.add_item("— без fixture —")
		fixture_option.set_item_metadata(0, &"")
		for fixture in _editor.blueprint.fixtures:
			fixture_option.add_item(String(fixture.id))
			fixture_option.set_item_metadata(fixture_option.item_count - 1, fixture.id)
			if fixture.id == anchor.fixture_id:
				fixture_option.select(fixture_option.item_count - 1)
		fixture_option.item_selected.connect(func(index: int) -> void:
			anchor.fixture_id = fixture_option.get_item_metadata(index)
			_editor.mark_dirty()
			_refresh_warnings())
		_add_anchor_row("Fixture", fixture_option)
	elif anchor.is_storage():
		var direction_option := OptionButton.new()
		for i in ZoneAnchorRecord.DIRECTIONS.size():
			var direction: StringName = ZoneAnchorRecord.DIRECTIONS[i]
			direction_option.add_item(ZoneAnchorRecord.direction_display_name(direction))
			direction_option.set_item_metadata(i, direction)
			if direction == anchor.direction:
				direction_option.select(i)
		direction_option.item_selected.connect(func(index: int) -> void:
			anchor.direction = direction_option.get_item_metadata(index)
			_editor.mark_dirty()
			_refresh_warnings())
		_add_anchor_row("Направление", direction_option)
		_add_anchor_row("Ёмкость", _make_spin(0.0, 10000.0, float(anchor.capacity), 10.0,
			func(v: float) -> void:
				anchor.capacity = int(v)
				_editor.mark_dirty()))
	elif anchor.is_queue():
		_add_anchor_row("Место в очереди", _make_spin(0.0, 64.0, float(anchor.index), 1.0,
			func(v: float) -> void:
				anchor.index = int(v)
				_editor.mark_dirty()))
		var target_option := OptionButton.new()
		for other in _editor.blueprint.anchors:
			if not other.is_slot():
				continue
			target_option.add_item(String(other.id))
			target_option.set_item_metadata(target_option.item_count - 1, other.id)
			if other.id == anchor.target_id:
				target_option.select(target_option.item_count - 1)
		target_option.item_selected.connect(func(index: int) -> void:
			anchor.target_id = target_option.get_item_metadata(index)
			_editor.mark_dirty())
		_add_anchor_row("К месту", target_option)
	elif anchor.role == ZoneAnchorRecord.ROLE_SPAWN or anchor.role == ZoneAnchorRecord.ROLE_POI:
		var tag_edit := LineEdit.new()
		tag_edit.text = String(anchor.tag)
		tag_edit.text_changed.connect(func(text: String) -> void:
			anchor.tag = StringName(text)
			_editor.mark_dirty())
		_add_anchor_row("Метка", tag_edit)
	# Ownership is explicit and editable — never inferred from geometry (§6).
	var owner_option := OptionButton.new()
	owner_option.add_item("— всё здание —")
	owner_option.set_item_metadata(0, &"")
	owner_option.select(0)
	for area in _editor.blueprint.areas:
		if not area.owns_content():
			continue
		owner_option.add_item(area.display_name())
		owner_option.set_item_metadata(owner_option.item_count - 1, area.id)
		if area.id == anchor.owner_id:
			owner_option.select(owner_option.item_count - 1)
	owner_option.item_selected.connect(func(index: int) -> void:
		anchor.owner_id = owner_option.get_item_metadata(index)
		_editor.mark_dirty()
		_refresh_tree()
		_refresh_warnings())
	_add_anchor_row("Принадлежит", owner_option)
	# Eligible anchors (door/slot/waypoint) can start a route by linking.
	if _anchor_can_route(anchor):
		var link_btn := Button.new()
		link_btn.text = "В маршрут" if not _linking else "Добавить в маршрут «%s»" % _link_route_id
		link_btn.tooltip_text = "Связать эту точку с другими в маршрут"
		link_btn.pressed.connect(_start_linking)
		_anchor_props.add_child(link_btn)


func _refresh_equipment(area: ZoneAreaRecord) -> void:
	_clear_container(_equipment_container)
	_equipment_title.visible = area != null
	_equipment_container.visible = area != null
	if area == null:
		return
	var found := false
	for fixture in _editor.blueprint.fixtures:
		if fixture.owner_zone_id != area.id:
			continue
		found = true
		var label := Label.new()
		label.text = "◆ Fixture %s · %s" % [fixture.id, ", ".join(
			fixture.capabilities.map(func(cap: StringName) -> String: return String(cap)))]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_equipment_container.add_child(label)
	for fill_object in _editor.blueprint.objects:
		if fill_object.owner_zone_id != area.id:
			continue
		found = true
		var label := Label.new()
		label.text = "▧ Предмет %s" % fill_object.id
		_equipment_container.add_child(label)
	if not found:
		var empty := Label.new()
		empty.text = "Нет принадлежащих комнате fixtures или предметов."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.modulate = Color(0.65, 0.68, 0.72)
		_equipment_container.add_child(empty)
	var fill_btn := Button.new()
	fill_btn.text = "Перейти к наполнению"
	fill_btn.pressed.connect(func() -> void:
		_editor.select_mode(_editor.EditMode.FILL)
		_editor.set_status("Выберите предмет или fixture и назначьте ему зону «%s»." % area.display_name()))
	_equipment_container.add_child(fill_btn)


func _build_route_rows(route: ZoneRouteRecord) -> void:
	_clear_container(_anchor_props)
	var cycle_option := OptionButton.new()
	for index in ZoneRouteRecord.CYCLES.size():
		var cycle := ZoneRouteRecord.CYCLES[index]
		cycle_option.add_item(ZoneRouteRecord.cycle_display_name(cycle))
		cycle_option.set_item_metadata(index, cycle)
		if cycle == route.cycle:
			cycle_option.select(index)
	cycle_option.item_selected.connect(func(index: int) -> void:
		route.cycle = cycle_option.get_item_metadata(index)
		_editor.mark_dirty())
	_add_anchor_row("Обход", cycle_option)
	_add_anchor_row("Ожидание, мин", _make_spin(0.0, 1440.0, route.wait_minutes, 0.5,
		func(value: float) -> void:
			route.wait_minutes = value
			_editor.mark_dirty()))
	var profile_edit := LineEdit.new()
	profile_edit.text = String(route.profile)
	profile_edit.placeholder_text = "pedestrian"
	profile_edit.text_changed.connect(func(value: String) -> void:
		route.profile = StringName(value.strip_edges())
		_editor.mark_dirty())
	_add_anchor_row("Профиль", profile_edit)
	var stops_label := Label.new()
	stops_label.text = " → ".join(route.stops.map(func(stop: StringName) -> String: return String(stop)))
	stops_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_anchor_props.add_child(stops_label)
	# Extend an existing route by clicking more anchors in 3D.
	var add_stop_btn := Button.new()
	add_stop_btn.text = "Добавить точку"
	add_stop_btn.tooltip_text = "Кликайте по точкам в 3D, чтобы добавить их в маршрут"
	add_stop_btn.pressed.connect(func() -> void:
		_link_route_id = route.id
		_selected_route_id = route.id
		_linking = true
		_editor.set_status("Редактируется маршрут «%s»." % route.id))
	_anchor_props.add_child(add_stop_btn)


func _make_spin(min_value: float, max_value: float, value: float, step: float,
		on_changed: Callable) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.value_changed.connect(on_changed)
	return spin


func _add_anchor_row(label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	_anchor_props.add_child(row)


func _build_permission_checkboxes(current: Array[StringName], on_changed: Callable) -> void:
	_clear_container(_overlay_permissions_container)
	var snapshot := current.duplicate()
	for audience in ZoneAccess.AUDIENCES:
		var box := CheckBox.new()
		box.text = ZoneAccess.audience_display_name(audience)
		box.button_pressed = audience in snapshot
		box.toggled.connect(func(pressed: bool) -> void:
			if pressed and audience not in snapshot:
				snapshot.append(audience)
			elif not pressed:
				snapshot.erase(audience)
			on_changed.call(snapshot.duplicate())
			_editor.mark_dirty()
			_refresh_visuals())
		_overlay_permissions_container.add_child(box)


func _build_effect_rows(area: ZoneAreaRecord) -> void:
	_clear_container(_overlay_effects_container)
	for key in ZoneEffects.KEYS:
		var row := HBoxContainer.new()
		var enabled := CheckBox.new()
		enabled.text = ZoneEffects.display_name(key)
		enabled.tooltip_text = ZoneEffects.hint_of(key)
		enabled.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bounds: Vector2 = ZoneEffects.RANGES[key]
		var spin := _make_spin(bounds.x, bounds.y,
			float(area.effects.get(key, ZoneEffects.default_of(key))), 0.1,
			func(value: float) -> void:
				if enabled.button_pressed:
					area.effects[key] = ZoneEffects.clamp_value(key, value)
					_editor.mark_dirty()
					_refresh_warnings())
		enabled.button_pressed = area.effects.has(key)
		spin.editable = enabled.button_pressed
		enabled.toggled.connect(func(pressed: bool) -> void:
			spin.editable = pressed
			if pressed:
				area.effects[key] = ZoneEffects.clamp_value(key, spin.value)
			else:
				area.effects.erase(key)
			_editor.mark_dirty()
			_refresh_warnings())
		row.add_child(enabled)
		row.add_child(spin)
		_overlay_effects_container.add_child(row)


func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_id_submitted(text: String) -> void:
	if _suppress_ui_events:
		return
	var new_id := StringName(text.strip_edges())
	if new_id == &"":
		return
	var area := _selected_area()
	if area != null:
		if _editor.blueprint.zone_id_taken(new_id, area):
			_editor.set_status("Идентификатор «%s» уже занят." % new_id)
			return
		# References follow the rename; a dangling owner is not an option.
		for anchor in _editor.blueprint.anchors:
			if anchor.owner_id == area.id:
				anchor.owner_id = new_id
		for fixture in _editor.blueprint.fixtures:
			if fixture.owner_zone_id == area.id:
				fixture.owner_zone_id = new_id
		for fill_object in _editor.blueprint.objects:
			if fill_object.owner_zone_id == area.id:
				fill_object.owner_zone_id = new_id
		area.id = new_id
		_selected_area_id = new_id
	else:
		var anchor := _selected_anchor()
		if anchor != null:
			if _editor.blueprint.zone_id_taken(new_id, anchor):
				_editor.set_status("Идентификатор «%s» уже занят." % new_id)
				return
			for other in _editor.blueprint.anchors:
				if other.is_queue() and other.target_id == anchor.id:
					other.target_id = new_id
			for route in _editor.blueprint.routes:
				for stop_index in route.stops.size():
					if route.stops[stop_index] == anchor.id:
						route.stops[stop_index] = new_id
			anchor.id = new_id
			_selected_anchor_id = new_id
		else:
			var route := _selected_route()
			if route == null:
				return
			if new_id != route.id and _editor.blueprint.route_by_id(new_id) != null:
				_editor.set_status("Идентификатор маршрута «%s» уже занят." % new_id)
				return
			route.id = new_id
			_selected_route_id = new_id
	_editor.mark_dirty()
	_refresh_all()


func _on_name_changed(text: String) -> void:
	if _suppress_ui_events:
		return
	var area := _selected_area()
	if area == null:
		return
	if area.area_name == text:
		return
	area.area_name = text
	_editor.mark_dirty()
	_refresh_tree()


func _on_inspector_role_selected(index: int) -> void:
	if _suppress_ui_events:
		return
	var role: StringName = _inspector_role_option.get_item_metadata(index)
	var area := _selected_area()
	if area != null:
		if area.owns_content() and role == ZoneAreaRecord.ROLE_OVERLAY and _area_has_owned_content(area.id):
			_editor.set_status("Сначала переназначьте точки, предметы и fixtures этой комнаты.")
			_refresh_inspector()
			return
		area.role = role
		if area.is_overlay():
			area.function = &""
			area.properties.clear()
		else:
			area.allow.clear()
			area.deny.clear()
			area.effects.clear()
	else:
		var anchor := _selected_anchor()
		if anchor == null:
			return
		if anchor.is_slot() and role != ZoneAnchorRecord.ROLE_SLOT:
			for other in _editor.blueprint.anchors.duplicate():
				if other.is_queue() and other.target_id == anchor.id:
					_editor.blueprint.anchors.erase(other)
			if role not in [ZoneAnchorRecord.ROLE_WAYPOINT,
					ZoneAnchorRecord.ROLE_SLOT, ZoneAnchorRecord.ROLE_DOOR]:
				ZoneAuthoring.remove_route_stops(_editor.blueprint.routes, [anchor.id])
			anchor.role = role
			if not anchor.is_slot():
				anchor.activity = &""
				anchor.fixture_id = &""
			if not ZoneFunctionCatalog.supports_anchor_role(anchor.function, role):
				anchor.function = &""
				anchor.properties.clear()
	_editor.mark_dirty()
	_refresh_all()


func _area_has_owned_content(area_id: StringName) -> bool:
	if not _editor.blueprint.anchors_of(area_id).is_empty():
		return true
	for fixture in _editor.blueprint.fixtures:
		if fixture.owner_zone_id == area_id:
			return true
	for fill_object in _editor.blueprint.objects:
		if fill_object.owner_zone_id == area_id:
			return true
	return false


func _on_inspector_function_selected(index: int) -> void:
	if _suppress_ui_events:
		return
	var function_id: StringName = _inspector_function_option.get_item_metadata(index)
	var area := _selected_area()
	if area != null:
		area.function = function_id
		# Defaults come from the pack, so a freshly picked function is complete
		# instead of starting as an empty dictionary the author must guess at.
		area.properties = ZoneFunctionCatalog.default_properties(function_id)
	else:
		var anchor := _selected_anchor()
		if anchor == null:
			return
		if anchor.is_slot():
			anchor.activity = function_id
		else:
			anchor.function = function_id
			anchor.properties = ZoneFunctionCatalog.default_properties(function_id)
	_editor.mark_dirty()
	_refresh_all()


# ---------------------------------------------------------------------------
# Zone list
# ---------------------------------------------------------------------------

## The tree is the only way to reach a point hidden under a roof or a mesh.
func _refresh_tree() -> void:
	if _zone_tree == null:
		return
	_zone_tree.clear()
	var root := _zone_tree.create_item()
	var selected_item: TreeItem = null
	var errors: Array[String] = _editor.blueprint.zone_validation_errors()
	var warnings: Array[String] = _editor.blueprint.validation_warnings()
	for area in _editor.blueprint.areas:
		var item := _zone_tree.create_item(root)
		var issue_count := _issues_for([String(area.id), area.display_name()], errors, warnings)
		item.set_text(0, "▣ %s%s" % [area.display_name(),
			"  ⚠%d" % issue_count if issue_count > 0 else ""])
		item.set_tooltip_text(0, "%s · Y%d…%d · %d клеток" % [
			ZoneAreaRecord.role_display_name(area.role), area.y_min, area.y_max, area.cell_count()])
		item.set_metadata(0, {"kind": "area", "id": area.id})
		if area.is_overlay():
			item.set_custom_color(0, OVERLAY_COLOR)
		if area.id == _selected_area_id:
			selected_item = item
		for anchor in _editor.blueprint.anchors_of(area.id):
			var child := _zone_tree.create_item(item)
			var anchor_issues := _issues_for([String(anchor.id)], errors, warnings)
			child.set_text(0, "%s %s%s" % [_role_glyph(anchor.role), anchor.id,
				"  ⚠%d" % anchor_issues if anchor_issues > 0 else ""])
			child.set_tooltip_text(0, "%s · Y%d" % [
				ZoneAnchorRecord.role_display_name(anchor.role), floori(anchor.pos.y)])
			child.set_metadata(0, {"kind": "anchor", "id": anchor.id})
			if anchor.id == _selected_anchor_id:
				selected_item = child
	var loose_anchors: Array[ZoneAnchorRecord] = []
	for anchor in _editor.blueprint.anchors:
		if anchor.owner_id == &"":
			loose_anchors.append(anchor)
	if not loose_anchors.is_empty():
		var loose := _zone_tree.create_item(root)
		loose.set_text(0, "— всё здание —")
		loose.set_selectable(0, false)
		for anchor in loose_anchors:
			var child := _zone_tree.create_item(loose)
			var anchor_issues := _issues_for([String(anchor.id)], errors, warnings)
			child.set_text(0, "%s %s%s" % [_role_glyph(anchor.role), anchor.id,
				"  ⚠%d" % anchor_issues if anchor_issues > 0 else ""])
			child.set_metadata(0, {"kind": "anchor", "id": anchor.id})
			if anchor.id == _selected_anchor_id:
				selected_item = child
	if not _editor.blueprint.routes.is_empty():
		var routes_item := _zone_tree.create_item(root)
		routes_item.set_text(0, "／ Маршруты")
		routes_item.set_selectable(0, false)
		for route in _editor.blueprint.routes:
			var child := _zone_tree.create_item(routes_item)
			child.set_text(0, "%s (%d)" % [route.id, route.stops.size()])
			child.set_metadata(0, {"kind": "route", "id": route.id})
			if route.id == _selected_route_id:
				selected_item = child
	if selected_item != null:
		selected_item.select(0)


func _issues_for(tokens: Array[String], errors: Array[String], warnings: Array[String]) -> int:
	var count := 0
	for issue in errors + warnings:
		for token in tokens:
			if not token.is_empty() and issue.contains(token):
				count += 1
				break
	return count


func _on_tree_item_selected() -> void:
	if _suppress_ui_events:
		return
	var item := _zone_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if not (meta is Dictionary):
		return
	if meta["kind"] == "area":
		_selected_area_id = meta["id"]
		_selected_anchor_id = &""
		_selected_route_id = &""
	elif meta["kind"] == "anchor":
		_selected_anchor_id = meta["id"]
		_selected_area_id = &""
		_selected_route_id = &""
	else:
		_selected_route_id = meta["id"]
		_selected_area_id = &""
		_selected_anchor_id = &""
	_refresh_inspector()
	_refresh_requirements()
	_refresh_visuals()


func _refresh_requirements() -> void:
	if _req_checklist == null:
		return
	for child in _req_checklist.get_children():
		if child != _req_empty_label:
			_req_checklist.remove_child(child)
			child.queue_free()
	var checklist: Array[Dictionary] = _editor.blueprint.zone_requirements_checklist()
	_req_empty_label.visible = checklist.is_empty()
	for entry in checklist:
		var label := Label.new()
		var satisfied: bool = entry.get("satisfied", false)
		label.text = "%s %s — %s" % ["✔" if satisfied else "✖", entry.get("area_name", ""),
			entry.get("capability", "")]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color",
			Color(0.55, 0.85, 0.55) if satisfied else Color(0.9, 0.5, 0.5))
		_req_checklist.add_child(label)


func _refresh_warnings() -> void:
	if _issues_container == null:
		return
	_clear_container(_issues_container)
	var errors: Array[String] = _editor.blueprint.zone_validation_errors()
	var warnings: Array[String] = _editor.blueprint.validation_warnings()
	for error in errors:
		_add_issue_button("✖", error, Color(0.95, 0.5, 0.5))
	for warning in warnings:
		_add_issue_button("⚠", warning, Color(0.9, 0.75, 0.4))
	if errors.is_empty() and warnings.is_empty():
		var ok := Label.new()
		ok.text = "✔ Проблем не найдено"
		ok.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
		_issues_container.add_child(ok)


func _add_issue_button(glyph: String, issue: String, color: Color) -> void:
	var target := _issue_target(issue)
	var button := Button.new()
	button.text = "%s %s" % [glyph, issue]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = issue + ("\nНажмите, чтобы выбрать объект." if not target.is_empty() else "")
	button.add_theme_color_override("font_color", color)
	button.disabled = target.is_empty()
	if not target.is_empty():
		button.pressed.connect(func() -> void: _select_issue_target(target))
	_issues_container.add_child(button)


func _issue_target(issue: String) -> Dictionary:
	for anchor in _editor.blueprint.anchors:
		if issue.contains(String(anchor.id)) or issue.contains("«%s»" % anchor.id):
			return {"kind": "anchor", "id": anchor.id}
	for area in _editor.blueprint.areas:
		if issue.contains(String(area.id)) or issue.contains("«%s»" % area.display_name()):
			return {"kind": "area", "id": area.id}
	for route in _editor.blueprint.routes:
		if issue.contains(String(route.id)):
			return {"kind": "route", "id": route.id}
	return {}


func _select_issue_target(target: Dictionary) -> void:
	_clear_selection()
	match String(target.get("kind", "")):
		"area":
			_selected_area_id = target.get("id", &"")
		"anchor":
			_selected_anchor_id = target.get("id", &"")
		"route":
			_selected_route_id = target.get("id", &"")
	_refresh_all()


func _run_validation() -> void:
	_refresh_requirements()
	_refresh_warnings()
	var errors: Array[String] = _editor.blueprint.zone_validation_errors()
	var warnings: Array[String] = _editor.blueprint.validation_warnings()
	if errors.is_empty() and warnings.is_empty():
		_editor.set_status("Проверка зон пройдена: ошибок и предупреждений нет.")
	elif errors.is_empty():
		_editor.set_status("Проверка зон: предупреждений %d. Подробности справа." % warnings.size())
	else:
		_editor.set_status("Проверка зон: ошибок %d, предупреждений %d. Подробности справа." % [
			errors.size(), warnings.size()])


func _refresh_cursor_status() -> void:
	if not _editor.cursor_valid:
		return
	var cell := _cursor_cell_2d()
	var parts: Array[String] = ["клетка %d,%d · Y%d" % [cell.x, cell.y, _editor.active_layer]]
	var rooms: Array[ZoneAreaRecord] = []
	for area in _editor.blueprint.rooms():
		if area.contains_cell_3d(Vector3i(cell.x, _editor.active_layer, cell.y)):
			rooms.append(area)
	if not rooms.is_empty():
		parts.append("комната «%s»" % rooms[0].display_name())
	var denied: Array[String] = []
	var allowed_only: Array[String] = []
	var effects: Array[String] = []
	for area in _editor.blueprint.overlays():
		if not area.contains_cell_3d(Vector3i(cell.x, _editor.active_layer, cell.y)):
			continue
		for audience in area.deny:
			if String(audience) not in denied:
				denied.append(String(audience))
		for audience in area.allow:
			if String(audience) not in allowed_only:
				allowed_only.append(String(audience))
		for effect in area.effects:
			if String(effect) not in effects:
				effects.append(String(effect))
	if not denied.is_empty():
		parts.append("нельзя: %s" % ", ".join(denied))
	if not allowed_only.is_empty():
		parts.append("только: %s" % ", ".join(allowed_only))
	if not effects.is_empty():
		parts.append("эффекты: %s" % ", ".join(effects))
	var issue_count: int = _editor.blueprint.zone_validation_errors().size() \
		+ _editor.blueprint.validation_warnings().size()
	parts.append("замечаний: %d" % issue_count)
	_editor.set_status(" · ".join(parts))


func _apply_xray() -> void:
	if not is_active():
		return
	_set_frame_transparency(0.72 if _xray_check.button_pressed else 0.0)


func _set_frame_transparency(value: float) -> void:
	var blocks_root := _editor.get_node_or_null("BlocksRoot")
	if blocks_root == null:
		return
	for node in blocks_root.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).transparency = value


# ---------------------------------------------------------------------------
# 3D markers
# ---------------------------------------------------------------------------

func _clear_visuals() -> void:
	if _zones_visual_root == null:
		return
	for child in _zones_visual_root.get_children():
		_zones_visual_root.remove_child(child)
		child.queue_free()


func _refresh_visuals() -> void:
	if _zones_visual_root == null:
		return
	_clear_visuals()
	if not is_active():
		return
	var color_index := 0
	for area in _editor.blueprint.areas:
		if area.is_overlay() and not _show_overlays_check.button_pressed and area.id != _selected_area_id:
			continue
		if not area.is_overlay() and not _show_rooms_check.button_pressed and area.id != _selected_area_id:
			continue
		var color := OVERLAY_COLOR
		var height := 0.04
		if not area.is_overlay():
			color = AREA_COLORS[color_index % AREA_COLORS.size()]
			color_index += 1
		else:
			# Permission overlays are red; effect-only overlays are purple and remain
			# visible. An author must be able to select what the file will apply.
			if not area.deny.is_empty() or not area.allow.is_empty():
				height = 0.12
			elif not area.effects.is_empty():
				color = Color(0.72, 0.38, 1.0)
				height = 0.08
			else:
				color = Color(0.55, 0.55, 0.55)
		if area.id == _selected_area_id:
			color = color.lerp(SELECTION_COLOR, 0.5)
		# Areas are flat markers; draw them on the current layer when it falls inside
		# the area's height range, so a room that spans floors is visible on each.
		if _editor.active_layer < area.y_min or _editor.active_layer > area.y_max:
			continue
		var marker_y := float(_editor.active_layer)
		for cell in area.footprint_cells():
			_add_marker(Vector3(cell.x + 0.5, marker_y, cell.y + 0.5), color,
				Vector3(0.94, height, 0.94), true)
	var fp: Vector2i = _editor.blueprint.footprint
	for anchor in _editor.blueprint.anchors:
		if not _show_anchors_check.button_pressed and anchor.id != _selected_anchor_id:
			continue
		# Anchors belong on the floor they were placed on; hide ones outside the
		# current layer or the building footprint so a upper floor stays clean.
		if int(floor(anchor.pos.y)) != _editor.active_layer:
			continue
		var ac: Vector2i = anchor.cell()
		if ac.x < 0 or ac.y < 0 or ac.x >= fp.x or ac.y >= fp.y:
			continue
		var style: Dictionary = ANCHOR_STYLE.get(anchor.role, ANCHOR_STYLE[&"poi"])
		var color: Color = style["color"]
		if anchor.id == _selected_anchor_id:
			color = color.lerp(SELECTION_COLOR, 0.6)
		_add_marker(anchor.pos, color, style["size"],
			anchor.role == ZoneAnchorRecord.ROLE_STORAGE, anchor.facing)
	for route in _editor.blueprint.routes:
		if not _show_routes_check.button_pressed and route.id != _selected_route_id:
			continue
		var route_color := Color(1.0, 0.85, 0.25)
		if route.id == _selected_route_id:
			route_color = route_color.lerp(SELECTION_COLOR, 0.5)
		for index in range(route.stops.size() - 1):
			var from_anchor: ZoneAnchorRecord = _editor.blueprint.anchor_by_id(route.stops[index])
			var to_anchor: ZoneAnchorRecord = _editor.blueprint.anchor_by_id(route.stops[index + 1])
			if from_anchor != null and to_anchor != null:
				_add_route_segment(from_anchor.pos, to_anchor.pos, route_color)


func _get_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_cache[key] = material
	return material


func _add_marker(pos: Vector3, color: Color, size: Vector3, flat: bool, facing: float = 0.0) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _get_material(color)
	instance.position = pos + Vector3(0.0, size.y * 0.5 + (0.02 if flat else 0.0), 0.0)
	instance.rotation.y = deg_to_rad(facing)
	_zones_visual_root.add_child(instance)


func _add_route_segment(from: Vector3, to: Vector3, color: Color) -> void:
	var delta := to - from
	var length := delta.length()
	if length <= 0.001:
		return
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, length)
	instance.mesh = mesh
	instance.material_override = _get_material(color)
	instance.position = (from + to) * 0.5 + Vector3.UP * 0.18
	instance.look_at_from_position(instance.position, instance.position + delta, Vector3.UP)
	_zones_visual_root.add_child(instance)
