class_name BlockMeshLibrary
extends RefCounted

## Builds and caches procedural meshes + materials for each construction block.
## Meshes are centred on their own origin at natural size; the editor places
## them at `Vector3(cell) + local_offset(block_id, vertical_offset)` so every block
## sits at the designated elevation of its anchor cell.

const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")

var _mesh_cache: Dictionary = {}
var _material_cache: Dictionary = {}


## World offset from the cell's minimum corner to the mesh origin.
##
## The cell is a fixed 1×1×1 slot; rotation turns the *detail* inside it (7 Days
## to Die style). At rot=0 the mesh rests on the cell floor at its in-cell anchor,
## giving a default offset of its centre from the cell centre; the full rotation
## then spins that offset about the cell centre, so a sub-cell part can be turned
## into the top / sides / corners of its cell instead of always hugging the floor.
static func local_offset(
	block_id: StringName,
	variant: StringName = &"",
	rot: int = 0,
	anchor: int = 0,
	vertical_offset: float = 0.0,
	rot_x: int = 0,
	rot_z: int = 0
) -> Vector3:
	var size := BuildingBlockCatalogScript.size_of(block_id, variant)
	var base := BuildingBlockCatalogScript.anchor_base_offset(block_id, variant, anchor)
	# Default centre-to-centre offset: horizontal anchor + resting on the floor.
	var d0 := Vector3(base.x, size.y * 0.5 - 0.5, base.y)
	var r := Basis.from_euler(Vector3(
		deg_to_rad(90.0 * float(rot_x)),
		deg_to_rad(90.0 * float(rot)),
		deg_to_rad(90.0 * float(rot_z))))
	var c := r * d0
	return Vector3(0.5 + c.x, 0.5 + c.y + vertical_offset + BuildingBlockCatalogScript.vertical_offset_of(block_id, variant), 0.5 + c.z)


func mesh_for(block_id: StringName, variant: StringName = &"") -> Mesh:
	var cache_key := "%s|%s" % [block_id, variant]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	var def := BuildingBlockCatalogScript.get_block(block_id)
	if def.is_empty():
		return null
	var size := BuildingBlockCatalogScript.size_of(block_id, variant)
	var mesh: Mesh
	match BuildingBlockCatalogScript.mesh_shape_of(block_id, variant):
		BuildingBlockCatalogScript.SHAPE_WEDGE:
			mesh = _build_wedge(size)
		BuildingBlockCatalogScript.SHAPE_WEDGE_LOW:
			mesh = _build_wedge(size)
		BuildingBlockCatalogScript.SHAPE_SLOPE_CORNER_IN:
			mesh = _build_slope_corner_in(size)
		BuildingBlockCatalogScript.SHAPE_SLOPE_CORNER_OUT:
			mesh = _build_slope_corner_out(size)
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
		BuildingBlockCatalogScript.SHAPE_STAIRS_CORNER_HALF:
			mesh = _build_stairs_corner_45(size, 4)
		BuildingBlockCatalogScript.SHAPE_STAIRS_CORNER_QUARTER:
			mesh = _build_stairs_corner_45(size, 2)
		BuildingBlockCatalogScript.SHAPE_WINDOW_WALL:
			mesh = _build_window_wall(size)
		BuildingBlockCatalogScript.SHAPE_DOOR_WALL:
			mesh = _build_door_wall(size)
		BuildingBlockCatalogScript.SHAPE_ARCH:
			mesh = _build_arch(size)
		BuildingBlockCatalogScript.SHAPE_HALF_ARCH:
			mesh = _build_half_arch(size)
		BuildingBlockCatalogScript.SHAPE_RAILING:
			mesh = _build_railing(size)
		BuildingBlockCatalogScript.SHAPE_FENCE:
			mesh = _build_fence(size)
		_:
			var box := BoxMesh.new()
			box.size = size
			mesh = box
	_mesh_cache[cache_key] = mesh
	return mesh


func material_for(material_id: StringName) -> StandardMaterial3D:
	if _material_cache.has(material_id):
		return _material_cache[material_id]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BuildingMaterialCatalogScript.color(material_id)
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
		_add_quad(st, p1_b, p1_t, p2_t, p2_b) # Side (wound so the normal faces outward)
		_add_tri(st, Vector3(0, hy, 0), p2_t, p1_t) # Top cap
		_add_tri(st, Vector3(0, -hy, 0), p1_b, p2_b) # Bottom cap
	return st.commit()


## Vertical half-cylinder: flat back on the cell-local `z = 0` plane, the round
## side bulging toward +Z. The sweep reuses the full cylinder's parametrisation
## (`x = cos`, `z = sin`) so the side quads and the caps keep the same outward
## winding; mirroring it into `x = sin` turned every face inside out and the
## round side rendered see-through.
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
		var a1 := float(i) / float(segments) * PI
		var a2 := float(i + 1) / float(segments) * PI
		var p1_b := Vector3(cos(a1) * rx, -hy, sin(a1) * rz)
		var p2_b := Vector3(cos(a2) * rx, -hy, sin(a2) * rz)
		var p1_t := Vector3(cos(a1) * rx, hy, sin(a1) * rz)
		var p2_t := Vector3(cos(a2) * rx, hy, sin(a2) * rz)
		_add_quad(st, p1_b, p1_t, p2_t, p2_b) # Curved side
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


## Corner porch stair: nested L-steps growing outward from the +X/+Z inner
## corner. Each step is a solid box (floor → its own top) inset from the two
## outer faces (-X, -Z); the +X and +Z faces stay flush so the piece mates with
## a straight stair block placed against either of those two sides. The lowest,
## widest step is outermost — the run "starts at the corner" and climbs inward.
func _build_stairs_corner_45(size: Vector3, steps: int = 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step_h := size.y / float(steps)
	var step_dx := size.x / float(steps)
	var step_dz := size.z / float(steps)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	for i in steps:
		# Step i is solid from the floor up to its own tread height, so lower
		# steps read as full risers rather than floating slabs.
		var top_y := -hy + float(i + 1) * step_h
		var min_x := -hx + float(i) * step_dx
		var min_z := -hz + float(i) * step_dz
		if hx > min_x and hz > min_z:
			_add_box(st, Vector3(min_x, -hy, min_z), Vector3(hx, top_y, hz))
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


## A horizontal half-slab with a semicircle cut out from its lower face. The
## curve springs from the slab's bottom edge, leaving material above the opening.
func _build_arch(size: Vector3, segments: int = 16) -> ArrayMesh:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var radius := minf(hx, hy)
	var profile := PackedVector2Array()
	# Cut-out first: the semicircle is traced left → right along the bottom edge,
	# which keeps the whole outline counter-clockwise.
	for i in range(segments + 1):
		var a := PI - float(i) / float(segments) * PI
		profile.append(Vector2(cos(a) * radius, -hy + sin(a) * radius))
	profile.append(Vector2(hx, hy))
	profile.append(Vector2(-hx, hy))
	return _build_extrusion(profile, size.z)


## Cube with a full quarter-circle sector removed from its lower-left corner.
## The sector's radius spans the whole block, so two mirrored half-arches meet
## in a single opening. Quarter-turn rotation moves the cut-out to other corners.
func _build_half_arch(size: Vector3, segments: int = 16) -> ArrayMesh:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var radius := minf(size.x, size.y)
	var profile := PackedVector2Array()
	profile.append(Vector2(hx, hy))
	profile.append(Vector2(-hx, hy))
	# Sector boundary, centred on the lower-left corner, traced from the top-left
	# corner back down to the bottom-right one.
	for i in range(segments + 1):
		var a := PI * 0.5 - float(i) / float(segments) * PI * 0.5
		profile.append(Vector2(-hx + cos(a) * radius, -hy + sin(a) * radius))
	return _build_extrusion(profile, size.z)


## Extrudes a closed, counter-clockwise XY profile along Z into a centred solid:
## two triangulated caps plus a quad per profile edge. Used by the arch blocks so
## their curved cut-outs come out smooth instead of stepped.
func _build_extrusion(source_profile: PackedVector2Array, depth: float) -> ArrayMesh:
	# A curve that ends exactly on a corner the caller also listed would leave a
	# repeated vertex, and `triangulate_polygon` bails out on those.
	var profile := PackedVector2Array()
	for point in source_profile:
		if not profile.is_empty() and profile[profile.size() - 1].is_equal_approx(point):
			continue
		profile.append(point)
	if profile.size() > 1 and profile[0].is_equal_approx(profile[profile.size() - 1]):
		profile.remove_at(profile.size() - 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := depth * 0.5
	var indices := Geometry2D.triangulate_polygon(profile)
	for i in range(0, indices.size(), 3):
		var a := profile[indices[i]]
		var b := profile[indices[i + 1]]
		var c := profile[indices[i + 2]]
		# `triangulate_polygon` does not promise a winding, so orient each
		# triangle by its own signed area before extruding it into both caps.
		if (b - a).cross(c - a) < 0.0:
			var swap := b
			b = c
			c = swap
		_add_tri(st, Vector3(a.x, a.y, hz), Vector3(b.x, b.y, hz), Vector3(c.x, c.y, hz))
		_add_tri(st, Vector3(a.x, a.y, -hz), Vector3(c.x, c.y, -hz), Vector3(b.x, b.y, -hz))
	for i in profile.size():
		var p := profile[i]
		var q := profile[(i + 1) % profile.size()]
		_add_quad(st,
			Vector3(p.x, p.y, -hz), Vector3(q.x, q.y, -hz),
			Vector3(q.x, q.y, hz), Vector3(p.x, p.y, hz))
	return st.commit()


func _build_railing(size: Vector3, balusters: int = 5) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var t := minf(size.z * 0.5, 0.06)       # half-thickness of the members
	var rail_h := minf(size.y * 0.12, 0.1)  # rail bar height
	_add_box(st, Vector3(-hx, hy - rail_h, -t), Vector3(hx, hy, t))
	_add_box(st, Vector3(-hx, -hy, -t), Vector3(hx, -hy + rail_h * 0.7, t))
	var bw := 0.045
	var bt := t * 0.7
	for i in balusters + 1:
		var cx := -hx + (2.0 * hx) * float(i) / float(balusters)
		var x0 := clampf(cx - bw, -hx, hx)
		var x1 := clampf(cx + bw, -hx, hx)
		if x1 > x0 + 0.0001:
			_add_box(st, Vector3(x0, -hy + rail_h * 0.5, -bt), Vector3(x1, hy - rail_h * 0.5, bt))
	return st.commit()


## A cattle fence: two horizontal rails held by end posts.
func _build_fence(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var t := minf(size.z * 0.5, 0.06)
	var rail_h := minf(size.y * 0.12, 0.1)
	var post_w := minf(0.07, size.x * 0.12)
	_add_box(st, Vector3(-hx, -hy, -t), Vector3(-hx + post_w, hy, t))
	_add_box(st, Vector3(hx - post_w, -hy, -t), Vector3(hx, hy, t))
	_add_box(st, Vector3(-hx, -hy * 0.35 - rail_h, -t), Vector3(hx, -hy * 0.35 + rail_h, t))
	_add_box(st, Vector3(-hx, hy * 0.35 - rail_h, -t), Vector3(hx, hy * 0.35 + rail_h, t))
	return st.commit()


## A balustrade: a bottom plinth, a heavy top rail (coping) and a row of closely
## spaced turned balusters between them. Fills `size.y` so the half-block-tall
## variant reads as a solid parapet-height railing.
func _build_balustrade(size: Vector3, balusters: int = 7) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var t := minf(size.z * 0.5, 0.09)        # half-thickness of the members
	var plinth_h := 0.16                     # bottom kerb height (same as full balustrade)
	var coping_h := 0.20                     # top rail height (same as full balustrade)
	# Bottom plinth and top coping span the full width.
	_add_box(st, Vector3(-hx, -hy, -t), Vector3(hx, -hy + plinth_h, t))
	_add_box(st, Vector3(-hx, hy - coping_h, -t), Vector3(hx, hy, t))
	# Vertical balusters between plinth and coping.
	var bw := 0.05                           # half-width of a baluster
	var bt := t * 0.8
	var y0 := -hy + plinth_h
	var y1 := hy - coping_h
	for i in balusters:
		var cx := -hx + (2.0 * hx) * (float(i) + 0.5) / float(balusters)
		var x0 := clampf(cx - bw, -hx, hx)
		var x1 := clampf(cx + bw, -hx, hx)
		if x1 > x0 + 0.0001 and y1 > y0:
			_add_box(st, Vector3(x0, y0, -bt), Vector3(x1, y1, bt))
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
	# Vertices are authored counter-clockwise as seen from outside, so the
	# cross product yields the outward normal. Godot's default CULL_BACK treats
	# clockwise winding as front-facing, so the triangles are emitted in
	# reversed order to face outward while the outward normal drives lighting.
	var n_vec := (p1 - p0).cross(p2 - p0)
	var normal := n_vec.normalized() if not n_vec.is_zero_approx() else Vector3.UP
	st.set_normal(normal); st.add_vertex(p0)
	st.set_normal(normal); st.add_vertex(p2)
	st.set_normal(normal); st.add_vertex(p1)
	st.set_normal(normal); st.add_vertex(p0)
	st.set_normal(normal); st.add_vertex(p3)
	st.set_normal(normal); st.add_vertex(p2)


func _add_tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	# See _add_quad: reversed winding for CULL_BACK, outward normal for lighting.
	var n_vec := (p1 - p0).cross(p2 - p0)
	var normal := n_vec.normalized() if not n_vec.is_zero_approx() else Vector3.UP
	st.set_normal(normal); st.add_vertex(p0)
	st.set_normal(normal); st.add_vertex(p2)
	st.set_normal(normal); st.add_vertex(p1)


func _build_square_cross(size: Vector3, arms_count: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := size.x
	var h := size.y
	var hw := w * 0.5
	var hh := h * 0.5
	# Central pillar
	_add_box(st, Vector3(-hw, -hh, -hw), Vector3(hw, hh, hw))
	# Arm 1 (+Z)
	_add_box(st, Vector3(-hw, -hh, hw), Vector3(hw, hh, hw + w * 0.5))
	# Arm 2 (+X)
	_add_box(st, Vector3(hw, -hh, -hw), Vector3(hw + w * 0.5, hh, hw))
	# Arm 3 (-X) if 3 columns
	if arms_count >= 3:
		_add_box(st, Vector3(-hw - w * 0.5, -hh, -hw), Vector3(-hw, hh, hw))
	return st.commit()


func _build_round_cross(size: Vector3, arms_count: int, segments: int = 12) -> ArrayMesh:
	var rx := size.x * 0.5
	var rz := size.z * 0.5
	var hy := size.y * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers: Array[Vector3] = [
		Vector3(0, 0, 0),
		Vector3(0, 0, rz * 1.5),
		Vector3(rx * 1.5, 0, 0),
	]
	if arms_count >= 3:
		centers.append(Vector3(-rx * 1.5, 0, 0))
	for center in centers:
		for i in segments:
			var a1 := float(i) / float(segments) * TAU
			var a2 := float(i + 1) / float(segments) * TAU
			var p1_b := center + Vector3(cos(a1) * rx, -hy, sin(a1) * rz)
			var p2_b := center + Vector3(cos(a2) * rx, -hy, sin(a2) * rz)
			var p1_t := center + Vector3(cos(a1) * rx, hy, sin(a1) * rz)
			var p2_t := center + Vector3(cos(a2) * rx, hy, sin(a2) * rz)
			_add_quad(st, p1_b, p1_t, p2_t, p2_b)
			_add_tri(st, center + Vector3(0, hy, 0), p2_t, p1_t)
			_add_tri(st, center + Vector3(0, -hy, 0), p1_b, p2_b)
	return st.commit()


func _build_half_cross(size: Vector3, arms_count: int, segments: int = 10) -> ArrayMesh:
	var rx := size.x * 0.5
	var rz := size.z
	var hy := size.y * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bbl1 := Vector3(-rx, -hy, 0.0)
	var bbr1 := Vector3(rx, -hy, 0.0)
	var btl1 := Vector3(-rx, hy, 0.0)
	var btr1 := Vector3(rx, hy, 0.0)
	_add_quad(st, bbr1, bbl1, btl1, btr1)
	for i in segments:
		var a1 := -PI * 0.5 + float(i) / float(segments) * PI
		var a2 := -PI * 0.5 + float(i + 1) / float(segments) * PI
		var p1_b := Vector3(sin(a1) * rx, -hy, cos(a1) * rz)
		var p2_b := Vector3(sin(a2) * rx, -hy, cos(a2) * rz)
		var p1_t := Vector3(sin(a1) * rx, hy, cos(a1) * rz)
		var p2_t := Vector3(sin(a2) * rx, hy, cos(a2) * rz)
		_add_quad(st, p1_b, p1_t, p2_t, p2_b)
		_add_tri(st, Vector3(0, hy, 0), p2_t, p1_t)
		_add_tri(st, Vector3(0, -hy, 0), p1_b, p2_b)
	var bbl2 := Vector3(0.0, -hy, -rx)
	var bbr2 := Vector3(0.0, -hy, rx)
	var btl2 := Vector3(0.0, hy, -rx)
	var btr2 := Vector3(0.0, hy, rx)
	_add_quad(st, bbl2, bbr2, btr2, btl2)
	for i in segments:
		var a1 := -PI * 0.5 + float(i) / float(segments) * PI
		var a2 := -PI * 0.5 + float(i + 1) / float(segments) * PI
		var p1_b := Vector3(cos(a1) * rz, -hy, sin(a1) * rx)
		var p2_b := Vector3(cos(a2) * rz, -hy, sin(a2) * rx)
		var p1_t := Vector3(cos(a1) * rz, hy, sin(a1) * rx)
		var p2_t := Vector3(cos(a2) * rz, hy, sin(a2) * rx)
		_add_quad(st, p1_b, p1_t, p2_t, p2_b)
		_add_tri(st, Vector3(0, hy, 0), p1_t, p2_t)
		_add_tri(st, Vector3(0, -hy, 0), p2_b, p1_b)
	return st.commit()
