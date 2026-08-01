class_name CoverageLayer
extends RefCounted

## The built-coverage layer of a board (design_docs/engine/map_editor.md §5.2.1).
##
## Two flat arrays parallel to `TerrainGrid`, the same shape `WaterGrid` uses and
## for the same reason: a Dictionary over 65 536 cells costs a hash on every
## texture update and every navigation publish to save a few dozen kilobytes.
##
## | array      | in memory | on disk | meaning                                |
## | ---------- | --------- | ------- | -------------------------------------- |
## | `index`    | `uint8`   | `uint8` | entry of `CoverageCatalog`; 0 = none    |
## | `detail`   | `uint8`   | `uint8` | `variant | wear | snow`, the SAME codec |
##
## **The detail byte is `TerrainDetailCodec`, not a private set of road flags.**
## Asphalt cracks, snow lies on a pavement and paving comes in variants — that is
## exactly the three states the terrain codec already packs, and a parallel format
## would buy a second shader path and a second set of tests for the same three
## numbers. What never varies per cell — whether the surface wears at all, whether
## it regrows — belongs to the catalog entry instead.
##
## Coverage is a LAYER and not a material index (`terrain_materials.md` §1):
## erasing it has to reveal the ground that was always underneath, and an
## unfaded trail has to survive a road laid over it. `NavGrid` already reads in
## that order — road, then trail, then terrain.

const NO_COVERAGE := CoverageCatalog.NONE_INDEX

var cell_size := 1.0
var board_cells := 0
var board_half_cells := 0

var _indices := PackedByteArray()
var _details := PackedByteArray()

## Cells changed since presentation last drained them. Painting coverage moves no
## vertex, so like a material repaint this never touches the chunk queue.
var _dirty_cells: Dictionary = {}


func configure(next_cell_size: float, next_board_cells: int) -> void:
	cell_size = next_cell_size
	board_cells = maxi(next_board_cells, 0)
	board_half_cells = board_cells / 2
	var count := board_cells * board_cells
	_indices = PackedByteArray()
	_details = PackedByteArray()
	_indices.resize(count)
	_details.resize(count)
	_dirty_cells.clear()


func is_configured() -> bool:
	return board_cells > 0


func min_cell() -> Vector2i:
	return Vector2i(-board_half_cells, -board_half_cells)


func max_cell() -> Vector2i:
	return Vector2i(board_cells - board_half_cells - 1, board_cells - board_half_cells - 1)


func is_inside(cell: Vector2i) -> bool:
	var minimum := min_cell()
	var maximum := max_cell()
	return cell.x >= minimum.x and cell.y >= minimum.y and cell.x <= maximum.x and cell.y <= maximum.y


## True when no cell carries coverage. The package omits `surface.bin` entirely in
## that case, which is what "this map has no paths" means on disk.
func is_empty() -> bool:
	for index in _indices:
		if index != NO_COVERAGE:
			return false
	return true


func index_at(cell: Vector2i) -> int:
	var offset := _offset_of(cell)
	return _indices[offset] if offset >= 0 else NO_COVERAGE


func detail_at(cell: Vector2i) -> int:
	var offset := _offset_of(cell)
	return _details[offset] if offset >= 0 else TerrainDetailCodec.DEFAULT_DETAIL


func has_coverage(cell: Vector2i) -> bool:
	return index_at(cell) != NO_COVERAGE


func id_at(cell: Vector2i) -> StringName:
	return CoverageCatalog.id_of_index(index_at(cell))


func variant_at(cell: Vector2i) -> int:
	return TerrainDetailCodec.variant_of(detail_at(cell))


func wear_at(cell: Vector2i) -> int:
	return TerrainDetailCodec.wear_of(detail_at(cell))


func snow_depth_at(cell: Vector2i) -> int:
	return TerrainDetailCodec.snow_depth_of(detail_at(cell))


## Writes one cell whole. The only writer: index and detail are one state, and a
## setter per field would let a caller leave a detail byte behind on a cell whose
## coverage was just erased.
func set_cell(cell: Vector2i, index: int, detail: int) -> bool:
	var offset := _offset_of(cell)
	if offset < 0:
		return false
	var next_index := clampi(index, 0, 255)
	# Erasing takes the detail with it. Keeping the byte would resurrect the wear
	# of a demolished road under the next one laid on the same cell.
	var next_detail := clampi(detail, 0, 255) if next_index != NO_COVERAGE else TerrainDetailCodec.DEFAULT_DETAIL
	if _indices[offset] == next_index and _details[offset] == next_detail:
		return false
	_indices[offset] = next_index
	_details[offset] = next_detail
	_dirty_cells[cell] = true
	return true


func clear_cell(cell: Vector2i) -> bool:
	return set_cell(cell, NO_COVERAGE, TerrainDetailCodec.DEFAULT_DETAIL)


## Every covered cell as `Vector2i -> index`. What the navigation publisher and
## the save delta both read; sparse because coverage is sparse even on a finished
## map, and a full board array would put 65 536 zeroes into every publish.
func covered_cells() -> Dictionary:
	var result: Dictionary = {}
	var minimum := min_cell()
	var maximum := max_cell()
	var offset := 0
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			if _indices[offset] != NO_COVERAGE:
				result[Vector2i(x, z)] = _indices[offset]
			offset += 1
	return result


func covered_cell_count() -> int:
	var count := 0
	for index in _indices:
		if index != NO_COVERAGE:
			count += 1
	return count


# --- Dirty set ----------------------------------------------------------------

func has_dirty_cells() -> bool:
	return not _dirty_cells.is_empty()


func take_dirty_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _dirty_cells:
		cells.append(cell)
	_dirty_cells.clear()
	return cells


func mark_all_dirty() -> void:
	var minimum := min_cell()
	var maximum := max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			_dirty_cells[Vector2i(x, z)] = true


func _offset_of(cell: Vector2i) -> int:
	if not is_inside(cell):
		return -1
	return (cell.y + board_half_cells) * board_cells + (cell.x + board_half_cells)
