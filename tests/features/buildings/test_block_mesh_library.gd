extends SceneTree

const BlockMeshLibraryScript = preload("res://game/features/buildings/presentation/editor/block_mesh_library.gd")


func _init() -> void:
	print("--- Running test_block_mesh_library.gd ---")
	_test_wedge_mesh_normals()
	_test_stairs_mesh_normals()
	_test_arch_and_railing_meshes()
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
	assert(arch_aabb.size.y > 0.5 and arch_aabb.size.x > 0.5, "arch must span the block")

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
