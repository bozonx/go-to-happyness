class_name RampPreview
extends MeshInstance3D

## Cursor-following ramp footprint.  It is deliberately presentation-only: the
## grid remains the authority for whether the edit is legal.

const SURFACE_OFFSET := 0.08

var _grid: TerrainGrid = null
var _material := StandardMaterial3D.new()


func configure(grid: TerrainGrid) -> void:
	_grid = grid
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func show_ramp(start_cell: Vector2i, slope_class: int, direction: int) -> void:
	if _grid == null or not _grid.is_inside(start_cell):
		visible = false
		return
	var valid := _grid.ramp_placement_rejection(start_cell, slope_class, direction).is_empty()
	_material.albedo_color = Color(0.24, 0.95, 0.45, 0.52) if valid else Color(1.0, 0.22, 0.20, 0.52)
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	var offset := SlopeCatalog.direction_offset(direction)
	var run := SlopeCatalog.run_of_class(slope_class)
	for step in run + 1:
		var cell := start_cell + offset * step
		if _grid.is_inside(cell):
			_add_cell(immediate, cell)
	immediate.surface_end()
	mesh = immediate
	visible = true


func hide_preview() -> void:
	visible = false


func _add_cell(immediate: ImmediateMesh, cell: Vector2i) -> void:
	var centre := _grid.cell_center(cell)
	var half := _grid.cell_size * 0.45
	var y := _grid.height_at(centre) + SURFACE_OFFSET
	var a := Vector3(centre.x - half, y, centre.z - half)
	var b := Vector3(centre.x + half, y, centre.z - half)
	var c := Vector3(centre.x + half, y, centre.z + half)
	var d := Vector3(centre.x - half, y, centre.z + half)
	for vertex in [a, b, c, a, c, d]:
		immediate.surface_add_vertex(vertex)
