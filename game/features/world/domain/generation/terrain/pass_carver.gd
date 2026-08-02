class_name PassCarver
extends RefCounted

## Saddles pressed through whatever split the land in two
## (procedural_map_generation.md §3.5 "Перевалы — не украшение, а игровое требование").
##
## A range that cuts the map in half without a single crossing makes half the map
## unreachable, and that is a defect of the map rather than a style. So after the
## heights are integers — and BEFORE hydrology, which has to run on the ground
## that will survive — the land is tested for connectivity and the narrowest
## barriers are pressed down until it is whole again.
##
## The test here uses the height difference directly rather than `NavGrid`: at
## this point in the pipeline no slope has been assigned yet, and the question
## "will a walker get across this boundary" reduces to "is the step at most
## `very_steep`", which is the steepest class a pedestrian may cross
## (`TravelerProfile.MAX_SLOPE_CLASS_PEDESTRIAN`). The real field is checked again
## at the end by the metrics stage, over the published `NavGrid` (§6).

const STAGE := &"passes"
## The steepest boundary a pedestrian crosses: `very_steep` gains two steps in one
## cell.
const MAX_WALKABLE_STEP := SlopeCatalog.RISE_BY_CLASS[SlopeCatalog.CLASS_VERY_STEEP]
## Half-width of a carved pass. Three cells across so a cart-width route exists,
## not only a goat track.
const CORRIDOR_RADIUS := 1
const MAX_PASSES := 12
## Components below this are islets and rocks; forcing a pass to every one of them
## would trench the whole map.
const MIN_COMPONENT_CELLS := 24

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


## Returns how many passes had to be carved. Zero is the good answer and the
## common one; a recipe whose mountains never seal the map pays nothing here.
static func carve(context: GenerationContext) -> int:
	var carved := 0
	for _attempt in MAX_PASSES:
		var components := _walkable_components(context)
		if components.size() <= 1:
			break
		components.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
		var main: Array = components[0]
		var target: Array = components[1]
		if target.size() < MIN_COMPONENT_CELLS:
			break
		var route := _route_between(context, main, target)
		if route.is_empty():
			break
		_press_corridor(context, route)
		carved += 1
	context.refresh_land_mask()
	if carved > 0:
		context.note("%d pass(es) carved to keep the land connected" % carved)
	return carved


## Presses one saddle between two named groups of cells. The pure stage above
## works from its own height model; this entry point exists for the verdict stage,
## which knows something the model cannot — what the published `NavGrid` made of
## the finished ground. Both press the same corridor, so a pass carved late looks
## like a pass carved early.
static func carve_between(context: GenerationContext, main: Array, target: Array) -> bool:
	var route := _route_between(context, main, target)
	if route.is_empty():
		return false
	_press_corridor(context, route)
	context.refresh_land_mask()
	return true


## Components of land under the walking rule, as arrays of buffer indices.
static func _walkable_components(context: GenerationContext) -> Array:
	var seen := PackedByteArray()
	seen.resize(context.cell_count)
	var components: Array = []
	for start in context.cell_count:
		if seen[start] != 0 or context.is_land[start] == 0:
			continue
		seen[start] = 1
		var queue: Array[int] = [start]
		var head := 0
		var component: Array[int] = []
		while head < queue.size():
			var index: int = queue[head]
			head += 1
			component.append(index)
			var cell := context.cell_of_index(index)
			for offset: Vector2i in NEIGHBOURS:
				var neighbour := cell + offset
				if not context.contains(neighbour.x, neighbour.y):
					continue
				var neighbour_index := context.cell_index(neighbour)
				if seen[neighbour_index] != 0 or context.is_land[neighbour_index] == 0:
					continue
				if absi(context.heights[neighbour_index] - context.heights[index]) > MAX_WALKABLE_STEP:
					continue
				seen[neighbour_index] = 1
				queue.append(neighbour_index)
		components.append(component)
	return components


## Shortest chain of land cells from one component to the other, ignoring how
## steep the ground is. That chain IS the barrier: it crosses the ridge at its
## narrowest reachable point, which is where a saddle belongs.
static func _route_between(context: GenerationContext, main: Array, target: Array) -> Array[Vector2i]:
	var parent := PackedInt32Array()
	parent.resize(context.cell_count)
	parent.fill(-2)
	var queue: Array[int] = []
	for index: int in main:
		parent[index] = -1
		queue.append(index)
	var inside_target: Dictionary = {}
	for index: int in target:
		inside_target[index] = true
	var head := 0
	var found := -1
	while head < queue.size():
		var index: int = queue[head]
		head += 1
		if inside_target.has(index):
			found = index
			break
		var cell := context.cell_of_index(index)
		for offset: Vector2i in NEIGHBOURS:
			var neighbour := cell + offset
			if not context.contains(neighbour.x, neighbour.y):
				continue
			var neighbour_index := context.cell_index(neighbour)
			if parent[neighbour_index] != -2 or context.is_land[neighbour_index] == 0:
				continue
			# Border walls are authored to be impassable; a pass carved through one
			# would silently undo the side the recipe asked for.
			if context.border_locked[neighbour_index] != 0:
				continue
			parent[neighbour_index] = index
			queue.append(neighbour_index)
	var route: Array[Vector2i] = []
	if found < 0:
		return route
	var walk := found
	while walk >= 0:
		route.append(context.cell_of_index(walk))
		walk = parent[walk]
	route.reverse()
	return route


## Flattens the barrier along the route until every step of it is walkable, and
## carries the neighbouring cells with it so the result is a corridor rather than
## a one-cell-wide crack no cart can use.
static func _press_corridor(context: GenerationContext, route: Array[Vector2i]) -> void:
	var profile := PackedInt32Array()
	for cell: Vector2i in route:
		profile.append(context.heights[context.cell_index(cell)])
	# Two sweeps: forward bounds each cell against its predecessor, backward
	# against its successor. Together they leave no step above the limit.
	for step in range(1, profile.size()):
		profile[step] = clampi(profile[step], profile[step - 1] - MAX_WALKABLE_STEP, profile[step - 1] + MAX_WALKABLE_STEP)
	for step in range(profile.size() - 2, -1, -1):
		profile[step] = clampi(profile[step], profile[step + 1] - MAX_WALKABLE_STEP, profile[step + 1] + MAX_WALKABLE_STEP)
	for step in route.size():
		var centre: Vector2i = route[step]
		for dz in range(-CORRIDOR_RADIUS, CORRIDOR_RADIUS + 1):
			for dx in range(-CORRIDOR_RADIUS, CORRIDOR_RADIUS + 1):
				var cell := centre + Vector2i(dx, dz)
				if not context.contains(cell.x, cell.y):
					continue
				var index := context.cell_index(cell)
				if context.border_locked[index] != 0:
					continue
				# The corridor is levelled in both directions: a crack too deep to
				# climb out of blocks a pass exactly as a ridge too high to climb
				# over does, and leaving one of the two unfixed makes the loop
				# above run its whole budget without ever joining the halves.
				context.heights[index] = profile[step]
				context.is_land[index] = 1 if profile[step] > context.recipe.ocean_level else 0
