class_name VillageTerritoryOverlay
extends Node3D

## Renders the village territory as a semi-transparent filled area on the
## ground. Intended to be shown only in build mode so the player can see
## where buildings can be placed.

@onready var _multimesh_instance: MultiMeshInstance3D = $OverlayMultiMeshInstance
var _cell_size: float = 1.0


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

