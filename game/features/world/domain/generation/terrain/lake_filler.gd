class_name LakeFiller
extends RefCounted

## Stage 9: what the water layer will be asked to author
## (procedural_map_generation.md §3.7, §4 stages 9 and 12).
##
## A lake here is a FILLED BASIN, never a painted patch: stage 7 already found
## every hollow and the level it spills at, so this stage only chooses which of
## them deserve water and how the choice answers `size`, `depth` and `prefer`.
## Where too few hollows fit the recipe, the shortfall is reported rather than
## faked — a lake dug into a hillside to satisfy a count is the exact failure the
## design doc refuses.
##
## The stage produces a PLAN, not water. Writing happens once, in stage 12, after
## slopes exist — because `SlopeAssigner` moves ground, and ground that moves
## under a finished lake breaks the body. The plan carries a level and a seed
## cell; the water stage floods from the seed at that level over the final terrain
## and so cannot disagree with it.

const STAGE := &"lakes"
## Ordinary rivers wade; a strength of 2 or more stops them freezing (§9.6 of the
## terrain doc), and stage 1 has no winter to model yet.
const RIVER_FLOW_STRENGTH := 1

## Moisture a basin needs before standing water in it is credible (§11.1.3). Below
## it the hollow is a dry pan: the same shape, no lake. This is the whole of "a
## desert has little water" — it is not a special case for a desert biome, it is
## the rain that would have to fall to keep the level up. A basin fed by a river
## is exempt: the water arrives from wherever it rained.
const LAKE_MIN_MOISTURE := 0.3

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


static func fill(context: GenerationContext) -> void:
	context.water_plan.clear()
	_plan_sea(context)
	_plan_lakes(context)
	_plan_rivers(context)


## The sea is everything below `border.ocean_level` that the board edge reaches.
## Anything below that level which the edge does NOT reach is an inland basin and
## belongs to the lake stage, not here.
static func _plan_sea(context: GenerationContext) -> void:
	var level := context.recipe.ocean_level
	var seen := PackedByteArray()
	seen.resize(context.cell_count)
	var low := context.min_coordinate()
	var high := context.max_coordinate()
	var cells: Array[Vector2i] = []
	var queue: Array[Vector2i] = []
	for z in range(low, high + 1):
		for x in range(low, high + 1):
			if x != low and x != high and z != low and z != high:
				continue
			var index := context.index_of(x, z)
			if seen[index] != 0 or context.heights[index] >= level:
				continue
			seen[index] = 1
			queue.append(Vector2i(x, z))
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		cells.append(cell)
		for offset: Vector2i in NEIGHBOURS:
			var neighbour := cell + offset
			if not context.contains(neighbour.x, neighbour.y):
				continue
			var index := context.cell_index(neighbour)
			if seen[index] != 0 or context.heights[index] >= level:
				continue
			seen[index] = 1
			queue.append(neighbour)
	if cells.is_empty():
		return
	cells.sort_custom(_cell_order)
	context.water_plan.append({
		"type": WaterBody.Type.SEA,
		"level": level,
		"cells": cells,
		"flow": {},
	})


static func _plan_lakes(context: GenerationContext) -> void:
	var recipe := context.recipe
	var rng := context.seeds.rng(STAGE)
	var wanted := rng.randi_range(recipe.lake_count[0], recipe.lake_count[1])
	if wanted <= 0:
		return
	var eligible: Array[Dictionary] = []
	var too_dry := 0
	for basin: Dictionary in context.basins:
		var cells: Array[Vector2i] = basin["cells"]
		var depth: int = int(basin["spill"]) - int(basin["floor"])
		if cells.size() < recipe.lake_size[0] or cells.size() > recipe.lake_size[1]:
			continue
		if depth < recipe.lake_depth[0] or depth > recipe.lake_depth[1]:
			continue
		if int(basin["spill"]) <= recipe.ocean_level:
			continue
		if not _is_watered(context, basin):
			too_dry += 1
			continue
		eligible.append(basin)
	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _lake_score(context, a) > _lake_score(context, b))

	var placed := 0
	for basin: Dictionary in eligible:
		if placed >= wanted:
			break
		var cells: Array[Vector2i] = basin["cells"]
		var level: int = int(basin["spill"])
		context.water_plan.append({
			"type": WaterBody.Type.LAKE,
			"level": level,
			"cells": cells.duplicate(),
			"flow": {},
		})
		placed += 1
		if recipe.lakes_connect_to_rivers:
			RiverCarver.carve_outflow(context, basin["outlet"], level)
	var arid := " (%d basin(s) refused as too arid)" % too_dry if too_dry > 0 else ""
	if placed < wanted:
		context.note("lakes: %d of %d requested — the terrain offered no more basins matching size/depth%s" % [
			placed, wanted, arid,
		])
	else:
		context.note("lakes: %d placed%s" % [placed, arid])


## Whether a basin gets any water at all. Rain is the ordinary source, so the mean
## moisture over the hollow decides; a channel running through it is the other
## one, and it overrules the climate because that water was collected elsewhere.
static func _is_watered(context: GenerationContext, basin: Dictionary) -> bool:
	var cells: Array[Vector2i] = basin["cells"]
	if cells.is_empty():
		return false
	var total := 0.0
	for cell: Vector2i in cells:
		if context.river_cells.has(cell):
			return true
		total += context.moisture[context.cell_index(cell)]
	return total / float(cells.size()) >= LAKE_MIN_MOISTURE


## `prefer` is a preference, so it is a ranking rather than a filter: a mountain
## recipe on a board with no mountain hollows still gets its lakes, just lower
## down, and the report says where they ended up.
static func _lake_score(context: GenerationContext, basin: Dictionary) -> float:
	var cells: Array[Vector2i] = basin["cells"]
	var score := float(cells.size())
	var centre: Vector2i = cells[cells.size() / 2]
	var index := context.cell_index(centre)
	match context.recipe.lake_prefer:
		MapRecipe.LAKE_PREFER_MOUNTAINS:
			score += context.uplift[index] * 40.0
		MapRecipe.LAKE_PREFER_COAST:
			score += maxf(0.0, 60.0 - absf(context.shore_distance[index])) * 6.0
		_:
			score += float(int(basin["spill"]) - int(basin["floor"])) * 12.0
	return score


## Each pool of each river becomes its own body: a `WaterBody` has one surface for
## all of its cells, and the sills carved by stage 8 are what keep two pools of
## different level from touching.
static func _plan_rivers(context: GenerationContext) -> void:
	if context.river_cells.is_empty():
		return
	var levels: Dictionary = {}
	for cell: Vector2i in context.river_cells:
		var record: Dictionary = context.river_cells[cell]
		if bool(record["sill"]):
			continue
		levels[cell] = int(record["bed"]) + 1

	var seen: Dictionary = {}
	var pools := 0
	var leaked := 0
	var rapids := 0
	for cell: Vector2i in levels:
		if seen.has(cell):
			continue
		var level: int = levels[cell]
		var queue: Array[Vector2i] = [cell]
		seen[cell] = true
		var head := 0
		var cells: Array[Vector2i] = []
		var flow: Dictionary = {}
		while head < queue.size():
			var current: Vector2i = queue[head]
			head += 1
			cells.append(current)
			var record: Dictionary = context.river_cells[current]
			flow[current] = Vector2i(int(record["direction"]), RIVER_FLOW_STRENGTH)
			for offset: Vector2i in NEIGHBOURS:
				var neighbour := current + offset
				if seen.has(neighbour) or not levels.has(neighbour):
					continue
				if int(levels[neighbour]) != level:
					continue
				seen[neighbour] = true
				queue.append(neighbour)
		# The footprint is not the channel cells — it is everything a body at this
		# level would actually reach over this ground, which is what the water stage
		# will flood. Planning the channel and discovering the difference only at
		# write time is how a stream turns into a sheet across half a valley.
		# A reach too short to hold anything is a rapid, not a pool: it costs a whole
		# `WaterBody` (one byte of the 255 the layer has) to draw a puddle.
		if cells.size() < RiverCarver.MIN_POOL_CELLS:
			rapids += 1
			continue
		var pool := _reachable_at(context, cells, level)
		if pool.is_empty() or pool.size() > cells.size() * 2 + 16:
			leaked += 1
			continue
		context.water_plan.append({
			"type": WaterBody.Type.RIVER,
			"level": level,
			"cells": pool,
			"flow": flow,
		})
		pools += 1
	context.note("rivers: %d pool(s) planned, %d rapids too short to hold water, %d spilling out of their reach" % [
		pools, rapids, leaked,
	])


## Everything a body of this level reaches from the given cells, over the ground
## as it stands now. Four-connected, because water spreads over edges and never
## through the point where two banks meet.
static func _reachable_at(context: GenerationContext, from: Array[Vector2i], level: int) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = []
	for cell: Vector2i in from:
		if context.heights[context.cell_index(cell)] >= level or seen.has(cell):
			continue
		seen[cell] = true
		queue.append(cell)
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for offset: Vector2i in NEIGHBOURS:
			var neighbour := cell + offset
			if seen.has(neighbour) or not context.contains(neighbour.x, neighbour.y):
				continue
			if context.heights[context.cell_index(neighbour)] >= level:
				continue
			seen[neighbour] = true
			queue.append(neighbour)
	var reached: Array[Vector2i] = []
	for cell: Vector2i in seen:
		reached.append(cell)
	reached.sort_custom(_cell_order)
	return reached


static func _cell_order(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y if a.y != b.y else a.x < b.x
