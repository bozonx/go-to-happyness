class_name FillModeController
extends MapEditorMode

## First authoring slice of map Fill Mode: named entity records only.  Scatter,
## property inspection and runtime activation deliberately build on this record
## layer instead of creating parallel kinds of placed object.

const TOOL_SELECT := &"select"
const TOOL_PLACE := &"place"
const TOOLS: Array[StringName] = [TOOL_SELECT, TOOL_PLACE]

var _tool: StringName = TOOL_SELECT
var _archetype_id: StringName = &""
var _selected_id: StringName = &""
var _root: Node3D = null
var _views: Dictionary = {}
var _last_warnings: Array[String] = []


func _init() -> void:
	id = &"fill"
	title = "Наполнение"


func configure(next_context: MapEditorContext) -> void:
	super.configure(next_context)
	if _root == null:
		_root = Node3D.new()
		_root.name = "FillEntityViews"
		context.terrain_world.add_child(_root)
	rebuild_views()


func activate() -> void:
	WorldAssetCatalog.refresh()
	rebuild_views()


func deactivate() -> void:
	_selected_id = &""


func document_changed() -> void:
	rebuild_views()


func clear_hover() -> void:
	if context != null and context.brush != null:
		context.brush.clear_hover()


func hover_brush() -> BaseBrushController:
	return context.brush if context != null else null


func process(_delta: float) -> void:
	context.brush.update_hover(context.camera, context.space_state(), context.mouse_position())


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _handle_mouse(event as InputEventMouseButton)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).keycode:
			KEY_TAB:
				_tool = TOOLS[(TOOLS.find(_tool) + 1) % TOOLS.size()]
				return true
			KEY_DELETE:
				return _delete_selected()
	return false


func _handle_mouse(event: InputEventMouseButton) -> bool:
	if not context.brush.has_hover:
		return false
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _tool == TOOL_PLACE:
		_pick_archetype(context.brush.hovered_cell)
		return true
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return false
	if _tool == TOOL_SELECT:
		_selected_id = _entity_at(context.brush.hovered_cell)
		rebuild_views()
		notify_ui_changed()
		return true
	if _archetype_id == &"":
		return false
	_place(context.brush.hovered_cell)
	return true


func _place(cell: Vector2i) -> void:
	if not context.terrain.is_inside(cell) or context.terrain.is_hole(cell):
		return
	var archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	if archetype == null:
		return
	var before := context.document.entities.to_json()
	var record := MapEntityRecord.new()
	record.id = _next_id("entity")
	record.archetype_id = archetype.id
	record.position = _surface_position(cell, archetype)
	record.initial_state = archetype.states.default_state
	record.activity = archetype.activity
	_last_warnings = _placement_warnings(cell, archetype)
	context.document.entities.entities.append(record)
	_selected_id = record.id
	_commit(before, "размещение %s" % archetype.name)


func _surface_position(cell: Vector2i, archetype: EntityArchetype) -> Vector3:
	var position := context.terrain.cell_center(cell)
	var asset := EntityArchetypeCatalog.asset_of(archetype.id)
	if asset != null:
		var policy := asset.placement_policy()
		var surface := _surface_kind(cell)
		if surface in [AssetPlacementPolicy.SURFACE_SHALLOW, AssetPlacementPolicy.SURFACE_WATER, AssetPlacementPolicy.SURFACE_ICE, AssetPlacementPolicy.SURFACE_LAVA]:
			position.y = context.water.surface_metres_at(cell)
		position.y += policy.vertical_offset
	return position


func _surface_kind(cell: Vector2i) -> StringName:
	if not context.water.has_water(cell):
		return AssetPlacementPolicy.SURFACE_GROUND
	if context.water.is_lava(cell):
		return AssetPlacementPolicy.SURFACE_LAVA
	if context.water.is_frozen(cell):
		return AssetPlacementPolicy.SURFACE_ICE
	if context.water.depth_steps_at(context.terrain, cell) <= WaterGrid.FORD_MAX_DEPTH_STEPS:
		return AssetPlacementPolicy.SURFACE_SHALLOW
	return AssetPlacementPolicy.SURFACE_WATER


func _placement_warnings(cell: Vector2i, archetype: EntityArchetype) -> Array[String]:
	var asset := EntityArchetypeCatalog.asset_of(archetype.id)
	if asset == null:
		return ["архетип не нашёл свой ассет: будет показана заглушка"]
	var submerged := context.water.has_water(cell) and context.water.depth_steps_at(context.terrain, cell) > 0
	return asset.placement_policy().warnings_for({
		"surface": _surface_kind(cell),
		"slope_class": context.terrain.slope_class_at(cell),
		"submerged": submerged,
	})


func _pick_archetype(cell: Vector2i) -> void:
	var entity_id := _entity_at(cell)
	var record := context.document.entities.by_id(entity_id)
	if record == null:
		return
	_archetype_id = record.archetype_id
	_tool = TOOL_PLACE
	notify_ui_changed()


func _entity_at(cell: Vector2i) -> StringName:
	for index in range(context.document.entities.entities.size() - 1, -1, -1):
		var record: MapEntityRecord = context.document.entities.entities[index]
		if record.cell(context.terrain) == cell:
			return record.id
	return &""


func _delete_selected() -> bool:
	if _selected_id == &"":
		return false
	var before := context.document.entities.to_json()
	for index in range(context.document.entities.entities.size() - 1, -1, -1):
		if context.document.entities.entities[index].id == _selected_id:
			context.document.entities.entities.remove_at(index)
			_selected_id = &""
			_commit(before, "удаление сущности")
			return true
	return false


func _next_id(prefix: String) -> StringName:
	var number := 1
	while context.document.entities.has_id(StringName("%s_%d" % [prefix, number])):
		number += 1
	return StringName("%s_%d" % [prefix, number])


func _commit(before: Array, command_label: String) -> void:
	var command := MapEntityCommand.of(context.document, before, context.document.entities.to_json(), command_label)
	context.history.push(command)
	rebuild_views()
	notify_ui_changed()


## Presentation-only stand-ins until the chunked renderer and lazy asset nodes
## arrive in 2.4.  They make placement/selectability visible without making map
## data depend on nodes or requiring every archetype scene to be loaded now.
func rebuild_views() -> void:
	if _root == null:
		return
	for child in _root.get_children():
		child.queue_free()
	_views.clear()
	for record: MapEntityRecord in context.document.entities.entities:
		var marker := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.28
		mesh.bottom_radius = 0.38
		mesh.height = 0.65
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.72, 0.22) if record.id == _selected_id else Color(0.28, 0.78, 0.46)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = material
		marker.mesh = mesh
		marker.position = record.position + Vector3.UP * 0.325
		marker.rotation_degrees.y = record.yaw_degrees
		marker.scale = Vector3.ONE * record.scale
		_root.add_child(marker)
		_views[record.id] = marker


func palette_entries() -> Array:
	var entries: Array = [
		PaletteEntry.of(TOOL_SELECT, "Выбрать"),
		PaletteEntry.of(TOOL_PLACE, "Поставить"),
	]
	for archetype: EntityArchetype in EntityArchetypeCatalog.all():
		var asset := EntityArchetypeCatalog.asset_of(archetype.id)
		if asset != null and asset.is_in_scope(WorldAssetDef.SCOPE_MAP):
			entries.append(PaletteEntry.of(archetype.id, archetype.name))
	return entries


func selected_palette_entry() -> StringName:
	return _archetype_id if _tool == TOOL_PLACE and _archetype_id != &"" else _tool


func select_palette_entry(entry_id: StringName) -> void:
	if entry_id in TOOLS:
		_tool = entry_id
	else:
		_archetype_id = entry_id
		_tool = TOOL_PLACE
	notify_ui_changed()


func inspector_lines() -> Array[String]:
	var lines: Array[String] = [
		"Инструмент: %s" % ("поставить" if _tool == TOOL_PLACE else "выбрать"),
		"Сущностей: %d" % context.document.entities.entities.size(),
	]
	var selected := context.document.entities.by_id(_selected_id)
	if selected != null:
		lines.append("id: %s" % selected.id)
		lines.append("архетип: %s" % selected.archetype_id)
		lines.append("клетка: %d, %d" % [selected.cell(context.terrain).x, selected.cell(context.terrain).y])
	for warning in _last_warnings:
		lines.append("⚠ %s" % warning)
	return lines


func list_title() -> String:
	return "Сущности карты"


func list_entries() -> Array[String]:
	var entries: Array[String] = []
	for record: MapEntityRecord in context.document.entities.entities:
		entries.append("● %s · %s" % [record.id, record.archetype_id])
	return entries


func empty_list_hint() -> String:
	return "Выберите архетип и поставьте его на карту"


func status_text() -> String:
	if context.brush == null or not context.brush.has_hover:
		return "Наполнение: выберите архетип в палитре"
	var cell := context.brush.hovered_cell
	return "клетка %d,%d · ЛКМ — %s" % [cell.x, cell.y, "поставить" if _tool == TOOL_PLACE else "выбрать"]
