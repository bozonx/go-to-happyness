class_name WaterWorld
extends Node3D

## Scene-side owner of the water surface (grid_terrain_system.md §9).
##
## The counterpart of `GridTerrainWorld`, and deliberately much simpler: open
## water has no collision and no navigation of its own. Passability comes from the
## published `NavTerrainField` (§9.7), so a body added here can never disagree
## with a body the routing sees — there is only one water layer and this draws it.
##
## What it builds per dirty chunk is one surface per (body, frozen) group: the top
## quad of every wet cell at that cell's level, plus a skirt where the level steps
## down to a wet neighbour, so a river descending a valley is a surface and not a
## flight of floating tiles. Everything that varies per cell — depth, distance to
## the bank — is baked into vertex colour, because both are derived from data that
## only changes when an author edits.
##
## Freezing rebuilds nothing at all in the geometry sense: it moves cells from one
## group to the other, and the two groups differ by a single uniform (§9.6). It
## does add ONE thing, and it is not visual — **ice is a floor**. Routing walks a
## frozen cell at the water level, so a citizen crossing a frozen lake needs
## something for `move_and_slide` to stand on; without it the published height and
## the physics disagree by the whole depth of the lake and the walker sinks to the
## bed. The ice collider is that floor, and it is the only collision this node
## owns.
##
## Beyond the board it draws the border ocean of `map_editor.md` §6.1, when the map
## asks for one: a horizontal plane at the border level, the same shader, no
## collider and no navigation. It is scenery for the horizon, not a place.

const SHADER_PATH := "res://game/features/world/presentation/water/water_surface.gdshader"

const REBUILD_BUDGET_PER_FRAME := 4
## How far from a bank the shore band reaches, in cells. Baked into the mesh, so
## it costs nothing per frame.
const SHORE_RANGE_CELLS := 3
## Lifts the surface a hair above the exact level so that water standing exactly
## on a terrace top does not z-fight with the ground it covers.
const SURFACE_EPSILON := 0.01
## How far past the board the border ocean reaches. Big enough to leave the far
## clip plane of an isometric camera, small enough not to lose float precision.
const BORDER_OCEAN_REACH := 2000.0
## The ice collider sits on the same physics layer as the ground, because as far as
## anything walking is concerned that is what it is.
const COLLISION_LAYER := 1

signal chunk_rebuilt(chunk: Vector2i)

var water: WaterGrid = null
var terrain: TerrainGrid = null

var _chunk_nodes: Dictionary = {}
var _ice_bodies: Dictionary = {}
var _pending_chunks: Array[Vector2i] = []
var _queued_lookup: Dictionary = {}
## body_id -> { frozen: ShaderMaterial }. A body's entry is dropped when the
## registry changes it, because a retyped body is a different colour, wave and
## emission.
var _materials: Dictionary = {}

var _wind_direction := Vector2(1.0, 0.0)
var _wind_strength := 0.4

## What lies past the last column (`map_editor.md` §6.1). `BORDER_NOTHING` draws
## nothing at all and makes the rim of the board a bank; `BORDER_OCEAN` and
## `BORDER_LAVA` draw the plane and make the rim open water (or lava), so the
## shore band does not paint a beach along a coastline that continues.
var _border_kind: StringName = MapMeta.BORDER_NOTHING
var _border_level := 0
var _border_node: MeshInstance3D = null


func _ready() -> void:
	set_process(true)


func configure(next_water: WaterGrid, next_terrain: TerrainGrid, water_service: WaterService = null, terrain_service: TerrainService = null) -> void:
	water = next_water
	terrain = next_terrain
	for node: Node in _chunk_nodes.values():
		node.queue_free()
	for node: Node in _ice_bodies.values():
		node.queue_free()
	_chunk_nodes.clear()
	_ice_bodies.clear()
	_pending_chunks.clear()
	_queued_lookup.clear()
	_materials.clear()
	if water == null:
		return
	if water_service != null:
		if not water_service.registry_changed.is_connected(_on_registry_changed):
			water_service.registry_changed.connect(_on_registry_changed)
		if not water_service.edit_committed.is_connected(_on_water_committed):
			water_service.edit_committed.connect(_on_water_committed)
	# Depth is water level minus ground, so raising the bottom of a lake changes
	# this surface without the water layer being touched at all.
	if terrain_service != null and not terrain_service.edit_committed.is_connected(_on_terrain_committed):
		terrain_service.edit_committed.connect(_on_terrain_committed)
	_mark_all_chunks_dirty()


## What the map says lies beyond the board (§6.1). Passed from the header rather
## than guessed, because the same flat rim means "coast continues" on an ocean map
## and "edge of the world" on a landlocked one.
func configure_border(kind: StringName, level: int) -> void:
	_border_kind = kind
	_border_level = level
	_rebuild_border()
	_mark_all_chunks_dirty()


func _process(_delta: float) -> void:
	if water == null:
		return
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


## A registry change reaches the cells it says it reaches and no others. Creating
## an empty body reaches none, and remeshing the board for it was 36 chunks of
## work — at the standard board size, 256 — to draw nothing new.
func _on_registry_changed(affected_cells: Array[Vector2i]) -> void:
	if water == null:
		return
	# The material cache is keyed by body id, not by cell, so it is dropped whole
	# whichever cells moved: a body that came back on undo must be rebuilt from the
	# registry entry that came back with it.
	_materials.clear()
	_rebuild_border()
	for cell: Vector2i in affected_cells:
		_queue_chunk(_chunk_of(cell))


func _on_water_committed(delta: WaterDelta) -> void:
	if water == null:
		return
	for cell: Vector2i in delta.cells:
		_queue_chunk(_chunk_of(cell))


func _on_terrain_committed(delta: TerrainDelta) -> void:
	if water == null or not delta.changes_geometry():
		return
	# Wetness and the shore band are derived from terrain height as well as water.
	# A raised lake bed can drain a cell without the water layer being touched.
	# Queued by chunk range rather than by cell: a cascade moves thousands of
	# columns and almost all of them land in chunks already queued, so walking the
	# 7×7 neighbourhood of each one was tens of thousands of iterations to produce
	# the same handful of chunks.
	for cell: Vector2i in delta.cells:
		var first := _chunk_of(cell - Vector2i(SHORE_RANGE_CELLS, SHORE_RANGE_CELLS))
		var last := _chunk_of(cell + Vector2i(SHORE_RANGE_CELLS, SHORE_RANGE_CELLS))
		for z in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				_queue_chunk(Vector2i(x, z))


func _mark_all_chunks_dirty() -> void:
	if water == null or water.board_cells <= 0:
		return
	var first := _chunk_of(water.min_cell())
	var last := _chunk_of(water.max_cell())
	for z in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			_queue_chunk(Vector2i(x, z))


func _queue_chunk(chunk: Vector2i) -> void:
	if _queued_lookup.has(chunk):
		return
	_queued_lookup[chunk] = true
	_pending_chunks.append(chunk)


func _chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x) / TerrainGrid.CHUNK_CELLS),
		floori(float(cell.y) / TerrainGrid.CHUNK_CELLS),
	)


# --- Meshing ------------------------------------------------------------------

func _rebuild_chunk(chunk: Vector2i) -> void:
	var shore := _shore_distance_of_chunk(chunk)
	var ice_triangles := PackedVector3Array()
	var groups := _collect_groups(chunk, shore, ice_triangles)
	_rebuild_ice_body(chunk, ice_triangles)
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
## because those are exactly the cells that share a material. The top quads of the
## frozen ones are appended to `ice_triangles` as well — that is the floor.
func _collect_groups(chunk: Vector2i, shore: PackedByteArray, ice_triangles: PackedVector3Array) -> Dictionary:
	var builders: Dictionary = {}
	var origin := chunk * TerrainGrid.CHUNK_CELLS
	for local_z in TerrainGrid.CHUNK_CELLS:
		for local_x in TerrainGrid.CHUNK_CELLS:
			var cell := origin + Vector2i(local_x, local_z)
			if not water.is_inside(cell) or not water.is_wet(terrain, cell):
				continue
			var frozen := water.is_frozen(cell)
			var key := (water.body_id_at(cell) << 1) | (1 if frozen else 0)
			if not builders.has(key):
				builders[key] = _new_builder()
			_emit_cell(builders[key], cell, _shore_metres(shore, chunk, cell), ice_triangles if frozen else null)
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
func _emit_cell(builder: Dictionary, cell: Vector2i, shore: float, ice_triangles: Variant) -> void:
	var size := water.cell_size
	var level := float(water.height_of(cell)) * TerrainGrid.HEIGHT_STEP + SURFACE_EPSILON
	var west := float(cell.x) * size
	var north := float(cell.y) * size
	var east := west + size
	var south := north + size
	var depth := water.depth_metres_at(terrain, cell)
	var tint := Color(depth, shore, 0.0, 1.0)

	var nw := Vector3(west, level, north)
	var ne := Vector3(east, level, north)
	var se := Vector3(east, level, south)
	var sw := Vector3(west, level, south)
	_add_quad(builder, nw, ne, se, sw, Vector3.UP, tint)
	if ice_triangles != null:
		# The collider is the top quad only. A skirt is a vertical wall a walker
		# would catch on at the lip of a river step, and the ice they are standing
		# on is flat by definition.
		var triangles: PackedVector3Array = ice_triangles
		for vertex: Vector3 in [nw, ne, se, nw, se, sw]:
			triangles.append(vertex)

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


# --- Ice collision --------------------------------------------------------------

## The floor a frozen cell publishes to routing, made real for physics (§9.6).
##
## Without it `NavGrid.height_at` puts the route on the ice while `move_and_slide`
## drops the walker to the lake bed — the two answers differ by the whole depth of
## the lake, and nothing in either layer can notice. A chunk with no ice keeps no
## body at all, so a map that never freezes pays nothing.
func _rebuild_ice_body(chunk: Vector2i, triangles: PackedVector3Array) -> void:
	if triangles.is_empty():
		var stale: StaticBody3D = _ice_bodies.get(chunk)
		if stale != null:
			# Detached before it is freed, not merely queued: `queue_free` lands at the
			# end of the frame, and until then the thawed lake still carries whoever is
			# standing on it.
			remove_child(stale)
			stale.queue_free()
			_ice_bodies.erase(chunk)
		return
	var body: StaticBody3D = _ice_bodies.get(chunk)
	if body == null:
		body = StaticBody3D.new()
		body.name = "Ice_%d_%d" % [chunk.x, chunk.y]
		body.collision_layer = COLLISION_LAYER
		body.collision_mask = 0
		body.add_child(CollisionShape3D.new())
		add_child(body)
		_ice_bodies[chunk] = body
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(triangles)
	(body.get_child(0) as CollisionShape3D).shape = shape


# --- Materials ----------------------------------------------------------------

## One material per body per state, built from the body itself: the colour, the
## wave and the foam of a river ARE the river's, and there is nowhere else for a
## renderer to look them up (§9.2).
func _material_for(body_id: int, frozen: bool) -> ShaderMaterial:
	var by_state: Dictionary = _materials.get(body_id, {})
	if by_state.has(frozen):
		return by_state[frozen]
	var material := _material_from_body(water.body(body_id), frozen)
	by_state[frozen] = material
	_materials[body_id] = by_state
	return material


func _material_from_body(body: WaterBody, frozen: bool) -> ShaderMaterial:
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
	return material


# --- Border ocean ---------------------------------------------------------------

## The world past the last column (§6.1): four bands around the board, at the
## border level, with the shader of the map's own sea. Four and not one big quad
## with the board cut out of it, because a quad under the board would z-fight with
## every shallow cell of the map.
##
## No collider and no navigation. A citizen cannot reach it — the rim of the board
## is the rim of the world for routing — so giving it either would only invite
## something to try.
func _rebuild_border() -> void:
	if _border_node != null:
		# Detached now, freed at the end of the frame: switching the border off must
		# take the horizon away in the same call that says so.
		remove_child(_border_node)
		_border_node.queue_free()
		_border_node = null
	if water == null or not MapMeta.has_border_fill_static(_border_kind) or water.board_cells <= 0:
		return
	var half := float(water.board_half_cells) * water.cell_size
	var far := half + BORDER_OCEAN_REACH
	var level := float(_border_level) * TerrainGrid.HEIGHT_STEP + SURFACE_EPSILON
	var builder := _new_builder()
	var tint := Color(4.0, float(SHORE_RANGE_CELLS) * water.cell_size, 0.0, 1.0)
	_add_border_band(builder, -far, far, -far, -half, level, tint)
	_add_border_band(builder, -far, far, half, far, level, tint)
	_add_border_band(builder, -far, -half, -half, half, level, tint)
	_add_border_band(builder, half, far, -half, half, level, tint)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = builder["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = builder["normals"]
	arrays[Mesh.ARRAY_COLOR] = builder["colors"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	_border_node = MeshInstance3D.new()
	_border_node.name = "BorderPlane"
	_border_node.mesh = mesh
	_border_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_border_node.set_surface_override_material(0, _material_from_body(_border_body(), false))
	add_child(_border_node)


static func _add_border_band(builder: Dictionary, west: float, east: float, north: float, south: float, level: float, tint: Color) -> void:
	if east <= west or south <= north:
		return
	_add_quad(
		builder,
		Vector3(west, level, north), Vector3(east, level, north),
		Vector3(east, level, south), Vector3(west, level, south),
		Vector3.UP, tint,
	)


## The map's own border body if it has one, so the horizon and the coast are the
## same water (or lava); a default body otherwise, which is what a border means
## on a map whose author has not painted a drop yet.
func _border_body() -> WaterBody:
	var body_type := WaterBody.Type.SEA if _border_kind == MapMeta.BORDER_OCEAN else WaterBody.Type.LAVA
	if water != null:
		for body: WaterBody in water.bodies():
			if body.type == body_type:
				return body
	return WaterBody.of_type(WaterBody.MIN_ID, body_type)


# --- Shore distance -----------------------------------------------------------

## Distance to the nearest dry cell, capped at `SHORE_RANGE_CELLS`, for one chunk
## plus the ring of cells that can reach into it.
##
## Computed per chunk rather than per board. The board-wide version walked all
## 65 536 columns of a standard map on every stroke to shade one chunk; a bank
## further than `SHORE_RANGE_CELLS` away cannot darken a cell inside the chunk by
## definition, so the padded region is all the input there ever was.
func _shore_distance_of_chunk(chunk: Vector2i) -> PackedByteArray:
	var span := TerrainGrid.CHUNK_CELLS + SHORE_RANGE_CELLS * 2
	var distances := PackedByteArray()
	distances.resize(span * span)
	distances.fill(SHORE_RANGE_CELLS)
	if water == null or terrain == null:
		return distances
	var origin := _shore_origin(chunk)
	var frontier: Array[Vector2i] = []
	for local_z in span:
		for local_x in span:
			var cell := origin + Vector2i(local_x, local_z)
			if _is_bank(cell):
				distances[local_z * span + local_x] = 0
				frontier.append(Vector2i(local_x, local_z))
	var distance := 0
	while distance < SHORE_RANGE_CELLS and not frontier.is_empty():
		distance += 1
		var next: Array[Vector2i] = []
		for local: Vector2i in frontier:
			for offset: Vector2i in WaterGrid.ORTHOGONAL_OFFSETS:
				var neighbour := local + offset
				if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= span or neighbour.y >= span:
					continue
				var index := neighbour.y * span + neighbour.x
				if distances[index] <= distance:
					continue
				distances[index] = distance
				next.append(neighbour)
		frontier = next
	return distances


## Whether a cell is a bank the shore band fades out from. Off the board that
## depends on the border: with an ocean out there the coastline continues and the
## rim is open water, without one the board simply ends.
func _is_bank(cell: Vector2i) -> bool:
	if not water.is_inside(cell):
		return not MapMeta.has_border_fill_static(_border_kind)
	return not water.is_wet(terrain, cell)


func _shore_origin(chunk: Vector2i) -> Vector2i:
	return chunk * TerrainGrid.CHUNK_CELLS - Vector2i(SHORE_RANGE_CELLS, SHORE_RANGE_CELLS)


func _shore_metres(distances: PackedByteArray, chunk: Vector2i, cell: Vector2i) -> float:
	var span := TerrainGrid.CHUNK_CELLS + SHORE_RANGE_CELLS * 2
	var local := cell - _shore_origin(chunk)
	if local.x < 0 or local.y < 0 or local.x >= span or local.y >= span:
		return float(SHORE_RANGE_CELLS) * water.cell_size
	return float(distances[local.y * span + local.x]) * water.cell_size
