class_name TerrainChunkMesher
extends RefCounted

## Turns a region of `TerrainGrid` into one chunk mesh
## (design_docs/core/grid_terrain_system.md §11).
##
## Geometry only: no materials, no nodes. The result carries the triangle soup as
## well, so chunk collision is built from exactly the same polygons the player
## sees — which is what makes a hole (§6) disappear from collision automatically
## instead of leaving an invisible wall in a tunnel mouth.
##
## Each column is drawn as its own flat-topped quad plus vertical faces down to
## the lower neighbour. Cracks are impossible because a shared edge is described
## by the same two corner heights from both sides. Colour comes from per-vertex
## colour for now; the splatmap / triplanar shader of §7 replaces it later without
## changing this geometry.

## Depth of the wall drawn where the ground ends: board border and hole edges.
const SKIRT_STEPS := 4.0

const MATERIAL_COLORS: Dictionary = {
	TerrainMaterialCatalog.GRASS: Color(0.32, 0.49, 0.24),
	TerrainMaterialCatalog.DIRT: Color(0.42, 0.31, 0.20),
	TerrainMaterialCatalog.STONE: Color(0.45, 0.45, 0.47),
	TerrainMaterialCatalog.SAND: Color(0.76, 0.68, 0.45),
	TerrainMaterialCatalog.SNOW: Color(0.86, 0.89, 0.93),
}
## Vertical faces are auto-rock regardless of the column's surface material (§7.2).
const CLIFF_COLOR := Color(0.38, 0.36, 0.33)
const CLIFF_SHADE_STEEP := 0.82

## Edges walked clockwise around a cell, so wall winding is uniform. Each entry is
## the rising direction plus the two cell corners forming that edge, in clockwise
## order seen from above.
const EDGES: Array = [
	{"dir": SlopeCatalog.DIR_N, "near": TerrainGrid.CORNER_NW, "far": TerrainGrid.CORNER_NE},
	{"dir": SlopeCatalog.DIR_E, "near": TerrainGrid.CORNER_NE, "far": TerrainGrid.CORNER_SE},
	{"dir": SlopeCatalog.DIR_S, "near": TerrainGrid.CORNER_SE, "far": TerrainGrid.CORNER_SW},
	{"dir": SlopeCatalog.DIR_W, "near": TerrainGrid.CORNER_SW, "far": TerrainGrid.CORNER_NW},
]
## The neighbour corner sitting on the same spot as ours, per edge above.
const NEIGHBOUR_EDGE_CORNERS: Dictionary = {
	SlopeCatalog.DIR_N: [TerrainGrid.CORNER_SW, TerrainGrid.CORNER_SE],
	SlopeCatalog.DIR_E: [TerrainGrid.CORNER_NW, TerrainGrid.CORNER_SW],
	SlopeCatalog.DIR_S: [TerrainGrid.CORNER_NE, TerrainGrid.CORNER_NW],
	SlopeCatalog.DIR_W: [TerrainGrid.CORNER_SE, TerrainGrid.CORNER_NE],
}

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _grid: TerrainGrid = null


## Builds one chunk. Returns `{ "mesh": ArrayMesh, "faces": PackedVector3Array }`;
## `mesh` is null for a chunk that produced no geometry (fully carved out, or
## entirely outside the board).
static func build_chunk(grid: TerrainGrid, chunk: Vector2i) -> Dictionary:
	var mesher := TerrainChunkMesher.new()
	return mesher._build(grid, chunk)


func _build(grid: TerrainGrid, chunk: Vector2i) -> Dictionary:
	_grid = grid
	_vertices = PackedVector3Array()
	_normals = PackedVector3Array()
	_colors = PackedColorArray()
	var origin := grid.chunk_origin_cell(chunk)
	for offset_z in TerrainGrid.CHUNK_CELLS:
		for offset_x in TerrainGrid.CHUNK_CELLS:
			var cell := origin + Vector2i(offset_x, offset_z)
			if not grid.is_inside(cell) or grid.is_hole(cell):
				continue
			_add_cell(cell)
	if _vertices.is_empty():
		return {"mesh": null, "faces": PackedVector3Array()}

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"mesh": mesh, "faces": _vertices}


func _add_cell(cell: Vector2i) -> void:
	var corners := _grid.corner_heights(cell)
	var color: Color = MATERIAL_COLORS.get(_grid.material_of(cell), Color.MAGENTA)
	_add_top(cell, corners, color)
	for edge: Dictionary in EDGES:
		_add_wall(cell, corners, int(edge["dir"]), int(edge["near"]), int(edge["far"]))


func _add_top(cell: Vector2i, corners: PackedFloat32Array, color: Color) -> void:
	var nw := _corner_position(cell, TerrainGrid.CORNER_NW, corners)
	var ne := _corner_position(cell, TerrainGrid.CORNER_NE, corners)
	var se := _corner_position(cell, TerrainGrid.CORNER_SE, corners)
	var sw := _corner_position(cell, TerrainGrid.CORNER_SW, corners)
	# A ramp quad is planar, so one normal per cell describes it exactly.
	var normal := (ne - nw).cross(sw - nw).normalized()
	if normal.y < 0.0:
		normal = -normal
	_add_triangle(nw, ne, se, normal, color)
	_add_triangle(nw, se, sw, normal, color)


## Vertical face between this cell's edge and the lower ground beyond it. Missing
## ground — board border or a carved hole — falls away by a fixed skirt instead of
## leaving an open silhouette.
func _add_wall(cell: Vector2i, corners: PackedFloat32Array, direction: int, near_corner: int, far_corner: int) -> void:
	var neighbour := cell + SlopeCatalog.direction_offset(direction)
	var near_top := corners[near_corner]
	var far_top := corners[far_corner]
	var near_bottom := near_top - SKIRT_STEPS
	var far_bottom := far_top - SKIRT_STEPS
	if _grid.is_inside(neighbour) and not _grid.is_hole(neighbour):
		var neighbour_corners := _grid.corner_heights(neighbour)
		var mapping: Array = NEIGHBOUR_EDGE_CORNERS[direction]
		near_bottom = minf(near_top, neighbour_corners[int(mapping[0])])
		far_bottom = minf(far_top, neighbour_corners[int(mapping[1])])
	if is_equal_approx(near_top, near_bottom) and is_equal_approx(far_top, far_bottom):
		return

	var near_top_position := _corner_position(cell, near_corner, corners)
	var far_top_position := _corner_position(cell, far_corner, corners)
	var near_bottom_position := Vector3(near_top_position.x, near_bottom * TerrainGrid.HEIGHT_STEP, near_top_position.z)
	var far_bottom_position := Vector3(far_top_position.x, far_bottom * TerrainGrid.HEIGHT_STEP, far_top_position.z)
	var offset := SlopeCatalog.direction_offset(direction)
	var normal := Vector3(float(offset.x), 0.0, float(offset.y))
	var color := CLIFF_COLOR * CLIFF_SHADE_STEEP
	color.a = 1.0
	_add_triangle(far_top_position, near_top_position, near_bottom_position, normal, color)
	_add_triangle(far_top_position, near_bottom_position, far_bottom_position, normal, color)


func _corner_position(cell: Vector2i, corner: int, corners: PackedFloat32Array) -> Vector3:
	var cell_size := _grid.cell_size
	var x := float(cell.x) * cell_size
	var z := float(cell.y) * cell_size
	match corner:
		TerrainGrid.CORNER_NE:
			x += cell_size
		TerrainGrid.CORNER_SE:
			x += cell_size
			z += cell_size
		TerrainGrid.CORNER_SW:
			z += cell_size
	return Vector3(x, corners[corner] * TerrainGrid.HEIGHT_STEP, z)


func _add_triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	_vertices.append(a)
	_vertices.append(b)
	_vertices.append(c)
	for _index in 3:
		_normals.append(normal)
		_colors.append(color)
