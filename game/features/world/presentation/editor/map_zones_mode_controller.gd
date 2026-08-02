class_name MapZonesModeController
extends MapEditorMode

## Zones mode of the territory editor (map_editor.md §5.5, active_zones.md §11.2).
##
## "Отличий в модели нет — те же инструменты и тот же инспектор": this is the map
## half of that promise, and it is deliberately built out of the same parts as
## the building editor's zones mode — `ZoneAuthoring` for the gestures,
## `ZoneMarkerStyle` for how things read, `ZoneFunctionCatalog` for what they
## mean. What differs is only what §18 says differs: the role vocabulary (no
## `room` on a map), the scale, and the fact that effects matter more than rights
## out here, because forest, mud and a ford are landscape rather than a room.
##
## The panels are the editor's generic ones. A mode describes what it wants shown
## — palette, tool options, typed inspector properties, a list — and never draws a
## control of its own (§3.5).

const TOOL_AREA := &"area"
const TOOL_POINT := &"point"
const TOOL_ROUTE := &"route"
const TOOL_SELECT := &"select"
const TOOLS: Array[StringName] = [TOOL_AREA, TOOL_POINT, TOOL_ROUTE, TOOL_SELECT]

## §18: the map vocabulary. `room` is a building's business — an addressable part
## of a building comes with the building, and a map that could author one would be
## the "map writes into the blueprint" direction the doc forbids.
const AREA_ROLES: Array[StringName] = [ZoneAreaRecord.ROLE_REGION, ZoneAreaRecord.ROLE_OVERLAY]
## Occupancy points (`slot`, `queue`, `storage`) are authored inside buildings and
## only rarely on a map; the ones offered here are the ones a map actually uses.
## A `queue` is deliberately absent: it is meaningless without the slot it leads
## to, and offering it produced records the validator then refused.
const ANCHOR_ROLES: Array[StringName] = [
	ZoneAnchorRecord.ROLE_SPAWN, ZoneAnchorRecord.ROLE_WAYPOINT, ZoneAnchorRecord.ROLE_POI,
	ZoneAnchorRecord.ROLE_DOOR, ZoneAnchorRecord.ROLE_SLOT, ZoneAnchorRecord.ROLE_STORAGE,
]

# Inspector property names. Prefixed so an area's `id` and an anchor's `id` are
# the same control on the same row of the panel.
const P_ID := &"zone_id"
const P_NAME := &"zone_name"
const P_ROLE := &"zone_role"
const P_FUNCTION := &"zone_function"
const P_Y_MIN := &"zone_y_min"
const P_Y_MAX := &"zone_y_max"
const P_ALLOW := &"zone_allow"
const P_DENY := &"zone_deny"
const P_COST := &"zone_cost"
const P_VISION := &"zone_vision"
const P_CONCEAL := &"zone_conceal"
const P_OWNER := &"anchor_owner"
const P_FACING := &"anchor_facing"
const P_ARC := &"anchor_arc"
const P_TAG := &"anchor_tag"
const P_POSE := &"anchor_pose"
const P_ACTIVITY := &"anchor_activity"
const P_DIRECTION := &"anchor_direction"
const P_CAPACITY := &"anchor_capacity"
const P_CYCLE := &"route_cycle"
const P_WAIT := &"route_wait"

const NO_FUNCTION := "—"

var _tool: StringName = TOOL_AREA
var _area_role: StringName = ZoneAreaRecord.ROLE_REGION
var _anchor_role: StringName = ZoneAnchorRecord.ROLE_SPAWN
var _armed_function: StringName = MapSpawnService.HERO_START

var _selected_area_id: StringName = &""
var _selected_anchor_id: StringName = &""
var _selected_route_id: StringName = &""

var _drag_start := Vector2i.ZERO
var _dragging := false
var _erasing := false
var _linking := false
var _link_route_id: StringName = &""

## Presentation only, rebuilt from the document. Areas are drawn as flat quads
## per rectangle and anchors as boxes: an area that is invisible until you click
## it is an area an author cannot place, and that is what the first cut of this
## mode shipped with.
var _root: Node3D = null
var _material_cache: Dictionary = {}
## Cached validator output so the status line and the list can show what is wrong
## without re-running the whole check on every mouse move.
var _errors: Array[String] = []
var _warnings: Array[String] = []
## Parallel to `list_entries()`: what each row addresses, so a click selects it.
var _rows: Array[Dictionary] = []


func _init() -> void:
	id = &"zones"
	title = "Зоны и точки"
	icon = "📍"


func configure(next_context: MapEditorContext) -> void:
	super.configure(next_context)
	if _root == null:
		_root = Node3D.new()
		_root.name = "ZoneViews"
		context.terrain_world.add_child(_root)
	document_changed()


func activate() -> void:
	document_changed()


func deactivate() -> void:
	_dragging = false
	_erasing = false
	_stop_linking()
	if context != null and context.brush != null:
		context.brush.clear_hover()


func document_changed() -> void:
	_revalidate()
	rebuild_views()


func clear_hover() -> void:
	if context != null and context.brush != null:
		context.brush.clear_hover()


func hover_brush() -> BaseBrushController:
	return context.brush if context != null else null


func process(_delta: float) -> void:
	context.brush.update_hover(context.camera, context.space_state(), context.mouse_position())
	# Held Shift+RMB erases the cells the cursor crosses. Driven from `process`
	# rather than a motion handler so a drag over the panel edge cannot leave the
	# gesture half-applied.
	if _erasing:
		_erase_at_hover()


# --- Input --------------------------------------------------------------------

func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _handle_mouse(event as InputEventMouseButton)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return _handle_key(event as InputEventKey)
	return false


## The layout is the building editor's, key for key (§11.1). Muscle memory is the
## whole reason the two editors share a model in the first place; `Tab` cycling
## tools in one and roles in the other threw that away for nothing.
func _handle_key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_Q:
			_arm_tool(TOOL_AREA)
			return true
		KEY_W:
			_arm_tool(TOOL_POINT)
			return true
		KEY_E:
			_arm_tool(TOOL_ROUTE)
			return true
		KEY_TAB:
			_cycle_role()
			return true
		KEY_F:
			return _rotate_selected_anchor()
		KEY_DELETE:
			return _delete_selection()
		KEY_ESCAPE:
			if _linking:
				_stop_linking()
				notify_ui_changed()
				return true
			if _has_selection():
				_clear_selection()
				notify_ui_changed()
				return true
			if _tool != TOOL_SELECT:
				_arm_tool(TOOL_SELECT)
				return true
	return false


func _handle_mouse(event: InputEventMouseButton) -> bool:
	# Shift+RMB erases, held or dragged — the same gesture as every other mode.
	if event.button_index == MOUSE_BUTTON_RIGHT and event.shift_pressed:
		_erasing = event.pressed
		if event.pressed:
			_erase_at_hover()
		return true
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if _linking and event.pressed:
			_stop_linking()
			notify_ui_changed()
			return true
		return false
	if event.button_index != MOUSE_BUTTON_LEFT or not context.brush.has_hover:
		return false
	var cell := context.brush.hovered_cell
	if event.pressed and _linking:
		_link_click(cell)
		return true
	if _tool == TOOL_AREA:
		if event.pressed:
			# Hybrid, as in the building editor: over an existing area a click
			# selects it, over empty ground it starts a rectangle.
			var area := _area_at(cell)
			if area != null:
				_select_area(area.id)
				return true
			_dragging = true
			_drag_start = cell
		elif _dragging:
			_dragging = false
			_add_area(_drag_start, cell)
		return true
	if not event.pressed:
		return false
	match _tool:
		TOOL_POINT:
			var anchor := _anchor_at(cell)
			if anchor != null:
				_select_anchor(anchor.id)
			else:
				_add_anchor(cell)
		TOOL_ROUTE:
			_append_route_stop(cell)
		TOOL_SELECT:
			_select_at(cell)
	return true


## Eyedropper: arm the tool, role and function of whatever is under the cursor.
func pick_from_cell() -> bool:
	if context == null or context.brush == null or not context.brush.has_hover:
		return false
	var cell := context.brush.hovered_cell
	var anchor := _anchor_at(cell)
	if anchor != null:
		_tool = TOOL_POINT
		_anchor_role = anchor.role
		if anchor.function != &"":
			_armed_function = anchor.function
		notify_ui_changed()
		return true
	var area := _area_at(cell)
	if area != null:
		_tool = TOOL_AREA
		_area_role = area.role
		if area.function != &"":
			_armed_function = area.function
		notify_ui_changed()
		return true
	return false


func _arm_tool(tool_id: StringName) -> void:
	_tool = tool_id
	_stop_linking()
	notify_ui_changed()


## `Tab` walks the roles of the active tool — never the two vocabularies at once.
func _cycle_role() -> void:
	if _tool == TOOL_AREA:
		_area_role = AREA_ROLES[(AREA_ROLES.find(_area_role) + 1) % AREA_ROLES.size()]
	elif _tool == TOOL_POINT:
		_anchor_role = ANCHOR_ROLES[(ANCHOR_ROLES.find(_anchor_role) + 1) % ANCHOR_ROLES.size()]
		_armed_function = _default_function_for_anchor(_anchor_role)
	notify_ui_changed()


func _default_function_for_anchor(role: StringName) -> StringName:
	if role == ZoneAnchorRecord.ROLE_SPAWN:
		return MapSpawnService.HERO_START
	return &""


# --- Editing ------------------------------------------------------------------

func _add_area(start: Vector2i, finish: Vector2i) -> void:
	var before := context.document.zones.to_json()
	var area := ZoneAreaRecord.new()
	area.id = ZoneAuthoring.unique_id(
		"region" if _area_role == ZoneAreaRecord.ROLE_REGION else "overlay",
		func(candidate: StringName) -> bool: return context.document.zones.has_id(candidate))
	area.area_name = "Регион" if _area_role == ZoneAreaRecord.ROLE_REGION else "Оверлей"
	area.role = _area_role
	if _area_role == ZoneAreaRecord.ROLE_REGION:
		area.function = _armed_function if ZoneFunctionCatalog.supports_area_role(
			_armed_function, _area_role) else &""
		area.properties = ZoneFunctionCatalog.default_properties(area.function)
	else:
		# An overlay that forbids nobody and corrects nothing is a no-op. On a map
		# the common case is an effect, not a right (§18) — so a fresh overlay
		# starts as terrain that costs more to cross, which is what a forest, mud
		# or rubble is, and the author widens it from there.
		area.effects = {ZoneEffects.KEY_COST: 2.0}
	area.add_rect(ZoneAuthoring.rect_from_drag(start, finish, _min_cell(), _max_cell()))
	area.y_min = context.terrain.height_of(start)
	area.y_max = area.y_min
	context.document.zones.areas.append(area)
	_select_area(area.id)
	_commit(before, "зона")


func _add_anchor(cell: Vector2i) -> void:
	var before := context.document.zones.to_json()
	var anchor := ZoneAnchorRecord.new()
	anchor.role = _anchor_role
	anchor.id = ZoneAuthoring.unique_id(String(_anchor_role),
		func(candidate: StringName) -> bool: return context.document.zones.has_id(candidate))
	if ZoneFunctionCatalog.supports_anchor_role(_armed_function, _anchor_role):
		anchor.function = _armed_function
		anchor.properties = ZoneFunctionCatalog.default_properties(_armed_function)
	# The party start is the one address a settlement launch looks up by name, so
	# the first one authored gets the readable id instead of `spawn_3`.
	if anchor.function == MapSpawnService.HERO_START and not context.document.zones.has_id(&"hero_start"):
		anchor.id = &"hero_start"
	# Board cells, not metres: `pos.y` is the terrain *level* the author placed it
	# on (§6). Conversion to world space happens once, in `MapSpawnService`.
	anchor.pos = Vector3(float(cell.x) + 0.5, float(context.terrain.height_of(cell)), float(cell.y) + 0.5)
	# Ownership is explicit, but the obvious owner is filled in: the region under
	# the point. An overlay never owns anything, so it is not a candidate.
	for area in context.document.zones.areas:
		if area.role == ZoneAreaRecord.ROLE_REGION and area.contains_cell(cell):
			anchor.owner_id = area.id
			break
	context.document.zones.anchors.append(anchor)
	_select_anchor(anchor.id)
	_commit(before, "точка")


func _append_route_stop(cell: Vector2i) -> void:
	var stop := _anchor_at(cell)
	if stop == null:
		context.set_status_message("Маршрут строится по точкам: поставьте точку и кликните по ней.")
		return
	var before := context.document.zones.to_json()
	var route := context.document.zones.route_by_id(_selected_route_id)
	if route == null:
		route = ZoneRouteRecord.new()
		route.id = ZoneAuthoring.unique_id("route",
			func(candidate: StringName) -> bool: return context.document.zones.has_id(candidate))
		context.document.zones.routes.append(route)
	if stop.id in route.stops:
		return
	route.stops.append(stop.id)
	_selected_route_id = route.id
	_selected_area_id = &""
	_selected_anchor_id = &""
	_commit(before, "маршрут")


## "В маршрут" from the inspector of a selected point: subsequent clicks on
## points in the 3D view append them, `Esc` or right-click finishes.
func _start_linking() -> void:
	var anchor := _selected_anchor()
	if anchor == null:
		return
	var before := context.document.zones.to_json()
	var route := context.document.zones.route_by_id(_link_route_id)
	if route == null:
		route = ZoneRouteRecord.new()
		route.id = ZoneAuthoring.unique_id("route",
			func(candidate: StringName) -> bool: return context.document.zones.has_id(candidate))
		route.stops.append(anchor.id)
		context.document.zones.routes.append(route)
		_link_route_id = route.id
		_commit(before, "маршрут")
	_linking = true
	context.set_status_message("Маршрут %s: кликайте по точкам, Esc — закончить" % _link_route_id)


func _link_click(cell: Vector2i) -> void:
	var stop := _anchor_at(cell)
	var route := context.document.zones.route_by_id(_link_route_id)
	if stop == null or route == null or stop.id in route.stops:
		return
	var before := context.document.zones.to_json()
	route.stops.append(stop.id)
	_commit(before, "маршрут")


func _stop_linking() -> void:
	if not _linking:
		return
	_linking = false
	var route := context.document.zones.route_by_id(_link_route_id)
	# A one-stop route is not a route; leaving it would put a line in the list
	# that does nothing.
	if route != null and route.stops.size() < 2:
		var before := context.document.zones.to_json()
		context.document.zones.routes.erase(route)
		_commit(before, "маршрут")
	elif route != null:
		_selected_route_id = route.id
	_link_route_id = &""


func _erase_at_hover() -> void:
	if not context.brush.has_hover:
		return
	var cell := context.brush.hovered_cell
	var anchor := _anchor_at(cell)
	if anchor != null:
		var before := context.document.zones.to_json()
		ZoneAuthoring.remove_anchor_cascade(
			context.document.zones.anchors, context.document.zones.routes, anchor.id)
		_clear_selection()
		_commit(before, "удаление точки")
		return
	var area := _area_at(cell)
	if area == null:
		return
	var before_area := context.document.zones.to_json()
	# Erasing takes one cell out of the area and keeps the rest; the record splits
	# its rectangles deterministically. An area erased down to nothing goes, and
	# takes what it owned with it.
	if area.remove_cell(cell) and area.is_empty():
		ZoneAuthoring.remove_area_cascade(
			context.document.zones.areas, context.document.zones.anchors,
			context.document.zones.routes, area.id)
		_clear_selection()
	_commit(before_area, "стирание зоны")


func _delete_selection() -> bool:
	var before := context.document.zones.to_json()
	var removed: Array[StringName] = []
	if _selected_anchor_id != &"":
		removed = ZoneAuthoring.remove_anchor_cascade(
			context.document.zones.anchors, context.document.zones.routes, _selected_anchor_id)
	elif _selected_area_id != &"":
		removed = ZoneAuthoring.remove_area_cascade(
			context.document.zones.areas, context.document.zones.anchors,
			context.document.zones.routes, _selected_area_id)
	elif _selected_route_id != &"":
		var route := context.document.zones.route_by_id(_selected_route_id)
		if route != null:
			context.document.zones.routes.erase(route)
			removed.append(route.id)
	elif context.brush.has_hover:
		# Nothing selected: Delete acts on what is under the cursor, which is what
		# the author means when they never clicked anything.
		_erase_at_hover()
		return true
	if removed.is_empty():
		return false
	_clear_selection()
	_commit(before, "удаление зоны")
	if removed.size() > 1:
		context.set_status_message("Удалено вместе с содержимым: %s" % ", ".join(
			removed.map(func(entry: StringName) -> String: return String(entry))))
	return true


func _rotate_selected_anchor() -> bool:
	var anchor := _selected_anchor()
	if anchor == null:
		return false
	var before := context.document.zones.to_json()
	anchor.facing = fmod(anchor.facing + 45.0, 360.0)
	_commit(before, "поворот точки")
	return true


func _commit(before: Dictionary, label: String) -> void:
	context.history.push(MapZoneCommand.of(
		context.document, before, context.document.zones.to_json(), label))
	_revalidate()
	rebuild_views()
	notify_ui_changed()


func _revalidate() -> void:
	if context == null or context.document == null:
		return
	var cells := context.document.board_cells()
	_errors = context.document.zones.validate(cells)
	_warnings = context.document.zones.warnings(cells)
	# Reachability needs a published navigation field; the map validator skips it
	# when there is none, so this stays correct in a headless test too.
	_warnings.append_array(MapValidator.warnings(context.document, context.nav_grid))


# --- Selection ----------------------------------------------------------------

func _has_selection() -> bool:
	return _selected_area_id != &"" or _selected_anchor_id != &"" or _selected_route_id != &""


func _clear_selection() -> void:
	_selected_area_id = &""
	_selected_anchor_id = &""
	_selected_route_id = &""


func _select_area(area_id: StringName) -> void:
	_selected_area_id = area_id
	_selected_anchor_id = &""
	_selected_route_id = &""
	rebuild_views()
	notify_ui_changed()


func _select_anchor(anchor_id: StringName) -> void:
	_selected_anchor_id = anchor_id
	_selected_area_id = &""
	_selected_route_id = &""
	rebuild_views()
	notify_ui_changed()


func _select_at(cell: Vector2i) -> void:
	var anchor := _anchor_at(cell)
	if anchor != null:
		_select_anchor(anchor.id)
		return
	var area := _area_at(cell)
	if area != null:
		_select_area(area.id)
		return
	_clear_selection()
	notify_ui_changed()


func _selected_area() -> ZoneAreaRecord:
	return context.document.zones.area_by_id(_selected_area_id) if _selected_area_id != &"" else null


func _selected_anchor() -> ZoneAnchorRecord:
	return context.document.zones.anchor_by_id(_selected_anchor_id) if _selected_anchor_id != &"" else null


func _selected_route() -> ZoneRouteRecord:
	return context.document.zones.route_by_id(_selected_route_id) if _selected_route_id != &"" else null


func _anchor_at(cell: Vector2i) -> ZoneAnchorRecord:
	for anchor in context.document.zones.anchors:
		if anchor.cell() == cell:
			return anchor
	return null


## The smallest area covering the cell, so an overlay drawn over a big region is
## reachable by clicking it rather than hidden behind the region forever.
func _area_at(cell: Vector2i) -> ZoneAreaRecord:
	var best: ZoneAreaRecord = null
	for area in context.document.zones.areas:
		if not area.contains_cell(cell):
			continue
		if best == null or area.cell_count() < best.cell_count():
			best = area
	return best


func _min_cell() -> Vector2i:
	return context.terrain.min_cell()


func _max_cell() -> Vector2i:
	return context.terrain.max_cell()


# --- 3D views -----------------------------------------------------------------

## Rebuilt on activation and whenever the document changes. `free()` rather than
## `queue_free()`: a mode switch rebuilds on the same frame, and a deferred free
## would leave the old markers counted alongside the new ones.
func rebuild_views() -> void:
	if _root == null:
		return
	for child in _root.get_children():
		child.free()
	if context == null or context.document == null:
		return
	var index := 0
	for area: ZoneAreaRecord in context.document.zones.areas:
		var color := ZoneMarkerStyle.color_of_area(area, index)
		if area.id == _selected_area_id:
			color = ZoneMarkerStyle.SELECTION_COLOR
		for rect: Rect2i in area.rects:
			_add_area_quad(rect, color, area.is_overlay())
		index += 1
	var companion_index := 0
	for anchor: ZoneAnchorRecord in context.document.zones.anchors:
		if anchor.is_spawn() and anchor.function == MapSpawnService.COMPANION_START:
			companion_index += 1
		_add_anchor_marker(anchor, _anchor_label(anchor, companion_index))
	for route: ZoneRouteRecord in context.document.zones.routes:
		_add_route(route)


## Companion starts are numbered in authoring order; the label mirrors what
## `MapSpawnService.companion_spawn_positions` returns, so the on-map text and the
## spawn order the runtime uses stay in sync.
func _anchor_label(anchor: ZoneAnchorRecord, companion_index: int) -> String:
	var style := ZoneMarkerStyle.of_anchor(anchor)
	if anchor.is_spawn() and anchor.function == MapSpawnService.COMPANION_START:
		return "%s %d" % [style.get("label", "Житель"), companion_index]
	if style.has("label"):
		return String(style["label"])
	return String(anchor.id)


func _add_area_quad(rect: Rect2i, color: Color, is_overlay: bool) -> void:
	var cell_size := context.terrain.cell_size
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(float(rect.size.x) * cell_size, 0.05, float(rect.size.y) * cell_size)
	instance.mesh = mesh
	# An overlay is drawn fainter than a region on purpose: there are more of them,
	# they overlap everything by definition, and at full strength they bury the
	# ground the author is trying to read (§11, "показ прав — оверлей, а не режим").
	instance.material_override = _get_material(color, 0.22 if is_overlay else 0.38)
	var centre := Vector2(rect.position) + Vector2(rect.size) * 0.5
	var world_centre := Vector2(centre.x * cell_size, centre.y * cell_size)
	instance.position = Vector3(
		world_centre.x,
		context.terrain.height_at(Vector3(world_centre.x, 0.0, world_centre.y)) + 0.06,
		world_centre.y)
	_root.add_child(instance)


func _add_anchor_marker(anchor: ZoneAnchorRecord, label_text: String) -> void:
	var style := ZoneMarkerStyle.of_anchor(anchor)
	var size: Vector3 = style["size"]
	var color: Color = ZoneMarkerStyle.SELECTION_COLOR if anchor.id == _selected_anchor_id else style["color"]
	var marker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	marker.mesh = mesh
	marker.material_override = _get_material(color, 0.75)
	var position := _world_position_of(anchor)
	position.y = context.terrain.height_at(position) + size.y * 0.5
	marker.position = position
	# `facing` is degrees (§10); feeding it to `rotation.y` as radians pointed
	# every authored marker somewhere the author never asked for.
	marker.rotation.y = deg_to_rad(anchor.facing)
	_root.add_child(marker)
	if not label_text.is_empty():
		_add_label(marker, label_text, size.y)


func _add_route(route: ZoneRouteRecord) -> void:
	var color := ZoneMarkerStyle.SELECTION_COLOR if route.id == _selected_route_id else Color(1.0, 0.9, 0.4)
	for index in range(1, route.stops.size()):
		var from := context.document.zones.anchor_by_id(route.stops[index - 1])
		var to := context.document.zones.anchor_by_id(route.stops[index])
		if from == null or to == null:
			continue
		_add_route_segment(_lifted(from), _lifted(to), color)


func _lifted(anchor: ZoneAnchorRecord) -> Vector3:
	var position := _world_position_of(anchor)
	position.y = context.terrain.height_at(position) + 0.4
	return position


## Board cells → world space, the same conversion the runtime does (§9).
func _world_position_of(anchor: ZoneAnchorRecord) -> Vector3:
	return MapSpawnService.world_position_of(anchor, context.terrain.cell_size)


func _add_route_segment(from: Vector3, to: Vector3, color: Color) -> void:
	var delta := to - from
	var length := delta.length()
	if length <= 0.001:
		return
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, length)
	instance.mesh = mesh
	instance.material_override = _get_material(color, 0.9)
	instance.position = (from + to) * 0.5
	instance.look_at_from_position(instance.position, instance.position + delta, Vector3.UP)
	_root.add_child(instance)


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


func _get_material(color: Color, alpha: float) -> StandardMaterial3D:
	var key := "%s:%0.2f" % [color.to_html(true), alpha]
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_cache[key] = material
	return material


# --- Palette and tool options -------------------------------------------------

func palette_entries() -> Array:
	return [
		PaletteEntry.of(TOOL_AREA, "Область  Q"),
		PaletteEntry.of(TOOL_POINT, "Точка  W"),
		PaletteEntry.of(TOOL_ROUTE, "Маршрут  E"),
		PaletteEntry.of(TOOL_SELECT, "Выбор  Esc"),
	]


func selected_palette_entry() -> StringName:
	return _tool


func select_palette_entry(entry_id: StringName) -> void:
	if entry_id in TOOLS:
		_arm_tool(entry_id)


## Role first, then function — the same order as the model and as the building
## editor's panel (§11). The function list comes from the packs; with no packs
## loaded it is simply absent and the map stays engine-neutral.
func tool_options() -> Array:
	var options: Array = []
	if _tool == TOOL_AREA:
		options.append(ToolOption.header(&"role_header", "Роль"))
		for role: StringName in AREA_ROLES:
			options.append(ToolOption.of(StringName("area_%s" % role), _area_role_label(role),
				&"area_role", _area_role == role))
		if _area_role == ZoneAreaRecord.ROLE_REGION:
			_append_function_options(options, ZoneFunctionCatalog.for_area_role(_area_role))
	elif _tool == TOOL_POINT:
		options.append(ToolOption.header(&"role_header", "Роль"))
		for role: StringName in ANCHOR_ROLES:
			options.append(ToolOption.of(StringName("anchor_%s" % role),
				ZoneAnchorRecord.role_display_name(role), &"anchor_role", _anchor_role == role))
		_append_function_options(options, ZoneFunctionCatalog.for_anchor_role(_anchor_role))
	elif _tool == TOOL_ROUTE:
		options.append(ToolOption.header(&"route_header", "Маршрут"))
		options.append(ToolOption.of(&"route_new", "Начать новый маршрут"))
	if _selected_anchor() != null:
		options.append(ToolOption.header(&"link_header", "Выделенная точка", true))
		options.append(ToolOption.of(&"link_route",
			"Закончить связывание" if _linking else "В маршрут"))
	return options


func _append_function_options(options: Array, entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	options.append(ToolOption.header(&"function_header", "Функция"))
	options.append(ToolOption.of(&"function_none", NO_FUNCTION, &"function", _armed_function == &""))
	for entry: Dictionary in entries:
		var function_id: StringName = entry["id"]
		options.append(ToolOption.of(StringName("function_%s" % function_id),
			"%s · %s" % [entry.get("label", function_id), entry.get("pack", "")],
			&"function", _armed_function == function_id))


func _area_role_label(role: StringName) -> String:
	return "Регион" if role == ZoneAreaRecord.ROLE_REGION else "Оверлей"


func activate_option(option_id: StringName) -> void:
	var raw := String(option_id)
	if raw.begins_with("area_"):
		_area_role = StringName(raw.trim_prefix("area_"))
		if not ZoneFunctionCatalog.supports_area_role(_armed_function, _area_role):
			_armed_function = &""
	elif raw.begins_with("anchor_"):
		_anchor_role = StringName(raw.trim_prefix("anchor_"))
		_armed_function = _default_function_for_anchor(_anchor_role)
	elif option_id == &"function_none":
		_armed_function = &""
	elif raw.begins_with("function_"):
		_armed_function = StringName(raw.trim_prefix("function_"))
	elif option_id == &"route_new":
		_selected_route_id = &""
		context.set_status_message("Следующий клик по точке начнёт новый маршрут.")
	elif option_id == &"link_route":
		if _linking:
			_stop_linking()
		else:
			_start_linking()
	notify_ui_changed()


# --- Inspector ----------------------------------------------------------------

func inspector_lines() -> Array[String]:
	var lines: Array[String] = []
	var area := _selected_area()
	var anchor := _selected_anchor()
	var route := _selected_route()
	if area != null:
		lines.append("%s %s" % [ZoneMarkerStyle.glyph_of_role(area.role), area.display_name()])
		lines.append("клеток: %d · уровни %d…%d" % [area.cell_count(), area.y_min, area.y_max])
		lines.append_array(_issues_for(area.id))
		return lines
	if anchor != null:
		lines.append("%s %s" % [ZoneMarkerStyle.glyph_of_role(anchor.role), anchor.id])
		var cell := anchor.cell()
		lines.append("клетка %d,%d · уровень %d" % [cell.x, cell.y, int(anchor.pos.y)])
		lines.append_array(_issues_for(anchor.id))
		return lines
	if route != null:
		lines.append("／ %s" % route.id)
		lines.append("остановок: %d" % route.stops.size())
		lines.append_array(_issues_for(route.id))
		return lines
	lines.append("Инструмент: %s" % _tool_label())
	lines.append("Областей: %d · точек: %d · маршрутов: %d" % [
		context.document.zones.areas.size(), context.document.zones.anchors.size(),
		context.document.zones.routes.size()])
	if _tool == TOOL_POINT and _anchor_role == ZoneAnchorRecord.ROLE_SPAWN:
		lines.append("Будет поставлено: %s" % (
			ZoneFunctionCatalog.label_for(_armed_function) if _armed_function != &"" else "точка появления без функции"))
	if not _errors.is_empty():
		lines.append("✖ ошибок: %d" % _errors.size())
	if not _warnings.is_empty():
		lines.append("⚠ замечаний: %d" % _warnings.size())
	return lines


func _tool_label() -> String:
	match _tool:
		TOOL_AREA: return "область"
		TOOL_POINT: return "точка"
		TOOL_ROUTE: return "маршрут"
	return "выбор"


func _issues_for(zone_id: StringName) -> Array[String]:
	var found: Array[String] = []
	var needle := String(zone_id)
	for issue in _errors:
		if issue.find(needle) >= 0:
			found.append("✖ %s" % issue)
	for issue in _warnings:
		if issue.find(needle) >= 0:
			found.append("⚠ %s" % issue)
	return found


## The inspector shows the fields of the selected role and nothing else (§11). A
## panel that lists every field of every role and hides the rest behind conditions
## is what made this model feel bigger than it is.
func inspector_properties() -> Array[EntityPropertyDef]:
	var area := _selected_area()
	if area != null:
		return _area_properties(area)
	var anchor := _selected_anchor()
	if anchor != null:
		return _anchor_properties(anchor)
	var route := _selected_route()
	if route != null:
		return _route_properties()
	return []


func _area_properties(area: ZoneAreaRecord) -> Array[EntityPropertyDef]:
	var properties: Array[EntityPropertyDef] = [
		EntityPropertyDef.from_dict({"name": P_ID, "label": "Идентификатор", "type": "string", "section": "main"}),
		EntityPropertyDef.from_dict({"name": P_NAME, "label": "Имя", "type": "string", "section": "main"}),
		EntityPropertyDef.from_dict({"name": P_ROLE, "label": "Роль", "type": "enum", "section": "main",
			"options": [_area_role_label(ZoneAreaRecord.ROLE_REGION), _area_role_label(ZoneAreaRecord.ROLE_OVERLAY)]}),
		EntityPropertyDef.from_dict({"name": P_Y_MIN, "label": "Уровень с", "type": "int", "section": "transform"}),
		EntityPropertyDef.from_dict({"name": P_Y_MAX, "label": "Уровень по", "type": "int", "section": "transform"}),
	]
	if area.is_overlay():
		# §4: rights and effects are the two independent halves of an overlay, and
		# on a map the effects are the half that carries the landscape.
		properties.append(EntityPropertyDef.from_dict({"name": P_COST, "label": "Стоимость прохода",
			"type": "float", "section": "gameplay", "min": ZoneEffects.RANGES[ZoneEffects.KEY_COST].x,
			"max": ZoneEffects.RANGES[ZoneEffects.KEY_COST].y, "step": 0.1, "default": 1.0}))
		properties.append(EntityPropertyDef.from_dict({"name": P_VISION, "label": "Перекрытие обзора",
			"type": "float", "section": "gameplay", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.0}))
		properties.append(EntityPropertyDef.from_dict({"name": P_CONCEAL, "label": "Укрытие",
			"type": "float", "section": "gameplay", "min": 0.0, "max": 1.0, "step": 0.05, "default": 0.0}))
		properties.append(_audience_property(P_ALLOW, "Разрешено"))
		properties.append(_audience_property(P_DENY, "Запрещено"))
	else:
		properties.append(_function_property(ZoneFunctionCatalog.for_area_role(area.role)))
		properties.append_array(_pack_properties(area.function))
	return properties


func _anchor_properties(anchor: ZoneAnchorRecord) -> Array[EntityPropertyDef]:
	var region_ids: Array = [NO_FUNCTION]
	for area in context.document.zones.areas:
		if area.role == ZoneAreaRecord.ROLE_REGION:
			region_ids.append(String(area.id))
	var role_labels: Array = []
	for role: StringName in ANCHOR_ROLES:
		role_labels.append(ZoneAnchorRecord.role_display_name(role))
	var properties: Array[EntityPropertyDef] = [
		EntityPropertyDef.from_dict({"name": P_ID, "label": "Идентификатор", "type": "string", "section": "main"}),
		EntityPropertyDef.from_dict({"name": P_ROLE, "label": "Роль", "type": "enum", "section": "main", "options": role_labels}),
		EntityPropertyDef.from_dict({"name": P_OWNER, "label": "Владелец", "type": "enum", "section": "links", "options": region_ids}),
		EntityPropertyDef.from_dict({"name": P_FACING, "label": "Поворот", "type": "float", "section": "transform",
			"unit": "°", "min": 0.0, "max": 359.0, "step": 15.0, "default": 0.0}),
		EntityPropertyDef.from_dict({"name": P_ARC, "label": "Сектор", "type": "float", "section": "transform",
			"unit": "°", "min": 0.0, "max": 360.0, "step": 15.0, "default": 0.0}),
		EntityPropertyDef.from_dict({"name": P_Y_MIN, "label": "Уровень", "type": "int", "section": "transform"}),
	]
	properties.append(_function_property(ZoneFunctionCatalog.for_anchor_role(anchor.role)))
	properties.append(EntityPropertyDef.from_dict({"name": P_TAG, "label": "Метка", "type": "string", "section": "gameplay"}))
	if anchor.is_slot():
		var poses: Array = []
		for pose: StringName in ZoneAnchorRecord.POSES:
			poses.append(String(pose))
		properties.append(EntityPropertyDef.from_dict({"name": P_POSE, "label": "Поза", "type": "enum",
			"section": "gameplay", "options": poses}))
		var activities: Array = [NO_FUNCTION]
		for entry: Dictionary in ZoneFunctionCatalog.activities():
			activities.append(String(entry["id"]))
		properties.append(EntityPropertyDef.from_dict({"name": P_ACTIVITY, "label": "Действие", "type": "enum",
			"section": "gameplay", "options": activities}))
	if anchor.is_storage():
		properties.append(EntityPropertyDef.from_dict({"name": P_DIRECTION, "label": "Направление", "type": "enum",
			"section": "gameplay", "options": [String(ZoneAnchorRecord.DIRECTION_IN), String(ZoneAnchorRecord.DIRECTION_OUT)]}))
		properties.append(EntityPropertyDef.from_dict({"name": P_CAPACITY, "label": "Вместимость", "type": "int",
			"section": "gameplay", "min": 0, "max": 10000}))
	if anchor.is_door():
		properties.append(_audience_property(P_ALLOW, "Пропускать"))
		properties.append(_audience_property(P_DENY, "Не пропускать"))
	properties.append_array(_pack_properties(anchor.function))
	return properties


func _route_properties() -> Array[EntityPropertyDef]:
	var cycles: Array = []
	for cycle: StringName in ZoneRouteRecord.CYCLES:
		cycles.append(ZoneRouteRecord.cycle_display_name(cycle))
	return [
		EntityPropertyDef.from_dict({"name": P_ID, "label": "Идентификатор", "type": "string", "section": "main"}),
		EntityPropertyDef.from_dict({"name": P_CYCLE, "label": "Обход", "type": "enum", "section": "main", "options": cycles}),
		EntityPropertyDef.from_dict({"name": P_WAIT, "label": "Ожидание", "type": "float", "section": "gameplay",
			"unit": "мин", "min": 0.0, "max": 600.0, "step": 0.5, "default": 0.0}),
	]


func _audience_property(name: StringName, label: String) -> EntityPropertyDef:
	var options: Array = []
	for audience: StringName in ZoneAccess.AUDIENCES:
		options.append(String(audience))
	return EntityPropertyDef.from_dict({
		"name": name, "label": label, "type": "flags", "section": "gameplay", "options": options})


## The function dropdown, filled from the loaded packs and never from here. An
## author must see that "Зона появления" is content and not engine — that is what
## makes their own pack thinkable (§11).
func _function_property(entries: Array[Dictionary]) -> EntityPropertyDef:
	var options: Array = [NO_FUNCTION]
	for entry: Dictionary in entries:
		options.append(String(entry["id"]))
	return EntityPropertyDef.from_dict({
		"name": P_FUNCTION, "label": "Функция", "type": "enum", "section": "main", "options": options})


## Property rows the pack declared for the chosen function, so a pack adds a field
## without a line of editor code (§8.3).
func _pack_properties(function_id: StringName) -> Array[EntityPropertyDef]:
	var properties: Array[EntityPropertyDef] = []
	for descriptor: Dictionary in ZoneFunctionCatalog.property_schema(function_id):
		var copy := descriptor.duplicate(true)
		copy["name"] = "pack:%s" % copy.get("key", "")
		copy["section"] = "gameplay"
		properties.append(EntityPropertyDef.from_dict(copy))
	return properties


func inspector_values() -> Dictionary:
	var area := _selected_area()
	if area != null:
		var values := {
			P_ID: String(area.id), P_NAME: area.area_name,
			P_ROLE: _area_role_label(area.role),
			P_Y_MIN: area.y_min, P_Y_MAX: area.y_max,
			P_FUNCTION: String(area.function) if area.function != &"" else NO_FUNCTION,
			P_COST: float(area.effects.get(ZoneEffects.KEY_COST, 1.0)),
			P_VISION: float(area.effects.get(ZoneEffects.KEY_VISION, 0.0)),
			P_CONCEAL: float(area.effects.get(ZoneEffects.KEY_CONCEAL, 0.0)),
			P_ALLOW: _audience_flags(area.allow), P_DENY: _audience_flags(area.deny),
		}
		_merge_pack_values(values, area.function, area.properties)
		return values
	var anchor := _selected_anchor()
	if anchor != null:
		var values := {
			P_ID: String(anchor.id),
			P_ROLE: ZoneAnchorRecord.role_display_name(anchor.role),
			P_OWNER: String(anchor.owner_id) if anchor.owner_id != &"" else NO_FUNCTION,
			P_FACING: anchor.facing, P_ARC: anchor.arc, P_Y_MIN: int(anchor.pos.y),
			P_FUNCTION: String(anchor.function) if anchor.function != &"" else NO_FUNCTION,
			P_TAG: String(anchor.tag),
			P_POSE: String(anchor.pose),
			P_ACTIVITY: String(anchor.activity) if anchor.activity != &"" else NO_FUNCTION,
			P_DIRECTION: String(anchor.direction), P_CAPACITY: anchor.capacity,
			P_ALLOW: _audience_flags(anchor.allow), P_DENY: _audience_flags(anchor.deny),
		}
		_merge_pack_values(values, anchor.function, anchor.properties)
		return values
	var route := _selected_route()
	if route != null:
		return {
			P_ID: String(route.id),
			P_CYCLE: ZoneRouteRecord.cycle_display_name(route.cycle),
			P_WAIT: route.wait_minutes,
		}
	return {}


func _merge_pack_values(values: Dictionary, function_id: StringName, authored: Dictionary) -> void:
	for descriptor: Dictionary in ZoneFunctionCatalog.property_schema(function_id):
		var key := String(descriptor.get("key", ""))
		values["pack:%s" % key] = authored.get(key, descriptor.get("default", null))


func _audience_flags(mask: Array[StringName]) -> Array:
	var flags: Array = []
	for audience: StringName in mask:
		flags.append(String(audience))
	return flags


func apply_inspector_value(property_name: StringName, value: Variant) -> bool:
	var before := context.document.zones.to_json()
	var changed := false
	var area := _selected_area()
	var anchor := _selected_anchor()
	var route := _selected_route()
	if area != null:
		changed = _apply_to_area(area, property_name, value)
	elif anchor != null:
		changed = _apply_to_anchor(anchor, property_name, value)
	elif route != null:
		changed = _apply_to_route(route, property_name, value)
	if not changed:
		return false
	_commit(before, "свойство зоны")
	return true


func _apply_to_area(area: ZoneAreaRecord, property_name: StringName, value: Variant) -> bool:
	match property_name:
		P_ID:
			return _rename(area.id, StringName(value))
		P_NAME:
			area.area_name = String(value)
			return true
		P_ROLE:
			var role := ZoneAreaRecord.ROLE_REGION if String(value) == _area_role_label(
				ZoneAreaRecord.ROLE_REGION) else ZoneAreaRecord.ROLE_OVERLAY
			if role == area.role:
				return false
			area.role = role
			# Role decides which half of the record is meaningful; carrying the
			# other half over would leave a region with a denial nothing reads.
			if area.is_overlay():
				area.function = &""
				area.properties.clear()
			else:
				area.allow.clear()
				area.deny.clear()
				area.effects.clear()
			return true
		P_Y_MIN:
			area.y_min = mini(int(value), area.y_max)
			return true
		P_Y_MAX:
			area.y_max = maxi(int(value), area.y_min)
			return true
		P_FUNCTION:
			var function := &"" if String(value) == NO_FUNCTION else StringName(value)
			if function == area.function:
				return false
			area.function = function
			area.properties = ZoneFunctionCatalog.default_properties(function)
			return true
		P_COST, P_VISION, P_CONCEAL:
			return _apply_effect(area, property_name, float(value))
		P_ALLOW:
			area.allow = _to_audiences(value)
			return true
		P_DENY:
			area.deny = _to_audiences(value)
			return true
	return _apply_pack_value(area.properties, property_name, value)


func _apply_effect(area: ZoneAreaRecord, property_name: StringName, value: float) -> bool:
	var key := ZoneEffects.KEY_COST
	if property_name == P_VISION:
		key = ZoneEffects.KEY_VISION
	elif property_name == P_CONCEAL:
		key = ZoneEffects.KEY_CONCEAL
	# A neutral effect is not written to the file (§10): it changes nothing, and
	# leaving it in makes every overlay look like it does something.
	if ZoneEffects.is_neutral(key, value):
		return area.effects.erase(key)
	if is_equal_approx(float(area.effects.get(key, ZoneEffects.default_of(key))), value):
		return false
	area.effects[key] = value
	return true


func _apply_to_anchor(anchor: ZoneAnchorRecord, property_name: StringName, value: Variant) -> bool:
	match property_name:
		P_ID:
			return _rename(anchor.id, StringName(value))
		P_ROLE:
			for role: StringName in ANCHOR_ROLES:
				if ZoneAnchorRecord.role_display_name(role) == String(value) and role != anchor.role:
					anchor.role = role
					if not ZoneFunctionCatalog.supports_anchor_role(anchor.function, role):
						anchor.function = &""
						anchor.properties.clear()
					return true
			return false
		P_OWNER:
			anchor.owner_id = &"" if String(value) == NO_FUNCTION else StringName(value)
			return true
		P_FACING:
			anchor.facing = fposmod(float(value), 360.0)
			return true
		P_ARC:
			anchor.arc = clampf(float(value), 0.0, 360.0)
			return true
		P_Y_MIN:
			anchor.pos.y = float(int(value))
			return true
		P_FUNCTION:
			var function := &"" if String(value) == NO_FUNCTION else StringName(value)
			if function == anchor.function:
				return false
			anchor.function = function
			anchor.properties = ZoneFunctionCatalog.default_properties(function)
			return true
		P_TAG:
			anchor.tag = StringName(value)
			return true
		P_POSE:
			anchor.pose = StringName(value)
			return true
		P_ACTIVITY:
			anchor.activity = &"" if String(value) == NO_FUNCTION else StringName(value)
			return true
		P_DIRECTION:
			anchor.direction = StringName(value)
			return true
		P_CAPACITY:
			anchor.capacity = maxi(int(value), 0)
			return true
		P_ALLOW:
			anchor.allow = _to_audiences(value)
			return true
		P_DENY:
			anchor.deny = _to_audiences(value)
			return true
	return _apply_pack_value(anchor.properties, property_name, value)


func _apply_to_route(route: ZoneRouteRecord, property_name: StringName, value: Variant) -> bool:
	match property_name:
		P_ID:
			return _rename(route.id, StringName(value))
		P_CYCLE:
			for cycle: StringName in ZoneRouteRecord.CYCLES:
				if ZoneRouteRecord.cycle_display_name(cycle) == String(value):
					if cycle == route.cycle:
						return false
					route.cycle = cycle
					return true
			return false
		P_WAIT:
			route.wait_minutes = maxf(float(value), 0.0)
			return true
	return false


func _apply_pack_value(properties: Dictionary, property_name: StringName, value: Variant) -> bool:
	var raw := String(property_name)
	if not raw.begins_with("pack:"):
		return false
	properties[raw.trim_prefix("pack:")] = value
	return true


## Renaming is the one edit that has to reach outside the record: ids are what
## routes, rules, saves and selectors address zones by (§6), and a rename that
## left them pointing at the old name would break exactly the references the
## author cannot see from here.
func _rename(from_id: StringName, to_id: StringName) -> bool:
	if to_id == &"" or to_id == from_id:
		return false
	if not ContentId.is_valid_id(String(to_id)):
		context.set_status_message("Идентификатор вне алфавита: %s" % to_id, true)
		return false
	if context.document.zones.has_id(to_id):
		context.set_status_message("Идентификатор %s уже занят" % to_id, true)
		return false
	var zones := context.document.zones
	var area := zones.area_by_id(from_id)
	if area != null:
		area.id = to_id
		for anchor in zones.anchors:
			if anchor.owner_id == from_id:
				anchor.owner_id = to_id
		context.document.scenario.rename_zone(from_id, to_id)
	var anchor_record := zones.anchor_by_id(from_id)
	if anchor_record != null:
		anchor_record.id = to_id
		for other in zones.anchors:
			if other.is_queue() and other.target_id == from_id:
				other.target_id = to_id
	var route := zones.route_by_id(from_id)
	if route != null:
		route.id = to_id
	for existing in zones.routes:
		for index in existing.stops.size():
			if existing.stops[index] == from_id:
				existing.stops[index] = to_id
	if _selected_area_id == from_id:
		_selected_area_id = to_id
	if _selected_anchor_id == from_id:
		_selected_anchor_id = to_id
	if _selected_route_id == from_id:
		_selected_route_id = to_id
	if _link_route_id == from_id:
		_link_route_id = to_id
	return true


func _to_audiences(value: Variant) -> Array[StringName]:
	var audiences: Array[StringName] = []
	if value is Array:
		for entry: Variant in value:
			audiences.append(StringName(entry))
	return audiences


# --- Side list ----------------------------------------------------------------

func list_title() -> String:
	return "Зоны карты"


## Areas with the points they own nested under them, then top-level points, then
## routes. This is the only way to reach a point that a hill or a building is
## sitting on top of (§3.2).
func list_entries() -> Array[String]:
	_rows.clear()
	var entries: Array[String] = []
	var owned: Dictionary = {}
	for anchor: ZoneAnchorRecord in context.document.zones.anchors:
		if anchor.owner_id != &"":
			var siblings: Array = owned.get(anchor.owner_id, [])
			siblings.append(anchor)
			owned[anchor.owner_id] = siblings
	for area: ZoneAreaRecord in context.document.zones.areas:
		entries.append("%s %s%s" % [
			ZoneMarkerStyle.glyph_of_role(area.role), area.display_name(), _issue_suffix(area.id)])
		_rows.append({"kind": "area", "id": area.id})
		for anchor: ZoneAnchorRecord in owned.get(area.id, []):
			entries.append("    %s %s%s" % [
				ZoneMarkerStyle.glyph_of_role(anchor.role), anchor.id, _issue_suffix(anchor.id)])
			_rows.append({"kind": "anchor", "id": anchor.id})
	for anchor: ZoneAnchorRecord in context.document.zones.anchors:
		if anchor.owner_id != &"":
			continue
		entries.append("%s %s%s" % [
			ZoneMarkerStyle.glyph_of_role(anchor.role), anchor.id, _issue_suffix(anchor.id)])
		_rows.append({"kind": "anchor", "id": anchor.id})
	for route: ZoneRouteRecord in context.document.zones.routes:
		entries.append("／ %s · %d%s" % [route.id, route.stops.size(), _issue_suffix(route.id)])
		_rows.append({"kind": "route", "id": route.id})
	return entries


func _issue_suffix(zone_id: StringName) -> String:
	var issues := _issues_for(zone_id)
	if issues.is_empty():
		return ""
	return "  ⚠%d" % issues.size()


func selected_list_index() -> int:
	for index in _rows.size():
		var row: Dictionary = _rows[index]
		match String(row["kind"]):
			"area":
				if row["id"] == _selected_area_id:
					return index
			"anchor":
				if row["id"] == _selected_anchor_id:
					return index
			"route":
				if row["id"] == _selected_route_id:
					return index
	return -1


func select_list_entry(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	var row: Dictionary = _rows[index]
	match String(row["kind"]):
		"area":
			_select_area(row["id"])
		"anchor":
			_select_anchor(row["id"])
		"route":
			_selected_route_id = row["id"]
			_selected_area_id = &""
			_selected_anchor_id = &""
			rebuild_views()
			notify_ui_changed()
	_focus_camera_on_selection()


func _focus_camera_on_selection() -> void:
	if context.camera == null:
		return
	var anchor := _selected_anchor()
	if anchor != null:
		context.camera.focus_on(_world_position_of(anchor))
		return
	var area := _selected_area()
	if area == null or area.rects.is_empty():
		return
	var centre := Vector2(area.rects[0].position) + Vector2(area.rects[0].size) * 0.5
	var cell_size := context.terrain.cell_size
	context.camera.focus_on(Vector3(centre.x * cell_size, 0.0, centre.y * cell_size))


func empty_list_hint() -> String:
	return "Нарисуйте область (Q) или поставьте точку (W) на карте"


# --- Status -------------------------------------------------------------------

## §3.2 asks the status line to answer "почему сюда не идут": the cell, its
## height, which zones cover it, what they forbid, and how many findings the
## validator has. It is the first debugging tool, before any test run.
func status_text() -> String:
	if context.brush == null or not context.brush.has_hover:
		return "Зоны: Q — область · W — точка · E — маршрут · Shift+ПКМ — стереть"
	var cell := context.brush.hovered_cell
	var parts: Array[String] = ["клетка %d,%d" % [cell.x, cell.y],
		"уровень %d" % context.terrain.height_of(cell)]
	var covering: Array[String] = []
	var denied: Array[String] = []
	var cost := 1.0
	for area in context.document.zones.areas:
		if not area.contains_cell(cell):
			continue
		covering.append(area.display_name())
		if area.is_overlay():
			cost *= float(area.effects.get(ZoneEffects.KEY_COST, 1.0))
			for audience: StringName in ZoneAccess.AUDIENCES:
				if not ZoneAccess.permits(area.allow, area.deny, audience) and String(audience) not in denied:
					denied.append(String(audience))
	if not covering.is_empty():
		parts.append("зоны: %s" % ", ".join(covering))
	if not is_equal_approx(cost, 1.0):
		parts.append("проход ×%.1f" % cost)
	if not denied.is_empty():
		parts.append("нельзя: %s" % ", ".join(denied))
	if not _errors.is_empty():
		parts.append("✖ %d" % _errors.size())
	if not _warnings.is_empty():
		parts.append("⚠ %d" % _warnings.size())
	return " · ".join(parts)
