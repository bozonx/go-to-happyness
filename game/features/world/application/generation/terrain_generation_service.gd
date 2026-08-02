class_name TerrainGenerationService
extends RefCounted

## The single application entry point of map generation
## (procedural_map_generation.md §8).
##
## It owns the three things the pure pipeline cannot: the real grids, the two
## stages that need them (slopes and water), and the verdict loop of §6.
##
## **Writing is bulk and happens once.** The board is filled column by column
## through `TerrainGrid.set_cell_state` — the same commit path a `TerrainDelta`
## uses — and navigation is published exactly once at the end. A generator that
## looped over `TerrainService.apply_operation` per cell would run the cascade
## 16 384 times and republish the board just as often; that is not an
## implementation of generation, it is a denial of service.
##
## Generation is deliberately NOT an undoable edit. It creates the contents of a
## document rather than modifying one, so the terrain and water histories are
## cleared afterwards instead of being filled with one enormous delta (§11,
## layer 6).

const CELL_SIZE := 1.0
## How many seeds §6 allows before the generator gives up and reports instead.
const MAX_ATTEMPTS := 4
## `WaterBody` ids are one byte and 0 means dry, so the layer holds 255 bodies. A
## cascading river spends one per pool, which is the only thing here that can
## realistically approach the limit.
const MAX_BODIES := WaterBody.MAX_ID
const WATER_REPAIR_ROUNDS := 4
## How many saddles the verdict stage may press before giving up and reporting a
## broken map. Each one costs a full re-commit, so the budget is small on purpose.
const CONNECTIVITY_ROUNDS := 3
## A walkable island smaller than this share of the walkable land is a ledge, not
## a region; trenching a corridor to every one of them would scar the whole board.
const MIN_ISLAND_SHARE := 0.02

signal attempt_finished(report: GenerationReport)

var _grid: TerrainGrid = null
var _water: WaterGrid = null
var _terrain_service: TerrainService = null
var _water_service: WaterService = null
var _nav_publisher: TerrainNavigationPublisher = null
var _nav_grid: NavGrid = null


func configure(
	grid: TerrainGrid, water: WaterGrid,
	terrain_service: TerrainService, water_service: WaterService,
	nav_publisher: TerrainNavigationPublisher, nav_grid: NavGrid,
) -> void:
	_grid = grid
	_water = water
	_terrain_service = terrain_service
	_water_service = water_service
	_nav_publisher = nav_publisher
	_nav_grid = nav_grid


## Runs the recipe until it produces a map that satisfies its own `targets`, or
## until the attempt budget runs out. Either way the grids hold the last attempt
## and the result explains what happened — silently returning a map that does not
## meet the recipe is the one thing the generator may not do (§6).
func generate(recipe: MapRecipe, seed_value: int) -> GenerationResult:
	var result := GenerationResult.new()
	result.recipe = recipe
	if not recipe.is_valid():
		var refusal := GenerationReport.new()
		refusal.recipe_id = recipe.id
		refusal.seed = seed_value
		refusal.recipe_errors = recipe.errors.duplicate()
		result.report = refusal
		result.attempts.append(refusal)
		return result

	# Two different things can be wrong with an attempt, and they deserve different
	# answers. A land share that came out short is a MEASUREMENT: the deltas and
	# the settling cost the map that much, so the next attempt asks the composition
	# solver for exactly that much more on the SAME seed (§5.3). Anything else is a
	# map that did not work out, and the answer to that is another world (§6).
	var bias := 0.0
	var reseeds := 0
	for attempt in MAX_ATTEMPTS:
		var seeds := GenerationSeed.new(seed_value)
		if reseeds > 0:
			seeds = seeds.derive(reseeds)
		var started := Time.get_ticks_msec()
		var context := GenerationPipeline.run(recipe, seeds, bias)
		_apply(context)

		var report := GenerationReport.new()
		report.recipe_id = recipe.id
		report.seed = seed_value
		report.attempt = attempt
		report.stage_times = context.stage_times.duplicate()
		report.notes = context.notes.duplicate()
		report.metrics = TerrainMetrics.measure(context, _grid, _water, _nav_grid)
		report.failures = TerrainMetrics.failures(recipe, report.metrics)
		report.accepted = report.failures.is_empty()
		report.total_milliseconds = Time.get_ticks_msec() - started

		result.attempts.append(report)
		result.report = report
		result.context = context
		attempt_finished.emit(report)
		if report.accepted:
			break
		var land_error := recipe.land_fraction - float(report.metrics["land_fraction"])
		if absf(land_error) > recipe.land_fraction_tolerance:
			bias += land_error
		if report.failures.size() > 1 or absf(land_error) <= recipe.land_fraction_tolerance:
			reseeds += 1
	return result


# --- Stages 11–13 -------------------------------------------------------------

func _apply(context: GenerationContext) -> void:
	_commit(context)
	# The pure stages carve passes against a model of what a walker can cross. The
	# model is close but not identical to the published field — slope assignment
	# moves columns after it ran, and a corner lifted by a neighbouring ramp can
	# turn a boundary one class steeper (§3.4 of the terrain doc). So the last word
	# on connectivity belongs to `NavGrid`, and this is where it gets it.
	var started := Time.get_ticks_msec()
	var rounds := 0
	for _round in CONNECTIVITY_ROUNDS:
		if not _carve_one_pass(context):
			break
		rounds += 1
		_commit(context)
	context.stage_times[&"repair"] = Time.get_ticks_msec() - started
	if rounds > 0:
		context.note("%d pass(es) pressed after navigation disagreed with the model" % rounds)

	# Nothing here belongs in the author's undo stack: this is a new document, not
	# an edit of one.
	_terrain_service.clear_history()
	_water_service.clear_history()


func _commit(context: GenerationContext) -> void:
	var started := Time.get_ticks_msec()
	_write_heights(context)
	context.stage_times[&"commit"] = Time.get_ticks_msec() - started

	started = Time.get_ticks_msec()
	_assign_slopes(context)
	context.stage_times[&"slopes"] = Time.get_ticks_msec() - started

	started = Time.get_ticks_msec()
	_write_water(context)
	context.stage_times[&"water"] = Time.get_ticks_msec() - started

	started = Time.get_ticks_msec()
	_nav_publisher.publish_all()
	context.stage_times[&"publish"] = Time.get_ticks_msec() - started


## Joins the two largest walkable regions, as `NavGrid` sees them, and reports
## whether it had anything to do. Returns false when the land is already one piece
## or when what is left over is too small to be worth a trench.
func _carve_one_pass(context: GenerationContext) -> bool:
	var components := _walkable_components(context.recipe.ocean_level)
	if components.size() <= 1:
		return false
	components.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	var walkable := 0
	for component: Array in components:
		walkable += component.size()
	# Nothing to repair once the recipe's own condition is met. An archipelago asks
	# for a quarter of its land in one piece and gets it; trenching a causeway
	# between two islands to reach a nine-tenths it never wanted is both wrong and
	# the most expensive thing this service does.
	if float((components[0] as Array).size()) >= float(walkable) * context.recipe.largest_land_component_min:
		return false
	if float((components[1] as Array).size()) < float(walkable) * MIN_ISLAND_SHARE:
		return false
	if PassCarver.carve_between(context, components[0], components[1]):
		return true
	# No chain of land joins the two at all: they are separated by water or by the
	# board itself, and no saddle can help. Saying so beats three silent rounds.
	context.note("connectivity: %d walkable cells are cut off with no land route to press" % (components[1] as Array).size())
	return false


## Walkable LAND regions over the published field, as arrays of context buffer
## indices so `PassCarver` can route between them in the coordinates it works in.
##
## Restricted to land on purpose. A shallow shelf is a ford and therefore
## walkable, so counting the sea here splits the board into pieces no saddle can
## ever join — and it is not the question §6 asks either, which is about the land.
func _walkable_components(ocean_level: int) -> Array:
	var components: Array = []
	var seen: Dictionary = {}
	var minimum := _grid.min_cell()
	var maximum := _grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var start := Vector2i(x, z)
			if seen.has(start) or _grid.height_of(start) <= ocean_level:
				continue
			if not _nav_grid.is_walkable(start, &"pedestrian"):
				continue
			seen[start] = true
			var queue: Array[Vector2i] = [start]
			var head := 0
			var component: Array[int] = []
			while head < queue.size():
				var cell: Vector2i = queue[head]
				head += 1
				component.append(_buffer_index(cell))
				for direction in NavTerrainField.DIRECTION_COUNT:
					var neighbour: Vector2i = cell + NavTerrainField.DIRECTION_OFFSETS[direction]
					if seen.has(neighbour) or not _grid.is_inside(neighbour):
						continue
					if _grid.height_of(neighbour) <= ocean_level:
						continue
					if not _nav_grid.is_walkable(neighbour, &"pedestrian"):
						continue
					if not _nav_grid.is_edge_passable(cell, neighbour, &"pedestrian"):
						continue
					seen[neighbour] = true
					queue.append(neighbour)
			components.append(component)
	return components


func _buffer_index(cell: Vector2i) -> int:
	var half := _grid.board_cells / 2
	return (cell.y + half) * _grid.board_cells + (cell.x + half)


## The whole board in one sweep. `set_cell_state` is the delta commit path, so it
## writes height, slope, material and flags together and dirties geometry and
## surface separately — which is what keeps this from costing a remesh per column.
func _write_heights(context: GenerationContext) -> void:
	var material := TerrainMaterialCatalog.index_of(context.recipe.repose_override)
	_water.clear_bodies()
	_grid.configure(CELL_SIZE, context.board_cells, 0, context.recipe.repose_override)
	_water.configure(CELL_SIZE, context.board_cells)
	for index in context.cell_count:
		var cell := context.cell_of_index(index)
		_grid.set_cell_state(
			cell, context.heights[index],
			SlopeCatalog.CLASS_FLAT, 0, 0, material, 0, TerrainDetailCodec.DEFAULT_DETAIL,
		)


## Stage 11. The generator does not invent slope classes: it hands the finished
## columns to the same `SlopeAssigner` the height brush uses, and takes whatever
## the catalog allows on the ground it left (§1 "Генератор не имеет своих правил
## геометрии").
func _assign_slopes(context: GenerationContext) -> void:
	var region := TerrainWorkingRegion.new(_grid)
	var seed_cells: Array[Vector2i] = []
	var minimum := _grid.min_cell()
	var maximum := _grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			seed_cells.append(Vector2i(x, z))
	var placed := SlopeAssigner.assign_slopes(region, seed_cells)
	for cell: Vector2i in region.touched_cells():
		_grid.set_cell_state(
			cell, region.height_of(cell),
			region.slope_class_at(cell), region.slope_direction_of(cell), region.slope_index_of(cell),
			_grid.material_index_at(cell), _grid.flags_of(cell), _grid.detail_at(cell),
		)
	context.note("slopes: %d boundaries got a ramp" % placed)


## Stage 12. The plan carries a level and a footprint; the level is authoritative
## and the footprint is re-derived by flooding over the FINISHED ground. That is
## deliberate: slope assignment moves columns, and a footprint captured before it
## would describe a lake the terrain no longer supports.
func _write_water(context: GenerationContext) -> void:
	var seedless := 0
	var empty := 0
	var escaped := 0
	for entry: Dictionary in context.water_plan:
		if _water.body_count() >= MAX_BODIES:
			context.note("water: body budget of %d exhausted, %d plans dropped" % [
				MAX_BODIES, context.water_plan.size() - _water.body_count(),
			])
			break
		var level := int(entry["level"])
		var cells: Array[Vector2i] = entry["cells"]
		var found: Variant = _lowest_free_cell(cells, level)
		if found == null:
			seedless += 1
			continue
		var seed_cell: Vector2i = found
		var body_type: WaterBody.Type = entry["type"]
		var body := _water.create_body(body_type, level)
		if body == null:
			break
		var filled := _water.flood_cells(_grid, seed_cell, level, body.id)
		if filled.is_empty():
			_water.remove_body(body.id)
			empty += 1
			continue
		if _escaped(entry, filled.size()):
			_water.remove_body(body.id)
			escaped += 1
			continue
		for cell: Vector2i in filled:
			_water.set_cell(cell, body.id, level)
		var flow: Dictionary = entry["flow"]
		for cell: Vector2i in flow:
			if _water.body_id_at(cell) != body.id:
				continue
			var packed: Vector2i = flow[cell]
			body.set_flow(cell, packed.x, packed.y)
	if seedless + empty + escaped > 0:
		context.note("water: %d planned bodies dropped — %d already flooded, %d dry, %d escaped their basin" % [
			seedless + empty + escaped, seedless, empty, escaped,
		])
	_repair_water(context)


## A lake is a level and the rim that holds it, and the slope pass is still
## allowed to move a column after the rim was chosen. When the re-flood comes back
## far larger than the basin the plan described, that rim broke: the honest answer
## is no lake there, not a level sheet of water over a quarter of the board. The
## sea is exempt — its plan IS a flood from the board edge, and it is allowed to
## be as large as the coastline makes it.
static func _escaped(entry: Dictionary, filled_size: int) -> bool:
	if entry["type"] == WaterBody.Type.SEA:
		return false
	var planned: int = (entry["cells"] as Array).size()
	return filled_size > planned * 2 + 16


## The cell of a plan most likely to still be under its level after the terrain
## settled. Flooding from the deepest point is what makes the footprint robust to
## a column the slope pass nudged.
func _lowest_free_cell(cells: Array[Vector2i], level: int) -> Variant:
	var best: Variant = null
	var best_height := TerrainGrid.MAX_HEIGHT + 1
	for cell: Vector2i in cells:
		if not _grid.is_inside(cell) or _water.has_water(cell):
			continue
		var height := _grid.height_of(cell)
		if height >= level or height >= best_height:
			continue
		best_height = height
		best = cell
	return best


## Two bodies of different level meeting over an open edge is the one damage
## flooding cannot avoid on its own, because the second flood stops at the first
## body instead of raising a bank against it. The repair puts a sill between them
## — ground at the higher surface — which is exactly what parts two pools of a
## river. Whatever still does not stand up afterwards is removed rather than
## shipped: a hanging sheet of water is worse than no water (§6).
func _repair_water(context: GenerationContext) -> void:
	for _round in WATER_REPAIR_ROUNDS:
		var damaged := _water.damaged_body_ids(_grid)
		if damaged.is_empty():
			return
		var repaired := 0
		for body_id: int in damaged:
			var body := _water.body(body_id)
			if body == null:
				continue
			for cell: Vector2i in _water.cells_of_body(body_id):
				if _grid.height_of(cell) >= body.surface_height:
					_water.clear_cell(cell)
					repaired += 1
					continue
				for offset: Vector2i in WaterGrid.ORTHOGONAL_OFFSETS:
					var neighbour: Vector2i = cell + offset
					if not _grid.is_inside(neighbour) or _grid.is_hole(neighbour):
						continue
					if _grid.height_of(neighbour) >= body.surface_height:
						continue
					var occupant := _water.body_id_at(neighbour)
					if occupant == body_id:
						continue
					var other := _water.body(occupant)
					var sill := body.surface_height
					if other != null:
						sill = maxi(body.surface_height, other.surface_height)
						_water.clear_cell(neighbour)
					_grid.set_height(neighbour, sill)
					repaired += 1
		if repaired == 0:
			break
	var removed := _water.remove_damaged_bodies(_grid)
	if not removed.is_empty():
		context.note("water: %d unsupported bodies removed" % removed.size())
