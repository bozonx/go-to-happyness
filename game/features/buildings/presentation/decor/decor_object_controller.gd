class_name DecorObjectController
extends Node3D

## Applies authored furnishing appearance values to a decor scene.
##
## The controller is deliberately generic: it owns no per-asset `@export`s and
## does no `find_child` guessing. Each asset declares, in its `FurnishingAssetDef`,
## which node property every control drives (`"bind"`, see
## furnishing_asset_def.gd), and this script just walks those bindings. Adding an
## asset therefore means adding a scene plus a catalog entry — never editing this
## file.

const FurnishingAssetCatalogScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_catalog.gd")
const FurnishingAssetDefScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_def.gd")

## Catalog id of the asset this scene implements. Set per scene; it is how the
## controller finds its own control/binding declarations.
@export var asset_id: StringName = &""

var _appearance: Dictionary = {}


func _ready() -> void:
	# A scene opened on its own (or dropped in without authored values) still
	# needs to look like its documented default state.
	var asset := _asset()
	if asset != null:
		apply_decor_properties(asset.default_appearance())


func apply_decor_properties(props: Dictionary) -> void:
	var asset := _asset()
	if asset == null:
		return
	var bindings := asset.bindings()
	# Start from the defaults so a partial dictionary (an older save, a control
	# added later) resets untouched knobs instead of leaving stale scene state.
	_appearance = asset.default_appearance()
	for key in props.keys():
		_appearance[str(key)] = props[key]
	for property_name in _appearance.keys():
		_apply_bindings(bindings.get(property_name, []), _appearance[property_name])


func set_decor_property(property_name: String, value: Variant) -> void:
	var asset := _asset()
	if asset == null:
		return
	_appearance[property_name] = value
	_apply_bindings(asset.bindings().get(property_name, []), value)


func get_decor_properties() -> Dictionary:
	return _appearance.duplicate(true)


func _asset() -> FurnishingAssetDefScript:
	return FurnishingAssetCatalogScript.get_asset(asset_id) if asset_id != &"" else null


func _apply_bindings(binds: Variant, value: Variant) -> void:
	if not (binds is Array):
		return
	for bind in binds:
		if not (bind is Dictionary):
			continue
		var node_path := String(bind.get("node", ""))
		var property_name := String(bind.get("prop", ""))
		if node_path.is_empty() or property_name.is_empty():
			continue
		var node := get_node_or_null(NodePath(node_path))
		if node == null:
			push_warning("DecorObjectController(%s): binding target '%s' not found" % [asset_id, node_path])
			continue
		_apply_to_node(node, property_name, value)


func _apply_to_node(node: Node, property_name: String, value: Variant) -> void:
	match property_name:
		FurnishingAssetDefScript.PROP_ALBEDO:
			_set_albedo(node, _to_color(value))
		FurnishingAssetDefScript.PROP_SCALE_Y:
			if node is Node3D:
				(node as Node3D).scale.y = maxf(0.001, float(value))
		"light_color":
			node.set(property_name, _to_color(value))
		_:
			node.set(property_name, value)


## Tints a mesh without touching the scene's shared sub-resource — every instance
## gets its own material_override, otherwise recolouring one campfire recolours
## every campfire in the settlement.
func _set_albedo(node: Node, color: Color) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null:
		return
	var override := mesh_instance.material_override as StandardMaterial3D
	if override == null or not override.has_meta("decor_instance_material"):
		var source: Material = mesh_instance.material_override
		if source == null and mesh_instance.mesh != null:
			source = mesh_instance.mesh.surface_get_material(0)
		override = source.duplicate() as StandardMaterial3D if source is StandardMaterial3D else StandardMaterial3D.new()
		override.set_meta("decor_instance_material", true)
		mesh_instance.material_override = override
	override.albedo_color = color
	# Unshaded flame meshes read better when the tint drives emission too.
	if override.emission_enabled:
		override.emission = color


static func _to_color(value: Variant) -> Color:
	if value is Color:
		return value
	var text := String(value)
	return Color.from_string(text, Color.WHITE) if not text.is_empty() else Color.WHITE
