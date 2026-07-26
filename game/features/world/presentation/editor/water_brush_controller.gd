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
## The hovered column comes from the TERRAIN's collision, not the water's: the
## water surface has no collider (§9), and picking through it is what lets an
## author paint the bottom of a lake they can see through.

## What the left button does.
const TOOL_FLOOD := &"flood"
const TOOL_FREEZE := &"freeze"
const TOOLS: Array[StringName] = [TOOL_FLOOD, TOOL_FREEZE]

var tool: StringName = TOOL_FLOOD
## The body strokes go into. Zero until the author makes one — a stroke with no
## body is refused rather than quietly inventing a lake.
var body_id := WaterBody.NO_BODY
## Surface level in steps. Absolute and stamped, never stepped per cell: a drag
## overlaps its own path, and a brush defined as "one step deeper than what is
## here" digs a staircase instead of filling a basin.
var level := 0
var ice_thickness := WaterGrid.MAX_ICE_THICKNESS

var _terrain: TerrainGrid
var _water: WaterGrid
var _service: WaterService


func configure(terrain: TerrainGrid, water: WaterGrid, service: WaterService) -> void:
	_terrain = terrain
	_water = water
	_pick_grid = terrain
	_service = service


func cycle_tool() -> void:
	tool = TOOLS[(TOOLS.find(tool) + 1) % TOOLS.size()]
	last_message = "tool: %s" % tool


func adjust_level(delta: int) -> void:
	level = clampi(level + delta, WaterGrid.MIN_HEIGHT, WaterGrid.MAX_HEIGHT)
	last_message = "level %d (%.1f m)" % [level, float(level) * TerrainGrid.HEIGHT_STEP]


## Takes the level from the ground under the cursor, one step above it — the
## natural gesture for "fill this hollow to just over that rock".
func pick_level_from_ground() -> void:
	if not has_hover or _terrain == null:
		return
	level = _terrain.height_of(hovered_cell) + 1
	last_message = "level from ground: %d" % level


func select_body(next_body_id: int) -> void:
	if _water == null or not _water.has_body(next_body_id):
		return
	body_id = next_body_id
	var body := _water.body(body_id)
	if body != null:
		level = body.surface_height
		last_message = "body: %s" % body.name


## Creates a registry entry and selects it. It has no visible water until Flood
## fills a basin; creation is never a painted brush stroke.
func create_body(body_type: WaterBody.Type) -> WaterBody:
	if _service == null:
		return null
	var body := _service.create_body(body_type, level)
	if body == null:
		last_message = "no room for more bodies (max %d)" % WaterBody.MAX_ID
		return null
	body_id = body.id
	last_message = "created body: %s" % body.name
	return body


# --- Strokes ------------------------------------------------------------------

## What the left button does, dispatched by tool. Called on press and again on
## every new column a drag crosses.
func apply() -> void:
	if not has_hover or _service == null:
		return
	match tool:
		TOOL_FLOOD:
			_flood()
		TOOL_FREEZE:
			_freeze(true)


func _flood() -> void:
	if body_id == WaterBody.NO_BODY:
		last_message = "create a body first"
		return
	if _service.flood(hovered_cell, body_id, level):
		last_message = "flooded basin: %d cells" % _service.last_delta_size()
		return
	last_message = "basin did not flood (%s)" % _service.last_rejection()


func _freeze(frozen: bool) -> void:
	if _service.set_frozen(brush_cells(hovered_cell), frozen, ice_thickness):
		last_message = "%s: %d cells" % ["ice" if frozen else "thaw", _service.last_delta_size()]
		return
	last_message = "ice did not set (%s)" % _service.last_rejection()


## Right button is the inverse operation: thaw ice, or drain the entire body
## under the cursor. There is deliberately no per-cell erase for authored water.
func apply_secondary() -> void:
	if not has_hover or _service == null:
		return
	if tool == TOOL_FREEZE:
		_freeze(false)
		return
	_drain_body_at_hover()


func _drain_body_at_hover() -> void:
	var target_body := _water.body_id_at(hovered_cell) if _water != null else WaterBody.NO_BODY
	if target_body == WaterBody.NO_BODY:
		last_message = "no water body here"
		return
	if _service.remove_body(target_body):
		body_id = WaterBody.NO_BODY if body_id == target_body else body_id
		last_message = "drained whole body"
		return
	last_message = "could not drain (%s)" % _service.last_rejection()


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
		last_message = "body %s" % ("froze" if freeze else "thawed")
		return
	last_message = "ice state unchanged (%s)" % _service.last_rejection()


func cycle_ice_thickness() -> void:
	ice_thickness = (ice_thickness % WaterGrid.MAX_ICE_THICKNESS) + 1
	last_message = "ice thickness %d" % ice_thickness


# --- History ------------------------------------------------------------------

func undo() -> void:
	last_message = "undo" if _service.undo() else "nothing to undo"


func redo() -> void:
	last_message = "redo" if _service.redo() else "nothing to redo"
