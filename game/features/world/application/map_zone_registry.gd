class_name MapZoneRegistry
extends RefCounted

## Session-state of every authored zone on the map (active_zones.md §13).
##
## The map-side peer of `BuildingRuntimeState.zones`: where the building carries
## one `ZoneRuntimeState` per room on a node's meta, the map carries one
## `MapZoneRuntimeState` per region/overlay here, in memory. The split is the
## same — definition comes from the file (`MapZoneLayer`), session state lives in
## the party — only the storage differs, because a map has no per-zone node to
## hang meta off.
##
## The registry is the single owner of map-zone session state, the way
## `MapZoneLayer` is the single owner of its definition. `MapZoneService` is the
## facade rules will eventually call through; nothing else mutates this directly.

var _states: Dictionary = {} # zone_id (StringName) -> MapZoneRuntimeState


func clear() -> void:
	_states.clear()


## Builds session state for every area on the layer. Idempotent — a rebuild
## discards the previous session, which is correct for a fresh launch and wrong
## mid-session: once persistence exists, a save load will call `apply_session_state`
## after this rather than rebuild a second time.
func build_from(zones: MapZoneLayer) -> void:
	clear()
	for area in zones.areas:
		_states[area.id] = MapZoneRuntimeState.from_definition(area)


func state(zone_id: StringName) -> MapZoneRuntimeState:
	return _states.get(zone_id, null)


func owner_of(zone_id: StringName) -> StringName:
	var s := state(zone_id)
	return s.owner_tag if s != null else &""


func flag_of(zone_id: StringName, key: StringName, fallback: Variant = null) -> Variant:
	var s := state(zone_id)
	return s.flag(key, fallback) if s != null else fallback


## Sets the owner of a zone, returning whether anything changed. A no-op (same
## owner, or a zone that does not exist) returns false so the service can skip
## publishing a spurious `owner_changed` once the event bus exists.
func set_owner(zone_id: StringName, owner_tag: StringName) -> bool:
	var s := state(zone_id)
	if s == null:
		return false
	return s.set_owner(owner_tag)


func set_flag(zone_id: StringName, key: StringName, value: Variant) -> bool:
	var s := state(zone_id)
	if s == null:
		return false
	return s.set_flag(key, value)


func is_owned_by(zone_id: StringName, agent_tags: Array) -> bool:
	var s := state(zone_id)
	return s.is_owned_by(agent_tags) if s != null else false


## Session slice of every zone, in id order, for a future save. Geometry never
## leaves the file, so this is only `{id, owner, flags}` per zone. Stable order
## keeps a map saved twice without an edit byte-identical.
func session_state_to_dict() -> Array:
	var ids: Array = _states.keys()
	ids.sort()
	var result: Array = []
	for id in ids:
		result.append((_states[id] as MapZoneRuntimeState).session_state_to_dict())
	return result
