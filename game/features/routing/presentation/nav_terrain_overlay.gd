class_name NavTerrainOverlay
extends MeshInstance3D

## Debug view of what navigation thinks the ground is (§10).
##
## An author editing terrain cannot see passability: two terraces look exactly
## like a slope from an isometric camera, and the difference — a wall nobody can
## climb — only shows up when a citizen refuses to walk. This draws the answer
## instead: every cell shaded by how steep navigation reads its surface, and a
## line along every edge the chosen traveller cannot cross.
##
## It reads `NavGrid` and never writes to it. Cost is a full rebuild of the board,
## so it is driven by the editor's explicit refresh, not by `_process`.

## Surface tint per slope class, flat → sheer. Deliberately a ramp from green to
## red rather than eight arbitrary hues: the question an author asks is "how bad
## is this", and an ordered scale answers it without a legend.
const CLASS_COLORS: Array[Color] = [
	Color(0.30, 0.75, 0.35),
	Color(0.45, 0.78, 0.32),
	Color(0.62, 0.80, 0.30),
	Color(0.82, 0.78, 0.28),
	Color(0.90, 0.62, 0.24),
	Color(0.90, 0.42, 0.22),
	Color(0.80, 0.25, 0.25),
	Color(0.55, 0.16, 0.20),
]
const BLOCKED_COLOR := Color(0.35, 0.10, 0.14)
const IMPASSABLE_EDGE_COLOR := Color(0.95, 0.12, 0.16, 0.75)
## How tall the wall on an impassable boundary is drawn. Not the real drop: it
## marks where the traveller stops, and a uniform height keeps a one-step ledge as
## legible as a cliff.
const WALL_HEIGHT := 0.5
## Lifted off the ground so it does not z-fight with the terrain mesh it covers.
const SURFACE_LIFT := 0.05
const EDGE_LIFT := 0.08
## Compass indices of east and south in `NavTerrainField.DIRECTION_OFFSETS`.
const DRAWN_EDGE_DIRECTIONS: Array[int] = [2, 4]

@export var traveler_profile: StringName = NavGrid.PEDESTRIAN_PROFILE
@export var surface_alpha := 0.45

var grid: NavGrid = null

var _surface_material: StandardMaterial3D = null
var _edge_material: StandardMaterial3D = null


func configure(next_grid: NavGrid, profile: StringName = NavGrid.PEDESTRIAN_PROFILE) -> void:
	grid = next_grid
	traveler_profile = profile
	rebuild()


## Rebuilds the whole overlay. Terrain editing invalidates arbitrary parts of the
## board — a cascade reaches far past the brush — so there is no partial path
## worth the bookkeeping for a debug view.
func rebuild() -> void:
	mesh = null
	if grid == null or not grid.has_terrain_field() or not visible:
		return
	var field := grid.terrain_field()
	var profile := TravelerProfile.get_profile(traveler_profile)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := SurfaceTool.new()
	edges.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_surface := false
	var has_edges := false
	for z in range(-field.board_half_cells, field.board_cells - field.board_half_cells):
		for x in range(-field.board_half_cells, field.board_cells - field.board_half_cells):
			var cell := Vector2i(x, z)
			has_surface = _add_cell(surface, field, cell, profile) or has_surface
			has_edges = _add_edges(edges, field, cell, profile) or has_edges
	var built := ArrayMesh.new()
	if has_surface:
		surface.set_material(_surface_mat())
		surface.commit(built)
	if has_edges:
		edges.set_material(_edge_mat())
		edges.commit(built)
	mesh = built if built.get_surface_count() > 0 else null


func _add_cell(surface: SurfaceTool, field: NavTerrainField, cell: Vector2i, profile: TravelerProfile) -> bool:
	var walkable := grid.is_walkable(cell, traveler_profile, profile)
	if not field.has_ground(cell):
		return false
	var color := BLOCKED_COLOR if not walkable else CLASS_COLORS[clampi(field.slope_class_at(cell), 0, 7)]
	color.a = surface_alpha
	# The two triangles the mesher splits the quad into, so the overlay sits on the
	# ground rather than cutting through it on a non-planar cell.
	var nw := _corner(field, cell, 0.0, 0.0)
	var ne := _corner(field, cell, 1.0, 0.0)
	var se := _corner(field, cell, 1.0, 1.0)
	var sw := _corner(field, cell, 0.0, 1.0)
	for vertex: Vector3 in [nw, ne, se, nw, se, sw]:
		surface.set_color(color)
		surface.add_vertex(vertex)
	return true


## A standing wall on every boundary the traveller cannot cross.
##
## Drawn as a vertical quad on the boundary itself, not a line between the two
## cell centres: a line one pixel wide is invisible at the distance an author
## actually works from, and the thing being shown is a wall. It stands on the
## higher of the two surfaces, so it reads as the top of the drop.
func _add_edges(edges: SurfaceTool, field: NavTerrainField, cell: Vector2i, profile: TravelerProfile) -> bool:
	if not field.has_ground(cell):
		return false
	var drew := false
	# East and south only: each shared boundary belongs to two cells and would
	# otherwise be drawn twice, once from each side.
	for direction: int in DRAWN_EDGE_DIRECTIONS:
		var offset: Vector2i = NavTerrainField.DIRECTION_OFFSETS[direction]
		var neighbour := cell + offset
		if not field.is_inside(neighbour):
			continue
		if grid.is_edge_passable(cell, neighbour, traveler_profile, profile) and grid.is_edge_passable(neighbour, cell, traveler_profile, profile):
			continue
		var left: Vector3
		var right: Vector3
		if offset.x != 0:
			left = _boundary_point(field, cell, neighbour, 1.0, 0.0, 0.0, 0.0)
			right = _boundary_point(field, cell, neighbour, 1.0, 1.0, 0.0, 1.0)
		else:
			left = _boundary_point(field, cell, neighbour, 0.0, 1.0, 0.0, 0.0)
			right = _boundary_point(field, cell, neighbour, 1.0, 1.0, 1.0, 0.0)
		var rise := Vector3.UP * WALL_HEIGHT
		edges.set_color(IMPASSABLE_EDGE_COLOR)
		for vertex: Vector3 in [left, right, right + rise, left, right + rise, left + rise]:
			edges.set_color(IMPASSABLE_EDGE_COLOR)
			edges.add_vertex(vertex)
		drew = true
	return drew


## A point on the boundary shared by two cells, at the height of whichever side is
## higher. `(u, v)` locate it inside `cell`; `(other_u, other_v)` the same world
## point inside `neighbour`.
func _boundary_point(field: NavTerrainField, cell: Vector2i, neighbour: Vector2i, u: float, v: float, other_u: float, other_v: float) -> Vector3:
	var own := _corner(field, cell, u, v)
	var theirs := _corner(field, neighbour, other_u, other_v)
	own.y = maxf(own.y, theirs.y) + EDGE_LIFT
	return own


func _corner(field: NavTerrainField, cell: Vector2i, u: float, v: float) -> Vector3:
	var size := field.cell_size
	# Sampled just inside the cell so the height query cannot land on the
	# neighbour and read a surface a step away.
	var sample := Vector3(
		(float(cell.x) + clampf(u, 0.001, 0.999)) * size,
		0.0,
		(float(cell.y) + clampf(v, 0.001, 0.999)) * size
	)
	return Vector3(
		(float(cell.x) + u) * size,
		field.height_at(sample) + SURFACE_LIFT,
		(float(cell.y) + v) * size
	)


func _surface_mat() -> StandardMaterial3D:
	if _surface_material == null:
		_surface_material = StandardMaterial3D.new()
		_surface_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_surface_material.vertex_color_use_as_albedo = true
		_surface_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_surface_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _surface_material


func _edge_mat() -> StandardMaterial3D:
	if _edge_material == null:
		_edge_material = StandardMaterial3D.new()
		_edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_edge_material.vertex_color_use_as_albedo = true
		_edge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_edge_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _edge_material
