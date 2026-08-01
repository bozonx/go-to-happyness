class_name CoverageBrushController
extends BaseBrushController

## The coverage brush (map_editor.md §5.2.1).
##
## It is a brush and not a mode: it lives beside the material brush inside the
## Surface mode, and which of the two a stroke writes into follows from the
## palette entry the author picked, never from a tab at the top of the screen.
##
## Picking is through the terrain collider, like the water brush: the coverage
## layer has no geometry of its own — laying a road moves no vertex — so the
## cursor is resolved on the ground underneath it.
##
## The controller owns brush state and the outcome message. Edits always go
## through `CoverageService`, which is what keeps undo and the published road
## weights in step with what is drawn.

## Width of a stroke, in cells. The layer is per-cell, so this is a whole number:
## 3 is a centre line plus one cell either side.
const MIN_WIDTH := 1
const MAX_WIDTH := 8

## What the palette selected. `NO_COVERAGE` means the eraser is armed.
var coverage_index := CoverageCatalog.NONE_INDEX
var variant := 0
var wear := 0

var _layer: CoverageLayer
var _service: CoverageService
## Set while a drag lays coverage. The previous cell is kept so the stroke is
## rasterised between cursor samples: a fast drag samples several cells apart and
## would otherwise lay a dotted road.
var _painting := false
var _erasing := false
var _last_stroke_cell := Vector2i.ZERO
var _has_stroke_cell := false


func configure(terrain: TerrainGrid, layer: CoverageLayer, service: CoverageService) -> void:
	_pick_grid = terrain
	_layer = layer
	_service = service
	_painting = false
	_erasing = false
	_has_stroke_cell = false


# --- Stroke -------------------------------------------------------------------

## Starts or stops a stroke. Starting also applies it once, so a click that never
## moves still paves the cell under it.
func set_painting(painting: bool, erasing := false) -> void:
	_painting = painting
	_erasing = erasing
	if not painting:
		_has_stroke_cell = false
		return
	_has_stroke_cell = false
	_apply_to_hover()


func is_painting() -> bool:
	return _painting


func _on_hover_changed(previous_cell: Vector2i, had_hover: bool) -> void:
	if has_hover and _painting and (not had_hover or previous_cell != hovered_cell):
		_apply_to_hover()


func _apply_to_hover() -> void:
	if not has_hover or _service == null:
		return
	var cells := _stroke_cells()
	_last_stroke_cell = hovered_cell
	_has_stroke_cell = true
	if _erasing:
		_erase_cells(cells)
	else:
		_paint_cells(cells)


## The cells this sample covers: the brush square at the cursor, joined to the
## previous sample so the stroke is continuous.
func _stroke_cells() -> Array[Vector2i]:
	var radius := brush_size - 1
	if not _has_stroke_cell or _last_stroke_cell == hovered_cell:
		return CoverageRasterizer.stamp(hovered_cell, radius, _layer)
	return CoverageRasterizer.stroke(
		[_last_stroke_cell, hovered_cell] as Array[Vector2i], radius * 2 + 1, _layer,
	)


func _paint_cells(cells: Array[Vector2i]) -> void:
	var detail := TerrainDetailCodec.pack(variant, wear, 0)
	# The editor passes no era: an author works outside the settlement's
	# progression, and a scenario may legitimately open with a stone square.
	if _service.paint(cells, coverage_index, detail):
		last_message = "покрытие: %s" % CoverageCatalog.title_of_index(coverage_index)
		return
	match _service.last_rejection():
		CoverageService.REASON_UNKNOWN_COVERAGE:
			last_message = "покрытие не установлено"
		CoverageService.REASON_SLOPE_TOO_STEEP:
			last_message = "слишком крутой уклон для этого покрытия"
		CoverageService.REASON_NOT_BUILDABLE:
			last_message = "здесь нельзя уложить покрытие"
		CoverageService.REASON_NOTHING_TO_DO:
			last_message = "здесь уже %s" % CoverageCatalog.title_of_index(coverage_index)
		_:
			last_message = "покрытие не легло сюда"


func _erase_cells(cells: Array[Vector2i]) -> void:
	if _service.erase(cells):
		last_message = "покрытие снято"
	else:
		last_message = "здесь нет покрытия"


# --- Palette state ------------------------------------------------------------

func set_coverage_index(index: int) -> void:
	coverage_index = index
	if not CoverageCatalog.supports_wear_index(index):
		wear = 0
	last_message = "покрытие: %s" % CoverageCatalog.title_of_index(index)


func set_variant(next_variant: int) -> void:
	variant = clampi(next_variant, 0, TerrainDetailCodec.MAX_VARIANT)


func set_wear(next_wear: int) -> void:
	wear = clampi(next_wear, 0, TerrainDetailCodec.MAX_WEAR)


## Takes the coverage under the cursor into the brush, eraser included: picking a
## bare cell arms the eraser, which is what an author means by pointing at ground.
func pick_coverage() -> void:
	if not has_hover or _layer == null:
		return
	coverage_index = _layer.index_at(hovered_cell)
	variant = _layer.variant_at(hovered_cell)
	wear = _layer.wear_at(hovered_cell)
	last_message = "взято: %s" % CoverageCatalog.title_of_index(coverage_index)
