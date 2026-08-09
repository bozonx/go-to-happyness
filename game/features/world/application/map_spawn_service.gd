class_name MapSpawnService
extends RefCounted

## Resolves where a unit appears on the map (active_zones.md §15).
##
## Spawn is authored as a `spawn`-role anchor, and a spawn group (`map_start.md`
## §4.3) is what the runtime looks up: `plan_party` lays out a whole party at
## once, in the author's order, and a member that does not fit refuses the
## *launch* rather than the placement.
##
## There used to be a second entry point here — `claim`, "one free place among
## these addresses", the §15 operation for waves, respawns and drop zones — plus
## `spawn_positions` and the occupancy ledger both needed. Nothing in the game
## ever called them: no rule engine exists to ask, and the two readers rotted
## quietly (the passability check inside them was dead for want of a configured
## nav grid). They come back with their first caller, from a design that knows
## what that caller needs, rather than being maintained as a guess.
##
## What used to be here — `hero_spawn_position` and `companion_spawn_positions`,
## read one anchor per party member — is gone. That pair is what made the map's
## geometry own the party size (`map_start.md` §5.3): a map with three companion
## anchors capped the game at four settlers and rejected any other number.
##
## **Coordinates.** Zone geometry is authored in board cells (`active_zones.md`
## §6): `pos.x/z` are cell coordinates with a `.5` centre offset and `pos.y` is
## the terrain *level*, not a height in metres. Conversion to world space happens
## here, on the runtime boundary (§9), exactly once — which is why every reader
## takes `cell_size`. Callers still clamp Y onto the live terrain themselves; the
## authored level says which terrace the author meant, not where the mesh ended
## up after the last edit.

## Party appearance functions (`map_start.md` §4.1). A `spawn` anchor's role stays
## geometric and its meaning is a function, so a pack adds its own kind of
## appearance without the closed role list growing an entry.
const PARTY_LEADER := &"core:party_leader"
const PARTY_SLOT := &"core:party_slot"
## Where the first frame looks from. Deliberately a `poi` and not a `spawn`: the
## validator demands dry passable ground of every role a unit stands on, and a
## good establishing camera stands over water, over a cliff or past the rim of the
## board (§4.1) — which is exactly the exemption `poi` buys it.
const CAMERA_START := &"core:camera_start"

## v7 names, read for one release (§16). They are resolved on load by
## `MapFormatMigration`; this table exists so a document held in memory from an
## older session, or a pack that still ships the old string, is not silently
## ignored by the readers below.
const FUNCTION_ALIASES: Dictionary = {
	&"core:hero_start": PARTY_LEADER,
	&"core:companion_start": PARTY_SLOT,
}


## The current name of an authored function.
static func canonical_function(function: StringName) -> StringName:
	return FUNCTION_ALIASES.get(function, function)


## What makes a cell standable. All three are optional because a headless
## placement test has none of them; a caller that *has* them and does not pass
## them is the bug this pair of fields replaced — the nav grid was never once
## configured, so every passability check in this file silently passed.
var _nav_grid: NavGrid = null
var _terrain: TerrainGrid = null
var _water: WaterGrid = null


## Ground sources for placement. `terrain`/`water` answer "is this real dry
## ground inside the board", which the editor can ask of a document alone;
## `nav_grid` adds cliffs and obstacles and exists only where the world is built.
func configure(nav_grid: NavGrid, terrain: TerrainGrid = null, water: WaterGrid = null) -> void:
	_nav_grid = nav_grid
	_terrain = terrain
	_water = water


## The anchor carrying a function, or null. Alias-aware, so a document that still
## holds `core:hero_start` in memory answers the same as a migrated one.
func anchor_with_function(zones: MapZoneLayer, function: StringName) -> ZoneAnchorRecord:
	for anchor in zones.anchors:
		if canonical_function(anchor.function) == function:
			return anchor
	return null


## Where the first frame looks from, or `Vector3.INF` when the entrance names no
## camera. Passability is deliberately not checked (§4.1).
func camera_position(zones: MapZoneLayer, camera_id: StringName, cell_size := 1.0) -> Vector3:
	var anchor := zones.anchor_by_id(camera_id)
	if anchor == null or canonical_function(anchor.function) != CAMERA_START:
		return Vector3.INF
	return world_position_of(anchor, cell_size)


## Board cells → world space. The one place the conversion lives (§9).
static func world_position_of(anchor: ZoneAnchorRecord, cell_size := 1.0) -> Vector3:
	return Vector3(anchor.pos.x * cell_size, anchor.pos.y * TerrainGrid.HEIGHT_STEP, anchor.pos.z * cell_size)


static func cell_to_world(cell: Vector2i, level: float, cell_size := 1.0) -> Vector3:
	return Vector3(
		(float(cell.x) + 0.5) * cell_size,
		level * TerrainGrid.HEIGHT_STEP,
		(float(cell.y) + 0.5) * cell_size)


## --- Party placement (`map_start.md` §4.3) -------------------------------------

## Where one member of the party ends up: a world position and the bearing the
## author gave the place it came from.
class PartyPlacement:
	extends RefCounted

	var position := Vector3.INF
	var facing := 0.0
	## Slot id, or the group id when the member was grown into the formation.
	var address: StringName = &""


## Outcome of laying out a party of `count` in a group. A refusal names the group
## and how many did not fit, because "the map needs 7 companion anchors" was
## exactly the message that told an author nothing about which clearing was small.
class PartyPlan:
	extends RefCounted

	var ok := false
	var placements: Array[PartyPlacement] = []
	var reason := ""


## Lays out `count` members in `group`, leader first (§4.3):
##
## 1. the leader takes the slot tagged `leader`, or the centre of the area;
## 2. remaining members take free slots in `order`;
## 3. anyone left over is grown into the formation, or refused, per `fallback`;
## 4. every position is checked for passability, rights and occupancy;
## 5. a party that does not fit **blocks the launch** — quietly shrinking it would
##    hand the player fewer settlers than they chose and call that success.
func plan_party(
	zones: MapZoneLayer,
	group: MapSpawnGroup,
	count: int,
	cell_size := 1.0,
	agent_tags: Array[StringName] = [],
) -> PartyPlan:
	var plan := PartyPlan.new()
	if group == null:
		plan.reason = "вариант старта не называет группу появления"
		return plan
	if not group.admits(agent_tags):
		plan.reason = "группа %s не принимает этот отряд" % group.id
		return plan
	if count <= 0:
		plan.ok = true
		return plan
	if count > group.capacity:
		plan.reason = "группа %s рассчитана на %d, а отряд из %d" % [group.id, group.capacity, count]
		return plan
	var tags: Array[StringName] = agent_tags.duplicate()
	if tags.is_empty():
		tags.append(ZoneAccess.AUDIENCE_VISITOR)
	var area := zones.area_by_id(group.area_id) if group.area_id != &"" else null
	var taken: Dictionary = {}

	var leader_slot := group.slot_with_tag(MapSpawnGroup.TAG_LEADER)
	if leader_slot != null:
		var leader := _placement_at_slot(zones, group, leader_slot, cell_size, tags, taken)
		if leader == null:
			# A refusal, not a shuffle. Silently letting the next slot become
			# `placements[0]` put the hero on a companion's place and gave the whole
			# party that place's bearing — a group that reads as authored and is not.
			plan.reason = "место лидера в группе %s занято или непроходимо" % group.id
			return plan
		plan.placements.append(leader)
	for slot in group.ordered_slots():
		if plan.placements.size() >= count:
			break
		if leader_slot != null and slot.id == leader_slot.id:
			continue
		var placement := _placement_at_slot(zones, group, slot, cell_size, tags, taken)
		if placement != null:
			plan.placements.append(placement)
	if plan.placements.size() >= count:
		plan.ok = true
		plan.placements.resize(count)
		return plan

	var missing := count - plan.placements.size()
	if group.fallback == MapSpawnGroup.FALLBACK_FAIL:
		plan.reason = "в группе %s не хватает %d мест" % [group.id, missing]
		return plan
	var origin := _group_origin(zones, group, area, plan.placements, cell_size)
	if origin == Vector3.INF:
		plan.reason = "группе %s негде разместить ещё %d участников" % [group.id, missing]
		return plan
	for offset: Vector2 in _formation_offsets(group, missing + plan.placements.size()):
		if plan.placements.size() >= count:
			break
		var candidate := origin + Vector3(offset.x, 0.0, offset.y)
		var cell := Vector2i(floori(candidate.x / cell_size), floori(candidate.z / cell_size))
		if taken.has(cell) or not _cell_is_free(zones, cell, tags):
			continue
		if area != null and not area.contains_cell(cell):
			continue
		taken[cell] = true
		var placement := PartyPlacement.new()
		placement.position = candidate
		placement.facing = group.facing
		placement.address = group.id
		plan.placements.append(placement)
	if plan.placements.size() < count:
		plan.reason = "в группе %s не помещаются %d участников" % [
			group.id, count - plan.placements.size()]
		return plan
	plan.ok = true
	return plan


func _placement_at_slot(
	zones: MapZoneLayer,
	group: MapSpawnGroup,
	slot: MapSpawnGroup.Slot,
	cell_size: float,
	tags: Array[StringName],
	taken: Dictionary,
) -> PartyPlacement:
	var anchor := zones.anchor_by_id(slot.anchor_id)
	if anchor == null:
		return null
	var cell := anchor.cell()
	if taken.has(cell) or not _cell_is_free(zones, cell, tags):
		return null
	taken[cell] = true
	var placement := PartyPlacement.new()
	placement.position = world_position_of(anchor, cell_size)
	placement.facing = anchor.facing if not is_zero_approx(anchor.facing) else group.facing
	placement.address = slot.id
	return placement


## Where the formation grows from: the area's centre when there is one, otherwise
## the first authored place. A group with neither is refused by the layer's
## validation, so `INF` here only happens on a document nobody validated.
func _group_origin(
	zones: MapZoneLayer,
	group: MapSpawnGroup,
	area: ZoneAreaRecord,
	placed: Array[PartyPlacement],
	cell_size: float,
) -> Vector3:
	if area != null:
		# `centroid` answers in board cells at the area's lowest level, the same
		# space every other authored coordinate uses; world conversion happens here,
		# on the runtime boundary, exactly like `world_position_of`.
		var centre := area.centroid()
		if centre != Vector3.INF:
			return Vector3(centre.x * cell_size, centre.y * TerrainGrid.HEIGHT_STEP, centre.z * cell_size)
	if not placed.is_empty():
		return placed[0].position
	if not group.slots.is_empty():
		var anchor := zones.anchor_by_id(group.slots[0].anchor_id)
		if anchor != null:
			return world_position_of(anchor, cell_size)
	return Vector3.INF


## Offsets from the origin, in metres, in the order they should be tried. `loose`
## walks rings of eight at multiples of `spacing`; `line` walks a single row
## alternating sides so the group stays centred on the origin.
func _formation_offsets(group: MapSpawnGroup, needed: int) -> Array[Vector2]:
	var spacing := maxf(group.spacing, 0.5)
	var offsets: Array[Vector2] = []
	if group.formation == MapSpawnGroup.FORMATION_LINE:
		var direction := Vector2(cos(deg_to_rad(group.facing + 90.0)), sin(deg_to_rad(group.facing + 90.0)))
		for index in range(needed * 2 + 1):
			var step := float((index + 1) / 2) * spacing * (1.0 if index % 2 == 0 else -1.0)
			offsets.append(direction * step)
		return offsets
	const RING: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	]
	# Two laps beyond what is needed: cells inside the rings are refused by water,
	# rights and occupancy, and a party that cannot fit must be told so rather than
	# be silently truncated by a candidate list that ran out.
	var laps := needed / RING.size() + 3
	for lap in range(1, laps + 1):
		for offset: Vector2i in RING:
			offsets.append(Vector2(float(offset.x), float(offset.y)) * spacing * float(lap))
	return offsets


## Can a unit with these audiences stand on this cell — the same test the party
## layout applies, exposed for a caller that lays a party out itself (the
## editor's "test from here", `map_start.md` §4.5). Cells are board cells.
func cell_is_standable(
	zones: MapZoneLayer, cell: Vector2i, agent_tags: Array[StringName] = [],
) -> bool:
	var tags: Array[StringName] = agent_tags.duplicate()
	if tags.is_empty():
		tags.append(ZoneAccess.AUDIENCE_VISITOR)
	return _cell_is_free(zones, cell, tags)


## Ground plus rights. Rights are read off the overlays directly rather than
## through `ZoneOverlayIndex`: spawning happens a handful of times per session,
## and the exact §4.1 rule — any matching audience denies — is worth more here
## than an O(1) lookup that only knows about visitors.
func _cell_is_free(zones: MapZoneLayer, cell: Vector2i, tags: Array[StringName]) -> bool:
	if not _cell_is_ground(cell):
		return false
	for area in zones.areas:
		if not area.is_overlay() or not area.contains_cell(cell):
			continue
		if not ZoneAccess.permits_tags(area.allow, area.deny, tags):
			return false
	return true


## Real, dry, standable ground inside the board — the same rule `MapValidator`
## applies to an authored spawn anchor, applied here to every cell a party
## actually lands on. The grown cells of a formation and the cells of a region
## are not authored anywhere, so this is the only place that can check them.
##
## **Outside the board is not free.** It read as free while the only check was
## `is_board_cell(cell) and not is_walkable(cell)`, which is how a group with no
## clearing grew its formation off the rim of the map.
func _cell_is_ground(cell: Vector2i) -> bool:
	if _terrain != null:
		if not _terrain.is_inside(cell) or _terrain.is_hole(cell):
			return false
		if _water != null and _water.is_wet(_terrain, cell):
			if _water.is_lava(cell):
				return false
			# Frozen water is walkable (ice); open water deeper than a ford is not.
			if not _water.is_frozen(cell) \
					and _water.depth_steps_at(_terrain, cell) > WaterGrid.FORD_MAX_DEPTH_STEPS:
				return false
	if _nav_grid != null and (not _nav_grid.is_board_cell(cell) or not _nav_grid.is_walkable(cell)):
		return false
	return true
