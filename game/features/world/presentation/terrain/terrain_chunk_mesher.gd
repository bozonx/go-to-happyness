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
## Four things keep the cost down, in the order §11 asks for them:
##
## * every corner height in the chunk and its one-cell border is computed once
##   into a local cache, instead of once per cell and again per neighbouring wall;
## * flat tops of equal height and material are merged greedily, so a flat
##   band of a chunk is two triangles rather than 64;
## * the mesh is indexed, so a quad costs four vertices instead of six;
## * **the chunk is emitted in bands and a mesher instance keeps them** (§11
##   "дельта-обновление чанка"). Editing one column re-emits the one or two bands
##   its ring touches and reuses the rest, instead of re-scanning 256 columns and
##   1024 cell edges for a single raised cell.
##
## A mesher is therefore RETAINED per chunk by `GridTerrainWorld`, not thrown away
## after one build. `build_chunk` remains for callers that want a one-shot full
## build (tests, tools) and simply drives the same code with `FULL_BOUNDS`.
##
## The mesh has exactly TWO surfaces and never more (`terrain_materials.md` §7.2):
## the tops, sampled by the ground shader through the index map, and the vertical
## faces, sampled triplanar by the cliff shader. A surface per material would be
## hundreds of draw calls on an empty map, which is why the surface material is
## NOT geometry input here: tops carry no material attribute at all, and only the
## faces carry one number — the auto-rock layer of the column above them (§3).

## Depth of the wall drawn where the ground ends: board border and hole edges.
const SKIRT_STEPS := 4.0
## A shallow change between neighbouring ramp cells is terrain shape, not a
## decorative seam. Only a clearly legible break gets handed to the bevel
## shader; otherwise its highlight would reveal the cell grid across a hill.
const ROUNDABLE_EDGE_MAX_DOT := 0.90630779 # cos(25 degrees)

## Detail levels (§11). Distant chunks drop the faces BETWEEN their columns: the
## camera is isometric and those are not visible from there anyway. They keep the
## skirt — the wall where the ground simply ends — because that one is a
## silhouette, and dropping it opens the board edge and every hole into the void.
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

## Rows of cells one retained geometry band covers. Four is the balance the
## measurement asks for: greedy merging still spans most of a flat chunk (four
## quads instead of one, invisible on screen and in the vertex count), while a
## single-column edit re-emits an eighth of the chunk instead of all of it.
const BAND_CELLS := 4
const BAND_COUNT := TerrainGrid.CHUNK_CELLS / BAND_CELLS

## Cell bounds meaning "everything": the sentinel a full rebuild passes.
const FULL_BOUNDS := Vector4i(-2147483647, -2147483647, 2147483647, 2147483647)

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

## Quantisation of a position when two quads are asked whether they meet on the
## same point or the same line. Positions are built by identical arithmetic on
## both sides, so this only has to survive the last bit of float noise.
const EDGE_QUANTISATION := 4096.0
const DIRECTION_QUANTISATION := 1024.0

## Grown once and sliced afterwards. Index, UV and empty-custom-channel data are
## the same numbers for every quad in every chunk of every map, and appending them
## element by element was a GDScript loop per quad on the rebuild path.
static var _index_template := PackedInt32Array()
static var _uv_template := PackedVector2Array()

# --- Retained per-chunk state -------------------------------------------------

var _grid: TerrainGrid = null
var _chunk := Vector2i.ZERO
var _origin := Vector2i.ZERO
var _built_lod := -1
var _has_bands := false

## Geometry of each band, kept between builds. A band that no edit reached is
## reused verbatim.
var _band_top_vertices: Array[PackedVector3Array] = []
var _band_top_normals: Array[PackedVector3Array] = []
var _band_top_sizes: Array[PackedVector2Array] = []
var _band_wall_vertices: Array[PackedVector3Array] = []
var _band_wall_normals: Array[PackedVector3Array] = []
var _band_wall_sizes: Array[PackedVector2Array] = []
## One entry per wall QUAD: the auto-rock texture layer of the column above it,
## already divided by 255. Colours are assembled in `_encode_smooth_normals`,
## which is the only pass that writes them.
var _band_wall_layers: Array[PackedFloat32Array] = []

## Padded caches, indexed by `_padded_index`.
var _corners := PackedFloat32Array()
var _levels := PackedFloat32Array()
var _materials := PackedInt32Array()
var _solid := PackedByteArray()
var _flat := PackedByteArray()
## Cells already merged into an emitted top quad.
var _merged := PackedByteArray()

## Concatenated buffers of the build in progress.
var _top_vertices := PackedVector3Array()
var _top_normals := PackedVector3Array()
var _top_colors := PackedColorArray()
var _top_uv2 := PackedVector2Array()
var _wall_vertices := PackedVector3Array()
var _wall_normals := PackedVector3Array()
var _wall_colors := PackedColorArray()
var _wall_uv2 := PackedVector2Array()
var _wall_layers := PackedFloat32Array()

## Buffers of the band currently being emitted. Kept as their own members and
## stored back into the band arrays when the band finishes, so emission never
## depends on whether a packed array fetched out of an `Array` aliases it.
var _emit_top_vertices := PackedVector3Array()
var _emit_top_normals := PackedVector3Array()
var _emit_top_sizes := PackedVector2Array()
var _emit_wall_vertices := PackedVector3Array()
var _emit_wall_normals := PackedVector3Array()
var _emit_wall_sizes := PackedVector2Array()
var _emit_wall_layers := PackedFloat32Array()
## Reused by the wall pass, once per direction per band.
var _visited := PackedByteArray()

## One record per quad edge, in parallel arrays the buckets index into.
var _edge_quad := PackedInt32Array()
var _edge_slot := PackedInt32Array()
var _edge_min := PackedFloat32Array()
var _edge_max := PackedFloat32Array()
var _edge_normal := PackedVector3Array()

## The profile `_wall_of` just measured, in height steps.
var _wall_near_top := 0.0
var _wall_far_top := 0.0
var _wall_near_bottom := 0.0
var _wall_far_bottom := 0.0


## One-shot full build, for tests and tools that do not keep a mesher around.
## Returns `{ "mesh": ArrayMesh, "faces": PackedVector3Array, "top_surface": int,
## "cliff_surface": int }`; `mesh` is null for a chunk that produced no geometry
## (fully carved out, or entirely outside the board), and a surface index is -1
## when that surface is empty.
static func build_chunk(grid: TerrainGrid, chunk: Vector2i, lod: int = Lod.FULL, encode_shading: bool = true) -> Dictionary:
	var mesher := TerrainChunkMesher.new()
	mesher.configure(grid, chunk)
	return mesher.build(lod, FULL_BOUNDS, encode_shading)


func configure(grid: TerrainGrid, chunk: Vector2i) -> void:
	_grid = grid
	_chunk = chunk
	_origin = grid.chunk_origin_cell(chunk)
	_built_lod = -1
	_has_bands = false
	_band_top_vertices = []
	_band_top_normals = []
	_band_top_sizes = []
	_band_wall_vertices = []
	_band_wall_normals = []
	_band_wall_sizes = []
	_band_wall_layers = []
	for _band in BAND_COUNT:
		_band_top_vertices.append(PackedVector3Array())
		_band_top_normals.append(PackedVector3Array())
		_band_top_sizes.append(PackedVector2Array())
		_band_wall_vertices.append(PackedVector3Array())
		_band_wall_normals.append(PackedVector3Array())
		_band_wall_sizes.append(PackedVector2Array())
		_band_wall_layers.append(PackedFloat32Array())


## Builds the chunk. `bounds` is the cell range that moved since the last build,
## in absolute cell coordinates (`FULL_BOUNDS` for everything). Bands outside it
## are reused.
##
## `encode_shading` builds the data the smoothing treatments need: one averaged
## normal per coincident vertex, and the roundable-edge mask with its bevel
## normals. None of it is read while `full_smoothing` and `edge_rounding` are both
## off — which is how the game and the map editor run — and computing it anyway
## was the largest remaining cost of a rebuild. `GridTerrainWorld` re-queues every
## chunk when a treatment is switched on, so the data is there the moment it is
## asked for.
func build(lod: int, bounds: Vector4i = FULL_BOUNDS, encode_shading: bool = true) -> Dictionary:
	# The corner cache is always rebuilt whole. It is the cheap half of the work
	# (measured well under a millisecond) and making it partial would mean
	# reasoning about a ring of influence twice — once for the cache and once for
	# the bands. One of those is enough.
	_cache_region()

	var first_band := 0
	var last_band := BAND_COUNT - 1
	if _has_bands and lod == _built_lod and bounds != FULL_BOUNDS:
		# One cell out: an edit changes the walls of the columns beside it (the
		# higher of the pair emits the face) and lifts their shared corners (§3.4).
		var local_min := bounds.y - 1 - _origin.y
		var local_max := bounds.w + 1 - _origin.y
		first_band = clampi(floori(float(local_min) / float(BAND_CELLS)), 0, BAND_COUNT - 1)
		last_band = clampi(floori(float(local_max) / float(BAND_CELLS)), 0, BAND_COUNT - 1)

	for band in range(first_band, last_band + 1):
		_build_band(band, lod)
	_built_lod = lod
	_has_bands = true

	_concatenate_bands()
	return _assemble(encode_shading)


# --- Region cache -----------------------------------------------------------

func _cache_region() -> void:
	var count := PADDED_CELLS * PADDED_CELLS
	if _corners.size() != count * 4:
		_corners.resize(count * 4)
		_levels.resize(count)
		_materials.resize(count)
		_solid.resize(count)
		_flat.resize(count)
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
			_corners[corner_base] = scratch[0]
			_corners[corner_base + 1] = scratch[1]
			_corners[corner_base + 2] = scratch[2]
			_corners[corner_base + 3] = scratch[3]
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


# --- Bands ------------------------------------------------------------------

func _build_band(band: int, lod: int) -> void:
	_emit_top_vertices = PackedVector3Array()
	_emit_top_normals = PackedVector3Array()
	_emit_top_sizes = PackedVector2Array()
	_emit_wall_vertices = PackedVector3Array()
	_emit_wall_normals = PackedVector3Array()
	_emit_wall_sizes = PackedVector2Array()
	_emit_wall_layers = PackedFloat32Array()
	# Merge bookkeeping is band-local: a greedy run never crosses into a band the
	# caller may be reusing, which is exactly what makes the reuse sound.
	_merged.fill(0)
	var first_row := band * BAND_CELLS
	var last_row := first_row + BAND_CELLS
	_add_tops(first_row, last_row)
	_add_walls(first_row, last_row, lod)
	_band_top_vertices[band] = _emit_top_vertices
	_band_top_normals[band] = _emit_top_normals
	_band_top_sizes[band] = _emit_top_sizes
	_band_wall_vertices[band] = _emit_wall_vertices
	_band_wall_normals[band] = _emit_wall_normals
	_band_wall_sizes[band] = _emit_wall_sizes
	_band_wall_layers[band] = _emit_wall_layers


func _concatenate_bands() -> void:
	_top_vertices = PackedVector3Array()
	_top_normals = PackedVector3Array()
	_top_uv2 = PackedVector2Array()
	_wall_vertices = PackedVector3Array()
	_wall_normals = PackedVector3Array()
	_wall_uv2 = PackedVector2Array()
	_wall_layers = PackedFloat32Array()
	for band in BAND_COUNT:
		_top_vertices.append_array(_band_top_vertices[band])
		_top_normals.append_array(_band_top_normals[band])
		_top_uv2.append_array(_band_top_sizes[band])
		_wall_vertices.append_array(_band_wall_vertices[band])
		_wall_normals.append_array(_band_wall_normals[band])
		_wall_uv2.append_array(_band_wall_sizes[band])
		_wall_layers.append_array(_band_wall_layers[band])


# --- Tops -------------------------------------------------------------------

## Greedy merge over flat columns of equal HEIGHT; ramps keep their own quad
## because their four corners differ. Material is deliberately not a criterion any
## more: it reaches the GPU through the index map (§7.3), so a boundary between
## two materials no longer splits a quad and a repainted plain stays two
## triangles.
func _add_tops(first_row: int, last_row: int) -> void:
	for local_z in range(first_row, last_row):
		for local_x in TerrainGrid.CHUNK_CELLS:
			var index := _padded_index(local_x, local_z)
			if _solid[index] == 0 or _merged[index] == 1:
				continue
			if _flat[index] == 0:
				_add_shaped_top(local_x, local_z, index)
				continue
			var width := _greedy_width(local_x, local_z, index)
			var depth := _greedy_depth(local_x, local_z, index, width, last_row)
			for offset_z in depth:
				for offset_x in width:
					_merged[_padded_index(local_x + offset_x, local_z + offset_z)] = 1
			_add_flat_top(local_x, local_z, width, depth, index)


func _greedy_width(local_x: int, local_z: int, index: int) -> int:
	var width := 1
	while local_x + width < TerrainGrid.CHUNK_CELLS and _matches(_padded_index(local_x + width, local_z), index):
		width += 1
	return width


func _greedy_depth(local_x: int, local_z: int, index: int, width: int, last_row: int) -> int:
	var depth := 1
	while local_z + depth < last_row:
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

func _add_walls(first_row: int, last_row: int, lod: int) -> void:
	var skirts_only := lod == Lod.TOP_ONLY
	for edge: Dictionary in EDGES:
		_add_walls_for_direction(int(edge["dir"]), int(edge["near"]), int(edge["far"]), first_row, last_row, skirts_only)


## All walls facing one direction inside one band, merged along the axis they run
## on. Only uniform walls merge — a wall under a ramp has two different corner
## heights and keeps its own quad. The merge stops at the band edge for the same
## reason the greedy top merge does.
func _add_walls_for_direction(direction: int, near_corner: int, far_corner: int, first_row: int, last_row: int, skirts_only: bool) -> void:
	var run: Dictionary = EDGE_RUNS[direction]
	var step: Vector2i = run["step"]
	var near_first := bool(run["near_first"])
	var offset := SlopeCatalog.direction_offset(direction)
	var neighbour_mapping: Array = NEIGHBOUR_EDGE_CORNERS[direction]
	var neighbour_near := int(neighbour_mapping[0])
	var neighbour_far := int(neighbour_mapping[1])
	var visited := _visited
	if visited.size() != PADDED_CELLS * PADDED_CELLS:
		visited.resize(PADDED_CELLS * PADDED_CELLS)
		_visited = visited
	visited.fill(0)
	var neighbour_step := offset.y * PADDED_CELLS + offset.x
	for local_z in range(first_row, last_row):
		var row_base := (local_z + 1) * PADDED_CELLS + 1
		for local_x in TerrainGrid.CHUNK_CELLS:
			var index := row_base + local_x
			if visited[index] == 1:
				continue
			visited[index] = 1
			if not _wall_of(index, index + neighbour_step, near_corner, far_corner, neighbour_near, neighbour_far, skirts_only):
				continue
			var near_top := _wall_near_top
			var far_top := _wall_far_top
			var near_bottom := _wall_near_bottom
			var far_bottom := _wall_far_bottom
			var last_x := local_x
			var last_z := local_z
			if is_equal_approx(near_top, far_top) and is_equal_approx(near_bottom, far_bottom):
				var next_x := local_x + step.x
				var next_z := local_z + step.y
				while next_x < TerrainGrid.CHUNK_CELLS and next_z < last_row:
					var next_index := (next_z + 1) * PADDED_CELLS + 1 + next_x
					if visited[next_index] == 1:
						break
					if not _wall_of(next_index, next_index + neighbour_step, near_corner, far_corner, neighbour_near, neighbour_far, skirts_only):
						break
					if (
						_wall_near_top != near_top or _wall_far_top != far_top
						or _wall_near_bottom != near_bottom or _wall_far_bottom != far_bottom
					):
						break
					visited[next_index] = 1
					last_x = next_x
					last_z = next_z
					next_x += step.x
					next_z += step.y
			_emit_wall(
				local_x, local_z, last_x, last_z, index, offset, near_corner, far_corner,
				near_top, far_top, near_bottom, far_bottom, near_first,
			)


## The wall profile of one cell's edge, written into `_wall_*`; false when the
## ground beyond that edge is level with it and there is no wall at all. Missing
## ground — board border or a carved hole — falls away by a fixed skirt instead of
## leaving an open silhouette.
##
## Returning the profile as a `PackedFloat32Array` allocated one of those per
## call, and this is called four times per cell of the chunk — a thousand
## throwaway arrays per rebuild, which was most of what a FLAT chunk cost.
##
## `skirts_only` is the distant LOD: the faces between two solid columns are the
## ones the isometric camera cannot see at that range, so they go; the skirt where
## the ground ENDS is the outline of the board and of every hole, and stays.
func _wall_of(index: int, neighbour_index: int, near_corner: int, far_corner: int, neighbour_near: int, neighbour_far: int, skirts_only: bool) -> bool:
	if _solid[index] == 0:
		return false
	var neighbour_solid := _solid[neighbour_index] == 1
	if skirts_only and neighbour_solid:
		return false
	var corner_base := index * 4
	var near_top := _corners[corner_base + near_corner]
	var far_top := _corners[corner_base + far_corner]
	var near_bottom := near_top - SKIRT_STEPS
	var far_bottom := far_top - SKIRT_STEPS
	if neighbour_solid:
		var neighbour_base := neighbour_index * 4
		near_bottom = minf(near_top, _corners[neighbour_base + neighbour_near])
		far_bottom = minf(far_top, _corners[neighbour_base + neighbour_far])
	if is_equal_approx(near_top, near_bottom) and is_equal_approx(far_top, far_bottom):
		return false
	_wall_near_top = near_top
	_wall_far_top = far_top
	_wall_near_bottom = near_bottom
	_wall_far_bottom = far_bottom
	return true


func _emit_wall(first_x: int, first_z: int, last_x: int, last_z: int, index: int, offset: Vector2i, near_corner: int, far_corner: int, near_top: float, far_top: float, near_bottom: float, far_bottom: float, near_first: bool) -> void:
	# `near` is the end of the run the edge starts at, walking clockwise around
	# the cell; for the south and west edges that is the far end of the merge.
	var near_cell := _origin + Vector2i(first_x if near_first else last_x, first_z if near_first else last_z)
	var far_cell := _origin + Vector2i(last_x if near_first else first_x, last_z if near_first else first_z)
	# Only X and Z are taken from the cached corners; the heights come from the
	# merged profile below, which is why the padded index of the run's first cell
	# is the right one to pass for either end.
	var near_top_position := _corner_position(near_cell, near_corner, index)
	var far_top_position := _corner_position(far_cell, far_corner, index)
	near_top_position.y = near_top * TerrainGrid.HEIGHT_STEP
	far_top_position.y = far_top * TerrainGrid.HEIGHT_STEP
	var near_bottom_position := Vector3(near_top_position.x, near_bottom * TerrainGrid.HEIGHT_STEP, near_top_position.z)
	var far_bottom_position := Vector3(far_top_position.x, far_bottom * TerrainGrid.HEIGHT_STEP, far_top_position.z)
	var normal := Vector3(float(offset.x), 0.0, float(offset.y))
	# The face belongs to the column above it, and its look comes from that
	# column's `cliff_material` — never from the material on top of it (§3).
	var layer := TerrainMaterialVariants.cliff_layer_of_material(_materials[index])
	_add_wall_quad(far_top_position, near_top_position, near_bottom_position, far_bottom_position, normal, float(layer) / 255.0)


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
	_emit_top_vertices.append(a)
	_emit_top_vertices.append(b)
	_emit_top_vertices.append(c)
	_emit_top_vertices.append(d)
	_emit_top_normals.append(normal)
	_emit_top_normals.append(normal)
	_emit_top_normals.append(normal)
	_emit_top_normals.append(normal)
	_append_quad_size(_emit_top_sizes, a, b, c)


func _add_wall_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, layer: float) -> void:
	_emit_wall_vertices.append(a)
	_emit_wall_vertices.append(b)
	_emit_wall_vertices.append(c)
	_emit_wall_vertices.append(d)
	_emit_wall_normals.append(normal)
	_emit_wall_normals.append(normal)
	_emit_wall_normals.append(normal)
	_emit_wall_normals.append(normal)
	_append_quad_size(_emit_wall_sizes, a, b, c)
	_emit_wall_layers.append(layer)


## UV2 initially carries the quad's size in CELLS, not metres.
## `_encode_roundable_edges` later packs a four-bit adjacency mask into the
## integer part of X, and a chunk is at most `CHUNK_CELLS` wide — so the width can
## never reach the 100 the packing divides by, whatever `cell_size` the map chose.
## In metres that invariant silently broke on any board with cells wider than
## 6.25 m. The shader multiplies the size back by `cell_size`.
func _append_quad_size(sizes: PackedVector2Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var cell_size := maxf(_grid.cell_size, 0.0001)
	var size := Vector2(a.distance_to(b) / cell_size, b.distance_to(c) / cell_size)
	sizes.append(size)
	sizes.append(size)
	sizes.append(size)
	sizes.append(size)


# --- Assembly ---------------------------------------------------------------

func _assemble(encode_shading: bool) -> Dictionary:
	var top_quads := _top_vertices.size() / 4
	var wall_quads := _wall_vertices.size() / 4
	if top_quads == 0 and wall_quads == 0:
		return {"mesh": null, "faces": PackedVector3Array(), SURFACE_TOP: -1, SURFACE_CLIFF: -1}

	_top_colors = PackedColorArray()
	_top_colors.resize(_top_vertices.size())
	_wall_colors = PackedColorArray()
	_wall_colors.resize(_wall_vertices.size())
	var top_edge_normals: Array
	if encode_shading:
		top_edge_normals = _encode_roundable_edges(top_quads, wall_quads)
		_encode_smooth_normals()
	else:
		top_edge_normals = _plain_shading(top_quads, wall_quads)

	var mesh := ArrayMesh.new()
	var top_surface := -1
	var cliff_surface := -1
	if top_quads > 0:
		var top_arrays: Array = []
		top_arrays.resize(Mesh.ARRAY_MAX)
		top_arrays[Mesh.ARRAY_VERTEX] = _top_vertices
		top_arrays[Mesh.ARRAY_NORMAL] = _top_normals
		top_arrays[Mesh.ARRAY_COLOR] = _top_colors
		top_arrays[Mesh.ARRAY_TEX_UV] = _uv_for(top_quads)
		top_arrays[Mesh.ARRAY_TEX_UV2] = _top_uv2
		for custom in 4:
			top_arrays[Mesh.ARRAY_CUSTOM0 + custom] = top_edge_normals[custom]
		top_arrays[Mesh.ARRAY_INDEX] = _indices_for(top_quads)
		top_surface = mesh.get_surface_count()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top_arrays, [], {}, _custom_float_flags())
	if wall_quads > 0:
		var wall_arrays: Array = []
		wall_arrays.resize(Mesh.ARRAY_MAX)
		wall_arrays[Mesh.ARRAY_VERTEX] = _wall_vertices
		wall_arrays[Mesh.ARRAY_NORMAL] = _wall_normals
		wall_arrays[Mesh.ARRAY_COLOR] = _wall_colors
		wall_arrays[Mesh.ARRAY_TEX_UV] = _uv_for(wall_quads)
		wall_arrays[Mesh.ARRAY_TEX_UV2] = _wall_uv2
		for custom in 4:
			wall_arrays[Mesh.ARRAY_CUSTOM0 + custom] = top_edge_normals[4 + custom]
		wall_arrays[Mesh.ARRAY_INDEX] = _indices_for(wall_quads)
		cliff_surface = mesh.get_surface_count()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wall_arrays, [], {}, _custom_float_flags())
	return {
		"mesh": mesh, "faces": _collision_faces(),
		SURFACE_TOP: top_surface, SURFACE_CLIFF: cliff_surface,
	}


## The no-treatment path: empty custom channels, a zero edge mask in UV2 so its
## packing invariant still holds, and wall colours carrying nothing but the layer
## the cliff shader samples. Tops keep their geometric normal, which is the only
## normal anything reads while smoothing is off.
func _plain_shading(top_quads: int, wall_quads: int) -> Array:
	# Encoded straight up. Nothing blends it in while the treatments are off, but a
	# meaningful unit vector beats leaving the channel at zero, which decodes to a
	# diagonal pointing into the ground.
	_top_colors.fill(Color(0.5, 1.0, 0.5, 1.0))
	for quad in top_quads:
		_pack_edge_mask(_top_uv2, quad, 0)
	for quad in wall_quads:
		_pack_edge_mask(_wall_uv2, quad, 0)
		var layer := _wall_layers[quad]
		var colour := Color(layer, 0.5, 0.5, 1.0)
		var base := quad * 4
		_wall_colors[base] = colour
		_wall_colors[base + 1] = colour
		_wall_colors[base + 2] = colour
		_wall_colors[base + 3] = colour
	return _empty_channels(top_quads, wall_quads)


static func _empty_channels(top_quads: int, wall_quads: int) -> Array:
	var channels: Array = []
	channels.resize(8)
	for channel_index in 4:
		var top_channel := PackedFloat32Array()
		top_channel.resize(top_quads * 16)
		channels[channel_index] = top_channel
		var wall_channel := PackedFloat32Array()
		wall_channel.resize(wall_quads * 16)
		channels[4 + channel_index] = wall_channel
	return channels


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
		# COLOR.r of a wall vertex is its auto-rock texture layer / 255 (§3). Faces
		# are the only place a material reaches the vertex data at all.
		_wall_colors[index] = Color(_wall_layers[index / 4], encoded.x, encoded.y, encoded.z)


static func _accumulate_normals(vertices: PackedVector3Array, normals: PackedVector3Array, sums: Dictionary) -> void:
	for index in vertices.size():
		var position := vertices[index]
		sums[position] = (sums.get(position, Vector3.ZERO) as Vector3) + normals[index]


static func _encode_normal(normal: Vector3) -> Vector3:
	return normal * 0.5 + Vector3.ONE * 0.5


## Marks only edges shared by two non-coplanar rendered faces. This rejects
## triangulation/chunk seams and silhouette edges (board skirts and holes), while
## still matching one long greedy top edge against several shorter wall edges.
##
## Edges are bucketed by the LINE they lie on, as a direction key holding a
## dictionary of anchor keys — both `Vector3i`, hashed natively. The previous
## version formatted a six-field String per edge, four per quad, on every rebuild
## of every chunk.
##
## Returns eight custom channels: four for the tops, four for the walls.
func _encode_roundable_edges(top_quads: int, wall_quads: int) -> Array:
	var quad_count := top_quads + wall_quads
	var masks := PackedInt32Array()
	masks.resize(quad_count)
	var edge_normal_sums: Array[Vector3] = []
	var edge_normal_counts := PackedInt32Array()
	edge_normal_sums.resize(quad_count * 4)
	edge_normal_counts.resize(quad_count * 4)
	var buckets: Dictionary = {}
	_edge_quad = PackedInt32Array()
	_edge_slot = PackedInt32Array()
	_edge_min = PackedFloat32Array()
	_edge_max = PackedFloat32Array()
	_edge_normal = PackedVector3Array()
	_collect_quad_edges(_top_vertices, _top_normals, 0, buckets)
	_collect_quad_edges(_wall_vertices, _wall_normals, top_quads, buckets)
	for anchors: Dictionary in buckets.values():
		for bucket: PackedInt32Array in anchors.values():
			if bucket.size() < 2:
				continue
			_pair_bucket(bucket, masks, edge_normal_sums, edge_normal_counts)

	var channels := _empty_channels(top_quads, wall_quads)
	for quad in top_quads:
		_pack_edge_mask(_top_uv2, quad, masks[quad])
		_pack_edge_normals(channels, 0, quad, edge_normal_sums, edge_normal_counts, quad)
	for quad in wall_quads:
		_pack_edge_mask(_wall_uv2, quad, masks[top_quads + quad])
		_pack_edge_normals(channels, 4, quad, edge_normal_sums, edge_normal_counts, top_quads + quad)
	return channels


func _pair_bucket(bucket: PackedInt32Array, masks: PackedInt32Array, edge_normal_sums: Array[Vector3], edge_normal_counts: PackedInt32Array) -> void:
	for left_index in bucket.size():
		var left := bucket[left_index]
		var left_quad := _edge_quad[left]
		var left_normal := _edge_normal[left]
		var left_min := _edge_min[left]
		var left_max := _edge_max[left]
		for right_index in range(left_index + 1, bucket.size()):
			var right := bucket[right_index]
			var right_quad := _edge_quad[right]
			if left_quad == right_quad:
				continue
			var right_normal := _edge_normal[right]
			if left_normal.dot(right_normal) > ROUNDABLE_EDGE_MAX_DOT:
				continue
			if minf(left_max, _edge_max[right]) - maxf(left_min, _edge_min[right]) <= 0.0001:
				continue
			var left_edge := _edge_slot[left]
			var right_edge := _edge_slot[right]
			masks[left_quad] |= 1 << left_edge
			masks[right_quad] |= 1 << right_edge
			_accumulate_edge_bisector(edge_normal_sums, edge_normal_counts, left_quad * 4 + left_edge, left_normal, right_normal)
			_accumulate_edge_bisector(edge_normal_sums, edge_normal_counts, right_quad * 4 + right_edge, right_normal, left_normal)


## Edge records live in parallel packed arrays and the buckets hold their indices.
## A `Dictionary` per edge — four per quad, a thousand per hilly chunk, allocated
## and thrown away on every single rebuild — was the largest single cost in the
## whole mesher.
func _collect_quad_edges(vertices: PackedVector3Array, normals: PackedVector3Array, quad_offset: int, buckets: Dictionary) -> void:
	for quad in vertices.size() / 4:
		var base := quad * 4
		var normal := normals[base]
		for edge in 4:
			var a := vertices[base + edge]
			var b := vertices[base + ((edge + 1) % 4)]
			var direction := (b - a).normalized()
			if direction.x < -0.0001 or (absf(direction.x) <= 0.0001 and direction.y < -0.0001) or (absf(direction.x) <= 0.0001 and absf(direction.y) <= 0.0001 and direction.z < 0.0):
				direction = -direction
			var anchor := a - direction * a.dot(direction)
			var direction_key := Vector3i(
				roundi(direction.x * DIRECTION_QUANTISATION),
				roundi(direction.y * DIRECTION_QUANTISATION),
				roundi(direction.z * DIRECTION_QUANTISATION),
			)
			var anchors: Dictionary = buckets.get(direction_key, {})
			if anchors.is_empty():
				buckets[direction_key] = anchors
			var anchor_key := Vector3i(
				roundi(anchor.x * EDGE_QUANTISATION),
				roundi(anchor.y * EDGE_QUANTISATION),
				roundi(anchor.z * EDGE_QUANTISATION),
			)
			var a_distance := a.dot(direction)
			var b_distance := b.dot(direction)
			var record := _edge_quad.size()
			_edge_quad.append(quad_offset + quad)
			_edge_slot.append(edge)
			_edge_min.append(minf(a_distance, b_distance))
			_edge_max.append(maxf(a_distance, b_distance))
			_edge_normal.append(normal)
			var bucket: PackedInt32Array = anchors.get(anchor_key, PackedInt32Array())
			bucket.append(record)
			anchors[anchor_key] = bucket


static func _accumulate_edge_bisector(sums: Array[Vector3], counts: PackedInt32Array, index: int, own_normal: Vector3, adjacent_normal: Vector3) -> void:
	var bisector := (own_normal + adjacent_normal).normalized()
	if bisector.is_zero_approx():
		return
	sums[index] += bisector
	counts[index] += 1


static func _pack_edge_normals(channels: Array, channel_offset: int, local_quad: int, sums: Array[Vector3], counts: PackedInt32Array, global_quad: int) -> void:
	for edge in 4:
		var source := global_quad * 4 + edge
		if counts[source] <= 0:
			continue
		var normal := sums[source].normalized()
		var channel: PackedFloat32Array = channels[channel_offset + edge]
		var base := local_quad * 16
		for corner in 4:
			var offset := base + corner * 4
			channel[offset] = normal.x
			channel[offset + 1] = normal.y
			channel[offset + 2] = normal.z
			channel[offset + 3] = 1.0


static func _pack_edge_mask(uv2: PackedVector2Array, quad: int, mask: int) -> void:
	var base := quad * 4
	var dimensions := uv2[base]
	# The size is in cells and a chunk is `CHUNK_CELLS` wide, so width/100 always
	# stays inside the fractional part and the four mask bits own the integer one.
	var packed_width := float(mask) + dimensions.x / 100.0
	var packed := Vector2(packed_width, dimensions.y)
	uv2[base] = packed
	uv2[base + 1] = packed
	uv2[base + 2] = packed
	uv2[base + 3] = packed


# --- Shared templates -------------------------------------------------------

## UV is the position across the quad — the same four corners for every quad ever
## emitted, so it is sliced off a template instead of appended four at a time.
static func _uv_for(quads: int) -> PackedVector2Array:
	while _uv_template.size() < quads * 4:
		_uv_template.append(Vector2.ZERO)
		_uv_template.append(Vector2(1.0, 0.0))
		_uv_template.append(Vector2.ONE)
		_uv_template.append(Vector2(0.0, 1.0))
	return _uv_template.slice(0, quads * 4)


static func _indices_for(quads: int) -> PackedInt32Array:
	while _index_template.size() < quads * 6:
		var base := (_index_template.size() / 6) * 4
		_index_template.append(base)
		_index_template.append(base + 1)
		_index_template.append(base + 2)
		_index_template.append(base)
		_index_template.append(base + 2)
		_index_template.append(base + 3)
	return _index_template.slice(0, quads * 6)


static func _custom_float_flags() -> int:
	return (
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)
	)


## Collision wants the flat triangle soup of BOTH surfaces, not the indexed mesh:
## a body walks on the tops and bumps into the faces, and both have to be there.
## The winding is the fixed quad pattern, so no index array is consulted.
func _collision_faces() -> PackedVector3Array:
	var top_quads := _top_vertices.size() / 4
	var wall_quads := _wall_vertices.size() / 4
	var faces := PackedVector3Array()
	faces.resize((top_quads + wall_quads) * 6)
	var position := 0
	position = _append_quad_faces(faces, position, _top_vertices, top_quads)
	_append_quad_faces(faces, position, _wall_vertices, wall_quads)
	return faces


static func _append_quad_faces(faces: PackedVector3Array, start: int, vertices: PackedVector3Array, quads: int) -> int:
	var position := start
	for quad in quads:
		var base := quad * 4
		var a := vertices[base]
		var c := vertices[base + 2]
		faces[position] = a
		faces[position + 1] = vertices[base + 1]
		faces[position + 2] = c
		faces[position + 3] = a
		faces[position + 4] = c
		faces[position + 5] = vertices[base + 3]
		position += 6
	return position
