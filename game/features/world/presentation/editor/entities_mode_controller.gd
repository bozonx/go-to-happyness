class_name EntitiesModeController
extends MapEditorMode

## Map authoring of the shared active-zone model. The first slice deliberately
## keeps the UI in the generic palette/inspector: static editor chrome stays in
## the scene, while all zone behaviour remains in this controller.

const TOOL_AREA := &"area"
const TOOL_POINT := &"point"
const TOOL_ROUTE := &"route"
const TOOLS: Array[StringName] = [TOOL_AREA, TOOL_POINT, TOOL_ROUTE]

var _tool: StringName = TOOL_AREA
var _area_role: StringName = ZoneAreaRecord.ROLE_REGION
var _anchor_role: StringName = ZoneAnchorRecord.ROLE_SPAWN
var _drag_start := Vector2i.ZERO
var _dragging := false
var _active_route_id: StringName = &""


func _init() -> void:
	id = &"entities"
	title = "Зоны и точки"
	icon = "📍"


func deactivate() -> void:
	_dragging = false
	if context != null and context.brush != null:
		context.brush.clear_hover()


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
				notify_ui_changed()
				return true
			KEY_DELETE:
				return _delete_at_hover()
	return false


func _handle_mouse(event: InputEventMouseButton) -> bool:
	if event.button_index != MOUSE_BUTTON_LEFT or not context.brush.has_hover:
		return false
	if _tool == TOOL_AREA:
		if event.pressed:
			_dragging = true
			_drag_start = context.brush.hovered_cell
		elif _dragging:
			_dragging = false
			_add_area(_drag_start, context.brush.hovered_cell)
		return true
	if event.pressed and _tool == TOOL_POINT:
		_add_anchor(context.brush.hovered_cell)
		return true
	if event.pressed and _tool == TOOL_ROUTE:
		_append_route_stop(context.brush.hovered_cell)
		return true
	return false


func _add_area(start: Vector2i, finish: Vector2i) -> void:
	var before := context.document.zones.to_json()
	var area := ZoneAreaRecord.new()
	area.id = _next_id("area")
	area.area_name = "Регион" if _area_role == ZoneAreaRecord.ROLE_REGION else "Оверлей"
	area.role = _area_role
	area.y_min = context.terrain.height_of(start)
	area.y_max = area.y_min
	area.add_rect(Rect2i(start, finish - start + Vector2i.ONE))
	context.document.zones.areas.append(area)
	_commit(before, "зона")


func _add_anchor(cell: Vector2i) -> void:
	var before := context.document.zones.to_json()
	var anchor := ZoneAnchorRecord.new()
	anchor.id = _next_id("point")
	anchor.role = _anchor_role
	var centre := context.terrain.cell_center(cell)
	anchor.pos = centre
	context.document.zones.anchors.append(anchor)
	_commit(before, "точка")


func _append_route_stop(cell: Vector2i) -> void:
	var stop := _anchor_at(cell)
	if stop == null:
		return
	var before := context.document.zones.to_json()
	var route := context.document.zones.route_by_id(_active_route_id)
	if route == null:
		route = ZoneRouteRecord.new()
		route.id = _next_id("route")
		context.document.zones.routes.append(route)
		_active_route_id = route.id
	if stop.id not in route.stops:
		route.stops.append(stop.id)
		_commit(before, "маршрут")


func _anchor_at(cell: Vector2i) -> ZoneAnchorRecord:
	for anchor in context.document.zones.anchors:
		if anchor.cell() == cell:
			return anchor
	return null


func _delete_at_hover() -> bool:
	if not context.brush.has_hover:
		return false
	var cell := context.brush.hovered_cell
	var before := context.document.zones.to_json()
	for index in range(context.document.zones.anchors.size() - 1, -1, -1):
		if context.document.zones.anchors[index].cell() == cell:
			context.document.zones.anchors.remove_at(index)
			_commit(before, "удаление точки")
			return true
	for index in range(context.document.zones.areas.size() - 1, -1, -1):
		if context.document.zones.areas[index].contains_cell(cell):
			context.document.zones.areas.remove_at(index)
			_commit(before, "удаление зоны")
			return true
	return false


func _next_id(prefix: String) -> StringName:
	var number := 1
	while context.document.zones.has_id(StringName("%s_%d" % [prefix, number])):
		number += 1
	return StringName("%s_%d" % [prefix, number])


func _commit(before: Dictionary, command_label: String) -> void:
	var command := MapZoneCommand.of(context.document, before, context.document.zones.to_json(), command_label)
	context.history.push(command)
	notify_ui_changed()


func palette_entries() -> Array:
	return [
		PaletteEntry.of(TOOL_AREA, "Область"),
		PaletteEntry.of(TOOL_POINT, "Точка"),
		PaletteEntry.of(TOOL_ROUTE, "Маршрут"),
	]


func selected_palette_entry() -> StringName:
	return _tool


func select_palette_entry(entry_id: StringName) -> void:
	if entry_id in TOOLS:
		_tool = entry_id
		notify_ui_changed()


func tool_options() -> Array:
	var options: Array = []
	if _tool == TOOL_AREA:
		options.append(ToolOption.of(&"area_region", "Регион", &"role", _area_role == ZoneAreaRecord.ROLE_REGION))
		options.append(ToolOption.of(&"area_overlay", "Оверлей", &"role", _area_role == ZoneAreaRecord.ROLE_OVERLAY))
	if _tool == TOOL_POINT:
		for role in ZoneAnchorRecord.ROLES:
			options.append(ToolOption.of(StringName("anchor_%s" % role), ZoneAnchorRecord.role_display_name(role), &"role", _anchor_role == role))
	return options


func activate_option(option_id: StringName) -> void:
	if option_id == &"area_region":
		_area_role = ZoneAreaRecord.ROLE_REGION
	elif option_id == &"area_overlay":
		_area_role = ZoneAreaRecord.ROLE_OVERLAY
	elif String(option_id).begins_with("anchor_"):
		_anchor_role = StringName(String(option_id).trim_prefix("anchor_"))
	notify_ui_changed()


func inspector_lines() -> Array[String]:
	return [
		"Инструмент: %s" % _tool,
		"Областей: %d" % context.document.zones.areas.size(),
		"Точек: %d" % context.document.zones.anchors.size(),
		"Маршрутов: %d" % context.document.zones.routes.size(),
	]


func list_title() -> String:
	return "Зоны карты"


func list_entries() -> Array[String]:
	var entries: Array[String] = []
	for area in context.document.zones.areas:
		entries.append("▣ %s" % area.id)
	for anchor in context.document.zones.anchors:
		entries.append("◆ %s" % anchor.id)
	for route in context.document.zones.routes:
		entries.append("／ %s" % route.id)
	return entries


func empty_list_hint() -> String:
	return "Нарисуйте область или поставьте точку на карте"


func status_text() -> String:
	if context.brush == null or not context.brush.has_hover:
		return "Зоны: ЛКМ — поставить, Delete — удалить под курсором"
	var cell := context.brush.hovered_cell
	return "клетка %d,%d · %s" % [cell.x, cell.y, _tool]
