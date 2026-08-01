class_name WaterFloodPreview
extends MeshInstance3D

## Visualizer for pending flood area preview in the editor.
## Displays blue dots at the intersection points of the flood level plane
## with surrounding terrain edges, along with a subtle blue overlay.

const SURFACE_OFFSET := 0.04
const OUTLINE_OFFSET := 0.05
const DOT_RADIUS := 0.12

var _water: WaterGrid = null
var _terrain: TerrainGrid = null
var _fill_material := StandardMaterial3D.new()
var _line_material := StandardMaterial3D.new()
var _dot_material := StandardMaterial3D.new()


func configure(water: WaterGrid, terrain: TerrainGrid) -> void:
	_water = water
	_terrain = terrain

	_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fill_material.albedo_color = Color(0.1, 0.6, 1.0, 0.18)

	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line_material.albedo_color = Color(0.2, 0.7, 1.0, 0.75)

	_dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dot_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dot_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dot_material.albedo_color = Color(0.1, 0.85, 1.0, 0.95)

	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func hide_preview() -> void:
	visible = false


func show_preview(cells: Array[Vector2i], level: int) -> void:
	if _water == null or _terrain == null or cells.is_empty():
		visible = false
		return

	var cell_set: Dictionary = {}
	for cell: Vector2i in cells:
		cell_set[cell] = true

	var cell_size := _water.cell_size
	var half := cell_size * 0.5
	var level_y := float(level) * TerrainGrid.HEIGHT_STEP

	var immediate := ImmediateMesh.new()

	# 1. Fill quad surface
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _fill_material)
	var fill_y := level_y + SURFACE_OFFSET
	for cell: Vector2i in cells:
		var center := _terrain.cell_center(cell)
		var nw := Vector3(center.x - half, fill_y, center.z - half)
		var ne := Vector3(center.x + half, fill_y, center.z - half)
		var se := Vector3(center.x + half, fill_y, center.z + half)
		var sw := Vector3(center.x - half, fill_y, center.z + half)
		_add_quad(immediate, nw, ne, se, sw)
	immediate.surface_end()

	# 2. Outer boundary lines
	var line_y := level_y + OUTLINE_OFFSET
	var boundary_points: Dictionary = {}

	immediate.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)
	for cell: Vector2i in cells:
		var center := _terrain.cell_center(cell)
		var nw := Vector3(center.x - half, line_y, center.z - half)
		var ne := Vector3(center.x + half, line_y, center.z - half)
		var se := Vector3(center.x + half, line_y, center.z + half)
		var sw := Vector3(center.x - half, line_y, center.z + half)

		# North edge (-z)
		if not cell_set.has(cell + Vector2i(0, -1)):
			immediate.surface_add_vertex(nw)
			immediate.surface_add_vertex(ne)
			boundary_points[nw] = true
			boundary_points[ne] = true
		# East edge (+x)
		if not cell_set.has(cell + Vector2i(1, 0)):
			immediate.surface_add_vertex(ne)
			immediate.surface_add_vertex(se)
			boundary_points[ne] = true
			boundary_points[se] = true
		# South edge (+z)
		if not cell_set.has(cell + Vector2i(0, 1)):
			immediate.surface_add_vertex(se)
			immediate.surface_add_vertex(sw)
			boundary_points[se] = true
			boundary_points[sw] = true
		# West edge (-x)
		if not cell_set.has(cell + Vector2i(-1, 0)):
			immediate.surface_add_vertex(sw)
			immediate.surface_add_vertex(nw)
			boundary_points[sw] = true
			boundary_points[nw] = true

	immediate.surface_end()

	# 3. Blue circular dots at boundary intersection points
	var dot_y := level_y + OUTLINE_OFFSET + 0.01
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _dot_material)
	for pt_val in boundary_points:
		var pt := pt_val as Vector3
		pt.y = dot_y
		_add_circle_disc(immediate, pt, DOT_RADIUS)
	immediate.surface_end()

	mesh = immediate
	visible = true


static func _add_quad(immediate: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex: Vector3 in [a, b, c, a, c, d]:
		immediate.surface_add_vertex(vertex)


static func _add_circle_disc(immediate: ImmediateMesh, center: Vector3, radius: float) -> void:
	var segments := 8
	var prev := center + Vector3(radius, 0, 0)
	for i in range(1, segments + 1):
		var angle := float(i) * (TAU / float(segments))
		var curr := center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		immediate.surface_add_vertex(center)
		immediate.surface_add_vertex(prev)
		immediate.surface_add_vertex(curr)
		prev = curr
