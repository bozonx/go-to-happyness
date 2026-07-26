class_name WaterWorld
extends Node3D

## Scene-side owner of the water surface (grid_terrain_system.md §9).
##
## The counterpart of `GridTerrainWorld`, and deliberately much simpler: water has
## no collision and no navigation of its own. Passability comes from the published
## `NavTerrainField` (§9.7), so a body added here can never disagree with a body
## the routing sees — there is only one water layer and this draws it.
##
## What it builds per dirty chunk is one surface per (body, frozen) group: the top
## quad of every wet cell at that cell's level, plus a skirt where the level steps
## down to a wet neighbour, so a river descending a valley is a surface and not a
## flight of floating tiles. Everything that varies per cell — depth, distance to
## the bank — is baked into vertex colour, because both are derived from data that
## only changes when an author edits.
##
## Freezing rebuilds nothing at all in the geometry sense: it moves cells from one
## group to the other, and the two groups differ by a single uniform (§9.6).

const SHADER_PATH := "res://game/features/world/presentation/water/water_surface.gdshader"

const REBUILD_BUDGET_PER_FRAME := 4
## How far from a bank the shore band reaches, in cells. Baked into the mesh, so
## it costs nothing per frame.
const SHORE_RANGE_CELLS := 3
## Lifts the surface a hair above the exact level so that water standing exactly
## on a terrace top does not z-fight with the ground it covers.
const SURFACE_EPSILON := 0.01

signal chunk_rebuilt(chunk: Vector2i)

var water: WaterGrid = null
var terrain: TerrainGrid = null

var _chunk_nodes: Dictionary = {}
var _pending_chunks: Array[Vector2i] = []
var _queued_lookup: Dictionary = {}
## body_id -> { frozen: ShaderMaterial }. Dropped whole when the registry changes,
## because a retyped body is a different colour, wave and emission.
var _materials: Dictionary = {}
## Cells from a dry one, capped at `SHORE_RANGE_CELLS`. Rebuilt whenever the
## layer changes shape; a chunk cannot compute it alone because a bank one cell
## outside the chunk still shades the cells inside it.
var _shore_distance := PackedByteArray()
var _shore_revision := -1

var _wind_direction := Vector2(1.0, 0.0)
var _wind_strength := 0.4


func _ready() -> void:
	set_process(true)


func configure(next_water: WaterGrid, next_terrain: TerrainGrid, water_service: WaterService = null, terrain_service: TerrainService = null) -> void:
	water = next_water
	terrain = next_terrain
	for node: Node in _chunk_nodes.values():
		node.queue_free()
	_chunk_nodes.clear()
	_pending_chunks.clear()
	_queued_lookup.clear()
	_materials.clear()
	_shore_revision = -1
	if water == null:
		return
	if water_service != null:
		if not water_service.registry_changed.is_connected(_on_registry_changed):
			water_service.registry_changed.connect(_on_registry_changed)
	# Depth is water level minus ground, so raising the bottom of a lake changes
	# this surface without the water layer being touched at all.
	if terrain_service != null and not terrain_service.edit_committed.is_connected(_on_terrain_committed):
		terrain_service.edit_committed.connect(_on_terrain_committed)
	water.mark_all_chunks_dirty()
	_collect_dirty()


func _process(_delta: float) -> void:
	if water == null:
		return
	_collect_dirty()
	if _pending_chunks.is_empty():
		return
	var budget := mini(REBUILD_BUDGET_PER_FRAME, _pending_chunks.size())
	for _index in budget:
		var chunk: Vector2i = _pending_chunks.pop_front()
		_queued_lookup.erase(chunk)
		_rebuild_chunk(chunk)


## Rebuilds everything outstanding at once, ignoring the frame budget. Used on
## load and by tools that need the surface to be current before capturing it.
func rebuild_pending_now() -> void:
	if water == null:
		return
	_collect_dirty()
	while not _pending_chunks.is_empty():
		var chunk: Vector2i = _pending_chunks.pop_front()
		_queued_lookup.erase(chunk)
		_rebuild_chunk(chunk)


func pending_chunk_count() -> int:
	return _pending_chunks.size()


## The wind every wave and every band of foam scales with (§9.5). The sea storms
## in a thunderstorm because this is the same wind the sky and the rain read, not
## because water has a weather state of its own.
func set_wind(direction: Vector2, strength: float) -> void:
	_wind_direction = direction if direction.length_squared() > 0.0001 else Vector2(1.0, 0.0)
	_wind_strength = clampf(strength, 0.0, 1.0)
	for by_state: Dictionary in _materials.values():
		for material: ShaderMaterial in by_state.values():
			material.set_shader_parameter(&"wind_direction", _wind_direction)
			material.set_shader_parameter(&"wind_strength", _wind_strength)


func _on_registry_changed() -> void:
	_materials.clear()
	if water != null:
		water.mark_all_chunks_dirty()


func _on_terrain_committed(delta: TerrainDelta) -> void:
	if water == null or not delta.changes_geometry():
		return
	for cell: Vector2i in delta.cells:
		water.mark_chunk_dirty(water.chunk_of(cell))


func _collect_dirty() -> void:
	if not water.has_dirty_chunks():
		return
	for chunk: Vector2i in water.take_dirty_chunks():
		if _queued_lookup.has(chunk):
			continue
		_queued_lookup[chunk] = true
		_pending_chunks.append(chunk)


# --- Meshing ------------------------------------------------------------------

func _rebuild_chunk(chunk: Vector2i) -> void:
	_ensure_shore_distance()
	var groups := _collect_groups(chunk)
	var node := _chunk_node(chunk, not groups.is_empty())
	if node == null:
		return
	if groups.is_empty():
		node.mesh = null
		chunk_rebuilt.emit(chunk)
		return

	var mesh := ArrayMesh.new()
	# Sorted so the same board produces the same surface order on every machine.
	var keys: Array = groups.keys()
	keys.sort()
	for key: int in keys:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, groups[key])
	node.mesh = mesh
	# Overrides go on after the mesh: a surface that does not exist yet cannot be
	# given a material.
	for surface in keys.size():
		var key: int = keys[surface]
		node.set_surface_override_material(surface, _material_for(key >> 1, (key & 1) != 0))
	chunk_rebuilt.emit(chunk)


## Vertex data of one chunk, keyed by `body_id << 1 | frozen`. One surface per key
## because those are exactly the cells that share a material.
func _collect_groups(chunk: Vector2i) -> Dictionary:
	var builders: Dictionary = {}
	var origin := chunk * TerrainGrid.CHUNK_CELLS
	for local_z in TerrainGrid.CHUNK_CELLS:
		for local_x in TerrainGrid.CHUNK_CELLS:
			var cell := origin + Vector2i(local_x, local_z)
			if not water.is_inside(cell) or not water.is_wet(terrain, cell):
				continue
			var key := (water.body_id_at(cell) << 1) | (1 if water.is_frozen(cell) else 0)
			if not builders.has(key):
				builders[key] = _new_builder()
			_emit_cell(builders[key], cell)
	var groups: Dictionary = {}
	for key: int in builders:
		var builder: Dictionary = builders[key]
		var vertices: PackedVector3Array = builder["vertices"]
		if vertices.is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = builder["normals"]
		arrays[Mesh.ARRAY_COLOR] = builder["colors"]
		groups[key] = arrays
	return groups


static func _new_builder() -> Dictionary:
	return {
		"vertices": PackedVector3Array(),
		"normals": PackedVector3Array(),
		"colors": PackedColorArray(),
	}


## One cell: its top quad, and a skirt down to each orthogonal neighbour whose
## surface is lower. Without the skirt a river step is a hole through which the
## bottom is visible.
func _emit_cell(builder: Dictionary, cell: Vector2i) -> void:
	var size := water.cell_size
	var level := float(water.height_of(cell)) * TerrainGrid.HEIGHT_STEP + SURFACE_EPSILON
	var west := float(cell.x) * size
	var north := float(cell.y) * size
	var east := west + size
	var south := north + size
	var depth := water.depth_metres_at(terrain, cell)
	var shore := _shore_metres(cell)
	var tint := Color(depth, shore, 0.0, 1.0)

	var nw := Vector3(west, level, north)
	var ne := Vector3(east, level, north)
	var se := Vector3(east, level, south)
	var sw := Vector3(west, level, south)
	_add_quad(builder, nw, ne, se, sw, Vector3.UP, tint)

	for direction in WaterGrid.ORTHOGONAL_OFFSETS.size():
		var offset: Vector2i = WaterGrid.ORTHOGONAL_OFFSETS[direction]
		var neighbour := cell + offset
		if not water.is_wet(terrain, neighbour):
			continue
		var neighbour_level := float(water.height_of(neighbour)) * TerrainGrid.HEIGHT_STEP + SURFACE_EPSILON
		if neighbour_level >= level - 0.001:
			continue
		var normal := Vector3(float(offset.x), 0.0, float(offset.y))
		match offset:
			Vector2i(0, -1):
				_add_quad(builder, Vector3(west, level, north), Vector3(east, level, north), Vector3(east, neighbour_level, north), Vector3(west, neighbour_level, north), normal, tint)
			Vector2i(1, 0):
				_add_quad(builder, Vector3(east, level, north), Vector3(east, level, south), Vector3(east, neighbour_level, south), Vector3(east, neighbour_level, north), normal, tint)
			Vector2i(0, 1):
				_add_quad(builder, Vector3(east, level, south), Vector3(west, level, south), Vector3(west, neighbour_level, south), Vector3(east, neighbour_level, south), normal, tint)
			Vector2i(-1, 0):
				_add_quad(builder, Vector3(west, level, south), Vector3(west, level, north), Vector3(west, neighbour_level, north), Vector3(west, neighbour_level, south), normal, tint)


## Two triangles, appended in place. The packed arrays are read back out of the
## builder and written back into it because they are value types: appending to a
## local copy would build a mesh of nothing at all.
static func _add_quad(builder: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, tint: Color) -> void:
	var vertices: PackedVector3Array = builder["vertices"]
	var normals: PackedVector3Array = builder["normals"]
	var colors: PackedColorArray = builder["colors"]
	for vertex: Vector3 in [a, b, c, a, c, d]:
		vertices.append(vertex)
		normals.append(normal)
		colors.append(tint)
	builder["vertices"] = vertices
	builder["normals"] = normals
	builder["colors"] = colors


func _chunk_node(chunk: Vector2i, create_if_missing: bool) -> MeshInstance3D:
	if _chunk_nodes.has(chunk):
		return _chunk_nodes[chunk]
	if not create_if_missing:
		return null
	var node := MeshInstance3D.new()
	node.name = "Water_%d_%d" % [chunk.x, chunk.y]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_chunk_nodes[chunk] = node
	return node


# --- Materials ----------------------------------------------------------------

## One material per body per state, built from the body itself: the colour, the
## wave and the foam of a river ARE the river's, and there is nowhere else for a
## renderer to look them up (§9.2).
func _material_for(body_id: int, frozen: bool) -> ShaderMaterial:
	var by_state: Dictionary = _materials.get(body_id, {})
	if by_state.has(frozen):
		return by_state[frozen]
	var body := water.body(body_id)
	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	material.render_priority = 1
	if body != null:
		material.set_shader_parameter(&"water_colour", Color(body.colour.r, body.colour.g, body.colour.b))
		material.set_shader_parameter(&"deep_colour", Color(body.colour.r * 0.35, body.colour.g * 0.4, body.colour.b * 0.5))
		material.set_shader_parameter(&"wave_amplitude", body.wave_amplitude)
		material.set_shader_parameter(&"foam_strength", body.foam_strength)
		if body.is_lava():
			# Lava lights its own banks, does not fade to a deep blue and never
			# freezes — all three follow from the type, not from a second shader.
			material.set_shader_parameter(&"emission_colour", Color(body.colour.r, body.colour.g, body.colour.b))
			material.set_shader_parameter(&"emission_energy", 2.4)
			material.set_shader_parameter(&"deep_colour", Color(body.colour.r * 0.8, body.colour.g * 0.35, body.colour.b * 0.2))
			material.set_shader_parameter(&"opacity", 1.0)
			material.set_shader_parameter(&"roughness_value", 0.75)
	material.set_shader_parameter(&"frozen", 1.0 if frozen else 0.0)
	material.set_shader_parameter(&"wind_direction", _wind_direction)
	material.set_shader_parameter(&"wind_strength", _wind_strength)
	by_state[frozen] = material
	_materials[body_id] = by_state
	return material


# --- Shore distance -----------------------------------------------------------

## Multi-source breadth-first walk out from every dry cell, capped at
## `SHORE_RANGE_CELLS`. One pass over the board per change of the layer, instead
## of a per-fragment search in the shader for a value that only an author can move.
func _ensure_shore_distance() -> void:
	if water == null or terrain == null or _shore_revision == water.revision():
		return
	_shore_revision = water.revision()
	var count := water.board_cells * water.board_cells
	_shore_distance = PackedByteArray()
	_shore_distance.resize(count)
	_shore_distance.fill(SHORE_RANGE_CELLS)
	var minimum := water.min_cell()
	var maximum := water.max_cell()
	var frontier: Array[Vector2i] = []
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			if water.is_wet(terrain, cell):
				continue
			_shore_distance[_shore_index(cell)] = 0
			frontier.append(cell)
	var distance := 0
	while distance < SHORE_RANGE_CELLS and not frontier.is_empty():
		distance += 1
		var next: Array[Vector2i] = []
		for cell: Vector2i in frontier:
			for offset: Vector2i in WaterGrid.ORTHOGONAL_OFFSETS:
				var neighbour := cell + offset
				if not water.is_inside(neighbour):
					continue
				var index := _shore_index(neighbour)
				if _shore_distance[index] <= distance:
					continue
				_shore_distance[index] = distance
				next.append(neighbour)
		frontier = next


func _shore_metres(cell: Vector2i) -> float:
	if not water.is_inside(cell) or _shore_distance.is_empty():
		return float(SHORE_RANGE_CELLS) * water.cell_size
	return float(_shore_distance[_shore_index(cell)]) * water.cell_size


func _shore_index(cell: Vector2i) -> int:
	return (cell.y + water.board_half_cells) * water.board_cells + (cell.x + water.board_half_cells)
