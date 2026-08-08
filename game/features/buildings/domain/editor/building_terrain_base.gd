class_name BuildingTerrainBase
extends RefCounted

## The `Terrain Base` layer of a blueprint: the ground the building brings with it
## (design_docs/engine/grid_terrain_system.md §5.2, building_placement.md §4.3).
##
## Heights are stored **relative to the blueprint's anchor level**, never in world
## coordinates — otherwise a blueprint could only ever be placed at the height it
## was authored at. Placement resolves one anchor level (§4.2) and adds these
## offsets to it.
##
## A blueprint that declares nothing has an empty layer, which means "one flat
## platform under the whole footprint". That is the common case, not a special
## one: §4.3 is explicit that a plain pad is just the simplest possible content of
## this layer, so there is no second code path for it.
##
## `holes` are cells the merge **cuts out** rather than levels (§10): the mouth of
## an underground entrance is a `is_hole` column, and levelling it would fill in
## the very opening the blueprint exists to leave.

var size: Vector2i = Vector2i.ZERO
## Row-major `z * size.x + x`, one entry per cell of `size`.
var heights := PackedInt32Array()
## Row-major, parallel to `heights`; 1 means the cell is cut out.
var holes := PackedByteArray()


func is_empty() -> bool:
	return size.x <= 0 or size.y <= 0 or heights.is_empty()


## Offset from the anchor level for a blueprint-local cell. Anything outside the
## declared rectangle is flat ground, which is what an absent layer means.
func height_at(local: Vector2i) -> int:
	var index := _index_of(local)
	return 0 if index < 0 else heights[index]


func is_hole(local: Vector2i) -> bool:
	var index := _index_of(local)
	return index >= 0 and index < holes.size() and holes[index] != 0


func has_holes() -> bool:
	for value: int in holes:
		if value != 0:
			return true
	return false


func _index_of(local: Vector2i) -> int:
	if is_empty() or local.x < 0 or local.y < 0 or local.x >= size.x or local.y >= size.y:
		return -1
	return local.y * size.x + local.x


func to_dict() -> Dictionary:
	if is_empty():
		return {}
	var data := {
		"size": [size.x, size.y],
		"heights": Array(heights),
	}
	if has_holes():
		data["holes"] = Array(holes)
	return data


## Parses the layer. `footprint` is the size the blueprint claims on the board; a
## layer whose own size disagrees with it is dropped rather than stretched — a
## silently resampled foundation would place the building on ground nobody
## authored.
static func from_dict(data: Variant, footprint: Vector2i) -> BuildingTerrainBase:
	var layer := BuildingTerrainBase.new()
	if not (data is Dictionary):
		return layer
	var source := data as Dictionary
	var raw_size: Variant = source.get("size", [])
	if raw_size is Array and (raw_size as Array).size() >= 2:
		layer.size = Vector2i(int(raw_size[0]), int(raw_size[1]))
	else:
		layer.size = footprint
	if layer.size != footprint:
		push_warning("[blueprint] terrain_base %s не совпадает с footprint %s — слой пропущен" % [
			layer.size, footprint])
		return BuildingTerrainBase.new()
	var count := layer.size.x * layer.size.y
	if count <= 0:
		return BuildingTerrainBase.new()
	layer.heights.resize(count)
	layer.holes.resize(count)
	var raw_heights: Variant = source.get("heights", [])
	if raw_heights is Array:
		for index in mini(count, (raw_heights as Array).size()):
			layer.heights[index] = int((raw_heights as Array)[index])
	var raw_holes: Variant = source.get("holes", [])
	if raw_holes is Array:
		for index in mini(count, (raw_holes as Array).size()):
			layer.holes[index] = 1 if int((raw_holes as Array)[index]) != 0 else 0
	return layer
