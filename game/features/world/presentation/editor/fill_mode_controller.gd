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
var _additional_selected: Array[StringName] = []
var _root: Node3D = null
var _views: Dictionary = {}
var _last_warnings: Array[String] = []
var _ghost: Node3D = null
var _ghost_archetype_id: StringName = &""


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
	_additional_selected.clear()
	_hide_ghost()


func document_changed() -> void:
	rebuild_views()


func clear_hover() -> void:
	if context != null and context.brush != null:
		context.brush.clear_hover()


func hover_brush() -> BaseBrushController:
	return context.brush if context != null else null


func process(_delta: float) -> void:
	context.brush.update_hover(context.camera, context.space_state(), context.mouse_position())
	_refresh_ghost()


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _handle_mouse(event as InputEventMouseButton)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key := event as InputEventKey
		if key.ctrl_pressed and key.keycode == KEY_D:
			return _duplicate_selection()
		match (event as InputEventKey).keycode:
			KEY_TAB:
				_tool = TOOLS[(TOOLS.find(_tool) + 1) % TOOLS.size()]
				return true
			KEY_DELETE:
				return _delete_selected()
			KEY_R:
				return _rotate_selection(-1 if key.shift_pressed else 1)
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
		_select_at(context.brush.hovered_cell, event.shift_pressed)
		rebuild_views()
		notify_ui_changed()
		return true
	if _archetype_id == &"":
		return false
	_place(context.brush.hovered_cell)
	return true


func _select_at(cell: Vector2i, additive: bool) -> void:
	var found := _entity_at(cell)
	if not additive:
		_selected_id = found
		_additional_selected.clear()
		return
	if found == &"":
		return
	if _selected_id == &"":
		_selected_id = found
	elif found == _selected_id:
		_selected_id = _additional_selected.pop_front() if not _additional_selected.is_empty() else &""
	elif found in _additional_selected:
		_additional_selected.erase(found)
	else:
		_additional_selected.append(found)


func _selected_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if _selected_id != &"":
		ids.append(_selected_id)
	for entity_id: StringName in _additional_selected:
		if entity_id not in ids:
			ids.append(entity_id)
	return ids


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
	# MapEntityRecord stores Y relative to the terrain at its X/Z. Keeping that
	# contract here is essential: the renderer and launched runtime add the live
	# terrain height when projecting the record into world space.
	position.y = 0.0
	var asset := EntityArchetypeCatalog.asset_of(archetype.id)
	if asset != null:
		var policy := asset.placement_policy()
		var surface := _surface_kind(cell)
		if surface in [AssetPlacementPolicy.SURFACE_SHALLOW, AssetPlacementPolicy.SURFACE_WATER, AssetPlacementPolicy.SURFACE_ICE, AssetPlacementPolicy.SURFACE_LAVA]:
			# Water levels are absolute, while the stored value is relative to
			# ground. This makes the projection land exactly on the water surface.
			position.y = context.water.surface_metres_at(cell) - context.terrain.height_at(position)
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
	var selected := _selected_ids()
	if selected.is_empty():
		return false
	var before := context.document.entities.to_json()
	for index in range(context.document.entities.entities.size() - 1, -1, -1):
		if context.document.entities.entities[index].id in selected:
			context.document.entities.entities.remove_at(index)
	_selected_id = &""
	_additional_selected.clear()
	_commit(before, "удаление сущности")
	return true


func _duplicate_selection() -> bool:
	var selected := _selected_ids()
	if selected.is_empty():
		return false
	var before := context.document.entities.to_json()
	var copies: Array[MapEntityRecord] = []
	for entity_id: StringName in selected:
		var original := context.document.entities.by_id(entity_id)
		if original == null:
			continue
		var copy := MapEntityRecord.from_dict(original.to_dict())
		copy.id = _next_id("entity")
		copy.position.x += context.terrain.cell_size
		var cell := copy.cell(context.terrain)
		if not context.terrain.is_inside(cell) or context.terrain.is_hole(cell):
			continue
		var archetype := EntityArchetypeCatalog.get_archetype(copy.archetype_id)
		if archetype != null:
			copy.position = _surface_position(cell, archetype)
		copies.append(copy)
	if copies.is_empty():
		return false
	context.document.entities.entities.append_array(copies)
	_selected_id = copies[0].id
	_additional_selected.clear()
	for copy: MapEntityRecord in copies.slice(1):
		_additional_selected.append(copy.id)
	_commit(before, "дублирование сущности")
	return true


func _rotate_selection(direction: int) -> bool:
	var selected := _selected_ids()
	if selected.is_empty():
		return false
	var before := context.document.entities.to_json()
	for entity_id: StringName in selected:
		var record := context.document.entities.by_id(entity_id)
		if record != null:
			record.yaw_degrees = fposmod(record.yaw_degrees + 15.0 * direction, 360.0)
	_commit(before, "поворот сущности")
	return true


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
		var view := _make_view(record.archetype_id)
		_root.add_child(view)
		_apply_transform(view, record)
		if record.id in _selected_ids():
			_add_selection_ring(view)
		_views[record.id] = view


func _make_view(archetype_id: StringName) -> Node3D:
	var asset := EntityArchetypeCatalog.asset_of(archetype_id)
	if asset != null and ResourceLoader.exists(asset.scene_path):
		var scene := load(asset.scene_path) as PackedScene
		if scene != null:
			var instance := scene.instantiate() as Node3D
			if instance != null:
				return instance
	# A missing pack must remain editable. This marker is deliberately a
	# placeholder, not a second asset system.
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


func _apply_transform(view: Node3D, record: MapEntityRecord) -> void:
	view.position = _world_position(record.position)
	# Stored Y is the authored offset above ground. The editor must draw the same
	# terrain-attached transform the launched map uses, otherwise objects vanish
	# into raised terrain or float over excavations.
	view.rotation_degrees.y = record.yaw_degrees
	view.scale = Vector3.ONE * record.scale


func _world_position(local_position: Vector3) -> Vector3:
	var world_position := local_position
	if context != null and context.terrain != null:
		world_position.y = context.terrain.height_at(local_position) + local_position.y
	return world_position


func _add_selection_ring(view: Node3D) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.34
	mesh.outer_radius = 0.39
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.72, 0.22)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	ring.mesh = mesh
	ring.position.y = 0.04
	view.add_child(ring)


func _refresh_ghost() -> void:
	if _tool != TOOL_PLACE or _archetype_id == &"" or context.brush == null or not context.brush.has_hover:
		_hide_ghost()
		return
	var archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	if archetype == null:
		_hide_ghost()
		return
	if _ghost == null or _ghost_archetype_id != archetype.id:
		if _ghost != null:
			_ghost.queue_free()
		_ghost = _make_view(archetype.id)
		_ghost_archetype_id = archetype.id
		_root.add_child(_ghost)
		_apply_preview_look(_ghost)
	var cell := context.brush.hovered_cell
	_ghost.visible = true
	_ghost.position = _world_position(_surface_position(cell, archetype))
	_set_preview_colour(_ghost, Color(1.0, 0.78, 0.22, 0.72) if not _placement_warnings(cell, archetype).is_empty() else Color(0.35, 0.9, 1.0, 0.58))


func _hide_ghost() -> void:
	if _ghost != null:
		_ghost.visible = false


func _apply_preview_look(root: Node3D) -> void:
	for node: Node in [root] + root.find_children("*", "MeshInstance3D"):
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			for surface in mesh_node.get_surface_override_material_count():
				var material := mesh_node.get_active_material(surface)
				if material is StandardMaterial3D:
					mesh_node.set_surface_override_material(surface, (material as StandardMaterial3D).duplicate())


func _set_preview_colour(root: Node3D, colour: Color) -> void:
	for node: Node in [root] + root.find_children("*", "MeshInstance3D"):
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			for surface in mesh_node.get_surface_override_material_count():
				var material := mesh_node.get_active_material(surface)
				if material is StandardMaterial3D:
					var preview := material as StandardMaterial3D
					preview.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					preview.albedo_color = colour


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
		"Сущностей: %d · выделено: %d" % [context.document.entities.entities.size(), _selected_ids().size()],
	]
	var selected := context.document.entities.by_id(_selected_id)
	if selected != null:
		lines.append("id: %s" % selected.id)
		lines.append("архетип: %s" % selected.archetype_id)
		lines.append("клетка: %d, %d" % [selected.cell(context.terrain).x, selected.cell(context.terrain).y])
	for warning in _last_warnings:
		lines.append("⚠ %s" % warning)
	return lines


func inspector_properties() -> Array[EntityPropertyDef]:
	var selected := context.document.entities.by_id(_selected_id)
	if selected == null:
		return []
	var archetype := EntityArchetypeCatalog.get_archetype(selected.archetype_id)
	return archetype.property_schema if archetype != null else []


func inspector_values() -> Dictionary:
	var selected := context.document.entities.by_id(_selected_id)
	if selected == null:
		return {}
	var archetype := EntityArchetypeCatalog.get_archetype(selected.archetype_id)
	return archetype.resolved_properties(selected.props) if archetype != null else {}


func apply_inspector_value(property_name: StringName, value: Variant) -> bool:
	var primary := context.document.entities.by_id(_selected_id)
	if primary == null:
		return false
	var archetype := EntityArchetypeCatalog.get_archetype(primary.archetype_id)
	var definition := archetype.get_property(property_name) if archetype != null else null
	if definition == null:
		return false
	var next: Variant = definition.clamp_value(value)
	var before := context.document.entities.to_json()
	var changed := false
	for entity_id: StringName in _selected_ids():
		var record := context.document.entities.by_id(entity_id)
		if record == null or record.archetype_id != archetype.id:
			continue
		var values := archetype.resolved_properties(record.props)
		if values.get(property_name, null) == next:
			continue
		values[property_name] = next
		record.props = archetype.authored_differences(values)
		changed = true
	if changed:
		_commit(before, "свойство %s" % definition.label)
	return changed


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
