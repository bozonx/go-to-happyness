class_name SurfacePainter
extends RefCounted

## Stage 14: what the finished ground is made of
## (procedural_map_generation.md §11.2; terrain_materials.md §2).
##
## Until this stage existed the generator produced a board of solid `stone`,
## because the recipe carried exactly one material — the one the repose pass
## borrowed its angle from — and the commit wrote it into every column. That is
## why `elevation.repose_override` and "what the map is made of" are now two
## different fields: one is a debug knob for comparing shapes, the other is
## content.
##
## ## The biome decides, the ground vetoes
##
## The painter itself knows almost nothing about climate. It asks the biome mask
## what belongs on a column (`BiomeCatalog` palettes, resolved by a low-frequency
## field so a meadow is patches rather than confetti) and then applies the rules
## that no biome may override, because they are about the SHAPE of the column and
## not about the weather over it:
##
## | Condition | Material |
## | :-- | :-- |
## | under planned water | the biome's bed — shallow, deep or channel |
## | in a river channel | the biome's channel bed |
## | a face: two steps or more to a neighbour | `stone` |
## | within a few cells of the water line, gentle | the biome's beach |
## | anything else | a weighted draw from the biome's palette |
##
## There used to be a "rock line" here — above a share of the height range the
## ground turned to stone. It is gone, and its absence is the point: a summit is
## bare because the lapse rate makes it cold and the cold makes it `alpine`
## (`BiomeField`), which is a palette of rock. One mechanism, measurable in °C,
## instead of a constant that had to be re-tuned for every kind of map.
##
## ## Snow is a state, and it comes from the temperature
##
## Permanent snow is written into the detail byte, never painted as a material
## (`terrain_materials.md` §2.5 — a material change would run the cascade over
## half the board twice a year). How much of it lies on a column is a reading of
## that column's temperature, so a polar cap and the top of a single high peak on
## a warm map are the same rule.
##
## ## A material may never be painted where it cannot stand
##
## Sand holds half a step per cell; painting it on a column that drops a full step
## to its neighbour authors ground the cascade would immediately collapse, and the
## editor refuses exactly that by hand (`TerrainService.paint_material`). So every
## candidate is checked against the local drop and falls back along `FALLBACKS`
## until one holds. Stone holds four steps and terminates every chain — including
## on the authored border walls, which are exempt from repose entirely (§3.2) and
## are steeper than anything in the catalog. Rock is the honest answer there; sand
## would be a promise the ground cannot keep.

## Cells from the water line that can still be beach, and how deep water has to be
## before its bed stops being the shallow kind.
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
## a per-cell random choice produces confetti, and the point of a palette draw is
## a patch of meadow, not a speckle (`terrain_materials.md` §4).
const PALETTE_NOISE_PERIOD := 34.0
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
	var palette_noise := _noise(context.seeds.stream_seed(&"surface_palette"), PALETTE_NOISE_PERIOD)
	var variant_noise := _noise(context.seeds.stream_seed(&"surface_variant"), VARIANT_NOISE_PERIOD)
	# Resolved once for the whole board: a palette is a pair of small arrays, and
	# building it per column would allocate two of them 16 384 times to answer a
	# question with a dozen possible answers.
	var palettes: Array = []
	for biome_index in BiomeCatalog.count():
		palettes.append(BiomeCatalog.palette_of_index(biome_index))

	var counts: Dictionary = {}
	for index in context.cell_count:
		var cell := context.cell_of_index(index)
		var candidate := _candidate(context, index, cell, water_depth, shore, palette_noise, palettes)
		var material_index := _settle(candidate, _local_drop(context, cell))
		context.materials[index] = material_index
		# Snow does not lie on open water: a frozen lake is the water layer's
		# business and a seasonal state of a body, not a surface of the bed (§9.6
		# of the terrain document).
		var snow := 0 if water_depth[index] > 0 else ClimateField.snow_level(context.temperature[index])
		context.details[index] = TerrainDetailCodec.pack(
			_variant_of(material_index, cell, variant_noise), 0, snow,
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
			# A ramp is SHAPED ground, and repose is about ground that slumps. The
			# assigner lifts the cells under the near links of a chain — that is what
			# building a slope up a bank is — and reading those lifted columns as a
			# face turned every ramp the generator laid, and the ground around it,
			# into stone. A grass hillside is the ordinary result of a grass cascade;
			# it is not a cliff just because it climbs.
			if grid.is_ramp_cell(cell):
				continue
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
			drop = maxi(drop, own - grid.height_of(neighbour))
	return drop


# --- Choice -------------------------------------------------------------------

static func _candidate(
	context: GenerationContext, index: int, cell: Vector2i,
	water_depth: PackedInt32Array, shore: PackedInt32Array,
	palette: FastNoiseLite, palettes: Array,
) -> StringName:
	var biome_index := context.biome_at_index(index)
	var channel := context.river_cells.has(cell)
	if water_depth[index] > 0:
		# The bed the author would have painted under the lake, so draining it later
		# leaves a beach or a silt flat rather than whatever the land happened to be
		# (`terrain_materials.md` §2.5: there is no `lakebed` material).
		return BiomeCatalog.bed_material_of_index(biome_index, water_depth[index], channel, SHALLOW_STEPS)
	if channel:
		return BiomeCatalog.bed_material_of_index(biome_index, 0, true, SHALLOW_STEPS)

	var drop := _local_drop(context, cell)
	# A column that drops two steps or more to a neighbour is a face, and a face is
	# rock: it is the only thing that stands there without a retaining structure,
	# and the auto-rock kind under it (§3) then matches what is on top.
	if drop >= 2:
		return TerrainMaterialCatalog.STONE

	if shore[index] <= BEACH_CELLS and drop <= 1:
		return BiomeCatalog.beach_material_of_index(biome_index)

	return _palette_draw(palettes[biome_index], cell, palette)


## One draw from the biome's palette, decided by a low-frequency field rather than
## by a hash of the cell. The field is what turns weights into geography: the same
## 55 % grass is a meadow with stands of tall grass in it instead of a grey average
## of the two.
static func _palette_draw(resolved: Array, cell: Vector2i, palette: FastNoiseLite) -> StringName:
	var ids: Array[StringName] = resolved[0]
	var thresholds: PackedFloat32Array = resolved[1]
	if ids.is_empty():
		return TerrainMaterialCatalog.DEFAULT_MATERIAL
	var value := clampf(palette.get_noise_2d(float(cell.x), float(cell.y)) * 0.5 + 0.5, 0.0, 0.9999)
	for slot in ids.size():
		if value < thresholds[slot]:
			return ids[slot]
	return ids[ids.size() - 1]


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


## How far this column drops AWAY to an orthogonal neighbour, in steps — the
## number its angle of repose has to hold (`terrain_materials.md` §2).
##
## Downwards only, and that is the fix to the second half of the stone problem.
## Measured as an absolute difference, a meadow at the foot of a rock face had to
## hold the face — so every mountain, every terrace and every river bank painted
## stone on BOTH of its sides. The ground that would slide is the ground on top of
## the drop; the flat below it holds nothing up.
static func _local_drop(context: GenerationContext, cell: Vector2i) -> int:
	var own := context.heights[context.cell_index(cell)]
	var drop := 0
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbour := cell + offset
		if not context.contains(neighbour.x, neighbour.y):
			continue
		drop = maxi(drop, own - context.heights[context.cell_index(neighbour)])
	return drop


static func _noise(seed_value: int, period: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / maxf(period, 1.0)
	return noise
