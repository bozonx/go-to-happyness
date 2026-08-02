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
## heights are pulled towards multiples of `TERRACE_STEP` first, and the result is
## the wide flat shelves separated by real faces that this grid is good at. It is
## a pull and not a snap, so the two ends are a continuum rather than two modes.
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
	var bias := context.recipe.terrace_bias
	for index in context.cell_count:
		var value := context.height_field[index]
		if bias > 0.0:
			var terrace: float = round(value / float(TERRACE_STEP)) * float(TERRACE_STEP)
			value = lerpf(value, terrace, bias)
		context.heights[index] = clampi(int(round(value)), TerrainGrid.MIN_HEIGHT, TerrainGrid.MAX_HEIGHT)
	context.refresh_land_mask()
