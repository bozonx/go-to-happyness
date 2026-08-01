class_name WaterModeController
extends MapEditorMode

## Mode 3, water (map_editor.md §5.3).
##
## Outline, level, type, current and ice. The palette expresses the author's
## primary choice — water or lava — while clicks resolve that intent to the
## `WaterBody` registry automatically. Existing liquid selects its body; dry
## ground creates a new one. The registry remains visible in the side list.

const OPTION_BRUSH_UP := &"brush_up"
const OPTION_BRUSH_DOWN := &"brush_down"
const OPTION_LEVEL_UP := &"level_up"
const OPTION_LEVEL_DOWN := &"level_down"
const OPTION_TOOL_PREFIX := "tool_"
const OPTION_ICE := &"ice"
const OPTION_FLOW_DIR := &"flow_dir"
const OPTION_FLOW_STRENGTH := &"flow_strength"
const OPTION_ACTION_ICE := &"action_ice"
const OPTION_DELETE_BODY := &"delete_body"

const OPTION_WATER := &"liquid_water"
const OPTION_LAVA := &"liquid_lava"
const OPTION_LAKE := &"type_lake"
const OPTION_RIVER := &"type_river"
const OPTION_SEA := &"type_sea"
const OPTION_AUTO_LEVEL := &"auto_level"

const ROW_BODY_TOOLS := &"row_body_tools"
const ROW_BODY_ACTIONS := &"row_body_actions"
const ROW_LIQUID_CAT := &"row_liquid_cat"
const ROW_WATER_TYPE := &"row_water_type"
const ROW_LEVEL := &"row_level"
const ROW_BRUSH_TOOLS := &"row_brush_tools"
const ROW_FLOW_PARAMS := &"row_flow_params"
const ROW_BRUSH_SIZE := &"row_brush_size"

var _painting := false


func _init() -> void:
	id = &"water"
	title = "Вода"
	icon = "🌊"


func activate() -> void:
	_painting = false
	if context != null and context.water_service != null:
		context.water_service.prune_empty_bodies()
		if not context.water_service.edit_committed.is_connected(_on_water_edit_committed):
			context.water_service.edit_committed.connect(_on_water_edit_committed)
	if context != null and context.water_brush != null:
		if not context.water_brush.body_selected.is_connected(_on_body_selected):
			context.water_brush.body_selected.connect(_on_body_selected)
		context.water_brush.tool = WaterBrushController.TOOL_FLOOD
		context.water_brush.body_id = WaterBody.NO_BODY
	_update_highlight()


func _on_body_selected(_body_id: int) -> void:
	_update_highlight()


func _on_water_edit_committed(_delta: Variant) -> void:
	_update_highlight()


func deactivate() -> void:
	_painting = false
	if context != null and context.water_service != null:
		context.water_service.prune_empty_bodies()
		if context.water_service.edit_committed.is_connected(_on_water_edit_committed):
			context.water_service.edit_committed.disconnect(_on_water_edit_committed)
	if context != null and context.water_brush != null:
		context.water_brush.clear_hover()
		if context.water_brush.body_selected.is_connected(_on_body_selected):
			context.water_brush.body_selected.disconnect(_on_body_selected)
	if context != null and context.water_highlight != null:
		context.water_highlight.hide_highlight()
	if context != null and context.water_flood_preview != null:
		context.water_flood_preview.hide_preview()


func clear_hover() -> void:
	if context != null and context.water_brush != null:
		context.water_brush.clear_hover()
	if context != null and context.water_flood_preview != null:
		context.water_flood_preview.hide_preview()


func hover_brush() -> BaseBrushController:
	return context.water_brush if context != null else null


func adjust_brush_size(delta: int) -> void:
	if context != null and context.water_brush != null and _brush_has_size():
		context.water_brush.adjust_brush_size(delta)


func _brush_has_size() -> bool:
	if context == null or context.water_brush == null:
		return false
	return context.water_brush.tool in [
		WaterBrushController.TOOL_FLOW,
		WaterBrushController.TOOL_FREEZE,
		WaterBrushController.TOOL_THAW,
	]


func process(_delta: float) -> void:
	var brush := context.water_brush
	var was := brush.hovered_cell
	var had := brush.has_hover
	brush.update_hover(context.camera, context.space_state(), context.mouse_position())
	if _painting and brush.has_hover and (not had or was != brush.hovered_cell):
		_stroke()
	_update_flood_preview()


func _update_flood_preview() -> void:
	if context == null or context.water_flood_preview == null or context.water == null or context.terrain == null:
		return
	var brush := context.water_brush
	if brush == null or not brush.has_hover or brush.tool != WaterBrushController.TOOL_FLOOD:
		context.water_flood_preview.hide_preview()
		return

	var cell := brush.hovered_cell
	if context.water.has_water(cell):
		context.water_flood_preview.hide_preview()
		return

	var preview_level := brush.level
	if brush.auto_level and context.terrain != null:
		preview_level = context.terrain.height_of(cell) + 1

	if context.terrain.height_of(cell) >= preview_level:
		context.water_flood_preview.hide_preview()
		return

	var flood_cells := context.water.flood_cells(context.terrain, cell, preview_level)
	if flood_cells.is_empty():
		context.water_flood_preview.hide_preview()
		return

	context.water_flood_preview.show_preview(flood_cells, preview_level)


func handle_input(event: InputEvent) -> bool:
	var brush := context.water_brush
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			if brush != null and brush.body_id != WaterBody.NO_BODY:
				brush.body_id = WaterBody.NO_BODY
				notify_ui_changed()
				_update_highlight()
				return true
		return _handle_key(key_event)

	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if _handle_common_mouse(button):
			return true
		if button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed and button.shift_pressed:
				brush.update_hover(context.camera, context.space_state(), context.mouse_position())
				context.set_edit_label("вода")
				brush.apply_secondary()
				notify_ui_changed()
				_update_highlight()
				return true
			return false
		if button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if button.pressed and button.shift_pressed:
			brush.update_hover(context.camera, context.space_state(), context.mouse_position())
			brush.pick_from_cell()
			notify_ui_changed()
			_update_highlight()
			return true
		_painting = button.pressed
		if button.pressed:
			_handle_left_click()
		notify_ui_changed()
		_update_highlight()
		return true

	return false


func _handle_left_click() -> void:
	var brush := context.water_brush
	brush.update_hover(context.camera, context.space_state(), context.mouse_position())
	if not brush.has_hover:
		return

	var cell := brush.hovered_cell

	if brush.tool == WaterBrushController.TOOL_FLOOD:
		if not context.water.has_water(cell):
			var preview_level := brush.level
			if brush.auto_level and context.terrain != null:
				preview_level = context.terrain.height_of(cell) + 1

			# If ground is >= preview_level (cannot flood here):
			if context.terrain.height_of(cell) >= preview_level:
				if brush.body_id != WaterBody.NO_BODY:
					brush.body_id = WaterBody.NO_BODY
					_update_highlight()
					notify_ui_changed()
				return

			# If a body was previously selected, first click on dry land deselects it
			if brush.body_id != WaterBody.NO_BODY:
				brush.body_id = WaterBody.NO_BODY
				_update_highlight()
				notify_ui_changed()
				return

	_stroke()


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
			brush.adjust_level(1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			brush.adjust_level(-1)
		KEY_G:
			brush.pick_level_from_ground()
		KEY_F:
			brush.tool = WaterBrushController.TOOL_FLOW if brush.tool != WaterBrushController.TOOL_FLOW else WaterBrushController.TOOL_FLOOD
		KEY_Z:
			brush.tool = WaterBrushController.TOOL_FREEZE if brush.tool != WaterBrushController.TOOL_FREEZE else WaterBrushController.TOOL_FLOOD
		KEY_R:
			brush.tool = WaterBrushController.TOOL_THAW if brush.tool != WaterBrushController.TOOL_THAW else WaterBrushController.TOOL_FLOOD
		KEY_I:
			brush.cycle_ice_thickness()
		KEY_V:
			_cycle_flow_direction()
		KEY_C:
			_cycle_flow_strength()
		_:
			return false
	notify_ui_changed()
	_update_highlight()
	return true


func _stroke() -> void:
	context.set_edit_label(_edit_label())
	var brush := context.water_brush
	brush.update_hover(context.camera, context.space_state(), context.mouse_position())
	brush.apply()
	_update_highlight()


func pick_from_cell() -> void:
	if context != null and context.water_brush != null:
		context.water_brush.update_hover(context.camera, context.space_state(), context.mouse_position())
		context.water_brush.pick_from_cell()
		notify_ui_changed()
		_update_highlight()


func _edit_label() -> String:
	match context.water_brush.tool:
		WaterBrushController.TOOL_SELECT: return "выделение водоёма"
		WaterBrushController.TOOL_FLOOD: return "наполнение водоёма"
		WaterBrushController.TOOL_DRAIN: return "осушение"
		WaterBrushController.TOOL_FLOW: return "течение"
		WaterBrushController.TOOL_FREEZE: return "заморозка"
		WaterBrushController.TOOL_THAW: return "разморозка"
	return "вода"


func _cycle_flow_direction() -> void:
	var order := SlopeCatalog.ORTHOGONAL_DIRECTIONS
	var brush := context.water_brush
	brush.flow_direction = order[(order.find(brush.flow_direction) + 1) % order.size()]


func _cycle_flow_strength() -> void:
	var brush := context.water_brush
	brush.flow_strength = (brush.flow_strength % WaterBody.MAX_FLOW_STRENGTH) + 1


func _update_highlight() -> void:
	if context != null and context.water_highlight != null:
		if context.water_brush != null and context.water_brush.body_id != WaterBody.NO_BODY:
			context.water_highlight.highlight_body(context.water_brush.body_id)
		else:
			context.water_highlight.hide_highlight()


# --- Panels -------------------------------------------------------------------

func palette_entries() -> Array:
	return []


func selected_palette_entry() -> StringName:
	return OPTION_LAVA if context.water_brush.liquid_category == &"lava" else OPTION_WATER


func select_palette_entry(entry_id: StringName) -> void:
	activate_option(entry_id)


func tool_options() -> Array:
	var brush := context.water_brush
	var options: Array = []

	# --- ВОДОЕМ ---
	options.append(ToolOption.of(&"header_body", "Водоём:", &"", false, true))

	options.append(ToolOption.of(OPTION_WATER, "Вода", ROW_LIQUID_CAT, brush.liquid_category == &"water", false, Color(0.2, 0.55, 0.85, 1.0)))
	options.append(ToolOption.of(OPTION_LAVA, "Лава", ROW_LIQUID_CAT, brush.liquid_category == &"lava", false, Color(0.95, 0.3, 0.08, 1.0)))

	if brush.liquid_category == &"water":
		options.append(ToolOption.of(OPTION_SEA, "Море", ROW_WATER_TYPE, brush.water_type == WaterBody.Type.SEA))
		options.append(ToolOption.of(OPTION_LAKE, "Озеро", ROW_WATER_TYPE, brush.water_type == WaterBody.Type.LAKE))
		options.append(ToolOption.of(OPTION_RIVER, "Река", ROW_WATER_TYPE, brush.water_type == WaterBody.Type.RIVER))

	var display_level := brush.level
	if context != null and context.water != null and brush.body_id != WaterBody.NO_BODY:
		var body := context.water.body(brush.body_id)
		if body != null:
			display_level = body.surface_height
	options.append(ToolOption.of(&"water_level", "Уровень %d" % display_level, ROW_LEVEL, false, true))
	options.append(ToolOption.of(OPTION_LEVEL_DOWN, "−", ROW_LEVEL))
	options.append(ToolOption.of(OPTION_LEVEL_UP, "+", ROW_LEVEL))
	options.append(ToolOption.of(OPTION_AUTO_LEVEL, "Авто", ROW_LEVEL, brush.auto_level))

	var has_selected_body := false
	var is_frozen := false
	if context != null and context.water != null and brush.body_id != WaterBody.NO_BODY:
		var cells := context.water.cells_of_body(brush.body_id)
		if not cells.is_empty():
			has_selected_body = true
			if context.water.is_frozen(cells[0]):
				is_frozen = true

	if has_selected_body:
		if brush.liquid_category == &"water":
			var freeze_label := "Разморозить водоём" if is_frozen else "Заморозить водоём"
			options.append(ToolOption.of(OPTION_ACTION_ICE, freeze_label, ROW_BODY_ACTIONS, is_frozen))
		options.append(ToolOption.of(OPTION_DELETE_BODY, "🗑 Удалить водоём", ROW_BODY_ACTIONS))

	# --- КИСТЬ ---
	options.append(ToolOption.of(&"header_brush", "Кисть:", &"", false, true))
	options.append(ToolOption.of(StringName("%s%s" % [OPTION_TOOL_PREFIX, WaterBrushController.TOOL_FLOW]), "Течение", ROW_BRUSH_TOOLS, brush.tool == WaterBrushController.TOOL_FLOW))
	options.append(ToolOption.of(StringName("%s%s" % [OPTION_TOOL_PREFIX, WaterBrushController.TOOL_FREEZE]), "Заморозка", ROW_BRUSH_TOOLS, brush.tool == WaterBrushController.TOOL_FREEZE))
	options.append(ToolOption.of(StringName("%s%s" % [OPTION_TOOL_PREFIX, WaterBrushController.TOOL_THAW]), "Разморозка", ROW_BRUSH_TOOLS, brush.tool == WaterBrushController.TOOL_THAW))

	if brush.tool == WaterBrushController.TOOL_FLOW:
		options.append(ToolOption.of(OPTION_FLOW_DIR, "Направление: %s" % TerrainBrushController.direction_name(brush.flow_direction), ROW_FLOW_PARAMS))
		options.append(ToolOption.of(OPTION_FLOW_STRENGTH, "Сила: %d" % brush.flow_strength, ROW_FLOW_PARAMS))

	if _brush_has_size():
		options.append(ToolOption.of(&"brush_size", "Кисть: %d" % (brush.brush_size - 1), ROW_BRUSH_SIZE, false, true))
		options.append(ToolOption.of(OPTION_BRUSH_DOWN, "−", ROW_BRUSH_SIZE))
		options.append(ToolOption.of(OPTION_BRUSH_UP, "+", ROW_BRUSH_SIZE))

	return options


func activate_option(option_id: StringName) -> void:
	var brush := context.water_brush
	var text := String(option_id)
	if text.begins_with(OPTION_TOOL_PREFIX):
		var target_tool := StringName(text.trim_prefix(OPTION_TOOL_PREFIX))
		if brush.tool == target_tool:
			brush.tool = WaterBrushController.TOOL_FLOOD
		else:
			brush.tool = target_tool
		notify_ui_changed()
		_update_highlight()
		return
	match option_id:
		OPTION_DELETE_BODY:
			if context != null and context.water_service != null and brush.body_id != WaterBody.NO_BODY:
				context.water_service.remove_body(brush.body_id)
				brush.body_id = WaterBody.NO_BODY
		OPTION_ACTION_ICE:
			brush.toggle_body_ice()
		OPTION_WATER:
			brush.select_liquid_category(&"water")
		OPTION_LAVA:
			brush.select_liquid_category(&"lava")
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
	_update_highlight()


func inspector_lines() -> Array[String]:
	return []


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


func status_text() -> String:
	var brush := context.water_brush
	if brush == null:
		return ""

	var parts: Array[String] = []

	if not brush.has_hover:
		parts.append("клетка —")
	else:
		var cell := brush.hovered_cell
		var ground := context.terrain.height_of(cell)
		if not context.water.is_wet(context.terrain, cell):
			parts.append("клетка %d,%d · суша · рельеф %d" % [cell.x, cell.y, ground])
		else:
			var body_at := context.water.body_at(cell)
			var depth := context.water.depth_steps_at(context.terrain, cell)
			parts.append("клетка %d,%d · %s · дно %d · уровень %d · глубина %d (%.1f м) · %s%s" % [
				cell.x, cell.y, body_at.name if body_at != null else "?", ground, context.water.height_of(cell),
				depth, float(depth) * TerrainGrid.HEIGHT_STEP,
				"брод" if context.water.is_ford(context.terrain, cell) else "глубоко",
				" · лёд %d" % context.water.ice_thickness_at(cell) if context.water.is_frozen(cell) else "",
			])

	if brush.body_id != WaterBody.NO_BODY and context.water != null:
		var sel_body := context.water.body(brush.body_id)
		if sel_body != null and context.water.cells_of_body(brush.body_id).size() > 0:
			parts.append("Выбран водоём: %s (%s, %s, уровень %d, клеток: %d)" % [
				sel_body.name,
				sel_body.type_id(),
				"солёная" if sel_body.salinity == WaterBody.Salinity.SALT else "пресная",
				sel_body.surface_height,
				context.water.cells_of_body(brush.body_id).size()
			])

	return "  │  ".join(parts)
