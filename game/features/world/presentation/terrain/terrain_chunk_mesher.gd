class_name TerrainChunkMesher
extends RefCounted

## Turns a region of `TerrainGrid` into one chunk mesh
## (design_docs/engine/grid_terrain_system.md §11).
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
## The mesh has exactly TWO surfaces and never more (`terrain_materials.md` §7.2):
## the tops, sampled by the ground shader through the index map, and the vertical
## faces, sampled triplanar by the cliff shader. A surface per material would be
## hundreds of draw calls on an empty map, which is why the surface material is
## NOT geometry input here: tops carry no material attribute at all, and only the
## faces carry one number — the auto-rock layer of the column above them (§3).

## Depth of the wall drawn where the ground ends: board border and hole edges.
const SKIRT_STEPS := 4.0

## Detail levels (§11). Distant chunks drop their side faces: the camera is
## isometric and the faces are not visible from there anyway.
enum Lod {
	FULL,
	TOP_ONLY,
}

## Surface indices of the built mesh. `build_chunk` reports which of them exist,
## because a chunk with no walls (flat ground, or the top-only LOD) has one.
const SURFACE_TOP := &"top_surface"
const SURFACE_CLIFF := &"cliff_surface"

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

var _top_vertices := PackedVector3Array()
var _top_normals := PackedVector3Array()
## RGB carries an encoded smooth normal. The shaders blend it with the geometric
## normal; geometry, collision and navigation never see that visual choice.
var _top_colors := PackedColorArray()
var _top_indices := PackedInt32Array()
var _wall_vertices := PackedVector3Array()
var _wall_normals := PackedVector3Array()
## COLOR.r of a wall vertex is its auto-rock texture layer / 255 (§3). Faces are
## the only place a material reaches the vertex data at all.
var _wall_colors := PackedColorArray()
var _wall_indices := PackedInt32Array()

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


## Builds one chunk. Returns `{ "mesh": ArrayMesh, "faces": PackedVector3Array,
## "top_surface": int, "cliff_surface": int }`; `mesh` is null for a chunk that
## produced no geometry (fully carved out, or entirely outside the board), and a
## surface index is -1 when that surface is empty.
static func build_chunk(grid: TerrainGrid, chunk: Vector2i, lod: int = Lod.FULL) -> Dictionary:
	var mesher := TerrainChunkMesher.new()
	return mesher._build(grid, chunk, lod)


func _build(grid: TerrainGrid, chunk: Vector2i, lod: int) -> Dictionary:
	_grid = grid
	_origin = grid.chunk_origin_cell(chunk)
	_top_vertices = PackedVector3Array()
	_top_normals = PackedVector3Array()
	_top_colors = PackedColorArray()
	_top_indices = PackedInt32Array()
	_wall_vertices = PackedVector3Array()
	_wall_normals = PackedVector3Array()
	_wall_colors = PackedColorArray()
	_wall_indices = PackedInt32Array()
	_cache_region()

	_add_tops()
	if lod == Lod.FULL:
		_add_walls()
	_encode_smooth_normals()

	if _top_indices.is_empty() and _wall_indices.is_empty():
		return {"mesh": null, "faces": PackedVector3Array(), SURFACE_TOP: -1, SURFACE_CLIFF: -1}

	var mesh := ArrayMesh.new()
	var top_surface := -1
	var cliff_surface := -1
	if not _top_indices.is_empty():
		var top_arrays: Array = []
		top_arrays.resize(Mesh.ARRAY_MAX)
		top_arrays[Mesh.ARRAY_VERTEX] = _top_vertices
		top_arrays[Mesh.ARRAY_NORMAL] = _top_normals
		top_arrays[Mesh.ARRAY_COLOR] = _top_colors
		top_arrays[Mesh.ARRAY_INDEX] = _top_indices
		top_surface = mesh.get_surface_count()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top_arrays)
	if not _wall_indices.is_empty():
		var wall_arrays: Array = []
		wall_arrays.resize(Mesh.ARRAY_MAX)
		wall_arrays[Mesh.ARRAY_VERTEX] = _wall_vertices
		wall_arrays[Mesh.ARRAY_NORMAL] = _wall_normals
		wall_arrays[Mesh.ARRAY_COLOR] = _wall_colors
		wall_arrays[Mesh.ARRAY_INDEX] = _wall_indices
		cliff_surface = mesh.get_surface_count()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wall_arrays)
	return {
		"mesh": mesh, "faces": _collision_faces(),
		SURFACE_TOP: top_surface, SURFACE_CLIFF: cliff_surface,
	}


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

## Greedy merge over flat columns of equal HEIGHT; ramps keep their own quad
## because their four corners differ. Material is deliberately not a criterion any
## more: it reaches the GPU through the index map (§7.3), so a boundary between
## two materials no longer splits a quad and a repainted plain stays two
## triangles.
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
	)


func _add_flat_top(local_x: int, local_z: int, width: int, depth: int, index: int) -> void:
	var cell_size := _grid.cell_size
	var west := float(_origin.x + local_x) * cell_size
	var north := float(_origin.y + local_z) * cell_size
	var east := west + float(width) * cell_size
	var south := north + float(depth) * cell_size
	var height := _levels[index] * TerrainGrid.HEIGHT_STEP
	_add_top_quad(
		Vector3(west, height, north), Vector3(east, height, north),
		Vector3(east, height, south), Vector3(west, height, south),
		Vector3.UP,
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
	_add_top_quad(nw, ne, se, sw, normal)


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
	# The face belongs to the column above it, and its look comes from that
	# column's `cliff_material` — never from the material on top of it (§3).
	var layer := TerrainMaterialVariants.cliff_layer_of_material(_materials[index])
	var color := Color(float(layer) / 255.0, 0.0, 0.0, 1.0)
	_add_wall_quad(far_top_position, near_top_position, near_bottom_position, far_bottom_position, normal, color)


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
func _add_top_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var base := _top_vertices.size()
	_top_vertices.append(a)
	_top_vertices.append(b)
	_top_vertices.append(c)
	_top_vertices.append(d)
	for _index in 4:
		_top_normals.append(normal)
		_top_colors.append(Color.WHITE)
	_append_quad_indices(_top_indices, base)


func _add_wall_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	var base := _wall_vertices.size()
	_wall_vertices.append(a)
	_wall_vertices.append(b)
	_wall_vertices.append(c)
	_wall_vertices.append(d)
	for _index in 4:
		_wall_normals.append(normal)
		_wall_colors.append(color)
	_append_quad_indices(_wall_indices, base)


## Builds one averaged normal for every coincident visual vertex, across both
## terrain surfaces. Vertices stay split (the two shaders and flat normals still
## need that), but their encoded target normal is shared, so a top can visually
## roll into a cliff without changing a single polygon.
func _encode_smooth_normals() -> void:
	var sums: Dictionary = {}
	_accumulate_normals(_top_vertices, _top_normals, sums)
	_accumulate_normals(_wall_vertices, _wall_normals, sums)
	for index in _top_vertices.size():
		var encoded := _encode_normal((sums[_top_vertices[index]] as Vector3).normalized())
		_top_colors[index] = Color(encoded.x, encoded.y, encoded.z, 1.0)
	for index in _wall_vertices.size():
		var encoded := _encode_normal((sums[_wall_vertices[index]] as Vector3).normalized())
		var layer := _wall_colors[index].r
		_wall_colors[index] = Color(layer, encoded.x, encoded.y, encoded.z)


static func _accumulate_normals(vertices: PackedVector3Array, normals: PackedVector3Array, sums: Dictionary) -> void:
	for index in vertices.size():
		var position := vertices[index]
		sums[position] = (sums.get(position, Vector3.ZERO) as Vector3) + normals[index]


static func _encode_normal(normal: Vector3) -> Vector3:
	return normal * 0.5 + Vector3.ONE * 0.5


static func _append_quad_indices(indices: PackedInt32Array, base: int) -> void:
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 3)


## Collision wants the flat triangle soup of BOTH surfaces, not the indexed mesh:
## a body walks on the tops and bumps into the faces, and both have to be there.
func _collision_faces() -> PackedVector3Array:
	var faces := PackedVector3Array()
	faces.resize(_top_indices.size() + _wall_indices.size())
	var position := 0
	for index in _top_indices.size():
		faces[position] = _top_vertices[_top_indices[index]]
		position += 1
	for index in _wall_indices.size():
		faces[position] = _wall_vertices[_wall_indices[index]]
		position += 1
	return faces
