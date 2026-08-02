class_name GenerationPipeline
extends RefCounted

## The order of the stages and the context they share
## (procedural_map_generation.md §4).
##
## One deterministic pass, no threads, no files, no services. Three places in the
## order are load-bearing and are not to be rearranged for convenience:
##
## * **Quantisation before hydrology.** Flow, basins and river beds are computed
##   on the integer ground that will actually exist. Routed over the float field
##   and rounded afterwards, a river runs uphill on the finished steps.
## * **Passes before hydrology too.** Carving a saddle moves ground, and ground
##   that moves after the drainage tree was built invalidates it.
## * **Repose before slopes.** `SlopeAssigner` picks a class from the drop and the
##   free ground beside it; settling columns afterwards would dissolve every ramp
##   it had just placed.
## * **Lakes after repose.** A lake is a level plus the rim that holds it. Anything
##   that moves a rim after the level was chosen turns the fill into a flood.
##
## Stages 11–13 — slopes, water and the verdict — need the real grids and live in
## `TerrainGenerationService`. Everything here is arithmetic over buffers.

## Stage 4.2 of the design doc: parallelism is deliberately absent while the
## algorithms still change daily. Correct first, fast afterwards.
## How many times the composition half may be re-shaped to hit `land_fraction`.
const COMPOSITION_PASSES := 3

const STAGES: Array[StringName] = [
	&"border_plan", &"landmass", &"relief", &"mountains", &"hypsometry", &"border",
	&"quantize", &"passes", &"flow", &"rivers", &"repose", &"reflow", &"lakes",
]


static func run(recipe: MapRecipe, seeds: GenerationSeed, land_fraction_bias := 0.0) -> GenerationContext:
	var context := GenerationContext.new()
	context.configure(recipe, seeds)
	# Carried in from a previous attempt: what the hydrology and the settling cost
	# the land share last time round (§5.3). Nothing inside the pipeline can know
	# that number, so the service hands it back.
	context.land_fraction_bias = land_fraction_bias

	# The sides are planned before the land is: a wall four cells thick is area the
	# land-fraction solver has to know about in advance (§3.2, §5.3).
	_timed(context, &"border_plan", func() -> void: BorderShaper.classify(context))
	# Stages 1–6 are re-run until the land share of the FINISHED integer board
	# matches the recipe. They are the cheap half of the pipeline and they are the
	# only ones that move that number, so measuring the result and correcting the
	# request beats modelling the shelf, the border blend and rounding separately —
	# and it beats throwing the whole map away and trying another seed, which is
	# what the verdict loop would otherwise do (§5.3, §6).
	# The target the composition half aims at already carries the correction the
	# service measured on the finished map, so the inner loop must not undo it: it
	# aims at the biased share, not at the recipe's.
	var composition_target := clampf(recipe.land_fraction + land_fraction_bias, 0.0, 1.0)
	for pass_index in COMPOSITION_PASSES:
		_shape_land(context)
		var error := composition_target - _land_share(context)
		if absf(error) <= recipe.land_fraction_tolerance * 0.4:
			break
		if pass_index + 1 < COMPOSITION_PASSES:
			context.land_fraction_bias += error
	_timed(context, &"passes", func() -> void: PassCarver.carve(context))
	_timed(context, &"flow", func() -> void: FlowField.build(context))
	_timed(context, &"rivers", func() -> void: RiverCarver.carve(context))
	_timed(context, &"repose", func() -> void: ReposePass.apply(context))
	# Lakes are chosen LAST, on the ground nothing will move again. A basin is only
	# a basin because of its rim, and both the river channels and the repose pass
	# rework rims: a lake planned before them is a level whose bowl no longer holds
	# it, and the flood that fills it at write time escapes across the whole map.
	_timed(context, &"reflow", func() -> void: FlowField.build(context))
	_timed(context, &"lakes", func() -> void: LakeFiller.fill(context))
	return context


## One composition attempt: everything from the land mask to the integer heights.
static func _shape_land(context: GenerationContext) -> void:
	_timed(context, &"landmass", func() -> void: LandmassField.build(context))
	_timed(context, &"relief", func() -> void: BaseReliefField.build(context))
	_timed(context, &"mountains", func() -> void: MountainSkeleton.build(context))
	_timed(context, &"hypsometry", func() -> void: Hypsometry.apply(context))
	_timed(context, &"border", func() -> void: BorderShaper.apply(context))
	_timed(context, &"quantize", func() -> void: HeightQuantizer.apply(context))


## Land share measured the way §6 measures it: inside the frame, over the integer
## heights. Anything else would tune the solver against a different number from
## the one the verdict uses.
static func _land_share(context: GenerationContext) -> float:
	var land := 0
	var inside := 0
	for index in context.cell_count:
		if context.border_locked[index] != 0:
			continue
		inside += 1
		if context.is_land[index] != 0:
			land += 1
	return float(land) / float(maxi(inside, 1))


static func _timed(context: GenerationContext, stage: StringName, work: Callable) -> void:
	var started := Time.get_ticks_msec()
	work.call()
	context.stage_times[stage] = Time.get_ticks_msec() - started
