class_name BorderSeal
extends RefCounted

## Stage 6b: the one thing a `mountain_wall` actually promises
## (procedural_map_generation.md §3.2).
##
## `BorderShaper` traced a closed contour one cell thick around every walled side.
## This stage is the whole guarantee that hangs off it: along that contour the drop
## into the map is at least `seal.riser_steps`, and no ramp may ever be built on it
## or beside it.
##
## Three is the smallest riser that means anything. A pedestrian walks up slope
## class 5 — `very_steep`, two steps in one cell — so two is a step and not a wall.
## Three is divided by no ramp class at all and comes out a bare `cliff`; four
## takes `pre_cliff`, which is class 6 and over the limit. That is the arithmetic
## the recipe is checked against, and it is why the number lives here rather than
## in an author's slider.
##
## **It runs on integers, twice.** Enforcing a riser on the float field before
## quantisation would let rounding turn a drop of three into a drop of two on a
## handful of columns — and a handful is all a walker needs. And the pass runs
## again after the ground settles, because settling moves the columns at the foot
## of the contour and the promise is about the ground that ships, not about the
## ground the stage happened to see.
##
## What it deliberately does NOT do is hold the rim up. The rim is a mountain: it
## settles, it is ramped, it may end up any shape at all. Only this contour is
## authored, which is what leaves the other nine tenths of the frame free to look
## like a landscape.

const STAGE := &"seal"


## Every contour, from the one the player meets outwards. The order matters: each
## riser is measured against the ground on its inner side, and for contour 2 that
## ground is the tread contour 1 has just raised. Walking outwards therefore
## stacks the terraces; walking inwards would measure every riser against ground
## that had not been lifted yet and produce one drop instead of three.
static func enforce(context: GenerationContext) -> void:
	var recipe := context.recipe
	var rings := 0
	for side: StringName in MapRecipe.SIDES:
		if recipe.border_kind(side) == MapRecipe.BORDER_MOUNTAIN_WALL:
			rings = maxi(rings, recipe.border_seal_risers(side))
	if rings == 0:
		return

	var raised := 0
	var tallest := 0
	for ring in range(1, rings + 1):
		for index in context.cell_count:
			if int(context.border_outer[index]) < ring:
				continue
			var cell := context.cell_of_index(index)
			var riser := _riser_at(context, cell)
			var wanted := TerrainGrid.MIN_HEIGHT
			for offset: Vector2i in BorderShaper.NEIGHBOURS_8:
				var neighbour := cell + offset
				if not context.contains(neighbour.x, neighbour.y):
					continue
				var neighbour_index := context.cell_index(neighbour)
				if int(context.border_outer[neighbour_index]) >= ring:
					continue
				# Water needs no riser: the sea at the foot of a headland is not a
				# route out of the map, and lifting the rim over it is exactly the
				# staircase into deep water §3.2 refuses to build.
				if context.is_land[neighbour_index] == 0:
					continue
				wanted = maxi(wanted, context.heights[neighbour_index] + riser)
			if wanted <= context.heights[index]:
				continue
			var height := mini(wanted, TerrainGrid.MAX_HEIGHT)
			tallest = maxi(tallest, height - context.heights[index])
			context.heights[index] = height
			raised += 1
	context.refresh_land_mask()
	if raised > 0:
		context.note("seal: %d columns of the rim carry a riser, the tallest lifted by %d" % [raised, tallest])


## The riser of the side this column belongs to. Sides can ask for different ones,
## and a corner belongs to both — so it gets the taller of the two, which is the
## only answer that keeps both promises.
static func _riser_at(context: GenerationContext, cell: Vector2i) -> int:
	var recipe := context.recipe
	var low := context.min_coordinate()
	var high := context.max_coordinate()
	var distances := PackedInt32Array([cell.y - low, high - cell.x, high - cell.y, cell.x - low])
	var nearest := high - low + 1
	var riser := MapRecipe.MIN_SEAL_RISER
	for side_index in MapRecipe.SIDES.size():
		var side: StringName = MapRecipe.SIDES[side_index]
		if recipe.border_kind(side) != MapRecipe.BORDER_MOUNTAIN_WALL:
			continue
		var steps := recipe.border_seal_riser_steps(side)
		if distances[side_index] < nearest:
			nearest = distances[side_index]
			riser = steps
		elif distances[side_index] == nearest:
			riser = maxi(riser, steps)
	return maxi(riser, MapRecipe.MIN_SEAL_RISER)


## Ground the slope assigner may not touch: the contour and the ring of columns
## standing at its foot.
##
## The ring is not decoration. §3.2 of the terrain document gives a boundary a
## budget of `ceil(drop / repose)` cells, measured on the material at the BOTTOM of
## the drop — and the bottom of this drop is the plain, which is soil, which holds
## one step per cell. So soil at the foot of a three-step riser buys a budget big
## enough for a `shallow` chain, and the assigner obligingly lays a staircase up
## the one side of the map that promised to be impassable.
##
## The ring is ONE cell wide and not the whole budget, which is the difference
## between this and the band the old wall blocked. A ramp is laid on the column
## BELOW a drop, so a chain that starts further out can climb to the foot of the
## riser and no further — and every cell blocked beyond that ring is a foothill
## the map has to render as a bare face for no reason at all. Whether one ring is
## enough is not assumed: `walls_sealed` floods the finished navigation field and
## says so (§6).
static func footings(context: GenerationContext) -> Dictionary:
	var blocked: Dictionary = {}
	for index in context.cell_count:
		if context.border_seal[index] == 0:
			continue
		var cell := context.cell_of_index(index)
		blocked[cell] = true
		for offset: Vector2i in BorderShaper.NEIGHBOURS_8:
			blocked[cell + offset] = true
	return blocked
