class_name TerrainModeController
extends MapEditorMode

## Mode 1, relief (map_editor.md §5.1).
##
## Raise and lower columns, level to a reference height, place and dissolve ramps,
## cut holes. None of that is implemented here: it is `TerrainBrushController`,
## the same tool the laboratory and the building editor's `Terrain Base` layer
## drive. This controller binds it to the editor's input, palette and undo stack.
##
## Navigation is available here, but starts hidden so terrain sculpting opens on
## the ground itself. The explicit profile buttons make the overlay's meaning
## clear when the author needs to inspect it.

const OPTION_MODE := &"edit_mode"
const OPTION_BRUSH_UP := &"brush_up"
const OPTION_BRUSH_DOWN := &"brush_down"
const OPTION_RAMP_CLASS := &"ramp_class"
const OPTION_TERRAIN_SLOPE := &"terrain_slope"
const OPTION_RAMP_GENTLER := &"ramp_gentler"
const OPTION_RAMP_STEEPER := &"ramp_steeper"
const OPTION_NAV_NONE := &"nav_none"
const OPTION_NAV_PEDESTRIAN := &"nav_pedestrian"
const OPTION_NAV_CART := &"nav_cart"
const OPTION_HOLE_MODE := &"hole_mode"

## What a map has to be checked against: what a citizen can climb, and what a
## loaded cart can. A ramp only a walker can use is a supply route that silently
## is not one.
# Keep in sync with terrain_lab.gd — GDScript const cannot reference another
# class's const array.
const NAV_PROFILES: Array[StringName] = [&"pedestrian", &"cart"]

## Sub-tools of the mode, cycled with `Tab`.
const TOOL_SCULPT := &"sculpt"
const TOOL_RAMP := &"ramp"
const TOOL_HOLE := &"hole"
const TOOLS: Array[StringName] = [TOOL_SCULPT, TOOL_RAMP, TOOL_HOLE]

var _tool: StringName = TOOL_SCULPT
var _nav_profile_index := 0
## Ramp connection is a two-anchor gesture. Auto is the useful default; exact
## catalog classes remain available for authors who need a specific traversal
## profile or footprint.
var _ramp_requested_class := RampConnectionPlan.AUTO_CLASS
var _ramp_dragging := false
var _ramp_drag_start := Vector2i.ZERO
var _last_ramp_status := ""
## Hole tool: true = cut, false = fill. Left-click applies the selected mode,
## Shift+right applies the inverse — same pattern as sculpt's raise/lower.
var _hole_cutting := true


func _init() -> void:
	id = &"terrain"
	title = "Рельеф"


func activate() -> void:
	if context.nav_overlay != null:
		context.nav_overlay.configure(context.nav_grid, NAV_PROFILES[_nav_profile_index])
		context.nav_overlay.visible = false
	_update_ramp_preview()


func deactivate() -> void:
	_cancel_ramp_drag()
	if context != null and context.brush != null:
		context.brush.set_paint_direction(0)
	if context != null and context.nav_overlay != null:
		context.nav_overlay.visible = false
	if context != null and context.ramp_preview != null:
		context.ramp_preview.hide_preview()


func clear_hover() -> void:
	if _ramp_dragging:
		_cancel_ramp_drag()
	if context != null and context.brush != null:
		context.brush.clear_hover()
	if context != null and context.ramp_preview != null:
		context.ramp_preview.hide_preview()


func hover_brush() -> BaseBrushController:
	return context.brush if context != null else null


func adjust_brush_size(delta: int) -> void:
	if context != null and context.brush != null:
		context.brush.adjust_brush_size(delta)


func process(_delta: float) -> void:
	if context.brush != null:
		context.brush.update_hover(context.camera, context.space_state(), context.mouse_position())
	_update_ramp_preview()


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _handle_mouse(event as InputEventMouseButton)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return _handle_key(event as InputEventKey)
	return false


func _handle_mouse(event: InputEventMouseButton) -> bool:
	if _tool == TOOL_RAMP:
		return _handle_ramp_mouse(event)
	if _handle_common_mouse(event):
		return true
	if event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed and event.pressed:
		context.brush.pick_material()
		notify_ui_changed()
		return true
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
			elif _tool == TOOL_SCULPT and context.brush.paint_direction() < 0:
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
		TOOL_HOLE:
			if event.pressed:
				var cutting := _hole_cutting if direction > 0 else not _hole_cutting
				context.set_edit_label("вырез" if cutting else "засыпка")
				context.brush.apply_hole(1 if cutting else -1)
	_redraw_overlay()
	notify_ui_changed()
	return true


func _handle_ramp_mouse(event: InputEventMouseButton) -> bool:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not context.brush.has_hover:
				return true
			_ramp_dragging = true
			_ramp_drag_start = context.brush.hovered_cell
			context.set_edit_label("соединение высот")
			_set_ramp_status("Пандус: протяните к площадке другой высоты")
		else:
			if not _ramp_dragging:
				return true
			var end_cell := context.brush.hovered_cell
			var had_hover := context.brush.has_hover
			_ramp_dragging = false
			if had_hover:
				var plan := RampConnectionPlan.between(
					context.terrain, _ramp_drag_start, end_cell, _ramp_requested_class,
				)
				context.brush.connect_ramp(_ramp_drag_start, end_cell, _ramp_requested_class)
				_set_ramp_status(_ramp_result_message(plan))
			_redraw_overlay()
		_update_ramp_preview()
		notify_ui_changed()
		return true
	if event.button_index == MOUSE_BUTTON_RIGHT and event.shift_pressed and event.pressed:
		context.set_edit_label("удаление пандуса")
		context.brush.dissolve_ramp()
		_set_ramp_status("Пандус удалён" if context.brush.last_message == "ramp dissolved" else "Под курсором нет пандуса")
		_redraw_overlay()
		notify_ui_changed()
		return true
	return false


func _handle_key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_TAB:
			_tool = TOOLS[(TOOLS.find(_tool) + 1) % TOOLS.size()]
			if _tool == TOOL_RAMP:
				context.set_status_message(_ramp_guidance_message())
			else:
				_cancel_ramp_drag()
				if context.ramp_preview != null:
					context.ramp_preview.hide_preview()
		KEY_F:
			if _tool != TOOL_SCULPT:
				return false
			context.set_edit_label("выравнивание")
			context.brush.apply_flatten()
			_redraw_overlay()
		KEY_M:
			_toggle_overlay()
		KEY_T:
			_cycle_profile()
		KEY_BRACKETLEFT:
			if _tool == TOOL_RAMP:
				return false
			context.brush.adjust_brush_size(-1)
		KEY_BRACKETRIGHT:
			if _tool == TOOL_RAMP:
				return false
			context.brush.adjust_brush_size(1)
		KEY_C:
			if _tool != TOOL_RAMP:
				return false
			_cycle_ramp_profile()
			context.set_status_message(_ramp_message())
		KEY_V:
			if _tool != TOOL_SCULPT or context.brush.edit_mode == TerrainEditOperation.Mode.TERRACE:
				return false
			context.brush.cycle_terrain_slope_class()
			context.set_status_message("Откос: %s" % _terrain_slope_label())
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
	entries.append(PaletteEntry.of(TOOL_RAMP, "Соединить высоты"))
	entries.append(PaletteEntry.of(TOOL_HOLE, "Вырез / засыпка"))
	return entries


func selected_palette_entry() -> StringName:
	return _tool


func select_palette_entry(entry_id: StringName) -> void:
	if TOOLS.has(entry_id):
		_tool = entry_id
		if _tool == TOOL_RAMP:
			context.set_status_message(_ramp_guidance_message())
		else:
			_cancel_ramp_drag()
			if context.ramp_preview != null:
				context.ramp_preview.hide_preview()
		notify_ui_changed()


func tool_options() -> Array:
	var options: Array = []
	options.append(ToolOption.of(OPTION_NAV_NONE, "Нет", &"navigation", context.nav_overlay == null or not context.nav_overlay.visible))
	options.append(ToolOption.of(OPTION_NAV_PEDESTRIAN, "Pedestrian", &"navigation", _overlay_profile_is(&"pedestrian")))
	options.append(ToolOption.of(OPTION_NAV_CART, "Cart", &"navigation", _overlay_profile_is(&"cart")))
	if _tool == TOOL_SCULPT:
		options.append(ToolOption.of(OPTION_MODE, "Режим: %s" % TerrainEditOperation.mode_name(context.brush.edit_mode)))
		if context.brush.edit_mode != TerrainEditOperation.Mode.TERRACE:
			options.append(ToolOption.of(OPTION_TERRAIN_SLOPE, "Откос: %s" % _terrain_slope_label()))
	if _tool != TOOL_RAMP:
		options.append(ToolOption.of(&"brush_size", "Кисть: %d" % (context.brush.brush_size - 1), &"brush", false, true))
		options.append(ToolOption.of(OPTION_BRUSH_DOWN, "−", &"brush"))
		options.append(ToolOption.of(OPTION_BRUSH_UP, "+", &"brush"))
	if _tool == TOOL_HOLE:
		options.append(ToolOption.of(OPTION_HOLE_MODE, "Режим: %s" % ("вырез" if _hole_cutting else "засыпка")))
	if _tool == TOOL_RAMP:
		options.append(ToolOption.of(OPTION_RAMP_CLASS, "Уклон: %s" % _ramp_class_label()))
		options.append(ToolOption.of(OPTION_RAMP_GENTLER, "Пологее", &"ramp_shape"))
		options.append(ToolOption.of(OPTION_RAMP_STEEPER, "Круче", &"ramp_shape"))
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
			_cycle_ramp_profile()
			context.set_status_message(_ramp_message())
		OPTION_TERRAIN_SLOPE:
			context.brush.cycle_terrain_slope_class()
			context.set_status_message("Откос: %s" % _terrain_slope_label())
		OPTION_RAMP_GENTLER:
			_reshape_hovered_ramp(true)
		OPTION_RAMP_STEEPER:
			_reshape_hovered_ramp(false)
		OPTION_NAV_NONE:
			_set_overlay_profile(&"")
		OPTION_NAV_PEDESTRIAN:
			_set_overlay_profile(&"pedestrian")
		OPTION_NAV_CART:
			_set_overlay_profile(&"cart")
		OPTION_HOLE_MODE:
			_hole_cutting = not _hole_cutting
	notify_ui_changed()


func inspector_lines() -> Array[String]:
	return []


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


func _overlay_profile_is(profile: StringName) -> bool:
	return context.nav_overlay != null and context.nav_overlay.visible and NAV_PROFILES[_nav_profile_index] == profile


func _set_overlay_profile(profile: StringName) -> void:
	if context.nav_overlay == null:
		return
	if profile == &"":
		context.nav_overlay.visible = false
		return
	_nav_profile_index = NAV_PROFILES.find(profile)
	context.nav_overlay.configure(context.nav_grid, profile)
	context.nav_overlay.visible = true
	context.nav_overlay.rebuild()


func _update_ramp_preview() -> void:
	if context == null or context.ramp_preview == null:
		return
	if _tool != TOOL_RAMP or context.brush == null or not context.brush.has_hover:
		context.ramp_preview.hide_preview()
		return
	if not _ramp_dragging:
		context.ramp_preview.show_start(context.brush.hovered_cell)
		return
	var plan := RampConnectionPlan.between(
		context.terrain, _ramp_drag_start, context.brush.hovered_cell, _ramp_requested_class,
	)
	context.ramp_preview.show_connection(plan)
	_set_ramp_status(_ramp_preview_message(plan))


func _ramp_class_label() -> String:
	if _ramp_requested_class == RampConnectionPlan.AUTO_CLASS:
		return "авто"
	var slope_id := SlopeCatalog.id_of_class(_ramp_requested_class)
	return "%s — %d кл., +%.1f м" % [
		_ramp_class_name(slope_id), SlopeCatalog.run_of(slope_id),
		float(SlopeCatalog.rise_of(slope_id)) * TerrainGrid.HEIGHT_STEP,
	]


func _terrain_slope_label() -> String:
	if context.brush.terrain_slope_class == RampConnectionPlan.AUTO_CLASS:
		return "естественная"
	var slope_id := SlopeCatalog.id_of_class(context.brush.terrain_slope_class)
	return "%s — %d кл. на +%.1f м" % [
		_ramp_class_name(slope_id), SlopeCatalog.run_of(slope_id),
		float(SlopeCatalog.rise_of(slope_id)) * TerrainGrid.HEIGHT_STEP,
	]


func _reshape_hovered_ramp(gentler: bool) -> void:
	context.set_edit_label("пандус пологее" if gentler else "пандус круче")
	context.brush.reshape_hovered_ramp(gentler)
	var message := context.brush.last_message
	if message == "no ramp under cursor":
		_set_ramp_status("Пандус: наведите курсор на существующий склон")
	elif message.begins_with("ramp reshaped"):
		_set_ramp_status("Пандус перестроен: %s" % message.trim_prefix("ramp reshaped to "))
	elif message.contains("already"):
		_set_ramp_status("Пандус уже имеет предельный профиль")
	else:
		_set_ramp_status("Пандус не перестроен: %s" % message)
	_redraw_overlay()
	_update_ramp_preview()


func _ramp_message() -> String:
	if _ramp_dragging and context.brush != null and context.brush.has_hover:
		return _ramp_preview_message(RampConnectionPlan.between(
			context.terrain, _ramp_drag_start, context.brush.hovered_cell, _ramp_requested_class,
		))
	return _ramp_guidance_message()


func _ramp_guidance_message() -> String:
	return "Пандус: протяните ЛКМ между площадками разной высоты · C — уклон · Shift+ПКМ — удалить"


func _cycle_ramp_profile() -> void:
	var profiles: Array[int] = [RampConnectionPlan.AUTO_CLASS]
	profiles.append_array(SlopeCatalog.RAMP_CLASSES)
	var index := profiles.find(_ramp_requested_class)
	_ramp_requested_class = profiles[(index + 1) % profiles.size()] if index >= 0 else profiles[0]
	_update_ramp_preview()


func _ramp_preview_message(plan: RampConnectionPlan) -> String:
	if not plan.is_valid():
		return "Пандус: %s" % _connection_rejection_message(plan)
	var slope_id := SlopeCatalog.id_of_class(plan.slope_class)
	var action := "будет изменено клеток: %d" % plan.reshaped_cells if plan.reshaped_cells > 0 else "земля уже подготовлена"
	if not plan.replacement_cells.is_empty():
		action += " · заменяется пандус"
	return "Пандус: %s · %d кл. · +%.1f м · %s · %s" % [
		_ramp_class_name(slope_id), plan.run,
		float(plan.rise) * TerrainGrid.HEIGHT_STEP,
		_direction_label(plan.direction), action,
	]


func _ramp_result_message(plan: RampConnectionPlan) -> String:
	if not plan.is_valid():
		return "Пандус не создан: %s" % _connection_rejection_message(plan)
	return "Пандус создан: %s" % _ramp_preview_message(plan).trim_prefix("Пандус: ")


func _set_ramp_status(message: String) -> void:
	if message == _last_ramp_status:
		return
	_last_ramp_status = message
	context.set_status_message(message)


func _cancel_ramp_drag() -> void:
	_ramp_dragging = false
	_last_ramp_status = ""


static func _direction_label(direction: int) -> String:
	match direction:
		SlopeCatalog.DIR_N: return "↑ север"
		SlopeCatalog.DIR_E: return "→ восток"
		SlopeCatalog.DIR_S: return "↓ юг"
		SlopeCatalog.DIR_W: return "← запад"
	return "—"


static func _connection_rejection_message(plan: RampConnectionPlan) -> String:
	match plan.reason:
		RampConnectionPlan.REASON_OUTSIDE: return "точка вне карты"
		RampConnectionPlan.REASON_HOLE: return "на пути есть вырез"
		RampConnectionPlan.REASON_SAME_CELL: return "протяните к другой клетке"
		RampConnectionPlan.REASON_SAME_HEIGHT: return "площадки находятся на одной высоте"
		RampConnectionPlan.REASON_NOT_STRAIGHT: return "соединение должно идти по прямой"
		RampConnectionPlan.REASON_ANCHOR: return "на пути закреплённая клетка"
		RampConnectionPlan.REASON_RAMP: return "на пути уже есть пандус"
		RampConnectionPlan.REASON_WRONG_RUN:
			return "для выбранного уклона нужно %d клеток" % SlopeCatalog.run_of_class(plan.requested_class)
		RampConnectionPlan.REASON_WRONG_RISE:
			return "для выбранного уклона нужен перепад %.1f м" % (
				float(SlopeCatalog.rise_of_class(plan.requested_class)) * TerrainGrid.HEIGHT_STEP
			)
		RampConnectionPlan.REASON_NO_MATCH:
			return "нет профиля для %d клеток и перепада %.1f м" % [
				plan.run, float(plan.rise) * TerrainGrid.HEIGHT_STEP,
			]
	return "недопустимое положение"


static func _ramp_class_name(slope_id: StringName) -> String:
	match slope_id:
		SlopeCatalog.SHALLOW: return "очень пологий"
		SlopeCatalog.GENTLE: return "пологий"
		SlopeCatalog.MODERATE: return "средний"
		SlopeCatalog.STEEP: return "крутой"
		SlopeCatalog.VERY_STEEP: return "очень крутой"
		SlopeCatalog.PRE_CLIFF: return "предельный"
		_: return String(slope_id)


func list_title() -> String:
	return ""


func empty_list_hint() -> String:
	return ""
