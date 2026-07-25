class_name GridTerrainWorld
extends Node3D

## Scene-side owner of the terrain mesh (design_docs/core/grid_terrain_system.md §11, §14).
##
## Holds one `StaticBody3D` per chunk with a mesh and a collision shape built from
## the same polygons, and rebuilds chunks the grid reported dirty under a per-frame
## budget so a brush drag never stalls the frame. It reads the grid and never
## writes to it: editing goes through tools, which own the transaction.

const REBUILD_BUDGET_PER_FRAME := 2
const COLLISION_LAYER := 1

signal chunk_rebuilt(chunk: Vector2i)
## Emitted when the queue drains, i.e. the visible terrain matches the data again.
signal rebuild_finished()

var grid: TerrainGrid = null

var _chunk_bodies: Dictionary = {}
var _pending_chunks: Array[Vector2i] = []
var _queued_lookup: Dictionary = {}
var _surface_material: StandardMaterial3D = null


func _ready() -> void:
	set_process(true)


func configure(next_grid: TerrainGrid) -> void:
	grid = next_grid
	for child: Node in _chunk_bodies.values():
		child.queue_free()
	_chunk_bodies.clear()
	_pending_chunks.clear()
	_queued_lookup.clear()
	if grid == null:
		return
	grid.mark_all_chunks_dirty()
	_collect_dirty()


func _process(_delta: float) -> void:
	if grid == null:
		return
	_collect_dirty()
	if _pending_chunks.is_empty():
		return
	var budget := mini(REBUILD_BUDGET_PER_FRAME, _pending_chunks.size())
	for _index in budget:
		var chunk: Vector2i = _pending_chunks.pop_front()
		_queued_lookup.erase(chunk)
		_rebuild_chunk(chunk)
	if _pending_chunks.is_empty():
		rebuild_finished.emit()


## Rebuilds everything the grid still owes, ignoring the frame budget. Used on
## load and by tools that need the mesh to be current before measuring it.
func rebuild_pending_now() -> void:
	if grid == null:
		return
	_collect_dirty()
	while not _pending_chunks.is_empty():
		var chunk: Vector2i = _pending_chunks.pop_front()
		_queued_lookup.erase(chunk)
		_rebuild_chunk(chunk)
	rebuild_finished.emit()


func pending_chunk_count() -> int:
	return _pending_chunks.size()


func _collect_dirty() -> void:
	if not grid.has_dirty_chunks():
		return
	for chunk: Vector2i in grid.take_dirty_chunks():
		if _queued_lookup.has(chunk):
			continue
		_queued_lookup[chunk] = true
		_pending_chunks.append(chunk)


func _rebuild_chunk(chunk: Vector2i) -> void:
	var result := TerrainChunkMesher.build_chunk(grid, chunk)
	var mesh: ArrayMesh = result["mesh"]
	var body := _chunk_body(chunk, mesh != null)
	if body == null:
		return
	var mesh_instance: MeshInstance3D = body.get_node(^"Mesh")
	var collision: CollisionShape3D = body.get_node(^"Collision")
	mesh_instance.mesh = mesh
	if mesh != null:
		mesh_instance.material_override = _material()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(result["faces"])
		collision.shape = shape
		collision.disabled = false
	else:
		collision.shape = null
		collision.disabled = true
	chunk_rebuilt.emit(chunk)


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


func _material() -> StandardMaterial3D:
	if _surface_material != null:
		return _surface_material
	_surface_material = StandardMaterial3D.new()
	_surface_material.vertex_color_use_as_albedo = true
	_surface_material.roughness = 0.95
	_surface_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _surface_material
