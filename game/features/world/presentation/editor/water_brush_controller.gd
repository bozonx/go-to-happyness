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
const TOOL_FLOOD := &"flood"
const TOOL_LEVEL := &"level"
const TOOL_FREEZE := &"freeze"
const TOOL_THAW := &"thaw"
const TOOLS: Array[StringName] = [TOOL_FLOOD, TOOL_LEVEL, TOOL_FREEZE, TOOL_THAW]

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
## every new column a drag crosses. When the hovered cell belongs to a body whose
## type differs from the selected body's type, the body is retyped first — one
## click converts an entire body, except border bodies which are protected.
func apply() -> void:
	if not has_hover or _service == null:
		return
	if tool == TOOL_FLOOD:
		_maybe_retype_hovered_body()
	match tool:
		TOOL_FLOOD:
			_flood()
		TOOL_LEVEL:
			_set_level()
		TOOL_FREEZE:
			_set_frozen(true)
		TOOL_THAW:
			_set_frozen(false)


func _flood() -> void:
	if body_id == WaterBody.NO_BODY:
		last_message = "create a body first"
		return
	if _service.flood(hovered_cell, body_id, level):
		last_message = "flooded basin: %d cells" % _service.last_delta_size()
		return
	# If the ground is at or above the level, the basin has no depth to fill.
	# Pick the level from the ground (one step above it) and try again, so
	# flood works on flat terrain without forcing the author to raise the
	# level manually first.
	if _terrain != null and _service.last_rejection() == WaterService.REASON_NOTHING_TO_DO:
		var ground := _terrain.height_of(hovered_cell)
		if level <= ground:
			level = ground + 1
			if _service.flood(hovered_cell, body_id, level):
				last_message = "flooded basin (level %d): %d cells" % [level, _service.last_delta_size()]
				return
	last_message = "basin did not flood (%s)" % _service.last_rejection()


## Moves the surface of the water already under the brush, without changing which
## body it belongs to. This is the one operation Flood cannot express: re-flooding
## at a lower level reaches fewer cells and leaves the rest standing at the old
## one, so a lake could be raised and never lowered.
func _set_level() -> void:
	if body_id == WaterBody.NO_BODY:
		last_message = "select a water body first"
		return
	if _service.set_body_level(body_id, level):
		last_message = "body level %d: %d cells" % [level, _service.last_delta_size()]
		return
	last_message = "level unchanged (%s)" % _service.last_rejection()


## Erase removes the whole body under the cursor, not a patch of cells. Water is
## authored per body — a lake is one entity with one level — so erasing a cell at a
## time would leave a half-drained body with no surface, which is not a state the
## author can meaningfully inspect or continue editing.
func _set_frozen(frozen: bool) -> void:
	if _service.set_frozen(brush_cells(hovered_cell), frozen, ice_thickness):
		last_message = "%s: %d cells" % ["froze" if frozen else "thawed", _service.last_delta_size()]
		return
	last_message = "ice unchanged (%s)" % _service.last_rejection()


## Right button is the inverse or the complement of the left one: drain the whole
## body under the cursor, except under the level tool, where the useful opposite of
## "stamp this level" is "take the level from here".
func apply_secondary() -> void:
	if not has_hover or _service == null:
		return
	if tool == TOOL_LEVEL:
		pick_level_from_ground()
		return
	_drain_body_at_hover()


func _drain_body_at_hover() -> void:
	var target_body := _water.body_id_at(hovered_cell) if _water != null else WaterBody.NO_BODY
	if target_body == WaterBody.NO_BODY:
		last_message = "no water body here"
		return
	if _border != null and _border.is_border_body(target_body):
		last_message = "border body cannot be drained — raise the ground above the level"
		return
	if _service.remove_body(target_body):
		body_id = WaterBody.NO_BODY if body_id == target_body else body_id
		last_message = "drained whole body"
		return
	last_message = "could not drain (%s)" % _service.last_rejection()


## When the hovered cell belongs to a body whose type differs from the selected
## body's type, retypes the hovered body to match. Border bodies are protected:
## they cannot be retyped, only drained by raising the ground.
func _maybe_retype_hovered_body() -> void:
	if _water == null or body_id == WaterBody.NO_BODY:
		return
	var selected := _water.body(body_id)
	if selected == null:
		return
	var hovered_id := _water.body_id_at(hovered_cell)
	if hovered_id == WaterBody.NO_BODY or hovered_id == body_id:
		return
	var hovered_body := _water.body(hovered_id)
	if hovered_body == null or hovered_body.type == selected.type:
		return
	if _border != null and _border.is_border_body(hovered_id):
		last_message = "border body cannot be retyped"
		return
	if _service.retype_body(hovered_id, selected.type):
		last_message = "retyped %s to %s" % [hovered_body.name, selected.type_id()]


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
