class_name TestWaterBrush
extends RefCounted

## The water brush (design_docs/core/map_editor.md §3.1, §5.3).
##
## Same arrangement as `TestTerrainBrush`: no camera, no viewport, no scene —
## just the controller over the real grids and the real `WaterService`.
## Hover is set directly because ray picking needs a physics world.

const BOARD_CELLS := 32


static func run_all() -> void:
	_test_brush_covers_a_square_and_clips_at_the_edge()
	_test_flood_writes_through_the_service()
	_test_reverse_flood_drains_whole_body()
	_test_no_hover_means_no_edit()
	_test_no_body_means_refusal()
	_test_cycle_tool_rotates_flood_and_ice()
	_test_adjust_level_clamps()
	_test_pick_level_from_ground()
	_test_create_body_is_undoable()
	_test_undo_and_redo()
	_test_freeze_and_thaw()
	print("    [PASS] Water Brush Tests")


# --- Building blocks ----------------------------------------------------------

static func _make() -> Dictionary:
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, BOARD_CELLS)
	var water := WaterGrid.new()
	water.configure(terrain.cell_size, terrain.board_cells)
	var service := WaterService.new()
	service.configure(water, terrain)
	var brush := WaterBrushController.new()
	brush.configure(terrain, water, service)
	return {"terrain": terrain, "water": water, "service": service, "brush": brush}


## Puts the cursor on a column without a raycast.
static func _hover(brush: WaterBrushController, cell: Vector2i) -> void:
	brush.hovered_cell = cell
	brush.has_hover = true


## Creates a body and selects it, so Flood has a type and owner to use.
static func _make_body(world: Dictionary, type: WaterBody.Type = WaterBody.Type.LAKE) -> WaterBody:
	var brush: WaterBrushController = world["brush"]
	return brush.create_body(type)


# --- Brush shape --------------------------------------------------------------

static func _test_brush_covers_a_square_and_clips_at_the_edge() -> void:
	var world := _make()
	var brush: WaterBrushController = world["brush"]

	assert(brush.brush_size == 1)
	assert(brush.brush_cells(Vector2i.ZERO).size() == 1)

	brush.adjust_brush_size(2)
	assert(brush.brush_size == 3)
	assert(brush.brush_cells(Vector2i.ZERO).size() == 25)

	# Off the board the square is cut, not wrapped.
	var half := BOARD_CELLS / 2
	assert(brush.brush_cells(Vector2i(half - 1, half - 1)).size() == 9)

	brush.adjust_brush_size(-99)
	assert(brush.brush_size == 1)
	brush.adjust_brush_size(99)
	assert(brush.brush_size == WaterBrushController.MAX_BRUSH_SIZE)


# --- Flood --------------------------------------------------------------------

static func _test_flood_writes_through_the_service() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]

	# Dig a basin so Flood has somewhere to put water.
	var centre := Vector2i(0, 0)
	terrain.set_height(centre, -2)
	_make_body(world)
	brush.level = 0
	_hover(brush, centre)
	brush.apply()

	assert(water.has_water(centre))
	assert(water.body_id_at(centre) == brush.body_id)
	assert(water.height_of(centre) == 0)


static func _test_reverse_flood_drains_whole_body() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]

	var centre := Vector2i(0, 0)
	terrain.set_height(centre, -2)
	_make_body(world)
	brush.level = 0
	_hover(brush, centre)
	brush.apply()
	assert(water.has_water(centre))

	# Right click Flood drains the complete body, not a painted patch.
	brush.apply_secondary()
	assert(not water.has_water(centre))
	assert(not water.has_body(brush.body_id))


# --- Guards -------------------------------------------------------------------

static func _test_no_hover_means_no_edit() -> void:
	var world := _make()
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]

	brush.has_hover = false
	_make_body(world)
	brush.apply()
	# No hover, no crash, no edit.
	assert(not water.has_water(Vector2i.ZERO))


static func _test_no_body_means_refusal() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var brush: WaterBrushController = world["brush"]

	terrain.set_height(Vector2i.ZERO, -2)
	_hover(brush, Vector2i.ZERO)
	brush.body_id = WaterBody.NO_BODY
	brush.apply()
	assert(brush.last_message == "create a body first")


# --- Tool cycling -------------------------------------------------------------

static func _test_cycle_tool_rotates_flood_and_ice() -> void:
	var world := _make()
	var brush: WaterBrushController = world["brush"]

	assert(brush.tool == WaterBrushController.TOOL_FLOOD)
	brush.cycle_tool()
	assert(brush.tool == WaterBrushController.TOOL_FREEZE)
	brush.cycle_tool()
	assert(brush.tool == WaterBrushController.TOOL_FLOOD)


# --- Level --------------------------------------------------------------------

static func _test_adjust_level_clamps() -> void:
	var world := _make()
	var brush: WaterBrushController = world["brush"]

	brush.level = 0
	brush.adjust_level(-999)
	assert(brush.level == WaterGrid.MIN_HEIGHT)
	brush.adjust_level(999)
	assert(brush.level == WaterGrid.MAX_HEIGHT)


static func _test_pick_level_from_ground() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var brush: WaterBrushController = world["brush"]

	terrain.set_height(Vector2i(2, 3), -4)
	_hover(brush, Vector2i(2, 3))
	brush.pick_level_from_ground()
	assert(brush.level == -3)


# --- Body management ----------------------------------------------------------

static func _test_create_body_is_undoable() -> void:
	var world := _make()
	var brush: WaterBrushController = world["brush"]
	var water: WaterGrid = world["water"]

	var body := _make_body(world)
	assert(body != null)
	assert(brush.body_id == body.id)
	assert(water.has_body(body.id))

	assert(world["service"].undo())
	assert(not water.has_body(body.id))
	assert(world["service"].redo())
	assert(water.has_body(body.id))


# --- History ------------------------------------------------------------------

static func _test_undo_and_redo() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]

	var centre := Vector2i(0, 0)
	terrain.set_height(centre, -2)
	_make_body(world)
	brush.level = 0
	_hover(brush, centre)
	brush.apply()
	assert(water.has_water(centre))

	brush.undo()
	assert(not water.has_water(centre))

	brush.redo()
	assert(water.has_water(centre))


# --- Freeze -------------------------------------------------------------------

static func _test_freeze_and_thaw() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]

	var centre := Vector2i(0, 0)
	terrain.set_height(centre, -2)
	_make_body(world)
	brush.level = 0
	_hover(brush, centre)
	brush.apply()
	assert(water.has_water(centre))

	brush.tool = WaterBrushController.TOOL_FREEZE
	brush.apply()
	assert(water.is_frozen(centre))

	# Right button while freezing = thaw.
	brush.apply_secondary()
	assert(not water.is_frozen(centre))
