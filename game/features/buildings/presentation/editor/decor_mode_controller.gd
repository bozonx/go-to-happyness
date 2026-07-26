class_name DecorModeController
extends Node3D

## Decor mode of the building editor (design §3.3): places, selects, moves and
## configures the `objects[]` of a blueprint.
##
## Lives as a child of BuildingEditor and owns everything decor-specific — the
## spawned instances, the placement ghost, the selection marker and its own undo
## stack — so the editor script only routes input and mode switching here.
##
## Three tools share the left mouse button: PLACE drops the catalog selection,
## SELECT picks and drags an existing object, ERASE removes the one under the
## cursor.

const FurnishingAssetCatalogScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_catalog.gd")
const FurnishingAssetDefScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_def.gd")
const DecorObjectRecordScript = preload("res://game/features/buildings/domain/editor/decor_object_record.gd")
const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")
const FireSourceDefaultsScript = preload("res://game/features/buildings/domain/editor/fire_source_defaults.gd")
const ZoneRequirementsScript = preload("res://game/features/buildings/domain/editor/zone_requirements.gd")

enum Tool { PLACE, SELECT, ERASE }

const ROTATION_STEP_DEG := 15.0
const UNDO_LIMIT := 40
const REDO_LIMIT := 40
const RECENT_ASSET_LIMIT := 6
## Minimum click radius, so thin objects (a flag pole) stay pickable.
const MIN_PICK_RADIUS := 0.35

## Ghost feedback colours (design §6.2).
const GHOST_COLOR_VALID := Color(0.45, 0.85, 1.0, 0.4)
const GHOST_COLOR_INTERSECTION := Color(1.0, 0.3, 0.2, 0.5)
const GHOST_COLOR_OUT_OF_BOUNDS := Color(1.0, 0.85, 0.2, 0.5)

enum GhostState { VALID, INTERSECTION, OUT_OF_BOUNDS }

var current_group: StringName = &""  ## empty = all groups
var current_category: StringName = &"camping"
var current_asset_id: StringName = &""
var current_snap_step: float = 1.0
var current_tool: int = Tool.PLACE
var current_yaw_deg: float = 0.0
var selected_object_id: String = ""

## Cycle-selection state: when the cursor is over overlapping objects,
## repeated clicks cycle through them instead of always picking the nearest.
var _last_pick_pos: Vector3 = Vector3(INF, INF, INF)
var _pick_cycle_index: int = 0
var _last_picked_ids: Array[String] = []

var _editor: Node = null
var _nodes: Dictionary = {}  ## object id (String) -> Node3D
var _ghost: Node3D = null
var _ghost_asset_id: StringName = &""
var _ghost_material: StandardMaterial3D = null
var _selection_marker: MeshInstance3D = null
var _undo_stack: Array = []
var _redo_stack: Array = []
var _recent_assets: Array[StringName] = []
var _search_edit: LineEdit = null
var _recent_container: HFlowContainer = null
var _recent_label: Label = null
var _object_search_edit: LineEdit = null
var _id_label: Label = null
var _asset_label: Label = null
var _badges_label: Label = null
var _zone_option: OptionButton = null
var _replace_btn: Button = null
var _undo_btn: Button = null
var _redo_btn: Button = null
var _dragging: bool = false
## Grab offset so dragging moves the object relative to where it was picked up.
var _drag_offset: Vector3 = Vector3.ZERO
var _drag_started: bool = false
## Guards the inspector's own writes from re-entering as user edits.
var _syncing_ui: bool = false

var _panel: PanelContainer = null
var _inspector_panel: PanelContainer = null
var _toolbar: HBoxContainer = null
var _group_option: OptionButton = null
var _category_option: OptionButton = null
var _asset_container: VBoxContainer = null
var _asset_hint: Label = null
var _snap_buttons: Dictionary = {} ## float snap step -> Button
var _inspector_title: Label = null
var _object_list: ItemList = null
var _controls_vbox: VBoxContainer = null
var _pos_x_spin: SpinBox = null
var _pos_y_spin: SpinBox = null
var _pos_z_spin: SpinBox = null
var _yaw_spin: SpinBox = null
var _scale_spin: SpinBox = null
var _duplicate_btn: Button = null
var _delete_btn: Button = null
var _rot_label: Label = null
var _layer_label: Label = null
var _collision_overlay_btn: Button = null
var _show_collision_overlay: bool = false
var _collision_overlays: Dictionary = {}  ## object id (String) -> Array[MeshInstance3D]
var _zone_filter_option: OptionButton = null
var _zone_highlight: MeshInstance3D = null
var _zone_out_of_bounds_label: Label = null
var _tool_buttons: Dictionary = {}
var _asset_buttons: Dictionary = {}
var _recent_buttons: Dictionary = {}

# Fixture editor UI
var _fixture_list: ItemList = null
var _fixture_id_label: Label = null
var _fixture_cap_option: OptionButton = null
var _fixture_visual_option: OptionButton = null
var _fixture_zone_option: OptionButton = null
var _fixture_fire_defaults_lbl: Label = null
var _fixture_fire_grid: GridContainer = null
var _fixture_lit_check: CheckBox = null
var _fixture_fuel_spin: SpinBox = null
var _fixture_cap_fuel_spin: SpinBox = null
var _selected_fixture_index: int = -1


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(editor: Node) -> void:
	_editor = editor
	name = "DecorRoot"

	_panel = editor.get_node("%DecorPanel")
	_inspector_panel = editor.get_node("%DecorInspectorPanel")
	_toolbar = editor.get_node("%DecorToolbar")
	_group_option = editor.get_node("%DecorGroupOption")
	_category_option = editor.get_node("%DecorCategoryOption")
	_search_edit = editor.get_node("%DecorSearchEdit")
	_recent_label = editor.get_node("%DecorRecentLbl")
	_recent_container = editor.get_node("%DecorRecentContainer")
	_asset_container = editor.get_node("%DecorAssetContainer")
	_asset_hint = editor.get_node("%DecorAssetHint")
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
	_scale_spin = editor.get_node("%DecorScaleSpin")
	_replace_btn = editor.get_node("%DecorReplaceBtn")
	_duplicate_btn = editor.get_node("%DecorDuplicateBtn")
	_delete_btn = editor.get_node("%DecorDeleteBtn")
	_undo_btn = editor.get_node("%DecorUndoBtn")
	_redo_btn = editor.get_node("%DecorRedoBtn")
	_rot_label = editor.get_node("%DecorRotLabel")
	_layer_label = editor.get_node("%DecorLayerLabel")

	# Fixture editor UI
	_fixture_list = editor.get_node("%FixtureList")
	_fixture_id_label = editor.get_node("%FixtureIdLbl")
	_fixture_cap_option = editor.get_node("%FixtureCapabilityOption")
	_fixture_visual_option = editor.get_node("%FixtureVisualOption")
	_fixture_zone_option = editor.get_node("%FixtureZoneOption")
	_fixture_fire_defaults_lbl = editor.get_node("%FixtureFireDefaultsLbl")
	_fixture_fire_grid = editor.get_node("%FixtureFireGrid")
	_fixture_lit_check = editor.get_node("%FixtureLitCheck")
	_fixture_fuel_spin = editor.get_node("%FixtureFuelSpin")
	_fixture_cap_fuel_spin = editor.get_node("%FixtureCapFuelSpin")

	editor.get_node("%FixtureAddBtn").pressed.connect(_add_fixture)
	editor.get_node("%FixtureDeleteBtn").pressed.connect(_delete_fixture)
	_fixture_list.item_selected.connect(_on_fixture_list_selected)
	_fixture_cap_option.item_selected.connect(_on_fixture_capability_selected)
	_fixture_visual_option.item_selected.connect(_on_fixture_visual_selected)
	_fixture_zone_option.item_selected.connect(_on_fixture_zone_selected)
	_fixture_lit_check.toggled.connect(_on_fixture_fire_param_changed)
	_fixture_fuel_spin.value_changed.connect(_on_fixture_fire_param_changed)
	_fixture_cap_fuel_spin.value_changed.connect(_on_fixture_fire_param_changed)

	_build_fixture_capability_options()

	_tool_buttons[Tool.PLACE] = editor.get_node("%DecorToolPlaceBtn")
	_tool_buttons[Tool.SELECT] = editor.get_node("%DecorToolSelectBtn")
	_tool_buttons[Tool.ERASE] = editor.get_node("%DecorToolEraseBtn")
	for tool_id in _tool_buttons.keys():
		var button: Button = _tool_buttons[tool_id]
		button.pressed.connect(_set_tool.bind(tool_id))

	editor.get_node("%DecorRotLeftBtn").pressed.connect(rotate_selection.bind(-ROTATION_STEP_DEG))
	editor.get_node("%DecorRotRightBtn").pressed.connect(rotate_selection.bind(ROTATION_STEP_DEG))
	editor.get_node("%DecorRotResetBtn").pressed.connect(_reset_rotation)
	editor.get_node("%DecorLayerDownBtn").pressed.connect(func(): _editor.set_layer(_editor.active_layer - 1))
	editor.get_node("%DecorLayerUpBtn").pressed.connect(func(): _editor.set_layer(_editor.active_layer + 1))
	_collision_overlay_btn = editor.get_node("%DecorCollisionOverlayBtn")
	_collision_overlay_btn.toggled.connect(_on_collision_overlay_toggled)

	_build_group_options()
	_build_snap_options()

	_category_option.item_selected.connect(_on_category_selected)
	_group_option.item_selected.connect(_on_group_selected)
	_search_edit.text_changed.connect(_on_search_changed)
	_object_search_edit.text_changed.connect(_on_object_search_changed)
	_object_list.item_selected.connect(_on_object_list_selected)
	_zone_option.item_selected.connect(_on_zone_selected)
	_zone_filter_option.item_selected.connect(_on_zone_filter_selected)
	_duplicate_btn.pressed.connect(duplicate_selection)
	_delete_btn.pressed.connect(delete_selection)
	_replace_btn.pressed.connect(_replace_selected_object)
	_undo_btn.pressed.connect(undo)
	_redo_btn.pressed.connect(redo)
	_pos_x_spin.value_changed.connect(_on_transform_spin_changed)
	_pos_y_spin.value_changed.connect(_on_transform_spin_changed)
	_pos_z_spin.value_changed.connect(_on_transform_spin_changed)
	_yaw_spin.value_changed.connect(_on_transform_spin_changed)
	_scale_spin.value_changed.connect(_on_transform_spin_changed)

	current_category = FurnishingAssetCatalogScript.first_populated_category(current_category)
	_rebuild_category_options()
	_rebuild_asset_buttons()
	_set_tool(Tool.PLACE)
	_update_rotation_label()


func _build_group_options() -> void:
	_group_option.clear()
	_group_option.add_item("Все группы")
	_group_option.set_item_metadata(0, &"")
	for group_id in FurnishingAssetCatalogScript.GROUPS.keys():
		_group_option.add_item(String(FurnishingAssetCatalogScript.GROUPS[group_id]))
		_group_option.set_item_metadata(_group_option.item_count - 1, group_id)
	_group_option.select(0)


func _build_snap_options() -> void:
	_snap_buttons = {1.0: _editor.get_node("%DecorSnap1Btn"), 0.5: _editor.get_node("%DecorSnapHalfBtn"), 0.25: _editor.get_node("%DecorSnapQuarterBtn")}
	for step in _snap_buttons.keys():
		(_snap_buttons[step] as Button).pressed.connect(_select_snap_step.bind(float(step)))
	_select_snap_step(1.0)
	current_snap_step = 1.0


# ---------------------------------------------------------------------------
# Mode lifecycle
# ---------------------------------------------------------------------------

func activate() -> void:
	# Picks up `.tres` assets authored since the editor opened.
	FurnishingAssetCatalogScript.refresh()
	current_category = FurnishingAssetCatalogScript.first_populated_category(current_category)
	_rebuild_category_options()
	_rebuild_asset_buttons()
	_rebuild_recent_assets()
	_panel.visible = true
	_toolbar.visible = true
	rebuild_nodes()
	_refresh_zone_filter_options()
	_refresh_object_list()
	_refresh_inspector()
	refresh_fixture_ui()
	_update_layer_label()
	_update_undo_redo_buttons()


func deactivate() -> void:
	_panel.visible = false
	_inspector_panel.visible = false
	_toolbar.visible = false
	_dragging = false
	_hide_ghost()
	_update_selection_marker()
	_clear_collision_overlays()


func is_active() -> bool:
	return _editor != null and _panel != null and _panel.visible


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func on_left_pressed() -> void:
	if not _editor.cursor_valid:
		return
	var hit: Vector3 = _editor.cursor_hit_pos
	match current_tool:
		Tool.PLACE:
			_place_or_select_at(hit)
		Tool.SELECT:
			var picked := pick_object_at(hit)
			select_object(picked)
			if not picked.is_empty():
				var record := find_record(picked)
				_drag_offset = record.pos - Vector3(hit.x, record.pos.y, hit.z)
				_dragging = true
				_drag_started = false
		Tool.ERASE:
			var target := pick_object_at(hit)
			if target.is_empty():
				_editor.set_status("Под курсором нет объекта декора.")
			else:
				_push_undo()
				_erase_object(target)
				_editor.set_status("Объект удалён.")


func on_left_released() -> void:
	_dragging = false
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
	if not _is_in_bounds(candidate, record.asset_id, record.scale):
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
		KEY_B:
			_set_tool(Tool.PLACE)
			return true
		KEY_V:
			_set_tool(Tool.SELECT)
			return true
		KEY_E:
			_set_tool(Tool.ERASE)
			return true
		KEY_C, KEY_R:
			rotate_selection(-ROTATION_STEP_DEG if event.shift_pressed else ROTATION_STEP_DEG)
			return true
		KEY_DELETE:
			delete_selection()
			return true
	return false


func _set_tool(tool_id: int) -> void:
	current_tool = tool_id
	for id in _tool_buttons.keys():
		(_tool_buttons[id] as Button).button_pressed = id == tool_id
	if tool_id != Tool.PLACE:
		_hide_ghost()
	refresh_ghost()


# ---------------------------------------------------------------------------
# Placement maths
# ---------------------------------------------------------------------------

## Snap grid points are the *centres* of `step`-sized cells, so an object always
## lands centred in its snap cell (1.0 → block centres, 0.5 → half-block centres).
## Free placement (step 0) is only allowed when the asset's snap_steps includes 0.
func snapped_position(raw_hit: Vector3) -> Vector3:
	var y := float(_editor.active_layer)
	var asset := FurnishingAssetCatalogScript.get_asset(current_asset_id)
	var step := current_snap_step
	# If the asset restricts snap steps, clamp to the closest allowed one.
	if asset != null and not asset.snap_steps.is_empty():
		var best_step := asset.snap_steps[0]
		var best_diff := absf(step - best_step)
		for allowed in asset.snap_steps:
			var diff := absf(step - allowed)
			if diff < best_diff:
				best_step = allowed
				best_diff = diff
		step = best_step
	if step <= 0.001:
		return Vector3(raw_hit.x, y, raw_hit.z)
	var half := step * 0.5
	return Vector3(
		snappedf(raw_hit.x - half, step) + half,
		y,
		snappedf(raw_hit.z - half, step) + half)


## Returns true when the position is inside the building footprint.
func _is_in_bounds(pos: Vector3, asset_id: StringName = current_asset_id, scale: Vector3 = Vector3.ONE) -> bool:
	if _editor == null or _editor.blueprint == null:
		return true
	var footprint: Vector2i = _editor.blueprint.footprint
	var asset := FurnishingAssetCatalogScript.get_asset(asset_id)
	var size := asset.footprint_m() if asset != null else Vector3.ONE
	var half_x := size.x * scale.x * 0.5
	var half_z := size.z * scale.z * 0.5
	return pos.x - half_x >= 0.0 and pos.x + half_x <= float(footprint.x) and pos.z - half_z >= 0.0 and pos.z + half_z <= float(footprint.y)


## Returns true when the position overlaps an existing decor object.
func _is_intersecting(pos: Vector3, exclude_id: String = "") -> bool:
	var asset := FurnishingAssetCatalogScript.get_asset(current_asset_id)
	var my_size := asset.footprint_m() if asset != null else Vector3.ONE
	var my_radius := maxf(my_size.x, my_size.z) * 0.5
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		if record.id == exclude_id:
			continue
		var other_asset := FurnishingAssetCatalogScript.get_asset(record.asset_id)
		var other_size := other_asset.footprint_m() if other_asset != null else Vector3.ONE
		var other_radius := maxf(other_size.x, other_size.z) * 0.5 * maxf(record.scale.x, record.scale.z)
		var dist := Vector2(pos.x - record.pos.x, pos.z - record.pos.z).length()
		if dist < my_radius + other_radius:
			return true
	return false


## Computes the current ghost state for placement feedback.
func _compute_ghost_state(pos: Vector3) -> int:
	if not _is_in_bounds(pos):
		return GhostState.OUT_OF_BOUNDS
	if _is_collision_conflict(pos):
		return GhostState.INTERSECTION
	if _is_intersecting(pos):
		return GhostState.INTERSECTION
	return GhostState.VALID


## Objects whose footprint contains `world_pos`, sorted nearest first.
## Returns all candidates so the caller can cycle through overlapping ones.
func _pick_objects_at(world_pos: Vector3) -> Array[String]:
	var candidates: Array[Dictionary] = []
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		var asset := FurnishingAssetCatalogScript.get_asset(record.asset_id)
		var size := asset.footprint_m() if asset != null else Vector3.ONE
		var radius := maxf(MIN_PICK_RADIUS, maxf(size.x, size.z) * 0.5 * maxf(record.scale.x, record.scale.z))
		var distance := Vector2(record.pos.x - world_pos.x, record.pos.z - world_pos.z).length()
		if distance <= radius:
			candidates.append({"id": record.id, "dist": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["dist"]) < float(b["dist"]))
	var result: Array[String] = []
	for c in candidates:
		result.append(String(c["id"]))
	return result


## Picks one object at `world_pos`. On repeated clicks at the same position,
## cycles through overlapping candidates instead of always returning the nearest.
func pick_object_at(world_pos: Vector3) -> String:
	var ids := _pick_objects_at(world_pos)
	if ids.is_empty():
		_last_pick_pos = Vector3(INF, INF, INF)
		_pick_cycle_index = 0
		_last_picked_ids = []
		return ""
	# If the cursor moved significantly, reset cycle state.
	if world_pos.distance_to(_last_pick_pos) > MIN_PICK_RADIUS:
		_last_pick_pos = world_pos
		_pick_cycle_index = 0
		_last_picked_ids = ids
	elif ids != _last_picked_ids:
		# Object list changed (e.g. after placement); reset.
		_last_pick_pos = world_pos
		_pick_cycle_index = 0
		_last_picked_ids = ids
	var idx := _pick_cycle_index % ids.size()
	_pick_cycle_index += 1
	return ids[idx]


func find_record(object_id: String) -> DecorObjectRecordScript:
	if object_id.is_empty():
		return null
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		if record.id == object_id:
			return record
	return null


# ---------------------------------------------------------------------------
# Mutations
# ---------------------------------------------------------------------------

## In placement mode an existing object takes precedence over the catalog
## selection. This makes a click on decor behave like selection instead of
## silently stacking another instance inside it.
func _place_or_select_at(hit: Vector3) -> void:
	var target := pick_object_at(hit)
	if not target.is_empty():
		select_object(target)
		_editor.set_status("Выбран объект под курсором.")
		return
	var position := snapped_position(hit)
	if _compute_ghost_state(position) != GhostState.VALID:
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
	var asset := FurnishingAssetCatalogScript.get_asset(current_asset_id)
	if asset == null:
		_editor.set_status("Выберите ассет в каталоге декора.")
		return
	# Keep the invariant at the mutation boundary too: UI input is not the only
	# caller of this method, and a red preview must never still create an overlap.
	if _compute_ghost_state(position) != GhostState.VALID:
		_editor.set_status("Нельзя разместить декор поверх другого объекта.")
		return
	_push_undo()
	var record := DecorObjectRecordScript.make(asset.id, position, _next_object_suffix())
	record.rot = Vector3(0.0, current_yaw_deg, 0.0)
	record.appearance = asset.default_appearance()
	_editor.blueprint.objects.append(record)
	_spawn_node(record)
	_add_recent_asset(asset.id)
	_editor.mark_dirty()
	_refresh_object_list()
	select_object(record.id)
	_editor.set_status("Поставлен «%s». Всего объектов: %d" % [asset.name, _editor.blueprint.objects.size()])


func _erase_object(object_id: String) -> void:
	for i in range(_editor.blueprint.objects.size() - 1, -1, -1):
		if _editor.blueprint.objects[i].id == object_id:
			_editor.blueprint.objects.remove_at(i)
			break
	_remove_node(object_id)
	_editor.mark_dirty()
	_refresh_object_list()
	if selected_object_id == object_id:
		select_object("")
	# Warn if a fixture referenced this visual object.
	for f in _editor.blueprint.fixtures:
		if f.visual_object_id == object_id:
			_editor.set_status("ВНИМАНИЕ: объект «%s» использовался fixture «%s»." % [object_id, String(f.id)])
			break


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
	_push_undo()
	var copy := record.duplicate_record(_next_object_suffix())
	# Offset by one snap step so the copy is visible rather than hidden inside
	# the original.
	var offset := maxf(current_snap_step, 0.5)
	copy.pos += Vector3(offset, 0.0, offset)
	# Clamp to building bounds.
	if not _is_in_bounds(copy.pos):
		# Try offsetting in other directions.
		copy.pos = record.pos + Vector3(-offset, 0.0, offset)
		if not _is_in_bounds(copy.pos):
			copy.pos = record.pos + Vector3(offset, 0.0, -offset)
			if not _is_in_bounds(copy.pos):
				copy.pos = record.pos + Vector3(-offset, 0.0, -offset)
				if not _is_in_bounds(copy.pos):
					_editor.set_status("Невозможно дублировать: нет места в границах здания.")
					return
	_editor.blueprint.objects.append(copy)
	_spawn_node(copy)
	_editor.mark_dirty()
	_refresh_object_list()
	select_object(copy.id)
	_editor.set_status("Объект продублирован.")


func rotate_selection(delta_deg: float) -> void:
	# Use the asset's quick_rotation_step if available.
	var asset := FurnishingAssetCatalogScript.get_asset(current_asset_id)
	var step := asset.quick_rotation_step if asset != null else ROTATION_STEP_DEG
	if step <= 0.0:
		step = ROTATION_STEP_DEG
	# Only Y-axis rotation is supported in phase 1.
	current_yaw_deg = fposmod(current_yaw_deg + delta_deg, 360.0)
	_update_rotation_label()
	var record := find_record(selected_object_id)
	if record != null:
		_push_undo()
		record.rot.y = current_yaw_deg
		_apply_transform_to_node(record)
		_editor.mark_dirty()
		_sync_transform_fields(record)
	refresh_ghost()


func _reset_rotation() -> void:
	current_yaw_deg = 0.0
	_update_rotation_label()
	var record := find_record(selected_object_id)
	if record != null:
		_push_undo()
		record.rot.y = 0.0
		_apply_transform_to_node(record)
		_editor.mark_dirty()
		_sync_transform_fields(record)
	refresh_ghost()


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
# Undo / Redo (decor-scoped snapshots)
# ---------------------------------------------------------------------------

func _push_undo() -> void:
	var snapshot: Array = []
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		snapshot.append(record.to_dict())
	_undo_stack.append(snapshot)
	if _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()
	# Clear redo stack on new action.
	_redo_stack.clear()
	_update_undo_redo_buttons()


func undo() -> bool:
	if _undo_stack.is_empty():
		_editor.set_status("Отменять нечего.")
		return true
	# Push current state to redo stack.
	var current: Array = []
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		current.append(record.to_dict())
	_redo_stack.append(current)
	if _redo_stack.size() > REDO_LIMIT:
		_redo_stack.pop_front()
	var snapshot: Array = _undo_stack.pop_back()
	_editor.blueprint.objects.clear()
	for data in snapshot:
		_editor.blueprint.objects.append(DecorObjectRecordScript.from_dict(data))
	_editor.mark_dirty()
	rebuild_nodes()
	_refresh_object_list()
	if find_record(selected_object_id) == null:
		select_object("")
	else:
		select_object(selected_object_id)
	_editor.set_status("Отменено. Шагов в истории: %d" % _undo_stack.size())
	_update_undo_redo_buttons()
	return true


func redo() -> bool:
	if _redo_stack.is_empty():
		_editor.set_status("Повторять нечего.")
		return true
	# Push current state to undo stack.
	var current: Array = []
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		current.append(record.to_dict())
	_undo_stack.append(current)
	if _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()
	var snapshot: Array = _redo_stack.pop_back()
	_editor.blueprint.objects.clear()
	for data in snapshot:
		_editor.blueprint.objects.append(DecorObjectRecordScript.from_dict(data))
	_editor.mark_dirty()
	rebuild_nodes()
	_refresh_object_list()
	if find_record(selected_object_id) == null:
		select_object("")
	else:
		select_object(selected_object_id)
	_editor.set_status("Повторено. Шагов в истории: %d" % _redo_stack.size())
	_update_undo_redo_buttons()
	return true


func _update_undo_redo_buttons() -> void:
	if _undo_btn != null:
		_undo_btn.disabled = _undo_stack.is_empty()
	if _redo_btn != null:
		_redo_btn.disabled = _redo_stack.is_empty()


func clear_undo_history() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_update_undo_redo_buttons()


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
	if _show_collision_overlay:
		_rebuild_collision_overlays()


func _spawn_node(record: DecorObjectRecordScript) -> void:
	var asset := FurnishingAssetCatalogScript.get_asset(record.asset_id)
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
	if not is_active() or current_tool != Tool.PLACE or not _editor.cursor_valid:
		_hide_ghost()
		return
	var asset := FurnishingAssetCatalogScript.get_asset(current_asset_id)
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
	_ghost.rotation_degrees = Vector3(0.0, current_yaw_deg, 0.0)
	# Update ghost colour based on placement state.
	var state := _compute_ghost_state(ghost_pos)
	_update_ghost_color(state)


func _hide_ghost() -> void:
	if _ghost != null:
		_ghost.visible = false


## Updates the ghost material colour based on placement state (design §6.2).
func _update_ghost_color(state: int) -> void:
	var color: Color = GHOST_COLOR_VALID
	match state:
		GhostState.INTERSECTION:
			color = GHOST_COLOR_INTERSECTION
		GhostState.OUT_OF_BOUNDS:
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


func _update_selection_marker() -> void:
	var record := find_record(selected_object_id)
	if record == null or not is_active():
		if _selection_marker != null:
			_selection_marker.visible = false
		return
	if _selection_marker == null:
		_selection_marker = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.42
		torus.outer_radius = 0.5
		_selection_marker.mesh = torus
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.35, 0.95, 1.0, 0.85)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_selection_marker.material_override = material
		add_child(_selection_marker)
	var asset := FurnishingAssetCatalogScript.get_asset(record.asset_id)
	var size := asset.footprint_m() if asset != null else Vector3.ONE
	var radius := maxf(MIN_PICK_RADIUS, maxf(size.x, size.z) * 0.5 * maxf(record.scale.x, record.scale.z))
	_selection_marker.visible = true
	_selection_marker.scale = Vector3.ONE * (radius / 0.5)
	_selection_marker.position = record.pos + Vector3(0.0, 0.03, 0.0)


# ---------------------------------------------------------------------------
# Collision overlay (design §4.2 — authoring preview, not runtime)
# ---------------------------------------------------------------------------

## Toggle collision overlay on/off. When on, wireframe boxes are drawn for
## each object whose collision_policy is not "none", and blocking-navigation
## objects get an additional coloured marker.
func _on_collision_overlay_toggled(pressed: bool) -> void:
	_show_collision_overlay = pressed
	if not pressed:
		_clear_collision_overlays()
	else:
		_rebuild_collision_overlays()


func _clear_collision_overlays() -> void:
	for overlays in _collision_overlays.values():
		for mesh: MeshInstance3D in overlays:
			mesh.queue_free()
	_collision_overlays.clear()


func _rebuild_collision_overlays() -> void:
	_clear_collision_overlays()
	if not _show_collision_overlay:
		return
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		_build_collision_overlay_for(record)


## Creates wireframe overlay meshes for a single decor object.
func _build_collision_overlay_for(record: DecorObjectRecordScript) -> void:
	var asset := FurnishingAssetCatalogScript.get_asset(record.asset_id)
	if asset == null:
		return
	var policy := asset.collision_policy
	if policy == FurnishingAssetDefScript.COLLISION_NONE and not asset.blocking_navigation:
		return
	var overlays: Array[MeshInstance3D] = []
	var size := asset.footprint_m()
	# Scale the collision box by the object's uniform scale.
	var scaled_size := size * record.scale.x
	# Collision box (box or footprint policy).
	if policy == FurnishingAssetDefScript.COLLISION_BOX or policy == FurnishingAssetDefScript.COLLISION_FOOTPRINT:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = scaled_size
		box.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.4, 0.2, 0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		box.material_override = mat
		box.position = record.pos
		box.rotation_degrees = record.rot
		add_child(box)
		overlays.append(box)
	# Blocking-navigation marker: a small red sphere on top.
	if asset.blocking_navigation:
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		marker.mesh = sphere
		var mat2 := StandardMaterial3D.new()
		mat2.albedo_color = Color(1.0, 0.1, 0.1, 0.8)
		mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = mat2
		marker.position = record.pos + Vector3(0.0, scaled_size.y * 0.5 + 0.15, 0.0)
		add_child(marker)
		overlays.append(marker)
	_collision_overlays[record.id] = overlays


## Checks if the given position intersects any blocking object (collision_policy
## != none or blocking_navigation == true). Used for ghost feedback.
func _is_collision_conflict(pos: Vector3, exclude_id: String = "") -> bool:
	var asset := FurnishingAssetCatalogScript.get_asset(current_asset_id)
	if asset == null:
		return false
	var my_size := asset.footprint_m()
	var my_radius := maxf(my_size.x, my_size.z) * 0.5
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		if record.id == exclude_id:
			continue
		var other_asset := FurnishingAssetCatalogScript.get_asset(record.asset_id)
		if other_asset == null:
			continue
		# Only check against objects that have collision or block navigation.
		if other_asset.collision_policy == FurnishingAssetDefScript.COLLISION_NONE and not other_asset.blocking_navigation:
			continue
		var other_size := other_asset.footprint_m()
		var other_radius := maxf(other_size.x, other_size.z) * 0.5 * maxf(record.scale.x, record.scale.z)
		var dist := Vector2(pos.x - record.pos.x, pos.z - record.pos.z).length()
		if dist < my_radius + other_radius:
			return true
	return false


# ---------------------------------------------------------------------------
# Catalog UI
# ---------------------------------------------------------------------------

func _on_group_selected(index: int) -> void:
	current_group = _group_option.get_item_metadata(index)
	_rebuild_category_options()
	_rebuild_asset_buttons()


func _rebuild_category_options() -> void:
	var counts := FurnishingAssetCatalogScript.category_counts()
	_category_option.clear()
	var selected_index := -1
	for category_id in FurnishingAssetCatalogScript.categories_in_group(current_group):
		var count := int(counts.get(category_id, 0))
		_category_option.add_item("%s (%d)" % [FurnishingAssetCatalogScript.category_display_name(category_id), count])
		var item_index := _category_option.item_count - 1
		_category_option.set_item_metadata(item_index, category_id)
		# Empty categories stay listed (they document what is planned) but cannot
		# be selected into a blank asset list.
		_category_option.set_item_disabled(item_index, count == 0)
		if category_id == current_category:
			selected_index = item_index
	if selected_index < 0:
		current_category = FurnishingAssetCatalogScript.first_populated_category(current_category)
		for i in _category_option.item_count:
			if _category_option.get_item_metadata(i) == current_category:
				selected_index = i
				break
	if selected_index >= 0:
		_category_option.select(selected_index)


func _on_category_selected(index: int) -> void:
	current_category = _category_option.get_item_metadata(index)
	_rebuild_asset_buttons()


## One toggle button per asset, mirroring the frame palette, instead of a second
## dropdown: the author sees every option at once.
## When the search field is non-empty, assets are filtered by name/description.
func _rebuild_asset_buttons() -> void:
	for child in _asset_container.get_children():
		child.queue_free()
	_asset_buttons.clear()

	var assets := FurnishingAssetCatalogScript.get_assets_by_category(current_category)
	var search_text := _search_edit.text.strip_edges().to_lower() if _search_edit != null else ""
	if not search_text.is_empty():
		# The top-bar search deliberately crosses category boundaries.
		assets = FurnishingAssetCatalogScript.get_all_assets()
		var filtered: Array = []
		for asset in assets:
			if String(asset.name).to_lower().contains(search_text) or String(asset.description).to_lower().contains(search_text):
				filtered.append(asset)
		assets = filtered

	if assets.is_empty():
		var empty_label := Label.new()
		if not search_text.is_empty():
			empty_label.text = "Ничего не найдено."
		else:
			empty_label.text = "В этой категории пока нет ассетов."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.75, 0.6, 0.4))
		_asset_container.add_child(empty_label)
		if search_text.is_empty():
			current_asset_id = &""
			_asset_hint.text = ""
		refresh_ghost()
		return

	var keep_selection := false
	for asset in assets:
		if asset.id == current_asset_id:
			keep_selection = true
	if not keep_selection:
		current_asset_id = assets[0].id

	for asset in assets:
		var button := Button.new()
		button.toggle_mode = true
		button.text = asset.name
		button.tooltip_text = asset.description
		# Long asset names must not widen the catalog panel; they ellipsize.
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.button_pressed = asset.id == current_asset_id
		button.pressed.connect(_select_asset.bind(asset.id))
		_asset_container.add_child(button)
		_asset_buttons[asset.id] = button
	_update_asset_hint()
	refresh_ghost()


func _select_asset(asset_id: StringName) -> void:
	current_asset_id = asset_id
	for id in _asset_buttons.keys():
		(_asset_buttons[id] as Button).button_pressed = id == asset_id
	# Choosing from the catalog means "I want to place this".
	_set_tool(Tool.PLACE)
	var asset := FurnishingAssetCatalogScript.get_asset(asset_id)
	if asset != null:
		_select_snap_step(asset.default_snap_step)
	_add_recent_asset(asset_id)
	_update_asset_hint()
	refresh_ghost()


func _on_search_changed(_new_text: String) -> void:
	_rebuild_asset_buttons()


## Track recently used assets for quick access.
func _add_recent_asset(asset_id: StringName) -> void:
	_recent_assets.erase(asset_id)
	_recent_assets.push_front(asset_id)
	if _recent_assets.size() > RECENT_ASSET_LIMIT:
		_recent_assets.resize(RECENT_ASSET_LIMIT)
	_rebuild_recent_assets()


## Rebuild the recently-used asset buttons row.
func _rebuild_recent_assets() -> void:
	for child in _recent_container.get_children():
		child.queue_free()
	_recent_buttons.clear()
	if _recent_assets.is_empty():
		_recent_label.visible = false
		return
	_recent_label.visible = true
	for asset_id in _recent_assets:
		var asset := FurnishingAssetCatalogScript.get_asset(asset_id)
		if asset == null:
			continue
		var button := Button.new()
		button.text = asset.name
		button.tooltip_text = asset.description
		button.custom_minimum_size = Vector2(80, 0)
		button.clip_text = true
		button.toggle_mode = true
		button.button_pressed = asset_id == current_asset_id
		button.pressed.connect(_select_asset.bind(asset_id))
		_recent_container.add_child(button)
		_recent_buttons[asset_id] = button


func _update_asset_hint() -> void:
	var asset := FurnishingAssetCatalogScript.get_asset(current_asset_id)
	if asset == null:
		_asset_hint.text = ""
		return
	var size := asset.footprint_m()
	_asset_hint.text = "%s\nРазмер: %.2f×%.2f×%.2f м" % [asset.description, size.x, size.y, size.z]


func _select_snap_step(step: float) -> void:
	if not _snap_buttons.has(step):
		return
	current_snap_step = step
	for snap_step in _snap_buttons.keys():
		(_snap_buttons[snap_step] as Button).button_pressed = is_equal_approx(float(snap_step), step)
	refresh_ghost()


# ---------------------------------------------------------------------------
# Inspector
# ---------------------------------------------------------------------------

func select_object(object_id: String) -> void:
	selected_object_id = object_id if find_record(object_id) != null else ""
	_inspector_panel.visible = is_active() and not selected_object_id.is_empty()
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
		var asset := FurnishingAssetCatalogScript.get_asset(record.asset_id)
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


## Rebuild the zone filter dropdown from the blueprint's place_zones.
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
		for i in _editor.blueprint.place_zones.size():
			var zone = _editor.blueprint.place_zones[i]
			_zone_filter_option.add_item(String(zone.zone_name))
			_zone_filter_option.set_item_metadata(_zone_filter_option.item_count - 1, zone.zone_id)
			if zone.zone_id == prev_selection:
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
	# Find the zone's cells to check bounds.
	var zone_cells: Array[Vector3i] = []
	for zone in _editor.blueprint.place_zones:
		if zone.zone_id == record.owner_zone_id:
			zone_cells = zone.cells
			break
	if zone_cells.is_empty():
		return
	# Check if the object position is within the zone's cell bounds.
	# floor maps cell-centre positions (e.g. 1.5) to the correct cell (1),
	# while round would snap 1.5 to 2 — a false out-of-zone warning.
	var obj_cell := Vector3i(int(floor(record.pos.x)), int(floor(record.pos.y)), int(floor(record.pos.z)))
	var in_zone := false
	for cell in zone_cells:
		if cell == obj_cell:
			in_zone = true
			break
	if not in_zone and _zone_out_of_bounds_label != null:
		_zone_out_of_bounds_label.text = "⚠ Предмет вне зоны «%s»" % _zone_name_for_id(record.owner_zone_id)
		_zone_out_of_bounds_label.visible = true


func _zone_name_for_id(zone_id: StringName) -> String:
	if _editor == null or _editor.blueprint == null:
		return String(zone_id)
	for zone in _editor.blueprint.place_zones:
		if zone.zone_id == zone_id:
			return String(zone.zone_name)
	return String(zone_id)


## Called by BuildingEditor when a place zone is deleted.
## Clears owner_zone_id on all decor objects that referenced it.
func on_zone_deleted(zone_id: StringName) -> void:
	var affected := 0
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		if record.owner_zone_id == zone_id:
			record.owner_zone_id = &""
			affected += 1
	if affected > 0:
		_editor.mark_dirty()
		_editor.set_status("Зона «%s» удалена. Связь снята с %d предметов." % [String(zone_id), affected])
	_refresh_zone_filter_options()
	_refresh_object_list()
	_refresh_inspector()


func _refresh_inspector() -> void:
	for child in _controls_vbox.get_children():
		child.queue_free()

	var record := find_record(selected_object_id)
	if record == null:
		_inspector_title.text = "Объект не выбран"
		_set_transform_fields_enabled(false)
		_id_label.text = "ID: —"
		_asset_label.text = "Ассет: —"
		_badges_label.text = ""
		_refresh_zone_options(&"", record)
		_update_zone_highlight()
		return

	var asset := FurnishingAssetCatalogScript.get_asset(record.asset_id)
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
	match String(control.get("type", FurnishingAssetDefScript.TYPE_STRING)):
		FurnishingAssetDefScript.TYPE_BOOL:
			var check := CheckBox.new()
			check.button_pressed = bool(stored)
			check.toggled.connect(func(pressed: bool): _set_property(property_name, pressed))
			row.add_child(check)
		FurnishingAssetDefScript.TYPE_FLOAT:
			var spin := SpinBox.new()
			spin.min_value = float(control.get("min", 0.0))
			spin.max_value = float(control.get("max", 10.0))
			spin.step = float(control.get("step", 0.1))
			spin.value = float(stored) if stored != null else spin.min_value
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value_changed.connect(func(value: float): _set_property(property_name, value))
			row.add_child(spin)
		FurnishingAssetDefScript.TYPE_COLOR:
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
	record.appearance[property_name] = value
	var node: Node3D = _nodes.get(record.id, null)
	if node != null and node.has_method("set_decor_property"):
		node.call("set_decor_property", property_name, value)
	_editor.mark_dirty()


func _set_transform_fields_enabled(enabled: bool) -> void:
	for spin in [_pos_x_spin, _pos_y_spin, _pos_z_spin, _yaw_spin, _scale_spin]:
		spin.editable = enabled
	_duplicate_btn.disabled = not enabled
	_delete_btn.disabled = not enabled
	_replace_btn.disabled = not enabled


## Refresh the owner-zone dropdown from the blueprint's place_zones.
func _refresh_zone_options(current_zone: StringName, _record: DecorObjectRecordScript) -> void:
	_syncing_ui = true
	_zone_option.clear()
	_zone_option.add_item("(без зоны)")
	_zone_option.set_item_metadata(0, &"")
	var selected_idx := 0
	if _editor != null and _editor.blueprint != null:
		for i in _editor.blueprint.place_zones.size():
			var zone = _editor.blueprint.place_zones[i]
			_zone_option.add_item(String(zone.zone_name))
			_zone_option.set_item_metadata(_zone_option.item_count - 1, zone.zone_id)
			if zone.zone_id == current_zone:
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
	if asset != null and asset.placement_surface != FurnishingAssetDefScript.SURFACE_ANY:
		badges.append("Поверхность: %s" % String(asset.placement_surface))
	if asset != null and asset.scale_mode != FurnishingAssetDefScript.SCALE_LOCKED:
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
	var old_asset := FurnishingAssetCatalogScript.get_asset(record.asset_id)
	var new_asset := FurnishingAssetCatalogScript.get_asset(current_asset_id)
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
				FurnishingAssetDefScript.TYPE_BOOL:
					compatible = old_value is bool
				FurnishingAssetDefScript.TYPE_FLOAT:
					compatible = old_value is float or old_value is int
				FurnishingAssetDefScript.TYPE_COLOR:
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
	_yaw_spin.value = record.rot.y
	_scale_spin.value = record.scale.x
	_syncing_ui = false


func _on_transform_spin_changed(_value: float) -> void:
	if _syncing_ui:
		return
	var record := find_record(selected_object_id)
	if record == null:
		return
	record.pos = Vector3(_pos_x_spin.value, _pos_y_spin.value, _pos_z_spin.value)
	record.rot.y = _yaw_spin.value
	# Clamp scale by asset policy.
	var asset := FurnishingAssetCatalogScript.get_asset(record.asset_id)
	var scale_val := _scale_spin.value
	if asset != null:
		if not asset.is_scale_allowed(scale_val):
			# Snap to the closest allowed value.
			match asset.scale_mode:
				FurnishingAssetDefScript.SCALE_LOCKED:
					scale_val = 1.0
				FurnishingAssetDefScript.SCALE_UNIFORM_STEPS:
					var best := asset.allowed_scales[0] if not asset.allowed_scales.is_empty() else 1.0
					var best_diff := absf(scale_val - best)
					for allowed in asset.allowed_scales:
						var diff := absf(scale_val - allowed)
						if diff < best_diff:
							best = allowed
							best_diff = diff
					scale_val = best
				FurnishingAssetDefScript.SCALE_FREE_UNIFORM:
					if asset.allowed_scales.size() >= 2:
						scale_val = clampf(scale_val, asset.allowed_scales[0], asset.allowed_scales[-1])
					else:
						scale_val = maxf(0.001, scale_val)
			_syncing_ui = true
			_scale_spin.value = scale_val
			_syncing_ui = false
	record.scale = Vector3.ONE * scale_val
	_apply_transform_to_node(record)
	_update_selection_marker()
	_editor.mark_dirty()


# ---------------------------------------------------------------------------
# Small UI sync helpers
# ---------------------------------------------------------------------------

func _update_rotation_label() -> void:
	if _rot_label != null:
		_rot_label.text = "%d°" % int(round(current_yaw_deg))


func _update_layer_label() -> void:
	if _layer_label != null and _editor != null:
		_layer_label.text = "Слой %d" % _editor.active_layer


func on_layer_changed() -> void:
	_update_layer_label()
	refresh_ghost()


# ---------------------------------------------------------------------------
# Fixtures (Phase 2A — fire_source vertical slice)
# ---------------------------------------------------------------------------

func _build_fixture_capability_options() -> void:
	_fixture_cap_option.clear()
	for cap in FixtureDefinitionScript.KNOWN_CAPABILITIES:
		_fixture_cap_option.add_item(String(cap))
		_fixture_cap_option.set_item_metadata(_fixture_cap_option.item_count - 1, cap)


func _refresh_fixture_list() -> void:
	_syncing_ui = true
	_fixture_list.clear()
	var fixtures: Array = _editor.blueprint.fixtures
	for i in fixtures.size():
		var fixture: FixtureDefinitionScript = fixtures[i]
		var cap_text := "—"
		if not fixture.capabilities.is_empty():
			cap_text = String(fixture.capabilities[0])
		_fixture_list.add_item("%s (%s)" % [String(fixture.id), cap_text])
	if _selected_fixture_index >= 0 and _selected_fixture_index < fixtures.size():
		_fixture_list.select(_selected_fixture_index)
	else:
		_selected_fixture_index = -1
	_syncing_ui = false
	_refresh_fixture_inspector()


func _refresh_fixture_inspector() -> void:
	var fixtures: Array = _editor.blueprint.fixtures
	var has_selection := _selected_fixture_index >= 0 and _selected_fixture_index < fixtures.size()
	_fixture_id_label.visible = has_selection
	_fixture_cap_option.disabled = not has_selection
	_fixture_visual_option.disabled = not has_selection
	_fixture_zone_option.disabled = not has_selection
	_fixture_fire_defaults_lbl.visible = false
	_fixture_fire_grid.visible = false
	if not has_selection:
		_fixture_id_label.text = "ID: —"
		return
	var fixture: FixtureDefinitionScript = fixtures[_selected_fixture_index]
	_fixture_id_label.text = "ID: %s" % String(fixture.id)
	# Capability dropdown — select first capability.
	_syncing_ui = true
	for i in _fixture_cap_option.item_count:
		if _fixture_cap_option.get_item_metadata(i) == fixture.capabilities[0] if not fixture.capabilities.is_empty() else null:
			_fixture_cap_option.select(i)
			break
	# Visual object dropdown — populate from blueprint objects.
	_fixture_visual_option.clear()
	_fixture_visual_option.add_item("— нет —")
	_fixture_visual_option.set_item_metadata(0, "")
	for obj in _editor.blueprint.objects:
		_fixture_visual_option.add_item(obj.id)
		_fixture_visual_option.set_item_metadata(_fixture_visual_option.item_count - 1, obj.id)
	for i in _fixture_visual_option.item_count:
		if String(_fixture_visual_option.get_item_metadata(i)) == fixture.visual_object_id:
			_fixture_visual_option.select(i)
			break
	# Zone dropdown — populate from blueprint place_zones.
	_fixture_zone_option.clear()
	_fixture_zone_option.add_item("— здание —")
	_fixture_zone_option.set_item_metadata(0, &"")
	for zone in _editor.blueprint.place_zones:
		_fixture_zone_option.add_item(zone.zone_name)
		_fixture_zone_option.set_item_metadata(_fixture_zone_option.item_count - 1, zone.zone_id)
	for i in _fixture_zone_option.item_count:
		if _fixture_zone_option.get_item_metadata(i) == fixture.owner_zone_id:
			_fixture_zone_option.select(i)
			break
	# Fire source defaults.
	var is_fire := fixture.has_capability(FixtureDefinitionScript.CAP_FIRE_SOURCE)
	_fixture_fire_defaults_lbl.visible = is_fire
	_fixture_fire_grid.visible = is_fire
	if is_fire:
		var defaults := FireSourceDefaultsScript.from_dict(fixture.runtime_defaults)
		_fixture_lit_check.button_pressed = defaults.lit
		_fixture_fuel_spin.value = defaults.fuel
		_fixture_cap_fuel_spin.value = defaults.fuel_capacity
	_syncing_ui = false


func _add_fixture() -> void:
	var fixture := FixtureDefinitionScript.new()
	var next_index := 1
	var existing_ids: Array = _editor.blueprint.fixtures.map(func(f): return String(f.id))
	while "fixture_%d" % next_index in existing_ids:
		next_index += 1
	fixture.id = StringName("fixture_%d" % next_index)
	fixture.capabilities = [FixtureDefinitionScript.CAP_FIRE_SOURCE]
	fixture.runtime_defaults = {"lit": true, "fuel": 4, "fuel_capacity": 10}
	_editor.blueprint.fixtures.append(fixture)
	_selected_fixture_index = _editor.blueprint.fixtures.size() - 1
	_editor.mark_dirty()
	_refresh_fixture_list()
	_editor.set_status("Fixture создан: %s" % String(fixture.id))


func _delete_fixture() -> void:
	if _selected_fixture_index < 0 or _selected_fixture_index >= _editor.blueprint.fixtures.size():
		return
	var fixture: FixtureDefinitionScript = _editor.blueprint.fixtures[_selected_fixture_index]
	# Check if deleting this fixture would violate zone requirements.
	var warning := _fixture_deletion_warning(fixture)
	if not warning.is_empty():
		_editor.set_status("ВНИМАНИЕ: %s" % warning)
	_editor.blueprint.fixtures.remove_at(_selected_fixture_index)
	_selected_fixture_index = mini(_selected_fixture_index, _editor.blueprint.fixtures.size() - 1)
	_editor.mark_dirty()
	_refresh_fixture_list()
	if warning.is_empty():
		_editor.set_status("Fixture удалён.")
	else:
		_editor.set_status("Fixture удалён. ВНИМАНИЕ: %s" % warning)


## Returns a warning message if removing the fixture would leave a zone
## without a required capability. Empty string if no violation.
func _fixture_deletion_warning(fixture: FixtureDefinitionScript) -> String:
	if fixture.owner_zone_id == &"":
		# Building-wide fixture: check all zones that have requirements.
		for zone in _editor.blueprint.place_zones:
			var required := ZoneRequirementsScript.required_capabilities_for_zone(zone)
			for cap in required:
				if not cap in fixture.capabilities:
					continue
				# Check if any other fixture still provides this cap for this zone.
				if not _zone_has_capability(zone.zone_id, cap, fixture):
					return "Зона «%s» останется без %s" % [zone.zone_name, ZoneRequirementsScript.capability_label(cap)]
		return ""
	# Zone-specific fixture: find the zone.
	for zone in _editor.blueprint.place_zones:
		if zone.zone_id != fixture.owner_zone_id:
			continue
		var required := ZoneRequirementsScript.required_capabilities_for_zone(zone)
		for cap in required:
			if not cap in fixture.capabilities:
				continue
			if not _zone_has_capability(zone.zone_id, cap, fixture):
				return "Зона «%s» останется без %s" % [zone.zone_name, ZoneRequirementsScript.capability_label(cap)]
		return ""
	return ""


## Returns true if any fixture (other than `exclude`) provides `cap` to the
## given zone (either zone-specific or building-wide).
func _zone_has_capability(zone_id: StringName, cap: StringName, exclude: FixtureDefinitionScript) -> bool:
	for f in _editor.blueprint.fixtures:
		if f == exclude:
			continue
		if f.owner_zone_id == zone_id or f.owner_zone_id == &"":
			if cap in f.capabilities:
				return true
	return false


func _on_fixture_list_selected(index: int) -> void:
	if _syncing_ui:
		return
	_selected_fixture_index = index
	_refresh_fixture_inspector()


func _on_fixture_capability_selected(index: int) -> void:
	if _syncing_ui or _selected_fixture_index < 0:
		return
	var fixture: FixtureDefinitionScript = _editor.blueprint.fixtures[_selected_fixture_index]
	var cap: StringName = _fixture_cap_option.get_item_metadata(index)
	# Replace capabilities with the single selected one (phase 2A: one cap per fixture).
	fixture.capabilities = [cap]
	_editor.mark_dirty()
	_refresh_fixture_inspector()


func _on_fixture_visual_selected(index: int) -> void:
	if _syncing_ui or _selected_fixture_index < 0:
		return
	var fixture: FixtureDefinitionScript = _editor.blueprint.fixtures[_selected_fixture_index]
	fixture.visual_object_id = String(_fixture_visual_option.get_item_metadata(index))
	_editor.mark_dirty()


func _on_fixture_zone_selected(index: int) -> void:
	if _syncing_ui or _selected_fixture_index < 0:
		return
	var fixture: FixtureDefinitionScript = _editor.blueprint.fixtures[_selected_fixture_index]
	fixture.owner_zone_id = _fixture_zone_option.get_item_metadata(index)
	_editor.mark_dirty()


func _on_fixture_fire_param_changed(_value: Variant) -> void:
	if _syncing_ui or _selected_fixture_index < 0:
		return
	var fixture: FixtureDefinitionScript = _editor.blueprint.fixtures[_selected_fixture_index]
	if not fixture.has_capability(FixtureDefinitionScript.CAP_FIRE_SOURCE):
		return
	fixture.runtime_defaults = {
		"lit": _fixture_lit_check.button_pressed,
		"fuel": int(_fixture_fuel_spin.value),
		"fuel_capacity": int(_fixture_cap_fuel_spin.value),
	}
	_editor.mark_dirty()


func refresh_fixture_ui() -> void:
	_refresh_fixture_list()
