class_name GroundMask
extends RefCounted

## How steep each landform is allowed to stand
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
## `LandformField` cuts the dependency loop once. This adapter maps its ridge and
## summit kinds to rock's repose and every softer form to soil's repose. It owns
## no height or temperature threshold of its own.
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

const ROCK_STEPS := 4
const SOIL_STEPS := 1


static func build(context: GenerationContext) -> void:
	context.repose_limit.resize(context.cell_count)
	var forced := _forced_limit(context.recipe)
	if forced > 0:
		context.repose_limit.fill(forced)
		context.note("ground: whole board settled at %d step(s)/cell by elevation.repose_override" % forced)
		return

	var rock := 0
	for index in context.cell_count:
		var limit := ROCK_STEPS if LandformField.is_rock(int(context.landforms[index])) else SOIL_STEPS
		context.repose_limit[index] = limit
		if limit == ROCK_STEPS:
			rock += 1
	context.note("ground: %d%% rock, %d%% soil" % [
		roundi(float(rock) * 100.0 / float(context.cell_count)),
		roundi(float(context.cell_count - rock) * 100.0 / float(context.cell_count)),
	])

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
