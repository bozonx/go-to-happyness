class_name BaseReliefField
extends RefCounted

## Stage 2: the shape of the ordinary ground (procedural_map_generation.md §4).
##
## This is the only place noise is allowed to decide anything by itself, and it
## decides the least important thing: which patch of plain is slightly higher than
## the patch beside it. Absolute heights are not set here — stage 4 remaps this
## field through the hypsometric curve and the solver, which is what keeps
## `land_mean_height` a promise rather than a hope (§5.3).
##
## `roughness` is the one recipe parameter that reaches this stage, and it does
## what its name says: it moves weight from the broad component to the fine one.
## At 0 the plains are long smooth swells; at 1 they are perpetually bumpy.

const STAGE := &"relief"


static func build(context: GenerationContext) -> void:
	var recipe := context.recipe
	var span := float(context.board_cells)
	var broad := context.seeds.noise(STAGE, 2.2 / span, 4, 0.5)
	var fine := context.seeds.noise(&"relief_fine", 9.0 / span, 4, 0.55)
	var ridged := context.seeds.noise(&"relief_ridged", 4.5 / span, 3, 0.5)
	var fine_weight := 0.12 + 0.48 * recipe.roughness
	var raw := PackedFloat32Array()
	raw.resize(context.cell_count)
	var lowest := INF
	var highest := -INF
	for z in range(context.min_coordinate(), context.max_coordinate() + 1):
		for x in range(context.min_coordinate(), context.max_coordinate() + 1):
			var index := context.index_of(x, z)
			var value := broad.get_noise_2d(float(x), float(z)) * (1.0 - fine_weight)
			value += fine.get_noise_2d(float(x), float(z)) * fine_weight
			# A touch of ridged noise keeps the plains from reading as pure blobs:
			# it puts low ribs and shallow valleys where rivers will later find
			# something to follow.
			value += (1.0 - absf(ridged.get_noise_2d(float(x), float(z)))) * 0.18
			# Rising away from the coast is not a rule of the noise, it is what a
			# coastline is: land that starts at the water and climbs inland.
			value += clampf(context.shore_distance[index] / (span * 0.35), 0.0, 1.0) * 0.35
			raw[index] = value
			if context.is_land[index] == 0:
				continue
			lowest = minf(lowest, value)
			highest = maxf(highest, value)
	if not is_finite(lowest) or highest - lowest < 0.0001:
		context.relief.fill(0.0)
		return
	var scale := 1.0 / (highest - lowest)
	for index in context.cell_count:
		context.relief[index] = clampf((raw[index] - lowest) * scale, 0.0, 1.0)
