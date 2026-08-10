class_name BorderShaper
extends RefCounted

## Stage 5: what each side of the board ends in
## (procedural_map_generation.md §3.2).
##
## The four sides are independent — ocean west and north, mountains east and
## south is the ordinary case, not the exception — so the stage is written per
## side and the corners are resolved by precedence rather than by special cases.
##
## **A wall has to be impassable; it does not have to be a wall.** The two used to
## be the same thing here: a slab of fixed thickness, flat across its top, with a
## sheer inner face, exempt from settling over its whole width. It was honest and
## it looked like the edge of a box.
##
## So the side is now two objects that happen to occupy the same ground:
##
## * **The rim** — an ordinary mountain range, grown from the same uplift the rest
##   of the map's ranges are grown from, at a crest height taken from those same
##   ranges. Its reach wanders along the side and its whole shape is warped, so the
##   inner edge comes out as headlands and bays rather than as a line. It settles,
##   it gets ramps, its foothills are ground the player walks on.
## * **The seal** — one closed contour, ONE CELL thick, hidden inside the body of
##   the rim, along which the drop is `seal.riser_steps` and nothing may build. That
##   contour, and nothing else, is what makes the side impassable: any path off the
##   board has to cross it, and a pedestrian walks up two steps at most (§3.2).
##   Several nested contours make the same guarantee look like terraces.
##
## The split is what lets the height of the frame stop being a separate number.
## Nothing about the rim's silhouette carries the promise, so the rim is free to be
## as ragged, as tall or as low as the map's own mountains are.
##
## Where a wall meets an ocean side the ocean wins by the width of its own shelf:
## the rim runs to the corner and dives into the sea as a headland, which is the
## case naive implementations turn into a staircase into deep water.

const STAGE := &"border"
const REACH_STAGE := &"border_reach"
const WARP_STAGE := &"border_warp"
const CREST_STAGE := &"border_crest"

## Extra cells beyond the shelf over which an ocean edge blends into the map.
const OCEAN_BLEND := 3
## How strong the ocean pull has to be before a column is counted as certain sea
## by `classify`. It matches the cut-off `apply` uses to stop a wall climbing back
## out of the water, so the plan and the shaping cannot disagree.
const FORCED_SEA_PULL := 0.55

## Where the rim's crest stands inside its reach. Near the outer edge on purpose:
## everything between the crest and the map is inner flank, which is where the
## seal and its terraces go and where the foothills the player sees come from.
const CREST_SHARE := 0.22
const CREST_MIN_CELLS := 2.0
## Where the innermost contour sits inside the reach — half way, so there is rim
## in front of it and rim behind it and it never lands on the crest itself.
const SEAL_SHARE := 0.5
## Cells between two risers of a terraced rim: the tread.
const TREAD_CELLS := 2
## How far the shape of a side is pushed sideways by the warp field, in cells.
## This is what turns a function of "distance to the edge" into a coastline.
const WARP_CELLS := 6.0
## Steepness of the rim's flanks in the vocabulary `MountainSkeleton` uses. 0.7 is
## two steps per cell on rock — a flank a pedestrian climbs — because the part of
## it inside the seal is ground, not scenery.
const RIM_STEEPNESS := 0.7

const NEIGHBOURS_8: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]


## Stage 0 of the border: the geometry of the frame, before anything has a height.
## It runs BEFORE the landmass stage on purpose — the rim is a sixth of a small
## board, and a land-fraction solver that learns about it only afterwards misses
## its target by exactly that much.
##
## What it produces is one number per column, `border_outer`: how many of the
## nested contours this column stands beyond. Everything else here and in the two
## stages that follow is read off it, so "outside the map" is one fact in one
## buffer rather than three files agreeing by arithmetic.
static func classify(context: GenerationContext) -> void:
	var recipe := context.recipe
	var ocean_band := maxi(recipe.shelf_width, 2) + OCEAN_BLEND
	var low := context.min_coordinate()
	var high := context.max_coordinate()

	context.border_locked.fill(0)
	context.border_wall.fill(0)
	context.border_sea.fill(0)
	context.border_outer.fill(0)
	context.border_seal.fill(0)
	_build_warp(context)
	var reach_tables := _reach_tables(context)

	for z in range(low, high + 1):
		for x in range(low, high + 1):
			var index := context.index_of(x, z)
			var distances := _distances(low, high, x, z)
			for side_index in MapRecipe.SIDES.size():
				var side: StringName = MapRecipe.SIDES[side_index]
				var kind := recipe.border_kind(side)
				var distance := distances[side_index]
				if kind == MapRecipe.BORDER_OCEAN:
					if 1.0 - float(distance) / float(ocean_band) >= FORCED_SEA_PULL:
						context.border_sea[index] = 1
				elif kind == MapRecipe.BORDER_PLATEAU:
					# A plateau is still an authored shelf: a flat band of stated
					# thickness is what the recipe means by the word, and a shelf can
					# be climbed, so none of the rim machinery applies to it.
					if distance < recipe.border_thickness(side):
						context.border_locked[index] = 1
			var level := _outer_level(context, reach_tables, distances, index)
			if level > 0:
				context.border_outer[index] = level
				context.border_locked[index] = 1
				context.border_wall[index] = 1

	# Where the two meet the sea wins by the width of its own shelf: the rim runs
	# to the corner and dives, which is what makes a headland instead of a
	# staircase into deep water (§3.2). This happens before the contour is traced,
	# so a drowned corner simply has no contour rather than a wall along the water.
	for index in context.cell_count:
		if context.border_sea[index] == 0:
			continue
		context.border_locked[index] = 0
		context.border_wall[index] = 0
		context.border_outer[index] = 0

	_trace_seal(context)


## The contour itself: a column stands on it when it is beyond contour `n` and one
## of its eight neighbours is not. Tracing it from the region instead of drawing it
## as a curve is what makes it closed by construction — including around corners,
## where two sides overlap and a hand-drawn line needs a special case.
##
## Eight neighbours and not four, because navigation moves diagonally: with four,
## the first column a walker enters when leaving the board diagonally would not be
## on the contour and would owe nothing to the riser.
static func _trace_seal(context: GenerationContext) -> void:
	for index in context.cell_count:
		var level := int(context.border_outer[index])
		if level == 0:
			continue
		var cell := context.cell_of_index(index)
		for offset: Vector2i in NEIGHBOURS_8:
			var neighbour := cell + offset
			# The board edge is not "inside": there is no ground out there for
			# anything to walk in from, so a column on the outer face of the rim is
			# not a contour and does not get a riser it has no reason to have.
			if not context.contains(neighbour.x, neighbour.y):
				continue
			if int(context.border_outer[context.cell_index(neighbour)]) < level:
				context.border_seal[index] = 1
				break


## Stage 3b: the rim as uplift, written into the same buffer the ranges of §3.5
## use and read by everything downstream that asks "is this a mountain" — the
## hypsometric solver, the ground mask that hands out the angle of repose, the
## rain shadow. A rim added later, straight onto the height field, would be a
## mountain none of those stages could see.
##
## The profile is a crest line running along the side at a wandering distance from
## it, with the flanks grown from the same gradient rule `MountainSkeleton` uses:
## the inner flank has to be ground the catalog can express, or the whole edge of
## the board becomes a staircase of cliffs the moment slopes are assigned.
static func raise_rims(context: GenerationContext) -> void:
	var recipe := context.recipe
	context.border_rim.fill(0)
	var sides: Array[int] = []
	for side_index in MapRecipe.SIDES.size():
		if recipe.border_kind(MapRecipe.SIDES[side_index]) == MapRecipe.BORDER_MOUNTAIN_WALL:
			sides.append(side_index)
	if sides.is_empty():
		return

	var reach_tables := _reach_tables(context)
	var crest_tables := _crest_tables(context)
	var gradient := MountainSkeleton.flank_gradient(recipe.repose_override, RIM_STEEPNESS)
	var low := context.min_coordinate()
	var high := context.max_coordinate()
	var tallest := 0.0
	for z in range(low, high + 1):
		for x in range(low, high + 1):
			var index := context.index_of(x, z)
			var distances := _distances(low, high, x, z)
			for side_index: int in sides:
				var offset := _table_offset(context, side_index, index)
				var reach := _sample(reach_tables[side_index], offset)
				var distance := float(distances[side_index])
				if distance > reach:
					continue
				# The footprint is the reach, not the part of it the profile happens
				# to raise: the outermost column of a rim sits at the foot of its own
				# outer flank and carries no uplift, and a mask that leaves it out
				# describes a rim with a hole along the board edge.
				context.border_rim[index] = 1
				var crest_distance := clampf(reach * CREST_SHARE, CREST_MIN_CELLS, reach - 1.0)
				var inner := maxf(reach - crest_distance, 1.0)
				var outer := maxf(crest_distance, 1.0)
				# The crest can only be as tall as its own inner flank can carry at
				# the gradient the ground allows. Asking for more does not make a
				# taller mountain, it makes a cliff wearing one.
				var crest := minf(_sample(crest_tables[side_index], offset), inner * gradient / MountainSkeleton.FLANK_PROFILE)
				var t := (crest_distance - distance) / outer if distance < crest_distance else (distance - crest_distance) / inner
				var value := crest * pow(clampf(1.0 - t, 0.0, 1.0), MountainSkeleton.FLANK_PROFILE)
				if value <= 0.0:
					continue
				tallest = maxf(tallest, crest)
				if value > context.uplift[index]:
					context.uplift[index] = value
	context.note("border: rim crests reach %d steps of uplift" % roundi(tallest))


## Stage 5 proper, on the height field: the sea, and the plateau shelf that is
## still authored as a band. The mountain rim is deliberately absent — it was
## written as uplift before the hypsometric solver ran, which is the whole point
## of it being a mountain rather than a frame.
static func apply(context: GenerationContext) -> void:
	var recipe := context.recipe
	var ocean_band := maxi(recipe.shelf_width, 2) + OCEAN_BLEND
	var ocean_floor := float(recipe.ocean_level) - float(Hypsometry.SEA_DEPTH)

	var low := context.min_coordinate()
	var high := context.max_coordinate()
	for z in range(low, high + 1):
		for x in range(low, high + 1):
			var index := context.index_of(x, z)
			var distances := _distances(low, high, x, z)
			# Ocean first: a side that ends in water sinks the corner it shares
			# with a rim, which is what turns the rim into a headland.
			var ocean_pull := 0.0
			for side_index in MapRecipe.SIDES.size():
				var side: StringName = MapRecipe.SIDES[side_index]
				if recipe.border_kind(side) != MapRecipe.BORDER_OCEAN:
					continue
				var distance := distances[side_index]
				if distance >= ocean_band:
					continue
				ocean_pull = maxf(ocean_pull, 1.0 - float(distance) / float(ocean_band))
			if ocean_pull > 0.0:
				var weight := smoothstep(0.0, 1.0, ocean_pull)
				context.height_field[index] = lerpf(context.height_field[index], ocean_floor, weight)
				# The blend shapes the shelf; it does not get to move the coastline.
				# Outside the band `classify` already counted as certain sea, a column
				# the land-fraction solver decided was land stays land — otherwise the
				# rim quietly drowns a few per cent of the board on every map and the
				# solved share is short by exactly that much.
				if context.is_land[index] != 0 and context.border_sea[index] == 0:
					context.height_field[index] = maxf(context.height_field[index], float(recipe.ocean_level) + 1.0)
				else:
					context.is_land[index] = 1 if context.height_field[index] >= float(recipe.ocean_level) else 0

			var shelf := -INF
			for side_index in MapRecipe.SIDES.size():
				var side: StringName = MapRecipe.SIDES[side_index]
				if recipe.border_kind(side) != MapRecipe.BORDER_PLATEAU:
					continue
				if distances[side_index] >= recipe.border_thickness(side):
					continue
				shelf = maxf(shelf, float(recipe.land_mean_height) + float(recipe.border_height(side)))
			if shelf == -INF:
				continue
			# A shelf drowned by the neighbouring ocean side stays drowned: it ends
			# where the sea begins, it does not climb back out.
			if context.border_locked[index] == 0:
				continue
			context.height_field[index] = maxf(context.height_field[index], shelf)
			context.is_land[index] = 1


# --- Geometry -----------------------------------------------------------------

## Distance to each of the four sides, in the order of `MapRecipe.SIDES`.
static func _distances(low: int, high: int, x: int, z: int) -> PackedInt32Array:
	return PackedInt32Array([z - low, high - x, high - z, x - low])


## The warp field, one value per column, in cells. Every stage of the border reads
## THIS buffer rather than sampling the noise again: the rim, the contour and the
## frame the metrics exclude have to be the same shape down to the cell, and two
## samplers of the same noise are one refactor away from not being.
static func _build_warp(context: GenerationContext) -> void:
	var field := context.seeds.noise(WARP_STAGE, 9.0 / float(context.board_cells), 2)
	context.border_warp.resize(context.cell_count)
	for index in context.cell_count:
		var cell := context.cell_of_index(index)
		context.border_warp[index] = field.get_noise_2d(float(cell.x), float(cell.y)) * WARP_CELLS


## Where along its side a column reads the rim's profile: its own coordinate along
## that side, pushed sideways by the warp. Sampling the profile at a warped
## position is what turns a curve that is a function of one coordinate into
## something with headlands and bays — the same trick that gives the coastline its
## shape, for the same reason.
static func _table_offset(context: GenerationContext, side_index: int, index: int) -> float:
	var cell := context.cell_of_index(index)
	var along := float(cell.x) if side_index == 0 or side_index == 2 else float(cell.y)
	return along - float(context.min_coordinate()) + context.border_warp[index]


## Per side, the reach at every position along it. A table and not a noise call
## per column: the reach is a property of the position along the side, and a board
## of 512 asks for it a quarter of a million times.
static func _reach_tables(context: GenerationContext) -> Array:
	var field := context.seeds.noise(REACH_STAGE, 5.0 / float(context.board_cells), 3)
	var tables: Array = []
	for side_index in MapRecipe.SIDES.size():
		var side: StringName = MapRecipe.SIDES[side_index]
		var table := PackedFloat32Array()
		table.resize(context.board_cells)
		var reach := context.recipe.border_reach(side)
		for position in context.board_cells:
			# Full amplitude, not half of it. Fractal noise of three octaves spends
			# most of its time near the middle of −1…1, so the textbook `0.5 + 0.5 n`
			# turned a reach of 8…18 into 10…15 and the ragged edge the whole stage
			# exists for came out as a wobble of one cell.
			var t := 0.5 + field.get_noise_2d(float(position), 128.0 * float(side_index + 1))
			table[position] = lerpf(float(reach[0]), float(reach[1]), clampf(t, 0.0, 1.0))
		tables.append(table)
	return tables


## Per side, the crest height at every position along it, in uplift steps — the
## same units the ranges of §3.5 are written in, so the solver scales both by the
## same gain and the rim comes out as tall as the map's own mountains.
static func _crest_tables(context: GenerationContext) -> Array:
	var field := context.seeds.noise(CREST_STAGE, 7.0 / float(context.board_cells), 3)
	var tables: Array = []
	for side_index in MapRecipe.SIDES.size():
		var side: StringName = MapRecipe.SIDES[side_index]
		var span := _crest_range(context.recipe, side)
		var table := PackedFloat32Array()
		table.resize(context.board_cells)
		for position in context.board_cells:
			# Full amplitude, not half of it. Fractal noise of three octaves spends
			# most of its time near the middle of −1…1, so the textbook `0.5 + 0.5 n`
			# turned a reach of 8…18 into 10…15 and the ragged edge the whole stage
			# exists for came out as a wobble of one cell.
			var t := 0.5 + field.get_noise_2d(float(position), 512.0 * float(side_index + 1))
			table[position] = lerpf(span.x, span.y, clampf(t, 0.0, 1.0))
		tables.append(table)
	return tables


## How tall the rim of a side is allowed to be, in uplift steps.
##
## §3.2: an author who says nothing about the height gets a rim made of the same
## mountains as the rest of the map, because that is what "the edge of the map is
## mountains" means. A stated `height` is still honoured — as a crest the rim aims
## at, not as a level every column of it holds.
static func _crest_range(recipe: MapRecipe, side: StringName) -> Vector2:
	if recipe.border_height_is_authored(side):
		var stated := float(recipe.land_mean_height + recipe.border_height(side))
		return Vector2(stated * 0.72, stated)
	var lowest := INF
	var highest := 0.0
	for entry: Dictionary in recipe.mountain_ranges:
		if int(entry.get("count", 0)) <= 0:
			continue
		var heights: Array[int] = entry["peak_height"]
		lowest = minf(lowest, float(heights[0]))
		highest = maxf(highest, float(heights[1]))
	if int(recipe.solitary_peaks.get("count", 0)) > 0:
		var peak_heights: Array[int] = recipe.solitary_peaks["height"]
		lowest = minf(lowest, float(peak_heights[0]))
		highest = maxf(highest, float(peak_heights[1]))
	if is_inf(lowest) or highest <= 0.0:
		# A map with no ranges at all still has a height budget, and the edge of it
		# is the one place a mountain is guaranteed to belong.
		var ceiling := float(recipe.land_max_height)
		return Vector2(ceiling * 0.5, ceiling * 0.8)
	return Vector2(lowest, highest)


static func _sample(table: PackedFloat32Array, position: float) -> float:
	if table.is_empty():
		return 0.0
	var clamped := clampf(position, 0.0, float(table.size() - 1))
	var index := int(clamped)
	var next := mini(index + 1, table.size() - 1)
	return lerpf(table[index], table[next], clamped - float(index))


## How far from the side contour `ring` runs, in cells. Contour 1 is the one the
## player meets — the deepest inland — and each further one steps back towards the
## edge by a tread, which is what stacks them into terraces.
static func seal_offset(recipe: MapRecipe, side: StringName, reach: float, ring: int) -> float:
	var risers := recipe.border_seal_risers(side)
	var base := maxf(reach * SEAL_SHARE, float(1 + (risers - 1) * TREAD_CELLS))
	return maxf(base - float((ring - 1) * TREAD_CELLS), 1.0)


## How many contours a column stands beyond, over every `mountain_wall` side at
## once — so the corner where two sides overlap needs no rule of its own.
static func _outer_level(context: GenerationContext, reach_tables: Array, distances: PackedInt32Array, index: int) -> int:
	var recipe := context.recipe
	var level := 0
	for side_index in MapRecipe.SIDES.size():
		var side: StringName = MapRecipe.SIDES[side_index]
		if recipe.border_kind(side) != MapRecipe.BORDER_MOUNTAIN_WALL:
			continue
		var distance := float(distances[side_index])
		var reach := _sample(reach_tables[side_index], _table_offset(context, side_index, index))
		for ring in range(recipe.border_seal_risers(side), 0, -1):
			if distance < seal_offset(recipe, side, reach, ring):
				level = maxi(level, ring)
				break
	return level
