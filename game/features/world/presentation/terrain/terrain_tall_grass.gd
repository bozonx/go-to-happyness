class_name TerrainTallGrass
extends RefCounted

## Chunk-local visual decoration for `grass_tall` terrain (§7.4).
##
## Up to two crossed alpha-cutout cards give a column a readable grassy
## silhouette. The cards are deterministic derivatives of the terrain cell: they
## are not saved, have no collision, and disappear as wear and snow cover the
## surface. `GridTerrainWorld` rebuilds only this cheap MultiMesh when surface
## details change; the terrain mesh remains untouched.

const TEXTURE_PATH := "res://game/features/world/presentation/terrain/assets/grass_tall_meadow.png"
const SHADER_PATH := "res://game/features/world/presentation/terrain/tall_grass.gdshader"

const CARD_WIDTH := 0.82
const CARD_HEIGHT := 1.25
const SURFACE_LIFT := 0.015

var _mesh: ArrayMesh = null
var _material: ShaderMaterial = null


func build_chunk(grid: TerrainGrid, chunk: Vector2i) -> MultiMesh:
	var transforms: Array[Transform3D] = []
	var origin := grid.chunk_origin_cell(chunk)
	for local_z in TerrainGrid.CHUNK_CELLS:
		for local_x in TerrainGrid.CHUNK_CELLS:
			var cell := origin + Vector2i(local_x, local_z)
			if not _shows_grass(grid, cell):
				continue
			# Untouched meadow gets two clumps per square metre. Wear 1 or a light
			# dusting of snow halves that density; the terminal states were rejected
			# by `_shows_grass` above. Density changes, individual plants do not shrink.
			var density := 1 if grid.wear_at(cell) == 1 or grid.snow_depth_at(cell) == 1 else 2
			for slot in density:
				var seed := _cell_hash(cell) ^ ((slot + 1) * 83492791)
				var offset_x := 0.12 + _unit(seed, 0) * 0.76
				var offset_z := 0.12 + _unit(seed, 1) * 0.76
				var x := (float(cell.x) + offset_x) * grid.cell_size
				var z := (float(cell.y) + offset_z) * grid.cell_size
				var y := grid.height_at(Vector3(x, 0.0, z)) + SURFACE_LIFT
				var yaw := _unit(seed, 2) * TAU
				var scale := lerpf(0.78, 1.08, _unit(seed, 3))
				var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale))
				transforms.append(Transform3D(basis, Vector3(x, y, z)))

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _card_mesh()
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	return multimesh


func material() -> ShaderMaterial:
	if _material != null:
		return _material
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH)
	_material.set_shader_parameter(&"grass_texture", load(TEXTURE_PATH))
	return _material


func set_wind(direction: Vector2, strength: float) -> void:
	var axis := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	material().set_shader_parameter(&"wind_direction", axis)
	material().set_shader_parameter(&"wind_strength", clampf(strength, 0.0, 1.0))


func _shows_grass(grid: TerrainGrid, cell: Vector2i) -> bool:
	return (
		grid.is_inside(cell)
		and not grid.is_hole(cell)
		and grid.material_of(cell) == TerrainMaterialCatalog.GRASS_TALL
		and grid.wear_at(cell) < TerrainDetailCodec.MAX_WEAR
		and grid.snow_depth_at(cell) < 2
	)


func _card_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var half_width := CARD_WIDTH * 0.5
	var vertices := PackedVector3Array([
		Vector3(-half_width, 0.0, 0.0), Vector3(half_width, 0.0, 0.0),
		Vector3(half_width, CARD_HEIGHT, 0.0), Vector3(-half_width, CARD_HEIGHT, 0.0),
		Vector3(0.0, 0.0, -half_width), Vector3(0.0, 0.0, half_width),
		Vector3(0.0, CARD_HEIGHT, half_width), Vector3(0.0, CARD_HEIGHT, -half_width),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0),
		Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0),
	])
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7])
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _mesh


static func _cell_hash(cell: Vector2i) -> int:
	return (cell.x * 73856093) ^ (cell.y * 19349663) ^ 0x5F356495


static func _unit(seed: int, channel: int) -> float:
	var mixed := seed ^ ((channel + 1) * 83492791)
	mixed = ((mixed >> 16) ^ mixed) * 0x45D9F3B
	mixed = ((mixed >> 16) ^ mixed) * 0x45D9F3B
	mixed = (mixed >> 16) ^ mixed
	return float(mixed & 0xFFFF) / 65535.0
