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
const TOOL_SELECT := &"select"

const AREA_COLORS: Array[Color] = [
	Color(0.35, 0.75, 1.0), Color(1.0, 0.7, 0.3), Color(0.6, 1.0, 0.5),
	Color(1.0, 0.5, 0.8), Color(0.8, 0.8, 0.4), Color(0.5, 0.9, 0.9),
]
const ACCESS_COLOR := Color(1.0, 0.35, 0.35)
const SELECTION_COLOR := Color(1.0, 1.0, 1.0)

## Marker size and colour per anchor role, so a glance at the 3D view tells the
## author what is where without selecting anything.
const ANCHOR_STYLE: Dictionary = {
	&"door": {"color": Color(1.0, 0.55, 0.2), "size": Vector3(0.5, 1.8, 0.5)},
	&"slot": {"color": Color(0.4, 1.0, 0.4), "size": Vector3(0.45, 1.2, 0.45)},
	&"queue": {"color": Color(0.9, 0.9, 0.4), "size": Vector3(0.35, 0.6, 0.35)},
	&"storage": {"color": Color(0.4, 0.8, 1.0), "size": Vector3(0.7, 0.3, 0.7)},
	&"spawn": {"color": Color(0.8, 0.5, 1.0), "size": Vector3(0.5, 0.9, 0.5)},
	&"waypoint": {"color": Color(0.7, 0.7, 0.7), "size": Vector3(0.3, 0.5, 0.3)},
	&"poi": {"color": Color(1.0, 0.8, 0.6), "size": Vector3(0.4, 0.9, 0.4)},
}

var _editor: Node = null
var _zones_visual_root: Node3D = null

# Left palette
var _palette_panel: PanelContainer = null
var _tool_area_btn: Button = null
var _tool_point_btn: Button = null
var _tool_select_btn: Button = null
var _role_option: OptionButton = null
var _function_option: OptionButton = null
var _function_pack_label: Label = null
var _layer_label: Label = null
var _layer_down_btn: Button = null
var _layer_up_btn: Button = null
var _show_access_check: CheckBox = null
var _access_audience_option: OptionButton = null

# Right inspector
var _inspector_panel: PanelContainer = null
var _inspector_title: Label = null
var _inspector_body: VBoxContainer = null
var _id_edit: LineEdit = null
var _name_edit: LineEdit = null
var _inspector_role_option: OptionButton = null
var _function_row: VBoxContainer = null
var _inspector_function_option: OptionButton = null
var _inspector_pack_label: Label = null
var _props_container: VBoxContainer = null
var _access_row: VBoxContainer = null
var _access_container: HFlowContainer = null
var _anchor_props: VBoxContainer = null
var _delete_btn: Button = null
var _req_checklist: VBoxContainer = null
var _req_empty_label: Label = null
var _zone_tree: Tree = null
var _warnings_label: Label = null

# Mode state
var _tool: StringName = TOOL_AREA
## Role armed for the next created zone; contextual to the tool.
var _area_role: StringName = ZoneAreaRecord.ROLE_ROOM
var _anchor_role: StringName = ZoneAnchorRecord.ROLE_SLOT
var _armed_function: StringName = &""
## Selection is either an area or an anchor; ids are unique per collection.
var _selected_area_id: StringName = &""
var _selected_anchor_id: StringName = &""
var _material_cache: Dictionary = {}
var _suppress_ui_events: bool = false

# Rectangle drag for the area tool.
var _dragging: bool = false
var _drag_start: Vector2i = Vector2i.ZERO


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(editor: Node) -> void:
	_editor = editor
	name = "ZonesModeController"

	_palette_panel = editor.get_node("%ZonesPalettePanel")
	_tool_area_btn = editor.get_node("%ToolAreaBtn")
	_tool_point_btn = editor.get_node("%ToolPointBtn")
	_tool_select_btn = editor.get_node("%ToolSelectBtn")
	_role_option = editor.get_node("%ZoneRoleOption")
	_function_option = editor.get_node("%ZoneFunctionOption")
	_function_pack_label = editor.get_node("%ZoneFunctionPackLbl")
	_layer_label = editor.get_node("%ZoneLayerLabel")
	_layer_down_btn = editor.get_node("%ZoneLayerDownBtn")
	_layer_up_btn = editor.get_node("%ZoneLayerUpBtn")
	_show_access_check = editor.get_node("%ShowAccessCheck")
	_access_audience_option = editor.get_node("%AccessAudienceOption")

	_inspector_panel = editor.get_node("%ZonesInspectorPanel")
	_inspector_title = editor.get_node("%ZoneInspectorTitle")
	_inspector_body = editor.get_node("%ZoneInspectorBody")
	_id_edit = editor.get_node("%ZoneIdEdit")
	_name_edit = editor.get_node("%ZoneNameEdit")
	_inspector_role_option = editor.get_node("%ZoneInspectorRoleOption")
	_function_row = editor.get_node("%ZoneFunctionRow")
	_inspector_function_option = editor.get_node("%ZoneInspectorFunctionOption")
	_inspector_pack_label = editor.get_node("%ZoneInspectorPackLbl")
	_props_container = editor.get_node("%ZonePropsContainer")
	_access_row = editor.get_node("%ZoneAccessRow")
	_access_container = editor.get_node("%ZoneAccessContainer")
	_anchor_props = editor.get_node("%ZoneAnchorProps")
	_delete_btn = editor.get_node("%DeleteZoneBtn")
	_req_checklist = editor.get_node("%ZoneReqChecklist")
	_req_empty_label = editor.get_node("%ZoneReqEmptyLabel")
	_zone_tree = editor.get_node("%ZoneTree")
	_warnings_label = editor.get_node("%ZoneWarningsLabel")
	_zones_visual_root = editor.get_node("%ZonesVisual")

	_tool_area_btn.pressed.connect(func() -> void: _arm_tool(TOOL_AREA))
	_tool_point_btn.pressed.connect(func() -> void: _arm_tool(TOOL_POINT))
	_tool_select_btn.pressed.connect(func() -> void: _arm_tool(TOOL_SELECT))
	_role_option.item_selected.connect(_on_palette_role_selected)
	_function_option.item_selected.connect(_on_palette_function_selected)
	_layer_down_btn.pressed.connect(func() -> void: _editor.set_layer(_editor.active_layer - 1))
	_layer_up_btn.pressed.connect(func() -> void: _editor.set_layer(_editor.active_layer + 1))
	_show_access_check.toggled.connect(func(_pressed: bool) -> void: _refresh_visuals())
	_access_audience_option.item_selected.connect(func(_index: int) -> void: _refresh_visuals())

	_id_edit.text_submitted.connect(_on_id_submitted)
	_id_edit.focus_exited.connect(func() -> void: _on_id_submitted(_id_edit.text))
	_name_edit.text_changed.connect(_on_name_changed)
	_inspector_role_option.item_selected.connect(_on_inspector_role_selected)
	_inspector_function_option.item_selected.connect(_on_inspector_function_selected)
	_delete_btn.pressed.connect(_delete_selection)
	_zone_tree.item_selected.connect(_on_tree_item_selected)

	for audience in ZoneAccess.AUDIENCES:
		_access_audience_option.add_item(ZoneAccess.audience_display_name(audience))
		_access_audience_option.set_item_metadata(_access_audience_option.item_count - 1, audience)
	_access_audience_option.select(0)

	_arm_tool(TOOL_AREA)


# ---------------------------------------------------------------------------
# Mode lifecycle
# ---------------------------------------------------------------------------

func activate() -> void:
	_palette_panel.visible = true
	_inspector_panel.visible = true
	_rebuild_function_options()
	_refresh_all()
	_editor.set_status("Режим зон: Q — область, W — точка, R — выделение.")


func deactivate() -> void:
	_palette_panel.visible = false
	_inspector_panel.visible = false
	_dragging = false
	_clear_visuals()


func is_active() -> bool:
	return _palette_panel != null and _palette_panel.visible


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

## Returns true when the mouse button was consumed by zones mode.
func handle_mouse_button(event: InputEventMouseButton) -> bool:
	if event.button_index == MOUSE_BUTTON_RIGHT and event.shift_pressed:
		if event.pressed and not _editor.is_pointer_over_ui():
			_erase_at_cursor()
		return true
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if event.pressed:
		if _editor.is_pointer_over_ui():
			return false
		match _tool:
			TOOL_AREA:
				_dragging = true
				_drag_start = _cursor_cell_2d()
			TOOL_POINT:
				_place_anchor_at_cursor()
			TOOL_SELECT:
				_select_at_cursor()
		return true
	if _dragging:
		_dragging = false
		_commit_area_rect(_drag_start, _cursor_cell_2d())
	return true


func on_mouse_motion(_event: InputEventMouseMotion) -> void:
	if _dragging:
		_editor.update_cursor()


## Returns true when the key was consumed by zones mode.
func handle_key(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	match event.keycode:
		KEY_Q:
			_arm_tool(TOOL_AREA)
		KEY_W:
			_arm_tool(TOOL_POINT)
		KEY_R:
			_arm_tool(TOOL_SELECT)
		KEY_TAB:
			_cycle_role()
		KEY_F:
			_rotate_selected_anchor()
		KEY_DELETE:
			_delete_selection()
		_:
			return false
	return true


func is_painting() -> bool:
	return _dragging


func process(_delta: float) -> void:
	pass


func refresh_ghost() -> void:
	pass


func on_layer_changed() -> void:
	if _layer_label != null and _editor != null:
		_layer_label.text = "Слой Y: %d" % _editor.active_layer


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
	_tool_select_btn.button_pressed = tool_id == TOOL_SELECT
	_rebuild_role_options()
	_rebuild_function_options()


## The role list is contextual: an area tool offers area roles, a point tool
## offers point roles. One dropdown, never both vocabularies at once.
func _rebuild_role_options() -> void:
	_suppress_ui_events = true
	_role_option.clear()
	_role_option.disabled = _tool == TOOL_SELECT
	if _tool == TOOL_AREA:
		# `region` belongs to maps; a building authors rooms and access overlays.
		for role in [ZoneAreaRecord.ROLE_ROOM, ZoneAreaRecord.ROLE_ACCESS]:
			_role_option.add_item(ZoneAreaRecord.role_display_name(role))
			_role_option.set_item_metadata(_role_option.item_count - 1, role)
			if role == _area_role:
				_role_option.select(_role_option.item_count - 1)
	elif _tool == TOOL_POINT:
		for role in ZoneAnchorRecord.BUILDING_ROLES:
			_role_option.add_item(ZoneAnchorRecord.role_display_name(role))
			_role_option.set_item_metadata(_role_option.item_count - 1, role)
			if role == _anchor_role:
				_role_option.select(_role_option.item_count - 1)
	_suppress_ui_events = false


func _on_palette_role_selected(index: int) -> void:
	if _suppress_ui_events:
		return
	var role: StringName = _role_option.get_item_metadata(index)
	if _tool == TOOL_AREA:
		_area_role = role
	else:
		_anchor_role = role
	_rebuild_function_options()


func _cycle_role() -> void:
	if _role_option.item_count == 0:
		return
	var next := (_role_option.selected + 1) % _role_option.item_count
	_role_option.select(next)
	_on_palette_role_selected(next)


## Functions offered for what is currently armed. An empty list is not a bug: it
## means no installed pack gives this role a meaning, and the zone stays inert.
func _rebuild_function_options() -> void:
	_suppress_ui_events = true
	_function_option.clear()
	_function_option.add_item("— без функции —")
	_function_option.set_item_metadata(0, &"")
	var entries := _armed_function_entries()
	for entry in entries:
		_function_option.add_item(String(entry.get("label", "")))
		_function_option.set_item_metadata(_function_option.item_count - 1, entry.get("id", &""))
	var matched := false
	for i in _function_option.item_count:
		if _function_option.get_item_metadata(i) == _armed_function:
			_function_option.select(i)
			matched = true
	if not matched:
		_armed_function = &""
		_function_option.select(0)
	_function_option.disabled = _tool == TOOL_SELECT
	_suppress_ui_events = false
	_update_pack_label(_function_pack_label, _armed_function, entries.is_empty())


func _armed_function_entries() -> Array[Dictionary]:
	if _tool == TOOL_AREA:
		return ZoneFunctionCatalog.for_area_role(_area_role)
	if _tool == TOOL_POINT and _anchor_role == ZoneAnchorRecord.ROLE_SLOT:
		return ZoneFunctionCatalog.activities()
	return [] as Array[Dictionary]


func _on_palette_function_selected(index: int) -> void:
	if _suppress_ui_events:
		return
	_armed_function = _function_option.get_item_metadata(index)
	_update_pack_label(_function_pack_label, _armed_function, false)


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


func _commit_area_rect(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if not _editor.cursor_valid:
		return
	var rect := Rect2i(from_cell, Vector2i.ONE).merge(Rect2i(to_cell, Vector2i.ONE))
	var area := _selected_area()
	if area == null or area.role != _area_role:
		area = _create_area()
	area.add_rect(rect)
	area.y_min = mini(area.y_min, _editor.active_layer)
	area.y_max = maxi(area.y_max, _editor.active_layer)
	_selected_area_id = area.id
	_selected_anchor_id = &""
	_editor.mark_dirty()
	_refresh_all()


func _create_area() -> ZoneAreaRecord:
	var area := ZoneAreaRecord.new()
	area.role = _area_role
	area.id = _unique_id("area", func(candidate: StringName) -> bool:
		return _editor.blueprint.area_by_id(candidate) != null)
	var template := "Комната %d" if _area_role == ZoneAreaRecord.ROLE_ROOM else "Доступ %d"
	area.area_name = template % (_editor.blueprint.areas.size() + 1)
	area.y_min = _editor.active_layer
	area.y_max = _editor.active_layer
	if _area_role == ZoneAreaRecord.ROLE_ACCESS:
		# An overlay that forbids nobody is a no-op; start from the case the
		# author almost always wants and let them widen it.
		area.deny = [ZoneAccess.AUDIENCE_VISITOR]
	elif _armed_function != &"":
		area.function = _armed_function
		area.properties = ZoneFunctionCatalog.default_properties(_armed_function)
	_editor.blueprint.areas.append(area)
	return area


func _place_anchor_at_cursor() -> void:
	if not _editor.cursor_valid:
		return
	var anchor := ZoneAnchorRecord.new()
	anchor.id = _unique_id(String(_anchor_role), func(candidate: StringName) -> bool:
		return _anchor_by_id(candidate) != null)
	anchor.role = _anchor_role
	anchor.pos = Vector3(_editor.cursor_cell) + Vector3(0.5, 0.0, 0.5)
	anchor.pos.y = float(_editor.active_layer)
	# Ownership is explicit, but the obvious owner is filled in for the author:
	# the room under the point. Doors stay building-wide unless retargeted.
	if not anchor.is_door():
		for area in _editor.blueprint.rooms():
			if area.contains_cell(_cursor_cell_2d()):
				anchor.owner_id = area.id
				break
	if anchor.is_slot() and _armed_function != &"":
		anchor.activity = _armed_function
	if anchor.is_storage():
		anchor.capacity = 50
	if anchor.is_queue():
		var target := _nearest_slot(anchor.pos)
		if target != null:
			anchor.target_id = target.id
			anchor.index = _next_queue_index(target.id)
	_editor.blueprint.anchors.append(anchor)
	_selected_anchor_id = anchor.id
	_selected_area_id = &""
	_editor.mark_dirty()
	_refresh_all()


func _nearest_slot(pos: Vector3) -> ZoneAnchorRecord:
	var best: ZoneAnchorRecord = null
	var best_distance := INF
	for anchor in _editor.blueprint.anchors:
		if not anchor.is_slot():
			continue
		var distance: float = anchor.pos.distance_to(pos)
		if distance < best_distance:
			best_distance = distance
			best = anchor
	return best


func _next_queue_index(target_id: StringName) -> int:
	var index := 0
	for anchor in _editor.blueprint.anchors:
		if anchor.is_queue() and anchor.target_id == target_id:
			index = maxi(index, anchor.index + 1)
	return index


func _erase_at_cursor() -> void:
	if not _editor.cursor_valid:
		return
	var cell := _cursor_cell_2d()
	for anchor in _editor.blueprint.anchors:
		if anchor.cell() == cell:
			_remove_anchor(anchor)
			return
	# Erasing works on whole rectangles: an area is composed of them, and a
	# partial erase would have to split what the author actually drew.
	for area in _editor.blueprint.areas:
		if area.remove_rect_at(cell):
			if area.is_empty():
				_remove_area(area)
			else:
				_editor.mark_dirty()
				_refresh_all()
			return


func _select_at_cursor() -> void:
	if not _editor.cursor_valid:
		return
	var cell := _cursor_cell_2d()
	for anchor in _editor.blueprint.anchors:
		if anchor.cell() == cell:
			_selected_anchor_id = anchor.id
			_selected_area_id = &""
			_refresh_all()
			return
	for area in _editor.blueprint.areas:
		if area.contains_cell(cell):
			_selected_area_id = area.id
			_selected_anchor_id = &""
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


func _delete_selection() -> void:
	var anchor := _selected_anchor()
	if anchor != null:
		_remove_anchor(anchor)
		return
	var area := _selected_area()
	if area != null:
		_remove_area(area)


## Deleting an area cascades to everything it owns — orphaned anchors and
## fixtures are the invariant this rule exists to protect (active_zones.md §7.7).
func _remove_area(area: ZoneAreaRecord) -> void:
	var kept_anchors: Array[ZoneAnchorRecord] = []
	for anchor in _editor.blueprint.anchors:
		if anchor.owner_id != area.id:
			kept_anchors.append(anchor)
	_editor.blueprint.anchors = kept_anchors
	for fixture in _editor.blueprint.fixtures:
		if fixture.owner_zone_id == area.id:
			fixture.owner_zone_id = &""
	for decor_object in _editor.blueprint.objects:
		if decor_object.owner_zone_id == area.id:
			decor_object.owner_zone_id = &""
	_editor.blueprint.areas.erase(area)
	_clear_selection()
	_editor.mark_dirty()
	_refresh_all()


func _remove_anchor(anchor: ZoneAnchorRecord) -> void:
	# A queue pointing at a deleted slot would be a dangling reference.
	if anchor.is_slot():
		var kept: Array[ZoneAnchorRecord] = []
		for other in _editor.blueprint.anchors:
			if not (other.is_queue() and other.target_id == anchor.id):
				kept.append(other)
		_editor.blueprint.anchors = kept
	_editor.blueprint.anchors.erase(anchor)
	_clear_selection()
	_editor.mark_dirty()
	_refresh_all()


func _unique_id(prefix: String, taken: Callable) -> StringName:
	var index := 1
	while taken.call(StringName("%s_%d" % [prefix, index])):
		index += 1
	return StringName("%s_%d" % [prefix, index])


# ---------------------------------------------------------------------------
# Selection helpers
# ---------------------------------------------------------------------------

func _clear_selection() -> void:
	_selected_area_id = &""
	_selected_anchor_id = &""


func _selected_area() -> ZoneAreaRecord:
	return _editor.blueprint.area_by_id(_selected_area_id) if _selected_area_id != &"" else null


func _selected_anchor() -> ZoneAnchorRecord:
	return _anchor_by_id(_selected_anchor_id) if _selected_anchor_id != &"" else null


func _anchor_by_id(anchor_id: StringName) -> ZoneAnchorRecord:
	for anchor in _editor.blueprint.anchors:
		if anchor.id == anchor_id:
			return anchor
	return null


# ---------------------------------------------------------------------------
# Inspector
# ---------------------------------------------------------------------------

func _refresh_all() -> void:
	on_layer_changed()
	_refresh_inspector()
	_refresh_tree()
	_refresh_requirements()
	_refresh_warnings()
	_refresh_visuals()


## Shows the fields of the selected role and nothing else. The old panel showed
## every field of every kind and hid them behind conditions; that is what made
## the model look bigger than it is.
func _refresh_inspector() -> void:
	var area := _selected_area()
	var anchor := _selected_anchor()
	_suppress_ui_events = true
	_inspector_body.visible = area != null or anchor != null
	if area == null and anchor == null:
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
			ZoneAreaRecord.ROLE_REGION, ZoneAreaRecord.ROLE_ACCESS], area.role,
			func(r: StringName) -> String: return ZoneAreaRecord.role_display_name(r))
		_function_row.visible = not area.is_access()
		_fill_function_option(_inspector_function_option,
			ZoneFunctionCatalog.for_area_role(area.role), area.function)
		_update_pack_label(_inspector_pack_label, area.function, false)
		_build_property_rows(area)
		_access_row.visible = area.is_access()
		if area.is_access():
			_build_access_checkboxes(area.deny, func(list: Array[StringName]) -> void:
				area.deny = list)
		_clear_container(_anchor_props)
	else:
		_inspector_title.text = "%s %s" % [_role_glyph(anchor.role), anchor.id]
		_id_edit.text = String(anchor.id)
		_name_edit.text = ""
		_name_edit.editable = false
		_fill_role_option(_inspector_role_option, ZoneAnchorRecord.BUILDING_ROLES, anchor.role,
			func(r: StringName) -> String: return ZoneAnchorRecord.role_display_name(r))
		_function_row.visible = anchor.is_slot()
		if anchor.is_slot():
			_fill_function_option(_inspector_function_option,
				ZoneFunctionCatalog.activities(), anchor.activity)
			_update_pack_label(_inspector_pack_label, anchor.activity, false)
		_clear_container(_props_container)
		_access_row.visible = anchor.is_door()
		if anchor.is_door():
			_build_access_checkboxes(anchor.deny, func(list: Array[StringName]) -> void:
				anchor.deny = list)
		_build_anchor_rows(anchor)
	_suppress_ui_events = false


func _role_glyph(role: StringName) -> String:
	return "▽" if role == ZoneAnchorRecord.ROLE_DOOR else "◆"


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
func _build_property_rows(area: ZoneAreaRecord) -> void:
	_clear_container(_props_container)
	for descriptor in ZoneFunctionCatalog.property_schema(area.function):
		var key := String(descriptor.get("key", ""))
		if key.is_empty():
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = String(descriptor.get("label", key))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var value: Variant = area.properties.get(key, descriptor.get("default", ""))
		match String(descriptor.get("type", "string")):
			"int":
				var spin := SpinBox.new()
				spin.min_value = float(descriptor.get("min", 0))
				spin.max_value = float(descriptor.get("max", 999))
				spin.value = float(value)
				spin.value_changed.connect(func(v: float) -> void:
					area.properties[key] = int(v)
					_editor.mark_dirty())
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
					area.properties[key] = String(option.get_item_metadata(index))
					_editor.mark_dirty())
				row.add_child(option)
			_:
				var edit := LineEdit.new()
				edit.text = String(value)
				edit.custom_minimum_size = Vector2(120, 0)
				edit.text_changed.connect(func(text: String) -> void:
					area.properties[key] = text
					_editor.mark_dirty())
				row.add_child(edit)
		_props_container.add_child(row)


func _build_anchor_rows(anchor: ZoneAnchorRecord) -> void:
	_clear_container(_anchor_props)
	_add_anchor_row("Поворот", _make_spin(0.0, 359.0, anchor.facing, 15.0, func(v: float) -> void:
		anchor.facing = v
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


func _build_access_checkboxes(current: Array[StringName], on_changed: Callable) -> void:
	_clear_container(_access_container)
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
		_access_container.add_child(box)


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
		if new_id != area.id and _editor.blueprint.area_by_id(new_id) != null:
			_editor.set_status("Идентификатор «%s» уже занят." % new_id)
			return
		# References follow the rename; a dangling owner is not an option.
		for anchor in _editor.blueprint.anchors:
			if anchor.owner_id == area.id:
				anchor.owner_id = new_id
		for fixture in _editor.blueprint.fixtures:
			if fixture.owner_zone_id == area.id:
				fixture.owner_zone_id = new_id
		for decor_object in _editor.blueprint.objects:
			if decor_object.owner_zone_id == area.id:
				decor_object.owner_zone_id = new_id
		area.id = new_id
		_selected_area_id = new_id
	else:
		var anchor := _selected_anchor()
		if anchor == null:
			return
		if new_id != anchor.id and _anchor_by_id(new_id) != null:
			_editor.set_status("Идентификатор «%s» уже занят." % new_id)
			return
		for other in _editor.blueprint.anchors:
			if other.is_queue() and other.target_id == anchor.id:
				other.target_id = new_id
		anchor.id = new_id
		_selected_anchor_id = new_id
	_editor.mark_dirty()
	_refresh_all()


func _on_name_changed(text: String) -> void:
	if _suppress_ui_events:
		return
	var area := _selected_area()
	if area == null:
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
		area.role = role
		if area.is_access():
			area.function = &""
			area.properties.clear()
	else:
		var anchor := _selected_anchor()
		if anchor == null:
			return
		anchor.role = role
	_editor.mark_dirty()
	_refresh_all()


func _on_inspector_function_selected(index: int) -> void:
	if _suppress_ui_events:
		return
	var function_id: StringName = _inspector_function_option.get_item_metadata(index)
	var area := _selected_area()
	if area != null:
		area.function = function_id
		# Defaults come from the pack, so a freshly picked function is complete
		# instead of starting as an empty dictionary the author must guess at.
		var defaults := ZoneFunctionCatalog.default_properties(function_id)
		for key in defaults:
			if not area.properties.has(key):
				area.properties[key] = defaults[key]
	else:
		var anchor := _selected_anchor()
		if anchor == null:
			return
		anchor.activity = function_id
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
	for area in _editor.blueprint.areas:
		var item := _zone_tree.create_item(root)
		item.set_text(0, "▣ %s" % area.display_name())
		item.set_metadata(0, {"kind": "area", "id": area.id})
		if area.is_access():
			item.set_custom_color(0, ACCESS_COLOR)
		if area.id == _selected_area_id:
			selected_item = item
		for anchor in _editor.blueprint.anchors_of(area.id):
			var child := _zone_tree.create_item(item)
			child.set_text(0, "%s %s" % [_role_glyph(anchor.role), anchor.id])
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
			child.set_text(0, "%s %s" % [_role_glyph(anchor.role), anchor.id])
			child.set_metadata(0, {"kind": "anchor", "id": anchor.id})
			if anchor.id == _selected_anchor_id:
				selected_item = child
	if selected_item != null:
		selected_item.select(0)


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
	else:
		_selected_anchor_id = meta["id"]
		_selected_area_id = &""
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
	if _warnings_label == null:
		return
	var warnings: Array[String] = _editor.blueprint.validation_warnings()
	_warnings_label.text = "\n".join(warnings)
	_warnings_label.visible = not warnings.is_empty()


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
	var show_access: bool = _show_access_check != null and _show_access_check.button_pressed
	var audience: StringName = &""
	if show_access and _access_audience_option.selected >= 0:
		audience = _access_audience_option.get_item_metadata(_access_audience_option.selected)
	var color_index := 0
	for area in _editor.blueprint.areas:
		var color := ACCESS_COLOR
		var height := 0.04
		if not area.is_access():
			color = AREA_COLORS[color_index % AREA_COLORS.size()]
			color_index += 1
		elif show_access:
			# With the overlay on, only what actually blocks the chosen audience
			# is painted — otherwise every overlay looks equally forbidding.
			if area.permits(audience):
				continue
			height = 0.12
		if area.id == _selected_area_id:
			color = color.lerp(SELECTION_COLOR, 0.5)
		for cell in area.footprint_cells():
			_add_marker(Vector3(cell.x + 0.5, float(area.y_min), cell.y + 0.5), color,
				Vector3(0.94, height, 0.94), true)
	for anchor in _editor.blueprint.anchors:
		var style: Dictionary = ANCHOR_STYLE.get(anchor.role, ANCHOR_STYLE[&"poi"])
		var color: Color = style["color"]
		if anchor.id == _selected_anchor_id:
			color = color.lerp(SELECTION_COLOR, 0.6)
		_add_marker(anchor.pos, color, style["size"],
			anchor.role == ZoneAnchorRecord.ROLE_STORAGE, anchor.facing)


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
