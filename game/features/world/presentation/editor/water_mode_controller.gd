class_name WaterModeController
extends MapEditorMode

## Mode 3, water (map_editor.md §5.3).
##
## Outline, level, type, current and ice. The palette is the registry of
## `WaterBody` plus one "new body" entry per type, because §9.2 puts the type on
## the body and not on the bottom: an author picks *which lake*, and the colour,
## the wave and the fish come with it. A material brush cannot express that, which
## is the whole reason this is a mode of its own rather than a paint on the
## surface mode.
##
## What the mode does NOT do is decide passability. Depth against the ground, the
## ford rule and the load the ice carries all live in the published navigation
## field (§9.7), so the overlay in this editor answers "can anyone cross this
## river" with the same code the game runs.

const OPTION_BRUSH_UP := &"brush_up"
const OPTION_BRUSH_DOWN := &"brush_down"
const OPTION_LEVEL_UP := &"level_up"
const OPTION_LEVEL_DOWN := &"level_down"
const OPTION_TOOL_PREFIX := "tool_"
const OPTION_ICE := &"ice"
const OPTION_BODY_ICE := &"body_ice"
const OPTION_DELETE_BODY := &"delete_body"
const OPTION_FLOW_DIR := &"flow_dir"
const OPTION_FLOW_STRENGTH := &"flow_strength"

const NEW_BODY_PREFIX := "new_"

var _painting := false
## What a river stroke writes into the body's sparse flow map (§9.3). Brush state,
## not a separate tool: an author draws the channel and its current in one pass.
var _flow_direction := SlopeCatalog.DIR_E
var _flow_strength := 0


func _init() -> void:
	id = &"water"
	title = "Вода"


func activate() -> void:
	_painting = false


func deactivate() -> void:
	_painting = false
	if context != null and context.water_brush != null:
		context.water_brush.clear_hover()


func process(_delta: float) -> void:
	var brush := context.water_brush
	var was := brush.hovered_cell
	var had := brush.has_hover
	brush.update_hover(context.camera, context.space_state(), context.mouse_position())
	# The terrain brush owns the shared hover marker, so it is kept on the same
	# column: otherwise the marker would sit wherever the author last left the
	# height tool while they paint water somewhere else.
	context.brush.update_hover(context.camera, context.space_state(), context.mouse_position())
	if _painting and brush.has_hover and (not had or was != brush.hovered_cell):
		_stroke()


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed:
				context.set_edit_label("вода")
				context.water_brush.apply_secondary()
			notify_ui_changed()
			return true
		if button.button_index != MOUSE_BUTTON_LEFT:
			return false
		_painting = button.pressed
		if button.pressed:
			_stroke()
		notify_ui_changed()
		return true
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return _handle_key(event as InputEventKey)
	return false


func _handle_key(event: InputEventKey) -> bool:
	var brush := context.water_brush
	match event.keycode:
		KEY_TAB:
			brush.cycle_tool()
		KEY_BRACKETLEFT:
			brush.adjust_brush_size(-1)
		KEY_BRACKETRIGHT:
			brush.adjust_brush_size(1)
		KEY_EQUAL, KEY_KP_ADD:
			brush.adjust_level(1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			brush.adjust_level(-1)
		KEY_G:
			brush.pick_level_from_ground()
		KEY_F:
			context.set_edit_label("лёд")
			brush.toggle_body_ice()
		KEY_I:
			brush.cycle_ice_thickness()
		KEY_V:
			_cycle_flow_direction()
		KEY_C:
			_cycle_flow_strength()
		_:
			return false
	notify_ui_changed()
	return true


## One stroke: the brush edit, and — on a river with a current dialled in — the
## flow written into the body for the cells it just filled. Flow belongs to the
## body (§9.2), so it is not part of the cell transaction and not on the undo
## stack; it is authored data about a channel, like its name.
func _stroke() -> void:
	context.set_edit_label(_edit_label())
	var brush := context.water_brush
	brush.apply()
	if brush.tool == WaterBrushController.TOOL_PAINT and _flow_strength > 0:
		_write_flow(brush.brush_cells(brush.hovered_cell))


func _edit_label() -> String:
	match context.water_brush.tool:
		WaterBrushController.TOOL_ERASE: return "осушение"
		WaterBrushController.TOOL_FLOOD: return "залив низины"
		WaterBrushController.TOOL_FREEZE: return "лёд"
	return "вода"


func _write_flow(cells: Array[Vector2i]) -> void:
	var body := context.water.body(context.water_brush.body_id)
	if body == null or body.type != WaterBody.Type.RIVER:
		return
	for cell: Vector2i in cells:
		if context.water.body_id_at(cell) == body.id:
			body.set_flow(cell, _flow_direction, _flow_strength)
	# A current that stops a ford is a passability change (§9.7), so the field has
	# to hear about it even though no cell record moved.
	if context.nav_publisher != null:
		context.nav_publisher.refresh_cells(cells)


func _cycle_flow_direction() -> void:
	var order := SlopeCatalog.ORTHOGONAL_DIRECTIONS
	_flow_direction = order[(order.find(_flow_direction) + 1) % order.size()]


func _cycle_flow_strength() -> void:
	_flow_strength = (_flow_strength + 1) % (WaterBody.MAX_FLOW_STRENGTH + 1)


# --- Panels -------------------------------------------------------------------

## The registry first, then one "new" entry per type. Both in the same palette on
## purpose: creating a lake and selecting it are the same gesture as far as the
## author is concerned, and a separate "add" button would put the type twice in
## the interface.
func palette_entries() -> Array:
	var entries: Array = []
	for body: WaterBody in context.water.bodies():
		entries.append(PaletteEntry.of(
			StringName("body_%d" % body.id),
			"%s (%s)" % [body.name, body.type_id()],
			body.colour,
		))
	for type_index in WaterBody.TYPE_IDS.size():
		var body_type := type_index as WaterBody.Type
		entries.append(PaletteEntry.of(
			StringName("%s%s" % [NEW_BODY_PREFIX, WaterBody.type_id_of(body_type)]),
			"+ %s" % WaterBody.type_id_of(body_type),
			WaterBody.of_type(WaterBody.MIN_ID, body_type).colour.darkened(0.35),
		))
	return entries


func selected_palette_entry() -> StringName:
	var body_id := context.water_brush.body_id
	return StringName("body_%d" % body_id) if body_id != WaterBody.NO_BODY else &""


func select_palette_entry(entry_id: StringName) -> void:
	var text := String(entry_id)
	if text.begins_with(NEW_BODY_PREFIX):
		context.water_brush.create_body(WaterBody.type_of_id(StringName(text.trim_prefix(NEW_BODY_PREFIX))))
		context.document.mark_dirty()
		notify_ui_changed()
		return
	if text.begins_with("body_"):
		context.water_brush.select_body(text.trim_prefix("body_").to_int())
		notify_ui_changed()


func tool_options() -> Array:
	var brush := context.water_brush
	var options: Array = []
	for tool: StringName in WaterBrushController.TOOLS:
		options.append(ToolOption.of(
			StringName("%s%s" % [OPTION_TOOL_PREFIX, tool]), String(tool), &"tools", brush.tool == tool,
		))
	options.append(ToolOption.of(OPTION_BRUSH_DOWN, "Кисть −"))
	options.append(ToolOption.of(OPTION_BRUSH_UP, "Кисть +"))
	options.append(ToolOption.of(OPTION_LEVEL_DOWN, "Уровень −"))
	options.append(ToolOption.of(OPTION_LEVEL_UP, "Уровень +"))
	options.append(ToolOption.of(OPTION_ICE, "Толщина льда: %d" % brush.ice_thickness))
	options.append(ToolOption.of(OPTION_BODY_ICE, "Заморозить водоём"))
	options.append(ToolOption.of(OPTION_FLOW_DIR, "Течение: %s" % TerrainBrushController.direction_name(_flow_direction)))
	options.append(ToolOption.of(OPTION_FLOW_STRENGTH, "Сила течения: %d" % _flow_strength))
	options.append(ToolOption.of(OPTION_DELETE_BODY, "Удалить водоём"))
	return options


func activate_option(option_id: StringName) -> void:
	var brush := context.water_brush
	var text := String(option_id)
	if text.begins_with(OPTION_TOOL_PREFIX):
		brush.tool = StringName(text.trim_prefix(OPTION_TOOL_PREFIX))
		notify_ui_changed()
		return
	match option_id:
		OPTION_BRUSH_UP:
			brush.adjust_brush_size(1)
		OPTION_BRUSH_DOWN:
			brush.adjust_brush_size(-1)
		OPTION_LEVEL_UP:
			brush.adjust_level(1)
		OPTION_LEVEL_DOWN:
			brush.adjust_level(-1)
		OPTION_ICE:
			brush.cycle_ice_thickness()
		OPTION_BODY_ICE:
			context.set_edit_label("лёд")
			brush.toggle_body_ice()
		OPTION_FLOW_DIR:
			_cycle_flow_direction()
		OPTION_FLOW_STRENGTH:
			_cycle_flow_strength()
		OPTION_DELETE_BODY:
			if brush.remove_selected_body():
				context.document.mark_dirty()
	notify_ui_changed()


func inspector_lines() -> Array[String]:
	var brush := context.water_brush
	var body := context.water.body(brush.body_id)
	var lines: Array[String] = []
	lines.append("Инструмент: %s" % brush.tool)
	lines.append("Кисть: %d×%d" % [brush.brush_size * 2 - 1, brush.brush_size * 2 - 1])
	lines.append("Уровень: %d (%.1f м)" % [brush.level, float(brush.level) * TerrainGrid.HEIGHT_STEP])
	lines.append("")
	if body == null:
		lines.append("Водоём не выбран — создайте его в палитре")
	else:
		lines.append("Водоём: %s" % body.name)
		lines.append("Тип: %s, %s" % [body.type_id(), "солёная" if body.salinity == WaterBody.Salinity.SALT else "пресная"])
		lines.append("Волна: %.2f м, пена ×%.2f" % [body.wave_amplitude, body.foam_strength])
		lines.append("Замерзает: %s" % ("да" if body.freezes else "нет"))
		lines.append("Клеток течения: %d" % body.flow.size())
	lines.append("")
	lines.append("Течение кисти: %s, сила %d" % [TerrainBrushController.direction_name(_flow_direction), _flow_strength])
	lines.append("Толщина льда: %d (пешеход %d, тележка %d)" % [
		brush.ice_thickness,
		TravelerProfile.MIN_ICE_THICKNESS_PEDESTRIAN,
		TravelerProfile.MIN_ICE_THICKNESS_CART,
	])
	lines.append("")
	lines.append("ЛКМ — инструмент, ПКМ — обратное действие, Tab — смена инструмента")
	lines.append("+ / − уровень, G — взять уровень с рельефа, [ ] — размер кисти")
	lines.append("F — заморозить/растопить водоём, I — толщина льда")
	lines.append("V — направление течения, C — сила течения")
	return lines


func list_title() -> String:
	return "Водоёмы"


func empty_list_hint() -> String:
	return "Ни одного водоёма — создайте его в палитре"


func list_entries() -> Array[String]:
	var entries: Array[String] = []
	for body: WaterBody in context.water.bodies():
		entries.append("%d · %s · %s · уровень %d" % [body.id, body.name, body.type_id(), body.surface_height])
	return entries


## The status line is where an author checks the rule they cannot see: depth is
## what decides a ford, and a cell that looks like water at a glance may be a
## crossing or a wall.
func status_text() -> String:
	var brush := context.water_brush
	if not brush.has_hover:
		return "клетка —"
	var cell := brush.hovered_cell
	var ground := context.terrain.height_of(cell)
	if not context.water.is_wet(context.terrain, cell):
		return "клетка %d,%d · суша · рельеф %d" % [cell.x, cell.y, ground]
	var body := context.water.body_at(cell)
	var depth := context.water.depth_steps_at(context.terrain, cell)
	return "клетка %d,%d · %s · дно %d · уровень %d · глубина %d (%.1f м) · %s%s" % [
		cell.x, cell.y, body.name if body != null else "?", ground, context.water.height_of(cell),
		depth, float(depth) * TerrainGrid.HEIGHT_STEP,
		"брод" if context.water.is_ford(context.terrain, cell) else "глубоко",
		" · лёд %d" % context.water.ice_thickness_at(cell) if context.water.is_frozen(cell) else "",
	]
