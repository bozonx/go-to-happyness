class_name FillObjectController
extends Node3D

## Applies authored furnishing appearance values to a fill scene.
##
## The controller is deliberately generic: it owns no per-asset `@export`s and
## does no `find_child` guessing. Each asset declares, in its `WorldAssetDef`,
## which node property every control drives (`"bind"`, see
## world_asset_def.gd), and this script just walks those bindings. Adding an
## asset therefore means adding a scene plus a catalog entry — never editing this
## file.


## Catalog id of the asset this scene implements. Set per scene; it is how the
## controller finds its own control/binding declarations.
@export var asset_id: StringName = &""

var _appearance: Dictionary = {}


func _ready() -> void:
	# A scene opened on its own (or dropped in without authored values) still
	# needs to look like its documented default state.
	var asset := _asset()
	if asset != null:
		apply_fill_properties(asset.default_appearance())


func apply_fill_properties(props: Dictionary) -> void:
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


func set_fill_property(property_name: String, value: Variant) -> void:
	var asset := _asset()
	if asset == null:
		return
	_appearance[property_name] = value
	_apply_bindings(asset.bindings().get(property_name, []), value)


func get_fill_properties() -> Dictionary:
	return _appearance.duplicate(true)


## Applies one named variant declared by the asset (`state_variants`) on top of
## whatever the object currently shows. Only the keys the variant mentions move:
## a tree that withers must keep the crown size its author chose, and gameplay
## code must not have to know which control holds the colour.
func apply_state_variant(variant_id: String) -> void:
	var asset := _asset()
	if asset == null:
		return
	var variant := asset.state_appearance(variant_id)
	for key: Variant in variant.keys():
		set_fill_property(str(key), variant[key])


func _asset() -> WorldAssetDef:
	return WorldAssetCatalog.get_asset(asset_id) if asset_id != &"" else null


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
			push_warning("FillObjectController(%s): binding target '%s' not found" % [asset_id, node_path])
			continue
		_apply_to_node(node, property_name, value)


func _apply_to_node(node: Node, property_name: String, value: Variant) -> void:
	match property_name:
		WorldAssetDef.PROP_ALBEDO:
			_set_albedo(node, WorldAssetDef.to_color(value))
		WorldAssetDef.PROP_SCALE:
			if node is Node3D:
				(node as Node3D).scale = Vector3.ONE * maxf(0.001, float(value))
		WorldAssetDef.PROP_SCALE_Y:
			if node is Node3D:
				(node as Node3D).scale.y = maxf(0.001, float(value))
		"light_color":
			node.set(property_name, WorldAssetDef.to_color(value))
		_:
			# A sub-property path (`position:y`, `rotation_degrees:z`) is the
			# difference between "this asset varies" and "this asset needs its own
			# script": plain `set` cannot reach one axis, `set_indexed` can.
			if property_name.contains(":"):
				node.set_indexed(NodePath(property_name), value)
			else:
				node.set(property_name, value)


## Tints a mesh without touching the scene's shared sub-resource — every instance
## gets its own material_override, otherwise recolouring one campfire recolours
## every campfire in the settlement.
##
## Binding a plain Node3D tints every mesh under it. A tree crown is four blobs
## that must always share a colour; listing all four in the catalog would mean
## the declaration silently rots the moment the scene gains a fifth.
func _set_albedo(node: Node, color: Color) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null:
		for child: Node in node.get_children():
			_set_albedo(child, color)
		return
	# Листва рисуется шейдером качания на ветру, а не StandardMaterial3D, но
	# «перекрасить» обязано значить одно и то же для обоих: иначе автор увидел бы,
	# что цвет кроны работает у одних растений и молча не работает у других.
	if mesh_instance.mesh != null and _source_material(mesh_instance) is ShaderMaterial:
		_set_shader_albedo(mesh_instance, color)
		return
	var override := mesh_instance.material_override as StandardMaterial3D
	if override == null or not override.has_meta("fill_instance_material"):
		var source := _source_material(mesh_instance)
		override = source.duplicate() as StandardMaterial3D if source is StandardMaterial3D else StandardMaterial3D.new()
		override.set_meta("fill_instance_material", true)
		mesh_instance.material_override = override
	override.albedo_color = color
	# Unshaded flame meshes read better when the tint drives emission too.
	if override.emission_enabled:
		override.emission = color


const SHADER_ALBEDO := &"albedo_color"


func _set_shader_albedo(mesh_instance: MeshInstance3D, color: Color) -> void:
	var override := mesh_instance.material_override as ShaderMaterial
	if override == null or not override.has_meta("fill_instance_material"):
		var source := _source_material(mesh_instance) as ShaderMaterial
		if source == null:
			return
		override = source.duplicate() as ShaderMaterial
		override.set_meta("fill_instance_material", true)
		mesh_instance.material_override = override
	override.set_shader_parameter(SHADER_ALBEDO, color)


## The material a mesh actually draws with before any per-instance override: the
## override when one is already in place, otherwise the one the scene authored on
## the mesh surface.
func _source_material(mesh_instance: MeshInstance3D) -> Material:
	if mesh_instance.material_override != null:
		return mesh_instance.material_override
	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		return mesh_instance.mesh.surface_get_material(0)
	return null
