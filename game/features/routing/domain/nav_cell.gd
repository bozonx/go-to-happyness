class_name NavCell
extends RefCounted

## Encapsulated identity of one navigable place (grid_terrain_system.md §10.3).
##
## Today every navigable place is a ground column and the level is always
## `GROUND`. Tunnels (§6), bridges and building floors will put several walkable
## surfaces over the same map cell, and then `Vector2i` stops being a key at all.
## Routing therefore never indexes its topology with a bare map coordinate: it
## goes through this class, so that day changes `NavGrid`'s storage instead of
## every caller that reads it.
##
## The key itself is a `Vector3i` (x, z, level), not an object. It is a value
## type, so it hashes and compares by content and allocates nothing in the A*
## inner loop — an object key would cost one allocation per expanded node.

const GROUND := 0


static func of(cell: Vector2i, level: int = GROUND) -> Vector3i:
	return Vector3i(cell.x, cell.y, level)


static func ground(cell: Vector2i) -> Vector3i:
	return Vector3i(cell.x, cell.y, GROUND)


static func cell_of(key: Vector3i) -> Vector2i:
	return Vector2i(key.x, key.y)


static func level_of(key: Vector3i) -> int:
	return key.z


## Moves within the same level. Levels are never crossed by a map-space offset:
## a change of level is a transition (a stair, a ramp mouth, a door), which the
## future `IndoorGraph` owns explicitly.
static func offset(key: Vector3i, delta: Vector2i) -> Vector3i:
	return Vector3i(key.x + delta.x, key.y + delta.y, key.z)


## Converts a caller-facing `Vector2i` set into the ground-level key set. Callers
## outside routing still speak map coordinates; this is the one place that
## promotion happens.
static func ground_keys(cells: Dictionary) -> Dictionary:
	var keys: Dictionary = {}
	for cell: Variant in cells:
		if cell is Vector2i:
			keys[ground(cell)] = true
	return keys
