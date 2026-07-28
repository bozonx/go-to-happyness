class_name MapEntityPresenter
extends Node3D

## Godot-facing projection of `MapEntityRuntime`. Missing content is a visible
## placeholder so a shared map remains launchable and resaveable.

var _views: Dictionary = {}


func present(runtime: MapEntityRuntime, territory: TerritoryBase) -> void:
	clear()
	if runtime == null or territory == null:
		return
	for entity: MapEntityRuntime.RuntimeEntity in runtime.all():
		var view := _make_view(entity)
		territory.add_landscape_object(view)
		_views[entity.id] = view


func view_for(entity_id: StringName) -> Node3D:
	return _views.get(entity_id, null)


func clear() -> void:
	for view: Node3D in _views.values():
		if is_instance_valid(view):
			view.queue_free()
	_views.clear()


func _make_view(entity: MapEntityRuntime.RuntimeEntity) -> Node3D:
	var asset := EntityArchetypeCatalog.asset_of(entity.archetype.id)
	var view: Node3D = null
	if asset != null and ResourceLoader.exists(asset.scene_path):
		var scene := load(asset.scene_path) as PackedScene
		view = scene.instantiate() as Node3D if scene != null else null
	if view == null:
		view = _placeholder(entity.id)
	view.name = "MapEntity_%s" % entity.id
	view.position = entity.position
	view.rotation_degrees.y = entity.yaw_degrees
	view.scale = Vector3.ONE * entity.scale
	view.set_meta("map_entity_id", entity.id)
	view.set_meta("map_entity_state", entity.state)
	return view


func _placeholder(entity_id: StringName) -> Node3D:
	var marker := MeshInstance3D.new()
	marker.name = "MissingEntity_%s" % entity_id
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 0.7, 0.7)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.12, 0.82)
	material.emission_enabled = true
	material.emission = material.albedo_color
	mesh.material = material
	marker.mesh = mesh
	marker.position.y = 0.35
	return marker
