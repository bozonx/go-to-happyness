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
	{"id": &"fill", "title": "Наполнение", "reason": "Здания, декор и природа — фаза 2"},
	{"id": &"entities", "title": "Зоны и точки", "reason": "Зоны, точки и маршруты — фаза 4"},
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
@onready var _save_button: Button = $UI/Screen/TopBar/Margin/Scroll/Row/SaveButton
@onready var _undo_button: Button = $UI/Screen/TopBar/Margin/Scroll/Row/UndoButton
@onready var _redo_button: Button = $UI/Screen/TopBar/Margin/Scroll/Row/RedoButton
@onready var _map_menu: MenuButton = $UI/Screen/TopBar/Margin/Scroll/Row/MapMenu

const MENU_BORDER_OCEAN := 1
const MENU_BORDER_NOTHING := 2

var document: MapDocument
var history := MapEditorHistory.new()

var _service := MapDocumentService.new()
var _terrain_service := TerrainService.new()
var _wear_service := SurfaceWearService.new()
var _nav_grid := NavGrid.new()
var _nav_publisher := TerrainNavigationPublisher.new()
var _brush := TerrainBrushController.new()
var _water_service := WaterService.new()
var _water_brush := WaterBrushController.new()

var _context := MapEditorContext.new()
var _modes: Array[MapEditorMode] = []
var _active: MapEditorMode = null
var _message := "готово"
## True while the history is replaying a command, so the commits that replay emits
## are not recorded as new commands.
var _replaying := false


func _ready() -> void:
	_open_requested_map()
	_build_services()
	_build_modes()
	_connect_ui()
	history.changed.connect(_refresh_panels)
	get_viewport().size_changed.connect(_refresh_camera_framing)
	_select_mode(_modes[0].id)
	_refresh_panels()


# --- Document -----------------------------------------------------------------

## Opens whatever the launcher asked for, or starts a new map. A map that will not
## open is reported and replaced by a new one rather than left as a half-editor.
func _open_requested_map() -> void:
	var launch_manager: Node = get_node_or_null("/root/GameLaunchManager")
	var requested: StringName = &""
	if launch_manager != null:
		requested = launch_manager.get("pending_editor_map")
	if not String(requested).is_empty():
		document = _service.load_map(requested)
		if document == null:
			_message = "не удалось открыть %s: %s" % [requested, _service.last_error]
	if document == null:
		document = MapDocument.create(&"new_map", "Новая карта", MapMeta.DEFAULT_BOARD_CELLS)


func _build_services() -> void:
	_terrain_service.configure(document.terrain)
	_wear_service.configure(_terrain_service)
	_water_service.configure(document.water, document.terrain)
	terrain_world.configure(document.terrain, camera)
	water_world.configure(document.water, document.terrain, _water_service, _terrain_service)
	# Binds navigation to the ground and the water, and keeps it current: every
	# committed edit republishes exactly the columns it touched.
	_nav_publisher.configure(document.terrain, _nav_grid, _terrain_service, document.water, _water_service)
	if not _terrain_service.edit_committed.is_connected(_on_terrain_committed):
		_terrain_service.edit_committed.connect(_on_terrain_committed)
	if not _water_service.edit_committed.is_connected(_on_water_committed):
		_water_service.edit_committed.connect(_on_water_committed)
	_brush.configure(document.terrain, _terrain_service, _wear_service)
	_water_brush.configure(document.terrain, document.water, _water_service)
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


func _save() -> void:
	var path := _service.save_map(document, MapDocumentService.SOURCE_PLAYER)
	if path.is_empty():
		_message = "не сохранено: %s" % _service.last_error
	else:
		_message = "сохранено в %s" % path
	_refresh_panels()


func _new_map() -> void:
	document = MapDocument.create(&"new_map", "Новая карта", MapMeta.DEFAULT_BOARD_CELLS)
	history.clear()
	_terrain_service.clear_history()
	_water_service.clear_history()
	_build_services()
	for mode: MapEditorMode in _modes:
		mode.configure(_context)
	_message = "новая карта"
	_refresh_map_menu()
	_refresh_panels()


# --- Modes --------------------------------------------------------------------

func _build_modes() -> void:
	_modes = [TerrainModeController.new(), SurfaceModeController.new(), WaterModeController.new()]
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
	_back_button.pressed.connect(_return_to_menu)
	_new_button.pressed.connect(_new_map)
	_save_button.pressed.connect(_save)
	_undo_button.pressed.connect(_undo)
	_redo_button.pressed.connect(_redo)
	_map_menu.get_popup().id_pressed.connect(_on_map_menu_item_pressed)
	_refresh_map_menu()


func _refresh_map_menu() -> void:
	var popup := _map_menu.get_popup()
	popup.clear()
	popup.add_radio_check_item("За пределами карты: Океан", MENU_BORDER_OCEAN)
	popup.add_radio_check_item("За пределами карты: Ничего", MENU_BORDER_NOTHING)
	popup.set_item_checked(0, document.meta.border_kind == MapMeta.BORDER_OCEAN)
	popup.set_item_checked(1, document.meta.border_kind == MapMeta.BORDER_NOTHING)


func _on_map_menu_item_pressed(menu_id: int) -> void:
	var kind := MapMeta.BORDER_OCEAN if menu_id == MENU_BORDER_OCEAN else MapMeta.BORDER_NOTHING
	if document.meta.border_kind == kind:
		return
	document.meta.border_kind = kind
	document.mark_dirty()
	_message = "за пределами карты: %s" % ("океан" if kind == MapMeta.BORDER_OCEAN else "ничего")
	if kind == MapMeta.BORDER_OCEAN:
		_flood_ocean_from_border()
	_refresh_map_menu()
	_refresh_panels()


func _rebuild_palette() -> void:
	_palette.set_title("%s — палитра" % _active.title)
	_palette.set_entries(_active.palette_entries(), _active.selected_palette_entry())


func _refresh_panels() -> void:
	if _active == null:
		return
	_palette.set_selected(_active.selected_palette_entry())
	_palette.set_options(_active.tool_options())
	_side_panel.set_map_info([
		"%s%s" % [document.meta.name, "*" if document.dirty else ""],
		"id: %s" % document.meta.id,
		"доска %d×%d" % [document.meta.board_cells, document.meta.board_cells],
		"отмен в стеке: %d" % history.undo_depth(),
	])
	_side_panel.set_inspector("Инспектор — %s" % _active.title, _active.inspector_lines())
	_side_panel.set_entries(
		_active.list_title(), _active.list_entries(), _active.empty_list_hint(),
	)
	# A stack you cannot pop says so by being grey, the way the building editor's
	# decor buttons do.
	_undo_button.disabled = not history.can_undo()
	_redo_button.disabled = not history.can_redo()
	_status_message.text = _message


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
		if camera.handle_mouse_button(button):
			return
		if not _is_pointer_over_view():
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


## Every committed ground edit becomes exactly one command, recorded here rather
## than by the mode that caused it.
##
## This is the only arrangement in which the editor's stack and the service's own
## delta stack stay aligned. A mode pushing once per click would be wrong twice
## over: a drag across twenty columns commits twenty deltas, and a click that the
## cascade refuses commits none. The service is the one thing that knows which of
## those happened, so it is the one thing that gets to say a command exists.
func _on_terrain_committed(_delta: TerrainDelta) -> void:
	# Undo and redo replay through the same signal. Recording those would push a
	# new command for every undo and the stack would never empty.
	if _replaying:
		return
	history.push(TerrainServiceCommand.of(_terrain_service, _context.pending_edit_label))
	document.mark_dirty()
	_flood_ocean_from_border()


## Ocean water enters only through the map boundary and only below the zero
## terrain level. Closed inland depressions are intentionally untouched.
func _flood_ocean_from_border() -> void:
	if document.meta.border_kind != MapMeta.BORDER_OCEAN:
		return
	var ocean_id := WaterBody.NO_BODY
	for body: WaterBody in document.water.bodies():
		if body.type == WaterBody.Type.SEA:
			ocean_id = body.id
			break
	if ocean_id == WaterBody.NO_BODY:
		# Avoid creating an empty registry entry on a map whose edge is still dry.
		var has_open_edge := false
		var minimum := document.terrain.min_cell()
		var maximum := document.terrain.max_cell()
		for x in range(minimum.x, maximum.x + 1):
			has_open_edge = document.terrain.height_of(Vector2i(x, minimum.y)) < 0 or document.terrain.height_of(Vector2i(x, maximum.y)) < 0
			if has_open_edge:
				break
		if not has_open_edge:
			for z in range(minimum.y + 1, maximum.y):
				has_open_edge = document.terrain.height_of(Vector2i(minimum.x, z)) < 0 or document.terrain.height_of(Vector2i(maximum.x, z)) < 0
				if has_open_edge:
					break
		if not has_open_edge:
			return
		var ocean := _water_service.create_body(WaterBody.Type.SEA, 0)
		if ocean == null:
			return
		ocean_id = ocean.id
	_context.set_edit_label("океан")
	_water_service.flood_from_edges(ocean_id, 0)


## The same arrangement for the water layer, and for the same reason: one command
## per committed delta, recorded here rather than by the mode that caused it. The
## two services push onto the SAME stack, which is what makes Ctrl+Z walk back
## through an author's actual sequence of strokes instead of through one layer at
## a time.
func _on_water_committed(_delta: WaterDelta) -> void:
	if _replaying:
		return
	history.push(WaterServiceCommand.of(_water_service, _context.pending_edit_label))
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
	if nav_overlay.visible:
		nav_overlay.rebuild()
	_refresh_panels()


func _return_to_menu() -> void:
	var launch_manager: Node = get_node_or_null("/root/GameLaunchManager")
	if launch_manager != null and launch_manager.has_method("return_to_main_menu"):
		launch_manager.call("return_to_main_menu")
		return
	get_tree().change_scene_to_file("res://game/features/ui/presentation/main_menu/main_menu.tscn")
