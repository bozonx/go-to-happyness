class_name NavTerrainField
extends RefCounted

## The shape of the ground as navigation sees it (grid_terrain_system.md §10).
##
## `TerrainGrid` owns the terrain; this is the flattened, routing-shaped view of
## it that `NavGrid` consumes. It holds four things per cell: whether there is
## ground at all, the slope class of the surface a body stands on, and the slope
## class plus signed height delta of the transition to each of the eight neighbours.
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

## Per-cell water state (grid_terrain_system.md §9.7). Water reaches routing as
## three derived bits and a thickness, never as a depth in metres: what a solver
## needs to know is whether a step is possible and what it costs, and the depth
## that decided it belongs to the layer that owns the water.
##
## `WATER_BLOCKS` is set for anything a traveller cannot enter on foot — water
## over one step deep, lava at any depth, a ford swept by a strong current — and
## `WATER_FROZEN` overrides it, because a sheet of ice is a floor over exactly
## that water (§9.6). Which travellers the ice actually carries is the thickness
## against `TravelerProfile.min_ice_thickness`.
const WATER_PRESENT := 1 << 0
const WATER_BLOCKS := 1 << 1
const WATER_FROZEN := 1 << 2
const WATER_LAVA := 1 << 3
const WATER_ICE_SHIFT := 4
const WATER_ICE_MASK := 0x03

## Corner order, clockwise from north-west — `TerrainGrid`'s order.
const CORNER_NW := 0
const CORNER_NE := 1
const CORNER_SE := 2
const CORNER_SW := 3

const DIAGONAL_DISTANCE := 1.41421356237

var cell_size := 1.0
var height_step_metres := 0.5
var board_cells := 0
var board_half_cells := 0

var _ground := PackedByteArray()
var _slope_classes := PackedByteArray()
## Eight entries per cell, indexed by the compass direction of the neighbour.
var _edge_classes := PackedByteArray()
## Signed landing-height delta in metres for every directed edge. Positive is a
## step up, negative is a drop. It is deliberately directed even though the
## slope class is shared by both directions.
var _edge_height_deltas := PackedFloat32Array()
## Four entries per cell (NW, NE, SE, SW) in metres. Standing height is
## interpolated from these, so it is the same surface the mesher emits.
var _corner_heights := PackedFloat32Array()
## Traversal cost multiplier of the surface: material, wear and snow folded
## together by the publisher (`terrain_materials.md` §2, §6.1, §6.2). It is a
## WEIGHT and never a passability — that separation is what lets a blizzard or a
## trodden field update costs without invalidating a single planned route (§7.5).
var _surface_weights := PackedFloat32Array()
## One packed byte per cell: presence, blocking, ice and lava (§9.7). Dry board
## cells hold zero, which is why a field published before water existed still
## reads correctly.
var _water := PackedByteArray()


func configure(next_cell_size: float, next_board_cells: int, next_height_step_metres: float = 0.5) -> void:
	cell_size = next_cell_size
	height_step_metres = maxf(next_height_step_metres, 0.0001)
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
	_edge_height_deltas = PackedFloat32Array()
	_edge_height_deltas.resize(count * DIRECTION_COUNT)
	_corner_heights = PackedFloat32Array()
	_corner_heights.resize(count * 4)
	_surface_weights = PackedFloat32Array()
	_surface_weights.resize(count)
	_surface_weights.fill(1.0)
	_water = PackedByteArray()
	_water.resize(count)


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


## Surface cost multiplier of a cell, always >= 1.0: a natural surface must never
## undercut a built road, or A* would route the whole settlement across it and
## the road layer would stop meaning anything (`terrain_materials.md` §6.5).
func set_surface_weight(cell: Vector2i, multiplier: float) -> void:
	if not is_inside(cell):
		return
	_surface_weights[_index_of(cell)] = maxf(multiplier, 1.0)


## The publisher's whole water statement about a cell, packed into one byte.
## Passing `false` for `present` clears everything, which is what a drained or
## erased cell has to leave behind.
func set_water(cell: Vector2i, present: bool, blocks: bool, frozen: bool, ice_thickness: int, lava: bool) -> void:
	if not is_inside(cell):
		return
	var packed := 0
	if present:
		packed |= WATER_PRESENT
		if blocks:
			packed |= WATER_BLOCKS
		if lava:
			packed |= WATER_LAVA
		if frozen:
			packed |= WATER_FROZEN
			packed |= (clampi(ice_thickness, 0, WATER_ICE_MASK) & WATER_ICE_MASK) << WATER_ICE_SHIFT
	_water[_index_of(cell)] = packed


func set_edge_class(cell: Vector2i, direction: int, edge_class: int) -> void:
	if not is_inside(cell) or direction < 0 or direction >= DIRECTION_COUNT:
		return
	_edge_classes[_index_of(cell) * DIRECTION_COUNT + direction] = clampi(edge_class, 0, CLASS_CLIFF)


func set_edge_height_delta(cell: Vector2i, direction: int, height_delta_metres: float) -> void:
	if not is_inside(cell) or direction < 0 or direction >= DIRECTION_COUNT:
		return
	_edge_height_deltas[_index_of(cell) * DIRECTION_COUNT + direction] = height_delta_metres


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


func surface_weight_at(cell: Vector2i) -> float:
	if not is_inside(cell):
		return 1.0
	return _surface_weights[_index_of(cell)]


func water_flags_at(cell: Vector2i) -> int:
	if not is_inside(cell):
		return 0
	return int(_water[_index_of(cell)])


func is_water(cell: Vector2i) -> bool:
	return (water_flags_at(cell) & WATER_PRESENT) != 0


func is_frozen(cell: Vector2i) -> bool:
	return (water_flags_at(cell) & WATER_FROZEN) != 0


func is_lava(cell: Vector2i) -> bool:
	return (water_flags_at(cell) & WATER_LAVA) != 0


func ice_thickness_at(cell: Vector2i) -> int:
	var flags := water_flags_at(cell)
	if (flags & WATER_FROZEN) == 0:
		return 0
	return (flags >> WATER_ICE_SHIFT) & WATER_ICE_MASK


## Whether water lets this traveller stand here (§9.6, §9.7).
##
## Ice is asked before depth on purpose: a frozen cell is a floor at the surface,
## and how deep the water under it is stops mattering — what matters is whether
## the sheet carries this traveller's weight. Lava is asked before everything,
## because nothing crosses it and no thickness or shallowness changes that.
static func water_allows(water_flags: int, min_ice_thickness: int) -> bool:
	if (water_flags & WATER_PRESENT) == 0:
		return true
	if (water_flags & WATER_LAVA) != 0:
		return false
	if (water_flags & WATER_FROZEN) != 0:
		var thickness := (water_flags >> WATER_ICE_SHIFT) & WATER_ICE_MASK
		return min_ice_thickness > 0 and thickness >= min_ice_thickness
	return (water_flags & WATER_BLOCKS) == 0


func water_allows_at(cell: Vector2i, min_ice_thickness: int) -> bool:
	return water_allows(water_flags_at(cell), min_ice_thickness)


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


## Positive means `to` is above `from`; negative means it is below. Non-neighbour
## and off-board queries return infinity so they can never look like a free step.
func edge_height_delta(from: Vector2i, to: Vector2i) -> float:
	if not is_inside(from) or not is_inside(to):
		return INF
	var direction := direction_of(to - from)
	if direction < 0:
		return INF
	return _edge_height_deltas[_index_of(from) * DIRECTION_COUNT + direction]


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


func slope_angle_degrees(slope_class: int) -> float:
	if slope_class >= CLASS_CLIFF:
		return 90.0
	return rad_to_deg(atan(STEPS_PER_CELL_BY_CLASS[clampi(slope_class, 0, CLASS_CLIFF)] * height_step_metres / maxf(cell_size, 0.0001)))


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
