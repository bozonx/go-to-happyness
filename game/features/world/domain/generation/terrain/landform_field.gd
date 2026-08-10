class_name LandformField
extends RefCounted

## The one geometric classification shared by settling, biomes and painting.
## It is built once from the quantised terrain after river incision; later stages
## may move columns, but they may not invent a second definition of a summit,
## ridge, floodplain or shore.

const STAGE := &"landforms"

const PLAIN := 0
const FOOTHILL := 1
const RIDGE := 2
const SUMMIT := 3
const FLOODPLAIN := 4
const SHORE := 5

const NAMES: Array[StringName] = [
	&"plain", &"foothill", &"ridge", &"summit", &"floodplain", &"shore",
]

const RIDGE_UPLIFT := 6.0
const FOOTHILL_UPLIFT := 0.75
const SUMMIT_HEIGHT_SHARE := 0.55
const SHORE_CELLS := 3.0
const FLOODPLAIN_CELLS := 3

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


static func build(context: GenerationContext) -> void:
	context.landforms.resize(context.cell_count)
	context.landforms.fill(PLAIN)
	var summit_height := _summit_height(context)
	var drainage_distance := _drainage_distance(context)
	var counts := PackedInt32Array()
	counts.resize(NAMES.size())
	for index in context.cell_count:
		var kind := _classify(context, index, summit_height, drainage_distance)
		context.landforms[index] = kind
		counts[kind] += 1
	var summary: Array[String] = []
	for kind in counts.size():
		if counts[kind] > 0:
			summary.append("%s %d%%" % [
				NAMES[kind], roundi(float(counts[kind]) * 100.0 / float(maxi(context.cell_count, 1))),
			])
	context.note("landforms: %s" % ", ".join(summary))


static func is_rock(kind: int) -> bool:
	return kind == RIDGE or kind == SUMMIT


static func _classify(
	context: GenerationContext, index: int, summit_height: int,
	drainage_distance: PackedInt32Array,
) -> int:
	if context.border_locked[index] != 0:
		return RIDGE
	if context.is_land[index] == 0:
		return PLAIN
	var uplift := context.uplift[index]
	if uplift >= RIDGE_UPLIFT:
		return SUMMIT if context.heights[index] >= summit_height else RIDGE
	if context.shore_distance[index] >= 0.0 and context.shore_distance[index] <= SHORE_CELLS:
		return SHORE
	if drainage_distance[index] <= FLOODPLAIN_CELLS and _local_relief(context, index) <= 1:
		return FLOODPLAIN
	if uplift >= FOOTHILL_UPLIFT:
		return FOOTHILL
	return PLAIN


static func _summit_height(context: GenerationContext) -> int:
	var lowest := TerrainGrid.MAX_HEIGHT
	var highest := TerrainGrid.MIN_HEIGHT
	for index in context.cell_count:
		if context.border_locked[index] != 0 or context.is_land[index] == 0:
			continue
		lowest = mini(lowest, context.heights[index])
		highest = maxi(highest, context.heights[index])
	if highest <= lowest:
		return TerrainGrid.MAX_HEIGHT
	return lowest + roundi(float(highest - lowest) * SUMMIT_HEIGHT_SHARE)


static func _drainage_distance(context: GenerationContext) -> PackedInt32Array:
	var limit := FLOODPLAIN_CELLS + 1
	var distance := PackedInt32Array()
	distance.resize(context.cell_count)
	distance.fill(limit)
	var queue: Array[Vector2i] = []
	for cell: Vector2i in context.river_cells:
		var index := context.cell_index(cell)
		distance[index] = 0
		queue.append(cell)
	# First-flow basins are the only pre-repose evidence of a future lake. Marking
	# their floors as drainage lowland lets the later wetland rule describe lake
	# margins without rebuilding landforms after the ground has moved.
	for basin: Dictionary in context.basins:
		for cell: Vector2i in (basin["cells"] as Array):
			var index := context.cell_index(cell)
			if distance[index] == 0:
				continue
			distance[index] = 0
			queue.append(cell)
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var next_distance := distance[context.cell_index(cell)] + 1
		if next_distance > FLOODPLAIN_CELLS:
			continue
		for offset: Vector2i in NEIGHBOURS:
			var neighbour := cell + offset
			if not context.contains(neighbour.x, neighbour.y):
				continue
			var neighbour_index := context.cell_index(neighbour)
			if next_distance >= distance[neighbour_index]:
				continue
			distance[neighbour_index] = next_distance
			queue.append(neighbour)
	return distance


static func _local_relief(context: GenerationContext, index: int) -> int:
	var cell := context.cell_of_index(index)
	var lowest := context.heights[index]
	var highest := context.heights[index]
	for offset: Vector2i in NEIGHBOURS:
		var neighbour := cell + offset
		if not context.contains(neighbour.x, neighbour.y):
			continue
		var height := context.heights[context.cell_index(neighbour)]
		lowest = mini(lowest, height)
		highest = maxi(highest, height)
	return highest - lowest
