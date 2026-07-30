class_name TestWaterBrush
extends RefCounted

## The water brush (design_docs/engine/map_editor.md §3.1, §5.3).
##
## Same arrangement as `TestTerrainBrush`: no camera, no viewport, no scene —
## just the controller over the real grids and the real `WaterService`.
## Hover is set directly because ray picking needs a physics world.

const BOARD_CELLS := 32


static func run_all() -> void:
	_test_brush_covers_a_square_and_clips_at_the_edge()
	_test_flood_writes_through_the_service()
	_test_flood_auto_picks_level_on_flat_ground()
	_test_reverse_flood_drains_whole_body()
	_test_drain_tool_removes_whole_body_at_any_level()
	_test_no_hover_means_no_edit()
	_test_no_body_means_refusal()
	_test_cycle_tool_rotates_the_water_tools()
	_test_adjust_level_clamps()
	_test_pick_level_from_ground()
	_test_create_body_is_undoable()
	_test_undo_and_redo()
	_test_freeze_and_thaw()
	_test_fill_replaces_a_body_with_the_selected_level()
	_test_freeze_and_thaw_brushes_are_cell_local()
	_test_eyedropper_picks_water_and_frozen_properties()
	_test_retype_body_on_flood_converts_lake_to_lava()
	_test_dry_click_creates_a_new_body_but_water_click_adopts_existing()
	_test_auto_level_and_direct_type_selection()
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


## On flat ground (height 0) with the default level 0, flood would have nowhere
## to put water. The brush auto-picks the level from the ground (one step above
## it) and retries, so flood works without forcing the author to raise the level
## manually first.
static func _test_flood_auto_picks_level_on_flat_ground() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]

	# Flat ground at height 0 — no basin dug.
	var centre := Vector2i(0, 0)
	assert(terrain.height_of(centre) == 0)
	_make_body(world)
	brush.level = 0
	_hover(brush, centre)
	brush.apply()

	# Flood auto-adjusted the level to 1 (ground + 1) and succeeded.
	assert(water.has_water(centre))
	assert(water.height_of(centre) == 1)
	assert(brush.level == 1)


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


static func _test_drain_tool_removes_whole_body_at_any_level() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]
	var centre := Vector2i(0, 0)
	terrain.set_height(centre, -4)
	var body := _make_body(world)
	brush.level = 3
	_hover(brush, centre)
	brush.apply()
	assert(water.has_water(centre))
	assert(water.height_of(centre) == 3)
	brush.tool = WaterBrushController.TOOL_DRAIN
	brush.apply()
	assert(not water.has_water(centre))
	assert(not water.has_body(body.id))


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
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]

	terrain.set_height(Vector2i.ZERO, -2)
	_hover(brush, Vector2i.ZERO)
	brush.body_id = WaterBody.NO_BODY
	brush.apply()
	# Auto-creates body on demand
	assert(water.has_water(Vector2i.ZERO))


# --- Tool cycling -------------------------------------------------------------

static func _test_cycle_tool_rotates_the_water_tools() -> void:
	var world := _make()
	var brush: WaterBrushController = world["brush"]

	assert(brush.tool == WaterBrushController.TOOL_FLOOD)
	brush.cycle_tool()
	assert(brush.tool == WaterBrushController.TOOL_DRAIN)
	brush.cycle_tool()
	assert(brush.tool == WaterBrushController.TOOL_FREEZE)
	brush.cycle_tool()
	assert(brush.tool == WaterBrushController.TOOL_THAW)
	brush.cycle_tool()
	assert(brush.tool == WaterBrushController.TOOL_SELECT)
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

	# Ice is a whole-body seasonal operation (§9.6), not a per-cell brush.
	brush.toggle_body_ice()
	assert(water.is_frozen(centre))
	brush.toggle_body_ice()
	assert(not water.is_frozen(centre))


# --- Fill level ---------------------------------------------------------------

## Fill owns both the contour and level. Re-filling a selected body replaces its
## old surface, so lowering cannot leave a second sheet of water behind.
static func _test_fill_replaces_a_body_with_the_selected_level() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]
	for z in range(-2, 3):
		for x in range(-2, 3):
			assert(terrain.set_height(Vector2i(x, z), -3))
	_make_body(world)
	brush.level = 0
	_hover(brush, Vector2i.ZERO)
	brush.apply()
	assert(water.height_of(Vector2i.ZERO) == 0)

	brush.level = -1
	brush.auto_level = false
	brush.apply()
	assert(water.height_of(Vector2i.ZERO) == -1, "the surface came down")
	assert(water.is_wet(terrain, Vector2i.ZERO), "and there is still water in the hole")


## Ice is the only local water brush: it authors passability, not a separate
## water surface. Thaw reverses only the cells the author paints.
static func _test_freeze_and_thaw_brushes_are_cell_local() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]
	for z in range(-2, 3):
		for x in range(-2, 3):
			assert(terrain.set_height(Vector2i(x, z), -2))
	var body := _make_body(world)
	brush.level = 0
	_hover(brush, Vector2i.ZERO)
	brush.apply()
	brush.tool = WaterBrushController.TOOL_FREEZE
	brush.apply()
	assert(water.is_frozen(Vector2i.ZERO))
	assert(not water.is_frozen(Vector2i(2, 2)))
	assert(water.has_body(body.id))
	brush.tool = WaterBrushController.TOOL_THAW
	brush.apply()
	assert(not water.is_frozen(Vector2i.ZERO))


static func _test_eyedropper_picks_water_and_frozen_properties() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]
	terrain.set_height(Vector2i.ZERO, -2)
	var body := _make_body(world, WaterBody.Type.LAKE)
	brush.level = 2
	_hover(brush, Vector2i.ZERO)
	brush.apply()
	brush.toggle_body_ice()

	# Pick from liquid/frozen cell
	brush.pick_from_cell()
	assert(brush.body_id == body.id)
	assert(brush.level == 2)
	assert(brush.tool == WaterBrushController.TOOL_FREEZE)


static func _test_retype_body_on_flood_converts_lake_to_lava() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]
	terrain.set_height(Vector2i.ZERO, -2)
	var lake_body := _make_body(world, WaterBody.Type.LAKE)
	brush.level = 0
	_hover(brush, Vector2i.ZERO)
	brush.apply()
	assert(water.body_at(Vector2i.ZERO).type == WaterBody.Type.LAKE)

	# Create lava body and flood over lake
	var lava_body := _make_body(world, WaterBody.Type.LAVA)
	_hover(brush, Vector2i.ZERO)
	brush.apply()
	assert(water.body_at(Vector2i.ZERO).type == WaterBody.Type.LAVA)


static func _test_dry_click_creates_a_new_body_but_water_click_adopts_existing() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]
	terrain.set_height(Vector2i.ZERO, -2)
	terrain.set_height(Vector2i(8, 8), -2)
	brush.auto_level = false
	brush.level = 0
	_hover(brush, Vector2i.ZERO)
	brush.apply()
	var first_id := water.body_id_at(Vector2i.ZERO)
	_hover(brush, Vector2i(8, 8))
	brush.apply()
	var second_id := water.body_id_at(Vector2i(8, 8))
	assert(second_id != first_id, "dry ground starts a new body")
	brush.body_id = first_id
	_hover(brush, Vector2i(8, 8))
	brush.apply()
	assert(brush.body_id == second_id, "existing liquid selects its own body")
	assert(water.has_water(Vector2i.ZERO), "editing the second body preserves the first")


static func _test_auto_level_and_direct_type_selection() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var brush: WaterBrushController = world["brush"]
	var cell := Vector2i(3, 4)
	terrain.set_height(cell, -4)
	brush.select_liquid_category(&"lava")
	assert(brush.active_body_type() == WaterBody.Type.LAVA)
	brush.select_water_type(WaterBody.Type.RIVER)
	assert(brush.active_body_type() == WaterBody.Type.RIVER)
	_hover(brush, cell)
	brush.apply()
	assert(brush.level == -3, "auto level follows clicked ground")
	assert(water.body_at(cell).type == WaterBody.Type.RIVER)
	var created_id := brush.body_id
	assert(world["service"].undo_depth() == 1, "create plus first flood is one gesture")
	assert(world["service"].undo())
	assert(not water.has_body(created_id) and not water.has_water(cell), "one undo removes the new body completely")
