class_name LandmassField
extends RefCounted

## Stage 1: where the land is (procedural_map_generation.md §3.3, §4).
##
## A composition mask gives the crude shape the preset promises — a continent, a
## coastline, an island, an archipelago — and a noise field breaks its outline.
## The land/sea decision is then a THRESHOLD SOLVED FOR, not a threshold chosen:
## `land_fraction` is a property of the finished map, so the stage bisects until
## the requested share of the board is above water (§5.3). That is what makes the
## utopian promise of the design doc true — 62 % of land on every seed, not on the
## lucky ones.
##
## `island_count` is enforced the only way it can be on a thresholded field: the
## components beyond the requested number are drowned and the threshold re-solved,
## so the land the author asked for comes back somewhere the author asked for it.

const STAGE := &"landmass"
const SOLVER_STEPS := 42
const ISLAND_PASSES := 5
## Components smaller than this are foam, not islands; drowning them one by one
## would make `island_count` a count of noise speckles.
const MIN_ISLAND_CELLS := 6

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


static func build(context: GenerationContext) -> void:
	var recipe := context.recipe
	if recipe.shape == MapRecipe.SHAPE_INLAND:
		context.is_land.fill(1)
		for index in context.cell_count:
			if context.border_sea[index] != 0:
				context.is_land[index] = 0
		_measure_shore_distance(context)
		return

	var signal_field := _composition_signal(context)
	var wanted := clampf(recipe.land_fraction + context.land_fraction_bias, 0.0, 1.0)
	var threshold := _solve_threshold(context, signal_field, wanted)
	_threshold_into(context, signal_field, threshold)

	# Drowning the surplus islands removes land, so the threshold has to come back
	# down to give it back on the components that survived. Two or three rounds
	# settle; the loop is bounded because each round only ever removes cells.
	for _pass in ISLAND_PASSES:
		var removed := _drown_surplus_islands(context, recipe.island_count)
		if removed == 0:
			break
		threshold = _solve_threshold(context, signal_field, wanted, context.is_land)
		_threshold_into(context, signal_field, threshold, context.is_land)

	_measure_shore_distance(context)


## The crude composition each preset stands for, perturbed by fBm. `coast_ruggedness`
## is both the amplitude and the frequency of that perturbation: a smooth arc at 0,
## fjords at 1.
static func _composition_signal(context: GenerationContext) -> PackedFloat32Array:
	var recipe := context.recipe
	var rugged := recipe.coast_ruggedness
	var base := context.seeds.noise(STAGE, 2.4 / float(context.board_cells), 4)
	var detail := context.seeds.noise(&"landmass_detail", (5.0 + 9.0 * rugged) / float(context.board_cells), 3)
	var blobs := context.seeds.noise(&"landmass_blobs", 4.5 / float(context.board_cells), 2)
	var amplitude := 0.18 + 0.55 * rugged
	var result := PackedFloat32Array()
	result.resize(context.cell_count)
	for z in range(context.min_coordinate(), context.max_coordinate() + 1):
		for x in range(context.min_coordinate(), context.max_coordinate() + 1):
			var p := context.normalised(x, z)
			var mask := _shape_mask(recipe.shape, p, blobs.get_noise_2d(float(x), float(z)))
			var perturbation := base.get_noise_2d(float(x), float(z)) * 0.6 + detail.get_noise_2d(float(x), float(z)) * 0.4
			result[context.index_of(x, z)] = mask + perturbation * amplitude
	return result


static func _shape_mask(shape: StringName, p: Vector2, blob: float) -> float:
	match shape:
		MapRecipe.SHAPE_COAST:
			# Land in the west, open water in the east: one coastline across the board.
			return 0.85 - (p.x + 1.0) * 0.85
		MapRecipe.SHAPE_BIG_ISLAND:
			return 1.0 - pow(p.length() / 0.72, 2.0)
		MapRecipe.SHAPE_ARCHIPELAGO:
			# Scattered blobs, faded near the rim so the sea always reaches the edge.
			return blob * 1.5 + 0.15 - pow(p.length() / 1.05, 3.0)
		MapRecipe.SHAPE_INLAND:
			return 1.0
		_:
			return 1.0 - pow(p.length() / 0.95, 2.2)


## Bisection on the threshold until the land share matches. Solving beats
## choosing: the same recipe then produces the same utopian 62 % on every seed
## rather than "whatever this noise happened to give".
static func _solve_threshold(context: GenerationContext, signal_field: PackedFloat32Array, target: float, restrict_to: PackedByteArray = PackedByteArray()) -> float:
	var low := -4.0
	var high := 4.0
	# The border bands are not up for negotiation, so they are not part of what
	# the solver is allowed to move: a wall is excluded from the board the share
	# is measured over, and a drowned rim counts as sea that is already there.
	var free_cells := 0
	for index in context.cell_count:
		if context.border_locked[index] == 0:
			free_cells += 1
	var wanted := int(round(clampf(target, 0.0, 1.0) * float(free_cells)))
	for _step in SOLVER_STEPS:
		var middle := (low + high) * 0.5
		var count := 0
		for index in context.cell_count:
			if context.border_locked[index] != 0 or context.border_sea[index] != 0:
				continue
			if restrict_to.size() == context.cell_count and restrict_to[index] == 0:
				continue
			if signal_field[index] > middle:
				count += 1
		if count > wanted:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


static func _threshold_into(context: GenerationContext, signal_field: PackedFloat32Array, threshold: float, restrict_to: PackedByteArray = PackedByteArray()) -> void:
	var restricted := restrict_to.size() == context.cell_count
	for index in context.cell_count:
		if context.border_sea[index] != 0:
			context.is_land[index] = 0
			continue
		if context.border_locked[index] != 0:
			context.is_land[index] = 1
			continue
		var allowed := not restricted or restrict_to[index] != 0
		context.is_land[index] = 1 if allowed and signal_field[index] > threshold else 0


## Keeps the main mass plus `island_count` further components and drowns the
## rest. Returns how many cells went under, so the caller knows whether the land
## share still has to be repaid.
static func _drown_surplus_islands(context: GenerationContext, island_count: int) -> int:
	var components := connected_components(context, context.is_land)
	if components.size() <= island_count + 1:
		return 0
	components.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	var removed := 0
	for position in range(island_count + 1, components.size()):
		var component: Array = components[position]
		if component.size() < MIN_ISLAND_CELLS and position < island_count + 1 + MIN_ISLAND_CELLS:
			continue
		for index: int in component:
			context.is_land[index] = 0
			removed += 1
	return removed


## Four-connected components of a mask, each as an array of buffer indices. Also
## used by the metrics stage to measure the largest land component (§6).
static func connected_components(context: GenerationContext, mask: PackedByteArray) -> Array:
	var seen := PackedByteArray()
	seen.resize(context.cell_count)
	var components: Array = []
	var queue := PackedInt32Array()
	for start in context.cell_count:
		if mask[start] == 0 or seen[start] != 0:
			continue
		seen[start] = 1
		queue.clear()
		queue.append(start)
		var head := 0
		var component := PackedInt32Array()
		while head < queue.size():
			var index := queue[head]
			head += 1
			component.append(index)
			var cell := context.cell_of_index(index)
			for offset: Vector2i in NEIGHBOURS:
				var neighbour := cell + offset
				if not context.contains(neighbour.x, neighbour.y):
					continue
				var neighbour_index := context.cell_index(neighbour)
				if seen[neighbour_index] != 0 or mask[neighbour_index] == 0:
					continue
				seen[neighbour_index] = 1
				queue.append(neighbour_index)
		components.append(component)
	return components


## Signed distance to the coast in cells: how far inland a column is, or how far
## out to sea. Two BFS sweeps, because the shelf profile and the coastal presets
## both need the same number with opposite signs.
static func _measure_shore_distance(context: GenerationContext) -> void:
	var distance := PackedInt32Array()
	distance.resize(context.cell_count)
	distance.fill(-1)
	var queue := PackedInt32Array()
	for index in context.cell_count:
		var cell := context.cell_of_index(index)
		var boundary := false
		for offset: Vector2i in NEIGHBOURS:
			var neighbour := cell + offset
			if not context.contains(neighbour.x, neighbour.y):
				continue
			if context.is_land[context.cell_index(neighbour)] != context.is_land[index]:
				boundary = true
				break
		if boundary:
			distance[index] = 0
			queue.append(index)
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var cell := context.cell_of_index(index)
		for offset: Vector2i in NEIGHBOURS:
			var neighbour := cell + offset
			if not context.contains(neighbour.x, neighbour.y):
				continue
			var neighbour_index := context.cell_index(neighbour)
			if distance[neighbour_index] >= 0:
				continue
			distance[neighbour_index] = distance[index] + 1
			queue.append(neighbour_index)
	for index in context.cell_count:
		# A board with no coastline at all (`inland`, or a seed that drowned
		# everything) leaves the sweep untouched; treat every column as deeply
		# inland rather than as a shore one cell wide.
		var value := float(distance[index]) if distance[index] >= 0 else float(context.board_cells)
		context.shore_distance[index] = value if context.is_land[index] != 0 else -value
