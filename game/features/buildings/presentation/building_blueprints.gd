class_name BuildingBlueprints
extends RefCounted

## Runtime adapter for authored `.gdbuilding.json` content. Building geometry,
## access anchors and zones all originate in BuildingBlueprintLibrary.

const BuildingModuleScene = preload("res://game/features/buildings/presentation/building_module.tscn")
const BLOCK_SIZE := 1.0
const FOUNDATION_SKIRT := 3.0

static var _block_meshes: BlockMeshLibrary = null


static func get_blueprint(building_type: String) -> Dictionary:
	var blueprint := BuildingBlueprintLibrary.get_blueprint(building_type)
	if blueprint == null:
		push_error("No authored blueprint for building type '%s'." % building_type)
		return {}
	return _blueprint_from_library(building_type, blueprint)


static func create_module(module: Dictionary) -> StaticBody3D:
	if module.has("block_id"):
		return _create_block_module(module)
	if module.has("asset_id") or module.get("kind") == "decor":
		var decor := _create_decor_module(module)
		if decor != null:
			return decor
		push_error("Could not create authored decor module '%s'." % module.get("asset_id", ""))
	return null


static func _create_decor_module(module: Dictionary) -> StaticBody3D:
	var asset_id: StringName = StringName(module.get("asset_id", ""))
	var asset := WorldAssetCatalog.get_asset(asset_id)
	if asset == null:
		push_error("Unknown authored decor asset '%s'." % asset_id)
		return null
	var scene := load(asset.scene_path) as PackedScene
	if scene == null:
		return null
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return null

	var body: StaticBody3D = BuildingModuleScene.instantiate()
	body.position = module.get("position", Vector3.ZERO)
	body.rotation_degrees = module.get("rotation", module.get("rot", Vector3.ZERO))
	body.scale = module.get("scale", Vector3.ONE)
	body.set_meta("building_module", true)
	body.set_meta("module_kind", "decor")

	var mesh_instance := body.get_node("MeshInstance3D") as MeshInstance3D
	if mesh_instance != null:
		mesh_instance.mesh = null
	var collision := body.get_node("CollisionShape3D") as CollisionShape3D
	if collision != null:
		var shape := BoxShape3D.new()
		var extent := asset.footprint_m()
		shape.size = extent
		collision.shape = shape
		collision.position.y = extent.y * 0.5
	body.add_child(instance)
	if instance.has_method("apply_decor_properties"):
		instance.call("apply_decor_properties", module.get("appearance", module.get("properties", {})))
	return body


static func _create_block_module(module: Dictionary) -> StaticBody3D:
	if _block_meshes == null:
		_block_meshes = BlockMeshLibrary.new()
	var block_id: StringName = module["block_id"]
	var material_id: StringName = module.get("material_id", &"branches")
	var variant: StringName = StringName(module.get("variant", ""))
	var body: StaticBody3D = BuildingModuleScene.instantiate()
	body.position = module["position"]
	body.rotation_degrees = Vector3(
		90.0 * float(int(module.get("rot_x", 0)) % 4),
		90.0 * float(int(module.get("rot", 0)) % 4),
		90.0 * float(int(module.get("rot_z", 0)) % 4))
	body.set_meta("building_module", true)
	body.set_meta("module_kind", module.get("kind", "block"))
	var mesh_instance := body.get_node("MeshInstance3D") as MeshInstance3D
	var size := BuildingBlockCatalog.size_of(block_id, variant)
	var collision := body.get_node("CollisionShape3D") as CollisionShape3D
	var shape: Shape3D
	if BuildingBlockCatalog.extends_down(block_id):
		var skirted := Vector3(size.x, size.y + FOUNDATION_SKIRT, size.z)
		var box := BoxMesh.new()
		box.size = skirted
		mesh_instance.mesh = box
		mesh_instance.position.y = -FOUNDATION_SKIRT * 0.5
		var foundation_shape := BoxShape3D.new()
		foundation_shape.size = skirted
		shape = foundation_shape
		collision.position.y = -FOUNDATION_SKIRT * 0.5
	else:
		mesh_instance.mesh = _block_meshes.mesh_for(block_id, variant)
		if BuildingBlockCatalog.mesh_shape_of(block_id, variant) == BuildingBlockCatalog.SHAPE_BOX:
			var box_shape := BoxShape3D.new()
			box_shape.size = size
			shape = box_shape
		elif mesh_instance.mesh != null:
			# Authored buildings are static, so a trimesh preserves stairs, slopes and
			# openings instead of sealing every procedural shape with a full box.
			shape = mesh_instance.mesh.create_trimesh_shape()
	mesh_instance.material_override = _block_meshes.material_for(material_id)
	collision.shape = shape
	return body


static func _blueprint_from_library(building_type: String, blueprint: BuildingBlueprint) -> Dictionary:
	return {
		"type": building_type,
		"footprint": BuildingBlueprintLibrary.footprint(building_type),
		"modules": BuildingBlueprintLibrary.ordered_modules(building_type),
		"blueprint_ref": BuildingBlueprintLibrary.blueprint_ref(building_type),
		"zones": blueprint.runtime_zone_definitions(),
		"routing_anchors": blueprint.routing_anchor_definitions(),
		"routes": blueprint.route_definitions(),
		"overlays": blueprint.overlay_definitions(),
		"construction_cost": blueprint.construction_cost.duplicate(true),
		"fixtures": blueprint.fixtures.map(func(fixture: FixtureDefinition) -> Dictionary: return fixture.to_dict()),
	}
