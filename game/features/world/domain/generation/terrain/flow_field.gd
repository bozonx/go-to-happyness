class_name FlowField
extends RefCounted

## Stage 7: where water would go (procedural_map_generation.md §4).
##
## Priority-Flood over the integer heights, run from the board edge inwards. It
## produces three things at once, which is why it is one stage and not three:
##
## * `filled` — the surface with every pit brimmed, i.e. the level water reaches
##   before it can leave a hollow;
## * `flow_dir` — the drainage tree, taken from the order the flood discovered
##   cells. A cell drains to whoever found it, and the flood only ever expands to
##   the lowest reachable frontier, so every path down that tree is non-increasing
##   and ends off the board. That is exactly the guarantee a river needs, and it
##   comes for free instead of from a separate flat-resolution pass;
## * `basins` — the connected hollows the fill had to raise, with the level they
##   spill at. Lakes are chosen from these, never painted on top of the ground.
##
## The queue is a bucket queue rather than a heap: heights are integers in a range
## of 256 values (§2.2 of the terrain doc), so the priority queue that this
## algorithm is usually written around collapses into an array of lists.

const STAGE := &"flow"

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]
## Compass direction of each entry above, as `SlopeCatalog` numbers them.
const NEIGHBOUR_DIRECTIONS: Array[int] = [
	SlopeCatalog.DIR_N, SlopeCatalog.DIR_E, SlopeCatalog.DIR_S, SlopeCatalog.DIR_W,
]

static func build(context: GenerationContext) -> void:
	_flood(context)
	_accumulate(context)
	_collect_basins(context)


static func _flood(context: GenerationContext) -> void:
	var span := TerrainGrid.MAX_HEIGHT - TerrainGrid.MIN_HEIGHT + 1
	# Plain `Array`s rather than `PackedInt32Array`s: these are mutated in place
	# through the outer array, and only a reference-semantics container makes that
	# unambiguous.
	var buckets: Array = []
	buckets.resize(span)
	for level in span:
		buckets[level] = []
	var seen := PackedByteArray()
	seen.resize(context.cell_count)
	context.flow_dir.fill(GenerationContext.NO_FLOW)
	context.flow_order = PackedInt32Array()

	var low := context.min_coordinate()
	var high := context.max_coordinate()
	for z in range(low, high + 1):
		for x in range(low, high + 1):
			if x != low and x != high and z != low and z != high:
				continue
			var index := context.index_of(x, z)
			seen[index] = 1
			context.filled[index] = context.heights[index]
			(buckets[context.heights[index] - TerrainGrid.MIN_HEIGHT] as Array).append(index)

	var level_index := 0
	while level_index < span:
		var bucket: Array = buckets[level_index]
		if bucket.is_empty():
			level_index += 1
			continue
		# The bucket may grow while it is being drained — a neighbour raised to
		# exactly this level lands back in it — so it is walked by index and only
		# then dropped.
		var cursor := 0
		while cursor < bucket.size():
			var index: int = bucket[cursor]
			cursor += 1
			context.flow_order.append(index)
			var cell := context.cell_of_index(index)
			for direction in NEIGHBOURS.size():
				var neighbour: Vector2i = cell + NEIGHBOURS[direction]
				if not context.contains(neighbour.x, neighbour.y):
					continue
				var neighbour_index := context.cell_index(neighbour)
				if seen[neighbour_index] != 0:
					continue
				seen[neighbour_index] = 1
				var filled_height := maxi(context.heights[neighbour_index], context.filled[index])
				context.filled[neighbour_index] = filled_height
				# The neighbour drains back to whoever found it: the opposite of
				# the direction we walked to reach it.
				context.flow_dir[neighbour_index] = SlopeCatalog.opposite_direction(NEIGHBOUR_DIRECTIONS[direction])
				var target := filled_height - TerrainGrid.MIN_HEIGHT
				if target < level_index:
					# Cannot happen — the fill never lowers a cell — but a silent
					# violation here would lose the cell entirely.
					push_error("[map_gen] priority flood pushed below the current level")
					target = level_index
				(buckets[target] as Array).append(neighbour_index)
		buckets[level_index] = []
		level_index += 1


## One unit of rain per land cell, routed down the tree. Walking the pop order
## backwards visits every cell before the one it drains into, so a single pass is
## enough.
static func _accumulate(context: GenerationContext) -> void:
	context.flow_accum.fill(0.0)
	for index in context.cell_count:
		context.flow_accum[index] = 1.0 if context.is_land[index] != 0 else 0.0
	for position in range(context.flow_order.size() - 1, -1, -1):
		var index := context.flow_order[position]
		var direction := int(context.flow_dir[index])
		if direction == GenerationContext.NO_FLOW:
			continue
		var target := context.cell_of_index(index) + SlopeCatalog.direction_offset(direction)
		if not context.contains(target.x, target.y):
			continue
		context.flow_accum[context.cell_index(target)] += context.flow_accum[index]


## Every hollow the fill had to raise, as a connected component of "filled above
## ground". `spill` is the level it overflows at — the level a lake in it stands
## at — and `floor` is its deepest point.
static func _collect_basins(context: GenerationContext) -> void:
	context.basins.clear()
	var seen := PackedByteArray()
	seen.resize(context.cell_count)
	for start in context.cell_count:
		if seen[start] != 0 or context.filled[start] <= context.heights[start]:
			continue
		if context.is_land[start] == 0:
			# Below sea level the "hollow" is simply the sea bed; the sea is not a
			# lake and is authored by the border, not by this list.
			seen[start] = 1
			continue
		var queue: Array[Vector2i] = [context.cell_of_index(start)]
		seen[start] = 1
		var head := 0
		var cells: Array[Vector2i] = []
		var spill := context.filled[start]
		var floor_height := context.heights[start]
		while head < queue.size():
			var cell: Vector2i = queue[head]
			head += 1
			cells.append(cell)
			var index := context.cell_index(cell)
			spill = maxi(spill, context.filled[index])
			floor_height = mini(floor_height, context.heights[index])
			for offset: Vector2i in NEIGHBOURS:
				var neighbour := cell + offset
				if not context.contains(neighbour.x, neighbour.y):
					continue
				var neighbour_index := context.cell_index(neighbour)
				if seen[neighbour_index] != 0 or context.is_land[neighbour_index] == 0:
					continue
				if context.filled[neighbour_index] <= context.heights[neighbour_index]:
					continue
				seen[neighbour_index] = 1
				queue.append(neighbour)
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y if a.y != b.y else a.x < b.x)
		context.basins.append({
			"cells": cells,
			"spill": spill,
			"floor": floor_height,
			"outlet": _outlet_of(context, cells, spill),
		})
	context.basins.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["cells"] as Array).size() > (b["cells"] as Array).size())


## The cell a full basin pours over: the lowest dry neighbour of its outline.
static func _outlet_of(context: GenerationContext, cells: Array[Vector2i], spill: int) -> Vector2i:
	var inside: Dictionary = {}
	for cell: Vector2i in cells:
		inside[cell] = true
	var best := cells[0]
	var best_height := TerrainGrid.MAX_HEIGHT + 1
	for cell: Vector2i in cells:
		for offset: Vector2i in NEIGHBOURS:
			var neighbour := cell + offset
			if inside.has(neighbour) or not context.contains(neighbour.x, neighbour.y):
				continue
			var height := context.heights[context.cell_index(neighbour)]
			if height < best_height or (height == best_height and (neighbour.y < best.y or (neighbour.y == best.y and neighbour.x < best.x))):
				best_height = height
				best = neighbour
	return best if best_height <= spill + 1 else cells[0]
