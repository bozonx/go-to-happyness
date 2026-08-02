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
const INSPECTOR_CELL_X := &"editor_cell_x"
const INSPECTOR_CELL_Z := &"editor_cell_z"
const INSPECTOR_ELEVATION := &"editor_elevation"
const INSPECTOR_OFFSET := &"editor_offset"
const INSPECTOR_PITCH := &"editor_pitch"
const INSPECTOR_YAW := &"editor_yaw"
const INSPECTOR_ROLL := &"editor_roll"
const INSPECTOR_SCALE := &"editor_scale"
const INSPECTOR_INITIAL_STATE := &"editor_initial_state"
const TRANSFORM_PROPERTIES: Array[StringName] = [INSPECTOR_CELL, INSPECTOR_CELL_X, INSPECTOR_CELL_Z, INSPECTOR_ELEVATION, INSPECTOR_OFFSET, INSPECTOR_PITCH, INSPECTOR_YAW, INSPECTOR_ROLL, INSPECTOR_SCALE]
## Действие «заменить выделенное на выбранный в палитре архетип».
const OPTION_REPLACE := &"fill_replace"

var _archetype_id: StringName = &""
## Полный образец кисти: пипетка забирает у объекта не только архетип, но и
## свойства, поворот, масштаб и смещение — поэтому отдельное дублирование не
## нужно (`map_fill_mode.md` §9.1).
var _brush_props: Dictionary = {}
var _brush_initial_state: StringName = EntityStateSet.FOLLOW_SEASON
var _brush_yaw_degrees := 0.0
var _brush_pitch_degrees := 0.0
var _brush_roll_degrees := 0.0
var _brush_elevation_blocks := 0
var _brush_scale := 1.0
var _brush_offset := Vector3.ZERO
var _pending_reference_property: StringName = &""
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
var _placing_stroke := false
var _last_placed_cell := Vector2i(-999999, -999999)
var _placement_stroke_serial := 0
var _placement_merge_key: StringName = &""
var _dragging_selection := false
var _drag_anchor_cell := Vector2i.ZERO


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
	# Fill has its own asset ghost. The generic terrain brush marker would draw a
	# second cursor-attached shape on top of it.
	return null


func process(_delta: float) -> void:
	context.brush.update_hover(context.camera, context.space_state(), context.mouse_position())
	_refresh_ghost()


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _handle_mouse(event as InputEventMouseButton)
	if event is InputEventMouseMotion:
		return _continue_placement_stroke()
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key := event as InputEventKey
		if key.ctrl_pressed:
			return false
		match key.keycode:
			KEY_DELETE:
				return _delete_selected()
			KEY_C, KEY_R:
				return _rotate_selection("y", -1 if key.shift_pressed else 1)
			KEY_X:
				return _rotate_selection("x", -1 if key.shift_pressed else 1)
			KEY_Z:
				return _rotate_selection("z", -1 if key.shift_pressed else 1)
			KEY_ESCAPE:
				if _pending_reference_property != &"":
					_pending_reference_property = &""
					context.set_status_message("Выбор ссылки отменён.")
					return true
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
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var consumed := _placing_stroke or _dragging_selection
		_placing_stroke = false
		_dragging_selection = false
		return consumed
	if not event.pressed or not context.brush.has_hover:
		return false
	_placing_stroke = false
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
	if _pending_reference_property != &"":
		var reference_target := _entity_at(cell)
		if reference_target == &"":
			context.set_status_message("Для ссылки щёлкните по объекту наполнения.", true)
			return true
		var property_name := _pending_reference_property
		_pending_reference_property = &""
		if _apply_value(property_name, String(reference_target), false):
			context.set_status_message("Ссылка установлена на %s." % reference_target)
		return true
	var found := _entity_at(cell)
	if found != &"":
		_select(found, event.ctrl_pressed)
		_dragging_selection = not event.ctrl_pressed
		_drag_anchor_cell = cell
		rebuild_views()
		_report_selected_warnings()
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
	_placement_stroke_serial += 1
	_placement_merge_key = StringName("fill_stroke/%d" % _placement_stroke_serial)
	_place(cell, _placement_merge_key)
	_placing_stroke = true
	_last_placed_cell = cell
	return true


func _continue_placement_stroke() -> bool:
	if _dragging_selection:
		return _drag_selection_to(context.brush.hovered_cell) if context.brush.has_hover else false
	if not _placing_stroke or not context.brush.has_hover or _archetype_id == &"":
		return false
	var cell := context.brush.hovered_cell
	if cell == _last_placed_cell:
		return true
	# Fill every crossed cell so fast mouse movement cannot leave a dotted trail.
	var delta := cell - _last_placed_cell
	var steps := maxi(absi(delta.x), absi(delta.y))
	for index in range(1, steps + 1):
		var sample := Vector2i(roundi(lerpf(_last_placed_cell.x, cell.x, float(index) / steps)), roundi(lerpf(_last_placed_cell.y, cell.y, float(index) / steps)))
		if _entity_at(sample) == &"":
			_place(sample, _placement_merge_key)
	_last_placed_cell = cell
	return true


func _drag_selection_to(target_cell: Vector2i) -> bool:
	var primary := context.document.entities.by_id(_selected_id)
	if primary == null:
		return false
	var shift := target_cell - _drag_anchor_cell
	if shift == Vector2i.ZERO:
		return true
	var selected := _selected_ids()
	var before := context.document.entities.to_json()
	var proposed: Dictionary = {}
	for entity_id: StringName in selected:
		var record := context.document.entities.by_id(entity_id)
		if record == null:
			continue
		var cells := Rect2i(_base_cell(record) + shift, cell_span(record.archetype_id, record.scale, record.yaw_degrees))
		if not _cells_placeable(cells) or not _cells_free_ignoring(cells, selected, record.archetype_id):
			context.set_status_message("Перенос невозможен: клетки заняты, вне карты или в вырезе.", true)
			return true
		proposed[entity_id] = cells
	if not _proposed_selection_is_free(proposed):
		context.set_status_message("Перенос невозможен: объекты выделения пересекутся.", true)
		return true
	for entity_id: StringName in proposed:
		var record := context.document.entities.by_id(entity_id)
		var archetype := EntityArchetypeCatalog.get_archetype(record.archetype_id) if record != null else null
		if record != null and archetype != null:
			record.position = _anchor_position(proposed[entity_id], archetype) + Vector3.UP * record.elevation_blocks + record.offset
	_drag_anchor_cell = target_cell
	_commit(before, "перенос сущности", StringName("fill_drag/%s" % primary.id))
	return true


## Ctrl+ЛКМ добавляет и убирает объект из выделения.  Shift занят пипеткой —
## тем же жестом, что и в редакторе зданий, поэтому множественное выделение
## получает Ctrl в обоих редакторах.
func _select(entity_id: StringName, additive: bool) -> void:
	if not additive:
		_selected_id = entity_id
		_additional_selected.clear()
		if entity_id == &"":
			_dragging_selection = false
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
		_brush_pitch_degrees = 0.0
		_brush_roll_degrees = 0.0
		_brush_elevation_blocks = 0
		_brush_scale = 1.0
		_brush_offset = Vector3.ZERO
		_brush_initial_state = EntityStateSet.FOLLOW_SEASON
		_hide_ghost()
		notify_ui_changed()
		context.set_status_message("Кисть наполнения сброшена.")
		return true
	return false


## Сколько целых клеток занимает архетип с учётом масштаба и поворота.
func cell_span(archetype_id: StringName, scale: float = 1.0, yaw_deg: float = 0.0) -> Vector2i:
	var asset := EntityArchetypeCatalog.asset_of(archetype_id)
	return asset.placement_cell_span(scale, yaw_deg) if asset != null else Vector2i.ONE


## Прямоугольник клеток, который занимает запись. Считается от якоря
## (`position - offset`): авторское смещение подстраивает модель внутри своих
## клеток и занятость не меняет.
func occupied_cells(record: MapEntityRecord) -> Rect2i:
	var span := cell_span(record.archetype_id, record.scale, record.yaw_degrees)
	return Rect2i(_base_cell(record, span), span)


func _base_cell(record: MapEntityRecord, span: Vector2i = Vector2i.ZERO) -> Vector2i:
	if span == Vector2i.ZERO:
		span = cell_span(record.archetype_id, record.scale, record.yaw_degrees)
	var anchor := record.anchor_position()
	return EditorFillConventions.base_cell_at(anchor.x, anchor.z, span, context.terrain.cell_size)


## Клетки, которые займёт кисть, если поставить её от клетки `cell`.
func _brush_cells(cell: Vector2i) -> Rect2i:
	return Rect2i(cell, cell_span(_archetype_id, _brush_scale, _brush_yaw_degrees))


## Занятость по клеткам: две записи не делят клетку. Проверяется до постановки,
## а не по факту — иначе «занято» ничего не значит.
func _cells_free(
	cells: Rect2i,
	exclude_id: StringName = &"",
	candidate_archetype_id: StringName = _archetype_id,
) -> bool:
	return _cells_free_ignoring(cells, [exclude_id] if exclude_id != &"" else [], candidate_archetype_id)


func _cells_free_ignoring(
	cells: Rect2i,
	ignored_ids: Array,
	candidate_archetype_id: StringName,
) -> bool:
	var candidate_asset := EntityArchetypeCatalog.asset_of(candidate_archetype_id)
	if not EditorFillConventions.asset_claims_cells(candidate_asset):
		return true
	for record: MapEntityRecord in context.document.entities.entities:
		if record.id in ignored_ids:
			continue
		if not EditorFillConventions.asset_claims_cells(EntityArchetypeCatalog.asset_of(record.archetype_id)):
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


func _place(cell: Vector2i, merge_key: StringName = &"") -> void:
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
	record.elevation_blocks = _brush_elevation_blocks
	record.position = _anchor_position(cells, archetype) + Vector3.UP * record.elevation_blocks + _brush_offset
	record.initial_state = _brush_initial_state
	record.activity = archetype.activity
	record.props = _brush_props.duplicate(true)
	record.yaw_degrees = _brush_yaw_degrees
	record.pitch_degrees = _brush_pitch_degrees
	record.roll_degrees = _brush_roll_degrees
	record.scale = _brush_scale
	_warnings_by_entity[record.id] = _placement_warnings_for_cells(cells, archetype)
	context.document.entities.entities.append(record)
	_select(record.id, false)
	_report_selected_warnings()
	_commit(before, "размещение %s" % archetype.name, merge_key)


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
	if not context.water.is_wet(context.terrain, cell):
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
	var submerged := context.water.is_wet(context.terrain, cell) and context.water.depth_steps_at(context.terrain, cell) > 0
	return asset.placement_policy().warnings_for({
		"surface": _surface_kind(cell),
		"slope_class": context.terrain.slope_class_at(cell),
		"submerged": submerged,
	})


func _placement_warnings_for_cells(cells: Rect2i, archetype: EntityArchetype) -> Array[String]:
	var warnings: Array[String] = []
	for x in range(cells.position.x, cells.end.x):
		for z in range(cells.position.y, cells.end.y):
			for warning: String in _placement_warnings(Vector2i(x, z), archetype):
				if warning not in warnings:
					warnings.append(warning)
	return warnings


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


func _report_selected_warnings() -> void:
	var primary := context.document.entities.by_id(_selected_id)
	if primary == null:
		return
	var warnings: Array = _warnings_by_entity.get(primary.id, [])
	if not warnings.is_empty():
		context.set_status_message("Предупреждение размещения: %s" % "; ".join(warnings), true)


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
	_brush_pitch_degrees = record.pitch_degrees
	_brush_roll_degrees = record.roll_degrees
	_brush_elevation_blocks = record.elevation_blocks
	_brush_scale = record.scale
	_brush_offset = record.offset
	_brush_initial_state = record.initial_state
	var archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	context.set_status_message("Пипетка: «%s» со всеми свойствами. Следующий клик поставит такой же." % (archetype.name if archetype != null else String(_archetype_id)))
	notify_ui_changed()
	return true


func _entity_at(cell: Vector2i) -> StringName:
	for index in range(context.document.entities.entities.size() - 1, -1, -1):
		var record: MapEntityRecord = context.document.entities.entities[index]
		if occupied_cells(record).has_point(cell):
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


func _rotate_selection(axis: String, direction: int) -> bool:
	var selected := _selected_ids()
	if selected.is_empty():
		if EntityArchetypeCatalog.asset_of(_archetype_id) == null:
			return false
		match axis:
			"x": _brush_pitch_degrees = EditorFillConventions.rotated_by(_brush_pitch_degrees, direction)
			"y": _brush_yaw_degrees = EditorFillConventions.rotated_by(_brush_yaw_degrees, direction)
			"z": _brush_roll_degrees = EditorFillConventions.rotated_by(_brush_roll_degrees, direction)
		notify_ui_changed()
		_refresh_ghost()
		return true
	var proposed_cells: Dictionary = {}
	var proposed_rotations: Dictionary = {}
	for entity_id: StringName in selected:
		var record := context.document.entities.by_id(entity_id)
		if record == null:
			continue
		var rotation := Vector3(record.pitch_degrees, record.yaw_degrees, record.roll_degrees)
		match axis:
			"x": rotation.x = EditorFillConventions.rotated_by(rotation.x, direction)
			"y": rotation.y = EditorFillConventions.rotated_by(rotation.y, direction)
			"z": rotation.z = EditorFillConventions.rotated_by(rotation.z, direction)
		var cells := Rect2i(_base_cell(record), cell_span(record.archetype_id, record.scale, rotation.y))
		if not _cells_placeable(cells) or not _cells_free_ignoring(cells, selected, record.archetype_id):
			context.set_status_message("Поворот не применён: итоговые клетки заняты или вне карты.", true)
			return true
		proposed_cells[entity_id] = cells
		proposed_rotations[entity_id] = rotation
	if not _proposed_selection_is_free(proposed_cells):
		context.set_status_message("Поворот не применён: выбранные объекты пересекутся.", true)
		return true
	var before := context.document.entities.to_json()
	for entity_id: StringName in selected:
		var record := context.document.entities.by_id(entity_id)
		var archetype := EntityArchetypeCatalog.get_archetype(record.archetype_id) if record != null else null
		if record == null or archetype == null:
			continue
		var rotation: Vector3 = proposed_rotations[entity_id]
		record.pitch_degrees = rotation.x
		record.yaw_degrees = rotation.y
		record.roll_degrees = rotation.z
		record.position = _anchor_position(proposed_cells[entity_id], archetype) + Vector3.UP * record.elevation_blocks + record.offset
	_commit(before, "поворот %d объект(а)" % selected.size())
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
	_warnings_by_entity.clear()
	var selected := _selected_ids()
	for record: MapEntityRecord in context.document.entities.entities:
		var archetype := EntityArchetypeCatalog.get_archetype(record.archetype_id)
		if archetype != null:
			_warnings_by_entity[record.id] = _placement_warnings_for_cells(occupied_cells(record), archetype)
		var view := _make_view(record.archetype_id)
		_root.add_child(view)
		_apply_record_appearance(view, record)
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
	view.rotation_degrees = Vector3(record.pitch_degrees, record.yaw_degrees, record.roll_degrees)
	view.scale = Vector3.ONE * record.scale


func _apply_record_appearance(view: Node3D, record: MapEntityRecord) -> void:
	var archetype := EntityArchetypeCatalog.get_archetype(record.archetype_id)
	var asset := EntityArchetypeCatalog.asset_of(record.archetype_id)
	if archetype != null and view.has_method("apply_entity_props"):
		view.call("apply_entity_props", archetype.resolved_properties(record.props))
	if archetype == null or asset == null or not view.has_method("apply_decor_properties"):
		return
	var appearance := asset.default_appearance()
	var state := archetype.states.get_state(record.initial_state)
	if state != null and state.visual_kind == EntityStateDef.VISUAL_VARIANT:
		appearance.merge(asset.state_appearance(state.visual_value), true)
	view.call("apply_decor_properties", appearance)
	# DecorObjectController applies asset defaults in `_ready`; repeat after the
	# node enters the tree so the authored initial state remains visible.
	view.call_deferred("apply_decor_properties", appearance)


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
	if _ghost.has_method("apply_entity_props"):
		_ghost.call("apply_entity_props", archetype.resolved_properties(_brush_props))
	if _ghost.has_method("apply_decor_properties"):
		var asset := EntityArchetypeCatalog.asset_of(archetype.id)
		if asset != null:
			var appearance := asset.default_appearance()
			var state := archetype.states.get_state(_brush_initial_state)
			if state != null and state.visual_kind == EntityStateDef.VISUAL_VARIANT:
				appearance.merge(asset.state_appearance(state.visual_value), true)
			_ghost.call("apply_decor_properties", appearance)
	_ghost.visible = true
	var cells := _brush_cells(cell)
	_ghost.position = _world_position(_anchor_position(cells, archetype) + Vector3.UP * _brush_elevation_blocks + _brush_offset)
	_ghost.rotation_degrees = Vector3(_brush_pitch_degrees, _brush_yaw_degrees, _brush_roll_degrees)
	_ghost.scale = Vector3.ONE * _brush_scale
	var blocked := not _cells_placeable(cells) or not _cells_free(cells)
	var warned := not _placement_warnings_for_cells(cells, archetype).is_empty()
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


func catalog_asset_enabled(asset_id: StringName) -> bool:
	return _resolve_archetype_for_asset(asset_id) != null


func catalog_asset_unavailable_reason(_asset_id: StringName) -> String:
	return "Для размещения на карте ассету нужен EntityArchetype."


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
	if _archetype_id == &"":
		return []
	var archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	if archetype == null:
		return []
	var options: Array = []
	if selected.is_empty():
		return options
	var replaceable := 0
	for entity_id: StringName in selected:
		var record := context.document.entities.by_id(entity_id)
		if record != null and record.archetype_id != _archetype_id:
			replaceable += 1
	var label := "Заменить выделенное на «%s»" % archetype.name
	if selected.size() > 1:
		label = "Заменить %d объект(а) на «%s»" % [selected.size(), archetype.name]
	options.append(ToolOption.of(OPTION_REPLACE, label, &"", false, replaceable == 0))
	return options


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
	var selected: Array[StringName] = []
	for target: MapEntityRecord in targets:
		selected.append(target.id)
	var proposed_cells: Dictionary = {}
	var proposed_scale: Dictionary = {}
	for record: MapEntityRecord in targets:
		var scale := EditorFillConventions.normalized_scale(
			EntityArchetypeCatalog.asset_of(archetype.id), record.scale)
		var cells := Rect2i(
			_base_cell(record), cell_span(archetype.id, scale, record.yaw_degrees))
		if not _cells_placeable(cells) or not _cells_free_ignoring(cells, selected, archetype.id):
			context.set_status_message("Замена не применена: новому ассету не хватает свободных клеток.", true)
			return
		proposed_cells[record.id] = cells
		proposed_scale[record.id] = scale
	# `_proposed_selection_is_free` reads current archetypes, while replacement
	# gives every target the same new one; compare the proposed rectangles here.
	if EditorFillConventions.asset_claims_cells(EntityArchetypeCatalog.asset_of(archetype.id)):
		var ids := proposed_cells.keys()
		for left_index in ids.size():
			for right_index in range(left_index + 1, ids.size()):
				if EditorFillConventions.rects_overlap(
						proposed_cells[ids[left_index]], proposed_cells[ids[right_index]]):
					context.set_status_message("Замена не применена: новые размеры объектов пересекутся.", true)
					return
	var before := context.document.entities.to_json()
	for record: MapEntityRecord in targets:
		var kept: Dictionary = {}
		for key: Variant in record.props.keys():
			if archetype.get_property(StringName(key)) != null:
				kept[key] = record.props[key]
		record.archetype_id = archetype.id
		record.props = kept
		record.initial_state = EntityStateSet.FOLLOW_SEASON
		record.activity = archetype.activity
		record.scale = proposed_scale[record.id]
		# Новый архетип может занимать другое число клеток: пересаживаем запись на
		# её собственные клетки, чтобы занятость осталась честной.
		var cells: Rect2i = proposed_cells[record.id]
		record.position = _anchor_position(cells, archetype) + record.offset
		_warnings_by_entity[record.id] = _placement_warnings_for_cells(cells, archetype)
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
	var previous := _archetype_id
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
	if _archetype_id != previous:
		_brush_props.clear()
		_brush_initial_state = EntityStateSet.FOLLOW_SEASON
		_brush_yaw_degrees = 0.0
		_brush_scale = EditorFillConventions.normalized_scale(
			EntityArchetypeCatalog.asset_of(_archetype_id), 1.0)
		_brush_offset = Vector3.ZERO
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
		return [
			"Свойства: %s" % (archetype.name if archetype != null else String(primary.archetype_id)),
			"id: %s" % primary.id,
			"архетип: %s" % primary.archetype_id,
		]

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
		var base_cell := _base_cell(context.document.entities.by_id(selected[0])) if selected.size() == 1 else Vector2i.ZERO
		var offset_property := EntityPropertyDef.from_dict({
			"name": INSPECTOR_OFFSET, "label": "Смещение", "type": "vector3", "section": "transform",
			"unit": "м", "step": EditorFillConventions.OFFSET_STEP,
			"min": -EditorFillConventions.MAX_OFFSET_CELLS, "max": EditorFillConventions.MAX_OFFSET_CELLS,
			"default": [0.0, 0.0, 0.0]})
		var properties: Array[EntityPropertyDef] = [
			EntityPropertyDef.from_dict({"name": INSPECTOR_CELL_X, "label": "Клетка X" if selected.size() == 1 else "Сдвиг X", "type": "int", "section": "transform", "step": 1.0, "default": base_cell.x}),
			EntityPropertyDef.from_dict({"name": INSPECTOR_CELL_Z, "label": "Клетка Z" if selected.size() == 1 else "Сдвиг Z", "type": "int", "section": "transform", "step": 1.0, "default": base_cell.y}),
			EntityPropertyDef.from_dict({"name": INSPECTOR_ELEVATION, "label": "Уровень Y", "type": "int", "section": "transform", "unit": "блок", "step": 1.0, "default": 0}),
			offset_property,
			EntityPropertyDef.from_dict({"name": INSPECTOR_PITCH, "label": "Поворот X", "type": "float", "section": "transform", "unit": "°", "min": 0.0, "max": 359.0, "step": EditorFillConventions.ROTATION_STEP_DEG, "default": 0.0}),
			EntityPropertyDef.from_dict({"name": INSPECTOR_YAW, "label": "Поворот Y", "type": "float", "section": "transform", "unit": "°", "min": 0.0, "max": 359.0, "step": EditorFillConventions.ROTATION_STEP_DEG, "default": 0.0}),
			EntityPropertyDef.from_dict({"name": INSPECTOR_ROLL, "label": "Поворот Z", "type": "float", "section": "transform", "unit": "°", "min": 0.0, "max": 359.0, "step": EditorFillConventions.ROTATION_STEP_DEG, "default": 0.0}),
			EntityPropertyDef.from_dict({"name": INSPECTOR_SCALE, "label": "Масштаб", "type": "float", "section": "transform", "min": EditorFillConventions.SCALE_MIN, "max": EditorFillConventions.SCALE_MAX, "step": EditorFillConventions.SCALE_STEP, "default": 1.0}),
		]
		if selected.size() > 1:
			return properties
		var primary := context.document.entities.by_id(selected[0])
		var archetype := EntityArchetypeCatalog.get_archetype(primary.archetype_id) if primary != null else null
		if archetype != null:
			properties.append(_initial_state_property(archetype))
			properties.append_array(archetype.property_schema)
		return properties

	var active_archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	if active_archetype != null:
		var brush_properties: Array[EntityPropertyDef] = [
			EntityPropertyDef.from_dict({"name": INSPECTOR_ELEVATION, "label": "Уровень Y", "type": "int", "section": "transform", "unit": "блок", "step": 1.0, "default": 0}),
			EntityPropertyDef.from_dict({"name": INSPECTOR_OFFSET, "label": "Смещение", "type": "vector3", "section": "transform", "unit": "м", "step": EditorFillConventions.OFFSET_STEP, "min": -EditorFillConventions.MAX_OFFSET_CELLS, "max": EditorFillConventions.MAX_OFFSET_CELLS, "default": [0.0, 0.0, 0.0]}),
			EntityPropertyDef.from_dict({"name": INSPECTOR_PITCH, "label": "Поворот X", "type": "float", "section": "transform", "unit": "°", "min": 0.0, "max": 359.0, "step": EditorFillConventions.ROTATION_STEP_DEG, "default": 0.0}),
			EntityPropertyDef.from_dict({"name": INSPECTOR_YAW, "label": "Поворот Y", "type": "float", "section": "transform", "unit": "°", "min": 0.0, "max": 359.0, "step": EditorFillConventions.ROTATION_STEP_DEG, "default": 0.0}),
			EntityPropertyDef.from_dict({"name": INSPECTOR_ROLL, "label": "Поворот Z", "type": "float", "section": "transform", "unit": "°", "min": 0.0, "max": 359.0, "step": EditorFillConventions.ROTATION_STEP_DEG, "default": 0.0}),
			EntityPropertyDef.from_dict({"name": INSPECTOR_SCALE, "label": "Масштаб", "type": "float", "section": "transform", "min": EditorFillConventions.SCALE_MIN, "max": EditorFillConventions.SCALE_MAX, "step": EditorFillConventions.SCALE_STEP, "default": 1.0}),
			_initial_state_property(active_archetype),
		]
		brush_properties.append_array(active_archetype.property_schema)
		return brush_properties
	return []


func _initial_state_property(archetype: EntityArchetype) -> EntityPropertyDef:
	var state_options: Array = [String(EntityStateSet.FOLLOW_SEASON)]
	for state_id: StringName in archetype.states.state_ids():
		state_options.append(String(state_id))
	return EntityPropertyDef.from_dict({
		"name": INSPECTOR_INITIAL_STATE,
		"label": "Начальное состояние",
		"type": "enum",
		"section": "state",
		"options": state_options,
		"default": String(EntityStateSet.FOLLOW_SEASON),
	})


func inspector_values() -> Dictionary:
	var selected := context.document.entities.by_id(_selected_id)
	if selected != null:
		var archetype := EntityArchetypeCatalog.get_archetype(selected.archetype_id)
		var values := archetype.resolved_properties(selected.props) if archetype != null else {}
		var cell := _base_cell(selected)
		values[INSPECTOR_CELL] = Vector2(cell.x, cell.y)
		values[INSPECTOR_CELL_X] = cell.x
		values[INSPECTOR_CELL_Z] = cell.y
		values[INSPECTOR_ELEVATION] = selected.elevation_blocks
		values[INSPECTOR_OFFSET] = selected.offset
		values[INSPECTOR_PITCH] = selected.pitch_degrees
		values[INSPECTOR_YAW] = selected.yaw_degrees
		values[INSPECTOR_ROLL] = selected.roll_degrees
		values[INSPECTOR_SCALE] = selected.scale
		values[INSPECTOR_INITIAL_STATE] = String(selected.initial_state)
		return values

	var active_archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	if active_archetype != null:
		var brush_values := active_archetype.resolved_properties(_brush_props)
		brush_values[INSPECTOR_ELEVATION] = _brush_elevation_blocks
		brush_values[INSPECTOR_OFFSET] = _brush_offset
		brush_values[INSPECTOR_PITCH] = _brush_pitch_degrees
		brush_values[INSPECTOR_YAW] = _brush_yaw_degrees
		brush_values[INSPECTOR_ROLL] = _brush_roll_degrees
		brush_values[INSPECTOR_SCALE] = _brush_scale
		brush_values[INSPECTOR_INITIAL_STATE] = String(_brush_initial_state)
		return brush_values
	return {}


func apply_inspector_value(property_name: StringName, value: Variant) -> bool:
	return _apply_value(property_name, value, true)


## `mergeable` отделяет непрерывную правку поля от разового действия: сброс к
## значению по умолчанию — отдельный шаг отмены, даже если он пришёл сразу после
## ввода в то же поле.
func _apply_value(property_name: StringName, value: Variant, mergeable: bool) -> bool:
	var primary := context.document.entities.by_id(_selected_id)
	if primary == null:
		return _apply_brush_value(property_name, value)
	if property_name in TRANSFORM_PROPERTIES:
		return _apply_transform_value(primary, property_name, value, mergeable)
	if _selected_ids().size() > 1:
		return false
	var archetype := EntityArchetypeCatalog.get_archetype(primary.archetype_id)
	if property_name == INSPECTOR_INITIAL_STATE:
		var next_state := StringName(value)
		if archetype == null or not archetype.states.allows_initial_state(next_state) \
				or primary.initial_state == next_state:
			return false
		var state_before := context.document.entities.to_json()
		primary.initial_state = next_state
		_commit(state_before, "начальное состояние")
		return true
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


func _apply_brush_value(property_name: StringName, value: Variant) -> bool:
	var archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
	if archetype == null:
		return false
	if property_name == INSPECTOR_OFFSET:
		var next_offset := EditorFillConventions.clamp_offset(
			EntityPropertyDef.from_dict({"name": "offset", "type": "vector3"}).coerce_value(value) as Vector3,
			context.terrain.cell_size,
		)
		if _brush_offset.is_equal_approx(next_offset):
			return false
		_brush_offset = next_offset
		notify_ui_changed()
		return true
	if property_name == INSPECTOR_ELEVATION:
		var next_elevation := int(round(float(value)))
		if _brush_elevation_blocks == next_elevation:
			return false
		_brush_elevation_blocks = next_elevation
		notify_ui_changed()
		return true
	if property_name in [INSPECTOR_PITCH, INSPECTOR_YAW, INSPECTOR_ROLL]:
		var next_rotation := fposmod(float(value), 360.0)
		var current := _brush_pitch_degrees if property_name == INSPECTOR_PITCH else (_brush_yaw_degrees if property_name == INSPECTOR_YAW else _brush_roll_degrees)
		if is_equal_approx(current, next_rotation):
			return false
		if property_name == INSPECTOR_PITCH:
			_brush_pitch_degrees = next_rotation
		elif property_name == INSPECTOR_YAW:
			_brush_yaw_degrees = next_rotation
		else:
			_brush_roll_degrees = next_rotation
		notify_ui_changed()
		return true
	if property_name == INSPECTOR_SCALE:
		var next_scale := EditorFillConventions.normalized_scale(
			EntityArchetypeCatalog.asset_of(archetype.id), float(value))
		if is_equal_approx(_brush_scale, next_scale):
			return false
		_brush_scale = next_scale
		notify_ui_changed()
		return true
	if property_name == INSPECTOR_INITIAL_STATE:
		var next_state := StringName(value)
		if not archetype.states.allows_initial_state(next_state) or next_state == _brush_initial_state:
			return false
		_brush_initial_state = next_state
		notify_ui_changed()
		return true
	var definition := archetype.get_property(property_name)
	if definition == null:
		return false
	var values := archetype.resolved_properties(_brush_props)
	var next: Variant = definition.clamp_value(value)
	if values.get(property_name, null) == next:
		return false
	values[property_name] = next
	_brush_props = archetype.authored_differences(values)
	notify_ui_changed()
	return true


func begin_reference_pick(property_name: StringName, reference_type: StringName) -> bool:
	if reference_type != EntityPropertyDef.TYPE_ENTITY_REF or context.document.entities.by_id(_selected_id) == null:
		return false
	_pending_reference_property = property_name
	context.set_status_message("Щёлкните по объекту, на который должна вести ссылка. Esc — отмена.")
	return true


func reset_inspector_value(property_name: StringName) -> bool:
	var primary := context.document.entities.by_id(_selected_id)
	if primary == null:
		var archetype := EntityArchetypeCatalog.get_archetype(_archetype_id)
		if archetype == null:
			return false
		if property_name == INSPECTOR_INITIAL_STATE:
			return _apply_brush_value(property_name, String(EntityStateSet.FOLLOW_SEASON))
		if property_name == INSPECTOR_OFFSET:
			return _apply_brush_value(property_name, [0.0, 0.0, 0.0])
		if property_name in [INSPECTOR_ELEVATION, INSPECTOR_PITCH, INSPECTOR_YAW, INSPECTOR_ROLL]:
			return _apply_brush_value(property_name, 0.0)
		if property_name == INSPECTOR_SCALE:
			return _apply_brush_value(property_name, 1.0)
		var brush_definition := archetype.get_property(property_name)
		return _apply_brush_value(property_name, brush_definition.default) \
			if brush_definition != null else false
	if property_name in [INSPECTOR_ELEVATION, INSPECTOR_PITCH, INSPECTOR_YAW, INSPECTOR_ROLL]:
		return _apply_transform_value(primary, property_name, 0.0, false)
	if property_name == INSPECTOR_SCALE:
		return _apply_transform_value(primary, property_name, 1.0, false)
	if property_name == INSPECTOR_OFFSET:
		# Сброс смещения ставит объект ровно по своим клеткам; сами клетки не
		# двигаются — «нулевой клетки» не существует.
		return _apply_transform_value(primary, property_name, [0.0, 0.0, 0.0], false)
	if property_name in [INSPECTOR_CELL, INSPECTOR_CELL_X, INSPECTOR_CELL_Z]:
		return false
	if property_name == INSPECTOR_INITIAL_STATE:
		return _apply_value(property_name, String(EntityStateSet.FOLLOW_SEASON), false)
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
	if property_name == INSPECTOR_OFFSET:
		var raw := EntityPropertyDef.from_dict({"name": "offset", "type": "vector3"}).coerce_value(value) as Vector3
		var offset := EditorFillConventions.clamp_offset(raw, context.terrain.cell_size)
		for entity_id: StringName in selected:
			var target := context.document.entities.by_id(entity_id)
			if target == null or target.offset.is_equal_approx(offset):
				continue
			target.position = target.anchor_position() + offset
			target.offset = offset
			changed = true
	else:
		var shift := Vector2i.ZERO
		var requested_rotation := fposmod(float(value), 360.0) if property_name in [INSPECTOR_PITCH, INSPECTOR_YAW, INSPECTOR_ROLL] else 0.0
		var requested_elevation := int(round(float(value))) if property_name == INSPECTOR_ELEVATION else 0
		if property_name == INSPECTOR_CELL:
			var requested := EntityPropertyDef.from_dict({"name": "cell", "type": "vector2"}).coerce_value(value) as Vector2
			var target_cell := Vector2i(int(round(requested.x)), int(round(requested.y)))
			shift = target_cell - _base_cell(record)
		elif property_name == INSPECTOR_CELL_X:
			shift.x = int(round(float(value))) - _base_cell(record).x
		elif property_name == INSPECTOR_CELL_Z:
			shift.y = int(round(float(value))) - _base_cell(record).y
		if property_name in [INSPECTOR_CELL, INSPECTOR_CELL_X, INSPECTOR_CELL_Z] and shift == Vector2i.ZERO:
			return false

		var proposed_cells: Dictionary = {}
		var proposed_rotations: Dictionary = {}
		var proposed_scales: Dictionary = {}
		var proposed_elevations: Dictionary = {}
		for entity_id: StringName in selected:
			var target := context.document.entities.by_id(entity_id)
			if target == null:
				continue
			var rotation := Vector3(target.pitch_degrees, target.yaw_degrees, target.roll_degrees)
			if property_name == INSPECTOR_PITCH: rotation.x = requested_rotation
			if property_name == INSPECTOR_YAW: rotation.y = requested_rotation
			if property_name == INSPECTOR_ROLL: rotation.z = requested_rotation
			var scale := target.scale
			var asset := EntityArchetypeCatalog.asset_of(target.archetype_id)
			if property_name == INSPECTOR_SCALE:
				scale = EditorFillConventions.normalized_scale(
					asset, float(value))
			var cells := Rect2i(
				_base_cell(target) + shift,
				cell_span(target.archetype_id, scale, rotation.y),
			)
			if not _cells_placeable(cells):
				context.set_status_message("Клетки вне карты или попадают в вырез.", true)
				return false
			if not _cells_free_ignoring(cells, selected, target.archetype_id):
				context.set_status_message("Эти клетки уже заняты другим объектом.", true)
				return false
			proposed_cells[entity_id] = cells
			proposed_rotations[entity_id] = rotation
			proposed_scales[entity_id] = scale
			proposed_elevations[entity_id] = requested_elevation if property_name == INSPECTOR_ELEVATION else target.elevation_blocks
		if not _proposed_selection_is_free(proposed_cells):
			context.set_status_message("Объекты выделения пересекутся после изменения.", true)
			return false

		for entity_id: StringName in selected:
			var target := context.document.entities.by_id(entity_id)
			if target == null or not proposed_cells.has(entity_id):
				continue
			var archetype := EntityArchetypeCatalog.get_archetype(target.archetype_id)
			if archetype == null:
				continue
			var cells: Rect2i = proposed_cells[entity_id]
			var rotation: Vector3 = proposed_rotations[entity_id]
			var scale: float = proposed_scales[entity_id]
			var elevation: int = proposed_elevations[entity_id]
			if _base_cell(target) != cells.position \
					or not Vector3(target.pitch_degrees, target.yaw_degrees, target.roll_degrees).is_equal_approx(rotation) \
					or target.elevation_blocks != elevation \
					or not is_equal_approx(target.scale, scale):
				changed = true
			target.pitch_degrees = rotation.x
			target.yaw_degrees = rotation.y
			target.roll_degrees = rotation.z
			target.elevation_blocks = elevation
			target.scale = scale
			target.position = _anchor_position(cells, archetype) + Vector3.UP * elevation + target.offset
	if not changed:
		return false
	var merge_key := StringName("%s/%s" % [record.id, property_name]) if mergeable else &""
	_commit(before, "трансформ сущности", merge_key)
	return true

func _proposed_selection_is_free(proposed_cells: Dictionary) -> bool:
	var ids := proposed_cells.keys()
	for left_index in ids.size():
		var left_id: StringName = ids[left_index]
		var left := context.document.entities.by_id(left_id)
		if left == null or not EditorFillConventions.asset_claims_cells(
				EntityArchetypeCatalog.asset_of(left.archetype_id)):
			continue
		for right_index in range(left_index + 1, ids.size()):
			var right_id: StringName = ids[right_index]
			var right := context.document.entities.by_id(right_id)
			if right == null or not EditorFillConventions.asset_claims_cells(
					EntityArchetypeCatalog.asset_of(right.archetype_id)):
				continue
			if EditorFillConventions.rects_overlap(proposed_cells[left_id], proposed_cells[right_id]):
				return false
	return true


func list_title() -> String:
	return "Сущности карты"


func list_entries() -> Array[String]:
	var entries: Array[String] = []
	for record: MapEntityRecord in context.document.entities.entities:
		var archetype := EntityArchetypeCatalog.get_archetype(record.archetype_id)
		var label := archetype.name if archetype != null else String(record.archetype_id)
		var cell := _base_cell(record)
		entries.append("● %s  ·  %d, %d  ·  %s" % [label, cell.x, cell.y, record.id])
	return entries


func selected_list_index() -> int:
	for index in context.document.entities.entities.size():
		if context.document.entities.entities[index].id == _selected_id:
			return index
	return -1


func selected_list_indices() -> Array[int]:
	var result: Array[int] = []
	var selected := _selected_ids()
	for index in context.document.entities.entities.size():
		if context.document.entities.entities[index].id in selected:
			result.append(index)
	return result


func list_allows_multiple() -> bool:
	return true


func select_list_entry(index: int) -> void:
	if index < 0 or index >= context.document.entities.entities.size():
		return
	_select(context.document.entities.entities[index].id, false)
	_focus_record(context.document.entities.entities[index])
	rebuild_views()
	notify_ui_changed()


func select_list_entries(indices: Array[int]) -> void:
	_selected_id = &""
	_additional_selected.clear()
	for index: int in indices:
		if index < 0 or index >= context.document.entities.entities.size():
			continue
		var entity_id: StringName = context.document.entities.entities[index].id
		if _selected_id == &"":
			_selected_id = entity_id
		else:
			_additional_selected.append(entity_id)
	if _selected_id != &"":
		_focus_record(context.document.entities.by_id(_selected_id))
	rebuild_views()
	notify_ui_changed()


func _focus_record(record: MapEntityRecord) -> void:
	if record == null or context.camera == null:
		return
	var cells := occupied_cells(record)
	context.camera.focus_on(_world_position(record.anchor_position()), float(maxi(cells.size.x, cells.size.y) + 2))


func empty_list_hint() -> String:
	return "Выберите архетип и поставьте его на карту"


func status_text() -> String:
	if context.brush == null or not context.brush.has_hover:
		return "Наполнение: выберите ассет в палитре"
	var cell := context.brush.hovered_cell
	var action := "поставить" if _archetype_id != &"" and _entity_at(cell) == &"" else "выбрать"
	return "клетка %d,%d · ЛКМ — %s · Shift+ЛКМ — пипетка · Shift+ПКМ — удалить" % [cell.x, cell.y, action]
