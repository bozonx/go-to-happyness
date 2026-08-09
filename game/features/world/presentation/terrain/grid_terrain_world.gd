class_name GridTerrainWorld
extends Node3D

## Scene-side owner of the terrain mesh (design_docs/engine/grid_terrain_system.md §11, §14).
##
## Holds one `StaticBody3D` per chunk with a mesh and a collision shape built from
## the same polygons, and rebuilds chunks the grid reported dirty under a per-frame
## budget so a brush drag never stalls the frame. It reads the grid and never
## writes to it: editing goes through tools, which own the transaction.
##
## It also owns the two things the surface needs on the GPU: the material texture
## array (`TerrainMaterialLibrary`) and the index/detail maps
## (`TerrainSurfaceMaps`). Painting a material, a variant, wear or snow updates a
## texel of those maps and rebuilds NOTHING (`terrain_materials.md` §7.5) — the
## dirty-surface set of the grid is drained here, separately from the dirty
## chunks, and only the latter ever produce geometry.
##
## Chunks further than `lod_distance` from the camera are rebuilt without their
## side faces (§11). The isometric camera cannot see those faces at that range,
## and dropping them is most of the geometry of a hilly chunk. Collision follows
## the mesh as always, and that stays safe: the top surface every body stands on
## is still there, only the vertical faces between columns are gone.

const GROUND_SHADER_PATH := "res://game/features/world/presentation/terrain/terrain_ground.gdshader"
const CLIFF_SHADER_PATH := "res://game/features/world/presentation/terrain/terrain_cliff.gdshader"

## Rebuild budget, in microseconds of wall clock per frame. A COUNT of chunks was
## the wrong unit: one chunk costs anywhere from a fraction of a millisecond (a
## band of flat ground re-emitted) to a dozen (a full rebuild of hilly ground with
## its vegetation), so "two per frame" was either idle or three frames' worth of
## work. The queue always makes progress — at least one chunk is taken even when
## the budget is already spent — so a single expensive chunk can never deadlock it.
const REBUILD_BUDGET_USEC := 4000
## Vegetation is derived decoration and never blocks the ground appearing. It gets
## its own, smaller slice after the geometry queue has had its turn.
const GRASS_BUDGET_USEC := 2500
const COLLISION_LAYER := 1
## Hysteresis on the LOD switch, so a camera parked on the boundary does not
## rebuild the same chunk every frame.
const LOD_HYSTERESIS := 0.9

signal chunk_rebuilt(chunk: Vector2i)
## Emitted when the queue drains, i.e. the visible terrain matches the data again.
signal rebuild_finished()

@export var lod_distance := 64.0
@export var full_smoothing := false
@export_range(0.0, 1.0, 0.01) var edge_rounding := 0.0
enum RenderMode {
	FULL = 0,
	TEXTURED = 1,
	MATTE = 2,
	SIMPLE = 3,
}

@export var edge_bevel := false
@export var grass_visible := true
@export var render_mode: RenderMode = RenderMode.FULL

var grid: TerrainGrid = null
## The built-coverage layer over the same board (map_editor.md §5.2.1). Optional:
## a board with no coverage draws exactly what it drew before coverage existed.
var coverage: CoverageLayer = null
## Optional: without it every chunk is built at full detail.
var camera: Camera3D = null

var _chunk_bodies: Dictionary = {}
var _chunk_lods: Dictionary = {}
## One retained `TerrainChunkMesher` per chunk. It owns the chunk's geometry bands
## between builds, which is what turns a one-column edit into a one-band re-emit
## instead of a full 256-column rescan (§11).
var _chunk_meshers: Dictionary = {}
var _pending_chunks: Array[Vector2i] = []
var _queued_lookup: Dictionary = {}
## chunk -> `Vector4i` cell range that moved since that chunk was last built. A
## chunk queued twice before it is served accumulates both regions.
var _pending_bounds: Dictionary = {}
## Chunks whose vegetation is stale. Separate from the geometry queue: grass is
## decoration, it must never delay the ground it stands on, and on load it is
## nearly half the cost of publishing a board.
var _pending_grass: Array[Vector2i] = []
var _queued_grass: Dictionary = {}
var _library := TerrainMaterialLibrary.new()
var _coverage_library := CoverageLibrary.new()
var _surface_maps := TerrainSurfaceMaps.new()
var _medium_grass := TerrainMediumGrass.new()
var _tall_grass := TerrainTallGrass.new()
var _ground_material: ShaderMaterial = null
var _cliff_material: ShaderMaterial = null


func _ready() -> void:
	set_process(true)


func configure(next_grid: TerrainGrid, next_camera: Camera3D = null, next_coverage: CoverageLayer = null) -> void:
	grid = next_grid
	camera = next_camera
	coverage = next_coverage
	for child: Node in _chunk_bodies.values():
		child.queue_free()
	_chunk_bodies.clear()
	_chunk_lods.clear()
	_chunk_meshers.clear()
	_pending_chunks.clear()
	_queued_lookup.clear()
	_pending_bounds.clear()
	_pending_grass.clear()
	_queued_grass.clear()
	if grid == null:
		return
	_surface_maps.configure(grid.board_cells)
	_surface_maps.rebuild(grid)
	_surface_maps.rebuild_coverage(coverage)
	_medium_grass.set_lod_distance(lod_distance)
	_tall_grass.set_lod_distance(lod_distance)
	# Every texel was just written, so the pending set is stale by definition.
	# Draining it through `take_dirty_surface_cells` built and sorted one entry per
	# column — a quarter of a million of them on the largest board — to throw away.
	grid.clear_dirty_surface_cells()
	if coverage != null:
		coverage.take_dirty_cells()
	_ground_material = null
	_cliff_material = null
	grid.mark_all_chunks_dirty()
	_collect_dirty()


func _process(_delta: float) -> void:
	if grid == null:
		return
	# Surface texels first and unconditionally: they are cheap, they are not
	# subject to the chunk budget, and a painted material has to show up on the
	# frame it was painted even while a cascade is still remeshing behind it.
	_sync_surface_visuals()
	_collect_dirty()
	_collect_lod_changes()
	var had_pending := not _pending_chunks.is_empty()
	if had_pending:
		var deadline := Time.get_ticks_usec() + REBUILD_BUDGET_USEC
		while not _pending_chunks.is_empty():
			var chunk: Vector2i = _pending_chunks.pop_front()
			_queued_lookup.erase(chunk)
			_rebuild_chunk(chunk)
			if Time.get_ticks_usec() >= deadline:
				break
	_serve_grass_queue(GRASS_BUDGET_USEC)
	if had_pending and _pending_chunks.is_empty():
		rebuild_finished.emit()


## Rebuilds every chunk the grid still owes, ignoring the frame budget. Used on
## load and by tools that need the mesh to be current before measuring it.
##
## Vegetation is deliberately NOT part of it. Grass carries no collision and
## decides nothing; making the caller wait for it doubled the time a board takes
## to appear. It streams in over the following frames instead, through the same
## budgeted queue an edit uses.
func rebuild_pending_now() -> void:
	if grid == null:
		return
	_sync_surface_visuals()
	_collect_dirty()
	_collect_lod_changes()
	while not _pending_chunks.is_empty():
		var chunk: Vector2i = _pending_chunks.pop_front()
		_queued_lookup.erase(chunk)
		_rebuild_chunk(chunk)
	rebuild_finished.emit()


## Drains the vegetation queue as well. Tests and screenshot tools that want the
## board fully dressed before measuring it call this instead.
func rebuild_everything_now() -> void:
	rebuild_pending_now()
	_serve_grass_queue(0)


func pending_chunk_count() -> int:
	return _pending_chunks.size()


func pending_grass_count() -> int:
	return _pending_grass.size()


## Serves the vegetation queue. A budget of 0 means "until it is empty".
func _serve_grass_queue(budget_usec: int) -> void:
	if _pending_grass.is_empty():
		return
	var deadline := Time.get_ticks_usec() + budget_usec
	while not _pending_grass.is_empty():
		var chunk: Vector2i = _pending_grass.pop_front()
		_queued_grass.erase(chunk)
		var body: StaticBody3D = _chunk_bodies.get(chunk)
		if body != null:
			var lod := lod_of_chunk(chunk)
			_rebuild_medium_grass(body, chunk, lod)
			_rebuild_tall_grass(body, chunk, lod)
		if budget_usec > 0 and Time.get_ticks_usec() >= deadline:
			return


func _queue_grass(chunk: Vector2i) -> void:
	if _queued_grass.has(chunk):
		return
	_queued_grass[chunk] = true
	_pending_grass.append(chunk)


## Independent shading controls. Neither rebuilds chunks nor changes collision.
func set_full_smoothing(enabled: bool) -> void:
	var was_needed := _needs_shading_encoding()
	full_smoothing = enabled
	_sync_smoothing_parameters()
	_sync_shading_encoding(was_needed)


func set_edge_rounding(amount: float) -> void:
	var was_needed := _needs_shading_encoding()
	edge_rounding = clampf(amount, 0.0, 1.0)
	_sync_smoothing_parameters()
	_sync_shading_encoding(was_needed)


## The bevel is a different SHAPE for the same band, never a different mesh: it
## reads the data `edge_rounding` already asked for.
func set_edge_bevel(enabled: bool) -> void:
	edge_bevel = enabled
	_sync_smoothing_parameters()


## Vegetation receives the authored weather wind here. Water deliberately has
## no weather coupling while waves remain a future idea.
func set_wind(direction: Vector2, strength: float) -> void:
	_medium_grass.set_wind(direction, strength)
	_tall_grass.set_wind(direction, strength)


## Whether the mesh has to carry the data the smoothing treatments read: the
## averaged vertex normal and the roundable-edge mask with its bevel normals.
## With every treatment off — how the game and the map editor run — the shader
## blends none of it in, and building it was the single largest cost of a chunk
## rebuild.
func _needs_shading_encoding() -> bool:
	return full_smoothing or edge_rounding > 0.001


## Re-queues every chunk when a treatment is switched on or off, because the
## answer to `_needs_shading_encoding` decides what the mesh carries. The retained
## bands are untouched by it, so the requeue only re-runs assembly.
func _sync_shading_encoding(was_needed: bool) -> void:
	if grid == null or was_needed == _needs_shading_encoding():
		return
	grid.mark_all_chunks_dirty()
	_collect_dirty()


func _sync_smoothing_parameters() -> void:
	var full_amount := 1.0 if full_smoothing else 0.0
	if _ground_material != null:
		_ground_material.set_shader_parameter(&"full_smoothing", full_amount)
		_ground_material.set_shader_parameter(&"edge_rounding", edge_rounding)
		_ground_material.set_shader_parameter(&"edge_bevel", 1.0 if edge_bevel else 0.0)
	if _cliff_material != null:
		_cliff_material.set_shader_parameter(&"full_smoothing", full_amount)
		_cliff_material.set_shader_parameter(&"edge_rounding", edge_rounding)
		_cliff_material.set_shader_parameter(&"edge_bevel", 1.0 if edge_bevel else 0.0)


func lod_of_chunk(chunk: Vector2i) -> int:
	return int(_chunk_lods.get(chunk, TerrainChunkMesher.Lod.FULL))


func _collect_dirty() -> void:
	if not grid.has_dirty_chunks():
		return
	var bounds: Dictionary = {}
	for chunk: Vector2i in grid.take_dirty_chunks(bounds):
		_queue(chunk, bounds[chunk])


## Surface painting never remeshes terrain, but derived decoration follows it.
## Drain the dirty cells once, then hand the same set to both GPU maps and the
## affected chunk MultiMeshes so neither presentation keeps a second state list.
func _sync_surface_visuals() -> void:
	# The surface maps are the size of the board, always. A caller that configured
	# this world before the grid had a board — or reconfigured the grid to another
	# size afterwards — leaves them one texel wide, and then every fragment on the
	# map samples the same texel: the whole world is drawn with one material while
	# the data underneath is perfectly varied. That is exactly what happened to the
	# generation laboratory, and it cost an afternoon of looking for the bug in the
	# painter. One comparison per frame is cheaper than the next afternoon.
	if _surface_maps.board_cells() != grid.board_cells:
		_surface_maps.rebuild(grid)
		_surface_maps.rebuild_coverage(coverage)
		grid.clear_dirty_surface_cells()
		grid.mark_all_chunks_dirty()
		_collect_dirty()
	# Coverage is drained first and on its own: it has a separate owner and a
	# separate dirty set, and a road stroke must show up on the frame it was laid
	# even when no material was painted at all.
	_surface_maps.sync_coverage(coverage)
	if not grid.has_dirty_surface_cells():
		return
	var cells := grid.take_dirty_surface_cells()
	_surface_maps.update_cells(grid, cells)
	var chunks: Dictionary = {}
	for cell: Vector2i in cells:
		chunks[grid.chunk_of(cell)] = true
	for chunk: Vector2i in chunks:
		_queue_grass(chunk)


## Re-queues chunks whose distance to the camera crossed the LOD boundary.
## Iterates the dictionary directly: `.keys()` allocated an array of every chunk
## on the board on every frame, and the board can be 1024 of them.
func _collect_lod_changes() -> void:
	if camera == null:
		return
	for chunk: Vector2i in _chunk_bodies:
		if _target_lod(chunk) != lod_of_chunk(chunk):
			_queue(chunk, TerrainChunkMesher.FULL_BOUNDS)


## Queues a chunk, merging the cell range with whatever it already owed. A chunk
## queued twice before it is served must rebuild the union of both edits, not the
## last one.
func _queue(chunk: Vector2i, bounds: Vector4i) -> void:
	if _queued_lookup.has(chunk):
		_pending_bounds[chunk] = _merged_bounds(_pending_bounds[chunk], bounds)
		return
	_queued_lookup[chunk] = true
	_pending_bounds[chunk] = bounds
	_pending_chunks.append(chunk)


static func _merged_bounds(first: Vector4i, second: Vector4i) -> Vector4i:
	if first == TerrainChunkMesher.FULL_BOUNDS or second == TerrainChunkMesher.FULL_BOUNDS:
		return TerrainChunkMesher.FULL_BOUNDS
	return Vector4i(
		mini(first.x, second.x), mini(first.y, second.y),
		maxi(first.z, second.z), maxi(first.w, second.w),
	)


func _target_lod(chunk: Vector2i) -> int:
	if camera == null:
		return TerrainChunkMesher.Lod.FULL
	var centre := _chunk_centre(chunk)
	var camera_position := camera.global_position
	var distance := Vector2(centre.x - camera_position.x, centre.z - camera_position.z).length()
	var current := lod_of_chunk(chunk)
	if current == TerrainChunkMesher.Lod.TOP_ONLY:
		return TerrainChunkMesher.Lod.FULL if distance < lod_distance * LOD_HYSTERESIS else TerrainChunkMesher.Lod.TOP_ONLY
	return TerrainChunkMesher.Lod.TOP_ONLY if distance > lod_distance else TerrainChunkMesher.Lod.FULL


func _chunk_centre(chunk: Vector2i) -> Vector3:
	var origin := grid.chunk_origin_cell(chunk)
	var half := float(TerrainGrid.CHUNK_CELLS) * 0.5 * grid.cell_size
	return Vector3(float(origin.x) * grid.cell_size + half, 0.0, float(origin.y) * grid.cell_size + half)


func _rebuild_chunk(chunk: Vector2i) -> void:
	var lod := _target_lod(chunk)
	var bounds: Vector4i = _pending_bounds.get(chunk, TerrainChunkMesher.FULL_BOUNDS)
	_pending_bounds.erase(chunk)
	var result := _mesher_for(chunk).build(lod, bounds, _needs_shading_encoding())
	_chunk_lods[chunk] = lod
	var mesh: ArrayMesh = result["mesh"]
	var body := _chunk_body(chunk, mesh != null)
	if body == null:
		return
	var mesh_instance: MeshInstance3D = body.get_node(^"Mesh")
	var collision: CollisionShape3D = body.get_node(^"Collision")
	mesh_instance.mesh = mesh
	if mesh != null:
		_assign_surface_materials(mesh_instance, result)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(result["faces"])
		collision.shape = shape
		collision.disabled = false
	else:
		collision.shape = null
		collision.disabled = true
	_queue_grass(chunk)
	chunk_rebuilt.emit(chunk)


func _mesher_for(chunk: Vector2i) -> TerrainChunkMesher:
	var mesher: TerrainChunkMesher = _chunk_meshers.get(chunk)
	if mesher != null:
		return mesher
	mesher = TerrainChunkMesher.new()
	mesher.configure(grid, chunk)
	_chunk_meshers[chunk] = mesher
	return mesher


## Chunks are created on demand: an empty chunk that never gains geometry costs
## nothing, which matters once the map is bigger than the settlement.
func _chunk_body(chunk: Vector2i, create_if_missing: bool) -> StaticBody3D:
	if _chunk_bodies.has(chunk):
		return _chunk_bodies[chunk]
	if not create_if_missing:
		return null
	var body := StaticBody3D.new()
	body.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	body.collision_layer = COLLISION_LAYER
	body.collision_mask = 0
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	body.add_child(collision)
	add_child(body)
	_chunk_bodies[chunk] = body
	return body


func set_render_mode(mode: RenderMode) -> void:
	if render_mode == mode:
		return
	render_mode = mode
	_sync_render_mode_parameters()
	_update_grass_visibility()


func set_grass_visible(enabled: bool) -> void:
	if grass_visible == enabled:
		return
	grass_visible = enabled
	_update_grass_visibility()


func _is_grass_effective() -> bool:
	return grass_visible and (render_mode == RenderMode.FULL)


func _update_grass_visibility() -> void:
	var effective := _is_grass_effective()
	for child: Node in _chunk_bodies.values():
		var body := child as StaticBody3D
		if body == null:
			continue
		var tall: MultiMeshInstance3D = body.get_node_or_null(^"TallGrass")
		if tall != null:
			tall.visible = effective
		var med: MultiMeshInstance3D = body.get_node_or_null(^"MediumGrass")
		if med != null:
			med.visible = effective


func _sync_render_mode_parameters() -> void:
	var mode_val := float(render_mode)
	if _ground_material != null:
		_ground_material.set_shader_parameter(&"render_mode_idx", mode_val)
	if _cliff_material != null:
		_cliff_material.set_shader_parameter(&"render_mode_idx", mode_val)
	_sync_simple_textures()


## The simplified array is procedural and therefore the one thing here that is
## still generated texel by texel. It is built on the first frame the mode is
## actually selected — an inspection aid must not be part of the cost of opening
## a map that never uses it.
func _sync_simple_textures() -> void:
	if render_mode != RenderMode.SIMPLE:
		return
	var textures := _library.simple_texture_array()
	if _ground_material != null:
		_ground_material.set_shader_parameter(&"simple_textures", textures)
	if _cliff_material != null:
		_cliff_material.set_shader_parameter(&"simple_textures", textures)


func _rebuild_tall_grass(body: StaticBody3D, chunk: Vector2i, lod: int) -> void:
	var instance: MultiMeshInstance3D = body.get_node_or_null(^"TallGrass")
	if lod == TerrainChunkMesher.Lod.TOP_ONLY:
		if instance != null:
			instance.multimesh = null
		return
	if instance == null:
		instance = MultiMeshInstance3D.new()
		instance.name = "TallGrass"
		# Thousands of alpha-cutout blades produce noisy shadow-map pinholes and
		# cost another overdraw pass. The painted dark base already grounds them.
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.extra_cull_margin = TerrainTallGrass.CARD_HEIGHT
		instance.material_override = _tall_grass.material()
		body.add_child(instance)
	instance.visible = _is_grass_effective()
	instance.multimesh = _tall_grass.build_chunk(grid, chunk)


func _rebuild_medium_grass(body: StaticBody3D, chunk: Vector2i, lod: int) -> void:
	var instance: MultiMeshInstance3D = body.get_node_or_null(^"MediumGrass")
	if lod == TerrainChunkMesher.Lod.TOP_ONLY:
		if instance != null:
			instance.multimesh = null
		return
	if instance == null:
		instance = MultiMeshInstance3D.new()
		instance.name = "MediumGrass"
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.extra_cull_margin = TerrainMediumGrass.CARD_HEIGHT
		instance.material_override = _medium_grass.material()
		body.add_child(instance)
	instance.visible = _is_grass_effective()
	instance.multimesh = _medium_grass.build_chunk(grid, chunk)


## Two surfaces, two shaders (§7.2): tops read the index map, faces are triplanar
## auto-rock. Both sample the SAME texture array, so the whole world still costs
## one texture binding.
func _assign_surface_materials(mesh_instance: MeshInstance3D, result: Dictionary) -> void:
	var top_surface := int(result.get(TerrainChunkMesher.SURFACE_TOP, -1))
	var cliff_surface := int(result.get(TerrainChunkMesher.SURFACE_CLIFF, -1))
	if top_surface >= 0:
		mesh_instance.set_surface_override_material(top_surface, _ground_shader_material())
	if cliff_surface >= 0:
		mesh_instance.set_surface_override_material(cliff_surface, _cliff_shader_material())


func _ground_shader_material() -> ShaderMaterial:
	if _ground_material != null:
		return _ground_material
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = load(GROUND_SHADER_PATH)
	_ground_material.set_shader_parameter(&"surface_textures", _library.texture_array())
	_ground_material.set_shader_parameter(&"surface_normals", _library.normal_array())
	_ground_material.set_shader_parameter(&"index_map", _surface_maps.index_texture())
	_ground_material.set_shader_parameter(&"detail_map", _surface_maps.detail_texture())
	_ground_material.set_shader_parameter(&"coverage_map", _surface_maps.coverage_texture())
	_ground_material.set_shader_parameter(&"coverage_palette", _coverage_library.palette_texture())
	_ground_material.set_shader_parameter(&"coverage_capacity", float(_coverage_library.palette_size()))
	_ground_material.set_shader_parameter(&"layer_lookup_map", _library.layer_lookup_texture())
	_ground_material.set_shader_parameter(&"board_cells", float(grid.board_cells))
	_ground_material.set_shader_parameter(&"cell_size", grid.cell_size)
	_ground_material.set_shader_parameter(&"material_count", float(TerrainMaterialCatalog.MATERIAL_COUNT))
	_ground_material.set_shader_parameter(&"variant_capacity", float(TerrainMaterialVariants.MAX_VARIANTS))
	_ground_material.set_shader_parameter(&"full_smoothing", 1.0 if full_smoothing else 0.0)
	_ground_material.set_shader_parameter(&"edge_rounding", edge_rounding)
	_ground_material.set_shader_parameter(&"edge_bevel", 1.0 if edge_bevel else 0.0)
	_ground_material.set_shader_parameter(&"render_mode_idx", float(render_mode))
	_sync_simple_textures()
	return _ground_material


func _cliff_shader_material() -> ShaderMaterial:
	if _cliff_material != null:
		return _cliff_material
	_cliff_material = ShaderMaterial.new()
	_cliff_material.shader = load(CLIFF_SHADER_PATH)
	_cliff_material.set_shader_parameter(&"surface_textures", _library.texture_array())
	_cliff_material.set_shader_parameter(&"surface_normals", _library.normal_array())
	_cliff_material.set_shader_parameter(&"cell_size", grid.cell_size)
	_cliff_material.set_shader_parameter(&"full_smoothing", 1.0 if full_smoothing else 0.0)
	_cliff_material.set_shader_parameter(&"edge_rounding", edge_rounding)
	_cliff_material.set_shader_parameter(&"edge_bevel", 1.0 if edge_bevel else 0.0)
	_cliff_material.set_shader_parameter(&"render_mode_idx", float(render_mode))
	_sync_simple_textures()
	return _cliff_material
