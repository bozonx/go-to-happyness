class_name MapPlacementPresenter
extends Node3D

## Runtime projection of authored `placements[]`.  The map owns placement and
## terrain state; this presenter owns only scene nodes and the blueprint-authored
## zone/access metadata consumed by building systems.

var _views: Dictionary = {}


func present(document: MapDocument, territory: TerritoryBase) -> void:
	clear()
	if document == null or territory == null:
		return
	for record: MapPlacementRecord in document.placements.placements:
		var view := _make_view(record, document.meta.cell_size)
		territory.add_landscape_object(view)
		_views[record.id] = view


func view_for(placement_id: StringName) -> Node3D:
	return _views.get(placement_id, null)


func all_views() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for view: Node3D in _views.values():
		if is_instance_valid(view):
			result.append(view)
	return result


func clear() -> void:
	for view: Node3D in _views.values():
		if is_instance_valid(view):
			view.queue_free()
	_views.clear()


func _make_view(record: MapPlacementRecord, cell_size: float) -> Node3D:
	var view := Node3D.new()
	view.name = "MapBuilding_%s" % record.id
	var footprint := BuildingPlacementService.footprint_of(record)
	var span := footprint.span()
	view.position = Vector3(
		(float(footprint.origin.x) + float(span.x) * 0.5) * cell_size,
		float(record.level_value) * TerrainGrid.HEIGHT_STEP,
		(float(footprint.origin.y) + float(span.y) * 0.5) * cell_size)
	view.rotation_degrees.y = -90.0 * float(record.orientation)
	view.set_meta("map_placement_id", record.id)
	view.set_meta("map_placement_state", record.state)
	view.set_meta("owner", record.owner)
	view.set_meta("tags", record.tags.duplicate())

	var blueprint := BuildingPlacementService.blueprint_of(record)
	if blueprint == null:
		view.add_child(_missing_marker(record.id))
		return view
	for module: Dictionary in BuildingBlueprintLibrary.modules_of(blueprint):
		var node := BuildingBlueprints.create_module(module)
		if node != null:
			view.add_child(node)
	var contribution := BuildingPlacementService.zones_of(record, cell_size)
	view.set_meta("active_zones", contribution.get("zones", []))
	view.set_meta("routing_anchors", contribution.get("routing_anchors", []))
	view.set_meta("zone_routes", contribution.get("routes", []))
	view.set_meta("zone_overlays", contribution.get("overlays", []))
	return view


static func _missing_marker(placement_id: StringName) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = "MissingBuilding_%s" % placement_id
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 1.6, 0.8)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.15, 0.85)
	material.emission_enabled = true
	material.emission = material.albedo_color
	mesh.material = material
	marker.mesh = mesh
	marker.position.y = 0.8
	return marker
