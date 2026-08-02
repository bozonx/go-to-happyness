class_name RiverCarver
extends RefCounted

## Stage 8: rivers cut into the ground (procedural_map_generation.md §3.6).
##
## A river is traced down the drainage tree of stage 7, never drawn with noise:
## that is what guarantees water runs from the mountain to the sea instead of into
## the hillside. The trace then **incises** the channel — it lowers columns — and
## only after that does stage 12 put water in it. A river added on top of finished
## ground is a puddle on a slope.
##
## One constraint of the water layer shapes the whole result and is worth stating
## plainly: a `WaterBody` has ONE surface level for all of its cells
## (`water.md` / `WaterGrid.damaged_body_ids`). A river that descends therefore
## cannot be one body. It is a chain of pools, each level in its own body, parted
## by a one-cell sill standing at the upper pool's surface — a step-pool stream,
## which is what a mountain river actually is. The sill is what keeps the two
## levels from meeting, and without it the layer would reject the river as a body
## with mixed levels.

const STAGE := &"rivers"
## Below this a reach is a rapid and gets no water: one `WaterBody` per two-cell
## puddle would exhaust the 255 the layer has and read as a dotted line.
const MIN_POOL_CELLS := 2
## A trace shorter than this is not a river at all — the head was already at its
## receiver.
const MIN_TRACE_CELLS := 4
const MAX_TRACE_STEPS := 4096
## Accumulated drainage a cell needs before it can be a river head at all.
const MIN_SOURCE_ACCUMULATION := 8.0
## `_incise` normally derives the starting bed from the head's own ground; a lake
## outflow overrides it so the stream leaves at the lake's spill level (§3.7).
const NO_INITIAL_BED := -100000

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]
const NEIGHBOUR_DIRECTIONS: Array[int] = [
	SlopeCatalog.DIR_N, SlopeCatalog.DIR_E, SlopeCatalog.DIR_S, SlopeCatalog.DIR_W,
]


static func carve(context: GenerationContext) -> void:
	context.river_cells.clear()
	var recipe := context.recipe
	if recipe.river_count <= 0:
		return
	var rng := context.seeds.rng(STAGE)
	var wander := context.seeds.noise(&"rivers_meander", 7.0 / float(context.board_cells), 2)

	var sources := _pick_sources(context, rng, recipe.river_count)
	var traced := 0
	for source: Vector2i in sources:
		var trace := _trace(context, wander, source)
		if trace.size() < MIN_TRACE_CELLS:
			continue
		_extend_to_receiver(context, trace)
		_note_termination(context, trace)
		_incise(context, trace, traced)
		traced += 1
	# Tributaries start lower and stop the moment they meet an existing channel,
	# which is what makes them tributaries and not more main rivers.
	var tributaries := _pick_sources(context, rng, recipe.river_tributaries, true)
	for source: Vector2i in tributaries:
		var trace := _trace(context, wander, source)
		if trace.size() < MIN_TRACE_CELLS:
			continue
		_extend_to_receiver(context, trace)
		_note_termination(context, trace)
		_incise(context, trace, traced)
		traced += 1
	context.refresh_land_mask()
	context.note("%d river(s) carved" % traced)


## A river has to end somewhere that can receive it: the sea, a hollow that will
## hold a lake, another channel, or the edge of the board. Ending halfway down a
## hillside is an error of the generator, so it is counted rather than hidden.
static func _note_termination(context: GenerationContext, trace: Array[Vector2i]) -> void:
	context.river_stats["traced"] = int(context.river_stats["traced"]) + 1
	var last: Vector2i = trace[trace.size() - 1]
	var index := context.cell_index(last)
	var low := context.min_coordinate()
	var high := context.max_coordinate()
	var terminated := (
		context.heights[index] <= context.recipe.ocean_level
		or context.filled[index] > context.heights[index]
		or context.river_cells.has(last)
		# A trace that ends on a cell it already passed has closed a meander loop:
		# the water joins its own channel, which is a receiver like any other.
		or trace.slice(0, trace.size() - 1).has(last)
		or last.x == low or last.x == high or last.y == low or last.y == high
	)
	if terminated:
		context.river_stats["terminated"] = int(context.river_stats["terminated"]) + 1


## The outlet stream of a lake (§3.7 `connect_to_rivers`). It is a river like any
## other — same trace, same incision — except that it starts one step below the
## lake's spill level instead of below its own ground, which is what lets the lake
## keep standing at that level while the stream leaves it.
static func carve_outflow(context: GenerationContext, outlet: Vector2i, spill: int) -> bool:
	var wander := context.seeds.noise(&"rivers_meander", 7.0 / float(context.board_cells), 2)
	var trace := _trace(context, wander, outlet)
	if trace.size() < MIN_TRACE_CELLS:
		return false
	_incise(context, trace, -1, spill - 1)
	context.refresh_land_mask()
	return true


## River heads: high ground that already collects water. Sorted by how much
## drainage arrives, then spaced out, so three rivers are three valleys rather
## than three fingers of the same one.
static func _pick_sources(context: GenerationContext, rng: RandomNumberGenerator, count: int, tributary := false) -> Array[Vector2i]:
	var chosen: Array[Vector2i] = []
	if count <= 0:
		return chosen
	var recipe := context.recipe
	var threshold := _source_height_threshold(context, tributary)
	var candidates: Array[int] = []
	for index in context.cell_count:
		if context.is_land[index] == 0 or context.border_locked[index] != 0:
			continue
		if context.heights[index] < threshold:
			continue
		if context.flow_accum[index] < MIN_SOURCE_ACCUMULATION:
			continue
		if recipe.river_source == MapRecipe.RIVER_SOURCE_MOUNTAINS and context.uplift[index] <= 0.0 and not tributary:
			continue
		candidates.append(index)
	if candidates.is_empty():
		return chosen
	var accumulation := context.flow_accum
	candidates.sort_custom(func(a: int, b: int) -> bool:
		return accumulation[a] > accumulation[b] if not is_equal_approx(accumulation[a], accumulation[b]) else a < b)
	var spacing := maxf(float(context.board_cells) * (0.12 if tributary else 0.22), 3.0)
	for index: int in candidates:
		if chosen.size() >= count:
			break
		var cell := context.cell_of_index(index)
		var far_enough := true
		for taken: Vector2i in chosen:
			if Vector2(cell - taken).length() < spacing:
				far_enough = false
				break
		if far_enough:
			chosen.append(cell)
	# A deterministic shuffle so the order rivers are carved in does not simply
	# follow the accumulation ranking — the biggest valley should not always be
	# the one that reaches the sea first and steals the others' confluences.
	for position in range(chosen.size() - 1, 0, -1):
		var swap := rng.randi_range(0, position)
		var kept := chosen[position]
		chosen[position] = chosen[swap]
		chosen[swap] = kept
	return chosen


static func _source_height_threshold(context: GenerationContext, tributary: bool) -> int:
	var land_heights := PackedInt32Array()
	for index in context.cell_count:
		if context.is_land[index] != 0:
			land_heights.append(context.heights[index])
	if land_heights.is_empty():
		return TerrainGrid.MAX_HEIGHT
	land_heights.sort()
	var percentile := 0.45 if tributary else 0.7
	if context.recipe.river_source == MapRecipe.RIVER_SOURCE_SPRINGS:
		percentile = 0.35 if tributary else 0.5
	return land_heights[mini(int(float(land_heights.size() - 1) * percentile), land_heights.size() - 1)]


## Downstream from a head. The drainage tree already guarantees the route is
## non-increasing on the filled surface; `meander` only chooses between the ties
## it leaves, which is where a river's wandering actually comes from.
static func _trace(context: GenerationContext, wander: FastNoiseLite, source: Vector2i) -> Array[Vector2i]:
	var trace: Array[Vector2i] = []
	var visited: Dictionary = {}
	var cell := source
	var meander := context.recipe.river_meander
	for _step in MAX_TRACE_STEPS:
		if visited.has(cell):
			break
		visited[cell] = true
		trace.append(cell)
		var index := context.cell_index(cell)
		if context.heights[index] <= context.recipe.ocean_level:
			break
		if context.river_cells.has(cell) and trace.size() > 1:
			break
		var next := _next_cell(context, wander, cell, visited, meander)
		if next == cell:
			break
		cell = next
	return trace


## A trace that stopped on open ground has not finished: it walked into a corner
## of its own making. Following the drainage tree from there always leads
## somewhere that can receive the water, because that is what the tree is.
static func _extend_to_receiver(context: GenerationContext, trace: Array[Vector2i]) -> void:
	var visited: Dictionary = {}
	for cell: Vector2i in trace:
		visited[cell] = true
	var cell: Vector2i = trace[trace.size() - 1]
	var low := context.min_coordinate()
	var high := context.max_coordinate()
	for _step in MAX_TRACE_STEPS:
		var index := context.cell_index(cell)
		if context.heights[index] <= context.recipe.ocean_level or context.filled[index] > context.heights[index]:
			return
		# A confluence and the board edge are receivers too, and they are exactly
		# the two the trace loop stops on. Walking past them here would turn a
		# river that had already arrived into one that ends nowhere.
		if context.river_cells.has(cell) and trace.size() > 1:
			return
		if cell.x == low or cell.x == high or cell.y == low or cell.y == high:
			return
		var direction := int(context.flow_dir[index])
		if direction == GenerationContext.NO_FLOW:
			return
		var next: Vector2i = cell + SlopeCatalog.direction_offset(direction)
		if not context.contains(next.x, next.y):
			return
		if visited.has(next):
			# The channel has run into itself: a meander cut off. The water has
			# somewhere to go — its own reach — so this is an arrival, not a river
			# that stops in the middle of a hillside.
			trace.append(next)
			return
		visited[next] = true
		trace.append(next)
		cell = next


static func _next_cell(context: GenerationContext, wander: FastNoiseLite, cell: Vector2i, visited: Dictionary, meander: float) -> Vector2i:
	var index := context.cell_index(cell)
	var here := context.filled[index]
	var best := cell
	var best_score := -INF
	# Two rounds, and the order matters: a cell that actually descends is always
	# preferred to one that merely does not climb. Letting the wander term choose
	# a level neighbour while a lower one was available is how a trace walks into
	# a flat pocket, exhausts it, and ends in the middle of a hillside.
	for require_descent in [true, false]:
		for direction in NEIGHBOURS.size():
			var neighbour: Vector2i = cell + NEIGHBOURS[direction]
			if not context.contains(neighbour.x, neighbour.y) or visited.has(neighbour):
				continue
			var neighbour_index := context.cell_index(neighbour)
			var drop := here - context.filled[neighbour_index]
			if drop < 0 or (require_descent and drop <= 0):
				continue
			var score := wander.get_noise_2d(float(neighbour.x), float(neighbour.y)) * meander * 3.0
			score += float(drop) * 4.0
			score += context.flow_accum[neighbour_index] * 0.002
			if score > best_score:
				best_score = score
				best = neighbour
		if best != cell:
			break
	# The trace has walked itself into a corner: fall back on the drainage tree,
	# which always has an answer where one exists.
	if best == cell:
		var direction := int(context.flow_dir[index])
		if direction != GenerationContext.NO_FLOW:
			var target := cell + SlopeCatalog.direction_offset(direction)
			if context.contains(target.x, target.y) and not visited.has(target):
				return target
	return best


## Cuts the channel. The bed descends monotonically, holds a level for at least
## `MIN_POOL_CELLS`, and every drop is marked with a sill — the cell that keeps
## two pools from becoming one body with two surfaces.
static func _incise(context: GenerationContext, trace: Array[Vector2i], river_index: int, initial_bed: int = NO_INITIAL_BED) -> void:
	var recipe := context.recipe
	var incision := recipe.river_incision
	var floor_level := recipe.ocean_level - 1
	var bed := context.heights[context.cell_index(trace[0])] - incision
	if initial_bed != NO_INITIAL_BED:
		bed = initial_bed
	var widths: Array[int] = recipe.river_width
	for step in trace.size():
		var cell: Vector2i = trace[step]
		var index := context.cell_index(cell)
		var wanted := context.heights[index] - incision
		# The bed follows the ground down as soon as the ground drops, one step at a
		# time. Holding a level for a minimum run was tried and is wrong: on a steep
		# reach it leaves the channel standing above ground that has already fallen
		# away beside it, and the pool then pours out sideways instead of running
		# down the valley. A steep reach is simply a short pool — a rapid — and the
		# planner drops the ones too short to hold water.
		var next_bed := mini(bed, maxi(wanted, bed - 1))
		if next_bed < floor_level:
			next_bed = floor_level
		var t := float(step) / float(maxi(trace.size() - 1, 1))
		var width := maxi(int(round(lerpf(float(widths[0]), float(widths[1]), t))), 1)
		var is_sill := next_bed < bed
		if is_sill:
			# The sill stands at the upper pool's surface, so it is dry from both
			# sides and neither body can leak into the other. It has to span the
			# WHOLE channel: a one-cell dam across a four-cell river is water
			# flowing around it, and the two pools become one body with two
			# surfaces — which the water layer rejects outright.
			_dam_cross_section(context, cell, width, bed + 1, _step_direction(trace, step))
			bed = next_bed
			continue
		bed = next_bed
		_cut_cross_section(context, cell, width, bed, _step_direction(trace, step))
	if recipe.river_delta:
		_spread_delta(context, trace)
	context.note("river %d: %d cells, bed from %d" % [
		river_index, trace.size(), context.heights[context.cell_index(trace[0])],
	])


## The channel at one point along the trace: a disc of the requested width, all of
## it lowered to the bed. Widening by radius rather than along the normal keeps
## the channel connected over the diagonal turns the four-way trace makes.
static func _cut_cross_section(context: GenerationContext, centre: Vector2i, width: int, bed: int, direction: int) -> void:
	var radius := (width - 1) / 2
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if absi(dx) + absi(dz) > radius:
				continue
			var cell := centre + Vector2i(dx, dz)
			if not context.contains(cell.x, cell.y) or context.border_locked[context.cell_index(cell)] != 0:
				continue
			var index := context.cell_index(cell)
			# Set, not lower: a channel with one flank standing lower than its own bed
			# is a channel that leaks. The levee this raises is at most half the
			# river's width and is what a bank is.
			context.heights[index] = bed
			context.is_land[index] = 1 if bed > context.recipe.ocean_level else 0
			var existing: Variant = context.river_cells.get(cell)
			if existing != null and bool((existing as Dictionary)["sill"]):
				continue
			context.river_cells[cell] = {"bed": bed, "sill": false, "direction": direction}


## The sill: a bar ACROSS the channel, raised to the upper pool's surface. It is
## drawn perpendicular to the flow and nowhere else — a disc would reach down the
## channel and dam the cells the trace has not carved yet, which turns the whole
## river into one long weir with nothing behind it.
static func _dam_cross_section(context: GenerationContext, centre: Vector2i, width: int, crest: int, direction: int) -> void:
	var along := SlopeCatalog.direction_offset(direction)
	var across := Vector2i(along.y, -along.x)
	var radius := (width - 1) / 2 + 1
	for step in range(-radius, radius + 1):
		var cell := centre + across * step
		if not context.contains(cell.x, cell.y):
			continue
		var index := context.cell_index(cell)
		if context.border_locked[index] != 0:
			continue
		if step != 0 and not context.river_cells.has(cell) and context.heights[index] >= crest:
			continue
		context.heights[index] = maxi(context.heights[index], crest)
		context.river_cells[cell] = {"bed": crest, "sill": true, "direction": direction}


static func _step_direction(trace: Array[Vector2i], step: int) -> int:
	if step + 1 >= trace.size():
		return _step_direction(trace, maxi(step - 1, 0)) if step > 0 else SlopeCatalog.DIR_S
	var offset: Vector2i = trace[step + 1] - trace[step]
	for direction in NEIGHBOURS.size():
		if NEIGHBOURS[direction] == offset:
			return NEIGHBOUR_DIRECTIONS[direction]
	return SlopeCatalog.DIR_S


## A delta is the mouth splitting where the current loses to the sea. It is only
## meaningful where the river actually reaches the water, which is exactly where
## the trace ends below the ocean level.
static func _spread_delta(context: GenerationContext, trace: Array[Vector2i]) -> void:
	var mouth: Vector2i = trace[trace.size() - 1]
	if context.heights[context.cell_index(mouth)] > context.recipe.ocean_level:
		return
	var bed := context.recipe.ocean_level - 1
	for step in range(maxi(trace.size() - 6, 0), trace.size()):
		var cell: Vector2i = trace[step]
		for offset: Vector2i in NEIGHBOURS:
			var branch := cell + offset
			if not context.contains(branch.x, branch.y):
				continue
			var index := context.cell_index(branch)
			if context.border_locked[index] != 0 or context.heights[index] <= bed:
				continue
			context.heights[index] = bed
			context.is_land[index] = 0
