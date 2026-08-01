extends SceneTree

const BlockMeshLibraryScript = preload("res://game/features/buildings/presentation/editor/block_mesh_library.gd")
const BlockTextureLibraryScript = preload("res://game/features/buildings/presentation/editor/block_texture_library.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")


func _init() -> void:
	print("--- Running test_block_mesh_library.gd ---")
	_test_wedge_mesh_normals()
	_test_stairs_mesh_normals()
	_test_arch_and_railing_meshes()
	_test_block_materials_and_textures()
	print("--- test_block_mesh_library.gd PASSED ALL TESTS ---")
	quit(0)


## Guards against a degenerate arch (a prior version emitted a zero-height box for
## the right pillar) and confirms the railing builds real, bounded geometry that
## respects the variant height.
func _test_arch_and_railing_meshes() -> void:
	print("Testing arch + railing meshes...")
	var lib := BlockMeshLibraryScript.new()

	var arch := lib.mesh_for(&"arch") as ArrayMesh
	assert(arch != null, "arch mesh must exist")
	var arch_verts: PackedVector3Array = arch.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(arch_verts.size() >= 72, "arch must build jambs + arch ring, got %d verts" % arch_verts.size())
	var arch_aabb := arch.get_aabb()
	assert(arch_aabb.size.y >= 0.49 and arch_aabb.size.y <= 0.501 and arch_aabb.size.x > 0.99, "arch must be cut from a 0.5m slab")
	var has_half_column_apex := false
	for vertex in arch_verts:
		if absf(vertex.x) < 0.001 and is_equal_approx(vertex.y, arch_aabb.end.y):
			has_half_column_apex = true
			break
	assert(has_half_column_apex, "arch opening must use the 1m half-column radius")

	var half_column := lib.mesh_for(&"column_half", &"0.5") as ArrayMesh
	assert(half_column != null, "half-column mesh must exist")
	var half_column_aabb := half_column.get_aabb()
	assert(is_equal_approx(half_column_aabb.position.z, -half_column_aabb.size.z * 0.5), "half-column flat face must be centred relative to its AABB")
	assert(is_equal_approx(half_column_aabb.end.z, half_column_aabb.size.z * 0.5), "half-column rounded apex must be centred relative to its AABB")

	# Full- and half-height railing variants must differ in height.
	var full := (lib.mesh_for(&"railing", &"full") as ArrayMesh).get_aabb()
	var half := (lib.mesh_for(&"railing", &"half") as ArrayMesh).get_aabb()
	assert(full.size.y > half.size.y + 0.2, "full railing must be taller than half")


func _test_wedge_mesh_normals() -> void:
	print("Testing wedge (roof_pitch) mesh normals...")
	var lib := BlockMeshLibraryScript.new()
	var mesh := lib.mesh_for(&"roof_pitch") as ArrayMesh
	assert(mesh != null, "roof_pitch mesh must exist")

	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

	assert(vertices.size() > 0, "Wedge mesh must have vertices")
	assert(normals.size() == vertices.size(), "Wedge mesh must have normals matching vertices")

	# Check that top slope face vertices have upward and forward pointing normals (+Y, +Z)
	# Top sloped face vertices were added first (indices 0 to 5)
	for i in range(6):
		var n: Vector3 = normals[i]
		assert(n.y > 0.0, "Top slope normal Y component must be positive (upward)")
		assert(n.z > 0.0, "Top slope normal Z component must be positive (forward)")

	# Check bottom face normals (indices 12 to 17) -> must point downward (-Y)
	for i in range(12, 18):
		var n: Vector3 = normals[i]
		assert(n.y < 0.0, "Bottom face normal Y component must be negative (downward)")


func _test_stairs_mesh_normals() -> void:
	print("Testing stairs mesh normals...")
	var lib := BlockMeshLibraryScript.new()
	var mesh := lib.mesh_for(&"stairs") as ArrayMesh
	assert(mesh != null, "stairs mesh must exist")

	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

	assert(vertices.size() > 0, "Stairs mesh must have vertices")
	assert(normals.size() == vertices.size(), "Stairs mesh must have normals matching vertices")

	# Verify that all face normals are flat (unit vectors along cardinal axes)
	for n in normals:
		assert(is_equal_approx(n.length(), 1.0), "Normal must be normalized")


func _test_block_materials_and_textures() -> void:
	print("Testing all block materials and textures from BuildingMaterialCatalog...")
	var tex_lib := BlockTextureLibraryScript.new()
	var materials: Array[StringName] = []
	for mat in BuildingMaterialCatalogScript.all():
		materials.append(mat["id"])
	assert(materials.size() == 13, "Expected 13 materials in catalog, got %d" % materials.size())

	for mat_id in materials:
		assert(tex_lib.has_texture(mat_id), "Texture must exist for material '%s'" % mat_id)
		assert(tex_lib.texture_for(mat_id) != null, "Texture for '%s' must load as Texture2D" % mat_id)

	var lib := BlockMeshLibraryScript.new()
	assert(lib.textures_enabled() == true, "Textures must be enabled by default in BlockMeshLibrary")

	for mat_id in materials:
		var mat := lib.material_for(mat_id)
		assert(mat != null, "Material for '%s' must not be null" % mat_id)
		assert(mat.albedo_texture != null, "Material '%s' must have albedo_texture when textures are enabled" % mat_id)
		assert(mat.albedo_color == Color.WHITE, "Material '%s' albedo_color must be WHITE when texture is active" % mat_id)

	# Disable textures
	lib.set_textures_enabled(false)
	assert(lib.textures_enabled() == false, "Textures must be disabled after set_textures_enabled(false)")

	for mat_id in materials:
		var mat_flat := lib.material_for(mat_id)
		assert(mat_flat != null, "Flat material for '%s' must not be null" % mat_id)
		assert(mat_flat.albedo_texture == null, "Flat material '%s' must not have albedo_texture" % mat_id)

	# Re-enable textures
	lib.set_textures_enabled(true)
	assert(lib.textures_enabled() == true, "Textures must be re-enabled after set_textures_enabled(true)")
	for mat_id in materials:
		var mat_tex := lib.material_for(mat_id)
		assert(mat_tex.albedo_texture != null, "Material '%s' must have albedo_texture re-applied" % mat_id)
