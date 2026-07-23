class_name BuildingEditor
extends Node3D

## Modular building editor — frame-construction level (Режим 1: Каркас).
##
## Runs in two modes (see design_docs/content/modular_building_editor.md §5):
##   * Dev mode  — launched by opening this scene directly in Godot; saves to
##     res://data/blueprints and exposes the developer panel.
##   * Player mode — launched from the main menu; saves to user://custom_buildings.
##
## Only the frame mode is functional; the decor and active-zone modes are
## present in the UI as disabled placeholders so the later slices drop in
## without reshaping the interface.

const CameraControllerScene = preload("res://game/features/world/presentation/camera_controller.tscn")
const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BuildingGridModelScript = preload("res://game/features/buildings/domain/editor/building_grid_model.gd")
const BlueprintRepositoryScript = preload("res://game/features/buildings/application/editor/blueprint_repository.gd")
const BlockMeshLibraryScript = preload("res://game/features/buildings/presentation/editor/block_mesh_library.gd")
const UI_THEME = preload("res://game/features/ui/presentation/theme/ui_theme.tres")

enum Tool { PLACE, ERASE }
enum EditMode { FRAME, DECOR, ZONES }

## Forces developer mode when the scene is opened/run directly. The main menu
## clears this via GameLaunchManager before switching in player mode.
@export var dev_mode: bool = true

var grid_model: BuildingGridModelScript
var blueprint: BuildingBlueprintScript
var repository: BlueprintRepositoryScript
var mesh_library: BlockMeshLibraryScript

var current_block_id: StringName = BuildingBlockCatalogScript.default_block_id()
var current_rot: int = 0
var current_tool: int = Tool.PLACE
var active_layer: int = 0
var cursor_cell: Vector3i = Vector3i.ZERO
var cursor_valid: bool = false

var _block_nodes: Dictionary = {}  ## Vector3i -> MeshInstance3D
var _camera_controller: Node3D
var _blocks_root: Node3D
var _ghost: MeshInstance3D
var _layer_plane: MeshInstance3D
var _panning: bool = false
var _orbiting: bool = false

# UI references populated in _build_ui().
var _name_edit: LineEdit
var _id_edit: LineEdit
var _palette_container: VBoxContainer
var _status_label: Label
var _layer_label: Label
var _rot_label: Label
var _count_label: Label
var _tool_place_btn: Button
var _tool_erase_btn: Button
var _mode_buttons: Dictionary = {}
var _dev_panel: PanelContainer
var _load_popup: PopupPanel
var _load_list: ItemList
var _palette_buttons: Dictionary = {}  ## StringName -> Button


func _ready() -> void:
	_resolve_launch_mode()
	grid_model = BuildingGridModelScript.new()
	blueprint = BuildingBlueprintScript.new()
	repository = BlueprintRepositoryScript.new(dev_mode)
	mesh_library = BlockMeshLibraryScript.new()

	_build_world()
	_build_ui()
	_refresh_layer_plane()
	_refresh_ghost()
	_update_status("Готово. Режим: %s" % ("Разработчик" if dev_mode else "Игрок"))


func _resolve_launch_mode() -> void:
	# Player mode is signalled by the launcher; a directly-run scene stays dev.
	var launch_mgr := get_node_or_null("/root/GameLaunchManager")
	if launch_mgr != null and "editor_player_mode" in launch_mgr:
		if bool(launch_mgr.get("editor_player_mode")):
			dev_mode = false


# ---------------------------------------------------------------------------
# World setup
# ---------------------------------------------------------------------------

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.10, 0.12, 0.16)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.5
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -46.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	_camera_controller = CameraControllerScene.instantiate()
	add_child(_camera_controller)
	_camera_controller.set("camera_target", Vector3(4.0, 0.0, 4.0))
	_camera_controller.set("camera_distance", 18.0)
	if _camera_controller.has_method("apply_position"):
		_camera_controller.call("apply_position")

	_build_ground()

	_blocks_root = Node3D.new()
	_blocks_root.name = "BlocksRoot"
	add_child(_blocks_root)

	_ghost = MeshInstance3D.new()
	_ghost.name = "Ghost"
	add_child(_ghost)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(64.0, 64.0)
	ground.mesh = plane
	ground.position = Vector3(0.0, -0.01, 0.0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.16, 0.18, 0.20)
	ground.material_override = ground_mat
	add_child(ground)

	# Static grid lines at ground level for reference.
	var grid := MeshInstance3D.new()
	grid.name = "GridLines"
	grid.mesh = _build_grid_mesh(32, Color(0.30, 0.34, 0.40, 0.6))
	add_child(grid)

	# Movable highlight plane showing the active build layer.
	_layer_plane = MeshInstance3D.new()
	_layer_plane.name = "LayerPlane"
	_layer_plane.mesh = _build_grid_mesh(24, Color(0.35, 0.7, 1.0, 0.5))
	add_child(_layer_plane)


func _build_grid_mesh(half_extent: int, color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(color)
	for i in range(-half_extent, half_extent + 1):
		st.add_vertex(Vector3(i, 0.0, -half_extent))
		st.add_vertex(Vector3(i, 0.0, half_extent))
		st.add_vertex(Vector3(-half_extent, 0.0, i))
		st.add_vertex(Vector3(half_extent, 0.0, i))
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, mat)
	return mesh


# ---------------------------------------------------------------------------
# Input & interaction
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _camera_controller != null and _camera_controller.has_method("update"):
		_camera_controller.call("update", delta)
	_update_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		if _orbiting and _camera_controller.has_method("rotate_yaw_pitch"):
			_camera_controller.call("rotate_yaw_pitch", event.relative)
		elif _panning and _camera_controller.has_method("pan"):
			_camera_controller.call("pan", event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
		MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom(-2.0)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom(2.0)
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_apply_tool_at_cursor()


func _handle_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_R:
			_cycle_rotation()
		KEY_E:
			_set_tool(Tool.ERASE)
		KEY_B:
			_set_tool(Tool.PLACE)
		KEY_PAGEUP:
			_set_layer(active_layer + 1)
		KEY_PAGEDOWN:
			_set_layer(active_layer - 1)
		KEY_ESCAPE:
			_confirm_back_to_menu()


func _zoom(amount: float) -> void:
	var dist := float(_camera_controller.get("camera_distance"))
	_camera_controller.set("camera_distance", clampf(dist + amount, 4.0, 60.0))
	if _camera_controller.has_method("apply_position"):
		_camera_controller.call("apply_position")


func _update_cursor() -> void:
	var camera := _camera_controller.get("camera") as Camera3D
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
	cursor_cell = Vector3i(int(floor(hit.x)), active_layer, int(floor(hit.z)))
	cursor_valid = true
	_refresh_ghost()


func _apply_tool_at_cursor() -> void:
	if not cursor_valid:
		return
	# Ignore clicks that land on UI (panels consume their own input, but guard
	# against the transparent status bar too).
	if get_viewport().gui_get_hovered_control() != null:
		return
	match current_tool:
		Tool.PLACE:
			if grid_model.place(cursor_cell, current_block_id, current_rot):
				_spawn_or_update_block_node(grid_model.get_block_at(cursor_cell))
				_update_count()
		Tool.ERASE:
			if grid_model.erase(cursor_cell):
				_remove_block_node(cursor_cell)
				_update_count()
	_refresh_ghost()


# ---------------------------------------------------------------------------
# Block visuals
# ---------------------------------------------------------------------------

func _spawn_or_update_block_node(block) -> void:
	var node: MeshInstance3D = _block_nodes.get(block.pos, null)
	if node == null:
		node = MeshInstance3D.new()
		_blocks_root.add_child(node)
		_block_nodes[block.pos] = node
	node.mesh = mesh_library.mesh_for(block.block_id)
	node.material_override = mesh_library.material_for(block.block_id)
	node.position = Vector3(block.pos) + BlockMeshLibraryScript.local_offset(block.block_id)
	node.rotation = Vector3(0.0, block.rotation_radians(), 0.0)


func _remove_block_node(cell: Vector3i) -> void:
	var node: MeshInstance3D = _block_nodes.get(cell, null)
	if node != null:
		node.queue_free()
		_block_nodes.erase(cell)


func _rebuild_all_block_nodes() -> void:
	for node in _block_nodes.values():
		node.queue_free()
	_block_nodes.clear()
	for block in grid_model.all_blocks():
		_spawn_or_update_block_node(block)
	_update_count()


func _refresh_ghost() -> void:
	if not cursor_valid:
		_ghost.visible = false
		return
	_ghost.visible = true
	if current_tool == Tool.ERASE:
		var target := grid_model.get_block_at(cursor_cell)
		if target == null:
			_ghost.mesh = mesh_library.mesh_for(current_block_id)
			_ghost.rotation = Vector3(0.0, deg_to_rad(90.0 * current_rot), 0.0)
			_ghost.position = Vector3(cursor_cell) + BlockMeshLibraryScript.local_offset(current_block_id)
			_ghost.material_override = mesh_library.ghost_material(false)
		else:
			_ghost.mesh = mesh_library.mesh_for(target.block_id)
			_ghost.rotation = Vector3(0.0, target.rotation_radians(), 0.0)
			_ghost.position = Vector3(target.pos) + BlockMeshLibraryScript.local_offset(target.block_id)
			_ghost.material_override = mesh_library.ghost_material(false)
	else:
		_ghost.mesh = mesh_library.mesh_for(current_block_id)
		_ghost.rotation = Vector3(0.0, deg_to_rad(90.0 * current_rot), 0.0)
		_ghost.position = Vector3(cursor_cell) + BlockMeshLibraryScript.local_offset(current_block_id)
		_ghost.material_override = mesh_library.ghost_material(true)


func _refresh_layer_plane() -> void:
	if _layer_plane != null:
		_layer_plane.position = Vector3(0.0, float(active_layer), 0.0)


# ---------------------------------------------------------------------------
# State changes
# ---------------------------------------------------------------------------

func _set_tool(tool_id: int) -> void:
	current_tool = tool_id
	if _tool_place_btn != null:
		_tool_place_btn.button_pressed = tool_id == Tool.PLACE
	if _tool_erase_btn != null:
		_tool_erase_btn.button_pressed = tool_id == Tool.ERASE
	_refresh_ghost()


func _select_block(block_id: StringName) -> void:
	current_block_id = block_id
	var def := BuildingBlockCatalogScript.get_block(block_id)
	if def.is_empty() or not def.get("rotatable", true):
		current_rot = 0
	_set_tool(Tool.PLACE)
	for id in _palette_buttons.keys():
		(_palette_buttons[id] as Button).button_pressed = id == block_id
	_update_rotation_label()
	_refresh_ghost()


func _cycle_rotation() -> void:
	var def := BuildingBlockCatalogScript.get_block(current_block_id)
	if def.is_empty() or not def.get("rotatable", true):
		return
	current_rot = (current_rot + 1) % 4
	_update_rotation_label()
	_refresh_ghost()


func _set_layer(layer: int) -> void:
	active_layer = maxi(0, layer)
	_refresh_layer_plane()
	if _layer_label != null:
		_layer_label.text = "Слой Y: %d" % active_layer


func _select_mode(mode: int) -> void:
	# Only frame mode is functional; the others are reserved placeholders.
	if mode != EditMode.FRAME:
		_update_status("Этот режим появится в следующем обновлении.")
		return
	for m in _mode_buttons.keys():
		(_mode_buttons[m] as Button).button_pressed = m == mode


# ---------------------------------------------------------------------------
# Save / load / new
# ---------------------------------------------------------------------------

func _on_save_pressed() -> void:
	blueprint.name = _name_edit.text.strip_edges()
	if blueprint.name.is_empty():
		blueprint.name = "Новое здание"
	if dev_mode and _id_edit != null:
		var raw_id := _id_edit.text.strip_edges()
		if not raw_id.is_empty():
			blueprint.id = StringName(raw_id)
	grid_model.write_to_blueprint(blueprint)
	var result := repository.save(blueprint)
	if result["ok"]:
		_update_status("Сохранено: %s (%d блоков)" % [result["path"], blueprint.block_count()])
	else:
		_update_status("Ошибка сохранения: %s" % result["error"])


func _on_new_pressed() -> void:
	grid_model.clear()
	blueprint = BuildingBlueprintScript.new()
	_rebuild_all_block_nodes()
	_sync_metadata_fields()
	_set_layer(0)
	_update_status("Новый чертёж.")


func _on_load_pressed() -> void:
	_load_list.clear()
	var entries := repository.list_blueprints()
	if entries.is_empty():
		_update_status("Нет сохранённых чертежей в %s" % repository.base_dir())
		return
	for entry in entries:
		var idx := _load_list.add_item("%s  (%s)" % [entry["name"], entry["id"]])
		_load_list.set_item_metadata(idx, entry["path"])
	_load_popup.popup_centered(Vector2i(420, 360))


func _on_load_item_activated(index: int) -> void:
	var path := String(_load_list.get_item_metadata(index))
	var loaded := repository.load_blueprint(path)
	if loaded == null:
		_update_status("Не удалось загрузить: %s" % path)
		return
	blueprint = loaded
	grid_model.load_from_blueprint(blueprint)
	_rebuild_all_block_nodes()
	_sync_metadata_fields()
	_load_popup.hide()
	_update_status("Загружено: %s (%d блоков)" % [blueprint.name, blueprint.block_count()])


func _confirm_back_to_menu() -> void:
	get_tree().change_scene_to_file("res://game/features/ui/presentation/main_menu/main_menu.tscn")


# ---------------------------------------------------------------------------
# UI construction (data-driven; built procedurally on top of the .tscn world)
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "EditorUI"
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI_THEME
	layer.add_child(root)

	_build_top_bar(root)
	_build_palette_panel(root)
	_build_status_bar(root)
	_build_load_popup(root)
	if dev_mode:
		_build_dev_panel(root)

	_select_block(current_block_id)
	_set_tool(Tool.PLACE)
	_set_layer(0)
	_update_count()


func _build_top_bar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size = Vector2(0, 52)
	root.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "← В меню"
	back_btn.pressed.connect(_confirm_back_to_menu)
	hbox.add_child(back_btn)

	hbox.add_child(_make_separator_v())

	var name_label := Label.new()
	name_label.text = "Название:"
	hbox.add_child(name_label)

	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(200, 0)
	_name_edit.text = blueprint.name
	hbox.add_child(_name_edit)

	hbox.add_child(_make_separator_v())

	# Mode tabs (only frame is enabled).
	for mode_info in [
		{"mode": EditMode.FRAME, "label": "1. Каркас", "enabled": true},
		{"mode": EditMode.DECOR, "label": "2. Декор", "enabled": false},
		{"mode": EditMode.ZONES, "label": "3. Зоны", "enabled": false},
	]:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = mode_info["label"]
		btn.disabled = not mode_info["enabled"]
		if not mode_info["enabled"]:
			btn.tooltip_text = "Появится в следующем обновлении"
		var mode: int = mode_info["mode"]
		btn.pressed.connect(func(): _select_mode(mode))
		_mode_buttons[mode] = btn
		hbox.add_child(btn)

	hbox.add_child(_make_spacer())

	var new_btn := Button.new()
	new_btn.text = "Новый"
	new_btn.pressed.connect(_on_new_pressed)
	hbox.add_child(new_btn)

	var load_btn := Button.new()
	load_btn.text = "Загрузить"
	load_btn.pressed.connect(_on_load_pressed)
	hbox.add_child(load_btn)

	var save_btn := Button.new()
	save_btn.text = "💾 Сохранить"
	save_btn.pressed.connect(_on_save_pressed)
	hbox.add_child(save_btn)


func _build_palette_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_top = 60.0
	panel.offset_bottom = -48.0
	panel.offset_left = 8.0
	panel.custom_minimum_size = Vector2(240, 0)
	root.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)
	_palette_container = vbox

	# Tools row.
	var tools_label := Label.new()
	tools_label.text = "Инструменты"
	tools_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(tools_label)

	var tools_row := HBoxContainer.new()
	vbox.add_child(tools_row)

	_tool_place_btn = Button.new()
	_tool_place_btn.text = "Строить (B)"
	_tool_place_btn.toggle_mode = true
	_tool_place_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_place_btn.pressed.connect(func(): _set_tool(Tool.PLACE))
	tools_row.add_child(_tool_place_btn)

	_tool_erase_btn = Button.new()
	_tool_erase_btn.text = "Стереть (E)"
	_tool_erase_btn.toggle_mode = true
	_tool_erase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_erase_btn.pressed.connect(func(): _set_tool(Tool.ERASE))
	tools_row.add_child(_tool_erase_btn)

	# Rotation + layer controls.
	var rot_row := HBoxContainer.new()
	vbox.add_child(rot_row)
	var rot_btn := Button.new()
	rot_btn.text = "⟳ Поворот (R)"
	rot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot_btn.pressed.connect(_cycle_rotation)
	rot_row.add_child(rot_btn)
	_rot_label = Label.new()
	_rot_label.custom_minimum_size = Vector2(48, 0)
	rot_row.add_child(_rot_label)

	var layer_row := HBoxContainer.new()
	vbox.add_child(layer_row)
	var layer_down := Button.new()
	layer_down.text = "Слой −"
	layer_down.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_down.pressed.connect(func(): _set_layer(active_layer - 1))
	layer_row.add_child(layer_down)
	var layer_up := Button.new()
	layer_up.text = "Слой +"
	layer_up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_up.pressed.connect(func(): _set_layer(active_layer + 1))
	layer_row.add_child(layer_up)
	_layer_label = Label.new()
	_layer_label.custom_minimum_size = Vector2(70, 0)
	layer_row.add_child(_layer_label)

	vbox.add_child(HSeparator.new())

	var blocks_label := Label.new()
	blocks_label.text = "Блоки"
	blocks_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(blocks_label)

	# Data-driven palette grouped by category.
	var current_category := -1
	for def in BuildingBlockCatalogScript.all():
		if def["category"] != current_category:
			current_category = def["category"]
			var cat_label := Label.new()
			cat_label.text = BuildingBlockCatalogScript.category_name(current_category)
			cat_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
			vbox.add_child(cat_label)
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = def["name"]
		btn.tooltip_text = "Размер: %.2f×%.2f×%.2f м" % [def["size"].x, def["size"].y, def["size"].z]
		var block_id: StringName = def["id"]
		btn.pressed.connect(func(): _select_block(block_id))
		_palette_buttons[block_id] = btn
		vbox.add_child(btn)


func _build_status_bar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.custom_minimum_size = Vector2(0, 40)
	root.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_status_label)

	_count_label = Label.new()
	hbox.add_child(_count_label)

	var help := Label.new()
	help.text = "ЛКМ — действие · ПКМ — вращение камеры · СКМ — панорама · Колесо — зум · WASD — движение"
	help.add_theme_color_override("font_color", Color(0.6, 0.66, 0.72))
	hbox.add_child(help)


func _build_dev_panel(root: Control) -> void:
	_dev_panel = PanelContainer.new()
	_dev_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_dev_panel.offset_top = 60.0
	_dev_panel.offset_left = -280.0
	_dev_panel.offset_right = -8.0
	root.add_child(_dev_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_dev_panel.add_child(vbox)

	var title := Label.new()
	title.text = "🛠 Панель разработчика"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var id_label := Label.new()
	id_label.text = "ID чертежа:"
	vbox.add_child(id_label)
	_id_edit = LineEdit.new()
	_id_edit.text = String(blueprint.id)
	vbox.add_child(_id_edit)

	var path_hint := Label.new()
	path_hint.text = "Сохранение → %s" % repository.base_dir()
	path_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_hint.add_theme_color_override("font_color", Color(0.6, 0.66, 0.72))
	vbox.add_child(path_hint)

	vbox.add_child(HSeparator.new())

	# Placeholders for later slices (recipes, mesh export, navmesh preview).
	for label_text in ["Редактор рецептов (скоро)", "Экспорт меша .tres/.gltf (скоро)", "Просмотр NavMesh (скоро)"]:
		var btn := Button.new()
		btn.text = label_text
		btn.disabled = true
		vbox.add_child(btn)


func _build_load_popup(root: Control) -> void:
	_load_popup = PopupPanel.new()
	root.add_child(_load_popup)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(400, 340)
	_load_popup.add_child(vbox)
	var title := Label.new()
	title.text = "Загрузить чертёж"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	_load_list = ItemList.new()
	_load_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_list.item_activated.connect(_on_load_item_activated)
	vbox.add_child(_load_list)


func _make_separator_v() -> VSeparator:
	return VSeparator.new()


func _make_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


# ---------------------------------------------------------------------------
# UI sync helpers
# ---------------------------------------------------------------------------

func _sync_metadata_fields() -> void:
	if _name_edit != null:
		_name_edit.text = blueprint.name
	if _id_edit != null:
		_id_edit.text = String(blueprint.id)


func _update_rotation_label() -> void:
	if _rot_label != null:
		_rot_label.text = "%d°" % (current_rot * 90)


func _update_count() -> void:
	if _count_label != null:
		_count_label.text = "Блоков: %d" % grid_model.count()


func _update_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
