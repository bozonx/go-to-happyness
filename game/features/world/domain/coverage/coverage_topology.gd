class_name CoverageTopology
extends RefCounted

## Derived connectivity of the authored coverage layer.
##
## CoverageLayer remains the only saved truth. This view answers the questions a
## future renderer needs for automatic ends, straights, corners, T/X junctions
## and closed rings without preserving the input stroke or inventing a second
## road graph. Lane and rail graphs are deliberately outside this contract.

const NORTH := 1 << 0
const NORTH_EAST := 1 << 1
const EAST := 1 << 2
const SOUTH_EAST := 1 << 3
const SOUTH := 1 << 4
const SOUTH_WEST := 1 << 5
const WEST := 1 << 6
const NORTH_WEST := 1 << 7

const OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

enum Shape { ISOLATED, END, STRAIGHT, CORNER, JUNCTION }


## Eight-way neighbour mask. Different coverage types connect by default so a
## dirt road can meet a stone square. A diagonal is used only when neither
## orthogonal shoulder already connects; this distinguishes a genuine diagonal
## stroke from the shortcut across an ordinary right-angle corner.
static func connection_mask(layer: CoverageLayer, cell: Vector2i, same_surface := false) -> int:
	if layer == null or not layer.has_coverage(cell):
		return 0
	var mask := 0
	for direction in OFFSETS.size():
		var offset := OFFSETS[direction]
		if not _compatible(layer, cell, cell + offset, same_surface):
			continue
		if offset.x != 0 and offset.y != 0:
			if _compatible(layer, cell, cell + Vector2i(offset.x, 0), same_surface) \
					or _compatible(layer, cell, cell + Vector2i(0, offset.y), same_surface):
				continue
		mask |= 1 << direction
	return mask


static func connection_count(mask: int) -> int:
	var count := 0
	for direction in OFFSETS.size():
		if (mask & (1 << direction)) != 0:
			count += 1
	return count


static func shape_of_mask(mask: int) -> Shape:
	var count := connection_count(mask)
	if count == 0:
		return Shape.ISOLATED
	if count == 1:
		return Shape.END
	if count >= 3:
		return Shape.JUNCTION
	var directions: Array[int] = []
	for direction in OFFSETS.size():
		if (mask & (1 << direction)) != 0:
			directions.append(direction)
	return Shape.STRAIGHT if (directions[0] + 4) % 8 == directions[1] else Shape.CORNER


static func shape_at(layer: CoverageLayer, cell: Vector2i, same_surface := false) -> Shape:
	return shape_of_mask(connection_mask(layer, cell, same_surface))


## True when the complete connected component has no endpoint or junction.
## Useful for proving that a closed author stroke remains a ring after
## rasterisation; it is not a one-way or lane-direction contract.
static func is_closed_component(layer: CoverageLayer, start: Vector2i, same_surface := false) -> bool:
	if layer == null or not layer.has_coverage(start):
		return false
	var pending: Array[Vector2i] = [start]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if visited.has(cell):
			continue
		visited[cell] = true
		var mask := connection_mask(layer, cell, same_surface)
		if connection_count(mask) != 2:
			return false
		for direction in OFFSETS.size():
			if (mask & (1 << direction)) != 0:
				var neighbour := cell + OFFSETS[direction]
				if not visited.has(neighbour):
					pending.append(neighbour)
	return visited.size() >= 4


static func _compatible(layer: CoverageLayer, origin: Vector2i, candidate: Vector2i, same_surface: bool) -> bool:
	if not layer.has_coverage(candidate):
		return false
	return not same_surface or layer.index_at(origin) == layer.index_at(candidate)
