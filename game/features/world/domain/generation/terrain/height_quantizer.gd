class_name HeightQuantizer
extends RefCounted

## Stage 6: the continuous field becomes the integer columns of `TerrainGrid`
## (procedural_map_generation.md §4, §5.2).
##
## Quantisation happens BEFORE hydrology on purpose. Flow, basins and river beds
## have to be computed on the ground that will actually exist; a river routed over
## a float field and rounded afterwards runs uphill on the finished steps.
##
## `terrace_bias` decides what kind of discrete ground this is. At 0 the field is
## simply rounded and a hillside becomes a chain of one-step boundaries; at 1 the
## an expanding capture band snaps values to multiples of `TERRACE_STEP`. At 0
## only ordinary integer rounding happens; at 1 every value is captured by its
## nearest terrace. Unlike lerp-then-round, every part of the 0…1 range changes a
## measurable set of columns instead of saturating halfway.
##
## `TERRACE_STEP` is two and not three because of §5.2: the generator has to plan
## the ground a slope needs. A terrace three steps tall cannot be ramped by the
## catalog at the angle of repose of stone — `rise` has to divide the drop, and
## the classes that do (1) need more cells than the budget allows — so every
## terrace edge would become a `cliff`. Contours close, so those cliffs form
## rings, and a terraced board would shatter into hundreds of plateaus nobody can
## walk between. A drop of two takes a `very_steep` ramp in a single cell and the
## terraces stay connected.

const STAGE := &"quantize"
const TERRACE_STEP := 2


static func apply(context: GenerationContext) -> void:
	var bias := clampf(context.recipe.terrace_bias + context.terrace_bias_adjustment, 0.0, 1.0)
	# The authored shelf stays at the authored mean. Downstream mean correction is
	# paid by the surrounding relief and mountains; lifting the shelf itself made
	# every island need a wider coast ramp and consumed the buildable area.
	var main_terrace := context.recipe.land_mean_height
	if context.recipe.shape == MapRecipe.SHAPE_ARCHIPELAGO:
		# Small islands cannot spend five or six rings climbing from the sea and
		# still keep a buildable top. Their shared shelf starts two steps above the
		# ocean; sparse hills and peaks carry the requested map-wide mean. Only a
		# large measured mean deficit raises that shelf, one tier at a time.
		main_terrace = context.recipe.ocean_level + 2
		if context.mean_height_adjustment > 8.0:
			main_terrace += 2
		elif context.mean_height_adjustment > 4.0:
			main_terrace += 1
	var main_radius := bias * maxf(
		2.0, float(context.recipe.land_max_height - context.recipe.land_mean_height) * 0.25)
	for index in context.cell_count:
		var value := context.height_field[index]
		if bias > 0.0:
			# The broad buildable shelf is centred on the recipe's mean. Its capture
			# band expands continuously with the slider; mountains above the band keep
			# their solved profile and peak.
			if (
				value >= float(main_terrace) - 0.49
				and value <= float(main_terrace) + main_radius + maxf(context.mean_height_adjustment, 0.0)
				and context.uplift[index] <= float(main_terrace) + main_radius + maxf(context.mean_height_adjustment, 0.0)
			):
				value = float(main_terrace)
			else:
				var terrace: float = round(value / float(TERRACE_STEP)) * float(TERRACE_STEP)
				var capture_radius := bias * float(TERRACE_STEP) * 0.5
				if absf(value - terrace) <= capture_radius:
					value = terrace
		context.heights[index] = clampi(int(round(value)), TerrainGrid.MIN_HEIGHT, TerrainGrid.MAX_HEIGHT)
	context.refresh_land_mask()
