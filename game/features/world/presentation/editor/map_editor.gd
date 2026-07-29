extends Node3D

## The territory editor (design_docs/engine/map_editor.md).
##
## This file does four things and no more: it loads and saves the document, it
## switches modes, it routes input to the active one, and it owns the shared undo
## stack. Everything an author actually does to a map lives in a mode controller.
##
## The rule is worth stating because breaking it is the failure this editor was
## designed around: `building_editor.gd` grew to 2159 lines before decor was cut
## out of it into `decor_mode_controller.gd`. **If an `if mode == ...` ever
## appears inside the input handling below, logic has leaked out of a
## controller.** The mode list is data; adding phase 2's fill mode should mean
## adding one entry to `_build_modes` and one file, and touching nothing else.
##
## Modes reach the document and the services through `MapEditorContext`, never
## through this node.

const MapEditorModeBarScript = preload("res://game/features/world/presentation/editor/ui/map_editor_mode_bar.gd")

## Phases that own the modes not yet built. They are listed so the author can see
## what the editor is going to be, and disabled so they cannot pretend to work.
const PLANNED_MODES: Array = [
	{"id": &"roads", "title": "Покрытия", "reason": "Слой покрытий — фаза 3"},
	{"id": &"rules", "title": "Правила и старт", "reason": "Правила и режимы игры — фаза 5"},
]

@onready var terrain_world: GridTerrainWorld = $Terrain
@onready var water_world: WaterWorld = $Water
@onready var nav_overlay: NavTerrainOverlay = $NavOverlay
@onready var hover_marker: MeshInstance3D = $HoverMarker
@onready var camera: MapEditorCamera = $Camera3D

@onready var _top_bar: Control = $UI/Screen/TopBar
@onready var _mode_bar: MapEditorModeBar = $UI/Screen/TopBar/Margin/Scroll/Row/ModeBar
@onready var _viewport_area: Control = $UI/Screen/Middle/Viewport3D
@onready var _side_panel: MapEditorSidePanel = $UI/Screen/Middle/SidePanel
@onready var _palette: MapEditorPalette = $UI/Screen/Middle/Palette
@onready var _status_cell: Label = $UI/Screen/StatusBar/Margin/Row/CellLabel
@onready var _status_message: Label = $UI/Screen/StatusBar/Margin/Row/MessageLabel
@onready var _back_button: Button = $UI/Screen/TopBar/Margin/Scroll/Row/BackButton
@onready var _new_button: Button = $UI/Screen/TopBar/Margin/Scroll/Row/NewButton
@onready var _load_button: Button = $UI/Screen/TopBar/Margin/Scroll/Row/LoadButton
@onready var _save_button: Button = $UI/Screen/TopBar/Margin/Scroll/Row/SaveButton
@onready var _save_as_button: Button = $UI/Screen/TopBar/Margin/Scroll/Row/SaveAsButton
@onready var _settings_button: Button = $UI/Screen/TopBar/Margin/Scroll/Row/SettingsButton
@onready var _undo_button: Button = $UI/Screen/TopBar/Margin/Scroll/Row/UndoButton
@onready var _redo_button: Button = $UI/Screen/TopBar/Margin/Scroll/Row/RedoButton
@onready var _validate_button: Button = $UI/Screen/TopBar/Margin/Scroll/Row/ValidateButton
@onready var _test_button: Button = $UI/Screen/TopBar/Margin/Scroll/Row/TestButton
@onready var _dialogs: MapEditorDialogs = $UI/Dialogs

var document: MapDocument
var history := MapEditorHistory.new()

## Path this document was opened from, or "" when it has none — a new map, or one
## detached because this mode cannot write where it came from
## (content_packaging.md §6.4). It is what makes Ctrl+S go back to the same
## package instead of minting `new_map.gdmap` over and over.
var current_path: String = ""

var _service := MapDocumentService.new()
var _terrain_service := TerrainService.new()
var _wear_service := SurfaceWearService.new()
var _nav_grid := NavGrid.new()
var _nav_publisher := TerrainNavigationPublisher.new()
var _brush := TerrainBrushController.new()
var _water_service := WaterService.new()
var _water_brush := WaterBrushController.new()
var _border_ocean := BorderOceanService.new()
var _test_run_service := MapTestRunService.new()

var _context := MapEditorContext.new()
var _modes: Array[MapEditorMode] = []
var _active: MapEditorMode = null
var _message := "готово"
var dev_mode := false
## True while the history is replaying a command, so the commits that replay emits
## are not recorded as new commands.
var _replaying := false
## True while `BorderOceanService` is filling as part of a terrain stroke, so the
## water commits it produces are folded into that stroke's command instead of
## becoming commands of their own.
var _recording_border_fill := false


func _ready() -> void:
	_resolve_launch_mode()
	_open_requested_map()
	_build_services()
	_build_modes()
	_connect_ui()
	history.changed.connect(_refresh_panels)
	get_viewport().size_changed.connect(_refresh_camera_framing)
	_select_mode(_modes[0].id)
	_refresh_panels()


# --- Document -----------------------------------------------------------------

## Dev mode authors the shipped pack, exactly as the building editor does
## (content_packaging.md §9). Running this scene straight from Godot is the
## developer's entry point; a launch through the menu always forces player mode.
func _resolve_launch_mode() -> void:
	var launch_manager: Node = get_node_or_null("/root/GameLaunchManager")
	var dev := OS.has_feature("editor")
	if launch_manager != null and "editor_mode_forced" in launch_manager \
			and bool(launch_manager.get("editor_mode_forced")):
		dev = bool(launch_manager.get("editor_dev_mode"))
	dev_mode = dev
	_service = MapDocumentService.new(dev)


## Opens whatever the launcher asked for, or starts a blank map. A map that will
## not open is reported and replaced by a blank one rather than left as a
## half-editor.
##
## A blank map deliberately has **no id**: it has not been named yet, and naming
## it `new_map` by default is what made every unnamed map overwrite the previous
## one. Saving it goes through Save As, which is where a name is asked for.
func _open_requested_map() -> void:
	var launch_manager: Node = get_node_or_null("/root/GameLaunchManager")
	if launch_manager != null and launch_manager.get("pending_editor_document") is MapDocument:
		document = launch_manager.get("pending_editor_document") as MapDocument
		launch_manager.set("pending_editor_document", null)
		current_path = ""
		_message = "возврат из тест-запуска · несохранённые правки сохранены"
		return
	var requested: StringName = &""
	if launch_manager != null:
		requested = launch_manager.get("pending_editor_map")
	if not String(requested).is_empty():
		document = _service.load_map(requested)
		if document == null:
			_message = "не удалось открыть %s: %s" % [requested, _service.last_error]
		else:
			_adopt_path(_service.map_path(requested))
	if document == null:
		document = MapDocument.create(&"", "Новая карта", MapMeta.DEFAULT_BOARD_CELLS)
		current_path = ""


## Binds the document to the file it came from, or detaches it when this mode may
## not write there. Detaching early — at open, not at save — is what lets the
## editor say so in the panel while the author still has a choice.
func _adopt_path(path: String) -> void:
	current_path = path if _service.can_write(path) else ""


func _build_services() -> void:
	_terrain_service.configure(document.terrain)
	_wear_service.configure(_terrain_service)
	_water_service.configure(document.water, document.terrain)
	_border_ocean.configure(_water_service, document.terrain, document.water, document.meta)
	terrain_world.configure(document.terrain, camera)
	water_world.configure(document.water, document.terrain, _water_service, _terrain_service)
	water_world.configure_border(document.meta.border_kind, document.meta.border_level)
	# Binds navigation to the ground and the water, and keeps it current: every
	# committed edit republishes exactly the columns it touched.
	_nav_publisher.configure(document.terrain, _nav_grid, _terrain_service, document.water, _water_service)
	if not _terrain_service.edit_committed.is_connected(_on_terrain_committed):
		_terrain_service.edit_committed.connect(_on_terrain_committed)
	if not _water_service.edit_committed.is_connected(_on_water_committed):
		_water_service.edit_committed.connect(_on_water_committed)
	_brush.configure(document.terrain, _terrain_service, _wear_service)
	_water_brush.configure(document.terrain, document.water, _water_service, _border_ocean)
	nav_overlay.configure(_nav_grid)
	nav_overlay.visible = false
	terrain_world.rebuild_pending_now()
	water_world.rebuild_pending_now()
	_build_hover_marker()
	_refresh_camera_framing()

	_context.document = document
	_context.terrain = document.terrain
	_context.terrain_service = _terrain_service
	_context.wear_service = _wear_service
	_context.brush = _brush
	_context.water = document.water
	_context.water_service = _water_service
	_context.water_brush = _water_brush
	_context.nav_grid = _nav_grid
	_context.nav_publisher = _nav_publisher
	_context.history = history
	_context.camera = camera
	_context.terrain_world = terrain_world
	_context.water_world = water_world
	_context.nav_overlay = nav_overlay
	_context.hover_marker = hover_marker
	_context.world_3d = get_world_3d()
	_context.viewport = get_viewport()


func _build_hover_marker() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(document.meta.cell_size, 0.06, document.meta.cell_size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.87, 0.25, 0.45)
	mesh.material = material
	hover_marker.mesh = mesh


## Ctrl+S. A document with a file of its own goes back into it, subfolder and all;
## anything else — a new map, or one opened from a source this mode cannot write —
## routes through Save As, which is where the author names it.
func _save() -> void:
	if current_path.is_empty() or not _service.can_write(current_path):
		_open_save_as()
		return
	# The `preview` argument is the reserved hook for map thumbnails
	# (map_editor.md §3.2.1). Nothing renders one yet, and passing null keeps the
	# call shape final so adding the snapshot later touches only this line.
	var path := _service.save_map_to(document, current_path, null)
	if path.is_empty():
		_message = "не сохранено: %s" % _service.last_error
	else:
		current_path = path
		_message = "сохранено в %s" % path
	_refresh_panels()


func _open_save_as() -> void:
	var proposed := document.meta.id if not String(document.meta.id).is_empty() else &"my_map"
	_dialogs.open_save_as_dialog(proposed, _service.base_dir())


func _on_save_as_requested(id: StringName) -> void:
	document.meta.id = id
	var path := _service.save_map(document, &"", null)
	if path.is_empty():
		_message = "не сохранено: %s" % _service.last_error
	else:
		current_path = path
		_message = "сохранено в %s" % path
	_refresh_panels()


func _on_new_pressed() -> void:
	if not await _confirm_discard_changes():
		return
	_dialogs.open_new_dialog()


func _on_create_requested(id: StringName, display_name: String, board_cells: int) -> void:
	_replace_document(MapDocument.create(id, display_name, board_cells), "")
	_message = "новая карта: %s (%d×%d)" % [id, board_cells, board_cells]


func _on_load_pressed() -> void:
	if not await _confirm_discard_changes():
		return
	var entries := _service.list_maps()
	_dialogs.open_load_dialog(entries, _service.last_errors)


func _on_open_requested(path: String) -> void:
	var opened := _service.load_package(path)
	if opened == null:
		_message = "не удалось открыть: %s" % _service.last_error
		_refresh_panels()
		return
	_replace_document(opened, path)
	_message = "открыто: %s" % path
	if current_path.is_empty():
		_message += " · только чтение, сохранится в %s" % _service.base_dir()


## Swaps in a different document and rebuilds everything bound to the old one. The
## undo stacks go with it: a command recorded against the previous board would
## replay onto cells that no longer mean the same thing.
func _replace_document(next: MapDocument, path: String) -> void:
	document = next
	_adopt_path(path)
	history.clear()
	_terrain_service.clear_history()
	_water_service.clear_history()
	_build_services()
	for mode: MapEditorMode in _modes:
		mode.configure(_context)
	_refresh_panels()


# --- Modes --------------------------------------------------------------------

func _build_modes() -> void:
	_modes = [TerrainModeController.new(), SurfaceModeController.new(), WaterModeController.new(), EntitiesModeController.new(), FillModeController.new()]
	for mode: MapEditorMode in _modes:
		mode.configure(_context)
		mode.ui_changed.connect(_refresh_panels)

	var bar_entries: Array = _modes.duplicate()
	for planned: Dictionary in PLANNED_MODES:
		var placeholder := MapEditorMode.new()
		placeholder.id = planned["id"]
		placeholder.title = planned["title"]
		bar_entries.append(placeholder)
	_mode_bar.build(bar_entries)
	for planned: Dictionary in PLANNED_MODES:
		_mode_bar.set_enabled(planned["id"], false, planned["reason"])


func _select_mode(mode_id: StringName) -> void:
	var next: MapEditorMode = null
	for mode: MapEditorMode in _modes:
		if mode.id == mode_id:
			next = mode
			break
	if next == null or next == _active:
		return
	if _active != null:
		_active.deactivate()
	_active = next
	_active.activate()
	_mode_bar.set_active(_active.id)
	_rebuild_palette()
	_refresh_panels()


# --- UI wiring ----------------------------------------------------------------

## Every top-bar action is a button rather than a menu item, and each has the
## shortcut §3.3 gives it in its tooltip: the actions an author uses every minute
## should not be two clicks deep.
func _connect_ui() -> void:
	_mode_bar.mode_selected.connect(_select_mode)
	_palette.entry_selected.connect(func(entry_id: StringName) -> void:
		_active.select_palette_entry(entry_id))
	_palette.option_activated.connect(func(option_id: StringName) -> void:
		_active.activate_option(option_id))
	_back_button.visible = not dev_mode
	_back_button.pressed.connect(_return_to_menu)
	_new_button.pressed.connect(_on_new_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_save_button.pressed.connect(_save)
	_save_as_button.pressed.connect(_open_save_as)
	_settings_button.pressed.connect(_open_settings)
	_undo_button.pressed.connect(_undo)
	_redo_button.pressed.connect(_redo)
	_validate_button.pressed.connect(_validate_map)
	_test_button.pressed.connect(_test_run)
	_validate_button.disabled = false
	_test_button.disabled = false
	_dialogs.create_requested.connect(_on_create_requested)
	_dialogs.open_requested.connect(_on_open_requested)
	_dialogs.save_as_requested.connect(_on_save_as_requested)
	_dialogs.properties_applied.connect(_on_properties_applied)
	_side_panel.property_committed.connect(_on_inspector_property_committed)


func _open_settings() -> void:
	_dialogs.open_properties_dialog(document.meta)


## The properties dialog has already written into `document.meta`; everything that
## caches a header value has to be told, which is the same work switching the
## border does.
func _on_properties_applied() -> void:
	_apply_header_change("свойства карты обновлены")


## Re-reads the header everywhere it is consumed: the rule that floods the rim, and
## the horizon that draws it. Both take the sea level as well as the border kind,
## so editing the level in the properties dialog lands here too.
func _apply_header_change(message: String) -> void:
	document.mark_dirty()
	_message = message
	_border_ocean.configure(_water_service, document.terrain, document.water, document.meta)
	water_world.configure_border(document.meta.border_kind, document.meta.border_level)
	if MapMeta.has_border_fill_static(document.meta.border_kind):
		_context.set_edit_label("граница")
		_border_ocean.apply()
	_refresh_panels()


func _rebuild_palette() -> void:
	_palette.set_title("%s — палитра" % _active.title)
	_palette.set_entries(_active.palette_entries(), _active.selected_palette_entry())


## Where a save would land, and whether this document owns a file. Silent write
## redirection is the failure this line exists to prevent
## (content_packaging.md §6.4).
func _binding_line() -> String:
	if current_path.is_empty():
		return "новый файл → %s" % _service.base_dir()
	return "файл: %s" % current_path


func _refresh_panels() -> void:
	if _active == null:
		return
	_palette.set_selected(_active.selected_palette_entry())
	_palette.set_options(_active.tool_options())
	_side_panel.set_map_info([
		"%s%s" % [document.meta.name, "*" if document.dirty else ""],
		"id: %s" % (document.meta.id if not String(document.meta.id).is_empty() else "— не задан"),
		"доска %d×%d" % [document.meta.board_cells, document.meta.board_cells],
		_binding_line(),
		"отмен в стеке: %d" % history.undo_depth(),
	])
	_side_panel.set_inspector("Инспектор — %s" % _active.title, _active.inspector_lines())
	_side_panel.set_property_fields(_active.inspector_properties(), _active.inspector_values())
	_side_panel.set_entries(
		_active.list_title(), _active.list_entries(), _active.empty_list_hint(),
	)
	# A stack you cannot pop says so by being grey, the way the building editor's
	# decor buttons do.
	_undo_button.disabled = not history.can_undo()
	_redo_button.disabled = not history.can_redo()
	_status_message.text = _message


func _on_inspector_property_committed(property_name: StringName, value: Variant) -> void:
	if _active != null and _active.apply_inspector_value(property_name, value):
		_refresh_panels()


# --- Frame and input ----------------------------------------------------------

func _process(delta: float) -> void:
	camera.process_keys(delta)
	if _active == null:
		return
	# A mode only tracks the cursor when the cursor is over the map. Otherwise
	# moving the mouse to a panel button would keep painting under it.
	if _is_pointer_over_view():
		_active.process(delta)
	else:
		_active.clear_hover()
	_update_hover_marker()
	_status_cell.text = _active.status_text()


func _update_hover_marker() -> void:
	var brush := _active.hover_brush() if _active != null else null
	hover_marker.visible = brush != null and brush.has_hover
	if brush == null or not brush.has_hover:
		return
	var centre := document.terrain.cell_center(brush.hovered_cell)
	hover_marker.position = Vector3(centre.x, centre.y + 0.03, centre.z)
	var span := float(brush.brush_size * 2 - 1)
	hover_marker.scale = Vector3(span, 1.0, span)


## The 3D view is the hole in the middle of the chrome. Anything over a panel
## belongs to that panel.
func _is_pointer_over_view() -> bool:
	return _viewport_area.get_global_rect().has_point(get_viewport().get_mouse_position())


## Tells the camera where the hole is. Re-run on every resize: the panels have
## fixed pixel widths, so their share of the window changes as it is resized and a
## framing computed once would be wrong at any other size.
func _refresh_camera_framing() -> void:
	# The layout has to have been solved for the hole to have a size.
	if _viewport_area.size.y <= 0.0:
		await get_tree().process_frame
	camera.set_view_rect(_viewport_area.get_global_rect(), Vector2(get_viewport().get_visible_rect().size))
	camera.configure(document.meta.board_metres())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		# Wheel over a panel should scroll that panel, not zoom the camera.
		# Only forward mouse buttons to the camera when the cursor is over the
		# 3D viewport.
		if not _is_pointer_over_view():
			return
		if camera.handle_mouse_button(button):
			return
		if _active != null and _active.handle_input(event):
			_refresh_panels()
		return
	if event is InputEventMouseMotion:
		camera.handle_mouse_motion(event as InputEventMouseMotion)
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		_handle_key(event as InputEventKey)


## Keys the editor owns: the ones §3.3 declares common to every mode. Everything
## else is offered to the active controller.
func _handle_key(event: InputEventKey) -> void:
	if event.ctrl_pressed:
		match event.keycode:
			KEY_Z:
				_redo() if event.shift_pressed else _undo()
			KEY_S:
				_save()
			KEY_Y:
				_redo()
		return
	match event.keycode:
		KEY_F5:
			_test_run()
			return
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
			var slot := event.keycode - KEY_1
			if slot < _modes.size():
				_select_mode(_modes[slot].id)
			return
		KEY_HOME:
			camera.frame_board()
			return
		KEY_ESCAPE:
			_return_to_menu()
			return
	if _active != null and _active.handle_input(event):
		_refresh_panels()


func _validate_map() -> Dictionary:
	var result := _test_run_service.validate(document, _nav_grid)
	var errors: Array = result["errors"]
	var warnings: Array = result["warnings"]
	if not errors.is_empty():
		_message = "ошибки: %s" % "; ".join(errors)
	elif warnings.is_empty():
		_message = "карта проверена: ошибок и предупреждений нет"
	else:
		_message = "карта проверена · предупреждения: %s" % "; ".join(warnings)
	_refresh_panels()
	return result


## F5 deliberately runs World Showcase: it is the generic `core.world`
## consumer and therefore proves this map without silently adding Settlement
## rules, citizens, economy or authored start requirements to a new map.
func _test_run() -> void:
	var result := _validate_map()
	if not (result["errors"] as Array).is_empty():
		return
	var launch_manager: Node = get_node_or_null("/root/GameLaunchManager")
	if launch_manager == null or not launch_manager.has_method("launch_game_definition"):
		_message = "тест-запуск недоступен: нет host launcher"
		_refresh_panels()
		return
	if launch_manager.has_method("launch_editor_test"):
		launch_manager.call("launch_editor_test", document)


## Every committed ground edit becomes exactly one command, recorded here rather
## than by the mode that caused it.
##
## This is the only arrangement in which the editor's stack and the service's own
## delta stack stay aligned. A mode pushing once per click would be wrong twice
## over: a drag across twenty columns commits twenty deltas, and a click that the
## cascade refuses commits none. The service is the one thing that knows which of
## those happened, so it is the one thing that gets to say a command exists.
func _on_terrain_committed(delta: TerrainDelta) -> void:
	# Undo and redo replay through the same signal. Recording those would push a
	# new command for every undo and the stack would never empty.
	if _replaying:
		return
	var label := _context.pending_edit_label
	var parts: Array[MapEditorCommand] = [TerrainServiceCommand.of(_terrain_service, delta, label)]
	# A placed entity owns no absolute ground height: it follows its surface.
	# Folding its position change into the terrain command preserves one author
	# action and one Ctrl+Z, just like the ocean fill below.
	if delta.changes_geometry():
		var entities_before := document.entities.to_json()
		var moved := false
		for record: MapEntityRecord in document.entities.entities:
			if record.cell(document.terrain) in delta.cells:
				var centre := document.terrain.cell_center(record.cell(document.terrain))
				var archetype := EntityArchetypeCatalog.get_archetype(record.archetype_id)
				var asset := EntityArchetypeCatalog.asset_of(archetype.id) if archetype != null else null
				record.position.y = centre.y + (asset.placement_policy().vertical_offset if asset != null else 0.0)
				moved = true
		if moved:
			parts.append(MapEntityCommand.of(document, entities_before, document.entities.to_json(), label).mark_applied())
	# The sea comes in as part of the stroke that opened the way for it (§6.1), so
	# it joins the same command. Two entries here would mean two Ctrl+Z for one
	# thing the author did.
	_recording_border_fill = true
	var flooded := _border_ocean.apply()
	_recording_border_fill = false
	if flooded:
		parts.append(WaterServiceCommand.of(_water_service, _water_service.last_delta(), label))
	history.push(
		parts[0] if parts.size() == 1
		else MapEditorCompositeCommand.of(parts, "%s + океан" % label)
	)
	document.mark_dirty()
	_notify_document_changed()


## The same arrangement for the water layer, and for the same reason: one command
## per committed delta, recorded here rather than by the mode that caused it. The
## two services push onto the SAME stack, which is what makes Ctrl+Z walk back
## through an author's actual sequence of strokes instead of through one layer at
## a time.
func _on_water_committed(delta: WaterDelta) -> void:
	# A border fill is part of the terrain command that triggered it, so it must not
	# also push one of its own.
	if _replaying or _recording_border_fill:
		return
	history.push(WaterServiceCommand.of(_water_service, delta, _context.pending_edit_label))
	document.mark_dirty()


func _undo() -> void:
	if not history.can_undo():
		_message = "нечего отменять"
		_refresh_panels()
		return
	var label := history.undo_label()
	_replaying = true
	var ok := history.undo()
	_replaying = false
	_message = "отменено: %s" % label if ok else "отмена не удалась"
	_after_history_change()


func _redo() -> void:
	if not history.can_redo():
		_message = "нечего повторять"
		_refresh_panels()
		return
	_replaying = true
	var ok := history.redo()
	_replaying = false
	_message = "повторено" if ok else "повтор не удался"
	_after_history_change()


## Undo reverts through `TerrainService`, which republishes the mesh and the
## navigation field on its own. The overlay is presentation and redraws only when
## it is actually being looked at.
func _after_history_change() -> void:
	_notify_document_changed()
	if nav_overlay.visible:
		nav_overlay.rebuild()
	_refresh_panels()


func _notify_document_changed() -> void:
	for mode: MapEditorMode in _modes:
		mode.document_changed()


func _return_to_menu() -> void:
	if not await _confirm_discard_changes():
		return
	var launch_manager: Node = get_node_or_null("/root/GameLaunchManager")
	if launch_manager != null and launch_manager.has_method("return_to_main_menu"):
		launch_manager.call("return_to_main_menu")
		return
	get_tree().change_scene_to_file("res://game/features/ui/presentation/main_menu/main_menu.tscn")


## Guards every path that throws the document away: New, Open, Back and Esc.
## `MapDocument.dirty` promised this prompt from the day the flag was added; until
## it existed, Esc during a session silently discarded the whole map.
func _confirm_discard_changes() -> bool:
	if document == null or not document.dirty:
		return true
	var dialog := ConfirmationDialog.new()
	dialog.title = "Несохранённые изменения"
	dialog.dialog_text = "Карта изменена и не сохранена. Продолжить и потерять правки?"
	dialog.ok_button_text = "Продолжить"
	dialog.cancel_button_text = "Отмена"
	# The flag lives in an Array because GDScript lambdas capture locals by value:
	# writing to a plain `var` from the handler would leave the outer one untouched
	# and every dialog would read as cancelled.
	var confirmed := [false]
	dialog.confirmed.connect(func() -> void: confirmed[0] = true)
	add_child(dialog)
	dialog.popup_centered(Vector2i(420, 140))
	while dialog.visible:
		await get_tree().process_frame
	dialog.queue_free()
	return confirmed[0]
