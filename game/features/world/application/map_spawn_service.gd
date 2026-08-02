class_name MapSpawnService
extends RefCounted

## Resolves where a unit appears on the map (active_zones.md §15).
##
## Spawn is authored either as a `spawn`-role anchor or as a `region` whose pack
## function declares it an appearance area. The engine gives **one** operation —
## "give me a free place among these addresses" — and decides nothing about what
## appears, how often, or why: those are rules.
##
## Two levels of API, and the difference matters:
##
## * `hero_spawn_position` / `companion_spawn_positions` read the authored party
##   starts one-to-one. A starting party is authored per member, so there is no
##   contention to resolve and no reason to make launch depend on a navigation
##   field that may not be published yet.
## * `claim` is the §15 operation: it filters candidates by passability, access
##   rights and occupancy and hands out a place, remembering that it did. A wave,
##   a respawn or a drop zone goes through this one.
##
## **Coordinates.** Zone geometry is authored in board cells (`active_zones.md`
## §6): `pos.x/z` are cell coordinates with a `.5` centre offset and `pos.y` is
## the terrain *level*, not a height in metres. Conversion to world space happens
## here, on the runtime boundary (§9), exactly once — which is why every reader
## takes `cell_size`. Callers still clamp Y onto the live terrain themselves; the
## authored level says which terrace the author meant, not where the mesh ended
## up after the last edit.

const HERO_START := &"core:hero_start"
const COMPANION_START := &"core:companion_start"


## Outcome of a §15 placement request: a world position, or a refusal that says
## why. A refusal is a normal answer — a full drop zone is not an error — so it
## carries a reason instead of pushing one.
class SpawnPlacement:
	extends RefCounted

	var ok := false
	var position := Vector3.INF
	## Address the place came from: an anchor id, or the region id it was picked
	## inside. Callers hold this to release the claim later.
	var address: StringName = &""
	var reason := ""

	static func granted(at: Vector3, from: StringName) -> SpawnPlacement:
		var placement := SpawnPlacement.new()
		placement.ok = true
		placement.position = at
		placement.address = from
		return placement

	static func refused(why: String) -> SpawnPlacement:
		var placement := SpawnPlacement.new()
		placement.reason = why
		return placement


## Passability source; null means "do not check", which is what a headless
## placement test and an early bootstrap both want.
var _nav_grid: NavGrid = null
## Addresses handed out and not yet released, so two units never land on one
## authored point. Keyed by address; a region address counts one claim per cell.
var _claimed: Dictionary = {}


func configure(nav_grid: NavGrid) -> void:
	_nav_grid = nav_grid


func release(address: StringName) -> void:
	_claimed.erase(address)


func release_all() -> void:
	_claimed.clear()


## World positions of every `spawn` anchor on the layer, in authoring order.
func spawn_positions(zones: MapZoneLayer, cell_size := 1.0) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for anchor in zones.anchors:
		if anchor.is_spawn():
			positions.append(world_position_of(anchor, cell_size))
	return positions


## The authored hero position, or `Vector3.INF` when the map is incomplete.
func hero_spawn_position(zones: MapZoneLayer, cell_size := 1.0) -> Vector3:
	for anchor in zones.anchors:
		if anchor.is_spawn() and anchor.function == HERO_START:
			return world_position_of(anchor, cell_size)
	return Vector3.INF


## The authored hero facing in degrees, or 0 when there is no hero start. A spawn
## point says which way the unit looks; ignoring it left every authored hero
## facing north regardless of what the author drew.
func hero_spawn_facing(zones: MapZoneLayer) -> float:
	for anchor in zones.anchors:
		if anchor.is_spawn() and anchor.function == HERO_START:
			return anchor.facing
	return 0.0


## Companion starts in authoring order. Their identity is their index; that is
## sufficient until party definitions become authored content of their own.
func companion_spawn_positions(zones: MapZoneLayer, cell_size := 1.0) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for anchor in zones.anchors:
		if anchor.is_spawn() and anchor.function == COMPANION_START:
			positions.append(world_position_of(anchor, cell_size))
	return positions


## Board cells → world space. The one place the conversion lives (§9).
static func world_position_of(anchor: ZoneAnchorRecord, cell_size := 1.0) -> Vector3:
	return Vector3(anchor.pos.x * cell_size, anchor.pos.y * TerrainGrid.HEIGHT_STEP, anchor.pos.z * cell_size)


static func cell_to_world(cell: Vector2i, level: float, cell_size := 1.0) -> Vector3:
	return Vector3(
		(float(cell.x) + 0.5) * cell_size,
		level * TerrainGrid.HEIGHT_STEP,
		(float(cell.y) + 0.5) * cell_size)


## The §15 operation: a free place among the addresses carrying `function`,
## checked for passability, access rights and occupancy.
##
## Candidates are the authored `spawn` anchors with that function first, then the
## cells of every `region` whose function matches — an author who wants exact
## placement puts points down, an author who wants "somewhere in this clearing"
## draws an area, and neither needs a different call. `agent_tags` are the
## acting unit's audiences (§12); an empty set is treated as a plain visitor,
## which is the default every acting entity carries.
func claim(
	zones: MapZoneLayer,
	function: StringName,
	cell_size := 1.0,
	agent_tags: Array[StringName] = [],
) -> SpawnPlacement:
	var tags: Array[StringName] = agent_tags.duplicate()
	if tags.is_empty():
		tags.append(ZoneAccess.AUDIENCE_VISITOR)
	var refused_reason := "нет точек появления с функцией %s" % function
	for anchor in zones.anchors:
		if not anchor.is_spawn() or anchor.function != function:
			continue
		refused_reason = "все точки появления %s заняты или недоступны" % function
		if _claimed.has(anchor.id):
			continue
		if not _cell_is_free(zones, anchor.cell(), tags):
			continue
		_claimed[anchor.id] = true
		return SpawnPlacement.granted(world_position_of(anchor, cell_size), anchor.id)
	for area in zones.areas:
		if area.role != ZoneAreaRecord.ROLE_REGION or area.function != function:
			continue
		refused_reason = "все точки появления %s заняты или недоступны" % function
		for cell in area.footprint_cells():
			var address := StringName("%s@%d,%d" % [area.id, cell.x, cell.y])
			if _claimed.has(address):
				continue
			if not _cell_is_free(zones, cell, tags):
				continue
			_claimed[address] = true
			return SpawnPlacement.granted(cell_to_world(cell, float(area.y_min), cell_size), address)
	return SpawnPlacement.refused(refused_reason)


## Passability plus rights. Rights are read off the overlays directly rather than
## through `ZoneOverlayIndex`: spawning happens a handful of times per session,
## and the exact §4.1 rule — any matching audience denies — is worth more here
## than an O(1) lookup that only knows about visitors.
func _cell_is_free(zones: MapZoneLayer, cell: Vector2i, tags: Array[StringName]) -> bool:
	if _nav_grid != null and _nav_grid.is_board_cell(cell) and not _nav_grid.is_walkable(cell):
		return false
	for area in zones.areas:
		if not area.is_overlay() or not area.contains_cell(cell):
			continue
		if not ZoneAccess.permits_tags(area.allow, area.deny, tags):
			return false
	return true
