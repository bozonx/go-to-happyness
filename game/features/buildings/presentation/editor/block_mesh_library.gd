class_name BlockMeshLibrary
extends RefCounted

## Builds and caches procedural meshes + materials for each construction block.
## Meshes are centred on their own origin at natural size; the editor places
## them at `Vector3(cell) + local_offset(block_id, vertical_offset)` so every block
## sits at the designated elevation of its anchor cell.

const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")

const MATERIAL_COLORS := {
	&"branches": Color(0.43, 0.28, 0.15),
	&"thatch": Color(0.72, 0.60, 0.28),
	&"tarp": Color(0.35, 0.40, 0.42),
	&"earth": Color(0.43, 0.31, 0.20),
	&"earth_stone": Color(0.45, 0.38, 0.30),
	&"clay": Color(0.58, 0.32, 0.22),
	&"adobe": Color(0.60, 0.45, 0.28),
	&"logs": Color(0.48, 0.34, 0.19),
	&"wood": Color(0.55, 0.38, 0.20),
	&"stone": Color(0.47, 0.49, 0.50),
	&"stone_mortar": Color(0.50, 0.52, 0.48),
	&"brick": Color(0.58, 0.22, 0.16),
	&"brick_mortar": Color(0.60, 0.28, 0.22),
}

var _mesh_cache: Dictionary = {}
var _material_cache: Dictionary = {}


## World offset from the cell's minimum corner to the mesh origin so the block
## rests on the cell floor (plus optional vertical offset parameter).
static func local_offset(block_id: StringName, vertical_offset: float = 0.0) -> Vector3:
	var def := BuildingBlockCatalogScript.get_block(block_id)
	if def.is_empty():
		return Vector3(0.5, 0.5 + vertical_offset, 0.5)
	var size: Vector3 = def["size"]
	return Vector3(0.5, size.y * 0.5 + vertical_offset, 0.5)


func mesh_for(block_id: StringName) -> Mesh:
	if _mesh_cache.has(block_id):
		return _mesh_cache[block_id]
	var def := BuildingBlockCatalogScript.get_block(block_id)
	if def.is_empty():
		return null
	var size: Vector3 = def["size"]
	var mesh: Mesh
	match def["mesh_shape"]:
		BuildingBlockCatalogScript.SHAPE_WEDGE:
			mesh = _build_wedge(size)
		BuildingBlockCatalogScript.SHAPE_WEDGE_LOW:
			mesh = _build_wedge(size)
		BuildingBlockCatalogScript.SHAPE_SLOPE_CORNER_IN:
			mesh = _build_slope_corner_in(size)
		BuildingBlockCatalogScript.SHAPE_SLOPE_CORNER_OUT:
			mesh = _build_slope_corner_out(size)
		BuildingBlockCatalogScript.SHAPE_GABLE:
			mesh = _build_gable(size)
		BuildingBlockCatalogScript.SHAPE_CYLINDER:
			mesh = _build_cylinder(size)
		BuildingBlockCatalogScript.SHAPE_HALF_CYLINDER:
			mesh = _build_half_cylinder(size)
		BuildingBlockCatalogScript.SHAPE_STAIRS:
			mesh = _build_stairs(size, 8)
		BuildingBlockCatalogScript.SHAPE_STAIRS_HALF:
			mesh = _build_stairs(size, 4)
		BuildingBlockCatalogScript.SHAPE_STAIRS_QUARTER:
			mesh = _build_stairs(size, 2)
		BuildingBlockCatalogScript.SHAPE_STAIRS_CORNER_45:
			mesh = _build_stairs_corner_45(size, 8)
		BuildingBlockCatalogScript.SHAPE_WINDOW_WALL:
			mesh = _build_window_wall(size)
		BuildingBlockCatalogScript.SHAPE_DOOR_WALL:
			mesh = _build_door_wall(size)
		BuildingBlockCatalogScript.SHAPE_ARCH:
			mesh = _build_arch(size)
		_:
			var box := BoxMesh.new()
			box.size = size
			mesh = box
	_mesh_cache[block_id] = mesh
	return mesh


func material_for(material_id: StringName) -> StandardMaterial3D:
	if _material_cache.has(material_id):
		return _material_cache[material_id]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = MATERIAL_COLORS.get(material_id, Color(0.7, 0.7, 0.7))
	mat.roughness = 0.85
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	_material_cache[material_id] = mat
	return mat


## Semi-transparent variant used for the placement ghost cursor.
func ghost_material(valid: bool) -> StandardMaterial3D:
	var key := &"__ghost_valid" if valid else &"__ghost_invalid"
	if _material_cache.has(key):
		return _material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.4, 0.85, 1.0, 0.45) if valid else Color(1.0, 0.35, 0.3, 0.45)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_cache[key] = mat
	return mat


func _build_wedge(size: Vector3) -> ArrayMesh:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bbl := Vector3(-hx, -hy, -hz)
	var bbr := Vector3(hx, -hy, -hz)
	var btl := Vector3(-hx, hy, -hz)
	var btr := Vector3(hx, hy, -hz)
	var fbl := Vector3(-hx, -hy, hz)
	var fbr := Vector3(hx, -hy, hz)
	_add_quad(st, btl, fbl, fbr, btr)
	_add_quad(st, bbr, bbl, btl, btr)
	_add_quad(st, bbl, bbr, fbr, fbl)
	_add_tri(st, bbl, fbl, btl)
	_add_tri(st, fbr, bbr, btr)
	return st.commit()


func _build_slope_corner_in(size: Vector3) -> ArrayMesh:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bbl := Vector3(-hx, -hy, -hz)
	var bbr := Vector3(hx, -hy, -hz)
	var btl := Vector3(-hx, hy, -hz)
	var btr := Vector3(hx, hy, -hz)
	var fbl := Vector3(-hx, -hy, hz)
	var fbr := Vector3(hx, -hy, hz)
	var ftl := Vector3(-hx, hy, hz)
	_add_quad(st, bbr, bbl, btl, btr) # Back (-Z)
	_add_quad(st, bbl, fbl, ftl, btl) # Left (-X)
	_add_quad(st, bbl, bbr, fbr, fbl) # Bottom (-Y)
	_add_tri(st, btl, ftl, btr)      # Top corner slope 1
	_add_tri(st, ftl, fbr, btr)      # Top corner slope 2
	_add_tri(st, ftl, fbl, fbr)      # Front sloped face
	_add_tri(st, btr, fbr, bbr)      # Right sloped face
	return st.commit()


func _build_slope_corner_out(size: Vector3) -> ArrayMesh:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bbl := Vector3(-hx, -hy, -hz)
	var bbr := Vector3(hx, -hy, -hz)
	var btl := Vector3(-hx, hy, -hz)
	var fbl := Vector3(-hx, -hy, hz)
	var fbr := Vector3(hx, -hy, hz)
	_add_quad(st, bbl, bbr, fbr, fbl) # Bottom (-Y)
	_add_tri(st, bbl, fbl, btl)       # Left triangle (-X)
	_add_tri(st, bbr, bbl, btl)       # Back triangle (-Z)
	_add_tri(st, btl, fbl, fbr)       # Sloped face 1
	_add_tri(st, btl, fbr, bbr)       # Sloped face 2
	return st.commit()


func _build_gable(size: Vector3) -> ArrayMesh:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bbl := Vector3(-hx, -hy, -hz)
	var bbr := Vector3(hx, -hy, -hz)
	var btc := Vector3(0.0, hy, -hz)
	var fbl := Vector3(-hx, -hy, hz)
	var fbr := Vector3(hx, -hy, hz)
	var ftc := Vector3(0.0, hy, hz)
	_add_tri(st, bbr, bbl, btc)       # Back triangle (-Z)
	_add_tri(st, fbl, fbr, ftc)       # Front triangle (+Z)
	_add_quad(st, bbl, bbr, fbr, fbl) # Bottom (-Y)
	_add_quad(st, bbl, fbl, ftc, btc) # Left slope
	_add_quad(st, btc, ftc, fbr, bbr) # Right slope
	return st.commit()


func _build_cylinder(size: Vector3, segments: int = 16) -> ArrayMesh:
	var rx := size.x * 0.5
	var rz := size.z * 0.5
	var hy := size.y * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a1 := float(i) / float(segments) * TAU
		var a2 := float(i + 1) / float(segments) * TAU
		var p1_b := Vector3(cos(a1) * rx, -hy, sin(a1) * rz)
		var p2_b := Vector3(cos(a2) * rx, -hy, sin(a2) * rz)
		var p1_t := Vector3(cos(a1) * rx, hy, sin(a1) * rz)
		var p2_t := Vector3(cos(a2) * rx, hy, sin(a2) * rz)
		_add_quad(st, p1_b, p2_b, p2_t, p1_t) # Side
		_add_tri(st, Vector3(0, hy, 0), p2_t, p1_t) # Top cap
		_add_tri(st, Vector3(0, -hy, 0), p1_b, p2_b) # Bottom cap
	return st.commit()


func _build_half_cylinder(size: Vector3, segments: int = 12) -> ArrayMesh:
	var rx := size.x * 0.5
	var rz := size.z
	var hy := size.y * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bbl := Vector3(-rx, -hy, 0.0)
	var bbr := Vector3(rx, -hy, 0.0)
	var btl := Vector3(-rx, hy, 0.0)
	var btr := Vector3(rx, hy, 0.0)
	_add_quad(st, bbr, bbl, btl, btr) # Flat back (-Z)
	for i in segments:
		var a1 := -PI * 0.5 + float(i) / float(segments) * PI
		var a2 := -PI * 0.5 + float(i + 1) / float(segments) * PI
		var p1_b := Vector3(sin(a1) * rx, -hy, cos(a1) * rz)
		var p2_b := Vector3(sin(a2) * rx, -hy, cos(a2) * rz)
		var p1_t := Vector3(sin(a1) * rx, hy, cos(a1) * rz)
		var p2_t := Vector3(sin(a2) * rx, hy, cos(a2) * rz)
		_add_quad(st, p1_b, p2_b, p2_t, p1_t) # Curved front
		_add_tri(st, Vector3(0, hy, 0), p2_t, p1_t) # Top cap
		_add_tri(st, Vector3(0, -hy, 0), p1_b, p2_b) # Bottom cap
	return st.commit()


func _build_stairs(size: Vector3, steps: int = 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step_h := size.y / float(steps)
	var step_d := size.z / float(steps)
	for i in steps:
		var min_y := -size.y * 0.5 + float(i) * step_h
		var max_y := min_y + step_h
		var min_z := -size.z * 0.5 + float(i) * step_d
		var max_z := size.z * 0.5
		_add_box(st, Vector3(-size.x * 0.5, min_y, min_z), Vector3(size.x * 0.5, max_y, max_z))
	return st.commit()


func _build_stairs_corner_45(size: Vector3, steps: int = 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step_h := size.y / float(steps)
	var step_d := size.x / float(steps)
	for i in steps:
		var min_y := -size.y * 0.5 + float(i) * step_h
		var max_y := min_y + step_h
		var inset := float(i) * step_d * 0.5
		var min_x := -size.x * 0.5 + inset
		var max_x := size.x * 0.5 - inset
		var min_z := -size.z * 0.5 + inset
		var max_z := size.z * 0.5 - inset
		if max_x > min_x and max_z > min_z:
			_add_box(st, Vector3(min_x, min_y, min_z), Vector3(max_x, max_y, max_z))
	return st.commit()


func _build_window_wall(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	# Bottom wall section (under window)
	_add_box(st, Vector3(-hx, -hy, -hz), Vector3(hx, -hy * 0.3, hz))
	# Top wall section (above window)
	_add_box(st, Vector3(-hx, hy * 0.5, -hz), Vector3(hx, hy, hz))
	# Left wall post
	_add_box(st, Vector3(-hx, -hy * 0.3, -hz), Vector3(-hx * 0.4, hy * 0.5, hz))
	# Right wall post
	_add_box(st, Vector3(hx * 0.4, -hy * 0.3, -hz), Vector3(hx, hy * 0.5, hz))
	return st.commit()


func _build_door_wall(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	# Top lintel section above door
	_add_box(st, Vector3(-hx, hy * 0.5, -hz), Vector3(hx, hy, hz))
	# Left door post
	_add_box(st, Vector3(-hx, -hy, -hz), Vector3(-hx * 0.4, hy * 0.5, hz))
	# Right door post
	_add_box(st, Vector3(hx * 0.4, -hy, -hz), Vector3(hx, hy * 0.5, hz))
	return st.commit()


func _build_arch(size: Vector3, segments: int = 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	# Top solid arch block
	_add_box(st, Vector3(-hx, 0.0, -hz), Vector3(hx, hy, hz))
	# Left pillar
	_add_box(st, Vector3(-hx, -hy, -hz), Vector3(-hx * 0.5, 0.0, hz))
	# Right pillar
	_add_box(st, Vector3(hx * 0.5, -hy, -hz), Vector3(hx, -hy, hz))
	return st.commit()


func _add_box(st: SurfaceTool, min_p: Vector3, max_p: Vector3) -> void:
	var a := Vector3(min_p.x, min_p.y, min_p.z)
	var b := Vector3(max_p.x, min_p.y, min_p.z)
	var c := Vector3(max_p.x, min_p.y, max_p.z)
	var d := Vector3(min_p.x, min_p.y, max_p.z)
	var e := Vector3(min_p.x, max_p.y, min_p.z)
	var f := Vector3(max_p.x, max_p.y, min_p.z)
	var g := Vector3(max_p.x, max_p.y, max_p.z)
	var h := Vector3(min_p.x, max_p.y, max_p.z)
	_add_quad(st, h, g, f, e)  # top (+Y)
	_add_quad(st, a, b, c, d)  # bottom (-Y)
	_add_quad(st, e, f, b, a)  # -Z
	_add_quad(st, g, h, d, c)  # +Z
	_add_quad(st, h, e, a, d)  # -X
	_add_quad(st, f, g, c, b)  # +X


func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	var n_vec := (p1 - p0).cross(p2 - p0)
	var normal := n_vec.normalized() if not n_vec.is_zero_approx() else Vector3.UP
	st.set_normal(normal); st.add_vertex(p0)
	st.set_normal(normal); st.add_vertex(p1)
	st.set_normal(normal); st.add_vertex(p2)
	st.set_normal(normal); st.add_vertex(p0)
	st.set_normal(normal); st.add_vertex(p2)
	st.set_normal(normal); st.add_vertex(p3)


func _add_tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	var n_vec := (p1 - p0).cross(p2 - p0)
	var normal := n_vec.normalized() if not n_vec.is_zero_approx() else Vector3.UP
	st.set_normal(normal); st.add_vertex(p0)
	st.set_normal(normal); st.add_vertex(p1)
	st.set_normal(normal); st.add_vertex(p2)
