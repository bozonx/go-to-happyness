class_name TerrainCatalogBlob
extends RefCounted

## The material catalog as it travels inside a binary file
## (design_docs/engine/terrain_materials.md §2, §2.6).
##
## A stored material is one byte, and which surface that byte means is decided by
## `TerrainMaterialCatalog` — a list this build owns and content packs will extend
## (`content_packaging.md`). Writing the bare byte is therefore only correct while
## exactly one build of the game exists.
##
## So every file that stores material bytes writes the id list beside them, and
## reading remaps by NAME. Two files need this — the map package's `terrain.bin`
## and the session save's surface layer — and they share it here rather than
## keeping a copy each, because a mismatch between two implementations of "which
## material is byte 5" is exactly the failure the blob exists to prevent.
##
## Layout: `u16 count`, then `u8 length + utf8` per id, in index order. Plain
## enough to read in a hex dump, which is the point — this is the part of a file
## that explains the rest of it.


static func encode() -> PackedByteArray:
	var blob := PackedByteArray()
	blob.resize(2)
	blob.encode_u16(0, TerrainMaterialCatalog.count())
	for id: StringName in TerrainMaterialCatalog.ids_view():
		var name := String(id).to_utf8_buffer()
		blob.append(mini(name.size(), 255))
		blob.append_array(name.slice(0, 255))
	return blob


## Maps every one of the 256 possible stored bytes onto a current catalog index.
##
## A file with no blob (`byte_length` 0 — written before the catalog travelled)
## carries bytes that ARE current indices, so it gets the identity. A file naming
## a material this build does not have resolves it to the default: the alternative
## is handing the column to whichever surface happens to occupy that number now,
## which is the exact failure §2.6 exists to prevent.
static func decode_remap(buffer: PackedByteArray, offset: int, byte_length: int) -> PackedByteArray:
	var remap := PackedByteArray()
	remap.resize(256)
	for stored in 256:
		remap[stored] = stored if TerrainMaterialCatalog.is_valid_index(stored) else TerrainMaterialCatalog.DEFAULT_INDEX
	if byte_length <= 2 or offset + byte_length > buffer.size():
		return remap
	var count := int(buffer.decode_u16(offset))
	var cursor := offset + 2
	var unknown: Array[String] = []
	for stored in count:
		if cursor >= buffer.size():
			break
		var length := int(buffer[cursor])
		cursor += 1
		var id := StringName(buffer.slice(cursor, cursor + length).get_string_from_utf8())
		cursor += length
		if stored > 255:
			continue
		var current := TerrainMaterialCatalog.index_of(id)
		if current < 0:
			unknown.append(String(id))
			current = TerrainMaterialCatalog.DEFAULT_INDEX
		remap[stored] = current
	if not unknown.is_empty():
		push_warning("[terrain] неизвестные материалы %s заменены на %s" % [
			", ".join(unknown), TerrainMaterialCatalog.DEFAULT_MATERIAL,
		])
	return remap
