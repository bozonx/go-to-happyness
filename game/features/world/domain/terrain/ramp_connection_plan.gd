class_name RampConnectionPlan
extends RefCounted

## Read-only plan for the map editor's "connect heights" gesture.
##
## The two picked columns are anchors. The lower one becomes the foot of the
## ramp, the higher one its top anchor, and the catalog decides whether their
## integer rise and horizontal distance describe a real terrain slope. Uneven
## ground between the anchors is allowed: `TerrainService.connect_ramp` reshapes
## it and writes the slope as one transaction.

const AUTO_CLASS := -1

const REASON_NONE := &""
const REASON_OUTSIDE := &"connection_outside"
const REASON_HOLE := &"connection_hole"
const REASON_SAME_CELL := &"connection_same_cell"
const REASON_SAME_HEIGHT := &"connection_same_height"
const REASON_NOT_STRAIGHT := &"connection_not_straight"
const REASON_NO_MATCH := &"connection_no_match"
const REASON_WRONG_RUN := &"connection_wrong_run"
const REASON_WRONG_RISE := &"connection_wrong_rise"
const REASON_ANCHOR := &"connection_anchor"
const REASON_RAMP := &"connection_ramp"

var requested_class := AUTO_CLASS
var first_cell := Vector2i.ZERO
var second_cell := Vector2i.ZERO
var start_cell := Vector2i.ZERO
var top_cell := Vector2i.ZERO
var direction := SlopeCatalog.DIR_N
var slope_class := AUTO_CLASS
var run := 0
var rise := 0
var segments := 0
var base_height := 0
var reshaped_cells := 0
var cells: Array[Vector2i] = []
## Old same-direction ramp cells replaced by this connection. Cells outside the
## new footprint are flattened by the service in the same transaction.
var replacement_cells: Array[Vector2i] = []
var reason: StringName = REASON_NONE


func is_valid() -> bool:
	return reason.is_empty() and SlopeCatalog.is_ramp_class(slope_class)


static func between(
	grid: TerrainGrid, first: Vector2i, second: Vector2i,
	requested: int = AUTO_CLASS,
) -> RampConnectionPlan:
	var plan := RampConnectionPlan.new()
	plan.requested_class = requested
	plan.first_cell = first
	plan.second_cell = second
	if grid == null or not grid.is_inside(first) or not grid.is_inside(second):
		plan.reason = REASON_OUTSIDE
		return plan
	if first == second:
		plan.reason = REASON_SAME_CELL
		return plan
	if grid.is_hole(first) or grid.is_hole(second):
		plan.reason = REASON_HOLE
		return plan
	var delta := second - first
	if delta.x != 0 and delta.y != 0:
		plan.reason = REASON_NOT_STRAIGHT
		return plan
	var first_height := grid.height_of(first)
	var second_height := grid.height_of(second)
	if first_height == second_height:
		plan.reason = REASON_SAME_HEIGHT
		return plan
	plan.start_cell = first if first_height < second_height else second
	plan.top_cell = second if first_height < second_height else first
	plan.base_height = mini(first_height, second_height)
	plan.run = absi(delta.x) + absi(delta.y)
	plan.rise = absi(second_height - first_height)
	plan.direction = _direction_from(plan.top_cell - plan.start_cell)
	if requested == AUTO_CLASS:
		for candidate: int in SlopeCatalog.RAMP_CLASSES:
			var candidate_rise := SlopeCatalog.rise_of_class(candidate)
			if plan.rise % candidate_rise != 0:
				continue
			var candidate_segments := plan.rise / candidate_rise
			if candidate_segments * SlopeCatalog.run_of_class(candidate) == plan.run:
				plan.slope_class = candidate
				plan.segments = candidate_segments
				break
		if plan.slope_class == AUTO_CLASS:
			plan.reason = REASON_NO_MATCH
			return plan
	elif not SlopeCatalog.is_ramp_class(requested):
		plan.reason = REASON_NO_MATCH
		return plan
	else:
		plan.slope_class = requested
		var requested_rise := SlopeCatalog.rise_of_class(requested)
		if plan.rise % requested_rise != 0:
			plan.reason = REASON_WRONG_RISE
			return plan
		plan.segments = plan.rise / requested_rise
		if plan.segments * SlopeCatalog.run_of_class(requested) != plan.run:
			plan.reason = REASON_WRONG_RUN
			return plan
	return _validate_footprint(grid, plan)


## Reprofiles the whole same-class chain containing `ramp_cell`, keeping its true
## low level and final top anchor. This is different from `between`: a point on an
## existing ramp stores its segment base, not the low plateau the author means.
static func reshape(
	grid: TerrainGrid, ramp_cell: Vector2i, requested: int,
) -> RampConnectionPlan:
	var plan := RampConnectionPlan.new()
	plan.requested_class = requested
	plan.first_cell = ramp_cell
	plan.second_cell = ramp_cell
	if grid == null or not grid.is_ramp_cell(ramp_cell) or not SlopeCatalog.is_ramp_class(requested):
		plan.reason = REASON_RAMP
		return plan
	var old_class := grid.slope_class_at(ramp_cell)
	plan.direction = grid.slope_direction_of(ramp_cell)
	var offset := SlopeCatalog.direction_offset(plan.direction)
	var current_cells := grid.ramp_cells_at(ramp_cell)
	var bottom: Vector2i = current_cells[0]
	var top: Vector2i = grid.ramp_top_anchor_at(ramp_cell)
	# Walk forward to the flat top of a same-profile chain.
	var guard := 0
	while grid.is_ramp_cell(top) and grid.slope_class_at(top) == old_class and grid.slope_direction_of(top) == plan.direction:
		top = grid.ramp_top_anchor_at(top)
		guard += 1
		if guard > MAX_CHAIN_SEGMENTS:
			plan.reason = REASON_RAMP
			return plan
	# Walk backward to the true low plateau.
	guard = 0
	while true:
		var previous := Vector2i(2147483647, 2147483647)
		for touching: Vector2i in grid.ramps_touching(bottom):
			if (
				touching != bottom
				and grid.is_ramp_cell(touching)
				and grid.slope_class_at(touching) == old_class
				and grid.slope_direction_of(touching) == plan.direction
				and grid.ramp_top_anchor_at(touching) == bottom
			):
				previous = grid.ramp_cells_at(touching)[0]
				break
		if previous.x == 2147483647:
			break
		bottom = previous
		guard += 1
		if guard > MAX_CHAIN_SEGMENTS:
			plan.reason = REASON_RAMP
			return plan
	plan.base_height = grid.height_of(bottom)
	plan.rise = grid.height_of(top) - plan.base_height
	var requested_rise := SlopeCatalog.rise_of_class(requested)
	if plan.rise <= 0 or plan.rise % requested_rise != 0:
		plan.reason = REASON_WRONG_RISE
		return plan
	plan.slope_class = requested
	plan.segments = plan.rise / requested_rise
	plan.run = plan.segments * SlopeCatalog.run_of_class(requested)
	plan.start_cell = top - offset * plan.run
	plan.top_cell = top
	plan.first_cell = plan.start_cell
	plan.second_cell = top
	if not grid.is_inside(plan.start_cell):
		plan.reason = REASON_OUTSIDE
		return plan
	return _validate_footprint(grid, plan)


const MAX_CHAIN_SEGMENTS := 64


static func _validate_footprint(grid: TerrainGrid, plan: RampConnectionPlan) -> RampConnectionPlan:
	var offset := SlopeCatalog.direction_offset(plan.direction)
	var replacement_seen: Dictionary = {}
	for step in plan.run:
		var cell := plan.start_cell + offset * step
		plan.cells.append(cell)
		if grid.is_hole(cell):
			plan.reason = REASON_HOLE
			return plan
		if grid.is_anchor(cell):
			plan.reason = REASON_ANCHOR
			return plan
		for ramp_cell: Vector2i in grid.ramps_touching(cell):
			if grid.slope_direction_of(ramp_cell) != plan.direction:
				plan.reason = REASON_RAMP
				return plan
			_collect_replacement_chain(grid, ramp_cell, plan.direction, replacement_seen)
		if grid.height_of(cell) != plan.expected_height_at_step(step):
			plan.reshaped_cells += 1
	if grid.is_ramp_cell(plan.top_cell):
		plan.reason = REASON_RAMP
		return plan
	for cell: Vector2i in replacement_seen:
		plan.replacement_cells.append(cell)
	plan.replacement_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return plan


func expected_height_at_step(step: int) -> int:
	if not SlopeCatalog.is_ramp_class(slope_class):
		return base_height
	return base_height + (step / SlopeCatalog.run_of_class(slope_class)) * SlopeCatalog.rise_of_class(slope_class)


static func _collect_replacement_chain(
	grid: TerrainGrid, ramp_cell: Vector2i, direction: int, seen: Dictionary,
) -> void:
	if seen.has(ramp_cell) or not grid.is_ramp_cell(ramp_cell) or grid.slope_direction_of(ramp_cell) != direction:
		return
	var ramp_cells := grid.ramp_cells_at(ramp_cell)
	if ramp_cells.is_empty():
		return
	for cell: Vector2i in ramp_cells:
		seen[cell] = true
	var start: Vector2i = ramp_cells[0]
	for touching: Vector2i in grid.ramps_touching(start):
		if touching != ramp_cell and grid.ramp_top_anchor_at(touching) == start:
			_collect_replacement_chain(grid, touching, direction, seen)


static func _direction_from(delta: Vector2i) -> int:
	if delta.x > 0:
		return SlopeCatalog.DIR_E
	if delta.x < 0:
		return SlopeCatalog.DIR_W
	return SlopeCatalog.DIR_S if delta.y > 0 else SlopeCatalog.DIR_N
