class_name MapEntityPresenter
extends Node3D

## Godot-facing projection of `MapEntityRuntime`. Missing content is a visible
## placeholder so a shared map remains launchable and resaveable.

var _views: Dictionary = {}
var _runtime: MapEntityRuntime = null


## Components the host module instantiates itself. An entity whose archetype
## declares any of them is left alone here.
##
## The list is a parameter and not a constant in this file for two reasons. It is
## the settlement that knows `settlement_natural` and `wander` mean "AmbientSpawner
## builds this one", and an engine presenter may not know those words
## (`multi_purpose_engine.md` §7). And it has to be ONE list: while the presenter
## skipped `settlement_natural` and the spawner claimed `wander`, a creature
## archetype that declared only `wander` got two bodies — an inert view here and a
## live one there — and nothing in the codebase said which was the real animal.
func present(
	runtime: MapEntityRuntime,
	territory: TerritoryBase,
	claimed_components: Array[StringName] = []
) -> void:
	clear()
	if runtime == null or territory == null:
		return
	_runtime = runtime
	if not _runtime.entity_changed.is_connected(_on_entity_changed):
		_runtime.entity_changed.connect(_on_entity_changed)
	for entity: MapEntityRuntime.RuntimeEntity in runtime.all():
		if not entity.active:
			continue
		# Test this before creating a scene instance: the former order leaked every
		# skipped view as an orphan.
		if _is_claimed(entity, claimed_components):
			continue
		var view := _make_view(entity)
		territory.add_landscape_object(view)
		_views[entity.id] = view


static func _is_claimed(
	entity: MapEntityRuntime.RuntimeEntity,
	claimed_components: Array[StringName]
) -> bool:
	for component: StringName in claimed_components:
		if entity.archetype.has_component(component):
			return true
	return false


func view_for(entity_id: StringName) -> Node3D:
	return _views.get(entity_id, null)


func clear() -> void:
	if _runtime != null and _runtime.entity_changed.is_connected(_on_entity_changed):
		_runtime.entity_changed.disconnect(_on_entity_changed)
	_runtime = null
	for view: Node3D in _views.values():
		if is_instance_valid(view):
			view.queue_free()
	_views.clear()


func _on_entity_changed(entity_id: StringName, change: StringName) -> void:
	var entity := _runtime.by_id(entity_id) if _runtime != null else null
	var view := view_for(entity_id)
	if entity == null or view == null:
		return
	if change == &"active":
		view.visible = entity.active
		return
	if change == &"props" and view.has_method("apply_entity_props"):
		view.call("apply_entity_props", entity.props)
	if change == &"state":
		view.set_meta("map_entity_state", entity.state)
		_apply_state_appearance(view, entity, EntityArchetypeCatalog.asset_of(entity.archetype.id))
	if change == &"appearance" and view.has_method("apply_decor_properties"):
		var asset := EntityArchetypeCatalog.asset_of(entity.archetype.id)
		var values := asset.default_appearance() if asset != null else {}
		values.merge(entity.appearance, true)
		view.call("apply_decor_properties", values)


func _make_view(entity: MapEntityRuntime.RuntimeEntity) -> Node3D:
	var asset := EntityArchetypeCatalog.asset_of(entity.archetype.id)
	var view: Node3D = null
	if asset != null and ResourceLoader.exists(asset.scene_path):
		var scene := load(asset.scene_path) as PackedScene
		view = scene.instantiate() as Node3D if scene != null else null
	if view == null:
		view = _placeholder(entity.id)
	# Authoring props (e.g. a firefly cluster's amount/radius/height) land on the
	# view before it enters the tree, so its `_ready` spawns with the right shape.
	if view.has_method("apply_entity_props"):
		view.call("apply_entity_props", entity.props)
	view.name = "MapEntity_%s" % entity.id
	view.position = entity.position
	view.rotation_degrees = entity.rotation_degrees
	view.scale = Vector3.ONE * entity.scale
	view.set_meta("map_entity_id", entity.id)
	view.set_meta("map_entity_state", entity.state)
	_apply_state_appearance(view, entity, asset)
	if view.has_method("apply_decor_properties") and not entity.appearance.is_empty():
		var appearance := asset.default_appearance() if asset != null else {}
		appearance.merge(entity.appearance, true)
		view.call("apply_decor_properties", appearance)
	return view


## Общий с `AmbientSpawner` код: карта строится двумя руками, а выглядеть должна
## одинаково (`EntityStateAppearance`).
func _apply_state_appearance(view: Node3D, entity: MapEntityRuntime.RuntimeEntity, asset: WorldAssetDef) -> void:
	EntityStateAppearance.apply(view, entity.archetype, entity.state, asset)


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
