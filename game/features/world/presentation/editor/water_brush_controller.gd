class_name WaterBrushController
extends RefCounted

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
## The hovered column comes from the TERRAIN's collision, not the water's: the
## water surface has no collider (§9), and picking through it is what lets an
## author paint the bottom of a lake they can see through.

const HOVER_RAY_LENGTH := 500.0
const MAX_BRUSH_SIZE := 8

## What the left button does.
const TOOL_PAINT := &"paint"
const TOOL_ERASE := &"erase"
const TOOL_FLOOD := &"flood"
const TOOL_FREEZE := &"freeze"
const TOOLS: Array[StringName] = [TOOL_PAINT, TOOL_ERASE, TOOL_FLOOD, TOOL_FREEZE]

var brush_size := 2
var tool: StringName = TOOL_PAINT
## The body strokes go into. Zero until the author makes one — a stroke with no
## body is refused rather than quietly inventing a lake.
var body_id := WaterBody.NO_BODY
## Surface level in steps. Absolute and stamped, never stepped per cell: a drag
## overlaps its own path, and a brush defined as "one step deeper than what is
## here" digs a staircase instead of filling a basin.
var level := 0
var ice_thickness := WaterGrid.MAX_ICE_THICKNESS

var hovered_cell := Vector2i.ZERO
var has_hover := false
var last_message := "готово"

var _terrain: TerrainGrid
var _water: WaterGrid
var _service: WaterService


func configure(terrain: TerrainGrid, water: WaterGrid, service: WaterService) -> void:
	_terrain = terrain
	_water = water
	_service = service


# --- Hover --------------------------------------------------------------------

func update_hover(camera: Camera3D, space: PhysicsDirectSpaceState3D, mouse: Vector2) -> bool:
	if camera == null or space == null or _terrain == null:
		has_hover = false
		return false
	var origin := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + camera.project_ray_normal(mouse) * HOVER_RAY_LENGTH,
	)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	has_hover = not hit.is_empty()
	if has_hover:
		var point: Vector3 = hit["position"] - (hit["normal"] as Vector3) * 0.01
		hovered_cell = _terrain.cell_from_position(point)
		has_hover = _terrain.is_inside(hovered_cell)
	return has_hover


func clear_hover() -> void:
	has_hover = false


func brush_cells(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var radius := brush_size - 1
	for offset_z in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			var cell := center + Vector2i(offset_x, offset_z)
			if _water != null and _water.is_inside(cell):
				cells.append(cell)
	return cells


func adjust_brush_size(delta: int) -> void:
	brush_size = clampi(brush_size + delta, 1, MAX_BRUSH_SIZE)


func cycle_tool() -> void:
	tool = TOOLS[(TOOLS.find(tool) + 1) % TOOLS.size()]
	last_message = "инструмент: %s" % tool


func adjust_level(delta: int) -> void:
	level = clampi(level + delta, WaterGrid.MIN_HEIGHT, WaterGrid.MAX_HEIGHT)
	last_message = "уровень %d (%.1f м)" % [level, float(level) * TerrainGrid.HEIGHT_STEP]


## Takes the level from the ground under the cursor, one step above it — the
## natural gesture for "fill this hollow to just over that rock".
func pick_level_from_ground() -> void:
	if not has_hover or _terrain == null:
		return
	level = _terrain.height_of(hovered_cell) + 1
	last_message = "уровень с рельефа: %d" % level


func select_body(next_body_id: int) -> void:
	if _water == null or not _water.has_body(next_body_id):
		return
	body_id = next_body_id
	var body := _water.body(body_id)
	if body != null:
		level = body.surface_height
		last_message = "водоём: %s" % body.name


## Creates a body of a type and starts painting with it. The level the author has
## dialled in becomes the body's own, so a new lake remembers where its surface is
## and the palette can put the author back on it later.
func create_body(body_type: WaterBody.Type) -> WaterBody:
	if _service == null:
		return null
	var body := _service.create_body(body_type, level)
	if body == null:
		last_message = "больше водоёмов не поместится (максимум %d)" % WaterBody.MAX_ID
		return null
	body_id = body.id
	last_message = "создан водоём: %s" % body.name
	return body


func remove_selected_body() -> bool:
	if _service == null or body_id == WaterBody.NO_BODY:
		return false
	var removed := _service.remove_body(body_id)
	if removed:
		last_message = "водоём удалён"
		body_id = WaterBody.NO_BODY
		var remaining := _water.bodies()
		if not remaining.is_empty():
			select_body(remaining[0].id)
	return removed


# --- Strokes ------------------------------------------------------------------

## What the left button does, dispatched by tool. Called on press and again on
## every new column a drag crosses.
func apply() -> void:
	if not has_hover or _service == null:
		return
	match tool:
		TOOL_PAINT:
			_paint()
		TOOL_ERASE:
			_erase()
		TOOL_FLOOD:
			_flood()
		TOOL_FREEZE:
			_freeze(true)


func _paint() -> void:
	if body_id == WaterBody.NO_BODY:
		last_message = "сначала создайте водоём"
		return
	if _service.paint(brush_cells(hovered_cell), body_id, level):
		last_message = "залито клеток: %d" % _service.last_delta_size()
		return
	# Refusal is a normal answer here: a stroke entirely on ground above the
	# surface has nothing to fill, and saying so is more useful than a silent
	# no-op the author reads as a broken tool.
	last_message = "нечего заливать (%s)" % _service.last_rejection()


func _erase() -> void:
	if _service.erase(brush_cells(hovered_cell)):
		last_message = "осушено клеток: %d" % _service.last_delta_size()
		return
	last_message = "здесь нет воды"


func _flood() -> void:
	if body_id == WaterBody.NO_BODY:
		last_message = "сначала создайте водоём"
		return
	if _service.flood(hovered_cell, body_id, level):
		last_message = "низина залита: %d клеток" % _service.last_delta_size()
		return
	last_message = "низина не залилась (%s)" % _service.last_rejection()


func _freeze(frozen: bool) -> void:
	if _service.set_frozen(brush_cells(hovered_cell), frozen, ice_thickness):
		last_message = "%s: %d клеток" % ["лёд" if frozen else "оттепель", _service.last_delta_size()]
		return
	last_message = "лёд не встал (%s)" % _service.last_rejection()


## Right button: the opposite of the current tool. Painting erases, freezing
## thaws — one modifier instead of four extra tools.
func apply_secondary() -> void:
	if not has_hover or _service == null:
		return
	if tool == TOOL_FREEZE:
		_freeze(false)
		return
	_erase()


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
		last_message = "водоём %s" % ("замёрз" if freeze else "оттаял")
		return
	last_message = "состояние льда не изменилось (%s)" % _service.last_rejection()


func cycle_ice_thickness() -> void:
	ice_thickness = (ice_thickness % WaterGrid.MAX_ICE_THICKNESS) + 1
	last_message = "толщина льда %d" % ice_thickness


# --- History ------------------------------------------------------------------

func undo() -> void:
	last_message = "отмена" if _service.undo() else "нечего отменять"


func redo() -> void:
	last_message = "повтор" if _service.redo() else "нечего повторять"
