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
	_test_recipe_shape_controls_are_observable()
	_test_repose_is_mirror_invariant()
	_test_every_stored_height_is_a_legal_integer()
	_test_mountain_graph_has_the_requested_shape()
	_test_generation_is_reproducible()
	_test_slopes_never_leave_the_catalog()
	_test_rivers_run_downhill_and_reach_a_receiver()
	_test_water_bodies_are_supported()
	_test_border_wall_cannot_be_walked_around()
	_test_every_crossing_of_a_border_wall_is_un_jumpable()
	_test_a_border_wall_is_a_mountainside_and_not_a_slab()
	_test_a_climbable_riser_is_refused()
	_test_navigation_is_published_once()
	_test_surface_is_painted_and_always_stands()
	_test_surface_can_be_turned_off()
	_test_a_generated_world_is_not_made_of_stone()
	_test_soil_holds_the_plains_and_rock_holds_the_ranges()
	_test_repose_belongs_to_the_upper_column()
	_test_a_plateau_border_can_be_walked_onto()
	_test_board_sizes_are_the_ones_a_map_can_have()
	_test_generation_fills_a_map_document()
	_test_climate_means_are_targets()
	_test_rain_shadow_follows_the_wind()
	_test_biomes_cover_the_board_and_follow_the_climate()
	_test_surface_follows_the_biome()
	_test_arid_climate_holds_no_lakes()
	_test_audit_contracts_are_explicit()
	_test_builtin_recipes_ship_with_the_game()
	print("    [PASS] Map Generation Tests")


## Встроенные рецепты обязаны попадать в сборку. Лежали они рядом с
## лабораторией, а `tools/*` исключён из экспорта — в собранной игре список
## рецептов оказывался пуст, и флажок «Сгенерировать ландшафт» гас без единого
## сообщения. Здесь проверяется не путь ради пути, а то, что ровно один каталог
## отвечает за встроенные рецепты и он экспортируемый.
static func _test_builtin_recipes_ship_with_the_game() -> void:
	assert(not MapRecipeLibrary.BUILTIN_DIRECTORY.begins_with("res://tools/"),
		"`tools/*` не экспортируется: встроенные рецепты оттуда не доедут до игрока")
	var builtin: Array[Dictionary] = []
	for entry: Dictionary in MapRecipeLibrary.list():
		if bool(entry.get("builtin", false)):
			builtin.append(entry)
	assert(not builtin.is_empty(), "встроенных рецептов нет ни одного")
	for entry: Dictionary in builtin:
		var recipe := MapRecipe.from_json_path(String(entry["path"]))
		assert(recipe.errors.is_empty(),
			"встроенный рецепт %s не читается: %s" % [entry["id"], ", ".join(recipe.errors)])


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


## A settled country rather than the test's default alpine postage stamp: one
## short range and no walls, on the same small board. The default recipe packs two
## ranges, a solitary peak and two four-cell walls onto 64 cells, which is a fine
## stress case for slopes and a useless one for asking what a world is MADE of —
## most of it is legitimately rock.
static func _settled_recipe() -> MapRecipe:
	return _recipe({
		"border": {
			"north": {"kind": "ocean"}, "west": {"kind": "ocean"},
			"east": {"kind": "open"}, "south": {"kind": "open"},
			"ocean_level": -2,
		},
		"mountains": {
			"ranges": [{
				"count": 1, "length": 0.3, "orientation": 55, "orientation_jitter": 20,
				"peak_height": [12, 18], "peaks_per_range": 2,
				"flank_steepness": 0.7, "foothills": 6, "passes": 2,
			}],
			"solitary_peaks": {"count": 0, "height": [12, 18], "flank_steepness": 0.9},
		},
		"elevation": {
			"land_mean_height": 4, "land_max_height": 18,
			"hypsometry": "plains_with_peaks", "roughness": 0.3, "terrace_bias": 0.5,
		},
	})


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
	var legacy := MapRecipe.from_dictionary({"generator_version": 1, "mountains": {"ranges": []}, "rivers": {"count": 0}})
	assert(not legacy.is_valid(), "a recipe from the previous generator algorithm must be refused")

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


## §3.1: a recipe slider must survive the solver and change a measurable property
## of the integer map. These compare the same seed and alter exactly one control.
static func _test_recipe_shape_controls_are_observable() -> void:
	var smooth := _pipeline_for_elevation(0.0, 0.0)
	var rough := _pipeline_for_elevation(1.0, 0.0)
	var changed := 0
	for index in smooth.cell_count:
		if smooth.heights[index] != rough.heights[index]:
			changed += 1
	assert(float(changed) / float(smooth.cell_count) > 0.08,
		"roughness changed only %d of %d integer columns" % [changed, smooth.cell_count])

	var unterraced := _pipeline_for_elevation(0.25, 0.0)
	var terraced := _pipeline_for_elevation(0.25, 1.0)
	assert(_level_neighbourhood_share(terraced) > _level_neighbourhood_share(unterraced) + 0.03,
		"terrace_bias must create measurably more level ground")


static func _pipeline_for_elevation(roughness: float, terrace_bias: float) -> GenerationContext:
	var recipe := _settled_recipe()
	recipe.roughness = roughness
	recipe.terrace_bias = terrace_bias
	return GenerationPipeline.run(recipe, GenerationSeed.new(7070))


static func _level_neighbourhood_share(context: GenerationContext) -> float:
	var level := 0
	var land := 0
	for index in context.cell_count:
		if context.border_locked[index] != 0 or context.is_land[index] == 0:
			continue
		land += 1
		var cell := context.cell_of_index(index)
		var same := true
		for offset: Vector2i in ReposePass.NEIGHBOURS:
			var neighbour := cell + offset
			if context.contains(neighbour.x, neighbour.y) and context.heights[context.cell_index(neighbour)] != context.heights[index]:
				same = false
				break
		if same:
			level += 1
	return float(level) / float(maxi(land, 1))


## §4.2: mirroring the input changes traversal order relative to the shape. A
## Jacobi relaxation must return the mirrored output exactly.
static func _test_repose_is_mirror_invariant() -> void:
	var recipe := _recipe({"board": {"size": 32}})
	recipe.terrace_bias = 0.0
	var left := GenerationContext.new()
	var right := GenerationContext.new()
	left.configure(recipe, GenerationSeed.new(1))
	right.configure(recipe, GenerationSeed.new(1))
	left.repose_limit.fill(1)
	right.repose_limit.fill(1)
	for index in left.cell_count:
		var cell := left.cell_of_index(index)
		var height := 12 if cell.x < -3 and cell.y > -7 else (5 if cell.x + cell.y > 4 else 8)
		left.heights[index] = height
		right.heights[right.index_of(-cell.x - 1, cell.y)] = height
	left.refresh_land_mask()
	right.refresh_land_mask()
	ReposePass.apply(left)
	ReposePass.apply(right)
	for index in left.cell_count:
		var cell := left.cell_of_index(index)
		assert(left.heights[index] == right.heights[right.index_of(-cell.x - 1, cell.y)],
			"repose depends on raster order at %s" % cell)


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


## §3.2, the strong form. `walls_sealed` asks whether a flood from the centre
## happened to reach the frame; this asks the thing the flood is evidence FOR —
## that every single boundary from the map onto the rim is a drop nothing walks
## up. A leak the flood misses because the ground behind it is a pocket is still a
## leak, and it is the kind a later edit turns into a route.
static func _test_every_crossing_of_a_border_wall_is_un_jumpable() -> void:
	var generated := _generated(9003)
	var harness: Harness = generated[0]
	var context: GenerationContext = (generated[1] as GenerationResult).context
	var grid := harness.grid
	var crossings := 0
	for index in context.cell_count:
		if context.border_outer[index] == 0:
			continue
		var cell := context.cell_of_index(index)
		for offset: Vector2i in BorderShaper.NEIGHBOURS_8:
			var neighbour := cell + offset
			if not context.contains(neighbour.x, neighbour.y):
				continue
			var neighbour_index := context.cell_index(neighbour)
			# Only crossings from the map itself. Water is not a route out — the sea
			# at the foot of a headland owes the rim nothing (§3.2).
			if context.border_outer[neighbour_index] != 0 or context.is_land[neighbour_index] == 0:
				continue
			crossings += 1
			var drop := grid.height_of(cell) - grid.height_of(neighbour)
			assert(drop >= MapRecipe.MIN_SEAL_RISER,
				"%s stands only %d over %s — a pedestrian walks up two" % [cell, drop, neighbour])
			assert(not harness.nav.is_edge_passable(neighbour, cell, &"pedestrian"),
				"navigation lets a pedestrian step from %s onto the rim at %s" % [neighbour, cell])
	assert(crossings > 0, "the recipe has two walled sides and produced no frame to cross")


## The other half of §3.2, and the reason the stage was rewritten: impassable is
## not the same promise as walled. The rim has to be a mountainside — a ragged
## foot and foothills that can be stood on — and both halves are numbers rather
## than opinions, which is what lets a test hold them.
static func _test_a_border_wall_is_a_mountainside_and_not_a_slab() -> void:
	var metrics: Dictionary = (_generated(9004)[1] as GenerationResult).report.metrics
	# A band of fixed thickness — the shape this replaced — scores exactly 0 here.
	assert(float(metrics["rim_edge_spread"]) >= 1.0,
		"the foot of the rim wanders %.1f cells: that is a straight line, not a mountainside" % metrics["rim_edge_spread"])
	assert(float(metrics["rim_walkable"]) >= 0.4,
		"only %.2f of the rim's foothills can be stood on" % metrics["rim_walkable"])
	assert(bool(metrics["walls_sealed"]), "a rim that is pretty and passable is not a wall")


## §3.3 applied to the one number the wall's promise rests on: a riser of two is a
## step a pedestrian walks up (slope class 5, `very_steep`), so a recipe asking for
## one is asking for a wall that can be walked over. It gets a refusal, not a
## quiet clamp to something it did not request.
static func _test_a_climbable_riser_is_refused() -> void:
	var climbable := _recipe({
		"border": {
			"north": {"kind": "ocean"}, "west": {"kind": "ocean"},
			"east": {"kind": "mountain_wall", "seal": {"risers": 1, "riser_steps": 2}},
			"south": {"kind": "mountain_wall"},
			"ocean_level": -2,
		},
	})
	assert(not climbable.is_valid(), "a riser of two steps is climbable and must be refused")
	var narrow := _recipe({
		"border": {
			"north": {"kind": "ocean"}, "west": {"kind": "ocean"},
			"east": {"kind": "mountain_wall", "reach": [3, 6], "seal": {"risers": 3, "riser_steps": 3}},
			"south": {"kind": "mountain_wall"},
			"ocean_level": -2,
		},
	})
	assert(not narrow.is_valid(), "three terraces do not fit on a rim three cells deep")


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
			# The drop the column stands ABOVE — repose is about ground sliding
			# downhill, so a meadow at the foot of a cliff owes nothing to the cliff.
			var drop := 0
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbour := cell + offset
				if grid.is_inside(neighbour):
					drop = maxi(drop, grid.height_of(cell) - grid.height_of(neighbour))
			# A border wall is an AUTHORED face (§3.2) and the repose pass exempts it,
			# so some columns are steeper than anything in the catalog holds. The
			# promise is therefore the one the painter can actually keep: where a
			# material would collapse, it fell back to the most stable one there is.
			assert(
				TerrainMaterialCatalog.holds_height_difference(index, drop)
				or grid.material_of(cell) == TerrainMaterialCatalog.STONE
				or (
					grid.material_of(cell) == TerrainMaterialCatalog.SAND and drop == 1
					and SurfacePainter.supports_half_step_at(grid, cell)
				)
				# A ramp is SHAPED ground and repose is about ground that slumps:
				# the slope assigner lifted this column on purpose, and reading the
				# lift back as a face is what used to turn every hillside to rock.
				or grid.is_ramp_cell(cell),
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


## The regression this whole layer exists to prevent, stated as a number.
##
## Between 58 % and 73 % of the land of every shipped preset used to be `stone`,
## and none of the surface tests noticed, because each of them asked a local
## question — does this column hold, is the palette addressed correctly — and the
## answer to all of those was yes. A map made of rock is a global property, so it
## takes a global assertion.
##
## The two thirds that were stone came from three rules, each defensible alone:
## the whole board settled at rock's angle, a material had to hold the drop on
## EITHER side of it, and the ramps the slope assigner laid were re-read as faces.
static func _test_a_generated_world_is_not_made_of_stone() -> void:
	for seed_value: int in [4242, 31337]:
		var generated := _generated(seed_value, _settled_recipe())
		var harness: Harness = generated[0]
		var result: GenerationResult = generated[1]
		var context := result.context
		var grid := harness.grid
		var counts: Dictionary = {}
		var land := 0
		var minimum := grid.min_cell()
		var maximum := grid.max_cell()
		for z in range(minimum.y, maximum.y + 1):
			for x in range(minimum.x, maximum.x + 1):
				var cell := Vector2i(x, z)
				# The frame of the map is rock by construction and is not the ground
				# the recipe was describing (§3.2).
				if context.border_locked[context.cell_index(cell)] != 0:
					continue
				if harness.water.has_water(cell) or grid.height_of(cell) < context.recipe.ocean_level:
					continue
				land += 1
				var id := grid.material_of(cell)
				counts[id] = int(counts.get(id, 0)) + 1
		assert(land > 0, "seed %d produced no land at all" % seed_value)
		var stone := float(int(counts.get(TerrainMaterialCatalog.STONE, 0))) / float(land)
		var soft := 0
		for id: StringName in [
			TerrainMaterialCatalog.GRASS, TerrainMaterialCatalog.GRASS_TALL,
			TerrainMaterialCatalog.DIRT, TerrainMaterialCatalog.MUD, TerrainMaterialCatalog.SAND,
		]:
			soft += int(counts.get(id, 0))
		assert(stone <= 0.45, "seed %d: %.0f%% of the land is stone" % [seed_value, stone * 100.0])
		assert(float(soft) / float(land) >= 0.35,
			"seed %d: only %.0f%% of the land is soil" % [seed_value, float(soft) * 100.0 / float(land)])


## §2.3, resolved: the angle of repose is a property of a PLACE, so the ranges get
## rock's four steps per cell and everything else gets soil's one. The mask is
## what makes the previous test's number achievable at all — no palette can put
## grass on ground that stands four steps above its neighbour.
static func _test_soil_holds_the_plains_and_rock_holds_the_ranges() -> void:
	var generated := _generated(4242, _settled_recipe())
	var context: GenerationContext = (generated[1] as GenerationResult).context
	var rock := 0
	var soil := 0
	var steep_soil := 0
	for index in context.cell_count:
		if int(context.repose_limit[index]) >= GroundMask.ROCK_STEPS:
			rock += 1
			continue
		soil += 1
		var cell := context.cell_of_index(index)
		# Authored cuts and their banks are exempt. A channel is incised on purpose,
		# and the ground beside it therefore stands above it by however deep the cut
		# is — including the outflow the lake stage carves after this pass has run.
		# That is a bank, not a slope that failed to settle.
		if context.border_locked[index] != 0 or _beside_authored_cut(context, cell):
			continue
		var lowest := TerrainGrid.MAX_HEIGHT
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbour := cell + offset
			if context.contains(neighbour.x, neighbour.y):
				lowest = mini(lowest, context.heights[context.cell_index(neighbour)])
		if context.heights[index] >= context.recipe.ocean_level:
			lowest = maxi(lowest, context.recipe.ocean_level)
		if context.heights[index] - lowest > GroundMask.SOIL_STEPS:
			steep_soil += 1
	assert(rock > 0, "a recipe with two ranges and a walled border produced no rock at all")
	assert(soil > rock, "the ranges cover more of the board than everything else does")
	# Not zero, and the difference matters. The lake stage carves an outflow AFTER
	# the settling pass has run (§10.1.4 — lakes are chosen last, on ground nothing
	# else will move), so a handful of banks around a fresh channel stand above
	# what soil holds. A handful is a bank; a percent is a settling pass that is
	# not doing its job, which is what this number was before the mask existed.
	assert(float(steep_soil) / float(maxi(soil, 1)) < 0.005,
		"%d of %d soil columns stand steeper than soil holds" % [steep_soil, soil])


static func _beside_authored_cut(context: GenerationContext, cell: Vector2i) -> bool:
	for offset: Vector2i in [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]:
		var probe := cell + offset
		if context.river_cells.has(probe) or context.carved_cells.has(probe):
			return true
	return false


## The rule the fix turns on, checked directly rather than through a whole map:
## ground slides downhill, so the drop below a column constrains it and the wall
## above it does not.
static func _test_repose_belongs_to_the_upper_column() -> void:
	var grass := TerrainMaterialCatalog.index_of(TerrainMaterialCatalog.GRASS)
	assert(TerrainMaterialCatalog.holds_height_difference(grass, 1))
	assert(not TerrainMaterialCatalog.holds_height_difference(grass, 2),
		"grass holds one step per cell, so a two-step brow is authored collapse")
	assert(TerrainMaterialCatalog.holds_height_difference(grass, -6),
		"a meadow at the foot of a six-step cliff holds nothing up")


## §3.2: `mountain_wall` promises to be impassable and `plateau` promises a shelf.
## Both are frame rather than map, but only one of them is a wall — a plateau
## nobody can climb onto is a wall spelled differently, and the verdict used to
## require exactly that.
static func _test_a_plateau_border_can_be_walked_onto() -> void:
	var recipe := _recipe({
		"border": {
			"north": {"kind": "plateau", "height": 6, "thickness": 4},
			"east": {"kind": "plateau", "height": 6, "thickness": 4},
			"south": {"kind": "plateau", "height": 6, "thickness": 4},
			"west": {"kind": "plateau", "height": 6, "thickness": 4},
			"ocean_level": -2,
		},
		"landmass": {"shape": "inland", "land_fraction": 1.0, "island_count": 0},
	})
	assert(recipe.is_valid(), "; ".join(recipe.errors))
	var generated := _generated(5150, recipe)
	var result: GenerationResult = generated[1]
	assert(bool(result.report.metrics["walls_sealed"]),
		"a board with no mountain_wall side has no wall to seal, so the check must pass trivially")
	var context := result.context
	var walls := 0
	for index in context.cell_count:
		walls += int(context.border_wall[index])
	assert(walls == 0, "a plateau side is not a wall and must not be counted as one")


## The generator and the editor have to agree about what sizes a board comes in
## (`map_editor.md` §6.2), or the editor offers a preset the generator refuses.
static func _test_board_sizes_are_the_ones_a_map_can_have() -> void:
	for cells: int in MapMeta.BOARD_PRESETS:
		var recipe := _recipe({"board": {"size": cells}})
		assert(recipe.is_valid(), "board preset %d refused: %s" % [cells, "; ".join(recipe.errors)])
	var ragged := _recipe({"board": {"size": 100}})
	assert(not ragged.is_valid(), "a board of 100 is not whole chunks and must be refused")


## Layer 6: generation as an operation on a MAP, not on two bare grids.
##
## The three things `MapGenerationService` exists for, because none of them can be
## the pipeline's business: the rim of the map is one header field where the
## recipe has four sides, the document has to come out dirty, and a map with no
## start option has to say so instead of being discovered unlaunchable later.
static func _test_generation_fills_a_map_document() -> void:
	var document := MapDocument.create(&"generated", "Сгенерированная", BOARD)
	var harness := Harness.new()
	harness.grid = document.terrain
	harness.water = document.water
	document.terrain.configure(1.0, BOARD)
	document.water.configure(1.0, BOARD)
	harness.terrain_service.configure(document.terrain)
	harness.water_service.configure(document.water, document.terrain)
	harness.publisher.configure(
		document.terrain, harness.nav, harness.terrain_service, document.water, harness.water_service)
	harness.service.configure(
		document.terrain, document.water, harness.terrain_service, harness.water_service,
		harness.publisher, harness.nav)
	var service := MapGenerationService.new()
	service.configure(harness.service)

	var result := service.generate_into(document, _recipe(), 4242)
	assert(result.report != null and not result.report.is_rejected_recipe(), result.failure_summary())
	assert(document.dirty, "a generated map is an unsaved map")
	# Two ocean sides in the reference recipe, so the world continues as sea past
	# the rim — at the level the generator poured, or `BorderOceanService` will
	# re-flood the coastline at a different one on the author's first stroke.
	assert(document.meta.border_kind == MapMeta.BORDER_OCEAN)
	assert(document.meta.border_level == _recipe().ocean_level)
	assert(not document.meta.biomes.is_empty(), "the header says what kind of world this is")
	assert(result.report.notes.has(MapGenerationService.MISSING_START_NOTE),
		"a map with no start option has to say so")

	# --- Слой 4: карта населена ------------------------------------------------
	# Земля без единого дерева — не «пока не сделано», а пустая карта: генератор,
	# доходящий только до поверхности, отдаёт автору доску, которую всё равно
	# засаживать руками.
	assert(document.scatter.live_count() > 0, "сгенерированная карта осталась голой")
	assert(not document.scatter.archetypes.is_empty())
	for archetype_id: StringName in document.scatter.referenced_archetypes():
		assert(EntityArchetypeCatalog.get_archetype(archetype_id) != null,
			"слой ссылается на архетип, которого нет: %s" % archetype_id)
	# Где стоит объект — ответ политики размещения, тот же, что у кисти автора.
	for record: MapScatterLayer.Record in document.scatter.records:
		if record.is_empty():
			continue
		var asset := EntityArchetypeCatalog.asset_of(document.scatter.archetype_of(record))
		assert(asset != null)
		assert(EntityPlacementProbe.accepts_cells(
			asset.placement_policy(), document.terrain, document.water,
			Rect2i(record.cell, asset.placement_policy().footprint_cells)),
			"объект %s встал там, где его же политика этого не разрешает: %s"
				% [asset.id, record.cell])

	# Тот же seed — та же карта, включая лес: иначе сохранённая карта и
	# перегенерированная перестают быть сравнимыми (§4.1).
	var twin := MapDocument.create(&"twin", "Двойник", BOARD)
	var twin_harness := Harness.new()
	twin_harness.grid = twin.terrain
	twin_harness.water = twin.water
	twin.terrain.configure(1.0, BOARD)
	twin.water.configure(1.0, BOARD)
	twin_harness.terrain_service.configure(twin.terrain)
	twin_harness.water_service.configure(twin.water, twin.terrain)
	twin_harness.publisher.configure(
		twin.terrain, twin_harness.nav, twin_harness.terrain_service, twin.water, twin_harness.water_service)
	twin_harness.service.configure(
		twin.terrain, twin.water, twin_harness.terrain_service, twin_harness.water_service,
		twin_harness.publisher, twin_harness.nav)
	var twin_service := MapGenerationService.new()
	twin_service.configure(twin_harness.service)
	twin_service.generate_into(twin, _recipe(), 4242)
	assert(MapScatterCodec.encode(twin.scatter) == MapScatterCodec.encode(document.scatter),
		"тот же seed обязан дать тот же лес байт в байт: %d против %d записей"
			% [twin.scatter.live_count(), document.scatter.live_count()])

	# Наполнение — записи, а не правило: убрав одно дерево, автор не должен
	# сдвинуть остальные (§9.2).
	var before_removal := document.scatter.live_count()
	assert(document.scatter.remove_at(0))
	assert(document.scatter.live_count() == before_removal - 1)

	# The size of a map is chosen once, at creation (map_editor.md §6.2): a recipe
	# for another board is refused rather than quietly resizing the document.
	var mismatched := service.generate_into(document, _recipe({"board": {"size": 128}}), 1)
	assert(mismatched.report.is_rejected_recipe(), "a recipe for another board must be refused")

	# A board walled or open on every side ends where it ends.
	var walled := MapMeta.new()
	MapGenerationService.apply_border(walled, _recipe({
		"border": {
			"north": {"kind": "mountain_wall", "height": 20, "thickness": 4},
			"east": {"kind": "open"}, "south": {"kind": "open"}, "west": {"kind": "open"},
			"ocean_level": -2,
		},
		"landmass": {"shape": "inland", "land_fraction": 1.0, "island_count": 0},
	}))
	assert(walled.border_kind == MapMeta.BORDER_NOTHING)


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


## Latent contracts found by the full pipeline audit: each one is asserted at
## its owning boundary so a table reorder or a reporting-only metric cannot make
## it silently disappear again.
static func _test_audit_contracts_are_explicit() -> void:
	# Equal-height shoreline is dry ground because water requires positive depth.
	var shoreline_recipe := _recipe()
	var shoreline := GenerationContext.new()
	shoreline.configure(shoreline_recipe, GenerationSeed.new(1))
	shoreline.heights.fill(shoreline_recipe.ocean_level)
	shoreline.refresh_land_mask()
	assert(shoreline.land_cell_count() == shoreline.cell_count, "ocean-level columns are shoreline land")

	# Flow accumulation reaches every authored strength and therefore both the
	# no-freeze and no-ford mechanics already defined by WaterBody.
	assert(LakeFiller.flow_strength(RiverCarver.MIN_SOURCE_ACCUMULATION) == 1)
	assert(LakeFiller.flow_strength(LakeFiller.FAST_FLOW_ACCUMULATION) == 2)
	assert(LakeFiller.flow_strength(LakeFiller.BLOCKING_FLOW_ACCUMULATION) == 3)

	# Overlapping climate rectangles resolve by authored priority, never table order.
	assert(
		BiomeCatalog.id_of_index(BiomeCatalog.classify_climate(0.0, 0.1)) == BiomeCatalog.TUNDRA,
		"cold dry overlap must resolve to tundra rather than desert",
	)

	var tolerance_recipe := _recipe({"targets": {
		"land_mean_temperature_tolerance": 0.25,
		"land_mean_moisture_tolerance": 0.01,
	}})
	assert(tolerance_recipe.land_mean_temperature_tolerance == 0.25)
	assert(tolerance_recipe.land_mean_moisture_tolerance == 0.01)
	var round_trip := MapRecipe.from_dictionary(tolerance_recipe.to_dictionary())
	assert(round_trip.land_mean_temperature_tolerance == 0.25)
	assert(round_trip.land_mean_moisture_tolerance == 0.01)

	# The generator's direct board sweep still crosses WaterService once, allowing
	# presentation to refresh without a presentation dependency in the generator.
	var harness := Harness.new()
	var bulk_notifications := [0]
	harness.water_service.bulk_replaced.connect(func() -> void: bulk_notifications[0] += 1)
	var result := harness.service.generate(_recipe(), 10101)
	assert(result.context != null)
	assert(bulk_notifications[0] > 0, "bulk generation must notify water consumers")
	assert(result.recipe.generator_version == 2)
	var scalar_miss: Dictionary = result.report.metrics.duplicate(true)
	scalar_miss["flat_fraction"] = 0.0
	assert(not TerrainMetrics.has_fatal_failures(result.recipe, scalar_miss),
		"a flat target miss must correct the same world, not reseed it")
	var broken_wall: Dictionary = result.report.metrics.duplicate(true)
	broken_wall["walls_sealed"] = false
	assert(TerrainMetrics.has_fatal_failures(result.recipe, broken_wall),
		"a leaking wall is a structural failure")
	var strongest_generated_flow := 0
	for body: WaterBody in harness.water.bodies():
		for cell: Vector2i in body.flow:
			var strength := body.flow_strength_at(cell)
			strongest_generated_flow = maxi(strongest_generated_flow, strength)
			assert(strength == LakeFiller.flow_strength(result.context.flow_accum[result.context.cell_index(cell)]))
	assert(strongest_generated_flow == WaterBody.MAX_FLOW_STRENGTH,
		"the generated accumulation axis must reach the blocking-current tier")
	var rejected_metrics: Dictionary = result.report.metrics.duplicate(true)
	rejected_metrics["mean_temperature"] = (
		tolerance_recipe.land_mean_temperature + tolerance_recipe.land_mean_temperature_tolerance + 1.0
	)
	rejected_metrics["mean_moisture"] = tolerance_recipe.land_mean_moisture
	var climate_failures := TerrainMetrics.failures(tolerance_recipe, rejected_metrics)
	assert(climate_failures.any(func(reason: String) -> bool: return reason.begins_with("mean temperature")),
		"a measured climate outside its tolerance must reject the attempt")

	# Acceptance reads the published triangles and edges. Recompute the two shares
	# directly from NavTerrainField and require the report to match them exactly.
	var field := harness.nav.terrain_field()
	var land: Dictionary = {}
	var flat := 0
	for index in result.context.cell_count:
		if result.context.border_locked[index] != 0:
			continue
		var cell := result.context.cell_of_index(index)
		if harness.grid.height_of(cell) < result.context.recipe.ocean_level:
			continue
		land[cell] = true
		if field.slope_class_at(cell) == SlopeCatalog.CLASS_FLAT:
			flat += 1
	assert(is_equal_approx(
		float(result.report.metrics["flat_fraction"]), float(flat) / float(maxi(land.size(), 1))))
	var boundaries := 0
	var cliffs := 0
	for cell: Vector2i in land:
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var neighbour := cell + offset
			if not land.has(neighbour):
				continue
			boundaries += 1
			if field.edge_class(cell, neighbour) == NavTerrainField.CLASS_CLIFF:
				cliffs += 1
	var geometric_cliffs := 0.0 if boundaries == 0 else float(cliffs) / float(boundaries)
	assert(is_equal_approx(float(result.report.metrics["cliff_fraction"]), geometric_cliffs))

	# Repose and alpine now consume the same landform mask. There is no independent
	# height threshold left for either one to drift from.
	for index in result.context.cell_count:
		var rock_form := LandformField.is_rock(int(result.context.landforms[index]))
		assert((int(result.context.repose_limit[index]) == GroundMask.ROCK_STEPS) == rock_form)
		if int(result.context.biomes[index]) == BiomeCatalog.index_of(BiomeCatalog.ALPINE):
			assert(int(result.context.landforms[index]) == LandformField.SUMMIT)


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
