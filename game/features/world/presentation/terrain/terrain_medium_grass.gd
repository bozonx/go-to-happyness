class_name TerrainMediumGrass
extends RefCounted

## Medium-height decoration derived from ordinary `grass` terrain (§7.4).
##
## This is deliberately a separate density layer from `grass_tall`: ordinary
## ground remains easy to read and walk, while the tall material forms a much
## stronger silhouette. Both are deterministic chunk MultiMeshes and neither is
## saved as a second list of vegetation.

const TEXTURE_PATH := "res://game/features/world/presentation/terrain/assets/grass_medium_atlas.png"
const SHADER_PATH := "res://game/features/world/presentation/terrain/tall_grass.gdshader"
const VARIANT_COUNT := 8

const CARD_WIDTH := 0.46
const CARD_HEIGHT := 0.50
const SURFACE_LIFT := 0.012

var _mesh: ArrayMesh = null
var _material: ShaderMaterial = null


func build_chunk(grid: TerrainGrid, chunk: Vector2i) -> MultiMesh:
	var transforms: Array[Transform3D] = []
	var variants: Array[int] = []
	var origin := grid.chunk_origin_cell(chunk)
	for local_z in TerrainGrid.CHUNK_CELLS:
		for local_x in TerrainGrid.CHUNK_CELLS:
			var cell := origin + Vector2i(local_x, local_z)
			var density := _density_at(grid, cell)
			for slot in density:
				var seed := _cell_hash(cell) ^ ((slot + 1) * 961748927)
				var offset_x := 0.1 + _unit(seed, 0) * 0.8
				var offset_z := 0.1 + _unit(seed, 1) * 0.8
				var x := (float(cell.x) + offset_x) * grid.cell_size
				var z := (float(cell.y) + offset_z) * grid.cell_size
				var y := grid.height_at(Vector3(x, 0.0, z)) + SURFACE_LIFT
				var yaw := _unit(seed, 2) * TAU
				var width_scale := lerpf(0.68, 1.12, _unit(seed, 3))
				var height_scale := lerpf(0.72, 1.10, _unit(seed, 4))
				var basis := Basis(Vector3.UP, yaw).scaled(Vector3(width_scale, height_scale, width_scale))
				transforms.append(Transform3D(basis, Vector3(x, y, z)))
				variants.append(TerrainMaterialVariants.clamp_variant(TerrainMaterialCatalog.DEFAULT_INDEX, grid.variant_at(cell)))

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _card_mesh()
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_custom_data(index, atlas_custom_data_for(variants[index]))
	return multimesh


## Encodes the atlas column in the normalized channel MultiMesh custom data
## guarantees across renderers. The shader reverses this exact mapping.
static func atlas_custom_data_for(variant: int) -> Color:
	var clamped := clampi(variant, 0, VARIANT_COUNT - 1)
	return Color(float(clamped) / float(VARIANT_COUNT - 1), 0.0, 0.0, 0.0)


func material() -> ShaderMaterial:
	if _material != null:
		return _material
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH)
	_material.set_shader_parameter(&"grass_texture", load(TEXTURE_PATH))
	_material.set_shader_parameter(&"atlas_columns", float(VARIANT_COUNT))
	_material.set_shader_parameter(&"grass_tint", Vector3(0.68, 0.78, 0.58))
	_material.set_shader_parameter(&"sway_metres", 0.065)
	_material.set_shader_parameter(&"wind_strength", 0.26)
	return _material


func set_wind(direction: Vector2, strength: float) -> void:
	var axis := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	material().set_shader_parameter(&"wind_direction", axis)
	material().set_shader_parameter(&"wind_strength", clampf(strength, 0.0, 1.0))


func set_lod_distance(distance: float) -> void:
	material().set_shader_parameter(&"lod_fade_start", distance * 0.78)
	material().set_shader_parameter(&"lod_fade_end", distance)


func _density_at(grid: TerrainGrid, cell: Vector2i) -> int:
	if (
		not grid.is_inside(cell)
		or grid.is_hole(cell)
		or grid.material_of(cell) != TerrainMaterialCatalog.GRASS
		or grid.wear_at(cell) >= TerrainDetailCodec.MAX_WEAR
		or grid.snow_depth_at(cell) >= 2
	):
		return 0
	if grid.wear_at(cell) == 1 or grid.snow_depth_at(cell) == 1:
		return 1
	match grid.variant_at(cell):
		1: return 4 # lush
		2: return 2 # parched
		_: return 3 # plain and the five flowering variants


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
	return (cell.x * 73856093) ^ (cell.y * 19349663) ^ 0x24A39B17


static func _unit(seed: int, channel: int) -> float:
	var mixed := seed ^ ((channel + 1) * 83492791)
	mixed = ((mixed >> 16) ^ mixed) * 0x45D9F3B
	mixed = ((mixed >> 16) ^ mixed) * 0x45D9F3B
	mixed = (mixed >> 16) ^ mixed
	return float(mixed & 0xFFFF) / 65535.0
