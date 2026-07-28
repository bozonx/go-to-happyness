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
## The engine never reads `function` or `tag` here (§2): a spawn anchor with
## `function: "core:hero_start"` and one with no function are the same to this
## service. Tag-based selection ("only the `red_team` spawn") waits for a tag
## issuer (§12); until then every spawn anchor is a candidate.


## Positions of every `spawn` anchor on the layer, in authoring order. The
## caller applies terrain-height clamping itself, the same way it does for the
## hardcoded entrance anchor today — keeping that responsibility here would
## couple this pure-data service to the terrain grid.
func spawn_positions(zones: MapZoneLayer) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for anchor in zones.anchors:
		if anchor.is_spawn():
			positions.append(anchor.pos)
	return positions


## The first spawn anchor, or `fallback` when the layer has none. A map with no
## authored spawns must behave like the no-map board did, so the citizen factory
## hands its current anchor here and gets it back unchanged when the layer is
## empty — one call site, one fallback rule.
func first_spawn_position(zones: MapZoneLayer, fallback: Vector3) -> Vector3:
	for anchor in zones.anchors:
		if anchor.is_spawn():
			return anchor.pos
	return fallback
