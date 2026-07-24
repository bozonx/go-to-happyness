class_name BuildingEditor
extends Node3D

## Modular building editor for frame construction and active work zones.
##
## Runs in two modes (see design_docs/content/modular_building_editor.md §5):
##   * Dev mode  — launched by opening this scene directly in Godot; saves to
##     res://data/blueprints and exposes the developer panel.
##   * Player mode — launched from the main menu; saves to user://custom_buildings.
##
## Frame and active-zone modes are functional. Surface finishing and
## furniture/decor are separate disabled stages whose serialized sections are
## already preserved by BuildingBlueprint.

const CameraControllerScene = preload("res://game/features/world/presentation/camera_controller.tscn")
const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BuildingGridModelScript = preload("res://game/features/buildings/domain/editor/building_grid_model.gd")
const ActiveWorkZoneRecordScript = preload("res://game/features/buildings/domain/editor/active_work_zone_record.gd")
const BlueprintRepositoryScript = preload("res://game/features/buildings/presentation/editor/blueprint_repository.gd")
const BlockMeshLibraryScript = preload("res://game/features/buildings/presentation/editor/block_mesh_library.gd")
const UI_THEME = preload("res://game/features/ui/presentation/theme/ui_theme.tres")

enum Tool { PLACE, ERASE }
enum Brush { LINE, RECT }
enum EditMode { FRAME, FINISHES, DECOR, ZONES }

## Forces developer mode when the scene is opened/run directly. The main menu
## clears this via GameLaunchManager before switching in player mode.
@export var dev_mode: bool = true

var grid_model: BuildingGridModelScript
var blueprint: BuildingBlueprintScript
var repository: BlueprintRepositoryScript
var mesh_library: BlockMeshLibraryScript

var current_block_id: StringName = BuildingBlockCatalogScript.default_block_id()
var current_material_id: StringName = BuildingMaterialCatalogScript.DEFAULT_ID
var current_rot: int = 0
var current_tool: int = Tool.PLACE
var current_brush: int = Brush.LINE
var active_layer: int = 0
var cursor_cell: Vector3i = Vector3i.ZERO
var cursor_valid: bool = false

var current_mode: int = EditMode.FRAME

## Frame-mode drag painting state.
var _painting: bool = false
var _last_paint_cell: Vector3i = Vector3i.ZERO
## Fixed corner of the current rectangle brush drag (the cell first pressed).
var _paint_anchor: Vector3i = Vector3i.ZERO

## Zones-mode state.
var _selected_zone_index: int = -1
var _armed_marker: StringName = &"anchor"  ## &"anchor" | &"input" | &"output"

var _block_nodes: Dictionary = {}  ## Vector3i -> MeshInstance3D
var _camera_controller: Node3D
var _blocks_root: Node3D
var _ghost: MeshInstance3D
var _layer_plane: MeshInstance3D
var _zones_visual_root: Node3D
var _panning: bool = false
var _orbiting: bool = false

# UI references populated in _build_ui().
var _name_edit: LineEdit
var _id_edit: LineEdit
var _category_option: OptionButton
var _style_option: OptionButton
var _material_option: OptionButton
var _brush_line_btn: Button
var _brush_rect_btn: Button
var _fallback_edit: LineEdit
var _footprint_x_spin: SpinBox
var _footprint_z_spin: SpinBox
var _entrance_x_spin: SpinBox
var _entrance_z_spin: SpinBox
var _palette_panel: PanelContainer
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

# Zones panel references.
var _zones_panel: PanelContainer
var _zone_option: OptionButton
var _zone_id_edit: LineEdit
var _zone_name_edit: LineEdit
var _zone_kind_option: OptionButton
var _zone_subtype_row: VBoxContainer
var _zone_subtype_option: OptionButton
var _zone_profession_option: OptionButton
var _zone_workers_spin: SpinBox
var _zone_info_label: Label
var _zone_action_edit: LineEdit
var _zone_marker_yaw_spin: SpinBox
var _zone_tray_capacity_spin: SpinBox
var _marker_buttons: Dictionary = {}  ## StringName -> Button

const ZONE_PROFESSIONS: Array[StringName] = [
	&"cook", &"teacher", &"seller", &"official", &"researcher",
	&"craftsman", &"forager", &"trader",
]

const ZONE_COLORS: Array[Color] = [
	Color(0.35, 0.75, 1.0), Color(1.0, 0.7, 0.3), Color(0.6, 1.0, 0.5),
	Color(1.0, 0.5, 0.8), Color(0.8, 0.8, 0.4), Color(0.5, 0.9, 0.9),
]


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

	_zones_visual_root = Node3D.new()
	_zones_visual_root.name = "ZonesVisual"
	add_child(_zones_visual_root)

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
		elif _painting:
			# Drag to build/erase following the mouse: a line, or — with the
			# rectangle brush — a filled floor/ceiling slab from the anchor.
			_update_cursor()
			if cursor_valid:
				if current_mode == EditMode.ZONES and _armed_marker == &"area":
					_paint_zone_line(_last_paint_cell, cursor_cell)
				elif current_mode == EditMode.FRAME and current_brush == Brush.RECT:
					_paint_rect(_paint_anchor, cursor_cell)
				else:
					_paint_line(_last_paint_cell, cursor_cell)
				_last_paint_cell = cursor_cell
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
				if _pointer_over_ui():
					return
				if current_mode == EditMode.ZONES:
					_place_zone_marker_at_cursor()
					_painting = _armed_marker == &"area"
					_last_paint_cell = cursor_cell
				else:
					_painting = true
					_last_paint_cell = cursor_cell
					_paint_anchor = cursor_cell
					if current_brush == Brush.RECT:
						_paint_rect(_paint_anchor, cursor_cell)
					else:
						_apply_tool_at_cursor()
			else:
				_painting = false


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
	_apply_tool_at_cell(cursor_cell)
	_refresh_ghost()


func _apply_tool_at_cell(cell: Vector3i) -> void:
	match current_tool:
		Tool.PLACE:
			if grid_model.place(cell, current_block_id, current_rot, current_material_id):
				_spawn_or_update_block_node(grid_model.get_block_at(cell))
				_update_count()
		Tool.ERASE:
			if grid_model.erase(cell):
				_remove_block_node(cell)
				_update_count()


## Applies the current tool to every cell on the line between two grid cells
## (inclusive), so a mouse drag lays a continuous run of blocks.
func _paint_line(from_cell: Vector3i, to_cell: Vector3i) -> void:
	var dx := absi(to_cell.x - from_cell.x)
	var dz := absi(to_cell.z - from_cell.z)
	var sx := 1 if to_cell.x > from_cell.x else -1
	var sz := 1 if to_cell.z > from_cell.z else -1
	var x := from_cell.x
	var z := from_cell.z
	var err := dx - dz
	var y := active_layer
	while true:
		_apply_tool_at_cell(Vector3i(x, y, z))
		if x == to_cell.x and z == to_cell.z:
			break
		var e2 := 2 * err
		if e2 > -dz:
			err -= dz
			x += sx
		if e2 < dx:
			err += dx
			z += sz
	_refresh_ghost()


## Fills the axis-aligned rectangle spanned by two grid cells at the active
## layer. Used to lay whole floors and ceilings in one drag.
func _paint_rect(from_cell: Vector3i, to_cell: Vector3i) -> void:
	var x0 := mini(from_cell.x, to_cell.x)
	var x1 := maxi(from_cell.x, to_cell.x)
	var z0 := mini(from_cell.z, to_cell.z)
	var z1 := maxi(from_cell.z, to_cell.z)
	var y := active_layer
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			_apply_tool_at_cell(Vector3i(x, y, z))
	_refresh_ghost()


func _paint_zone_line(from_cell: Vector3i, to_cell: Vector3i) -> void:
	var zone := _current_zone()
	if zone == null:
		return
	var steps := maxi(absi(to_cell.x - from_cell.x), absi(to_cell.z - from_cell.z))
	for step in range(steps + 1):
		var t := float(step) / float(maxi(1, steps))
		var cell := Vector3i(
			roundi(lerpf(from_cell.x, to_cell.x, t)),
			active_layer,
			roundi(lerpf(from_cell.z, to_cell.z, t)))
		if cell not in zone.cells:
			zone.cells.append(cell)
	_refresh_zone_visuals()
	_update_zone_info()


func _pointer_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


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
	node.material_override = mesh_library.material_for(block.material_id)
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
	if current_mode == EditMode.ZONES or not cursor_valid:
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


## Repopulates the frame material list from the currently chosen era. Materials
## from the era and every earlier era are offered (cumulative), so each era has
## several materials; the block material is thus driven by the era, not picked
## from the full catalog.
func _rebuild_material_options() -> void:
	if _material_option == null:
		return
	_material_option.clear()
	var current_ok := false
	for material in BuildingMaterialCatalogScript.materials_for_era(blueprint.category):
		_material_option.add_item("%s → %s" % [material["name"], material["resource_id"]])
		_material_option.set_item_metadata(_material_option.item_count - 1, material["id"])
		if material["id"] == current_material_id:
			current_ok = true
	if not current_ok:
		current_material_id = BuildingMaterialCatalogScript.default_material_for_era(blueprint.category)
	for i in _material_option.item_count:
		if _material_option.get_item_metadata(i) == current_material_id:
			_material_option.select(i)
			break
	_refresh_ghost()


func _on_era_changed(index: int) -> void:
	blueprint.category = str(_category_option.get_item_metadata(index))
	_rebuild_material_options()
	_refresh_underground_availability()
	var offenders := _count_blocks_off_era()
	if offenders > 0:
		_update_status("Эра: %s. Внимание: %d блок(ов) используют более поздний материал." % [blueprint.category, offenders])
	else:
		_update_status("Эра: %s." % blueprint.category)


## Number of placed blocks whose material is not available in the chosen era.
func _count_blocks_off_era() -> int:
	var count := 0
	for block in grid_model.all_blocks():
		if not BuildingMaterialCatalogScript.is_available_in_era(block.material_id, blueprint.category):
			count += 1
	return count


## Underground digging is unlocked only from the earth era; keep the style option
## honest about that and never leave an illegal underground selection standing.
func _refresh_underground_availability() -> void:
	if _style_option == null:
		return
	var earth_rank := BuildingMaterialCatalogScript.era_rank("earth")
	var allowed := BuildingMaterialCatalogScript.era_rank(blueprint.category) >= earth_rank
	for i in _style_option.item_count:
		if _style_option.get_item_metadata(i) == &"underground":
			_style_option.set_item_disabled(i, not allowed)
	if not allowed and blueprint.construction_style == &"underground":
		blueprint.construction_style = &"surface"
		_select_style_in_option(&"surface")


func _select_style_in_option(style: StringName) -> void:
	if _style_option == null:
		return
	for i in _style_option.item_count:
		if _style_option.get_item_metadata(i) == style:
			_style_option.select(i)
			break


func _set_brush(brush_id: int) -> void:
	current_brush = brush_id
	if _brush_line_btn != null:
		_brush_line_btn.button_pressed = brush_id == Brush.LINE
	if _brush_rect_btn != null:
		_brush_rect_btn.button_pressed = brush_id == Brush.RECT


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
	# Frame and Zones modes are functional. Finishes and furnishings have
	# separate data sections and UI slots, but their authoring slices are next.
	if mode in [EditMode.FINISHES, EditMode.DECOR]:
		_update_status("Этот режим подготовлен в формате и будет реализован следующим срезом.")
		if _mode_buttons.has(current_mode):
			(_mode_buttons[current_mode] as Button).button_pressed = true
		return
	current_mode = mode
	for m in _mode_buttons.keys():
		(_mode_buttons[m] as Button).button_pressed = m == mode
	if _palette_panel != null:
		_palette_panel.visible = mode == EditMode.FRAME
	if _zones_panel != null:
		_zones_panel.visible = mode == EditMode.ZONES
	if mode == EditMode.ZONES:
		_set_tool(Tool.PLACE)
		_refresh_zone_visuals()
		_update_status("Режим зон: создайте зону и расставьте якоря работы / поддоны.")
	else:
		_update_status("Режим каркаса.")
	_refresh_ghost()


# ---------------------------------------------------------------------------
# Save / load / new
# ---------------------------------------------------------------------------

func _on_save_pressed() -> void:
	blueprint.name = _name_edit.text.strip_edges()
	if blueprint.name.is_empty():
		blueprint.name = "Новое здание"
	if _id_edit != null:
		var raw_id := _id_edit.text.strip_edges()
		if not raw_id.is_empty():
			blueprint.id = StringName(raw_id)
	if _category_option != null:
		blueprint.category = str(_category_option.get_item_metadata(_category_option.selected))
	if _fallback_edit != null and not _fallback_edit.text.strip_edges().is_empty():
		blueprint.fallback_building_id = StringName(_fallback_edit.text.strip_edges())
	if _footprint_x_spin != null and _footprint_z_spin != null:
		blueprint.footprint = Vector2i(int(_footprint_x_spin.value), int(_footprint_z_spin.value))
	if _entrance_x_spin != null and _entrance_z_spin != null:
		blueprint.entrance = Vector2i(int(_entrance_x_spin.value), int(_entrance_z_spin.value))
	grid_model.write_to_blueprint(blueprint)
	var result := repository.save(blueprint)
	if result["ok"]:
		_update_status("Сохранено: %s (%d блоков)" % [result["path"], blueprint.block_count()])
	else:
		_update_status("Ошибка сохранения: %s" % result["error"])


func _on_new_pressed() -> void:
	grid_model.clear()
	blueprint = BuildingBlueprintScript.new()
	_selected_zone_index = -1
	_rebuild_all_block_nodes()
	_rebuild_zone_option()
	_refresh_zone_visuals()
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
	_selected_zone_index = 0 if not blueprint.work_zones.is_empty() else -1
	_rebuild_all_block_nodes()
	_rebuild_zone_option()
	_refresh_zone_visuals()
	_sync_metadata_fields()
	_load_popup.hide()
	_update_status("Загружено: %s (%d блоков, %d зон)" % [blueprint.name, blueprint.block_count(), blueprint.work_zones.size()])


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
	_build_zones_panel(root)
	_build_status_bar(root)
	_build_load_popup(root)
	_build_dev_panel(root)
	_sync_metadata_fields()

	_select_block(current_block_id)
	_set_tool(Tool.PLACE)
	_set_brush(Brush.LINE)
	_set_layer(0)
	_update_count()
	_select_mode(EditMode.FRAME)


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

	var id_label := Label.new()
	id_label.text = "ID:"
	hbox.add_child(id_label)
	_id_edit = LineEdit.new()
	_id_edit.custom_minimum_size = Vector2(140, 0)
	_id_edit.text = String(blueprint.id)
	hbox.add_child(_id_edit)

	hbox.add_child(_make_separator_v())

	# Editing stages are deliberately separate: surface finishes do not share
	# authoring state with furniture/decor placement.
	for mode_info in [
		{"mode": EditMode.FRAME, "label": "1. Каркас", "enabled": true},
		{"mode": EditMode.FINISHES, "label": "2. Отделка", "enabled": false},
		{"mode": EditMode.DECOR, "label": "3. Декор", "enabled": false},
		{"mode": EditMode.ZONES, "label": "4. Зоны", "enabled": true},
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
	_palette_panel = panel

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

	# Brush shape: single line vs. filled rectangle (floors and ceilings).
	var brush_row := HBoxContainer.new()
	vbox.add_child(brush_row)
	_brush_line_btn = Button.new()
	_brush_line_btn.text = "／ Линия"
	_brush_line_btn.toggle_mode = true
	_brush_line_btn.tooltip_text = "Кисть: линия по перетаскиванию"
	_brush_line_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brush_line_btn.pressed.connect(func(): _set_brush(Brush.LINE))
	brush_row.add_child(_brush_line_btn)
	_brush_rect_btn = Button.new()
	_brush_rect_btn.text = "▭ Прямоуг."
	_brush_rect_btn.toggle_mode = true
	_brush_rect_btn.tooltip_text = "Кисть: прямоугольник — залить пол или потолок"
	_brush_rect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brush_rect_btn.pressed.connect(func(): _set_brush(Brush.RECT))
	brush_row.add_child(_brush_rect_btn)

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

	var materials_label := Label.new()
	materials_label.text = "Материал каркаса (по эре)"
	materials_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(materials_label)
	_material_option = OptionButton.new()
	_material_option.item_selected.connect(func(index: int):
		current_material_id = _material_option.get_item_metadata(index)
		_refresh_ghost()
	)
	vbox.add_child(_material_option)
	_rebuild_material_options()

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


# ---------------------------------------------------------------------------
# Active work zones (Mode 3)
# ---------------------------------------------------------------------------

func _build_zones_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_top = 60.0
	panel.offset_bottom = -48.0
	panel.offset_left = 8.0
	panel.custom_minimum_size = Vector2(260, 0)
	panel.visible = false
	root.add_child(panel)
	_zones_panel = panel

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "Активные зоны"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var zone_row := HBoxContainer.new()
	vbox.add_child(zone_row)
	_zone_option = OptionButton.new()
	_zone_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zone_option.item_selected.connect(_on_zone_option_selected)
	zone_row.add_child(_zone_option)
	var add_btn := Button.new()
	add_btn.text = "＋"
	add_btn.tooltip_text = "Создать зону"
	add_btn.pressed.connect(_add_zone)
	zone_row.add_child(add_btn)
	var del_btn := Button.new()
	del_btn.text = "🗑"
	del_btn.tooltip_text = "Удалить зону"
	del_btn.pressed.connect(_delete_zone)
	zone_row.add_child(del_btn)

	vbox.add_child(HSeparator.new())

	vbox.add_child(_labeled("ID зоны:"))
	_zone_id_edit = LineEdit.new()
	_zone_id_edit.text_changed.connect(_on_zone_id_changed)
	vbox.add_child(_zone_id_edit)

	vbox.add_child(_labeled("Название зоны:"))
	_zone_name_edit = LineEdit.new()
	_zone_name_edit.text_changed.connect(_on_zone_name_changed)
	vbox.add_child(_zone_name_edit)

	vbox.add_child(_labeled("Назначение:"))
	_zone_kind_option = OptionButton.new()
	for kind in ActiveWorkZoneRecordScript.KINDS:
		_zone_kind_option.add_item(ActiveWorkZoneRecordScript.kind_display_name(kind))
		_zone_kind_option.set_item_metadata(_zone_kind_option.item_count - 1, kind)
	_zone_kind_option.item_selected.connect(_on_zone_kind_selected)
	vbox.add_child(_zone_kind_option)

	# Subtype (recreation flavour / special marker). Hidden for flat kinds.
	_zone_subtype_row = VBoxContainer.new()
	_zone_subtype_row.add_child(_labeled("Тип:"))
	_zone_subtype_option = OptionButton.new()
	_zone_subtype_option.item_selected.connect(_on_zone_subtype_selected)
	_zone_subtype_row.add_child(_zone_subtype_option)
	vbox.add_child(_zone_subtype_row)

	vbox.add_child(_labeled("Профессия:"))
	_zone_profession_option = OptionButton.new()
	_zone_profession_option.add_item("— нет —")
	_zone_profession_option.set_item_metadata(0, &"")
	for prof in ZONE_PROFESSIONS:
		_zone_profession_option.add_item(String(prof))
		_zone_profession_option.set_item_metadata(_zone_profession_option.item_count - 1, prof)
	_zone_profession_option.item_selected.connect(_on_zone_profession_selected)
	vbox.add_child(_zone_profession_option)

	var workers_row := HBoxContainer.new()
	vbox.add_child(workers_row)
	workers_row.add_child(_labeled("Макс. рабочих:"))
	_zone_workers_spin = SpinBox.new()
	_zone_workers_spin.min_value = 0
	_zone_workers_spin.max_value = 12
	_zone_workers_spin.value = 1
	_zone_workers_spin.value_changed.connect(_on_zone_workers_changed)
	workers_row.add_child(_zone_workers_spin)

	vbox.add_child(HSeparator.new())

	vbox.add_child(_labeled("Действие якоря:"))
	_zone_action_edit = LineEdit.new()
	_zone_action_edit.text = "work"
	vbox.add_child(_zone_action_edit)

	var marker_settings := HBoxContainer.new()
	marker_settings.add_child(_labeled("Поворот:"))
	_zone_marker_yaw_spin = SpinBox.new()
	_zone_marker_yaw_spin.min_value = 0
	_zone_marker_yaw_spin.max_value = 270
	_zone_marker_yaw_spin.step = 90
	marker_settings.add_child(_zone_marker_yaw_spin)
	marker_settings.add_child(_labeled("Ёмкость:"))
	_zone_tray_capacity_spin = SpinBox.new()
	_zone_tray_capacity_spin.min_value = 1
	_zone_tray_capacity_spin.max_value = 10000
	_zone_tray_capacity_spin.value = 50
	marker_settings.add_child(_zone_tray_capacity_spin)
	vbox.add_child(marker_settings)

	var place_label := Label.new()
	place_label.text = "Что ставить (ЛКМ по сетке):"
	place_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	vbox.add_child(place_label)

	for marker in [
		{"id": &"area", "label": "▦ Ячейка зоны"},
		{"id": &"anchor", "label": "📍 Якорь работы"},
		{"id": &"input", "label": "📥 Поддон (вход)"},
		{"id": &"output", "label": "📤 Поддон (выход)"},
	]:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = marker["label"]
		var marker_id: StringName = marker["id"]
		btn.pressed.connect(func(): _arm_marker(marker_id))
		_marker_buttons[marker_id] = btn
		vbox.add_child(btn)

	var clear_anchors := Button.new()
	clear_anchors.text = "Очистить область и маркеры"
	clear_anchors.pressed.connect(_clear_zone_anchors)
	vbox.add_child(clear_anchors)

	vbox.add_child(HSeparator.new())
	_zone_info_label = Label.new()
	_zone_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zone_info_label.add_theme_color_override("font_color", Color(0.6, 0.66, 0.72))
	vbox.add_child(_zone_info_label)

	_arm_marker(&"anchor")
	_rebuild_zone_option()


func _labeled(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _current_zone() -> ActiveWorkZoneRecord:
	if _selected_zone_index < 0 or _selected_zone_index >= blueprint.work_zones.size():
		return null
	return blueprint.work_zones[_selected_zone_index]


func _add_zone() -> void:
	var zone := ActiveWorkZoneRecordScript.new()
	var next_index := 1
	var existing_ids: Array = blueprint.work_zones.map(func(existing): return existing.zone_id)
	while StringName("zone_%d" % next_index) in existing_ids:
		next_index += 1
	zone.zone_id = StringName("zone_%d" % next_index)
	zone.zone_name = "Зона %d" % (blueprint.work_zones.size() + 1)
	blueprint.work_zones.append(zone)
	_selected_zone_index = blueprint.work_zones.size() - 1
	_rebuild_zone_option()
	_refresh_zone_panel_fields()
	_refresh_zone_visuals()
	_update_status("Зона создана. Задайте назначение и расставьте якоря.")


func _delete_zone() -> void:
	var zone := _current_zone()
	if zone == null:
		return
	blueprint.work_zones.remove_at(_selected_zone_index)
	_selected_zone_index = mini(_selected_zone_index, blueprint.work_zones.size() - 1)
	_rebuild_zone_option()
	_refresh_zone_panel_fields()
	_refresh_zone_visuals()


func _rebuild_zone_option() -> void:
	if _zone_option == null:
		return
	_zone_option.clear()
	for i in blueprint.work_zones.size():
		var zone: ActiveWorkZoneRecord = blueprint.work_zones[i]
		_zone_option.add_item("%s" % zone.zone_name)
	if _selected_zone_index >= 0 and _selected_zone_index < blueprint.work_zones.size():
		_zone_option.select(_selected_zone_index)
	_refresh_zone_panel_fields()


func _on_zone_option_selected(index: int) -> void:
	_selected_zone_index = index
	_refresh_zone_panel_fields()
	_refresh_zone_visuals()


func _refresh_zone_panel_fields() -> void:
	var zone := _current_zone()
	var has_zone := zone != null
	if _zone_name_edit != null:
		_zone_name_edit.editable = has_zone
	if _zone_id_edit != null:
		_zone_id_edit.editable = has_zone
	if _zone_kind_option != null:
		_zone_kind_option.disabled = not has_zone
	if _zone_profession_option != null:
		_zone_profession_option.disabled = not has_zone
	if _zone_workers_spin != null:
		_zone_workers_spin.editable = has_zone
	if not has_zone:
		if _zone_name_edit != null:
			_zone_name_edit.text = ""
		if _zone_id_edit != null:
			_zone_id_edit.text = ""
		if _zone_info_label != null:
			_zone_info_label.text = "Нет зон. Нажмите ＋, чтобы создать."
		_rebuild_zone_subtype_options()
		return
	if _zone_name_edit != null:
		_zone_name_edit.text = zone.zone_name
	if _zone_id_edit != null:
		_zone_id_edit.text = String(zone.zone_id)
	if _zone_kind_option != null:
		for i in _zone_kind_option.item_count:
			if _zone_kind_option.get_item_metadata(i) == zone.kind:
				_zone_kind_option.select(i)
				break
	_rebuild_zone_subtype_options()
	if _zone_profession_option != null:
		var found := 0
		for i in _zone_profession_option.item_count:
			if _zone_profession_option.get_item_metadata(i) == zone.profession:
				found = i
				break
		_zone_profession_option.select(found)
	if _zone_workers_spin != null:
		_zone_workers_spin.value = zone.max_workers
	_update_zone_info()


func _update_zone_info() -> void:
	var zone := _current_zone()
	if zone == null or _zone_info_label == null:
		return
	var trays := ""
	if zone.storage_trays.has("input"):
		trays += " вход✓"
	if zone.storage_trays.has("output"):
		trays += " выход✓"
	var subtype_line := ""
	if zone.subtype != &"":
		subtype_line = "\nТип: %s" % ActiveWorkZoneRecordScript.subtype_display_name(zone.subtype)
	_zone_info_label.text = "Ячеек: %d · Якорей: %d · Поддоны:%s\nID: %s%s" % [
		zone.cells.size(), zone.work_anchors.size(), (trays if trays != "" else " —"), zone.zone_id, subtype_line]


func _on_zone_name_changed(text: String) -> void:
	var zone := _current_zone()
	if zone == null:
		return
	zone.zone_name = text
	if _zone_option != null and _selected_zone_index >= 0:
		_zone_option.set_item_text(_selected_zone_index, text)


func _on_zone_id_changed(text: String) -> void:
	var zone := _current_zone()
	if zone != null:
		zone.zone_id = StringName(text.strip_edges().to_lower())


func _on_zone_kind_selected(index: int) -> void:
	var zone := _current_zone()
	if zone == null:
		return
	zone.kind = _zone_kind_option.get_item_metadata(index)
	# Reset the subtype to the first legal value for the new kind (or none).
	var subtypes := ActiveWorkZoneRecordScript.subtypes_for_kind(zone.kind)
	zone.subtype = subtypes[0] if not subtypes.is_empty() else &""
	_rebuild_zone_subtype_options()
	_update_zone_info()


func _on_zone_subtype_selected(index: int) -> void:
	var zone := _current_zone()
	if zone == null:
		return
	zone.subtype = _zone_subtype_option.get_item_metadata(index)


## Fills the subtype list from the zone's kind and hides the row for flat kinds.
func _rebuild_zone_subtype_options() -> void:
	if _zone_subtype_option == null:
		return
	var zone := _current_zone()
	var subtypes: Array[StringName] = []
	if zone != null:
		subtypes = ActiveWorkZoneRecordScript.subtypes_for_kind(zone.kind)
	_zone_subtype_row.visible = not subtypes.is_empty()
	_zone_subtype_option.clear()
	for st in subtypes:
		_zone_subtype_option.add_item(ActiveWorkZoneRecordScript.subtype_display_name(st))
		_zone_subtype_option.set_item_metadata(_zone_subtype_option.item_count - 1, st)
	if zone != null:
		for i in _zone_subtype_option.item_count:
			if _zone_subtype_option.get_item_metadata(i) == zone.subtype:
				_zone_subtype_option.select(i)
				break


func _on_zone_profession_selected(index: int) -> void:
	var zone := _current_zone()
	if zone == null:
		return
	zone.profession = _zone_profession_option.get_item_metadata(index)


func _on_zone_workers_changed(value: float) -> void:
	var zone := _current_zone()
	if zone == null:
		return
	zone.max_workers = int(value)


func _arm_marker(marker: StringName) -> void:
	_armed_marker = marker
	for id in _marker_buttons.keys():
		(_marker_buttons[id] as Button).button_pressed = id == marker


func _clear_zone_anchors() -> void:
	var zone := _current_zone()
	if zone == null:
		return
	zone.work_anchors.clear()
	zone.storage_trays.clear()
	zone.cells.clear()
	_refresh_zone_visuals()
	_update_zone_info()


func _place_zone_marker_at_cursor() -> void:
	if not cursor_valid:
		return
	var zone := _current_zone()
	if zone == null:
		_update_status("Сначала создайте зону (＋).")
		return
	var pos := Vector3(cursor_cell) + Vector3(0.5, 0.0, 0.5)
	match _armed_marker:
		&"area":
			if cursor_cell not in zone.cells:
				zone.cells.append(cursor_cell)
		&"input":
			zone.set_tray(&"input", pos, int(_zone_tray_capacity_spin.value))
		&"output":
			zone.set_tray(&"output", pos, int(_zone_tray_capacity_spin.value))
		_:
			zone.add_anchor(
				pos,
				Vector3(0.0, _zone_marker_yaw_spin.value, 0.0),
				_zone_action_edit.text.strip_edges() if not _zone_action_edit.text.strip_edges().is_empty() else "work")
	_refresh_zone_visuals()
	_update_zone_info()


func _refresh_zone_visuals() -> void:
	if _zones_visual_root == null:
		return
	for child in _zones_visual_root.get_children():
		child.queue_free()
	if current_mode != EditMode.ZONES:
		return
	for i in blueprint.work_zones.size():
		var zone: ActiveWorkZoneRecord = blueprint.work_zones[i]
		var color := ZONE_COLORS[i % ZONE_COLORS.size()]
		for cell in zone.cells:
			_add_zone_marker(Vector3(cell) + Vector3(0.5, 0.0, 0.5), color, Vector3(0.9, 0.04, 0.9), true)
		for anchor in zone.work_anchors:
			_add_zone_marker(anchor["pos"], color, Vector3(0.4, 1.2, 0.4), false)
		if zone.storage_trays.has("input"):
			_add_zone_marker(zone.storage_trays["input"]["pos"], Color(0.4, 0.8, 1.0), Vector3(0.7, 0.3, 0.7), true)
		if zone.storage_trays.has("output"):
			_add_zone_marker(zone.storage_trays["output"]["pos"], Color(1.0, 0.7, 0.3), Vector3(0.7, 0.3, 0.7), true)


func _add_zone_marker(pos: Vector3, color: Color, size: Vector3, is_tray: bool) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = pos + Vector3(0.0, size.y * 0.5 + (0.02 if is_tray else 0.0), 0.0)
	_zones_visual_root.add_child(mi)


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
	help.text = "ЛКМ (зажать) — линия/прямоугольник · ПКМ — камера · СКМ — панорама · Колесо — зум · WASD — движение"
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
	title.text = "Параметры здания"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	vbox.add_child(_labeled("Эра (задаёт материалы):"))
	_category_option = OptionButton.new()
	for category_id in BuildingMaterialCatalogScript.ERA_ORDER:
		_category_option.add_item(category_id.capitalize())
		_category_option.set_item_metadata(_category_option.item_count - 1, category_id)
	_category_option.item_selected.connect(_on_era_changed)
	vbox.add_child(_category_option)

	vbox.add_child(_labeled("Стиль постройки:"))
	_style_option = OptionButton.new()
	for style_info in [
		{"id": &"surface", "label": "Наземная"},
		{"id": &"underground", "label": "Подземная (с земляной эры)"},
	]:
		_style_option.add_item(style_info["label"])
		_style_option.set_item_metadata(_style_option.item_count - 1, style_info["id"])
	_style_option.item_selected.connect(func(index: int):
		blueprint.construction_style = _style_option.get_item_metadata(index)
	)
	vbox.add_child(_style_option)

	vbox.add_child(_labeled("Fallback стандартного здания:"))
	_fallback_edit = LineEdit.new()
	_fallback_edit.text = String(blueprint.fallback_building_id)
	vbox.add_child(_fallback_edit)

	vbox.add_child(_labeled("Пятно размещения X × Z:"))
	var footprint_row := HBoxContainer.new()
	_footprint_x_spin = SpinBox.new()
	_footprint_x_spin.min_value = 1
	_footprint_x_spin.max_value = 64
	_footprint_x_spin.value = blueprint.footprint.x
	footprint_row.add_child(_footprint_x_spin)
	_footprint_z_spin = SpinBox.new()
	_footprint_z_spin.min_value = 1
	_footprint_z_spin.max_value = 64
	_footprint_z_spin.value = blueprint.footprint.y
	footprint_row.add_child(_footprint_z_spin)
	vbox.add_child(footprint_row)

	# Entrance offset from the footprint centre (grid cells). Citizens path to the
	# building through this side; 0,0 lets the game pick a default edge.
	vbox.add_child(_labeled("Вход (смещение X × Z от центра):"))
	var entrance_row := HBoxContainer.new()
	_entrance_x_spin = SpinBox.new()
	_entrance_x_spin.min_value = -32
	_entrance_x_spin.max_value = 32
	_entrance_x_spin.value = blueprint.entrance.x
	entrance_row.add_child(_entrance_x_spin)
	_entrance_z_spin = SpinBox.new()
	_entrance_z_spin.min_value = -32
	_entrance_z_spin.max_value = 32
	_entrance_z_spin.value = blueprint.entrance.y
	entrance_row.add_child(_entrance_z_spin)
	vbox.add_child(entrance_row)

	var path_hint := Label.new()
	path_hint.text = "Сохранение → %s" % repository.base_dir()
	path_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	path_hint.add_theme_color_override("font_color", Color(0.6, 0.66, 0.72))
	vbox.add_child(path_hint)

	if dev_mode:
		vbox.add_child(HSeparator.new())
		for label_text in ["Экспорт меша .tres/.gltf (скоро)", "Просмотр NavMesh (скоро)"]:
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
	if _fallback_edit != null:
		_fallback_edit.text = String(blueprint.fallback_building_id)
	if _footprint_x_spin != null:
		_footprint_x_spin.value = blueprint.footprint.x
	if _footprint_z_spin != null:
		_footprint_z_spin.value = blueprint.footprint.y
	if _entrance_x_spin != null:
		_entrance_x_spin.value = blueprint.entrance.x
	if _entrance_z_spin != null:
		_entrance_z_spin.value = blueprint.entrance.y
	if _category_option != null:
		for i in _category_option.item_count:
			if str(_category_option.get_item_metadata(i)) == blueprint.category:
				_category_option.select(i)
				break
	_select_style_in_option(blueprint.construction_style)
	_rebuild_material_options()
	_refresh_underground_availability()


func _update_rotation_label() -> void:
	if _rot_label != null:
		_rot_label.text = "%d°" % (current_rot * 90)


func _update_count() -> void:
	if _count_label != null:
		_count_label.text = "Блоков: %d" % grid_model.count()


func _update_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
