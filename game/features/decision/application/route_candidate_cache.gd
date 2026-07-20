class_name RouteCandidateCache
extends RefCounted

## Time-limited cache for route candidate lists. Avoids recomputing expensive
## pathfinding on every snapshot when the citizen has not moved and the nav grid
## topology has not changed.

const CACHE_SECONDS := 1.0
const MAX_ENTRIES := 1024

var _cache: Dictionary = {}


func get_or_produce(
	key: StringName,
	topology_revision: int,
	origin_cell: Vector2i,
	now: float,
	producer: Callable
) -> Array[Dictionary]:
	var cached := _cache.get(key, {}) as Dictionary
	if (
		not cached.is_empty()
		and int(cached.get(&"topology_revision", -2)) == topology_revision
		and cached.get(&"origin_cell", Vector2i(-999999, -999999)) == origin_cell
		and float(cached.get(&"expires_at", -INF)) >= now
	):
		return (cached.get(&"candidates", []) as Array).duplicate(true)
	var produced: Array[Dictionary] = producer.call()
	if _cache.size() >= MAX_ENTRIES:
		_cache.clear()
	_cache[key] = {
		&"topology_revision": topology_revision,
		&"origin_cell": origin_cell,
		&"expires_at": now + CACHE_SECONDS,
		&"candidates": produced.duplicate(true),
	}
	return produced
