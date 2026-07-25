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
## Three things keep the cost down, in the order §11 asks for them:
##
## * every corner height in the chunk and its one-cell border is computed once
##   into a local cache, instead of once per cell and again per neighbouring wall;
## * flat tops of equal height and material are merged greedily, so a flat
##   16×16 chunk is two triangles rather than 512;
## * the mesh is indexed, so a quad costs four vertices instead of six.
##
## Colour comes from per-vertex colour for now; the splatmap / triplanar shader of
## §7 replaces it later without changing this geometry.

## Depth of the wall drawn where the ground ends: board border and hole edges.
const SKIRT_STEPS := 4.0

## Detail levels (§11). Distant chunks drop their side faces: the camera is
## isometric and the faces are not visible from there anyway.
enum Lod {
	FULL,
	TOP_ONLY,
}

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

## Cached cells: the chunk plus a one-cell border, so a wall can read its
## neighbour's corners without asking the grid again.
const PADDED_CELLS := TerrainGrid.CHUNK_CELLS + 2

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
## Which axis a wall of this direction runs along, and whether its `near` corner
## is the one with the smaller coordinate on that axis. Walls are merged along it
## exactly like flat tops, so a long cliff is one quad instead of sixteen.
const EDGE_RUNS: Dictionary = {
	SlopeCatalog.DIR_N: {"step": Vector2i(1, 0), "near_first": true},
	SlopeCatalog.DIR_E: {"step": Vector2i(0, 1), "near_first": true},
	SlopeCatalog.DIR_S: {"step": Vector2i(1, 0), "near_first": false},
	SlopeCatalog.DIR_W: {"step": Vector2i(0, 1), "near_first": false},
}

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()

var _grid: TerrainGrid = null
var _origin := Vector2i.ZERO
## Padded caches, indexed by `_padded_index`.
var _corners := PackedFloat32Array()
var _levels := PackedFloat32Array()
var _materials := PackedInt32Array()
var _solid := PackedByteArray()
var _flat := PackedByteArray()
## Cells already merged into an emitted top quad.
var _merged := PackedByteArray()


## Builds one chunk. Returns `{ "mesh": ArrayMesh, "faces": PackedVector3Array }`;
## `mesh` is null for a chunk that produced no geometry (fully carved out, or
## entirely outside the board).
static func build_chunk(grid: TerrainGrid, chunk: Vector2i, lod: int = Lod.FULL) -> Dictionary:
	var mesher := TerrainChunkMesher.new()
	return mesher._build(grid, chunk, lod)


func _build(grid: TerrainGrid, chunk: Vector2i, lod: int) -> Dictionary:
	_grid = grid
	_origin = grid.chunk_origin_cell(chunk)
	_vertices = PackedVector3Array()
	_normals = PackedVector3Array()
	_colors = PackedColorArray()
	_indices = PackedInt32Array()
	_cache_region()

	_add_tops()
	if lod == Lod.FULL:
		_add_walls()

	if _indices.is_empty():
		return {"mesh": null, "faces": PackedVector3Array()}

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"mesh": mesh, "faces": _collision_faces()}


# --- Region cache -----------------------------------------------------------

func _cache_region() -> void:
	var count := PADDED_CELLS * PADDED_CELLS
	_corners = PackedFloat32Array()
	_corners.resize(count * 4)
	_levels = PackedFloat32Array()
	_levels.resize(count)
	_materials = PackedInt32Array()
	_materials.resize(count)
	_solid = PackedByteArray()
	_solid.resize(count)
	_flat = PackedByteArray()
	_flat.resize(count)
	_merged = PackedByteArray()
	_merged.resize(count)

	var scratch := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for padded_z in PADDED_CELLS:
		for padded_x in PADDED_CELLS:
			var cell := _origin + Vector2i(padded_x - 1, padded_z - 1)
			var index := padded_z * PADDED_CELLS + padded_x
			var solid := _grid.is_inside(cell) and not _grid.is_hole(cell)
			_solid[index] = 1 if solid else 0
			if not solid:
				continue
			_grid.corner_heights_into(cell, scratch)
			var corner_base := index * 4
			for corner in 4:
				_corners[corner_base + corner] = scratch[corner]
			_materials[index] = _grid.material_index_at(cell)
			# Level ground is a property of the CORNERS, never of the stored
			# height: §3.4 can lift a whole column's surface a step above the
			# height it stores, and a quad drawn at the stored height would then
			# sit below the walls around it and leave a hole in the ground.
			_levels[index] = scratch[0]
			_flat[index] = 1 if (
				is_equal_approx(scratch[0], scratch[1])
				and is_equal_approx(scratch[1], scratch[2])
				and is_equal_approx(scratch[2], scratch[3])
			) else 0


func _padded_index(local_x: int, local_z: int) -> int:
	return (local_z + 1) * PADDED_CELLS + (local_x + 1)


func _corner_of(index: int, corner: int) -> float:
	return _corners[index * 4 + corner]


# --- Tops -------------------------------------------------------------------

## Greedy merge over flat columns of equal height and material; ramps keep their
## own quad because their four corners differ.
func _add_tops() -> void:
	for local_z in TerrainGrid.CHUNK_CELLS:
		for local_x in TerrainGrid.CHUNK_CELLS:
			var index := _padded_index(local_x, local_z)
			if _solid[index] == 0 or _merged[index] == 1:
				continue
			if _flat[index] == 0:
				_add_shaped_top(local_x, local_z, index)
				continue
			var width := _greedy_width(local_x, local_z, index)
			var depth := _greedy_depth(local_x, local_z, index, width)
			for offset_z in depth:
				for offset_x in width:
					_merged[_padded_index(local_x + offset_x, local_z + offset_z)] = 1
			_add_flat_top(local_x, local_z, width, depth, index)


func _greedy_width(local_x: int, local_z: int, index: int) -> int:
	var width := 1
	while local_x + width < TerrainGrid.CHUNK_CELLS and _matches(_padded_index(local_x + width, local_z), index):
		width += 1
	return width


func _greedy_depth(local_x: int, local_z: int, index: int, width: int) -> int:
	var depth := 1
	while local_z + depth < TerrainGrid.CHUNK_CELLS:
		for offset_x in width:
			if not _matches(_padded_index(local_x + offset_x, local_z + depth), index):
				return depth
		depth += 1
	return depth


func _matches(candidate: int, reference: int) -> bool:
	return (
		_solid[candidate] == 1 and _merged[candidate] == 0 and _flat[candidate] == 1
		and is_equal_approx(_levels[candidate], _levels[reference])
		and _materials[candidate] == _materials[reference]
	)


func _add_flat_top(local_x: int, local_z: int, width: int, depth: int, index: int) -> void:
	var cell_size := _grid.cell_size
	var west := float(_origin.x + local_x) * cell_size
	var north := float(_origin.y + local_z) * cell_size
	var east := west + float(width) * cell_size
	var south := north + float(depth) * cell_size
	var height := _levels[index] * TerrainGrid.HEIGHT_STEP
	var color: Color = MATERIAL_COLORS.get(TerrainMaterialCatalog.id_of_index(_materials[index]), Color.MAGENTA)
	_add_quad(
		Vector3(west, height, north), Vector3(east, height, north),
		Vector3(east, height, south), Vector3(west, height, south),
		Vector3.UP, color,
	)


func _add_shaped_top(local_x: int, local_z: int, index: int) -> void:
	var cell := _origin + Vector2i(local_x, local_z)
	var nw := _corner_position(cell, TerrainGrid.CORNER_NW, index)
	var ne := _corner_position(cell, TerrainGrid.CORNER_NE, index)
	var se := _corner_position(cell, TerrainGrid.CORNER_SE, index)
	var sw := _corner_position(cell, TerrainGrid.CORNER_SW, index)
	# A ramp quad is planar, so one normal per cell describes it exactly.
	var normal := (ne - nw).cross(sw - nw).normalized()
	if normal.y < 0.0:
		normal = -normal
	var color: Color = MATERIAL_COLORS.get(TerrainMaterialCatalog.id_of_index(_materials[index]), Color.MAGENTA)
	_add_quad(nw, ne, se, sw, normal, color)


# --- Walls ------------------------------------------------------------------

func _add_walls() -> void:
	for edge: Dictionary in EDGES:
		_add_walls_for_direction(int(edge["dir"]), int(edge["near"]), int(edge["far"]))


## All walls facing one direction, merged along the axis they run on. Only
## uniform walls merge — a wall under a ramp has two different corner heights and
## keeps its own quad.
func _add_walls_for_direction(direction: int, near_corner: int, far_corner: int) -> void:
	var run: Dictionary = EDGE_RUNS[direction]
	var step: Vector2i = run["step"]
	var visited := PackedByteArray()
	visited.resize(PADDED_CELLS * PADDED_CELLS)
	for local_z in TerrainGrid.CHUNK_CELLS:
		for local_x in TerrainGrid.CHUNK_CELLS:
			var index := _padded_index(local_x, local_z)
			if visited[index] == 1:
				continue
			visited[index] = 1
			var wall := _wall_of(local_x, local_z, index, direction, near_corner, far_corner)
			if wall.is_empty():
				continue
			var last_x := local_x
			var last_z := local_z
			if _is_uniform(wall):
				var next_x := local_x + step.x
				var next_z := local_z + step.y
				while next_x < TerrainGrid.CHUNK_CELLS and next_z < TerrainGrid.CHUNK_CELLS:
					var next_index := _padded_index(next_x, next_z)
					if visited[next_index] == 1:
						break
					var next_wall := _wall_of(next_x, next_z, next_index, direction, near_corner, far_corner)
					if next_wall != wall:
						break
					visited[next_index] = 1
					last_x = next_x
					last_z = next_z
					next_x += step.x
					next_z += step.y
			_emit_wall(local_x, local_z, last_x, last_z, index, direction, near_corner, far_corner, wall, bool(run["near_first"]))


## The wall profile of one cell's edge as `[near_top, far_top, near_bottom,
## far_bottom]`, empty when the ground beyond that edge is level with it. Missing
## ground — board border or a carved hole — falls away by a fixed skirt instead of
## leaving an open silhouette.
func _wall_of(local_x: int, local_z: int, index: int, direction: int, near_corner: int, far_corner: int) -> PackedFloat32Array:
	if _solid[index] == 0:
		return PackedFloat32Array()
	var offset := SlopeCatalog.direction_offset(direction)
	var neighbour_index := _padded_index(local_x + offset.x, local_z + offset.y)
	var near_top := _corner_of(index, near_corner)
	var far_top := _corner_of(index, far_corner)
	var near_bottom := near_top - SKIRT_STEPS
	var far_bottom := far_top - SKIRT_STEPS
	if _solid[neighbour_index] == 1:
		var mapping: Array = NEIGHBOUR_EDGE_CORNERS[direction]
		near_bottom = minf(near_top, _corner_of(neighbour_index, int(mapping[0])))
		far_bottom = minf(far_top, _corner_of(neighbour_index, int(mapping[1])))
	if is_equal_approx(near_top, near_bottom) and is_equal_approx(far_top, far_bottom):
		return PackedFloat32Array()
	return PackedFloat32Array([near_top, far_top, near_bottom, far_bottom])


static func _is_uniform(wall: PackedFloat32Array) -> bool:
	return is_equal_approx(wall[0], wall[1]) and is_equal_approx(wall[2], wall[3])


func _emit_wall(first_x: int, first_z: int, last_x: int, last_z: int, index: int, direction: int, near_corner: int, far_corner: int, wall: PackedFloat32Array, near_first: bool) -> void:
	# `near` is the end of the run the edge starts at, walking clockwise around
	# the cell; for the south and west edges that is the far end of the merge.
	var near_cell := _origin + Vector2i(first_x if near_first else last_x, first_z if near_first else last_z)
	var far_cell := _origin + Vector2i(last_x if near_first else first_x, last_z if near_first else first_z)
	var near_top_position := _corner_position(near_cell, near_corner, index)
	var far_top_position := _corner_position(far_cell, far_corner, index)
	near_top_position.y = wall[0] * TerrainGrid.HEIGHT_STEP
	far_top_position.y = wall[1] * TerrainGrid.HEIGHT_STEP
	var near_bottom_position := Vector3(near_top_position.x, wall[2] * TerrainGrid.HEIGHT_STEP, near_top_position.z)
	var far_bottom_position := Vector3(far_top_position.x, wall[3] * TerrainGrid.HEIGHT_STEP, far_top_position.z)
	var offset := SlopeCatalog.direction_offset(direction)
	var normal := Vector3(float(offset.x), 0.0, float(offset.y))
	var color := CLIFF_COLOR * CLIFF_SHADE_STEEP
	color.a = 1.0
	_add_quad(far_top_position, near_top_position, near_bottom_position, far_bottom_position, normal, color)


# --- Emission ---------------------------------------------------------------

func _corner_position(cell: Vector2i, corner: int, index: int) -> Vector3:
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
	return Vector3(x, _corner_of(index, corner) * TerrainGrid.HEIGHT_STEP, z)


## One quad as two triangles sharing an edge: a, b, c and a, c, d.
func _add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	var base := _vertices.size()
	_vertices.append(a)
	_vertices.append(b)
	_vertices.append(c)
	_vertices.append(d)
	for _index in 4:
		_normals.append(normal)
		_colors.append(color)
	_indices.append(base)
	_indices.append(base + 1)
	_indices.append(base + 2)
	_indices.append(base)
	_indices.append(base + 2)
	_indices.append(base + 3)


## Collision wants the flat triangle soup, not the indexed mesh.
func _collision_faces() -> PackedVector3Array:
	var faces := PackedVector3Array()
	faces.resize(_indices.size())
	for position in _indices.size():
		faces[position] = _vertices[_indices[position]]
	return faces
