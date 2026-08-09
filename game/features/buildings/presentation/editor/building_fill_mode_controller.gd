class_name BuildingFillModeController
extends Node3D

## Fill mode of the building editor (design §3.3): places, selects, moves and
## configures the `objects[]` of a blueprint.
##
## Lives as a child of BuildingEditor and owns everything fill-specific — the
## spawned instances, the placement ghost and the selection marker — so the
## editor script only routes input and mode switching here.  History belongs to
## BuildingEditor, where it remains chronological across every mode.
##
## One contextual gesture owns the left mouse button: it drops the selected
## catalog asset on empty ground, or selects and drags an existing object.
## `Ctrl` on that click adds to the selection, `Shift` is the eyedropper and
## `Shift+RMB` erases — the same three gestures the map editor uses.

var current_group: StringName = &""  ## empty = all groups
var current_category: StringName = &"camping"
var current_asset_id: StringName = &""
## Смещение кисти: с ним объект ставится сразу подстроенным — пипетка забирает
## смещение образца вместе с остальными свойствами.
var current_offset: Vector3 = Vector3.ZERO
## Масштаб кисти — тоже часть образца, снятого пипеткой.
var current_scale: float = 1.0
var current_yaw_deg: float = 0.0
var current_pitch_deg: float = 0.0
var current_roll_deg: float = 0.0
var _brush_appearance: Dictionary = {}
## Primary selection: the object the inspector describes and drags follow.
var selected_object_id: String = ""
## Everything else selected alongside it. Transform edits apply to all of them;
## per-asset properties stay single-object work (design §7.4).
var additional_selected_ids: Array[String] = []

var _editor: Node = null
var _validator: RefCounted = null
var _nodes: Dictionary = {}  ## object id (String) -> Node3D
var _ghost: Node3D = null
var _ghost_asset_id: StringName = &""
var _ghost_material: StandardMaterial3D = null
var _selection_markers: Dictionary = {}  ## object id (String) -> MeshInstance3D
var _hover_marker: MeshInstance3D = null
var _hovered_object_id: String = ""
var _id_label: Label = null
var _asset_label: Label = null
var _badges_label: Label = null
var _zone_option: OptionButton = null
var _replace_btn: Button = null
var _dragging: bool = false
## Grab offset so dragging moves the object relative to where it was picked up.
var _drag_offset: Vector3 = Vector3.ZERO
var _drag_started: bool = false
var _placing_stroke: bool = false
var _last_placed_cell := Vector2i(-999999, -999999)
## Guards the inspector's own writes from re-entering as user edits.
var _syncing_ui: bool = false

var _panel: PanelContainer = null
var _inspector_panel: PanelContainer = null
var _toolbar: HBoxContainer = null
var _inspector_title: Label = null
var _object_list: EditorSearchableList = null
var _visible_object_ids: Array[String] = []
var _controls_vbox: EditorPropertyInspector = null
var _transform_inspector: EditorFillTransformInspector = null
var _pos_x_spin: SpinBox = null
var _pos_y_spin: SpinBox = null
var _pos_z_spin: SpinBox = null
var _yaw_spin: SpinBox = null
var _pitch_spin: SpinBox = null
var _roll_spin: SpinBox = null
var _scale_spin: SpinBox = null
var _toolbar_delete_btn: Button = null
var _layer_label: Label = null
var _collision_overlay_btn: Button = null
var _collision_overlay: Node3D = null
var _catalog_panel: EditorCatalogPanel = null
var _off_x_spin: SpinBox = null
var _off_y_spin: SpinBox = null
var _off_z_spin: SpinBox = null
var _zone_filter_option: OptionButton = null
var _zone_out_of_bounds_label: Label = null

# Fixture editor — delegated to FixtureEditorPanel
var _fixture_panel: RefCounted = null


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(editor: Node) -> void:
	_editor = editor
	_validator = FillPlacementValidator.new()
	name = "FillRoot"

	_panel = editor.get_node("%FillPanel")
	_inspector_panel = editor.get_node("%FillInspectorPanel")
	_toolbar = editor.get_node("%FillToolbar")
	_inspector_title = editor.get_node("%FillInspectorTitle")
	_id_label = editor.get_node("%FillIdLabel")
	_asset_label = editor.get_node("%FillAssetLabel")
	_zone_option = editor.get_node("%FillZoneOption")
	_badges_label = editor.get_node("%FillBadgesLabel")
	_zone_out_of_bounds_label = editor.get_node("%FillZoneWarningLabel")
	_zone_filter_option = editor.get_node("%FillZoneFilterOption")
	_object_list = editor.get_node("%FillObjectList")
	_controls_vbox = editor.get_node("%FillControlsVBox")
	_transform_inspector = editor.get_node("%FillTransformInspector")
	_pos_x_spin = _transform_inspector.pos_x_spin
	_pos_y_spin = _transform_inspector.height_spin
	_pos_z_spin = _transform_inspector.pos_z_spin
	_pitch_spin = _transform_inspector.pitch_spin
	_yaw_spin = _transform_inspector.yaw_spin
	_roll_spin = _transform_inspector.roll_spin
	_scale_spin = _transform_inspector.scale_spin
	_replace_btn = editor.get_node("%FillReplaceBtn")
	_toolbar_delete_btn = editor.get_node("%FillDeleteSelectionBtn")
	_layer_label = editor.get_node("%FillLayerLabel")
	_off_x_spin = _transform_inspector.off_x_spin
	_off_y_spin = _transform_inspector.off_y_spin
	_off_z_spin = _transform_inspector.off_z_spin

	# Fixture editor — delegated to FixtureEditorPanel
	_fixture_panel = FixtureEditorPanel.new()
	_fixture_panel.setup(editor)

	# Catalog panel — the shared widget, used directly: a subclass that only
	# forwarded `setup` to `super` was pure indirection.
	_catalog_panel = EditorCatalogPanel.new()
	_catalog_panel.setup(self, editor, WorldAssetDef.SCOPE_BUILDING)

	editor.get_node("%FillRotXBtn").pressed.connect(rotate_selection.bind("x", 1))
	editor.get_node("%FillRotYBtn").pressed.connect(rotate_selection.bind("y", 1))
	editor.get_node("%FillRotZBtn").pressed.connect(rotate_selection.bind("z", 1))
	editor.get_node("%FillLayerDownBtn").pressed.connect(func(): _editor.set_layer(_editor.active_layer - 1))
	editor.get_node("%FillLayerUpBtn").pressed.connect(func(): _editor.set_layer(_editor.active_layer + 1))
	_collision_overlay_btn = editor.get_node("%FillCollisionOverlayBtn")
	_collision_overlay = FillCollisionOverlay.new()
	_collision_overlay.name = "CollisionOverlay"
	add_child(_collision_overlay)
	_collision_overlay_btn.toggled.connect(_on_collision_overlay_toggled)

	_object_list.entry_selection_toggled.connect(_on_object_list_selection_toggled)
	_zone_option.item_selected.connect(_on_zone_selected)
	_zone_filter_option.item_selected.connect(_on_zone_filter_selected)
	_toolbar_delete_btn.pressed.connect(delete_selection)
	_replace_btn.pressed.connect(_replace_selected_object)
	_controls_vbox.property_committed.connect(_on_appearance_property_committed)
	_controls_vbox.property_reset_requested.connect(_on_appearance_property_reset)
	for spin: SpinBox in _transform_spins():
		spin.value_changed.connect(_on_transform_spin_changed)
	# Клетка и слой — целые; смещение — общий шаг обоих редакторов и предел в одну
	# клетку; поворот — общий шаг.
	for spin: SpinBox in [_off_x_spin, _off_y_spin, _off_z_spin]:
		spin.step = EditorFillConventions.OFFSET_STEP
		spin.min_value = -EditorFillConventions.MAX_OFFSET_CELLS
		spin.max_value = EditorFillConventions.MAX_OFFSET_CELLS
	_yaw_spin.step = EditorFillConventions.ROTATION_STEP_DEG
	_pitch_spin.step = EditorFillConventions.ROTATION_STEP_DEG
	_roll_spin.step = EditorFillConventions.ROTATION_STEP_DEG
	_scale_spin.step = EditorFillConventions.SCALE_STEP
	_transform_inspector.property_reset_requested.connect(_on_transform_reset_requested)

	current_category = WorldAssetCatalog.first_populated_category(current_category)
	_catalog_panel.activate()


func _on_transform_reset_requested(property_name: StringName) -> void:
	match property_name:
		EditorFillTransformInspector.HEIGHT:
			_pos_y_spin.value = 0.0
		EditorFillTransformInspector.OFFSET:
			reset_offset()
		EditorFillTransformInspector.ROTATION:
			reset_rotation()
		EditorFillTransformInspector.SCALE:
			reset_scale()


# ---------------------------------------------------------------------------
# Mode lifecycle
# ---------------------------------------------------------------------------

func activate() -> void:
	# Picks up `.tres` assets authored since the editor opened.
	WorldAssetCatalog.refresh()
	current_category = WorldAssetCatalog.first_populated_category(current_category)
	_catalog_panel.activate()
	_panel.visible = true
	_inspector_panel.visible = true
	_toolbar.visible = true
	rebuild_nodes()
	_refresh_zone_filter_options()
	_refresh_object_list()
	_refresh_inspector()
	_fixture_panel.refresh_fixture_ui()
	_update_layer_label()


func deactivate() -> void:
	_panel.visible = false
	_inspector_panel.visible = false
	_toolbar.visible = false
	_dragging = false
	_hide_ghost()
	_update_selection_marker()
	_collision_overlay.clear()


func is_active() -> bool:
	return _editor != null and _panel != null and _panel.visible


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func on_left_pressed(additive: bool = false) -> void:
	_placing_stroke = false
	if not _editor.cursor_valid:
		return
	var hit: Vector3 = _editor.cursor_hit_pos
	var picked := pick_object_at(hit)
	if not picked.is_empty():
		if additive:
			toggle_object_selection(picked)
			return
		_select_for_drag(picked, hit)
		return
	if additive:
		return
	if current_asset_id.is_empty():
		select_object("")
		_editor.set_status("Выберите ассет для размещения или объект для редактирования.")
		return
	var count_before: int = _editor.blueprint.objects.size()
	_place_or_select_at(hit)
	_placing_stroke = _editor.blueprint.objects.size() > count_before
	if _placing_stroke:
		selected_object_id = ""
	_last_placed_cell = occupied_cells(snapped_position(hit), current_asset_id, current_scale, current_yaw_deg).position


func on_left_released() -> void:
	if _drag_started and _editor != null:
		_editor.end_history_group()
	_dragging = false
	_drag_started = false
	_placing_stroke = false
	refresh_hover()


func erase_at_cursor() -> void:
	if not _editor.cursor_valid:
		return
	var target := pick_object_at(_editor.cursor_hit_pos)
	if target.is_empty():
		_editor.set_status("Под курсором нет объекта наполнения.")
		return
	_erase_object(target)
	_editor.set_status("Объект удалён.")
	refresh_hover()


## Shift+LMB: use the object below the cursor as the next placement brush.
func pick_asset_at_cursor() -> bool:
	if not _editor.cursor_valid:
		return false
	var object_id := pick_object_at(_editor.cursor_hit_pos)
	var record := find_record(object_id)
	if record == null:
		_editor.set_status("Под курсором нет объекта для пипетки.")
		return false
	_catalog_panel.select_asset(record.asset_id)
	current_pitch_deg = record.rot.x
	current_yaw_deg = record.rot.y
	current_roll_deg = record.rot.z
	current_offset = record.offset
	current_scale = record.scale.x
	_brush_appearance = record.appearance.duplicate(true)
	select_object("")
	_editor.set_status("Пипетка: «%s» со всеми свойствами. Следующий клик поставит такой же." % WorldAssetCatalog.get_asset(record.asset_id).name)
	refresh_ghost()
	return true


func _select_for_drag(object_id: String, hit: Vector3) -> void:
	select_object(object_id)
	var record := find_record(object_id)
	if record == null:
		return
	_drag_offset = record.anchor_pos() - Vector3(hit.x, record.anchor_pos().y, hit.z)
	_dragging = true
	_drag_started = false


func on_drag() -> void:
	if _placing_stroke and _editor.cursor_valid:
		var position := snapped_position(_editor.cursor_hit_pos, current_asset_id, current_scale, current_yaw_deg)
		var cell := occupied_cells(position, current_asset_id, current_scale, current_yaw_deg).position
		if cell != _last_placed_cell:
			var delta := cell - _last_placed_cell
			var steps := maxi(absi(delta.x), absi(delta.y))
			for index in range(1, steps + 1):
				var sample := Vector2i(roundi(lerpf(_last_placed_cell.x, cell.x, float(index) / steps)), roundi(lerpf(_last_placed_cell.y, cell.y, float(index) / steps)))
				var sample_position := position + Vector3(sample.x - cell.x, 0.0, sample.y - cell.y)
				if pick_object_at(sample_position).is_empty():
					_place_at(sample_position)
					selected_object_id = ""
			_last_placed_cell = cell
		return
	if not _dragging or not _editor.cursor_valid:
		return
	var record := find_record(selected_object_id)
	if record == null:
		return
	# One drag is one step of undo, however long it lasts and however many motion
	# events it produces.
	if not _drag_started:
		_editor.begin_history_group("fill_drag/%s" % record.id)
		_drag_started = true
	var hit: Vector3 = _editor.cursor_hit_pos
	var candidate := snapped_position(hit + _drag_offset, record.asset_id, record.scale.x, record.rot.y)
	if candidate.is_equal_approx(record.anchor_pos()):
		return
	# Перетаскивание двигает якорь по клеткам; авторское смещение едет вместе с
	# объектом и не сбрасывается.
	var shift := candidate - record.anchor_pos()
	# Everything selected moves together: dragging one of five chairs must not
	# silently leave the other four behind.
	var records := selected_records()
	var ignored_ids: Array = selected_object_ids()
	for target: FillObjectRecord in records:
		var next_anchor := target.anchor_pos() + shift
		if not _is_valid_transform(
				next_anchor, target.rot, target.scale, target.asset_id, target.id, ignored_ids):
			return
	for target: FillObjectRecord in records:
		target.pos += shift
		_apply_transform_to_node(target)
	_editor.mark_dirty()
	_sync_transform_fields(record)
	_update_selection_marker()


## Returns true when the key was consumed by fill mode. Ctrl+Z / Ctrl+Y never
## arrive here: `BuildingEditor` owns the blueprint-wide history and handles them
## before delegating.
func handle_key(event: InputEventKey) -> bool:
	if event.ctrl_pressed:
		return false
	match event.keycode:
		KEY_P:
			pick_asset_at_cursor()
			return true
		KEY_C, KEY_R:
			rotate_selection("y", -1 if event.shift_pressed else 1)
			return true
		KEY_X:
			rotate_selection("x", -1 if event.shift_pressed else 1)
			return true
		KEY_Z:
			rotate_selection("z", -1 if event.shift_pressed else 1)
			return true
		KEY_ESCAPE:
			cancel_current_action()
			return true
		KEY_DELETE:
			delete_selection()
			return true
	return false

# ---------------------------------------------------------------------------
# Placement maths — delegated to FillPlacementValidator
# ---------------------------------------------------------------------------

## Точка, в которую сядет якорь объекта: центр прямоугольника целых клеток,
## который он занимает.
func snapped_position(raw_hit: Vector3, asset_id: StringName = current_asset_id, scale: float = 1.0, yaw_deg: float = NAN) -> Vector3:
	var yaw := current_yaw_deg if is_nan(yaw_deg) else yaw_deg
	return _validator.snapped_position(raw_hit, _editor.active_layer, asset_id, scale, yaw)


## Клетки, которые займёт объект — для подсветки и для проверки занятости.
func occupied_cells(anchor: Vector3, asset_id: StringName, scale: float = 1.0, yaw_deg: float = 0.0) -> Rect2i:
	return _validator.occupied_cells(anchor, asset_id, scale, yaw_deg)


func _is_in_bounds(pos: Vector3, asset_id: StringName = current_asset_id, scale: Vector3 = Vector3.ONE) -> bool:
	return _validator.is_in_bounds(pos, _editor.blueprint, asset_id, scale)


func _is_collision_conflict(pos: Vector3, asset_id: StringName = current_asset_id, scale: Vector3 = Vector3.ONE, exclude_id: String = "") -> bool:
	return _validator.is_collision_conflict(pos, _editor.blueprint, asset_id, scale, exclude_id)


func _is_valid_transform(
	pos: Vector3,
	rot: Vector3,
	scale: Vector3,
	asset_id: StringName,
	exclude_id: String = "",
	ignored_ids: Array = [],
) -> bool:
	return _validator.is_valid_transform(
		pos, rot, scale, asset_id, _editor.blueprint, exclude_id, ignored_ids)


func _compute_ghost_state(pos: Vector3) -> int:
	var scale := Vector3.ONE * current_scale
	var rotation := Vector3(current_pitch_deg, current_yaw_deg, current_roll_deg)
	if not _validator.is_in_bounds(
			pos, _editor.blueprint, current_asset_id, scale, current_yaw_deg):
		return FillPlacementValidator.GhostState.OUT_OF_BOUNDS
	if not _is_valid_transform(pos, rotation, scale, current_asset_id):
		return FillPlacementValidator.GhostState.INTERSECTION
	return FillPlacementValidator.GhostState.VALID


func _pick_objects_at(world_pos: Vector3) -> Array[String]:
	return _validator.pick_objects_at(world_pos, _editor.blueprint)


func pick_object_at(world_pos: Vector3) -> String:
	return _validator.pick_object_at(world_pos, _editor.blueprint)


func find_record(object_id: String) -> FillObjectRecord:
	return FillPlacementValidator.find_record_in(object_id, _editor.blueprint)


# ---------------------------------------------------------------------------
# Mutations
# ---------------------------------------------------------------------------

## A placement click that lands on occupied geometry selects the conflicting
## object where possible instead of silently stacking another instance inside it.
##
## The caller has already established that nothing is under the cursor itself;
## what this handles is the footprint of a neighbour reaching into the snapped
## position.
func _place_or_select_at(hit: Vector3) -> void:
	var position := snapped_position(hit, current_asset_id, current_scale)
	var asset := WorldAssetCatalog.get_asset(current_asset_id)
	if asset == null:
		_editor.set_status("Выберите ассет в каталоге наполнения.")
		return
	if not _is_valid_transform(position, Vector3(current_pitch_deg, current_yaw_deg, current_roll_deg), Vector3.ONE * current_scale, asset.id):
		# The hit can be near the edge of an object's footprint rather than inside
		# its pick radius. Select that conflicting object where possible, so the
		# click still has a useful result.
		var conflict := pick_object_at(position)
		if not conflict.is_empty():
			select_object(conflict)
			_editor.set_status("Выбран объект, занимающий это место.")
		else:
			_editor.set_status("Здесь нельзя разместить наполнение: место занято или вне границ здания.")
		return
	_place_at(position)


func _place_at(position: Vector3) -> void:
	var asset := WorldAssetCatalog.get_asset(current_asset_id)
	if asset == null:
		_editor.set_status("Выберите ассет в каталоге наполнения.")
		return
	# Keep the invariant at the mutation boundary too: UI input is not the only
	# caller of this method, and a red preview must never still create an overlap.
	if not _is_valid_transform(
			position,
			Vector3(current_pitch_deg, current_yaw_deg, current_roll_deg),
			Vector3.ONE * current_scale,
			asset.id,
	):
		_editor.set_status("Нельзя разместить наполнение поверх другого объекта.")
		return
	# `pos` — итог: якорь по клеткам плюс авторское смещение кисти. Клетки объекта
	# считаются от якоря, поэтому смещение не переселяет его к соседям.
	var record := FillObjectRecord.make(asset.id, position + current_offset, _next_object_suffix())
	record.offset = current_offset
	record.scale = Vector3.ONE * current_scale
	# Every axis the brush carries, not just yaw: the ghost was previewed with
	# all three, and dropping pitch/roll here made the placed object differ from
	# what the author saw.
	record.rot = Vector3(current_pitch_deg, current_yaw_deg, current_roll_deg)
	record.appearance = _brush_appearance.duplicate(true) if not _brush_appearance.is_empty() else asset.default_appearance()
	_editor.blueprint.objects.append(record)
	_spawn_node(record)
	_catalog_panel.add_recent_asset(asset.id)
	_editor.mark_dirty()
	_refresh_object_list()
	select_object(record.id)
	_editor.set_status("Поставлен «%s». Всего объектов: %d" % [asset.name, _editor.blueprint.objects.size()])


func _erase_object(object_id: String) -> void:
	# A fixture without a visual is valid 2A data. Clear the explicit reference
	# rather than leaving the blueprint unsaveable.
	_fixture_panel.clear_visual_references(object_id)
	for i in range(_editor.blueprint.objects.size() - 1, -1, -1):
		if _editor.blueprint.objects[i].id == object_id:
			_editor.blueprint.objects.remove_at(i)
			break
	_remove_node(object_id)
	_editor.mark_dirty()
	_refresh_object_list()
	if selected_object_id == object_id or object_id in additional_selected_ids:
		additional_selected_ids.erase(object_id)
		if selected_object_id == object_id:
			selected_object_id = additional_selected_ids.pop_front() if not additional_selected_ids.is_empty() else ""
		_after_selection_changed()
	if not _editor.blueprint.fixtures.is_empty():
		_fixture_panel.refresh_fixture_ui()


func delete_selection() -> void:
	var targets := selected_object_ids()
	if targets.is_empty():
		return
	# Deleting a selection is one action: one Ctrl+Z brings all of it back.
	_editor.begin_history_group("fill_delete")
	for object_id: String in targets:
		_erase_object(object_id)
	_editor.end_history_group()
	_editor.set_status("Объект удалён." if targets.size() == 1 else "Удалено объектов: %d." % targets.size())


## Rotation applies to every selected object and to the brush. The step is the
## shared one for both editors: an asset-specific step made the same key turn
## different objects by different amounts.
func rotate_selection(axis: String, direction: int) -> void:
	if axis not in ["x", "y", "z"]:
		push_warning("BuildingFillModeController: invalid rotation axis '%s'" % axis)
		return
	var records := selected_records()
	var ignored_ids: Array = selected_object_ids()
	var anchors: Dictionary = {}
	var rotations: Dictionary = {}
	var scales: Dictionary = {}
	for record: FillObjectRecord in records:
		var candidate := _rotated_vector(record.rot, axis, direction)
		if not _is_valid_transform(
				record.anchor_pos(), candidate, record.scale, record.asset_id, record.id, ignored_ids):
			_editor.set_status("Поворот не применён: итоговые клетки заняты или пересекают каркас.")
			return
		anchors[record.id] = record.anchor_pos()
		rotations[record.id] = candidate
		scales[record.id] = record.scale
	if not _proposed_fill_is_free(records, anchors, rotations, scales):
		_editor.set_status("Поворот не применён: выбранные объекты пересекутся друг с другом.")
		return
	for record: FillObjectRecord in records:
		record.rot = rotations[record.id]
		_apply_transform_to_node(record)
	# The brush follows only when it is not describing a rejected rotation: its
	# angle and the object's must not drift apart.
	if records.is_empty() or not rotations.is_empty():
		var brush := _rotated_vector(Vector3(current_pitch_deg, current_yaw_deg, current_roll_deg), axis, direction)
		current_pitch_deg = brush.x
		current_yaw_deg = brush.y
		current_roll_deg = brush.z
	if not rotations.is_empty():
		_editor.mark_dirty()
		var primary := find_record(selected_object_id)
		if primary != null:
			_sync_transform_fields(primary)
	refresh_ghost()


func _rotated_vector(rotation: Vector3, axis: String, direction: int) -> Vector3:
	var next := rotation
	match axis:
		"x":
			next.x = EditorFillConventions.rotated_by(rotation.x, direction)
		"y":
			next.y = EditorFillConventions.rotated_by(rotation.y, direction)
		"z":
			next.z = EditorFillConventions.rotated_by(rotation.z, direction)
	return next


## Reset buttons of the transform section. Each one resets its own field of every
## selected object, and the brush along with the rotation.
func reset_rotation() -> void:
	var records := selected_records()
	if records.is_empty():
		current_pitch_deg = 0.0
		current_yaw_deg = 0.0
		current_roll_deg = 0.0
	var ignored_ids: Array = selected_object_ids()
	var anchors: Dictionary = {}
	var rotations: Dictionary = {}
	var scales: Dictionary = {}
	for record: FillObjectRecord in records:
		if not _is_valid_transform(
				record.anchor_pos(), Vector3.ZERO, record.scale, record.asset_id, record.id, ignored_ids):
			_editor.set_status("Сброс поворота не применён: итоговые клетки заняты.")
			return
		anchors[record.id] = record.anchor_pos()
		rotations[record.id] = Vector3.ZERO
		scales[record.id] = record.scale
	if not _proposed_fill_is_free(records, anchors, rotations, scales):
		_editor.set_status("Сброс поворота не применён: выбранные объекты пересекутся.")
		return
	var changed := false
	for record: FillObjectRecord in records:
		if not record.rot.is_zero_approx():
			record.rot = Vector3.ZERO
			_apply_transform_to_node(record)
			changed = true
	_commit_transform_reset(changed, "Поворот сброшен.")
	if records.is_empty():
		_sync_brush_transform_fields()
	refresh_ghost()


## Drops the authored offset: the object sits exactly on the cells it owns. The
## cells themselves do not move — there is no "zero cell" to go back to.
func reset_offset() -> void:
	var records := selected_records()
	if records.is_empty():
		current_offset = Vector3.ZERO
	var changed := false
	for record: FillObjectRecord in records:
		if record.offset.is_zero_approx():
			continue
		record.pos = record.anchor_pos()
		record.offset = Vector3.ZERO
		_apply_transform_to_node(record)
		changed = true
	_commit_transform_reset(changed, "Смещение сброшено: объект стоит ровно по своим клеткам.")
	if records.is_empty():
		_sync_brush_transform_fields()
	refresh_ghost()


func reset_scale() -> void:
	var records := selected_records()
	if records.is_empty():
		current_scale = 1.0
	var ignored_ids: Array = selected_object_ids()
	var anchors: Dictionary = {}
	var rotations: Dictionary = {}
	var scales: Dictionary = {}
	for record: FillObjectRecord in records:
		if not _is_valid_transform(
				record.anchor_pos(), record.rot, Vector3.ONE, record.asset_id, record.id, ignored_ids):
			_editor.set_status("Сброс масштаба не применён: итоговые клетки заняты.")
			return
		anchors[record.id] = record.anchor_pos()
		rotations[record.id] = record.rot
		scales[record.id] = Vector3.ONE
	if not _proposed_fill_is_free(records, anchors, rotations, scales):
		_editor.set_status("Сброс масштаба не применён: выбранные объекты пересекутся.")
		return
	var changed := false
	for record: FillObjectRecord in records:
		if is_equal_approx(record.scale.x, 1.0):
			continue
		record.scale = Vector3.ONE
		_apply_transform_to_node(record)
		changed = true
	_commit_transform_reset(changed, "Масштаб сброшен.")
	if records.is_empty():
		_sync_brush_transform_fields()
	refresh_ghost()


func _commit_transform_reset(changed: bool, message: String) -> void:
	if not changed:
		return
	_editor.mark_dirty()
	var primary := find_record(selected_object_id)
	if primary != null:
		_sync_transform_fields(primary)
	_update_selection_marker()
	_editor.set_status(message)


func cancel_current_action() -> void:
	_dragging = false
	_drag_started = false
	if not selected_object_ids().is_empty():
		select_object("")
		_editor.set_status("Выделение снято.")
		return
	if not current_asset_id.is_empty():
		_catalog_panel.clear_asset_selection()
		_brush_appearance.clear()
		current_offset = Vector3.ZERO
		current_scale = 1.0
		_editor.set_status("Кисть наполнения сброшена.")
		return
	_editor.set_status("Ничего не выбрано.")


## Monotonic-enough suffix for generated ids. `Time.get_ticks_msec()` alone
## collides when two objects are placed inside the same millisecond (duplicate
## then move), which would make two records share one node.
func _next_object_suffix() -> int:
	var suffix := Time.get_ticks_msec()
	var taken: Dictionary = {}
	for record: FillObjectRecord in _editor.blueprint.objects:
		taken[record.id] = true
	while taken.has("fill_%s_%d" % [String(current_asset_id), suffix]):
		suffix += 1
	return suffix


# ---------------------------------------------------------------------------
# Undo / Redo — fill has no history of its own. `BuildingEditor.mark_dirty`
# snapshots the whole blueprint after every mutation, which is what keeps Ctrl+Z
# chronological across frame, zones and fill.
# ---------------------------------------------------------------------------

func undo() -> bool:
	return _editor != null and _editor.undo()


func redo() -> bool:
	return _editor != null and _editor.redo()


# ---------------------------------------------------------------------------
# Scene nodes
# ---------------------------------------------------------------------------

func rebuild_nodes() -> void:
	for node: Node3D in _nodes.values():
		node.queue_free()
	_nodes.clear()
	# Selection markers are keyed by object id; the ids of the previous blueprint
	# mean nothing here.
	_clear_selection_markers()
	for record: FillObjectRecord in _editor.blueprint.objects:
		_spawn_node(record)
	_update_selection_marker()
	if _collision_overlay != null:
		_collision_overlay.rebuild(_editor.blueprint)


func _spawn_node(record: FillObjectRecord) -> void:
	var asset := WorldAssetCatalog.get_asset(record.asset_id)
	var instance: Node3D = null
	if asset != null:
		var scene := load(asset.scene_path) as PackedScene
		if scene != null:
			instance = scene.instantiate() as Node3D
	if instance == null:
		# A blueprint from a pack that is not installed must stay editable and
		# visible: an object that silently disappears from the viewport while
		# staying in the data is worse than a marker (map_fill_mode.md §11).
		push_warning("BuildingFillModeController: unknown asset %s, object %s drawn as a placeholder" % [record.asset_id, record.id])
		instance = _make_placeholder()
	add_child(instance)
	_nodes[record.id] = instance
	_apply_transform_to_node(record)
	if instance.has_method("apply_decor_properties"):
		instance.call("apply_decor_properties", record.appearance)


## Deliberately a placeholder, not a second asset system — the same marker the
## map editor draws for content it cannot resolve.
func _make_placeholder() -> Node3D:
	var placeholder := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.38
	mesh.height = 0.65
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.15, 0.85)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	placeholder.mesh = mesh
	placeholder.position.y = 0.325
	return placeholder


func _apply_transform_to_node(record: FillObjectRecord) -> void:
	var node: Node3D = _nodes.get(record.id, null)
	if node == null:
		return
	node.position = record.pos
	node.rotation_degrees = record.rot
	node.scale = record.scale


func _remove_node(object_id: String) -> void:
	var node: Node3D = _nodes.get(object_id, null)
	if node != null:
		_nodes.erase(object_id)
		node.queue_free()


# ---------------------------------------------------------------------------
# Ghost & selection marker
# ---------------------------------------------------------------------------

func refresh_ghost() -> void:
	refresh_hover()
	if not is_active() or not _editor.cursor_valid or not _hovered_object_id.is_empty():
		_hide_ghost()
		return
	var asset := WorldAssetCatalog.get_asset(current_asset_id)
	if asset == null:
		_hide_ghost()
		return
	if _ghost == null or _ghost_asset_id != asset.id:
		if _ghost != null:
			_ghost.queue_free()
			_ghost = null
		var scene := load(asset.scene_path) as PackedScene
		if scene == null:
			return
		_ghost = scene.instantiate() as Node3D
		if _ghost == null:
			return
		_ghost_asset_id = asset.id
		add_child(_ghost)
		EditorFillConventions.apply_preview_look(_ghost, _get_ghost_material())
	_ghost.visible = true
	var ghost_pos := snapped_position(_editor.cursor_hit_pos, current_asset_id, current_scale)
	_ghost.position = ghost_pos + current_offset
	_ghost.rotation_degrees = Vector3(current_pitch_deg, current_yaw_deg, current_roll_deg)
	_ghost.scale = Vector3.ONE * current_scale
	# Update ghost colour based on placement state.
	var state := _compute_ghost_state(ghost_pos)
	_update_ghost_color(state)


## Updates cursor feedback without changing cycle-selection state.  Hovering an
## object hides the placement ghost and shows what a left click will select.
func refresh_hover() -> void:
	_hovered_object_id = ""
	if is_active() and _editor.cursor_valid:
		var candidates := _pick_objects_at(_editor.cursor_hit_pos)
		if not candidates.is_empty():
			_hovered_object_id = candidates[0]
	_update_hover_marker()


func _update_hover_marker() -> void:
	var record := find_record(_hovered_object_id)
	if record == null or not is_active():
		if _hover_marker != null:
			_hover_marker.visible = false
		return
	if _hover_marker == null:
		_hover_marker = _create_torus_marker(EditorFillConventions.COLOR_HOVER)
	_place_marker(_hover_marker, record, 0.05)


func _hide_ghost() -> void:
	if _ghost != null:
		_ghost.visible = false


## Updates the ghost material colour based on placement state (design §6.2).
func _update_ghost_color(state: int) -> void:
	var color: Color = EditorFillConventions.COLOR_GHOST_VALID
	match state:
		FillPlacementValidator.GhostState.INTERSECTION:
			color = EditorFillConventions.COLOR_GHOST_BLOCKED
		FillPlacementValidator.GhostState.OUT_OF_BOUNDS:
			color = EditorFillConventions.COLOR_GHOST_BLOCKED
	_get_ghost_material().albedo_color = color


func _get_ghost_material() -> StandardMaterial3D:
	if _ghost_material == null:
		_ghost_material = EditorFillConventions.make_ghost_material()
	return _ghost_material


func _create_torus_marker(color: Color) -> MeshInstance3D:
	var marker := EditorFillConventions.make_ring_marker(color)
	add_child(marker)
	return marker


## Scales a ring to the object's footprint. Both markers read the same way, so
## they are positioned by one function.
func _place_marker(marker: MeshInstance3D, record: FillObjectRecord, lift: float) -> void:
	var asset := WorldAssetCatalog.get_asset(record.asset_id)
	var size := asset.footprint_m() if asset != null else Vector3.ONE
	var radius := maxf(FillPlacementValidator.MIN_PICK_RADIUS, maxf(size.x, size.z) * 0.5 * maxf(record.scale.x, record.scale.z))
	marker.visible = true
	marker.scale = Vector3.ONE * (radius / 0.5)
	marker.position = record.pos + Vector3(0.0, lift, 0.0)


## One ring per selected object. The primary selection is the brighter one: with
## several objects selected the author still has to see which one the inspector
## and the drag are about.
func _update_selection_marker() -> void:
	var selected := selected_object_ids() if is_active() else ([] as Array[String])
	for object_id: Variant in _selection_markers.keys():
		if object_id not in selected:
			(_selection_markers[object_id] as MeshInstance3D).queue_free()
			_selection_markers.erase(object_id)
	for object_id: String in selected:
		var record := find_record(object_id)
		if record == null:
			continue
		if not _selection_markers.has(object_id):
			_selection_markers[object_id] = _create_torus_marker(EditorFillConventions.COLOR_SELECTION)
		var marker: MeshInstance3D = _selection_markers[object_id]
		var material := marker.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = EditorFillConventions.COLOR_SELECTION if object_id == selected_object_id \
				else Color(EditorFillConventions.COLOR_SELECTION, 0.45)
		_place_marker(marker, record, 0.03)


func _clear_selection_markers() -> void:
	for marker: Variant in _selection_markers.values():
		(marker as MeshInstance3D).queue_free()
	_selection_markers.clear()


# ---------------------------------------------------------------------------
# Collision overlay — delegated to FillCollisionOverlay node
# ---------------------------------------------------------------------------

## Toggle collision overlay on/off. When on, wireframe boxes are drawn for
## each object whose collision_policy is not "none", and blocking-navigation
## objects get an additional coloured marker.
func _on_collision_overlay_toggled(pressed: bool) -> void:
	_collision_overlay.toggle(pressed)
	if pressed:
		_collision_overlay.rebuild(_editor.blueprint)


# ---------------------------------------------------------------------------
# Inspector
# ---------------------------------------------------------------------------

func select_object(object_id: String) -> void:
	selected_object_id = object_id if find_record(object_id) != null else ""
	additional_selected_ids.clear()
	_after_selection_changed()


## Ctrl+LMB. Shift is the eyedropper in both editors, so additive selection gets
## Ctrl — the same gesture on the map.
func toggle_object_selection(object_id: String) -> void:
	if find_record(object_id) == null:
		return
	if object_id == selected_object_id:
		selected_object_id = additional_selected_ids.pop_front() if not additional_selected_ids.is_empty() else ""
	elif object_id in additional_selected_ids:
		additional_selected_ids.erase(object_id)
	elif selected_object_id.is_empty():
		selected_object_id = object_id
	else:
		additional_selected_ids.append(object_id)
	_after_selection_changed()


## Primary first: the inspector, drags and status messages are about that one.
func selected_object_ids() -> Array[String]:
	var ids: Array[String] = []
	if not selected_object_id.is_empty():
		ids.append(selected_object_id)
	for object_id: String in additional_selected_ids:
		if object_id not in ids and find_record(object_id) != null:
			ids.append(object_id)
	return ids


func selected_records() -> Array:
	var records: Array = []
	for object_id: String in selected_object_ids():
		var record := find_record(object_id)
		if record != null:
			records.append(record)
	return records


func _after_selection_changed() -> void:
	_inspector_panel.visible = is_active()
	_toolbar_delete_btn.disabled = selected_object_id.is_empty()
	_refresh_object_list()
	_refresh_inspector()
	_update_selection_marker()


func _refresh_object_list() -> void:
	_syncing_ui = true
	_visible_object_ids.clear()
	var entries: Array[String] = []
	var zone_filter := _get_zone_filter_selection()
	for record: FillObjectRecord in _editor.blueprint.objects:
		var asset := WorldAssetCatalog.get_asset(record.asset_id)
		var label := asset.name if asset != null else "%s (нет ассета)" % record.asset_id
		if zone_filter != &"" and record.owner_zone_id != zone_filter:
			continue
		entries.append("%s  ·  %s  ·  %.1f, %.1f, %.1f" % [label, record.id, record.pos.x, record.pos.y, record.pos.z])
		_visible_object_ids.append(record.id)
	var selected_indices: Array[int] = []
	for object_id: String in selected_object_ids():
		var index := _visible_object_ids.find(object_id)
		if index >= 0:
			selected_indices.append(index)
	_object_list.set_entries(entries, "Нет объектов в выбранной зоне", -1, [], selected_indices, true)
	_syncing_ui = false


## The list mirrors the 3D selection, multiple rows included. The clicked row
## becomes the primary one so the inspector follows the pointer.
func _on_object_list_selection_toggled(index: int, selected: bool) -> void:
	if _syncing_ui:
		return
	if index < 0 or index >= _visible_object_ids.size():
		return
	var clicked := _visible_object_ids[index]
	var ids: Array[String] = []
	for object_id: String in selected_object_ids():
		if object_id != clicked:
			ids.append(object_id)
	if selected:
		ids.append(clicked)
	selected_object_id = clicked if selected else (ids[0] if not ids.is_empty() else "")
	additional_selected_ids.clear()
	for object_id: String in ids:
		if object_id != selected_object_id:
			additional_selected_ids.append(object_id)
	_after_selection_changed()


## Returns the currently selected zone filter value (&"" = all zones).
func _get_zone_filter_selection() -> StringName:
	if _zone_filter_option == null or _zone_filter_option.item_count == 0:
		return &""
	var idx := _zone_filter_option.selected
	if idx < 0:
		return &""
	return _zone_filter_option.get_item_metadata(idx)


## Rebuild the zone filter dropdown from the blueprint's owning areas.
func _refresh_zone_filter_options() -> void:
	if _zone_filter_option == null:
		return
	_syncing_ui = true
	var prev_selection := _get_zone_filter_selection()
	_zone_filter_option.clear()
	_zone_filter_option.add_item("(все зоны)")
	_zone_filter_option.set_item_metadata(0, &"")
	var selected_idx := 0
	if _editor != null and _editor.blueprint != null:
		for area in _editor.blueprint.areas:
			if not area.owns_content():
				continue
			_zone_filter_option.add_item(area.display_name())
			_zone_filter_option.set_item_metadata(_zone_filter_option.item_count - 1, area.id)
			if area.id == prev_selection:
				selected_idx = _zone_filter_option.item_count - 1
	_zone_filter_option.select(selected_idx)
	_syncing_ui = false


func _on_zone_filter_selected(_index: int) -> void:
	if _syncing_ui:
		return
	_refresh_object_list()


## Updates the zone highlight overlay and out-of-zone warning for the selected object.
func _update_zone_highlight() -> void:
	if _zone_out_of_bounds_label != null:
		_zone_out_of_bounds_label.visible = false
	var record := find_record(selected_object_id)
	if record == null or record.owner_zone_id == &"":
		return
	if _editor == null or _editor.blueprint == null:
		return
	var area: ZoneAreaRecord = _editor.blueprint.area_by_id(record.owner_zone_id)
	if area == null or area.is_empty():
		return
	# floor maps cell-centre positions (e.g. 1.5) to the correct cell (1),
	# while round would snap 1.5 to 2 — a false out-of-zone warning.
	var obj_cell := Vector2i(int(floor(record.pos.x)), int(floor(record.pos.z)))
	var in_zone := area.contains_cell(obj_cell)
	if not in_zone and _zone_out_of_bounds_label != null:
		_zone_out_of_bounds_label.text = "⚠ Предмет вне зоны «%s»" % _zone_name_for_id(record.owner_zone_id)
		_zone_out_of_bounds_label.visible = true


func _zone_name_for_id(zone_id: StringName) -> String:
	if _editor == null or _editor.blueprint == null:
		return String(zone_id)
	var area: ZoneAreaRecord = _editor.blueprint.area_by_id(zone_id)
	return area.display_name() if area != null else String(zone_id)


## Called by BuildingEditor when a place zone is deleted.
## Clears owner_zone_id on all fill objects that referenced it.
func on_zone_deleted(zone_id: StringName) -> void:
	var affected := 0
	for record: FillObjectRecord in _editor.blueprint.objects:
		if record.owner_zone_id == zone_id:
			record.owner_zone_id = &""
			affected += 1
	if affected > 0:
		_editor.set_status("Зона «%s» удалена. Связь снята с %d предметов." % [String(zone_id), affected])
	_refresh_zone_filter_options()
	_refresh_object_list()
	_refresh_inspector()


func _refresh_inspector() -> void:
	var record := find_record(selected_object_id)
	if record == null:
		_refresh_zone_options(&"", null)
		_update_zone_highlight()
		var selected_asset := WorldAssetCatalog.get_asset(current_asset_id)
		if selected_asset != null:
			_set_transform_fields_enabled(true)
			# The cursor owns brush position. Its fine transform is still authored
			# here and must immediately affect the placement ghost.
			_pos_x_spin.editable = false
			_pos_y_spin.editable = false
			_pos_z_spin.editable = false
			_sync_brush_transform_fields()
			_inspector_title.text = "Ассет: %s" % selected_asset.name
			_id_label.text = "Категория: %s" % WorldAssetCatalog.category_display_name(selected_asset.category)
			_asset_label.text = "Размер: %d×%d×%d м" % [selected_asset.size_in_blocks.x, selected_asset.size_in_blocks.y, selected_asset.size_in_blocks.z]
			_badges_label.text = selected_asset.description
			_controls_vbox.set_fields(
				_appearance_definitions(selected_asset), selected_asset.default_appearance(), true, false)
		else:
			_set_transform_fields_enabled(false)
			_inspector_title.text = "Инспектор наполнения"
			_id_label.text = "ID: —"
			_asset_label.text = "Выберите ассет в палитре или объект в 3D"
			_badges_label.text = ""
			_controls_vbox.set_fields([], {})
		return

	var asset := WorldAssetCatalog.get_asset(record.asset_id)
	var selection_size := selected_object_ids().size()
	_set_transform_fields_enabled(true)
	_sync_transform_fields(record)
	_refresh_replace_action(record)
	_refresh_zone_options(record.owner_zone_id, record)
	_update_badges(record, asset)
	_update_zone_highlight()

	# With several objects selected only what is meaningful for all of them is
	# editable: transform. Per-asset appearance, the owning zone and replacement
	# stay single-object work — an inspector showing the first object's value and
	# writing into all of them would be silent data loss (design §7.4).
	if selection_size > 1:
		_inspector_title.text = "Выбрано объектов: %d" % selection_size
		_id_label.text = "Основной: %s" % record.id
		_asset_label.text = "Правятся общие поля: позиция (сдвигом), поворот, масштаб"
		_badges_label.text = ""
		_zone_option.disabled = true
		_replace_btn.disabled = true
		_controls_vbox.set_fields([], {})
		return

	_inspector_title.text = "Свойства: %s" % (asset.name if asset != null else String(record.asset_id))
	_id_label.text = "ID: %s" % record.id
	_asset_label.text = "Ассет: %s" % (asset.name if asset != null else String(record.asset_id))
	if asset == null:
		return

	_controls_vbox.set_fields(_appearance_definitions(asset), record.appearance)


func _appearance_definitions(asset: WorldAssetDef) -> Array[EntityPropertyDef]:
	var definitions: Array[EntityPropertyDef] = []
	for control: Dictionary in asset.appearance_controls:
		var source := control.duplicate(true)
		source["section"] = "appearance"
		var definition := EntityPropertyDef.from_dict(source)
		if definition.is_valid():
			definitions.append(definition)
	return definitions


func _on_appearance_property_committed(property_name: StringName, value: Variant) -> void:
	_set_property(String(property_name), FillObjectRecord.json_safe_value(value))


func _on_appearance_property_reset(property_name: StringName) -> void:
	var record := find_record(selected_object_id)
	var asset := WorldAssetCatalog.get_asset(record.asset_id) if record != null else null
	if asset == null:
		return
	for definition: EntityPropertyDef in _appearance_definitions(asset):
		if definition.name == property_name:
			_set_property(String(property_name), FillObjectRecord.json_safe_value(definition.default))
			_refresh_inspector()
			return


func _set_property(property_name: String, value: Variant) -> void:
	var record := find_record(selected_object_id)
	if record == null:
		return
	if record.appearance.get(property_name, null) == value:
		return
	record.appearance[property_name] = value
	var node: Node3D = _nodes.get(record.id, null)
	if node != null and node.has_method("set_decor_property"):
		node.call("set_decor_property", property_name, value)
	# One property of one object is one merge key: a slider dragged through
	# twenty values is one author action, but two different fields never merge.
	_editor.mark_dirty_coalesced("fill_prop/%s/%s" % [record.id, property_name])


func _set_transform_fields_enabled(enabled: bool) -> void:
	for spin in _transform_spins():
		spin.editable = enabled
	_transform_inspector.set_reset_enabled(enabled)
	_zone_option.disabled = not enabled
	_replace_btn.disabled = not enabled
	if not enabled:
		_replace_btn.text = "Заменить на выбранный ассет"


func _refresh_replace_action(record: FillObjectRecord) -> void:
	var replacement := WorldAssetCatalog.get_asset(current_asset_id)
	_replace_btn.disabled = replacement == null or current_asset_id == record.asset_id
	_replace_btn.text = "Заменить на «%s»" % replacement.name if replacement != null else "Заменить на выбранный ассет"


## Refresh the owner-zone dropdown from the blueprint's owning areas.
func _refresh_zone_options(current_zone: StringName, _record: FillObjectRecord) -> void:
	_syncing_ui = true
	_zone_option.clear()
	_zone_option.add_item("(без зоны)")
	_zone_option.set_item_metadata(0, &"")
	var selected_idx := 0
	if _editor != null and _editor.blueprint != null:
		for area in _editor.blueprint.areas:
			if not area.owns_content():
				continue
			_zone_option.add_item(area.display_name())
			_zone_option.set_item_metadata(_zone_option.item_count - 1, area.id)
			if area.id == current_zone:
				selected_idx = _zone_option.item_count - 1
	_zone_option.select(selected_idx)
	_syncing_ui = false


func _on_zone_selected(index: int) -> void:
	if _syncing_ui:
		return
	var record := find_record(selected_object_id)
	if record == null:
		return
	record.owner_zone_id = _zone_option.get_item_metadata(index)
	_editor.mark_dirty()


## Show diagnostic badges for the selected object.
func _update_badges(record: FillObjectRecord, asset: Variant) -> void:
	var badges: Array[String] = []
	if asset != null and asset.scale_mode != WorldAssetDef.SCALE_LOCKED:
		badges.append("Масштаб: %s" % String(asset.scale_mode))
	if asset != null and asset.blocking_navigation:
		badges.append("Блокирует навигацию")
	if record.owner_zone_id != &"":
		badges.append("Зона: %s" % String(record.owner_zone_id))
	_badges_label.text = "  ·  ".join(badges) if not badges.is_empty() else ""


## Replaces the asset of every selected object with the current catalog pick.
##
## This exists instead of "delete and place a new one" because the record keeps
## its **id**, and with it the fixture link, the owning zone and every rule that
## refers to it. Deleting breaks those references silently
## (map_fill_mode.md §8.3), which is exactly the cost an author cannot see.
##
## Properties the new asset does not have are lost, so the author is asked first
## — before the replacement, not after it.
func _replace_selected_object() -> void:
	var records := selected_records()
	if records.is_empty():
		_editor.set_status("Выберите объект для замены.")
		return
	if current_asset_id == &"":
		_editor.set_status("Выберите ассет в каталоге для замены.")
		return
	var new_asset := WorldAssetCatalog.get_asset(current_asset_id)
	if new_asset == null:
		return
	var targets: Array = []
	for record: FillObjectRecord in records:
		if record.asset_id != new_asset.id:
			targets.append(record)
	if targets.is_empty():
		_editor.set_status("Объект уже использует этот ассет.")
		return
	var ignored_ids: Array = targets.map(func(target: FillObjectRecord) -> String: return target.id)
	var anchors: Dictionary = {}
	var rotations: Dictionary = {}
	var scales: Dictionary = {}
	for record: FillObjectRecord in targets:
		var old_cells := occupied_cells(record.anchor_pos(), record.asset_id, record.scale.x, record.rot.y)
		var next_scale := Vector3.ONE * EditorFillConventions.normalized_scale(new_asset, record.scale.x)
		var next_span: Vector2i = _validator.cell_span(new_asset.id, next_scale.x, record.rot.y)
		var next_xz := EditorFillConventions.anchor_of_cells(old_cells.position, next_span)
		var next_anchor := Vector3(next_xz.x, record.anchor_pos().y, next_xz.y)
		if not _is_valid_transform(
				next_anchor, record.rot, next_scale, new_asset.id, record.id, ignored_ids):
			_editor.set_status("Замена не применена: новому ассету не хватает свободных клеток или запрещён текущий поворот.")
			return
		anchors[record.id] = next_anchor
		rotations[record.id] = record.rot
		scales[record.id] = next_scale
	if not _proposed_fill_is_free(targets, anchors, rotations, scales, new_asset.id):
		_editor.set_status("Замена не применена: новые размеры выбранных объектов пересекутся.")
		return

	var lost_total := 0
	for record: FillObjectRecord in targets:
		lost_total += _lost_property_count(record, new_asset)
	var incompatible_fixture_links := 0
	for fixture: FixtureDefinition in _editor.blueprint.fixtures:
		if fixture.visual_object_id not in ignored_ids:
			continue
		for capability: StringName in fixture.capabilities:
			if capability not in new_asset.supported_capabilities:
				incompatible_fixture_links += 1
				break
	if lost_total > 0 or incompatible_fixture_links > 0:
		var question := "Замена на «%s» потеряет настроенных свойств: %d." % [new_asset.name, lost_total]
		if incompatible_fixture_links > 0:
			question += " Несовместимых связей fixture будет снято: %d." % incompatible_fixture_links
		question += " Продолжить?"
		if not await _editor.confirm_action(question, "Замена ассета"):
			_editor.set_status("Замена отменена.")
			return

	# Замена всего выделения — одно действие, а не N шагов отмены.
	_editor.begin_history_group("fill_replace")
	var replaced := 0
	for record: FillObjectRecord in targets:
		_replace_one(record, new_asset, anchors[record.id], scales[record.id])
		replaced += 1
	for fixture: FixtureDefinition in _editor.blueprint.fixtures:
		if fixture.visual_object_id not in ignored_ids:
			continue
		for capability: StringName in fixture.capabilities:
			if capability not in new_asset.supported_capabilities:
				fixture.visual_object_id = ""
				break
	_editor.end_history_group()
	_refresh_object_list()
	_refresh_inspector()
	if lost_total > 0:
		_editor.set_status("Заменено объектов: %d на «%s». Потеряно свойств: %d." % [replaced, new_asset.name, lost_total])
	else:
		_editor.set_status("Заменено объектов: %d на «%s»." % [replaced, new_asset.name])


## Свойства, которых у нового ассета нет и которые исчезнут при замене.
func _lost_property_count(record: FillObjectRecord, new_asset: WorldAssetDef) -> int:
	var lost := 0
	for key: Variant in record.appearance.keys():
		var found := false
		for control: Dictionary in new_asset.appearance_controls:
			if String(control.get("name", "")) == String(key):
				found = true
				break
		if not found:
			lost += 1
	return lost


func _replace_one(
	record: FillObjectRecord,
	new_asset: WorldAssetDef,
	next_anchor: Vector3,
	next_scale: Vector3,
) -> void:
	var old_appearance := record.appearance.duplicate(true)
	record.asset_id = new_asset.id
	record.scale = next_scale
	record.appearance = new_asset.default_appearance()
	# Carry over compatible properties: keys that exist in the new asset's
	# appearance_controls with a matching type, preserving the old value.
	var new_controls_by_name: Dictionary = {}
	for control: Dictionary in new_asset.appearance_controls:
		new_controls_by_name[String(control.get("name", ""))] = control
	for key: Variant in old_appearance.keys():
		var key_str := String(key)
		if not new_controls_by_name.has(key_str):
			continue
		var new_control: Dictionary = new_controls_by_name[key_str]
		var new_type := String(new_control.get("type", "string"))
		var old_value: Variant = old_appearance[key]
		# Type compatibility check: bool, float, string, color (stored as html string).
		var compatible := false
		match new_type:
			WorldAssetDef.TYPE_BOOL:
				compatible = old_value is bool
			WorldAssetDef.TYPE_FLOAT:
				compatible = old_value is float or old_value is int
			WorldAssetDef.TYPE_COLOR:
				compatible = old_value is String or old_value is Color
			_:
				compatible = old_value is String
		if compatible:
			record.appearance[key_str] = old_value
	# Новый ассет может занимать другое число клеток: пересаживаем объект на его
	# собственные клетки, чтобы занятость осталась честной.
	record.pos = next_anchor + record.offset
	_spawn_node_for_existing(record)
	_editor.mark_dirty()


## Re-spawn the visual node for an existing record (used by replace).
func _spawn_node_for_existing(record: FillObjectRecord) -> void:
	_remove_node(record.id)
	_spawn_node(record)


func _transform_spins() -> Array[SpinBox]:
	return [_pos_x_spin, _pos_y_spin, _pos_z_spin, _off_x_spin, _off_y_spin, _off_z_spin,
		_pitch_spin, _yaw_spin, _roll_spin, _scale_spin]


## Инспектор показывает то, чем автор оперирует: клетку, слой и смещение внутри
## своих клеток. Мировая позиция — производная (`якорь + смещение`) и в полях не
## участвует: она заставляла бы считать доли метра в уме.
func _sync_transform_fields(record: FillObjectRecord) -> void:
	_syncing_ui = true
	_scale_spin.editable = true
	_scale_spin.tooltip_text = ""
	_pitch_spin.editable = true
	_yaw_spin.editable = true
	_roll_spin.editable = true
	var cells := occupied_cells(record.anchor_pos(), record.asset_id, record.scale.x, record.rot.y)
	_pos_x_spin.value = cells.position.x
	_pos_z_spin.value = cells.position.y
	_pos_y_spin.value = record.anchor_pos().y
	_off_x_spin.value = record.offset.x
	_off_y_spin.value = record.offset.y
	_off_z_spin.value = record.offset.z
	_pitch_spin.value = record.rot.x
	_yaw_spin.value = record.rot.y
	_roll_spin.value = record.rot.z
	_scale_spin.value = record.scale.x
	_syncing_ui = false


func _sync_brush_transform_fields() -> void:
	_syncing_ui = true
	_pos_x_spin.value = 0.0
	_pos_y_spin.value = _editor.active_layer
	_pos_z_spin.value = 0.0
	_off_x_spin.value = current_offset.x
	_off_y_spin.value = current_offset.y
	_off_z_spin.value = current_offset.z
	_pitch_spin.value = current_pitch_deg
	_yaw_spin.value = current_yaw_deg
	_roll_spin.value = current_roll_deg
	_scale_spin.value = current_scale
	_syncing_ui = false


func _on_transform_spin_changed(_value: float) -> void:
	if _syncing_ui:
		return
	var record := find_record(selected_object_id)
	if record == null:
		if current_asset_id.is_empty():
			return
		current_offset = EditorFillConventions.clamp_offset(
			Vector3(_off_x_spin.value, _off_y_spin.value, _off_z_spin.value))
		current_pitch_deg = _pitch_spin.value
		current_yaw_deg = _yaw_spin.value
		current_roll_deg = _roll_spin.value
		current_scale = EditorFillConventions.normalized_scale(
			WorldAssetCatalog.get_asset(current_asset_id), _scale_spin.value)
		refresh_ghost()
		return
	var old_anchor := record.anchor_pos()
	var old_offset := record.offset
	var old_rot := record.rot
	var old_scale := record.scale

	var candidate_rot := Vector3(_pitch_spin.value, _yaw_spin.value, _roll_spin.value)
	var candidate_scale := Vector3.ONE * _clamped_scale(record, _scale_spin.value)
	var candidate_offset := EditorFillConventions.clamp_offset(
		Vector3(_off_x_spin.value, _off_y_spin.value, _off_z_spin.value))
	# Поле хранит левую-нижнюю клетку прямоугольника; якорь — его центр.
	var span: Vector2i = _validator.cell_span(record.asset_id, candidate_scale.x, candidate_rot.y)
	var base_cell := Vector2i(int(round(_pos_x_spin.value)), int(round(_pos_z_spin.value)))
	var anchor_xz := EditorFillConventions.anchor_of_cells(base_cell, span)
	var candidate_anchor := Vector3(anchor_xz.x, float(int(round(_pos_y_spin.value))), anchor_xz.y)
	# Reconstructing an anchor from a bounding cell is lossy for an already
	# authored fractional anchor (notably after scaling). If the position fields
	# themselves were not changed, preserve the exact anchor: editing offset,
	# rotation or scale must never make the object jump to a neighbouring cell.
	var old_cells := occupied_cells(old_anchor, record.asset_id, record.scale.x, record.rot.y)
	if base_cell == old_cells.position and is_equal_approx(_pos_y_spin.value, old_anchor.y):
		candidate_anchor = old_anchor

	if old_anchor.is_equal_approx(candidate_anchor) and old_offset.is_equal_approx(candidate_offset) \
			and old_rot.is_equal_approx(candidate_rot) and old_scale.is_equal_approx(candidate_scale):
		return

	# Клетка применяется сдвигом, чтобы выделение сохранило свою расстановку;
	# смещение, поворот и масштаб — абсолютом: поле говорит именно это.
	var shift := candidate_anchor - old_anchor
	var records := selected_records()
	var ignored_ids: Array = selected_object_ids()
	var anchors: Dictionary = {}
	var rotations: Dictionary = {}
	var scales: Dictionary = {}
	for target: FillObjectRecord in records:
		var anchor := candidate_anchor if target.id == record.id else target.anchor_pos() + shift
		var target_scale := Vector3.ONE * EditorFillConventions.normalized_scale(
			WorldAssetCatalog.get_asset(target.asset_id), _scale_spin.value)
		if not _is_valid_transform(
				anchor, candidate_rot, target_scale, target.asset_id, target.id, ignored_ids):
			_sync_transform_fields(record)
			_editor.set_status("Не применено: одному из выбранных объектов не хватает свободных клеток.")
			return
		anchors[target.id] = anchor
		rotations[target.id] = candidate_rot
		scales[target.id] = target_scale
	if not _proposed_fill_is_free(records, anchors, rotations, scales):
		_sync_transform_fields(record)
		_editor.set_status("Не применено: выбранные объекты пересекутся друг с другом.")
		return
	for target: FillObjectRecord in records:
		var anchor: Vector3 = anchors[target.id]
		target.offset = candidate_offset
		target.pos = anchor + candidate_offset
		target.rot = rotations[target.id]
		target.scale = scales[target.id]
		_apply_transform_to_node(target)
	_update_selection_marker()
	# One field of one object is one undo step, however many intermediate values
	# the wheel or the arrows produced.
	_editor.mark_dirty_coalesced("fill_transform/%s" % record.id)


## Масштаб, приведённый к политике ассета.
func _clamped_scale(record: FillObjectRecord, requested: float) -> float:
	var asset := WorldAssetCatalog.get_asset(record.asset_id)
	var scale_val := EditorFillConventions.normalized_scale(asset, requested)
	_syncing_ui = true
	_scale_spin.value = scale_val
	_syncing_ui = false
	return scale_val


func _proposed_fill_is_free(
	records: Array,
	anchors: Dictionary,
	rotations: Dictionary,
	scales: Dictionary,
	asset_override: StringName = &"",
) -> bool:
	for left_index in records.size():
		var left: FillObjectRecord = records[left_index]
		var left_asset_id := asset_override if asset_override != &"" else left.asset_id
		var left_asset := WorldAssetCatalog.get_asset(left_asset_id)
		if not EditorFillConventions.asset_claims_cells(left_asset):
			continue
		var left_anchor: Vector3 = anchors[left.id]
		for right_index in range(left_index + 1, records.size()):
			var right: FillObjectRecord = records[right_index]
			var right_asset_id := asset_override if asset_override != &"" else right.asset_id
			var right_asset := WorldAssetCatalog.get_asset(right_asset_id)
			if not EditorFillConventions.asset_claims_cells(right_asset):
				continue
			var right_anchor: Vector3 = anchors[right.id]
			if not is_equal_approx(left_anchor.y, right_anchor.y):
				continue
			var left_rot: Vector3 = rotations[left.id]
			var right_rot: Vector3 = rotations[right.id]
			var left_scale: Vector3 = scales[left.id]
			var right_scale: Vector3 = scales[right.id]
			var left_cells := occupied_cells(left_anchor, left_asset_id, left_scale.x, left_rot.y)
			var right_cells := occupied_cells(right_anchor, right_asset_id, right_scale.x, right_rot.y)
			if EditorFillConventions.rects_overlap(left_cells, right_cells):
				return false
	return true


# ---------------------------------------------------------------------------
# Small UI sync helpers
# ---------------------------------------------------------------------------

func _update_layer_label() -> void:
	if _layer_label != null and _editor != null:
		_layer_label.text = "Слой %d" % _editor.active_layer


func on_layer_changed() -> void:
	_update_layer_label()
	refresh_ghost()


# ---------------------------------------------------------------------------
# Fixtures — proxy methods for test compatibility. Logic lives in
# FixtureEditorPanel.
# ---------------------------------------------------------------------------

func _add_fixture() -> void:
	_fixture_panel.add_fixture()


func _on_fixture_visual_selected(index: int) -> void:
	_fixture_panel._on_fixture_visual_selected(index)
