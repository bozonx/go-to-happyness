class_name TerrainSurfaceCodec
extends RefCounted

## The surface half of a terrain grid, for the SESSION save
## (design_docs/engine/terrain_materials.md §5, §6.1, §6.4).
##
## A session does not save its relief: the map package owns the ground and the
## save reloads it. The surface is different — it changes while the game runs.
## Citizens wear paths into meadows (§6.1) and burned cells grow back into grass
## (§6.4), and until this codec existed both were silently discarded on save,
## because the settlement save had no terrain in it at all.
##
## Only the two things that change are written: the material index and the packed
## detail byte. Heights, slopes, holes and anchors are not in the file at all,
## which is what keeps this from becoming a second, half-authoritative copy of the
## map's relief.
##
## ## Run-length encoded, and why that is the exception
##
## `MapTerrainCodec` deliberately does not compress: an author's map is a document
## and a second encoding between them and their world is a liability. A save is
## not a document — nobody edits it by hand, and it is written every few minutes
## of play. A worn board is overwhelmingly long runs of one material, so the same
## 128 KB of raw bytes for a 256² board comes to a few hundred.
##
## Layout, little-endian throughout:
##
## ```
## "GTHS" u16 version  u32 board_cells  u16 catalog_bytes
## <material catalog blob, TerrainCatalogBlob>
## u32 material_runs  (u8 length-1, u8 value) * material_runs
## u32 detail_runs    (u8 length-1, u8 value) * detail_runs
## ```

const MAGIC := "GTHS"
const VERSION := 1
const HEADER_BYTES := 12
const CATALOG_BYTES_OFFSET := 10
## A run length is stored as `length - 1`, so one pair covers up to 256 columns.
const MAX_RUN := 256


static func encode(grid: TerrainGrid) -> PackedByteArray:
	var buffer := PackedByteArray()
	if grid == null or grid.board_cells <= 0:
		return buffer
	var catalog := TerrainCatalogBlob.encode()
	buffer.resize(HEADER_BYTES)
	for index in MAGIC.length():
		buffer[index] = MAGIC.unicode_at(index)
	buffer.encode_u16(4, VERSION)
	buffer.encode_u32(6, grid.board_cells)
	buffer.encode_u16(CATALOG_BYTES_OFFSET, catalog.size())
	buffer.append_array(catalog)

	var materials := PackedByteArray()
	var details := PackedByteArray()
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			materials.append(grid.material_index_at(cell))
			details.append(grid.detail_at(cell))
	buffer.append_array(_pack_runs(materials))
	buffer.append_array(_pack_runs(details))
	return buffer


## Writes the surface onto an already-loaded grid. The relief is whatever the map
## put there; only material and detail are replaced, through `set_material_index`
## and `set_detail` so the dirty sets, the cliff-kind check and the surface texels
## all behave exactly as they do for a brush stroke.
static func decode_into(buffer: PackedByteArray, grid: TerrainGrid) -> bool:
	if grid == null or not is_valid(buffer):
		return false
	if int(buffer.decode_u32(6)) != grid.board_cells:
		return false
	var catalog_bytes := int(buffer.decode_u16(CATALOG_BYTES_OFFSET))
	var remap := TerrainCatalogBlob.decode_remap(buffer, HEADER_BYTES, catalog_bytes)
	var cursor := HEADER_BYTES + catalog_bytes
	var expected := grid.board_cells * grid.board_cells
	var materials := _unpack_runs(buffer, cursor, expected)
	if materials.is_empty():
		return false
	cursor += 4 + int(buffer.decode_u32(cursor)) * 2
	var details := _unpack_runs(buffer, cursor, expected)
	if details.is_empty():
		return false

	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	var index := 0
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			var material_index := int(remap[materials[index]])
			grid.set_material_index(cell, material_index)
			# The variant is clamped to the palette of the material it landed on, for
			# the same reason painting does: a stale variant of another material
			# addresses an unrelated texture layer.
			grid.set_detail(cell, TerrainDetailCodec.with_variant(
				details[index],
				TerrainMaterialVariants.clamp_variant(material_index, TerrainDetailCodec.variant_of(details[index])),
			))
			index += 1
	return true


static func is_valid(buffer: PackedByteArray) -> bool:
	if buffer.size() < HEADER_BYTES:
		return false
	for index in MAGIC.length():
		if buffer[index] != MAGIC.unicode_at(index):
			return false
	if buffer.decode_u16(4) != VERSION:
		return false
	var catalog_bytes := int(buffer.decode_u16(CATALOG_BYTES_OFFSET))
	return HEADER_BYTES + catalog_bytes + 8 <= buffer.size()


## Base64 wrappers: the session save is JSON, and a byte array in JSON is either
## this or an array of numbers five times the size.
static func to_base64(grid: TerrainGrid) -> String:
	var bytes := encode(grid)
	return "" if bytes.is_empty() else Marshalls.raw_to_base64(bytes)


static func from_base64(encoded: String, grid: TerrainGrid) -> bool:
	if encoded.is_empty() or grid == null:
		return false
	return decode_into(Marshalls.base64_to_raw(encoded), grid)


# --- Run-length -----------------------------------------------------------

static func _pack_runs(values: PackedByteArray) -> PackedByteArray:
	var pairs := PackedByteArray()
	var index := 0
	while index < values.size():
		var value := values[index]
		var length := 1
		while index + length < values.size() and length < MAX_RUN and values[index + length] == value:
			length += 1
		pairs.append(length - 1)
		pairs.append(value)
		index += length
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, pairs.size() / 2)
	out.append_array(pairs)
	return out


## Expands one run-length block. Returns an empty array — never a short one — when
## the block does not describe exactly `expected` values, so a truncated or
## foreign save is refused rather than half-applied.
static func _unpack_runs(buffer: PackedByteArray, offset: int, expected: int) -> PackedByteArray:
	var values := PackedByteArray()
	if offset + 4 > buffer.size():
		return values
	var runs := int(buffer.decode_u32(offset))
	var cursor := offset + 4
	if cursor + runs * 2 > buffer.size():
		return values
	values.resize(expected)
	var index := 0
	for _run in runs:
		var length := int(buffer[cursor]) + 1
		var value := buffer[cursor + 1]
		cursor += 2
		if index + length > expected:
			return PackedByteArray()
		for _step in length:
			values[index] = value
			index += 1
	return values if index == expected else PackedByteArray()
