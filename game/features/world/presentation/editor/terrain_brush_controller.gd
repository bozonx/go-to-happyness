class_name TerrainBrushController
extends BaseBrushController

## The terrain brush itself, with no host around it (map_editor.md §3.1, §3.6).
##
## Everything an author does to the ground — raise, level, paint, wear, snow,
## hole, ramp — lives here once, so the terrain laboratory, the map editor and
## the `Terrain Base` layer of the building editor drive the same tool instead of
## growing three implementations that drift apart.
##
## The controller owns brush state (size, edit mode, picked material and variant,
## ramp class and direction), the hovered column, and the outcome message of the
## last operation. It owns no nodes: the host draws the hover marker, prints the
## message and binds the keys. Edits always go through `TerrainService`, never
## into the grid directly, which is what keeps undo, the chunk mesher and the
## published navigation field in step.

var edit_mode := TerrainEditOperation.Mode.SCULPT
var material_index := 0
var variant := 0
var ramp_class := SlopeCatalog.CLASS_GENTLE
var ramp_direction := SlopeCatalog.DIR_E

var _grid: TerrainGrid
var _service: TerrainService
var _wear_service: SurfaceWearService
## Non-zero while a drag paints: +1 raises, -1 lowers, applied again whenever the
## cursor crosses into a new column.
var _paint_direction := 0
## The absolute plateau height captured when a Level stroke starts.  It must not
## follow the hovered column: doing so turns Level into another sculpt brush.
var _level_target_height := 0
var _has_level_target := false
var _wear_day := 0


func configure(grid: TerrainGrid, service: TerrainService, wear_service: SurfaceWearService = null) -> void:
	_grid = grid
	_pick_grid = grid
	_service = service
	_wear_service = wear_service


# --- Hover ------------------------------------------------------------------

## Applies the height brush while a drag is painting and the cursor crosses into
## a new column.
func _on_hover_changed(previous_cell: Vector2i, had_hover: bool) -> void:
	if has_hover and _paint_direction != 0 and (not had_hover or previous_cell != hovered_cell):
		apply_height_brush(_paint_direction)


## Starts or stops a painting drag. Non-zero also applies the brush at once, so a
## click that never moves still edits the column under it.
func set_paint_direction(direction: int) -> void:
	if direction != 0 and _paint_direction == 0 and edit_mode == TerrainEditOperation.Mode.LEVEL:
		_capture_level_target()
	_paint_direction = direction
	if direction != 0:
		apply_height_brush(direction)
	else:
		_has_level_target = false


func is_painting() -> bool:
	return _paint_direction != 0


# --- Height -----------------------------------------------------------------

func apply_height_brush(delta: int) -> void:
	if not has_hover:
		return
	var operation := TerrainEditOperation.offset(brush_cells(hovered_cell), delta, edit_mode)
	if edit_mode == TerrainEditOperation.Mode.LEVEL:
		if not _has_level_target:
			_capture_level_target()
		operation = TerrainEditOperation.level(brush_cells(hovered_cell), _level_target_height)
	if _service.apply_operation(operation):
		last_message = "%s %+d — %d cells changed" % [
			TerrainEditOperation.mode_name(edit_mode), delta, _service.last_delta_size(),
		]
		return
	last_message = "%s %+d REFUSED (%s)" % [
		TerrainEditOperation.mode_name(edit_mode), delta, _service.last_rejection(),
	]


## Changes the captured plateau height without using the current column as a
## new reference.  Ctrl+wheel invokes this during a Level stroke.
func adjust_level_target(delta: int) -> void:
	if not _has_level_target:
		if not has_hover:
			return
		_capture_level_target()
	_level_target_height += delta
	last_message = "level target %d" % _level_target_height


func level_target_height() -> int:
	return _level_target_height


func _capture_level_target() -> void:
	if not has_hover:
		return
	_level_target_height = _grid.height_of(hovered_cell)
	_has_level_target = true


func apply_flatten() -> void:
	if not has_hover:
		return
	var target := _grid.height_of(hovered_cell)
	if _service.apply_operation(TerrainEditOperation.level(brush_cells(hovered_cell), target)):
		last_message = "levelled to %d" % target
		return
	last_message = "level REFUSED (%s)" % _service.last_rejection()


func cycle_edit_mode() -> void:
	edit_mode = (edit_mode + 1) % TerrainEditOperation.Mode.size()
	last_message = "mode %s" % TerrainEditOperation.mode_name(edit_mode)


# --- Surface ----------------------------------------------------------------

func set_material_index(index: int) -> void:
	if index < 0 or index >= TerrainMaterialCatalog.count():
		return
	material_index = index
	variant = TerrainMaterialVariants.clamp_variant(material_index, variant)
	last_message = "material %s" % TerrainMaterialCatalog.ids()[material_index]


func material_id() -> StringName:
	return TerrainMaterialCatalog.ids()[material_index]


## Picks the complete paint state, so the next surface stroke has the clicked
## material and its authored variant rather than only the base material.
func pick_material() -> void:
	if not has_hover or _grid == null:
		return
	material_index = _grid.material_index_at(hovered_cell)
	variant = _grid.variant_at(hovered_cell)
	last_message = "picked %s/%s" % [material_id(), TerrainMaterialVariants.variant_name(material_index, variant)]


func apply_material() -> void:
	if not has_hover:
		return
	var id := material_id()
	if _service.paint_material(brush_cells(hovered_cell), id, variant):
		last_message = "painted %s/%s" % [id, TerrainMaterialVariants.variant_name(material_index, variant)]
		return
	last_message = "paint %s changed nothing" % id


func set_variant(next_variant: int) -> void:
	variant = TerrainMaterialVariants.clamp_variant(material_index, next_variant)
	last_message = "variant %s" % TerrainMaterialVariants.variant_name(material_index, variant)


## Variant selection is brush state, not a paint operation.  The next ordinary
## material stroke applies it, which also lets palette controls work after the
## pointer has left the 3D viewport.
func cycle_variant() -> void:
	set_variant((variant + 1) % TerrainMaterialVariants.variant_count(material_index))


## Paints a wear level over the brush. Absolute and therefore idempotent, which
## is what a DRAG needs: a stroke passes over the same column several times as
## the brush square overlaps its own path, and an operation defined as "one more
## than what is there" would leave a stripe of every value instead of a band of
## one.
func paint_wear(level: int) -> void:
	if not has_hover:
		return
	var clamped := clampi(level, 0, TerrainDetailCodec.MAX_WEAR)
	if _service.set_wear(brush_cells(hovered_cell), clamped):
		last_message = "wear %d" % clamped
		return
	last_message = "wear unchanged"


func paint_snow(level: int) -> void:
	if not has_hover:
		return
	var clamped := clampi(level, 0, TerrainDetailCodec.MAX_SNOW_DEPTH)
	if _service.set_snow_depth(brush_cells(hovered_cell), clamped):
		last_message = "snow depth %d" % clamped
		return
	last_message = "snow unchanged"


## Steps the value under the cursor by one. This is a keyboard affordance — one
## press, one step — and NOT a brush: see `paint_wear` for why the difference
## matters. The laboratory binds it to `U` and `J`.
func cycle_wear() -> void:
	if not has_hover:
		return
	paint_wear((_grid.wear_at(hovered_cell) + 1) % (TerrainDetailCodec.MAX_WEAR + 1))


func cycle_snow() -> void:
	if not has_hover:
		return
	paint_snow((_grid.snow_depth_at(hovered_cell) + 1) % (TerrainDetailCodec.MAX_SNOW_DEPTH + 1))


## Fakes a day of traffic over the brush: enough crossings to move the wear level,
## fed through the real `SurfaceWearService` so the throttle, the transaction and
## the navigation weight are the real ones (terrain_materials.md §6.1).
func walk_the_brush() -> void:
	if not has_hover or _wear_service == null:
		return
	var cells := brush_cells(hovered_cell)
	for _pass in SurfaceWearService.CROSSINGS_PER_WEAR_LEVEL:
		_wear_service.begin_tick()
		for cell: Vector2i in cells:
			_wear_service.record_crossing(cell)
	_wear_day += 1
	var raised := _wear_service.flush(_wear_day)
	last_message = "walked %d cells — %d wore down" % [cells.size(), raised.size()]


func toggle_hole() -> void:
	if not has_hover:
		return
	var enabled := not _grid.is_hole(hovered_cell)
	if _service.set_hole(brush_cells(hovered_cell), enabled):
		last_message = "hole %s" % ("cut" if enabled else "filled")
		return
	last_message = "hole unchanged"


# --- Ramps ------------------------------------------------------------------

func place_ramp() -> void:
	if not has_hover:
		return
	var slope_id := SlopeCatalog.id_of_class(ramp_class)
	if _service.place_ramp(hovered_cell, slope_id, ramp_direction):
		last_message = "ramp %s placed" % slope_id
		return
	# Refusal is a normal answer (grid_terrain_system.md §3.1): the run must be
	# flat, free, and end at a column exactly `rise` steps higher.
	last_message = "ramp %s REFUSED (needs %d free flat cells and a +%d step at the top)" % [
		slope_id, SlopeCatalog.run_of(slope_id), SlopeCatalog.rise_of(slope_id),
	]


func dissolve_ramp() -> void:
	if not has_hover:
		return
	last_message = "ramp dissolved" if _service.dissolve_ramp(hovered_cell) else "no ramp here"


func cycle_ramp_class() -> void:
	var classes: Array[int] = []
	for slope_id: StringName in SlopeCatalog.ramp_ids():
		classes.append(SlopeCatalog.slope_class_of(slope_id))
	var position := classes.find(ramp_class)
	ramp_class = classes[(position + 1) % classes.size()] if position >= 0 else classes[0]
	last_message = "ramp class %d (%s)" % [ramp_class, SlopeCatalog.id_of_class(ramp_class)]


func cycle_ramp_direction() -> void:
	var order := SlopeCatalog.ORTHOGONAL_DIRECTIONS
	ramp_direction = order[(order.find(ramp_direction) + 1) % order.size()]
	last_message = "ramp direction %s" % direction_name(ramp_direction)


static func direction_name(direction: int) -> String:
	match direction:
		SlopeCatalog.DIR_N: return "N"
		SlopeCatalog.DIR_E: return "E"
		SlopeCatalog.DIR_S: return "S"
		SlopeCatalog.DIR_W: return "W"
	return str(direction)


# --- History ----------------------------------------------------------------

func undo() -> void:
	last_message = "undo" if _service.undo() else "nothing to undo"


func redo() -> void:
	last_message = "redo" if _service.redo() else "nothing to redo"
