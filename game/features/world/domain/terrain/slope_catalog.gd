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
##
## The slope CLASS (the index in `SLOPES`) is the stable identity used by data,
## saves and the traveller profiles — the string id is for tools and debugging.
## Everything on the meshing and cascading hot path therefore has a `*_of_class`
## variant that indexes a packed array instead of scanning for a `StringName`.

const FLAT := &"flat"
const SHALLOW := &"shallow"
const GENTLE := &"gentle"
const MODERATE := &"moderate"
const STEEP := &"steep"
const VERY_STEEP := &"very_steep"
const PRE_CLIFF := &"pre_cliff"
const CLIFF := &"cliff"

## Ordered by class index (0..7); the position in this array IS the slope class.
const SLOPES: Array = [
	{"id": FLAT, "rise": 0, "run": 1, "angle": 0.0},
	{"id": SHALLOW, "rise": 1, "run": 8, "angle": 5.625},
	{"id": GENTLE, "rise": 1, "run": 4, "angle": 11.25},
	{"id": MODERATE, "rise": 1, "run": 2, "angle": 22.5},
	{"id": STEEP, "rise": 1, "run": 1, "angle": 45.0},
	{"id": VERY_STEEP, "rise": 2, "run": 1, "angle": 63.4},
	{"id": PRE_CLIFF, "rise": 4, "run": 1, "angle": 76.0},
	{"id": CLIFF, "rise": 0, "run": 0, "angle": 90.0},
]

const CLASS_FLAT := 0
const CLASS_SHALLOW := 1
const CLASS_GENTLE := 2
const CLASS_MODERATE := 3
const CLASS_STEEP := 4
const CLASS_VERY_STEEP := 5
const CLASS_PRE_CLIFF := 6
const CLASS_CLIFF := 7

## Parallel lookups by class, so the mesher and the cascade never scan `SLOPES`.
const RISE_BY_CLASS: Array[int] = [0, 1, 1, 1, 1, 2, 4, 0]
const RUN_BY_CLASS: Array[int] = [1, 8, 4, 2, 1, 1, 1, 0]
const ANGLE_BY_CLASS: Array[float] = [0.0, 5.625, 11.25, 22.5, 45.0, 63.4, 76.0, 90.0]
const CLASS_BY_ID := {
	FLAT: CLASS_FLAT,
	SHALLOW: CLASS_SHALLOW,
	GENTLE: CLASS_GENTLE,
	MODERATE: CLASS_MODERATE,
	STEEP: CLASS_STEEP,
	VERY_STEEP: CLASS_VERY_STEEP,
	PRE_CLIFF: CLASS_PRE_CLIFF,
	CLIFF: CLASS_CLIFF,
}

## Ramp classes ordered gentlest first — the exact order §3.2 walks when it picks
## the flattest slope that fits a boundary.
const RAMP_CLASSES: Array[int] = [
	CLASS_SHALLOW, CLASS_GENTLE, CLASS_MODERATE, CLASS_STEEP, CLASS_VERY_STEEP, CLASS_PRE_CLIFF,
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

## The direction a ramp pointing `direction` would be reversed to.
const OPPOSITE_DIRECTIONS: Array[int] = [DIR_S, DIR_SW, DIR_W, DIR_NW, DIR_N, DIR_NE, DIR_E, DIR_SE]


static func slope_class_of(slope_id: StringName) -> int:
	return int(CLASS_BY_ID.get(slope_id, -1))


static func has_slope(slope_id: StringName) -> bool:
	return CLASS_BY_ID.has(slope_id)


static func is_valid_class(slope_class: int) -> bool:
	return slope_class >= 0 and slope_class < SLOPES.size()


static func id_of_class(slope_class: int) -> StringName:
	if not is_valid_class(slope_class):
		return FLAT
	return SLOPES[slope_class]["id"]


static func rise_of_class(slope_class: int) -> int:
	if not is_valid_class(slope_class):
		return 0
	return RISE_BY_CLASS[slope_class]


## Number of cells the slope occupies along its direction. `flat` is a single
## cell with no rise; `cliff` occupies nothing.
static func run_of_class(slope_class: int) -> int:
	if not is_valid_class(slope_class):
		return 0
	return RUN_BY_CLASS[slope_class]


## A ramp is a slope that actually occupies cells and gains height: everything
## between `shallow` and `pre_cliff`. `flat` and `cliff` are not ramps.
static func is_ramp_class(slope_class: int) -> bool:
	return run_of_class(slope_class) > 0 and rise_of_class(slope_class) > 0


## Height gained per cell as a fraction, i.e. rise/run. `cliff` has no run, so it
## gains any height in no distance at all: INF.
static func steps_per_cell_of_class(slope_class: int) -> float:
	var run := run_of_class(slope_class)
	if run <= 0:
		return INF
	return float(rise_of_class(slope_class)) / float(run)


static func rise_of(slope_id: StringName) -> int:
	return rise_of_class(slope_class_of(slope_id))


static func run_of(slope_id: StringName) -> int:
	return run_of_class(slope_class_of(slope_id))


static func angle_degrees_of(slope_id: StringName) -> float:
	var slope_class := slope_class_of(slope_id)
	return 0.0 if not is_valid_class(slope_class) else ANGLE_BY_CLASS[slope_class]


static func is_ramp(slope_id: StringName) -> bool:
	return is_ramp_class(slope_class_of(slope_id))


static func steps_per_cell_of(slope_id: StringName) -> float:
	return steps_per_cell_of_class(slope_class_of(slope_id))


static func is_orthogonal(direction: int) -> bool:
	return direction >= 0 and direction < 8 and direction % 2 == 0


static func direction_offset(direction: int) -> Vector2i:
	if direction < 0 or direction >= DIRECTION_OFFSETS.size():
		return Vector2i.ZERO
	return DIRECTION_OFFSETS[direction]


static func opposite_direction(direction: int) -> int:
	if direction < 0 or direction >= OPPOSITE_DIRECTIONS.size():
		return direction
	return OPPOSITE_DIRECTIONS[direction]


static func ramp_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for slope_class: int in RAMP_CLASSES:
		ids.append(id_of_class(slope_class))
	return ids
