class_name MapCoverageCodec
extends RefCounted

## `surface.bin`: the built-coverage layer as fixed-width cell records
## (design_docs/engine/map_editor.md §4, §5.2.1).
##
## Two bytes per cell — catalog index and detail — in the same row-major order
## `terrain.bin` and `water.bin` use, so all three files index the same column at
## the same offset.
##
## The catalog is NOT written into the package: the index is the saved form and
## the catalog is append-only after release (`CoverageCatalog`). What a map does
## carry is the id of any coverage it uses, in `required_content[]`, so a map that
## paints a pack surface says so.
##
## An untouched layer encodes to an empty buffer and the package omits the file.

const MAGIC := "GTHC"
const VERSION := 1
const HEADER_BYTES := 16
const BYTES_PER_CELL := 2


static func encode(layer: CoverageLayer, skip_if_empty := true) -> PackedByteArray:
	var buffer := PackedByteArray()
	if layer == null or layer.board_cells <= 0:
		return buffer
	if skip_if_empty and layer.is_empty():
		return buffer

	var count := layer.board_cells * layer.board_cells
	buffer.resize(HEADER_BYTES + count * BYTES_PER_CELL)
	_write_header(buffer, layer.board_cells)

	var minimum := layer.min_cell()
	var maximum := layer.max_cell()
	var offset := HEADER_BYTES
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			buffer[offset] = layer.index_at(cell)
			buffer[offset + 1] = layer.detail_at(cell)
			offset += BYTES_PER_CELL
	return buffer


## Fills an already-configured layer. An index this build does not know — a pack
## surface that is not installed — is kept in the file but decoded as bare ground,
## so the map opens and reports its missing content instead of refusing to load.
static func decode_into(buffer: PackedByteArray, layer: CoverageLayer) -> bool:
	if layer == null or not is_valid(buffer):
		return false
	if board_cells_of(buffer) != layer.board_cells:
		return false

	var minimum := layer.min_cell()
	var maximum := layer.max_cell()
	var offset := HEADER_BYTES
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var index := buffer[offset]
			if index != CoverageLayer.NO_COVERAGE and not CoverageCatalog.is_known_index(index):
				push_warning("[map] покрытие с индексом %d не установлено; клетка %s открыта как земля" % [
					index, Vector2i(x, z),
				])
				index = CoverageLayer.NO_COVERAGE
			layer.set_cell(Vector2i(x, z), index, buffer[offset + 1])
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
