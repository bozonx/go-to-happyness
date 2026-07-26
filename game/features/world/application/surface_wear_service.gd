class_name SurfaceWearService
extends RefCounted

## Ground wears where people walk (design_docs/core/terrain_materials.md §6.1).
##
## Citizens crossing a cell edge raise its `wear`; cells nobody visits for a while
## grow back. Wear changes the look everywhere and the traversal weight only where
## the material declared it does — `grass_tall` today, which goes from 2.0 to 1.0
## as it is flattened into a path.
##
## Two rules keep this from becoming a per-frame terrain rewrite:
##
## * **One increment per cell per simulation tick.** Crossings are accumulated and
##   flushed; without the throttle a crowd tramples a whole meadow in one frame,
##   because every one of them reports on every step.
## * **Everything goes through `TerrainService`.** Wear is column state and lands
##   in the undo delta like any other edit (parent §4.4). A wear pass writing
##   straight into the grid would be a change undo cannot see — and, worse, one
##   the navigation publisher would never hear about.
##
## This is deliberately the SAME counter as the trail treading of
## `navigation_and_roads.md`, not a second one: two independent "how trodden is
## this" numbers are a guaranteed drift between the visible path and the routed
## one. `TrailFieldService` owns the pedestrian weight override; this owns the
## surface state, and they read the same crossings.

## Crossings of one cell needed to raise its wear by one level. Wear is a slow,
## visible story of where people actually go, not a reaction to a single walker.
const CROSSINGS_PER_WEAR_LEVEL := 12

signal wear_changed(cells: Array[Vector2i])

var service: TerrainService = null
var grid: TerrainGrid = null

## cell -> crossings counted since the last flush.
var _pending: Dictionary = {}
## cell -> the tick it was last counted on, so a cell gains at most one crossing
## per tick however many bodies stand on it.
var _last_tick: Dictionary = {}
## cell -> crossings accumulated towards the next wear level.
var _progress: Dictionary = {}
## cell -> the day it was last walked on, for the recovery pass.
var _last_visit_day: Dictionary = {}
var _tick := 0


func configure(next_service: TerrainService) -> void:
	service = next_service
	grid = null if next_service == null else next_service.get_grid()
	_pending.clear()
	_last_tick.clear()
	_progress.clear()
	_last_visit_day.clear()
	_tick = 0


## One simulation tick has passed. Anything reporting crossings should do so
## against the current tick; the counter is what makes the throttle work.
func begin_tick() -> void:
	_tick += 1


## A body crossed into this cell. Counted at most once per cell per tick.
func record_crossing(cell: Vector2i) -> void:
	if grid == null or not grid.is_inside(cell):
		return
	if int(_last_tick.get(cell, -1)) == _tick:
		return
	_last_tick[cell] = _tick
	_pending[cell] = int(_pending.get(cell, 0)) + 1


## Turns accumulated crossings into wear levels, as one transaction. Returns the
## cells whose wear actually changed — usually none, which is the point.
func flush(day: int = 0) -> Array[Vector2i]:
	var raised: Array[Vector2i] = []
	if service == null or grid == null or _pending.is_empty():
		_pending.clear()
		return raised
	var by_level: Dictionary = {}
	for cell: Vector2i in _pending:
		_last_visit_day[cell] = day
		var progress := int(_progress.get(cell, 0)) + int(_pending[cell])
		var levels := progress / CROSSINGS_PER_WEAR_LEVEL
		_progress[cell] = progress % CROSSINGS_PER_WEAR_LEVEL
		if levels <= 0:
			continue
		var target := mini(grid.wear_at(cell) + levels, TerrainDetailCodec.MAX_WEAR)
		if target == grid.wear_at(cell):
			continue
		var cells: Array[Vector2i] = by_level.get(target, [] as Array[Vector2i])
		cells.append(cell)
		by_level[target] = cells
		raised.append(cell)
	_pending.clear()
	for level: int in by_level:
		service.set_wear(by_level[level], level)
	if not raised.is_empty():
		wear_changed.emit(raised)
	return raised


## Recovery (§6.1): a cell nobody has visited for the material's recovery period
## drops one wear level. Grass comes back, rock never does — `wear_recovery_days`
## of 0 says so, rather than a special case per material here.
##
## Called once per simulated day, after `flush`.
func recover(day: int) -> Array[Vector2i]:
	var healed: Array[Vector2i] = []
	if service == null or grid == null:
		return healed
	var by_level: Dictionary = {}
	for cell: Vector2i in _last_visit_day.keys():
		var wear := grid.wear_at(cell)
		if wear <= 0:
			_last_visit_day.erase(cell)
			continue
		var recovery_days := TerrainMaterialCatalog.wear_recovery_days(grid.material_index_at(cell))
		if recovery_days <= 0:
			continue
		if day - int(_last_visit_day[cell]) < recovery_days:
			continue
		# Snow melts faster on trodden ground and trodden ground recovers slower
		# under it; until the snow service exists, deep snow simply pauses regrowth
		# rather than pretending grass grows through it.
		if grid.snow_depth_at(cell) > 0:
			continue
		var target := wear - 1
		var cells: Array[Vector2i] = by_level.get(target, [] as Array[Vector2i])
		cells.append(cell)
		by_level[target] = cells
		healed.append(cell)
		_last_visit_day[cell] = day
		_progress[cell] = 0
	for level: int in by_level:
		service.set_wear(by_level[level], level)
	if not healed.is_empty():
		wear_changed.emit(healed)
	return healed


## Crossings counted towards the next wear level of a cell — the number the lab
## HUD shows so "why is this not a path yet" has an answer.
func progress_at(cell: Vector2i) -> int:
	return int(_progress.get(cell, 0)) + int(_pending.get(cell, 0))
