class_name TerrainNavigationPublisher
extends RefCounted

## Keeps navigation's view of the ground equal to the terrain (§10).
##
## This is the only place where the terrain vocabulary (`TerrainGrid`,
## `SlopeCatalog`, heights in steps) meets the routing one (`NavTerrainField`,
## plain class numbers, metres). Routing must not know how terrain is stored, and
## terrain must not know what a traveller profile is; both know this class.
##
## It owns the geometry contract between the two grids as well: `configure` sizes
## the `NavGrid` from the `TerrainGrid` instead of trusting two callers to pass
## matching numbers. A half-cell disagreement between them is not an error either
## side can detect — it just silently indexes the wrong column.
##
## Everything it publishes is derived from corner heights, never from the stored
## slope descriptor:
##
## - A column with no ground (a hole) is not standable.
## - The surface class of a cell is how steep its own quad actually is. A cell
##   beside a ramp is tilted by the corner lift (§3.4) while still storing
##   `flat`; reading the descriptor would let a citizen run up it at full speed.
## - The class of an *edge* is the steepness of the transition to that neighbour.
##   A vertical discontinuity between the corners the two cells share is a face,
##   not a slope: no traveller crosses it, whatever its height. Everything else is
##   classified by how much height the step actually gains per cell.

## Vertical mismatch between two shared corners, in height steps, from which the
## boundary counts as a sheer face rather than a slope. Corner lifts move by whole
## steps (`TerrainGrid.corner_heights_into`), so in practice a boundary is either
## continuous or a full step tall; half a step is the safety margin between them.
const FACE_GAP_STEPS := 0.5

## Editing one column moves the corners of its eight neighbours, and an edge is
## owned by both of the cells it joins. So a patch of edited cells invalidates
## surfaces one ring out, and edges one ring beyond that.
const SURFACE_RING := 1
const EDGE_RING := 2

var terrain: TerrainGrid = null
var nav_grid: NavGrid = null
var field: NavTerrainField = null
## The water layer over the same board, when the map has one (§9). Optional: a
## board with no water publishes exactly what it published before water existed.
var water: WaterGrid = null


## Binds the grids together and publishes the whole board once. Pass the editing
## services to keep the field current: every committed edit — brush, ramp, hole,
## water stroke, freeze, undo — republishes exactly the columns it touched.
func configure(
	next_terrain: TerrainGrid,
	next_nav_grid: NavGrid,
	service: TerrainService = null,
	next_water: WaterGrid = null,
	water_service: WaterService = null,
) -> void:
	terrain = next_terrain
	nav_grid = next_nav_grid
	water = next_water
	if terrain == null or nav_grid == null:
		return
	nav_grid.configure(terrain.cell_size, terrain.board_cells)
	publish_all()
	if service != null and not service.edit_committed.is_connected(_on_edit_committed):
		service.edit_committed.connect(_on_edit_committed)
	if water_service != null and not water_service.edit_committed.is_connected(_on_water_committed):
		water_service.edit_committed.connect(_on_water_committed)


## Rebuilds the whole field. Cheap enough to run on load and on a board resize;
## an edit uses `refresh_cells` instead.
func publish_all() -> NavTerrainField:
	if terrain == null:
		return null
	field = build_field(terrain, water)
	if nav_grid != null:
		nav_grid.set_terrain_field(field)
	return field


## Republishes a patch of edited columns and everything their geometry reaches.
##
## Surfaces and edges are written in two passes over two different rings: an edge
## reads the corners of both of its cells, so writing them interleaved would make
## the result depend on iteration order.
func refresh_cells(cells: Array[Vector2i]) -> void:
	if terrain == null or field == null or cells.is_empty():
		return
	var corners := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var neighbour_corners := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for cell: Vector2i in _dilate(cells, SURFACE_RING):
		_write_surface(field, terrain, water, cell, corners)
	for cell: Vector2i in _dilate(cells, EDGE_RING):
		_write_edges(field, terrain, cell, corners, neighbour_corners)
	if nav_grid != null:
		nav_grid.notify_terrain_changed()


## Republishes only the traversal weight of a patch — the whole answer for a
## material, variant, wear or snow edit (`terrain_materials.md` §7.5). No rings
## are needed: unlike a corner height, a surface weight belongs to its own column
## and to nothing around it. Topology is left untouched, so live routes stay
## valid and only their cost changes.
func refresh_weights(cells: Array[Vector2i]) -> void:
	if terrain == null or field == null or cells.is_empty():
		return
	for cell: Vector2i in cells:
		if terrain.is_inside(cell):
			field.set_surface_weight(cell, surface_weight_of(terrain, water, cell))
	if nav_grid != null:
		nav_grid.notify_terrain_weights_changed()


func _on_edit_committed(delta: TerrainDelta) -> void:
	if delta.changes_geometry():
		refresh_cells(delta.cells)
		return
	refresh_weights(delta.cells)


## A water edit always goes through the full path. Every field of a water cell is
## navigational: the level moves the depth, the body decides whether it is lava,
## and freezing turns "no floor" into a floor at the surface (§9.6). There is no
## cost-only water edit to optimise for.
func _on_water_committed(delta: WaterDelta) -> void:
	refresh_cells(delta.cells)


# --- Construction ------------------------------------------------------------

static func build_field(source: TerrainGrid, water_source: WaterGrid = null) -> NavTerrainField:
	var built := NavTerrainField.new()
	if source == null or source.board_cells <= 0:
		return built
	built.configure(source.cell_size, source.board_cells)
	var minimum := source.min_cell()
	var maximum := source.max_cell()
	var corners := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var neighbour_corners := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			_write_surface(built, source, water_source, Vector2i(x, z), corners)
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			_write_edges(built, source, Vector2i(x, z), corners, neighbour_corners)
	return built


## One-call helper for callers that only ever publish once.
static func publish(source: TerrainGrid, target: NavGrid, water_source: WaterGrid = null) -> NavTerrainField:
	if source == null or target == null:
		return null
	var built := build_field(source, water_source)
	target.set_terrain_field(built)
	return built


## Shared conversion buffer. The surface pass runs once per cell of the board, so
## allocating four floats inside it costs one allocation per cell — 65 536 of them
## on a standard map, for a value that is thrown away immediately.
static var _metres_scratch := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


static func _write_surface(target: NavTerrainField, source: TerrainGrid, water_source: WaterGrid, cell: Vector2i, corners: PackedFloat32Array) -> void:
	if not source.is_inside(cell):
		return
	source.corner_heights_into(cell, corners)
	var frozen := water_source != null and water_source.is_frozen(cell) and water_source.is_wet(source, cell)
	if frozen:
		# A frozen cell is walked ON THE ICE, not on the bottom (§9.6). The surface
		# is the water level and it is flat, so the standing height, the slope class
		# and the edges to the bank all have to be read from there — otherwise a
		# citizen crossing a frozen lake walks along the lake bed and the bank is a
		# cliff instead of a step up out of the water.
		var ice_steps := float(water_source.height_of(cell))
		corners[0] = ice_steps
		corners[1] = ice_steps
		corners[2] = ice_steps
		corners[3] = ice_steps
	var metres := _metres_scratch
	for corner in 4:
		metres[corner] = corners[corner] * TerrainGrid.HEIGHT_STEP
	target.set_cell(cell, not source.is_hole(cell), surface_class_of(corners), metres)
	# Material, wear and snow folded into one multiplier (§2, §6.1, §6.2), times
	# what wading costs where the water is shallow enough to wade. It is a cost and
	# never a passability: the ground under a snowdrift is still ground, and the
	# ford under a walker is still a crossing.
	target.set_surface_weight(cell, surface_weight_of(source, water_source, cell))
	_write_water(target, source, water_source, cell)


## What the water layer means to routing, as the four bits and the thickness of
## §9.7. Depth stays behind: routing needs to know that a step is refused, not by
## how many centimetres.
static func _write_water(target: NavTerrainField, source: TerrainGrid, water_source: WaterGrid, cell: Vector2i) -> void:
	if water_source == null or not water_source.is_wet(source, cell):
		target.set_water(cell, false, false, false, 0, false)
		return
	var body := water_source.body_at(cell)
	var lava := body != null and body.is_lava()
	target.set_water(
		cell,
		true,
		lava or not water_source.is_ford(source, cell),
		water_source.is_frozen(cell),
		water_source.ice_thickness_at(cell),
		lava,
	)


## Surface cost of a column: the material multiplier, and the ford penalty where
## there is water shallow enough to wade through (§9.7). Deep water and lava carry
## no weight at all — they are refused by passability, and pricing a step nobody
## may take only makes the number harder to read.
static func surface_weight_of(source: TerrainGrid, water_source: WaterGrid, cell: Vector2i) -> float:
	var weight := source.surface_weight_at(cell)
	if water_source == null or water_source.is_frozen(cell):
		return weight
	if water_source.is_ford(source, cell):
		weight *= WaterGrid.FORD_WEIGHT_MULTIPLIER
	return weight


## Edges are read back out of the field, not recomputed off the terrain. Every
## edge is shared by two cells and every cell has eight of them, so going back to
## `TerrainGrid.corner_heights_into` — a pass over nine columns — would repeat the
## same work about twenty times per cell. The surface pass has already written
## exactly the numbers this needs, which is why the two passes are separate.
## An edge belongs to both of the cells it joins and reads the same way from
## either side: the corner gap is symmetric, the height difference is an absolute
## value and the direction distance is the same both ways. So each edge is
## computed once, from the cell on the north-west side of it, and written into
## both — the four compass directions `N`, `NE`, `E`, `SE` cover every edge of the
## board exactly once. Computing all eight per cell did the work twice.
const HALF_DIRECTION_COUNT := 4


static func _write_edges(target: NavTerrainField, source: TerrainGrid, cell: Vector2i, own: PackedFloat32Array, other: PackedFloat32Array) -> void:
	if not source.is_inside(cell):
		return
	var is_hole := source.is_hole(cell)
	if not is_hole:
		target.corner_heights_into(cell, own)
	var own_centre := target.centre_height(cell)

	for direction in HALF_DIRECTION_COUNT:
		var neighbour: Vector2i = cell + NavTerrainField.DIRECTION_OFFSETS[direction]
		var opposite := direction + HALF_DIRECTION_COUNT
		if not source.is_inside(neighbour):
			# Off the board is a cliff for this cell, and there is no other side.
			target.set_edge_class(cell, direction, NavTerrainField.CLASS_CLIFF)
			continue
		var edge_class := NavTerrainField.CLASS_CLIFF
		if not is_hole and not source.is_hole(neighbour):
			target.corner_heights_into(neighbour, other)
			if corner_gap_metres(own, other, direction) < FACE_GAP_STEPS * TerrainGrid.HEIGHT_STEP:
				var rise_steps := absf(target.centre_height(neighbour) - own_centre) / TerrainGrid.HEIGHT_STEP
				edge_class = NavTerrainField.class_from_steps_per_cell(rise_steps / NavTerrainField.direction_distance(direction))
		target.set_edge_class(cell, direction, edge_class)
		target.set_edge_class(neighbour, opposite, edge_class)

	# The other four directions are written by the neighbour on that side — except
	# where there is no neighbour, at the south and west rim of the board.
	for direction in range(HALF_DIRECTION_COUNT, NavTerrainField.DIRECTION_COUNT):
		if not source.is_inside(cell + NavTerrainField.DIRECTION_OFFSETS[direction]):
			target.set_edge_class(cell, direction, NavTerrainField.CLASS_CLIFF)


# --- Classification ----------------------------------------------------------

## Steepness of a cell's own surface, from the steepest gradient across its quad.
##
## The quad is read the way the mesher builds it — as two triangles — so the
## diagonals count too, divided by the diagonal's length. On an authored ramp this
## reproduces exactly the class the catalog stored (a `gentle` run of four gains a
## quarter step per cell, which is `gentle` again); on a cell tilted only by its
## neighbours' corner lift it produces the class nothing stored.
static func surface_class_of(corners: PackedFloat32Array) -> int:
	var nw := corners[TerrainGrid.CORNER_NW]
	var ne := corners[TerrainGrid.CORNER_NE]
	var se := corners[TerrainGrid.CORNER_SE]
	var sw := corners[TerrainGrid.CORNER_SW]
	var gradient := maxf(
		maxf(absf(nw - ne), absf(sw - se)),
		maxf(absf(nw - sw), absf(ne - se))
	)
	gradient = maxf(gradient, maxf(absf(nw - se), absf(ne - sw)) / NavTerrainField.DIAGONAL_DISTANCE)
	return NavTerrainField.class_from_steps_per_cell(gradient)


## Largest disagreement, in metres, between the corners two adjacent cells share —
## the height of the vertical face standing between them. Zero means their
## surfaces meet and one can be walked onto from the other. An orthogonal
## neighbour shares an edge (two corners), a diagonal one a single point.
static func corner_gap_metres(own: PackedFloat32Array, other: PackedFloat32Array, direction: int) -> float:
	var mapping: Variant = TerrainGrid.SHARED_CORNERS.get(direction)
	if mapping == null:
		mapping = TerrainGrid.SHARED_DIAGONAL_CORNERS.get(direction)
	if mapping == null:
		return INF
	var pairs: Array = mapping
	var gap := 0.0
	for pair in pairs.size() / 2:
		gap = maxf(gap, absf(own[int(pairs[pair * 2])] - other[int(pairs[pair * 2 + 1])]))
	return gap


## Cells within `ring` of any of the given ones, deduplicated. Sorted so a patch
## is republished in the same order on every machine (§4.4 determinism).
static func _dilate(cells: Array[Vector2i], ring: int) -> Array[Vector2i]:
	var seen: Dictionary = {}
	for cell: Vector2i in cells:
		for z in range(cell.y - ring, cell.y + ring + 1):
			for x in range(cell.x - ring, cell.x + ring + 1):
				seen[Vector2i(x, z)] = true
	var result: Array[Vector2i] = []
	for cell: Vector2i in seen:
		result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return result
