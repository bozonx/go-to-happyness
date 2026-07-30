class_name DecorModeController
extends Node3D

## Decor mode of the building editor (design §3.3): places, selects, moves and
## configures the `objects[]` of a blueprint.
##
## Lives as a child of BuildingEditor and owns everything decor-specific — the
## spawned instances, the placement ghost and the selection marker — so the
## editor script only routes input and mode switching here.  History belongs to
## BuildingEditor, where it remains chronological across every mode.
##
## One contextual gesture owns the left mouse button: it drops the selected
## catalog asset on empty ground, or selects and drags an existing object.

const DecorObjectRecordScript = preload("res://game/features/buildings/domain/editor/decor_object_record.gd")
const FixtureEditorPanelScript = preload("res://game/features/buildings/presentation/editor/fixture_editor_panel.gd")
const DecorPlacementValidatorScript = preload("res://game/features/buildings/presentation/editor/decor_placement_validator.gd")
const DecorCollisionOverlayScript = preload("res://game/features/buildings/presentation/editor/decor_collision_overlay.gd")
const DecorCatalogPanelScript = preload("res://game/features/buildings/presentation/editor/decor_catalog_panel.gd")

const ROTATION_STEP_DEG := 15.0
## Ghost feedback colours (design §6.2).
const GHOST_COLOR_VALID := Color(0.45, 0.85, 1.0, 0.4)
const GHOST_COLOR_INTERSECTION := Color(1.0, 0.3, 0.2, 0.5)
const GHOST_COLOR_OUT_OF_BOUNDS := Color(1.0, 0.85, 0.2, 0.5)

var current_group: StringName = &""  ## empty = all groups
var current_category: StringName = &"camping"
var current_asset_id: StringName = &""
var current_snap_step: float = 1.0
var current_yaw_deg: float = 0.0
var current_pitch_deg: float = 0.0
var current_roll_deg: float = 0.0
var selected_object_id: String = ""

var _editor: Node = null
var _validator: RefCounted = null
var _nodes: Dictionary = {}  ## object id (String) -> Node3D
var _ghost: Node3D = null
var _ghost_asset_id: StringName = &""
var _ghost_material: StandardMaterial3D = null
var _selection_marker: MeshInstance3D = null
var _hover_marker: MeshInstance3D = null
var _hovered_object_id: String = ""
var _object_search_edit: LineEdit = null
var _id_label: Label = null
var _asset_label: Label = null
var _badges_label: Label = null
var _zone_option: OptionButton = null
var _replace_btn: Button = null
var _dragging: bool = false
## Grab offset so dragging moves the object relative to where it was picked up.
var _drag_offset: Vector3 = Vector3.ZERO
var _drag_started: bool = false
## Guards the inspector's own writes from re-entering as user edits.
var _syncing_ui: bool = false

var _panel: PanelContainer = null
var _inspector_panel: PanelContainer = null
var _toolbar: HBoxContainer = null
var _inspector_title: Label = null
var _object_list: ItemList = null
var _controls_vbox: VBoxContainer = null
var _pos_x_spin: SpinBox = null
var _pos_y_spin: SpinBox = null
var _pos_z_spin: SpinBox = null
var _yaw_spin: SpinBox = null
var _pitch_spin: SpinBox = null
var _roll_spin: SpinBox = null
var _scale_spin: SpinBox = null
var _duplicate_btn: Button = null
var _delete_btn: Button = null
var _toolbar_delete_btn: Button = null
var _layer_label: Label = null
var _collision_overlay_btn: Button = null
var _collision_overlay: Node3D = null
var _catalog_panel: RefCounted = null
var _zone_filter_option: OptionButton = null
var _zone_out_of_bounds_label: Label = null

# Fixture editor — delegated to FixtureEditorPanel
var _fixture_panel: RefCounted = null


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(editor: Node) -> void:
	_editor = editor
	_validator = DecorPlacementValidatorScript.new()
	name = "DecorRoot"

	_panel = editor.get_node("%DecorPanel")
	_inspector_panel = editor.get_node("%DecorInspectorPanel")
	_toolbar = editor.get_node("%DecorToolbar")
	_inspector_title = editor.get_node("%DecorInspectorTitle")
	_id_label = editor.get_node("%DecorIdLabel")
	_asset_label = editor.get_node("%DecorAssetLabel")
	_zone_option = editor.get_node("%DecorZoneOption")
	_badges_label = editor.get_node("%DecorBadgesLabel")
	_zone_out_of_bounds_label = editor.get_node("%DecorZoneWarningLabel")
	_object_search_edit = editor.get_node("%DecorObjectSearchEdit")
	_zone_filter_option = editor.get_node("%DecorZoneFilterOption")
	_object_list = editor.get_node("%DecorObjectList")
	_controls_vbox = editor.get_node("%DecorControlsVBox")
	_pos_x_spin = editor.get_node("%DecorPosXSpin")
	_pos_y_spin = editor.get_node("%DecorPosYSpin")
	_pos_z_spin = editor.get_node("%DecorPosZSpin")
	_yaw_spin = editor.get_node("%DecorYawSpin")
	_pitch_spin = editor.get_node("%DecorPitchSpin")
	_roll_spin = editor.get_node("%DecorRollSpin")
	_scale_spin = editor.get_node("%DecorScaleSpin")
	_replace_btn = editor.get_node("%DecorReplaceBtn")
	_duplicate_btn = editor.get_node("%DecorDuplicateBtn")
	_delete_btn = editor.get_node("%DecorDeleteBtn")
	_toolbar_delete_btn = editor.get_node("%DecorDeleteSelectionBtn")
	_layer_label = editor.get_node("%DecorLayerLabel")

	# Fixture editor — delegated to FixtureEditorPanel
	_fixture_panel = FixtureEditorPanelScript.new()
	_fixture_panel.setup(editor, Callable(self, "_push_undo"))

	# Catalog panel — delegated to DecorCatalogPanel
	_catalog_panel = DecorCatalogPanelScript.new()
	_catalog_panel.setup(self, editor)

	editor.get_node("%DecorRotXBtn").pressed.connect(rotate_selection.bind("x", 1))
	editor.get_node("%DecorRotYBtn").pressed.connect(rotate_selection.bind("y", 1))
	editor.get_node("%DecorRotZBtn").pressed.connect(rotate_selection.bind("z", 1))
	editor.get_node("%DecorLayerDownBtn").pressed.connect(func(): _editor.set_layer(_editor.active_layer - 1))
	editor.get_node("%DecorLayerUpBtn").pressed.connect(func(): _editor.set_layer(_editor.active_layer + 1))
	_collision_overlay_btn = editor.get_node("%DecorCollisionOverlayBtn")
	_collision_overlay = DecorCollisionOverlayScript.new()
	_collision_overlay.name = "CollisionOverlay"
	add_child(_collision_overlay)
	_collision_overlay_btn.toggled.connect(_on_collision_overlay_toggled)

	_object_search_edit.text_changed.connect(_on_object_search_changed)
	_object_list.item_selected.connect(_on_object_list_selected)
	_zone_option.item_selected.connect(_on_zone_selected)
	_zone_filter_option.item_selected.connect(_on_zone_filter_selected)
	_duplicate_btn.pressed.connect(duplicate_selection)
	_delete_btn.pressed.connect(delete_selection)
	_toolbar_delete_btn.pressed.connect(delete_selection)
	_replace_btn.pressed.connect(_replace_selected_object)
	_pos_x_spin.value_changed.connect(_on_transform_spin_changed)
	_pos_y_spin.value_changed.connect(_on_transform_spin_changed)
	_pos_z_spin.value_changed.connect(_on_transform_spin_changed)
	_yaw_spin.value_changed.connect(_on_transform_spin_changed)
	_pitch_spin.value_changed.connect(_on_transform_spin_changed)
	_roll_spin.value_changed.connect(_on_transform_spin_changed)
	_scale_spin.value_changed.connect(_on_transform_spin_changed)

	current_category = WorldAssetCatalog.first_populated_category(current_category)
	_catalog_panel.activate()


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

func on_left_pressed() -> void:
	if not _editor.cursor_valid:
		return
	var hit: Vector3 = _editor.cursor_hit_pos
	var picked := pick_object_at(hit)
	if not picked.is_empty():
		_select_for_drag(picked, hit)
		return
	if current_asset_id.is_empty():
		select_object("")
		_editor.set_status("Выберите ассет для размещения или объект для редактирования.")
		return
	_place_or_select_at(hit)


func on_left_released() -> void:
	_dragging = false
	_drag_started = false
	refresh_hover()


func erase_at_cursor() -> void:
	if not _editor.cursor_valid:
		return
	var target := pick_object_at(_editor.cursor_hit_pos)
	if target.is_empty():
		_editor.set_status("Под курсором нет объекта декора.")
		return
	_push_undo()
	_erase_object(target)
	_editor.set_status("Объект удалён.")
	refresh_hover()


## Shift+LMB: use the object below the cursor as the next placement brush.
func pick_asset_at_cursor() -> void:
	if not _editor.cursor_valid:
		return
	var object_id := pick_object_at(_editor.cursor_hit_pos)
	var record := find_record(object_id)
	if record == null:
		_editor.set_status("Под курсором нет объекта для пипетки.")
		return
	_catalog_panel.select_asset(record.asset_id)
	current_pitch_deg = record.rot.x
	current_yaw_deg = record.rot.y
	current_roll_deg = record.rot.z
	select_object("")
	_editor.set_status("Пипетка: выбран «%s»." % WorldAssetCatalog.get_asset(record.asset_id).name)
	refresh_ghost()


func _select_for_drag(object_id: String, hit: Vector3) -> void:
	select_object(object_id)
	var record := find_record(object_id)
	if record == null:
		return
	_drag_offset = record.pos - Vector3(hit.x, record.pos.y, hit.z)
	_dragging = true
	_drag_started = false


func on_drag() -> void:
	if not _dragging or not _editor.cursor_valid:
		return
	var record := find_record(selected_object_id)
	if record == null:
		return
	# Snapshot once per drag, not once per mouse-motion event.
	if not _drag_started:
		_push_undo()
		_drag_started = true
	var hit: Vector3 = _editor.cursor_hit_pos
	var candidate := snapped_position(hit + _drag_offset)
	if not _is_valid_transform(candidate, record.rot, record.scale, record.asset_id, record.id):
		return
	record.pos = candidate
	_apply_transform_to_node(record)
	_editor.mark_dirty()
	_sync_transform_fields(record)
	_update_selection_marker()


## Returns true when the key was consumed by decor mode.
func handle_key(event: InputEventKey) -> bool:
	if event.ctrl_pressed:
		match event.keycode:
			KEY_Z:
				if event.shift_pressed:
					redo()
				else:
					undo()
				return true
			KEY_Y:
				redo()
				return true
			KEY_D:
				duplicate_selection()
				return true
		return false
	match event.keycode:
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
# Placement maths — delegated to DecorPlacementValidator
# ---------------------------------------------------------------------------

func snapped_position(raw_hit: Vector3) -> Vector3:
	return _validator.snapped_position(raw_hit, _editor.active_layer, current_asset_id, current_snap_step)


func _is_in_bounds(pos: Vector3, asset_id: StringName = current_asset_id, scale: Vector3 = Vector3.ONE) -> bool:
	return _validator.is_in_bounds(pos, _editor.blueprint, asset_id, scale)


func _is_collision_conflict(pos: Vector3, asset_id: StringName = current_asset_id, scale: Vector3 = Vector3.ONE, exclude_id: String = "") -> bool:
	return _validator.is_collision_conflict(pos, _editor.blueprint, asset_id, scale, exclude_id)


func _is_valid_transform(pos: Vector3, rot: Vector3, scale: Vector3, asset_id: StringName, exclude_id: String = "") -> bool:
	return _validator.is_valid_transform(pos, rot, scale, asset_id, _editor.blueprint, exclude_id)


func _compute_ghost_state(pos: Vector3) -> int:
	return _validator.compute_ghost_state(pos, _editor.blueprint, current_asset_id)


func _pick_objects_at(world_pos: Vector3) -> Array[String]:
	return _validator.pick_objects_at(world_pos, _editor.blueprint)


func pick_object_at(world_pos: Vector3) -> String:
	return _validator.pick_object_at(world_pos, _editor.blueprint)


func find_record(object_id: String) -> DecorObjectRecordScript:
	return DecorPlacementValidatorScript.find_record_in(object_id, _editor.blueprint)


# ---------------------------------------------------------------------------
# Mutations
# ---------------------------------------------------------------------------

## A placement click that lands on occupied geometry selects the conflicting
## object where possible instead of silently stacking another instance inside it.
func _place_or_select_at(hit: Vector3) -> void:
	var target := pick_object_at(hit)
	if not target.is_empty():
		select_object(target)
		_editor.set_status("Выбран объект под курсором.")
		return
	var position := snapped_position(hit)
	var asset := WorldAssetCatalog.get_asset(current_asset_id)
	if asset == null:
		_editor.set_status("Выберите ассет в каталоге декора.")
		return
	if not _is_valid_transform(position, Vector3(current_pitch_deg, current_yaw_deg, current_roll_deg), Vector3.ONE, asset.id):
		# The hit can be near the edge of an object's footprint rather than inside
		# its pick radius. Select that conflicting object where possible, so the
		# click still has a useful result.
		var conflict := pick_object_at(position)
		if not conflict.is_empty():
			select_object(conflict)
			_editor.set_status("Выбран объект, занимающий это место.")
		else:
			_editor.set_status("Здесь нельзя разместить декор: место занято или вне границ здания.")
		return
	_place_at(position)


func _place_at(position: Vector3) -> void:
	var asset := WorldAssetCatalog.get_asset(current_asset_id)
	if asset == null:
		_editor.set_status("Выберите ассет в каталоге декора.")
		return
	# Keep the invariant at the mutation boundary too: UI input is not the only
	# caller of this method, and a red preview must never still create an overlap.
	if _compute_ghost_state(position) != DecorPlacementValidatorScript.GhostState.VALID:
		_editor.set_status("Нельзя разместить декор поверх другого объекта.")
		return
	_push_undo()
	var record := DecorObjectRecordScript.make(asset.id, position, _next_object_suffix())
	record.rot = Vector3(0.0, current_yaw_deg, 0.0)
	record.appearance = asset.default_appearance()
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
	if selected_object_id == object_id:
		select_object("")
	if not _editor.blueprint.fixtures.is_empty():
		_fixture_panel.refresh_fixture_ui()


func delete_selection() -> void:
	if selected_object_id.is_empty():
		return
	_push_undo()
	_erase_object(selected_object_id)
	_editor.set_status("Объект удалён.")


func duplicate_selection() -> void:
	var record := find_record(selected_object_id)
	if record == null:
		_editor.set_status("Нечего дублировать: объект не выбран.")
		return
	var copy := record.duplicate_record(_next_object_suffix())
	# Offset by one snap step so the copy is visible rather than hidden inside
	# the original.
	var offset := maxf(current_snap_step, 0.5)
	var offset_candidates := [
		Vector3(offset, 0.0, offset),
		Vector3(-offset, 0.0, offset),
		Vector3(offset, 0.0, -offset),
		Vector3(-offset, 0.0, -offset),
	]
	var placed := false
	for off in offset_candidates:
		copy.pos = record.pos + off
		if _is_valid_transform(copy.pos, copy.rot, copy.scale, copy.asset_id, record.id):
			placed = true
			break
	if not placed:
		_editor.set_status("Невозможно дублировать: нет места в границах здания.")
		return
	_push_undo()
	_editor.blueprint.objects.append(copy)
	_spawn_node(copy)
	_editor.mark_dirty()
	_refresh_object_list()
	select_object(copy.id)
	_editor.set_status("Объект продублирован.")


func rotate_selection(axis: String, direction: int) -> void:
	var record := find_record(selected_object_id)
	var asset := WorldAssetCatalog.get_asset(record.asset_id if record != null else current_asset_id)
	if asset != null and not asset.is_rotation_axis_allowed(axis):
		_editor.set_status("Этот ассет нельзя вращать вокруг оси %s." % axis.to_upper())
		return
	var step := asset.quick_rotation_step if asset != null else ROTATION_STEP_DEG
	step = step if step > 0.0 else ROTATION_STEP_DEG
	var delta := step * direction
	if axis == "x":
		current_pitch_deg = fposmod(current_pitch_deg + delta, 360.0)
	elif axis == "y":
		current_yaw_deg = fposmod(current_yaw_deg + delta, 360.0)
	elif axis == "z":
		current_roll_deg = fposmod(current_roll_deg + delta, 360.0)
	else:
		push_warning("DecorModeController: invalid rotation axis '%s'" % axis)
		return
	if record != null:
		var candidate := Vector3(current_pitch_deg, current_yaw_deg, current_roll_deg)
		if not _is_valid_transform(record.pos, candidate, record.scale, record.asset_id, record.id):
			return
		_push_undo()
		record.rot = candidate
		_apply_transform_to_node(record)
		_editor.mark_dirty()
		_sync_transform_fields(record)
	refresh_ghost()


func _reset_rotation() -> void:
	current_pitch_deg = 0.0
	current_yaw_deg = 0.0
	current_roll_deg = 0.0
	var record := find_record(selected_object_id)
	if record != null:
		_push_undo()
		record.rot = Vector3.ZERO
		_apply_transform_to_node(record)
		_editor.mark_dirty()
		_sync_transform_fields(record)
	refresh_ghost()


func cancel_current_action() -> void:
	_dragging = false
	_drag_started = false
	if not selected_object_id.is_empty():
		select_object("")
		_editor.set_status("Выделение снято.")
		return
	if not current_asset_id.is_empty():
		_catalog_panel.clear_asset_selection()
		_editor.set_status("Кисть декора сброшена.")
		return
	_editor.set_status("Ничего не выбрано.")


## Monotonic-enough suffix for generated ids. `Time.get_ticks_msec()` alone
## collides when two objects are placed inside the same millisecond (duplicate
## then move), which would make two records share one node.
func _next_object_suffix() -> int:
	var suffix := Time.get_ticks_msec()
	var taken: Dictionary = {}
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		taken[record.id] = true
	while taken.has("decor_%s_%d" % [String(current_asset_id), suffix]):
		suffix += 1
	return suffix


# ---------------------------------------------------------------------------
# Undo / Redo (delegated to the editor-wide history)
# ---------------------------------------------------------------------------

func _push_undo() -> void:
	# Compatibility hook for fixture/decor callers.  The authoritative snapshot
	# is recorded by BuildingEditor.mark_dirty after the mutation.
	pass


func undo() -> bool:
	return _editor != null and _editor.undo()


func redo() -> bool:
	return _editor != null and _editor.redo()


func refresh_history_buttons() -> void:
	pass


func clear_undo_history() -> void:
	pass


# ---------------------------------------------------------------------------
# Scene nodes
# ---------------------------------------------------------------------------

func rebuild_nodes() -> void:
	for node: Node3D in _nodes.values():
		node.queue_free()
	_nodes.clear()
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		_spawn_node(record)
	_update_selection_marker()
	if _collision_overlay != null:
		_collision_overlay.rebuild(_editor.blueprint)


func _spawn_node(record: DecorObjectRecordScript) -> void:
	var asset := WorldAssetCatalog.get_asset(record.asset_id)
	if asset == null:
		push_warning("DecorModeController: unknown asset %s, object %s not shown" % [record.asset_id, record.id])
		return
	var scene := load(asset.scene_path) as PackedScene
	if scene == null:
		return
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return
	add_child(instance)
	_nodes[record.id] = instance
	_apply_transform_to_node(record)
	if instance.has_method("apply_decor_properties"):
		instance.call("apply_decor_properties", record.appearance)


func _apply_transform_to_node(record: DecorObjectRecordScript) -> void:
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
		_apply_preview_look(_ghost)
	_ghost.visible = true
	var ghost_pos := snapped_position(_editor.cursor_hit_pos)
	_ghost.position = ghost_pos
	_ghost.rotation_degrees = Vector3(current_pitch_deg, current_yaw_deg, current_roll_deg)
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
		_hover_marker = _create_torus_marker(Color(1.0, 0.8, 0.2, 0.9))
	var asset := WorldAssetCatalog.get_asset(record.asset_id)
	var size := asset.footprint_m() if asset != null else Vector3.ONE
	var radius := maxf(DecorPlacementValidatorScript.MIN_PICK_RADIUS, maxf(size.x, size.z) * 0.5 * maxf(record.scale.x, record.scale.z))
	_hover_marker.visible = true
	_hover_marker.scale = Vector3.ONE * (radius / 0.5)
	_hover_marker.position = record.pos + Vector3(0.0, 0.05, 0.0)


func _hide_ghost() -> void:
	if _ghost != null:
		_ghost.visible = false


## Updates the ghost material colour based on placement state (design §6.2).
func _update_ghost_color(state: int) -> void:
	var color: Color = GHOST_COLOR_VALID
	match state:
		DecorPlacementValidatorScript.GhostState.INTERSECTION:
			color = GHOST_COLOR_INTERSECTION
		DecorPlacementValidatorScript.GhostState.OUT_OF_BOUNDS:
			color = GHOST_COLOR_OUT_OF_BOUNDS
	_get_ghost_material().albedo_color = color


## Makes an instance read as a preview rather than a placed object: translucent
## meshes, no lights and no live particles. Without this the ghost lit the scene
## and was indistinguishable from real decor.
func _apply_preview_look(root: Node3D) -> void:
	var targets: Array[Node] = [root]
	targets.append_array(root.find_children("*", "", true, false))
	for node in targets:
		if node is Light3D:
			(node as Light3D).visible = false
		elif node is GPUParticles3D:
			(node as GPUParticles3D).emitting = false
		elif node is CPUParticles3D:
			(node as CPUParticles3D).emitting = false
		elif node is MeshInstance3D:
			(node as MeshInstance3D).material_override = _get_ghost_material()
		elif node is Label3D:
			(node as Label3D).modulate = Color(0.6, 0.9, 1.0, 0.6)


func _get_ghost_material() -> StandardMaterial3D:
	if _ghost_material == null:
		_ghost_material = StandardMaterial3D.new()
		_ghost_material.albedo_color = Color(0.45, 0.85, 1.0, 0.4)
		_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _ghost_material


func _create_torus_marker(color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	marker.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = material
	add_child(marker)
	return marker


func _update_selection_marker() -> void:
	var record := find_record(selected_object_id)
	if record == null or not is_active():
		if _selection_marker != null:
			_selection_marker.visible = false
		return
	if _selection_marker == null:
		_selection_marker = _create_torus_marker(Color(0.35, 0.95, 1.0, 0.85))
	var asset := WorldAssetCatalog.get_asset(record.asset_id)
	var size := asset.footprint_m() if asset != null else Vector3.ONE
	var radius := maxf(DecorPlacementValidatorScript.MIN_PICK_RADIUS, maxf(size.x, size.z) * 0.5 * maxf(record.scale.x, record.scale.z))
	_selection_marker.visible = true
	_selection_marker.scale = Vector3.ONE * (radius / 0.5)
	_selection_marker.position = record.pos + Vector3(0.0, 0.03, 0.0)


# ---------------------------------------------------------------------------
# Collision overlay — delegated to DecorCollisionOverlay node
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
	_inspector_panel.visible = is_active()
	_toolbar_delete_btn.disabled = selected_object_id.is_empty()
	_sync_object_list_selection()
	_refresh_inspector()
	_update_selection_marker()


func _on_object_list_selected(index: int) -> void:
	if _syncing_ui:
		return
	select_object(String(_object_list.get_item_metadata(index)))


func _refresh_object_list() -> void:
	_syncing_ui = true
	_object_list.clear()
	var search_text := _object_search_edit.text.strip_edges().to_lower() if _object_search_edit != null else ""
	var zone_filter := _get_zone_filter_selection()
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		var asset := WorldAssetCatalog.get_asset(record.asset_id)
		var label := asset.name if asset != null else "%s (нет ассета)" % record.asset_id
		if not search_text.is_empty():
			if not String(label).to_lower().contains(search_text) and not record.id.to_lower().contains(search_text):
				continue
		if zone_filter != &"" and record.owner_zone_id != zone_filter:
			continue
		var index := _object_list.add_item("%s  ·  %.1f, %.1f, %.1f" % [label, record.pos.x, record.pos.y, record.pos.z])
		_object_list.set_item_metadata(index, record.id)
	_syncing_ui = false
	_sync_object_list_selection()


func _sync_object_list_selection() -> void:
	_syncing_ui = true
	_object_list.deselect_all()
	for i in _object_list.item_count:
		if String(_object_list.get_item_metadata(i)) == selected_object_id:
			_object_list.select(i)
			break
	_syncing_ui = false


func _on_object_search_changed(_new_text: String) -> void:
	_refresh_object_list()


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
## Clears owner_zone_id on all decor objects that referenced it.
func on_zone_deleted(zone_id: StringName) -> void:
	var affected := 0
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		if record.owner_zone_id == zone_id:
			record.owner_zone_id = &""
			affected += 1
	if affected > 0:
		_editor.set_status("Зона «%s» удалена. Связь снята с %d предметов." % [String(zone_id), affected])
	_refresh_zone_filter_options()
	_refresh_object_list()
	_refresh_inspector()


func _refresh_inspector() -> void:
	for child in _controls_vbox.get_children():
		child.queue_free()

	var record := find_record(selected_object_id)
	if record == null:
		_set_transform_fields_enabled(false)
		_refresh_zone_options(&"", null)
		_update_zone_highlight()
		var selected_asset := WorldAssetCatalog.get_asset(current_asset_id)
		if selected_asset != null:
			_inspector_title.text = "Ассет: %s" % selected_asset.name
			_id_label.text = "Категория: %s" % WorldAssetCatalog.category_display_name(selected_asset.category)
			_asset_label.text = "Размер: %d×%d×%d м" % [selected_asset.size_in_blocks.x, selected_asset.size_in_blocks.y, selected_asset.size_in_blocks.z]
			_badges_label.text = selected_asset.description
			for control in selected_asset.appearance_controls:
				var row := _build_preview_control_row(selected_asset, control)
				if row != null:
					_controls_vbox.add_child(row)
		else:
			_inspector_title.text = "Инспектор декора"
			_id_label.text = "ID: —"
			_asset_label.text = "Выберите ассет в палитре или объект в 3D"
			_badges_label.text = ""
		return

	var asset := WorldAssetCatalog.get_asset(record.asset_id)
	_inspector_title.text = "Свойства: %s" % (asset.name if asset != null else String(record.asset_id))
	_id_label.text = "ID: %s" % record.id
	_asset_label.text = "Ассет: %s" % (asset.name if asset != null else String(record.asset_id))
	_set_transform_fields_enabled(true)
	_sync_transform_fields(record)
	_refresh_zone_options(record.owner_zone_id, record)
	_update_badges(record, asset)
	_update_zone_highlight()
	if asset == null:
		return

	for control in asset.appearance_controls:
		var row := _build_control_row(record, control)
		if row != null:
			_controls_vbox.add_child(row)


func _build_preview_control_row(asset: WorldAssetDef, control: Dictionary) -> Control:
	var property_name := String(control.get("name", ""))
	if property_name.is_empty():
		return null
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = String(control.get("label", property_name)) + ":"
	label.custom_minimum_size.x = 130
	row.add_child(label)

	var default_val: Variant = control.get("default", null)
	match String(control.get("type", WorldAssetDef.TYPE_STRING)):
		WorldAssetDef.TYPE_BOOL:
			var check := CheckBox.new()
			check.button_pressed = bool(default_val)
			check.disabled = true
			row.add_child(check)
		WorldAssetDef.TYPE_FLOAT:
			var spin := SpinBox.new()
			spin.min_value = float(control.get("min", 0.0))
			spin.max_value = float(control.get("max", 10.0))
			spin.step = float(control.get("step", 0.1))
			spin.value = float(default_val) if default_val != null else spin.min_value
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.editable = false
			row.add_child(spin)
		WorldAssetDef.TYPE_COLOR:
			var picker := ColorPickerButton.new()
			if default_val is Color:
				picker.color = default_val as Color
			elif default_val is String:
				picker.color = Color(default_val as String)
			picker.disabled = true
			row.add_child(picker)
		_:
			var val_label := Label.new()
			val_label.text = String(default_val)
			row.add_child(val_label)
	return row


func _build_control_row(record: DecorObjectRecordScript, control: Dictionary) -> Control:
	var property_name := String(control.get("name", ""))
	if property_name.is_empty():
		return null
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = String(control.get("label", property_name)) + ":"
	label.custom_minimum_size.x = 130
	row.add_child(label)

	var stored: Variant = record.appearance.get(property_name, control.get("default", null))
	match String(control.get("type", WorldAssetDef.TYPE_STRING)):
		WorldAssetDef.TYPE_BOOL:
			var check := CheckBox.new()
			check.button_pressed = bool(stored)
			check.toggled.connect(func(pressed: bool): _set_property(property_name, pressed))
			row.add_child(check)
		WorldAssetDef.TYPE_FLOAT:
			var spin := SpinBox.new()
			spin.min_value = float(control.get("min", 0.0))
			spin.max_value = float(control.get("max", 10.0))
			spin.step = float(control.get("step", 0.1))
			spin.value = float(stored) if stored != null else spin.min_value
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value_changed.connect(func(value: float): _set_property(property_name, value))
			row.add_child(spin)
		WorldAssetDef.TYPE_COLOR:
			var picker := ColorPickerButton.new()
			picker.color = DecorObjectController._to_color(stored)
			picker.custom_minimum_size = Vector2(48, 24)
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# Colours are stored as html strings so the blueprint stays JSON-safe.
			picker.color_changed.connect(func(color: Color): _set_property(property_name, color.to_html(false)))
			row.add_child(picker)
		_:
			var edit := LineEdit.new()
			edit.text = String(stored) if stored != null else ""
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.text_changed.connect(func(text: String): _set_property(property_name, text))
			row.add_child(edit)
	return row


func _set_property(property_name: String, value: Variant) -> void:
	var record := find_record(selected_object_id)
	if record == null:
		return
	if record.appearance.get(property_name, null) == value:
		return
	_push_undo()
	record.appearance[property_name] = value
	var node: Node3D = _nodes.get(record.id, null)
	if node != null and node.has_method("set_decor_property"):
		node.call("set_decor_property", property_name, value)
	_editor.mark_dirty()


func _set_transform_fields_enabled(enabled: bool) -> void:
	for spin in [_pos_x_spin, _pos_y_spin, _pos_z_spin, _pitch_spin, _yaw_spin, _roll_spin, _scale_spin]:
		spin.editable = enabled
	_duplicate_btn.disabled = not enabled
	_delete_btn.disabled = not enabled
	_replace_btn.disabled = not enabled


## Refresh the owner-zone dropdown from the blueprint's owning areas.
func _refresh_zone_options(current_zone: StringName, _record: DecorObjectRecordScript) -> void:
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
	_push_undo()
	record.owner_zone_id = _zone_option.get_item_metadata(index)
	_editor.mark_dirty()


## Show diagnostic badges for the selected object.
func _update_badges(record: DecorObjectRecordScript, asset: Variant) -> void:
	var badges: Array[String] = []
	if asset != null and asset.scale_mode != WorldAssetDef.SCALE_LOCKED:
		badges.append("Масштаб: %s" % String(asset.scale_mode))
	if asset != null and asset.blocking_navigation:
		badges.append("Блокирует навигацию")
	if record.owner_zone_id != &"":
		badges.append("Зона: %s" % String(record.owner_zone_id))
	_badges_label.text = "  ·  ".join(badges) if not badges.is_empty() else ""


## Replace the selected object's asset with the current catalog selection.
## Appearance properties that don't exist on the new asset are lost.
func _replace_selected_object() -> void:
	var record := find_record(selected_object_id)
	if record == null:
		_editor.set_status("Выберите объект для замены.")
		return
	if current_asset_id == &"":
		_editor.set_status("Выберите ассет в каталоге для замены.")
		return
	if current_asset_id == record.asset_id:
		_editor.set_status("Объект уже использует этот ассет.")
		return
	var old_asset := WorldAssetCatalog.get_asset(record.asset_id)
	var new_asset := WorldAssetCatalog.get_asset(current_asset_id)
	if new_asset == null:
		return
	# Count how many appearance properties will be lost.
	var lost_count := 0
	if old_asset != null:
		for key in record.appearance.keys():
			var found := false
			for control in new_asset.appearance_controls:
				if String(control.get("name", "")) == String(key):
					found = true
					break
			if not found:
				lost_count += 1
	_push_undo()
	var old_appearance := record.appearance.duplicate(true)
	record.asset_id = new_asset.id
	record.appearance = new_asset.default_appearance()
	# Carry over compatible properties: keys that exist in the new asset's
	# appearance_controls with a matching type, preserving the old value.
	if old_asset != null:
		var new_controls_by_name: Dictionary = {}
		for control in new_asset.appearance_controls:
			new_controls_by_name[String(control.get("name", ""))] = control
		for key in old_appearance.keys():
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
	_spawn_node_for_existing(record)
	_editor.mark_dirty()
	_refresh_object_list()
	_refresh_inspector()
	if lost_count > 0:
		_editor.set_status("Заменён на «%s». Потеряно свойств: %d." % [new_asset.name, lost_count])
	else:
		_editor.set_status("Заменён на «%s»." % new_asset.name)


## Re-spawn the visual node for an existing record (used by replace).
func _spawn_node_for_existing(record: DecorObjectRecordScript) -> void:
	_remove_node(record.id)
	_spawn_node(record)


func _sync_transform_fields(record: DecorObjectRecordScript) -> void:
	_syncing_ui = true
	_pos_x_spin.value = record.pos.x
	_pos_y_spin.value = record.pos.y
	_pos_z_spin.value = record.pos.z
	_pitch_spin.value = record.rot.x
	_yaw_spin.value = record.rot.y
	_roll_spin.value = record.rot.z
	_scale_spin.value = record.scale.x
	_syncing_ui = false


func _on_transform_spin_changed(_value: float) -> void:
	if _syncing_ui:
		return
	var record := find_record(selected_object_id)
	if record == null:
		return
	var old_pos := record.pos
	var old_rot := record.rot
	var old_scale := record.scale
	var candidate_pos := Vector3(_pos_x_spin.value, _pos_y_spin.value, _pos_z_spin.value)
	var candidate_rot := Vector3(_pitch_spin.value, _yaw_spin.value, _roll_spin.value)
	# Clamp scale by asset policy.
	var asset := WorldAssetCatalog.get_asset(record.asset_id)
	var scale_val := _scale_spin.value
	if asset != null:
		if not asset.is_scale_allowed(scale_val):
			# Snap to the closest allowed value.
			match asset.scale_mode:
				WorldAssetDef.SCALE_LOCKED:
					scale_val = 1.0
				WorldAssetDef.SCALE_UNIFORM_STEPS:
					var best := asset.allowed_scales[0] if not asset.allowed_scales.is_empty() else 1.0
					var best_diff := absf(scale_val - best)
					for allowed in asset.allowed_scales:
						var diff := absf(scale_val - allowed)
						if diff < best_diff:
							best = allowed
							best_diff = diff
					scale_val = best
				WorldAssetDef.SCALE_FREE_UNIFORM:
					if asset.allowed_scales.size() >= 2:
						scale_val = clampf(scale_val, asset.allowed_scales[0], asset.allowed_scales[-1])
					else:
						scale_val = maxf(0.001, scale_val)
			_syncing_ui = true
			_scale_spin.value = scale_val
			_syncing_ui = false
	var candidate_scale := Vector3.ONE * scale_val
	if not _is_valid_transform(candidate_pos, candidate_rot, candidate_scale, record.asset_id, record.id):
		_sync_transform_fields(record)
		_editor.set_status("Этот трансформ пересекает каркас, проход или препятствие.")
		return
	if not old_pos.is_equal_approx(candidate_pos) or not old_rot.is_equal_approx(candidate_rot) or not old_scale.is_equal_approx(candidate_scale):
		_push_undo()
	record.pos = candidate_pos
	record.rot = candidate_rot
	record.scale = candidate_scale
	_apply_transform_to_node(record)
	_update_selection_marker()
	_editor.mark_dirty()


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
