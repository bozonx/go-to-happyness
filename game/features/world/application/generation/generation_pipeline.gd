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
	# Climate comes before the hydrology because the hydrology needs it: a spring
	# needs rain over it and a basin in a desert holds no lake (§11.1.3). It is
	# re-run further down for the same reason the drainage tree is.
	_timed(context, &"climate", func() -> void: ClimateField.build(context))
	_timed(context, &"passes", func() -> void: PassCarver.carve(context))
	_timed(context, &"flow", func() -> void: FlowField.build(context))
	_timed(context, &"rivers", func() -> void: RiverCarver.carve(context))
	# Shape has one vocabulary. It is fixed once the quantised terrain and authored
	# river cuts exist, then shared by repose, rule biomes and the surface painter.
	_timed(context, &"landforms", func() -> void: LandformField.build(context))
	# Which columns are rock and which are soil, decided from the ranges and the
	# climate rather than from the biome mask that does not exist yet. Without it
	# the whole board settles at one angle and every plain ends up too steep for
	# anything but stone to be painted on (§2.3).
	_timed(context, &"ground", func() -> void: GroundMask.build(context))
	_timed(context, &"repose", func() -> void: ReposePass.apply(context))
	# Lakes are chosen LAST, on the ground nothing will move again. A basin is only
	# a basin because of its rim, and both the river channels and the repose pass
	# rework rims: a lake planned before them is a level whose bowl no longer holds
	# it, and the flood that fills it at write time escapes across the whole map.
	_timed(context, &"reflow", func() -> void: FlowField.build(context))
	_timed(context, &"lakes", func() -> void: LakeFiller.fill(context))
	# The riser is re-asserted LAST, after the final stage that moves a column.
	# Settling reworks the ground at the foot of the contour and the lake stage
	# carves an outflow through it, and both of them left drops of one and two on
	# a rim that had been sealed correctly two stages earlier. The promise is about
	# the ground that ships, so it is made on the ground that ships.
	_timed(context, &"reseal", func() -> void: BorderSeal.enforce(context))
	# Temperature is mostly altitude, and the river channels and the repose pass
	# have both moved altitude since the first climate pass. The biomes describe
	# the ground that ships, so they are computed from the climate of that ground.
	_timed(context, &"reclimate", func() -> void: ClimateField.build(context))
	_timed(context, &"biomes", func() -> void: BiomeField.build(context))
	# The surface is chosen from ground nothing will move again, after the water
	# plan exists and after the biome mask does — a lake bed is silt because there
	# is a lake over it, sand because the biome around it is desert, and the angle
	# a material has to hold is the angle the finished column actually has.
	_timed(context, &"surface", func() -> void: SurfacePainter.apply(context))
	return context


## One composition attempt: everything from the land mask to the integer heights.
static func _shape_land(context: GenerationContext) -> void:
	_timed(context, &"landmass", func() -> void: LandmassField.build(context))
	_timed(context, &"relief", func() -> void: BaseReliefField.build(context))
	_timed(context, &"mountains", func() -> void: MountainSkeleton.build(context))
	# The rim is a range and is written as one, into the same uplift buffer and
	# before the same solver (§3.2). Everything that asks "is this a mountain"
	# downstream — the height budget, the angle of repose, the rain shadow — then
	# gets the same answer for the edge of the board as for the middle of it.
	_timed(context, &"border_rim", func() -> void: BorderShaper.raise_rims(context))
	_timed(context, &"hypsometry", func() -> void: Hypsometry.apply(context))
	_timed(context, &"border", func() -> void: BorderShaper.apply(context))
	_timed(context, &"quantize", func() -> void: HeightQuantizer.apply(context))
	# The riser is whole steps and is enforced on whole steps. Half a step of
	# rounding is the difference between a drop nothing climbs and a drop a
	# pedestrian walks up, so it may not be left to the quantiser.
	_timed(context, &"seal", func() -> void: BorderSeal.enforce(context))


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
