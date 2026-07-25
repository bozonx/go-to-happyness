class_name TestTerrainMeshing
extends RefCounted

## Chunk meshing and its collision (design_docs/core/grid_terrain_system.md §6, §11).
##
## The mesh is what the player sees and the collision is what everybody walks on,
## and they are built from the same triangles on purpose — so these tests check
## the two together. The cases that matter are the ones where geometry disappears
## or doubles: carved holes, chunk borders, merged flat ground and the seam
## between a ramp and the column it climbs to.

const BOARD_CELLS := 64
## Chunk (0,0) covers cells 0..15 and has ground on every side, so nothing it
## builds is a border artefact.
const INNER_CHUNK := Vector2i(0, 0)


static func run_all() -> void:
	_test_flat_chunk_merges_into_one_quad()
	_test_merge_splits_on_material_and_height()
	_test_step_builds_one_wall_without_cracks()
	_test_hole_removes_mesh_and_collision()
	_test_ramp_meets_its_column_without_a_wall()
	_test_border_chunk_gets_a_skirt()
	_test_collision_faces_match_the_mesh()
	_test_top_only_lod_drops_the_walls()
	_test_empty_chunk_builds_nothing()
	print("    [PASS] Terrain Meshing Tests")


static func _make_grid() -> TerrainGrid:
	var grid := TerrainGrid.new()
	grid.configure(1.0, BOARD_CELLS)
	return grid


static func _build(grid: TerrainGrid, chunk: Vector2i = INNER_CHUNK, lod: int = TerrainChunkMesher.Lod.FULL) -> Dictionary:
	return TerrainChunkMesher.build_chunk(grid, chunk, lod)


static func _vertex_count(result: Dictionary) -> int:
	var mesh: ArrayMesh = result["mesh"]
	return 0 if mesh == null else (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


static func _triangle_count(result: Dictionary) -> int:
	return (result["faces"] as PackedVector3Array).size() / 3


## How many triangles of the collision soup cover the middle of a cell, seen from
## above. Counting triangles per cell would prove nothing once flat ground is
## merged into big quads — the question is whether there is ground over that spot
## at all.
static func _triangles_covering_cell(result: Dictionary, cell: Vector2i) -> int:
	var faces: PackedVector3Array = result["faces"]
	var point := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
	var count := 0
	for triangle in faces.size() / 3:
		var a := faces[triangle * 3]
		var b := faces[triangle * 3 + 1]
		var c := faces[triangle * 3 + 2]
		if _covers(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z), point):
			count += 1
	return count


static func _covers(a: Vector2, b: Vector2, c: Vector2, point: Vector2) -> bool:
	var area := (b - a).cross(c - a)
	# Vertical faces collapse to a line from above and cover nothing.
	if is_zero_approx(area):
		return false
	var first := (b - a).cross(point - a) / area
	var second := (c - b).cross(point - b) / area
	var third := (a - c).cross(point - c) / area
	return first >= 0.0 and second >= 0.0 and third >= 0.0


# --- Greedy merging ---------------------------------------------------------

static func _test_flat_chunk_merges_into_one_quad() -> void:
	var grid := _make_grid()
	var result := _build(grid)
	# 256 flat columns of the same height and material are two triangles, not 512
	# (§11). Nothing is above or below them, so there are no walls either.
	assert(_vertex_count(result) == 4)
	assert(_triangle_count(result) == 2)


static func _test_merge_splits_on_material_and_height() -> void:
	var grid := _make_grid()
	# A different material cannot share a quad even at the same height: the
	# splatmap (§7) and the repose angle (§4.2) are per column.
	for z in 16:
		for x in range(8, 16):
			grid.set_material(Vector2i(x, z), TerrainMaterialCatalog.SAND)
	var split := _build(grid)
	assert(_vertex_count(split) == 8)
	assert(_triangle_count(split) == 4)

	var stepped := _make_grid()
	for z in 16:
		for x in range(8, 16):
			stepped.set_height(Vector2i(x, z), 1)
	var result := _build(stepped)
	# Two merged plateaus, plus one merged wall per side of the raised half: the
	# step inside the chunk, and the three chunk borders where the ground beyond
	# is a step lower. Six quads for 256 columns.
	assert(_vertex_count(result) == 24)
	assert(_triangle_count(result) == 12)


# --- Seams ------------------------------------------------------------------

static func _test_step_builds_one_wall_without_cracks() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(4, 4), 2)
	var result := _build(grid)
	var faces: PackedVector3Array = result["faces"]

	# The raised column is walled on all four sides, once each: the lower
	# neighbour draws nothing, because a shared edge belongs to the higher column.
	var wall_triangles := 0
	var top_of_wall := 2.0 * TerrainGrid.HEIGHT_STEP
	for triangle in faces.size() / 3:
		var a := faces[triangle * 3]
		var b := faces[triangle * 3 + 1]
		var c := faces[triangle * 3 + 2]
		if is_equal_approx(a.y, b.y) and is_equal_approx(b.y, c.y):
			continue
		wall_triangles += 1
		# No crack and no overshoot: every wall spans exactly the two columns it
		# separates.
		for vertex: Vector3 in [a, b, c]:
			assert(is_equal_approx(vertex.y, 0.0) or is_equal_approx(vertex.y, top_of_wall))
	assert(wall_triangles == 8)


static func _test_ramp_meets_its_column_without_a_wall() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(8, 4), 1)
	assert(grid.place_ramp(Vector2i(4, 4), SlopeCatalog.GENTLE, SlopeCatalog.DIR_E))
	var faces: PackedVector3Array = _build(grid)["faces"]

	# Along the ramp's own axis every seam is continuous, so no wall may stand on
	# the boundary the ramp climbs — that is the whole point of a ramp.
	var seam_x := 8.0
	for triangle in faces.size() / 3:
		var a := faces[triangle * 3]
		var b := faces[triangle * 3 + 1]
		var c := faces[triangle * 3 + 2]
		var vertical := is_equal_approx(a.x, b.x) and is_equal_approx(b.x, c.x) and is_equal_approx(a.x, seam_x)
		if not vertical:
			continue
		var flat_top := is_equal_approx(a.y, b.y) and is_equal_approx(b.y, c.y)
		assert(flat_top)
	# The ramp's fractional corner heights exist in the mesh and nowhere else.
	var quarter_step := 0.25 * TerrainGrid.HEIGHT_STEP
	var fractional := 0
	for vertex: Vector3 in faces:
		if not is_equal_approx(fposmod(vertex.y, TerrainGrid.HEIGHT_STEP), 0.0):
			assert(is_equal_approx(fposmod(vertex.y, quarter_step), 0.0))
			fractional += 1
	assert(fractional > 0)


static func _test_border_chunk_gets_a_skirt() -> void:
	var grid := _make_grid()
	var chunk := grid.chunk_of(grid.min_cell())
	var result := _build(grid, chunk)
	var faces: PackedVector3Array = result["faces"]
	assert(not faces.is_empty())
	# Where the board ends the ground falls away instead of showing an open
	# silhouette, and it never rises above the surface it hangs from.
	var lowest := 0.0
	for vertex: Vector3 in faces:
		lowest = minf(lowest, vertex.y)
		assert(vertex.y <= 0.0)
	assert(is_equal_approx(lowest, -TerrainChunkMesher.SKIRT_STEPS * TerrainGrid.HEIGHT_STEP))


# --- Holes (§6) -------------------------------------------------------------

static func _test_hole_removes_mesh_and_collision() -> void:
	var grid := _make_grid()
	var solid := _build(grid)
	grid.set_hole(Vector2i(4, 4), true)
	var carved := _build(grid)

	# No polygons over the carved column — not a transparent shader, so the hole
	# is gone from collision too and nobody bumps into invisible ground.
	assert(_triangles_covering_cell(carved, Vector2i(4, 4)) == 0)
	assert(_triangles_covering_cell(solid, Vector2i(4, 4)) > 0)
	# Its neighbours now end at a hole, so they grow a skirt: the carved cell is
	# an edge of the world, not a gap in a plane.
	var faces: PackedVector3Array = carved["faces"]
	var below_ground := 0
	for vertex: Vector3 in faces:
		if vertex.y < 0.0:
			below_ground += 1
	assert(below_ground > 0)

	# Filling it back in restores exactly what was there.
	grid.set_hole(Vector2i(4, 4), false)
	assert(_triangle_count(_build(grid)) == _triangle_count(solid))


static func _test_empty_chunk_builds_nothing() -> void:
	var grid := _make_grid()
	for z in 16:
		for x in 16:
			grid.set_hole(Vector2i(x, z), true)
	var result := _build(grid)
	# A fully carved chunk produces no mesh at all rather than an empty one, so
	# its body can drop its collision shape entirely.
	assert(result["mesh"] == null)
	assert((result["faces"] as PackedVector3Array).is_empty())

	# So does a chunk that lies completely off the board.
	var outside := _build(grid, Vector2i(64, 64))
	assert(outside["mesh"] == null)


# --- Collision and LOD ------------------------------------------------------

static func _test_collision_faces_match_the_mesh() -> void:
	var grid := _make_grid()
	grid.set_height(Vector2i(4, 4), 3)
	grid.set_hole(Vector2i(9, 9), true)
	var result := _build(grid)
	var faces: PackedVector3Array = result["faces"]
	var mesh: ArrayMesh = result["mesh"]
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	# The collision soup is the indexed mesh expanded — one is not allowed to
	# drift from the other (§6, §11).
	assert(faces.size() % 3 == 0)
	assert(faces.size() == indices.size())
	for position in indices.size():
		assert(faces[position] == vertices[indices[position]])
	# Indexing is what makes a quad cost four vertices instead of six.
	assert(vertices.size() < indices.size())
	# And the shape Godot builds from it is valid.
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	assert(shape.get_faces().size() == faces.size())


static func _test_top_only_lod_drops_the_walls() -> void:
	var grid := _make_grid()
	for z in 16:
		for x in 16:
			grid.set_height(Vector2i(x, z), (x + z) % 3)
	var full := _build(grid)
	var distant := _build(grid, INNER_CHUNK, TerrainChunkMesher.Lod.TOP_ONLY)
	assert(_triangle_count(distant) < _triangle_count(full))

	# Nothing vertical survives, and the ground bodies stand on is still there.
	var faces: PackedVector3Array = distant["faces"]
	for triangle in faces.size() / 3:
		var a := faces[triangle * 3]
		var b := faces[triangle * 3 + 1]
		var c := faces[triangle * 3 + 2]
		assert(is_equal_approx(a.y, b.y) and is_equal_approx(b.y, c.y))
	assert(_triangles_covering_cell(distant, Vector2i(4, 4)) > 0)
