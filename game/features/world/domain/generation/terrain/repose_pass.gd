class_name ReposePass
extends RefCounted

## Stage 10: the ground settles (procedural_map_generation.md §2.3, §4).
##
## Everything on stage 1 is made of one material, so one angle of repose applies
## to the whole board — the material's own, straight from
## `TerrainMaterialCatalog` (§4.2 of the terrain doc). Stone holds four steps per
## cell, which is why it is the default here: it is the material that hides the
## least, so a shape that is too steep shows up as too steep instead of being
## smoothed away by soft soil. `elevation.repose_override` swaps the angle for a
## laboratory comparison and nothing else.
##
## Two things are deliberately exempt. Border walls are AUTHORED faces (§3.2) —
## letting them slump would quietly undo the side the recipe asked for — and river
## channels are authored cuts, which would fill in again on the first sweep.
##
## The pass runs before slopes are assigned, because `SlopeAssigner` chooses a
## class from the drop it finds and the free ground beside it; moving columns
## afterwards would dissolve every ramp it had just placed (§4 "Осыпание до
## склонов").

const STAGE := &"repose"
const MAX_SWEEPS := 6

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


static func apply(context: GenerationContext) -> void:
	var repose := TerrainMaterialCatalog.repose_steps_per_cell_of(context.recipe.repose_override)
	var limit := TerrainGrid.MAX_HEIGHT if is_inf(repose) else int(floor(repose))
	var moved_total := 0
	for _sweep in MAX_SWEEPS:
		var moved := _sweep_once(context, maxi(limit, 1))
		moved_total += moved
		if moved == 0:
			break
	context.refresh_land_mask()
	if moved_total > 0:
		context.note("repose (%s, %d steps/cell): %d columns settled" % [
			context.recipe.repose_override, limit, moved_total,
		])


static func _sweep_once(context: GenerationContext, limit: int) -> int:
	var moved := 0
	for index in context.cell_count:
		if context.border_locked[index] != 0:
			continue
		var cell := context.cell_of_index(index)
		if context.river_cells.has(cell):
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
		# A pothole is one column disagreeing with every neighbour it has: nothing
		# an author would draw and nothing a slope can be laid on. It is filled to
		# one step under the shallowest side, which keeps genuine hollows — the
		# ones a lake will use — intact, because those have a low neighbour too.
		var settled := height
		if height < lowest - 1:
			settled = lowest - 1
		# The angle of repose proper: a column may not stand more than the material
		# holds above its lowest neighbour. Needles fall out of the same rule, which
		# is why they get no separate one — a summit that a real flank can support
		# has to survive this pass untouched.
		if settled - lowest > limit:
			settled = lowest + limit
		if settled == height:
			continue
		context.heights[index] = clampi(settled, TerrainGrid.MIN_HEIGHT, TerrainGrid.MAX_HEIGHT)
		context.is_land[index] = 1 if context.heights[index] > context.recipe.ocean_level else 0
		moved += 1
	return moved
