class_name TerrainModeController
extends MapEditorMode

## Mode 1, relief (map_editor.md §5.1).
##
## Raise and lower columns, level to a reference height, place and dissolve ramps,
## cut holes. None of that is implemented here: it is `TerrainBrushController`,
## the same tool the laboratory and the building editor's `Terrain Base` layer
## drive. This controller binds it to the editor's input, palette and undo stack.
##
## The navigation overlay is not optional decoration in this mode. A green board
## proves nothing about whether anyone can walk on it — two terraces and a slope
## are identical from this camera, and the difference is a wall the author cannot
## see. `M` toggles it, and it is on by default here for exactly that reason.

const OPTION_MODE := &"edit_mode"
const OPTION_BRUSH_UP := &"brush_up"
const OPTION_BRUSH_DOWN := &"brush_down"
const OPTION_RAMP_CLASS := &"ramp_class"
const OPTION_RAMP_DIR := &"ramp_dir"
const OPTION_NAV := &"nav_overlay"
const OPTION_PROFILE := &"nav_profile"

## What a map has to be checked against: what a citizen can climb, and what a
## loaded cart can. A ramp only a walker can use is a supply route that silently
## is not one.
const NAV_PROFILES: Array[StringName] = [&"pedestrian", &"cart"]

## Sub-tools of the mode, cycled with `Tab`.
const TOOL_SCULPT := &"sculpt"
const TOOL_RAMP := &"ramp"
const TOOL_HOLE := &"hole"
const TOOLS: Array[StringName] = [TOOL_SCULPT, TOOL_RAMP, TOOL_HOLE]

var _tool: StringName = TOOL_SCULPT
var _nav_profile_index := 0


func _init() -> void:
	id = &"terrain"
	title = "Рельеф"


func activate() -> void:
	if context.nav_overlay != null:
		context.nav_overlay.configure(context.nav_grid, NAV_PROFILES[_nav_profile_index])
		context.nav_overlay.visible = true
		context.nav_overlay.rebuild()


func deactivate() -> void:
	context.brush.set_paint_direction(0)
	if context.nav_overlay != null:
		context.nav_overlay.visible = false


func process(_delta: float) -> void:
	context.brush.update_hover(context.camera, context.space_state(), context.mouse_position())


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _handle_mouse(event as InputEventMouseButton)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return _handle_key(event as InputEventKey)
	return false


func _handle_mouse(event: InputEventMouseButton) -> bool:
	if event.ctrl_pressed and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				context.brush.adjust_level_target(1)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				context.brush.adjust_level_target(-1)
				return true
	var direction := 0
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			direction = 1
		MOUSE_BUTTON_RIGHT:
			# A Shift-started sculpt stroke still has to stop if Shift is released
			# before the mouse button.  An unmodified right button belongs to camera
			# orbit and is claimed before the mode sees it.
			if event.pressed:
				if not event.shift_pressed:
					return false
				direction = -1
			elif _tool == TOOL_SCULPT and context.brush.is_painting():
				context.brush.set_paint_direction(0)
				_redraw_overlay()
				return true
			else:
				return false
		_:
			return false
	# Every tool uses left to apply and Shift+right for its inverse. Only sculpting
	# drags; unmodified right is reserved for the shared camera orbit.
	match _tool:
		TOOL_SCULPT:
			context.set_edit_label("рельеф")
			context.brush.set_paint_direction(direction if event.pressed else 0)
		TOOL_RAMP:
			if event.pressed:
				context.set_edit_label("пандус")
				if direction > 0:
					context.brush.place_ramp()
				else:
					context.brush.dissolve_ramp()
		TOOL_HOLE:
			if event.pressed:
				context.set_edit_label("вырез")
				context.brush.toggle_hole()
	_redraw_overlay()
	notify_ui_changed()
	return true


func _handle_key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_TAB:
			_tool = TOOLS[(TOOLS.find(_tool) + 1) % TOOLS.size()]
		KEY_F:
			context.set_edit_label("выравнивание")
			context.brush.apply_flatten()
			_redraw_overlay()
		KEY_M:
			_toggle_overlay()
		KEY_T:
			_cycle_profile()
		KEY_BRACKETLEFT:
			context.brush.adjust_brush_size(-1)
		KEY_BRACKETRIGHT:
			context.brush.adjust_brush_size(1)
		KEY_C:
			context.brush.cycle_ramp_class()
		KEY_V:
			context.brush.cycle_ramp_direction()
		_:
			return false
	notify_ui_changed()
	return true


## The overlay is presentation: it redraws only when it is actually being looked
## at. The navigation FIELD behind it is republished by the publisher on every
## commit whether or not anything is drawing it.
func _redraw_overlay() -> void:
	if context.nav_overlay != null and context.nav_overlay.visible:
		context.nav_overlay.rebuild()


func _toggle_overlay() -> void:
	if context.nav_overlay == null:
		return
	context.nav_overlay.visible = not context.nav_overlay.visible
	if context.nav_overlay.visible:
		context.nav_overlay.rebuild()


func _cycle_profile() -> void:
	_nav_profile_index = (_nav_profile_index + 1) % NAV_PROFILES.size()
	if context.nav_overlay != null:
		context.nav_overlay.configure(context.nav_grid, NAV_PROFILES[_nav_profile_index])
		if context.nav_overlay.visible:
			context.nav_overlay.rebuild()


# --- Panels -------------------------------------------------------------------

func palette_entries() -> Array:
	var entries: Array = []
	entries.append(PaletteEntry.of(TOOL_SCULPT, "Подъём / спуск"))
	entries.append(PaletteEntry.of(TOOL_RAMP, "Пандус"))
	entries.append(PaletteEntry.of(TOOL_HOLE, "Вырез"))
	return entries


func selected_palette_entry() -> StringName:
	return _tool


func select_palette_entry(entry_id: StringName) -> void:
	if TOOLS.has(entry_id):
		_tool = entry_id
		notify_ui_changed()


func tool_options() -> Array:
	var options: Array = []
	options.append(ToolOption.of(OPTION_MODE, "Режим: %s" % TerrainEditOperation.mode_name(context.brush.edit_mode)))
	options.append(ToolOption.of(OPTION_BRUSH_DOWN, "Кисть −"))
	options.append(ToolOption.of(OPTION_BRUSH_UP, "Кисть +"))
	if _tool == TOOL_RAMP:
		options.append(ToolOption.of(OPTION_RAMP_CLASS, "Класс: %s" % SlopeCatalog.id_of_class(context.brush.ramp_class)))
		options.append(ToolOption.of(OPTION_RAMP_DIR, "Направление: %s" % TerrainBrushController.direction_name(context.brush.ramp_direction)))
	options.append(ToolOption.of(OPTION_NAV, "Навигация: %s" % _overlay_state()))
	options.append(ToolOption.of(OPTION_PROFILE, "Профиль: %s" % NAV_PROFILES[_nav_profile_index]))
	return options


func activate_option(option_id: StringName) -> void:
	match option_id:
		OPTION_MODE:
			context.brush.cycle_edit_mode()
		OPTION_BRUSH_UP:
			context.brush.adjust_brush_size(1)
		OPTION_BRUSH_DOWN:
			context.brush.adjust_brush_size(-1)
		OPTION_RAMP_CLASS:
			context.brush.cycle_ramp_class()
		OPTION_RAMP_DIR:
			context.brush.cycle_ramp_direction()
		OPTION_NAV:
			_toggle_overlay()
		OPTION_PROFILE:
			_cycle_profile()
	notify_ui_changed()


func inspector_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("Инструмент: %s" % _tool)
	lines.append("Кисть: %d×%d" % [context.brush.brush_size * 2 - 1, context.brush.brush_size * 2 - 1])
	lines.append("Режим высоты: %s" % TerrainEditOperation.mode_name(context.brush.edit_mode))
	if context.brush.edit_mode == TerrainEditOperation.Mode.LEVEL:
		lines.append("Цель Level: %d (Ctrl+колесо)" % context.brush.level_target_height())
	lines.append("Пандус: %s → %s" % [
		SlopeCatalog.id_of_class(context.brush.ramp_class),
		TerrainBrushController.direction_name(context.brush.ramp_direction),
	])
	lines.append("Навигация: %s (%s)" % [_overlay_state(), NAV_PROFILES[_nav_profile_index]])
	lines.append("")
	lines.append("ЛКМ — применить, Shift+ПКМ — обратно")
	lines.append("Tab — подынструмент, F — выровнять")
	lines.append("[ ] — размер кисти, C/V — класс и направление пандуса")
	lines.append("Ctrl+колесо — высота Level")
	lines.append("M — оверлей навигации, T — профиль")
	return lines


func status_text() -> String:
	if not context.brush.has_hover:
		return "клетка —"
	var cell := context.brush.hovered_cell
	var record := context.terrain.cell_at(cell)
	var text := "клетка %d,%d · высота %d (%.2f м) · %s · уклон %s" % [
		cell.x, cell.y, record.height, record.height * TerrainGrid.HEIGHT_STEP,
		record.material_id, record.slope_id,
	]
	if record.is_hole():
		text += " · ВЫРЕЗ"
	if context.nav_grid != null and context.nav_grid.has_terrain_field():
		var profile: StringName = NAV_PROFILES[_nav_profile_index]
		text += " · %s" % ("проходима" if context.nav_grid.is_walkable(cell, profile) else "НЕПРОХОДИМА")
	return text


func _overlay_state() -> String:
	if context.nav_overlay == null:
		return "нет"
	return "вкл" if context.nav_overlay.visible else "выкл"


func list_title() -> String:
	return "Объекты рельефа"


func empty_list_hint() -> String:
	return "В режиме «Рельеф» объектов в списке пока нет"
