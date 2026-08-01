class_name WaterBodyHighlight
extends MeshInstance3D

## Visualizer for the selected water body in the editor.
## Draws a subtle cell overlay and yellow markers at the intersections of the
## selected body's cells.  Markers read cleanly against both water and lava and
## do not turn a jagged bank into a second, misleading contour.

const SURFACE_OFFSET := 0.04
const OUTLINE_OFFSET := 0.05
const MARKER_RADIUS_RATIO := 0.11
const MARKER_SEGMENTS := 12

var _water: WaterGrid = null
var _terrain: TerrainGrid = null
var _body_id: int = WaterBody.NO_BODY
var _material := StandardMaterial3D.new()


func configure(water: WaterGrid, terrain: TerrainGrid) -> void:
	_water = water
	_terrain = terrain
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func highlight_body(body_id: int) -> void:
	_body_id = body_id
	refresh()


func hide_highlight() -> void:
	_body_id = WaterBody.NO_BODY
	visible = false


func refresh() -> void:
	if _water == null or _terrain == null or _body_id == WaterBody.NO_BODY or not _water.has_body(_body_id):
		visible = false
		return
	var cells := _water.cells_of_body(_body_id)
	if cells.is_empty():
		visible = false
		return

	var body := _water.body(_body_id)
	var is_lava := body != null and body.is_lava()
	var fill_color := Color(1.0, 0.45, 0.1, 0.25) if is_lava else Color(0.2, 0.85, 1.0, 0.25)
	var marker_color := Color(1.0, 0.88, 0.08, 1.0)

	_material.albedo_color = fill_color

	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)

	var cell_size := _water.cell_size
	var half := cell_size * 0.5

	for cell: Vector2i in cells:
		var level_y := float(_water.height_of(cell)) * TerrainGrid.HEIGHT_STEP + SURFACE_OFFSET
		var center := _terrain.cell_center(cell)
		var nw := Vector3(center.x - half, level_y, center.z - half)
		var ne := Vector3(center.x + half, level_y, center.z - half)
		var se := Vector3(center.x + half, level_y, center.z + half)
		var sw := Vector3(center.x - half, level_y, center.z + half)

		_add_quad(immediate, nw, ne, se, sw)

	immediate.surface_end()

	var marker_mat := StandardMaterial3D.new()
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	marker_mat.no_depth_test = true
	marker_mat.render_priority = 127
	marker_mat.albedo_color = marker_color

	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, marker_mat)
	var intersections: Dictionary = {}
	for cell: Vector2i in cells:
		var level_y := float(_water.height_of(cell)) * TerrainGrid.HEIGHT_STEP + OUTLINE_OFFSET
		var center := _terrain.cell_center(cell)
		for point in [
			Vector3(center.x - half, level_y, center.z - half), Vector3(center.x + half, level_y, center.z - half),
			Vector3(center.x + half, level_y, center.z + half), Vector3(center.x - half, level_y, center.z + half),
		]:
			intersections[point] = true
	for point: Vector3 in intersections:
		_add_disc(immediate, point, cell_size * MARKER_RADIUS_RATIO)

	immediate.surface_end()

	mesh = immediate
	visible = true


static func _add_quad(immediate: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex: Vector3 in [a, b, c, a, c, d]:
		immediate.surface_add_vertex(vertex)


static func _add_disc(immediate: ImmediateMesh, center: Vector3, radius: float) -> void:
	for index in MARKER_SEGMENTS:
		var first := TAU * float(index) / float(MARKER_SEGMENTS)
		var second := TAU * float(index + 1) / float(MARKER_SEGMENTS)
		immediate.surface_add_vertex(center)
		immediate.surface_add_vertex(center + Vector3(cos(first) * radius, 0.0, sin(first) * radius))
		immediate.surface_add_vertex(center + Vector3(cos(second) * radius, 0.0, sin(second) * radius))
