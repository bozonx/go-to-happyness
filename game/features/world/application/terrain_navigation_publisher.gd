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


## Binds the two grids together and publishes the whole board once. Pass the
## editing service to keep the field current: every committed edit — brush,
## ramp, hole, undo — republishes exactly the columns it touched.
func configure(next_terrain: TerrainGrid, next_nav_grid: NavGrid, service: TerrainService = null) -> void:
	terrain = next_terrain
	nav_grid = next_nav_grid
	if terrain == null or nav_grid == null:
		return
	nav_grid.configure(terrain.cell_size, terrain.board_cells)
	publish_all()
	if service != null and not service.edit_committed.is_connected(_on_edit_committed):
		service.edit_committed.connect(_on_edit_committed)


## Rebuilds the whole field. Cheap enough to run on load and on a board resize;
## an edit uses `refresh_cells` instead.
func publish_all() -> NavTerrainField:
	if terrain == null:
		return null
	field = build_field(terrain)
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
		_write_surface(field, terrain, cell, corners)
	for cell: Vector2i in _dilate(cells, EDGE_RING):
		_write_edges(field, terrain, cell, corners, neighbour_corners)
	if nav_grid != null:
		nav_grid.notify_terrain_changed()


func _on_edit_committed(delta: TerrainDelta) -> void:
	refresh_cells(delta.cells)


# --- Construction ------------------------------------------------------------

static func build_field(source: TerrainGrid) -> NavTerrainField:
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
			_write_surface(built, source, Vector2i(x, z), corners)
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			_write_edges(built, source, Vector2i(x, z), corners, neighbour_corners)
	return built


## One-call helper for callers that only ever publish once.
static func publish(source: TerrainGrid, target: NavGrid) -> NavTerrainField:
	if source == null or target == null:
		return null
	var built := build_field(source)
	target.set_terrain_field(built)
	return built


static func _write_surface(target: NavTerrainField, source: TerrainGrid, cell: Vector2i, corners: PackedFloat32Array) -> void:
	if not source.is_inside(cell):
		return
	source.corner_heights_into(cell, corners)
	var metres := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for corner in 4:
		metres[corner] = corners[corner] * TerrainGrid.HEIGHT_STEP
	target.set_cell(cell, not source.is_hole(cell), surface_class_of(corners), metres)


## Edges are read back out of the field, not recomputed off the terrain. Every
## edge is shared by two cells and every cell has eight of them, so going back to
## `TerrainGrid.corner_heights_into` — a pass over nine columns — would repeat the
## same work about twenty times per cell. The surface pass has already written
## exactly the numbers this needs, which is why the two passes are separate.
static func _write_edges(target: NavTerrainField, source: TerrainGrid, cell: Vector2i, own: PackedFloat32Array, other: PackedFloat32Array) -> void:
	if not source.is_inside(cell):
		return
	if source.is_hole(cell):
		for direction in NavTerrainField.DIRECTION_COUNT:
			target.set_edge_class(cell, direction, NavTerrainField.CLASS_CLIFF)
		return
	target.corner_heights_into(cell, own)
	var own_centre := target.centre_height(cell)
	for direction in NavTerrainField.DIRECTION_COUNT:
		var neighbour: Vector2i = cell + NavTerrainField.DIRECTION_OFFSETS[direction]
		if not source.is_inside(neighbour) or source.is_hole(neighbour):
			target.set_edge_class(cell, direction, NavTerrainField.CLASS_CLIFF)
			continue
		target.corner_heights_into(neighbour, other)
		var edge_class := NavTerrainField.CLASS_CLIFF
		if corner_gap_metres(own, other, direction) < FACE_GAP_STEPS * TerrainGrid.HEIGHT_STEP:
			var rise_steps := absf(target.centre_height(neighbour) - own_centre) / TerrainGrid.HEIGHT_STEP
			edge_class = NavTerrainField.class_from_steps_per_cell(rise_steps / NavTerrainField.direction_distance(direction))
		target.set_edge_class(cell, direction, edge_class)


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
