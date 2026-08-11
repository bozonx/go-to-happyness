class_name EnvironmentAccumulationService
extends RefCounted

## Drives the two accumulations the world carries (`world_environment.md` §13).
##
## Lying snow belongs to `terrain_materials.md` §6.2 and ice to `water.md` §4 —
## each is stored in its own layer and edited through its own service, and this
## file owns neither. What it owns is the **command**: the single answer to "is it
## winter" comes from the environment, so the surface and the water never form
## their own.
##
## Three rules hold the whole thing together:
##
## 1. **The cursor catches up.** A skipped night or a scripted jump must apply the
##    accumulation for the interval it passed over in one step, not pretend it did
##    not happen. That is what accumulation pays for not being a function (§3).
## 2. **Accumulations are saved, weather is not.** Snow depth, ice thickness and
##    the seed live in the save; cloud and wind are recomputed from time (§16).
## 3. **Only the environment decides it is winter.**

## Cells swept per tick. One chunk of columns is enough to cover a 256×256 board
## in a couple of game hours, which is the pace snow visibly creeps at, and it
## keeps the per-frame cost flat regardless of board size.
const CELLS_PER_TICK := TerrainGrid.CHUNK_CELLS * TerrainGrid.CHUNK_CELLS
## Game minutes of snowfall a single depth step costs at full intensity.
const MINUTES_PER_SNOW_STEP := 90.0
## Game minutes of thaw a single depth step costs, at one degree above freezing.
const MINUTES_PER_MELT_STEP := 120.0
## Trodden ground loses its snow faster (§13).
const WEAR_MELT_FACTOR := 2.2
## Sun on bare snow does more than air temperature alone.
const SUNLIT_MELT_FACTOR := 1.6
## Water freezes below this and thaws above it, with the gap keeping a lake from
## flickering between states across a single cold night.
const FREEZE_TEMPERATURE := -2.0
const THAW_TEMPERATURE := 1.5
const MINUTES_PER_ICE_STEP := 180.0
const MINUTES_PER_ICE_THAW_STEP := 120.0
## The longest stretch a catch-up will simulate. A save resumed after a very long
## jump settles to the same steady state as one resumed after this, so paying for
## more is paying for nothing.
const MAX_CATCH_UP_MINUTES := 3.0 * 24.0 * 60.0

var terrain_service: TerrainService = null
var water_service: WaterService = null
var terrain_grid: TerrainGrid = null
var water_grid: WaterGrid = null

## Where the sweep is, as a linear cell index into the board. Saved, so a reload
## does not restart the world's snow from one corner.
var cursor := 0
## Fractional depth carried between ticks, so a slow snowfall still accumulates
## instead of rounding away to nothing every frame.
var _snow_progress: Dictionary = {}
var _previous_minutes := -1.0
var _slice_last_minutes: Dictionary = {}
var _ice_progress: Dictionary = {}


func configure(
	p_terrain_service: TerrainService,
	p_water_service: WaterService,
	p_terrain_grid: TerrainGrid,
	p_water_grid: WaterGrid,
) -> void:
	terrain_service = p_terrain_service
	water_service = p_water_service
	terrain_grid = p_terrain_grid
	water_grid = p_water_grid
	cursor = 0
	_snow_progress.clear()
	_slice_last_minutes.clear()
	_ice_progress.clear()
	_previous_minutes = -1.0


## Called once per frame with the environment as it is now. Advancing by the
## snapshot's own clock rather than by real seconds is what makes this survive a
## change of time scale for free.
func tick(snapshot: EnvironmentSnapshot) -> void:
	if terrain_grid == null:
		return
	var elapsed := 0.0
	if _previous_minutes >= 0.0:
		elapsed = maxf(snapshot.elapsed_minutes - _previous_minutes, 0.0)
	else:
		_seed_slice_times(snapshot.elapsed_minutes)
	_previous_minutes = snapshot.elapsed_minutes
	if elapsed <= 0.0:
		return
	# Ice is body-wide, so it advances once for the real interval. The snow cursor
	# below deliberately revisits slices at different rates; using that slice's
	# elapsed time for every body used to multiply freezing by the chunk count.
	_update_ice(snapshot, elapsed)
	var slice_start := cursor
	var slice_elapsed := maxf(snapshot.elapsed_minutes - float(_slice_last_minutes.get(slice_start, snapshot.elapsed_minutes - elapsed)), 0.0)
	_slice_last_minutes[slice_start] = snapshot.elapsed_minutes
	_advance(snapshot, slice_elapsed, false, false)


## Applies an interval that was skipped rather than lived — a skipped night, a
## scripted jump, a save resumed. Rule 1: the world must look like the time
## passed, because the player will walk out into it.
func catch_up(snapshot: EnvironmentSnapshot, skipped_minutes: float) -> void:
	if terrain_grid == null or skipped_minutes <= 0.0:
		return
	_previous_minutes = snapshot.elapsed_minutes
	_advance(snapshot, minf(skipped_minutes, MAX_CATCH_UP_MINUTES), true)
	_seed_slice_times(snapshot.elapsed_minutes)


func catch_up_samples(samples: Array[Dictionary], final_snapshot: EnvironmentSnapshot) -> void:
	if terrain_grid == null or samples.is_empty():
		return
	var total := 0.0
	for sample: Dictionary in samples:
		var minutes := float(sample.get("minutes", 0.0))
		var value: Variant = sample.get("snapshot", null)
		if value is EnvironmentSnapshot and minutes > 0.0:
			_advance(value as EnvironmentSnapshot, minutes, true)
			total += minutes
			if total >= MAX_CATCH_UP_MINUTES:
				break
	_previous_minutes = final_snapshot.elapsed_minutes
	_seed_slice_times(final_snapshot.elapsed_minutes)


func save_state() -> Dictionary:
	return {"cursor": cursor, "snow_progress": _snow_progress.duplicate(true), "ice_progress": _ice_progress.duplicate(true)}


func restore_state(state: Dictionary) -> void:
	cursor = int(state.get("cursor", 0))
	_snow_progress.clear()
	var saved_snow: Variant = state.get("snow_progress", {})
	if saved_snow is Dictionary:
		for key: Variant in saved_snow:
			_snow_progress[int(key)] = float(saved_snow[key])
	_ice_progress.clear()
	var saved_ice: Variant = state.get("ice_progress", {})
	if saved_ice is Dictionary:
		for key: Variant in saved_ice:
			_ice_progress[int(key)] = float(saved_ice[key])
	_slice_last_minutes.clear()
	_previous_minutes = -1.0


func _advance(
	snapshot: EnvironmentSnapshot,
	minutes: float,
	whole_board := false,
	advance_ice := true,
) -> void:
	if advance_ice:
		_update_ice(snapshot, minutes)
	var cells := _next_cells(whole_board)
	if cells.is_empty():
		return
	var deepen: Dictionary = {}
	for cell: Vector2i in cells:
		var target := _target_depth_change(snapshot, cell, minutes)
		if target == 0:
			continue
		var depth := clampi(terrain_grid.snow_depth_at(cell) + target, 0, TerrainDetailCodec.MAX_SNOW_DEPTH)
		if depth == terrain_grid.snow_depth_at(cell):
			continue
		if not deepen.has(depth):
			deepen[depth] = [] as Array[Vector2i]
		deepen[depth].append(cell)
	if terrain_service == null:
		return
	# Grouped by resulting depth so one sweep costs at most four commits rather
	# than one per cell — the publisher republishes navigation on every commit.
	for depth: int in deepen:
		terrain_service.set_snow_depth(deepen[depth], depth)


## Which way this column's snow is going, in depth steps. Positive while it
## snows, negative while it thaws, zero when neither has accumulated enough of a
## fraction yet.
func _target_depth_change(snapshot: EnvironmentSnapshot, cell: Vector2i, minutes: float) -> int:
	var key := _key_of(cell)
	var progress := float(_snow_progress.get(key, 0.0))
	if snapshot.is_snowing() and _snow_can_rest_on(cell):
		progress += minutes * snapshot.precipitation_intensity / MINUTES_PER_SNOW_STEP
	elif terrain_grid.snow_depth_at(cell) > 0:
		var above_freezing := maxf(snapshot.temperature_at(_column_position(cell)), 0.0)
		if above_freezing > 0.0:
			var rate := above_freezing / MINUTES_PER_MELT_STEP
			# Trodden ground and direct sun both thaw faster, which is what makes
			# paths appear through a snowfield instead of it lifting uniformly.
			if terrain_grid.wear_at(cell) > 0:
				rate *= WEAR_MELT_FACTOR
			if snapshot.solar_height > 0.15 and snapshot.cloud_cover < 0.6:
				rate *= SUNLIT_MELT_FACTOR
			progress -= minutes * rate
	if absf(progress) < 1.0:
		_snow_progress[key] = progress
		return 0
	var steps := int(progress)
	_snow_progress[key] = progress - float(steps)
	return steps


## Open water has no ground surface for snow. Frozen water does — an ice sheet is
## a floor — and snow on a frozen lake is normal, so it is deliberately eligible.
func _snow_can_rest_on(cell: Vector2i) -> bool:
	return SnowRestRule.can_rest(terrain_grid, water_grid, cell)


## Freezing and thawing are an ordinary `WaterService` transaction, per body and
## by the body's own `freezes` flag — a lava lake and a fast current stay open
## whatever the temperature (§13).
func _update_ice(snapshot: EnvironmentSnapshot, minutes: float) -> void:
	if water_service == null or water_grid == null:
		return
	var freezing := snapshot.temperature <= FREEZE_TEMPERATURE
	var thawing := snapshot.temperature >= THAW_TEMPERATURE
	if not freezing and not thawing:
		return
	for body: WaterBody in water_grid.bodies():
		var cells := water_service.cells_of_body(body.id)
		if cells.is_empty():
			continue
		var thickness := water_grid.ice_thickness_at(cells[0])
		var progress := float(_ice_progress.get(body.id, 0.0))
		if freezing and body.freezes:
			progress += minutes * maxf(-snapshot.temperature / 2.0, 1.0) / MINUTES_PER_ICE_STEP
		elif thawing and thickness > 0:
			progress -= minutes * maxf(snapshot.temperature / THAW_TEMPERATURE, 1.0) / MINUTES_PER_ICE_THAW_STEP
		if absf(progress) < 1.0:
			_ice_progress[body.id] = progress
			continue
		var steps := int(progress)
		var next_thickness := clampi(thickness + steps, 0, WaterGrid.MAX_ICE_THICKNESS)
		_ice_progress[body.id] = progress - float(steps)
		if next_thickness != thickness:
			water_service.set_body_frozen(body.id, next_thickness > 0, next_thickness)


## The next slice of the board, advancing the cursor. A catch-up takes the whole
## board in one step instead: a night that has already passed does not get to
## leave three quarters of the map bare.
func _next_cells(whole_board: bool) -> Array[Vector2i]:
	var minimum := terrain_grid.min_cell()
	var side := terrain_grid.board_cells
	var total := side * side
	if total <= 0:
		return []
	var cells: Array[Vector2i] = []
	var count := total if whole_board else mini(CELLS_PER_TICK, total)
	var start := 0 if whole_board else cursor
	for offset in range(count):
		var index := posmod(start + offset, total)
		cells.append(Vector2i(minimum.x + index % side, minimum.y + index / side))
	if not whole_board:
		cursor = posmod(cursor + count, total)
	return cells


func _column_position(cell: Vector2i) -> Vector3:
	return Vector3(0.0, float(terrain_grid.height_of(cell)), 0.0)


func _key_of(cell: Vector2i) -> int:
	return cell.x * 100003 + cell.y


func _seed_slice_times(elapsed_minutes: float) -> void:
	_slice_last_minutes.clear()
	if terrain_grid == null:
		return
	var total := terrain_grid.board_cells * terrain_grid.board_cells
	var start := 0
	while start < total:
		_slice_last_minutes[start] = elapsed_minutes
		start += CELLS_PER_TICK
