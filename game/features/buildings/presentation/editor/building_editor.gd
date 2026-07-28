class_name BuildingEditor
extends Node3D

## Modular building editor for frame construction and active work zones.
##
## Runs in two modes (see design_docs/engine/modular_building_editor.md §5):
##   * Dev mode  — launched by opening this scene directly in Godot; saves to
##     res://game/content/core/buildings and exposes the developer panel.
##   * Player mode — launched from the main menu; saves to user://custom_buildings.

signal back_requested


## Footprint centre marks. The band is faint on purpose: it must not compete
## with block colours, only hint where the building's origin will sit in game.
const CENTRE_LINE_COLOR := Color(1.0, 0.82, 0.18, 1.0)
const CENTRE_BAND_COLOR := Color(1.0, 0.82, 0.18, 0.12)

enum Tool { PLACE, ERASE }
enum Brush { LINE, RECT }
enum EditMode { FRAME, FINISHES, DECOR, ZONES }

@export_group("Editor")
## Forces developer mode when the scene is opened/run directly. The main menu
## clears this via GameLaunchManager before switching in player mode.
@export var dev_mode: bool = true

var grid_model: BuildingGridModel
var blueprint: BuildingBlueprint
var repository: BlueprintRepository
var mesh_library: BlockMeshLibrary

var current_block_id: StringName = &""
var current_variant: StringName = &""
var current_anchor: int = BuildingBlockCatalog.ANCHOR_CENTER
var current_material_id: StringName = BuildingMaterialCatalog.DEFAULT_ID
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

## Frame mode lives in its own controller; see frame_mode_controller.gd.
var frame_mode: FrameModeController = null
## Decor mode (design §3.3) lives in its own controller; see decor_mode_controller.gd.
var decor_mode: DecorModeController = null
## Zones mode lives in its own controller; see zones_mode_controller.gd.
var zones_mode: ZonesModeController = null

## True when there are unsaved changes. Checked before scene transitions.
var _dirty: bool = false

## Path this document was opened from, or "" when it has none — a new blueprint, or
## one detached because this mode cannot write where it came from
## (content_packaging.md §6.4). A save with a path goes back to that exact file,
## subfolder included; a save without one goes to the mode's source under the
## current id.
var current_path: String = ""

var _panning: bool = false
var _orbiting: bool = false

@onready var _camera_controller: CameraController = %CameraController
@onready var _export_mesh_btn: Button = %ExportMeshBtn
@onready var _navmesh_preview_btn: Button = %NavMeshPreviewBtn

# UI bindings (linked to scene unique nodes in building_editor.tscn).
@onready var _name_edit: LineEdit = %NameEdit
@onready var _id_edit: LineEdit = %IdEdit
## Entrances are authored as `door` anchors in zones mode; the metadata panel
## only reports where they landed (active_zones.md §5.2).
@onready var _entrance_label: Label = %EntranceDerivedLabel
@onready var _status_label: Label = %StatusLabel
@onready var _metadata_panel: PanelContainer = %MetadataPanel
@onready var _load_popup: PopupPanel = %LoadPopup
@onready var _load_list: ItemList = %LoadList
@onready var _save_as_dialog: ConfirmationDialog = %SaveAsDialog
@onready var _save_as_id_edit: LineEdit = %SaveAsIdEdit
@onready var _save_as_hint: Label = %SaveAsHint

@onready var _mode_frame_btn: Button = %ModeFrameBtn
@onready var _mode_finishes_btn: Button = %ModeFinishesBtn
@onready var _mode_decor_btn: Button = %ModeDecorBtn
@onready var _mode_zones_btn: Button = %ModeZonesBtn

@onready var _back_btn: Button = %BackBtn
@onready var _undo_btn: Button = %UndoBtn
@onready var _redo_btn: Button = %RedoBtn

var _mode_buttons: Dictionary = {}
## Prevent value_changed callbacks from overwriting one footprint dimension
## with the stale value of the other while a loaded blueprint updates both UI
## fields.
var _syncing_metadata_fields := false

## One chronological history for the entire blueprint.  The older decor-only
## snapshots made Ctrl+Z depend on the active mode and left frame/zones edits
## irreversible.  A blueprint is still small enough for bounded whole-document
## snapshots; this gives every existing mode undo coverage without making each
## controller own a competing stack.
const HISTORY_LIMIT := 128
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _history_baseline: Dictionary = {}
var _saved_snapshot: Dictionary = {}
var _history_replaying := false


func _ready() -> void:
	_resolve_launch_mode()
	grid_model = BuildingGridModel.new()
	blueprint = BuildingBlueprint.new()
	repository = BlueprintRepository.new(dev_mode)
	mesh_library = BlockMeshLibrary.new()

	_init_world()
	_setup_ui()
	frame_mode.refresh_layer_plane()
	_refresh_ghost()
	_connect_back_navigation()
	reset_history()
	_update_status("Готово. Режим: %s" % ("Разработчик" if dev_mode else "Игрок"))


## The scene's `dev_mode` export is what "opened directly in Godot" means. A launch
## through `GameLaunchManager` always overrides it, so the menu cannot land in dev
## mode and a dev launch cannot be downgraded by a stale export.
func _resolve_launch_mode() -> void:
	var launch_mgr := get_node_or_null("/root/GameLaunchManager")
	if launch_mgr != null and "editor_mode_forced" in launch_mgr \
			and bool(launch_mgr.get("editor_mode_forced")):
		dev_mode = bool(launch_mgr.get("editor_dev_mode"))
	dev_mode = dev_mode and OS.has_feature("editor")


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
	_camera_controller.camera_distance = 18.0
	_camera_controller.apply_position()

	frame_mode = FrameModeController.new()
	add_child(frame_mode)
	decor_mode = DecorModeController.new()
	add_child(decor_mode)
	zones_mode = ZonesModeController.new()
	add_child(zones_mode)


# ---------------------------------------------------------------------------
# Input & interaction
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _camera_controller != null:
		_camera_controller.update(delta)
	_update_cursor()
	if current_mode == EditMode.DECOR:
		decor_mode.refresh_ghost()
		return
	if current_mode == EditMode.ZONES:
		zones_mode.refresh_ghost()
		return
	frame_mode.process(delta)


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
		elif frame_mode.is_painting():
			_update_cursor()
			if cursor_valid:
				if current_mode == EditMode.DECOR:
					decor_mode.on_drag()
				elif current_mode == EditMode.ZONES:
					zones_mode.on_mouse_motion(event)
				elif current_mode == EditMode.FRAME and current_brush == Brush.RECT:
					frame_mode.paint_rect(frame_mode.paint_anchor, cursor_cell)
				else:
					frame_mode.paint_line(frame_mode.last_paint_cell, cursor_cell)
				frame_mode.last_paint_cell = cursor_cell
		elif frame_mode.is_shift_erasing():
			_update_cursor()
			if cursor_valid:
				frame_mode.erase_line(frame_mode.last_paint_cell, cursor_cell)
				frame_mode.last_paint_cell = cursor_cell
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and _pointer_over_ui():
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			if frame_mode.is_shift_erasing():
				if not event.pressed:
					frame_mode.shift_erasing = false
				_orbiting = false
				return
			if current_mode == EditMode.FRAME and event.pressed and event.shift_pressed:
				frame_mode.shift_erasing = true
				_orbiting = false
				frame_mode.last_paint_cell = cursor_cell
				frame_mode.erase_hovered_block_or_cell()
				return
			if current_mode == EditMode.DECOR and event.pressed and event.shift_pressed:
				_orbiting = false
				decor_mode.erase_at_cursor()
				return
			_orbiting = event.pressed
		MOUSE_BUTTON_MIDDLE:
			if event.pressed and current_mode == EditMode.FRAME and event.shift_pressed:
				frame_mode.pick_stamp_brush()
				return
			_panning = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom(-2.0)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom(2.0)
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.shift_pressed:
					if current_mode == EditMode.FRAME:
						frame_mode.pick_single_block()
						return
					if current_mode == EditMode.DECOR:
						decor_mode.pick_asset_at_cursor()
						return
				if current_mode == EditMode.ZONES:
					if zones_mode.handle_mouse_button(event):
						frame_mode.painting = zones_mode.is_painting()
						frame_mode.last_paint_cell = cursor_cell
					return
				elif current_mode == EditMode.DECOR:
					decor_mode.on_left_pressed()
					frame_mode.painting = true
				else:
					frame_mode.painting = true
					frame_mode.last_paint_cell = cursor_cell
					frame_mode.paint_anchor = cursor_cell
					if current_brush == Brush.RECT:
						frame_mode.paint_rect(frame_mode.paint_anchor, cursor_cell)
					else:
						frame_mode.apply_tool_at_cursor()
			else:
				frame_mode.painting = false
				if current_mode == EditMode.DECOR:
					decor_mode.on_left_released()
				elif current_mode == EditMode.ZONES:
					zones_mode.handle_mouse_button(event)


func _handle_key(event: InputEventKey) -> void:
	if event.ctrl_pressed:
		match event.keycode:
			KEY_Z:
				redo() if event.shift_pressed else undo()
				return
			KEY_Y:
				redo()
				return
	if current_mode == EditMode.DECOR:
		decor_mode.handle_key(event)
		return
	match event.keycode:
		KEY_Z:
			frame_mode.cycle_rotation_z(-1 if event.shift_pressed else 1)
		KEY_X:
			frame_mode.cycle_rotation_x(-1 if event.shift_pressed else 1)
		KEY_C, KEY_R:
			frame_mode.cycle_rotation(-1 if event.shift_pressed else 1)
		KEY_E:
			frame_mode.set_tool(Tool.ERASE)
		KEY_L:
			_on_brush_line_pressed()
		KEY_M:
			_on_brush_rect_pressed()
		KEY_PAGEUP:
			_set_layer(active_layer + 1)
		KEY_PAGEDOWN:
			_set_layer(active_layer - 1)
		KEY_ESCAPE:
			frame_mode.clear_block_selection()


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


func _pointer_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


# ---------------------------------------------------------------------------
# Ghost & bounds (delegated to frame_mode)
# ---------------------------------------------------------------------------

func _refresh_ghost() -> void:
	if current_mode == EditMode.DECOR:
		decor_mode.refresh_ghost()
		return
	if current_mode == EditMode.ZONES:
		zones_mode.refresh_ghost()
		return
	if not cursor_valid:
		return
	frame_mode.refresh_ghost()


func _is_cell_in_bounds(cell: Vector3i) -> bool:
	return cell.x >= 0 and cell.z >= 0 and cell.x < blueprint.footprint.x and cell.z < blueprint.footprint.y


# ---------------------------------------------------------------------------
# State changes (delegated to frame_mode)
# ---------------------------------------------------------------------------

func _set_layer(layer: int) -> void:
	active_layer = maxi(0, layer)
	frame_mode.refresh_layer_plane()
	if decor_mode != null:
		decor_mode.on_layer_changed()


## Public entry points used by the mode controllers.
func set_layer(layer: int) -> void:
	_set_layer(layer)


func mark_dirty() -> void:
	_record_history_change()
	_mark_dirty()


func undo() -> bool:
	if _undo_stack.is_empty():
		_update_status("Отменять нечего.")
		return false
	_redo_stack.append(_history_baseline.duplicate(true))
	_restore_history_snapshot(_undo_stack.pop_back())
	_update_status("Отменено. Шагов в истории: %d" % _undo_stack.size())
	_refresh_undo_redo_buttons()
	return true


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func redo() -> bool:
	if _redo_stack.is_empty():
		_update_status("Повторять нечего.")
		return false
	_undo_stack.append(_history_baseline.duplicate(true))
	_restore_history_snapshot(_redo_stack.pop_back())
	_update_status("Повторено. Шагов в истории: %d" % _redo_stack.size())
	_refresh_undo_redo_buttons()
	return true


func _on_undo_pressed() -> void:
	undo()


func _on_redo_pressed() -> void:
	redo()


func _refresh_undo_redo_buttons() -> void:
	if _undo_btn != null:
		_undo_btn.disabled = _undo_stack.is_empty()
	if _redo_btn != null:
		_redo_btn.disabled = _redo_stack.is_empty()


func set_status(message: String) -> void:
	_update_status(message)


func is_pointer_over_ui() -> bool:
	return _pointer_over_ui()


func update_cursor() -> void:
	_update_cursor()


func is_cell_in_bounds(cell: Vector3i) -> bool:
	return _is_cell_in_bounds(cell)


func _select_mode(mode: int) -> void:
	if mode == EditMode.FINISHES:
		_update_status("Этот режим подготовлен в формате и будет реализован следующим срезом.")
		if _mode_buttons.has(current_mode):
			(_mode_buttons[current_mode] as Button).button_pressed = true
		return
	current_mode = mode
	for m in _mode_buttons.keys():
		(_mode_buttons[m] as Button).button_pressed = m == mode
	if _metadata_panel != null:
		_metadata_panel.visible = mode != EditMode.DECOR

	if mode == EditMode.DECOR:
		frame_mode.deactivate()
		zones_mode.deactivate()
		decor_mode.activate()
		_update_status("Режим декора: щелчок — поставить или выбрать, Delete — удалить, Esc — снять выделение.")
	else:
		decor_mode.deactivate()
		if mode == EditMode.ZONES:
			frame_mode.deactivate()
			frame_mode.set_tool(Tool.PLACE)
			zones_mode.activate()
		else:
			zones_mode.deactivate()
			frame_mode.activate()
			_update_status("Режим каркаса.")
	_refresh_ghost()


# ---------------------------------------------------------------------------
# Save / load / new
# ---------------------------------------------------------------------------

func _on_save_pressed() -> void:
	frame_mode.on_save_pressed()


## Save As always asks for an id, because that is the only thing that distinguishes
## the copy from the original. It is also the way out of a detached document: a
## player who opened a shipped blueprint lands here with the same id proposed in
## their own source.
func _on_save_as_pressed() -> void:
	frame_mode.collect_metadata_from_ui()
	_save_as_id_edit.text = String(blueprint.id)
	_save_as_hint.text = "ID нового чертежа (сохранится в %s):" % repository.base_dir()
	_save_as_dialog.popup_centered()


func _on_save_as_confirmed() -> void:
	var requested := ContentId.normalize_id(_save_as_id_edit.text)
	if requested.is_empty():
		_update_status("ID не может быть пустым: допустимы латинские строчные буквы, цифры, «_» и «-».")
		return
	blueprint.id = StringName(requested)
	# A Save As deliberately forgets where the document came from: writing to the
	# proposed id in this mode's source is the whole point of the command.
	current_path = ""
	frame_mode.on_save_pressed()


func _on_new_pressed() -> void:
	if not await _confirm_discard_changes():
		return
	grid_model.clear()
	blueprint = BuildingBlueprint.new()
	current_path = ""
	frame_mode.rebuild_all_block_nodes()
	zones_mode.on_blueprint_changed()
	_reset_decor_for_new_blueprint()
	frame_mode.sync_metadata_fields()
	_dirty = false
	reset_history()
	_set_layer(0)
	_update_status("Новый чертёж.")


func _on_export_mesh_pressed() -> void:
	_update_status("Экспорт меша: функция в разработке.")


func _on_navmesh_preview_pressed() -> void:
	_update_status("Предпросмотр навмеша: функция в разработке.")


## Lists every source, not just the writable one (content_packaging.md §6.4).
## Taking a shipped building as a starting point is the most common first step an
## author takes, and a list that hides it makes that step impossible.
func _on_load_pressed() -> void:
	_load_list.clear()
	var entries := repository.list_blueprints()
	if not repository.last_errors.is_empty():
		_update_status("Ошибка контента: " + "\n".join(repository.last_errors))
	if entries.is_empty():
		_update_status("Нет чертежей ни в одном источнике.")
		return
	for entry in entries:
		var suffix := "" if entry["writable"] else "  · только чтение"
		var idx := _load_list.add_item("%s  (%s)%s" % [entry["name"], entry["key"], suffix])
		_load_list.set_item_metadata(idx, entry["path"])
	_load_popup.popup_centered(Vector2i(460, 380))


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
	# Remembering the path is what makes a save go back where the file came from,
	# including into a subfolder. A file this mode cannot write detaches instead:
	# `current_path` stays empty and the next save behaves as Save As.
	current_path = path if repository.can_write(path) else ""
	grid_model.load_from_blueprint(blueprint)
	frame_mode.rebuild_all_block_nodes()
	zones_mode.on_blueprint_loaded()
	_reset_decor_for_new_blueprint()
	frame_mode.sync_metadata_fields()
	_dirty = false
	reset_history()
	_load_popup.hide()
	var detached := " · только чтение, сохранится в %s" % repository.base_dir() if current_path.is_empty() else ""
	_update_status("Загружено: %s (%d блоков, %d зон, %d объектов)%s" % [
		blueprint.name, blueprint.block_count(), blueprint.areas.size(),
		blueprint.objects.size(), detached])


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
	frame_mode.set_tool(Tool.PLACE)


func _on_tool_erase_pressed() -> void:
	frame_mode.set_tool(Tool.ERASE)


func _on_brush_line_pressed() -> void:
	frame_mode.set_brush(Brush.LINE)


func _on_brush_rect_pressed() -> void:
	frame_mode.set_brush(Brush.RECT)


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

	frame_mode.setup(self)
	zones_mode.setup(self)
	decor_mode.setup(self)

	_back_btn.visible = not dev_mode
	if dev_mode:
		_export_mesh_btn.visible = true
		_navmesh_preview_btn.visible = true
		_export_mesh_btn.pressed.connect(_on_export_mesh_pressed)
		_navmesh_preview_btn.pressed.connect(_on_navmesh_preview_pressed)

	_load_list.item_activated.connect(_on_load_item_activated)
	_save_as_dialog.confirmed.connect(_on_save_as_confirmed)

	frame_mode.sync_metadata_fields()
	frame_mode.clear_block_selection()
	frame_mode.set_tool(Tool.PLACE)
	frame_mode.set_brush(Brush.LINE)
	_set_layer(0)
	_select_mode(EditMode.FRAME)


# ---------------------------------------------------------------------------
# UI sync helpers
# ---------------------------------------------------------------------------

func _update_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _mark_dirty() -> void:
	_dirty = true


func _record_history_change() -> void:
	if _history_replaying or blueprint == null:
		return
	var current := blueprint.to_dict()
	if current == _history_baseline:
		return
	_undo_stack.append(_history_baseline.duplicate(true))
	if _undo_stack.size() > HISTORY_LIMIT:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_history_baseline = current
	_refresh_undo_redo_buttons()
	if decor_mode != null:
		decor_mode.refresh_history_buttons()


func reset_history() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_history_baseline = blueprint.to_dict() if blueprint != null else {}
	_saved_snapshot = _history_baseline.duplicate(true)
	_refresh_undo_redo_buttons()


func _restore_history_snapshot(snapshot: Dictionary) -> void:
	_history_replaying = true
	blueprint = BuildingBlueprint.from_dict(snapshot)
	grid_model.load_from_blueprint(blueprint)
	frame_mode.rebuild_all_block_nodes()
	zones_mode.on_blueprint_loaded()
	_reset_decor_for_new_blueprint()
	frame_mode.sync_metadata_fields()
	_history_baseline = snapshot.duplicate(true)
	_dirty = _history_baseline != _saved_snapshot
	_history_replaying = false


func _confirm_discard_changes() -> bool:
	if not _dirty:
		return true
	var dialog := ConfirmationDialog.new()
	dialog.title = "Несохранённые изменения"
	dialog.dialog_text = "Есть несохранённые изменения. Продолжить?"
	dialog.ok_button_text = "Да"
	dialog.cancel_button_text = "Отмена"
	return await _run_confirmation_dialog(dialog, Vector2i(360, 120))


## Shows `dialog` modally and resolves to `true` only when the user pressed OK.
##
## The confirmation flag lives in an Array because GDScript lambdas capture
## locals by value: writing to a plain `var` from inside the `confirmed`
## handler would leave the outer variable untouched and every dialog would
## read as "cancelled".
func _run_confirmation_dialog(dialog: ConfirmationDialog, size: Vector2i) -> bool:
	var confirmed_flag := [false]
	dialog.confirmed.connect(func(): confirmed_flag[0] = true)
	add_child(dialog)
	dialog.popup_centered(size)
	# `popup_centered` makes the dialog visible synchronously, so the loop
	# body only runs while the user hasn't confirmed or cancelled yet.
	while dialog.visible:
		await get_tree().process_frame
	dialog.queue_free()
	return confirmed_flag[0]


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
