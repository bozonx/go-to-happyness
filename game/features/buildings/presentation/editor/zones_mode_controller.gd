class_name ZonesModeController
extends Node

## Zones mode of the building editor (design §3.3): creates and edits the
## `place_zones[]` and `zone_anchors[]` of a blueprint.
##
## Lives as a child of BuildingEditor and owns everything zones-specific — the
## zone panel, the cell/anchor tools, the 3D zone markers — so the editor script
## only routes input and mode switching here.

const PlaceZoneRecordScript = preload("res://game/features/buildings/domain/editor/place_zone_record.gd")
const ZoneAnchorRecordScript = preload("res://game/features/buildings/domain/editor/zone_anchor_record.gd")
const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")
const ZoneRequirementsScript = preload("res://game/features/buildings/domain/editor/zone_requirements.gd")

const ZONE_COLORS: Array[Color] = [
	Color(0.35, 0.75, 1.0), Color(1.0, 0.7, 0.3), Color(0.6, 1.0, 0.5),
	Color(1.0, 0.5, 0.8), Color(0.8, 0.8, 0.4), Color(0.5, 0.9, 0.9),
]

var _editor: Node = null
var _zones_visual_root: Node3D = null

# Zones panel UI
var _zones_panel: PanelContainer = null
var _zone_option: OptionButton = null
var _add_place_btn: Button = null
var _del_place_btn: Button = null
var _zone_id_edit: LineEdit = null
var _zone_name_edit: LineEdit = null
var _zone_kind_option: OptionButton = null
var _zone_subtype_row: VBoxContainer = null
var _zone_subtype_option: OptionButton = null
var _zone_profession_option: OptionButton = null
var _zone_workers_spin: SpinBox = null
var _zone_info_label: Label = null
var _zone_req_checklist: VBoxContainer = null
var _zone_req_empty_label: Label = null
var _anchor_family_option: OptionButton = null
var _anchor_role_option: OptionButton = null
var _anchor_world_check: CheckBox = null
var _zone_marker_yaw_spin: SpinBox = null
var _zone_capacity_spin: SpinBox = null
var _tool_cell_btn: Button = null
var _tool_anchor_btn: Button = null
var _clear_cells_btn: Button = null
var _clear_anchors_btn: Button = null
var _tool_buttons: Dictionary = {}

# Zones-mode state
var _selected_place_index: int = -1
## &"cell" | &"anchor" — what a grid click does.
var _armed_tool: StringName = &"cell"
var _anchor_family: StringName = ZoneAnchorRecordScript.FAMILY_OCCUPANCY
var _anchor_role: StringName = ZoneAnchorRecordScript.ROLE_WORK
var _zone_material_cache: Dictionary = {}

# Drag-paint state for cell painting.
var _painting: bool = false
var _last_paint_cell: Vector3i = Vector3i.ZERO


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(editor: Node) -> void:
	_editor = editor
	name = "ZonesModeController"

	_zones_panel = editor.get_node("%ZonesPanel")
	_zone_option = editor.get_node("%ZoneOption")
	_add_place_btn = editor.get_node("%AddPlaceBtn")
	_del_place_btn = editor.get_node("%DelPlaceBtn")
	_zone_id_edit = editor.get_node("%ZoneIdEdit")
	_zone_name_edit = editor.get_node("%ZoneNameEdit")
	_zone_kind_option = editor.get_node("%ZoneKindOption")
	_zone_subtype_row = editor.get_node("%ZoneSubtypeRow")
	_zone_subtype_option = editor.get_node("%ZoneSubtypeOption")
	_zone_profession_option = editor.get_node("%ZoneProfessionOption")
	_zone_workers_spin = editor.get_node("%ZoneWorkersSpin")
	_zone_info_label = editor.get_node("%ZoneInfoLabel")
	_zone_req_checklist = editor.get_node("%ZoneReqChecklist")
	_zone_req_empty_label = editor.get_node("%ZoneReqEmptyLabel")
	_anchor_family_option = editor.get_node("%AnchorFamilyOption")
	_anchor_role_option = editor.get_node("%AnchorRoleOption")
	_anchor_world_check = editor.get_node("%AnchorWorldCheck")
	_zone_marker_yaw_spin = editor.get_node("%ZoneMarkerYawSpin")
	_zone_capacity_spin = editor.get_node("%ZoneCapacitySpin")
	_tool_cell_btn = editor.get_node("%ToolCellBtn")
	_tool_anchor_btn = editor.get_node("%ToolAnchorBtn")
	_clear_cells_btn = editor.get_node("%ClearCellsBtn")
	_clear_anchors_btn = editor.get_node("%ClearAnchorsBtn")
	_zones_visual_root = editor.get_node("%ZonesVisual")

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


# ---------------------------------------------------------------------------
# Mode lifecycle
# ---------------------------------------------------------------------------

func activate() -> void:
	_zones_panel.visible = true
	_refresh_zone_visuals()
	_refresh_zone_requirements_checklist()
	_editor.set_status("Режим зон: создайте зону и расставьте якоря работы / поддоны.")


func deactivate() -> void:
	_zones_panel.visible = false
	_painting = false
	_clear_zone_visuals()


func is_active() -> bool:
	return _zones_panel != null and _zones_panel.visible


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

## Returns true when the mouse button was consumed by zones mode.
func handle_mouse_button(event: InputEventMouseButton) -> bool:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if event.pressed:
		if _editor.is_pointer_over_ui():
			return false
		_place_zone_marker_at_cursor()
		_painting = _armed_tool == &"cell"
		_last_paint_cell = _editor.cursor_cell
		return true
	_painting = false
	return true


func on_mouse_motion(_event: InputEventMouseMotion) -> void:
	if not _painting:
		return
	_editor.update_cursor()
	if _editor.cursor_valid and _armed_tool == &"cell":
		_paint_zone_line(_last_paint_cell, _editor.cursor_cell)
		_last_paint_cell = _editor.cursor_cell


## Returns true when the key was consumed by zones mode.
func handle_key(_event: InputEventKey) -> bool:
	return false


func is_painting() -> bool:
	return _painting


func process(_delta: float) -> void:
	pass


func refresh_ghost() -> void:
	# Zones mode has no placement ghost; the editor's ghost is hidden.
	pass


func on_layer_changed() -> void:
	pass


# ---------------------------------------------------------------------------
# Blueprint lifecycle — called by the editor after load/new.
# ---------------------------------------------------------------------------

func on_blueprint_loaded() -> void:
	_selected_place_index = 0 if not _editor.blueprint.place_zones.is_empty() else -1
	_rebuild_place_option()
	_refresh_zone_visuals()


func on_blueprint_changed() -> void:
	_selected_place_index = -1
	_rebuild_place_option()
	_clear_zone_visuals()


func on_blueprint_created() -> void:
	_selected_place_index = -1
	_rebuild_place_option()
	_refresh_zone_visuals()


# ---------------------------------------------------------------------------
# Zone management
# ---------------------------------------------------------------------------

func current_place() -> PlaceZoneRecord:
	if _selected_place_index < 0 or _selected_place_index >= _editor.blueprint.place_zones.size():
		return null
	return _editor.blueprint.place_zones[_selected_place_index]


func _add_place() -> void:
	var place := PlaceZoneRecordScript.new()
	var next_index := 1
	var existing_ids: Array = _editor.blueprint.place_zones.map(func(existing): return existing.zone_id)
	while StringName("place_%d" % next_index) in existing_ids:
		next_index += 1
	place.zone_id = StringName("place_%d" % next_index)
	place.zone_name = "Место %d" % (_editor.blueprint.place_zones.size() + 1)
	_editor.blueprint.place_zones.append(place)
	_selected_place_index = _editor.blueprint.place_zones.size() - 1
	_editor.mark_dirty()
	_editor.update_fallback_display()
	_rebuild_place_option()
	_refresh_place_panel_fields()
	_refresh_zone_visuals()
	_editor.set_status("Зона места создана. Задайте назначение и обведите ячейки.")


func _delete_place() -> void:
	var place := current_place()
	if place == null:
		return
	var deleted_zone_id := place.zone_id
	var kept: Array[ZoneAnchorRecord] = []
	for anchor in _editor.blueprint.zone_anchors:
		if anchor.owner_zone_id != deleted_zone_id:
			kept.append(anchor)
	_editor.blueprint.zone_anchors = kept
	_editor.blueprint.place_zones.remove_at(_selected_place_index)
	_selected_place_index = mini(_selected_place_index, _editor.blueprint.place_zones.size() - 1)
	_editor.mark_dirty()
	_editor.update_fallback_display()
	_rebuild_place_option()
	_refresh_place_panel_fields()
	_refresh_zone_visuals()
	# Notify decor mode so it can clear owner_zone_id references.
	var decor = _editor.decor_mode
	if decor != null and decor.is_active():
		decor.on_zone_deleted(deleted_zone_id)


func _rebuild_place_option() -> void:
	if _zone_option == null:
		return
	_zone_option.clear()
	for i in _editor.blueprint.place_zones.size():
		var place: PlaceZoneRecord = _editor.blueprint.place_zones[i]
		_zone_option.add_item("%s" % place.zone_name)
	if _selected_place_index >= 0 and _selected_place_index < _editor.blueprint.place_zones.size():
		_zone_option.select(_selected_place_index)
	_refresh_place_panel_fields()


func _on_place_option_selected(index: int) -> void:
	_selected_place_index = index
	_refresh_place_panel_fields()
	_refresh_zone_visuals()


func _refresh_place_panel_fields() -> void:
	var place := current_place()
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
	var place := current_place()
	if place == null:
		return
	var owned := 0
	var trays := 0
	var routing := 0
	var world := 0
	for anchor in _editor.blueprint.zone_anchors:
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
	_refresh_zone_requirements_checklist()


## Auto-creates required runtime fixtures for a zone when its kind/profession
## changes. Only creates fixtures for capabilities backed by a runtime schema
## (is_runtime_capability). Non-runtime caps (bed, storage_*) are shown in the
## checklist but not auto-created. Does not duplicate existing fixtures that
## already satisfy the requirement.
func _ensure_zone_fixtures(zone: PlaceZoneRecordScript) -> void:
	if _editor.blueprint == null or zone == null:
		return
	var required := ZoneRequirementsScript.required_capabilities_for_zone(zone)
	if required.is_empty():
		return
	# Collect capabilities already provided by fixtures assigned to this zone
	# or building-wide.
	var existing_caps: Array[StringName] = []
	for fixture in _editor.blueprint.fixtures:
		if fixture.owner_zone_id == zone.zone_id or fixture.owner_zone_id == &"":
			existing_caps.append_array(fixture.capabilities)
	for cap in required:
		if cap in existing_caps:
			continue
		if not ZoneRequirementsScript.is_runtime_capability(cap):
			continue
		# Only fire_source has a runtime schema in Phase 2B.
		if cap == FixtureDefinitionScript.CAP_FIRE_SOURCE:
			var fixture := FixtureDefinitionScript.new()
			fixture.id = StringName("%s_%s" % [String(zone.zone_id), String(cap)])
			fixture.capabilities = [cap]
			fixture.owner_zone_id = zone.zone_id
			fixture.runtime_defaults = {"lit": true, "fuel": 4, "fuel_capacity": 8}
			_editor.blueprint.fixtures.append(fixture)
			_editor.mark_dirty()


func _refresh_zone_requirements_checklist() -> void:
	if _zone_req_checklist == null:
		return
	for child in _zone_req_checklist.get_children():
		child.queue_free()
	if _editor.blueprint == null:
		return
	var checklist: Array[Dictionary] = _editor.blueprint.zone_requirements_checklist()
	if checklist.is_empty():
		if _zone_req_empty_label != null:
			_zone_req_empty_label.visible = true
		return
	if _zone_req_empty_label != null:
		_zone_req_empty_label.visible = false
	for entry in checklist:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var mark := "✓" if entry.satisfied else "✗"
		var color := Color(0.4, 0.8, 0.4) if entry.satisfied else Color(0.9, 0.5, 0.4)
		if not entry.is_runtime and not entry.satisfied:
			color = Color(0.7, 0.65, 0.4)
		label.text = "%s %s — %s" % [mark, entry.zone_name, entry.label]
		label.add_theme_color_override("font_color", color)
		label.add_theme_font_size_override("font_size", 12)
		_zone_req_checklist.add_child(label)


func _on_place_name_changed(text: String) -> void:
	var place := current_place()
	if place == null:
		return
	place.zone_name = text
	_editor.mark_dirty()
	if _zone_option != null and _selected_place_index >= 0:
		_zone_option.set_item_text(_selected_place_index, text)


func _on_place_id_changed(text: String) -> void:
	var place := current_place()
	if place != null:
		var cleaned := text.strip_edges().to_lower()
		place.zone_id = StringName(cleaned)
		_editor.mark_dirty()
		if _zone_id_edit != null:
			var valid := not cleaned.is_empty() and BuildingBlueprint._valid_id(cleaned)
			if valid:
				_zone_id_edit.remove_theme_color_override("font_color")
			else:
				_zone_id_edit.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))


func _on_place_kind_selected(index: int) -> void:
	var place := current_place()
	if place == null:
		return
	place.kind = _zone_kind_option.get_item_metadata(index)
	var subtypes := PlaceZoneRecordScript.subtypes_for_kind(place.kind)
	place.subtype = subtypes[0] if not subtypes.is_empty() else &""
	_editor.mark_dirty()
	_rebuild_subtype_options()
	_ensure_zone_fixtures(place)
	_update_zone_info()
	_editor.update_fallback_display()


func _on_place_subtype_selected(index: int) -> void:
	var place := current_place()
	if place == null:
		return
	place.subtype = _zone_subtype_option.get_item_metadata(index)
	_editor.mark_dirty()


func _rebuild_subtype_options() -> void:
	if _zone_subtype_option == null:
		return
	var place := current_place()
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
	var place := current_place()
	if place == null:
		return
	place.profession = _zone_profession_option.get_item_metadata(index)
	_editor.mark_dirty()
	_ensure_zone_fixtures(place)
	_update_zone_info()
	_editor.update_fallback_display()


func _on_place_workers_changed(value: float) -> void:
	var place := current_place()
	if place == null:
		return
	place.max_workers = int(value)
	_editor.mark_dirty()


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
	var place := current_place()
	if place == null:
		return
	place.cells.clear()
	_editor.mark_dirty()
	_refresh_zone_visuals()
	_update_zone_info()


func _clear_place_anchors() -> void:
	var place := current_place()
	if place == null:
		return
	var kept: Array[ZoneAnchorRecord] = []
	for anchor in _editor.blueprint.zone_anchors:
		if anchor.owner_zone_id != place.zone_id:
			kept.append(anchor)
	_editor.blueprint.zone_anchors = kept
	_editor.mark_dirty()
	_refresh_zone_visuals()
	_update_zone_info()


func _next_anchor_id() -> StringName:
	var next_index := 1
	var existing: Array = _editor.blueprint.zone_anchors.map(func(a): return a.anchor_id)
	while StringName("anchor_%d" % next_index) in existing:
		next_index += 1
	return StringName("anchor_%d" % next_index)


func _place_zone_marker_at_cursor() -> void:
	if not _editor.cursor_valid or not _editor.is_cell_in_bounds(_editor.cursor_cell):
		return
	if _armed_tool == &"cell":
		var place := current_place()
		if place == null:
			_editor.set_status("Сначала создайте зону места (＋).")
			return
		var idx := place.cells.find(_editor.cursor_cell)
		if idx >= 0:
			place.cells.remove_at(idx)
		else:
			place.cells.append(_editor.cursor_cell)
		_editor.mark_dirty()
		_refresh_zone_visuals()
		_update_zone_info()
		return
	var owner_id: StringName = &""
	var world := _anchor_world_check != null and _anchor_world_check.button_pressed
	if not world:
		var place := current_place()
		if place == null:
			_editor.set_status("Создайте зону места или включите «мировой якорь».")
			return
		owner_id = place.zone_id
	var anchor := ZoneAnchorRecordScript.new()
	anchor.anchor_id = _next_anchor_id()
	anchor.owner_zone_id = owner_id
	anchor.role = _anchor_role
	anchor.pos = Vector3(_editor.cursor_cell) + Vector3(0.5, 0.0, 0.5)
	if _zone_marker_yaw_spin != null:
		anchor.rot = Vector3(0.0, _zone_marker_yaw_spin.value, 0.0)
	if _zone_capacity_spin != null:
		anchor.capacity = int(_zone_capacity_spin.value)
	_editor.blueprint.zone_anchors.append(anchor)
	_editor.mark_dirty()
	_refresh_zone_visuals()
	_update_zone_info()


func _paint_zone_line(from_cell: Vector3i, to_cell: Vector3i) -> void:
	var zone := current_place()
	if zone == null:
		return
	var steps := maxi(absi(to_cell.x - from_cell.x), absi(to_cell.z - from_cell.z))
	var changed := false
	for step in range(steps + 1):
		var t := float(step) / float(maxi(1, steps))
		var cell := Vector3i(
			roundi(lerpf(from_cell.x, to_cell.x, t)),
			_editor.active_layer,
			roundi(lerpf(from_cell.z, to_cell.z, t)))
		if not _editor.is_cell_in_bounds(cell):
			continue
		if cell not in zone.cells:
			zone.cells.append(cell)
			changed = true
	if changed:
		_editor.mark_dirty()
		_refresh_zone_visuals()
		_update_zone_info()


# ---------------------------------------------------------------------------
# Zone visuals
# ---------------------------------------------------------------------------

func _clear_zone_visuals() -> void:
	if _zones_visual_root == null:
		return
	for child in _zones_visual_root.get_children():
		child.queue_free()


func _refresh_zone_visuals() -> void:
	if _zones_visual_root == null:
		return
	_clear_zone_visuals()
	if not is_active():
		return
	for i in _editor.blueprint.place_zones.size():
		var place: PlaceZoneRecord = _editor.blueprint.place_zones[i]
		var color := ZONE_COLORS[i % ZONE_COLORS.size()]
		for cell in place.cells:
			_add_zone_marker(Vector3(cell) + Vector3(0.5, 0.0, 0.5), color, Vector3(0.9, 0.04, 0.9), true)
	for anchor in _editor.blueprint.zone_anchors:
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
