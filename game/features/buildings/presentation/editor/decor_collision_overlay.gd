class_name DecorCollisionOverlay
extends Node3D

## Wireframe collision overlay for decor objects (design §4.2 — authoring preview,
## not runtime). When toggled on, draws translucent boxes for each object whose
## collision_policy is not "none", and blocking-navigation objects get an
## additional coloured sphere marker.
##
## Extracted from DecorModeController to isolate the visual overlay lifecycle.

const DecorObjectRecordScript = preload("res://game/features/buildings/domain/editor/decor_object_record.gd")

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
	for record: DecorObjectRecordScript in blueprint.objects:
		_build_for(record)


func _build_for(record: DecorObjectRecordScript) -> void:
	var asset := WorldAssetCatalog.get_asset(record.asset_id)
	if asset == null:
		return
	var policy := asset.collision_policy
	if policy == WorldAssetDef.COLLISION_NONE and not asset.blocking_navigation:
		return
	var meshes: Array[MeshInstance3D] = []
	var size := asset.footprint_m()
	# Scale the collision box by the object's uniform scale.
	var scaled_size := size * record.scale.x
	# Collision box (box or footprint policy).
	if policy == WorldAssetDef.COLLISION_BOX or policy == WorldAssetDef.COLLISION_FOOTPRINT:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = scaled_size
		box.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.4, 0.2, 0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		box.material_override = mat
		box.position = record.pos
		box.rotation_degrees = record.rot
		add_child(box)
		meshes.append(box)
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
		marker.position = record.pos + Vector3(0.0, scaled_size.y * 0.5 + 0.15, 0.0)
		add_child(marker)
		meshes.append(marker)
	_overlays[record.id] = meshes


func is_empty() -> bool:
	return _overlays.is_empty()
