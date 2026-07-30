class_name RampPreview
extends MeshInstance3D

## Cursor-following preview for the map editor's "connect heights" gesture.
## It draws the real inclined surface when the anchors describe a catalog ramp,
## and a red footprint otherwise. The grid and `RampConnectionPlan` remain the
## authority; presentation never invents a second placement rule.

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


## Compatibility preview used by the terrain laboratory's one-click ramp tool.
func show_ramp(start_cell: Vector2i, slope_class: int, direction: int) -> void:
	if _grid == null or not _grid.is_inside(start_cell):
		hide_preview()
		return
	var top := start_cell + SlopeCatalog.direction_offset(direction) * SlopeCatalog.run_of_class(slope_class)
	show_connection(RampConnectionPlan.between(_grid, start_cell, top, slope_class))


func show_start(cell: Vector2i) -> void:
	if _grid == null or not _grid.is_inside(cell):
		hide_preview()
		return
	_material.albedo_color = Color(0.25, 0.72, 1.0, 0.58)
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	_add_flat_cell(immediate, cell)
	immediate.surface_end()
	mesh = immediate
	visible = true


func show_connection(plan: RampConnectionPlan) -> void:
	if _grid == null or plan == null:
		hide_preview()
		return
	if plan.is_valid():
		_material.albedo_color = (
			Color(1.0, 0.68, 0.16, 0.58) if plan.reshaped_cells > 0
			else Color(0.24, 0.95, 0.45, 0.55)
		)
	else:
		_material.albedo_color = Color(1.0, 0.22, 0.20, 0.55)
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	if plan.is_valid():
		for step in plan.cells.size():
			_add_slope_cell(immediate, plan, step)
		_add_arrow(immediate, plan)
	else:
		_add_invalid_footprint(immediate, plan)
	immediate.surface_end()
	mesh = immediate
	visible = true


func hide_preview() -> void:
	visible = false


func _add_slope_cell(immediate: ImmediateMesh, plan: RampConnectionPlan, step: int) -> void:
	var cell: Vector2i = plan.cells[step]
	var centre := _grid.cell_center(cell)
	var half := _grid.cell_size * 0.47
	var corners := [
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	]
	var vertices: Array[Vector3] = []
	for corner: Vector2 in corners:
		var local_progress := _local_progress(corner, plan.direction)
		var progress := (float(step) + local_progress) / float(plan.run)
		var y := (float(plan.base_height) + float(plan.rise) * progress) * TerrainGrid.HEIGHT_STEP + SURFACE_OFFSET
		vertices.append(Vector3(centre.x + corner.x, y, centre.z + corner.y))
	_add_quad(immediate, vertices[0], vertices[1], vertices[2], vertices[3])


func _add_arrow(immediate: ImmediateMesh, plan: RampConnectionPlan) -> void:
	var offset := SlopeCatalog.direction_offset(plan.direction)
	var forward := Vector3(float(offset.x), 0.0, float(offset.y))
	var side := Vector3(-forward.z, 0.0, forward.x)
	var distance := float(plan.run) * _grid.cell_size
	var start := _grid.cell_center(plan.start_cell)
	var progress := 0.62
	var centre := Vector3(
		start.x + forward.x * distance * progress,
		(float(plan.base_height) + float(plan.rise) * progress) * TerrainGrid.HEIGHT_STEP + SURFACE_OFFSET * 2.0,
		start.z + forward.z * distance * progress,
	)
	var length := minf(_grid.cell_size * 0.8, distance * 0.28)
	var width := minf(_grid.cell_size * 0.32, distance * 0.12)
	immediate.surface_add_vertex(centre + forward * length)
	immediate.surface_add_vertex(centre - forward * length * 0.55 + side * width)
	immediate.surface_add_vertex(centre - forward * length * 0.55 - side * width)


func _add_invalid_footprint(immediate: ImmediateMesh, plan: RampConnectionPlan) -> void:
	if _grid.is_inside(plan.first_cell):
		_add_flat_cell(immediate, plan.first_cell)
	if _grid.is_inside(plan.second_cell) and plan.second_cell != plan.first_cell:
		_add_flat_cell(immediate, plan.second_cell)
	var delta := plan.second_cell - plan.first_cell
	if delta.x != 0 and delta.y != 0:
		return
	var count := absi(delta.x) + absi(delta.y)
	if count <= 1:
		return
	var step := Vector2i(signi(delta.x), signi(delta.y))
	for index in range(1, count):
		var cell := plan.first_cell + step * index
		if _grid.is_inside(cell):
			_add_flat_cell(immediate, cell)


func _add_flat_cell(immediate: ImmediateMesh, cell: Vector2i) -> void:
	var centre := _grid.cell_center(cell)
	var half := _grid.cell_size * 0.45
	var y := _grid.height_at(centre) + SURFACE_OFFSET
	_add_quad(
		immediate,
		Vector3(centre.x - half, y, centre.z - half),
		Vector3(centre.x + half, y, centre.z - half),
		Vector3(centre.x + half, y, centre.z + half),
		Vector3(centre.x - half, y, centre.z + half),
	)


static func _local_progress(corner: Vector2, direction: int) -> float:
	match direction:
		SlopeCatalog.DIR_E: return 0.0 if corner.x < 0.0 else 1.0
		SlopeCatalog.DIR_W: return 1.0 if corner.x < 0.0 else 0.0
		SlopeCatalog.DIR_S: return 0.0 if corner.y < 0.0 else 1.0
		SlopeCatalog.DIR_N: return 1.0 if corner.y < 0.0 else 0.0
	return 0.0


static func _add_quad(immediate: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex: Vector3 in [a, b, c, a, c, d]:
		immediate.surface_add_vertex(vertex)
