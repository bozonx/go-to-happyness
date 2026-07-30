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
var base_height := 0
var reshaped_cells := 0
var cells: Array[Vector2i] = []
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
			if SlopeCatalog.run_of_class(candidate) == plan.run and SlopeCatalog.rise_of_class(candidate) == plan.rise:
				plan.slope_class = candidate
				break
		if plan.slope_class == AUTO_CLASS:
			plan.reason = REASON_NO_MATCH
			return plan
	elif not SlopeCatalog.is_ramp_class(requested):
		plan.reason = REASON_NO_MATCH
		return plan
	else:
		plan.slope_class = requested
		if SlopeCatalog.run_of_class(requested) != plan.run:
			plan.reason = REASON_WRONG_RUN
			return plan
		if SlopeCatalog.rise_of_class(requested) != plan.rise:
			plan.reason = REASON_WRONG_RISE
			return plan
	var offset := SlopeCatalog.direction_offset(plan.direction)
	for step in plan.run:
		var cell := plan.start_cell + offset * step
		plan.cells.append(cell)
		if grid.is_hole(cell):
			plan.reason = REASON_HOLE
			return plan
		if grid.is_anchor(cell):
			plan.reason = REASON_ANCHOR
			return plan
		# A cell may be the flat top anchor of a different ramp without storing a
		# slope descriptor itself. Reshaping it would break that ramp just as surely
		# as overwriting one of its occupied cells.
		if not grid.ramps_touching(cell).is_empty():
			plan.reason = REASON_RAMP
			return plan
		if grid.height_of(cell) != plan.base_height:
			plan.reshaped_cells += 1
	if grid.is_ramp_cell(plan.top_cell):
		plan.reason = REASON_RAMP
	return plan


static func _direction_from(delta: Vector2i) -> int:
	if delta.x > 0:
		return SlopeCatalog.DIR_E
	if delta.x < 0:
		return SlopeCatalog.DIR_W
	return SlopeCatalog.DIR_S if delta.y > 0 else SlopeCatalog.DIR_N
