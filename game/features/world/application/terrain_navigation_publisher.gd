class_name TerrainNavigationPublisher
extends RefCounted

## Translates the terrain into the shape navigation understands (§10).
##
## This is the only place where the terrain vocabulary (`TerrainGrid`,
## `SlopeCatalog`, heights in steps) meets the routing one (`NavTerrainField`,
## plain class numbers, metres). Routing must not know how terrain is stored, and
## terrain must not know what a traveller profile is; both know this class.
##
## The rules it applies, all from §10.1:
##
## - A column with no ground (a hole) is not standable.
## - The surface class of a cell is the class of the slope authored on it, which
##   is what §10.2 charges speed for.
## - The class of an *edge* is the steepness of the transition to that neighbour.
##   A vertical discontinuity between the corners the two cells share is a face,
##   not a slope: no traveller crosses it, whatever its height. Everything else
##   is classified by how much height the step actually gains per cell.

## Vertical mismatch between two shared corners, in height steps, from which the
## boundary counts as a sheer face rather than a slope. Corner lifts move by whole
## steps (`TerrainGrid.corner_heights_into`), so in practice a boundary is either
## continuous or a full step tall; half a step is the safety margin between them.
const FACE_GAP_STEPS := 0.5


## Builds the field and hands it to the grid. One call after the terrain is built
## or loaded; terrain edits during play republish through the same path.
static func publish(terrain: TerrainGrid, nav_grid: NavGrid) -> NavTerrainField:
	if terrain == null or nav_grid == null:
		return null
	var field := build_field(terrain)
	nav_grid.set_terrain_field(field)
	return field


static func build_field(terrain: TerrainGrid) -> NavTerrainField:
	var field := NavTerrainField.new()
	if terrain == null or terrain.board_cells <= 0:
		return field
	field.configure(terrain.cell_size, terrain.board_cells)
	var minimum := terrain.min_cell()
	var maximum := terrain.max_cell()
	# One pass for surfaces, a second for edges: an edge reads both of its cells,
	# and reading a half-written field would make the answer depend on iteration
	# order.
	var corners := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			terrain.corner_heights_into(cell, corners)
			var metres := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
			for corner in 4:
				metres[corner] = corners[corner] * TerrainGrid.HEIGHT_STEP
			field.set_cell(cell, not terrain.is_hole(cell), terrain.slope_class_at(cell), metres)
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			for direction in NavTerrainField.DIRECTION_COUNT:
				var neighbour: Vector2i = cell + NavTerrainField.DIRECTION_OFFSETS[direction]
				field.set_edge_class(cell, direction, edge_class_between(terrain, cell, neighbour, direction))
	return field


## Steepness of the boundary between two adjacent columns, as a catalog class.
static func edge_class_between(terrain: TerrainGrid, from: Vector2i, to: Vector2i, direction: int) -> int:
	if not terrain.is_inside(from) or not terrain.is_inside(to):
		return NavTerrainField.CLASS_CLIFF
	if terrain.is_hole(from) or terrain.is_hole(to):
		return NavTerrainField.CLASS_CLIFF
	if corner_gap_steps(terrain, from, to, direction) >= FACE_GAP_STEPS:
		return NavTerrainField.CLASS_CLIFF
	var rise_steps := absf(
		terrain.height_steps_in_cell(to, 0.5, 0.5) - terrain.height_steps_in_cell(from, 0.5, 0.5)
	)
	return NavTerrainField.class_from_steps_per_cell(rise_steps / NavTerrainField.direction_distance(direction))


## Largest disagreement, in height steps, between the corners the two cells share
## — the height of the vertical face standing between them. Zero means their
## surfaces meet and one can be walked onto from the other.
static func corner_gap_steps(terrain: TerrainGrid, from: Vector2i, to: Vector2i, direction: int) -> float:
	var mapping: Variant = TerrainGrid.SHARED_CORNERS.get(direction)
	if mapping == null:
		mapping = TerrainGrid.SHARED_DIAGONAL_CORNERS.get(direction)
	if mapping == null:
		return INF
	var own := terrain.corner_heights(from)
	var theirs := terrain.corner_heights(to)
	var gap := 0.0
	var pairs: Array = mapping
	for pair in pairs.size() / 2:
		gap = maxf(gap, absf(own[int(pairs[pair * 2])] - theirs[int(pairs[pair * 2 + 1])]))
	return gap
