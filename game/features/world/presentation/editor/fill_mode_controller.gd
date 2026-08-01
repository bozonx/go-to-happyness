class_name FillModeController
extends MapEditorMode

## Режим наполнения карты: именованные записи сущностей.  Scatter, ссылки кликом
## и активация в runtime намеренно строятся поверх этого слоя записей, а не
## заводят второй вид размещаемого объекта.
##
## Управление — один контекстный жест ЛКМ, как в редакторе зданий: клик по
## пустому месту ставит выбранный в каталоге архетип, клик по объекту выделяет
## его.  Отдельных инструментов «выбрать»/«поставить» нет: они были невидимы в
## палитре (палитра занята каталогом) и переключались только по Tab, о котором
## автору никто не сообщал.  Раскладка совпадает с редактором зданий там, где
## действие то же самое (`map_fill_mode.md` §9.1).

const INSPECTOR_CELL := &"editor_cell"
const INSPECTOR_OFFSET := &"editor_offset"
const INSPECTOR_YAW := &"editor_yaw"
const INSPECTOR_SCALE := &"editor_scale"
const TRANSFORM_PROPERTIES: Array[StringName] = [INSPECTOR_CELL, INSPECTOR_OFFSET, INSPECTOR_YAW, INSPECTOR_SCALE]
## Действие «заменить выделенное на выбранный в палитре архетип».
const OPTION_REPLACE := &"fill_replace"

var _archetype_id: StringName = &""
## Полный образец кисти: пипетка забирает у объекта не только архетип, но и
## свойства, поворот, масштаб и смещение — поэтому отдельное дублирование не
## нужно (`map_fill_mode.md` §9.1).
var _brush_props: Dictionary = {}
var _brush_yaw_degrees := 0.0
var _brush_scale := 1.0
var _brush_offset := Vector3.ZERO
var _selected_id: StringName = &""
var _additional_selected: Array[StringName] = []
var _root: Node3D = null
var _views: Dictionary = {}
## Предупреждения политики размещения относятся к конкретной записи, а не к
## режиму: иначе жёлтая строка от одного камыша висела бы под инспектором всех
## последующих объектов.
var _warnings_by_entity: Dictionary = {}
var _ghost: Node3D = null
var _ghost_archetype_id: StringName = &""
var _ghost_material: StandardMaterial3D = null


func _init() -> void:
	id = &"fill"
	title = "Наполнение"
	icon = "🪣"


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
	_drop_stale_warnings()
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
		if key.ctrl_pressed:
			return false
		match key.keycode:
			KEY_DELETE:
				return _delete_selected()
			KEY_C, KEY_R:
				return _rotate_selection(-1 if key.shift_pressed else 1)
			KEY_X, KEY_Z:
				# Обе оси существуют в редакторе зданий, но запись карты хранит
				# только рыскание: врать автору поворотом, который некуда
				# положить, хуже, чем сказать это в статусе.
				context.set_status_message("На карте объект поворачивается только вокруг Y: C или R.", true)
				return true
			KEY_ESCAPE:
				return _cancel_current_action()
	return false


## Пипетка (Shift+ЛКМ и кнопка на панели): берёт архетип из-под курсора в кисть.
func pick_from_cell() -> bool:
	if context != null and context.brush != null and context.brush.has_hover:
		if not _pick_archetype(context.brush.hovered_cell):
			return false
		notify_ui_changed()
		return true
	return false


func _handle_mouse(event: InputEventMouseButton) -> bool:
	if not event.pressed or not context.brush.has_hover:
		return false
	var cell := context.brush.hovered_cell
	# Shift+ПКМ — обратное действие, как во всех режимах редактора карт
	# (`map_editor.md` §3.3); обычная ПКМ остаётся камере.
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if not event.shift_pressed:
			return false
		return _erase_at(cell)
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if event.shift_pressed:
		return pick_from_cell()
	var found := _entity_at(cell)
	if found != &"":
		_select(found, event.ctrl_pressed)
		rebuild_views()
		notify_ui_changed()
		return true
	if event.ctrl_pressed:
		return false
	if _archetype_id == &"":
		_select(&"", false)
		context.set_status_message("Выберите ассет в палитре или щёлкните по объекту.", true)
		rebuild_views()
		notify_ui_changed()
		return true
	_place(cell)
	return true


## Ctrl+ЛКМ добавляет и убирает объект из выделения.  Shift занят пипеткой —
## тем же жестом, что и в редакторе зданий, поэтому множественное выделение
## получает Ctrl в обоих редакторах.
func _select(entity_id: StringName, additive: bool) -> void:
	if not additive:
		_selected_id = entity_id
		_additional_selected.clear()
		return
	if entity_id == &"":
		return
	if _selected_id == &"":
		_selected_id = entity_id
	elif entity_id == _selected_id:
		_selected_id = _additional_selected.pop_front() if not _additional_selected.is_empty() else &""
	elif entity_id in _additional_selected:
		_additional_selected.erase(entity_id)
	else:
		_additional_selected.append(entity_id)


## Только те, что ещё существуют: документ могли заменить, а отмена — убрать
## запись, на которую выделение ссылалось. Инспектор, спрашивающий свойства
## исчезнувшей записи, — ошибка на каждый refresh панелей.
func _selected_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if context == null or context.document == null:
		return ids
	if _selected_id != &"" and context.document.entities.by_id(_selected_id) != null:
		ids.append(_selected_id)
	for entity_id: StringName in _additional_selected:
		if entity_id not in ids and context.document.entities.by_id(entity_id) != null:
			ids.append(entity_id)
	return ids


func _cancel_current_action() -> bool:
	if not _selected_ids().is_empty():
		_select(&"", false)
		rebuild_views()
		notify_ui_changed()
		context.set_status_message("Выделение снято.")
		return true
	if _archetype_id != &"":
		_archetype_id = &""
		_brush_props.clear()
		_brush_yaw_degrees = 0.0
		_brush_scale = 1.0
		_brush_offset = Vector3.ZERO
		_hide_ghost()
		notify_ui_changed()
		context.set_status_message("Кисть наполнения сброшена.")
		return true
	return false


## Сколько целых клеток занимает архетип с учётом масштаба и поворота.
func cell_span(archetype_id: StringName, scale: float = 1.0, yaw_deg: float = 0.0) -> Vector2i:
	var asset := EntityArchetypeCatalog.asset_of(archetype_id)
	var size := asset.placement_policy().footprint_cells if asset != null else Vector2i.ONE
	return EditorFillConventions.cell_span(size, scale, yaw_deg)


## Прямоугольник клеток, который занимает запись. Считается от якоря
## (`position - offset`): авторское смещение подстраивает модель внутри своих
## клеток и занятость не меняет.
func occupied_cells(record: MapEntityRecord) -> Rect2i:
	return Rect2i(record.cell(context.terrain), cell_span(record.archetype_id, record.scale, record.yaw_degrees))


## Клетки, которые займёт кисть, если поставить её от клетки `cell`.
func _brush_cells(cell: Vector2i) -> Rect2i:
	return Rect2i(cell, cell_span(_archetype_id, _brush_scale, _brush_yaw_degrees))


## Занятость по клеткам: две записи не делят клетку. Проверяется до постановки,
## а не по факту — иначе «занято» ничего не значит.
func _cells_free(cells: Rect2i, exclude_id: StringName = &"") -> bool:
	for record: MapEntityRecord in context.document.entities.entities:
		if record.id == exclude_id:
			continue
		if EditorFillConventions.rects_overlap(cells, occupied_cells(record)):
			return false
	return true


## Все клетки прямоугольника внутри доски и ни одна не попадает в вырез.
func _cells_placeable(cells: Rect2i) -> bool:
	for x in range(cells.position.x, cells.end.x):
		for z in range(cells.position.y, cells.end.y):
			var cell := Vector2i(x, z)
			if not context.terrain.is_inside(cell) or context.terrain.is_hole(cell):
				return false
	return true


## Якорь — центр занятого прямоугольника клеток, поднятый на свою поверхность.
## Для объекта 1×1 это центр клетки, как и раньше.
func _anchor_position(cells: Rect2i, archetype: EntityArchetype) -> Vector3:
	var centre := EditorFillConventions.anchor_of_cells(cells.position, cells.size, context.terrain.cell_size)
	var probe := _surface_position(cells.position, archetype)
	return Vector3(centre.x, probe.y, centre.y)


func _place(cell: Vector2i) -> void:
	var archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	if archetype == null:
		return
	var cells := _brush_cells(cell)
	if not _cells_placeable(cells):
		context.set_status_message("Здесь нельзя ставить: клетки вне карты или в вырезе.", true)
		return
	if not _cells_free(cells):
		context.set_status_message("Эти клетки уже заняты другим объектом.", true)
		return
	var before := context.document.entities.to_json()
	var record := MapEntityRecord.new()
	record.id = _next_id("entity")
	record.archetype_id = archetype.id
	record.offset = _brush_offset
	record.position = _anchor_position(cells, archetype) + _brush_offset
	record.initial_state = archetype.states.default_state
	record.activity = archetype.activity
	record.props = _brush_props.duplicate(true)
	record.yaw_degrees = _brush_yaw_degrees
	record.scale = _brush_scale
	_warnings_by_entity[record.id] = _placement_warnings(cell, archetype)
	context.document.entities.entities.append(record)
	_select(record.id, false)
	_commit(before, "размещение %s" % archetype.name)


func _erase_at(cell: Vector2i) -> bool:
	var entity_id := _entity_at(cell)
	if entity_id == &"":
		context.set_status_message("Под курсором нет объекта наполнения.", true)
		return true
	var before := context.document.entities.to_json()
	for index in range(context.document.entities.entities.size() - 1, -1, -1):
		if context.document.entities.entities[index].id == entity_id:
			context.document.entities.entities.remove_at(index)
			break
	_forget(entity_id)
	_commit(before, "удаление сущности")
	context.set_status_message("Объект удалён.")
	return true


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


func _forget(entity_id: StringName) -> void:
	_warnings_by_entity.erase(entity_id)
	if _selected_id == entity_id:
		_selected_id = &""
	_additional_selected.erase(entity_id)


## Отмена и правки из других режимов могут вернуть или убрать записи; держать
## предупреждения для исчезнувших id незачем.
func _drop_stale_warnings() -> void:
	if context == null or context.document == null:
		return
	for entity_id: Variant in _warnings_by_entity.keys():
		if context.document.entities.by_id(entity_id) == null:
			_warnings_by_entity.erase(entity_id)


func _pick_archetype(cell: Vector2i) -> bool:
	var entity_id := _entity_at(cell)
	var record := context.document.entities.by_id(entity_id)
	if record == null:
		context.set_status_message("Под курсором нет объекта для пипетки.", true)
		return false
	_archetype_id = record.archetype_id
	# Полный образец, а не только архетип: следующий клик поставит точно такой же
	# объект. Именно это делает отдельное «дублировать» ненужным.
	_brush_props = record.props.duplicate(true)
	_brush_yaw_degrees = record.yaw_degrees
	_brush_scale = record.scale
	_brush_offset = record.offset
	var archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	context.set_status_message("Пипетка: «%s» со всеми свойствами. Следующий клик поставит такой же." % (archetype.name if archetype != null else String(_archetype_id)))
	notify_ui_changed()
	return true


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
	for entity_id: StringName in selected:
		_forget(entity_id)
	_commit(before, "удаление сущности" if selected.size() == 1 else "удаление %d сущностей" % selected.size())
	return true


func _rotate_selection(direction: int) -> bool:
	var selected := _selected_ids()
	if selected.is_empty():
		return false
	var before := context.document.entities.to_json()
	for entity_id: StringName in selected:
		var record := context.document.entities.by_id(entity_id)
		if record != null:
			record.yaw_degrees = EditorFillConventions.rotated_by(record.yaw_degrees, direction)
	_commit(before, "поворот сущности")
	return true


func _next_id(prefix: String) -> StringName:
	var number := 1
	while context.document.entities.has_id(StringName("%s_%d" % [prefix, number])):
		number += 1
	return StringName("%s_%d" % [prefix, number])


func _commit(before: Array, command_label: String, merge_key: StringName = &"") -> void:
	var command := MapEntityCommand.of(context.document, before, context.document.entities.to_json(), command_label)
	context.history.push(command, merge_key)
	rebuild_views()
	notify_ui_changed()


## Presentation-only stand-ins until the chunked renderer and lazy asset nodes
## arrive in 2.4.  They make placement/selectability visible without making map
## data depend on nodes or requiring every archetype scene to be loaded now.
func rebuild_views() -> void:
	if _root == null:
		return
	for child in _root.get_children():
		# Призрак живёт в том же корне и не является видом записи: пересборка
		# видов не должна освобождать его — иначе следующий кадр обратится к
		# уже уничтоженному инстансу.
		if child == _ghost:
			continue
		child.queue_free()
	_views.clear()
	var selected := _selected_ids()
	for record: MapEntityRecord in context.document.entities.entities:
		var view := _make_view(record.archetype_id)
		_root.add_child(view)
		_apply_transform(view, record)
		if record.id in selected:
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
	var ring := EditorFillConventions.make_ring_marker(EditorFillConventions.COLOR_SELECTION)
	ring.position.y = 0.04
	view.add_child(ring)


func _refresh_ghost() -> void:
	if _archetype_id == &"" or context.brush == null or not context.brush.has_hover:
		_hide_ghost()
		return
	var archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	if archetype == null:
		_hide_ghost()
		return
	var cell := context.brush.hovered_cell
	# Наведение на существующий объект означает «клик выделит», а не «клик
	# поставит»: показывать призрак поверх него — врать о том, что произойдёт.
	if _entity_at(cell) != &"":
		_hide_ghost()
		return
	if not is_instance_valid(_ghost) or _ghost_archetype_id != archetype.id:
		if is_instance_valid(_ghost):
			_ghost.queue_free()
		_ghost = _make_view(archetype.id)
		_ghost_archetype_id = archetype.id
		_root.add_child(_ghost)
		EditorFillConventions.apply_preview_look(_ghost, _ghost_material_resource())
	_ghost.visible = true
	var cells := _brush_cells(cell)
	_ghost.position = _world_position(_anchor_position(cells, archetype) + _brush_offset)
	_ghost.rotation_degrees.y = _brush_yaw_degrees
	_ghost.scale = Vector3.ONE * _brush_scale
	var blocked := not _cells_placeable(cells) or not _cells_free(cells)
	var warned := not _placement_warnings(cell, archetype).is_empty()
	_ghost_material_resource().albedo_color = EditorFillConventions.COLOR_GHOST_BLOCKED if blocked \
		else (EditorFillConventions.COLOR_GHOST_WARNING if warned else EditorFillConventions.COLOR_GHOST_VALID)


func _hide_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.visible = false


func _ghost_material_resource() -> StandardMaterial3D:
	if _ghost_material == null:
		_ghost_material = EditorFillConventions.make_ghost_material()
	return _ghost_material


func use_catalog_panel() -> bool:
	return true


func catalog_scope() -> StringName:
	return WorldAssetDef.SCOPE_MAP


## Палитра занята каталогом ассетов; записи остаются для тестов и для случая,
## когда каталог недоступен.  Инструментов в списке нет намеренно: жест один.
func palette_entries() -> Array:
	var entries: Array = []
	for archetype: EntityArchetype in EntityArchetypeCatalog.all():
		var asset := EntityArchetypeCatalog.asset_of(archetype.id)
		if asset != null and asset.is_in_scope(WorldAssetDef.SCOPE_MAP):
			entries.append(PaletteEntry.of(archetype.id, archetype.name))
	return entries


func selected_palette_entry() -> StringName:
	return _archetype_id


## Замена существует вместо «удалить и поставить новый», потому что запись
## сохраняет свой **id**, а с ним — ссылки правил, квестов и сейвов на неё
## (`map_fill_mode.md` §8.3). Удаление рвёт их молча.
func tool_options() -> Array:
	var selected := _selected_ids()
	if selected.is_empty() or _archetype_id == &"":
		return []
	var archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	if archetype == null:
		return []
	var replaceable := 0
	for entity_id: StringName in selected:
		var record := context.document.entities.by_id(entity_id)
		if record != null and record.archetype_id != _archetype_id:
			replaceable += 1
	var label := "Заменить выделенное на «%s»" % archetype.name
	if selected.size() > 1:
		label = "Заменить %d объект(а) на «%s»" % [selected.size(), archetype.name]
	return [ToolOption.of(OPTION_REPLACE, label, &"", false, replaceable == 0)]


func activate_option(option_id: StringName) -> void:
	if option_id == OPTION_REPLACE:
		_replace_selection()


## Меняет архетип у всего выделения, сохраняя id, клетки и трансформ. Свойства,
## которых нет у нового архетипа, теряются — поэтому автора спрашивают заранее,
## а не сообщают post factum.
func _replace_selection() -> void:
	var archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	if archetype == null:
		return
	var targets: Array[MapEntityRecord] = []
	for entity_id: StringName in _selected_ids():
		var record := context.document.entities.by_id(entity_id)
		if record != null and record.archetype_id != archetype.id:
			targets.append(record)
	if targets.is_empty():
		context.set_status_message("Объекты уже используют этот архетип.")
		return
	var lost_total := 0
	for record: MapEntityRecord in targets:
		lost_total += _lost_property_count(record, archetype)
	if lost_total > 0:
		var question := "Замена на «%s» потеряет настроенных свойств: %d. Продолжить?" % [archetype.name, lost_total]
		if not await context.confirm_action(question, "Замена архетипа"):
			context.set_status_message("Замена отменена.")
			return
	var before := context.document.entities.to_json()
	for record: MapEntityRecord in targets:
		var kept: Dictionary = {}
		for key: Variant in record.props.keys():
			if archetype.get_property(StringName(key)) != null:
				kept[key] = record.props[key]
		record.archetype_id = archetype.id
		record.props = kept
		record.initial_state = archetype.states.default_state
		record.activity = archetype.activity
		# Новый архетип может занимать другое число клеток: пересаживаем запись на
		# её собственные клетки, чтобы занятость осталась честной.
		var cells := Rect2i(record.cell(context.terrain), cell_span(archetype.id, record.scale, record.yaw_degrees))
		record.position = _anchor_position(cells, archetype) + record.offset
		_warnings_by_entity[record.id] = _placement_warnings(cells.position, archetype)
	_commit(before, "замена архетипа")
	if lost_total > 0:
		context.set_status_message("Заменено объектов: %d. Потеряно свойств: %d." % [targets.size(), lost_total])
	else:
		context.set_status_message("Заменено объектов: %d." % targets.size())


func _lost_property_count(record: MapEntityRecord, archetype: EntityArchetype) -> int:
	var lost := 0
	for key: Variant in record.props.keys():
		if archetype.get_property(StringName(key)) == null:
			lost += 1
	return lost


func select_palette_entry(entry_id: StringName) -> void:
	if EntityArchetypeCatalog.has_archetype(entry_id):
		_archetype_id = entry_id
	else:
		var archetype := _resolve_archetype_for_asset(entry_id)
		if archetype == null:
			# Каталог показывает все ассеты области `map`, а поставить можно
			# только те, за которыми стоит архетип. Молчаливый отказ выглядел
			# как сломанная палитра.
			var asset := WorldAssetCatalog.get_asset(entry_id)
			var asset_name := asset.name if asset != null else String(entry_id)
			context.set_status_message("«%s» пока не описан архетипом и не может быть поставлен на карту." % asset_name, true)
			return
		_archetype_id = archetype.id
	notify_ui_changed()


func _resolve_archetype_for_asset(asset_id: StringName) -> EntityArchetype:
	for archetype: EntityArchetype in EntityArchetypeCatalog.all():
		if archetype.asset_id == asset_id or archetype.id == asset_id:
			return archetype
	return null


func inspector_lines() -> Array[String]:
	var selected := _selected_ids()
	if selected.size() > 1:
		var lines: Array[String] = [
			"Выбрано объектов: %d" % selected.size(),
			"Правятся общие поля: позиция (сдвигом), поворот, масштаб",
		]
		return lines
	var primary := context.document.entities.by_id(_selected_id)
	if primary != null:
		var archetype := EntityArchetypeCatalog.get_archetype(primary.archetype_id)
		var lines: Array[String] = [
			"Свойства: %s" % (archetype.name if archetype != null else String(primary.archetype_id)),
			"id: %s" % primary.id,
			"архетип: %s" % primary.archetype_id,
			"клетка: %d, %d" % [primary.cell(context.terrain).x, primary.cell(context.terrain).y],
		]
		var warnings: Array = _warnings_by_entity.get(primary.id, [])
		for warning: Variant in warnings:
			lines.append("⚠ %s" % String(warning))
		return lines

	var active_archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	if active_archetype != null:
		var asset := EntityArchetypeCatalog.asset_of(active_archetype.id)
		var lines: Array[String] = [
			"Кисть: %s" % active_archetype.name,
			"Категория: %s" % (WorldAssetCatalog.category_display_name(asset.category) if asset != null else active_archetype.category),
			"Сущностей на карте: %d" % context.document.entities.entities.size(),
		]
		if asset != null and not asset.description.is_empty():
			lines.append(asset.description)
		return lines

	return [
		"Сущностей на карте: %d" % context.document.entities.entities.size(),
		"Выберите ассет в палитре или объект на карте",
	]


## При множественном выделении показываются только поля, осмысленные для всех
## сразу.  Уникальные свойства архетипа правятся по одному объекту: инспектор,
## показывающий значение первого и пишущий во все, — это тихая порча данных.
func inspector_properties() -> Array[EntityPropertyDef]:
	var selected := _selected_ids()
	if not selected.is_empty():
		# Автор оперирует клеткой и смещением внутри неё — теми же полями, что и в
		# редакторе зданий. Мировая позиция производна и в полях не участвует.
		var cell_property := EntityPropertyDef.from_dict({
			"name": INSPECTOR_CELL, "label": "Клетка" if selected.size() == 1 else "Сдвиг по клеткам",
			"type": "vector2", "section": "transform", "step": 1.0})
		var offset_property := EntityPropertyDef.from_dict({
			"name": INSPECTOR_OFFSET, "label": "Смещение", "type": "vector3", "section": "transform",
			"unit": "м", "step": EditorFillConventions.OFFSET_STEP,
			"min": -EditorFillConventions.MAX_OFFSET_CELLS, "max": EditorFillConventions.MAX_OFFSET_CELLS,
			"default": [0.0, 0.0, 0.0]})
		var properties: Array[EntityPropertyDef] = [
			cell_property,
			offset_property,
			EntityPropertyDef.from_dict({"name": INSPECTOR_YAW, "label": "Поворот Y", "type": "float", "section": "transform", "unit": "°", "min": 0.0, "max": 359.0, "step": EditorFillConventions.ROTATION_STEP_DEG, "default": 0.0}),
			EntityPropertyDef.from_dict({"name": INSPECTOR_SCALE, "label": "Масштаб", "type": "float", "section": "transform", "min": EditorFillConventions.SCALE_MIN, "max": EditorFillConventions.SCALE_MAX, "step": EditorFillConventions.SCALE_STEP, "default": 1.0}),
		]
		if selected.size() > 1:
			return properties
		var primary := context.document.entities.by_id(selected[0])
		var archetype := EntityArchetypeCatalog.get_archetype(primary.archetype_id) if primary != null else null
		if archetype != null:
			properties.append_array(archetype.property_schema)
		return properties

	var active_archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	if active_archetype != null:
		return active_archetype.property_schema
	return []


func inspector_values() -> Dictionary:
	var selected := context.document.entities.by_id(_selected_id)
	if selected != null:
		var archetype := EntityArchetypeCatalog.get_archetype(selected.archetype_id)
		var values := archetype.resolved_properties(selected.props) if archetype != null else {}
		var cell := selected.cell(context.terrain)
		values[INSPECTOR_CELL] = Vector2(cell.x, cell.y)
		values[INSPECTOR_OFFSET] = selected.offset
		values[INSPECTOR_YAW] = selected.yaw_degrees
		values[INSPECTOR_SCALE] = selected.scale
		return values

	var active_archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	if active_archetype != null:
		return active_archetype.default_values()
	return {}


func apply_inspector_value(property_name: StringName, value: Variant) -> bool:
	return _apply_value(property_name, value, true)


## `mergeable` отделяет непрерывную правку поля от разового действия: сброс к
## значению по умолчанию — отдельный шаг отмены, даже если он пришёл сразу после
## ввода в то же поле.
func _apply_value(property_name: StringName, value: Variant, mergeable: bool) -> bool:
	var primary := context.document.entities.by_id(_selected_id)
	if primary == null:
		return false
	if property_name in TRANSFORM_PROPERTIES:
		return _apply_transform_value(primary, property_name, value, mergeable)
	if _selected_ids().size() > 1:
		return false
	var archetype := EntityArchetypeCatalog.get_archetype(primary.archetype_id)
	var definition := archetype.get_property(property_name) if archetype != null else null
	if definition == null:
		return false
	var next: Variant = definition.clamp_value(value)
	var values := archetype.resolved_properties(primary.props)
	if values.get(property_name, null) == next:
		return false
	var before := context.document.entities.to_json()
	values[property_name] = next
	primary.props = archetype.authored_differences(values)
	var merge_key := StringName("%s/%s" % [primary.id, property_name]) if mergeable else &""
	_commit(before, "свойство %s" % definition.label, merge_key)
	return true


func reset_inspector_value(property_name: StringName) -> bool:
	var primary := context.document.entities.by_id(_selected_id)
	if primary == null:
		return false
	if property_name == INSPECTOR_YAW:
		return _apply_transform_value(primary, property_name, 0.0, false)
	if property_name == INSPECTOR_SCALE:
		return _apply_transform_value(primary, property_name, 1.0, false)
	if property_name == INSPECTOR_OFFSET:
		# Сброс смещения ставит объект ровно по своим клеткам; сами клетки не
		# двигаются — «нулевой клетки» не существует.
		return _apply_transform_value(primary, property_name, [0.0, 0.0, 0.0], false)
	if property_name == INSPECTOR_CELL:
		return false
	var archetype := EntityArchetypeCatalog.get_archetype(primary.archetype_id)
	var definition := archetype.get_property(property_name) if archetype != null else null
	return _apply_value(property_name, definition.default, false) if definition != null else false


## Клетка применяется сдвигом: одинаковые абсолютные координаты сложили бы всё
## выделение в одну клетку. Смещение, поворот и масштаб — абсолютом: поле
## говорит именно это.
func _apply_transform_value(record: MapEntityRecord, property_name: StringName, value: Variant, mergeable: bool = true) -> bool:
	var selected := _selected_ids()
	var before := context.document.entities.to_json()
	var changed := false
	if property_name == INSPECTOR_CELL:
		var requested := EntityPropertyDef.from_dict({"name": "cell", "type": "vector2"}).coerce_value(value) as Vector2
		var target_cell := Vector2i(int(round(requested.x)), int(round(requested.y)))
		var shift := target_cell - record.cell(context.terrain)
		if shift == Vector2i.ZERO:
			return false
		# Сначала проверяем всё выделение, потом двигаем: половина переехавших
		# объектов хуже, чем отказ.
		for entity_id: StringName in selected:
			var target := context.document.entities.by_id(entity_id)
			if target == null:
				continue
			var cells := Rect2i(target.cell(context.terrain) + shift, occupied_cells(target).size)
			if not _cells_placeable(cells):
				context.set_status_message("Клетки вне карты или попадают в вырез.", true)
				return false
			if not _cells_free(cells, target.id) or not _selection_free_of(cells, selected, target.id, shift):
				context.set_status_message("Эти клетки уже заняты другим объектом.", true)
				return false
		for entity_id: StringName in selected:
			var target := context.document.entities.by_id(entity_id)
			if target == null:
				continue
			var archetype := EntityArchetypeCatalog.get_archetype(target.archetype_id)
			if archetype == null:
				continue
			var cells := Rect2i(target.cell(context.terrain) + shift, occupied_cells(target).size)
			target.position = _anchor_position(cells, archetype) + target.offset
			changed = true
	elif property_name == INSPECTOR_OFFSET:
		var raw := EntityPropertyDef.from_dict({"name": "offset", "type": "vector3"}).coerce_value(value) as Vector3
		var offset := EditorFillConventions.clamp_offset(raw, context.terrain.cell_size)
		for entity_id: StringName in selected:
			var target := context.document.entities.by_id(entity_id)
			if target == null or target.offset.is_equal_approx(offset):
				continue
			target.position = target.anchor_position() + offset
			target.offset = offset
			changed = true
	elif property_name == INSPECTOR_YAW:
		var yaw := fposmod(float(value), 360.0)
		for entity_id: StringName in selected:
			var target := context.document.entities.by_id(entity_id)
			if target != null and not is_equal_approx(target.yaw_degrees, yaw):
				target.yaw_degrees = yaw
				changed = true
	else:
		var next_scale := clampf(float(value), EditorFillConventions.SCALE_MIN, EditorFillConventions.SCALE_MAX)
		for entity_id: StringName in selected:
			var target := context.document.entities.by_id(entity_id)
			if target != null and not is_equal_approx(target.scale, next_scale):
				target.scale = next_scale
				changed = true
	if not changed:
		return false
	var merge_key := StringName("%s/%s" % [record.id, property_name]) if mergeable else &""
	_commit(before, "трансформ сущности", merge_key)
	return true


## Не наедет ли сдвинутое выделение на другого своего же участника.
func _selection_free_of(cells: Rect2i, selected: Array[StringName], self_id: StringName, shift: Vector2i) -> bool:
	for entity_id: StringName in selected:
		if entity_id == self_id:
			continue
		var other := context.document.entities.by_id(entity_id)
		if other == null:
			continue
		var moved := Rect2i(other.cell(context.terrain) + shift, occupied_cells(other).size)
		if EditorFillConventions.rects_overlap(cells, moved):
			return false
	return true


func list_title() -> String:
	return "Сущности карты"


func list_entries() -> Array[String]:
	var entries: Array[String] = []
	for record: MapEntityRecord in context.document.entities.entities:
		var archetype := EntityArchetypeCatalog.get_archetype(record.archetype_id)
		var label := archetype.name if archetype != null else String(record.archetype_id)
		var cell := record.cell(context.terrain)
		entries.append("● %s  ·  %d, %d  ·  %s" % [label, cell.x, cell.y, record.id])
	return entries


func selected_list_index() -> int:
	for index in context.document.entities.entities.size():
		if context.document.entities.entities[index].id == _selected_id:
			return index
	return -1


func select_list_entry(index: int) -> void:
	if index < 0 or index >= context.document.entities.entities.size():
		return
	_select(context.document.entities.entities[index].id, false)
	rebuild_views()
	notify_ui_changed()


func empty_list_hint() -> String:
	return "Выберите архетип и поставьте его на карту"


func status_text() -> String:
	if context.brush == null or not context.brush.has_hover:
		return "Наполнение: выберите ассет в палитре"
	var cell := context.brush.hovered_cell
	var action := "поставить" if _archetype_id != &"" and _entity_at(cell) == &"" else "выбрать"
	return "клетка %d,%d · ЛКМ — %s · Shift+ЛКМ — пипетка · Shift+ПКМ — удалить" % [cell.x, cell.y, action]
