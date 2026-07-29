class_name TerrainGrid
extends RefCounted

## The settlement's discrete elevation grid (design_docs/engine/grid_terrain_system.md §2).
##
## Stores exactly four things per column: integer height in Δh steps, surface
## material, slope descriptor (catalog class + direction + index inside a
## multi-cell ramp) and flags. Everything fractional — corner heights, standing
## height, slope classes of faces — is DERIVED here and lives only in the
## generated mesh. That invariant is what keeps mesh, navigation and saves from
## drifting apart.
##
## Cell coordinates are centred on the world origin like `NavGrid`: for a board of
## N cells they run from -N/2 to N/2-1, and cell (x, z) covers world
## [x*cell_size, (x+1)*cell_size] × [z*cell_size, (z+1)*cell_size].
##
## Storage is flat packed arrays rather than per-chunk arrays. The chunk grid is
## still first-class (see `chunk_of` / `take_dirty_chunks`) because meshing and
## the save format (§12) are chunked; splitting the backing storage per chunk is a
## save-format optimisation and can be done without touching this API.
##
## The read API comes in two flavours: `*_of` returns catalog `StringName`s for
## tools and tests, `*_class_at` / `*_index_at` returns the stored integer for the
## mesher and the cascade, which run over every cell of a chunk and must not pay
## for a catalog lookup per query.
##
## Surface appearance — material index and the detail byte holding variant, wear
## and snow depth (`terrain_materials.md` §5) — is stored here but is NOT mesh
## input: it reaches the GPU through the index and detail maps (§7.3). So painting
## it dirties the *surface* set, never a chunk, and that is what makes a material
## brush cost one texel instead of a remesh (§7.5).

## Vertical step in metres. All stored heights are integer multiples of it.
const HEIGHT_STEP := 0.5
## Inclusive height limits in steps (§2.2). Out-of-range operations are rejected,
## never silently clamped.
const MIN_HEIGHT := -64
const MAX_HEIGHT := 191
const CHUNK_CELLS := 16

## Corner order used everywhere in this system, clockwise from north-west.
const CORNER_NW := 0
const CORNER_NE := 1
const CORNER_SE := 2
const CORNER_SW := 3

## Per orthogonal direction: the two corners this cell shares with that
## neighbour, as `[mine, theirs, mine, theirs]` — the same point in the world
## seen from both sides.
const SHARED_CORNERS: Dictionary = {
	SlopeCatalog.DIR_N: [CORNER_NW, CORNER_SW, CORNER_NE, CORNER_SE],
	SlopeCatalog.DIR_E: [CORNER_NE, CORNER_NW, CORNER_SE, CORNER_SW],
	SlopeCatalog.DIR_S: [CORNER_SE, CORNER_NE, CORNER_SW, CORNER_NW],
	SlopeCatalog.DIR_W: [CORNER_SW, CORNER_SE, CORNER_NW, CORNER_NE],
}
## A diagonal neighbour shares exactly one corner with us (§3.4), as
## `[mine, theirs]`.
const SHARED_DIAGONAL_CORNERS: Dictionary = {
	SlopeCatalog.DIR_NE: [CORNER_NE, CORNER_SW],
	SlopeCatalog.DIR_SE: [CORNER_SE, CORNER_NW],
	SlopeCatalog.DIR_SW: [CORNER_SW, CORNER_NE],
	SlopeCatalog.DIR_NW: [CORNER_NW, CORNER_SE],
}
## How far above its own column a corner may be pulled by a neighbouring slope,
## in steps. Two is the diagonal of a 45° hillside; see `corner_heights_into`.
const MAX_CORNER_LIFT_STEPS := 2

const DIAGONAL_DIRECTIONS: Array[int] = [
	SlopeCatalog.DIR_NE, SlopeCatalog.DIR_SE, SlopeCatalog.DIR_SW, SlopeCatalog.DIR_NW,
]

var cell_size := 1.0
var board_cells := 0
var board_half_cells := 0

var _heights := PackedInt32Array()
var _materials := PackedByteArray()
## variant | wear | snow_depth, packed by `TerrainDetailCodec` (§5).
var _details := PackedByteArray()
var _slope_classes := PackedByteArray()
var _slope_dirs := PackedByteArray()
var _slope_indices := PackedByteArray()
var _flags := PackedByteArray()

var _revision := 0
## Scratch space for `corner_heights_into`, which runs once per cell of the board
## on every publish and once per neighbour on every mesh.
var _neighbour_corner_scratch := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _dirty_chunks: Dictionary = {}
## Columns whose surface texels are out of date. Separate from the dirty chunks
## on purpose: a material or detail edit changes no geometry at all (§7.5), and
## folding the two sets together would put the remesh cost back on every brush
## stroke that does not need it.
var _dirty_surface_cells: Dictionary = {}


func configure(next_cell_size: float, next_board_cells: int, fill_height: int = 0, fill_material: StringName = TerrainMaterialCatalog.DEFAULT_MATERIAL) -> void:
	cell_size = next_cell_size
	board_cells = maxi(next_board_cells, 0)
	board_half_cells = board_cells / 2
	var count := board_cells * board_cells
	_heights = PackedInt32Array()
	_heights.resize(count)
	_materials = PackedByteArray()
	_materials.resize(count)
	_details = PackedByteArray()
	_details.resize(count)
	_slope_classes = PackedByteArray()
	_slope_classes.resize(count)
	_slope_dirs = PackedByteArray()
	_slope_dirs.resize(count)
	_slope_indices = PackedByteArray()
	_slope_indices.resize(count)
	_flags = PackedByteArray()
	_flags.resize(count)
	_heights.fill(clampi(fill_height, MIN_HEIGHT, MAX_HEIGHT))
	_materials.fill(maxi(TerrainMaterialCatalog.index_of(fill_material), 0))
	_details.fill(TerrainDetailCodec.DEFAULT_DETAIL)
	_slope_classes.fill(0)
	_slope_dirs.fill(0)
	_slope_indices.fill(0)
	_flags.fill(0)
	_revision += 1
	mark_all_chunks_dirty()
	mark_all_surface_dirty()


func revision() -> int:
	return _revision


func is_inside(cell: Vector2i) -> bool:
	return (
		cell.x >= -board_half_cells and cell.x < board_cells - board_half_cells
		and cell.y >= -board_half_cells and cell.y < board_cells - board_half_cells
	)


func min_cell() -> Vector2i:
	return Vector2i(-board_half_cells, -board_half_cells)


func max_cell() -> Vector2i:
	return Vector2i(board_cells - board_half_cells - 1, board_cells - board_half_cells - 1)


# --- Reads ------------------------------------------------------------------

## Height in steps. Outside the board reads as the world zero level; callers that
## care about the difference ask `is_inside` first (the mesher does, to build the
## border skirt instead of a wall).
func height_of(cell: Vector2i) -> int:
	if not is_inside(cell):
		return 0
	return _heights[_index_of(cell)]


func material_index_at(cell: Vector2i) -> int:
	if not is_inside(cell):
		return TerrainMaterialCatalog.DEFAULT_INDEX
	return int(_materials[_index_of(cell)])


func material_of(cell: Vector2i) -> StringName:
	return TerrainMaterialCatalog.id_of_index(material_index_at(cell))


## The packed variant | wear | snow byte (§5). Presentation writes it into the
## detail map wholesale; the accessors below are for everyone else.
func detail_at(cell: Vector2i) -> int:
	if not is_inside(cell):
		return TerrainDetailCodec.DEFAULT_DETAIL
	return int(_details[_index_of(cell)])


func variant_at(cell: Vector2i) -> int:
	return TerrainDetailCodec.variant_of(detail_at(cell))


func wear_at(cell: Vector2i) -> int:
	return TerrainDetailCodec.wear_of(detail_at(cell))


func snow_depth_at(cell: Vector2i) -> int:
	return TerrainDetailCodec.snow_depth_of(detail_at(cell))


## Traversal cost multiplier of this column's surface: material, wear and snow
## folded together (`terrain_materials.md` §2, §6.1, §6.2). This is a weight and
## never a passability — snow and wear must not move `topology_revision` (§7.5).
func surface_weight_at(cell: Vector2i) -> float:
	var detail := detail_at(cell)
	return TerrainMaterialCatalog.surface_weight(
		material_index_at(cell),
		TerrainDetailCodec.wear_of(detail),
		TerrainDetailCodec.snow_depth_of(detail),
	)


func slope_class_at(cell: Vector2i) -> int:
	if not is_inside(cell):
		return SlopeCatalog.CLASS_FLAT
	return int(_slope_classes[_index_of(cell)])


func slope_of(cell: Vector2i) -> StringName:
	return SlopeCatalog.id_of_class(slope_class_at(cell))


func slope_direction_of(cell: Vector2i) -> int:
	if not is_inside(cell):
		return SlopeCatalog.DIR_N
	return int(_slope_dirs[_index_of(cell)])


func slope_index_of(cell: Vector2i) -> int:
	if not is_inside(cell):
		return 0
	return int(_slope_indices[_index_of(cell)])


func flags_of(cell: Vector2i) -> int:
	if not is_inside(cell):
		return 0
	return int(_flags[_index_of(cell)])


func is_hole(cell: Vector2i) -> bool:
	return (flags_of(cell) & TerrainCell.FLAG_HOLE) != 0


func is_anchor(cell: Vector2i) -> bool:
	return (flags_of(cell) & TerrainCell.FLAG_ANCHOR) != 0


func is_ramp_cell(cell: Vector2i) -> bool:
	return SlopeCatalog.is_ramp_class(slope_class_at(cell))


func cell_at(cell: Vector2i) -> TerrainCell:
	var record := TerrainCell.new()
	record.height = height_of(cell)
	record.material_id = material_of(cell)
	var detail := detail_at(cell)
	record.variant = TerrainDetailCodec.variant_of(detail)
	record.wear = TerrainDetailCodec.wear_of(detail)
	record.snow_depth = TerrainDetailCodec.snow_depth_of(detail)
	record.slope_id = slope_of(cell)
	record.slope_dir = slope_direction_of(cell)
	record.slope_index = slope_index_of(cell)
	record.flags = flags_of(cell)
	return record


# --- Writes -----------------------------------------------------------------

## Sets a column height. Returns false (and changes nothing) when the target is
## outside the board or outside the legal height range — §2.2 forbids silent
## clamping. Ramps invalidated by the move are dissolved first: a ramp is a single
## object spanning its run AND the column it climbs to, so it cannot survive any
## of those columns moving.
func set_height(cell: Vector2i, height: int) -> bool:
	if not is_inside(cell):
		return false
	if height < MIN_HEIGHT or height > MAX_HEIGHT:
		return false
	var index := _index_of(cell)
	if _heights[index] == height and not is_ramp_cell(cell):
		return true
	dissolve_ramps_touching(cell)
	_heights[index] = height
	_touch(cell)
	return true


## Writes a whole column state at once: height, slope descriptor, material, detail
## byte and flags. This is the commit path for `TerrainDelta` — it does NOT
## dissolve ramps or run any cascade, because the delta already describes the
## final state of every cell it touches. Tools use `set_height` / `place_ramp`
## instead.
##
## Geometry and surface are dirtied separately, by comparing against what is
## already stored: a delta that only repainted a column (or the undo of one) must
## not cost a remesh (§7.5), and the undo path is exactly where that guarantee is
## easiest to lose.
func set_cell_state(cell: Vector2i, height: int, slope_class: int, slope_dir: int, slope_index: int, material_index: int, flags: int, detail: int = TerrainDetailCodec.DEFAULT_DETAIL) -> bool:
	if not is_inside(cell):
		return false
	if height < MIN_HEIGHT or height > MAX_HEIGHT:
		return false
	if not SlopeCatalog.is_valid_class(slope_class):
		return false
	if not TerrainMaterialCatalog.is_valid_index(material_index):
		return false
	var index := _index_of(cell)
	var next_dir := clampi(slope_dir, 0, 7)
	var next_index := clampi(slope_index, 0, 255)
	var next_flags := flags & 0xFF
	var next_detail := detail & 0xFF
	var geometry_changed := (
		_heights[index] != height
		or _slope_classes[index] != slope_class
		or _slope_dirs[index] != next_dir
		or _slope_indices[index] != next_index
		or _flags[index] != next_flags
	)
	var surface_changed := _materials[index] != material_index or _details[index] != next_detail
	_heights[index] = height
	_slope_classes[index] = slope_class
	_slope_dirs[index] = next_dir
	_slope_indices[index] = next_index
	_materials[index] = material_index
	_details[index] = next_detail
	_flags[index] = next_flags
	if geometry_changed:
		_touch(cell)
	if geometry_changed or surface_changed:
		_touch_surface(cell)
	return true


func offset_height(cell: Vector2i, delta: int) -> bool:
	return set_height(cell, height_of(cell) + delta)


func set_material(cell: Vector2i, material_id: StringName) -> bool:
	return set_material_index(cell, TerrainMaterialCatalog.index_of(material_id))


## Painting a material touches no geometry at all: the index reaches the GPU
## through the index map (§7.3), so the mesh, its collision and the chunk queue
## are all left alone. The only consequences are the texel and the traversal
## weight.
func set_material_index(cell: Vector2i, material_index: int) -> bool:
	if not is_inside(cell) or not TerrainMaterialCatalog.is_valid_index(material_index):
		return false
	var index := _index_of(cell)
	if _materials[index] == material_index:
		return true
	_materials[index] = material_index
	_touch_surface(cell)
	return true


func set_detail(cell: Vector2i, detail: int) -> bool:
	if not is_inside(cell):
		return false
	var index := _index_of(cell)
	var next_detail := detail & 0xFF
	if _details[index] == next_detail:
		return true
	_details[index] = next_detail
	_touch_surface(cell)
	return true


func set_variant(cell: Vector2i, variant: int) -> bool:
	return set_detail(cell, TerrainDetailCodec.with_variant(detail_at(cell), variant))


func set_wear(cell: Vector2i, wear: int) -> bool:
	return set_detail(cell, TerrainDetailCodec.with_wear(detail_at(cell), wear))


func set_snow_depth(cell: Vector2i, snow_depth: int) -> bool:
	return set_detail(cell, TerrainDetailCodec.with_snow_depth(detail_at(cell), snow_depth))


func set_flag(cell: Vector2i, flag: int, enabled: bool) -> bool:
	if not is_inside(cell):
		return false
	var index := _index_of(cell)
	var next_flags := (_flags[index] | flag) if enabled else (_flags[index] & ~flag)
	if _flags[index] == next_flags:
		return true
	_flags[index] = next_flags
	_touch(cell)
	return true


## Cutting a hole removes ground, so every ramp that leaned on this column — its
## own and the ones climbing to it — goes with it.
func set_hole(cell: Vector2i, enabled: bool) -> bool:
	if enabled and is_inside(cell):
		dissolve_ramps_touching(cell)
	return set_flag(cell, TerrainCell.FLAG_HOLE, enabled)


func set_anchor(cell: Vector2i, enabled: bool) -> bool:
	return set_flag(cell, TerrainCell.FLAG_ANCHOR, enabled)


# --- Ramps ------------------------------------------------------------------

## Cells occupied by the ramp `cell` belongs to, ordered from its low end to its
## high end. Empty when the cell carries no ramp.
func ramp_cells_at(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var slope_class := slope_class_at(cell)
	if not SlopeCatalog.is_ramp_class(slope_class):
		return result
	var offset := SlopeCatalog.direction_offset(slope_direction_of(cell))
	var start := cell - offset * slope_index_of(cell)
	for step in SlopeCatalog.run_of_class(slope_class):
		result.append(start + offset * step)
	return result


## The column a ramp climbs to. It is not part of the ramp's run, but the ramp is
## only meaningful while that column sits exactly `rise` steps above the run — so
## it is part of the ramp's identity for invalidation purposes.
func ramp_top_anchor_at(cell: Vector2i) -> Vector2i:
	var slope_class := slope_class_at(cell)
	if not SlopeCatalog.is_ramp_class(slope_class):
		return cell
	var offset := SlopeCatalog.direction_offset(slope_direction_of(cell))
	var start := cell - offset * slope_index_of(cell)
	return start + offset * SlopeCatalog.run_of_class(slope_class)


## Places one whole ramp starting at `start_cell` and rising towards `direction`.
##
## Refuses unless the run fits: every cell in bounds, free of holes and other
## ramps, all at the same height, and the column right beyond the top end exactly
## `rise` steps higher. A partial ramp cannot exist in the data (§3.1), so this is
## all-or-nothing.
func place_ramp(start_cell: Vector2i, slope_id: StringName, direction: int) -> bool:
	return place_ramp_class(start_cell, SlopeCatalog.slope_class_of(slope_id), direction)


func place_ramp_class(start_cell: Vector2i, slope_class: int, direction: int) -> bool:
	if not can_place_ramp_class(start_cell, slope_class, direction):
		return false
	var offset := SlopeCatalog.direction_offset(direction)
	var base_height := height_of(start_cell)
	for step in SlopeCatalog.run_of_class(slope_class):
		var cell := start_cell + offset * step
		var index := _index_of(cell)
		_heights[index] = base_height
		_slope_classes[index] = slope_class
		_slope_dirs[index] = direction
		_slope_indices[index] = step
		_touch(cell)
	return true


func can_place_ramp(start_cell: Vector2i, slope_id: StringName, direction: int) -> bool:
	return can_place_ramp_class(start_cell, SlopeCatalog.slope_class_of(slope_id), direction)


func can_place_ramp_class(start_cell: Vector2i, slope_class: int, direction: int) -> bool:
	return ramp_placement_rejection(start_cell, slope_class, direction) == &""


## Empty when a ramp can be placed.  The editor uses the stable reason codes to
## explain its preview; placement itself uses this same query, so the preview
## cannot promise an invalid edit.
func ramp_placement_rejection(start_cell: Vector2i, slope_class: int, direction: int) -> StringName:
	if not SlopeCatalog.is_ramp_class(slope_class):
		return &"invalid_slope"
	if not SlopeCatalog.is_orthogonal(direction):
		return &"invalid_direction"
	if not is_inside(start_cell) or is_hole(start_cell):
		return &"start_outside" if not is_inside(start_cell) else &"start_hole"
	var offset := SlopeCatalog.direction_offset(direction)
	var run := SlopeCatalog.run_of_class(slope_class)
	var rise := SlopeCatalog.rise_of_class(slope_class)
	var base_height := height_of(start_cell)
	for step in run:
		var cell := start_cell + offset * step
		if not is_inside(cell):
			return &"run_outside"
		if is_hole(cell):
			return &"run_hole"
		if is_anchor(cell):
			return &"run_anchor"
		if height_of(cell) != base_height:
			return &"run_height"
		if is_ramp_cell(cell):
			return &"run_ramp"
	var top_cell := start_cell + offset * run
	if not is_inside(top_cell):
		return &"top_outside"
	if is_hole(top_cell):
		return &"top_hole"
	if is_ramp_cell(top_cell):
		return &"top_ramp"
	return &"" if height_of(top_cell) == base_height + rise else &"top_height"


## Turns the ramp containing `cell` back into flat columns at its base height.
## Returns true when a ramp was actually removed.
func dissolve_ramp_at(cell: Vector2i) -> bool:
	var cells := ramp_cells_at(cell)
	if cells.is_empty():
		return false
	for ramp_cell: Vector2i in cells:
		var index := _index_of(ramp_cell)
		_slope_classes[index] = SlopeCatalog.CLASS_FLAT
		_slope_dirs[index] = 0
		_slope_indices[index] = 0
		_touch(ramp_cell)
	return true


## Every ramp that editing `cell` would break: the one it belongs to, plus the
## ones that climb to it. A ramp whose top column moves would otherwise survive as
## a slope leading into a wall — the invariant §3.1 has to hold after every write,
## not only at placement time.
func ramps_touching(cell: Vector2i) -> Array[Vector2i]:
	var starts: Array[Vector2i] = []
	if is_ramp_cell(cell):
		starts.append(cell)
	for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
		var neighbour := cell + SlopeCatalog.direction_offset(direction)
		if not is_ramp_cell(neighbour):
			continue
		if ramp_top_anchor_at(neighbour) == cell:
			starts.append(neighbour)
	return starts


func dissolve_ramps_touching(cell: Vector2i) -> bool:
	var dissolved := false
	for ramp_cell: Vector2i in ramps_touching(cell):
		dissolved = dissolve_ramp_at(ramp_cell) or dissolved
	return dissolved


## True when the ramp under `cell` still satisfies everything §3.1 demands of it.
## Used by tests and by tools that want to assert the invariant rather than rely
## on every write path remembering it.
func is_ramp_valid_at(cell: Vector2i) -> bool:
	var slope_class := slope_class_at(cell)
	if not SlopeCatalog.is_ramp_class(slope_class):
		return false
	var cells := ramp_cells_at(cell)
	var direction := slope_direction_of(cell)
	if not SlopeCatalog.is_orthogonal(direction):
		return false
	var base_height := height_of(cells[0])
	for step in cells.size():
		var ramp_cell: Vector2i = cells[step]
		if not is_inside(ramp_cell) or is_hole(ramp_cell):
			return false
		if slope_class_at(ramp_cell) != slope_class or slope_direction_of(ramp_cell) != direction:
			return false
		if slope_index_of(ramp_cell) != step or height_of(ramp_cell) != base_height:
			return false
	# The column it climbs to may itself be a ramp — a hillside is a chain of them,
	# and the corner heights still line up because a ramp cell stores its base.
	# `can_place_ramp` is stricter on purpose: that is a tool rule, not a data one.
	var top_cell := ramp_top_anchor_at(cell)
	if not is_inside(top_cell) or is_hole(top_cell):
		return false
	return height_of(top_cell) == base_height + SlopeCatalog.rise_of_class(slope_class)


# --- Derived geometry -------------------------------------------------------

## Heights (in steps, fractional) of the cell's four corners, ordered
## NW, NE, SE, SW. This is the only place fractional height is created, and it is
## produced purely by unrolling the stored slope descriptor (§2.1, §3.3).
func corner_heights(cell: Vector2i) -> PackedFloat32Array:
	var result := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	corner_heights_into(cell, result)
	return result


## Same, writing into a caller-owned buffer of 4 floats. The mesher walks every
## cell of a chunk and every one of their neighbours, so the allocation matters.
## §3.4: corner heights follow the cell's own descriptor AND the neighbours that
## share those corners — the four orthogonal ones over an edge, the four diagonal
## ones over a single point.
##
## Only neighbours that carry a slope lift anything. That is the whole rule: a
## slope is terrain that has already been shaped, so the corner it raises is
## raised for everybody standing on it, while a flat column beside a flat column
## is a terrace and has to stay sheer (§4.1). Without the neighbour half, a
## hillside is a set of axis-aligned ramps with a vertical wedge across every
## diagonal, and every convex corner of the hill keeps a triangular face.
##
## The lift never carries a corner higher than one `rise` above the column it
## belongs to (one whole step for a flat column), so a real cliff to a taller
## terrace stays a cliff.
func corner_heights_into(cell: Vector2i, result: PackedFloat32Array) -> void:
	var slope_class := slope_class_at(cell)
	_descriptor_corners_into(cell, slope_class, result)
	if is_hole(cell) or not is_inside(cell):
		return
	var rise_steps := SlopeCatalog.rise_of_class(slope_class)
	# Lifts come from ANY slope (`_lifts_corners`) and never from a flat column:
	# a slope is ground that has already been shaped, so the corner it raises is
	# raised for everyone standing on that point, while a terrace beside a terrace
	# has to stay sheer (§4.1). Restricting the source to one-cell 45° slopes was
	# tried and grows triangular fins along the sides of sand terraces and authored
	# ramps, where the neighbour rose and the flat ground beside it did not.
	#
	# The lift is a whole number of steps and at most two. Whole steps keep the
	# rule single-valued: every column sharing the corner tests the same integer,
	# so the ones that accept it land on exactly the same height and the surface
	# closes instead of tearing somewhere else. Two steps is what a diagonal of a
	# 45° hillside actually drops (one step each way), which is why the corner
	# between four such cells needs it; the result is a `very_steep` corner, still
	# straight out of the catalog.
	# The overwhelmingly common cell: flat ground with nothing sloped touching it.
	# Its corners are its own height and the two neighbour passes below cannot
	# change that, so the whole scan is skipped. This is what makes publishing a
	# board proportional to how much of it is actually shaped rather than to how
	# many cells it has.
	if not SlopeCatalog.is_ramp_class(slope_class) and not _has_ramp_neighbour(cell):
		return

	var own_height := height_of(cell)
	var lift_ceiling := float(own_height + MAX_CORNER_LIFT_STEPS)
	# Reused across calls rather than allocated per cell. Nothing below re-enters
	# this function, so a single scratch buffer is safe.
	var neighbour_corners := _neighbour_corner_scratch

	for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
		var neighbour := cell + SlopeCatalog.direction_offset(direction)
		if not is_inside(neighbour) or is_hole(neighbour):
			continue
		if not _lifts_corners(neighbour):
			# A flat column exactly one step above a single-cell slope is the
			# other half of that slope's corner; anything else is a face.
			if (
				SlopeCatalog.is_ramp_class(slope_class)
				and SlopeCatalog.run_of_class(slope_class) == 1
				and height_of(neighbour) == height_of(cell) + rise_steps
			):
				_raise_edge(result, direction, float(own_height + rise_steps))
			continue
		_descriptor_corners_into(neighbour, slope_class_at(neighbour), neighbour_corners)
		var mapping: Array = SHARED_CORNERS[direction]
		for pair in 2:
			_lift_corner(result, int(mapping[pair * 2]), neighbour_corners[int(mapping[pair * 2 + 1])], lift_ceiling)

	for direction: int in DIAGONAL_DIRECTIONS:
		var neighbour := cell + SlopeCatalog.direction_offset(direction)
		if not is_inside(neighbour) or is_hole(neighbour) or not _lifts_corners(neighbour):
			continue
		_descriptor_corners_into(neighbour, slope_class_at(neighbour), neighbour_corners)
		var mapping: Array = SHARED_DIAGONAL_CORNERS[direction]
		_lift_corner(result, int(mapping[0]), neighbour_corners[int(mapping[1])], lift_ceiling)

	# A column surrounded on three sides — the inside of a pit — can end up with
	# every corner pulled up, and then its surface sits a whole step above its
	# stored height. That is allowed: mesh, collision and `height_at` all read the
	# same corners, so they still agree with each other, and refusing the lift
	# there would tear the inside of every pit open instead.


## A neighbour whose corners pull ours up: any slope at all. A slope is ground
## that has already been shaped, so the corner it raises is raised for everyone
## standing on that point; a flat column is not, which is what keeps a terrace
## beside a terrace sheer (§4.1).
func _lifts_corners(cell: Vector2i) -> bool:
	return SlopeCatalog.is_ramp_class(slope_class_at(cell))


## Whether any of the eight neighbours carries a slope — the question that decides
## if a flat column needs the corner-lift scan at all.
##
## Indexes the slope array directly instead of going through `is_inside` and
## `slope_class_at`, which would be three calls per neighbour and twenty-four per
## cell. Everything it inlines is the arithmetic in `_index_of`.
func _has_ramp_neighbour(cell: Vector2i) -> bool:
	var low := -board_half_cells
	var high := board_cells - board_half_cells - 1
	for offset: Vector2i in SlopeCatalog.DIRECTION_OFFSETS:
		var x := cell.x + offset.x
		var z := cell.y + offset.y
		if x < low or x > high or z < low or z > high:
			continue
		if SlopeCatalog.IS_RAMP_BY_CLASS[_slope_classes[(z + board_half_cells) * board_cells + (x + board_half_cells)]]:
			return true
	return false


## Takes a neighbour's corner whole or not at all — never clamped, because a
## clamped corner stops at a height nobody else agrees on.
static func _lift_corner(result: PackedFloat32Array, corner: int, target: float, ceiling: float) -> void:
	if target > result[corner] and target <= ceiling + 0.0001:
		result[corner] = target


## Corner heights from the stored descriptor alone, before the neighbour pass.
func _descriptor_corners_into(cell: Vector2i, slope_class: int, result: PackedFloat32Array) -> void:
	var base := float(height_of(cell))
	if not SlopeCatalog.is_ramp_class(slope_class):
		result[0] = base
		result[1] = base
		result[2] = base
		result[3] = base
		return
	var run := SlopeCatalog.run_of_class(slope_class)
	var rise := float(SlopeCatalog.rise_of_class(slope_class))
	var step_index := float(slope_index_of(cell))
	var low := base + rise * step_index / float(run)
	var high := base + rise * (step_index + 1.0) / float(run)
	result[0] = low
	result[1] = low
	result[2] = low
	result[3] = low
	_raise_edge(result, slope_direction_of(cell), high)


static func _raise_edge(result: PackedFloat32Array, direction: int, height: float) -> void:
	match direction:
		SlopeCatalog.DIR_N:
			result[CORNER_NW] = height
			result[CORNER_NE] = height
		SlopeCatalog.DIR_E:
			result[CORNER_NE] = height
			result[CORNER_SE] = height
		SlopeCatalog.DIR_S:
			result[CORNER_SE] = height
			result[CORNER_SW] = height
		SlopeCatalog.DIR_W:
			result[CORNER_SW] = height
			result[CORNER_NW] = height


## Height in steps a body standing anywhere inside the cell would have. `u` runs
## west→east and `v` north→south, both in [0, 1].
##
## The cell is read as the same two triangles the mesher emits, split NW–SE, not
## as a bilinear patch. Once a corner can be lifted on its own (§3.4) the quad is
## no longer planar, and the two readings differ by up to half a step in the
## middle of it — which would put a citizen's feet through the ground they are
## standing on. Mesh, collision and standing height have to be one surface.
func height_steps_in_cell(cell: Vector2i, u: float, v: float) -> float:
	var corners := corner_heights(cell)
	var east := clampf(u, 0.0, 1.0)
	var south := clampf(v, 0.0, 1.0)
	if east >= south:
		# North-east triangle: NW → NE → SE.
		return corners[CORNER_NW] + (corners[CORNER_NE] - corners[CORNER_NW]) * east + (corners[CORNER_SE] - corners[CORNER_NE]) * south
	# South-west triangle: NW → SE → SW.
	return corners[CORNER_NW] + (corners[CORNER_SW] - corners[CORNER_NW]) * south + (corners[CORNER_SE] - corners[CORNER_SW]) * east


## World-space ground height in metres under a position — the query navigation,
## citizens and previews will use (§10.4).
func height_at(world_position: Vector3) -> float:
	var cell := cell_from_position(world_position)
	var u := world_position.x / cell_size - float(cell.x)
	var v := world_position.z / cell_size - float(cell.y)
	return height_steps_in_cell(cell, u, v) * HEIGHT_STEP


func cell_from_position(world_position: Vector3) -> Vector2i:
	return Vector2i(floori(world_position.x / cell_size), floori(world_position.z / cell_size))


func cell_center(cell: Vector2i) -> Vector3:
	var height := height_steps_in_cell(cell, 0.5, 0.5) * HEIGHT_STEP
	return Vector3((float(cell.x) + 0.5) * cell_size, height, (float(cell.y) + 0.5) * cell_size)


## Byte-exact copy of everything stored. Used by tests to prove that applying a
## delta and reverting it restores the grid exactly, and it is the shape the save
## format (§12) writes per chunk.
func snapshot() -> Dictionary:
	return {
		"heights": _heights.duplicate(),
		"materials": _materials.duplicate(),
		"details": _details.duplicate(),
		"slope_classes": _slope_classes.duplicate(),
		"slope_dirs": _slope_dirs.duplicate(),
		"slope_indices": _slope_indices.duplicate(),
		"flags": _flags.duplicate(),
	}


# --- Chunks -----------------------------------------------------------------

func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK_CELLS), floori(float(cell.y) / CHUNK_CELLS))


func chunk_origin_cell(chunk: Vector2i) -> Vector2i:
	return chunk * CHUNK_CELLS


func chunk_coords() -> Array[Vector2i]:
	var chunks: Array[Vector2i] = []
	var first := chunk_of(min_cell())
	var last := chunk_of(max_cell())
	for z in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			chunks.append(Vector2i(x, z))
	return chunks


func mark_all_chunks_dirty() -> void:
	for chunk: Vector2i in chunk_coords():
		_dirty_chunks[chunk] = true


func mark_chunk_dirty(chunk: Vector2i) -> void:
	_dirty_chunks[chunk] = true


func has_dirty_chunks() -> bool:
	return not _dirty_chunks.is_empty()


## Hands the dirty set over and clears it. Sorted so a rebuild budget consumes
## chunks in the same order on every machine (§4.4 determinism).
func take_dirty_chunks() -> Array[Vector2i]:
	var chunks: Array[Vector2i] = []
	for chunk: Vector2i in _dirty_chunks:
		chunks.append(chunk)
	chunks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	_dirty_chunks.clear()
	return chunks


# --- Surface texels ---------------------------------------------------------

func mark_all_surface_dirty() -> void:
	if board_cells <= 0:
		return
	var minimum := min_cell()
	var maximum := max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			_dirty_surface_cells[Vector2i(x, z)] = true


func has_dirty_surface_cells() -> bool:
	return not _dirty_surface_cells.is_empty()


## Hands over the columns whose index/detail texels are stale and clears the set.
## Sorted for the same reason the dirty chunks are (§4.4 determinism).
func take_dirty_surface_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _dirty_surface_cells:
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	_dirty_surface_cells.clear()
	return cells


# --- Internals --------------------------------------------------------------

func _index_of(cell: Vector2i) -> int:
	return (cell.y + board_half_cells) * board_cells + (cell.x + board_half_cells)


## A cell's geometry is shared with its neighbours' side faces, so an edit on a
## chunk border dirties the neighbouring chunks too — but only there. A cascade
## touches thousands of cells and almost none of them sit on a border, so the
## border test is much cheaper than unconditionally marking nine chunks.
func _touch(cell: Vector2i) -> void:
	_revision += 1
	var chunk := chunk_of(cell)
	_dirty_chunks[chunk] = true
	var local_x := cell.x - chunk.x * CHUNK_CELLS
	var local_z := cell.y - chunk.y * CHUNK_CELLS
	var step_x := 0
	var step_z := 0
	if local_x == 0:
		step_x = -1
	elif local_x == CHUNK_CELLS - 1:
		step_x = 1
	if local_z == 0:
		step_z = -1
	elif local_z == CHUNK_CELLS - 1:
		step_z = 1
	if step_x != 0:
		_dirty_chunks[chunk + Vector2i(step_x, 0)] = true
	if step_z != 0:
		_dirty_chunks[chunk + Vector2i(0, step_z)] = true
	if step_x != 0 and step_z != 0:
		_dirty_chunks[chunk + Vector2i(step_x, step_z)] = true


## A surface edit is one texel and nothing else — no neighbours, no chunk, no
## collision. The index map is per column, so unlike geometry it has no ring of
## influence around the cell that changed.
func _touch_surface(cell: Vector2i) -> void:
	_revision += 1
	_dirty_surface_cells[cell] = true
