class_name WaterBrushController
extends BaseBrushController

## The water brush itself, with no host around it (map_editor.md §3.1, §5.3).
##
## Same arrangement as `TerrainBrushController`, and for the same reason: the
## terrain laboratory and the map editor both need to paint water, and a tool that
## exists twice drifts apart at the first fix. The controller owns brush state —
## size, level, the body being painted, the tool — the hovered column and the
## message of the last operation. It owns no nodes and it never writes into
## `WaterGrid`: every edit goes through `WaterService`, which is what keeps undo
## and the published navigation field in step.
##
## The hovered column comes from the TERRAIN's collision, not the water's: open
## water has no collider (§9), and picking through it is what lets an author paint
## the bottom of a lake they can see through. Ice does have one — it is a floor
## walkers stand on — and the ray would stop on it, which is correct: an author
## clicking a frozen lake means the cell they can see.

## What the left button does. Three tools, the three `map_editor.md` §5.3 names:
## fill a basin, move the surface of water that is already there, take it away.
##
## Ice is NOT one of them. §9.6 makes freezing a seasonal operation over a whole
## body — "one operation per body per season" — so a per-cell ice brush authors a
## state the first seasonal pass overwrites wholesale. Freezing stays a button on
## the body (`toggle_body_ice`), which is the granularity the mechanic has.
const TOOL_SELECT := &"select"
const TOOL_FLOOD := &"flood"
const TOOL_DRAIN := &"drain"
const TOOL_FLOW := &"flow"
const TOOL_FREEZE := &"freeze"
const TOOL_THAW := &"thaw"
const TOOL_STILL := &"still"
const TOOLS: Array[StringName] = [TOOL_SELECT, TOOL_FLOOD, TOOL_DRAIN, TOOL_FLOW, TOOL_STILL, TOOL_FREEZE, TOOL_THAW]

var tool: StringName = TOOL_FLOOD
## The body strokes go into. Zero until the author makes one — a stroke with no
## body is refused rather than quietly inventing a lake.
var body_id := WaterBody.NO_BODY
## Surface level in steps. Absolute and stamped, never stepped per cell: a drag
## overlaps its own path, and a brush defined as "one step deeper than what is
## here" digs a staircase instead of filling a basin.
var level := 0
## Load the ice of this body carries when it freezes (§9.6). Two thresholds are
## distinguishable — `MIN_ICE_THICKNESS_PEDESTRIAN` and `..._CART` — so the useful
## authored answers are "walkers only" and "carts too"; the fourth value of the
## two-bit field is spare, kept because the format has the bits and a third
## traveller class would need them.
var ice_thickness := WaterGrid.MAX_ICE_THICKNESS
var liquid_category: StringName = &"water"
var water_type: WaterBody.Type = WaterBody.Type.LAKE

func active_body_type() -> WaterBody.Type:
	if liquid_category == &"lava":
		return WaterBody.Type.LAVA
	return water_type if water_type != WaterBody.Type.LAVA else WaterBody.Type.LAKE


func cycle_liquid_category() -> void:
	liquid_category = &"lava" if liquid_category == &"water" else &"water"
	last_message = "жидкость: %s" % ("лава" if liquid_category == &"lava" else "вода")


func cycle_water_type() -> void:
	if liquid_category == &"lava":
		liquid_category = &"water"
	var water_types: Array[WaterBody.Type] = [WaterBody.Type.LAKE, WaterBody.Type.RIVER, WaterBody.Type.SEA]
	var current_idx := water_types.find(water_type)
	var next_idx := (current_idx + 1) % water_types.size() if current_idx >= 0 else 0
	water_type = water_types[next_idx]
	last_message = "тип воды: %s" % WaterBody.type_id_of(water_type)


var flow_direction := SlopeCatalog.DIR_E
var flow_strength := 1


func select_liquid_category(category: StringName) -> void:
	liquid_category = &"lava" if category == &"lava" else &"water"
	last_message = "жидкость: %s" % ("лава" if liquid_category == &"lava" else "вода")
	if body_id != WaterBody.NO_BODY and _service != null:
		_service.retype_body(body_id, active_body_type())


func select_water_type(body_type: WaterBody.Type) -> void:
	liquid_category = &"water"
	water_type = body_type if body_type != WaterBody.Type.LAVA else WaterBody.Type.LAKE
	last_message = "тип воды: %s" % WaterBody.type_id_of(water_type)
	if body_id != WaterBody.NO_BODY and _service != null:
		_service.retype_body(body_id, water_type)

var _terrain: TerrainGrid
var _water: WaterGrid
var _service: WaterService
var _border: BorderOceanService = null


func configure(terrain: TerrainGrid, water: WaterGrid, service: WaterService, border: BorderOceanService = null) -> void:
	_terrain = terrain
	_water = water
	_pick_grid = terrain
	_service = service
	_border = border


func cycle_tool() -> void:
	tool = TOOLS[(TOOLS.find(tool) + 1) % TOOLS.size()]
	last_message = "инструмент: %s" % _tool_label()


func adjust_level(delta: int) -> void:
	level = clampi(level + delta, WaterGrid.MIN_HEIGHT, WaterGrid.MAX_HEIGHT)
	last_message = "уровень %d (%.1f м)" % [level, float(level) * TerrainGrid.HEIGHT_STEP]
	if body_id != WaterBody.NO_BODY and _service != null:
		_service.set_body_level(body_id, level)


## Takes the level from the ground under the cursor, one step above it — the
## natural gesture for "fill this hollow to just over that rock".
func pick_level_from_ground() -> void:
	if not has_hover or _terrain == null:
		return
	level = _terrain.height_of(hovered_cell) + 1
	last_message = "уровень по рельефу: %d" % level


signal body_selected(body_id: int)


func select_body(next_body_id: int) -> void:
	if _water == null or not _water.has_body(next_body_id):
		return
	var changed := body_id != next_body_id
	body_id = next_body_id
	var body := _water.body(body_id)
	if body != null:
		if changed:
			level = body.surface_height
		last_message = "водоём: %s" % body.name
	body_selected.emit(body_id)


## Creates a registry entry and selects it. It has no visible water until Flood
## fills a basin; creation is never a painted brush stroke.
func create_body(body_type: WaterBody.Type) -> WaterBody:
	if _service == null:
		return null
	var body := _service.create_body(body_type, level)
	if body == null:
		last_message = "нет места для водоёмов (макс. %d)" % WaterBody.MAX_ID
		return null
	body_id = body.id
	if body_type == WaterBody.Type.LAVA:
		liquid_category = &"lava"
	else:
		liquid_category = &"water"
		water_type = body_type
	last_message = "создан водоём: %s" % body.name
	return body


func update_hover(camera: Camera3D, space: PhysicsDirectSpaceState3D, mouse: Vector2) -> bool:
	return super.update_hover(camera, space, mouse)


# --- Eyedropper ---------------------------------------------------------------

func pick_from_cell() -> void:
	if not has_hover or _water == null:
		return
	if _water.has_water(hovered_cell):
		var target_body_id := _water.body_id_at(hovered_cell)
		select_body(target_body_id)
		level = _water.height_of(hovered_cell)
		var found_body := _water.body(target_body_id)
		if found_body != null:
			if found_body.is_lava():
				liquid_category = &"lava"
			else:
				liquid_category = &"water"
				water_type = found_body.type
		if _water.is_frozen(hovered_cell):
			tool = TOOL_FREEZE
			ice_thickness = _water.ice_thickness_at(hovered_cell)
		else:
			tool = TOOL_FLOOD
		last_message = "пипетка: %s (уровень %d)" % [found_body.name if found_body != null else "водоём", level]
	else:
		if _terrain != null:
			level = _terrain.height_of(hovered_cell) + 1
		tool = TOOL_FLOOD
		last_message = "пипетка: рельеф → уровень %d" % level


# --- Strokes ------------------------------------------------------------------

## What the left button does, dispatched by tool. Called on press and again on
## every new column a drag crosses. When the hovered cell belongs to a body whose
## type differs from the selected body's type, the body is retyped first — one
## click converts an entire body, except border bodies which are protected.
func apply() -> void:
	if not has_hover or _service == null:
		return
	if tool == TOOL_SELECT:
		_select_hovered_body()
		return
	if tool == TOOL_FLOOD:
		_adopt_body_at_hover()
		_maybe_retype_hovered_body()
	match tool:
		TOOL_FLOOD:
			_flood()
		TOOL_DRAIN:
			_drain_body_at_hover()
		TOOL_FLOW:
			_apply_flow()
		TOOL_STILL:
			_clear_flow()
		TOOL_FREEZE:
			_set_frozen(true)
		TOOL_THAW:
			_set_frozen(false)


func _apply_flow() -> void:
	if _service == null or _water == null or not has_hover:
		return
	if not _water.has_water(hovered_cell):
		last_message = "нет воды под курсором"
		return
	var target_body := _water.body_id_at(hovered_cell)
	if target_body == WaterBody.NO_BODY:
		return
	var cells := brush_cells(hovered_cell)
	if _service.set_flow(cells, target_body, flow_direction, flow_strength):
		last_message = "течение: %d клеток" % _service.last_delta_size()
		return
	last_message = "течение не изменилось (%s)" % _water_rejection_label(_service.last_rejection())


func _clear_flow() -> void:
	if _service == null or _water == null or not has_hover:
		return
	if not _water.has_water(hovered_cell):
		last_message = "нет воды под курсором"
		return
	var target_body := _water.body_id_at(hovered_cell)
	if target_body == WaterBody.NO_BODY:
		return
	var cells := brush_cells(hovered_cell)
	if _service.clear_flow(cells, target_body):
		last_message = "течение удалено: %d клеток" % _service.last_delta_size()
		return
	last_message = "течение не изменилось (%s)" % _water_rejection_label(_service.last_rejection())


func _select_hovered_body() -> void:
	if _water == null or not _water.has_water(hovered_cell):
		body_id = WaterBody.NO_BODY
		last_message = "водоём не выбран"
		return
	var hovered_id := _water.body_id_at(hovered_cell)
	select_body(hovered_id)
	var body := _water.body(hovered_id)
	if body != null:
		if body.is_lava():
			liquid_category = &"lava"
		else:
			liquid_category = &"water"
			water_type = body.type
		last_message = "выбран водоём: %s (%s, уровень %d)" % [body.name, body.type_id(), level]


func _flood() -> void:
	var dry_cell := _water == null or not _water.has_water(hovered_cell)
	# A click on dry ground means "make water here", not "move the lake I last
	# touched over here". An empty body is still reused (undo and old documents
	# may leave one selected); a body with a contour is not.
	if dry_cell and body_id != WaterBody.NO_BODY and _water.cells_of_body(body_id).size() > 0:
		body_id = WaterBody.NO_BODY
	if dry_cell and body_id == WaterBody.NO_BODY and _terrain != null:
		level = _terrain.height_of(hovered_cell) + 1
	if body_id == WaterBody.NO_BODY:
		var body := _service.create_and_flood(hovered_cell, active_body_type(), level)
		if body == null:
			last_message = "затопление не удалось (%s)" % _water_rejection_label(_service.last_rejection())
			return
		body_id = body.id
		last_message = "создан и затоплен %s: %d клеток" % [body.name, _service.last_delta_size()]
		return
	if _water != null and _water.has_water(hovered_cell):
		var cell_body_id := _water.body_id_at(hovered_cell)
		var cell_height := _water.height_of(hovered_cell)
		if cell_body_id == body_id and cell_height == level:
			last_message = "уже на этом уровне (%d)" % level
			return
	if _service.flood(hovered_cell, body_id, level):
		last_message = "затоплено: %d клеток" % _service.last_delta_size()
		return
	# If the ground is at or above the level, the basin has no depth to fill.
	# Pick the level from the ground (one step above it) and try again only if dry ground.
	if _terrain != null and _service.last_rejection() == WaterService.REASON_NOTHING_TO_DO:
		if _water != null and not _water.has_water(hovered_cell):
			var ground := _terrain.height_of(hovered_cell)
			if level <= ground:
				level = ground + 1
				if _service.flood(hovered_cell, body_id, level):
					last_message = "затоплено (уровень %d): %d клеток" % [level, _service.last_delta_size()]
					return
	last_message = "затопление не удалось (%s)" % _water_rejection_label(_service.last_rejection())


## Existing liquid is its own selection target. The registry remains the storage
## model, but the author no longer has to find its id in a palette before editing.
func _adopt_body_at_hover() -> void:
	if _water == null or not _water.has_water(hovered_cell):
		return
	select_body(_water.body_id_at(hovered_cell))


func _set_frozen(frozen: bool) -> void:
	if _service.set_frozen(brush_cells(hovered_cell), frozen, ice_thickness, true):
		last_message = "%s: %d клеток" % ["заморожено" if frozen else "оттаяло", _service.last_delta_size()]
		return
	last_message = "лёд не изменился (%s)" % _water_rejection_label(_service.last_rejection())


## Shift+right drains the whole body under the cursor. Plain right button remains
## reserved for camera orbit.
func apply_secondary() -> void:
	if not has_hover or _service == null:
		return
	_drain_body_at_hover()


func _drain_cells_at_hover() -> void:
	if _border != null and _water != null:
		var body_at := _water.body_id_at(hovered_cell)
		if body_at != WaterBody.NO_BODY and _border.is_border_body(body_at):
			last_message = "граничный водоём нельзя осушить — поднимите рельеф выше уровня"
			return
	var cells := brush_cells(hovered_cell)
	if _service.drain_cells(cells):
		if body_id != WaterBody.NO_BODY and _water != null and not _water.has_body(body_id):
			body_id = WaterBody.NO_BODY
		last_message = "осушено: %d клеток" % _service.last_delta_size()
		return
	last_message = "не удалось осушить (%s)" % _water_rejection_label(_service.last_rejection())


func _drain_body_at_hover() -> void:
	var target_body := _water.body_id_at(hovered_cell) if _water != null else WaterBody.NO_BODY
	if target_body == WaterBody.NO_BODY:
		last_message = "здесь нет водоёма"
		return
	if _border != null and _border.is_border_body(target_body):
		last_message = "граничный водоём нельзя осушить — поднимите рельеф выше уровня"
		return
	if _service.remove_body(target_body):
		body_id = WaterBody.NO_BODY if body_id == target_body else body_id
		last_message = "водоём осушен"
		return
	last_message = "не удалось осушить (%s)" % _water_rejection_label(_service.last_rejection())


## When the hovered cell belongs to a body whose type differs from the selected
## body's type, retypes the hovered body to match. Border bodies are protected:
## they cannot be retyped, only drained by raising the ground.
func _maybe_retype_hovered_body() -> void:
	if _water == null:
		return
	var target_type := active_body_type()
	var hovered_id := _water.body_id_at(hovered_cell)
	if hovered_id == WaterBody.NO_BODY:
		return
	var hovered_body := _water.body(hovered_id)
	if hovered_body == null or hovered_body.type == target_type:
		return
	if _border != null and _border.is_border_body(hovered_id):
		last_message = "граничный водоём нельзя изменить"
		return
	if _service.retype_body(hovered_id, target_type):
		body_id = hovered_id
		level = hovered_body.surface_height
		last_message = "тип изменён: %s → %s" % [hovered_body.name, WaterBody.type_id_of(target_type)]


## Freezes or thaws the whole selected body in one transaction — the seasonal
## operation of §9.6, available to the author as a button.
func toggle_body_ice() -> void:
	if _service == null or body_id == WaterBody.NO_BODY:
		return
	var frozen_cells := 0
	for cell: Vector2i in _service.cells_of_body(body_id):
		if _water.is_frozen(cell):
			frozen_cells += 1
	var freeze := frozen_cells == 0
	if _service.set_body_frozen(body_id, freeze, ice_thickness):
		last_message = "водоём %s" % ("заморожен" if freeze else "оттаял")
		return
	last_message = "состояние льда не изменилось (%s)" % _water_rejection_label(_service.last_rejection())


func cycle_ice_thickness() -> void:
	ice_thickness = (ice_thickness % WaterGrid.MAX_ICE_THICKNESS) + 1
	last_message = "толщина льда: %d" % ice_thickness


# --- History ------------------------------------------------------------------

func undo() -> void:
	last_message = "отменено" if _service.undo() else "нечего отменять"


func redo() -> void:
	last_message = "повторено" if _service.redo() else "нечего повторять"


func _tool_label() -> String:
	match tool:
		TOOL_SELECT: return "выбор"
		TOOL_FLOOD: return "затопление"
		TOOL_DRAIN: return "осушение"
		TOOL_FLOW: return "течение"
		TOOL_STILL: return "штиль"
		TOOL_FREEZE: return "заморозка"
		TOOL_THAW: return "оттайка"
	return String(tool)


static func _water_rejection_label(reason: StringName) -> String:
	match reason:
		WaterService.REASON_NO_GRID: return "нет сетки"
		WaterService.REASON_NO_BODY: return "нет водоёма"
		WaterService.REASON_NOTHING_TO_DO: return "нечего менять"
		WaterService.REASON_NOT_FREEZABLE: return "нельзя заморозить"
		WaterService.REASON_FLOW_REQUIRES_RIVER: return "течение только для рек"
	return String(reason)
