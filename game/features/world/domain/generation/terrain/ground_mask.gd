class_name GroundMask
extends RefCounted

## Stage 10a: how steep each column is allowed to stand
## (procedural_map_generation.md §2.3).
##
## This is the stage that unties the knot the design document names and used to
## resolve by force: the angle of repose comes from the MATERIAL, the material
## comes from the biome, and the biome needs the finished ground. The old answer
## was "settle the whole board at one angle", and because the only angle that
## keeps a mountain a mountain is rock's four steps per cell, every plain on every
## map was left with two- and four-step boundaries. Nothing softer than stone can
## stand on those, so the surface painter had no choice: **58–73 % of the land of
## every preset came out stone.** The knot was cut in the wrong place.
##
## The mask cuts it in the right one. Rock is not a material the map is made of,
## it is a PLACE: the ranges the mountain stage raised, and the cold summits the
## lapse rate produced. Both are known here — `uplift` from stage 3, temperature
## from the climate stage — and neither needs the biome mask, which is why this
## can run before the ground settles instead of after it.
##
## So each column gets the angle its own kind of ground holds:
##
## | Where | Steps per cell | What it looks like |
## | :-- | :-- | :-- |
## | Ranges, summits, authored walls | 4 | faces, scree, real rock |
## | Everything else — plains, foothills, valleys, coasts | 1 | soil at 45°, which grass holds |
##
## The tiers are two and not three on purpose. A middle tier of two steps per cell
## sounds like the broken ground of a foothill, but no soil in the catalog holds
## two steps — grass, dirt and gravel all stop at one — so every column of it
## would be painted stone anyway. A tier that can only produce rock is the rock
## tier under another name, and the foothills are the exact ground the map most
## needs to be soft.
##
## The result is the landscape the documents describe and the generator never
## produced: rolling meadows and grassy foothills with rock where the map is
## actually rocky.
##
## `elevation.repose_override` still forces one angle over the whole board, which
## is what the laboratory wants when it compares two shapes; it is a debug knob
## and no longer the thing that decides what a world is made of.

const STAGE := &"ground"

## Uplift in height steps above which a column belongs to a range rather than to
## the plain the range stands on. Six is the height at which a flank is tall
## enough to be worth a face; below it a hill made of earth is a better hill.
const ROCK_UPLIFT := 6.0

## A summit is rock even where the mountain stage did not put it: the top of the
## height range, and cold with it. Both halves matter for the same reason they do
## in `BiomeField` — the share alone turns the highest dune of a desert into a
## crag, the temperature alone turns the whole northern edge of a cold map into
## one.
const ALPINE_HEIGHT_SHARE := 0.62
const ALPINE_TEMPERATURE := 4.0

const ROCK_STEPS := 4
const SOIL_STEPS := 1


static func build(context: GenerationContext) -> void:
	context.repose_limit.resize(context.cell_count)
	var forced := _forced_limit(context.recipe)
	if forced > 0:
		context.repose_limit.fill(forced)
		context.note("ground: whole board settled at %d step(s)/cell by elevation.repose_override" % forced)
		return

	var alpine_height := _alpine_height(context)
	var rock := 0
	for index in context.cell_count:
		var limit := SOIL_STEPS
		if context.uplift[index] >= ROCK_UPLIFT:
			limit = ROCK_STEPS
		if context.heights[index] >= alpine_height and context.temperature[index] <= ALPINE_TEMPERATURE:
			limit = ROCK_STEPS
		# An authored wall is a face by construction (§3.2) and the repose pass
		# skips it anyway; marking it rock keeps the two statements consistent for
		# anything that reads the mask later.
		if context.border_locked[index] != 0:
			limit = ROCK_STEPS
		context.repose_limit[index] = limit
		if limit == ROCK_STEPS:
			rock += 1
	context.note("ground: %d%% rock, %d%% soil" % [
		roundi(float(rock) * 100.0 / float(context.cell_count)),
		roundi(float(context.cell_count - rock) * 100.0 / float(context.cell_count)),
	])


## The height above which a column counts as a summit, measured against the range
## this attempt actually produced rather than against the recipe's ceiling: a
## recipe that asked for 30 and got 22 still has a top to its map.
static func _alpine_height(context: GenerationContext) -> int:
	var lowest := TerrainGrid.MAX_HEIGHT
	var highest := TerrainGrid.MIN_HEIGHT
	for index in context.cell_count:
		if context.border_locked[index] != 0 or context.is_land[index] == 0:
			continue
		lowest = mini(lowest, context.heights[index])
		highest = maxi(highest, context.heights[index])
	if highest <= lowest:
		return TerrainGrid.MAX_HEIGHT
	return lowest + int(round(float(highest - lowest) * ALPINE_HEIGHT_SHARE))


## The laboratory's one-angle override, in whole steps, or 0 when the recipe
## leaves the ground to the mask. Sand holds half a step per cell, which no
## integer sweep can express, so the softest forced angle is one step — the
## fallback chain of the surface painter is what turns that into the two-cell
## terraces sand really makes.
static func _forced_limit(recipe: MapRecipe) -> int:
	if String(recipe.repose_override).is_empty():
		return 0
	var repose := TerrainMaterialCatalog.repose_steps_per_cell_of(recipe.repose_override)
	if is_inf(repose):
		return TerrainGrid.MAX_HEIGHT
	return maxi(int(floor(repose)), 1)
