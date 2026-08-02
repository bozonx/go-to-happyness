class_name BorderShaper
extends RefCounted

## Stage 5: what each side of the board ends in
## (procedural_map_generation.md §3.2).
##
## The four sides are independent — ocean west and north, mountains east and
## south is the ordinary case, not the exception — so the stage is written per
## side and the corners are resolved by precedence rather than by special cases.
##
## **A wall has to actually be a wall.** The band is raised to a crest and its
## inner face is left sheer on purpose: `ReposePass` skips the cells this stage
## locks, because a wall is not ground that failed to settle. Whether the result
## is really impassable is not assumed here — the metrics stage floods `NavGrid`
## from the centre of the board and refuses a map the flood can walk out of (§6).
##
## Where a wall meets an ocean side the ocean wins by the width of its own shelf:
## the wall runs to the corner and dives into the sea as a headland, which is the
## case naive implementations turn into a staircase into deep water.

const STAGE := &"border"
## Extra cells beyond the shelf over which an ocean edge blends into the map.
const OCEAN_BLEND := 3
## How strong the ocean pull has to be before a column is counted as certain sea
## by `classify`. It matches the cut-off `apply` uses to stop a wall climbing back
## out of the water, so the plan and the shaping cannot disagree.
const FORCED_SEA_PULL := 0.55


## Stage 0 of the border: what the sides will force whatever the composition
## says. It runs BEFORE the landmass stage on purpose — a wall four cells thick on
## two sides of a 48-cell board is a sixth of the area, and a land-fraction solver
## that learns about it only afterwards misses its target by exactly that much.
##
## Splitting the plan from the shaping is the only way the two can be consistent
## by construction rather than by two copies of the same arithmetic.
static func classify(context: GenerationContext) -> void:
	var recipe := context.recipe
	var ocean_band := maxi(recipe.shelf_width, 2) + OCEAN_BLEND
	var low := context.min_coordinate()
	var high := context.max_coordinate()
	for z in range(low, high + 1):
		for x in range(low, high + 1):
			var index := context.index_of(x, z)
			var distances := PackedInt32Array([z - low, high - x, high - z, x - low])
			for side_index in MapRecipe.SIDES.size():
				var side: StringName = MapRecipe.SIDES[side_index]
				var kind := recipe.border_kind(side)
				var distance := distances[side_index]
				if kind == MapRecipe.BORDER_OCEAN:
					if 1.0 - float(distance) / float(ocean_band) >= FORCED_SEA_PULL:
						context.border_sea[index] = 1
				elif kind == MapRecipe.BORDER_MOUNTAIN_WALL or kind == MapRecipe.BORDER_PLATEAU:
					if distance < recipe.border_thickness(side):
						context.border_locked[index] = 1
	# Where the two meet the sea wins by the width of its own shelf: the wall runs
	# to the corner and dives, which is what makes a headland instead of a
	# staircase into deep water (§3.2).
	for index in context.cell_count:
		if context.border_sea[index] != 0:
			context.border_locked[index] = 0


static func apply(context: GenerationContext) -> void:
	var recipe := context.recipe
	var ocean_band := maxi(recipe.shelf_width, 2) + OCEAN_BLEND
	var ocean_floor := float(recipe.ocean_level) - float(Hypsometry.SEA_DEPTH)
	var ridge := context.seeds.noise(STAGE, 6.0 / float(context.board_cells), 2)

	var low := context.min_coordinate()
	var high := context.max_coordinate()
	for z in range(low, high + 1):
		for x in range(low, high + 1):
			var index := context.index_of(x, z)
			var distances := PackedInt32Array([z - low, high - x, high - z, x - low])
			# Ocean first: a side that ends in water sinks the corner it shares
			# with a wall, which is what turns the wall into a headland.
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
					context.is_land[index] = 1 if context.height_field[index] > float(recipe.ocean_level) else 0

			var crest := -INF
			for side_index in MapRecipe.SIDES.size():
				var side: StringName = MapRecipe.SIDES[side_index]
				var kind := recipe.border_kind(side)
				if kind != MapRecipe.BORDER_MOUNTAIN_WALL and kind != MapRecipe.BORDER_PLATEAU:
					continue
				var distance := distances[side_index]
				if distance >= recipe.border_thickness(side):
					continue
				crest = maxf(crest, _band_height(ridge, recipe, side, x, z, distance, kind))
			if crest == -INF:
				continue
			# A wall drowned by the neighbouring ocean side stays drowned: the
			# headland ends where the shelf begins, it does not climb back out.
			# `classify` already resolved that corner, so this reads its answer
			# instead of recomputing the same cut-off a second time.
			if context.border_locked[index] == 0:
				continue
			context.height_field[index] = maxf(context.height_field[index], crest)
			context.is_land[index] = 1


## A wall is flat-topped across its thickness and stops dead at the inner edge —
## that is the face. A plateau is the same shape at a gentler height; the
## difference between the two is what the recipe asked for, not how they are
## built.
static func _band_height(ridge: FastNoiseLite, recipe: MapRecipe, side: StringName, x: int, z: int, distance: int, kind: StringName) -> float:
	var base := float(recipe.land_mean_height)
	var crest := base + float(recipe.border_height(side))
	if kind == MapRecipe.BORDER_PLATEAU:
		return crest
	var thickness := maxi(recipe.border_thickness(side), 1)
	# The outermost cells carry the full crest; the innermost one still carries
	# nearly all of it, so the drop to the land inside stays a single face.
	var t := 1.0 - float(distance) / float(thickness)
	var roughness := ridge.get_noise_2d(float(x), float(z)) * float(recipe.border_height(side)) * 0.08
	return base + (crest - base) * (0.55 + 0.45 * t) + roughness
