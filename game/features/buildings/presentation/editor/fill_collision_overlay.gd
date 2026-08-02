class_name FillCollisionOverlay
extends Node3D

## Wireframe collision overlay for fill objects (design §4.2 — authoring preview,
## not runtime). Physical shapes are read from the same asset PackedScene used by
## the game. The editor never authors or approximates a second collision shape.
##
## Extracted from BuildingFillModeController to isolate the visual overlay lifecycle.

const FillObjectRecordScript = preload("res://game/features/buildings/domain/editor/fill_object_record.gd")

var _overlays: Dictionary = {}  ## object id (String) -> Array[MeshInstance3D]
var _active: bool = false


func toggle(pressed: bool) -> void:
	_active = pressed
	if not pressed:
		clear()
	else:
		rebuild()


func clear() -> void:
	for group in _overlays.values():
		for mesh: MeshInstance3D in group:
			mesh.queue_free()
	_overlays.clear()


func rebuild(blueprint: RefCounted = null) -> void:
	clear()
	if not _active:
		return
	if blueprint == null:
		return
	for record: FillObjectRecordScript in blueprint.objects:
		_build_for(record)


func _build_for(record: FillObjectRecordScript) -> void:
	var asset := WorldAssetCatalog.get_asset(record.asset_id)
	if asset == null:
		return
	var policy := asset.collision_policy
	if policy == WorldAssetDef.COLLISION_NONE and not asset.blocking_navigation:
		return
	var meshes: Array[MeshInstance3D] = []
	if policy == WorldAssetDef.COLLISION_SCENE:
		meshes.append_array(_scene_collision_meshes(asset, record))
	# Blocking-navigation marker: a small red sphere on top.
	if asset.blocking_navigation:
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		marker.mesh = sphere
		var mat2 := StandardMaterial3D.new()
		mat2.albedo_color = Color(1.0, 0.1, 0.1, 0.8)
		mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = mat2
		marker.position = record.pos + Vector3(0.0, asset.footprint_m().y * record.scale.x + 0.15, 0.0)
		add_child(marker)
		meshes.append(marker)
	_overlays[record.id] = meshes


func _scene_collision_meshes(asset: WorldAssetDef, record: FillObjectRecordScript) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var packed := load(asset.scene_path) as PackedScene
	var instance := packed.instantiate() as Node3D if packed != null else null
	if instance == null:
		return result
	for shape_node: Node in instance.find_children("*", "CollisionShape3D", true, false):
		var collision := shape_node as CollisionShape3D
		if collision == null or collision.disabled or collision.shape == null:
			continue
		var preview := MeshInstance3D.new()
		preview.mesh = collision.shape.get_debug_mesh()
		preview.transform = Transform3D(Basis.from_euler(record.rot * PI / 180.0).scaled(record.scale), record.pos) * collision.transform
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.4, 0.2, 0.3)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		preview.material_override = material
		add_child(preview)
		result.append(preview)
	instance.free()
	return result


func is_empty() -> bool:
	return _overlays.is_empty()
