class_name ReposePass
extends RefCounted

## Stage 10: the ground settles (procedural_map_generation.md §2.3, §4).
##
## Each column settles at the angle ITS OWN ground holds, which `GroundMask` has
## already decided: four steps per cell on a range, two on its shoulders, one on
## the plains. That is the whole difference between a map made of stone and a map
## made of what the biome asked for — a plain left standing at rock's angle has
## boundaries no soil can hold, and the surface painter then has no honest choice
## but to paint it stone (see `GroundMask` for the measurement).
##
## The limit belongs to the UPPER column of a boundary, because that is the ground
## that would slide: a meadow at the foot of a cliff holds nothing up and is an
## ordinary landscape, while sand on the brow of the same drop is not.
##
## Two things are deliberately exempt, and the first one is deliberately SMALL.
## The authored part of a border is the seal contour of §3.2 and nothing else —
## one cell wide — because the rim around it is a mountain and a mountain that is
## not allowed to settle is the slab this whole design replaced. River channels are
## the second: they are authored cuts and would fill in again on the first sweep.
##
## The pass runs before slopes are assigned, because `SlopeAssigner` chooses a
## class from the drop it finds and the free ground beside it; moving columns
## afterwards would dissolve every ramp it had just placed (§4 "Осыпание до
## склонов").

const STAGE := &"repose"
## Settling the plains from rock's angle down to soil's moves whole hillsides, so
## the sweep needs more rounds than it did when the limit was uniform and high.
const MAX_SWEEPS := 12

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


static func apply(context: GenerationContext) -> void:
	var filled := _fill_potholes(context)
	var moved_total := 0
	for _sweep in MAX_SWEEPS:
		var moved := _sweep_once(context)
		moved_total += moved
		if moved == 0:
			break
	context.refresh_land_mask()
	if moved_total + filled > 0:
		context.note("repose: %d columns settled, %d potholes filled" % [moved_total, filled])


## One pass, and one pass only. A pothole is a single column that disagrees with
## every neighbour it has — nothing an author would draw and nothing a slope can
## be laid on — so it is filled to one step under the shallowest side. Genuine
## hollows survive, because those have a low neighbour to drain towards.
##
## Iterating this to a fixed point turns it into a flood fill: each filled column
## makes its neighbour the new pothole, and a basin disappears one ring at a time.
## Run to convergence it raised the mean height of a continent from 5 to 11 and
## would have swallowed the hollows the lake stage is about to use.
static func _fill_potholes(context: GenerationContext) -> int:
	var filled := 0
	for index in context.cell_count:
		if context.border_seal[index] != 0:
			continue
		var cell := context.cell_of_index(index)
		if context.river_cells.has(cell) or context.carved_cells.has(cell):
			continue
		# The trench at the foot of a riser is not a pothole. Filling it is the one
		# way this pass can climb a seal contour: raise the column below the drop and
		# the drop is no longer the drop the recipe promised.
		if _beside_seal(context, cell):
			continue
		var lowest := TerrainGrid.MAX_HEIGHT
		for offset: Vector2i in NEIGHBOURS:
			var neighbour := cell + offset
			if not context.contains(neighbour.x, neighbour.y):
				continue
			lowest = mini(lowest, context.heights[context.cell_index(neighbour)])
		if lowest == TerrainGrid.MAX_HEIGHT or context.heights[index] >= lowest - 1:
			continue
		context.heights[index] = lowest - 1
		filled += 1
	return filled


static func _beside_seal(context: GenerationContext, cell: Vector2i) -> bool:
	for offset: Vector2i in BorderShaper.NEIGHBOURS_8:
		var neighbour := cell + offset
		if not context.contains(neighbour.x, neighbour.y):
			continue
		if context.border_seal[context.cell_index(neighbour)] != 0:
			return true
	return false


static func _sweep_once(context: GenerationContext) -> int:
	var moved := 0
	for index in context.cell_count:
		if context.border_seal[index] != 0:
			continue
		var cell := context.cell_of_index(index)
		if context.river_cells.has(cell) or context.carved_cells.has(cell):
			continue
		var height := context.heights[index]
		var lowest := TerrainGrid.MAX_HEIGHT
		var neighbours := 0
		for offset: Vector2i in NEIGHBOURS:
			var neighbour := cell + offset
			if not context.contains(neighbour.x, neighbour.y):
				continue
			lowest = mini(lowest, context.heights[context.cell_index(neighbour)])
			neighbours += 1
		if neighbours == 0:
			continue
		# The sea holds the coast up. A shore column standing beside deep water is
		# not a column standing beside a hole: the ground under water is supported
		# by it, and a beach does not slide into the shelf the way a cliff face
		# slides into a valley. Without this the settling pass eats the coastline of
		# every map — measurably, it cost every preset its land-fraction target on
		# the first attempt and made the generator spend a second one to put the
		# same land back.
		if height > context.recipe.ocean_level:
			lowest = maxi(lowest, context.recipe.ocean_level)
		# The angle of repose proper: a column may not stand more than its own
		# ground holds above its lowest neighbour. Needles fall out of the same
		# rule, which is why they get no separate one — a summit that a real flank
		# can support has to survive this pass untouched.
		var limit := maxi(int(context.repose_limit[index]), 1)
		if height - lowest <= limit:
			continue
		var settled := lowest + limit
		context.heights[index] = clampi(settled, TerrainGrid.MIN_HEIGHT, TerrainGrid.MAX_HEIGHT)
		context.is_land[index] = 1 if context.heights[index] > context.recipe.ocean_level else 0
		moved += 1
	return moved
