class_name MapWaterCodec
extends RefCounted

## `water.bin`: the water layer as fixed-width cell records
## (design_docs/engine/map_editor.md §4, grid_terrain_system.md §9.3).
##
## Three bytes per cell — level, body reference, flags — exactly the three arrays
## the layer keeps in memory, in the same row-major order `terrain.bin` uses, so
## the two files index the same column at the same offset.
##
## The registry of `WaterBody` objects is NOT here: it lives in `map.json` beside
## the header (§9.2). It is small, authored and worth reading by eye, and its
## contents — flow runs, fish stocks — are variable-length in a way a fixed-width
## cell record cannot be.
##
## An untouched layer encodes to an empty buffer and the package omits the file,
## which is what "no water on this map" means on disk.

const MAGIC := "GTHW"
const VERSION := 1
const HEADER_BYTES := 16
const BYTES_PER_CELL := 3

## Levels run over the same range as terrain heights, so they take the same bias.
const HEIGHT_BIAS := 64


static func encode(grid: WaterGrid, skip_if_empty := true) -> PackedByteArray:
	var buffer := PackedByteArray()
	if grid == null or grid.board_cells <= 0:
		return buffer
	if skip_if_empty and grid.is_empty():
		return buffer

	var count := grid.board_cells * grid.board_cells
	buffer.resize(HEADER_BYTES + count * BYTES_PER_CELL)
	_write_header(buffer, grid.board_cells)

	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	var offset := HEADER_BYTES
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			buffer[offset] = clampi(grid.height_of(cell) + HEIGHT_BIAS, 0, 255)
			buffer[offset + 1] = grid.body_id_at(cell)
			buffer[offset + 2] = grid.flags_of(cell)
			offset += BYTES_PER_CELL
	return buffer


## Fills an already-configured grid — registry included, because a cell reference
## to a body that is not registered is refused by `WaterGrid.set_cell` and would
## decode as dry. Returns false and leaves the grid untouched when the buffer is
## not a water layer of exactly this board.
static func decode_into(buffer: PackedByteArray, grid: WaterGrid) -> bool:
	if grid == null or not is_valid(buffer):
		return false
	if board_cells_of(buffer) != grid.board_cells:
		return false

	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	var offset := HEADER_BYTES
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			grid.set_cell(
				Vector2i(x, z),
				buffer[offset + 1],
				buffer[offset] - HEIGHT_BIAS,
				buffer[offset + 2],
			)
			offset += BYTES_PER_CELL
	return true


static func is_valid(buffer: PackedByteArray) -> bool:
	if buffer.size() < HEADER_BYTES:
		return false
	for index in MAGIC.length():
		if buffer[index] != MAGIC.unicode_at(index):
			return false
	if buffer.decode_u16(4) != VERSION:
		return false
	if buffer.decode_u16(6) != BYTES_PER_CELL:
		return false
	var board_cells := board_cells_of(buffer)
	return buffer.size() == HEADER_BYTES + board_cells * board_cells * BYTES_PER_CELL


static func board_cells_of(buffer: PackedByteArray) -> int:
	if buffer.size() < HEADER_BYTES:
		return 0
	return buffer.decode_u32(8)


static func _write_header(buffer: PackedByteArray, board_cells: int) -> void:
	for index in MAGIC.length():
		buffer[index] = MAGIC.unicode_at(index)
	buffer.encode_u16(4, VERSION)
	buffer.encode_u16(6, BYTES_PER_CELL)
	buffer.encode_u32(8, board_cells)
	buffer.encode_u32(12, 0) # reserved
