extends SceneTree

## Diagnostic: instantiate every catalog asset and compare its real visual bounds
## with the size the catalog declares.


func _init() -> void:
	for asset in WorldAssetCatalog.get_all_assets():
		var packed := load(asset.scene_path) as PackedScene
		var instance := packed.instantiate()
		var bounds := _bounds_of(instance, Transform3D.IDENTITY)
		if bounds.size == Vector3.ZERO:
			print("%-16s (нет мешей)" % asset.id)
			instance.free()
			continue
		print("%-16s bounds=(%.2f, %.2f, %.2f) y_min=%.2f  declared=(%.2f, %.2f, %.2f)" % [
			asset.id, bounds.size.x, bounds.size.y, bounds.size.z, bounds.position.y,
			asset.size_m.x, asset.size_m.y, asset.size_m.z,
		])
		instance.free()
	quit(0)


func _bounds_of(node: Node, parent_transform: Transform3D) -> AABB:
	var here := parent_transform
	if node is Node3D:
		here = parent_transform * (node as Node3D).transform
	var total := AABB()
	var has_any := false
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var local := mesh_instance.mesh.get_aabb()
		total = _transformed(local, here)
		has_any = true
	for child in node.get_children():
		var child_bounds := _bounds_of(child, here)
		if child_bounds.size == Vector3.ZERO:
			continue
		total = child_bounds if not has_any else total.merge(child_bounds)
		has_any = true
	return total if has_any else AABB()


func _transformed(local: AABB, transform: Transform3D) -> AABB:
	var result := AABB(transform * local.position, Vector3.ZERO)
	for index in 8:
		result = result.expand(transform * local.get_endpoint(index))
	return result
