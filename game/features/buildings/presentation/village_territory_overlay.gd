class_name VillageTerritoryOverlay
extends Node3D

## Renders the village territory as a semi-transparent filled area on the
## ground. Intended to be shown only in build mode so the player can see
## where buildings can be placed.

var _multimesh_instance: MultiMeshInstance3D
var _cell_size: float = 1.0


func _ready() -> void:
	_multimesh_instance = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _create_quad_mesh()
	_multimesh_instance.multimesh = mm
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.75, 0.4, 0.25)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	_multimesh_instance.material_override = material
	add_child(_multimesh_instance)
	visible = false


func configure(cell_size: float) -> void:
	_cell_size = cell_size


func refresh(territory: VillageTerritory) -> void:
	if _multimesh_instance == null or DisplayServer.get_name() == "headless":
		return
	var cells := territory.cells()
	var mm := _multimesh_instance.multimesh
	mm.instance_count = cells.size()
	var i := 0
	for cell in cells:
		var c: Vector2i = cell
		var t := Transform3D.IDENTITY
		t.origin = Vector3(
			(c.x + 0.5) * _cell_size,
			0.06,
			(c.y + 0.5) * _cell_size,
		)
		t = t.scaled(Vector3(_cell_size, 1.0, _cell_size))
		mm.set_instance_transform(i, t)
		i += 1


func show_overlay() -> void:
	visible = true


func hide_overlay() -> void:
	visible = false


func _create_quad_mesh() -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1.0, 1.0)
	mesh.orientation = PlaneMesh.FACE_Y
	return mesh
