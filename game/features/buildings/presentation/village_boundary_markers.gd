class_name VillageBoundaryMarkers
extends Node3D

## Visualizes the perimeter of the village territory by placing small
## ground-level markers at each perimeter cell. The markers are rebuilt
## whenever the territory changes.

const VillageTerritoryScript = preload("res://game/features/buildings/domain/village_territory.gd")

var _markers: Array[MeshInstance3D] = []
var _cell_size: float = 1.0


func configure(cell_size: float) -> void:
	_cell_size = cell_size


func refresh(territory: VillageTerritory) -> void:
	_clear_markers()
	if DisplayServer.get_name() == "headless":
		return
	var perimeter := territory.perimeter_cells()
	for cell in perimeter:
		var marker := _create_marker(cell)
		add_child(marker)
		_markers.append(marker)


func _clear_markers() -> void:
	for marker in _markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_markers.clear()


func _create_marker(cell: Vector2i) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12
	mesh.bottom_radius = 0.12
	mesh.height = 0.08
	marker.mesh = mesh
	marker.position = Vector3(
		(cell.x + 0.5) * _cell_size,
		0.04,
		(cell.y + 0.5) * _cell_size,
	)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c4a35a")
	material.roughness = 0.9
	marker.material_override = material
	return marker
