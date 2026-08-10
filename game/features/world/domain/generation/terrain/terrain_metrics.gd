class_name TerrainMetrics
extends RefCounted

## `verdict`: the map is measured, not admired
## (procedural_map_generation.md §6).
##
## A generated map passes when measurable conditions hold, not when it "looks
## natural". Everything here is read off the FINISHED grids — the same
## `TerrainGrid`, `WaterGrid` and `NavGrid` the game would use — so no metric can
## be right about a map the game then disagrees with. In particular passability is
## taken from the published navigation field rather than from the height
## differences the pipeline worked with: whether a boundary is crossable is
## `SlopeAssigner`'s answer, and this is where the two are made to agree.
##
## One convention runs through every figure: LAND means the ground inside the
## frame. Columns the border stage locked as a wall are excluded from the land
## share, the mean, the maximum and the connectivity — they are the edge of the
## board, not the map.
##
## Failure is a verdict with a reason, never a shrug. `failures()` returns the
## conditions the map broke, and the service is what decides to retry.

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


static func measure(context: GenerationContext, grid: TerrainGrid, water: WaterGrid, nav: NavGrid) -> Dictionary:
	var recipe := context.recipe
	var land: Array[Vector2i] = []
	var land_index: Dictionary = {}
	var total := 0
	var height_sum := 0
	var height_max := TerrainGrid.MIN_HEIGHT
	var height_min := TerrainGrid.MAX_HEIGHT
	var flat := 0
	var terrain_field: NavTerrainField = nav.terrain_field() if nav.has_terrain_field() else null
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			var height := grid.height_of(cell)
			height_min = mini(height_min, height)
			height_max = maxi(height_max, height)
			# A border wall is the frame of the map, not ground the recipe was
			# describing. Counting it as land would put a sixth of a small board
			# into `land_fraction` and pull `land_mean_height` up by the wall's own
			# crest, so every land figure is measured inside the frame (§3.2).
			if context.border_locked[context.cell_index(cell)] != 0:
				continue
			total += 1
			if height < recipe.ocean_level:
				continue
			land.append(cell)
			land_index[cell] = true
			# Measured over ALL the land inside the frame, ranges included, because
			# that is the number `Hypsometry` solves for. Measuring it over the
			# plains alone would compare the finished map against a target nobody
			# aimed at — the ranges are most of the height budget on a mountainous
			# recipe, and leaving them out reads 1 where the solver aimed at 5.
			height_sum += height
			if terrain_field != null and terrain_field.slope_class_at(cell) == NavTerrainField.class_from_steps_per_cell(0.0):
				flat += 1

	var land_count := land.size()
	var metrics: Dictionary = {
		"board_cells": grid.board_cells,
		"land_fraction": float(land_count) / float(maxi(total, 1)),
		"land_mean_height": float(height_sum) / float(maxi(land.size(), 1)),
		"land_max_height": _max_land_height(grid, land),
		"height_min": height_min,
		"height_max": height_max,
		"flat_fraction": float(flat) / float(maxi(land_count, 1)),
		"cliff_fraction": _cliff_fraction(terrain_field, land, land_index),
		"largest_land_component": _largest_component_share(grid, land, land_index),
		"pedestrian_reach": _reach_share(nav, land, &"pedestrian"),
		"cart_reach": _reach_share(nav, land, &"cart"),
		"pedestrian_walkable": _walkable_share(nav, land, &"pedestrian"),
		"walls_sealed": _walls_sealed(context, grid, nav),
		"rim_walkable": _rim_walkable(context, nav),
		"rim_edge_spread": _rim_edge_spread(context),
		"rivers_traced": int(context.river_stats["traced"]),
		"rivers_terminated": int(context.river_stats["terminated"]),
		"water_bodies": water.body_count(),
		"damaged_water_bodies": water.damaged_body_ids(grid).size(),
		"wet_cells": water.wet_cell_count(),
		"peaks": context.peaks.size(),
		"ranges": context.ridges.size(),
		"passes": context.passes.size(),
		"mean_temperature": ClimateField.mean_over_land(context, context.temperature),
		"mean_moisture": ClimateField.mean_over_land(context, context.moisture),
		"biome_shares": BiomeField.land_shares(context),
		"desert_lake_fraction": _desert_lake_fraction(context, water),
	}
	return metrics


## Conditions of §6 that the finished map broke, in the order they are listed
## there. An empty array is the verdict "accepted".
static func failures(recipe: MapRecipe, metrics: Dictionary) -> Array[String]:
	var broken: Array[String] = []
	var land_fraction := float(metrics["land_fraction"])
	if absf(land_fraction - recipe.land_fraction) > recipe.land_fraction_tolerance:
		broken.append("land fraction %.3f is more than %.3f away from %.3f" % [
			land_fraction, recipe.land_fraction_tolerance, recipe.land_fraction,
		])
	# The two height promises of §3.4, kept to a tolerance rather than to the digit.
	# The solver hits them exactly on the continuous field, and then quantisation,
	# the settling pass and river incision each move a column or two — so the
	# honest condition is a band, and a band that is checked beats a promise of
	# exactness that nothing enforced.
	var mean_error := absf(float(metrics["land_mean_height"]) - float(recipe.land_mean_height))
	if mean_error > recipe.land_mean_height_tolerance:
		broken.append("mean height of the plains %.2f is more than %.1f from %d" % [
			metrics["land_mean_height"], recipe.land_mean_height_tolerance, recipe.land_mean_height,
		])
	var max_error := absi(int(metrics["land_max_height"]) - recipe.land_max_height)
	if max_error > recipe.land_max_height_tolerance:
		broken.append("highest point %d is more than %d from %d" % [
			metrics["land_max_height"], recipe.land_max_height_tolerance, recipe.land_max_height,
		])
	var temperature_error := absf(float(metrics["mean_temperature"]) - recipe.land_mean_temperature)
	if temperature_error > recipe.land_mean_temperature_tolerance:
		broken.append("mean temperature %.2f is more than %.2f from %.2f" % [
			metrics["mean_temperature"], recipe.land_mean_temperature_tolerance, recipe.land_mean_temperature,
		])
	var moisture_error := absf(float(metrics["mean_moisture"]) - recipe.land_mean_moisture)
	if moisture_error > recipe.land_mean_moisture_tolerance:
		broken.append("mean moisture %.3f is more than %.3f from %.3f" % [
			metrics["mean_moisture"], recipe.land_mean_moisture_tolerance, recipe.land_mean_moisture,
		])
	if float(metrics["largest_land_component"]) < recipe.largest_land_component_min:
		broken.append("largest land component %.3f is under %.3f" % [
			metrics["largest_land_component"], recipe.largest_land_component_min,
		])
	if float(metrics["flat_fraction"]) < recipe.flat_fraction_min:
		broken.append("flat fraction %.3f is under %.3f — no room to build" % [
			metrics["flat_fraction"], recipe.flat_fraction_min,
		])
	if float(metrics["cliff_fraction"]) > recipe.cliff_fraction_max:
		broken.append("cliff fraction %.3f is over %.3f — the map is a maze of walls" % [
			metrics["cliff_fraction"], recipe.cliff_fraction_max,
		])
	if float(metrics["pedestrian_reach"]) < recipe.largest_land_component_min:
		broken.append("the walkable land is in pieces — the largest holds %.3f of it" % metrics["pedestrian_reach"])
	if float(metrics["cart_reach"]) < recipe.cart_reach_min:
		broken.append("carts reach %.3f of the walkable land, under %.3f" % [
			metrics["cart_reach"], recipe.cart_reach_min,
		])
	if not bool(metrics["walls_sealed"]):
		broken.append("a border wall is passable — the flood from the centre reached it")
	if float(metrics["rim_walkable"]) < recipe.rim_walkable_min:
		broken.append("only %.3f of the rim's foothills can be stood on, under %.3f — the edge is a wall, not a mountainside" % [
			metrics["rim_walkable"], recipe.rim_walkable_min,
		])
	if int(metrics["rivers_terminated"]) < int(metrics["rivers_traced"]):
		broken.append("%d of %d rivers end nowhere" % [
			int(metrics["rivers_traced"]) - int(metrics["rivers_terminated"]), metrics["rivers_traced"],
		])
	if int(metrics["damaged_water_bodies"]) > 0:
		broken.append("%d water bodies are not physically supported" % metrics["damaged_water_bodies"])
	if int(metrics["height_min"]) < TerrainGrid.MIN_HEIGHT or int(metrics["height_max"]) > TerrainGrid.MAX_HEIGHT:
		broken.append("heights left the legal range")
	if float(metrics["desert_lake_fraction"]) > recipe.desert_lake_fraction_max:
		broken.append("%.3f of the desert stands under a lake, over %.3f" % [
			metrics["desert_lake_fraction"], recipe.desert_lake_fraction_max,
		])
	return broken


## Share of the desert that stands under a LAKE (§11.1.3) — the measurable half of
## "an arid map has little water". Rivers and the sea are deliberately not counted:
## a river crossing a desert brought its water from where it rained, and a coastal
## desert is a real place. A pond in the dunes is neither.
static func _desert_lake_fraction(context: GenerationContext, water: WaterGrid) -> float:
	if context.biomes.size() != context.cell_count:
		return 0.0
	var desert := BiomeCatalog.index_of(BiomeCatalog.DESERT)
	var cells := 0
	var wet := 0
	for index in context.cell_count:
		if context.border_locked[index] != 0 or int(context.biomes[index]) != desert:
			continue
		cells += 1
		var body := water.body_at(context.cell_of_index(index))
		if body != null and body.type == WaterBody.Type.LAKE:
			wet += 1
	if cells == 0:
		return 0.0
	return float(wet) / float(cells)


static func _max_land_height(grid: TerrainGrid, land: Array[Vector2i]) -> int:
	var highest := TerrainGrid.MIN_HEIGHT
	for cell: Vector2i in land:
		highest = maxi(highest, grid.height_of(cell))
	return highest


## The share of land-to-land boundaries that ended up a bare vertical face. A
## cliff is a normal outcome, a board made of them is not — which is why this is a
## fraction with a ceiling and not a count.
static func _cliff_fraction(field: NavTerrainField, land: Array[Vector2i], land_index: Dictionary) -> float:
	if field == null:
		return 0.0
	var boundaries := 0
	var cliffs := 0
	for cell: Vector2i in land:
		# East and south visit every undirected orthogonal boundary exactly once.
		# The published edge class is the geometry, including a ramp on only one
		# side of a cell; a per-cell descriptor cannot answer this question.
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var neighbour := cell + offset
			if not land_index.has(neighbour):
				continue
			boundaries += 1
			if field.edge_class(cell, neighbour) == NavTerrainField.CLASS_CLIFF:
				cliffs += 1
	return 0.0 if boundaries == 0 else float(cliffs) / float(boundaries)


static func _largest_component_share(grid: TerrainGrid, land: Array[Vector2i], land_index: Dictionary) -> float:
	if land.is_empty():
		return 0.0
	var seen: Dictionary = {}
	var largest := 0
	for start: Vector2i in land:
		if seen.has(start):
			continue
		seen[start] = true
		var queue: Array[Vector2i] = [start]
		var head := 0
		while head < queue.size():
			var cell: Vector2i = queue[head]
			head += 1
			for offset: Vector2i in NEIGHBOURS:
				var neighbour := cell + offset
				if seen.has(neighbour) or not land_index.has(neighbour):
					continue
				seen[neighbour] = true
				queue.append(neighbour)
		largest = maxi(largest, queue.size())
	return float(largest) / float(land.size())


## How much of the WALKABLE land is one piece, over the published navigation
## field. The denominator is deliberately the walkable land and not all of it: on
## a mountainous map most of a range is a stone flank at the angle of repose,
## which is a `pre_cliff` and impassable on purpose (§3.5 — that is what makes a
## pass a game requirement). Measuring against all land would fail every map with
## real mountains in it while saying nothing about the question §6 actually asks:
## can everything a walker CAN stand on be reached from everything else.
static func _reach_share(nav: NavGrid, land: Array[Vector2i], profile: StringName) -> float:
	if land.is_empty() or not nav.has_terrain_field():
		return 0.0
	var walkable: Dictionary = {}
	for cell: Vector2i in land:
		if nav.is_walkable(cell, profile):
			walkable[cell] = true
	if walkable.is_empty():
		return 0.0
	var seen: Dictionary = {}
	var largest := 0
	for start: Vector2i in walkable:
		if seen.has(start):
			continue
		seen[start] = true
		var queue: Array[Vector2i] = [start]
		var head := 0
		while head < queue.size():
			var cell: Vector2i = queue[head]
			head += 1
			for direction in NavTerrainField.DIRECTION_COUNT:
				var neighbour: Vector2i = cell + NavTerrainField.DIRECTION_OFFSETS[direction]
				if seen.has(neighbour) or not walkable.has(neighbour):
					continue
				if not nav.is_edge_passable(cell, neighbour, profile):
					continue
				seen[neighbour] = true
				queue.append(neighbour)
		largest = maxi(largest, queue.size())
	return float(largest) / float(walkable.size())


## The other half of the same question: how much of the land a walker can stand
## on at all. Reported, never a pass/fail — a high-alpine recipe is allowed to be
## mostly cliff, and `flat_fraction_min` is the condition that guards buildable
## ground.
static func _walkable_share(nav: NavGrid, land: Array[Vector2i], profile: StringName) -> float:
	if land.is_empty() or not nav.has_terrain_field():
		return 0.0
	var walkable := 0
	for cell: Vector2i in land:
		if nav.is_walkable(cell, profile):
			walkable += 1
	return float(walkable) / float(land.size())


## §3.2's promise, checked instead of assumed: a flood from the centre of the
## board must never reach a column the border stage raised as a `mountain_wall`.
##
## A `plateau` side is excluded. It is locked ground like a wall — frame, not the
## map — but the recipe asked for a shelf, and a shelf the author cannot walk onto
## is a wall spelled differently. Only the side that promised to be impassable is
## held to it.
static func _walls_sealed(context: GenerationContext, grid: TerrainGrid, nav: NavGrid) -> bool:
	var has_wall := false
	for index in context.cell_count:
		if context.border_wall[index] != 0:
			has_wall = true
			break
	if not has_wall or not nav.has_terrain_field():
		return true
	var found: Variant = _nearest_walkable(grid, nav, Vector2i(0, 0))
	if found == null:
		return true
	var start: Vector2i = found
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if context.contains(cell.x, cell.y) and context.border_wall[context.cell_index(cell)] != 0:
			return false
		for direction in NavTerrainField.DIRECTION_COUNT:
			var neighbour: Vector2i = cell + NavTerrainField.DIRECTION_OFFSETS[direction]
			if seen.has(neighbour) or not grid.is_inside(neighbour):
				continue
			if not nav.is_walkable(neighbour, &"pedestrian") or not nav.is_edge_passable(cell, neighbour, &"pedestrian"):
				continue
			seen[neighbour] = true
			queue.append(neighbour)
	return true


## The half of §3.2 that "impassable" says nothing about: how much of the rim the
## player can actually walk on.
##
## Measured over the rim's foothills INSIDE the seal, because those are the ones
## that are in the map at all — the crest and its outer face are scenery, and
## scoring them would let a sheer inner face hide behind a gentle outer one. A
## slab of a border, the shape this design replaced, scores 0 here: every column
## of it was either wall or frame.
static func _rim_walkable(context: GenerationContext, nav: NavGrid) -> float:
	if not nav.has_terrain_field():
		return 0.0
	var cells := 0
	var walkable := 0
	for index in context.cell_count:
		if context.border_rim[index] == 0 or context.border_locked[index] != 0:
			continue
		if context.is_land[index] == 0:
			continue
		cells += 1
		if nav.is_walkable(context.cell_of_index(index), &"pedestrian"):
			walkable += 1
	if cells == 0:
		return 1.0
	return float(walkable) / float(cells)


## How ragged the foot of the rim is, in cells: the spread of the depth the
## mountains reach inland, measured along every walled side.
##
## The foot and not the frame boundary, because the foot is what anyone standing
## in the map can see. The frame ends at the seal contour, which is halfway up the
## rim and behind it — a number about that line would describe geometry nobody
## looks at. A band of fixed thickness, the shape §3.2 stopped asking for, scores
## 0 either way.
static func _rim_edge_spread(context: GenerationContext) -> float:
	var depths := PackedFloat32Array()
	var low := context.min_coordinate()
	var high := context.max_coordinate()
	for side_index in MapRecipe.SIDES.size():
		var side: StringName = MapRecipe.SIDES[side_index]
		if context.recipe.border_kind(side) != MapRecipe.BORDER_MOUNTAIN_WALL:
			continue
		for position in range(low, high + 1):
			# Corners belong to both sides, and a column inside the neighbouring
			# side's rim would be counted as this side's frame running the whole
			# depth of the board. Measured along a four-walled basin that alone
			# reported a spread of 29 cells on a rim eight deep.
			if _inside_perpendicular_rim(context, side_index, position, low, high):
				continue
			var depth := 0
			for step in range(0, high - low + 1):
				var cell := _side_cell(side_index, position, step, low, high)
				if context.border_rim[context.cell_index(cell)] == 0:
					break
				depth = step + 1
			depths.append(float(depth))
	if depths.size() < 2:
		return 0.0
	var mean := 0.0
	for value: float in depths:
		mean += value
	mean /= float(depths.size())
	var variance := 0.0
	for value: float in depths:
		variance += (value - mean) * (value - mean)
	return sqrt(variance / float(depths.size()))


## Whether a position along one side already stands inside the rim of a side at
## right angles to it.
static func _inside_perpendicular_rim(context: GenerationContext, side_index: int, position: int, low: int, high: int) -> bool:
	var crossing: Array[int] = ([1, 3] as Array[int]) if side_index == 0 or side_index == 2 else ([0, 2] as Array[int])
	for other: int in crossing:
		var side: StringName = MapRecipe.SIDES[other]
		if context.recipe.border_kind(side) != MapRecipe.BORDER_MOUNTAIN_WALL:
			continue
		var reach := context.recipe.border_reach(side)
		var distance := high - position if other == 1 or other == 2 else position - low
		if distance < reach[1]:
			return true
	return false


## The cell `step` columns inland from `side`, at `position` along it.
static func _side_cell(side_index: int, position: int, step: int, low: int, high: int) -> Vector2i:
	match side_index:
		0:
			return Vector2i(position, low + step)
		1:
			return Vector2i(high - step, position)
		2:
			return Vector2i(position, high - step)
		_:
			return Vector2i(low + step, position)


static func _nearest_walkable(grid: TerrainGrid, nav: NavGrid, around: Vector2i) -> Variant:
	var reach := grid.board_cells / 2
	for radius in range(0, reach):
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius:
					continue
				var cell := around + Vector2i(dx, dz)
				if grid.is_inside(cell) and nav.is_walkable(cell, &"pedestrian"):
					return cell
	return null
