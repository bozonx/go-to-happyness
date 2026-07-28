class_name MapSpawnService
extends RefCounted

## Resolves where a unit appears on the map (active_zones.md §15).
##
## Spawn is authored as `spawn`-role anchors on the map's zone layer. The engine
## gives one operation — "the positions a unit may appear at" — and decides
## nothing about what appears, how often, or why: those are rules, which do not
## exist yet. What this service does is read the authored anchors and return
## them in a stable order, so the citizen factory can stop hardcoding a cell and
## a settlement editor demo can place a hero where the author drew them.
##
## Functions are the stable launch contract.  A generic `spawn` is deliberately
## not silently reused for the hero or a companion: maps must say which member of
## the starting party belongs there.  Tags remain a future selection dimension.

const HERO_START := &"core:hero_start"
const COMPANION_START := &"core:companion_start"


## Positions of every `spawn` anchor on the layer, in authoring order. The
## caller applies terrain-height clamping itself, keeping this pure-data service
## independent from the terrain grid.
func spawn_positions(zones: MapZoneLayer) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for anchor in zones.anchors:
		if anchor.is_spawn():
			positions.append(anchor.pos)
	return positions


## The authored hero position, or `Vector3.INF` when the map is incomplete.
func hero_spawn_position(zones: MapZoneLayer) -> Vector3:
	for anchor in zones.anchors:
		if anchor.is_spawn() and anchor.function == HERO_START:
			return anchor.pos
	return Vector3.INF


## Companion starts in authoring order.  Their identity is their index; that is
## sufficient until party definitions become authored content of their own.
func companion_spawn_positions(zones: MapZoneLayer) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for anchor in zones.anchors:
		if anchor.is_spawn() and anchor.function == COMPANION_START:
			positions.append(anchor.pos)
	return positions
