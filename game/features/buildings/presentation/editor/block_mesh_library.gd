class_name BlockMeshLibrary
extends RefCounted

## Builds and caches procedural meshes + materials for each construction block.
## Meshes are centred on their own origin at natural size; the editor places
## them at `Vector3(cell) + local_offset(block_id)` so every block sits on the
## floor of its anchor cell.

const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")

var _mesh_cache: Dictionary = {}
var _material_cache: Dictionary = {}


## World offset from the cell's minimum corner to the mesh origin so the block
## rests on the cell floor and is centred horizontally.
static func local_offset(block_id: StringName) -> Vector3:
	var def := BuildingBlockCatalogScript.get_block(block_id)
	if def.is_empty():
		return Vector3(0.5, 0.5, 0.5)
	var size: Vector3 = def["size"]
	return Vector3(0.5, size.y * 0.5, 0.5)


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
		BuildingBlockCatalogScript.SHAPE_STAIRS:
			mesh = _build_stairs(size)
		_:
			var box := BoxMesh.new()
			box.size = size
			mesh = box
	_mesh_cache[block_id] = mesh
	return mesh


func material_for(block_id: StringName) -> StandardMaterial3D:
	if _material_cache.has(block_id):
		return _material_cache[block_id]
	var def := BuildingBlockCatalogScript.get_block(block_id)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def.get("color", Color(0.7, 0.7, 0.7)) if not def.is_empty() else Color(0.7, 0.7, 0.7)
	mat.roughness = 0.85
	_material_cache[block_id] = mat
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
	# Right-triangle prism: full height at -Z, tapering to zero at +Z.
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Vertices: back-bottom-left/right, back-top-left/right, front-bottom-left/right
	var bbl := Vector3(-hx, -hy, -hz)
	var bbr := Vector3(hx, -hy, -hz)
	var btl := Vector3(-hx, hy, -hz)
	var btr := Vector3(hx, hy, -hz)
	var fbl := Vector3(-hx, -hy, hz)
	var fbr := Vector3(hx, -hy, hz)
	# Sloped top face
	_add_quad(st, btl, btr, fbr, fbl)
	# Back vertical face
	_add_quad(st, bbr, bbl, btl, btr)
	# Bottom face
	_add_quad(st, fbl, fbr, bbr, bbl)
	# Left triangle
	_add_tri(st, bbl, fbl, btl)
	# Right triangle
	_add_tri(st, fbr, bbr, btr)
	st.generate_normals()
	return st.commit()


func _build_stairs(size: Vector3, steps: int = 4) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step_h := size.y / float(steps)
	var step_d := size.z / float(steps)
	for i in steps:
		# Each step rises with i and recedes toward +Z.
		var min_y := -size.y * 0.5 + float(i) * step_h
		var max_y := min_y + step_h
		var min_z := -size.z * 0.5 + float(i) * step_d
		var max_z := size.z * 0.5
		_add_box(st, Vector3(-size.x * 0.5, min_y, min_z), Vector3(size.x * 0.5, max_y, max_z))
	st.generate_normals()
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
	_add_quad(st, h, g, f, e)  # top
	_add_quad(st, a, b, c, d)  # bottom
	_add_quad(st, e, f, b, a)  # -Z
	_add_quad(st, g, h, d, c)  # +Z
	_add_quad(st, h, e, a, d)  # -X
	_add_quad(st, f, g, c, b)  # +X


func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	st.add_vertex(p0); st.add_vertex(p1); st.add_vertex(p2)
	st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p3)


func _add_tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	st.add_vertex(p0); st.add_vertex(p1); st.add_vertex(p2)
