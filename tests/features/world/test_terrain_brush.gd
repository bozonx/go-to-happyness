class_name TestTerrainBrush
extends RefCounted

## The shared terrain brush (design_docs/engine/map_editor.md §3.1, §3.6).
##
## The whole point of extracting it was that three hosts — the laboratory, the map
## editor and the `Terrain Base` layer of the building editor — drive one tool.
## That only holds if the tool is testable without any of them, which is what this
## file asserts: no camera, no viewport, no scene, just the controller over the
## real grid and the real `TerrainService`.
##
## Hover picking is deliberately absent: it needs a physics raycast against a
## meshed board, and it is the one part of the controller a host cannot supply
## from data. Everything downstream of it is exercised by writing `hovered_cell`.

const BOARD_CELLS := 32


static func run_all() -> void:
	_test_brush_covers_a_square_and_clips_at_the_edge()
	_test_height_brush_edits_through_the_service()
	_test_level_mode_latches_a_plateau_height_for_the_stroke()
	_test_no_hover_means_no_edit()
	print("    [PASS] Terrain Brush Tests")
	_test_material_pick_clamps_the_variant()
	_test_paint_and_detail_reach_the_grid()
	_test_detail_brushes_are_idempotent_under_a_drag()
	print("    [PASS] Terrain Brush Surface Tests")
	_test_a_sculpt_drag_lays_one_layer()
	_test_a_stroke_ends_when_the_button_is_released()
	_test_circle_brush_drops_the_corners()
	_test_falloff_rounds_the_shoulder_of_a_mound()
	print("    [PASS] Terrain Brush Stroke Tests")
	_test_ramp_cycles_stay_inside_the_catalog()
	_test_material_picker_copies_material_and_variant()
	_test_undo_reports_through_the_message()
	print("    [PASS] Terrain Brush Tool Tests")


static func _make() -> Dictionary:
	var grid := TerrainGrid.new()
	grid.configure(1.0, BOARD_CELLS)
	var service := TerrainService.new()
	service.configure(grid)
	var wear := SurfaceWearService.new()
	wear.configure(service)
	var brush := TerrainBrushController.new()
	brush.configure(grid, service, wear)
	return {"grid": grid, "service": service, "wear": wear, "brush": brush}


## Puts the cursor on a column without a raycast.
static func _hover(brush: TerrainBrushController, cell: Vector2i) -> void:
	brush.hovered_cell = cell
	brush.has_hover = true


# --- Brush shape --------------------------------------------------------------

static func _test_brush_covers_a_square_and_clips_at_the_edge() -> void:
	var world := _make()
	var brush: TerrainBrushController = world["brush"]

	assert(brush.brush_size == 1)
	assert(brush.brush_cells(Vector2i.ZERO).size() == 1)

	brush.adjust_brush_size(2)
	assert(brush.brush_size == 3)
	assert(brush.brush_cells(Vector2i.ZERO).size() == 25)

	# Off the board the square is cut, not wrapped: a brush at the corner edits
	# only what exists.
	var half := BOARD_CELLS / 2
	assert(brush.brush_cells(Vector2i(half - 1, half - 1)).size() == 9)

	# The size is clamped at both ends rather than running negative.
	brush.adjust_brush_size(-99)
	assert(brush.brush_size == 1)
	brush.adjust_brush_size(99)
	assert(brush.brush_size == TerrainBrushController.MAX_BRUSH_SIZE)


# --- Height -------------------------------------------------------------------

## The rule from AGENTS.md, asserted rather than trusted: the brush never writes
## the grid directly, so undo, the mesher and navigation all see the edit.
static func _test_height_brush_edits_through_the_service() -> void:
	var world := _make()
	var brush: TerrainBrushController = world["brush"]
	var grid: TerrainGrid = world["grid"]
	var service: TerrainService = world["service"]

	_hover(brush, Vector2i(0, 0))
	brush.apply_height_brush(1)
	assert(grid.height_of(Vector2i(0, 0)) == 1)
	assert(service.undo_depth() == 1)

	brush.apply_height_brush(-1)
	assert(grid.height_of(Vector2i(0, 0)) == 0)
	assert(service.undo_depth() == 2)

	# A drag paints on press and then on every column it crosses, and stops when
	# the button is released.
	brush.set_paint_direction(1)
	assert(brush.is_painting())
	assert(grid.height_of(Vector2i(0, 0)) == 1)
	brush.set_paint_direction(0)
	assert(not brush.is_painting())

	# paint_direction() reports which button started the drag: +1 for LMB,
	# -1 for Shift+RMB. A host uses this to avoid stopping an LMB stroke when
	# RMB is released without Shift.
	brush.set_paint_direction(1)
	assert(brush.paint_direction() == 1)
	brush.set_paint_direction(0)
	assert(brush.paint_direction() == 0)
	brush.set_paint_direction(-1)
	assert(brush.paint_direction() == -1)
	brush.set_paint_direction(0)


static func _test_level_mode_latches_a_plateau_height_for_the_stroke() -> void:
	var world := _make()
	var brush: TerrainBrushController = world["brush"]
	var grid: TerrainGrid = world["grid"]

	brush.adjust_brush_size(1)
	_hover(brush, Vector2i(0, 0))
	brush.apply_height_brush(2)
	var raised := grid.height_of(Vector2i(0, 0))
	assert(raised == 2)

	# Level captures its absolute target at the start of a stroke and preserves it
	# as the cursor travels, rather than recalculating from every new column.
	brush.edit_mode = TerrainEditOperation.Mode.LEVEL
	brush.set_paint_direction(1)
	assert(brush.level_target_height() == raised)
	_hover(brush, Vector2i(4, 0))
	brush.apply_height_brush(1)
	for cell: Vector2i in brush.brush_cells(Vector2i(4, 0)):
		assert(grid.height_of(cell) == raised)
	brush.adjust_level_target(-1)
	_hover(brush, Vector2i(7, 0))
	brush.apply_height_brush(1)
	for cell: Vector2i in brush.brush_cells(Vector2i(7, 0)):
		assert(grid.height_of(cell) == raised - 1)
	brush.set_paint_direction(0)

	# Flatten takes the hovered height as it stands and spreads it.
	_hover(brush, Vector2i(8, 8))
	brush.edit_mode = TerrainEditOperation.Mode.SCULPT
	brush.apply_height_brush(3)
	brush.apply_flatten()
	for cell: Vector2i in brush.brush_cells(Vector2i(8, 8)):
		assert(grid.height_of(cell) == grid.height_of(Vector2i(8, 8)))


## Every tool is a no-op with the cursor off the board. A host that forgets to
## clear the hover must not be able to edit the corner cell by accident.
static func _test_no_hover_means_no_edit() -> void:
	var world := _make()
	var brush: TerrainBrushController = world["brush"]
	var service: TerrainService = world["service"]

	brush.clear_hover()
	brush.apply_height_brush(1)
	brush.apply_flatten()
	brush.apply_material()
	brush.cycle_variant()
	brush.cycle_wear()
	brush.cycle_snow()
	brush.walk_the_brush()
	brush.toggle_hole()
	brush.place_ramp()
	brush.dissolve_ramp()
	assert(service.undo_depth() == 0)
	assert(brush.variant == 1, "variant selection is brush state even without hover")


# --- Surface ------------------------------------------------------------------

## Materials do not all carry the same number of variants, so a variant picked on
## a rich material must not leak onto a poor one as an out-of-range index.
static func _test_material_pick_clamps_the_variant() -> void:
	var world := _make()
	var brush: TerrainBrushController = world["brush"]

	for index in TerrainMaterialCatalog.count():
		brush.set_material_index(index)
		assert(brush.material_index == index)
		assert(brush.material_id() == TerrainMaterialCatalog.ids()[index])
		assert(brush.variant < TerrainMaterialVariants.variant_count(index))

	# Out of range is refused rather than clamped: a paged number row that
	# addresses past the end of the catalog must leave the pick alone.
	var last := TerrainMaterialCatalog.count() - 1
	brush.set_material_index(TerrainMaterialCatalog.count())
	assert(brush.material_index == last)
	brush.set_material_index(-1)
	assert(brush.material_index == last)


static func _test_paint_and_detail_reach_the_grid() -> void:
	var world := _make()
	var brush: TerrainBrushController = world["brush"]
	var grid: TerrainGrid = world["grid"]

	_hover(brush, Vector2i(2, 2))
	brush.set_material_index(TerrainMaterialCatalog.index_of(TerrainMaterialCatalog.MUD))
	brush.apply_material()
	assert(grid.material_of(Vector2i(2, 2)) == TerrainMaterialCatalog.MUD)

	brush.cycle_wear()
	assert(grid.wear_at(Vector2i(2, 2)) == 1)
	brush.cycle_snow()
	assert(grid.snow_depth_at(Vector2i(2, 2)) == 1)

	brush.toggle_hole()
	assert(grid.is_hole(Vector2i(2, 2)))
	brush.toggle_hole()
	assert(not grid.is_hole(Vector2i(2, 2)))


## A brush is dragged, and a drag overlaps its own path: with a 5×5 brush moving
## one cell at a time, a column is covered five times over. So every brush
## operation has to be idempotent, or a single stroke leaves a stripe of every
## value instead of a band of one.
##
## This is a real defect that shipped and was seen on screen: wear and snow were
## wired to the laboratory's `cycle` affordance — "one more than what is here" —
## which is correct for one keypress and wrong for every drag. The regression it
## guards is the pattern `0123012301230…` across a stroke.
static func _test_detail_brushes_are_idempotent_under_a_drag() -> void:
	var world := _make()
	var brush: TerrainBrushController = world["brush"]
	var grid: TerrainGrid = world["grid"]
	brush.has_hover = true
	brush.adjust_brush_size(2) # 5×5

	for x in range(-6, 7):
		brush.hovered_cell = Vector2i(x, 0)
		brush.paint_snow(TerrainDetailCodec.MAX_SNOW_DEPTH)
		brush.paint_wear(TerrainDetailCodec.MAX_WEAR)

	# Everything the stroke covered carries the level that was painted, once.
	for x in range(-8, 9):
		for z in range(-2, 3):
			var depth := grid.snow_depth_at(Vector2i(x, z))
			assert(depth == TerrainDetailCodec.MAX_SNOW_DEPTH, "snow at %d,%d is %d" % [x, z, depth])
			assert(grid.wear_at(Vector2i(x, z)) == TerrainDetailCodec.MAX_WEAR)
	# ...and nothing outside it does.
	assert(grid.snow_depth_at(Vector2i(9, 0)) == 0)

	# Repainting the same level is not an edit at all, so a held brush that never
	# moves does not fill the undo stack with nothing.
	var depth_before: int = world["service"].undo_depth()
	brush.paint_snow(TerrainDetailCodec.MAX_SNOW_DEPTH)
	assert(world["service"].undo_depth() == depth_before, "repainting the same level changed nothing")

	# Cycling remains available for the keyboard, and still steps by one.
	brush.hovered_cell = Vector2i(0, 0)
	brush.paint_snow(0)
	brush.cycle_snow()
	assert(grid.snow_depth_at(Vector2i(0, 0)) == 1)


# --- Ramps and history --------------------------------------------------------

static func _test_material_picker_copies_material_and_variant() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["grid"]
	var brush: TerrainBrushController = world["brush"]
	var cell := Vector2i(3, 2)
	terrain.set_material_index(cell, TerrainMaterialCatalog.index_of(TerrainMaterialCatalog.MUD))
	terrain.set_variant(cell, 1)
	_hover(brush, cell)
	brush.pick_material()
	assert(brush.material_id() == TerrainMaterialCatalog.MUD)
	assert(brush.variant == 1)


static func _test_ramp_cycles_stay_inside_the_catalog() -> void:
	var world := _make()
	var brush: TerrainBrushController = world["brush"]

	var seen: Array[int] = []
	for _step in SlopeCatalog.ramp_ids().size() + 1:
		brush.cycle_ramp_class()
		assert(SlopeCatalog.id_of_class(brush.ramp_class) != &"")
		if not seen.has(brush.ramp_class):
			seen.append(brush.ramp_class)
	# The cycle visits every ramp class and then wraps.
	assert(seen.size() == SlopeCatalog.ramp_ids().size())

	var directions: Array[int] = []
	for _step in SlopeCatalog.ORTHOGONAL_DIRECTIONS.size():
		brush.cycle_ramp_direction()
		assert(not directions.has(brush.ramp_direction))
		directions.append(brush.ramp_direction)
		assert(TerrainBrushController.direction_name(brush.ramp_direction).length() == 1)
	var terrain_profiles: Array[int] = []
	for _step in SlopeCatalog.ramp_ids().size() + 1:
		brush.cycle_terrain_slope_class()
		terrain_profiles.append(brush.terrain_slope_class)
	assert(terrain_profiles.has(RampConnectionPlan.AUTO_CLASS))
	for slope_class: int in SlopeCatalog.RAMP_CLASSES:
		assert(terrain_profiles.has(slope_class))


## The message is the only thing a host has to report an outcome with, so an
## empty history has to say so instead of reading as success.
static func _test_undo_reports_through_the_message() -> void:
	var world := _make()
	var brush: TerrainBrushController = world["brush"]
	var grid: TerrainGrid = world["grid"]

	brush.undo()
	assert(brush.last_message == "нечего отменять")

	_hover(brush, Vector2i(4, 4))
	brush.apply_height_brush(1)
	assert(grid.height_of(Vector2i(4, 4)) == 1)
	brush.undo()
	assert(brush.last_message == "отменено")
	assert(grid.height_of(Vector2i(4, 4)) == 0)
	brush.redo()
	assert(brush.last_message == "повторено")
	assert(grid.height_of(Vector2i(4, 4)) == 1)


# --- Strokes ------------------------------------------------------------------

## A drag is a footprint being pulled across the ground, not a stamp re-applied at
## every column the cursor enters. Since the brush square overlaps its own path,
## re-applying meant every cell inside it got the step again for each column of
## travel: a size-3 brush left a +5 ramp where the author asked for a +1 band, and
## a size-8 brush left +15. The stroke remembers the columns it has moved.
static func _test_a_sculpt_drag_lays_one_layer() -> void:
	var world := _make()
	var brush: TerrainBrushController = world["brush"]
	var grid: TerrainGrid = world["grid"]
	brush.brush_size = 3
	brush.edit_mode = TerrainEditOperation.Mode.SCULPT

	_hover(brush, Vector2i(-6, 0))
	brush.set_paint_direction(1)
	for x in range(-5, 7):
		var previous := brush.hovered_cell
		_hover(brush, Vector2i(x, 0))
		brush._on_hover_changed(previous, true)
	brush.set_paint_direction(0)

	for x in range(-4, 5):
		assert(grid.height_of(Vector2i(x, 0)) == 1, "the swept band is raised by exactly one step")

	# The same two columns crossed back and forth cannot keep climbing either.
	var wiggle := _make()
	var jitter: TerrainBrushController = wiggle["brush"]
	var jitter_grid: TerrainGrid = wiggle["grid"]
	_hover(jitter, Vector2i(0, 0))
	jitter.set_paint_direction(1)
	for _pass in 8:
		var previous := jitter.hovered_cell
		_hover(jitter, Vector2i(1, 0))
		jitter._on_hover_changed(previous, true)
		previous = jitter.hovered_cell
		_hover(jitter, Vector2i(0, 0))
		jitter._on_hover_changed(previous, true)
	jitter.set_paint_direction(0)
	assert(jitter_grid.height_of(Vector2i(0, 0)) == 1)
	assert(jitter_grid.height_of(Vector2i(1, 0)) == 1)


## Releasing the button ends the layer: pressing again over the same ground is a
## second, deliberate step, which is how a hill gets built.
static func _test_a_stroke_ends_when_the_button_is_released() -> void:
	var world := _make()
	var brush: TerrainBrushController = world["brush"]
	var grid: TerrainGrid = world["grid"]

	_hover(brush, Vector2i(2, 2))
	for _press in 3:
		brush.set_paint_direction(1)
		brush.set_paint_direction(0)
	assert(grid.height_of(Vector2i(2, 2)) == 3)


# --- Shape and falloff --------------------------------------------------------

static func _test_circle_brush_drops_the_corners() -> void:
	var world := _make()
	var brush: TerrainBrushController = world["brush"]
	brush.brush_size = 3

	brush.brush_shape = BaseBrushController.Shape.SQUARE
	assert(brush.brush_cells(Vector2i.ZERO).size() == 25)

	brush.brush_shape = BaseBrushController.Shape.CIRCLE
	var round_cells := brush.brush_cells(Vector2i.ZERO)
	assert(round_cells.size() < 25, "a circle covers less than its bounding square")
	assert(not round_cells.has(Vector2i(2, 2)), "and drops the corners first")
	assert(round_cells.has(Vector2i(2, 0)), "while keeping the full radius on the axes")

	brush.cycle_brush_shape()
	assert(brush.brush_shape == BaseBrushController.Shape.SQUARE, "cycling wraps back")


## A weighted brush still writes whole columns (§2.1): the step is scaled and
## rounded, never stored as a fraction. What it buys is a mound with a shoulder
## instead of a flat-topped block.
static func _test_falloff_rounds_the_shoulder_of_a_mound() -> void:
	var world := _make()
	var brush: TerrainBrushController = world["brush"]
	var grid: TerrainGrid = world["grid"]
	brush.brush_size = 4
	brush.brush_shape = BaseBrushController.Shape.CIRCLE
	brush.brush_falloff = BaseBrushController.Falloff.LINEAR

	var weights := brush.brush_weights(Vector2i.ZERO)
	var cells := brush.brush_cells(Vector2i.ZERO)
	assert(weights.size() == cells.size(), "weights stay parallel to the footprint")
	assert(is_equal_approx(weights[cells.find(Vector2i.ZERO)], 1.0), "full strength at the centre")
	assert(weights[cells.find(Vector2i(3, 0))] < 0.35, "and almost nothing at the rim")

	_hover(brush, Vector2i.ZERO)
	brush.apply_height_brush(4)
	var centre := grid.height_of(Vector2i.ZERO)
	var shoulder := grid.height_of(Vector2i(2, 0))
	var rim := grid.height_of(Vector2i(3, 0))
	assert(centre == 4, "the centre gets the whole step")
	assert(shoulder > 0 and shoulder < centre, "the shoulder gets part of it")
	assert(rim <= shoulder, "and the rim less again")

	# Every height the weighted brush wrote is still a whole number of steps —
	# there is no fractional column anywhere on the board.
	for z in range(-4, 5):
		for x in range(-4, 5):
			assert(grid.height_of(Vector2i(x, z)) == int(grid.height_of(Vector2i(x, z))))
