class_name WaterAccessService
extends RefCounted

## Where a citizen can reach drinkable water (grid_terrain_system.md §9.2).
##
## This replaces the old separate pond props; water is authored on the map.
## Those were a second water system: a decorative mesh, a hard-coded 5×5 blot
## written straight into `terrain_blocked_cells`, and a list of world positions
## that gameplay read — none of it known to `WaterGrid`, none of it known to the
## navigation field. Two owners of "is there water here" is the same mistake that
## got Terrain3D removed (§13), and it was quietly the load-bearing one: every
## `gather_water` job in the game came from the decoration.
##
## Now there is one owner. Water is wet cells belonging to a drinkable `WaterBody`,
## impassability comes from the published `NavTerrainField`, and this service
## answers the only question gameplay actually asks: **standing where can someone
## fill a bucket?**
##
## An access point is a dry, standable column orthogonally touching such a cell.
## The bank, never the water: a citizen sent to the middle of a lake either cannot
## route there or is wading, and neither is drawing water.
##
## The list is thinned. A pond yields two or three points, but a coastline yields
## one bank cell per metre of shore, and every consumer here loops the list and
## prices a route to each entry. `SPACING_CELLS` keeps the answer proportional to
## how much shore there is rather than to how many cells it is made of.

## One access point per this many cells of shore, in each axis. Eight metres is
## close enough that the nearest point is never a detour worth noticing, and
## coarse enough that a sea coast is tens of points and not thousands.
const SPACING_CELLS := 8

var water: WaterGrid = null
var terrain: TerrainGrid = null
## Used only to put an access point on the surface a citizen actually stands on.
## Optional: without it the points sit at the column height, which is right on
## flat ground and off by the corner lift on a slope.
var nav_grid: NavGrid = null

var _cached: Array[Vector3] = []
var _cached_water_revision := -1
var _cached_terrain_revision := -1


func configure(next_water: WaterGrid, next_terrain: TerrainGrid, next_nav_grid: NavGrid = null) -> void:
	water = next_water
	terrain = next_terrain
	nav_grid = next_nav_grid
	invalidate()


func invalidate() -> void:
	_cached_water_revision = -1
	_cached_terrain_revision = -1
	_cached.clear()


## Bank positions, recomputed only when a layer has actually moved. Both revisions
## matter: raising a lake bed drains it without the water layer being written at
## all (§9.1), and that removes access just as surely as erasing the water would.
func source_positions() -> Array[Vector3]:
	if water == null or terrain == null:
		return []
	if _cached_water_revision == water.revision() and _cached_terrain_revision == terrain.revision():
		return _cached
	_cached_water_revision = water.revision()
	_cached_terrain_revision = terrain.revision()
	_cached = _collect()
	return _cached


func has_source() -> bool:
	return not source_positions().is_empty()


## The nearest access point, or `Vector3.INF` when the map has no drinkable water
## a citizen could stand beside.
func nearest_source(from: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_distance := INF
	for position: Vector3 in source_positions():
		var distance := from.distance_squared_to(position)
		if distance < best_distance:
			best = position
			best_distance = distance
	return best


func _collect() -> Array[Vector3]:
	var chosen: Dictionary = {}
	var minimum := water.min_cell()
	var maximum := water.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, z)
			if not _is_bank_of_drinkable_water(cell):
				continue
			# First bank cell of its neighbourhood wins. Deterministic because the
			# scan is row-major, which is what keeps two machines agreeing about
			# where a citizen goes to drink.
			var bucket := Vector2i(floori(float(x) / SPACING_CELLS), floori(float(z) / SPACING_CELLS))
			if chosen.has(bucket):
				continue
			chosen[bucket] = cell
	var positions: Array[Vector3] = []
	for bucket: Vector2i in chosen:
		positions.append(_position_of(chosen[bucket]))
	return positions


## A column someone can stand on, next to water they can drink. Standable means
## dry: a ford is passable but a citizen standing in it is in the water, and a
## frozen cell is a floor over water they cannot reach through it.
func _is_bank_of_drinkable_water(cell: Vector2i) -> bool:
	if terrain.is_hole(cell) or water.is_wet(terrain, cell):
		return false
	for offset: Vector2i in WaterGrid.ORTHOGONAL_OFFSETS:
		var neighbour := cell + offset
		if not water.is_wet(terrain, neighbour) or water.is_frozen(neighbour):
			continue
		var body := water.body_at(neighbour)
		if body != null and body.is_drinkable():
			return true
	return false


func _position_of(cell: Vector2i) -> Vector3:
	if nav_grid != null and nav_grid.has_terrain_field():
		return nav_grid.cell_center(cell)
	return terrain.cell_center(cell)
