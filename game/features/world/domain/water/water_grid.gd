class_name WaterGrid
extends RefCounted

## The water layer of a board (design_docs/engine/grid_terrain_system.md §9.3).
##
## Three flat arrays parallel to `TerrainGrid`, not sparse structures: a
## `Dictionary` over 65 536 cells costs a hash on every shader update and every
## navigation publish to save a few tens of kilobytes.
##
## | array          | format  | meaning                                    |
## | -------------- | ------- | ------------------------------------------ |
## | `water_height` | `int8`  | surface level in Δh steps, biased like the terrain |
## | `body_id`      | `uint8` | which `WaterBody`; 0 is dry                |
## | `water_flags`  | `uint8` | FROZEN, ice thickness (2 bits), reserve    |
##
## **Water is authored, not simulated** (§9.1). Nothing here flows between frames:
## the level is painted, low ground is filled once at edit time, and no game
## decision has ever needed real hydrodynamics.
##
## Depth is not stored. It is `water_height - terrain_height`, and storing it
## would create a second copy of the ground that the next terrain edit silently
## invalidates. Everything that needs depth asks `depth_steps_at(terrain, cell)`.
##
## The registry of bodies lives here too, because a cell's `body_id` is
## meaningless without it and the two must be configured, saved and loaded as one
## layer.

## Same bias as the terrain layer, so a water surface can sit anywhere the ground
## can (`TerrainGrid.MIN_HEIGHT` … `MAX_HEIGHT`).
const MIN_HEIGHT := TerrainGrid.MIN_HEIGHT
const MAX_HEIGHT := TerrainGrid.MAX_HEIGHT

const FLAG_FROZEN := 1 << 0
const ICE_THICKNESS_SHIFT := 1
const ICE_THICKNESS_MASK := 0x03
const MAX_ICE_THICKNESS := 3

## Depth, in steps, up to which a cell is a ford rather than open water (§9.7).
## One step is 0.5 m — knee-deep.
const FORD_MAX_DEPTH_STEPS := 1
## What wading costs compared with dry ground of the same material (§9.7).
const FORD_WEIGHT_MULTIPLIER := 3.0

var cell_size := 1.0
var board_cells := 0
var board_half_cells := 0

var _heights := PackedInt32Array()
var _body_ids := PackedByteArray()
var _flags := PackedByteArray()

## id -> WaterBody. Ordered by insertion; `bodies()` sorts by id so anything
## written to disk or drawn in a list is deterministic.
var _bodies: Dictionary = {}

## body_id -> Dictionary[Vector2i, true]. Maintained alongside `_body_ids`
## so `cells_of_body` and `remove_body` are O(cells_in_body), not O(board²).
var _body_cells: Dictionary = {}

var _revision := 0


func configure(next_cell_size: float, next_board_cells: int) -> void:
	cell_size = next_cell_size
	board_cells = maxi(next_board_cells, 0)
	board_half_cells = board_cells / 2
	var count := board_cells * board_cells
	_heights = PackedInt32Array()
	_heights.resize(count)
	_body_ids = PackedByteArray()
	_body_ids.resize(count)
	_flags = PackedByteArray()
	_flags.resize(count)
	_bodies.clear()
	_body_cells.clear()
	_revision += 1


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


# --- Registry -----------------------------------------------------------------

## Registers a body under its own id, or under the next free one when it has
## none. Returns the id actually used, or `WaterBody.NO_BODY` when the registry
## is full — 255 bodies is a hard limit of the one-byte cell reference, not a
## soft one to clamp past.
func add_body(body: WaterBody) -> int:
	if body == null:
		return WaterBody.NO_BODY
	if body.id < WaterBody.MIN_ID or _bodies.has(body.id):
		var free_id := next_free_body_id()
		if free_id == WaterBody.NO_BODY:
			return WaterBody.NO_BODY
		body.id = free_id
	_bodies[body.id] = body
	_revision += 1
	return body.id


## Creates and registers a body of a type with that type's defaults.
func create_body(body_type: WaterBody.Type, surface_height := 0) -> WaterBody:
	var free_id := next_free_body_id()
	if free_id == WaterBody.NO_BODY:
		return null
	var body := WaterBody.of_type(free_id, body_type)
	body.surface_height = surface_height
	add_body(body)
	return body


## Drops a body and dries every cell that referenced it. A cell pointing at a body
## that is not in the registry is the one state this layer must never be in: the
## shader would read a colour from nowhere and navigation a depth from nowhere.
func remove_body(body_id: int) -> bool:
	if not _bodies.has(body_id):
		return false
	_bodies.erase(body_id)
	var cells: Dictionary = _body_cells.get(body_id, {})
	for cell: Vector2i in cells:
		var index := _index_of(cell)
		_body_ids[index] = WaterBody.NO_BODY
		_heights[index] = 0
		_flags[index] = 0
		_touch_index(index)
	_body_cells.erase(body_id)
	_revision += 1
	return true


func has_body(body_id: int) -> bool:
	return _bodies.has(body_id)


func body(body_id: int) -> WaterBody:
	return _bodies.get(body_id, null)


func body_count() -> int:
	return _bodies.size()


func bodies() -> Array[WaterBody]:
	var ids: Array[int] = []
	for body_id: int in _bodies:
		ids.append(body_id)
	ids.sort()
	var result: Array[WaterBody] = []
	for body_id: int in ids:
		result.append(_bodies[body_id])
	return result


func next_free_body_id() -> int:
	for candidate in range(WaterBody.MIN_ID, WaterBody.MAX_ID + 1):
		if not _bodies.has(candidate):
			return candidate
	return WaterBody.NO_BODY


func clear_bodies() -> void:
	_bodies.clear()
	_body_cells.clear()
	_revision += 1


# --- Reads --------------------------------------------------------------------

func body_id_at(cell: Vector2i) -> int:
	if not is_inside(cell):
		return WaterBody.NO_BODY
	return int(_body_ids[_index_of(cell)])


func body_at(cell: Vector2i) -> WaterBody:
	return body(body_id_at(cell))


func has_water(cell: Vector2i) -> bool:
	return body_id_at(cell) != WaterBody.NO_BODY


## Surface level in steps. Meaningless — and returned as zero — where there is no
## water; ask `has_water` first.
func height_of(cell: Vector2i) -> int:
	if not is_inside(cell):
		return 0
	return _heights[_index_of(cell)]


func surface_metres_at(cell: Vector2i) -> float:
	return float(height_of(cell)) * TerrainGrid.HEIGHT_STEP


func flags_of(cell: Vector2i) -> int:
	if not is_inside(cell):
		return 0
	return int(_flags[_index_of(cell)])


func is_frozen(cell: Vector2i) -> bool:
	return (flags_of(cell) & FLAG_FROZEN) != 0


func ice_thickness_at(cell: Vector2i) -> int:
	if not is_frozen(cell):
		return 0
	return (flags_of(cell) >> ICE_THICKNESS_SHIFT) & ICE_THICKNESS_MASK


func is_lava(cell: Vector2i) -> bool:
	var found := body_at(cell)
	return found != null and found.is_lava()


## How deep the water stands over the ground of this column, in steps. Negative or
## zero means the ground is at or above the surface — a bank inside the painted
## outline, which happens constantly while an author paints a level over uneven
## terrain and is not an error.
func depth_steps_at(terrain: TerrainGrid, cell: Vector2i) -> int:
	if terrain == null or not has_water(cell):
		return 0
	return height_of(cell) - terrain.height_of(cell)


func depth_metres_at(terrain: TerrainGrid, cell: Vector2i) -> float:
	return float(depth_steps_at(terrain, cell)) * TerrainGrid.HEIGHT_STEP


## True where there is water deep enough to actually be water. A painted cell
## whose ground has since risen above the surface is dry again, and every consumer
## — mesh, navigation, drinking — has to agree about that without anyone
## rewriting the layer.
func is_wet(terrain: TerrainGrid, cell: Vector2i) -> bool:
	return has_water(cell) and depth_steps_at(terrain, cell) > 0


## A ford is water a walker can wade: shallow, not lava, and not swept by a strong
## current (§9.7). Ice is a different question entirely — see `is_frozen`.
func is_ford(terrain: TerrainGrid, cell: Vector2i) -> bool:
	if not is_wet(terrain, cell):
		return false
	var found := body_at(cell)
	if found == null or found.is_lava():
		return false
	if found.flow_strength_at(cell) >= WaterBody.FLOW_STRENGTH_BLOCKS_FORD:
		return false
	return depth_steps_at(terrain, cell) <= FORD_MAX_DEPTH_STEPS


func flow_direction_at(cell: Vector2i) -> int:
	var found := body_at(cell)
	return 0 if found == null else found.flow_direction_at(cell)


func flow_strength_at(cell: Vector2i) -> int:
	var found := body_at(cell)
	return 0 if found == null else found.flow_strength_at(cell)


# --- Writes -------------------------------------------------------------------

## Puts a cell into a body at a level, or dries it when `body_id` is
## `WaterBody.NO_BODY`. Refuses a body the registry does not know: a dangling
## reference is the one state this layer must never reach.
func set_cell(cell: Vector2i, body_id: int, height: int, flags: int = 0) -> bool:
	if not is_inside(cell):
		return false
	if body_id != WaterBody.NO_BODY and not _bodies.has(body_id):
		return false
	if body_id != WaterBody.NO_BODY and (height < MIN_HEIGHT or height > MAX_HEIGHT):
		return false
	var index := _index_of(cell)
	var next_height := height if body_id != WaterBody.NO_BODY else 0
	var next_flags := (flags & 0xFF) if body_id != WaterBody.NO_BODY else 0
	if _body_ids[index] == body_id and _heights[index] == next_height and _flags[index] == next_flags:
		return true
	var prev_body := int(_body_ids[index])
	if prev_body != body_id:
		_index_remove(prev_body, cell)
		_index_add(body_id, cell)
	_body_ids[index] = body_id
	_heights[index] = next_height
	_flags[index] = next_flags
	_touch(cell)
	return true


func clear_cell(cell: Vector2i) -> bool:
	return set_cell(cell, WaterBody.NO_BODY, 0, 0)


func set_height(cell: Vector2i, height: int) -> bool:
	if not has_water(cell):
		return false
	return set_cell(cell, body_id_at(cell), height, flags_of(cell))


## Freezes or thaws a cell. Thickness is what carries load (§9.6): a walker needs
## 1, a cart 2, a construction site can never be put on ice at all. Freezing a
## body that cannot freeze — lava, a fast river reach, a tropical sea — is
## refused rather than silently ignored, so a seasonal pass can count what it
## actually changed.
func set_frozen(cell: Vector2i, frozen: bool, thickness: int = MAX_ICE_THICKNESS) -> bool:
	if not has_water(cell):
		return false
	var found := body_at(cell)
	if frozen and (found == null or not found.can_freeze_at(cell)):
		return false
	var next_flags := flags_of(cell) & ~(FLAG_FROZEN | (ICE_THICKNESS_MASK << ICE_THICKNESS_SHIFT))
	if frozen:
		next_flags |= FLAG_FROZEN
		next_flags |= (clampi(thickness, 0, MAX_ICE_THICKNESS) & ICE_THICKNESS_MASK) << ICE_THICKNESS_SHIFT
	return set_cell(cell, body_id_at(cell), height_of(cell), next_flags)


static func pack_flags(frozen: bool, ice_thickness: int) -> int:
	if not frozen:
		return 0
	return FLAG_FROZEN | ((clampi(ice_thickness, 0, MAX_ICE_THICKNESS) & ICE_THICKNESS_MASK) << ICE_THICKNESS_SHIFT)


# --- Filling ------------------------------------------------------------------

## Every cell a body of this level would reach from `seed`, flood-filled over
## ground strictly below the surface and stopped by the board edge, by holes and
## by cells that already belong to a different body.
##
## This is the whole of §9.1's "low ground is filled once, at edit time": there is
## no per-frame spreading anywhere in the system, only this, run when the author
## asks for it.
func flood_cells(terrain: TerrainGrid, seed: Vector2i, level: int, keep_body_id := WaterBody.NO_BODY) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if terrain == null or not is_inside(seed) or terrain.height_of(seed) >= level:
		return found
	var seen: Dictionary = {seed: true}
	var queue: Array[Vector2i] = [seed]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		found.append(cell)
		for offset: Vector2i in ORTHOGONAL_OFFSETS:
			var neighbour := cell + offset
			if seen.has(neighbour) or not is_inside(neighbour):
				continue
			seen[neighbour] = true
			if terrain.is_hole(neighbour) or terrain.height_of(neighbour) >= level:
				continue
			var occupant := body_id_at(neighbour)
			if occupant != WaterBody.NO_BODY and occupant != keep_body_id:
				continue
			queue.append(neighbour)
	found.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return found


## The four orthogonal neighbours, in compass order. Water spreads and is meshed
## over edges only: a diagonal touch is a corner, and filling through one would
## leak a lake through the point where two banks meet.
const ORTHOGONAL_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


# --- Whole-layer helpers ------------------------------------------------------

## True when nothing has been authored. The package skips `water.bin` entirely for
## such a layer, exactly as it skips an untouched `terrain.bin`.
func is_empty() -> bool:
	if _bodies.is_empty():
		return true
	return _body_cells.is_empty()


func wet_cell_count() -> int:
	var count := 0
	for body_id: int in _body_cells:
		count += (_body_cells[body_id] as Dictionary).size()
	return count


## Byte-exact copy of the cell arrays, for tests that assert an edit and its undo
## leave the layer where it started.
func snapshot() -> Dictionary:
	return {
		"heights": _heights.duplicate(),
		"body_ids": _body_ids.duplicate(),
		"flags": _flags.duplicate(),
	}


# --- Internals ----------------------------------------------------------------

func _index_of(cell: Vector2i) -> int:
	return (cell.y + board_half_cells) * board_cells + (cell.x + board_half_cells)


## Unlike the terrain, a water cell's geometry is its own: the surface is a flat
## quad at one level, so a change never moves a neighbour's vertex.
func _touch(cell: Vector2i) -> void:
	_revision += 1


func _touch_index(index: int) -> void:
	if board_cells <= 0:
		return
	_touch(Vector2i(
		index % board_cells - board_half_cells,
		index / board_cells - board_half_cells,
	))


# --- Body cell index ----------------------------------------------------------

## The cells that belong to a body, in row-major order. O(cells_in_body) thanks
## to the `_body_cells` index; the sort is deterministic (§4.4).
func cells_of_body(body_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _body_cells.has(body_id):
		return result
	for cell: Vector2i in _body_cells[body_id]:
		result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return result


func _index_add(body_id: int, cell: Vector2i) -> void:
	if body_id == WaterBody.NO_BODY:
		return
	if not _body_cells.has(body_id):
		_body_cells[body_id] = {}
	(_body_cells[body_id] as Dictionary)[cell] = true


func _index_remove(body_id: int, cell: Vector2i) -> void:
	if body_id == WaterBody.NO_BODY:
		return
	if _body_cells.has(body_id):
		(_body_cells[body_id] as Dictionary).erase(cell)
