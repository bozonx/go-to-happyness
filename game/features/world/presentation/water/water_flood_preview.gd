class_name WaterFloodPreview
extends MeshInstance3D

## Visualizer for pending flood area preview in the editor.
## Displays blue dots at the intersection points of the flood level plane
## with surrounding terrain edges, along with a subtle blue overlay.

const OUTLINE_OFFSET := 0.05
const DOT_RADIUS := 0.12

var _water: WaterGrid = null
var _terrain: TerrainGrid = null
var _dot_material := StandardMaterial3D.new()


func configure(water: WaterGrid, terrain: TerrainGrid) -> void:
	_water = water
	_terrain = terrain

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

	# Only dots at boundary intersection points — the fill and outline are
	# intentionally omitted so the preview reads as level markers, not as
	# phantom water the author might mistake for the real surface.
	var boundary_points: Dictionary = {}
	for cell: Vector2i in cells:
		var center := _terrain.cell_center(cell)
		var nw := Vector3(center.x - half, level_y, center.z - half)
		var ne := Vector3(center.x + half, level_y, center.z - half)
		var se := Vector3(center.x + half, level_y, center.z + half)
		var sw := Vector3(center.x - half, level_y, center.z + half)
		if not cell_set.has(cell + Vector2i(0, -1)):
			boundary_points[nw] = true
			boundary_points[ne] = true
		if not cell_set.has(cell + Vector2i(1, 0)):
			boundary_points[ne] = true
			boundary_points[se] = true
		if not cell_set.has(cell + Vector2i(0, 1)):
			boundary_points[se] = true
			boundary_points[sw] = true
		if not cell_set.has(cell + Vector2i(-1, 0)):
			boundary_points[sw] = true
			boundary_points[nw] = true

	var dot_y := level_y + OUTLINE_OFFSET + 0.01
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _dot_material)
	for pt_val in boundary_points:
		var pt := pt_val as Vector3
		pt.y = dot_y
		_add_circle_disc(immediate, pt, DOT_RADIUS)
	immediate.surface_end()

	mesh = immediate
	visible = true


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
