class_name Hypsometry
extends RefCounted

## Stage 4: how much of the board sits at which height
## (procedural_map_generation.md §3.4, §5.3).
##
## "Many gentle slopes, but if there is a mountain then a real one" is not a pair
## of min/max heights — it is a statement about the DISTRIBUTION of area over
## height, which is what a hypsometric curve is. So the stage does three things in
## order:
##
## 1. Rank-normalises the relief of stage 2, turning whatever the noise produced
##    into a uniform 0…1 field. From here on the noise's own histogram is gone,
##    which is why `land_mean_height` can be met exactly rather than approximately.
## 2. Bends that uniform field through the curve the recipe named.
## 3. Solves the plain exponent and, when necessary, a mountain-profile exponent
##    so that the mean and maximum are compatible (§5.3). The peak gain itself is
##    analytical: requested maximum / raw uplift maximum.
##
## Plains and mountains keep separate budgets and combine with `max`, which is
## what makes "mean height 6, peaks 48" an ordinary recipe instead of a
## pathological one: raising the peaks does not lift the plain under them.

const STAGE := &"hypsometry"
const SOLVER_STEPS := 24
const MIN_EXPONENT := 0.02
const MAX_EXPONENT := 32.0
const MIN_MOUNTAIN_EXPONENT := 1.0
const MAX_MOUNTAIN_EXPONENT := 32.0
## Maximum displacement of ordinary ground at roughness=1, as a share of its
## height budget. It is applied after rank normalisation so the slider survives.
const ROUGHNESS_AMPLITUDE := 0.30

## How far above the mean the pure-plain component may reach, per curve. The
## ceiling has to sit above the mean or no exponent can bring the mean down to it.
const PLAIN_CEILING_FACTOR: Dictionary = {
	MapRecipe.HYPSOMETRY_PLAINS_WITH_PEAKS: 4.0,
	MapRecipe.HYPSOMETRY_ROLLING: 3.0,
	MapRecipe.HYPSOMETRY_PLATEAU: 3.6,
	MapRecipe.HYPSOMETRY_BOWL: 3.0,
	MapRecipe.HYPSOMETRY_ALPINE: 2.4,
}

## Depth of the open sea below the ocean level, in steps, reached at the far edge
## of the shelf.
const SEA_DEPTH := 9


static func apply(context: GenerationContext) -> void:
	var recipe := context.recipe
	var land: PackedInt32Array = _land_indices(context)
	_write_sea(context)
	if land.is_empty():
		return

	var shaped := _shaped_field(context, land)
	var ceiling := _plain_ceiling(recipe)
	# The two promises of §3.4 are about the MAP, and the frame is not map. Solving
	# over it too was harmless while the frame was a slab written after this stage;
	# now that the rim of §3.2 is uplift like any range, a rim taller than the
	# ranges behind it would absorb the whole mountain budget and leave the map's
	# own peaks short of the maximum the recipe asked for — measured, of course,
	# over the map, where the rim is not.
	var sample: PackedInt32Array = _sample_indices(context, land)
	if sample.is_empty():
		sample = land
	var uplift_peak := 0.0
	for index: int in sample:
		uplift_peak = maxf(uplift_peak, context.uplift[index])

	var target_mean := clampf(
		float(recipe.land_mean_height) + context.mean_height_adjustment,
		float(recipe.ocean_level) + 0.5,
		float(TerrainGrid.MAX_HEIGHT),
	)
	var target_max := clampf(
		float(recipe.land_max_height) + context.max_height_adjustment,
		target_mean + 1.0,
		float(TerrainGrid.MAX_HEIGHT),
	)
	ceiling = minf(ceiling, target_max)
	var exponent := 1.0
	var mountain_exponent := MIN_MOUNTAIN_EXPONENT
	var gain := 1.0
	if uplift_peak <= 0.0:
		# No mountains: the plains alone must reach the maximum, so the ceiling IS
		# the maximum and only the mean is left to solve.
		ceiling = target_max
		exponent = _solve_exponent(context, sample, shaped, ceiling, target_mean, 0.0, 1.0, target_max)
	else:
		gain = target_max / uplift_peak
		mountain_exponent = _solve_mountain_exponent(
			context, sample, shaped, ceiling, target_mean, uplift_peak, target_max)
		exponent = _solve_exponent(
			context, sample, shaped, ceiling, target_mean, uplift_peak, mountain_exponent, target_max)
	context.mountain_gain = gain

	var ceiling_height := target_max
	for index: int in land:
		var plain := ceiling * pow(shaped[index], exponent)
		var normalised_uplift := clampf(context.uplift[index] / maxf(uplift_peak, 0.0001), 0.0, 1.0)
		context.uplift[index] = target_max * pow(normalised_uplift, mountain_exponent) if uplift_peak > 0.0 else 0.0
		var height := maxf(plain, context.uplift[index])
		# The rim keeps to the map's own height budget. It is scaled by a gain
		# solved without it, so nothing stops it overshooting — and a frame standing
		# a head above every range behind it reads as a wall however ragged it is.
		if context.border_locked[index] != 0:
			height = minf(height, ceiling_height)
		context.height_field[index] = height

	# The two targets can be genuinely incompatible: mountains wide enough to hold
	# their own peaks can cover so much of a small board that no plain exponent
	# brings the average down. That is a fact about the recipe, not a failure of
	# the solver, so it is said out loud rather than met halfway in silence.
	if mountain_exponent >= MAX_MOUNTAIN_EXPONENT - 0.01 and exponent >= MAX_EXPONENT - 0.01:
		context.note("elevation: even the narrowest mountain profile cannot reach a mean of %.1f" % target_mean)
	elif mountain_exponent > MIN_MOUNTAIN_EXPONENT + 0.01:
		context.note("elevation: mountain profile narrowed to %.2f to preserve mean %.1f and peaks %.1f" % [
			mountain_exponent, target_mean, target_max,
		])


static func _land_indices(context: GenerationContext) -> PackedInt32Array:
	var land := PackedInt32Array()
	for index in context.cell_count:
		if context.is_land[index] != 0:
			land.append(index)
	return land


## The land the recipe was describing: everything except the frame. It is what the
## verdict measures the mean and the maximum over (§6), so it is what the solver
## has to aim at.
static func _sample_indices(context: GenerationContext, land: PackedInt32Array) -> PackedInt32Array:
	var sample := PackedInt32Array()
	for index: int in land:
		if context.border_locked[index] == 0:
			sample.append(index)
	return sample


static func _plain_ceiling(recipe: MapRecipe) -> float:
	var factor := float(PLAIN_CEILING_FACTOR.get(recipe.hypsometry, 3.0))
	var mean := float(recipe.land_mean_height)
	var floor_value := mean + 1.0
	# The ceiling has to sit strictly above the mean (otherwise no exponent
	# reaches it) and never above the requested maximum.
	return clampf(maxf(mean, 1.0) * factor, floor_value, maxf(float(recipe.land_max_height), floor_value))


## Rank-normalise, then bend. Ranking first is the whole trick: it makes the
## result independent of what the noise's own histogram looked like.
static func _shaped_field(context: GenerationContext, land: PackedInt32Array) -> PackedFloat32Array:
	var recipe := context.recipe
	var biased := PackedFloat32Array()
	biased.resize(context.cell_count)
	for index: int in land:
		var value := context.relief[index]
		if recipe.hypsometry == MapRecipe.HYPSOMETRY_BOWL:
			# A bowl is a spatial statement, not only a histogram one: the rim is
			# high because it is the rim, so the radius joins the ranking key.
			var cell := context.cell_of_index(index)
			var radius := context.normalised(cell.x, cell.y).length() / sqrt(2.0)
			value = value * 0.3 + radius * 0.7
		biased[index] = value

	var order := PackedInt32Array(land)
	var keys := biased
	var sorted: Array[int] = []
	sorted.resize(order.size())
	for position in order.size():
		sorted[position] = order[position]
	sorted.sort_custom(func(a: int, b: int) -> bool:
		return keys[a] < keys[b] if not is_equal_approx(keys[a], keys[b]) else a < b)

	var shaped := PackedFloat32Array()
	shaped.resize(context.cell_count)
	var last := maxi(sorted.size() - 1, 1)
	for position in sorted.size():
		var t := float(position) / float(last)
		var index: int = sorted[position]
		var effective_roughness := clampf(recipe.roughness + context.roughness_adjustment, 0.0, 1.0)
		var detail := context.roughness_detail[index] * effective_roughness * ROUGHNESS_AMPLITUDE
		shaped[index] = clampf(_curve(recipe.hypsometry, t) + detail, 0.0, 1.0)
	return shaped


## The five curves of §3.4. Each maps a uniform 0…1 rank to the share of the
## height range that rank should occupy.
static func _curve(id: StringName, t: float) -> float:
	match id:
		MapRecipe.HYPSOMETRY_ROLLING:
			return smoothstep(0.0, 1.0, t)
		MapRecipe.HYPSOMETRY_PLATEAU:
			# Two shelves with a wall between them: the ledge is where the curve jumps.
			return t / 0.6 * 0.18 if t < 0.6 else 0.72 + (t - 0.6) / 0.4 * 0.28
		MapRecipe.HYPSOMETRY_BOWL:
			return smoothstep(0.0, 1.0, t)
		MapRecipe.HYPSOMETRY_ALPINE:
			return pow(t, 0.55)
		_:
			# plains_with_peaks: most of the area within a few steps of the mean,
			# and a long thin tail upwards.
			return pow(t, 3.0)


static func _solve_exponent(
	context: GenerationContext, land: PackedInt32Array, shaped: PackedFloat32Array,
	ceiling: float, target_mean: float, uplift_peak: float,
	mountain_exponent: float, target_max: float,
) -> float:
	var low := MIN_EXPONENT
	var high := MAX_EXPONENT
	for _step in SOLVER_STEPS:
		var middle := (low + high) * 0.5
		if _mean_of(context, land, shaped, ceiling, middle, uplift_peak, mountain_exponent, target_max) > target_mean:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


## Find the least narrowing that lets the plains solver reach the requested mean.
## The maximum stays fixed because `target_max * pow(1, p) == target_max`.
static func _solve_mountain_exponent(
	context: GenerationContext, land: PackedInt32Array, shaped: PackedFloat32Array,
	ceiling: float, target_mean: float, uplift_peak: float, target_max: float,
) -> float:
	if _mean_of(context, land, shaped, ceiling, MAX_EXPONENT, uplift_peak, MIN_MOUNTAIN_EXPONENT, target_max) <= target_mean:
		return MIN_MOUNTAIN_EXPONENT
	var low := MIN_MOUNTAIN_EXPONENT
	var high := MAX_MOUNTAIN_EXPONENT
	for _step in SOLVER_STEPS:
		var middle := (low + high) * 0.5
		if _mean_of(context, land, shaped, ceiling, MAX_EXPONENT, uplift_peak, middle, target_max) > target_mean:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


static func _mean_of(
	context: GenerationContext, land: PackedInt32Array, shaped: PackedFloat32Array,
	ceiling: float, exponent: float, uplift_peak: float,
	mountain_exponent: float, target_max: float,
) -> float:
	var total := 0.0
	for index: int in land:
		var mountain := 0.0
		if uplift_peak > 0.0:
			mountain = target_max * pow(clampf(context.uplift[index] / uplift_peak, 0.0, 1.0), mountain_exponent)
		total += maxf(ceiling * pow(shaped[index], exponent), mountain)
	return total / float(land.size())


## The sea floor: a shelf of the requested width around the coast, deepening to
## open water beyond it. Depth is measured from `border.ocean_level`, so a recipe
## that moves the sea moves the whole basin with it.
static func _write_sea(context: GenerationContext) -> void:
	var recipe := context.recipe
	var shelf := maxf(float(recipe.shelf_width), 1.0)
	for index in context.cell_count:
		if context.is_land[index] != 0:
			continue
		var distance := -context.shore_distance[index]
		var t := clampf(distance / (shelf * 3.0), 0.0, 1.0)
		var depth := 1.0 + pow(t, 1.4) * float(SEA_DEPTH - 1)
		context.height_field[index] = float(recipe.ocean_level) - depth
