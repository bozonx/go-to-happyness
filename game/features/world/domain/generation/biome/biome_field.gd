class_name BiomeField
extends RefCounted

## Layer 3: which biome every column belongs to
## (procedural_map_generation.md §11.2).
##
## The classification is a mask over the finished board, computed once and then
## baked — into materials today, into vegetation and fauna when layers 4 and 5
## exist. Nothing reads it at runtime.
##
## ## Every column has a biome, including the wet ones
##
## Water is a LAYER, not a biome. A lagoon on a desert coast is desert with water
## over it, and the map already has exactly one owner for "where the water is"
## (`WaterGrid`, AGENTS.md). Giving the sea a biome id of its own would create a
## second one, and it would also destroy the only honest way to ask the question
## the recipe cares about — "how much standing water is there in the desert?" —
## because the desert cells would have stopped being desert the moment they got
## wet.
##
## ## Two rules come before the climate, and both are about ground, not air
##
## 1. **Alpine.** Cold ground that is cold BECAUSE IT IS HIGH is bare rock, not
##    tundra: same temperature, completely different place. The rule is a height
##    one, measured against the range this attempt actually produced, so a recipe
##    of gentle hills and one of real alps put their rock in the same visual
##    place without a second parameter.
## 2. **Wetland.** Flat, low, wet ground beside standing water is a marsh whatever
##    the latitude says. This is drainage, and drainage beats climate locally —
##    the shoulder ten metres above the same hollow is ordinary meadow.
##
## Everything else is the Whittaker envelope of `BiomeCatalog`: nearest rectangle
## in (temperature, moisture), no decision tree.

const STAGE := &"biomes"

## A column is alpine when it stands in the top share of the height range AND is
## below this temperature. Both halves matter: the share alone would make the
## highest dune in a desert into a rock face, and the temperature alone would make
## the whole northern edge of a cold map alpine.
const ALPINE_HEIGHT_SHARE := 0.55
const ALPINE_TEMPERATURE := 4.0

## A wetland is wet ground with nowhere to drain: no more than this far above the
## water beside it, no more than this many cells from it, flat, and wetter than
## the threshold.
const WETLAND_MOISTURE := 0.62
const WETLAND_CELLS := 4
const WETLAND_RISE := 2


static func build(context: GenerationContext) -> void:
	context.biomes.resize(context.cell_count)
	var alpine_height := _alpine_height(context)
	var nearest_water := _nearest_standing_water(context)
	var wet_near: PackedInt32Array = nearest_water[0]
	var wet_level: PackedInt32Array = nearest_water[1]

	var counts := PackedInt32Array()
	counts.resize(BiomeCatalog.count())
	for index in context.cell_count:
		var biome_index := _classify(context, index, alpine_height, wet_near, wet_level)
		context.biomes[index] = biome_index
		counts[biome_index] += 1

	context.note("biomes: %s" % ", ".join(_shares_summary(counts, context.cell_count)))


## Share of the LAND inside the frame per biome id. The population is the same one
## every other land metric uses (§10.1.5) — a figure measured over the whole board
## would be mostly "whatever the sea floor is" and would move whenever the coast
## did.
static func land_shares(context: GenerationContext) -> Dictionary:
	var counts := PackedInt32Array()
	counts.resize(BiomeCatalog.count())
	var land := 0
	for index in context.cell_count:
		if context.border_locked[index] != 0 or context.is_land[index] == 0:
			continue
		counts[int(context.biomes[index])] += 1
		land += 1
	var shares: Dictionary = {}
	for biome_index in counts.size():
		if counts[biome_index] == 0:
			continue
		shares[String(BiomeCatalog.id_of_index(biome_index))] = float(counts[biome_index]) / float(maxi(land, 1))
	return shares


# --- Classification -----------------------------------------------------------

static func _classify(
	context: GenerationContext, index: int, alpine_height: int,
	wet_near: PackedInt32Array, wet_level: PackedInt32Array,
) -> int:
	var temperature := context.temperature[index]
	var moisture := context.moisture[index]
	if context.heights[index] >= alpine_height and temperature <= ALPINE_TEMPERATURE:
		return BiomeCatalog.index_of(BiomeCatalog.ALPINE)
	if _is_wetland(context, index, wet_near, wet_level, temperature, moisture):
		return BiomeCatalog.index_of(BiomeCatalog.WETLAND)
	return BiomeCatalog.classify_climate(temperature, moisture)


## A marsh needs all four of: rain, a neighbour that holds water, no fall to it,
## and ground level enough that the water does not run off. Frozen ground is
## excluded — a tundra bog is a real thing, but at these temperatures the biome
## that describes it is tundra, and mud is not what is on top of it.
static func _is_wetland(
	context: GenerationContext, index: int,
	wet_near: PackedInt32Array, wet_level: PackedInt32Array,
	temperature: float, moisture: float,
) -> bool:
	if context.is_land[index] == 0 or moisture < WETLAND_MOISTURE or temperature < 1.0:
		return false
	var distance := wet_near[index]
	if distance <= 0 or distance > WETLAND_CELLS:
		return false
	var cell := context.cell_of_index(index)
	var height := context.heights[index]
	var lowest := height
	var highest := height
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbour := cell + offset
		if not context.contains(neighbour.x, neighbour.y):
			continue
		var neighbour_height := context.heights[context.cell_index(neighbour)]
		lowest = mini(lowest, neighbour_height)
		highest = maxi(highest, neighbour_height)
	return highest - lowest <= 1 and height - wet_level[index] <= WETLAND_RISE


# --- Fields -------------------------------------------------------------------

## The height at which the top `ALPINE_HEIGHT_SHARE` of this attempt's range
## begins. Taken from the RESULT, never from the recipe: the recipe's
## `land_max_height` is a target the verdict checks, and the biome mask has to
## describe the board that exists even on an attempt that missed it.
static func _alpine_height(context: GenerationContext) -> int:
	var highest := context.recipe.ocean_level
	for index in context.cell_count:
		if context.border_locked[index] != 0:
			continue
		highest = maxi(highest, context.heights[index])
	var span := maxi(highest - context.recipe.ocean_level, 1)
	return context.recipe.ocean_level + maxi(roundi(float(span) * ALPINE_HEIGHT_SHARE), 4)


## Chebyshev distance to the nearest column the water plan will cover, and the
## surface level of that water, capped just past the wetland band. Two linear
## sweeps rather than a flood fill, the same way the painter measures its beach —
## and both answers ride the same sweep, because "how far to the water" and "how
## high is that water" are the same question asked about the same cell.
static func _nearest_standing_water(context: GenerationContext) -> Array:
	var limit := WETLAND_CELLS + 1
	var distance := PackedInt32Array()
	var level := PackedInt32Array()
	distance.resize(context.cell_count)
	level.resize(context.cell_count)
	distance.fill(limit)
	level.fill(context.recipe.ocean_level)
	for index in context.cell_count:
		if context.heights[index] <= context.recipe.ocean_level:
			distance[index] = 0
	for entry: Dictionary in context.water_plan:
		var surface := int(entry["level"])
		for cell: Vector2i in (entry["cells"] as Array):
			if not context.contains(cell.x, cell.y):
				continue
			var index := context.cell_index(cell)
			distance[index] = 0
			level[index] = surface
	var low := context.min_coordinate()
	var high := context.max_coordinate()
	var span := high - low + 1
	for sweep in 2:
		var forward := sweep == 0
		for step_z in span:
			var z := (low + step_z) if forward else (high - step_z)
			for step_x in span:
				var x := (low + step_x) if forward else (high - step_x)
				var index := context.index_of(x, z)
				for offset_z in [-1, 0, 1]:
					for offset_x in [-1, 0, 1]:
						if not context.contains(x + offset_x, z + offset_z):
							continue
						var other := context.index_of(x + offset_x, z + offset_z)
						var candidate := mini(distance[other] + 1, limit)
						if candidate >= distance[index]:
							continue
						distance[index] = candidate
						level[index] = level[other]
	return [distance, level]


static func _shares_summary(counts: PackedInt32Array, total: int) -> Array[String]:
	var summary: Array[String] = []
	for biome_index in counts.size():
		if counts[biome_index] == 0:
			continue
		summary.append("%s %d%%" % [
			BiomeCatalog.id_of_index(biome_index),
			roundi(float(counts[biome_index]) * 100.0 / float(maxi(total, 1))),
		])
	return summary
