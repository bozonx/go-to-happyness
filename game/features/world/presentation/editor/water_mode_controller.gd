class_name WaterModeController
extends MapEditorMode

## Mode 3, water (map_editor.md §5.3).
##
## Outline, level, type, current and ice. The palette expresses the author's
## primary choice — water or lava — while clicks resolve that intent to the
## `WaterBody` registry automatically. Existing liquid selects its body; dry
## ground creates a new one. The registry remains visible in the side list.
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
const OPTION_FLOW_DIR := &"flow_dir"
const OPTION_FLOW_STRENGTH := &"flow_strength"
const OPTION_ACTION_ICE := &"action_ice"

var _painting := false
## What a river stroke writes into the body's sparse flow map (§9.3). Brush state,
## not a separate tool: an author draws the channel and its current in one pass.
var _flow_direction := SlopeCatalog.DIR_E
var _flow_strength := 0


func _init() -> void:
	id = &"water"
	title = "Вода"
	icon = "🌊"


func activate() -> void:
	_painting = false
	if context != null and context.water_service != null:
		context.water_service.prune_empty_bodies()
	if context != null and context.water_brush != null:
		context.water_brush.tool = WaterBrushController.TOOL_FLOOD
		var bodies := context.water.bodies()
		var found_non_empty := false
		for b in bodies:
			if context.water.cells_of_body(b.id).size() > 0:
				context.water_brush.select_body(b.id)
				found_non_empty = true
				break
		if not found_non_empty:
			context.water_brush.body_id = WaterBody.NO_BODY


func deactivate() -> void:
	_painting = false
	if context != null and context.water_service != null:
		context.water_service.prune_empty_bodies()
	if context != null and context.water_brush != null:
		context.water_brush.clear_hover()


func clear_hover() -> void:
	if context != null and context.water_brush != null:
		context.water_brush.clear_hover()


func hover_brush() -> BaseBrushController:
	return context.water_brush if context != null else null


## Flood takes its extent from the basin, not from the brush, so the size control
## belongs to the tools that stamp a square.
func adjust_brush_size(delta: int) -> void:
	if context != null and context.water_brush != null and _brush_has_size():
		context.water_brush.adjust_brush_size(delta)


func _brush_has_size() -> bool:
	if context == null or context.water_brush == null:
		return false
	return context.water_brush.tool in [WaterBrushController.TOOL_FREEZE, WaterBrushController.TOOL_THAW]


func process(_delta: float) -> void:
	var brush := context.water_brush
	var was := brush.hovered_cell
	var had := brush.has_hover
	brush.update_hover(context.camera, context.space_state(), context.mouse_position())
	if _painting and brush.has_hover and (not had or was != brush.hovered_cell):
		_stroke()


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if _handle_common_mouse(button):
			return true
		if button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed and button.shift_pressed:
				context.water_brush.update_hover(context.camera, context.space_state(), context.mouse_position())
				context.set_edit_label("вода")
				context.water_brush.apply_secondary()
				notify_ui_changed()
				return true
			return false
		if button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if button.pressed and button.shift_pressed:
			context.water_brush.update_hover(context.camera, context.space_state(), context.mouse_position())
			context.water_brush.pick_from_cell()
			notify_ui_changed()
			return true
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
			if _brush_has_size():
				brush.adjust_brush_size(-1)
		KEY_BRACKETRIGHT:
			if _brush_has_size():
				brush.adjust_brush_size(1)
		KEY_EQUAL, KEY_KP_ADD:
			if brush.tool == WaterBrushController.TOOL_FLOOD:
				brush.adjust_level(1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			if brush.tool == WaterBrushController.TOOL_FLOOD:
				brush.adjust_level(-1)
		KEY_G:
			if brush.tool == WaterBrushController.TOOL_FLOOD:
				brush.pick_level_from_ground()
		KEY_F:
			brush.tool = WaterBrushController.TOOL_FREEZE
		KEY_R:
			brush.tool = WaterBrushController.TOOL_THAW
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
## flow written through `WaterService` so it is undoable and republishes
## navigation like every other water edit.
func _stroke() -> void:
	context.set_edit_label(_edit_label())
	var brush := context.water_brush
	# A mouse press may arrive before this frame's hover update. Refresh it here
	# so drain always resolves the body actually clicked, not the previous cell.
	brush.update_hover(context.camera, context.space_state(), context.mouse_position())
	brush.apply()
	if brush.tool == WaterBrushController.TOOL_FLOOD and _flow_strength > 0 and _selected_body_has_flow():
		context.water_service.set_flow(
			brush.brush_cells(brush.hovered_cell),
			brush.body_id,
			_flow_direction,
			_flow_strength,
		)


func _edit_label() -> String:
	match context.water_brush.tool:
		WaterBrushController.TOOL_FLOOD: return "наполнение водоёма"
		WaterBrushController.TOOL_DRAIN: return "осушение"
		WaterBrushController.TOOL_FREEZE: return "заморозка"
		WaterBrushController.TOOL_THAW: return "разморозка"
	return "вода"


func _cycle_flow_direction() -> void:
	var order := SlopeCatalog.ORTHOGONAL_DIRECTIONS
	_flow_direction = order[(order.find(_flow_direction) + 1) % order.size()]


func _cycle_flow_strength() -> void:
	_flow_strength = (_flow_strength + 1) % (WaterBody.MAX_FLOW_STRENGTH + 1)


const OPTION_WATER := &"liquid_water"
const OPTION_LAVA := &"liquid_lava"
const OPTION_LAKE := &"type_lake"
const OPTION_RIVER := &"type_river"
const OPTION_SEA := &"type_sea"
const OPTION_AUTO_LEVEL := &"auto_level"

# --- Panels -------------------------------------------------------------------

func palette_entries() -> Array:
	return [
		PaletteEntry.of(OPTION_WATER, "Вода", Color(0.2, 0.55, 0.85, 1.0)),
		PaletteEntry.of(OPTION_LAVA, "Лава", Color(0.95, 0.3, 0.08, 1.0)),
	]


func selected_palette_entry() -> StringName:
	return OPTION_LAVA if context.water_brush.liquid_category == &"lava" else OPTION_WATER


func select_palette_entry(entry_id: StringName) -> void:
	if entry_id == OPTION_LAVA:
		context.water_brush.select_liquid_category(&"lava")
	elif entry_id == OPTION_WATER:
		context.water_brush.select_liquid_category(&"water")
	notify_ui_changed()


func tool_options() -> Array:
	var brush := context.water_brush
	var options: Array = []
	options.append(ToolOption.of(StringName("%s%s" % [OPTION_TOOL_PREFIX, WaterBrushController.TOOL_FLOOD]), "Залить", &"tools", brush.tool == WaterBrushController.TOOL_FLOOD))
	options.append(ToolOption.of(StringName("%s%s" % [OPTION_TOOL_PREFIX, WaterBrushController.TOOL_DRAIN]), "Удалить", &"tools", brush.tool == WaterBrushController.TOOL_DRAIN))
	options.append(ToolOption.of(OPTION_ACTION_ICE, "Лёд", &"tools", brush.tool in [WaterBrushController.TOOL_FREEZE, WaterBrushController.TOOL_THAW]))
	if brush.tool in [WaterBrushController.TOOL_FREEZE, WaterBrushController.TOOL_THAW]:
		options.append(ToolOption.of(StringName("%s%s" % [OPTION_TOOL_PREFIX, WaterBrushController.TOOL_FREEZE]), "Заморозить", &"ice_action", brush.tool == WaterBrushController.TOOL_FREEZE))
		options.append(ToolOption.of(StringName("%s%s" % [OPTION_TOOL_PREFIX, WaterBrushController.TOOL_THAW]), "Убрать лёд", &"ice_action", brush.tool == WaterBrushController.TOOL_THAW))
	if brush.liquid_category == &"water":
		options.append(ToolOption.of(OPTION_LAKE, "Озеро", &"water_type", brush.water_type == WaterBody.Type.LAKE))
		options.append(ToolOption.of(OPTION_RIVER, "Река", &"water_type", brush.water_type == WaterBody.Type.RIVER))
		options.append(ToolOption.of(OPTION_SEA, "Море", &"water_type", brush.water_type == WaterBody.Type.SEA))
	if brush.tool == WaterBrushController.TOOL_FLOOD:
		options.append(ToolOption.of(OPTION_AUTO_LEVEL, "Авто", &"level", brush.auto_level))
		options.append(ToolOption.of(&"water_level", "Уровень %d" % brush.level, &"level", false, true))
		options.append(ToolOption.of(OPTION_LEVEL_DOWN, "−", &"level"))
		options.append(ToolOption.of(OPTION_LEVEL_UP, "+", &"level"))
	if _brush_has_size():
		options.append(ToolOption.of(&"brush_size", "Кисть: %d" % (brush.brush_size - 1), &"brush", false, true))
		options.append(ToolOption.of(OPTION_BRUSH_DOWN, "−", &"brush"))
		options.append(ToolOption.of(OPTION_BRUSH_UP, "+", &"brush"))
	if brush.tool == WaterBrushController.TOOL_FREEZE:
		options.append(ToolOption.of(OPTION_ICE, "Толщина льда: %d" % brush.ice_thickness))
	if brush.tool == WaterBrushController.TOOL_FLOOD and brush.active_body_type() in [WaterBody.Type.RIVER, WaterBody.Type.LAVA]:
		options.append(ToolOption.of(OPTION_FLOW_DIR, "Течение: %s" % TerrainBrushController.direction_name(_flow_direction)))
		options.append(ToolOption.of(OPTION_FLOW_STRENGTH, "Сила течения: %d" % _flow_strength))
	return options


func activate_option(option_id: StringName) -> void:
	var brush := context.water_brush
	var text := String(option_id)
	if text.begins_with(OPTION_TOOL_PREFIX):
		brush.tool = StringName(text.trim_prefix(OPTION_TOOL_PREFIX))
		notify_ui_changed()
		return
	match option_id:
		OPTION_ACTION_ICE:
			if brush.tool not in [WaterBrushController.TOOL_FREEZE, WaterBrushController.TOOL_THAW]:
				brush.tool = WaterBrushController.TOOL_FREEZE
		OPTION_LAKE:
			brush.select_water_type(WaterBody.Type.LAKE)
		OPTION_RIVER:
			brush.select_water_type(WaterBody.Type.RIVER)
		OPTION_SEA:
			brush.select_water_type(WaterBody.Type.SEA)
		OPTION_AUTO_LEVEL:
			brush.auto_level = not brush.auto_level
		OPTION_BRUSH_UP:
			brush.adjust_brush_size(1)
		OPTION_BRUSH_DOWN:
			brush.adjust_brush_size(-1)
		OPTION_LEVEL_UP:
			brush.auto_level = false
			brush.adjust_level(1)
		OPTION_LEVEL_DOWN:
			brush.auto_level = false
			brush.adjust_level(-1)
		OPTION_ICE:
			brush.cycle_ice_thickness()
		OPTION_FLOW_DIR:
			_cycle_flow_direction()
		OPTION_FLOW_STRENGTH:
			_cycle_flow_strength()
	notify_ui_changed()


func _selected_body_has_flow() -> bool:
	var body := context.water.body(context.water_brush.body_id)
	return body != null and (body.type == WaterBody.Type.RIVER or body.type == WaterBody.Type.LAVA)


func inspector_lines() -> Array[String]:
	var brush := context.water_brush
	var body := context.water.body(brush.body_id)
	var lines: Array[String] = []
	lines.append("Инструмент: %s" % brush.tool)
	if _brush_has_size():
		lines.append("Кисть: %d×%d" % [brush.brush_size * 2 - 1, brush.brush_size * 2 - 1])
	if brush.tool == WaterBrushController.TOOL_FLOOD:
		lines.append("Уровень: %d (%.1f м)" % [brush.level, float(brush.level) * TerrainGrid.HEIGHT_STEP])
	lines.append("")
	if body == null:
		lines.append("ЛКМ по суше создаст новый водоём")
	else:
		lines.append("Водоём: %s" % body.name)
		lines.append("Тип: %s, %s" % [body.type_id(), "солёная" if body.salinity == WaterBody.Salinity.SALT else "пресная"])
		lines.append("Волна: %.2f м, пена ×%.2f" % [body.wave_amplitude, body.foam_strength])
		lines.append("Замерзает: %s" % ("да" if body.freezes else "нет"))
		lines.append("Клеток течения: %d" % body.flow.size())
	lines.append("")
	if _selected_body_has_flow():
		lines.append("Течение Flood: %s, сила %d" % [TerrainBrushController.direction_name(_flow_direction), _flow_strength])
	if brush.tool == WaterBrushController.TOOL_FREEZE:
		lines.append("Толщина льда: %d (пешеход %d, тележка %d)" % [
			brush.ice_thickness,
			TravelerProfile.MIN_ICE_THICKNESS_PEDESTRIAN,
			TravelerProfile.MIN_ICE_THICKNESS_CART,
		])
	lines.append("")
	lines.append("ЛКМ по воде выбирает и редактирует этот водоём")
	lines.append("ЛКМ по суше создаёт новый водоём выбранного типа")
	lines.append("Удалить или Shift+ПКМ удаляет весь водоём; океан защищён")
	return lines


func list_title() -> String:
	return "Водоёмы"


func empty_list_hint() -> String:
	return "Ни одного водоёма — выберите воду или лаву и кликните по карте"


func list_entries() -> Array[String]:
	var entries: Array[String] = []
	for body: WaterBody in context.water.bodies():
		if context.water.cells_of_body(body.id).size() > 0:
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
