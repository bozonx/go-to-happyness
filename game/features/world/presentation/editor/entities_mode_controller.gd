class_name EntitiesModeController
extends MapEditorMode

## Map authoring of the shared active-zone model. The first slice deliberately
## keeps the UI in the generic palette/inspector: static editor chrome stays in
## the scene, while all zone behaviour remains in this controller.
##
## Anchors are visible in the 3D view: a `spawn` marker's colour and label say
## whether it is the hero start, a companion start, or an undecorated spawn, so
## the author never has to click into the list to tell them apart. This is the
## map-editor counterpart of the building editor's `zones_mode_controller` — the
## colours stay aligned across both tools.

const TOOL_AREA := &"area"
const TOOL_POINT := &"point"
const TOOL_ROUTE := &"route"
const TOOLS: Array[StringName] = [TOOL_AREA, TOOL_POINT, TOOL_ROUTE]

## Colour/size/label per spawn function. `MapSpawnService` distinguishes hero and
## companion starts; a function this build does not interpret still draws as a
## spawn, just without a role-specific colour.
const SPAWN_FUNCTION_STYLE: Dictionary = {
	MapSpawnService.HERO_START: {"color": Color(1.0, 0.82, 0.25), "size": Vector3(0.5, 1.1, 0.5), "label": "Герой"},
	MapSpawnService.COMPANION_START: {"color": Color(0.45, 0.7, 1.0), "size": Vector3(0.45, 0.9, 0.45), "label": "Житель"},
}
const SPAWN_FALLBACK_STYLE: Dictionary = {"color": Color(0.8, 0.5, 1.0), "size": Vector3(0.45, 0.9, 0.45)}
## Non-spawn roles get their own colour, matching the building editor's
## `ANCHOR_STYLE` so a waypoint reads the same in both tools.
const ROLE_STYLE: Dictionary = {
	ZoneAnchorRecord.ROLE_WAYPOINT: Color(0.7, 0.7, 0.7),
	ZoneAnchorRecord.ROLE_POI: Color(1.0, 0.8, 0.6),
}

var _tool: StringName = TOOL_AREA
var _area_role: StringName = ZoneAreaRecord.ROLE_REGION
var _anchor_role: StringName = ZoneAnchorRecord.ROLE_SPAWN
var _spawn_function: StringName = MapSpawnService.HERO_START
var _drag_start := Vector2i.ZERO
var _dragging := false
var _active_route_id: StringName = &""

var _root: Node3D = null
var _material_cache: Dictionary = {}


func _init() -> void:
	id = &"entities"
	title = "Зоны и точки"
	icon = "📍"


func configure(next_context: MapEditorContext) -> void:
	super.configure(next_context)
	if _root == null:
		_root = Node3D.new()
		_root.name = "ZoneAnchorViews"
		context.terrain_world.add_child(_root)
	rebuild_views()


func activate() -> void:
	rebuild_views()


func deactivate() -> void:
	_dragging = false
	if context != null and context.brush != null:
		context.brush.clear_hover()


func document_changed() -> void:
	rebuild_views()


func clear_hover() -> void:
	if context != null and context.brush != null:
		context.brush.clear_hover()


func hover_brush() -> BaseBrushController:
	return context.brush if context != null else null


## Presentation-only markers for every anchor on the zone layer, rebuilt on
## activation and whenever the document changes. They are the only way to tell,
## at a glance, where a spawn sits and whether it is the hero or a companion —
## the authored `pos` is planar, so the marker lifts onto the live terrain the
## way the runtime will, otherwise it would sit inside a raised hill.
func rebuild_views() -> void:
	if _root == null:
		return
	# `free()` rather than `queue_free()`: `activate()` is called on the same
	# frame a mode switch also rebuilds, and a deferred free would leave the old
	# markers counted alongside the new ones — the editor would draw and re-draw
	# on top of itself. Markers own no signals, so freeing in place is safe.
	for child in _root.get_children():
		child.free()
	if context == null or context.document == null:
		return
	# Companion starts are numbered in authoring order; the label mirrors what
	# `MapSpawnService.companion_spawn_positions` returns, so the on-map text and
	# the spawn order the runtime uses stay in sync.
	var companion_index := 0
	for anchor: ZoneAnchorRecord in context.document.zones.anchors:
		var style := _anchor_style(anchor)
		if anchor.is_spawn() and anchor.function == MapSpawnService.COMPANION_START:
			companion_index += 1
		var label_text := _anchor_label(anchor, style, companion_index)
		_add_marker(anchor, style, label_text)


func _anchor_style(anchor: ZoneAnchorRecord) -> Dictionary:
	if anchor.is_spawn():
		return SPAWN_FUNCTION_STYLE.get(anchor.function, SPAWN_FALLBACK_STYLE)
	var color: Color = ROLE_STYLE.get(anchor.role, Color(0.6, 0.6, 0.65))
	return {"color": color, "size": Vector3(0.4, 0.8, 0.4)}


func _anchor_label(anchor: ZoneAnchorRecord, style: Dictionary, companion_index: int) -> String:
	if anchor.is_spawn():
		if anchor.function == MapSpawnService.COMPANION_START:
			return "%s %d" % [style.get("label", ""), companion_index]
		if style.has("label"):
			return String(style["label"])
		return String(anchor.id)
	return String(anchor.id)


func _add_marker(anchor: ZoneAnchorRecord, style: Dictionary, label_text: String) -> void:
	var marker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = style["size"]
	marker.mesh = mesh
	marker.material_override = _get_material(style["color"])
	var size: Vector3 = style["size"]
	# Anchored XZ with Y lifted onto the terrain — the same projection the
	# citizen factory applies at launch, so a marker never sits inside the ground.
	var position := anchor.pos
	position.y = context.terrain.height_at(position) + size.y * 0.5
	marker.position = position
	marker.rotation.y = anchor.facing
	_root.add_child(marker)
	if not label_text.is_empty():
		_add_label(marker, label_text, size.y)


func _add_label(parent: Node3D, text: String, marker_height: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.outline_size = 16
	label.outline_modulate = Color.BLACK
	label.modulate = Color.WHITE
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.position = Vector3(0.0, marker_height * 0.5 + 0.5, 0.0)
	parent.add_child(label)


func _get_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_cache[key] = material
	return material


func pick_from_cell() -> void:
	if context == null or context.brush == null or not context.brush.has_hover:
		return
	var cell := context.brush.hovered_cell
	var anchor := _anchor_at(cell)
	if anchor != null:
		_tool = TOOL_POINT
		_anchor_role = anchor.role
		notify_ui_changed()
		return
	for area: ZoneAreaRecord in context.document.zones.areas:
		if area.bounds.has_point(cell):
			_tool = TOOL_AREA
			_area_role = area.role
			notify_ui_changed()
			return


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
	if _anchor_role == ZoneAnchorRecord.ROLE_SPAWN:
		anchor.function = _spawn_function
		if _spawn_function == MapSpawnService.HERO_START and not context.document.zones.has_id(&"hero_start"):
			anchor.id = &"hero_start"
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
		if _anchor_role == ZoneAnchorRecord.ROLE_SPAWN:
			options.append(ToolOption.of(&"spawn_hero", "Старт героя", &"function", _spawn_function == MapSpawnService.HERO_START))
			options.append(ToolOption.of(&"spawn_companion", "Старт жителя", &"function", _spawn_function == MapSpawnService.COMPANION_START))
	return options


func activate_option(option_id: StringName) -> void:
	if option_id == &"area_region":
		_area_role = ZoneAreaRecord.ROLE_REGION
	elif option_id == &"area_overlay":
		_area_role = ZoneAreaRecord.ROLE_OVERLAY
	elif String(option_id).begins_with("anchor_"):
		_anchor_role = StringName(String(option_id).trim_prefix("anchor_"))
	elif option_id == &"spawn_hero":
		_spawn_function = MapSpawnService.HERO_START
	elif option_id == &"spawn_companion":
		_spawn_function = MapSpawnService.COMPANION_START
	notify_ui_changed()


func inspector_lines() -> Array[String]:
	var lines: Array[String] = [
		"Инструмент: %s" % _tool,
		"Областей: %d" % context.document.zones.areas.size(),
		"Точек: %d" % context.document.zones.anchors.size(),
		"Маршрутов: %d" % context.document.zones.routes.size(),
	]
	if _tool == TOOL_POINT and _anchor_role == ZoneAnchorRecord.ROLE_SPAWN:
		# The active spawn function decides what a new click places; restating it
		# in the inspector keeps the palette toggle and the marker colour honest.
		var function_label := "старт героя" if _spawn_function == MapSpawnService.HERO_START else "старт жителя"
		lines.append("Будет поставлено: %s" % function_label)
	return lines


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
