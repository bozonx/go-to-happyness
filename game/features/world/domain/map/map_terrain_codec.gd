class_name MapTerrainCodec
extends RefCounted

## `terrain.bin`: the whole grid as fixed-width cell records
## (design_docs/engine/map_editor.md §4, grid_terrain_system.md §12).
##
## Five bytes per cell, not the four the design estimated. The estimate assumed
## slope class, direction, index and flags fit in one byte together; they do not.
## Class is eight values (3 bits), direction is eight compass slots (3 bits — the
## diagonal slots exist precisely so stored data never has to be remapped), index
## runs to the longest ramp of eight cells (3 bits) and flags are a growing
## bitmask. That is eleven bits, so the descriptor takes two bytes and a board of
## 256×256 costs 320 KB instead of 256 KB. Squeezing direction to two bits would
## buy 64 KB by breaking the one promise the direction encoding makes.
##
## Byte order is little-endian and the cell order is row-major from `min_cell()`,
## so a file written on one machine decodes identically on another.
##
## Nothing here compresses: the win would be real (a mostly-flat board repeats one
## record) but it would put a second encoding between the author and their map.
## The package skips the file entirely when the layer is untouched, which is the
## same saving for the case that actually occurs.

const MAGIC := "GTHT"
const VERSION := 1
const HEADER_BYTES := 16
const BYTES_PER_CELL := 5

## Heights run −64..191 (`TerrainGrid.MIN_HEIGHT`/`MAX_HEIGHT`) — 256 values, so
## they fit one byte once biased by the minimum.
const HEIGHT_BIAS := 64

const SLOPE_CLASS_MASK := 0x07
const SLOPE_DIR_SHIFT := 3
const SLOPE_DIR_MASK := 0x07
## Flags occupy the low bits of the second descriptor byte so the mask can grow to
## five before it collides with the ramp index above it.
const FLAGS_MASK := 0x1F
const SLOPE_INDEX_SHIFT := 5
const SLOPE_INDEX_MASK := 0x07


## Serialises the grid, or an empty buffer when it is entirely default — a flat
## board of one material with no ramps, holes or anchors. The package leaves such
## a layer unwritten (§4) and rebuilds it from `board` on load.
static func encode(grid: TerrainGrid, skip_if_default := true) -> PackedByteArray:
	var buffer := PackedByteArray()
	if grid == null or grid.board_cells <= 0:
		return buffer
	if skip_if_default and is_default(grid):
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
			buffer[offset + 1] = grid.material_index_at(cell)
			buffer[offset + 2] = grid.detail_at(cell)
			buffer[offset + 3] = (
				(grid.slope_class_at(cell) & SLOPE_CLASS_MASK)
				| ((grid.slope_direction_of(cell) & SLOPE_DIR_MASK) << SLOPE_DIR_SHIFT)
			)
			buffer[offset + 4] = (
				(grid.flags_of(cell) & FLAGS_MASK)
				| ((grid.slope_index_of(cell) & SLOPE_INDEX_MASK) << SLOPE_INDEX_SHIFT)
			)
			offset += BYTES_PER_CELL
	return buffer


## Fills an already-configured grid from a buffer. Returns false and leaves the
## grid untouched when the buffer is not a terrain layer of exactly this board —
## a truncated or foreign file must not half-load a world.
static func decode_into(buffer: PackedByteArray, grid: TerrainGrid) -> bool:
	if grid == null or not is_valid(buffer):
		return false
	var board_cells := board_cells_of(buffer)
	if board_cells != grid.board_cells:
		return false

	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	var offset := HEADER_BYTES
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var slope := buffer[offset + 3]
			var index_flags := buffer[offset + 4]
			# One call per cell: the grid recomputes nothing and marks the chunk
			# dirty once, instead of once per field.
			var material_index := buffer[offset + 1]
			if not TerrainMaterialCatalog.is_valid_index(material_index):
				material_index = TerrainMaterialCatalog.DEFAULT_INDEX
			var detail := TerrainDetailCodec.with_variant(
				buffer[offset + 2],
				TerrainMaterialVariants.clamp_variant(material_index, TerrainDetailCodec.variant_of(buffer[offset + 2])),
			)
			grid.set_cell_state(
				Vector2i(x, z),
				buffer[offset] - HEIGHT_BIAS,
				slope & SLOPE_CLASS_MASK,
				(slope >> SLOPE_DIR_SHIFT) & SLOPE_DIR_MASK,
				(index_flags >> SLOPE_INDEX_SHIFT) & SLOPE_INDEX_MASK,
				material_index,
				index_flags & FLAGS_MASK,
				detail,
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


## A board nothing has been done to. Worth asking before writing a quarter of a
## megabyte of zeroes for a map whose author has only named it so far.
static func is_default(grid: TerrainGrid) -> bool:
	if grid == null:
		return true
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			if grid.height_of(cell) != 0 or grid.flags_of(cell) != 0:
				return false
			if grid.material_index_at(cell) != TerrainMaterialCatalog.DEFAULT_INDEX:
				return false
			if grid.detail_at(cell) != TerrainDetailCodec.DEFAULT_DETAIL:
				return false
			if grid.slope_class_at(cell) != SlopeCatalog.CLASS_FLAT:
				return false
	return true


static func _write_header(buffer: PackedByteArray, board_cells: int) -> void:
	for index in MAGIC.length():
		buffer[index] = MAGIC.unicode_at(index)
	buffer.encode_u16(4, VERSION)
	buffer.encode_u16(6, BYTES_PER_CELL)
	buffer.encode_u32(8, board_cells)
	buffer.encode_u32(12, 0) # reserved: water/surface layers get their own files
