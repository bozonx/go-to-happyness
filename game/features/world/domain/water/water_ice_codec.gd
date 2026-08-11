class_name WaterIceCodec
extends RefCounted

## Session-only overlay for accumulated ice. The map remains owner of water
## bodies, levels and flow; a save records only the parallel flag byte for every
## cell and lays it over the freshly loaded map through WaterService.
const MAGIC := "GTHI"
const VERSION := 1
const HEADER_BYTES := 14
const MAX_RUN := 256


static func to_base64(grid: WaterGrid) -> String:
	if grid == null or grid.board_cells <= 0:
		return ""
	var values := PackedByteArray()
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			values.append(grid.flags_of(Vector2i(x, z)))
	var pairs := _pack_runs(values)
	var buffer := PackedByteArray()
	buffer.resize(HEADER_BYTES)
	for index in MAGIC.length():
		buffer[index] = MAGIC.unicode_at(index)
	buffer.encode_u16(4, VERSION)
	buffer.encode_u32(6, grid.board_cells)
	buffer.encode_u32(10, pairs.size() / 2)
	buffer.append_array(pairs)
	return Marshalls.raw_to_base64(buffer)


static func from_base64(encoded: String, service: WaterService) -> bool:
	if encoded.is_empty() or service == null or service.grid == null:
		return false
	var buffer := Marshalls.base64_to_raw(encoded)
	var grid := service.grid
	if not _header_is_valid(buffer, grid.board_cells):
		return false
	var flags := _unpack_runs(buffer, grid.board_cells * grid.board_cells)
	if flags.is_empty():
		return false
	var by_thickness: Dictionary = {
		0: [] as Array[Vector2i],
		1: [] as Array[Vector2i],
		2: [] as Array[Vector2i],
		3: [] as Array[Vector2i],
	}
	var minimum := grid.min_cell()
	var index := 0
	for z in grid.board_cells:
		for x in grid.board_cells:
			var cell := minimum + Vector2i(x, z)
			var value := int(flags[index])
			index += 1
			if not grid.has_water(cell):
				if value != 0:
					return false
				continue
			var thickness := (value >> WaterGrid.ICE_THICKNESS_SHIFT) & WaterGrid.ICE_THICKNESS_MASK
			var frozen := (value & WaterGrid.FLAG_FROZEN) != 0
			if value != WaterGrid.pack_flags(frozen, thickness) or frozen != (thickness > 0):
				return false
			by_thickness[thickness].append(cell)
	# At most four transactions, regardless of board size. `force` is required
	# here because this restores authored/session truth rather than applying the
	# seasonal rule to a body for the first time.
	for thickness: int in by_thickness:
		var cells: Array[Vector2i] = by_thickness[thickness]
		if not cells.is_empty():
			service.set_frozen(cells, thickness > 0, thickness, true)
	service.clear_history()
	return true


static func _header_is_valid(buffer: PackedByteArray, board_cells: int) -> bool:
	if buffer.size() < HEADER_BYTES:
		return false
	for index in MAGIC.length():
		if buffer[index] != MAGIC.unicode_at(index):
			return false
	return (
		buffer.decode_u16(4) == VERSION
		and int(buffer.decode_u32(6)) == board_cells
		and HEADER_BYTES + int(buffer.decode_u32(10)) * 2 == buffer.size()
	)


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
	return pairs


static func _unpack_runs(buffer: PackedByteArray, expected: int) -> PackedByteArray:
	var values := PackedByteArray()
	values.resize(expected)
	var cursor := HEADER_BYTES
	var index := 0
	for _run in int(buffer.decode_u32(10)):
		var length := int(buffer[cursor]) + 1
		var value := buffer[cursor + 1]
		cursor += 2
		if index + length > expected:
			return PackedByteArray()
		for _step in length:
			values[index] = value
			index += 1
	return values if index == expected else PackedByteArray()
