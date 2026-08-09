class_name TestMapGeneration
extends RefCounted

## Procedural map generation, stage 1 (design_docs/engine/procedural_map_generation.md §9).
##
## The tests never compare screenshots of noise. They check the promises the
## design doc makes about the RESULT: that a parameter named after a property of
## the map really is that property, that the same request produces the same
## buffers, that a river never runs uphill, that no lake hangs in the air and that
## a wall the recipe asked for cannot be walked around.

const BOARD := 64


static func run_all() -> void:
	_test_recipe_refuses_contradictions()
	_test_recipe_round_trips_through_json()
	_test_streams_are_independent_per_stage()
	_test_land_fraction_is_a_target_not_a_hope()
	_test_mean_and_max_height_are_met()
	_test_every_stored_height_is_a_legal_integer()
	_test_mountain_graph_has_the_requested_shape()
	_test_generation_is_reproducible()
	_test_slopes_never_leave_the_catalog()
	_test_rivers_run_downhill_and_reach_a_receiver()
	_test_water_bodies_are_supported()
	_test_border_wall_cannot_be_walked_around()
	_test_navigation_is_published_once()
	_test_surface_is_painted_and_always_stands()
	_test_surface_can_be_turned_off()
	_test_climate_means_are_targets()
	_test_rain_shadow_follows_the_wind()
	_test_biomes_cover_the_board_and_follow_the_climate()
	_test_surface_follows_the_biome()
	_test_arid_climate_holds_no_lakes()
	print("    [PASS] Map Generation Tests")


# --- Building blocks ---------------------------------------------------------

class Harness extends RefCounted:
	var grid := TerrainGrid.new()
	var water := WaterGrid.new()
	var terrain_service := TerrainService.new()
	var water_service := WaterService.new()
	var nav := NavGrid.new()
	var publisher := TerrainNavigationPublisher.new()
	var service := TerrainGenerationService.new()

	func _init() -> void:
		grid.configure(1.0, BOARD)
		water.configure(1.0, BOARD)
		terrain_service.configure(grid)
		water_service.configure(water, grid)
		nav.configure(1.0, BOARD)
		publisher.configure(grid, nav, terrain_service, water, water_service)
		service.configure(grid, water, terrain_service, water_service, publisher, nav)


static func _recipe(overrides: Dictionary = {}) -> MapRecipe:
	var source: Dictionary = {
		"kind": "map_generator",
		"id": "test_temperate",
		"board": {"size": BOARD},
		"border": {
			"north": {"kind": "ocean"},
			"west": {"kind": "ocean"},
			"east": {"kind": "mountain_wall", "height": 22, "thickness": 4},
			"south": {"kind": "mountain_wall", "height": 22, "thickness": 4},
			"ocean_level": -2,
		},
		"landmass": {"shape": "continent", "land_fraction": 0.62, "island_count": 2, "shelf_width": 3},
		"elevation": {
			"land_mean_height": 5, "land_max_height": 24,
			"hypsometry": "plains_with_peaks", "roughness": 0.3, "terrace_bias": 0.5,
		},
		"mountains": {
			"ranges": [{
				"count": 2, "length": 0.35, "orientation": 55, "orientation_jitter": 20,
				"peak_height": [16, 24], "peaks_per_range": 3,
				"flank_steepness": 0.7, "foothills": 6, "passes": 2,
			}],
			"solitary_peaks": {"count": 1, "height": [12, 18], "flank_steepness": 0.9},
		},
		"rivers": {"count": 2, "width": [1, 3], "meander": 0.5, "incision": 2, "source": "mountains", "tributaries": 1},
		"lakes": {"count": [1, 3], "size": [6, 300], "depth": [1, 6], "prefer": "basins"},
		"targets": {"flat_fraction_min": 0.2, "largest_land_component_min": 0.85, "cliff_fraction_max": 0.6},
	}
	for key: String in overrides:
		source[key] = overrides[key]
	return MapRecipe.from_dictionary(source)


static func _generated(seed_value: int = 12345, recipe: MapRecipe = null) -> Array:
	var harness := Harness.new()
	var used := recipe if recipe != null else _recipe()
	var result := harness.service.generate(used, seed_value)
	return [harness, result]


# --- Recipe ------------------------------------------------------------------

## §3.3: a request the preset cannot satisfy is refused with a reason, not
## clamped into something else. And it is refused BEFORE any expensive stage.
static func _test_recipe_refuses_contradictions() -> void:
	var inland := MapRecipe.from_dictionary({
		"board": {"size": BOARD},
		"landmass": {"shape": "inland"},
		"border": {"north": {"kind": "ocean"}},
		"mountains": {"ranges": []},
		"rivers": {"count": 0},
	})
	assert(not inland.is_valid(), "an inland shape may not have an ocean border")

	var archipelago := MapRecipe.from_dictionary({
		"board": {"size": BOARD},
		"landmass": {"shape": "archipelago", "land_fraction": 0.8},
		"mountains": {"ranges": []},
		"rivers": {"count": 0},
	})
	assert(not archipelago.is_valid(), "an archipelago is not 80 % land")

	var sourceless := MapRecipe.from_dictionary({
		"board": {"size": BOARD},
		"mountains": {"ranges": []},
		"rivers": {"count": 2, "source": "mountains"},
	})
	assert(not sourceless.is_valid(), "rivers cannot spring from mountains that do not exist")

	var odd := MapRecipe.from_dictionary({"board": {"size": 49}, "mountains": {"ranges": []}, "rivers": {"count": 0}})
	assert(not odd.is_valid(), "an odd board cannot be centred on the origin")

	assert(_recipe().is_valid(), "the reference recipe has to be accepted")


static func _test_recipe_round_trips_through_json() -> void:
	var original := _recipe()
	var text := JSON.stringify(original.to_dictionary())
	var reloaded := MapRecipe.from_dictionary(JSON.parse_string(text) as Dictionary)
	assert(reloaded.is_valid())
	assert(reloaded.board_size == original.board_size)
	assert(is_equal_approx(reloaded.land_fraction, original.land_fraction))
	assert(reloaded.land_max_height == original.land_max_height)
	assert(reloaded.mountain_ranges.size() == original.mountain_ranges.size())
	assert(reloaded.border_kind(&"east") == MapRecipe.BORDER_MOUNTAIN_WALL)
	assert(reloaded.border_thickness(&"east") == original.border_thickness(&"east"))


## §4.1: adding a stage must not move the ones before it, which is only true if
## every stage draws from its own stream.
static func _test_streams_are_independent_per_stage() -> void:
	var seeds := GenerationSeed.new(7)
	assert(seeds.stream_seed(&"landmass") != seeds.stream_seed(&"rivers"))
	assert(seeds.stream_seed(&"landmass") == GenerationSeed.new(7).stream_seed(&"landmass"))
	assert(seeds.derive(1).stream_seed(&"landmass") != seeds.stream_seed(&"landmass"))


# --- Solved targets -----------------------------------------------------------

## §5.3: `land_fraction` is a property of the finished map. Three seeds, one
## answer — that is the whole difference between solving and thresholding.
static func _test_land_fraction_is_a_target_not_a_hope() -> void:
	for seed_value: int in [11, 4242, 90210]:
		var run := _generated(seed_value)
		var report: GenerationReport = (run[1] as GenerationResult).report
		var measured := float(report.metrics["land_fraction"])
		assert(absf(measured - 0.62) <= 0.04, "seed %d gave %.3f of land" % [seed_value, measured])


static func _test_mean_and_max_height_are_met() -> void:
	var run := _generated(2024)
	var report: GenerationReport = (run[1] as GenerationResult).report
	# The solver works on the continuous field; quantisation, the repose pass and
	# river incision each move a column or two afterwards, so the promise is kept
	# to within a step rather than to the digit.
	assert(absf(float(report.metrics["land_mean_height"]) - 5.0) <= 2.0,
		"mean height %.2f" % report.metrics["land_mean_height"])
	assert(absi(int(report.metrics["land_max_height"]) - 24) <= 3,
		"max height %d" % report.metrics["land_max_height"])


static func _test_every_stored_height_is_a_legal_integer() -> void:
	var run := _generated(555)
	var grid: TerrainGrid = (run[0] as Harness).grid
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var height := grid.height_of(Vector2i(x, z))
			assert(height >= TerrainGrid.MIN_HEIGHT and height <= TerrainGrid.MAX_HEIGHT)


# --- Structures ---------------------------------------------------------------

## §3.5: the count and the bearing of a range are things the author asked for, so
## they have to be things the result actually has.
static func _test_mountain_graph_has_the_requested_shape() -> void:
	var run := _generated(31337)
	var context: GenerationContext = (run[1] as GenerationResult).context
	# Two ranges from the one spec plus one solitary peak, each its own polyline.
	assert(context.ridges.size() == 3, "ridges: %d" % context.ridges.size())
	assert(context.peaks.size() == 2 * 3 + 1, "peaks: %d" % context.peaks.size())
	assert(context.passes.size() == 4, "passes: %d" % context.passes.size())
	for ridge: PackedVector2Array in context.ridges:
		if ridge.size() < 2:
			continue
		var bearing := rad_to_deg(atan2(ridge[ridge.size() - 1].x - ridge[0].x, -(ridge[ridge.size() - 1].y - ridge[0].y)))
		var offset := absf(wrapf(bearing - 55.0, -180.0, 180.0))
		# The polyline wanders sideways, so the end-to-end bearing is looser than
		# the jitter itself; what matters is that it is not a different direction.
		assert(offset <= 60.0, "range points %.1f° away from the requested 55°" % offset)


## §4.1: the same request has to produce the same buffers, bit for bit.
static func _test_generation_is_reproducible() -> void:
	var first := _generated(8080)
	var second := _generated(8080)
	var left: TerrainGrid = (first[0] as Harness).grid
	var right: TerrainGrid = (second[0] as Harness).grid
	var left_snapshot := left.snapshot()
	var right_snapshot := right.snapshot()
	for key: String in left_snapshot:
		assert(left_snapshot[key] == right_snapshot[key], "%s differs between two identical runs" % key)
	var left_water: WaterGrid = (first[0] as Harness).water
	var right_water: WaterGrid = (second[0] as Harness).water
	assert(left_water.snapshot() == right_water.snapshot(), "the water layer differs between two identical runs")


## §1: the generator has no geometry rules of its own. Every slope on the board
## came out of the catalog through `SlopeAssigner`, and every ramp is whole.
static func _test_slopes_never_leave_the_catalog() -> void:
	var run := _generated(606)
	var grid: TerrainGrid = (run[0] as Harness).grid
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			var slope_class := grid.slope_class_at(cell)
			assert(SlopeCatalog.is_valid_class(slope_class))
			if SlopeCatalog.is_ramp_class(slope_class):
				assert(grid.is_ramp_valid_at(cell), "ramp at (%d, %d) is not whole" % [x, z])


# --- Hydrology ----------------------------------------------------------------

## §3.6: a river that stops halfway down a hillside is an error of the generator,
## and the bed never climbs.
static func _test_rivers_run_downhill_and_reach_a_receiver() -> void:
	var run := _generated(4711)
	var result: GenerationResult = run[1]
	var report := result.report
	assert(int(report.metrics["rivers_traced"]) > 0, "the reference recipe asks for rivers")
	assert(int(report.metrics["rivers_terminated"]) == int(report.metrics["rivers_traced"]),
		"%d rivers end nowhere" % (int(report.metrics["rivers_traced"]) - int(report.metrics["rivers_terminated"])))

	var context := result.context
	for entry: Dictionary in context.water_plan:
		if entry["type"] != WaterBody.Type.RIVER:
			continue
		var cells: Array[Vector2i] = entry["cells"]
		var level := int(entry["level"])
		# The footprint is what a body at this level would reach, so it is wider than
		# the reach that named it and two neighbouring pools may propose the same
		# cell. That is a proposal, not a contradiction — the water stage floods once
		# and `_test_water_bodies_are_supported` is what proves the result holds. What
		# must be true here is the part the level depends on: every cell of the
		# footprint stands under that one surface, and the reach it belongs to is
		# actually at this level.
		var own_reach := false
		for cell: Vector2i in cells:
			assert(context.heights[context.cell_index(cell)] < level, "a pool cell must stand under its surface")
			if not context.river_cells.has(cell):
				continue
			var record: Dictionary = context.river_cells[cell]
			if not bool(record["sill"]) and int(record["bed"]) + 1 == level:
				own_reach = true
		assert(own_reach, "a river pool must contain the reach whose level it carries")


## §6: no hanging water. Every wet column stands on ground below its own surface
## and every open side of it meets the same body or a bank.
static func _test_water_bodies_are_supported() -> void:
	var run := _generated(1212)
	var harness: Harness = run[0]
	var damaged := harness.water.damaged_body_ids(harness.grid)
	assert(damaged.is_empty(), "%d water bodies are not physically supported" % damaged.size())
	for body: WaterBody in harness.water.bodies():
		for cell: Vector2i in harness.water.cells_of_body(body.id):
			assert(harness.water.depth_steps_at(harness.grid, cell) > 0, "a body may not contain a dry column")


# --- Borders ------------------------------------------------------------------

## §3.2: the wall is checked, not assumed. A flood from the centre of the board
## must not reach the locked band — for the corner case of an ocean side meeting
## a wall side as much as for the plain one.
static func _test_border_wall_cannot_be_walked_around() -> void:
	var run := _generated(9001)
	var result: GenerationResult = run[1]
	assert(bool(result.report.metrics["walls_sealed"]), "a pedestrian walked into the border wall")

	var four_walls := _recipe({
		"border": {
			"north": {"kind": "mountain_wall", "height": 20, "thickness": 4},
			"east": {"kind": "mountain_wall", "height": 20, "thickness": 4},
			"south": {"kind": "mountain_wall", "height": 20, "thickness": 4},
			"west": {"kind": "mountain_wall", "height": 20, "thickness": 4},
			"ocean_level": -2,
		},
		"landmass": {"shape": "inland", "land_fraction": 1.0, "island_count": 0},
	})
	assert(four_walls.is_valid(), "; ".join(four_walls.errors))
	var walled := _generated(9002, four_walls)
	assert(bool((walled[1] as GenerationResult).report.metrics["walls_sealed"]),
		"a basin closed on all four sides leaked")


## §8: the board is published once, not once per column. The revision counter of
## the navigation grid is the cheapest honest proof of that.
static func _test_navigation_is_published_once() -> void:
	var harness := Harness.new()
	var before := harness.nav.topology_revision()
	harness.service.generate(_recipe(), 77)
	var after := harness.nav.topology_revision()
	assert(after - before <= 4, "navigation topology moved %d times for one generation" % (after - before))
	assert(harness.nav.has_terrain_field(), "the generated board must be published at all")
	assert(harness.terrain_service.undo_depth() == 0, "generation is a new document, not an undoable edit")


# --- Surface (stage 14) -------------------------------------------------------

## Stage 3 of the design's layer list: the map is made of something. It used to be
## made of exactly one thing — `elevation.repose_override`, a knob for comparing
## SHAPES, was also the material written into every column — so every generated
## world was solid stone.
##
## The hard promise is the last one: a material may never be painted where its own
## angle of repose cannot hold the column. Ground that violates it is ground the
## cascade would collapse the moment anything touched it, and the editor refuses
## exactly this by hand.
static func _test_surface_is_painted_and_always_stands() -> void:
	var generated := _generated(4242)
	var harness: Harness = generated[0]
	var grid := harness.grid
	var seen: Dictionary = {}
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			var index := grid.material_index_at(cell)
			seen[index] = true
			var drop := 0
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbour := cell + offset
				if grid.is_inside(neighbour):
					drop = maxi(drop, absi(grid.height_of(neighbour) - grid.height_of(cell)))
			# A border wall is an AUTHORED face (§3.2) and the repose pass exempts it,
			# so some columns are steeper than anything in the catalog holds. The
			# promise is therefore the one the painter can actually keep: where a
			# material would collapse, it fell back to the most stable one there is.
			assert(
				TerrainMaterialCatalog.holds_height_difference(index, drop)
				or grid.material_of(cell) == TerrainMaterialCatalog.STONE,
				"%s at %s cannot hold a drop of %d and is not the fallback" % [grid.material_of(cell), cell, drop],
			)
			# Variants must address the palette of the material they landed on.
			assert(grid.variant_at(cell) < TerrainMaterialVariants.variant_count(index))
	assert(seen.size() >= 3, "a generated world is made of more than one thing")

	# Same seed, same surface — the painter reads the same finished ground and the
	# same two noise streams, so it may not introduce a new source of divergence.
	var again := _generated(4242)
	var other: Harness = again[0]
	assert(other.grid.snapshot()["materials"] == grid.snapshot()["materials"])
	assert(other.grid.snapshot()["details"] == grid.snapshot()["details"])


## The shape laboratory wants one flat colour, so it can read relief without the
## surface arguing with it. That is a recipe switch, not a missing feature.
static func _test_surface_can_be_turned_off() -> void:
	var recipe := _recipe()
	recipe.paint_surface = false
	recipe.base_material = TerrainMaterialCatalog.STONE
	var generated := _generated(4242, recipe)
	var harness: Harness = generated[0]
	var grid := harness.grid
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			assert(grid.material_of(Vector2i(x, z)) == TerrainMaterialCatalog.STONE)


# --- Climate (layer 2) --------------------------------------------------------

## §11.1: the two means are TARGETS, not outcomes. An author who typed 24 °C gets
## 24 °C on any seed, exactly as with `land_fraction` — otherwise the metric that
## reports the climate is reporting something other than what was asked for. The
## band names are checked the same way the composition presets are: a request that
## contradicts itself is refused with a reason (§3.3).
static func _test_climate_means_are_targets() -> void:
	for wanted: Array in [[24.0, 0.2, "subtropical"], [3.0, 0.7, "boreal"]]:
		var recipe := _recipe({"climate": {
			"latitude": wanted[2],
			"land_mean_temperature": wanted[0],
			"land_mean_moisture": wanted[1],
		}})
		assert(recipe.is_valid(), "; ".join(recipe.errors))
		var generated := _generated(3131, recipe)
		var metrics: Dictionary = (generated[1] as GenerationResult).report.metrics
		assert(absf(float(metrics["mean_temperature"]) - float(wanted[0])) < 0.5,
			"asked for %.1f °C, measured %.1f" % [wanted[0], metrics["mean_temperature"]])
		assert(absf(float(metrics["mean_moisture"]) - float(wanted[1])) < 0.03,
			"asked for %.2f moisture, measured %.2f" % [wanted[1], metrics["mean_moisture"]])

	var contradiction := _recipe({"climate": {"latitude": "tropical", "land_mean_temperature": -5.0}})
	assert(not contradiction.is_valid(), "a tropical band at −5 °C has to be refused, not clamped")
	var unknown := _recipe({"climate": {"latitude": "mediterranean"}})
	assert(not unknown.is_valid(), "an unknown latitude band is a refusal")
	var off_earth := _recipe({"biomes": {"origin": "mars"}})
	assert(not off_earth.is_valid(), "only Earth biomes exist, and asking for others is refused")


## §11.1.2: the rain shadow is the payoff for building mountains as structures.
## The test is the one thing that proves the mechanism rather than the field: turn
## the wind around and the dry side has to change sides. Both halves are measured
## on the SAME ground — only `wind_direction` differs — so nothing but the wind
## can explain the difference.
static func _test_rain_shadow_follows_the_wind() -> void:
	var westerly := _moisture_halves(270.0)
	var easterly := _moisture_halves(90.0)
	assert(westerly[0] > westerly[1] + 0.03,
		"with a westerly the windward (west) side of the range must be the wetter one: %.3f vs %.3f" % westerly)
	assert(easterly[1] > easterly[0] + 0.03,
		"with an easterly the east side must be the wetter one: %.3f vs %.3f" % easterly)


## Mean moisture of the western and the eastern half of the land, for one wind.
##
## The board is deliberately landlocked with a single north–south range down the
## middle: a coastline would wet one side of the map whatever the wind does, and
## then the test would be measuring the sea. Here the wind is the only asymmetry
## there is, so the sides must swap when it turns round.
static func _moisture_halves(wind_direction: float) -> Array:
	var recipe := _recipe({
		"border": {
			"north": {"kind": "open"}, "east": {"kind": "open"},
			"south": {"kind": "open"}, "west": {"kind": "open"}, "ocean_level": -2,
		},
		"landmass": {"shape": "inland", "land_fraction": 1.0, "island_count": 0, "shelf_width": 0},
		"mountains": {
			"ranges": [{
				"count": 1, "length": 0.9, "orientation": 0, "orientation_jitter": 0,
				"peak_height": [18, 24], "peaks_per_range": 3,
				"flank_steepness": 0.8, "foothills": 6, "passes": 2,
			}],
			"solitary_peaks": {"count": 0},
		},
		"climate": {"wind_direction": wind_direction, "rain_shadow": 1.0},
	})
	assert(recipe.is_valid(), "; ".join(recipe.errors))
	var context := GenerationPipeline.run(recipe, GenerationSeed.new(555))
	# Split at the crest the generator actually placed, not at the origin: the range
	# is dropped at a random offset, and halving the board instead of the range
	# would put a strip of the lee side into the windward figure.
	var crest := 0.0
	var crest_points := 0
	for ridge: PackedVector2Array in context.ridges:
		for point: Vector2 in ridge:
			crest += point.x
			crest_points += 1
	crest /= float(maxi(crest_points, 1))

	var totals := [0.0, 0.0]
	var counts := [0, 0]
	for index in context.cell_count:
		if context.border_locked[index] != 0 or context.is_land[index] == 0:
			continue
		var half := 0 if float(context.cell_of_index(index).x) < crest else 1
		totals[half] += context.moisture[index]
		counts[half] += 1
	return [
		float(totals[0]) / float(maxi(int(counts[0]), 1)),
		float(totals[1]) / float(maxi(int(counts[1]), 1)),
	]


# --- Biomes (layer 3) ---------------------------------------------------------

## §11.2: every column has a biome, including the wet ones — water is a layer over
## the board, not a biome — and which one it is follows the climate rather than a
## second noise field. Two recipes that differ ONLY in their climate must not
## produce the same kind of world.
static func _test_biomes_cover_the_board_and_follow_the_climate() -> void:
	var cold := _biome_shares({"latitude": "polar", "land_mean_temperature": -6.0, "land_mean_moisture": 0.4})
	var hot := _biome_shares({"latitude": "subtropical", "land_mean_temperature": 26.0, "land_mean_moisture": 0.12})

	var frozen := (
		float(cold.get(String(BiomeCatalog.POLAR_DESERT), 0.0))
		+ float(cold.get(String(BiomeCatalog.TUNDRA), 0.0))
		+ float(cold.get(String(BiomeCatalog.ALPINE), 0.0))
		+ float(cold.get(String(BiomeCatalog.BOREAL_FOREST), 0.0))
	)
	assert(frozen > 0.8, "a polar recipe produced %.2f of cold biomes" % frozen)
	assert(float(hot.get(String(BiomeCatalog.DESERT), 0.0)) > 0.3,
		"a hot dry recipe produced %.2f desert" % hot.get(String(BiomeCatalog.DESERT), 0.0))
	assert(float(cold.get(String(BiomeCatalog.DESERT), 0.0)) < 0.05, "a polar map is not a desert map")


static func _biome_shares(climate: Dictionary) -> Dictionary:
	var recipe := _recipe({"climate": climate})
	assert(recipe.is_valid(), "; ".join(recipe.errors))
	var context := GenerationPipeline.run(recipe, GenerationSeed.new(808))
	assert(context.biomes.size() == context.cell_count, "the mask has to cover every column")
	var total := 0.0
	for index in context.cell_count:
		assert(BiomeCatalog.is_valid_index(int(context.biomes[index])), "an unclassified column")
		assert(BiomeCatalog.entry_of_index(int(context.biomes[index]))["origin"] == BiomeCatalog.ORIGIN_EARTH)
	var shares := BiomeField.land_shares(context)
	for id: String in shares:
		total += float(shares[id])
	assert(absf(total - 1.0) < 0.001, "the land shares of the biomes have to add up to the land")
	return shares


## The surface is drawn from the biome's palette, so two climates over the same
## relief have to produce two different grounds. Only the relative order is
## asserted: how much of the board ends up as rock is decided by the SHAPE (a face
## is stone whatever the biome says), and that is not what this test is about.
static func _test_surface_follows_the_biome() -> void:
	var desert := _material_counts({
		"latitude": "subtropical", "land_mean_temperature": 26.0, "land_mean_moisture": 0.1,
	})
	var temperate := _material_counts({
		"latitude": "temperate", "land_mean_temperature": 12.0, "land_mean_moisture": 0.6,
	})
	var desert_sand := int(desert.get(TerrainMaterialCatalog.SAND, 0))
	var desert_grass := int(desert.get(TerrainMaterialCatalog.GRASS, 0))
	var temperate_grass := int(temperate.get(TerrainMaterialCatalog.GRASS, 0))
	assert(desert_sand > desert_grass, "a desert with more meadow than sand is not a desert")
	assert(temperate_grass > desert_grass, "a temperate map must be greener than a desert one")


static func _material_counts(climate: Dictionary) -> Dictionary:
	var generated := _generated(2468, _recipe({"climate": climate}))
	var grid: TerrainGrid = (generated[0] as Harness).grid
	var counts: Dictionary = {}
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var id := grid.material_of(Vector2i(x, z))
			counts[id] = int(counts.get(id, 0)) + 1
	return counts


## §11.1.3, and the whole point of computing the climate before the hydrology: a
## hollow in dry country is a dry pan, not a lake. The exemption is a channel
## running through it, because that water was collected where it did rain.
static func _test_arid_climate_holds_no_lakes() -> void:
	var recipe := _recipe({"climate": {
		"latitude": "subtropical", "land_mean_temperature": 26.0, "land_mean_moisture": 0.1,
	}})
	assert(recipe.is_valid(), "; ".join(recipe.errors))
	var context := GenerationPipeline.run(recipe, GenerationSeed.new(1357))
	var lakes := 0
	for entry: Dictionary in context.water_plan:
		if entry["type"] != WaterBody.Type.LAKE:
			continue
		lakes += 1
		var cells: Array[Vector2i] = entry["cells"]
		var moisture := 0.0
		var fed := false
		for cell: Vector2i in cells:
			moisture += context.moisture[context.cell_index(cell)]
			fed = fed or context.river_cells.has(cell)
		moisture /= float(maxi(cells.size(), 1))
		assert(fed or moisture >= LakeFiller.LAKE_MIN_MOISTURE,
			"a lake stands in ground of %.2f moisture with no river feeding it" % moisture)

	# And the verdict measures it on the finished map, not just in the plan.
	var generated := _generated(1357, recipe)
	var metrics: Dictionary = (generated[1] as GenerationResult).report.metrics
	assert(float(metrics["desert_lake_fraction"]) <= recipe.desert_lake_fraction_max,
		"%.3f of the desert is under a lake" % metrics["desert_lake_fraction"])
