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

const DecorAssetCatalogScript = preload("res://game/features/buildings/domain/editor/decor_asset_catalog.gd")
const DecorAssetDefScript = preload("res://game/features/buildings/domain/editor/decor_asset_def.gd")
const DecorObjectRecordScript = preload("res://game/features/buildings/domain/editor/decor_object_record.gd")

enum Tool { PLACE, SELECT, ERASE }

const ROTATION_STEP_DEG := 15.0
const UNDO_LIMIT := 40
## Minimum click radius, so thin objects (a flag pole) stay pickable.
const MIN_PICK_RADIUS := 0.35

var current_group: StringName = &""  ## empty = all groups
var current_category: StringName = &"camping"
var current_asset_id: StringName = &""
var current_snap_step: float = 0.5
var current_anchor: Vector2i = Vector2i.ZERO
var current_tool: int = Tool.PLACE
var current_yaw_deg: float = 0.0
var selected_object_id: String = ""

var _editor: Node = null
var _nodes: Dictionary = {}  ## object id (String) -> Node3D
var _ghost: Node3D = null
var _ghost_asset_id: StringName = &""
var _ghost_material: StandardMaterial3D = null
var _selection_marker: MeshInstance3D = null
var _undo_stack: Array = []
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
var _snap_option: OptionButton = null
var _anchor_pad: GridContainer = null
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
var _tool_buttons: Dictionary = {}
var _asset_buttons: Dictionary = {}
var _anchor_buttons: Dictionary = {}


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
	_asset_container = editor.get_node("%DecorAssetContainer")
	_asset_hint = editor.get_node("%DecorAssetHint")
	_snap_option = editor.get_node("%DecorSnapOption")
	_anchor_pad = editor.get_node("%DecorAnchorPad")
	_inspector_title = editor.get_node("%DecorInspectorTitle")
	_object_list = editor.get_node("%DecorObjectList")
	_controls_vbox = editor.get_node("%DecorControlsVBox")
	_pos_x_spin = editor.get_node("%DecorPosXSpin")
	_pos_y_spin = editor.get_node("%DecorPosYSpin")
	_pos_z_spin = editor.get_node("%DecorPosZSpin")
	_yaw_spin = editor.get_node("%DecorYawSpin")
	_scale_spin = editor.get_node("%DecorScaleSpin")
	_duplicate_btn = editor.get_node("%DecorDuplicateBtn")
	_delete_btn = editor.get_node("%DecorDeleteBtn")
	_rot_label = editor.get_node("%DecorRotLabel")
	_layer_label = editor.get_node("%DecorLayerLabel")

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

	_build_group_options()
	_build_snap_options()
	_build_anchor_pad()

	_category_option.item_selected.connect(_on_category_selected)
	_group_option.item_selected.connect(_on_group_selected)
	_snap_option.item_selected.connect(_on_snap_selected)
	_object_list.item_selected.connect(_on_object_list_selected)
	_duplicate_btn.pressed.connect(duplicate_selection)
	_delete_btn.pressed.connect(delete_selection)
	_pos_x_spin.value_changed.connect(_on_transform_spin_changed)
	_pos_y_spin.value_changed.connect(_on_transform_spin_changed)
	_pos_z_spin.value_changed.connect(_on_transform_spin_changed)
	_yaw_spin.value_changed.connect(_on_transform_spin_changed)
	_scale_spin.value_changed.connect(_on_transform_spin_changed)

	current_category = DecorAssetCatalogScript.first_populated_category(current_category)
	_rebuild_category_options()
	_rebuild_asset_buttons()
	_set_tool(Tool.PLACE)
	_update_rotation_label()


func _build_group_options() -> void:
	_group_option.clear()
	_group_option.add_item("Все группы")
	_group_option.set_item_metadata(0, &"")
	for group_id in DecorAssetCatalogScript.GROUPS.keys():
		_group_option.add_item(String(DecorAssetCatalogScript.GROUPS[group_id]))
		_group_option.set_item_metadata(_group_option.item_count - 1, group_id)
	_group_option.select(0)


func _build_snap_options() -> void:
	_snap_option.clear()
	for entry in [
		{"label": "1.0 м — центр блока", "step": 1.0},
		{"label": "0.5 м — полублок", "step": 0.5},
		{"label": "0.25 м — четверть", "step": 0.25},
		{"label": "Свободно", "step": 0.0},
	]:
		_snap_option.add_item(String(entry["label"]))
		_snap_option.set_item_metadata(_snap_option.item_count - 1, float(entry["step"]))
	_snap_option.select(1)
	current_snap_step = 0.5


## 3×3 in-cell anchor selector, matching the frame-mode anchor semantics: each
## component is −1 / 0 / +1 in the cell's own coordinate frame (design §3.3).
func _build_anchor_pad() -> void:
	for child in _anchor_pad.get_children():
		child.queue_free()
	_anchor_buttons.clear()
	for az in [-1, 0, 1]:
		for ax in [-1, 0, 1]:
			var anchor := Vector2i(ax, az)
			var button := Button.new()
			button.toggle_mode = true
			button.custom_minimum_size = Vector2(28, 28)
			button.text = "•" if anchor == Vector2i.ZERO else "◻"
			button.tooltip_text = _anchor_tooltip(anchor)
			button.button_pressed = anchor == current_anchor
			button.pressed.connect(_select_anchor.bind(anchor))
			_anchor_pad.add_child(button)
			_anchor_buttons[anchor] = button


func _anchor_tooltip(anchor: Vector2i) -> String:
	if anchor == Vector2i.ZERO:
		return "По центру ячейки"
	var parts: Array[String] = []
	if anchor.x != 0:
		parts.append("к грани %sX" % ("+" if anchor.x > 0 else "−"))
	if anchor.y != 0:
		parts.append("к грани %sZ" % ("+" if anchor.y > 0 else "−"))
	return "Прижать " + " и ".join(parts)


# ---------------------------------------------------------------------------
# Mode lifecycle
# ---------------------------------------------------------------------------

func activate() -> void:
	# Picks up `.tres` assets authored since the editor opened.
	DecorAssetCatalogScript.refresh()
	current_category = DecorAssetCatalogScript.first_populated_category(current_category)
	_rebuild_category_options()
	_rebuild_asset_buttons()
	_panel.visible = true
	_toolbar.visible = true
	rebuild_nodes()
	_refresh_object_list()
	_refresh_inspector()
	_update_layer_label()


func deactivate() -> void:
	_panel.visible = false
	_inspector_panel.visible = false
	_toolbar.visible = false
	_dragging = false
	_hide_ghost()
	_update_selection_marker()


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
			_place_at(snapped_position(hit))
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
	record.pos = snapped_position(hit + _drag_offset)
	_apply_transform_to_node(record)
	_editor.mark_dirty()
	_sync_transform_fields(record)
	_update_selection_marker()


## Returns true when the key was consumed by decor mode.
func handle_key(event: InputEventKey) -> bool:
	if event.ctrl_pressed:
		match event.keycode:
			KEY_Z:
				return undo()
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
## A non-zero in-cell anchor overrides the free grid and pins the object against
## the chosen side of the containing 1×1 cell (design §3.3).
func snapped_position(raw_hit: Vector3) -> Vector3:
	var y := float(_editor.active_layer)
	if current_anchor != Vector2i.ZERO:
		var asset := DecorAssetCatalogScript.get_asset(current_asset_id)
		var size := asset.footprint_m() if asset != null else Vector3.ONE
		var cell_x := floorf(raw_hit.x) + 0.5
		var cell_z := floorf(raw_hit.z) + 0.5
		var inset_x := maxf(0.0, 0.5 - size.x * 0.5)
		var inset_z := maxf(0.0, 0.5 - size.z * 0.5)
		return Vector3(cell_x + float(current_anchor.x) * inset_x, y, cell_z + float(current_anchor.y) * inset_z)
	if current_snap_step <= 0.001:
		return Vector3(raw_hit.x, y, raw_hit.z)
	var half := current_snap_step * 0.5
	return Vector3(
		snappedf(raw_hit.x - half, current_snap_step) + half,
		y,
		snappedf(raw_hit.z - half, current_snap_step) + half)


## Object whose footprint contains `world_pos`, nearest first. Empty when none.
func pick_object_at(world_pos: Vector3) -> String:
	var best_id := ""
	var best_distance := INF
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		var asset := DecorAssetCatalogScript.get_asset(record.asset_id)
		var size := asset.footprint_m() if asset != null else Vector3.ONE
		var radius := maxf(MIN_PICK_RADIUS, maxf(size.x, size.z) * 0.5 * maxf(record.scale.x, record.scale.z))
		var distance := Vector2(record.pos.x - world_pos.x, record.pos.z - world_pos.z).length()
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best_id = record.id
	return best_id


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

func _place_at(position: Vector3) -> void:
	var asset := DecorAssetCatalogScript.get_asset(current_asset_id)
	if asset == null:
		_editor.set_status("Выберите ассет в каталоге декора.")
		return
	_push_undo()
	var record := DecorObjectRecordScript.make(asset.id, position, _next_object_suffix())
	record.rot = Vector3(0.0, current_yaw_deg, 0.0)
	record.anchor = current_anchor
	record.properties = asset.default_properties()
	_editor.blueprint.objects.append(record)
	_spawn_node(record)
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
	_editor.blueprint.objects.append(copy)
	_spawn_node(copy)
	_editor.mark_dirty()
	_refresh_object_list()
	select_object(copy.id)
	_editor.set_status("Объект продублирован.")


func rotate_selection(delta_deg: float) -> void:
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
# Undo (decor-scoped snapshots)
# ---------------------------------------------------------------------------

func _push_undo() -> void:
	var snapshot: Array = []
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		snapshot.append(record.to_dict())
	_undo_stack.append(snapshot)
	if _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()


func undo() -> bool:
	if _undo_stack.is_empty():
		_editor.set_status("Отменять нечего.")
		return true
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
	return true


func clear_undo_history() -> void:
	_undo_stack.clear()


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


func _spawn_node(record: DecorObjectRecordScript) -> void:
	var asset := DecorAssetCatalogScript.get_asset(record.asset_id)
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
		instance.call("apply_decor_properties", record.properties)


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
	var asset := DecorAssetCatalogScript.get_asset(current_asset_id)
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
	_ghost.position = snapped_position(_editor.cursor_hit_pos)
	_ghost.rotation_degrees = Vector3(0.0, current_yaw_deg, 0.0)


func _hide_ghost() -> void:
	if _ghost != null:
		_ghost.visible = false


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
	var asset := DecorAssetCatalogScript.get_asset(record.asset_id)
	var size := asset.footprint_m() if asset != null else Vector3.ONE
	var radius := maxf(MIN_PICK_RADIUS, maxf(size.x, size.z) * 0.5 * maxf(record.scale.x, record.scale.z))
	_selection_marker.visible = true
	_selection_marker.scale = Vector3.ONE * (radius / 0.5)
	_selection_marker.position = record.pos + Vector3(0.0, 0.03, 0.0)


# ---------------------------------------------------------------------------
# Catalog UI
# ---------------------------------------------------------------------------

func _on_group_selected(index: int) -> void:
	current_group = _group_option.get_item_metadata(index)
	_rebuild_category_options()
	_rebuild_asset_buttons()


func _rebuild_category_options() -> void:
	var counts := DecorAssetCatalogScript.category_counts()
	_category_option.clear()
	var selected_index := -1
	for category_id in DecorAssetCatalogScript.categories_in_group(current_group):
		var count := int(counts.get(category_id, 0))
		_category_option.add_item("%s (%d)" % [DecorAssetCatalogScript.category_display_name(category_id), count])
		var item_index := _category_option.item_count - 1
		_category_option.set_item_metadata(item_index, category_id)
		# Empty categories stay listed (they document what is planned) but cannot
		# be selected into a blank asset list.
		_category_option.set_item_disabled(item_index, count == 0)
		if category_id == current_category:
			selected_index = item_index
	if selected_index < 0:
		current_category = DecorAssetCatalogScript.first_populated_category(current_category)
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
func _rebuild_asset_buttons() -> void:
	for child in _asset_container.get_children():
		child.queue_free()
	_asset_buttons.clear()

	var assets := DecorAssetCatalogScript.get_assets_by_category(current_category)
	if assets.is_empty():
		var empty_label := Label.new()
		empty_label.text = "В этой категории пока нет ассетов."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.75, 0.6, 0.4))
		_asset_container.add_child(empty_label)
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
	var asset := DecorAssetCatalogScript.get_asset(asset_id)
	if asset != null:
		_select_snap_step(asset.default_snap_step)
	_update_asset_hint()
	refresh_ghost()


func _update_asset_hint() -> void:
	var asset := DecorAssetCatalogScript.get_asset(current_asset_id)
	if asset == null:
		_asset_hint.text = ""
		return
	var size := asset.footprint_m()
	_asset_hint.text = "%s\nРазмер: %.2f×%.2f×%.2f м" % [asset.description, size.x, size.y, size.z]


func _select_snap_step(step: float) -> void:
	for i in _snap_option.item_count:
		if is_equal_approx(float(_snap_option.get_item_metadata(i)), step):
			_snap_option.select(i)
			current_snap_step = step
			return


func _on_snap_selected(index: int) -> void:
	current_snap_step = float(_snap_option.get_item_metadata(index))
	refresh_ghost()


func _select_anchor(anchor: Vector2i) -> void:
	current_anchor = anchor
	for key in _anchor_buttons.keys():
		(_anchor_buttons[key] as Button).button_pressed = key == anchor
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
	for record: DecorObjectRecordScript in _editor.blueprint.objects:
		var asset := DecorAssetCatalogScript.get_asset(record.asset_id)
		var label := asset.name if asset != null else "%s (нет ассета)" % record.asset_id
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


func _refresh_inspector() -> void:
	for child in _controls_vbox.get_children():
		child.queue_free()

	var record := find_record(selected_object_id)
	if record == null:
		_inspector_title.text = "Объект не выбран"
		_set_transform_fields_enabled(false)
		return

	var asset := DecorAssetCatalogScript.get_asset(record.asset_id)
	_inspector_title.text = "Свойства: %s" % (asset.name if asset != null else String(record.asset_id))
	_set_transform_fields_enabled(true)
	_sync_transform_fields(record)
	if asset == null:
		return

	for control in asset.controls:
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

	var stored: Variant = record.properties.get(property_name, control.get("default", null))
	match String(control.get("type", DecorAssetDefScript.TYPE_STRING)):
		DecorAssetDefScript.TYPE_BOOL:
			var check := CheckBox.new()
			check.button_pressed = bool(stored)
			check.toggled.connect(func(pressed: bool): _set_property(property_name, pressed))
			row.add_child(check)
		DecorAssetDefScript.TYPE_FLOAT:
			var spin := SpinBox.new()
			spin.min_value = float(control.get("min", 0.0))
			spin.max_value = float(control.get("max", 10.0))
			spin.step = float(control.get("step", 0.1))
			spin.value = float(stored) if stored != null else spin.min_value
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value_changed.connect(func(value: float): _set_property(property_name, value))
			row.add_child(spin)
		DecorAssetDefScript.TYPE_COLOR:
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
	record.properties[property_name] = value
	var node: Node3D = _nodes.get(record.id, null)
	if node != null and node.has_method("set_decor_property"):
		node.call("set_decor_property", property_name, value)
	_editor.mark_dirty()


func _set_transform_fields_enabled(enabled: bool) -> void:
	for spin in [_pos_x_spin, _pos_y_spin, _pos_z_spin, _yaw_spin, _scale_spin]:
		spin.editable = enabled
	_duplicate_btn.disabled = not enabled
	_delete_btn.disabled = not enabled


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
	record.scale = Vector3.ONE * _scale_spin.value
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
