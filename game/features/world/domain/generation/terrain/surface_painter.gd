class_name SurfacePainter
extends RefCounted

## Stage 14: what the finished ground is made of
## (procedural_map_generation.md §5.2, layer 3; terrain_materials.md §2).
##
## Until this stage existed the generator produced a board of solid `stone`,
## because the recipe carried exactly one material — the one the repose pass
## borrowed its angle from — and the commit wrote it into every column. That is
## why `elevation.repose_override` and "what the map is made of" are now two
## different fields: one is a debug knob for comparing shapes, the other is
## content.
##
## ## It runs last, and reads only finished ground
##
## Material decides the angle of repose, so painting BEFORE the shape is settled
## would mean the repose pass sees a different angle per column and the shape it
## produces depends on a decision that was itself made from the shape. The knot is
## cut the same way the design cuts it (§2.3): the whole board settles at one
## angle, and the surface is chosen afterwards from ground nothing will move
## again. The one obligation that leaves is the last rule below.
##
## ## The rules, in the order they are asked
##
## | Condition | Material |
## | :-- | :-- |
## | under planned water, shallow | `sand` |
## | under planned water, deep | `mud` |
## | in a river channel | `gravel` |
## | a face: two steps or more to a neighbour | `stone` |
## | within a few cells of the water line, gentle | `sand` |
## | high ground | `stone`, `gravel` just below the rock line |
## | the rest | `grass`, drifting to `dirt` and `grass_tall` by noise |
##
## **A material may never be painted where it cannot stand.** Sand holds half a
## step per cell; painting it on a column that drops a full step to its neighbour
## authors ground the cascade would immediately collapse, and the editor refuses
## exactly that by hand (`TerrainService.paint_material`). So every candidate is
## checked against the local drop and falls back along `FALLBACKS` until one
## holds. Stone holds four steps and terminates every chain — including on the
## authored border walls, which are exempt from repose entirely (§3.2 of the
## generation doc) and are steeper than anything in the catalog. Rock is the
## honest answer there; sand would be a promise the ground cannot keep.

## Cells from the water line that can still be beach, and how deep water has to be
## before its bed stops being sand.
const BEACH_CELLS := 3
const SHALLOW_STEPS := 2

## Where a candidate goes when the ground is too steep for it. Every chain ends at
## `stone`, which holds more than any legal single-cell drop.
const FALLBACKS: Dictionary = {
	TerrainMaterialCatalog.SAND: TerrainMaterialCatalog.GRAVEL,
	TerrainMaterialCatalog.MUD: TerrainMaterialCatalog.DIRT,
	TerrainMaterialCatalog.GRAVEL: TerrainMaterialCatalog.DIRT,
	TerrainMaterialCatalog.DIRT: TerrainMaterialCatalog.STONE,
	TerrainMaterialCatalog.GRASS: TerrainMaterialCatalog.DIRT,
	TerrainMaterialCatalog.GRASS_TALL: TerrainMaterialCatalog.GRASS,
	TerrainMaterialCatalog.CLAY: TerrainMaterialCatalog.DIRT,
}

## Metres of world per repetition of the two decision fields. Coarse on purpose:
## a per-cell random choice produces confetti, and the point of a variant is a
## patch of meadow, not a speckle (`terrain_materials.md` §4).
const BIOME_NOISE_PERIOD := 34.0
const VARIANT_NOISE_PERIOD := 19.0


static func apply(context: GenerationContext) -> void:
	context.materials.resize(context.cell_count)
	context.details.resize(context.cell_count)
	var base_index := TerrainMaterialCatalog.index_of(context.recipe.base_material)
	if base_index < 0:
		base_index = TerrainMaterialCatalog.DEFAULT_INDEX
	context.materials.fill(base_index)
	context.details.fill(TerrainDetailCodec.DEFAULT_DETAIL)
	if not context.recipe.paint_surface:
		return

	var water_depth := _water_depth_field(context)
	var shore := _distance_to_water(context, water_depth)
	var biome := _noise(context.seeds.stream_seed(&"surface_biome"), BIOME_NOISE_PERIOD)
	var variant_noise := _noise(context.seeds.stream_seed(&"surface_variant"), VARIANT_NOISE_PERIOD)
	var rock_line := _rock_line(context)

	var counts: Dictionary = {}
	for index in context.cell_count:
		var cell := context.cell_of_index(index)
		var candidate := _candidate(context, index, cell, water_depth, shore, biome, rock_line)
		var material_index := _settle(candidate, _local_drop(context, cell))
		context.materials[index] = material_index
		context.details[index] = TerrainDetailCodec.pack(
			_variant_of(material_index, cell, variant_noise), 0, 0,
		)
		var id := TerrainMaterialCatalog.id_of_index(material_index)
		counts[id] = int(counts.get(id, 0)) + 1

	var summary: Array[String] = []
	for id: StringName in counts:
		summary.append("%s %d%%" % [id, roundi(float(counts[id]) * 100.0 / float(context.cell_count))])
	summary.sort()
	context.note("surface: %s" % ", ".join(summary))


## Re-checks the finished grid and downgrades any column whose material can no
## longer hold it. Returns how many were moved.
##
## This is not a duplicate of the check `apply` already does — it is the same
## check against different ground. Slope assignment runs AFTER the commit and
## reshapes columns (`TerrainGenerationService._assign_slopes`), and the
## connectivity repair may press a saddle and re-commit on top of that. Both move
## height under a surface that was chosen from the heights the pipeline produced,
## so the guarantee "sand is never painted on a cliff" is only true if it is
## re-established once the ground has actually stopped moving.
static func settle_grid(grid: TerrainGrid) -> int:
	if grid == null:
		return 0
	var moved := 0
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			var current := grid.material_index_at(cell)
			var settled := _settle(TerrainMaterialCatalog.id_of_index(current), _grid_drop(grid, cell))
			if settled == current:
				continue
			grid.set_material_index(cell, settled)
			grid.set_variant(cell, TerrainMaterialVariants.clamp_variant(settled, grid.variant_at(cell)))
			moved += 1
	return moved


static func _grid_drop(grid: TerrainGrid, cell: Vector2i) -> int:
	var own := grid.height_of(cell)
	var drop := 0
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbour := cell + offset
		if grid.is_inside(neighbour):
			drop = maxi(drop, absi(grid.height_of(neighbour) - own))
	return drop


# --- Choice -------------------------------------------------------------------

static func _candidate(
	context: GenerationContext, index: int, cell: Vector2i,
	water_depth: PackedInt32Array, shore: PackedInt32Array,
	biome: FastNoiseLite, rock_line: int,
) -> StringName:
	if water_depth[index] > 0:
		# The bed the author would have painted under the lake, so draining it later
		# leaves a beach or a silt flat rather than whatever the land happened to be
		# (`terrain_materials.md` §2.5: there is no `lakebed` material).
		if context.river_cells.has(cell):
			return TerrainMaterialCatalog.GRAVEL
		return TerrainMaterialCatalog.SAND if water_depth[index] <= SHALLOW_STEPS else TerrainMaterialCatalog.MUD
	if context.river_cells.has(cell):
		return TerrainMaterialCatalog.GRAVEL

	var drop := _local_drop(context, cell)
	# A column that drops two steps or more to a neighbour is a face, and a face is
	# rock: it is the only thing that stands there without a retaining structure,
	# and the auto-rock kind under it (§3) then matches what is on top.
	if drop >= 2:
		return TerrainMaterialCatalog.STONE

	if shore[index] <= BEACH_CELLS and drop <= 1:
		return TerrainMaterialCatalog.SAND

	var height := context.heights[index]
	if height >= rock_line:
		return TerrainMaterialCatalog.STONE
	if height >= rock_line - 3:
		return TerrainMaterialCatalog.GRAVEL

	# Everything else is ordinary land, and which ordinary land it is comes from one
	# low-frequency field: meadow where it is high, bare earth where it is low.
	var wet := biome.get_noise_2d(float(cell.x), float(cell.y))
	if wet > 0.25:
		return TerrainMaterialCatalog.GRASS_TALL
	if wet < -0.35:
		return TerrainMaterialCatalog.DIRT
	return TerrainMaterialCatalog.GRASS


## Walks the fallback chain until the material can hold the drop this column
## actually has. Returns an index, never an id: the caller stores bytes.
static func _settle(candidate: StringName, drop: int) -> int:
	var id := candidate
	for _step in FALLBACKS.size() + 1:
		var index := TerrainMaterialCatalog.index_of(id)
		if index < 0:
			break
		if TerrainMaterialCatalog.holds_height_difference(index, drop):
			return index
		if not FALLBACKS.has(id):
			break
		id = FALLBACKS[id]
	return TerrainMaterialCatalog.index_of(TerrainMaterialCatalog.STONE)


static func _variant_of(material_index: int, cell: Vector2i, noise: FastNoiseLite) -> int:
	var count := TerrainMaterialVariants.variant_count(material_index)
	if count <= 1:
		return 0
	var value := noise.get_noise_2d(float(cell.x), float(cell.y)) * 0.5 + 0.5
	return clampi(int(value * float(count)), 0, count - 1)


# --- Fields -------------------------------------------------------------------

## Depth in steps of the water the plan will place over each column. Read from the
## plan rather than from the finished `WaterGrid`, because the grid does not exist
## yet at this point in the pipeline — and the plan is what will be written.
static func _water_depth_field(context: GenerationContext) -> PackedInt32Array:
	var depth := PackedInt32Array()
	depth.resize(context.cell_count)
	for entry: Dictionary in context.water_plan:
		var level := int(entry["level"])
		for cell: Vector2i in (entry["cells"] as Array):
			if not context.contains(cell.x, cell.y):
				continue
			var index := context.cell_index(cell)
			depth[index] = maxi(depth[index], level - context.heights[index])
	return depth


## Chebyshev distance to the nearest wet column, in cells, capped just past the
## beach so the sweep stays two linear passes instead of a flood fill.
static func _distance_to_water(context: GenerationContext, water_depth: PackedInt32Array) -> PackedInt32Array:
	var limit := BEACH_CELLS + 1
	var distance := PackedInt32Array()
	distance.resize(context.cell_count)
	for index in context.cell_count:
		distance[index] = 0 if water_depth[index] > 0 else limit
	var minimum := context.min_coordinate()
	var maximum := context.max_coordinate()
	for _sweep in 2:
		var forward := _sweep == 0
		for step_z in range(maximum - minimum + 1):
			var z := (minimum + step_z) if forward else (maximum - step_z)
			for step_x in range(maximum - minimum + 1):
				var x := (minimum + step_x) if forward else (maximum - step_x)
				var index := context.index_of(x, z)
				var best := distance[index]
				for offset_z in [-1, 0, 1]:
					for offset_x in [-1, 0, 1]:
						if not context.contains(x + offset_x, z + offset_z):
							continue
						best = mini(best, distance[context.index_of(x + offset_x, z + offset_z)] + 1)
				distance[index] = mini(best, limit)
	return distance


## Height above which the map is bare rock, as a share of the range this attempt
## actually produced. Taken from the result rather than from the recipe: a recipe
## asking for gentle plains and one asking for alps would otherwise need two
## different constants to put snow-free rock in the same visual place.
static func _rock_line(context: GenerationContext) -> int:
	var highest := context.recipe.ocean_level
	for index in context.cell_count:
		highest = maxi(highest, context.heights[index])
	var span := maxi(highest - context.recipe.ocean_level, 1)
	return context.recipe.ocean_level + maxi(roundi(float(span) * 0.62), 4)


## Largest orthogonal height difference to a neighbour, in steps — the number a
## material's angle of repose has to hold (`terrain_materials.md` §2).
static func _local_drop(context: GenerationContext, cell: Vector2i) -> int:
	var own := context.heights[context.cell_index(cell)]
	var drop := 0
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbour := cell + offset
		if not context.contains(neighbour.x, neighbour.y):
			continue
		drop = maxi(drop, absi(context.heights[context.cell_index(neighbour)] - own))
	return drop


static func _noise(seed_value: int, period: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / maxf(period, 1.0)
	return noise
