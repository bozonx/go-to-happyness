class_name TerrainGrid
extends RefCounted

## The settlement's discrete elevation grid (design_docs/core/grid_terrain_system.md §2).
##
## Stores exactly four things per column: integer height in Δh steps, surface
## material, slope descriptor (catalog id + direction + index inside a multi-cell
## ramp) and flags. Everything fractional — corner heights, standing height,
## slope classes of faces — is DERIVED here and lives only in the generated mesh.
## That invariant is what keeps mesh, navigation and saves from drifting apart.
##
## Cell coordinates are centred on the world origin like `NavGrid`: for a board of
## N cells they run from -N/2 to N/2-1, and cell (x, z) covers world
## [x*cell_size, (x+1)*cell_size] × [z*cell_size, (z+1)*cell_size].
##
## Storage is flat packed arrays rather than per-chunk arrays. The chunk grid is
## still first-class (see `chunk_of` / `take_dirty_chunks`) because meshing and
## the save format (§12) are chunked; splitting the backing storage per chunk is a
## save-format optimisation and can be done without touching this API.

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

var cell_size := 1.0
var board_cells := 0
var board_half_cells := 0

var _heights := PackedInt32Array()
var _materials := PackedByteArray()
var _slope_classes := PackedByteArray()
var _slope_dirs := PackedByteArray()
var _slope_indices := PackedByteArray()
var _flags := PackedByteArray()

var _revision := 0
var _dirty_chunks: Dictionary = {}


func configure(next_cell_size: float, next_board_cells: int, fill_height: int = 0, fill_material: StringName = TerrainMaterialCatalog.DEFAULT_MATERIAL) -> void:
	cell_size = next_cell_size
	board_cells = maxi(next_board_cells, 0)
	board_half_cells = board_cells / 2
	var count := board_cells * board_cells
	_heights = PackedInt32Array()
	_heights.resize(count)
	_materials = PackedByteArray()
	_materials.resize(count)
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
	_slope_classes.fill(0)
	_slope_dirs.fill(0)
	_slope_indices.fill(0)
	_flags.fill(0)
	_revision += 1
	mark_all_chunks_dirty()


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


func material_of(cell: Vector2i) -> StringName:
	if not is_inside(cell):
		return TerrainMaterialCatalog.DEFAULT_MATERIAL
	return TerrainMaterialCatalog.id_of_index(_materials[_index_of(cell)])


func slope_of(cell: Vector2i) -> StringName:
	if not is_inside(cell):
		return SlopeCatalog.FLAT
	return SlopeCatalog.id_of_class(_slope_classes[_index_of(cell)])


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
	return SlopeCatalog.is_ramp(slope_of(cell))


func cell_at(cell: Vector2i) -> TerrainCell:
	var record := TerrainCell.new()
	record.height = height_of(cell)
	record.material_id = material_of(cell)
	record.slope_id = slope_of(cell)
	record.slope_dir = slope_direction_of(cell)
	record.slope_index = slope_index_of(cell)
	record.flags = flags_of(cell)
	return record


# --- Writes -----------------------------------------------------------------

## Sets a column height. Returns false (and changes nothing) when the target is
## outside the board or outside the legal height range — §2.2 forbids silent
## clamping. Any ramp the cell belonged to is dissolved first: a ramp is a single
## object, so it cannot survive one of its cells moving.
func set_height(cell: Vector2i, height: int) -> bool:
	if not is_inside(cell):
		return false
	if height < MIN_HEIGHT or height > MAX_HEIGHT:
		return false
	dissolve_ramp_at(cell)
	var index := _index_of(cell)
	if _heights[index] == height:
		return true
	_heights[index] = height
	_touch(cell)
	return true


func offset_height(cell: Vector2i, delta: int) -> bool:
	return set_height(cell, height_of(cell) + delta)


func set_material(cell: Vector2i, material_id: StringName) -> bool:
	if not is_inside(cell):
		return false
	var material_index := TerrainMaterialCatalog.index_of(material_id)
	if material_index < 0:
		return false
	var index := _index_of(cell)
	if _materials[index] == material_index:
		return true
	_materials[index] = material_index
	_touch(cell)
	return true


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


func set_hole(cell: Vector2i, enabled: bool) -> bool:
	if enabled:
		dissolve_ramp_at(cell)
	return set_flag(cell, TerrainCell.FLAG_HOLE, enabled)


func set_anchor(cell: Vector2i, enabled: bool) -> bool:
	return set_flag(cell, TerrainCell.FLAG_ANCHOR, enabled)


# --- Ramps ------------------------------------------------------------------

## Cells occupied by the ramp `cell` belongs to, ordered from its low end to its
## high end. Empty when the cell carries no ramp.
func ramp_cells_at(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var slope_id := slope_of(cell)
	if not SlopeCatalog.is_ramp(slope_id):
		return result
	var offset := SlopeCatalog.direction_offset(slope_direction_of(cell))
	var start := cell - offset * slope_index_of(cell)
	for step in SlopeCatalog.run_of(slope_id):
		result.append(start + offset * step)
	return result


## Places one whole ramp starting at `start_cell` and rising towards `direction`.
##
## Refuses unless the run fits: every cell in bounds, free of holes and other
## ramps, all at the same height, and the column right beyond the top end exactly
## `rise` steps higher. A partial ramp cannot exist in the data (§3.1), so this is
## all-or-nothing.
func place_ramp(start_cell: Vector2i, slope_id: StringName, direction: int) -> bool:
	if not SlopeCatalog.is_ramp(slope_id) or not SlopeCatalog.is_orthogonal(direction):
		return false
	if not can_place_ramp(start_cell, slope_id, direction):
		return false
	var offset := SlopeCatalog.direction_offset(direction)
	var slope_class := SlopeCatalog.slope_class_of(slope_id)
	var base_height := height_of(start_cell)
	for step in SlopeCatalog.run_of(slope_id):
		var cell := start_cell + offset * step
		var index := _index_of(cell)
		_heights[index] = base_height
		_slope_classes[index] = slope_class
		_slope_dirs[index] = direction
		_slope_indices[index] = step
		_touch(cell)
	return true


func can_place_ramp(start_cell: Vector2i, slope_id: StringName, direction: int) -> bool:
	if not SlopeCatalog.is_ramp(slope_id) or not SlopeCatalog.is_orthogonal(direction):
		return false
	var offset := SlopeCatalog.direction_offset(direction)
	var run := SlopeCatalog.run_of(slope_id)
	var rise := SlopeCatalog.rise_of(slope_id)
	if not is_inside(start_cell):
		return false
	var base_height := height_of(start_cell)
	for step in run:
		var cell := start_cell + offset * step
		if not is_inside(cell) or is_hole(cell) or is_anchor(cell):
			return false
		if height_of(cell) != base_height:
			return false
		if is_ramp_cell(cell):
			return false
	var top_cell := start_cell + offset * run
	if not is_inside(top_cell) or is_hole(top_cell) or is_ramp_cell(top_cell):
		return false
	return height_of(top_cell) == base_height + rise


## Turns the ramp containing `cell` back into flat columns at its base height.
## Returns true when a ramp was actually removed.
func dissolve_ramp_at(cell: Vector2i) -> bool:
	var cells := ramp_cells_at(cell)
	if cells.is_empty():
		return false
	for ramp_cell: Vector2i in cells:
		var index := _index_of(ramp_cell)
		_slope_classes[index] = 0
		_slope_dirs[index] = 0
		_slope_indices[index] = 0
		_touch(ramp_cell)
	return true


# --- Derived geometry -------------------------------------------------------

## Heights (in steps, fractional) of the cell's four corners, ordered
## NW, NE, SE, SW. This is the only place fractional height is created, and it is
## produced purely by unrolling the stored slope descriptor (§2.1, §3.3).
func corner_heights(cell: Vector2i) -> PackedFloat32Array:
	var result := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var base := float(height_of(cell))
	var slope_id := slope_of(cell)
	if not SlopeCatalog.is_ramp(slope_id):
		result.fill(base)
		return result
	var run := SlopeCatalog.run_of(slope_id)
	var rise := float(SlopeCatalog.rise_of(slope_id))
	var step_index := float(slope_index_of(cell))
	var low := base + rise * step_index / float(run)
	var high := base + rise * (step_index + 1.0) / float(run)
	result.fill(low)
	for corner in _corners_towards(slope_direction_of(cell)):
		result[corner] = high
	return result


## Height in steps a body standing anywhere inside the cell would have, sampled
## by bilinear interpolation of the corner heights. `u` runs west→east and `v`
## north→south, both in [0, 1].
func height_steps_in_cell(cell: Vector2i, u: float, v: float) -> float:
	var corners := corner_heights(cell)
	var north := lerpf(corners[CORNER_NW], corners[CORNER_NE], clampf(u, 0.0, 1.0))
	var south := lerpf(corners[CORNER_SW], corners[CORNER_SE], clampf(u, 0.0, 1.0))
	return lerpf(north, south, clampf(v, 0.0, 1.0))


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


# --- Internals --------------------------------------------------------------

func _index_of(cell: Vector2i) -> int:
	return (cell.y + board_half_cells) * board_cells + (cell.x + board_half_cells)


## A cell's geometry is shared with its neighbours' side faces, so an edit dirties
## the neighbouring chunks too.
func _touch(cell: Vector2i) -> void:
	_revision += 1
	for offset_z in [-1, 0, 1]:
		for offset_x in [-1, 0, 1]:
			_dirty_chunks[chunk_of(cell + Vector2i(offset_x, offset_z))] = true


func _corners_towards(direction: int) -> Array[int]:
	match direction:
		SlopeCatalog.DIR_N:
			return [CORNER_NW, CORNER_NE]
		SlopeCatalog.DIR_E:
			return [CORNER_NE, CORNER_SE]
		SlopeCatalog.DIR_S:
			return [CORNER_SE, CORNER_SW]
		SlopeCatalog.DIR_W:
			return [CORNER_SW, CORNER_NW]
	return []
