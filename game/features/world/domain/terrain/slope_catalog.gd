class_name SlopeCatalog
extends RefCounted

## One source of truth for terrain slopes (design_docs/core/grid_terrain_system.md §3).
##
## A slope is never a height of its own: it is the authored transition between two
## integer columns. Every slope occupies a whole number of cells horizontally
## (`run`) and a whole number of height steps vertically (`rise`). Nothing outside
## this table can be built, in data or in tools.
##
## `cliff` is the odd one out: it occupies no cells at all (run = 0). It is simply
## the absence of a ramp between two columns of different height, drawn by the
## mesher as a vertical face.

const FLAT := &"flat"
const GENTLE := &"gentle"
const MODERATE := &"moderate"
const STEEP := &"steep"
const VERY_STEEP := &"very_steep"
const PRE_CLIFF := &"pre_cliff"
const CLIFF := &"cliff"

## Ordered by class index (0..6); the position in this array IS the slope class.
const SLOPES: Array = [
	{"id": FLAT, "rise": 0, "run": 1, "angle": 0.0},
	{"id": GENTLE, "rise": 1, "run": 4, "angle": 11.25},
	{"id": MODERATE, "rise": 1, "run": 2, "angle": 22.5},
	{"id": STEEP, "rise": 1, "run": 1, "angle": 45.0},
	{"id": VERY_STEEP, "rise": 2, "run": 1, "angle": 63.4},
	{"id": PRE_CLIFF, "rise": 4, "run": 1, "angle": 76.0},
	{"id": CLIFF, "rise": 0, "run": 0, "angle": 90.0},
]

## Compass directions, clockwise from north. Ramps use the four orthogonal ones;
## the diagonal slots exist so stored data does not have to be remapped when
## diagonal decoration is added later.
const DIR_N := 0
const DIR_NE := 1
const DIR_E := 2
const DIR_SE := 3
const DIR_S := 4
const DIR_SW := 5
const DIR_W := 6
const DIR_NW := 7

const DIRECTION_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]

const ORTHOGONAL_DIRECTIONS: Array[int] = [DIR_N, DIR_E, DIR_S, DIR_W]


static func slope_class_of(slope_id: StringName) -> int:
	for index in SLOPES.size():
		var slope: Dictionary = SLOPES[index]
		if slope["id"] == slope_id:
			return index
	return -1


static func has_slope(slope_id: StringName) -> bool:
	return slope_class_of(slope_id) >= 0


static func id_of_class(slope_class: int) -> StringName:
	if slope_class < 0 or slope_class >= SLOPES.size():
		return FLAT
	return SLOPES[slope_class]["id"]


static func rise_of(slope_id: StringName) -> int:
	var slope_class := slope_class_of(slope_id)
	return 0 if slope_class < 0 else int(SLOPES[slope_class]["rise"])


## Number of cells the slope occupies along its direction. `flat` is a single
## cell with no rise; `cliff` occupies nothing.
static func run_of(slope_id: StringName) -> int:
	var slope_class := slope_class_of(slope_id)
	return 0 if slope_class < 0 else int(SLOPES[slope_class]["run"])


static func angle_degrees_of(slope_id: StringName) -> float:
	var slope_class := slope_class_of(slope_id)
	return 0.0 if slope_class < 0 else float(SLOPES[slope_class]["angle"])


## A ramp is a slope that actually occupies cells and gains height: everything
## between `gentle` and `pre_cliff`. `flat` and `cliff` are not ramps.
static func is_ramp(slope_id: StringName) -> bool:
	return run_of(slope_id) > 0 and rise_of(slope_id) > 0


static func is_orthogonal(direction: int) -> bool:
	return direction >= 0 and direction < 8 and direction % 2 == 0


static func direction_offset(direction: int) -> Vector2i:
	if direction < 0 or direction >= DIRECTION_OFFSETS.size():
		return Vector2i.ZERO
	return DIRECTION_OFFSETS[direction]


## Height gained per cell as a fraction, i.e. rise/run. `cliff` has no run, so it
## gains any height in no distance at all: INF.
static func steps_per_cell_of(slope_id: StringName) -> float:
	var run := run_of(slope_id)
	if run <= 0:
		return INF
	return float(rise_of(slope_id)) / float(run)


static func ramp_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for slope: Dictionary in SLOPES:
		if is_ramp(slope["id"]):
			ids.append(slope["id"])
	return ids
