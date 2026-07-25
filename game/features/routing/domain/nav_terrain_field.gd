class_name NavTerrainField
extends RefCounted

## The shape of the ground as navigation sees it (grid_terrain_system.md §10).
##
## `TerrainGrid` owns the terrain; this is the flattened, routing-shaped view of
## it that `NavGrid` consumes. It holds three things per cell: whether there is
## ground at all, the slope class of the surface a body stands on, and the slope
## class of the transition to each of the eight neighbours.
##
## **Passability is a property of the edge, not of the cell** (§10.1). Two free
## columns say nothing about whether one can be reached from the other: a terrace
## beside a terrace is a sheer face, and the only way to express that is on the
## edge between them.
##
## Slope classes are plain integers 0–7 with the meaning `SlopeCatalog` gives
## them (0 flat … 7 cliff/90°). They are deliberately *numbers* here: routing
## must not depend on the terrain feature to know how steep a step is, and the
## publisher that fills this field is the one place the two vocabularies meet.

## Impassable for everything. A cliff is not a steep slope, it is the absence of
## a transition.
const CLASS_CLIFF := 7
const CLASS_COUNT := 8

## Height gained per cell for each class, i.e. rise/run of the catalog entry.
## `CLASS_CLIFF` gains any height in no distance at all.
const STEPS_PER_CELL_BY_CLASS: Array[float] = [0.0, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0, INF]

## §10.2. A slope costs speed before it costs passability; the profile's
## `max_slope_class` decides where passability itself ends.
const PEDESTRIAN_SPEED_BY_CLASS: Array[float] = [1.0, 1.0, 1.0, 1.0, 0.5, 0.25, 0.0, 0.0]
const WHEELED_SPEED_BY_CLASS: Array[float] = [1.0, 1.0, 1.0, 0.7, 0.0, 0.0, 0.0, 0.0]

## Compass directions clockwise from north — the same order and the same offsets
## `SlopeCatalog` uses, so the publisher can hand slope directions over unmapped.
const DIRECTION_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
const DIRECTION_COUNT := 8

## Corner order, clockwise from north-west — `TerrainGrid`'s order.
const CORNER_NW := 0
const CORNER_NE := 1
const CORNER_SE := 2
const CORNER_SW := 3

const DIAGONAL_DISTANCE := 1.41421356237

var cell_size := 1.0
var board_cells := 0
var board_half_cells := 0

var _ground := PackedByteArray()
var _slope_classes := PackedByteArray()
## Eight entries per cell, indexed by the compass direction of the neighbour.
var _edge_classes := PackedByteArray()
## Four entries per cell (NW, NE, SE, SW) in metres. Standing height is
## interpolated from these, so it is the same surface the mesher emits.
var _corner_heights := PackedFloat32Array()


func configure(next_cell_size: float, next_board_cells: int) -> void:
	cell_size = next_cell_size
	board_cells = maxi(next_board_cells, 0)
	board_half_cells = board_cells / 2
	var count := board_cells * board_cells
	_ground = PackedByteArray()
	_ground.resize(count)
	_ground.fill(1)
	_slope_classes = PackedByteArray()
	_slope_classes.resize(count)
	_edge_classes = PackedByteArray()
	_edge_classes.resize(count * DIRECTION_COUNT)
	_corner_heights = PackedFloat32Array()
	_corner_heights.resize(count * 4)


func is_configured() -> bool:
	return board_cells > 0


func is_inside(cell: Vector2i) -> bool:
	return (
		cell.x >= -board_half_cells and cell.x < board_cells - board_half_cells
		and cell.y >= -board_half_cells and cell.y < board_cells - board_half_cells
	)


# --- Writes (publisher only) -------------------------------------------------

## `corner_heights_metres` is NW, NE, SE, SW, in metres.
func set_cell(cell: Vector2i, has_ground: bool, slope_class: int, corner_heights_metres: PackedFloat32Array) -> void:
	if not is_inside(cell):
		return
	var index := _index_of(cell)
	_ground[index] = 1 if has_ground else 0
	_slope_classes[index] = clampi(slope_class, 0, CLASS_CLIFF)
	var base := index * 4
	for corner in 4:
		_corner_heights[base + corner] = corner_heights_metres[corner]


func set_edge_class(cell: Vector2i, direction: int, edge_class: int) -> void:
	if not is_inside(cell) or direction < 0 or direction >= DIRECTION_COUNT:
		return
	_edge_classes[_index_of(cell) * DIRECTION_COUNT + direction] = clampi(edge_class, 0, CLASS_CLIFF)


# --- Reads -------------------------------------------------------------------

func has_ground(cell: Vector2i) -> bool:
	if not is_inside(cell):
		return false
	return _ground[_index_of(cell)] != 0


## Corner heights in metres (NW, NE, SE, SW) into a caller-owned buffer. The
## publisher classifies edges from these rather than recomputing them off the
## terrain: an edge is shared by two cells and read eight times per cell, and
## `TerrainGrid.corner_heights_into` costs a pass over nine columns each time.
func corner_heights_into(cell: Vector2i, result: PackedFloat32Array) -> void:
	if not is_inside(cell):
		result[0] = 0.0
		result[1] = 0.0
		result[2] = 0.0
		result[3] = 0.0
		return
	var base := _index_of(cell) * 4
	for corner in 4:
		result[corner] = _corner_heights[base + corner]


## Height in metres a body standing in the middle of the cell would have.
func centre_height(cell: Vector2i) -> float:
	if not is_inside(cell):
		return 0.0
	var base := _index_of(cell) * 4
	# u = v = 0.5 sits exactly on the NW–SE split, where both triangles agree.
	return (_corner_heights[base + CORNER_NW] + _corner_heights[base + CORNER_SE]) * 0.5


func slope_class_at(cell: Vector2i) -> int:
	if not is_inside(cell):
		return CLASS_CLIFF
	return int(_slope_classes[_index_of(cell)])


## Steepness of the transition from one cell to an adjacent one. Anything that is
## not an actual neighbour — off the board, or two cells apart — is a cliff: the
## caller asked about a step that does not exist, and answering "flat" would let
## a route teleport across it.
func edge_class(from: Vector2i, to: Vector2i) -> int:
	if not is_inside(from) or not is_inside(to):
		return CLASS_CLIFF
	var direction := direction_of(to - from)
	if direction < 0:
		return CLASS_CLIFF
	return int(_edge_classes[_index_of(from) * DIRECTION_COUNT + direction])


static func direction_of(delta: Vector2i) -> int:
	for direction in DIRECTION_COUNT:
		if DIRECTION_OFFSETS[direction] == delta:
			return direction
	return -1


## Horizontal cells crossed by a step in this direction: one orthogonally, the
## diagonal of the cell otherwise.
static func direction_distance(direction: int) -> float:
	if direction < 0 or direction >= DIRECTION_COUNT:
		return 1.0
	var offset := DIRECTION_OFFSETS[direction]
	return DIAGONAL_DISTANCE if offset.x != 0 and offset.y != 0 else 1.0


## The flattest catalog class that still gains at least this much height per
## cell; `CLASS_CLIFF` when nothing in the catalog does.
static func class_from_steps_per_cell(steps_per_cell: float) -> int:
	for slope_class in CLASS_COUNT:
		if steps_per_cell <= STEPS_PER_CELL_BY_CLASS[slope_class] + 0.0001:
			return slope_class
	return CLASS_CLIFF


static func speed_multiplier(slope_class: int, walks_on_foot: bool) -> float:
	var index := clampi(slope_class, 0, CLASS_CLIFF)
	return PEDESTRIAN_SPEED_BY_CLASS[index] if walks_on_foot else WHEELED_SPEED_BY_CLASS[index]


## World-space ground height in metres under a position (§10.4).
##
## The cell is read as the same two triangles the mesher emits, split NW–SE, not
## as a bilinear patch — once a corner can be lifted on its own the quad is no
## longer planar, and the two readings differ by up to half a step in the middle
## of the cell. `TerrainGrid.height_steps_in_cell` resolves it the same way; mesh,
## collision and the height a citizen is placed at have to be one surface, and
## `test_domain_terrain_navigation` asserts the two agree.
func height_at(world_position: Vector3) -> float:
	var cell := cell_from_position(world_position)
	if not is_inside(cell):
		return 0.0
	var base := _index_of(cell) * 4
	var east := clampf(world_position.x / cell_size - float(cell.x), 0.0, 1.0)
	var south := clampf(world_position.z / cell_size - float(cell.y), 0.0, 1.0)
	var nw := _corner_heights[base + CORNER_NW]
	var ne := _corner_heights[base + CORNER_NE]
	var se := _corner_heights[base + CORNER_SE]
	if east >= south:
		# North-east triangle: NW → NE → SE.
		return nw + (ne - nw) * east + (se - ne) * south
	# South-west triangle: NW → SE → SW.
	var sw := _corner_heights[base + CORNER_SW]
	return nw + (sw - nw) * south + (se - sw) * east


func cell_from_position(world_position: Vector3) -> Vector2i:
	return Vector2i(floori(world_position.x / cell_size), floori(world_position.z / cell_size))


func _index_of(cell: Vector2i) -> int:
	return (cell.y + board_half_cells) * board_cells + (cell.x + board_half_cells)
